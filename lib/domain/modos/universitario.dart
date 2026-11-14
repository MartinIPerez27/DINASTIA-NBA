import 'dart:math';

import '../entities/franquicia.dart';
import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/perfil.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/rol_cancha.dart';
import '../entities/temporada.dart';
import '../motor.dart';
import '../playbook.dart';
import '../progreso.dart';
import 'carrera_jugador.dart';

// ===========================================================================================
// Modo universitario: un programa ficticio, una liga ficticia de 32 universidades y jugadores
// inventados. Se simulan temporadas enteras (30 partidos + torneo de 16), se recluta, los
// jugadores crecen y los mejores pasan por un draft de la NBA ficticio.
//
// Todo el estado vive en `Temporada.datosModo`. Las plantillas de las 31 universidades de la IA
// no se guardan: se regeneran con la semilla (misma semilla, mismos jugadores).
// ===========================================================================================

/// Hash estable (FNV-1a) para derivar semillas: `Object.hash` cambia en cada ejecución.
int hashUniv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

double _gauss(Random r) {
  final u = max(1e-9, r.nextDouble()), v = r.nextDouble();
  return sqrt(-2 * log(u)) * cos(2 * pi * v);
}

// -------------------------------------------------------------------------------------------
// Nombres, colores y universidades ficticias
// -------------------------------------------------------------------------------------------

/// Generador de nombres de personas (mezcla neutra: sirve para un campus de cualquier lado).
class NombresFicticios {
  const NombresFicticios._();

  static const nombres = [
    'Lucas',
    'Mateo',
    'Thiago',
    'Santiago',
    'Benjamín',
    'Joaquín',
    'Bruno',
    'Facundo',
    'Emilio',
    'Tomás',
    'Nicolás',
    'Dante',
    'Marcus',
    'Jaylen',
    'Darius',
    'Tyrese',
    'Elijah',
    'Isaiah',
    'Caleb',
    'Jordan',
    'Malik',
    'Andre',
    'Devin',
    'Terrence',
    'Kobe',
    'Shawn',
    'Diego',
    'Gonzalo',
    'Ramiro',
    'Matías',
    'Ian',
    'Noah',
    'Ethan',
    'Liam',
    'Kai',
    'Zion',
    'Amir',
    'Jamal',
    'Cole',
    'Wyatt',
  ];
  static const apellidos = [
    'Aguirre',
    'Benítez',
    'Cabrera',
    'Domínguez',
    'Escobar',
    'Fernández',
    'Giménez',
    'Herrera',
    'Ibarra',
    'Juárez',
    'Luna',
    'Medina',
    'Navarro',
    'Ortega',
    'Paredes',
    'Quiroga',
    'Rivas',
    'Sosa',
    'Tapia',
    'Vega',
    'Williams',
    'Johnson',
    'Brooks',
    'Carter',
    'Davis',
    'Edwards',
    'Foster',
    'Grant',
    'Hayes',
    'Irving',
    'Jenkins',
    'Knight',
    'Lawson',
    'Mitchell',
    'Newman',
    'Owens',
    'Parker',
    'Reed',
    'Stewart',
    'Turner',
    'Walker',
    'Young',
    'Bianchi',
    'Costa',
    'Duarte',
    'Moreira',
    'Okafor',
    'Mensah',
    'Petrović',
    'Novak',
    'Lindgren',
    'Kovač',
    'Tanaka',
    'Silva',
    'Romero',
    'Acosta',
    'Peralta',
    'Villalba',
    'Ferreyra',
  ];

  static String persona(Random r) => '${nombres[r.nextInt(nombres.length)]} ${apellidos[r.nextInt(apellidos.length)]}';
}

/// Colores para elegir (nombre, ARGB).
class PaletaUniv {
  const PaletaUniv._();

  static const colores = <(String, int)>[
    ('Rojo', 0xFFC8102E),
    ('Azul', 0xFF0B3D91),
    ('Verde', 0xFF00703C),
    ('Dorado', 0xFFFFB81C),
    ('Violeta', 0xFF582C83),
    ('Naranja', 0xFFF47321),
    ('Celeste', 0xFF4B9CD3),
    ('Negro', 0xFF1A1A1A),
    ('Bordó', 0xFF7A1F3D),
    ('Turquesa', 0xFF00A19B),
    ('Blanco', 0xFFF2F2F2),
    ('Plata', 0xFFA7A9AC),
  ];
}

/// Las 31 universidades de la IA: (sigla, lugar, mote).
const _colegios = <(String, String, String)>[
  ('ALB', 'Albion State', 'Wolves'),
  ('BRK', 'Brookhaven', 'Herons'),
  ('CAS', 'Cascade Tech', 'Rams'),
  ('DUN', 'Dunmore', 'Stags'),
  ('EMB', 'Emberton', 'Phoenix'),
  ('FAL', 'Falcon Ridge', 'Falcons'),
  ('GLA', 'Glacier Valley', 'Huskies'),
  ('HAR', 'Harlow', 'Bears'),
  ('IRO', 'Ironwood', 'Forge'),
  ('JUN', 'Juniper Coast', 'Otters'),
  ('KES', 'Kestrel Hill', 'Kestrels'),
  ('LAK', 'Lakemont', 'Pilots'),
  ('MAR', 'Marlow', 'Mustangs'),
  ('NOR', 'Northgate', 'Knights'),
  ('OAK', 'Oakridge', 'Titans'),
  ('PIN', 'Pinecrest', 'Foxes'),
  ('QUA', 'Quarry Bay', 'Anchors'),
  ('RED', 'Redstone', 'Bison'),
  ('SIL', 'Silverlake', 'Comets'),
  ('TAL', 'Talbot', 'Tigers'),
  ('UMB', 'Umber Falls', 'Ravens'),
  ('VAL', 'Valmont', 'Vipers'),
  ('WES', 'Westerly', 'Gales'),
  ('XAN', 'Xanadu Tech', 'Rockets'),
  ('YOR', 'Yorkdale', 'Lions'),
  ('ZEP', 'Zephyr State', 'Jets'),
  ('AMB', 'Amberfield', 'Hornets'),
  ('BLU', 'Bluffton', 'Pelicans'),
  ('CRE', 'Crestwood', 'Eagles'),
  ('DEL', 'Delmar', 'Dolphins'),
  ('ELM', 'Elmhurst', 'Badgers'),
];

const nombresConferencias = ['Pacífico', 'Gran Lago', 'Sureña', 'Atlántica'];

/// Tu programa: nombre, mote, colores y sigla (las iniciales, para el escudo tipográfico).
class Programa {
  const Programa({required this.nombre, required this.mote, required this.color1, required this.color2});

  final String nombre, mote;

  /// Índices en [PaletaUniv.colores].
  final int color1, color2;

  /// Hasta 3 letras: iniciales del nombre (o sus primeras letras si es una sola palabra).
  String get sigla {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final base = partes.length >= 2 ? partes.take(3).map((p) => p[0]).join() : (partes.isEmpty ? 'UNI' : partes[0]);
    final s = base.toUpperCase().replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÑ0-9]'), '');
    final corta = s.length >= 3 ? s.substring(0, 3) : s.padRight(3, 'X');
    // No puede repetir la sigla de una universidad de la IA.
    return _colegios.any((c) => c.$1 == corta) ? '${corta.substring(0, 2)}9' : corta;
  }

  String? get error {
    if (nombre.trim().length < 3) return 'Poné un nombre de al menos 3 letras.';
    if (mote.trim().length < 3) return 'Poné un mote (los "Halcones", los "Toros"…).';
    if (color1 == color2) return 'Elegí dos colores distintos.';
    return null;
  }

  Franquicia get franquicia => Franquicia(
    id: sigla,
    nbaTeamId: 0,
    ciudad: nombre.trim(),
    nombre: mote.trim(),
    colorPrimario: PaletaUniv.colores[color1].$2,
    colorSecundario: PaletaUniv.colores[color2].$2,
  );

  Map<String, dynamic> toJson() => {'n': nombre, 'm': mote, 'c1': color1, 'c2': color2};

  factory Programa.fromJson(Map<String, dynamic> j) =>
      Programa(nombre: j['n'] as String, mote: j['m'] as String, color1: j['c1'] as int, color2: j['c2'] as int);
}

