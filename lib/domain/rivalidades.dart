import 'dart:math';

import 'entities/metajuego.dart';
import 'entities/partido.dart';
import 'entities/temporada.dart';

// Rivalidades persistentes con "mala sangre" (ronda 2).
//
// DECISIÓN DE DISEÑO: el calor de una rivalidad es SOLO NARRATIVO y de lectura (tarjeta del próximo
// partido, playoffs, escalera y noticias; también lo lee el relator vía `ContextoNarrativo`). No
// toca el motor ni las probabilidades: así no se mueve el balance (test/balance_test.dart) y el
// efecto es siempre simétrico y legible: lo que se siente es la historia, no un número escondido.
//
// Cómo se acumula (todo por diferencia de estado, ver `Rivalidades.registrar` en misiones.dart):
//   derrota en temporada regular +2 · derrota en un partido de playoffs +4 · victoria en playoffs +1
//   partido picante (prórroga o definido por ≤ 3 puntos) +3 · te eliminó +30 (+20 si fue en 7 juegos)
//   le ganaste una serie +8 (+10 si fue en 7 juegos) · revancha cumplida −10.
// Cómo se enfría: cada vez que arranca una temporada (partida) nueva, el calor vale el 75 %.

/// Qué tan caliente está una rivalidad.
enum NivelRivalidad {
  fria('Fría'),
  caliente('Caliente'),
  malaSangre('Mala sangre'),
  odio('Odio total');

  const NivelRivalidad(this.etiqueta);
  final String etiqueta;
}

/// Lo que la UI y el relator saben de una rivalidad con una franquicia.
class RelatoRivalidad {
  const RelatoRivalidad({required this.nivel, required this.calor, required this.frase, this.fichas = const []});

  final NivelRivalidad nivel;

  /// 0–100, ya enfriado a la temporada actual.
  final int calor;

  /// Frase en voseo: "Los Knicks te sacaron en 6 el año pasado."
  final String frase;

  /// Datos cortos para chips: "2 series cerradas", "4 partidos picantes".
  final List<String> fichas;

  /// Vale la pena mostrarla (no es una rivalidad fría y sin cuentas pendientes).
  bool get visible => nivel != NivelRivalidad.fria || frase.isNotEmpty;
}

class MalaSangre {
  MalaSangre._();

  static const maximo = 100;
  static const factorEnfriamiento = 0.75;

  /// Puntos que suma cada hecho.
  static const derrotaRegular = 2, derrotaPlayoff = 4, victoriaPlayoff = 1, picante = 3;
  static const eliminacion = 30, eliminacionEnSiete = 20, serieGanada = 8, serieGanadaEnSiete = 10;
  static const revanchaCumplida = 10;

  /// Calor de [r] visto desde la temporada [temporadaId] (enfriado una vez si es de otra partida).
  static int vigente(Rivalidad r, String temporadaId) => r.calorTemporadaId == null || r.calorTemporadaId == temporadaId
      ? r.calor
      : (r.calor * factorEnfriamiento).floor();

  static NivelRivalidad nivel(int calor) => calor >= 80
      ? NivelRivalidad.odio
      : calor >= 50
      ? NivelRivalidad.malaSangre
      : calor >= 20
      ? NivelRivalidad.caliente
      : NivelRivalidad.fria;

  /// Suma (o resta) [delta] al calor, enfriando antes si cambió la temporada. Nunca baja de 0 ni pasa de 100.
  static Rivalidad sumar(Rivalidad r, int delta, String temporadaId) =>
      r.copyWith(calor: (vigente(r, temporadaId) + delta).clamp(0, maximo), calorTemporadaId: temporadaId);

  /// Un partido picante: prórroga (más de 4 periodos) o definido por 3 puntos o menos.
  static bool esPicante(Partido p) =>
      p.jugado &&
      (p.periodosLocal.length > Partido.cuartosReglamentarios || (p.puntosLocal - p.puntosVisitante).abs() <= 3);

  /// Frase de rivalidad con [rivalId]; null si no hay nada que contar. [nombre] es "Knicks" (sin "los").
  /// [numeroActual]: número de tu temporada en la carrera (si se conoce) para decir "el año pasado".
  static RelatoRivalidad? relato(
    Map<String, Rivalidad> rivalidades,
    Temporada t,
    String rivalId,
    String nombre, {
    int? numeroActual,
  }) {
    final r = rivalidades[rivalId];
    if (r == null) return null;
    final calor = vigente(r, t.id);
    final nv = nivel(calor);
    final pendiente = r.eliminaciones > r.revanchas && r.temporadaId != t.id;
    String? frase;
    if (pendiente) {
      final juegos = r.juegosEliminacion == null ? '' : ' en ${r.juegosEliminacion}';
      final cuando = r.temporadaNumero == null
          ? ''
          : numeroActual != null && numeroActual - 1 == r.temporadaNumero
          ? ' el año pasado'
          : ' en tu temporada ${r.temporadaNumero}';
      frase = 'Los $nombre te sacaron$juegos$cuando. Hay cuenta pendiente.';
    } else if (r.eliminaciones > 0 && r.temporadaId == t.id) {
      frase = 'Esta temporada ya te sacaron los $nombre: no se olvida.';
    } else if (r.cerradas >= 2) {
      frase = 'Con los $nombre ya van ${r.cerradas} series que se definen por detalles.';
    } else if (r.derrotas >= 5) {
      frase = 'Los $nombre te vienen ganando: ${r.derrotas} partidos en tu carrera.';
    } else if (r.picantes >= 2) {
      frase = 'Cada partido con los $nombre se pica: ${r.picantes} al límite.';
    } else if (r.revanchas > 0) {
      frase = 'Ya los dejaste afuera una vez. Los $nombre vienen por la revancha.';
    } else if (nv != NivelRivalidad.fria) {
      frase = 'Hay tensión con los $nombre desde hace rato.';
    }
    if (frase == null) return null;
    return RelatoRivalidad(
      nivel: nv,
      calor: calor,
      frase: frase,
      fichas: [
        if (r.eliminaciones > 0) '${r.eliminaciones} ${r.eliminaciones == 1 ? 'eliminación' : 'eliminaciones'}',
        if (r.cerradas > 0) '${r.cerradas} ${r.cerradas == 1 ? 'serie cerrada' : 'series cerradas'}',
        if (r.picantes > 0) '${r.picantes} ${r.picantes == 1 ? 'partido picante' : 'partidos picantes'}',
        if (r.derrotas + r.victorias > 0) 'Duelos: ${r.victorias}-${r.derrotas}',
      ],
    );
  }

  /// Partido picante por faltas técnicas o expulsiones (el partido en vivo conoce estos datos; la
  /// temporada no): suma al calor de [rivalId]. Lo puede llamar quien cierre un partido en vivo.
  static Metajuego anotarPicante(
    Metajuego m,
    String rivalId,
    String temporadaId, {
    int tecnicas = 0,
    int expulsiones = 0,
  }) {
    if (tecnicas + expulsiones == 0) return m;
    final r = m.rivalidades[rivalId] ?? Rivalidad(franquiciaId: rivalId);
    final extra = min(10, tecnicas * 2 + expulsiones * 4);
    final nueva = sumar(r, extra, temporadaId).copyWith(picantes: r.picantes + 1);
    return m.copyWith(rivalidades: {...m.rivalidades, rivalId: nueva});
  }
}
