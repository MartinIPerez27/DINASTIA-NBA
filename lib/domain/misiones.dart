import 'dart:math';

import 'entities/metajuego.dart';
import 'entities/perfil.dart';
import 'entities/temporada.dart';
import 'rivalidades.dart';

/// Misiones diarias y semanales: salen de la fecha (las mismas para todos, sin conexión) y avanzan
/// con lo que pasa en tus partidas.
class Misiones {
  Misiones._();

  /// Quién registra el avance que no queda en la temporada (jugar en vivo, ganar un partido de un modo
  /// de escalera). La app lo conecta al perfil y a la base (ver main.dart): se aplica y se guarda en el
  /// momento, así que no hay cola en memoria que se pierda al cerrar la app.
  static void Function(TipoMision tipo, int cantidad)? alAnotar;

  /// Suma avance a una misión desde fuera de la temporada (p. ej. un partido de Racha ganado).
  static void anotar(TipoMision tipo, [int cantidad = 1]) => alAnotar?.call(tipo, cantidad);

  /// Versión pura de [anotar]: el perfil con el avance sumado (y las misiones al día).
  static PerfilEntrenador anotarEn(PerfilEntrenador p, TipoMision tipo, int cantidad, DateTime ahora) =>
      p.copyWith(metajuego: avanzar(alDia(p.metajuego, ahora), {tipo: cantidad}));

  static const _diarias = [
    (TipoMision.ganarPartidos, 3),
    (TipoMision.ganarPorMargen, 1),
    (TipoMision.triples, 15),
    (TipoMision.rebotes, 60),
    (TipoMision.asistencias, 40),
    (TipoMision.jugarEnVivo, 1),
    (TipoMision.ficharSuplente, 1),
    (TipoMision.ganarDesafio, 1),
    (TipoMision.ganarPlayoff, 2),
  ];

  static const _semanales = [
    (TipoMision.ganarPartidos, 15),
    (TipoMision.ganarPorMargen, 5),
    (TipoMision.triples, 80),
    (TipoMision.rebotes, 300),
    (TipoMision.asistencias, 200),
    (TipoMision.jugarEnVivo, 3),
    (TipoMision.ganarPlayoff, 8),
    (TipoMision.ganarDesafio, 5),
  ];

  static String _dos(int n) => n.toString().padLeft(2, '0');
  static String _clave(DateTime f) => '${f.year}${_dos(f.month)}${_dos(f.day)}';

  /// El lunes de la semana de [f].
  static DateTime lunes(DateTime f) => DateTime(f.year, f.month, f.day).subtract(Duration(days: f.weekday - 1));

  static List<Mision> _elegir(List<(TipoMision, int)> pool, String clave, {required bool semanal}) {
    final lista = [...pool]..shuffle(Random(int.parse(clave) * (semanal ? 7 : 1)));
    return [
      for (final (i, (tipo, objetivo)) in lista.take(3).indexed)
        Mision(id: '${semanal ? 'w' : 'd'}-$clave-$i', tipo: tipo, objetivo: objetivo, semanal: semanal),
    ];
  }

  /// Las 3 diarias y las 3 semanales que tocan en [fecha] (siempre las mismas para esa fecha).
  static List<Mision> generar(DateTime fecha) => [
    ..._elegir(_diarias, _clave(fecha), semanal: false),
    ..._elegir(_semanales, _clave(lunes(fecha)), semanal: true),
  ];

  /// Pase vigente: uno por trimestre ('2026-T4').
  static String paseDe(DateTime f) => '${f.year}-T${(f.month - 1) ~/ 3 + 1}';

  static int _fechaInt(DateTime f) => int.parse(_clave(f));

  /// Renueva misiones vencidas (conserva el avance de las vigentes) y el pase si cambió el trimestre.
  ///
  /// Las misiones cumplidas y sin cobrar de días anteriores NO se pierden: quedan en la lista para
  /// cobrarlas. Y si el reloj del teléfono se atrasa, se sigue usando la última fecha vista (si no,
  /// las misiones ya cobradas volverían a aparecer y se podrían cobrar de nuevo).
  static Metajuego alDia(Metajuego m, DateTime ahora) {
    final hoy = _fechaInt(ahora);
    final fecha = m.ultimaFecha > hoy
        ? DateTime(m.ultimaFecha ~/ 10000, (m.ultimaFecha ~/ 100) % 100, m.ultimaFecha % 100)
        : ahora;
    final previas = {for (final x in m.misiones) x.id: x};
    final vigentes = [for (final x in generar(fecha)) previas[x.id] ?? x];
    final ids = {for (final x in vigentes) x.id};
    final rezagadas = [
      for (final x in m.misiones)
        if (x.cumplida && !x.reclamada && !ids.contains(x.id)) x,
    ];
    final misiones = [...vigentes, ...rezagadas];
    final pase = paseDe(fecha);
    final nuevaFecha = max(m.ultimaFecha, hoy);
    final mismas = misiones.length == m.misiones.length && misiones.every((x) => previas[x.id] == x);
    if (mismas && pase == m.pase && nuevaFecha == m.ultimaFecha) return m;
    return pase == m.pase
        ? m.copyWith(misiones: misiones, ultimaFecha: nuevaFecha)
        : m.copyWith(misiones: misiones, pase: pase, puntosPase: 0, nivelesReclamados: {}, ultimaFecha: nuevaFecha);
  }