// -------------------------------------------------------------------------------------------
// Estudiantes (los jugadores ficticios)
// -------------------------------------------------------------------------------------------

/// Un jugador universitario. [anio] va de 1 (primer año) a 4 (último).
class Estudiante {
  const Estudiante({
    required this.id,
    required this.nombre,
    required this.posicion,
    required this.rol,
    required this.atributos,
    this.alturaCm = 198,
    this.pesoKg = 95,
    this.anio = 1,
    this.estrellas = 3,
    this.potencial = 1,
    this.creado = false,
    this.pj = 0,
    this.pts = 0,
    this.reb = 0,
    this.ast = 0,
  });

  final String id, nombre;
  final Posicion posicion;
  final RolCancha rol;
  final Atributos atributos;
  final int alturaCm, pesoKg;
  final int anio, estrellas;

  /// 0 a 3: cuánto sigue creciendo en cada receso.
  final int potencial;

  /// Lo creaste vos (y se puede llevar a Mi carrera).
  final bool creado;
  final int pj, pts, reb, ast;

  int get media => ModeloCarrera.mediaDe(atributos, posicion);

  static const etiquetasAnio = ['', 'Primer año', 'Segundo año', 'Tercer año', 'Último año'];
  String get etiquetaAnio => etiquetasAnio[anio.clamp(1, 4)];

  EstadisticasJugador get estadisticas => ModeloCarrera.estadisticasDe(atributos, posicion, media);

  /// La carta que usa el motor.
  Jugador get carta => Jugador(
    id: id,
    nbaPlayerId: -(3000000 + (hashUniv(id) & 0xfffff)),
    nombre: nombre,
    franquiciaId: 'UNI',
    epoca: Epoca.actualidad,
    tier: media >= 85 ? Tier.s : (media >= 75 ? Tier.a : Tier.b),
    posiciones: [posicion, ..._vecinos(posicion)],
    rol: rol,
    dorsal: 0,
    stats: estadisticas,
    media: media,
    fotos: const [],
  );

  static List<Posicion> _vecinos(Posicion p) => switch (p) {
    Posicion.base => const [Posicion.escolta],
    Posicion.escolta => const [Posicion.alero],
    Posicion.alero => const [Posicion.escolta, Posicion.alaPivot],
    Posicion.alaPivot => const [Posicion.alero],
    _ => const [Posicion.alaPivot],
  };

  /// Valor de temporada para premios (por partido, con los minutos que juega).
  double get valor {
    final s = estadisticas;
    return (s.ppp + 0.7 * s.rpp + 0.7 * s.app + s.robP + s.tapP - s.perP) * (s.minP / 30);
  }

  Estudiante copyWith({Atributos? atributos, int? anio, int? pj, int? pts, int? reb, int? ast}) => Estudiante(
    id: id,
    nombre: nombre,
    posicion: posicion,
    rol: rol,
    atributos: atributos ?? this.atributos,
    alturaCm: alturaCm,
    pesoKg: pesoKg,
    anio: anio ?? this.anio,
    estrellas: estrellas,
    potencial: potencial,
    creado: creado,
    pj: pj ?? this.pj,
    pts: pts ?? this.pts,
    reb: reb ?? this.reb,
    ast: ast ?? this.ast,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': nombre,
    'p': posicion.name,
    'r': rol.name,
    'a': atributos.toJson(),
    'h': alturaCm,
    'w': pesoKg,
    'y': anio,
    's': estrellas,
    'pot': potencial,
    if (creado) 'c': true,
    if (pj > 0) 'st': [pj, pts, reb, ast],
  };

  factory Estudiante.fromJson(Map<String, dynamic> j) {
    final st = (j['st'] as List?)?.cast<int>() ?? const [0, 0, 0, 0];
    return Estudiante(
      id: j['id'] as String,
      nombre: j['n'] as String,
      posicion: Posicion.values.byName(j['p'] as String),
      rol: RolCancha.values.byName(j['r'] as String),
      atributos: Atributos.fromJson(j['a'] as Map<String, dynamic>),
      alturaCm: j['h'] as int? ?? 198,
      pesoKg: j['w'] as int? ?? 95,
      anio: j['y'] as int? ?? 1,
      estrellas: j['s'] as int? ?? 3,
      potencial: j['pot'] as int? ?? 1,
      creado: j['c'] as bool? ?? false,
      pj: st[0],
      pts: st[1],
      reb: st[2],
      ast: st[3],
    );
  }

  /// Un jugador creado con el creador de Mi carrera, ya como estudiante (arranca de primer año).
  static Estudiante deCreado(JugadorCreado c, String id) => Estudiante(
    id: id,
    nombre: c.nombre.trim(),
    posicion: c.posicion,
    rol: c.rol,
    atributos: c.atributos,
    alturaCm: c.alturaCm,
    pesoKg: c.pesoKg,
    anio: 1,
    estrellas: 4,
    potencial: 2,
    creado: true,
  );

  /// Un jugador generado: [media] objetivo de su nivel de partida.
  static Estudiante generar(
    Random azar, {
    required String id,
    required double media,
    required int anio,
    required int estrellas,
    int potencial = 1,
    Posicion? posicion,
  }) {
    final pos = posicion ?? Posicion.titulares[azar.nextInt(5)];
    final roles = JugadorCreado.rolesDe(pos);
    final rol = roles[azar.nextInt(roles.length)];
    final altura = (JugadorCreado.alturaSugerida(pos) + (_gauss(azar) * 4).round()).clamp(175, 220);
    final peso = (70 + (altura - 180) * 1.0 + _gauss(azar) * 5).round().clamp(72, 140);
    // Inversa de ModeloCarrera.mediaDe: media = 60 + 1.5 × (promedio − 55).
    final objetivo = (media - 60) / 1.5 + 55;
    final base = ModeloCarrera.desdePerfil(rol, pos, objetivo, altura: altura, peso: peso);
    // Un poco de desparejo entre atributos.
    final atributos = Atributos({
      for (final a in Atributo.values) a: (base[a] + (_gauss(azar) * 2).round()).clamp(25, 99),
    });
    return Estudiante(
      id: id,
      nombre: NombresFicticios.persona(azar),
      posicion: pos,
      rol: rol,
      atributos: atributos,
      alturaCm: altura,
      pesoKg: peso,
      anio: anio,
      estrellas: estrellas,
      potencial: potencial,
    );
  }
}

/// Un recluta: un estudiante de primer año con su precio en puntos de reclutamiento.
class Recluta {
  const Recluta(this.estudiante, this.precio);

  final Estudiante estudiante;
  final int precio;

  static const precios = [0, 1, 2, 3, 5, 7];
}

// -------------------------------------------------------------------------------------------
// Estado de la partida
// -------------------------------------------------------------------------------------------

enum FaseUniv {
  regular('Temporada regular'),
  torneo('Torneo nacional'),
  premios('Fin de temporada'),
  receso('Receso');

  const FaseUniv(this.etiqueta);
  final String etiqueta;
}

/// Un partido del calendario: índices de equipo (0 = tu programa).
typedef JuegoU = (int local, int visitante);

