import 'dart:math';

import 'entities/partido.dart';
import 'entities/temporada.dart';
import 'historicos.dart';
import 'liga.dart';
import 'premios.dart';

/// Un titular de la semana (cada 7 jornadas).
class Titular {
  const Titular(this.jornada, this.texto, {this.franquiciaId, this.destacado = false});

  /// Última jornada de la semana a la que se refiere.
  final int jornada;
  final String texto;
  final String? franquiciaId;

  /// Tiene que ver con tu equipo.
  final bool destacado;
}

/// Jornadas por "semana" de titulares.
const jornadasPorSemana = 7;

/// Titulares de la temporada, del más nuevo al más viejo: rachas, batacazos, palizas, punteros por
/// conferencia, la carrera al MVP y los récords en juego. Deterministas: la misma temporada da los
/// mismos titulares. [nombre] da el nombre visible de cada franquicia (con su identidad de época).
List<Titular> titulares(Temporada t, Liga liga, {required String Function(String franquiciaId) nombre}) {
  final usuario = t.franquiciaUsuarioId;
  final jornadas = {for (final p in t.calendario) p.jornada};
  if (jornadas.isEmpty) return const [];
  final ultimaCompleta = [
    for (final j in jornadas)
      if (t.calendario.where((p) => p.jornada <= j).every((p) => p.jugado)) j,
  ].fold(0, max);
  final semanas = ultimaCompleta ~/ jornadasPorSemana;
  final conferencias = {for (final f in liga.franquicias) f.id: f.conferencia};
  final resultado = <Titular>[];

  for (var s = 1; s <= semanas; s++) {
    final desde = (s - 1) * jornadasPorSemana + 1, hasta = s * jornadasPorSemana;
    final azar = Random(Object.hash(t.id, s));
    String uno(List<String> opciones) => opciones[azar.nextInt(opciones.length)];
    final hastaAhora = t.calendario.where((p) => p.jornada <= hasta && p.jugado).toList();
    (int, int) record(String f) {
      var v = 0, d = 0;
      for (final p in hastaAhora) {
        if (!p.participa(f)) continue;
        p.ganadorId == f ? v++ : d++;
      }
      return (v, d);
    }

    final semana = hastaAhora.where((p) => p.jornada >= desde).toList();
    final semanaTitulares = <Titular>[];

    // Tu equipo: racha o semana.
    final propios = hastaAhora.where((p) => p.participa(usuario)).toList()
      ..sort((a, b) => a.jornada.compareTo(b.jornada));
    var racha = 0;
    final ganando = propios.isNotEmpty && propios.last.ganadorId == usuario;
    for (final p in propios.reversed) {
      if ((p.ganadorId == usuario) != ganando) break;
      racha++;
    }
    final propio = nombre(usuario);
    final (v, d) = record(usuario);
    if (ganando && racha >= 5) {
      semanaTitulares.add(
        Titular(
          hasta,
          uno([
            'Los $propio no paran: $racha al hilo ($v-$d).',
            'Racha de $racha triunfos seguidos para los $propio.',
            '¿Quién frena a los $propio? Van $racha seguidos.',
          ]),
          franquiciaId: usuario,
          destacado: true,
        ),
      );
    } else if (!ganando && racha >= 3) {
      semanaTitulares.add(
        Titular(
          hasta,
          uno([
            'Crisis en los $propio: $racha derrotas seguidas.',
            'Se encendieron las alarmas: los $propio perdieron $racha al hilo.',
          ]),
          franquiciaId: usuario,
          destacado: true,
        ),
      );
    } else {
      final semanales = semana.where((p) => p.participa(usuario)).toList();
      final g = semanales.where((p) => p.ganadorId == usuario).length;
      if (semanales.isNotEmpty) {
        semanaTitulares.add(
          Titular(
            hasta,
            'Semana ${g * 2 >= semanales.length ? 'positiva' : 'para olvidar'} de los $propio: ganaron $g de ${semanales.length} ($v-$d).',
            franquiciaId: usuario,
            destacado: true,
          ),
        );
      }
    }

    // Batacazo: el peor récord le gana al mejor.
    Partido? batacazo;
    var diferencia = 0.0;
    for (final p in semana) {
      final ganador = p.ganadorId!;
      final perdedor = p.localId == ganador ? p.visitanteId : p.localId;
      final (vg, dg) = record(ganador);
      final (vp, dp) = record(perdedor);
      final pg = vg / max(1, vg + dg), pp = vp / max(1, vp + dp);
      if (pp - pg > diferencia) {
        diferencia = pp - pg;
        batacazo = p;
      }
    }
    if (batacazo != null && diferencia >= 0.3) {
      final ganador = batacazo.ganadorId!;
      final perdedor = batacazo.localId == ganador ? batacazo.visitanteId : batacazo.localId;
      final (vg, dg) = record(ganador);
      final (vp, dp) = record(perdedor);
      semanaTitulares.add(
        Titular(
          hasta,
          uno([
            'Batacazo: los ${nombre(ganador)} ($vg-$dg) le ganaron a los ${nombre(perdedor)} ($vp-$dp).',
            'Nadie lo esperaba: los ${nombre(ganador)} sorprendieron a los ${nombre(perdedor)}.',
          ]),
          franquiciaId: ganador,
          destacado: ganador == usuario || perdedor == usuario,
        ),
      );
    }

    // Paliza de la semana.
    Partido? paliza;
    for (final p in semana) {
      if (paliza == null ||
          (p.puntosLocal - p.puntosVisitante).abs() > (paliza.puntosLocal - paliza.puntosVisitante).abs()) {
        paliza = p;
      }
    }
    if (paliza != null && (paliza.puntosLocal - paliza.puntosVisitante).abs() >= 25) {
      final ganador = paliza.ganadorId!;
      final perdedor = paliza.localId == ganador ? paliza.visitanteId : paliza.localId;
      final a = max(paliza.puntosLocal, paliza.puntosVisitante), b = min(paliza.puntosLocal, paliza.puntosVisitante);
      semanaTitulares.add(
        Titular(
          hasta,
          'Paliza de los ${nombre(ganador)}: $a-$b a los ${nombre(perdedor)}.',
          franquiciaId: ganador,
          destacado: ganador == usuario || perdedor == usuario,
        ),
      );
    }

    // Punteros por conferencia (cada tanto, para no repetir siempre lo mismo).
    if (s % 2 == 0) {
      for (final conf in {...conferencias.values}) {
        final de = conferencias.entries.where((e) => e.value == conf).map((e) => e.key).toList()
          ..sort((a, b) {
            final (va, da) = record(a);
            final (vb, db) = record(b);
            return (vb / max(1, vb + db)).compareTo(va / max(1, va + da));
          });
        if (de.isEmpty) continue;
        final (vl, dl) = record(de.first);
        semanaTitulares.add(
          Titular(
            hasta,
            'Los ${nombre(de.first)} mandan en el ${conf?.etiqueta.replaceFirst('Conferencia ', '') ?? 'Oeste'} ($vl-$dl).',
            franquiciaId: de.first,
            destacado: de.first == usuario,
          ),
        );
      }
    }

    // La carrera al MVP y los récords, solo en la semana más reciente (con los datos de hoy).
    if (s == semanas) {
      final carrera = carreraMvp(t, liga);
      if (carrera.isNotEmpty) {
        final l = carrera.first;
        semanaTitulares.add(
          Titular(
            hasta,
            '${l.jugador.nombre}, al frente de la carrera al MVP: '
            '${l.por(l.linea.pts).toStringAsFixed(1).replaceAll('.', ',')} puntos por partido.',
            franquiciaId: l.franquiciaId,
            destacado: l.franquiciaId == usuario,
          ),
        );
      }
      for (final r in recordsEnJuego(t, liga)) {
        semanaTitulares.add(Titular(hasta, r.texto, franquiciaId: usuario, destacado: true));
      }
    }
    resultado.addAll(semanaTitulares.reversed);
  }
  return resultado.reversed.toList();
}

/// Los 5 primeros de la carrera al MVP con lo jugado hasta hoy.
List<Galardon> carreraMvp(Temporada t, Liga liga) => candidatos(t, liga).take(5).toList();
