import '../entities/partido.dart';
import '../entities/temporada.dart';
import 'contexto_relato.dart';

/// Arma el contexto del relato con lo que sabe la temporada: récord, racha, historial contra el rival
/// y, en playoffs, la ronda, el juego y la ventaja de la serie. Lo demás (nombres, jugadores) lo completa
/// la pantalla del partido.
ContextoRelato contextoDeTemporada(Temporada t, Partido p, {SeriePlayoff? serie}) {
  final yo = t.franquiciaUsuarioId;
  final rivalId = p.localId == yo ? p.visitanteId : p.localId;
  final reg = t.registroUsuario;

  // Racha: resultados seguidos del usuario, del más reciente hacia atrás.
  var racha = 0;
  final jugados = [
    for (final x in t.calendario)
      if (x.jugado && x.participa(yo)) x,
  ];
  for (final x in jugados.reversed) {
    final gano = x.ganadorId == yo;
    if (racha == 0) {
      racha = gano ? 1 : -1;
    } else if ((racha > 0) == gano) {
      racha += gano ? 1 : -1;
    } else {
      break;
    }
  }

  var hv = 0, hd = 0;
  String? ultimo;
  if (t.rivales.containsKey(rivalId) || rivalId.isNotEmpty) {
    final (v, d, partidos) = t.historialContra(rivalId);
    hv = v;
    hd = d;
    final previos = partidos.where((x) => x.jugado).toList();
    if (previos.isNotEmpty) {
      final u = previos.last;
      final propios = u.localId == yo ? u.puntosLocal : u.puntosVisitante;
      final ajenos = u.localId == yo ? u.puntosVisitante : u.puntosLocal;
      ultimo = propios > ajenos ? '$propios-$ajenos a favor' : '$ajenos-$propios en contra';
    }
  }

  return ContextoRelato(
    victorias: reg.victorias,
    derrotas: reg.derrotas,
    rachaVictorias: racha == 0 ? null : racha,
    historialVictorias: hv,
    historialDerrotas: hd,
    ultimoResultado: ultimo,
    playoffs: serie != null && !serie.ronda.esCopa,
    ronda: serie?.ronda.etiqueta,
    juegoSerie: serie == null ? null : serie.victoriasAlto + serie.victoriasBajo + 1,
    victoriasLocalSerie: serie == null ? null : (p.localId == serie.altoId ? serie.victoriasAlto : serie.victoriasBajo),
    victoriasVisitanteSerie: serie == null
        ? null
        : (p.localId == serie.altoId ? serie.victoriasBajo : serie.victoriasAlto),
    victoriasParaGanar: serie?.victoriasParaGanar ?? 4,
  );
}