/// Posición en la tabla de un equipo.
class RegistroU {
  const RegistroU(this.idx, this.v, this.d, this.vConf, this.dConf, this.pf, this.pc);

  final int idx, v, d, vConf, dConf, pf, pc;
  int get jugados => v + d;
  double get porcentaje => jugados == 0 ? 0 : v / jugados;
  int get diferencia => pf - pc;
}

/// Resumen de una temporada tuya, para la historia.
class TemporadaUniv {
  const TemporadaUniv({
    required this.numero,
    required this.v,
    required this.d,
    required this.puestoConferencia,
    required this.torneo,
    required this.campeon,
    this.premios = const [],
    this.picks = const [],
  });

  final int numero, v, d, puestoConferencia;

  /// 'Campeón', 'Final', 'Semifinal', 'Cuartos', 'Octavos' o 'Sin torneo'.
  final String torneo;
  final bool campeon;
  final List<String> premios;

  /// Draft de ese año: "Nombre · pick 7" o "Nombre · sin draft".
  final List<String> picks;

  Map<String, dynamic> toJson() => {
    'n': numero,
    'v': v,
    'd': d,
    'pc': puestoConferencia,
    't': torneo,
    'c': campeon,
    if (premios.isNotEmpty) 'pr': premios,
    if (picks.isNotEmpty) 'pk': picks,
  };

  factory TemporadaUniv.fromJson(Map<String, dynamic> j) => TemporadaUniv(
    numero: j['n'] as int,
    v: j['v'] as int,
    d: j['d'] as int,
    puestoConferencia: j['pc'] as int,
    torneo: j['t'] as String,
    campeon: j['c'] as bool? ?? false,
    premios: (j['pr'] as List?)?.cast<String>() ?? const [],
    picks: (j['pk'] as List?)?.cast<String>() ?? const [],
  );
}

/// Un jugador tuyo que se fue (draft o graduación): para el Salón y para llevarlo a Mi carrera.
class Egresado {
  const Egresado({
    required this.nombre,
    required this.posicion,
    required this.rol,
    required this.atributos,
    required this.alturaCm,
    required this.pesoKg,
    required this.temporada,
    required this.anios,
    required this.media,
    this.pick,
    this.creado = false,
  });

  final String nombre;
  final Posicion posicion;
  final RolCancha rol;
  final Atributos atributos;
  final int alturaCm, pesoKg, temporada, anios, media;

  /// Elección del draft (1 a 30); null si nadie lo eligió.
  final int? pick;
  final bool creado;

  String get destino => pick == null ? 'Sin draft' : (pick! <= 30 ? 'Pick $pick' : 'Sin draft');

  /// Se lleva a Mi carrera como un jugador creado: sus tres mejores atributos pasan a ser sus fuertes.
  JugadorCreado get comoCreado {
    final orden = [...Atributo.values]..sort((a, b) => atributos[b].compareTo(atributos[a]));
    return JugadorCreado(
      nombre: nombre,
      posicion: posicion,
      rol: rol,
      fuertes: orden.take(3).toList(),
      alturaCm: alturaCm,
      pesoKg: pesoKg,
    );
  }

  Map<String, dynamic> toJson() => {
    'n': nombre,
    'p': posicion.name,
    'r': rol.name,
    'a': atributos.toJson(),
    'h': alturaCm,
    'w': pesoKg,
    't': temporada,
    'y': anios,
    'm': media,
    if (pick != null) 'pick': pick,
    if (creado) 'c': true,
  };

  factory Egresado.fromJson(Map<String, dynamic> j) => Egresado(
    nombre: j['n'] as String,
    posicion: Posicion.values.byName(j['p'] as String),
    rol: RolCancha.values.byName(j['r'] as String),
    atributos: Atributos.fromJson(j['a'] as Map<String, dynamic>),
    alturaCm: j['h'] as int,
    pesoKg: j['w'] as int,
    temporada: j['t'] as int,
    anios: j['y'] as int,
    media: j['m'] as int,
    pick: j['pick'] as int?,
    creado: j['c'] as bool? ?? false,
  );
}

/// La partida completa del modo universitario.
class EstadoUniv {
  const EstadoUniv({
    required this.semilla,
    required this.programa,
    required this.plantel,
    this.temporada = 1,
    this.prestigio = 30,
    this.prestigioIA = const [],
    this.fase = FaseUniv.regular,
    this.jornada = 0,
    this.resultados = const [],
    this.torneo = const [],
    this.historial = const [],
    this.egresados = const [],
    this.siguienteId = 1,
  });

  /// Cantidad de equipos, conferencias, partidos y jornadas.
  static const equipos = 32, porConferencia = 8, jornadas = 30, partidosPorJornada = 16;
  static const plantelMin = 8, plantelMax = 13, plantelBase = 10;

  final int semilla;
  final Programa programa;
  final List<Estudiante> plantel;
  final int temporada, prestigio;

  /// Prestigio de las 31 universidades de la IA (0 a 100), para armar sus planteles cada año.
  final List<int> prestigioIA;
  final FaseUniv fase;

  /// Jornadas ya jugadas (0 a 30).
  final int jornada;

  /// Puntos de cada partido, de a dos (local, visitante); 0 = sin jugar.
  final List<int> resultados;

  /// Torneo: rondas → partidos → [equipoA, equipoB, puntosA, puntosB].
  final List<List<List<int>>> torneo;
  final List<TemporadaUniv> historial;
  final List<Egresado> egresados;
  final int siguienteId;

  static EstadoUniv? de(Temporada t) {
    if (t.modoJuego != ModoJuego.universitario || t.datosModo['u'] == null) return null;
    return EstadoUniv.fromJson(t.datosModo['u'] as Map<String, dynamic>);
  }

  /// Datos para `Temporada.datosModo`.
  Map<String, dynamic> aDatos() => {'u': toJson()};

  String get etiquetaFase => switch (fase) {
    FaseUniv.regular => 'Temporada $temporada · $jornada/$jornadas',
    _ => 'Temporada $temporada · ${fase.etiqueta}',
  };

  int get titulos => historial.where((h) => h.campeon).length;

  // --- Estructura de la liga ---

  /// Conferencia de cada equipo (0..3). El tuyo es el equipo 0.
  List<int> get conferenciaDe {
    final orden = List.generate(equipos - 1, (i) => i + 1)..shuffle(Random(semilla));
    final conf = List.filled(equipos, 0);
    final ordenado = [0, ...orden];
    for (var k = 0; k < ordenado.length; k++) {
      conf[ordenado[k]] = k ~/ porConferencia;
    }
    return conf;
  }

  /// Datos de un equipo para mostrar y jugar.
  Franquicia franquicia(int idx) {
    if (idx == 0) return programa.franquicia;
    final (sigla, lugar, mote) = _colegios[idx - 1];
    final c1 = (idx * 7 + semilla) % PaletaUniv.colores.length;
    var c2 = (idx * 5 + 3 + semilla) % PaletaUniv.colores.length;
    if (c2 == c1) c2 = (c2 + 4) % PaletaUniv.colores.length;
    return Franquicia(
      id: sigla,
      nbaTeamId: 0,
      ciudad: lugar,
      nombre: mote,
      colorPrimario: PaletaUniv.colores[c1].$2,
      colorSecundario: PaletaUniv.colores[c2].$2,
    );
  }

  int prestigioDe(int idx) => idx == 0 ? prestigio : (idx - 1 < prestigioIA.length ? prestigioIA[idx - 1] : 50);

  // --- Planteles ---