  /// Cuánto avanzó cada tipo de misión entre dos estados de la misma temporada.
  static Map<TipoMision, int> diferencias(Temporada antes, Temporada despues) {
    final r = <TipoMision, int>{};
    void sumar(TipoMision t, int n) {
      if (n > 0) r[t] = (r[t] ?? 0) + n;
    }

    final usuario = despues.franquiciaUsuarioId;
    final jugadosAntes = {
      for (final x in antes.calendario)
        if (x.jugado) x.id,
    };
    for (final x in despues.calendario) {
      if (!x.jugado || jugadosAntes.contains(x.id) || !x.participa(usuario) || x.ganadorId != usuario) continue;
      sumar(TipoMision.ganarPartidos, 1);
      if ((x.puntosLocal - x.puntosVisitante).abs() >= 15) sumar(TipoMision.ganarPorMargen, 1);
    }
    int victorias(List<SeriePlayoff> series) => series.fold(
      0,
      (a, s) =>
          a +
          (s.altoId == usuario
              ? s.victoriasAlto
              : s.bajoId == usuario
              ? s.victoriasBajo
              : 0),
    );
    final playoffs = victorias(despues.series) - victorias(antes.series);
    sumar(TipoMision.ganarPlayoff, playoffs);
    sumar(TipoMision.ganarPartidos, playoffs + victorias(despues.copa) - victorias(antes.copa));

    final propios = {
      for (final j in [...despues.plantel.jugadores, ...despues.suplentes]) j.id,
    };
    (int, int, int) totales(Temporada t) {
      var t3 = 0, reb = 0, ast = 0;
      for (final lineas in [t.lineas, t.lineasPlayoffs]) {
        for (final id in propios) {
          final l = lineas[id];
          if (l == null) continue;
          t3 += l.t3I;
          reb += l.reb;
          ast += l.ast;
        }
      }
      return (t3, reb, ast);
    }

    final (t3a, reba, asta) = totales(antes);
    final (t3d, rebd, astd) = totales(despues);
    sumar(TipoMision.triples, t3d - t3a);
    sumar(TipoMision.rebotes, rebd - reba);
    sumar(TipoMision.asistencias, astd - asta);
    final suplentesAntes = {for (final j in antes.suplentes) j.id};
    sumar(TipoMision.ficharSuplente, despues.suplentes.where((j) => !suplentesAntes.contains(j.id)).length);
    return r;
  }

  /// Suma avance a las misiones sin reclamar.
  static Metajuego avanzar(Metajuego m, Map<TipoMision, int> sumas) {
    if (sumas.isEmpty) return m;
    return m.copyWith(
      misiones: [
        for (final x in m.misiones)
          x.reclamada || x.cumplida || (sumas[x.tipo] ?? 0) == 0
              ? x
              : x.conProgreso(min(x.objetivo, x.progreso + sumas[x.tipo]!)),
      ],
    );
  }

  /// Cobra una misión cumplida: XP, monedas y puntos del pase. Null si no se puede.
  static PerfilEntrenador? reclamar(PerfilEntrenador p, String misionId) {
    final m = p.metajuego;
    final i = m.misiones.indexWhere((x) => x.id == misionId);
    if (i < 0 || !m.misiones[i].cumplida || m.misiones[i].reclamada) return null;
    final (xp, monedas, puntos) = m.misiones[i].premio;
    final misiones = [...m.misiones]..[i] = m.misiones[i].comoReclamada;
    return p.copyWith(
      xp: p.xp + xp,
      monedas: p.monedas + monedas,
      metajuego: m.copyWith(misiones: misiones, puntosPase: m.puntosPase + puntos),
    );
  }

