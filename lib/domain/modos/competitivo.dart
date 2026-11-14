import 'dart:math';

import '../entities/franquicia.dart';
import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/perfil.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/temporada.dart';
import '../liga.dart';
import '../motor.dart';
import '../playbook.dart';
import '../progreso.dart' show Novedad;
import 'escalera.dart';

/// Divisiones, Conquista y Creador de torneos: modos que juegan con cartas de tu álbum (las
/// evoluciones de cartas valen acá). Cada uno guarda todo su estado en [Temporada.datosModo].

/// Punto de enganche de las evoluciones de cartas del álbum: devuelve la carta como juega en estos
/// modos. Hoy es la carta tal cual; las evoluciones lo reemplazan.
Jugador cartaDeAlbum(Jugador j) => j;

/// Media de una carta tal como juega en estos modos.
int mediaDe(Jugador j) => cartaDeAlbum(j).media;

bool esPartidaCompetitiva(ModoJuego m) =>
    m == ModoJuego.divisiones || m == ModoJuego.creadorTorneos || m == ModoJuego.conquista;

/// Los 6 puestos con la carta (por id) de cada uno.
typedef Alineacion = Map<Posicion, String>;

Map<String, dynamic> alineacionAJson(Alineacion a) => {for (final e in a.entries) e.key.name: e.value};

Alineacion alineacionDeJson(Map<String, dynamic> j) => {
  for (final e in j.entries) Posicion.values.byName(e.key): e.value as String,
};

Alineacion alineacionDePlantel(Plantel p) => {
  for (final pos in Posicion.values)
    if (p.en(pos) != null) pos: p.en(pos)!.id,
};

(int, int) _par(Object? v) => ((v as List)[0] as int, v[1] as int);

// ═════════════════════════════════════════ Divisiones ═══════════════════════════════════════════

enum MovimientoDivision {
  asciende('ASCENSO'),
  mantiene('TE QUEDÁS'),
  desciende('DESCENSO');

  const MovimientoDivision(this.etiqueta);
  final String etiqueta;
}

/// Cómo terminó una temporada de división.
class CierreDivision {
  const CierreDivision(this.division, this.puntos, this.movimiento);

  final int division, puntos;
  final MovimientoDivision movimiento;

  factory CierreDivision.fromJson(Map<String, dynamic> j) =>
      CierreDivision(j['d'] as int, j['p'] as int, MovimientoDivision.values.byName(j['m'] as String));

  Map<String, dynamic> toJson() => {'d': division, 'p': puntos, 'm': movimiento.name};
}

class EstadoDivisiones {
  const EstadoDivisiones({
    this.cartas = const {},
    this.division = ultimaDivision,
    this.rivales = const [],
    this.marcadores = const [],
    this.temporada = 1,
    this.victorias = 0,
    this.derrotas = 0,
    this.titulos = 0,
    this.llegoA1 = false,
    this.historial = const [],
  });

  /// Diez divisiones: la 10 es la de abajo y la 1, la élite.
  static const ultimaDivision = 10;
  static const partidosPorTemporada = 10;

  /// Con estos puntos (o más) ascendés; con estos (o menos) descendés.
  static const umbralAscenso = 21, umbralDescenso = 9;

  final Alineacion cartas;
  final int division;

  /// Los rivales de esta temporada de división, en orden.
  final List<RivalEscalera> rivales;

  /// Tus resultados de esta temporada: (tus puntos, los del rival).
  final List<(int, int)> marcadores;
  final int temporada;

  /// Totales de toda la partida (para las recompensas).
  final int victorias, derrotas;

  /// Temporadas ganadas en la División 1.
  final int titulos;
  final bool llegoA1;
  final List<CierreDivision> historial;

  /// 3 por victoria, 4 si fue paliza (15 o más de diferencia); 0 si perdés.
  static int puntosPartido(int mios, int suyos) => mios > suyos ? (mios - suyos >= 15 ? 4 : 3) : 0;

  /// Qué pasa al terminar una temporada: (división nueva, movimiento).
  static (int, MovimientoDivision) cierre(int division, int puntos) {
    if (puntos >= umbralAscenso) {
      return division == 1 ? (1, MovimientoDivision.mantiene) : (division - 1, MovimientoDivision.asciende);
    }
    if (puntos <= umbralDescenso && division < ultimaDivision) {
      return (division + 1, MovimientoDivision.desciende);
    }
    return (division, MovimientoDivision.mantiene);
  }

  /// Media objetivo de los rivales de una división.
  static int objetivo(int division, Dificultad d) => min(
    95,
    68 +
        ((ultimaDivision - division) * 2.6).round() +
        switch (d) {
          Dificultad.normal => 0,
          Dificultad.dificil => 2,
          Dificultad.leyenda => 4,
        },
  );

  int get puntos => marcadores.fold(0, (a, m) => a + puntosPartido(m.$1, m.$2));
  bool get temporadaTerminada => marcadores.length >= partidosPorTemporada;
  RivalEscalera? get pendiente =>
      temporadaTerminada || marcadores.length >= rivales.length ? null : rivales[marcadores.length];
  bool get localProximo => marcadores.length.isEven;
  int get ganadosTemporada => marcadores.where((m) => m.$1 > m.$2).length;

  /// ¿Esta temporada terminó con puntos de ascenso en la División 1 (título de la élite)?
  bool get tituloDeLaElite => temporadaTerminada && division == 1 && puntos >= umbralAscenso;

  EstadoDivisiones copyWith({
    Alineacion? cartas,
    int? division,
    List<RivalEscalera>? rivales,
    List<(int, int)>? marcadores,
    int? temporada,
    int? victorias,
    int? derrotas,
    int? titulos,
    bool? llegoA1,
    List<CierreDivision>? historial,
  }) => EstadoDivisiones(
    cartas: cartas ?? this.cartas,
    division: division ?? this.division,
    rivales: rivales ?? this.rivales,
    marcadores: marcadores ?? this.marcadores,
    temporada: temporada ?? this.temporada,
    victorias: victorias ?? this.victorias,
    derrotas: derrotas ?? this.derrotas,
    titulos: titulos ?? this.titulos,
    llegoA1: llegoA1 ?? this.llegoA1,
    historial: historial ?? this.historial,
  );

  factory EstadoDivisiones.fromJson(Map<String, dynamic> j) => EstadoDivisiones(
    cartas: alineacionDeJson((j['cartas'] as Map).cast<String, dynamic>()),
    division: j['division'] as int,
    rivales: [for (final r in j['rivales'] as List) RivalEscalera.fromJson((r as Map).cast<String, dynamic>())],
    marcadores: [for (final m in j['marcadores'] as List) _par(m)],
    temporada: j['temporada'] as int,
    victorias: j['v'] as int,
    derrotas: j['d'] as int,
    titulos: j['titulos'] as int,
    llegoA1: j['llegoA1'] as bool,
    historial: [for (final h in j['historial'] as List) CierreDivision.fromJson((h as Map).cast<String, dynamic>())],
  );