  /// Plantel de un equipo esta temporada (el tuyo es el guardado; los demás se regeneran).
  List<Estudiante> plantelDe(int idx) => idx == 0 ? plantel : plantelIA(semilla, temporada, idx, prestigioDe(idx));

  /// Plantel de una universidad de la IA: determinístico para (semilla, temporada, equipo).
  static List<Estudiante> plantelIA(int semilla, int temporada, int idx, int prestigio) {
    final azar = Random(hashUniv('$semilla|$temporada|$idx'));
    final media0 = 56 + prestigio * 0.22; // 56 a 78
    return [
      for (var i = 0; i < plantelBase; i++)
        () {
          // Como en tu plantel, los de años altos ya crecieron: el último año vale más que el primero.
          final anio = 1 + (i + azar.nextInt(2)) % 4;
          return Estudiante.generar(
            azar,
            id: 'ia$idx-$temporada-$i',
            media: media0 + (anio - 2.5) * 2.2 + (i < 5 ? 1.5 : -2.5) + _gauss(azar) * 2.2,
            anio: anio,
            estrellas: 1 + ((media0 - 54) / 6).floor().clamp(0, 4),
            potencial: azar.nextInt(3),
            posicion: Posicion.titulares[i % 5],
          );
        }(),
    ];
  }

  /// Fuerza de un plantel: promedio de los 5 mejores, con los 3 siguientes valiendo la mitad.
  static double fuerzaDe(List<Estudiante> r) {
    final m = [for (final e in r) e.media]..sort((a, b) => b.compareTo(a));
    if (m.isEmpty) return 50;
    final top = m.take(5), banco = m.skip(5).take(3);
    return (top.fold(0, (a, b) => a + b) + 0.5 * banco.fold(0, (a, b) => a + b)) / (top.length + 0.5 * banco.length);
  }

  // --- Calendario ---

  /// Las 30 jornadas de la temporada: 14 de conferencia (todos contra todos, ida y vuelta) y 16
  /// de otras conferencias. En cada jornada juegan los 32 equipos, una vez cada uno.
  List<List<JuegoU>> calendario() {
    final conf = conferenciaDe;
    final grupos = [
      for (var c = 0; c < 4; c++)
        [
          for (var i = 0; i < equipos; i++)
            if (conf[i] == c) i,
        ],
    ];
    final rondas = <List<JuegoU>>[];
    // Conferencia: método del círculo, 7 rondas de ida y 7 de vuelta.
    final dentro = <List<JuegoU>>[];
    final vuelta = <List<JuegoU>>[];
    final rot = [for (final g in grupos) List.of(g)];
    for (var r = 0; r < porConferencia - 1; r++) {
      final ida = <JuegoU>[], vta = <JuegoU>[];
      for (final g in rot) {
        for (var i = 0; i < porConferencia ~/ 2; i++) {
          final a = g[i], b = g[porConferencia - 1 - i];
          if ((r + i).isEven) {
            ida.add((a, b));
            vta.add((b, a));
          } else {
            ida.add((b, a));
            vta.add((a, b));
          }
        }
        g.insert(1, g.removeLast());
      }
      dentro.add(ida);
      vuelta.add(vta);
    }
    rondas.addAll(dentro);
    rondas.addAll(vuelta);
    // Otras conferencias: tres cruces posibles, cada uso con un corrimiento distinto (sin repetir rival).
    const cruces = [
      [(0, 1), (2, 3)],
      [(0, 2), (1, 3)],
      [(0, 3), (1, 2)],
    ];
    final usos = [0, 0, 0];
    final faltan = jornadas - rondas.length;
    for (var r = 0; r < faltan; r++) {
      final k = r % 3;
      final uso = usos[k]++;
      final shift = (uso * 3) % porConferencia;
      final juegos = <JuegoU>[];
      for (final (ca, cb) in cruces[k]) {
        for (var i = 0; i < porConferencia; i++) {
          final a = grupos[ca][i], b = grupos[cb][(i + shift) % porConferencia];
          juegos.add((i + uso).isEven ? (a, b) : (b, a));
        }
      }
      rondas.add(juegos);
    }
    rondas.shuffle(Random(hashUniv('$semilla|cal|$temporada')));
    return rondas;
  }

  /// Resultado de un partido de la temporada regular (null si no se jugó).
  (int, int)? resultado(int jornadaIdx, int juegoIdx) {
    final i = (jornadaIdx * partidosPorJornada + juegoIdx) * 2;
    if (i + 1 >= resultados.length || resultados[i] == 0) return null;
    return (resultados[i], resultados[i + 1]);
  }

  /// Tu partido de la jornada [j] (local, visitante) y su índice dentro de la jornada.
  (JuegoU, int)? partidoUsuario(int j, [List<List<JuegoU>>? cal]) {
    final c = (cal ?? calendario())[j];
    for (var i = 0; i < c.length; i++) {
      if (c[i].$1 == 0 || c[i].$2 == 0) return (c[i], i);
    }
    return null;
  }

  // --- Tabla y ranking ---

  List<RegistroU> registros() {
    final cal = calendario();
    final conf = conferenciaDe;
    final v = List.filled(equipos, 0), d = List.filled(equipos, 0);
    final vc = List.filled(equipos, 0), dc = List.filled(equipos, 0);
    final pf = List.filled(equipos, 0), pc = List.filled(equipos, 0);
    for (var j = 0; j < jornada; j++) {
      for (var i = 0; i < cal[j].length; i++) {
        final r = resultado(j, i);
        if (r == null) continue;
        final (l, vis) = cal[j][i];
        pf[l] += r.$1;
        pc[l] += r.$2;
        pf[vis] += r.$2;
        pc[vis] += r.$1;
        final gana = r.$1 > r.$2 ? l : vis, pierde = gana == l ? vis : l;
        v[gana]++;
        d[pierde]++;
        if (conf[l] == conf[vis]) {
          vc[gana]++;
          dc[pierde]++;
        }
      }
    }
    return [for (var i = 0; i < equipos; i++) RegistroU(i, v[i], d[i], vc[i], dc[i], pf[i], pc[i])];
  }

  /// Orden de la tabla: % de victorias, después diferencia de puntos.
  static int comparar(RegistroU a, RegistroU b) {
    final c = b.porcentaje.compareTo(a.porcentaje);
    return c != 0 ? c : b.diferencia.compareTo(a.diferencia);
  }

  /// Tabla de una conferencia.
  List<RegistroU> tablaConferencia(int conf) {
    final c = conferenciaDe;
    return [
      for (final r in registros())
        if (c[r.idx] == conf) r,
    ]..sort(comparar);
  }

  /// Top 25 (en realidad los 25 mejores de 32): récord, diferencia de puntos y prestigio.
  List<int> ranking() {
    final regs = registros();
    double puntos(RegistroU r) =>
        r.porcentaje * 100 +
        (r.jugados == 0 ? 0 : r.diferencia / r.jugados) * 0.8 +
        prestigioDe(r.idx) * (r.jugados == 0 ? 0.6 : 0.12);
    final orden = [...regs]..sort((a, b) => puntos(b).compareTo(puntos(a)));
    return [for (final r in orden) r.idx];
  }

  // --- Torneo ---

  /// Los 16 clasificados: los 4 campeones de conferencia y los 12 mejores récords que quedan,
  /// sembrados por récord (1 a 16).
  List<int> clasificados() {
    final regs = registros()..sort(comparar);
    final conf = conferenciaDe;
    final campeones = <int>[];
    for (var c = 0; c < 4; c++) {
      campeones.add(regs.firstWhere((r) => conf[r.idx] == c).idx);
    }
    final resto = [
      for (final r in regs)
        if (!campeones.contains(r.idx)) r.idx,
    ].take(12);
    final todos = [...campeones, ...resto];
    todos.sort((a, b) {
      final ra = regs.indexWhere((r) => r.idx == a), rb = regs.indexWhere((r) => r.idx == b);
      return ra.compareTo(rb);
    });
    return todos;
  }