  /// Hay algo para cobrar (misión cumplida o nivel del pase alcanzado).
  static bool hayParaReclamar(PerfilEntrenador p) =>
      p.metajuego.misiones.any((x) => x.cumplida && !x.reclamada) || PaseTemporada.pendientes(p).isNotEmpty;
}

/// Pase de temporada offline: 20 niveles por trimestre, solo premios estéticos y monedas.
class PaseTemporada {
  PaseTemporada._();

  static const niveles = 20, puntosPorNivel = 200;

  /// Puntos por jugar (además de las misiones).
  static const puntosVictoria = 10, puntosDerrota = 3;

  static int nivel(int puntos) => min(niveles, puntos ~/ puntosPorNivel);

  /// El cosmético de ese nivel, si tiene.
  static Cosmetico? cosmetico(int nivel) => Cosmetico.values.where((c) => c.nivelPase == nivel).firstOrNull;

  /// Monedas de un nivel sin cosmético (o con uno que ya tenés).
  static int monedas(int nivel) => 40 + 10 * nivel;

  /// Niveles alcanzados y sin cobrar.
  static List<int> pendientes(PerfilEntrenador p) => [
    for (var n = 1; n <= nivel(p.metajuego.puntosPase); n++)
      if (!p.metajuego.nivelesReclamados.contains(n)) n,
  ];

  /// Cobra un nivel. Null si no se puede.
  static PerfilEntrenador? reclamar(PerfilEntrenador p, int n) {
    final m = p.metajuego;
    if (n < 1 || n > nivel(m.puntosPase) || m.nivelesReclamados.contains(n)) return null;
    final c = cosmetico(n);
    final reclamados = {...m.nivelesReclamados, n};
    if (c != null && !m.cosmeticos.contains(c)) {
      return p.copyWith(
        metajuego: m.copyWith(nivelesReclamados: reclamados, cosmeticos: {...m.cosmeticos, c}),
      );
    }
    return p.copyWith(
      monedas: p.monedas + monedas(n),
      metajuego: m.copyWith(nivelesReclamados: reclamados),
    );
  }

  /// Si el cosmético se puede usar: de fábrica, ganado en el pase o por nivel de entrenador.
  static bool disponible(PerfilEntrenador p, Cosmetico c) =>
      c.deFabrica || p.metajuego.cosmeticos.contains(c) || (c.nivelEntrenador != null && p.nivel >= c.nivelEntrenador!);

  static PerfilEntrenador elegir(PerfilEntrenador p, Cosmetico c) {
    if (!disponible(p, c)) return p;
    final m = p.metajuego;
    return p.copyWith(metajuego: m.copyWith(elegidos: {...m.elegidos, c.categoria: c}));
  }
}

/// Rivalidades que se arrastran entre partidas ("Revancha").
class Rivalidades {
  Rivalidades._();