  Map<String, dynamic> toJson() => {
    'cartas': alineacionAJson(cartas),
    'division': division,
    'rivales': [for (final r in rivales) r.toJson()],
    'marcadores': [
      for (final (a, b) in marcadores) [a, b],
    ],
    'temporada': temporada,
    'v': victorias,
    'd': derrotas,
    'titulos': titulos,
    'llegoA1': llegoA1,
    'historial': [for (final h in historial) h.toJson()],
  };

  static EstadoDivisiones? de(Temporada t) =>
      t.modoJuego != ModoJuego.divisiones || t.datosModo.isEmpty ? null : EstadoDivisiones.fromJson(t.datosModo);

  Temporada en(Temporada t) => t.copyWith(datosModo: toJson());
}

// ═════════════════════════════════════════ Conquista ════════════════════════════════════════════

/// Dónde está cada franquicia en el tablero (columna, fila): el Oeste a la izquierda, el Este a la
/// derecha y el norte arriba. Es un tablero estilizado, no un mapa geográfico.
const mapaConquista = <String, (int, int)>{
  'POR': (1, 0), 'MIN': (4, 0), 'MIL': (5, 0), 'DET': (6, 0), 'TOR': (7, 0), 'BOS': (9, 0), //
  'SAC': (0, 1), 'UTA': (2, 1), 'DEN': (3, 1), 'CHI': (5, 1), 'CLE': (6, 1), 'NYK': (8, 1), 'BKN': (9, 1),
  'GSW': (0, 2), 'LAC': (1, 2), 'PHX': (2, 2), 'OKC': (4, 2), 'IND': (5, 2), 'WAS': (7, 2), 'PHI': (8, 2),
  'LAL': (0, 3), 'SAS': (3, 3), 'DAL': (4, 3), 'MEM': (5, 3), 'ATL': (6, 3), 'CHA': (7, 3),
  'HOU': (4, 4), 'NOP': (5, 4), 'ORL': (7, 4), 'MIA': (8, 4),
};

const columnasMapa = 10, filasMapa = 5;

/// Territorios pegados al de [id] (en las ocho direcciones del tablero).
List<String> vecinosConquista(String id) {
  final (c, f) = mapaConquista[id]!;
  return [
    for (final e in mapaConquista.entries)
      if (e.key != id && (e.value.$1 - c).abs() <= 1 && (e.value.$2 - f).abs() <= 1) e.key,
  ];
}

/// Ventaja por dominar una división de la NBA: con 3 territorios de sus 5, +1 a esos puestos; con
/// los 5, +2.
class VentajaConquista {
  const VentajaConquista(this.division, this.nombre, this.puestos);

  final Division division;
  final String nombre;
  final List<Posicion> puestos;

  String get descripcion =>
      '+1 de forma a ${puestos.map((p) => p.etiqueta.toLowerCase()).join(' y ')} '
      '(+2 con las cinco ${division.etiqueta})';
}

const ventajasConquista = <VentajaConquista>[
  VentajaConquista(Division.pacifico, 'Costa dorada', [Posicion.base, Posicion.escolta]),
  VentajaConquista(Division.atlantico, 'Costa Este', [Posicion.alero]),
  VentajaConquista(Division.central, 'Corazón industrial', [Posicion.pivot]),
  VentajaConquista(Division.sureste, 'Banco del sur', [Posicion.sextoHombre]),
  VentajaConquista(Division.noroeste, 'Frontera norte', [Posicion.alaPivot]),
  VentajaConquista(Division.suroeste, 'Calor texano', [Posicion.escolta, Posicion.alero]),
];

class EstadoConquista {
  const EstadoConquista({
    this.inicio = '',
    this.conquistados = const [],
    this.cartas = const {},
    this.derrotas = 0,
    this.victorias = 0,
    this.batallas = 0,
    this.objetivo,
    this.rival,
  });

  /// Derrotas que aguantás antes de perder la campaña.
  static const vidas = 8;

  final String inicio;
  final List<String> conquistados;
  final Alineacion cartas;
  final int derrotas, victorias, batallas;

  /// El territorio que estás atacando y su rival (null: todavía no elegiste).
  final String? objetivo;
  final RivalEscalera? rival;

  Set<String> get propios => conquistados.toSet();

  /// Territorios que podés atacar: los vecinos de los tuyos que todavía no son tuyos.
  Set<String> get atacables => {for (final id in conquistados) ...vecinosConquista(id)}.difference(propios);

  bool get completo => conquistados.length >= mapaConquista.length;
  bool get sinVidas => derrotas >= vidas;
  bool get terminada => completo || sinVidas;
  int get vidasRestantes => max(0, vidas - derrotas);
  bool get localProximo => batallas.isEven;

  bool conferenciaCompleta(Conferencia c, List<Franquicia> franquicias) {
    final ids = [
      for (final f in franquicias)
        if (f.conferencia == c && mapaConquista.containsKey(f.id)) f.id,
    ];
    return ids.isNotEmpty && ids.every(propios.contains);
  }

  /// Ventajas activas: (ventaja, nivel 1 o 2).
  List<(VentajaConquista, int)> ventajas(List<Franquicia> franquicias) {
    final res = <(VentajaConquista, int)>[];
    for (final v in ventajasConquista) {
      final ids = [
        for (final f in franquicias)
          if (f.division == v.division) f.id,
      ];
      final tengo = ids.where(propios.contains).length;
      if (tengo >= 3) res.add((v, tengo == ids.length ? 2 : 1));
    }
    return res;
  }

  /// Forma extra por ventajas, por puesto.
  Map<Posicion, int> bonusPorPuesto(List<Franquicia> franquicias) {
    final b = <Posicion, int>{};
    for (final (v, nivel) in ventajas(franquicias)) {
      for (final p in v.puestos) {
        b[p] = (b[p] ?? 0) + nivel;
      }
    }
    return b;
  }

  EstadoConquista copyWith({
    List<String>? conquistados,
    Alineacion? cartas,
    int? derrotas,
    int? victorias,
    int? batallas,
    Object? objetivo = _igual,
    Object? rival = _igual,
  }) => EstadoConquista(
    inicio: inicio,
    conquistados: conquistados ?? this.conquistados,
    cartas: cartas ?? this.cartas,
    derrotas: derrotas ?? this.derrotas,
    victorias: victorias ?? this.victorias,
    batallas: batallas ?? this.batallas,
    objetivo: identical(objetivo, _igual) ? this.objetivo : objetivo as String?,
    rival: identical(rival, _igual) ? this.rival : rival as RivalEscalera?,
  );

  factory EstadoConquista.fromJson(Map<String, dynamic> j) => EstadoConquista(
    inicio: j['inicio'] as String,
    conquistados: (j['conquistados'] as List).cast<String>(),
    cartas: alineacionDeJson((j['cartas'] as Map).cast<String, dynamic>()),
    derrotas: j['derrotas'] as int,
    victorias: j['victorias'] as int,
    batallas: j['batallas'] as int,
    objetivo: j['objetivo'] as String?,
    rival: j['rival'] == null ? null : RivalEscalera.fromJson((j['rival'] as Map).cast<String, dynamic>()),
  );