  static const _llave = [(0, 15), (7, 8), (3, 12), (4, 11), (1, 14), (6, 9), (2, 13), (5, 10)];

  static const nombresRondas = ['Octavos de final', 'Cuartos de final', 'Semifinales', 'La final'];

  /// Ronda en juego (índice) o 4 si ya hay campeón.
  int get rondaActual {
    for (var r = 0; r < torneo.length; r++) {
      if (torneo[r].any((g) => g[2] == 0)) return r;
    }
    return torneo.length < 4 ? torneo.length : 4;
  }

  int? get campeon {
    if (torneo.length < 4 || torneo[3].isEmpty || torneo[3][0][2] == 0) return null;
    return _ganadorDe(torneo[3][0]);
  }

  static int _ganadorDe(List<int> g) => g[2] > g[3] ? g[0] : g[1];

  /// Tu partido pendiente de la ronda actual (o null).
  List<int>? get juegoTorneoUsuario {
    final r = rondaActual;
    if (r >= torneo.length) return null;
    for (final g in torneo[r]) {
      if (g[2] == 0 && (g[0] == 0 || g[1] == 0)) return g;
    }
    return null;
  }

  /// Hasta dónde llegó tu programa: 'Campeón', 'Final', 'Semifinal', 'Cuartos', 'Octavos' o 'Sin torneo'.
  String get resultadoTorneoUsuario {
    if (torneo.isEmpty) return 'Sin torneo';
    var llego = -1;
    for (var r = 0; r < torneo.length; r++) {
      if (torneo[r].any((g) => g[0] == 0 || g[1] == 0)) llego = r;
    }
    if (llego < 0) return 'Sin torneo';
    if (campeon == 0) return 'Campeón';
    return const ['Octavos', 'Cuartos', 'Semifinal', 'Final'][llego];
  }

  // --- Premios ---

  /// Premios de la temporada, con los jugadores de toda la liga. Determinístico.
  PremiosUniv premios() {
    final regs = registros();
    final todos = <(Estudiante, int, double)>[];
    for (var idx = 0; idx < equipos; idx++) {
      final azar = Random(hashUniv('$semilla|prem|$temporada|$idx'));
      final factor = 0.85 + 0.3 * regs[idx].porcentaje;
      for (final e in plantelDe(idx)) {
        todos.add((e, idx, e.valor * factor + _gauss(azar) * 1.2));
      }
    }
    todos.sort((a, b) => b.$3.compareTo(a.$3));
    PremioU p((Estudiante, int, double) x) => PremioU(x.$1.nombre, x.$2, x.$1.posicion, x.$1.anio, x.$3, x.$1.id);
    final novatos = todos.where((x) => x.$1.anio == 1);
    return PremiosUniv(
      mejor: p(todos.first),
      primerEquipo: [for (final x in todos.take(5)) p(x)],
      segundoEquipo: [for (final x in todos.skip(5).take(5)) p(x)],
      novato: novatos.isEmpty ? null : p(novatos.first),
    );
  }

  // --- Receso ---

  /// ¿Declara para el draft? Los de último año siempre; los demás, si pueden y el usuario lo elige.
  static bool puedeDeclarar(Estudiante e) => e.anio >= 2 && e.anio < 4 && e.media >= 72;

  /// Tu plantel del año que viene antes de reclutar: crecen todos los que siguen.
  /// [declarados]: ids que se van al draft (los de último año siempre se van).
  (List<Estudiante> quedan, List<Estudiante> seVan, Map<String, Map<Atributo, int>> cambios) pasarDeAnio(
    Set<String> declarados,
  ) {
    final seVan = [
      for (final e in plantel)
        if (e.anio >= 4 || declarados.contains(e.id)) e,
    ];
    final quedan = <Estudiante>[];
    final cambios = <String, Map<Atributo, int>>{};
    final azar = Random(hashUniv('$semilla|prog|$temporada'));
    for (final e in plantel) {
      if (seVan.contains(e)) continue;
      final nuevo = e.anio + 1;
      final base = ModeloCarrera.desarrolloNatural(18 + nuevo, azar);
      // Los de primer año ya saltan por edad en desarrolloNatural; el potencial suma un poco más.
      final extra = (e.potencial * (nuevo <= 2 ? 0.6 : 0.3)).round();
      // En la universidad se crece más despacio que en los modelos de Mi carrera (cuatro años, no veinte).
      final delta = {for (final a in Atributo.values) a: (base[a]! * 0.55).round() + extra};
      cambios[e.id] = delta;
      quedan.add(e.copyWith(atributos: e.atributos.sumar(delta), anio: nuevo, pj: 0, pts: 0, reb: 0, ast: 0));
    }
    return (quedan, seVan, cambios);
  }

  /// Los 8 reclutas de este receso (determinísticos): mejores estrellas cuanto más prestigio.
  List<Recluta> reclutas() {
    final azar = Random(hashUniv('$semilla|rec|$temporada|$prestigio'));
    final p = prestigio.toDouble();
    final pesos = [max(5, 30 - p * 0.15), max(5, 30 - p * 0.10), 25.0, 12 + p * 0.15, 3 + p * 0.08];
    final total = pesos.fold(0.0, (a, b) => a + b);
    int estrellas() {
      var x = azar.nextDouble() * total;
      for (var i = 0; i < pesos.length; i++) {
        x -= pesos[i];
        if (x <= 0) return i + 1;
      }
      return 5;
    }

    const medias = [0, 56.0, 60.0, 64.0, 68.0, 73.0];
    final lista = <Recluta>[
      for (var i = 0; i < 8; i++)
        () {
          final s = estrellas();
          final e = Estudiante.generar(
            azar,
            id: 'rec$temporada-$i',
            media: medias[s] + _gauss(azar) * 1.5,
            anio: 1,
            estrellas: s,
            potencial: min(3, (s - 1) ~/ 2 + azar.nextInt(2)),
            posicion: Posicion.titulares[(i + azar.nextInt(2)) % 5],
          );
          return Recluta(e, Recluta.precios[s]);
        }(),
    ]..sort((a, b) => b.estudiante.estrellas.compareTo(a.estudiante.estrellas));
    return lista;
  }

  /// Puntos de reclutamiento de este receso: victorias, prestigio y éxito en el torneo.
  int puntosReclutamiento() {
    final v = registros()[0].v;
    final bonus = switch (resultadoTorneoUsuario) {
      'Campeón' => 6,
      'Final' => 4,
      'Semifinal' => 3,
      'Cuartos' => 2,
      'Octavos' => 1,
      _ => 0,
    };
    return 8 + v ~/ 3 + prestigio ~/ 10 + bonus;
  }

  /// Cuadro de las elecciones del draft: tus [declarados] entran con un puntaje (media, potencial y
  /// ruido) y compiten con 30 prospectos ficticios. Devuelve las 30 elecciones.
  TablaDraft tablaDraft(List<Estudiante> declarados) {
    final azar = Random(hashUniv('$semilla|draft|$temporada'));
    final entradas = <PickDraft>[];
    for (var i = 0; i < 34; i++) {
      final e = Estudiante.generar(
        azar,
        id: 'dr$temporada-$i',
        media: 80 - i * 0.55 + _gauss(azar) * 2.0,
        anio: 3,
        estrellas: 5,
      );
      entradas.add(PickDraft(0, e.nombre, e.posicion, e.media, puntaje: e.media + e.potencial + _gauss(azar) * 1.5));
    }
    for (final e in declarados) {
      final ruido = Random(hashUniv('${e.id}|$temporada')).nextDouble() * 3 - 1.5;
      entradas.add(PickDraft(0, e.nombre, e.posicion, e.media, puntaje: e.media + e.potencial * 0.8 + ruido, id: e.id));
    }
    entradas.sort((a, b) => b.puntaje.compareTo(a.puntaje));
    return TablaDraft([for (var i = 0; i < entradas.length; i++) entradas[i].conPick(i + 1)]);
  }

