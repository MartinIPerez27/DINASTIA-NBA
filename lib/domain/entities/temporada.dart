import 'franquicia.dart';
import 'jugador.dart';
import 'partido.dart';
import 'plantel.dart';
import '../motor.dart';
import 'oferta.dart';
import 'rival.dart';
import 'tactica.dart';
import 'tirada.dart';

/// Fila de la tabla de posiciones (Standings).
class RegistroEquipo {
  const RegistroEquipo(this.franquiciaId, this.victorias, this.derrotas);

  final String franquiciaId;
  final int victorias;
  final int derrotas;

  int get jugados => victorias + derrotas;
  double get porcentaje => jugados == 0 ? 0 : victorias / jugados;
}

enum RondaPlayoff {
  primeraRonda('1ª Ronda de Conferencia'),
  semifinalConferencia('Semifinales de Conferencia'),
  finalConferencia('Finales de Conferencia'),
  finalesNba('Las Finales de la NBA');

  const RondaPlayoff(this.etiqueta);
  final String etiqueta;
}

/// Serie al mejor de 7 (GDD §7). [altoId] es la mejor siembra y tiene la ventaja de localía.
class SeriePlayoff {
  const SeriePlayoff({
    required this.ronda,
    required this.altoId,
    required this.bajoId,
    this.victoriasAlto = 0,
    this.victoriasBajo = 0,
  });

  static const victoriasParaGanar = 4;

  final RondaPlayoff ronda;
  final String altoId;
  final String bajoId;
  final int victoriasAlto;
  final int victoriasBajo;

  bool get terminada => victoriasAlto == victoriasParaGanar || victoriasBajo == victoriasParaGanar;

  String? get ganadorId => !terminada
      ? null
      : victoriasAlto == victoriasParaGanar
      ? altoId
      : bajoId;

  /// Formato 2-2-1-1-1: el mejor sembrado es local en los partidos 1, 2, 5 y 7.
  String get localProximoPartido => const {0, 1, 4, 6}.contains(victoriasAlto + victoriasBajo) ? altoId : bajoId;

  SeriePlayoff registrarVictoria(String franquiciaId) {
    if (terminada) throw StateError('La serie ya terminó.');
    if (franquiciaId != altoId && franquiciaId != bajoId) {
      throw ArgumentError('$franquiciaId no juega esta serie.');
    }
    final ganaAlto = franquiciaId == altoId;
    return SeriePlayoff(
      ronda: ronda,
      altoId: altoId,
      bajoId: bajoId,
      victoriasAlto: victoriasAlto + (ganaAlto ? 1 : 0),
      victoriasBajo: victoriasBajo + (ganaAlto ? 0 : 1),
    );
  }

  factory SeriePlayoff.fromJson(Map<String, dynamic> j) => SeriePlayoff(
    ronda: RondaPlayoff.values.byName(j['ronda'] as String),
    altoId: j['alto'] as String,
    bajoId: j['bajo'] as String,
    victoriasAlto: j['victoriasAlto'] as int,
    victoriasBajo: j['victoriasBajo'] as int,
  );

  Map<String, dynamic> toJson() => {
    'ronda': ronda.name,
    'alto': altoId,
    'bajo': bajoId,
    'victoriasAlto': victoriasAlto,
    'victoriasBajo': victoriasBajo,
  };
}

/// Qué tan fuertes son los rivales (se elige al empezar la partida).
enum Dificultad {
  normal('Normal', 'Rivales a la altura de un buen draft: con un gran plantel, el 82-0 está a tiro.', 79),
  dificil('Difícil', 'Rivales con muchas figuras. Cada victoria cuesta.', 82),
  leyenda('Leyenda', 'Cada rival es lo mejor de su historia o de su época. El 82-0 es una hazaña.', null);

  const Dificultad(this.nombre, this.descripcion, this.mediaRivales);
  final String nombre;
  final String descripcion;

  /// Media a la que apuntan los planteles rivales (null: lo mejor que tenga cada franquicia).
  final int? mediaRivales;
}

