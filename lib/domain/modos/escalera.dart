import 'dart:math';

import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/tactica.dart';
import '../entities/temporada.dart';
import '../liga.dart';
import '../modificadores.dart';
import '../motor.dart';
import '../playbook.dart';
import '../quimica.dart';

/// Rival de un modo de escalera: un plantel armado a medida (no es una franquicia de la liga).
class RivalEscalera {
  const RivalEscalera({
    required this.identidadId,
    required this.etiqueta,
    required this.cartaIds,
    required this.tactica,
    required this.media,
  });

  /// Con qué escudo y colores juega ('CHI', 'SEA'…).
  final String identidadId;

  /// Lo que va después del nombre: "1995-96", "(90’)" o "(Histórico)".
  final String etiqueta;
  final Map<Posicion, String> cartaIds;
  final Tactica tactica;

  /// Media del plantel (promedio de los 6), para mostrar y sembrar.
  final double media;

  factory RivalEscalera.fromJson(Map<String, dynamic> j) => RivalEscalera(
    identidadId: j['identidad'] as String,
    etiqueta: j['etiqueta'] as String,
    cartaIds: {
      for (final e in (j['cartas'] as Map<String, dynamic>).entries) Posicion.values.byName(e.key): e.value as String,
    },
    tactica: Tactica.fromJson(j['tactica'] as Map<String, dynamic>),
    media: (j['media'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'identidad': identidadId,
    'etiqueta': etiqueta,
    'cartas': {for (final e in cartaIds.entries) e.key.name: e.value},
    'tactica': tactica.toJson(),
    'media': media,
  };
}

/// Un cruce del usuario: partido único o serie (al mejor de 3, 5 o 7), que puede arrancar con un
/// marcador dado (escenarios).
class Cruce {
  const Cruce({
    required this.rival,
    required this.titulo,
    this.aGanar = 1,
    this.propias = 0,
    this.ajenas = 0,
    this.usuarioAlto = true,
    this.marcadores = const [],
    this.dosTresDos = false,
  });

  final RivalEscalera rival;

  /// "Escalón 3 de 10", "16avos de final", "Las Finales 1998"…
  final String titulo;

  /// Victorias para ganar el cruce (1: partido único; 4: al mejor de 7).
  final int aGanar;
  final int propias, ajenas;

  /// El usuario tiene la ventaja de localía.
  final bool usuarioAlto;

  /// Marcador de cada partido jugado en este cruce: (tus puntos, los del rival).
  final List<(int, int)> marcadores;

  /// Localías 2-3-2 (las Finales de 1985 a 2013) en vez de 2-2-1-1-1.
  final bool dosTresDos;

  bool get terminado => propias >= aGanar || ajenas >= aGanar;
  bool get ganado => propias >= aGanar;
  int get juego => propias + ajenas;
  bool get esSerie => aGanar > 1;

  /// Local del próximo partido: el mejor sembrado abre (2-2-1-1-1 en las de 7; 2-2-1 en las de 5).
  bool get usuarioLocalProximo {
    final altoLocal = switch (aGanar) {
      1 => true,
      2 => juego != 1,
      3 => const {0, 1, 4}.contains(juego),
      _ => (dosTresDos ? const {0, 1, 5, 6} : const {0, 1, 4, 6}).contains(juego),
    };
    return altoLocal == usuarioAlto;
  }

  Cruce conResultado(int mios, int suyos) => Cruce(
    rival: rival,
    titulo: titulo,
    aGanar: aGanar,
    propias: propias + (mios > suyos ? 1 : 0),
    ajenas: ajenas + (mios > suyos ? 0 : 1),
    usuarioAlto: usuarioAlto,
    marcadores: [...marcadores, (mios, suyos)],
    dosTresDos: dosTresDos,
  );

  factory Cruce.fromJson(Map<String, dynamic> j) => Cruce(
    rival: RivalEscalera.fromJson(j['rival'] as Map<String, dynamic>),
    titulo: j['titulo'] as String,
    aGanar: j['aGanar'] as int? ?? 1,
    propias: j['propias'] as int? ?? 0,
    ajenas: j['ajenas'] as int? ?? 0,
    usuarioAlto: j['alto'] as bool? ?? true,
    marcadores: [for (final m in j['marcadores'] as List? ?? const []) ((m as List)[0] as int, m[1] as int)],
    dosTresDos: j['232'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'rival': rival.toJson(),
    'titulo': titulo,
    'aGanar': aGanar,
    'propias': propias,
    'ajenas': ajenas,
    'alto': usuarioAlto,
    if (dosTresDos) '232': true,
    'marcadores': [
      for (final (a, b) in marcadores) [a, b],
    ],
  };
}

/// Insignias tácticas del Camino al anillo: después de cada escalón ganado elegís 1 de 3, quedan
/// para todo el camino y se suman entre sí. Varias rinden de verdad solo si tu plantel tiene con qué
/// (si no, dan una versión chica): así elegís según tu armado.
enum InsigniaCamino {
  showtime('Showtime', 'Más contraataques después de cada robo o rebote defensivo.', 'un base que reparta (7+ asistencias)'),
  badBoys('Bad Boys', 'Defensa física: el rival se cansa más rápido.', null),
  zonaProhibida('Zona prohibida', 'El rival tira peor cerca del aro.', '2 taponadores (2+ tapas)'),
  pizarron('Pizarrón de Popovich', 'Los tiros con asistencia entran más.', '3 jugadores de IQ 88 o más'),
  splash('Splash', 'Tus triples entran más.', '2 tiradores (37 % o más de triple)'),
  sangreFria('Sangre fría', 'Todo tu equipo tira mejor en el clutch.', null),
  bancoProfundo('Banco profundo', 'Tus jugadores se cansan menos.', null),
  quimica('Química de vestuario', 'Un poco más de acierto para todos.', 'química de 60 o más'),
  mamba('Mamba mentality', 'Tu máximo anotador se agranda en el último cuarto.', null),
  manosRapidas('Manos rápidas', 'Tu defensa fuerza más pérdidas.', '2 ladrones (1,5+ robos)'),
  segundaChance('Segunda chance', 'Más rebotes ofensivos.', '2 reboteadores (9+ rebotes)'),
  refuerzo('Refuerzo', 'Fichás un suplente para el banco largo.', null);

  const InsigniaCamino(this.nombre, this.descripcion, this.requisito);
  final String nombre;
  final String descripcion;

  /// Qué necesita tu plantel para el efecto completo (null: siempre completo).
  final String? requisito;

  /// ¿Tu plantel cumple el requisito?
  bool cumple(Iterable<Jugador> js) {
    int cuantos(bool Function(Jugador) f) => js.where(f).length;
    return switch (this) {
      showtime => cuantos((j) => j.stats.app >= 7) >= 1,
      zonaProhibida => cuantos((j) => j.stats.tapP >= 2.0) >= 2,
      pizarron => cuantos((j) => j.stats.iq >= 88) >= 3,
      splash => cuantos((j) => j.stats.pctT3 >= 0.37) >= 2,
      quimica => Quimica.de(js).puntaje >= 60,
      manosRapidas => cuantos((j) => j.stats.robP >= 1.5) >= 2,
      segundaChance => cuantos((j) => j.stats.rpp >= 9) >= 2,
      _ => true,
    };
  }

  /// Efecto en el partido (completo o la versión chica si el plantel no cumple el requisito).
  ModificadoresEquipo efecto(Iterable<Jugador> js) {
    final ok = cumple(js);
    return switch (this) {
      showtime => ModificadoresEquipo(contraataqueFactor: ok ? 1.8 : 1.3),
      badBoys => const ModificadoresEquipo(fatigaRivalFactor: 1.25),
      zonaProhibida => ModificadoresEquipo(interiorRival: ok ? 0.045 : 0.015),
      pizarron => ModificadoresEquipo(asistidoExtra: ok ? 0.045 : 0.015),
      splash => ModificadoresEquipo(tripleExtra: ok ? 0.04 : 0.015),
      sangreFria => const ModificadoresEquipo(clutchExtra: 0.06),
      bancoProfundo => const ModificadoresEquipo(fatigaFactor: 0.75),
      quimica => ModificadoresEquipo(quimicaExtra: ok ? 0.025 : 0.01),
      mamba => const ModificadoresEquipo(estrellaCuartoFinal: 0.08),
      manosRapidas => ModificadoresEquipo(robosFactor: ok ? 1.35 : 1.12),
      segundaChance => ModificadoresEquipo(reboteOfensivoFactor: ok ? 1.4 : 1.15),
      refuerzo => ModificadoresEquipo.neutros,
    };
  }

  /// El efecto en palabras, con números ("+3 % en triples").
  String detalle(Iterable<Jugador> js) {
    final ok = cumple(js);
    String pct(double x) {
      final v = (x * 100).abs();
      return '${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(1).replaceAll('.', ',')} %';
    }

    final m = efecto(js);
    final texto = switch (this) {
      showtime => '+${pct(m.contraataqueFactor - 1)} de contraataques',
      badBoys => 'el rival se cansa ${pct(m.fatigaRivalFactor - 1)} más',
      zonaProhibida => '−${pct(m.interiorRival)} al doble del rival',
      pizarron => '+${pct(m.asistidoExtra)} en tiros asistidos',
      splash => '+${pct(m.tripleExtra)} en triples',
      sangreFria => '+${pct(m.clutchExtra)} en el clutch',
      bancoProfundo => '${pct(1 - m.fatigaFactor)} menos de cansancio',
      quimica => '+${pct(m.quimicaExtra)} de acierto',
      mamba => '+${pct(m.estrellaCuartoFinal)} a tu figura en el último cuarto',
      manosRapidas => '+${pct(m.robosFactor - 1)} de pérdidas del rival',
      segundaChance => '+${pct(m.reboteOfensivoFactor - 1)} de rebotes ofensivos',
      refuerzo => 'un suplente más',
    };
    if (requisito == null) return texto;
    return ok ? '$texto (completo: tenés $requisito)' : '$texto (versión chica: falta $requisito)';
  }

  /// Todas las insignias juntas.
  static ModificadoresEquipo suma(Iterable<InsigniaCamino> insignias, Iterable<Jugador> js) =>
      insignias.fold(ModificadoresEquipo.neutros, (m, i) => m.mas(i.efecto(js)));
}

/// Ventajas del Camino al anillo de antes de las insignias (solo para partidas guardadas).
enum VentajaCamino {
  inspiracion('Arenga', '+3 de media a todo tu plantel en el próximo partido.'),
  figura('Momento de gloria', '+3 de media a tu mejor jugador por el resto del camino.'),
  quimica('Química de vestuario', '+1 de media a todo tu plantel por el resto del camino.'),
  refuerzo('Refuerzo', 'Fichás un suplente para el banco largo.'),
  piernasFrescas('Rival trasnochado', 'El próximo rival arranca cansado (92 de energía).'),
  scouting('Video del rival', 'Le conocés todas las jugadas: −2 de media al próximo rival.');

  const VentajaCamino(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Momento real para reescribir: tu plantel y el rival son los históricos y la serie arranca con
/// el marcador de verdad.
class Escenario {
  const Escenario({
    required this.id,
    required this.titulo,
    required this.relato,
    required this.usuario,
    required this.rival,
    required this.propias,
    required this.ajenas,
    required this.usuarioAlto,
    this.dosTresDos = false,
  });

  final String id;
  final String titulo;
  final String relato;
  final EquipoHistorico usuario, rival;
  final int propias, ajenas;
  final bool usuarioAlto;
  final bool dosTresDos;
}

/// Plantel de un año concreto: franquicia + década del catálogo y los nombres del núcleo real
/// (los que falten se completan con los mejores de esa franquicia y década).
class EquipoHistorico {
  const EquipoHistorico(this.franquiciaId, this.identidadId, this.epoca, this.etiqueta, this.nucleo);

  final String franquiciaId;
  final String identidadId;
  final Epoca epoca;
  final String etiqueta;
  final List<String> nucleo;
}

/// Los mejores equipos de la historia, de menor a mayor (los Bulls de las 72 victorias, al final).
const mejoresEquipos = <EquipoHistorico>[
  EquipoHistorico('LAL', 'LAL', Epoca.anios2000, '2000-01', [
    'Derek Fisher',
    'Kobe Bryant',
    'Rick Fox',
    'Horace Grant',
    "Shaquille O'Neal",
    'Robert Horry',
  ]),
  EquipoHistorico('SAS', 'SAS', Epoca.anios2010, '2013-14', [
    'Tony Parker',
    'Danny Green',
    'Kawhi Leonard',
    'Tim Duncan',
    'Tiago Splitter',
    'Manu Ginóbili',
    'Boris Diaw',
  ]),
  EquipoHistorico('MIA', 'MIA', Epoca.anios2010, '2012-13', [
    'Mario Chalmers',
    'Dwyane Wade',
    'LeBron James',
    'Udonis Haslem',
    'Chris Bosh',
    'Ray Allen',
    'Shane Battier',
  ]),
  EquipoHistorico('DET', 'DET', Epoca.anios80, '1988-89', [
    'Isiah Thomas',
    'Joe Dumars',
    'Bill Laimbeer',
    'Rick Mahorn',
    'Mark Aguirre',
    'Dennis Rodman',
    'Vinnie Johnson',
  ]),
  EquipoHistorico('MIL', 'MIL', Epoca.anios70, '1970-71', [
    'Kareem Abdul-Jabbar',
    'Oscar Robertson',
    'Bob Dandridge',
    'Jon McGlocklin',
    'Greg Smith',
    'Lucius Allen',
  ]),
  EquipoHistorico('PHI', 'PHI', Epoca.anios80, '1982-83', [
    'Moses Malone',
    'Julius Erving',
    'Maurice Cheeks',
    'Andrew Toney',
    'Marc Iavaroni',
    'Bobby Jones',
  ]),
  EquipoHistorico('BOS', 'BOS', Epoca.anios80, '1985-86', [
    'Dennis Johnson',
    'Danny Ainge',
    'Larry Bird',
    'Kevin McHale',
    'Robert Parish',
    'Bill Walton',
  ]),
  EquipoHistorico('LAL', 'LAL', Epoca.anios80, '1986-87', [
    'Magic Johnson',
    'Byron Scott',
    'James Worthy',
    'A.C. Green',
    'Kareem Abdul-Jabbar',
    'Michael Cooper',
    'Mychal Thompson',
  ]),
  EquipoHistorico('GSW', 'GSW', Epoca.anios2010, '2016-17', [
    'Stephen Curry',
    'Klay Thompson',
    'Kevin Durant',
    'Draymond Green',
    'Zaza Pachulia',
    'Andre Iguodala',
  ]),
  EquipoHistorico('CHI', 'CHI', Epoca.anios90, '1995-96', [
    'Ron Harper',
    'Michael Jordan',
    'Scottie Pippen',
    'Dennis Rodman',
    'Luc Longley',
    'Toni Kukoč',
  ]),
];

const _bulls98 = EquipoHistorico('CHI', 'CHI', Epoca.anios90, '1997-98', [
  'Ron Harper',
  'Michael Jordan',
  'Scottie Pippen',
  'Dennis Rodman',
  'Luc Longley',
  'Toni Kukoč',
]);

/// Escenarios históricos.
const escenarios = <Escenario>[
  Escenario(
    id: 'finales98',
    titulo: 'Finales 1998: Juego 6',
    relato:
        'Los Bulls ganan 3-2 y el sexto es en Salt Lake City. Forzá el séptimo y dales a Stockton y '
        'Malone el anillo que se les escapó.',
    usuario: EquipoHistorico('UTA', 'UTA', Epoca.anios90, '1997-98', [
      'John Stockton',
      'Jeff Hornacek',
      'Bryon Russell',
      'Karl Malone',
      'Greg Ostertag',
      'Howard Eisley',
    ]),
    rival: _bulls98,
    propias: 2,
    ajenas: 3,
    usuarioAlto: true,
    dosTresDos: true,
  ),
  Escenario(
    id: 'finales16',
    titulo: 'Finales 2016: abajo 1-3',
    relato: 'Nadie había remontado un 1-3 en unas Finales. Los Warriors de las 73 victorias te esperan.',
    usuario: EquipoHistorico('CLE', 'CLE', Epoca.anios2010, '2015-16', [
      'Kyrie Irving',
      'J.R. Smith',
      'LeBron James',
      'Kevin Love',
      'Tristan Thompson',
      'Richard Jefferson',
    ]),
    rival: EquipoHistorico('GSW', 'GSW', Epoca.anios2010, '2015-16', [
      'Stephen Curry',
      'Klay Thompson',
      'Harrison Barnes',
      'Draymond Green',
      'Andrew Bogut',
      'Andre Iguodala',
    ]),
    propias: 1,
    ajenas: 3,
    usuarioAlto: false,
  ),
  Escenario(
    id: 'finales93',
    titulo: 'Finales 1993: Juego 6',
    relato: 'Barkley es el MVP, pero Jordan va por el tricampeonato. Abajo 2-3, en Phoenix.',
    usuario: EquipoHistorico('PHX', 'PHX', Epoca.anios90, '1992-93', [
      'Kevin Johnson',
      'Dan Majerle',
      'Richard Dumas',
      'Charles Barkley',
      'Mark West',
      'Danny Ainge',
    ]),
    rival: EquipoHistorico('CHI', 'CHI', Epoca.anios90, '1992-93', [
      'B.J. Armstrong',
      'Michael Jordan',
      'Scottie Pippen',
      'Horace Grant',
      'Bill Cartwright',
      'John Paxson',
    ]),
    propias: 2,
    ajenas: 3,
    usuarioAlto: true,
    dosTresDos: true,
  ),
  Escenario(
    id: 'finales84',
    titulo: 'Finales 1984: Juego 7',
    relato: 'Magic contra Bird, 3-3, séptimo partido en el Boston Garden. Un partido, todo o nada.',
    usuario: EquipoHistorico('LAL', 'LAL', Epoca.anios80, '1983-84', [
      'Magic Johnson',
      'Byron Scott',
      'Jamaal Wilkes',
      'James Worthy',
      'Kareem Abdul-Jabbar',
      'Michael Cooper',
    ]),
    rival: EquipoHistorico('BOS', 'BOS', Epoca.anios80, '1983-84', [
      'Dennis Johnson',
      'Gerald Henderson',
      'Larry Bird',
      'Kevin McHale',
      'Robert Parish',
      'Cedric Maxwell',
    ]),
    propias: 3,
    ajenas: 3,
    usuarioAlto: false,
  ),
  Escenario(
    id: 'finales13',
    titulo: 'Finales 2013: a 28 segundos',
    relato: 'Los Spurs ganan 3-2 y van a Miami. Esta vez no se te escapa: cerrá la serie.',
    usuario: EquipoHistorico('SAS', 'SAS', Epoca.anios2010, '2012-13', [
      'Tony Parker',
      'Danny Green',
      'Kawhi Leonard',
      'Tim Duncan',
      'Tiago Splitter',
      'Manu Ginóbili',
    ]),
    rival: EquipoHistorico('MIA', 'MIA', Epoca.anios2010, '2012-13', [
      'Mario Chalmers',
      'Dwyane Wade',
      'LeBron James',
      'Udonis Haslem',
      'Chris Bosh',
      'Ray Allen',
    ]),
    propias: 3,
    ajenas: 2,
    usuarioAlto: false,
    dosTresDos: true,
  ),
  Escenario(
    id: 'oeste02',
    titulo: 'Final del Oeste 2002: Juego 7',
    relato: 'Los Kings de Webber y Bibby contra los Lakers de Shaq y Kobe. 3-3 y el séptimo es en Sacramento.',
    usuario: EquipoHistorico('SAC', 'SAC', Epoca.anios2000, '2001-02', [
      'Mike Bibby',
      'Doug Christie',
      'Peja Stojaković',
      'Chris Webber',
      'Vlade Divac',
      'Bobby Jackson',
    ]),
    rival: EquipoHistorico('LAL', 'LAL', Epoca.anios2000, '2001-02', [
      'Derek Fisher',
      'Kobe Bryant',
      'Rick Fox',
      'Robert Horry',
      "Shaquille O'Neal",
      'Devean George',
    ]),
    propias: 3,
    ajenas: 3,
    usuarioAlto: true,
  ),
  Escenario(
    id: 'finales06',
    titulo: 'Finales 2006: Juego 6',
    relato: 'Dallas ganaba 2-0 y perdió tres seguidos. Vuelve a casa abajo 2-3: dale a Dirk su revancha.',
    usuario: EquipoHistorico('DAL', 'DAL', Epoca.anios2000, '2005-06', [
      'Jason Terry',
      'Devin Harris',
      'Josh Howard',
      'Dirk Nowitzki',
      'Erick Dampier',
      'Jerry Stackhouse',
    ]),
    rival: EquipoHistorico('MIA', 'MIA', Epoca.anios2000, '2005-06', [
      'Jason Williams',
      'Dwyane Wade',
      'Antoine Walker',
      'Udonis Haslem',
      "Shaquille O'Neal",
      'Gary Payton',
    ]),
    propias: 2,
    ajenas: 3,
    usuarioAlto: true,
    dosTresDos: true,
  ),
  Escenario(
    id: 'finales94',
    titulo: 'Finales 1994: Juego 7',
    relato: 'Ewing contra Hakeem, 3-3, séptimo en Houston. Los Knicks no ganan desde 1973.',
    usuario: EquipoHistorico('NYK', 'NYK', Epoca.anios90, '1993-94', [
      'Derek Harper',
      'John Starks',
      'Charles Oakley',
      'Charles Smith',
      'Patrick Ewing',
      'Anthony Mason',
    ]),
    rival: EquipoHistorico('HOU', 'HOU', Epoca.anios90, '1993-94', [
      'Kenny Smith',
      'Vernon Maxwell',
      'Robert Horry',
      'Otis Thorpe',
      'Hakeem Olajuwon',
      'Sam Cassell',
    ]),
    propias: 3,
    ajenas: 3,
    usuarioAlto: false,
    dosTresDos: true,
  ),
];

Escenario? escenarioPorId(String? id) {
  for (final e in escenarios) {
    if (e.id == id) return e;
  }
  return null;
}

/// Estado de un modo de escalera, guardado en [Temporada.datosModo].
class Escalera {
  const Escalera({
    this.cruces = const [],
    this.total,
    this.ofrecidas = const [],
    this.elegidas = const [],
    this.insignias = const [],
    this.insigniasOfrecidas = const [],
    this.bonusPlantel = const {},
    this.bonusProximo = 0,
    this.rivalCansado = false,
    this.rivalDebil = 0,
    this.escenarioId,
    this.cuadro = const [],
    this.ganadores = const [],
    this.marcadoresCuadro = const [],
  });

  final List<Cruce> cruces;

  /// Cruces para completar el modo (null: infinita, como la racha).
  final int? total;

  // ── Camino al anillo ──
  /// Ventajas que esperan que elijas una (vacío: no hay elección pendiente).
  final List<VentajaCamino> ofrecidas;
  final List<VentajaCamino> elegidas;

  /// Insignias ganadas (se suman entre sí) y las 3 que esperan que elijas una.
  final List<InsigniaCamino> insignias;
  final List<InsigniaCamino> insigniasOfrecidas;

  /// Media extra de tus cartas por el resto del camino (id de carta → bonus).
  final Map<String, int> bonusPlantel;

  /// Media extra de todo tu plantel solo en el próximo partido.
  final int bonusProximo;
  final bool rivalCansado;
  final int rivalDebil;

  // ── Escenarios ──
  final String? escenarioId;

  // ── Mundial de franquicias ──
  /// Los 32 del cuadro en orden de llaves (null: tu equipo).
  final List<RivalEscalera?> cuadro;

  /// Ganadores de cada ronda (índices de [cuadro]): 16, 8, 4, 2, 1.
  final List<List<int>> ganadores;

  /// Marcador de cada llave de cada ronda ("112-104"; en series, "2-1").
  final List<List<String>> marcadoresCuadro;

  static const clave = 'escalera';

  static Escalera de(Temporada t) =>
      t.datosModo[clave] == null ? const Escalera() : Escalera.fromJson(t.datosModo[clave] as Map<String, dynamic>);

  Temporada en(Temporada t) => t.copyWith(datosModo: {...t.datosModo, clave: toJson()});

  bool get iniciada => cruces.isNotEmpty;
  Cruce? get actual => cruces.isEmpty ? null : cruces.last;

  /// Perdiste un cruce: se terminó.
  bool get eliminado => cruces.any((c) => c.terminado && !c.ganado);

  /// Ganaste todo lo que había que ganar.
  bool get completada {
    if (eliminado || total == null) return false;
    if (cuadro.isNotEmpty) return ganadores.length == 5 && cuadro[ganadores.last.first] == null;
    return cruces.where((c) => c.ganado).length >= total!;
  }

  bool get terminada => eliminado || completada;
  bool get esperandoVentaja => ofrecidas.isNotEmpty || insigniasOfrecidas.isNotEmpty;

  /// Cruce que se puede jugar ahora (null si el modo terminó o espera que elijas una ventaja).
  Cruce? get pendiente {
    final c = actual;
    if (c == null || c.terminado || esperandoVentaja) return null;
    return c;
  }

  int get victorias => cruces.fold(0, (a, c) => a + c.marcadores.where((m) => m.$1 > m.$2).length);
  int get derrotas => cruces.fold(0, (a, c) => a + c.marcadores.where((m) => m.$1 <= m.$2).length);

  /// Racha infinita: partidos ganados seguidos.
  int get racha => cruces.where((c) => c.ganado).length;

  /// Todos los marcadores tuyos, en orden (para repartir XP de lo nuevo).
  List<(int, int)> get todosLosMarcadores => [for (final c in cruces) ...c.marcadores];

  Escalera copyWith({
    List<Cruce>? cruces,
    List<VentajaCamino>? ofrecidas,
    List<VentajaCamino>? elegidas,
    List<InsigniaCamino>? insignias,
    List<InsigniaCamino>? insigniasOfrecidas,
    Map<String, int>? bonusPlantel,
    int? bonusProximo,
    bool? rivalCansado,
    int? rivalDebil,
    List<RivalEscalera?>? cuadro,
    List<List<int>>? ganadores,
    List<List<String>>? marcadoresCuadro,
  }) => Escalera(
    cruces: cruces ?? this.cruces,
    total: total,
    ofrecidas: ofrecidas ?? this.ofrecidas,
    elegidas: elegidas ?? this.elegidas,
    insignias: insignias ?? this.insignias,
    insigniasOfrecidas: insigniasOfrecidas ?? this.insigniasOfrecidas,
    bonusPlantel: bonusPlantel ?? this.bonusPlantel,
    bonusProximo: bonusProximo ?? this.bonusProximo,
    rivalCansado: rivalCansado ?? this.rivalCansado,
    rivalDebil: rivalDebil ?? this.rivalDebil,
    escenarioId: escenarioId,
    cuadro: cuadro ?? this.cuadro,
    ganadores: ganadores ?? this.ganadores,
    marcadoresCuadro: marcadoresCuadro ?? this.marcadoresCuadro,
  );

  factory Escalera.fromJson(Map<String, dynamic> j) => Escalera(
    cruces: [for (final c in j['cruces'] as List? ?? const []) Cruce.fromJson(c as Map<String, dynamic>)],
    total: j['total'] as int?,
    ofrecidas: [for (final v in j['ofrecidas'] as List? ?? const []) VentajaCamino.values.byName(v as String)],
    elegidas: [for (final v in j['elegidas'] as List? ?? const []) VentajaCamino.values.byName(v as String)],
    insignias: [for (final v in j['insignias'] as List? ?? const []) ?InsigniaCamino.values.asNameMap()[v]],
    insigniasOfrecidas: [
      for (final v in j['insigniasOfrecidas'] as List? ?? const []) ?InsigniaCamino.values.asNameMap()[v],
    ],
    bonusPlantel: (j['bonus'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, v as int)),
    bonusProximo: j['bonusProximo'] as int? ?? 0,
    rivalCansado: j['rivalCansado'] as bool? ?? false,
    rivalDebil: j['rivalDebil'] as int? ?? 0,
    escenarioId: j['escenario'] as String?,
    cuadro: [
      for (final r in j['cuadro'] as List? ?? const [])
        r == null ? null : RivalEscalera.fromJson(r as Map<String, dynamic>),
    ],
    ganadores: [for (final r in j['ganadores'] as List? ?? const []) (r as List).cast<int>()],
    marcadoresCuadro: [for (final r in j['marcadoresCuadro'] as List? ?? const []) (r as List).cast<String>()],
  );

  Map<String, dynamic> toJson() => {
    'cruces': [for (final c in cruces) c.toJson()],
    if (total != null) 'total': total,
    if (ofrecidas.isNotEmpty) 'ofrecidas': [for (final v in ofrecidas) v.name],
    if (elegidas.isNotEmpty) 'elegidas': [for (final v in elegidas) v.name],
    if (insignias.isNotEmpty) 'insignias': [for (final v in insignias) v.name],
    if (insigniasOfrecidas.isNotEmpty) 'insigniasOfrecidas': [for (final v in insigniasOfrecidas) v.name],
    if (bonusPlantel.isNotEmpty) 'bonus': bonusPlantel,
    if (bonusProximo != 0) 'bonusProximo': bonusProximo,
    if (rivalCansado) 'rivalCansado': true,
    if (rivalDebil != 0) 'rivalDebil': rivalDebil,
    if (escenarioId != null) 'escenario': escenarioId,
    if (cuadro.isNotEmpty) 'cuadro': [for (final r in cuadro) r?.toJson()],
    if (ganadores.isNotEmpty) 'ganadores': ganadores,
    if (marcadoresCuadro.isNotEmpty) 'marcadoresCuadro': marcadoresCuadro,
  };
}

/// Nombres de las rondas del Mundial (32 equipos).
const rondasMundial = ['16avos de final', 'Octavos de final', 'Cuartos de final', 'Semifinales', 'La final'];

/// Lógica de los modos de escalera: arma los rivales, juega y registra cruces, reparte ventajas
/// y hace avanzar el cuadro del Mundial. Pura: devuelve temporadas nuevas.
class ModosEscalera {
  ModosEscalera(this.liga, {Random? azar}) : _azar = azar ?? Random();

  final Liga liga;
  final Random _azar;

  static const largoCamino = 10;

  late final Map<String, Jugador> _porId = {for (final j in liga.catalogo) j.id: j};

  late final Map<(String, Epoca), List<Jugador>> _grupos = () {
    final g = <(String, Epoca), List<Jugador>>{};
    for (final j in liga.catalogo) {
      (g[(j.franquiciaId, j.epoca)] ??= []).add(j);
    }
    return g;
  }();

  /// Diferencia de media de los rivales históricos fijos según la dificultad.
  static int ajusteDificultad(Dificultad d) => switch (d) {
    Dificultad.normal => -4,
    Dificultad.dificil => -1,
    Dificultad.leyenda => 1,
  };

  /// Media objetivo del primer rival de la racha y del camino.
  static int _base(Dificultad d) => switch (d) {
    Dificultad.normal => 72,
    Dificultad.dificil => 74,
    Dificultad.leyenda => 78,
  };

  // ── Armado de planteles ──

  /// Plantel con los nombres del [nucleo] en sus puestos (maximiza cuántos entran, prefiriendo a
  /// los primeros de la lista) y completa con los mejores del [resto].
  Plantel? armarConNucleo(List<Jugador> nucleo, List<Jugador> resto) {
    final candidatos = nucleo.take(8).toList();
    final puestos = Posicion.titulares;
    var mejor = <Posicion, Jugador>{};
    var mejorPuntaje = -1;
    void buscar(int i, Map<Posicion, Jugador> asignado, int puntaje) {
      if (i == puestos.length) {
        if (puntaje > mejorPuntaje) {
          mejorPuntaje = puntaje;
          mejor = Map.of(asignado);
        }
        return;
      }
      final p = puestos[i];
      for (final (k, j) in candidatos.indexed) {
        if (!j.posiciones.contains(p) || asignado.values.any((x) => x.nbaPlayerId == j.nbaPlayerId)) continue;
        asignado[p] = j;
        // Entrar vale mucho; los primeros del núcleo y su puesto natural, un poco más.
        buscar(i + 1, asignado, puntaje + 100 + (10 - k) + (j.posiciones.first == p ? 3 : 0));
        asignado.remove(p);
      }
      buscar(i + 1, asignado, puntaje);
    }

    buscar(0, {}, 0);
    var plantel = const Plantel();
    for (final e in mejor.entries) {
      plantel = plantel.asignar(e.value, e.key);
    }
    for (final j in candidatos) {
      if (plantel.estaOcupada(Posicion.sextoHombre)) break;
      if (!plantel.contiene(j)) plantel = plantel.asignar(j, Posicion.sextoHombre);
    }
    return completar(plantel, resto);
  }

  /// Completa los puestos vacíos: los más escasos primero; con [objetivo], los de media más
  /// cercana a esa (al azar entre los [variedad] más cercanos); si no, los de más media.
  Plantel? completar(Plantel inicial, List<Jugador> pool, {int? objetivo, int variedad = 1}) {
    final ordenadas = [...pool]
      ..sort(
        (a, b) => objetivo == null
            ? b.media.compareTo(a.media)
            : (a.media - objetivo).abs().compareTo((b.media - objetivo).abs()),
      );
    var plantel = inicial;
    final puestos = [...Posicion.titulares]
      ..sort(
        (a, b) => ordenadas
            .where((j) => j.posiciones.contains(a))
            .length
            .compareTo(ordenadas.where((j) => j.posiciones.contains(b)).length),
      );
    for (final p in [...puestos, Posicion.sextoHombre]) {
      if (plantel.estaOcupada(p)) continue;
      final aptos = ordenadas.where((j) => plantel.posicionesDisponiblesPara(j).contains(p)).take(variedad).toList();
      if (aptos.isEmpty) return null;
      plantel = plantel.asignar(aptos[_azar.nextInt(aptos.length)], p);
    }
    return plantel;
  }

  static double mediaDe(Plantel p) => p.jugadores.fold(0, (a, j) => a + j.media) / p.jugadores.length;

  RivalEscalera _rival(Plantel p, String identidad, String etiqueta) => RivalEscalera(
    identidadId: identidad,
    etiqueta: etiqueta,
    cartaIds: {for (final pos in Posicion.values) pos: p.en(pos)!.id},
    tactica: recomendar(PerfilPlantel.de(p)).tactica,
    media: mediaDe(p),
  );

  /// Identidad más repetida entre las cartas (los Thunder de los 90 juegan como Sonics).
  String _identidad(Iterable<Jugador> js) {
    final cuenta = <String, int>{};
    for (final j in js) {
      cuenta[j.equipo] = (cuenta[j.equipo] ?? 0) + 1;
    }
    return cuenta.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  Plantel? plantelHistorico(EquipoHistorico e, {Set<int> excluidos = const {}}) {
    final grupo = [
      for (final j in _grupos[(e.franquiciaId, e.epoca)] ?? const <Jugador>[])
        if (!excluidos.contains(j.nbaPlayerId)) j,
    ];
    final nucleo = <Jugador>[];
    for (final n in e.nucleo) {
      final mejores = grupo.where((j) => j.nombre == n).toList()..sort((a, b) => b.media.compareTo(a.media));
      if (mejores.isNotEmpty) nucleo.add(mejores.first);
    }
    return armarConNucleo(nucleo, grupo);
  }

  RivalEscalera rivalHistorico(EquipoHistorico e, {Set<int> excluidos = const {}}) =>
      _rival(plantelHistorico(e, excluidos: excluidos)!, e.identidadId, e.etiqueta);

  /// Rival de una franquicia y década, con la media más cercana a [objetivo].
  RivalEscalera? rivalDeEpoca(String franquiciaId, Epoca epoca, int objetivo, Set<int> excluidos) {
    final pool = [
      for (final j in _grupos[(franquiciaId, epoca)] ?? const <Jugador>[])
        if (!excluidos.contains(j.nbaPlayerId)) j,
    ];
    final p = completar(const Plantel(), pool, objetivo: objetivo, variedad: 2);
    if (p == null) return null;
    return _rival(p, _identidad(p.jugadores), '(${epoca.corta})');
  }

  /// Rival al azar (franquicia y década) cuya media se acerque a [objetivo].
  /// [evitar]: franquicias de los últimos rivales (para que no se repitan seguidas).
  RivalEscalera rivalAlAzar(int objetivo, Set<int> excluidos, {Set<String> evitar = const {}}) {
    final franquicias = {for (final f in liga.franquicias) f.id}.difference(evitar);
    final grupos = _grupos.keys.where((k) => franquicias.contains(k.$1) && k.$2 != Epoca.anios40).toList()
      ..shuffle(_azar);
    RivalEscalera? mas;
    for (final (f, e) in grupos.take(14)) {
      final r = rivalDeEpoca(f, e, objetivo, excluidos);
      if (r == null) continue;
      if ((r.media - objetivo).abs() <= 1.5) return r;
      if (mas == null || (r.media - objetivo).abs() < (mas.media - objetivo).abs()) mas = r;
    }
    return mas!;
  }

  /// Plantel histórico de una franquicia (lo mejor de toda su historia), sin [excluidos].
  RivalEscalera? rivalTodosLosTiempos(
    String franquiciaId,
    Set<int> excluidos, {
    String? soloIdentidad,
    String? sinIdentidad,
    int? objetivo,
  }) {
    final pool = [
      for (final j in liga.catalogo)
        if (j.franquiciaId == franquiciaId &&
            !excluidos.contains(j.nbaPlayerId) &&
            (soloIdentidad == null || j.equipo == soloIdentidad) &&
            (sinIdentidad == null || j.equipo != sinIdentidad))
          j,
    ];
    final p = completar(const Plantel(), pool, objetivo: objetivo, variedad: objetivo == null ? 1 : 3);
    if (p == null) return null;
    return _rival(p, soloIdentidad ?? franquiciaId, '(Histórico)');
  }

  Set<int> _propios(Temporada t) => {
    for (final j in t.plantel.jugadores) j.nbaPlayerId,
    for (final j in t.suplentes) j.nbaPlayerId,
  };

  // ── Arranque ──

  /// Arma el primer cruce (o el cuadro) si todavía no arrancó. No hace nada si ya arrancó.
  Temporada iniciar(Temporada t) {
    final e = Escalera.de(t);
    if (e.iniciada) return t;
    final propios = _propios(t);
    switch (t.modoJuego) {
      case ModoJuego.racha:
        return Escalera(cruces: [_cruceRacha(t, 0, propios)]).en(t);
      case ModoJuego.caminoAlAnillo:
        return Escalera(total: largoCamino, cruces: [_cruceCamino(t, 0, propios)]).en(t);
      case ModoJuego.mejoresEquipos:
        return Escalera(total: mejoresEquipos.length, cruces: [_cruceMejores(0, propios)]).en(t);
      case ModoJuego.escenario:
        final esc = escenarioPorId(e.escenarioId) ?? escenarios.first;
        return Escalera(
          total: 1,
          escenarioId: esc.id,
          cruces: [
            Cruce(
              rival: rivalHistorico(esc.rival, excluidos: propios),
              titulo: esc.titulo,
              aGanar: 4,
              propias: esc.propias,
              ajenas: esc.ajenas,
              usuarioAlto: esc.usuarioAlto,
              dosTresDos: esc.dosTresDos,
            ),
          ],
        ).en(t);
      case ModoJuego.mundial:
        return _iniciarMundial(t, propios);
      default:
        return t;
    }
  }

  Cruce _cruceRacha(Temporada t, int i, Set<int> propios, {List<Cruce> previos = const []}) {
    final objetivo = min(96, _base(t.dificultad) + (i * 0.6).round());
    return Cruce(
      rival: rivalAlAzar(objetivo, propios, evitar: _recientes(previos)),
      titulo: 'Partido ${i + 1}',
      usuarioAlto: i.isEven,
    );
  }

  /// Franquicias de los últimos 3 rivales.
  Set<String> _recientes(List<Cruce> previos) => {
    for (final c in previos.reversed.take(3)) ?_porId[c.rival.cartaIds.values.first]?.franquiciaId,
  };

  Cruce _cruceCamino(Temporada t, int i, Set<int> propios) {
    if (i == largoCamino - 1) {
      // El último escalón son Las Finales contra uno de los mejores equipos de la historia.
      // En Normal, uno de los 6 más accesibles; en Difícil, del 4.º al 9.º; en Leyenda, los 4 más grandes.
      final desde = switch (t.dificultad) {
        Dificultad.normal => 0,
        Dificultad.dificil => 3,
        Dificultad.leyenda => 6,
      };
      final final_ = mejoresEquipos[min(mejoresEquipos.length - 1, desde + _azar.nextInt(desde == 6 ? 4 : 6))];
      return Cruce(
        rival: rivalHistorico(final_, excluidos: propios),
        titulo: 'Escalón $largoCamino de $largoCamino: Las Finales',
        aGanar: 4,
        usuarioAlto: false,
      );
    }
    // Con las insignias el plantel crece en el camino: los rivales también (+2 de base, +1,7 por escalón).
    final objetivo = _base(t.dificultad) + 2 + (i * 1.7).round();
    return Cruce(
      rival: rivalAlAzar(objetivo, propios, evitar: _recientes(Escalera.de(t).cruces)),
      titulo: 'Escalón ${i + 1} de $largoCamino',
      usuarioAlto: i.isEven,
    );
  }

  Cruce _cruceMejores(int i, Set<int> propios) => Cruce(
    rival: rivalHistorico(mejoresEquipos[i], excluidos: propios),
    titulo: '${i + 1} de ${mejoresEquipos.length}',
    aGanar: 2,
    usuarioAlto: false,
  );

  /// Mundial: tu equipo + las 29 franquicias restantes con planteles de toda su historia (armados a
  /// la medida de la dificultad, como los rivales históricos de la temporada) + 2 identidades
  /// clásicas con su propia historia (los SuperSonics, separados del Thunder; los Nets de New
  /// Jersey, separados de Brooklyn; o los Bullets, si alguna de esas es la tuya). 32 sin byes.
  Temporada _iniciarMundial(Temporada t, Set<int> propios) {
    final usados = {...propios};
    final clasicas = [
      ('OKC', 'SEA'),
      ('BKN', 'NJN'),
      ('WAS', 'WSB'),
    ].where((c) => c.$1 != t.franquiciaUsuarioId).take(2).toList();
    final equipos = <RivalEscalera>[];
    // Primero las identidades clásicas, así la franquicia madre no se lleva a sus figuras.
    for (final (f, ident) in clasicas) {
      final r = rivalTodosLosTiempos(f, usados, soloIdentidad: ident, objetivo: t.dificultad.mediaRivales);
      if (r == null) continue;
      equipos.add(r);
      usados.addAll(_nbaIds(r));
    }
    for (final f in liga.franquicias) {
      if (f.id == t.franquiciaUsuarioId) continue;
      final clasica = clasicas.where((c) => c.$1 == f.id).firstOrNull;
      final r = rivalTodosLosTiempos(f.id, usados, sinIdentidad: clasica?.$2, objetivo: t.dificultad.mediaRivales);
      if (r == null) continue;
      equipos.add(r);
      usados.addAll(_nbaIds(r));
    }
    // Sembrado por media (el tuyo también), con el cuadro clásico 1-32, 16-17…
    final mediaUsuario = mediaDe(t.plantel);
    final sembrados = <RivalEscalera?>[null, ...equipos.take(31)]
      ..sort((a, b) => (b?.media ?? mediaUsuario).compareTo(a?.media ?? mediaUsuario));
    final orden = _ordenLlaves(32);
    final cuadro = [for (final s in orden) sembrados[s]];
    final e = Escalera(total: rondasMundial.length, cuadro: cuadro);
    return _avanzarMundial(e, t);
  }

  Iterable<int> _nbaIds(RivalEscalera r) => [for (final id in r.cartaIds.values) ?_porId[id]?.nbaPlayerId];

  /// Posición de cada siembra en el cuadro (0-index): 1 vs 32, 16 vs 17, 8 vs 25…
  static List<int> _ordenLlaves(int n) {
    var orden = [0];
    while (orden.length < n) {
      final m = orden.length * 2;
      orden = [
        for (final s in orden) ...[s, m - 1 - s],
      ];
    }
    return orden;
  }

  /// Participantes de la ronda [r] del Mundial (índices de cuadro).
  List<int> participantesRonda(Escalera e, int r) => r == 0 ? [for (var i = 0; i < 32; i++) i] : e.ganadores[r - 1];

  /// Si la ronda actual tiene al usuario sin cruce, se lo crea; si el usuario ya terminó la suya,
  /// simula el resto de la ronda y arma la siguiente.
  Temporada _avanzarMundial(Escalera e, Temporada t) {
    var esc = e;
    for (var guarda = 0; guarda < 6; guarda++) {
      final r = esc.ganadores.length;
      if (r >= rondasMundial.length) break;
      final part = participantesRonda(esc, r);
      final iu = part.indexWhere((i) => esc.cuadro[i] == null);
      final cruceDeRonda = esc.cruces.length > r ? esc.cruces[r] : null;
      if (iu >= 0 && cruceDeRonda == null) {
        final rivalIdx = part[iu ^ 1];
        esc = esc.copyWith(
          cruces: [
            ...esc.cruces,
            Cruce(
              rival: esc.cuadro[rivalIdx]!,
              titulo: 'Mundial: ${rondasMundial[r]}',
              aGanar: r >= 3 ? 2 : 1,
              usuarioAlto: iu.isEven,
            ),
          ],
        );
        break; // espera que juegues
      }
      if (iu >= 0 && !cruceDeRonda!.terminado) break;
      // Ronda resuelta para el usuario (o ya eliminado): se simula el resto.
      final ganadores = <int>[];
      final marcadores = <String>[];
      for (var k = 0; k + 1 < part.length; k += 2) {
        final (a, b) = (part[k], part[k + 1]);
        if (esc.cuadro[a] == null || esc.cuadro[b] == null) {
          final c = cruceDeRonda!;
          ganadores.add(c.ganado ? (esc.cuadro[a] == null ? a : b) : (esc.cuadro[a] == null ? b : a));
          marcadores.add(c.esSerie ? '${c.propias}-${c.ajenas}' : '${c.marcadores.last.$1}-${c.marcadores.last.$2}');
          continue;
        }
        final (g, m) = _simularLlave(esc.cuadro[a]!, esc.cuadro[b]!, aGanar: r >= 3 ? 2 : 1);
        ganadores.add(g ? a : b);
        marcadores.add(m);
      }
      esc = esc.copyWith(
        ganadores: [...esc.ganadores, ganadores],
        marcadoresCuadro: [...esc.marcadoresCuadro, marcadores],
      );
    }
    return esc.en(t);
  }

  /// Simula una llave entre dos rivales del cuadro. Devuelve (ganó el primero, marcador).
  (bool, String) _simularLlave(RivalEscalera a, RivalEscalera b, {required int aGanar}) {
    var va = 0, vb = 0;
    String ultimo = '';
    while (va < aGanar && vb < aGanar) {
      final aLocal = (va + vb).isEven;
      final m = MotorPartido(local: equipoRival(aLocal ? a : b), visitante: equipoRival(aLocal ? b : a), azar: _azar)
        ..simularTodo();
      final ganaLocal = m.puntosLocal > m.puntosVisitante;
      (ganaLocal == aLocal) ? va++ : vb++;
      final (pa, pb) = aLocal ? (m.puntosLocal, m.puntosVisitante) : (m.puntosVisitante, m.puntosLocal);
      ultimo = '$pa-$pb';
    }
    return (va > vb, aGanar > 1 ? '$va-$vb' : ultimo);
  }

  // ── Partidos ──

  Plantel plantelDe(RivalEscalera r) {
    var p = const Plantel();
    for (final e in r.cartaIds.entries) {
      p = p.asignar(cartaOReemplazo(_porId, liga.catalogo, e.value, e.key, p), e.key);
    }
    return p;
  }

  /// Equipo de un rival; [ajuste] se suma a la media de todas sus cartas.
  EquipoPartido equipoRival(RivalEscalera r, {int ajuste = 0, double energia = 100}) {
    final plantel = plantelDe(r);
    return EquipoPartido(
      identidadId: r.identidadId,
      plantel: plantel,
      tactica: r.tactica,
      forma: ajuste == 0 ? const {} : {for (final j in plantel.jugadores) j.id: ajuste},
      energiaInicial: energia,
    );
  }

  EquipoPartido equipoUsuario(Temporada t) {
    final e = Escalera.de(t);
    final base = liga.equipo(t, t.franquiciaUsuarioId);
    final mods = InsigniaCamino.suma(e.insignias, base.plantel.jugadores);
    if (e.bonusPlantel.isEmpty && e.bonusProximo == 0 && mods.esNeutro) return base;
    final forma = <String, int>{...base.forma};
    for (final j in [...base.plantel.jugadores, ...base.reserva]) {
      forma[j.id] = (forma[j.id] ?? 0) + (e.bonusPlantel[j.id] ?? 0) + e.bonusProximo;
    }
    return EquipoPartido(
      identidadId: base.identidadId,
      plantel: base.plantel,
      tactica: base.tactica,
      entrenador: base.entrenador,
      forma: forma,
      energiaInicial: base.energiaInicial,
      reserva: base.reserva,
      modificadores: mods,
    );
  }

  /// Motor del próximo partido de tu cruce pendiente.
  MotorPartido motor(Temporada t) {
    final e = Escalera.de(t);
    final c = e.pendiente ?? (throw StateError('No hay partido pendiente.'));
    final propio = equipoUsuario(t);
    // Los rivales de la racha, del camino y del Mundial ya se arman a la medida de la dificultad
    // (como los de la temporada); a los históricos fijos (mejores equipos, escenarios, la final del
    // camino) se les ajusta la media.
    final aMedida =
        t.modoJuego == ModoJuego.racha ||
        t.modoJuego == ModoJuego.mundial ||
        t.modoJuego == ModoJuego.caminoAlAnillo && c.aGanar == 1;
    // Las Finales del camino: el rival llega entero (+2) porque el tuyo llega con sus insignias.
    final ajuste = aMedida ? 0 : ajusteDificultad(t.dificultad) + (t.modoJuego == ModoJuego.caminoAlAnillo ? 2 : 0);
    final rival = equipoRival(
      c.rival,
      ajuste: ajuste - e.rivalDebil + _rampa(t, e),
      energia: e.rivalCansado ? 92 : 100,
    );
    final local = c.usuarioLocalProximo;
    return MotorPartido(
      local: local ? propio : rival,
      visitante: local ? rival : propio,
      usuarioLocal: local,
      azar: _azar,
    );
  }

  /// Los mejores equipos de la historia arrancan un poco más accesibles (−3 al primero) y llegan
  /// enteros al último.
  int _rampa(Temporada t, Escalera e) {
    if (t.modoJuego != ModoJuego.mejoresEquipos) return 0;
    final i = e.cruces.length - 1;
    return -3 + (i * 3 / (mejoresEquipos.length - 1)).round();
  }

  /// Registra un partido terminado (en vivo o simulado) y hace avanzar el modo.
  Temporada registrar(Temporada t, MotorPartido m) {
    var e = Escalera.de(t);
    final c = e.pendiente;
    if (c == null) return t;
    final local = m.usuarioLocal ?? c.usuarioLocalProximo;
    final (mios, suyos) = local ? (m.puntosLocal, m.puntosVisitante) : (m.puntosVisitante, m.puntosLocal);
    final nuevo = c.conResultado(mios, suyos);
    e = e.copyWith(
      cruces: [...e.cruces.take(e.cruces.length - 1), nuevo],
      bonusProximo: 0,
      rivalCansado: false,
      rivalDebil: 0,
    );
    if (!nuevo.terminado) return e.en(t);
    final propios = _propios(t);
    switch (t.modoJuego) {
      case ModoJuego.racha when nuevo.ganado:
        e = e.copyWith(
          cruces: [
            ...e.cruces,
            _cruceRacha(t, e.cruces.length, propios, previos: e.cruces),
          ],
        );
      case ModoJuego.caminoAlAnillo when nuevo.ganado && e.cruces.length < largoCamino:
        e = e.copyWith(insigniasOfrecidas: ofrecerInsignias(t, e));
      case ModoJuego.mejoresEquipos when nuevo.ganado && e.cruces.length < mejoresEquipos.length:
        e = e.copyWith(cruces: [...e.cruces, _cruceMejores(e.cruces.length, propios)]);
      case ModoJuego.mundial:
        return _avanzarMundial(e, t);
      default:
        break;
    }
    return e.en(t);
  }

  Temporada simularPartido(Temporada t) => registrar(t, motor(t)..simularTodo());

  /// Simula lo que queda del cruce pendiente.
  Temporada simularCruce(Temporada t) {
    var x = t;
    final inicio = Escalera.de(t).cruces.length;
    for (var guarda = 0; guarda < 7; guarda++) {
      final e = Escalera.de(x);
      if (e.pendiente == null || e.cruces.length > inicio) break;
      x = simularPartido(x);
    }
    return x;
  }

  /// Mundial: con el usuario eliminado, simula el resto del cuadro.
  Temporada simularResto(Temporada t) {
    final e = Escalera.de(t);
    if (e.cuadro.isEmpty) return t;
    return _avanzarMundial(e, t);
  }

  // ── Camino al anillo ──

  /// 3 insignias que todavía no tenés (el refuerzo, solo si hay lugar en el banco largo).
  List<InsigniaCamino> ofrecerInsignias(Temporada t, Escalera e) {
    final opciones = [
      for (final v in InsigniaCamino.values)
        if (!e.insignias.contains(v) && (v != InsigniaCamino.refuerzo || t.suplentes.length < Temporada.maxSuplentes))
          v,
    ]..shuffle(_azar);
    return opciones.take(3).toList();
  }

  /// Elige una de las insignias ofrecidas y arma el próximo escalón.
  Temporada elegirInsignia(Temporada t, InsigniaCamino v) {
    var e = Escalera.de(t);
    if (!e.insigniasOfrecidas.contains(v)) return t;
    var x = t;
    if (v == InsigniaCamino.refuerzo) x = x.copyWith(suplentes: [...x.suplentes, _refuerzo(x)]);
    e = e.copyWith(
      insigniasOfrecidas: const [],
      insignias: [...e.insignias, v],
      cruces: [...e.cruces, _cruceCamino(t, e.cruces.length, _propios(x))],
    );
    return e.en(x);
  }

  /// Ventajas de antes de las insignias: solo para partidas guardadas con una elección pendiente.
  Temporada elegirVentaja(Temporada t, VentajaCamino v) {
    var e = Escalera.de(t);
    if (!e.ofrecidas.contains(v)) return t;
    var x = t;
    final mejor = t.plantel.jugadores.reduce((a, b) => a.media >= b.media ? a : b);
    final bonus = Map.of(e.bonusPlantel);
    switch (v) {
      case VentajaCamino.inspiracion:
        e = e.copyWith(bonusProximo: 3);
      case VentajaCamino.figura:
        bonus[mejor.id] = (bonus[mejor.id] ?? 0) + 3;
      case VentajaCamino.quimica:
        for (final j in t.plantel.jugadores) {
          bonus[j.id] = (bonus[j.id] ?? 0) + 1;
        }
      case VentajaCamino.refuerzo:
        x = x.copyWith(suplentes: [...x.suplentes, _refuerzo(x)]);
      case VentajaCamino.piernasFrescas:
        e = e.copyWith(rivalCansado: true);
      case VentajaCamino.scouting:
        e = e.copyWith(rivalDebil: 2);
    }
    e = e.copyWith(
      bonusPlantel: bonus,
      ofrecidas: const [],
      elegidas: [...e.elegidas, v],
      cruces: [...e.cruces, _cruceCamino(t, e.cruces.length, _propios(x))],
    );
    return e.en(x);
  }

  Jugador _refuerzo(Temporada t) {
    final propios = _propios(t);
    final candidatos = [
      for (final j in liga.catalogo)
        if ((j.tier == Tier.a || j.tier == Tier.b) &&
            j.media >= 80 &&
            j.media <= 86 &&
            !propios.contains(j.nbaPlayerId))
          j,
    ];
    return candidatos[_azar.nextInt(candidatos.length)];
  }

  // ── Escenarios ──

  /// Partida nueva de un escenario: el plantel y las tácticas ya vienen puestos.
  Temporada nuevaDeEscenario(Escenario esc, {required String id, Dificultad dificultad = Dificultad.normal}) {
    final plantel = plantelHistorico(esc.usuario)!;
    final t = Temporada(
      id: id,
      franquiciaUsuarioId: esc.usuario.franquiciaId,
      plantel: plantel,
      tactica: recomendar(PerfilPlantel.de(plantel)).tactica,
      tacticaConfirmada: true,
      rerollsRestantes: 0,
      dificultad: dificultad,
      modoJuego: ModoJuego.escenario,
      datosModo: {Escalera.clave: Escalera(escenarioId: esc.id).toJson()},
    );
    return iniciar(t);
  }
}

/// Lo que dejó un cambio en una escalera, para el metajuego.
class ProgresoEscalera {
  const ProgresoEscalera({
    required this.ganados,
    required this.perdidos,
    required this.completada,
    required this.racha,
  });

  final int ganados, perdidos;

  /// Se completó en este cambio (no antes).
  final bool completada;

  /// Racha actual (racha infinita).
  final int racha;

  static ProgresoEscalera? entre(Temporada antes, Temporada despues) {
    if (!esEscalera(despues.modoJuego)) return null;
    final a = Escalera.de(antes), d = Escalera.de(despues);
    final previos = a.todosLosMarcadores.length;
    final nuevos = d.todosLosMarcadores.skip(previos).toList();
    return ProgresoEscalera(
      ganados: nuevos.where((m) => m.$1 > m.$2).length,
      perdidos: nuevos.where((m) => m.$1 <= m.$2).length,
      completada: d.completada && !a.completada,
      racha: despues.modoJuego == ModoJuego.racha ? d.racha : 0,
    );
  }

  static bool esEscalera(ModoJuego m) => const {
    ModoJuego.racha,
    ModoJuego.caminoAlAnillo,
    ModoJuego.mejoresEquipos,
    ModoJuego.mundial,
    ModoJuego.escenario,
  }.contains(m);
}