  // --- JSON ---

  EstadoUniv copyWith({
    Programa? programa,
    List<Estudiante>? plantel,
    int? temporada,
    int? prestigio,
    List<int>? prestigioIA,
    FaseUniv? fase,
    int? jornada,
    List<int>? resultados,
    List<List<List<int>>>? torneo,
    List<TemporadaUniv>? historial,
    List<Egresado>? egresados,
    int? siguienteId,
  }) => EstadoUniv(
    semilla: semilla,
    programa: programa ?? this.programa,
    plantel: plantel ?? this.plantel,
    temporada: temporada ?? this.temporada,
    prestigio: (prestigio ?? this.prestigio).clamp(0, 100),
    prestigioIA: prestigioIA ?? this.prestigioIA,
    fase: fase ?? this.fase,
    jornada: jornada ?? this.jornada,
    resultados: resultados ?? this.resultados,
    torneo: torneo ?? this.torneo,
    historial: historial ?? this.historial,
    egresados: egresados ?? this.egresados,
    siguienteId: siguienteId ?? this.siguienteId,
  );

  Map<String, dynamic> toJson() => {
    's': semilla,
    'pg': programa.toJson(),
    'pl': [for (final e in plantel) e.toJson()],
    't': temporada,
    'pr': prestigio,
    'pia': prestigioIA,
    'f': fase.name,
    'j': jornada,
    'rs': resultados,
    if (torneo.isNotEmpty) 'to': torneo,
    'h': [for (final h in historial) h.toJson()],
    'eg': [for (final e in egresados) e.toJson()],
    'id': siguienteId,
  };

  factory EstadoUniv.fromJson(Map<String, dynamic> j) => EstadoUniv(
    semilla: j['s'] as int,
    programa: Programa.fromJson(j['pg'] as Map<String, dynamic>),
    plantel: [for (final e in j['pl'] as List) Estudiante.fromJson(e as Map<String, dynamic>)],
    temporada: j['t'] as int? ?? 1,
    prestigio: j['pr'] as int? ?? 30,
    prestigioIA: (j['pia'] as List?)?.cast<int>() ?? const [],
    fase: FaseUniv.values.asNameMap()[j['f']] ?? FaseUniv.regular,
    jornada: j['j'] as int? ?? 0,
    resultados: (j['rs'] as List?)?.cast<int>() ?? const [],
    torneo: [
      for (final r in j['to'] as List? ?? const []) [for (final g in r as List) (g as List).cast<int>()],
    ],
    historial: [for (final h in j['h'] as List? ?? const []) TemporadaUniv.fromJson(h as Map<String, dynamic>)],
    egresados: [for (final e in j['eg'] as List? ?? const []) Egresado.fromJson(e as Map<String, dynamic>)],
    siguienteId: j['id'] as int? ?? 1,
  );
}

/// Un premio de la temporada: quién, de qué equipo y su valor.
class PremioU {
  const PremioU(this.nombre, this.equipo, this.posicion, this.anio, this.valor, this.id);

  final String nombre, id;
  final int equipo, anio;
  final Posicion posicion;
  final double valor;
}

class PremiosUniv {
  const PremiosUniv({required this.mejor, required this.primerEquipo, required this.segundoEquipo, this.novato});

  final PremioU mejor;
  final List<PremioU> primerEquipo, segundoEquipo;
  final PremioU? novato;

  /// Los premios que ganó alguien de tu programa (equipo 0), en texto.
  List<String> deUsuario() => [
    if (mejor.equipo == 0) 'Jugador del Año: ${mejor.nombre}',
    for (final p in primerEquipo)
      if (p.equipo == 0) 'Primer equipo All-American: ${p.nombre}',
    for (final p in segundoEquipo)
      if (p.equipo == 0) 'Segundo equipo All-American: ${p.nombre}',
    if (novato != null && novato!.equipo == 0) 'Novato del Año: ${novato!.nombre}',
  ];
}

/// Una elección del draft.
class PickDraft {
  const PickDraft(this.pick, this.nombre, this.posicion, this.media, {required this.puntaje, this.id});

  /// 1 a N; 0 mientras no se ordenó.
  final int pick;
  final String nombre;
  final Posicion posicion;
  final int media;
  final double puntaje;

  /// Id del estudiante si es tuyo (null: prospecto ficticio).
  final String? id;

  bool get esTuyo => id != null;

  PickDraft conPick(int p) => PickDraft(p, nombre, posicion, media, puntaje: puntaje, id: id);
}

class TablaDraft {
  const TablaDraft(this.todos);

  final List<PickDraft> todos;

  /// Las 30 elecciones de la primera ronda.
  List<PickDraft> get primeraRonda => todos.take(30).toList();

  /// Elección de uno de los tuyos (null: no lo eligieron en la primera ronda).
  int? pickDe(String id) {
    for (final p in primeraRonda) {
      if (p.id == id) return p.pick;
    }
    return null;
  }
}

// -------------------------------------------------------------------------------------------
// Simulación
// -------------------------------------------------------------------------------------------

/// Lo que sabe jugar partidos y avanzar la temporada. Puro: devuelve estados nuevos.
class Universitario {
  const Universitario();

  /// Años de los jugadores generados de tu primer plantel (un programa con vida).
  static const _aniosInicio = [4, 3, 4, 2, 3, 2, 1];

  static const _localia = 2.5;

  /// Una partida nueva: tu programa, los jugadores que creaste (2 a 5) y el resto del plantel generado.
  EstadoUniv nueva({required int semilla, required Programa programa, required List<JugadorCreado> creados}) {
    if (creados.length < 2 || creados.length > 5) throw ArgumentError('Creá entre 2 y 5 jugadores.');
    final azar = Random(hashUniv('nueva|$semilla'));
    var id = 1;
    final plantel = <Estudiante>[for (final c in creados) Estudiante.deCreado(c, 'u${id++}')];
    // El resto: una mezcla de años (2 a 4 en su mayoría) a un nivel de programa chico.
    final cubiertos = {for (final e in plantel) e.posicion};
    var i = 0;
    while (plantel.length < EstadoUniv.plantelBase) {
      final faltan = [
        for (final p in Posicion.titulares)
          if (!cubiertos.contains(p)) p,
      ];
      final pos = faltan.isNotEmpty ? faltan.first : Posicion.titulares[i % 5];
      cubiertos.add(pos);
      plantel.add(
        Estudiante.generar(
          azar,
          id: 'u${id++}',
          media: 60 + azar.nextDouble() * 6,
          // Un programa con vida: últimos, terceros y segundos años, y algún novato.
          anio: _aniosInicio[i % 7],
          estrellas: 2 + azar.nextInt(2),
          potencial: azar.nextInt(3),
          posicion: pos,
        ),
      );
      i++;
    }
    final ia = Random(hashUniv('ia|$semilla'));
    return EstadoUniv(
      semilla: semilla,
      programa: programa,
      plantel: plantel,
      prestigioIA: [for (var k = 0; k < EstadoUniv.equipos - 1; k++) (50 + _gauss(ia) * 18).round().clamp(15, 90)],
      resultados: List.filled(EstadoUniv.jornadas * EstadoUniv.partidosPorJornada * 2, 0),
      siguienteId: id,
    );
  }