/// Reglas especiales del draft (modos de draft). Algunas solo existen en el modo Cartas.
enum ReglaDraft {
  libre('Libre', 'Todo el catálogo, como siempre.'),
  unaDecada('Una sola década', 'Todos los jugadores salen de la misma época.'),
  franquiciaPura('Franquicia pura', 'Solo jugadores que pasaron por tu franquicia.'),
  underdog('Underdog', 'Sin leyendas: solo cartas A y B.'),
  aCiegas('A ciegas', 'Las 5 cartas vienen boca abajo: elegís sin verlas.', soloCartas: true),
  serpiente('Draft en serpiente', 'Los rivales también eligen, y a veces antes que vos.', soloCartas: true),
  coleccion('Mi colección', 'Solo con las cartas de tu álbum.');

  const ReglaDraft(this.nombre, this.descripcion, {this.soloCartas = false});
  final String nombre;
  final String descripcion;
  final bool soloCartas;
}

enum FaseTemporada { draft, tacticas, temporadaRegular, playoffs, finalizada }

/// Partida guardada: todo lo que el usuario construyó y jugó en una temporada.
class Temporada {
  const Temporada({
    required this.id,
    required this.franquiciaUsuarioId,
    this.plantel = const Plantel(),
    this.tactica = const Tactica(),
    this.rerollsRestantes = rerollsPorTemporada,
    this.calendario = const [],
    this.series = const [],
    this.tirada,
    this.tacticaConfirmada = false,
    this.modo = ModoDraft.ruleta,
    this.oferta,
    this.rivales = const {},
    this.lineas = const {},
    this.lineasPlayoffs = const {},
    this.dificultad = Dificultad.normal,
    this.regla = ReglaDraft.libre,
    this.epocaRegla,
    this.robos = const {},
    this.entrenadorId,
    this.forma = const {},
  });

  static const rerollsPorTemporada = 3;
  static const partidosTemporadaRegular = 82;
  static const clasificadosPorConferencia = 8;

  final String id;
  final String franquiciaUsuarioId;
  final Plantel plantel;
  final Tactica tactica;
  final int rerollsRestantes;
  final List<Partido> calendario;
  final List<SeriePlayoff> series;

  /// Tirada del tragamonedas pendiente de elegir carta (null si no hay).
  final Tirada? tirada;

  /// El usuario ya eligió su playbook (Fase 4); se puede seguir cambiando durante la temporada.
  final bool tacticaConfirmada;

  final ModoDraft modo;

  /// Modo cartas: las 5 cartas repartidas para un puesto, pendientes de elegir.
  final Oferta? oferta;

  /// Planteles de las otras 29 franquicias esta temporada.
  final Map<String, Rival> rivales;

  /// Estadísticas de la temporada regular de todos los jugadores de la liga (por id de carta).
  final Map<String, LineaEstadistica> lineas;

  /// Estadísticas de los playoffs (por id de carta).
  final Map<String, LineaEstadistica> lineasPlayoffs;

  final Dificultad dificultad;

  final ReglaDraft regla;

  /// Década elegida con la regla [ReglaDraft.unaDecada].
  final Epoca? epocaRegla;

  /// Draft en serpiente: cartas que se llevó cada rival (franquicia → ids de carta).
  final Map<String, List<String>> robos;

  /// Carta de entrenador (7.º puesto), si ya se eligió.
  final String? entrenadorId;

  /// Forma de cada carta en la temporada (−3 a +3): suma a su media mientras dure la racha.
  final Map<String, int> forma;

  /// Ganador de Las Finales (null mientras se juegan).
  String? get campeonId {
    for (final s in series) {
      if (s.ronda == RondaPlayoff.finalesNba) return s.ganadorId;
    }
    return null;
  }

  /// La serie del usuario que todavía se está jugando (null si quedó afuera o ya terminó todo).
  SeriePlayoff? get serieDelUsuario {
    for (final s in series) {
      if (!s.terminada && (s.altoId == franquiciaUsuarioId || s.bajoId == franquiciaUsuarioId)) return s;
    }
    return null;
  }