  /// Registra derrotas y eliminaciones nuevas. Devuelve el metajuego y las franquicias a las que
  /// acabás de eliminar después de que te eliminaran (revanchas cumplidas).
  static (Metajuego, List<String>) registrar(Metajuego m, Temporada antes, Temporada despues, {required int numero}) {
    final usuario = despues.franquiciaUsuarioId;
    final rivalidades = Map.of(m.rivalidades);
    Rivalidad de(String id) => rivalidades[id] ?? Rivalidad(franquiciaId: id);
    final cumplidas = <String>[];

    final jugadosAntes = {
      for (final x in antes.calendario)
        if (x.jugado) x.id,
    };
    for (final x in despues.calendario) {
      if (!x.jugado || jugadosAntes.contains(x.id) || !x.participa(usuario)) continue;
      final gane = x.ganadorId == usuario;
      final otroId = x.localId == usuario ? x.visitanteId : x.localId;
      final picante = MalaSangre.esPicante(x);
      // Los partidos ganados solo cuentan si ya hay historia con ese rival o fue picante.
      if (gane && !picante && !rivalidades.containsKey(otroId)) continue;
      var r = de(otroId);
      r = gane ? r.copyWith(victorias: r.victorias + 1) : r.copyWith(derrotas: r.derrotas + 1);
      r = MalaSangre.sumar(r, (gane ? 0 : MalaSangre.derrotaRegular) + (picante ? MalaSangre.picante : 0), despues.id);
      if (picante) r = r.copyWith(picantes: r.picantes + 1);
      if (r.calor > 0 || r.derrotas > 0 || r.eliminaciones > 0) rivalidades[otroId] = r;
    }
    for (final s in despues.series) {
      if (s.altoId != usuario && s.bajoId != usuario) continue;
      final rivalId = s.altoId == usuario ? s.bajoId : s.altoId;
      final previa = antes.series.where((a) => a.ronda == s.ronda && a.altoId == s.altoId && a.bajoId == s.bajoId);
      final derrotasRival = s.altoId == usuario ? s.victoriasBajo : s.victoriasAlto;
      final derrotasAntes = previa.isEmpty
          ? 0
          : (s.altoId == usuario ? previa.first.victoriasBajo : previa.first.victoriasAlto);
      var r = de(rivalId);
      final victoriasRival = s.altoId == usuario ? s.victoriasAlto : s.victoriasBajo;
      final victoriasAntes = previa.isEmpty
          ? 0
          : (s.altoId == usuario ? previa.first.victoriasAlto : previa.first.victoriasBajo);
      if (derrotasRival > derrotasAntes) {
        final n = derrotasRival - derrotasAntes;
        r = r.copyWith(derrotas: r.derrotas + n);
        r = MalaSangre.sumar(r, n * MalaSangre.derrotaPlayoff, despues.id);
      }
      if (victoriasRival > victoriasAntes) {
        final n = victoriasRival - victoriasAntes;
        r = r.copyWith(victorias: r.victorias + n);
        r = MalaSangre.sumar(r, n * MalaSangre.victoriaPlayoff, despues.id);
      }
      final recienTerminada = s.terminada && (previa.isEmpty || !previa.first.terminada);
      final juegos = s.victoriasAlto + s.victoriasBajo;
      if (recienTerminada && !s.ronda.esPlayIn && juegos >= 6) r = r.copyWith(cerradas: r.cerradas + 1);
      if (recienTerminada && s.ganadorId != usuario) {
        r = r.copyWith(
          eliminaciones: r.eliminaciones + 1,
          ronda: s.ronda.name,
          temporadaId: despues.id,
          temporadaNumero: numero,
          juegosEliminacion: s.ronda.esPlayIn ? null : juegos,
        );
        r = MalaSangre.sumar(r, MalaSangre.eliminacion + (juegos >= 7 ? MalaSangre.eliminacionEnSiete : 0), despues.id);
      } else if (recienTerminada) {
        r = MalaSangre.sumar(r, MalaSangre.serieGanada + (juegos >= 7 ? MalaSangre.serieGanadaEnSiete : 0), despues.id);
        if (r.eliminaciones > r.revanchas && r.temporadaId != despues.id) {
          r = r.copyWith(revanchas: r.revanchas + 1);
          r = MalaSangre.sumar(r, -MalaSangre.revanchaCumplida, despues.id);
          cumplidas.add(rivalId);
        }
      }
      if (r.eliminaciones > 0 || r.derrotas > 0 || r.calor > 0) rivalidades[rivalId] = r;
    }
    return (m.copyWith(rivalidades: rivalidades), cumplidas);
  }

  static String _ronda(String? nombre) => switch (RondaPlayoff.values.asNameMap()[nombre]) {
    RondaPlayoff.playIn || RondaPlayoff.playInFinal => 'el Play-In',
    RondaPlayoff.primeraRonda => 'la 1.ª ronda',
    RondaPlayoff.semifinalConferencia => 'las Semifinales de Conferencia',
    RondaPlayoff.finalConferencia => 'las Finales de Conferencia',
    RondaPlayoff.finalesNba => 'Las Finales',
    _ => 'los playoffs',
  };

  /// Relato de la rivalidad (mala sangre, series cerradas, picantes) con [rivalId]: ver `MalaSangre.relato`.
  /// [nombre] va sin artículo ("Knicks"). Null si no hay historia con esa franquicia.
  static RelatoRivalidad? relato(PerfilEntrenador p, Temporada t, String rivalId, String nombre, {int? numeroActual}) =>
      MalaSangre.relato(p.metajuego.rivalidades, t, rivalId, nombre, numeroActual: numeroActual ?? p.historial.length + 1);

  /// "Te eliminaron en las Finales de Conferencia de tu temporada 3", o null si no hay cuenta
  /// pendiente con esa franquicia (o si fue en esta misma partida).
  static String? contexto(PerfilEntrenador p, Temporada t, String rivalId) {
    final r = p.metajuego.rivalidades[rivalId];
    if (r == null || !r.pendiente) return null;
    if (r.eliminaciones > r.revanchas && r.temporadaId != t.id) {
      final cuando = r.temporadaNumero == null ? '' : ' de tu temporada ${r.temporadaNumero}';
      return 'Te eliminaron en ${_ronda(r.ronda)}$cuando';
    }
    if (r.derrotas >= 5) return 'Te ganaron ${r.derrotas} partidos en tu carrera';
    return null;
  }
}