  /// Puntos de un partido entre dos equipos sin engine (los de la IA): diferencia de nivel,
  /// localía y ruido. Una unidad de nivel vale ~0,8 puntos de margen (como en el motor).
  (int, int) simularLigero(double fuerzaLocal, double fuerzaVisitante, Random azar) {
    final margen = 0.8 * (fuerzaLocal - fuerzaVisitante) + _localia + _gauss(azar) * 11;
    final total = 200 + _gauss(azar) * 12;
    var l = ((total + margen) / 2).round(), v = ((total - margen) / 2).round();
    l = max(l, 55);
    v = max(v, 55);
    if (l == v) l++;
    return (l, v);
  }

  /// El equipo para el motor: los 5 mejores como titulares (cada uno en su puesto si se puede),
  /// el sexto, y los que quedan en el banco largo.
  EquipoPartido equipo(EstadoUniv e, int idx) {
    final cartas = [for (final x in e.plantelDe(idx)) x.carta]..sort((a, b) => b.media.compareTo(a.media));
    final puestos = <Posicion, Jugador>{};
    final libres = List.of(cartas);
    final orden = [...Posicion.titulares]
      ..sort(
        (a, b) => libres
            .where((j) => j.posiciones.first == a)
            .length
            .compareTo(libres.where((j) => j.posiciones.first == b).length),
      );
    for (final p in orden) {
      final natural = libres.where((j) => j.posiciones.first == p).firstOrNull;
      final j = natural ?? libres.first;
      puestos[p] = j;
      libres.remove(j);
    }
    puestos[Posicion.sextoHombre] = libres.removeAt(0);
    final plantel = Plantel.deEmergencia(puestos);
    return EquipoPartido(
      identidadId: e.franquicia(idx).id,
      plantel: plantel,
      tactica: recomendar(PerfilPlantel.de(plantel)).tactica,
      reserva: libres.take(4).toList(),
    );
  }

  /// El partido de [juego] para el motor (se puede jugar en vivo o simular con `simularTodo`).
  MotorPartido motor(EstadoUniv e, JuegoU juego, {Random? azar}) => MotorPartido(
    local: equipo(e, juego.$1),
    visitante: equipo(e, juego.$2),
    usuarioLocal: juego.$1 == 0,
    azar:
        azar ??
        Random(hashUniv('${e.semilla}|m|${e.temporada}|${e.jornada}|${juego.$1}|${juego.$2}|${e.torneo.length}')),
  );

  /// Suma al plantel tuyo lo que hicieron en un partido (para las líneas de la temporada).
  List<Estudiante> _acumular(List<Estudiante> plantel, Map<String, LineaEstadistica> box) => [
    for (final p in plantel)
      if (box[p.id] case final l? when l.pj > 0)
        p.copyWith(pj: p.pj + 1, pts: p.pts + l.pts, reb: p.reb + l.reb, ast: p.ast + l.ast)
      else
        p,
  ];

  /// Juega la jornada actual. Tu partido sale de [motorUsuario] ya jugado (en vivo) o se simula con
  /// el motor. Los demás, con el modelo ligero.
  EstadoUniv simularJornada(EstadoUniv e, {MotorPartido? motorUsuario}) {
    if (e.fase != FaseUniv.regular || e.jornada >= EstadoUniv.jornadas) return e;
    final cal = e.calendario();
    final azar = Random(hashUniv('${e.semilla}|j|${e.temporada}|${e.jornada}'));
    final resultados = List.of(e.resultados);
    if (resultados.length < EstadoUniv.jornadas * EstadoUniv.partidosPorJornada * 2) {
      resultados.addAll(List.filled(EstadoUniv.jornadas * EstadoUniv.partidosPorJornada * 2 - resultados.length, 0));
    }
    var plantel = e.plantel;
    final fuerzas = {for (var i = 0; i < EstadoUniv.equipos; i++) i: EstadoUniv.fuerzaDe(e.plantelDe(i))};
    for (var i = 0; i < cal[e.jornada].length; i++) {
      final (l, v) = cal[e.jornada][i];
      final pesos = (e.jornada * EstadoUniv.partidosPorJornada + i) * 2;
      if (l == 0 || v == 0) {
        final m = motorUsuario ?? (motor(e, (l, v))..simularTodo());
        if (!m.terminado) m.simularTodo();
        resultados[pesos] = m.puntosLocal;
        resultados[pesos + 1] = m.puntosVisitante;
        plantel = _acumular(plantel, l == 0 ? m.boxLocal : m.boxVisitante);
      } else {
        final (pl, pv) = simularLigero(fuerzas[l]!, fuerzas[v]!, azar);
        resultados[pesos] = pl;
        resultados[pesos + 1] = pv;
      }
    }
    final nueva = e.copyWith(plantel: plantel, resultados: resultados, jornada: e.jornada + 1);
    return nueva.jornada >= EstadoUniv.jornadas ? _abrirTorneo(nueva) : nueva;
  }

  /// Juega [n] jornadas seguidas (tus partidos se simulan con el motor).
  EstadoUniv simularJornadas(EstadoUniv e, int n) {
    var x = e;
    for (var i = 0; i < n && x.fase == FaseUniv.regular; i++) {
      x = simularJornada(x);
    }
    return x;
  }

  EstadoUniv _abrirTorneo(EstadoUniv e) {
    final clas = e.clasificados();
    final r0 = [
      for (final (a, b) in EstadoUniv._llave) [clas[a], clas[b], 0, 0],
    ];
    return e.copyWith(fase: FaseUniv.torneo, torneo: [r0]);
  }

  /// Juega la ronda actual del torneo (un partido por llave). Tu partido, en vivo o simulado.
  EstadoUniv simularRonda(EstadoUniv e, {MotorPartido? motorUsuario}) {
    if (e.fase != FaseUniv.torneo) return e;
    final r = e.rondaActual;
    if (r >= 4) return _cerrarTorneo(e);
    final azar = Random(hashUniv('${e.semilla}|t|${e.temporada}|$r'));
    final ronda = [for (final g in e.torneo[r]) List.of(g)];
    var plantel = e.plantel;
    for (final g in ronda) {
      if (g[2] != 0) continue;
      if (g[0] == 0 || g[1] == 0) {
        final m = motorUsuario ?? (motor(e, (g[0], g[1]))..simularTodo());
        if (!m.terminado) m.simularTodo();
        g[2] = m.puntosLocal;
        g[3] = m.puntosVisitante;
        plantel = _acumular(plantel, g[0] == 0 ? m.boxLocal : m.boxVisitante);
      } else {
        final (pl, pv) = simularLigero(
          EstadoUniv.fuerzaDe(e.plantelDe(g[0])),
          EstadoUniv.fuerzaDe(e.plantelDe(g[1])),
          azar,
        );
        g[2] = pl;
        g[3] = pv;
      }
    }
    final rondas = [...e.torneo.take(r), ronda];
    // Si la ronda quedó completa, arma la siguiente con los ganadores.
    if (r < 3) {
      final ganadores = [for (final g in ronda) EstadoUniv._ganadorDe(g)];
      rondas.add([
        for (var i = 0; i < ganadores.length; i += 2) [ganadores[i], ganadores[i + 1], 0, 0],
      ]);
    }
    final nueva = e.copyWith(plantel: plantel, torneo: rondas);
    return nueva.campeon != null ? _cerrarTorneo(nueva) : nueva;
  }

  /// Simula todo el torneo (tu partido, si te toca, con el motor).
  EstadoUniv simularTorneo(EstadoUniv e) {
    var x = e;
    var guarda = 0;
    while (x.fase == FaseUniv.torneo && guarda++ < 8) {
      x = simularRonda(x);
    }
    return x;
  }