  /// La serie en la que el usuario quedó eliminado (null si sigue vivo o no clasificó).
  SeriePlayoff? get eliminacion {
    for (final s in series) {
      if (s.terminada && (s.altoId == franquiciaUsuarioId || s.bajoId == franquiciaUsuarioId)) {
        if (s.ganadorId != franquiciaUsuarioId) return s;
      }
    }
    return null;
  }

  FaseTemporada get fase {
    if (!plantel.completo) return FaseTemporada.draft;
    if (!tacticaConfirmada) return FaseTemporada.tacticas;
    if (calendario.isEmpty || calendario.any((p) => !p.jugado)) {
      return FaseTemporada.temporadaRegular;
    }
    final finales = series.where((s) => s.ronda == RondaPlayoff.finalesNba);
    if (finales.isNotEmpty && finales.first.terminada) return FaseTemporada.finalizada;
    return FaseTemporada.playoffs;
  }

  RegistroEquipo registroDe(String franquiciaId) {
    var v = 0, d = 0;
    for (final p in calendario) {
      if (!p.jugado || !p.participa(franquiciaId)) continue;
      p.ganadorId == franquiciaId ? v++ : d++;
    }
    return RegistroEquipo(franquiciaId, v, d);
  }

  RegistroEquipo get registroUsuario => registroDe(franquiciaUsuarioId);

  /// La Hazaña Inmortal: 82-0.
  bool get esTemporadaPerfecta => registroUsuario.victorias == partidosTemporadaRegular;

  /// Tabla de una conferencia ordenada por % de victorias (desempate: más victorias).
  List<RegistroEquipo> standings(Conferencia conf, Iterable<Franquicia> franquicias) {
    final tabla = [
      for (final f in franquicias)
        if (f.conferencia == conf) registroDe(f.id),
    ];
    tabla.sort((a, b) {
      final c = b.porcentaje.compareTo(a.porcentaje);
      return c != 0 ? c : b.victorias.compareTo(a.victorias);
    });
    return tabla;
  }

  Temporada usarReroll() {
    if (rerollsRestantes <= 0) throw StateError('No quedan fichas de Reroll.');
    return copyWith(rerollsRestantes: rerollsRestantes - 1);
  }

  Temporada copyWith({
    Plantel? plantel,
    Tactica? tactica,
    int? rerollsRestantes,
    List<Partido>? calendario,
    List<SeriePlayoff>? series,
    bool? tacticaConfirmada,
    Map<String, Rival>? rivales,
    Map<String, LineaEstadistica>? lineas,
    Map<String, LineaEstadistica>? lineasPlayoffs,
    Map<String, List<String>>? robos,
    String? entrenadorId,
    Map<String, int>? forma,
  }) => Temporada(
    id: id,
    franquiciaUsuarioId: franquiciaUsuarioId,
    plantel: plantel ?? this.plantel,
    tactica: tactica ?? this.tactica,
    rerollsRestantes: rerollsRestantes ?? this.rerollsRestantes,
    calendario: calendario == null ? this.calendario : List.unmodifiable(calendario),
    series: series == null ? this.series : List.unmodifiable(series),
    tirada: tirada,
    tacticaConfirmada: tacticaConfirmada ?? this.tacticaConfirmada,
    modo: modo,
    oferta: oferta,
    rivales: rivales ?? this.rivales,
    lineas: lineas ?? this.lineas,
    lineasPlayoffs: lineasPlayoffs ?? this.lineasPlayoffs,
    dificultad: dificultad,
    regla: regla,
    epocaRegla: epocaRegla,
    robos: robos ?? this.robos,
    entrenadorId: entrenadorId ?? this.entrenadorId,
    forma: forma ?? this.forma,
  );

  Temporada conTirada(Tirada? nueva) => _con(tirada: nueva, oferta: oferta);

  Temporada conOferta(Oferta? nueva) => _con(tirada: tirada, oferta: nueva);

