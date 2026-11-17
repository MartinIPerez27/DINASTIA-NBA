import '../entities/jugador.dart';

/// Los dos personajes de la transmisión (propios, sin personas reales).
enum Personaje {
  /// Español neutro y técnico: canta la jugada, da datos, reloj, rotaciones y táctica.
  relator('Relator'),

  /// Color rioplatense: humor, asombro, temperatura del partido.
  comentarista('Comentarista');

  const Personaje(this.nombre);
  final String nombre;
}

/// Todas las situaciones que el relato sabe contar. Las primeras salen de una jugada del motor; las
/// de [contextual] salen del contexto (rachas, récords, momento del partido, temporada).
enum Situacion {
  // Tiros
  doble,
  dobleAsistido,
  contraataque,
  canastaYFalta,
  triple,
  tripleCierre,
  volcada,
  alleyOop,
  tapon,
  taponRecuperado,
  reboteOfensivo,
  ladrillo,
  aro,
  tiroDesesperado,
  chicharraLejana,
  chicharra,
  interferencia,
  // Libres
  libresPerfectos,
  libresParciales,
  libresFallados,
  lineaDeSuspiros,
  // Pérdidas
  robo,
  perdidaAfuera,
  perdida24,
  perdida3s,
  campoAtras,
  pasos,
  dobles,
  carga,
  // Faltas
  faltaPersonal,
  bonus,
  tecnica,
  flagrante,
  intencional,
  // Gestión del partido
  salto,
  cambio,
  cambioFaltas,
  cambioExpulsion,
  expulsion,
  tiempoMuerto,
  tiempoMuertoParcial,
  finCuarto,
  entretiempo,
  prorroga,
  finPartido,
  // Contexto
  parcialAFavor,
  parcialEnContra,
  remontada,
  finalApretado,
  rachaTirador,
  jugadorDominante,
  dobleDoble,
  tripleDoble,
  anotadorAlto,
  partidoParejo,
  partidoPicado,
  playoffs,
  eliminacion,
  clutch,
  apertura,
  arranque,
  historial,
  serie,
  localia,
  record,
  rivalidad,
  recordEnJuego,
  historiaTemporada,
  fatiga,
  tramite,
  retoma,
  ritmoAlto,
  ritmoBajo;

  /// ¿Sale del contexto del partido y no de una jugada concreta?
  bool get contextual => index >= Situacion.parcialAFavor.index;
}

/// Una línea de la transmisión: quién habla, qué dice y con cuánta emoción (0 mesurado … 4 épico).
class LineaRelato {
  const LineaRelato(this.personaje, this.texto, this.intensidad, this.situacion);

  final Personaje personaje;
  final String texto;
  final int intensidad;
  final Situacion situacion;

  @override
  String toString() => '${personaje.nombre}: $texto';
}

/// Todo lo que el relato puede saber del partido además de la jugada. Todos los campos son opcionales:
/// quien tenga más datos (historias, rivalidades, récords) los completa sin romper nada.
class ContextoRelato {
  const ContextoRelato({
    this.jugadores = const {},
    this.nombreLocal,
    this.nombreVisitante,
    this.ciudadLocal,
    this.ciudadVisitante,
    this.usuarioLocal,
    this.playoffs = false,
    this.ronda,
    this.juegoSerie,
    this.victoriasLocalSerie,
    this.victoriasVisitanteSerie,
    this.victoriasParaGanar = 4,
    this.victorias,
    this.derrotas,
    this.rachaVictorias,
    this.historialVictorias,
    this.historialDerrotas,
    this.ultimoResultado,
    this.energiaDe,
    this.lesionados = const {},
    this.ritmoAlto,
    this.rivalidad,
    this.recordEnJuego,
    this.historia,
  });

  /// Todos los jugadores del partido por id de carta.
  final Map<String, Jugador> jugadores;

  /// Apodo y ciudad de cada equipo ("Bulls", "Chicago").
  final String? nombreLocal, nombreVisitante, ciudadLocal, ciudadVisitante;

  /// ¿El usuario dirige al local? (null si no hay usuario: partido entre máquinas).
  final bool? usuarioLocal;

