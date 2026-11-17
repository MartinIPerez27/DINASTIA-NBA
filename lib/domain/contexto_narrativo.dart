import 'entities/metajuego.dart';
import 'entities/partido.dart';
import 'entities/temporada.dart';
import 'historias.dart';
import 'historicos.dart' as hist;
import 'liga.dart';
import 'rivalidades.dart';
import 'tension.dart';

/// Contexto de un partido para quien lo cuenta (el relator/comentarista) y para los banners.
///
/// CONTRATO ESTABLE para el agente de narración: los nombres de los campos y de [lineas] no cambian.
/// Nada acá depende de Flutter ni del motor; se arma desde `Temporada` + `Liga` + las rivalidades del perfil:
///
/// ```dart
/// final ctx = ContextoNarrativo.de(temporada, liga,
///     partido: partido,            // o serie: serie (playoffs)
///     rivalidades: perfil.metajuego.rivalidades,
///     nombre: (id) => franquiciaPorId(...).nombre);
/// ctx.lineas;          // frases listas para intercalar en el relato, de más a menos importante
/// ctx.presion?.etiqueta; // "PARTIDO 7", "MATCH POINT"…
/// ```
class ContextoNarrativo {
  const ContextoNarrativo({
    required this.usuarioId,
    required this.rivalId,
    required this.rivalNombre,
    this.rachaPropia = 0,
    this.rachaRival = 0,
    this.recordPropio = (0, 0),
    this.recordRival = (0, 0),
    this.rivalidad,
    this.recordsEnJuego = const [],
    this.presion,
    this.invicto = false,
    this.lesionesRival = const [],
    this.lesionesPropias = const [],
  });

  final String usuarioId;
  final String rivalId;

  /// Nombre visible del rival sin artículo ("Knicks").
  final String rivalNombre;

  /// Con signo: positiva = victorias seguidas; negativa = derrotas seguidas.
  final int rachaPropia, rachaRival;

  /// (victorias, derrotas) en la temporada regular.
  final (int, int) recordPropio, recordRival;

  /// Rivalidad persistente con ese rival (mala sangre), si la hay.
  final RelatoRivalidad? rivalidad;

  /// Textos de récords históricos que tu equipo o tus jugadores persiguen.
  final List<String> recordsEnJuego;

  /// Presión del partido (solo en series; null en temporada regular).
  final PresionPartido? presion;

  /// Venís sin perder (la ilusión del 82-0).
  final bool invicto;

  /// Nombres de figuras lesionadas ("Jokic").
  final List<String> lesionesRival, lesionesPropias;

  bool get esDecisivo => presion?.decisivo ?? false;
  bool get esEliminacion => presion?.eliminacion ?? false;
  bool get esMatchPoint => presion?.matchPoint ?? false;
  bool get hayMalaSangre =>
      rivalidad != null && (rivalidad!.nivel == NivelRivalidad.malaSangre || rivalidad!.nivel == NivelRivalidad.odio);

  /// Frases cortas en voseo/rioplatense, de más a menos importante (máximo 5). Nunca vacío.
  List<String> get lineas {
    final r = <String>[];
    if (presion != null && presion!.nivel.index >= NivelTension.alta.index) {
      r.add('${presion!.etiqueta}. ${presion!.detalle}');
    }
    if (rivalidad != null && rivalidad!.nivel != NivelRivalidad.fria) r.add(rivalidad!.frase);
    if (invicto && recordPropio.$1 >= 5) {
      r.add('Los tuyos siguen invictos: ${recordPropio.$1}-0.');
    } else if (rachaPropia >= 5) {
      r.add('Llegan con $rachaPropia victorias seguidas.');
    } else if (rachaPropia <= -3) {
      r.add('Vienen golpeados: ${-rachaPropia} derrotas al hilo.');
    }
    if (rachaRival >= 5) r.add('Los $rivalNombre llegan en racha: $rachaRival seguidos.');
    for (final n in lesionesRival.take(1)) {
      r.add('Los $rivalNombre no tienen a $n.');
    }
    for (final n in lesionesPropias.take(1)) {
      r.add('Tus chicos juegan sin $n.');
    }
    r.addAll(recordsEnJuego.take(1));
    if (r.isEmpty) {
      r.add(
        '${recordPropio.$1}-${recordPropio.$2} contra ${recordRival.$1}-${recordRival.$2}: un partido más de la temporada.',
      );
    }
    return r.take(5).toList();
  }

  /// Arma el contexto del próximo partido ([partido]) o de una serie de playoffs ([serie]).
  static ContextoNarrativo de(
    Temporada t,
    Liga liga, {
    Partido? partido,
    SeriePlayoff? serie,
    Map<String, Rivalidad> rivalidades = const {},
    required String Function(String franquiciaId) nombre,
    int? numeroActual,
  }) {
    final u = t.franquiciaUsuarioId;
    final String rivalId;
    if (serie != null) {
      rivalId = serie.altoId == u ? serie.bajoId : serie.altoId;
    } else {
      final p = partido ?? liga.proximoDelUsuario(t);
      rivalId = p == null ? u : (p.localId == u ? p.visitanteId : p.localId);
    }
    (int, int) rec(String f) {
      var v = 0, d = 0;
      for (final p in t.calendario) {
        if (!p.jugado || !p.participa(f)) continue;
        p.ganadorId == f ? v++ : d++;
      }
      return (v, d);
    }

    final equipos = liga.equipos(t);
    List<String> lesionados(String f) => [
      for (final e in t.lesiones.entries)
        if (equipos[e.key] == f)
          if (liga.jugador(e.key) case final j? when j.media >= 80) j.nombre,
    ];
    final rn = nombre(rivalId);
    final propios = rec(u);
    return ContextoNarrativo(
      usuarioId: u,
      rivalId: rivalId,
      rivalNombre: rn,
      rachaPropia: Historias.rachaDe(t, u),
      rachaRival: Historias.rachaDe(t, rivalId),
      recordPropio: propios,
      recordRival: rec(rivalId),
      rivalidad: MalaSangre.relato(rivalidades, t, rivalId, rn, numeroActual: numeroActual),
      recordsEnJuego: [for (final r in hist.recordsEnJuego(t, liga)) r.texto],
      presion: serie == null ? null : presionDeSerie(serie, u),
      invicto: propios.$2 == 0 && propios.$1 > 0,
      lesionesRival: lesionados(rivalId),
      lesionesPropias: lesionados(u),
    );
  }
}