  EstadoUniv _cerrarTorneo(EstadoUniv e) => e.fase == FaseUniv.torneo ? e.copyWith(fase: FaseUniv.premios) : e;

  /// Cierra la temporada: guarda su resumen, mueve el prestigio de todos y pasa al receso.
  /// Los picks se completan después, al cerrar el receso ([cerrarReceso]).
  EstadoUniv cerrarTemporada(EstadoUniv e) {
    if (e.fase != FaseUniv.premios) return e;
    final regs = e.registros();
    final mia = regs[0];
    final conf = e.conferenciaDe;
    final tabla = e.tablaConferencia(conf[0]);
    final puesto = tabla.indexWhere((r) => r.idx == 0) + 1;
    final premios = e.premios();
    final campeon = e.campeon == 0;
    final resumen = TemporadaUniv(
      numero: e.temporada,
      v: mia.v,
      d: mia.d,
      puestoConferencia: puesto,
      torneo: e.resultadoTorneoUsuario,
      campeon: campeon,
      premios: premios.deUsuario(),
    );
    // Prestigio: tu récord y el torneo suben o bajan tu programa; los de la IA se mueven con su récord.
    final bonusTorneo = switch (resumen.torneo) {
      'Campeón' => 12,
      'Final' => 7,
      'Semifinal' => 5,
      'Cuartos' => 3,
      'Octavos' => 1,
      _ => 0,
    };
    final nuevoPrestigio = (e.prestigio + ((mia.v - 15) * 0.9).round() + bonusTorneo - (e.prestigio - 45) ~/ 8).clamp(
      0,
      100,
    );
    final azar = Random(hashUniv('${e.semilla}|pia|${e.temporada}'));
    final ia = [
      for (var i = 1; i < EstadoUniv.equipos; i++)
        (e.prestigioDe(i) +
                ((regs[i].porcentaje - 0.5) * 14).round() +
                (_gauss(azar) * 3).round() -
                (e.prestigioDe(i) - 50) ~/ 10)
            .clamp(10, 95),
    ];
    return e.copyWith(
      fase: FaseUniv.receso,
      prestigio: nuevoPrestigio,
      prestigioIA: ia,
      historial: [...e.historial, resumen],
    );
  }

  /// Cierra el receso: los que se van al draft, los reclutas firmados y la temporada que sigue.
  /// [declarados]: ids de los que entran al draft además de los de último año.
  /// [firmados]: reclutas elegidos (ya pagados con los puntos).
  EstadoUniv cerrarReceso(EstadoUniv e, {required Set<String> declarados, required List<Recluta> firmados}) {
    if (e.fase != FaseUniv.receso) return e;
    final (quedan, seVan, _) = e.pasarDeAnio(declarados);
    final tabla = e.tablaDraft(seVan);
    // Los que se van: pick y Salón.
    final egresados = [
      ...e.egresados,
      for (final s in seVan)
        Egresado(
          nombre: s.nombre,
          posicion: s.posicion,
          rol: s.rol,
          atributos: s.atributos,
          alturaCm: s.alturaCm,
          pesoKg: s.pesoKg,
          temporada: e.temporada,
          anios: s.anio,
          media: s.media,
          pick: tabla.pickDe(s.id),
          creado: s.creado,
        ),
    ];
    final picks = [
      for (final s in seVan) '${s.nombre} · ${tabla.pickDe(s.id) == null ? 'sin draft' : 'pick ${tabla.pickDe(s.id)}'}',
    ];
    final historial = [
      for (final h in e.historial)
        h.numero == e.temporada
            ? TemporadaUniv(
                numero: h.numero,
                v: h.v,
                d: h.d,
                puestoConferencia: h.puestoConferencia,
                torneo: h.torneo,
                campeon: h.campeon,
                premios: h.premios,
                picks: picks,
              )
            : h,
    ];
    var id = e.siguienteId;
    final plantel = [...quedan];
    for (final r in firmados) {
      if (plantel.length >= EstadoUniv.plantelMax) break;
      plantel.add(
        Estudiante(
          id: 'u${id++}',
          nombre: r.estudiante.nombre,
          posicion: r.estudiante.posicion,
          rol: r.estudiante.rol,
          atributos: r.estudiante.atributos,
          alturaCm: r.estudiante.alturaCm,
          pesoKg: r.estudiante.pesoKg,
          anio: 1,
          estrellas: r.estudiante.estrellas,
          potencial: r.estudiante.potencial,
        ),
      );
    }
    // Si faltan jugadores, entran estudiantes sin beca (1 estrella) para llegar al mínimo.
    final azar = Random(hashUniv('${e.semilla}|extra|${e.temporada}'));
    while (plantel.length < EstadoUniv.plantelMin) {
      final cuentan = {for (final p in Posicion.titulares) p: plantel.where((x) => x.posicion == p).length};
      final pos = Posicion.titulares.reduce((a, b) => cuentan[a]! <= cuentan[b]! ? a : b);
      plantel.add(
        Estudiante.generar(
          azar,
          id: 'u${id++}',
          media: 56 + azar.nextDouble() * 4,
          anio: 1,
          estrellas: 1,
          posicion: pos,
        ),
      );
    }
    return e.copyWith(
      plantel: plantel,
      temporada: e.temporada + 1,
      fase: FaseUniv.regular,
      jornada: 0,
      resultados: List.filled(EstadoUniv.jornadas * EstadoUniv.partidosPorJornada * 2, 0),
      torneo: const [],
      historial: historial,
      egresados: egresados,
      siguienteId: id,
    );
  }
}

// -------------------------------------------------------------------------------------------
// Metajuego
// -------------------------------------------------------------------------------------------

const _xpVictoriaUniv = 15, _monedasVictoriaUniv = 3;

/// XP y monedas por cada victoria tuya, y el título nacional (logro). Sin cartas para el álbum:
/// los jugadores son ficticios.
(PerfilEntrenador, List<Novedad>) premiarUniversitario(PerfilEntrenador perfil, Temporada antes, Temporada despues) {
  final a = EstadoUniv.de(antes), d = EstadoUniv.de(despues);
  if (d == null) return (perfil, const []);
  var p = perfil;
  final novedades = <Novedad>[];
  // Victorias nuevas (regular y torneo).
  int victorias(EstadoUniv? e) {
    if (e == null) return 0;
    var v = e.registros()[0].v;
    for (final r in e.torneo) {
      for (final g in r) {
        if (g[2] != 0 && ((g[0] == 0 && g[2] > g[3]) || (g[1] == 0 && g[3] > g[2]))) v++;
      }
    }
    return v;
  }

  // Al pasar de temporada el contador de la nueva arranca en 0: sin victorias nuevas ese paso.
  final nuevas = (a != null && a.temporada == d.temporada) ? victorias(d) - victorias(a) : 0;
  if (nuevas > 0) {
    final xp = nuevas * _xpVictoriaUniv, monedas = nuevas * _monedasVictoriaUniv;
    p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
    novedades.add(Novedad('+$xp XP · +$monedas monedas'));
  }
  final titulosAntes = a?.titulos ?? 0;
  if (d.titulos > titulosAntes) {
    p = p.copyWith(xp: p.xp + 400, monedas: p.monedas + 150);
    novedades.add(const Novedad('¡Campeón nacional!', detalle: '+400 XP · +150 monedas', destacada: true));
    if (!p.logros.containsKey(Logro.campeonNacional)) {
      p = p.copyWith(logros: {...p.logros, Logro.campeonNacional: DateTime.now().millisecondsSinceEpoch});
    }
  }
  return (p, novedades);
}