  Temporada _con({required Tirada? tirada, required Oferta? oferta}) => Temporada(
    id: id,
    franquiciaUsuarioId: franquiciaUsuarioId,
    plantel: plantel,
    tactica: tactica,
    rerollsRestantes: rerollsRestantes,
    calendario: calendario,
    series: series,
    tirada: tirada,
    tacticaConfirmada: tacticaConfirmada,
    modo: modo,
    oferta: oferta,
    rivales: rivales,
    lineas: lineas,
    lineasPlayoffs: lineasPlayoffs,
    dificultad: dificultad,
    regla: regla,
    epocaRegla: epocaRegla,
    robos: robos,
    entrenadorId: entrenadorId,
    forma: forma,
  );

  factory Temporada.fromJson(Map<String, dynamic> j) => Temporada(
    id: j['id'] as String,
    franquiciaUsuarioId: j['franquiciaUsuario'] as String,
    plantel: Plantel.fromJson(j['plantel'] as Map<String, dynamic>),
    tactica: Tactica.fromJson(j['tactica'] as Map<String, dynamic>),
    rerollsRestantes: j['rerollsRestantes'] as int,
    calendario: List.unmodifiable([
      for (final p in j['calendario'] as List) Partido.fromJson(p as Map<String, dynamic>),
    ]),
    series: List.unmodifiable([for (final s in j['series'] as List) SeriePlayoff.fromJson(s as Map<String, dynamic>)]),
    tirada: j['tirada'] == null ? null : Tirada.fromJson(j['tirada'] as Map<String, dynamic>),
    tacticaConfirmada: j['tacticaConfirmada'] as bool? ?? false,
    modo: ModoDraft.values.byName(j['modo'] as String? ?? 'ruleta'),
    oferta: j['oferta'] == null ? null : Oferta.fromJson(j['oferta'] as Map<String, dynamic>),
    rivales: {
      for (final e in (j['rivales'] as Map<String, dynamic>? ?? {}).entries)
        e.key: Rival.fromJson(e.value as Map<String, dynamic>),
    },
    lineas: {
      for (final e in (j['lineas'] as Map<String, dynamic>? ?? {}).entries)
        e.key: LineaEstadistica.fromJson(e.value as Map<String, dynamic>),
    },
    lineasPlayoffs: {
      for (final e in (j['lineasPlayoffs'] as Map<String, dynamic>? ?? {}).entries)
        e.key: LineaEstadistica.fromJson(e.value as Map<String, dynamic>),
    },
    // Las partidas de antes del selector se armaron con rivales casi all-time.
    dificultad: Dificultad.values.byName(j['dificultad'] as String? ?? 'leyenda'),
    regla: ReglaDraft.values.byName(j['regla'] as String? ?? 'libre'),
    epocaRegla: j['epocaRegla'] == null ? null : Epoca.values.byName(j['epocaRegla'] as String),
    robos: {
      for (final e in (j['robos'] as Map<String, dynamic>? ?? {}).entries) e.key: (e.value as List).cast<String>(),
    },
    entrenadorId: j['entrenador'] as String?,
    forma: (j['forma'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v as int)),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'franquiciaUsuario': franquiciaUsuarioId,
    'plantel': plantel.toJson(),
    'tactica': tactica.toJson(),
    'rerollsRestantes': rerollsRestantes,
    'calendario': [for (final p in calendario) p.toJson()],
    'series': [for (final s in series) s.toJson()],
    if (tirada != null) 'tirada': tirada!.toJson(),
    'tacticaConfirmada': tacticaConfirmada,
    'modo': modo.name,
    'dificultad': dificultad.name,
    'regla': regla.name,
    if (epocaRegla != null) 'epocaRegla': epocaRegla!.name,
    if (robos.isNotEmpty) 'robos': robos,
    if (entrenadorId != null) 'entrenador': entrenadorId,
    if (forma.isNotEmpty) 'forma': forma,
    if (oferta != null) 'oferta': oferta!.toJson(),
    if (rivales.isNotEmpty) 'rivales': {for (final e in rivales.entries) e.key: e.value.toJson()},
    if (lineas.isNotEmpty) 'lineas': {for (final e in lineas.entries) e.key: e.value.toJson()},
    if (lineasPlayoffs.isNotEmpty) 'lineasPlayoffs': {for (final e in lineasPlayoffs.entries) e.key: e.value.toJson()},
  };
}