  /// Playoffs: ronda ("Semifinales del Este"), juego N de la serie y victorias de cada uno.
  final bool playoffs;
  final String? ronda;
  final int? juegoSerie, victoriasLocalSerie, victoriasVisitanteSerie;
  final int victoriasParaGanar;

  /// Récord del usuario y racha (positiva: victorias seguidas; negativa: derrotas).
  final int? victorias, derrotas, rachaVictorias;

  /// Lo que lleva el usuario contra este rival en la temporada y cómo fue el último cruce
  /// (p. ej. "104-99 a favor").
  final int? historialVictorias, historialDerrotas;
  final String? ultimoResultado;

  /// Energía (0-100) de un jugador, para notar el cansancio, y los lesionados que no juegan.
  final double? Function(String id)? energiaDe;
  final Set<String> lesionados;

  /// ¿El partido viene a ritmo alto (true) o lento (false)? null: no se sabe.
  final bool? ritmoAlto;

  /// Ganchos para otras funciones: una frase suelta de rivalidad ("el clásico del Medio Oeste"),
  /// un récord que se juega esta noche ("a 12 puntos del máximo de la temporada") y un hecho de la
  /// historia de la temporada. Se usan tal cual, por eso van en minúscula inicial y sin punto final.
  final String? rivalidad, recordEnJuego, historia;

  /// Copia que completa con [jugadores], los nombres, las ciudades, [usuarioLocal] y [energiaDe] lo que
  /// este contexto no trae (lo que ya trae, queda).
  ContextoRelato conBase({
    Map<String, Jugador>? jugadores,
    String? nombreLocal,
    String? nombreVisitante,
    String? ciudadLocal,
    String? ciudadVisitante,
    bool? usuarioLocal,
    double? Function(String id)? energiaDe,
  }) => ContextoRelato(
    jugadores: this.jugadores.isNotEmpty ? this.jugadores : (jugadores ?? const {}),
    nombreLocal: this.nombreLocal ?? nombreLocal,
    nombreVisitante: this.nombreVisitante ?? nombreVisitante,
    ciudadLocal: this.ciudadLocal ?? ciudadLocal,
    ciudadVisitante: this.ciudadVisitante ?? ciudadVisitante,
    usuarioLocal: this.usuarioLocal ?? usuarioLocal,
    playoffs: playoffs,
    ronda: ronda,
    juegoSerie: juegoSerie,
    victoriasLocalSerie: victoriasLocalSerie,
    victoriasVisitanteSerie: victoriasVisitanteSerie,
    victoriasParaGanar: victoriasParaGanar,
    victorias: victorias,
    derrotas: derrotas,
    rachaVictorias: rachaVictorias,
    historialVictorias: historialVictorias,
    historialDerrotas: historialDerrotas,
    ultimoResultado: ultimoResultado,
    energiaDe: this.energiaDe ?? energiaDe,
    lesionados: lesionados,
    ritmoAlto: ritmoAlto,
    rivalidad: rivalidad,
    recordEnJuego: recordEnJuego,
    historia: historia,
  );

  /// Alguna serie de playoffs puede cerrarse hoy (el que está a una victoria de ganar o perder).
  bool get noHayManana {
    if (!playoffs) return false;
    final g = victoriasParaGanar;
    final l = victoriasLocalSerie, v = victoriasVisitanteSerie;
    if (g <= 1) return true;
    return (l != null && l == g - 1) || (v != null && v == g - 1);
  }

  /// "la serie está 2-1 a favor de Bulls" (o null si no se sabe).
  String? get textoSerie {
    final l = victoriasLocalSerie, v = victoriasVisitanteSerie;
    if (!playoffs || l == null || v == null) return null;
    final nl = nombreLocal ?? 'el local', nv = nombreVisitante ?? 'el visitante';
    if (l == v) return 'la serie está igualada $l-$v';
    return l > v ? 'la serie está $l-$v a favor de $nl' : 'la serie está $v-$l a favor de $nv';
  }

  String? get nombreUsuario => usuarioLocal == null ? null : (usuarioLocal! ? nombreLocal : nombreVisitante);
  String? get nombreRival => usuarioLocal == null ? null : (usuarioLocal! ? nombreVisitante : nombreLocal);
}