  Map<String, dynamic> toJson() => {
    'inicio': inicio,
    'conquistados': conquistados,
    'cartas': alineacionAJson(cartas),
    'derrotas': derrotas,
    'victorias': victorias,
    'batallas': batallas,
    if (objetivo != null) 'objetivo': objetivo,
    if (rival != null) 'rival': rival!.toJson(),
  };

  static EstadoConquista? de(Temporada t) =>
      t.modoJuego != ModoJuego.conquista || t.datosModo.isEmpty ? null : EstadoConquista.fromJson(t.datosModo);

  Temporada en(Temporada t) => t.copyWith(datosModo: toJson());
}

const _igual = Object();

// ═══════════════════════════════════════ Creador de torneos ═════════════════════════════════════

enum FormatoTorneo {
  liga('Liga', 'Todos contra todos, una vez. Gana el que más victorias hace.'),
  eliminacion('Eliminación', 'Cuadro de eliminación directa. Perdés y te vas.'),
  grupos('Grupos + eliminación', 'Grupos de todos contra todos; pasan los dos mejores a un cuadro final.');

  const FormatoTorneo(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Un participante del torneo: un plantel armado (cartas por puesto, escudo y tácticas).
class EquipoTorneo {
  const EquipoTorneo({required this.nombre, required this.rival, this.usuario = false});

  final String nombre;
  final RivalEscalera rival;

  /// El tuyo (el que jugás vos). Como mucho uno por torneo.
  final bool usuario;

  double get media => rival.media;

  factory EquipoTorneo.fromJson(Map<String, dynamic> j) => EquipoTorneo(
    nombre: j['nombre'] as String,
    rival: RivalEscalera.fromJson((j['rival'] as Map).cast<String, dynamic>()),
    usuario: j['usuario'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'nombre': nombre, 'rival': rival.toJson(), if (usuario) 'usuario': true};
}

/// Un cruce del cuadro o un partido de liga/grupo: partido único o serie (al mejor de 3, 5 o 7).
class Llave {
  const Llave({
    required this.fase,
    required this.ronda,
    required this.a,
    required this.b,
    this.aGanar = 1,
    this.juegos = const [],
    this.ko = false,
    this.bye = false,
  });

  /// "Liga", "Grupo B", "Semifinales"…
  final String fase;
  final int ronda;

  /// Índices de los equipos; [a] es el local (en el cuadro, el mejor sembrado: tiene la ventaja de localía).
  final int a, b;
  final int aGanar;

  /// Resultados: (puntos de a, puntos de b).
  final List<(int, int)> juegos;
  final bool ko;

  /// Pasa directo a la ronda siguiente (cuadro con equipos de más o de menos).
  final bool bye;

  int get victoriasA => bye ? aGanar : juegos.where((j) => j.$1 > j.$2).length;
  int get victoriasB => juegos.where((j) => j.$2 > j.$1).length;
  bool get terminada => bye || victoriasA >= aGanar || victoriasB >= aGanar;
  int? get ganador => !terminada ? null : (victoriasA >= aGanar ? a : b);
  bool involucra(int i) => !bye && (a == i || b == i);

  /// ¿Es local [a] en el próximo juego? 1-1-1 (al mejor de 3), 2-2-1 (de 5) y 2-2-1-1-1 (de 7).
  bool get aLocalProximo {
    final n = juegos.length;
    return switch (aGanar) {
      1 => true,
      2 => n != 1,
      3 => const {0, 1, 4}.contains(n),
      _ => const {0, 1, 4, 6}.contains(n),
    };
  }

  Llave conJuego(int pa, int pb) =>
      Llave(fase: fase, ronda: ronda, a: a, b: b, aGanar: aGanar, juegos: [...juegos, (pa, pb)], ko: ko, bye: bye);

  factory Llave.fromJson(Map<String, dynamic> j) => Llave(
    fase: j['fase'] as String,
    ronda: j['ronda'] as int,
    a: j['a'] as int,
    b: j['b'] as int,
    aGanar: j['aGanar'] as int? ?? 1,
    juegos: [for (final x in j['juegos'] as List? ?? const []) _par(x)],
    ko: j['ko'] as bool? ?? false,
    bye: j['bye'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'fase': fase,
    'ronda': ronda,
    'a': a,
    'b': b,
    if (aGanar != 1) 'aGanar': aGanar,
    if (juegos.isNotEmpty)
      'juegos': [
        for (final (x, y) in juegos) [x, y],
      ],
    if (ko) 'ko': true,
    if (bye) 'bye': true,
  };
}

/// Una fila de la tabla de una liga o un grupo.
class FilaTorneo {
  const FilaTorneo(this.equipo, this.victorias, this.derrotas, this.diferencia);

  final int equipo, victorias, derrotas, diferencia;
}

/// Resultado de simular un juego entre dos equipos (por índice): (puntos de a, puntos de b); el
/// tercer parámetro dice si [a] juega de local.
typedef SimuladorTorneo = (int, int) Function(int a, int b, bool aLocal);

class Torneo {
  const Torneo({
    required this.nombre,
    required this.formato,
    required this.aGanar,
    required this.equipos,
    required this.llaves,
    this.grupos = const [],
  });

  static const minimoEquipos = 4, maximoEquipos = 32, maximoLiga = 16, minimoGrupos = 6;

  final String nombre;
  final FormatoTorneo formato;

  /// Victorias para ganar cada cruce del cuadro (1: partido único; 2: al mejor de 3…).
  final int aGanar;

  /// Ordenados por media: el índice es la siembra (0 = el mejor).
  final List<EquipoTorneo> equipos;
  final List<Llave> llaves;

  /// Los índices de cada grupo (solo "grupos + eliminación").
  final List<List<int>> grupos;

  /// Por qué no se puede armar un torneo así (null: está bien).
  static String? validar(FormatoTorneo f, int equipos) {
    if (equipos < minimoEquipos) return 'Hacen falta al menos $minimoEquipos equipos.';
    if (equipos > maximoEquipos) return 'Como mucho $maximoEquipos equipos.';
    if (f == FormatoTorneo.liga && equipos > maximoLiga) return 'En una liga, como mucho $maximoLiga equipos.';
    if (f == FormatoTorneo.grupos && equipos < minimoGrupos) return 'Con grupos hacen falta al menos $minimoGrupos.';
    return null;
  }

  int get usuario => equipos.indexWhere((e) => e.usuario);
  bool get conUsuario => usuario >= 0;

  // ── Armado ──

  /// Torneo nuevo: ordena por media (la siembra) y arma los primeros partidos.
  static Torneo crear({
    required String nombre,
    required FormatoTorneo formato,
    required List<EquipoTorneo> equipos,
    int aGanar = 1,
  }) {
    final error = validar(formato, equipos.length);
    if (error != null) throw ArgumentError(error);
    if (equipos.where((e) => e.usuario).length > 1) throw ArgumentError('Solo un equipo puede ser el tuyo.');
    final ordenados = [...equipos]..sort((x, y) => y.media.compareTo(x.media));
    final base = Torneo(nombre: nombre, formato: formato, aGanar: aGanar, equipos: ordenados, llaves: const []);
    final n = ordenados.length;
    switch (formato) {
      case FormatoTorneo.liga:
        return base._con(llaves: _fixture([for (var i = 0; i < n; i++) i], 'Liga'));
      case FormatoTorneo.eliminacion:
        return base._con(llaves: _primeraRondaKO([for (var i = 0; i < n; i++) i], 0, aGanar));
      case FormatoTorneo.grupos:
        final g = max(2, (n / 4).round());
        final repartidos = List.generate(g, (_) => <int>[]);
        for (var i = 0; i < n; i++) {
          // Serpiente: 0..g-1 y después g-1..0, así los grupos quedan parejos.
          final vuelta = i ~/ g;
          repartidos[vuelta.isEven ? i % g : g - 1 - i % g].add(i);
        }
        final llaves = <Llave>[];
        for (final (k, ids) in repartidos.indexed) {
          llaves.addAll(_fixture(ids, 'Grupo ${String.fromCharCode(65 + k)}'));
        }
        return base._con(llaves: llaves, grupos: repartidos);
    }
  }

  Torneo _con({List<Llave>? llaves, List<List<int>>? grupos}) => Torneo(
    nombre: nombre,
    formato: formato,
    aGanar: aGanar,
    equipos: equipos,
    llaves: llaves ?? this.llaves,
    grupos: grupos ?? this.grupos,
  );

  /// Todos contra todos (método del círculo): una lista de partidos por fecha. Con un número impar
  /// de equipos, uno descansa en cada fecha.
  static List<List<(int, int)>> todosContraTodos(List<int> ids) {
    final lista = [...ids];
    if (lista.length.isOdd) lista.add(-1);
    final n = lista.length;
    final fechas = <List<(int, int)>>[];
    for (var r = 0; r < n - 1; r++) {
      final partidos = <(int, int)>[];
      for (var i = 0; i < n ~/ 2; i++) {
        final x = lista[i], y = lista[n - 1 - i];
        if (x == -1 || y == -1) continue;
        // El mejor sembrado (índice menor) es "a"; se alterna para repartir las localías.
        final (m, p) = x < y ? (x, y) : (y, x);
        partidos.add(r.isEven ? (m, p) : (p, m));
      }
      fechas.add(partidos);
      lista.insert(1, lista.removeLast());
    }
    return fechas;
  }

  static List<Llave> _fixture(List<int> ids, String fase) => [
    for (final (r, partidos) in todosContraTodos(ids).indexed)
      for (final (x, y) in partidos) Llave(fase: fase, ronda: r, a: x, b: y),
  ];

  /// Orden de los sembrados en un cuadro de [tam] lugares: el 1 contra el último, el 2 contra el
  /// anteúltimo, y los mejores quedan en mitades opuestas. Ej. 8 → [0, 7, 3, 4, 1, 6, 2, 5].
  static List<int> ordenSiembra(int tam) {
    var orden = [0];
    while (orden.length < tam) {
      final n = orden.length * 2;
      orden = [
        for (final x in orden) ...[x, n - 1 - x],
      ];
    }
    return orden;
  }

  static int _potencia(int n) {
    var p = 2;
    while (p < n) {
      p *= 2;
    }
    return p;
  }

  static String nombreFase(int equipos) => switch (equipos) {
    2 => 'Final',
    4 => 'Semifinales',
    8 => 'Cuartos de final',
    16 => 'Octavos de final',
    32 => '16avos de final',
    _ => 'Ronda de $equipos',
  };

  /// Primera ronda de un cuadro con [sembrados] (mejor primero). Si no son potencia de 2, los
  /// mejores sembrados pasan directo (llave con [Llave.bye]).
  static List<Llave> _primeraRondaKO(List<int> sembrados, int ronda, int aGanar) {
    final tam = _potencia(sembrados.length);
    final lugares = [for (final k in ordenSiembra(tam)) k < sembrados.length ? sembrados[k] : null];
    final fase = nombreFase(tam);
    final res = <Llave>[];
    for (var i = 0; i < lugares.length; i += 2) {
      final x = lugares[i], y = lugares[i + 1];
      if (x != null && y != null) {
        res.add(Llave(fase: fase, ronda: ronda, a: min(x, y), b: max(x, y), aGanar: aGanar, ko: true));
      } else {
        final pasa = (x ?? y)!;
        res.add(Llave(fase: fase, ronda: ronda, a: pasa, b: pasa, ko: true, bye: true));
      }
    }
    return res;
  }

  // ── Consultas ──

  /// La ronda que se está jugando (la primera con partidos sin jugar); null si no queda ninguna.
  int? get rondaActual {
    final pendientes = [
      for (final l in llaves)
        if (!l.terminada) l.ronda,
    ];
    return pendientes.isEmpty ? null : pendientes.reduce(min);
  }

  /// Tu próximo partido (null si no jugás, ya terminaste o te eliminaron).
  Llave? get pendienteUsuario {
    final u = usuario;
    final r = rondaActual;
    if (u < 0 || r == null) return null;
    for (final l in llaves) {
      if (l.ronda == r && !l.terminada && l.involucra(u)) return l;
    }
    return null;
  }

  bool get terminado => llaves.isNotEmpty && llaves.every((l) => l.terminada) && _siguiente() == null;

  /// El campeón (índice de equipo), o null si el torneo sigue.
  int? get campeon {
    if (!terminado) return null;
    if (formato == FormatoTorneo.liga) return tabla(null).first.equipo;
    final ultima = llaves.map((l) => l.ronda).reduce(max);
    return llaves.firstWhere((l) => l.ronda == ultima).ganador;
  }

  /// Tabla de una liga o de un grupo ([fase] null: de todos los partidos de liga/grupo).
  List<FilaTorneo> tabla(String? fase) {
    final v = <int, int>{}, d = <int, int>{}, dif = <int, int>{};
    final ids = <int>{};
    for (final l in llaves) {
      if (l.ko || l.bye || (fase != null && l.fase != fase)) continue;
      ids
        ..add(l.a)
        ..add(l.b);
      if (!l.terminada) continue;
      final (pa, pb) = l.juegos.first;
      final gana = l.ganador!;
      final pierde = gana == l.a ? l.b : l.a;
      v[gana] = (v[gana] ?? 0) + 1;
      d[pierde] = (d[pierde] ?? 0) + 1;
      dif[l.a] = (dif[l.a] ?? 0) + pa - pb;
      dif[l.b] = (dif[l.b] ?? 0) + pb - pa;
    }
    final filas = [for (final i in ids) FilaTorneo(i, v[i] ?? 0, d[i] ?? 0, dif[i] ?? 0)]
      ..sort((x, y) {
        final c = y.victorias.compareTo(x.victorias);
        if (c != 0) return c;
        final c2 = y.diferencia.compareTo(x.diferencia);
        return c2 != 0 ? c2 : x.equipo.compareTo(y.equipo);
      });
    return filas;
  }

  /// Los partidos tuyos ya terminados: (victorias, derrotas).
  (int, int) get recordUsuario {
    final u = usuario;
    if (u < 0) return (0, 0);
    var v = 0, d = 0;
    for (final l in llaves) {
      if (!l.involucra(u)) continue;
      final (mios, suyos) = u == l.a ? (l.victoriasA, l.victoriasB) : (l.victoriasB, l.victoriasA);
      v += mios;
      d += suyos;
    }
    return (v, d);
  }

  // ── Avance ──

  /// Siguiente ronda (o fin de los grupos) cuando la actual terminó; null si el torneo terminó.
  Torneo? _siguiente() {
    if (llaves.isEmpty || formato == FormatoTorneo.liga) return null;
    final ultima = llaves.map((l) => l.ronda).reduce(max);
    final deUltima = [
      for (final l in llaves)
        if (l.ronda == ultima) l,
    ];
    if (!deUltima.every((l) => l.terminada)) return null;
    if (!llaves.any((l) => l.ko)) {
      return _con(llaves: [...llaves, ..._primeraRondaKO(_clasificados(), ultima + 1, aGanar)]);
    }
    if (deUltima.length == 1) return null;
    final ganadores = [for (final l in deUltima) l.ganador!];
    final fase = nombreFase(ganadores.length);
    return _con(
      llaves: [
        ...llaves,
        for (var i = 0; i < ganadores.length; i += 2)
          Llave(
            fase: fase,
            ronda: ultima + 1,
            a: min(ganadores[i], ganadores[i + 1]),
            b: max(ganadores[i], ganadores[i + 1]),
            aGanar: aGanar,
            ko: true,
          ),
      ],
    );
  }

  /// Los dos primeros de cada grupo, ordenados por siembra del cuadro: primero los ganadores de
  /// grupo, después los segundos (cada tanda, por victorias y diferencia).
  List<int> _clasificados() {
    final primeros = <FilaTorneo>[], segundos = <FilaTorneo>[];
    for (var k = 0; k < grupos.length; k++) {
      final t = tabla('Grupo ${String.fromCharCode(65 + k)}');
      primeros.add(t[0]);
      segundos.add(t[1]);
    }
    int cmp(FilaTorneo x, FilaTorneo y) {
      final c = y.victorias.compareTo(x.victorias);
      if (c != 0) return c;
      final c2 = y.diferencia.compareTo(x.diferencia);
      return c2 != 0 ? c2 : x.equipo.compareTo(y.equipo);
    }

    primeros.sort(cmp);
    segundos.sort(cmp);
    return [
      for (final f in [...primeros, ...segundos]) f.equipo,
    ];
  }

  Llave _jugar(Llave l, SimuladorTorneo sim) {
    var x = l;
    while (!x.terminada) {
      final (pa, pb) = sim(x.a, x.b, x.aLocalProximo);
      x = x.conJuego(pa, pb);
    }
    return x;
  }

  /// Hace avanzar el torneo: simula los partidos de los demás (y los tuyos si [incluirUsuario]) de
  /// la ronda actual y arma las rondas siguientes, hasta llegar a un partido tuyo o al final.
  Torneo avanzar(SimuladorTorneo sim, {bool incluirUsuario = false}) {
    // Sin equipo tuyo (espectador) no hay a quién esperar: el torneo avanza por rondas, a pedido.
    if (!conUsuario && !incluirUsuario) return this;
    var t = this;
    for (var vuelta = 0; vuelta < 400; vuelta++) {
      final r = t.rondaActual;
      if (r == null) {
        final n = t._siguiente();
        if (n == null) return t;
        t = n;
        continue;
      }
      final u = t.usuario;
      t = t._con(
        llaves: [
          for (final l in t.llaves)
            if (l.ronda != r || l.terminada || (!incluirUsuario && l.involucra(u))) l else t._jugar(l, sim),
        ],
      );
      if (t.llaves.any((l) => l.ronda == r && !l.terminada)) return t;
    }
    return t;
  }

  /// Juega la ronda actual entera (incluidos tus partidos) y arma la siguiente. Para mirar el torneo
  /// ronda por ronda.
  Torneo jugarRonda(SimuladorTorneo sim) {
    final r = rondaActual;
    if (r == null) return _siguiente() ?? this;
    final t = _con(
      llaves: [
        for (final l in llaves)
          if (l.ronda != r || l.terminada) l else _jugar(l, sim),
      ],
    );
    return t._siguiente() ?? t;
  }

  /// Anota el resultado de tu próximo partido.
  Torneo registrarUsuario(int mios, int suyos) {
    final p = pendienteUsuario;
    if (p == null) return this;
    final u = usuario;
    final (pa, pb) = u == p.a ? (mios, suyos) : (suyos, mios);
    return _con(llaves: [for (final l in llaves) identical(l, p) ? l.conJuego(pa, pb) : l]);
  }

  factory Torneo.fromJson(Map<String, dynamic> j) => Torneo(
    nombre: j['nombre'] as String,
    formato: FormatoTorneo.values.byName(j['formato'] as String),
    aGanar: j['aGanar'] as int,
    equipos: [for (final e in j['equipos'] as List) EquipoTorneo.fromJson((e as Map).cast<String, dynamic>())],
    llaves: [for (final l in j['llaves'] as List) Llave.fromJson((l as Map).cast<String, dynamic>())],
    grupos: [for (final g in j['grupos'] as List? ?? const []) (g as List).cast<int>()],
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'formato': formato.name,
    'aGanar': aGanar,
    'equipos': [for (final e in equipos) e.toJson()],
    'llaves': [for (final l in llaves) l.toJson()],
    if (grupos.isNotEmpty) 'grupos': grupos,
  };

  static Torneo? de(Temporada t) =>
      t.modoJuego != ModoJuego.creadorTorneos || t.datosModo.isEmpty ? null : Torneo.fromJson(t.datosModo);

  Temporada en(Temporada t) => t.copyWith(datosModo: toJson());
}

/// El mejor equipo posible con las cartas de [pool] (los puestos con menos candidatos primero; cada
/// uno, la de más media que pueda jugarlo). [fijas] ya vienen elegidas. Null si no alcanza.
Alineacion? mejorAlineacion(Iterable<Jugador> pool, {Map<Posicion, Jugador> fijas = const {}}) {
  final ordenadas = [...pool]..sort((a, b) => mediaDe(b).compareTo(mediaDe(a)));
  var p = const Plantel();
  for (final e in fijas.entries) {
    p = p.asignar(e.value, e.key);
  }
  final puestos =
      [
        for (final x in Posicion.values)
          if (!p.estaOcupada(x)) x,
      ]..sort(
        (a, b) => ordenadas
            .where((j) => j.puedeJugarEn(a))
            .length
            .compareTo(ordenadas.where((j) => j.puedeJugarEn(b)).length),
      );
  for (final pos in puestos) {
    final j = ordenadas.where((x) => p.posicionesDisponiblesPara(x).contains(pos)).firstOrNull;
    if (j == null) return null;
    p = p.asignar(j, pos);
  }
  return alineacionDePlantel(p);
}

// ═════════════════════════════════════════ El servicio ══════════════════════════════════════════

/// Reglas de los tres modos sobre la liga y el motor de partido. Puro salvo el azar de los
/// partidos y de los rivales.
class ModosCompetitivo {
  ModosCompetitivo(this.liga, {Random? azar}) : _azar = azar ?? Random(), esc = ModosEscalera(liga, azar: azar);

  final Liga liga;
  final ModosEscalera esc;
  final Random _azar;

  late final Map<String, Jugador> _porId = {for (final j in liga.catalogo) j.id: j};

  Jugador? jugador(String id) => _porId[id];

  // ── Equipos ──

  /// El plantel de una alineación (con las cartas como juegan hoy: evoluciones incluidas). Una
  /// carta que ya no está en el catálogo se reemplaza por otra que juegue ese puesto.
  Plantel plantelDe(Alineacion a) {
    var p = const Plantel();
    for (final pos in Posicion.values) {
      final id = a[pos];
      if (id == null) continue;
      final j = cartaOReemplazo(_porId, liga.catalogo, id, pos, p);
      p = p.asignar(cartaDeAlbum(j), pos);
    }
    return p;
  }

  /// La alineación como un equipo con nombre (para el cuadro de un torneo).
  RivalEscalera rivalDeAlineacion(Alineacion a, String identidad, String etiqueta) {
    final p = plantelDe(a);
    return RivalEscalera(
      identidadId: identidad,
      etiqueta: etiqueta,
      cartaIds: alineacionDePlantel(p),
      tactica: recomendar(PerfilPlantel.de(p)).tactica,
      media: ModosEscalera.mediaDe(p),
    );
  }

  EquipoPartido equipoPropio(Alineacion a, String identidad, {Map<Posicion, int> bonus = const {}}) {
    final p = plantelDe(a);
    final forma = <String, int>{
      for (final e in bonus.entries)
        if (p.en(e.key) != null) p.en(e.key)!.id: e.value,
    };
    return EquipoPartido(
      identidadId: identidad,
      plantel: p,
      tactica: recomendar(PerfilPlantel.de(p)).tactica,
      forma: forma,
    );
  }

  EquipoPartido equipoDeRival(RivalEscalera r) => esc.equipoRival(r);

  /// Partido simulado de principio a fin: (puntos de [a], puntos de [b]).
  (int, int) simular(EquipoPartido a, EquipoPartido b, {bool aLocal = true}) {
    final m = MotorPartido(local: aLocal ? a : b, visitante: aLocal ? b : a, azar: _azar)..simularTodo();
    return aLocal ? (m.puntosLocal, m.puntosVisitante) : (m.puntosVisitante, m.puntosLocal);
  }

  /// Motor de un partido tuyo contra [rival].
  MotorPartido motorUsuario(EquipoPartido propio, EquipoPartido rival, {required bool propioLocal}) => MotorPartido(
    local: propioLocal ? propio : rival,
    visitante: propioLocal ? rival : propio,
    usuarioLocal: propioLocal,
    azar: _azar,
  );

  /// Marcador de un partido terminado desde tu lado: (tus puntos, los del rival).
  (int, int) marcadorUsuario(MotorPartido m) =>
      (m.usuarioLocal ?? true) ? (m.puntosLocal, m.puntosVisitante) : (m.puntosVisitante, m.puntosLocal);

  Set<int> _ids(Alineacion a) => {for (final j in plantelDe(a).jugadores) j.nbaPlayerId};

  // ── Divisiones ──

  List<RivalEscalera> rivalesDeDivision(int division, Dificultad d, Set<int> excluidos) {
    final objetivo = EstadoDivisiones.objetivo(division, d);
    final res = <RivalEscalera>[];
    for (var i = 0; i < EstadoDivisiones.partidosPorTemporada; i++) {
      final evitar = {for (final r in res.reversed.take(2)) r.identidadId};
      res.add(esc.rivalAlAzar(objetivo + (i % 3) - 1, excluidos, evitar: evitar));
    }
    return res;
  }

  Temporada nuevaDivisiones({
    required String id,
    required String franquiciaId,
    required Dificultad dificultad,
    required Alineacion cartas,
  }) {
    final estado = EstadoDivisiones(
      cartas: cartas,
      rivales: rivalesDeDivision(EstadoDivisiones.ultimaDivision, dificultad, _ids(cartas)),
    );
    return estado.en(
      Temporada(id: id, franquiciaUsuarioId: franquiciaId, modoJuego: ModoJuego.divisiones, dificultad: dificultad),
    );
  }

  MotorPartido motorDivisiones(Temporada t) {
    final e = EstadoDivisiones.de(t)!;
    final rival = e.pendiente ?? (throw StateError('No hay partido pendiente.'));
    return motorUsuario(
      equipoPropio(e.cartas, t.franquiciaUsuarioId),
      equipoDeRival(rival),
      propioLocal: e.localProximo,
    );
  }

  Temporada registrarDivisiones(Temporada t, MotorPartido m) {
    final e = EstadoDivisiones.de(t)!;
    if (e.pendiente == null) return t;
    final (mios, suyos) = marcadorUsuario(m);
    return e
        .copyWith(
          marcadores: [...e.marcadores, (mios, suyos)],
          victorias: e.victorias + (mios > suyos ? 1 : 0),
          derrotas: e.derrotas + (mios > suyos ? 0 : 1),
        )
        .en(t);
  }

  Temporada simularDivisiones(Temporada t) => registrarDivisiones(t, motorDivisiones(t)..simularTodo());

  /// Juega lo que queda de la temporada de división.
  Temporada simularTemporadaDivisiones(Temporada t) {
    var x = t;
    while (EstadoDivisiones.de(x)!.pendiente != null) {
      x = simularDivisiones(x);
    }
    return x;
  }

  /// Termina la temporada de división: asciende, se queda o desciende, y arma los rivales de la
  /// siguiente.
  Temporada cerrarTemporadaDivisiones(Temporada t) {
    final e = EstadoDivisiones.de(t)!;
    if (!e.temporadaTerminada) return t;
    final (nueva, mov) = EstadoDivisiones.cierre(e.division, e.puntos);
    return e
        .copyWith(
          division: nueva,
          temporada: e.temporada + 1,
          marcadores: const [],
          rivales: rivalesDeDivision(nueva, t.dificultad, _ids(e.cartas)),
          titulos: e.titulos + (e.tituloDeLaElite ? 1 : 0),
          llegoA1: e.llegoA1 || nueva == 1,
          historial: [...e.historial, CierreDivision(e.division, e.puntos, mov)],
        )
        .en(t);
  }

  Temporada cambiarCartasDivisiones(Temporada t, Alineacion cartas) {
    final e = EstadoDivisiones.de(t)!;
    return e.copyWith(cartas: cartas).en(t);
  }

  // ── Conquista ──

  Temporada nuevaConquista({
    required String id,
    required String franquiciaId,
    required Dificultad dificultad,
    required Alineacion cartas,
  }) => EstadoConquista(
    inicio: franquiciaId,
    conquistados: [franquiciaId],
    cartas: cartas,
  ).en(Temporada(id: id, franquiciaUsuarioId: franquiciaId, modoJuego: ModoJuego.conquista, dificultad: dificultad));

  /// Media objetivo del rival: sube un poco con cada territorio que ya tenés.
  static double objetivoConquista(Dificultad d, int conquistados) =>
      switch (d) {
        Dificultad.normal => 72.0,
        Dificultad.dificil => 76.0,
        Dificultad.leyenda => 80.0,
      } +
      conquistados * 0.35;

  /// Elegís el territorio a atacar: se arma el rival (lo mejor de esa franquicia, según la media
  /// objetivo).
  Temporada atacar(Temporada t, String territorio) {
    final e = EstadoConquista.de(t)!;
    if (!e.atacables.contains(territorio) || e.objetivo != null || e.terminada) return t;
    final rival = esc.rivalTodosLosTiempos(
      territorio,
      _ids(e.cartas),
      objetivo: objetivoConquista(t.dificultad, e.conquistados.length).round(),
    );
    if (rival == null) return t;
    return e.copyWith(objetivo: territorio, rival: rival).en(t);
  }

  /// Cartas que tenés para armar el equipo: las de tu álbum y las de los territorios conquistados.
  List<Jugador> cartasDisponiblesConquista(EstadoConquista e, Set<String> album) => [
    for (final j in liga.catalogo)
      if (album.contains(j.id) || e.propios.contains(j.franquiciaId)) j,
  ];

  MotorPartido motorConquista(Temporada t) {
    final e = EstadoConquista.de(t)!;
    final rival = e.rival ?? (throw StateError('Elegí un territorio para atacar.'));
    return motorUsuario(
      equipoPropio(e.cartas, t.franquiciaUsuarioId, bonus: e.bonusPorPuesto(liga.franquicias)),
      equipoDeRival(rival),
      propioLocal: e.localProximo,
    );
  }

  Temporada registrarConquista(Temporada t, MotorPartido m) {
    final e = EstadoConquista.de(t)!;
    final objetivo = e.objetivo;
    if (objetivo == null) return t;
    final (mios, suyos) = marcadorUsuario(m);
    final gano = mios > suyos;
    return e
        .copyWith(
          conquistados: gano ? [...e.conquistados, objetivo] : null,
          victorias: e.victorias + (gano ? 1 : 0),
          derrotas: e.derrotas + (gano ? 0 : 1),
          batallas: e.batallas + 1,
          objetivo: null,
          rival: null,
        )
        .en(t);
  }

  Temporada simularConquista(Temporada t) => registrarConquista(t, motorConquista(t)..simularTodo());

  /// Te arrepentís del ataque: volvés a elegir territorio.
  Temporada cancelarAtaque(Temporada t) {
    final e = EstadoConquista.de(t)!;
    return e.objetivo == null ? t : e.copyWith(objetivo: null, rival: null).en(t);
  }

  Temporada cambiarCartasConquista(Temporada t, Alineacion cartas) {
    final e = EstadoConquista.de(t)!;
    return e.copyWith(cartas: cartas).en(t);
  }

  // ── Creador de torneos ──

  /// El mejor plantel de una franquicia y época (null si esa combinación no alcanza para armar uno).
  RivalEscalera? rivalMejorDeEpoca(String franquiciaId, Epoca epoca, Set<int> excluidos) {
    final pool = [
      for (final j in liga.catalogo)
        if (j.franquiciaId == franquiciaId && j.epoca == epoca && !excluidos.contains(j.nbaPlayerId)) j,
    ];
    final p = esc.completar(const Plantel(), pool);
    if (p == null) return null;
    return rivalDeAlineacion(alineacionDePlantel(p), _identidad(p.jugadores), '(${epoca.corta})');
  }

  /// Identidad más repetida entre las cartas (los Thunder de los 90 juegan como Sonics).
  String _identidad(Iterable<Jugador> js) {
    final cuenta = <String, int>{};
    for (final j in js) {
      cuenta[j.equipo] = (cuenta[j.equipo] ?? 0) + 1;
    }
    return cuenta.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// Equipo de un plantel guardado (una de tus partidas).
  RivalEscalera? rivalDePlantel(Plantel p, String identidad, String etiqueta) =>
      p.completo ? rivalDeAlineacion(alineacionDePlantel(p), identidad, etiqueta) : null;

  SimuladorTorneo simuladorDe(Torneo t) {
    final cache = <int, EquipoPartido>{};
    EquipoPartido de(int i) => cache.putIfAbsent(i, () => equipoDeRival(t.equipos[i].rival));
    return (a, b, aLocal) => simular(de(a), de(b), aLocal: aLocal);
  }

  Temporada nuevoTorneo({required String id, required String franquiciaId, required Torneo torneo}) => torneo
      .avanzar(simuladorDe(torneo))
      .en(Temporada(id: id, franquiciaUsuarioId: franquiciaId, modoJuego: ModoJuego.creadorTorneos));

  MotorPartido motorTorneo(Temporada t) {
    final torneo = Torneo.de(t)!;
    final l = torneo.pendienteUsuario ?? (throw StateError('No hay partido tuyo pendiente.'));
    final u = torneo.usuario;
    final otro = u == l.a ? l.b : l.a;
    final local = u == l.a ? l.aLocalProximo : !l.aLocalProximo;
    return motorUsuario(
      equipoDeRival(torneo.equipos[u].rival),
      equipoDeRival(torneo.equipos[otro].rival),
      propioLocal: local,
    );
  }

  Temporada registrarTorneo(Temporada t, MotorPartido m) {
    final torneo = Torneo.de(t)!;
    if (torneo.pendienteUsuario == null) return t;
    final (mios, suyos) = marcadorUsuario(m);
    final nuevo = torneo.registrarUsuario(mios, suyos);
    return nuevo.avanzar(simuladorDe(nuevo)).en(t);
  }

  Temporada simularTorneo(Temporada t) => registrarTorneo(t, motorTorneo(t)..simularTodo());

  /// Termina tu cruce (la serie o el partido) y sigue hasta tu próximo partido.
  Temporada simularCruceTorneo(Temporada t) {
    var x = t;
    final inicial = Torneo.de(t)!.pendienteUsuario;
    if (inicial == null) return t;
    for (var i = 0; i < 9; i++) {
      final p = Torneo.de(x)!.pendienteUsuario;
      if (p == null || p.fase != inicial.fase || p.a != inicial.a || p.b != inicial.b) break;
      x = simularTorneo(x);
    }
    return x;
  }

  /// Simula todo lo que queda, incluidos tus partidos.
  /// Espectador: juega una ronda entera.
  Temporada simularRondaTorneo(Temporada t) {
    final torneo = Torneo.de(t)!;
    return torneo.jugarRonda(simuladorDe(torneo)).en(t);
  }

  Temporada simularRestoTorneo(Temporada t) {
    final torneo = Torneo.de(t)!;
    return torneo.avanzar(simuladorDe(torneo), incluirUsuario: true).en(t);
  }
}

// ═════════════════════════════════════════ Recompensas ══════════════════════════════════════════

/// Metajuego de Divisiones, Conquista y Creador de torneos: XP y monedas por partido, más los
/// premios de cada modo. No toca récords ni anillos de la temporada.
(PerfilEntrenador, List<Novedad>) premiarCompetitivo(PerfilEntrenador perfil, Temporada antes, Temporada despues) {
  final modo = despues.modoJuego;
  var p = perfil;
  final novedades = <Novedad>[];
  final mult = switch (despues.dificultad) {
    Dificultad.normal => 1.0,
    Dificultad.dificil => 1.25,
    Dificultad.leyenda => 1.5,
  };
  final ahora = DateTime.now().millisecondsSinceEpoch;

  void xpMonedas(int xp, int monedas, String texto, {String? detalle}) {
    p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
    novedades.add(Novedad(texto, detalle: detalle ?? '+$xp XP · +$monedas monedas', destacada: true));
  }

  void logro(Logro l) {
    if (p.logros.containsKey(l)) return;
    p = p.copyWith(logros: {...p.logros, l: ahora}, xp: p.xp + 100, monedas: p.monedas + 50);
    novedades.add(Novedad('Logro: ${l.nombre}', detalle: l.descripcion, destacada: true));
  }

  void trofeo(TipoTrofeo tipo, String detalle) {
    p = p.copyWith(
      trofeos: [
        ...p.trofeos,
        Trofeo(
          tipo: tipo,
          temporadaId: despues.id,
          franquiciaId: despues.franquiciaUsuarioId,
          detalle: detalle,
          fecha: ahora,
        ),
      ],
    );
    novedades.add(Novedad('Trofeo: ${tipo.nombre}', destacada: true));
  }

  void porPartidos(int ganados, int perdidos) {
    if (ganados + perdidos == 0) return;
    final xp = ((ganados * 30 + perdidos * 10) * mult).round();
    final monedas = ganados * 10 + perdidos * 3;
    p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
    novedades.add(Novedad('+$xp XP · +$monedas monedas'));
  }

  switch (modo) {
    case ModoJuego.divisiones:
      final a = EstadoDivisiones.de(antes), d = EstadoDivisiones.de(despues);
      if (a == null || d == null) break;
      porPartidos(d.victorias - a.victorias, d.derrotas - a.derrotas);
      if (d.division < a.division) {
        xpMonedas((150 * mult).round(), 60, '¡Ascenso a la División ${d.division}!');
      }
      if (!a.llegoA1 && d.llegoA1) {
        logro(Logro.divisionUno);
        trofeo(TipoTrofeo.divisiones, 'División 1');
      }
      if (d.titulos > a.titulos) xpMonedas((300 * mult).round(), 120, '¡Campeón de la élite!');
    case ModoJuego.conquista:
      final a = EstadoConquista.de(antes), d = EstadoConquista.de(despues);
      if (a == null || d == null) break;
      porPartidos(d.victorias - a.victorias, d.derrotas - a.derrotas);
      final nuevos = d.conquistados.length - a.conquistados.length;
      if (nuevos > 0) {
        p = p.copyWith(monedas: p.monedas + 5 * nuevos);
        novedades.add(Novedad('+${5 * nuevos} monedas · territorio conquistado'));
      }
      if (!d.completo && nuevos > 0) {
        // Una conferencia entera es un hito.
        for (final c in Conferencia.values) {
          if (_conferenciaCompleta(d, c) && !_conferenciaCompleta(a, c)) {
            xpMonedas((120 * mult).round(), 50, '¡${c.etiqueta} conquistada!');
          }
        }
      }
      if (d.completo && !a.completo) {
        logro(Logro.conquistaTotal);
        trofeo(TipoTrofeo.conquista, '30 de 30');
      }
    case ModoJuego.creadorTorneos:
      final a = Torneo.de(antes), d = Torneo.de(despues);
      if (a == null || d == null || !d.conUsuario) break;
      final (va, da) = a.recordUsuario;
      final (vd, dd) = d.recordUsuario;
      porPartidos(vd - va, dd - da);
      if (d.terminado && !a.terminado && d.campeon == d.usuario) {
        xpMonedas((200 * mult).round(), 80, '¡Campeón de ${d.nombre}!');
        logro(Logro.campeonTorneo);
        trofeo(TipoTrofeo.torneoPropio, d.nombre);
      }
    default:
      break;
  }
  return (p, novedades);
}

bool _conferenciaCompleta(EstadoConquista e, Conferencia c) =>
    mapaConquista.keys.where((id) => conferenciaDeConquista(id) == c).every(e.propios.contains);

/// Conferencia de cada franquicia del tablero (las 30 actuales); el metajuego no tiene la lista de
/// franquicias a mano, y una prueba la compara con los datos.
Conferencia conferenciaDeConquista(String id) => _este.contains(id) ? Conferencia.este : Conferencia.oeste;

const _este = {'BOS', 'BKN', 'NYK', 'PHI', 'TOR', 'CHI', 'CLE', 'DET', 'IND', 'MIL', 'ATL', 'CHA', 'MIA', 'ORL', 'WAS'};

/// Dónde va una partida de estos modos, para la lista de partidas (null si no es de ellos).
String? faseCompetitiva(Temporada t) {
  switch (t.modoJuego) {
    case ModoJuego.divisiones:
      final e = EstadoDivisiones.de(t);
      return e == null ? null : 'División ${e.division} · temporada ${e.temporada}';
    case ModoJuego.conquista:
      final e = EstadoConquista.de(t);
      if (e == null) return null;
      return e.completo
          ? 'Mapa completo'
          : (e.sinVidas ? 'Perdida' : '${e.conquistados.length}/${mapaConquista.length} territorios');
    case ModoJuego.creadorTorneos:
      final e = Torneo.de(t);
      if (e == null) return null;
      final c = e.campeon;
      return c == null ? '${e.nombre} · ${e.formato.nombre}' : 'Campeón: ${e.equipos[c].nombre}';
    default:
      return null;
  }
}

/// El número LED de la fila de una partida de estos modos: victorias y derrotas tuyas.
String? marcadorCompetitivo(Temporada t) {
  switch (t.modoJuego) {
    case ModoJuego.divisiones:
      final e = EstadoDivisiones.de(t);
      return e == null ? null : '${e.victorias}-${e.derrotas}';
    case ModoJuego.conquista:
      final e = EstadoConquista.de(t);
      return e == null ? null : '${e.victorias}-${e.derrotas}';
    case ModoJuego.creadorTorneos:
      final e = Torneo.de(t);
      if (e == null) return null;
      final (v, d) = e.recordUsuario;
      return '$v-$d';
    default:
      return null;
  }
}
