import 'dart:math';

import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/rol_cancha.dart';
import '../entities/temporada.dart';
import '../liga.dart';
import '../motor.dart';
import '../playbook.dart';
import '../premios.dart';
import 'dinastia.dart';

// ===========================================================================================
// Mi carrera (tipo MyCareer): un jugador, real o creado, del draft al Salón de la Fama.
// El equipo lo maneja la IA; vos sumás puntos de habilidad jugando y los gastás en atributos
// que cambian las estadísticas de la carta que usa el motor.
// ===========================================================================================

/// Los cinco atributos en los que se gastan los puntos de habilidad.
enum Atributo {
  tiro('Tiro exterior', 'Triples y tiros libres: sube el % de tres y de libres.'),
  finalizacion('Finalización', 'Bandejas, volcadas y tiros cerca del aro: puntos y % de campo.'),
  defensa('Defensa', 'Robos y tapones.'),
  fisico('Físico', 'Rebotes, aguante (minutos) y tapones.'),
  iq('IQ y pase', 'Asistencias, menos pérdidas y lectura de juego.');

  const Atributo(this.etiqueta, this.descripcion);
  final String etiqueta;
  final String descripcion;
}

/// Los cinco atributos de un jugador (25 a 99).
class Atributos {
  const Atributos(this._v);

  factory Atributos.de({
    required int tiro,
    required int finalizacion,
    required int defensa,
    required int fisico,
    required int iq,
  }) => Atributos({
    Atributo.tiro: tiro.clamp(25, 99),
    Atributo.finalizacion: finalizacion.clamp(25, 99),
    Atributo.defensa: defensa.clamp(25, 99),
    Atributo.fisico: fisico.clamp(25, 99),
    Atributo.iq: iq.clamp(25, 99),
  });

  final Map<Atributo, int> _v;

  int operator [](Atributo a) => _v[a] ?? 50;

  Atributos con(Atributo a, int valor) => Atributos({..._v, a: valor.clamp(25, 99)});

  /// Suma [cambios] (por atributo), con el tope de 99.
  Atributos sumar(Map<Atributo, int> cambios) =>
      Atributos({for (final a in Atributo.values) a: ((this[a]) + (cambios[a] ?? 0)).clamp(25, 99)});

  bool igualA(Atributos o) => Atributo.values.every((a) => this[a] == o[a]);

  Map<String, dynamic> toJson() => {for (final a in Atributo.values) a.name: this[a]};

  factory Atributos.fromJson(Map<String, dynamic> j) =>
      Atributos({for (final a in Atributo.values) a: (j[a.name] as num?)?.toInt() ?? 50});
}

/// Insignias: se desbloquean al llegar a ciertos atributos y mejoran un poco las estadísticas.
enum Insignia {
  francotirador('Francotirador', 'Tiro 80+: más acierto en triples y libres.'),
  finalizador('Finalizador', 'Finalización 80+: más acierto en el aro.'),
  muralla('Muralla', 'Defensa 80+ y Físico 65+: más robos y tapones.'),
  atleta('Atleta', 'Físico 82+: más rebotes.'),
  maestroDelPase('Maestro del pase', 'IQ 82+: más asistencias y menos pérdidas.'),
  sangreFria('Sangre fría', 'IQ 75+ y Tiro 75+: más puntos en los finales.'),
  completo('Completo', 'Todos los atributos en 70+: un poco de todo.');

  const Insignia(this.etiqueta, this.descripcion);
  final String etiqueta;
  final String descripcion;

  bool la(Atributos a) => switch (this) {
    Insignia.francotirador => a[Atributo.tiro] >= 80,
    Insignia.finalizador => a[Atributo.finalizacion] >= 80,
    Insignia.muralla => a[Atributo.defensa] >= 80 && a[Atributo.fisico] >= 65,
    Insignia.atleta => a[Atributo.fisico] >= 82,
    Insignia.maestroDelPase => a[Atributo.iq] >= 82,
    Insignia.sangreFria => a[Atributo.iq] >= 75 && a[Atributo.tiro] >= 75,
    Insignia.completo => Atributo.values.every((x) => a[x] >= 70),
  };

  static List<Insignia> de(Atributos a) => [
    for (final i in values)
      if (i.la(a)) i,
  ];
}

/// Dónde juega tu jugador en el equipo (lo decide la confianza del DT).
enum RolEquipo {
  titular('Titular'),
  sexto('Sexto hombre'),
  banco('Banco');

  const RolEquipo(this.etiqueta);
  final String etiqueta;
}

/// El modelo que une atributos, estadísticas y media. Una sola fórmula para jugadores reales y creados.
class ModeloCarrera {
  const ModeloCarrera._();

  static const tope = 99;

  /// Peso de cada atributo en la media según el puesto (suman 1).
  static Map<Atributo, double> pesos(Posicion p) => switch (p) {
    Posicion.base => {
      Atributo.tiro: .22,
      Atributo.finalizacion: .14,
      Atributo.defensa: .14,
      Atributo.fisico: .10,
      Atributo.iq: .40,
    },
    Posicion.escolta => {
      Atributo.tiro: .32,
      Atributo.finalizacion: .20,
      Atributo.defensa: .14,
      Atributo.fisico: .10,
      Atributo.iq: .24,
    },
    Posicion.alero => {
      Atributo.tiro: .22,
      Atributo.finalizacion: .24,
      Atributo.defensa: .20,
      Atributo.fisico: .16,
      Atributo.iq: .18,
    },
    Posicion.alaPivot => {
      Atributo.tiro: .10,
      Atributo.finalizacion: .26,
      Atributo.defensa: .22,
      Atributo.fisico: .24,
      Atributo.iq: .18,
    },
    _ => {
      Atributo.tiro: .06,
      Atributo.finalizacion: .26,
      Atributo.defensa: .26,
      Atributo.fisico: .26,
      Atributo.iq: .16,
    },
  };

  static double promedioPonderado(Atributos a, Posicion p) {
    final w = pesos(p);
    return Atributo.values.fold(0.0, (s, x) => s + w[x]! * a[x]);
  }

  /// Media 55–99 a partir de los atributos: 60 + 1,5 × (promedio ponderado − 55).
  static int mediaDe(Atributos a, Posicion p) => (60 + 1.5 * (promedioPonderado(a, p) - 55)).round().clamp(55, 99);

  /// Perfil de cada arquetipo (tiro, finalización, defensa, físico, IQ). Solo importa la forma: el
  /// nivel se ajusta después a la media que corresponda.
  static (int, int, int, int, int) perfilDe(RolCancha r) => switch (r) {
    RolCancha.organizadorPuro => (58, 52, 56, 50, 74),
    RolCancha.anotadorExterior => (72, 58, 48, 50, 62),
    RolCancha.penetradorAtletico => (52, 72, 52, 66, 56),
    RolCancha.baseDefensivo => (54, 50, 74, 60, 62),
    RolCancha.superestrellaAclarados => (66, 72, 50, 58, 60),
    RolCancha.tiradorPantallas => (76, 52, 48, 50, 60),
    RolCancha.escoltaGenerador => (62, 60, 52, 52, 70),
    RolCancha.especialista3D => (70, 50, 70, 58, 58),
    RolCancha.controladorTotal => (56, 62, 60, 64, 72),
    RolCancha.anotadorTresNiveles => (68, 68, 52, 58, 58),
    RolCancha.cerrojoDefensivo => (52, 54, 76, 66, 58),
    RolCancha.aleroCortador => (50, 70, 58, 70, 54),
    RolCancha.maestroPoste => (52, 72, 54, 66, 64),
    RolCancha.alaPivotTirador => (70, 56, 52, 60, 58),
    RolCancha.fuerzaBruta => (44, 64, 62, 78, 52),
    RolCancha.distribuidorInterior => (52, 60, 56, 64, 74),
    RolCancha.goliatPintura => (38, 74, 60, 80, 46),
    RolCancha.juegoDePies => (44, 76, 52, 66, 62),
    RolCancha.protectorAro => (38, 62, 78, 76, 54),
    RolCancha.pivotOrganizador => (48, 58, 56, 66, 76),
    RolCancha.pivotTirador => (68, 56, 54, 66, 56),
    RolCancha.microondas => (72, 62, 44, 50, 56),
    RolCancha.directorSegundaUnidad => (58, 52, 52, 50, 72),
    RolCancha.inyeccionEnergia => (46, 60, 70, 66, 54),
  };

  /// Atributos de un arquetipo con el nivel pedido (promedio ponderado [objetivo]), con ajustes de
  /// [altura] (cm) y [peso] (kg): los altos ganan físico y defensa y pierden tiro.
  static Atributos desdePerfil(RolCancha rol, Posicion pos, double objetivo, {int altura = 198, int peso = 95}) {
    final (t, f, d, fi, i) = perfilDe(rol);
    final h = (altura - 198) / 10.0, k = (peso - 95) / 10.0;
    final crudo = {
      Atributo.tiro: t - h * 1.5,
      Atributo.finalizacion: f + k * 1.0 + h * 0.5,
      Atributo.defensa: d + h * 1.0,
      Atributo.fisico: fi + h * 2.0 + k * 1.5,
      Atributo.iq: i.toDouble(),
    };
    final w = pesos(pos);
    final actual = Atributo.values.fold(0.0, (s, x) => s + w[x]! * crudo[x]!);
    final corrimiento = objetivo - actual;
    return Atributos({for (final a in Atributo.values) a: (crudo[a]! + corrimiento).round().clamp(25, tope)});
  }

  /// Estadísticas de un jugador creado a partir de sus atributos.
  static EstadisticasJugador estadisticasDe(Atributos a, Posicion pos, int media) {
    final (rpp0, app0, rob0, tap0, tc0, t30) = switch (pos) {
      Posicion.base => (2.8, 5.0, 1.1, 0.1, 0.43, 0.33),
      Posicion.escolta => (3.2, 3.5, 1.0, 0.15, 0.435, 0.34),
      Posicion.alero => (4.5, 3.0, 0.9, 0.3, 0.45, 0.32),
      Posicion.alaPivot => (7.0, 2.5, 0.8, 0.8, 0.49, 0.24),
      _ => (8.5, 2.2, 0.7, 1.2, 0.53, 0.14),
    };
    final tiro = a[Atributo.tiro] - 66.0, fin = a[Atributo.finalizacion] - 66.0;
    final def = a[Atributo.defensa] - 62.0, fis = a[Atributo.fisico] - 62.0, iq = a[Atributo.iq] - 62.0;
    final ppp = max(6.5, 5.5 + 0.275 * (tiro + fin + 32));
    return _estadisticas(
      ppp: ppp,
      rpp: rpp0 + 0.10 * fis,
      app: app0 + 0.12 * iq,
      robP: rob0 + 0.025 * def,
      tapP: tap0 + 0.015 * def + 0.008 * fis,
      pctTc: tc0 + 0.002 * fin + 0.0004 * iq,
      pctT3: t30 + 0.003 * tiro,
      pctTl: 0.74 + 0.0045 * tiro,
      minP: 24 + (media - 65) * 0.35,
      perP: 2.2 - 0.02 * iq + (ppp - 11) * 0.06,
      iq: 62 + iq.round(),
    );
  }

  static EstadisticasJugador _estadisticas({
    required double ppp,
    required double rpp,
    required double app,
    required double robP,
    required double tapP,
    required double pctTc,
    required double pctT3,
    required double pctTl,
    required double minP,
    required double perP,
    required int iq,
  }) {
    double r2(double v) => (v * 10).round() / 10;
    double r3(double v) => (v * 1000).round() / 1000;
    return EstadisticasJugador(
      ppp: r2(ppp.clamp(2.0, 38.0)),
      rpp: r2(rpp.clamp(0.8, 18.0)),
      app: r2(app.clamp(0.3, 13.0)),
      robP: r2(robP.clamp(0.2, 3.0)),
      tapP: r2(tapP.clamp(0.0, 4.5)),
      pctTc: r3(pctTc.clamp(0.36, 0.70)),
      pctT3: r3(pctT3.clamp(0.0, 0.46)),
      pctTl: r3(pctTl.clamp(0.45, 0.96)),
      minP: r2(minP.clamp(14.0, 40.0)),
      perP: r2(perP.clamp(0.7, 5.0)),
      iq: iq.clamp(1, 99),
    );
  }

  /// Las estadísticas de [base] movidas por lo que cambiaron los atributos (de [a0] a [a]), más las
  /// insignias, la relación con el vestuario y el ánimo.
  static EstadisticasJugador estadisticasActuales({
    required EstadisticasJugador base,
    required Atributos a0,
    required Atributos a,
    int relacion = 50,
    int moral = 60,
  }) {
    double d(Atributo x) => (a[x] - a0[x]).toDouble();
    var ppp = base.ppp + 0.275 * (d(Atributo.tiro) + d(Atributo.finalizacion));
    var rpp = base.rpp + 0.10 * d(Atributo.fisico);
    var app = base.app + 0.12 * d(Atributo.iq);
    var robP = base.robP + 0.025 * d(Atributo.defensa);
    var tapP = base.tapP + 0.015 * d(Atributo.defensa) + 0.008 * d(Atributo.fisico);
    var pctTc = base.pctTc + 0.002 * d(Atributo.finalizacion);
    var pctT3 = base.pctT3 + 0.003 * d(Atributo.tiro);
    var pctTl = base.pctTl + 0.0045 * d(Atributo.tiro);
    var minP = base.minP + 0.15 * d(Atributo.fisico);
    var perP = base.perP - 0.02 * d(Atributo.iq);
    final iq = base.iq + d(Atributo.iq).round();
    // Solo cuentan las insignias que ganaste (las de arranque ya están en las estadísticas base).
    for (final i in Insignia.de(a).where((i) => !i.la(a0))) {
      switch (i) {
        case Insignia.francotirador:
          pctT3 += 0.015;
          pctTl += 0.015;
        case Insignia.finalizador:
          pctTc += 0.015;
        case Insignia.muralla:
          robP += 0.15;
          tapP += 0.2;
        case Insignia.atleta:
          rpp += 0.8;
        case Insignia.maestroDelPase:
          app += 0.8;
          perP -= 0.2;
        case Insignia.sangreFria:
          ppp += 0.8;
        case Insignia.completo:
          ppp += 0.4;
          rpp += 0.3;
          app += 0.3;
      }
    }
    if (relacion >= 70) {
      app += 0.4;
      pctTc += 0.005;
    } else if (relacion < 30) {
      perP += 0.3;
    }
    if (moral >= 75) {
      ppp += 0.5;
    } else if (moral < 30) {
      ppp -= 0.8;
      pctTc -= 0.005;
    }
    return _estadisticas(
      ppp: ppp,
      rpp: rpp,
      app: app,
      robP: robP,
      tapP: tapP,
      pctTc: pctTc,
      pctT3: pctT3,
      pctTl: pctTl,
      minP: minP,
      perP: perP,
      iq: iq,
    );
  }

  /// Cuánto cuesta subir un punto un atributo que ya está en [valor] (más caro cuanto más alto).
  static int costo(int valor) => valor >= 85 ? 3 : (valor >= 70 ? 2 : 1);

  /// Cambio natural de cada atributo en el receso, según la edad que se cumple. Determinístico
  /// con [azar]: los jóvenes crecen y después del pico el cuerpo cae antes que la cabeza.
  static Map<Atributo, int> desarrolloNatural(int edad, Random azar) {
    double base(Atributo a) => switch (a) {
      Atributo.tiro => edad <= 24 ? 2 : (edad <= 27 ? 1 : (edad <= 31 ? 0 : (edad <= 34 ? -0.7 : -1.6))),
      Atributo.finalizacion => edad <= 24 ? 1.2 : (edad <= 28 ? 0.2 : (edad <= 31 ? -0.8 : -1.8)),
      Atributo.defensa => edad <= 25 ? 1 : (edad <= 29 ? 0 : (edad <= 32 ? -0.8 : -1.8)),
      Atributo.fisico => edad <= 23 ? 2 : (edad <= 26 ? 1 : (edad <= 28 ? 0 : (edad <= 31 ? -1.8 : -2.8))),
      Atributo.iq => edad <= 28 ? 1 : (edad <= 32 ? 0.4 : (edad <= 35 ? 0 : -1)),
    };
    return {for (final a in Atributo.values) a: (base(a) + (azar.nextDouble() - 0.5) * 1.2).round()};
  }
}

// -------------------------------------------------------------------------------------------
// Jugador creado (reutilizable por otros modos, como el universitario)
// -------------------------------------------------------------------------------------------

/// Un jugador que crea el usuario: nombre, puesto, físico, arquetipo y tres puntos fuertes.
class JugadorCreado {
  const JugadorCreado({
    required this.nombre,
    required this.posicion,
    required this.rol,
    required this.fuertes,
    this.alturaCm = 198,
    this.pesoKg = 95,
    this.nacimiento,
  });

  final String nombre;

  /// Puesto titular (nunca Sexto Hombre).
  final Posicion posicion;
  final RolCancha rol;

  /// Los tres atributos fuertes (+4 cada uno al arrancar).
  final List<Atributo> fuertes;
  final int alturaCm, pesoKg;
  final int? nacimiento;

  static const alturaMin = 170, alturaMax = 225, pesoMin = 70, pesoMax = 150;

  /// Altura típica de cada puesto, para sugerir un valor al crear.
  static int alturaSugerida(Posicion p) => switch (p) {
    Posicion.base => 188,
    Posicion.escolta => 195,
    Posicion.alero => 201,
    Posicion.alaPivot => 206,
    _ => 212,
  };

  /// Arquetipos disponibles para un puesto.
  static List<RolCancha> rolesDe(Posicion p) => [
    for (final r in RolCancha.values)
      if (r.posicion == p) r,
  ];

  /// Se puede crear si hay nombre, el arquetipo es del puesto y elegiste tres fuertes distintos.
  String? get error {
    if (nombre.trim().length < 2) return 'Poné un nombre de al menos 2 letras.';
    if (posicion == Posicion.sextoHombre) return 'Elegí un puesto titular.';
    if (rol.posicion != posicion) return 'Ese arquetipo no es de ese puesto.';
    if (fuertes.toSet().length != 3) return 'Elegí tres puntos fuertes distintos.';
    if (alturaCm < alturaMin || alturaCm > alturaMax) return 'La altura va de $alturaMin a $alturaMax cm.';
    if (pesoKg < pesoMin || pesoKg > pesoMax) return 'El peso va de $pesoMin a $pesoMax kg.';
    return null;
  }

  /// Atributos de arranque: el perfil del arquetipo con tu físico, nivelado a ~61 de promedio
  /// ponderado (media ~69) y +4 en cada punto fuerte.
  Atributos get atributos {
    var a = ModeloCarrera.desdePerfil(rol, posicion, 58.5, altura: alturaCm, peso: pesoKg);
    for (final f in fuertes) {
      a = a.con(f, a[f] + 4);
    }
    return a;
  }

  int get media => ModeloCarrera.mediaDe(atributos, posicion);

  EstadisticasJugador get estadisticas => ModeloCarrera.estadisticasDe(atributos, posicion, media);

  /// La carta de tu jugador en [franquiciaId] (la franquicia y la época cambian con los equipos).
  Jugador comoCarta({required String id, required String franquiciaId, Epoca epoca = Epoca.actualidad, int? anio}) =>
      Jugador(
        id: id,
        nbaPlayerId: -(2000000 + (id.hashCode & 0xfffff)),
        nombre: nombre.trim(),
        franquiciaId: franquiciaId,
        epoca: epoca,
        tier: Tier.b,
        posiciones: [posicion],
        rol: rol,
        dorsal: 0,
        stats: estadisticas,
        media: media,
        fotos: const [],
        temporadas: anio == null ? null : (anio, anio),
        nacimiento: nacimiento,
      );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'pos': posicion.name,
    'rol': rol.name,
    'fuertes': [for (final f in fuertes) f.name],
    'altura': alturaCm,
    'peso': pesoKg,
    if (nacimiento != null) 'nacimiento': nacimiento,
  };

  factory JugadorCreado.fromJson(Map<String, dynamic> j) => JugadorCreado(
    nombre: j['nombre'] as String,
    posicion: Posicion.values.byName(j['pos'] as String),
    rol: RolCancha.values.byName(j['rol'] as String),
    fuertes: [for (final f in j['fuertes'] as List) Atributo.values.byName(f as String)],
    alturaCm: j['altura'] as int? ?? 198,
    pesoKg: j['peso'] as int? ?? 95,
    nacimiento: j['nacimiento'] as int?,
  );
}

// -------------------------------------------------------------------------------------------
// Combine y draft
// -------------------------------------------------------------------------------------------

/// Una prueba del combine: nombre, nota 30–99 y lo que dicen los scouts.
class PruebaCombine {
  const PruebaCombine(this.nombre, this.nota, this.comentario);

  final String nombre;
  final int nota;
  final String comentario;
}

class ResultadoCombine {
  const ResultadoCombine({required this.pruebas, required this.puntaje, required this.pick});

  final List<PruebaCombine> pruebas;

  /// Proyección 0–100 (65 % tu media, 35 % el combine).
  final double puntaje;

  /// Número de elección (1–60); más de 50 = sin draft.
  final int pick;

  bool get sinDraft => pick > 50;
  int get ronda => pick <= 30 ? 1 : 2;
  double get promedio => pruebas.fold(0, (a, p) => a + p.nota) / max(1, pruebas.length);
}

// -------------------------------------------------------------------------------------------
// Objetivos, prensa y contratos
// -------------------------------------------------------------------------------------------

enum TipoObjetivo { puntos, rebotes, asistencias, defensa, victorias, playoffs, allStar, partidos }

/// Un objetivo que te pide el DT para la temporada.
class ObjetivoTemporada {
  const ObjetivoTemporada(this.tipo, this.meta);

  final TipoObjetivo tipo;
  final double meta;

  String get texto => switch (tipo) {
    TipoObjetivo.puntos => 'Promediar ${_n(meta)} puntos',
    TipoObjetivo.rebotes => 'Promediar ${_n(meta)} rebotes',
    TipoObjetivo.asistencias => 'Promediar ${_n(meta)} asistencias',
    TipoObjetivo.defensa => 'Sumar ${_n(meta)} robos + tapones por partido',
    TipoObjetivo.victorias => 'Ganar ${meta.round()} partidos con el equipo',
    TipoObjetivo.playoffs => 'Meter al equipo en los playoffs',
    TipoObjetivo.allStar => 'Ser All-Star',
    TipoObjetivo.partidos => 'Jugar ${meta.round()} partidos',
  };

  static String _n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Valor actual del objetivo y si ya se cumple, con lo que se sabe de la temporada.
  (double, bool) avance(MarcaTemporada m) {
    final v = switch (tipo) {
      TipoObjetivo.puntos => m.ppg,
      TipoObjetivo.rebotes => m.rpg,
      TipoObjetivo.asistencias => m.apg,
      TipoObjetivo.defensa => m.defensaPorPartido,
      TipoObjetivo.victorias => m.victorias.toDouble(),
      TipoObjetivo.playoffs => m.playoffs ? 1.0 : 0.0,
      TipoObjetivo.allStar => m.allStar ? 1.0 : 0.0,
      TipoObjetivo.partidos => m.pj.toDouble(),
    };
    return (v, v >= meta - 1e-9);
  }

  Map<String, dynamic> toJson() => {'t': tipo.name, 'm': meta};

  factory ObjetivoTemporada.fromJson(Map<String, dynamic> j) =>
      ObjetivoTemporada(TipoObjetivo.values.byName(j['t'] as String), (j['m'] as num).toDouble());
}

/// Lo que va haciendo el jugador en la temporada (por partido) y el equipo.
class MarcaTemporada {
  const MarcaTemporada({
    required this.pj,
    required this.ppg,
    required this.rpg,
    required this.apg,
    required this.defensaPorPartido,
    required this.victorias,
    required this.derrotas,
    this.playoffs = false,
    this.allStar = false,
  });

  final int pj;
  final double ppg, rpg, apg, defensaPorPartido;
  final int victorias, derrotas;
  final bool playoffs, allStar;
}

/// Una respuesta en la conferencia de prensa y lo que mueve.
class RespuestaPrensa {
  const RespuestaPrensa(
    this.texto,
    this.reaccion, {
    this.confianza = 0,
    this.moral = 0,
    this.fans = 0,
    this.relacion = 0,
  });

  final String texto, reaccion;
  final int confianza, moral, fans, relacion;
}

class PreguntaPrensa {
  const PreguntaPrensa(this.texto, this.respuestas);

  final String texto;
  final List<RespuestaPrensa> respuestas;
}

/// Qué papel te ofrece un equipo.
enum RolOferta {
  estrella('Figura del equipo', RolEquipo.titular, 85),
  titular('Titular', RolEquipo.titular, 66),
  rotacion('Rotación', RolEquipo.sexto, 45);

  const RolOferta(this.etiqueta, this.rolEquipo, this.confianza);
  final String etiqueta;
  final RolEquipo rolEquipo;

  /// Confianza del DT con la que arrancás.
  final int confianza;
}

/// Oferta de un equipo en la agencia libre (o al pedir el traspaso).
class OfertaContrato {
  const OfertaContrato({
    required this.franquiciaId,
    required this.rol,
    required this.anios,
    required this.nivelEquipo,
    this.rival,
    this.renovacion = false,
  });

  final String franquiciaId;
  final RolOferta rol;
  final int anios;

  /// Media promedio del plantel (qué tan fuerte es el equipo).
  final int nivelEquipo;

  /// Con quién competís por el puesto: nombre y media del que juega ahí hoy.
  final (String, int)? rival;

  /// Es tu propio equipo renovando.
  final bool renovacion;
}

// -------------------------------------------------------------------------------------------
// Historia de la carrera
// -------------------------------------------------------------------------------------------

/// Una temporada de la carrera de tu jugador.
class TemporadaJugador {
  const TemporadaJugador({
    required this.numero,
    required this.etiqueta,
    required this.franquiciaId,
    required this.edad,
    required this.media,
    required this.pj,
    required this.pts,
    required this.reb,
    required this.ast,
    required this.victorias,
    required this.derrotas,
    required this.resultado,
    this.campeon = false,
    this.allStar = false,
    this.premios = const [],
    this.objetivos = 0,
    this.objetivosTotal = 0,
  });

  final int numero;

  /// "2026–27".
  final String etiqueta;
  final String franquiciaId;
  final int edad, media;
  final int pj;
  final double pts, reb, ast;
  final int victorias, derrotas;
  final String resultado;
  final bool campeon, allStar;
  final List<String> premios;
  final int objetivos, objetivosTotal;

  Map<String, dynamic> toJson() => {
    'n': numero,
    'et': etiqueta,
    'f': franquiciaId,
    'edad': edad,
    'media': media,
    'pj': pj,
    'pts': pts,
    'reb': reb,
    'ast': ast,
    'v': victorias,
    'd': derrotas,
    'res': resultado,
    if (campeon) 'campeon': true,
    if (allStar) 'allStar': true,
    if (premios.isNotEmpty) 'premios': premios,
    'obj': objetivos,
    'objT': objetivosTotal,
  };

  factory TemporadaJugador.fromJson(Map<String, dynamic> j) => TemporadaJugador(
    numero: j['n'] as int,
    etiqueta: j['et'] as String,
    franquiciaId: j['f'] as String,
    edad: j['edad'] as int,
    media: j['media'] as int,
    pj: j['pj'] as int,
    pts: (j['pts'] as num).toDouble(),
    reb: (j['reb'] as num).toDouble(),
    ast: (j['ast'] as num).toDouble(),
    victorias: j['v'] as int,
    derrotas: j['d'] as int,
    resultado: j['res'] as String,
    campeon: j['campeon'] as bool? ?? false,
    allStar: j['allStar'] as bool? ?? false,
    premios: (j['premios'] as List? ?? const []).cast<String>(),
    objetivos: j['obj'] as int? ?? 0,
    objetivosTotal: j['objT'] as int? ?? 0,
  );
}

/// La carrera completa: totales, anillos, premios y el veredicto del Salón de la Fama.
class LegadoCarrera {
  const LegadoCarrera(this.nombre, this.temporadas, {this.retirado = false});

  final String nombre;
  final List<TemporadaJugador> temporadas;
  final bool retirado;

  int get partidos => temporadas.fold(0, (a, s) => a + s.pj);
  int get puntos => temporadas.fold(0, (a, s) => a + (s.pts * s.pj).round());
  int get rebotes => temporadas.fold(0, (a, s) => a + (s.reb * s.pj).round());
  int get asistencias => temporadas.fold(0, (a, s) => a + (s.ast * s.pj).round());
  int get anillos => temporadas.where((s) => s.campeon).length;
  int get allStars => temporadas.where((s) => s.allStar).length;
  int premio(String n) => temporadas.where((s) => s.premios.contains(n)).length;
  int get mvps => premio('MVP');
  int get allNba => temporadas.where((s) => s.premios.any((p) => p.startsWith('All-NBA'))).length;
  int get mejorMedia => temporadas.fold(0, (a, s) => max(a, s.media));

  /// Puntos de Salón de la Fama (anillos, MVP, All-NBA, All-Star y puntos de carrera).
  int get puntosSalon => anillos * 4 + mvps * 6 + allNba * 2 + allStars + puntos ~/ 5000;

  bool get salon => puntosSalon >= 14;

  String get veredicto {
    final p = puntosSalon;
    if (p >= 24) return 'Salón de la Fama en la primera votación: una leyenda de la NBA.';
    if (p >= 14) return 'Salón de la Fama: una carrera de las grandes.';
    if (p >= 7) return 'Candidato al Salón: le faltó un empujón para entrar.';
    if (temporadas.length < 3) return 'Recién empieza: el legado se escribe temporada a temporada.';
    return 'Una carrera digna, sin llegar al Salón.';
  }
}

// -------------------------------------------------------------------------------------------
// Estado de la carrera (se guarda en Temporada.datosModo)
// -------------------------------------------------------------------------------------------

/// Todo lo que tiene tu jugador: atributos, confianza, ánimo, contrato, objetivos e historia.
class EstadoCarrera {
  const EstadoCarrera({
    required this.raiz,
    required this.base,
    required this.atributosBase,
    required this.atributos,
    required this.edad,
    required this.anioBase,
    required this.franquiciaId,
    required this.rolEquipo,
    required this.confianza,
    required this.contrato,
    required this.pick,
    this.numero = 1,
    this.creado,
    this.moral = 65,
    this.fans = 40,
    this.relacion = 55,
    this.phBanco = 0,
    this.phAcreditados = 0,
    this.phGastados = 0,
    this.companeros = const [],
    this.objetivos = const [],
    this.historial = const [],
    this.hitos = const [],
    this.snapPj = 0,
    this.snapValor = 0,
    this.snapVictorias = 0,
    this.snapDerrotas = 0,
    this.cerrada = false,
    this.retirado = false,
    this.prensaHecha = 0,
    this.pidioTraspaso = false,
  });

  /// Id de la primera temporada: las siguientes son `<raiz>-t2`…
  final String raiz;

  /// La carta de arranque (de un jugador real o la de tu creado) con sus estadísticas base.
  final Jugador base;

  /// Atributos de arranque y actuales. Las estadísticas se mueven por la diferencia.
  final Atributos atributosBase, atributos;
  final int edad;

  /// Año del draft (o del arranque): la temporada 1 cierra en el año siguiente.
  final int anioBase;
  final String franquiciaId;
  final RolEquipo rolEquipo;

  /// Confianza del DT 0–100, ánimo 0–100, fans 0–100 y relación con el vestuario 0–100.
  final int confianza, moral, fans, relacion;

  /// Temporadas de contrato que le quedan (incluida la actual) y número de elección en el draft.
  final int contrato, pick;
  final int numero;

  /// Si es un jugador creado, sus datos (null: jugador real).
  final JugadorCreado? creado;

  /// Puntos de habilidad: disponibles, ya acreditados en esta temporada y gastados en total.
  final int phBanco, phAcreditados, phGastados;

  /// Los siete compañeros del equipo (la IA arma el resto).
  final List<Jugador> companeros;
  final List<ObjetivoTemporada> objetivos;
  final List<TemporadaJugador> historial;

  /// Cosas que pasaron: draft, contratos, prensa, traspasos… (para la línea de tiempo).
  final List<String> hitos;

  /// Lo que se vio la última vez (para medir el rendimiento de los partidos nuevos).
  final int snapPj, snapVictorias, snapDerrotas;
  final double snapValor;

  /// La temporada terminó y estás en el receso (entrenar, prensa, contrato).
  final bool cerrada;
  final bool retirado;

  /// Conferencias de prensa ya hechas en este receso.
  final int prensaHecha;
  final bool pidioTraspaso;

  bool get esReal => creado == null;
  String get nombre => base.nombre;
  Posicion get posicion => base.posiciones.first;

  /// Id de la carta de tu jugador en el juego.
  String get jugadorId => creado != null ? 'mc-$raiz' : '${base.idBbref}-mc$raiz-me';

  int get anioCierre => anioBase + numero;
  String get etiquetaTemporada => etiquetaDe(numero);

  String etiquetaDe(int n) {
    final cierre = anioBase + n;
    return '${cierre - 1}–${(cierre % 100).toString().padLeft(2, '0')}';
  }

  Epoca get epoca => epocaDeCierre(anioCierre);

  int get media => max(
    55,
    min(
      ModeloCarrera.tope,
      base.media +
          (1.5 * _suma(ModeloCarrera.pesos(posicion), (a) => (atributos[a] - atributosBase[a]).toDouble())).round(),
    ),
  );

  static double _suma(Map<Atributo, double> w, double Function(Atributo) f) =>
      Atributo.values.fold(0.0, (s, a) => s + w[a]! * f(a));

  List<Insignia> get insignias => Insignia.de(atributos);

  /// Las que ya tenías al arrancar (ya están en las estadísticas) y las que ganaste después.
  List<Insignia> get insigniasDeArranque => Insignia.de(atributosBase);
  List<Insignia> get insigniasGanadas => [
    for (final i in insignias)
      if (!i.la(atributosBase)) i,
  ];

  static Epoca epocaDeCierre(int cierre) {
    if (cierre >= 2020) return Epoca.actualidad;
    if (cierre >= 2010) return Epoca.anios2010;
    if (cierre >= 2000) return Epoca.anios2000;
    if (cierre >= 1990) return Epoca.anios90;
    if (cierre >= 1980) return Epoca.anios80;
    if (cierre >= 1970) return Epoca.anios70;
    if (cierre >= 1960) return Epoca.anios60;
    if (cierre >= 1950) return Epoca.anios50;
    return Epoca.anios40;
  }

  /// Tier de la carta según la media.
  Tier get tier => media >= 95
      ? Tier.sPlus
      : media >= 90
      ? Tier.s
      : media >= 80
      ? Tier.a
      : Tier.b;

  /// La carta de tu jugador hoy: estadísticas movidas por atributos, insignias, relación y ánimo.
  Jugador get carta => Jugador(
    id: jugadorId,
    nbaPlayerId: base.nbaPlayerId,
    nombre: base.nombre,
    franquiciaId: franquiciaId,
    epoca: epoca,
    tier: tier,
    posiciones: base.posiciones,
    rol: base.rol,
    dorsal: 0,
    stats: ModeloCarrera.estadisticasActuales(
      base: base.stats,
      a0: atributosBase,
      a: atributos,
      relacion: relacion,
      moral: moral,
    ),
    media: media,
    equipo: franquiciaId,
    fotos: [
      for (final f in base.fotos)
        if (esReal || f != 'b') f,
    ],
    temporadas: (anioCierre, anioCierre),
    draft: base.draft,
    universidad: base.universidad,
    nacimiento: base.nacimiento,
  );

  LegadoCarrera get legado => LegadoCarrera(nombre, historial, retirado: retirado);

  EstadoCarrera copyWith({
    Jugador? base,
    Atributos? atributos,
    int? edad,
    String? franquiciaId,
    RolEquipo? rolEquipo,
    int? confianza,
    int? moral,
    int? fans,
    int? relacion,
    int? contrato,
    int? numero,
    int? phBanco,
    int? phAcreditados,
    int? phGastados,
    List<Jugador>? companeros,
    List<ObjetivoTemporada>? objetivos,
    List<TemporadaJugador>? historial,
    List<String>? hitos,
    int? snapPj,
    double? snapValor,
    int? snapVictorias,
    int? snapDerrotas,
    bool? cerrada,
    bool? retirado,
    int? prensaHecha,
    bool? pidioTraspaso,
  }) => EstadoCarrera(
    raiz: raiz,
    base: base ?? this.base,
    atributosBase: atributosBase,
    atributos: atributos ?? this.atributos,
    edad: edad ?? this.edad,
    anioBase: anioBase,
    franquiciaId: franquiciaId ?? this.franquiciaId,
    rolEquipo: rolEquipo ?? this.rolEquipo,
    confianza: (confianza ?? this.confianza).clamp(0, 100),
    contrato: contrato ?? this.contrato,
    pick: pick,
    numero: numero ?? this.numero,
    creado: creado,
    moral: (moral ?? this.moral).clamp(0, 100),
    fans: (fans ?? this.fans).clamp(0, 100),
    relacion: (relacion ?? this.relacion).clamp(0, 100),
    phBanco: phBanco ?? this.phBanco,
    phAcreditados: phAcreditados ?? this.phAcreditados,
    phGastados: phGastados ?? this.phGastados,
    companeros: companeros ?? this.companeros,
    objetivos: objetivos ?? this.objetivos,
    historial: historial ?? this.historial,
    hitos: hitos ?? this.hitos,
    snapPj: snapPj ?? this.snapPj,
    snapValor: snapValor ?? this.snapValor,
    snapVictorias: snapVictorias ?? this.snapVictorias,
    snapDerrotas: snapDerrotas ?? this.snapDerrotas,
    cerrada: cerrada ?? this.cerrada,
    retirado: retirado ?? this.retirado,
    prensaHecha: prensaHecha ?? this.prensaHecha,
    pidioTraspaso: pidioTraspaso ?? this.pidioTraspaso,
  );

  /// Lo que se guarda en [Temporada.datosModo]. `raiz` y `numero` quedan arriba para que los
  /// resúmenes de la dinastía (que los leen ahí) funcionen igual.
  Map<String, dynamic> aDatos() => {'raiz': raiz, 'numero': numero, 'carreraJugador': toJson()};

  Map<String, dynamic> toJson() => {
    'raiz': raiz,
    'base': base.toJson(),
    'a0': atributosBase.toJson(),
    'a': atributos.toJson(),
    'edad': edad,
    'anioBase': anioBase,
    'franq': franquiciaId,
    'rol': rolEquipo.name,
    'conf': confianza,
    'contrato': contrato,
    'pick': pick,
    'numero': numero,
    if (creado != null) 'creado': creado!.toJson(),
    'moral': moral,
    'fans': fans,
    'relacion': relacion,
    'ph': phBanco,
    'phAcr': phAcreditados,
    'phGas': phGastados,
    'comp': [for (final j in companeros) j.toJson()],
    'objetivos': [for (final o in objetivos) o.toJson()],
    'historial': [for (final h in historial) h.toJson()],
    if (hitos.isNotEmpty) 'hitos': hitos,
    'snapPj': snapPj,
    'snapValor': snapValor,
    'snapV': snapVictorias,
    'snapD': snapDerrotas,
    if (cerrada) 'cerrada': true,
    if (retirado) 'retirado': true,
    if (prensaHecha > 0) 'prensa': prensaHecha,
    if (pidioTraspaso) 'traspaso': true,
  };

  factory EstadoCarrera.fromJson(Map<String, dynamic> j) => EstadoCarrera(
    raiz: j['raiz'] as String,
    base: Jugador.fromJson(j['base'] as Map<String, dynamic>),
    atributosBase: Atributos.fromJson(j['a0'] as Map<String, dynamic>),
    atributos: Atributos.fromJson(j['a'] as Map<String, dynamic>),
    edad: j['edad'] as int,
    anioBase: j['anioBase'] as int,
    franquiciaId: j['franq'] as String,
    rolEquipo: RolEquipo.values.byName(j['rol'] as String),
    confianza: j['conf'] as int,
    contrato: j['contrato'] as int,
    pick: j['pick'] as int,
    numero: j['numero'] as int? ?? 1,
    creado: j['creado'] == null ? null : JugadorCreado.fromJson(j['creado'] as Map<String, dynamic>),
    moral: j['moral'] as int? ?? 65,
    fans: j['fans'] as int? ?? 40,
    relacion: j['relacion'] as int? ?? 55,
    phBanco: j['ph'] as int? ?? 0,
    phAcreditados: j['phAcr'] as int? ?? 0,
    phGastados: j['phGas'] as int? ?? 0,
    companeros: [for (final x in j['comp'] as List? ?? const []) Jugador.fromJson(x as Map<String, dynamic>)],
    objetivos: [
      for (final x in j['objetivos'] as List? ?? const []) ObjetivoTemporada.fromJson(x as Map<String, dynamic>),
    ],
    historial: [
      for (final x in j['historial'] as List? ?? const []) TemporadaJugador.fromJson(x as Map<String, dynamic>),
    ],
    hitos: (j['hitos'] as List? ?? const []).cast<String>(),
    snapPj: j['snapPj'] as int? ?? 0,
    snapValor: (j['snapValor'] as num? ?? 0).toDouble(),
    snapVictorias: j['snapV'] as int? ?? 0,
    snapDerrotas: j['snapD'] as int? ?? 0,
    cerrada: j['cerrada'] as bool? ?? false,
    retirado: j['retirado'] as bool? ?? false,
    prensaHecha: j['prensa'] as int? ?? 0,
    pidioTraspaso: j['traspaso'] as bool? ?? false,
  );

  /// El estado de una partida de Mi carrera (null si no es una).
  static EstadoCarrera? de(Temporada t) {
    if (t.modoJuego != ModoJuego.carreraJugador) return null;
    final d = t.datosModo['carreraJugador'];
    return d is Map<String, dynamic> ? EstadoCarrera.fromJson(d) : null;
  }
}

/// Lo que pasa al terminar la temporada (para mostrarlo en el receso).
class CierreTemporada {
  const CierreTemporada({
    required this.estado,
    required this.temporada,
    required this.objetivos,
    required this.phBase,
    required this.phObjetivos,
    required this.phPremios,
    required this.desarrollo,
    required this.insigniasNuevas,
  });

  final EstadoCarrera estado;
  final TemporadaJugador temporada;

  /// Cada objetivo y si se cumplió.
  final List<(ObjetivoTemporada, bool)> objetivos;
  final int phBase, phObjetivos, phPremios;

  /// Cambio natural de atributos por la edad (aplicado en [estado]).
  final Map<Atributo, int> desarrollo;
  final List<Insignia> insigniasNuevas;
}

// -------------------------------------------------------------------------------------------
// El servicio: todo lo que necesita Liga
// -------------------------------------------------------------------------------------------

class CarreraJugador {
  CarreraJugador(this.liga);

  final Liga liga;

  static int _hash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

  static const maxCompaneros = 7;

  // ---------- Arranque ----------

  /// Jugadores reales para elegir: la carta más temprana de cada persona, de mayor a menor media.
  /// Con [texto] filtra por nombre.
  List<Jugador> candidatosReales({String texto = '', int limite = 60}) {
    final q = _normalizar(texto);
    final primera = <int, Jugador>{};
    for (final j in liga.catalogo) {
      if (j.nbaPlayerId <= 0) continue;
      final actual = primera[j.nbaPlayerId];
      final a = j.temporadas?.$1 ?? 9999, b = actual?.temporadas?.$1 ?? 9999;
      if (actual == null || a < b) primera[j.nbaPlayerId] = j;
    }
    final lista = [
      for (final j in primera.values)
        if (j.tier != Tier.b && (q.isEmpty || _normalizar(j.nombre).contains(q))) j,
    ]..sort((a, b) => b.media.compareTo(a.media));
    return lista.take(limite).toList();
  }

  static String _normalizar(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ć', 'c')
      .replaceAll('č', 'c')
      .replaceAll('š', 's')
      .replaceAll('ž', 'z')
      .replaceAll('ñ', 'n')
      .trim();

  /// El orden de elección del draft (de la franquicia que elige primera a la última): sorteo con [semilla].
  List<String> ordenDraft(int semilla) => [for (final f in liga.franquicias) f.id]..shuffle(Random(semilla));

  /// El combine de un jugador creado: cinco pruebas y la elección en el draft que proyectan.
  ResultadoCombine combine(JugadorCreado jc, Random azar) {
    final a = jc.atributos;
    int nota(double valor) => (valor + (azar.nextDouble() - 0.5) * 14).round().clamp(30, 99);
    String comentario(int n, String bueno, String malo) => n >= 78
        ? bueno
        : n >= 62
        ? 'Cumple sin deslumbrar.'
        : malo;
    final sprint = nota(a[Atributo.fisico] * 0.85 + 10);
    final salto = nota(a[Atributo.fisico] * 0.9 + 6);
    final tiro = nota(a[Atributo.tiro] * 0.92 + 8);
    final defensa = nota(a[Atributo.defensa] * 0.92 + 8);
    final iq = nota(a[Atributo.iq] * 0.92 + 8);
    final pruebas = [
      PruebaCombine('Sprint de tres cuartos', sprint, comentario(sprint, 'Un cohete.', 'Lento para la NBA.')),
      PruebaCombine('Salto vertical', salto, comentario(salto, 'Vuela hasta el aro.', 'Le falta explosión.')),
      PruebaCombine('Tiro en movimiento', tiro, comentario(tiro, 'Red, red, red.', 'Tiene que trabajar el tiro.')),
      PruebaCombine('Defensa uno contra uno', defensa, comentario(defensa, 'Una pared.', 'Lo pasan por arriba.')),
      PruebaCombine('Entrevistas y lectura de juego', iq, comentario(iq, 'Un jugador con cabeza.', 'Decide tarde.')),
    ];
    final promedio = pruebas.fold(0, (s, p) => s + p.nota) / pruebas.length;
    final puntaje = 0.65 * jc.media + 0.35 * promedio;
    final pick = (18 - (puntaje - 67) * 1.6 + (azar.nextDouble() - 0.5) * 8).round().clamp(1, 60);
    return ResultadoCombine(pruebas: pruebas, puntaje: puntaje, pick: pick);
  }

  /// Confianza del DT con la que arrancás, según tu elección en el draft (y tu nivel).
  static int confianzaInicial(int pick, int media) {
    final porPick = pick <= 5
        ? 82
        : pick <= 14
        ? 68
        : pick <= 30
        ? 52
        : pick <= 45
        ? 38
        : 30;
    return max(porPick, ((media - 55) * 1.8).round()).clamp(0, 100);
  }

  /// Temporadas de contrato de novato: 4 en primera ronda, 2 en segunda o sin draft.
  static int contratoNovato(int pick) => pick <= 30 ? 4 : 2;

  /// Qué tan fuerte es el equipo que te elige: los peores equipos eligen primero.
  static double nivelEquipoPorPick(int pick) => 74 + (pick.clamp(1, 30) - 1) * 0.4;

  static RolEquipo rolPorConfianza(int confianza) => confianza >= 60
      ? RolEquipo.titular
      : confianza >= 35
      ? RolEquipo.sexto
      : RolEquipo.banco;

  /// El estado de arranque de un jugador real (su carta más temprana) con el draft real.
  EstadoCarrera estadoReal({required String raiz, required Jugador carta, int? pick}) {
    final draft = carta.draft;
    final eleccion = pick ?? draft?.$2 ?? (carta.media >= 90 ? 3 : (carta.media >= 80 ? 10 : 25));
    final anioBase = draft?.$1 ?? ((carta.temporadas?.$1 ?? 2025) - 1);
    final edad = carta.nacimiento == null ? 20 : (anioBase - carta.nacimiento!).clamp(18, 24);
    final pos = carta.posiciones.first;
    final objetivo = 55 + (carta.media - 60) / 1.5;
    final a0 = ModeloCarrera.desdePerfil(carta.rol, pos, objetivo);
    final confianza = confianzaInicial(eleccion, carta.media);
    return EstadoCarrera(
      raiz: raiz,
      base: carta,
      atributosBase: a0,
      atributos: a0,
      edad: edad,
      anioBase: anioBase,
      franquiciaId: carta.franquiciaId,
      rolEquipo: rolPorConfianza(confianza),
      confianza: confianza,
      contrato: contratoNovato(eleccion),
      pick: eleccion,
      hitos: [
        '$anioBase: ${carta.nombre} es elegido ${eleccion == 1 ? 'primero' : 'n.º $eleccion'} en el draft por '
            '${_nombre(carta.franquiciaId)}.',
      ],
    );
  }

  /// El estado de arranque de un jugador creado, elegido en el [pick] por [franquiciaId].
  EstadoCarrera estadoCreado({
    required String raiz,
    required JugadorCreado creado,
    required int pick,
    required String franquiciaId,
    int anioBase = 2026,
    int edad = 20,
  }) {
    final a0 = creado.atributos;
    final carta = creado.comoCarta(id: 'mc-$raiz', franquiciaId: franquiciaId, anio: anioBase + 1);
    final confianza = confianzaInicial(pick, carta.media);
    return EstadoCarrera(
      raiz: raiz,
      base: carta,
      atributosBase: a0,
      atributos: a0,
      edad: edad,
      anioBase: anioBase,
      franquiciaId: franquiciaId,
      rolEquipo: rolPorConfianza(confianza),
      confianza: confianza,
      contrato: contratoNovato(pick),
      pick: pick,
      creado: creado,
      hitos: [
        pick > 50
            ? '$anioBase: ${creado.nombre} no es elegido en el draft y firma con ${_nombre(franquiciaId)}.'
            : '$anioBase: ${creado.nombre} es elegido n.º $pick en el draft por ${_nombre(franquiciaId)}.',
      ],
    );
  }

  String _nombre(String id) {
    for (final f in liga.franquicias) {
      if (f.id == id) return f.nombreCompleto;
    }
    return id;
  }

  /// Arma la primera temporada: compañeros, plantel, táctica, calendario y rivales.
  Temporada nuevaCarrera({required EstadoCarrera estado, required Dificultad dificultad}) {
    final azar = Random(_hash('${estado.raiz}-companeros'));
    final objetivoEquipo = estado.esReal ? 80.0 : nivelEquipoPorPick(estado.pick);
    final companeros = armarCompaneros(
      franquiciaId: estado.franquiciaId,
      epoca: estado.epoca,
      objetivo: objetivoEquipo,
      excluidos: {estado.base.nbaPlayerId},
      azar: azar,
    );
    final e = estado.copyWith(
      companeros: companeros,
      objetivos: objetivosPara(estado, Random(_hash('${estado.raiz}-obj-1'))),
    );
    return _armarTemporada(id: e.raiz, estado: e, franquiciaId: e.franquiciaId, dificultad: dificultad, origen: null);
  }

  Temporada _armarTemporada({
    required String id,
    required EstadoCarrera estado,
    required String franquiciaId,
    required Dificultad dificultad,
    required Temporada? origen,
  }) {
    final yo = estado.carta;
    final (plantel, suplentes, rol) = ubicar(yo, estado.companeros, estado.rolEquipo);
    final e = estado.copyWith(rolEquipo: rol);
    final t = Temporada(
      id: id,
      franquiciaUsuarioId: franquiciaId,
      plantel: plantel,
      tactica: recomendar(PerfilPlantel.de(plantel)).tactica,
      tacticaConfirmada: true,
      dificultad: dificultad,
      suplentes: suplentes,
      modoJuego: ModoJuego.carreraJugador,
      datosModo: e.aDatos(),
    );
    liga.registrarCarta(yo);
    return liga.iniciar(t, excluidos: {yo.nbaPlayerId});
  }

  // ---------- Compañeros y plantel ----------

  /// Siete compañeros de [franquiciaId] (de la [epoca] si alcanza): uno por puesto titular y dos más,
  /// con medias cercanas a [objetivo]. Los de [fijos] se conservan.
  List<Jugador> armarCompaneros({
    required String franquiciaId,
    required Epoca epoca,
    required double objetivo,
    required Set<int> excluidos,
    required Random azar,
    List<Jugador> fijos = const [],
  }) {
    final usados = {...excluidos, for (final j in fijos) j.nbaPlayerId};
    List<Jugador> pool(bool soloEpoca) => [
      for (final j in liga.catalogo)
        if (j.franquiciaId == franquiciaId && (!soloEpoca || j.epoca == epoca) && j.nbaPlayerId > 0) j,
    ];
    var propios = pool(true);
    if (Posicion.titulares.any((p) => propios.where((j) => j.posiciones.first == p).length < 2)) {
      propios = pool(false);
    }
    final liguilla = [
      for (final j in liga.catalogo)
        if (j.epoca == epoca && j.nbaPlayerId > 0) j,
    ];
    final elegidos = [...fijos];

    Jugador? elegir(List<Jugador> fuente, bool Function(Jugador) cumple) {
      final candidatos = [
        for (final j in fuente)
          if (!usados.contains(j.nbaPlayerId) && cumple(j)) j,
      ]..sort((a, b) => (a.media - objetivo).abs().compareTo((b.media - objetivo).abs()));
      if (candidatos.isEmpty) return null;
      final j = candidatos[azar.nextInt(min(3, candidatos.length))];
      usados.add(j.nbaPlayerId);
      return j;
    }

    for (final p in Posicion.titulares) {
      if (elegidos.any((j) => j.posiciones.first == p)) continue;
      final j = elegir(propios, (j) => j.posiciones.first == p) ?? elegir(liguilla, (j) => j.posiciones.first == p);
      if (j != null) elegidos.add(j);
    }
    while (elegidos.length < maxCompaneros) {
      final j = elegir(propios, (_) => true) ?? elegir(liguilla, (_) => true);
      if (j == null) break;
      elegidos.add(j);
    }
    return elegidos;
  }

  /// Ubica a tu jugador y a los [companeros]: quinteto, sexto hombre y hasta dos suplentes. Si tu rol
  /// no se puede armar (por posiciones), baja a sexto hombre y después a banco.
  (Plantel, List<Jugador>, RolEquipo) ubicar(Jugador yo, List<Jugador> companeros, RolEquipo rol) {
    final orden = [
      for (final r in RolEquipo.values)
        if (r.index >= rol.index) r,
    ];
    for (final r in orden) {
      final resultado = _intentar(yo, companeros, r);
      if (resultado != null) return (resultado.$1, resultado.$2, r);
    }
    // Último recurso: un plantel de emergencia con los siete mejores (el motor no exige posiciones).
    final todos = [yo, ...companeros]..sort((a, b) => b.media.compareTo(a.media));
    final puestos = <Posicion, Jugador>{};
    for (var i = 0; i < Posicion.values.length && i < todos.length; i++) {
      puestos[Posicion.values[i]] = todos[i];
    }
    return (Plantel.deEmergencia(puestos), todos.skip(6).take(Temporada.maxSuplentes).toList(), RolEquipo.titular);
  }

  (Plantel, List<Jugador>)? _intentar(Jugador yo, List<Jugador> companeros, RolEquipo rol) {
    var plantel = const Plantel();
    switch (rol) {
      case RolEquipo.titular:
        final pos = yo.posiciones.firstWhere((p) => p != Posicion.sextoHombre, orElse: () => Posicion.alero);
        plantel = plantel.asignar(yo, pos);
      case RolEquipo.sexto:
        plantel = plantel.asignar(yo, Posicion.sextoHombre);
      case RolEquipo.banco:
        break;
    }
    final pool = [...companeros]..sort((a, b) => b.media.compareTo(a.media));
    final libres = [
      for (final p in Posicion.values)
        if (!plantel.estaOcupada(p)) p,
    ];
    // Primero los puestos con menos candidatos; el sexto hombre al final.
    libres.sort((a, b) {
      if (a == Posicion.sextoHombre) return 1;
      if (b == Posicion.sextoHombre) return -1;
      return pool.where((j) => j.puedeJugarEn(a)).length.compareTo(pool.where((j) => j.puedeJugarEn(b)).length);
    });
    final asignados = <Posicion, Jugador>{};
    bool llenar(int i) {
      if (i == libres.length) return true;
      final p = libres[i];
      for (final j in pool) {
        if (asignados.values.contains(j) || !j.puedeJugarEn(p)) continue;
        asignados[p] = j;
        if (llenar(i + 1)) return true;
        asignados.remove(p);
      }
      return false;
    }

    if (!llenar(0)) return null;
    for (final e in asignados.entries) {
      plantel = plantel.asignar(e.value, e.key);
    }
    final resto = [
      for (final j in pool)
        if (!asignados.values.contains(j)) j,
    ];
    final suplentes = <Jugador>[if (rol == RolEquipo.banco) yo, ...resto].take(Temporada.maxSuplentes).toList();
    return (plantel, suplentes);
  }

  /// Vuelve a ubicar a tu jugador (con su carta actual) en la temporada: rol, estadísticas y plantel.
  Temporada sincronizar(Temporada t, EstadoCarrera e) {
    final yo = e.carta;
    liga.registrarCarta(yo);
    // Sin compañeros suficientes no hay nada que reubicar (el estado todavía no armó el equipo).
    if (e.companeros.length < 6) return t.copyWith(datosModo: e.aDatos());
    final (plantel, suplentes, rol) = ubicar(yo, e.companeros, e.rolEquipo);
    final ne = rol == e.rolEquipo ? e : e.copyWith(rolEquipo: rol);
    final tactica = t.tacticaConfirmada ? t.tactica : recomendar(PerfilPlantel.de(plantel)).tactica;
    return t.copyWith(plantel: plantel, suplentes: suplentes, tactica: tactica, datosModo: ne.aDatos());
  }

  // ---------- Durante la temporada ----------

  /// Puntos de habilidad que da una línea de temporada: 0,1 por partido y el rendimiento sobre 6.
  static double phDeLinea(LineaEstadistica? l) {
    if (l == null || l.pj == 0) return 0;
    final valor = (l.pts + 0.7 * l.reb + 0.7 * l.ast + l.rob + l.tap - l.per) / l.pj;
    return min(24.0, l.pj * 0.1 + max(0.0, valor - 6) * 0.25);
  }

  static double _valorTotal(LineaEstadistica l) => l.pts + 0.7 * l.reb + 0.7 * l.ast + l.rob + l.tap - l.per;

  /// Se llama en cada guardado de la temporada: acredita puntos, mueve la confianza, el ánimo y los
  /// fans según los partidos nuevos, y reubica a tu jugador si cambió su rol.
  Temporada alGuardar(Temporada t) {
    final e = EstadoCarrera.de(t);
    if (e == null || e.retirado) return t;
    final l = t.lineas[e.jugadorId];
    final registro = t.registroUsuario;
    var ne = e;
    if (l != null && l.pj > e.snapPj) {
      final nuevos = l.pj - e.snapPj;
      final promedio = (_valorTotal(l) - e.snapValor) / nuevos;
      final esperado = max(4.0, (e.media - 58) * 0.75);
      final ratio = promedio / esperado;
      final paso = min(nuevos, 6) / 6.0;
      final victorias = registro.victorias - e.snapVictorias, derrotas = registro.derrotas - e.snapDerrotas;
      final tasa = victorias + derrotas == 0 ? 0.5 : victorias / (victorias + derrotas);
      final dConfianza = ((ratio - 1) * 10).clamp(-6.0, 6.0) * paso + (e.moral - 50) / 50.0 * paso;
      final dMoral = (ratio > 1.1 ? 2.0 : (ratio < 0.7 ? -2.0 : 0.0)) * paso + (tasa - 0.5) * 6 * paso;
      final dFans = (ratio - 0.9) * 2 * paso + (tasa - 0.5) * 2 * paso;
      final acreditar = max(0, phDeLinea(l).floor() - e.phAcreditados);
      ne = e.copyWith(
        confianza: (e.confianza + dConfianza).round(),
        moral: (e.moral + dMoral).round(),
        fans: (e.fans + dFans).round(),
        phBanco: e.phBanco + acreditar,
        phAcreditados: e.phAcreditados + acreditar,
        snapPj: l.pj,
        snapValor: _valorTotal(l),
        snapVictorias: registro.victorias,
        snapDerrotas: registro.derrotas,
        rolEquipo: _rolConHisterecis(e.rolEquipo, (e.confianza + dConfianza).round()),
      );
    } else if (e.snapVictorias != registro.victorias || e.snapDerrotas != registro.derrotas) {
      ne = e.copyWith(snapVictorias: registro.victorias, snapDerrotas: registro.derrotas);
    }
    return sincronizar(t, ne);
  }

  /// Cambia de rol con histéresis: hace falta pasar un umbral con margen para subir y bajar.
  static RolEquipo _rolConHisterecis(RolEquipo actual, int confianza) => switch (actual) {
    RolEquipo.titular => confianza < 50 ? RolEquipo.sexto : RolEquipo.titular,
    RolEquipo.sexto => confianza >= 65 ? RolEquipo.titular : (confianza < 30 ? RolEquipo.banco : RolEquipo.sexto),
    RolEquipo.banco => confianza >= 40 ? RolEquipo.sexto : RolEquipo.banco,
  };

  /// Lo que lleva tu jugador en la temporada y cómo va el equipo.
  MarcaTemporada marca(Temporada t, EstadoCarrera e) {
    final l = t.lineas[e.jugadorId];
    final pj = l?.pj ?? 0;
    final r = t.registroUsuario;
    final playoffs = t.series.any(
      (s) => (s.altoId == t.franquiciaUsuarioId || s.bajoId == t.franquiciaUsuarioId) && !s.ronda.esPlayIn,
    );
    return MarcaTemporada(
      pj: pj,
      ppg: pj == 0 ? 0 : l!.pts / pj,
      rpg: pj == 0 ? 0 : l!.reb / pj,
      apg: pj == 0 ? 0 : l!.ast / pj,
      defensaPorPartido: pj == 0 ? 0 : (l!.rob + l.tap) / pj,
      victorias: r.victorias,
      derrotas: r.derrotas,
      playoffs: playoffs,
      allStar: _esAllStar(t, e),
    );
  }

  bool _esAllStar(Temporada t, EstadoCarrera e) {
    final a = t.allStar;
    if (a == null) return false;
    return [...a.este, ...a.oeste].any((j) => j.id == e.jugadorId);
  }

  // ---------- Puntos de habilidad ----------

  bool puedeSubir(EstadoCarrera e, Atributo a) =>
      e.atributos[a] < ModeloCarrera.tope && e.phBanco >= ModeloCarrera.costo(e.atributos[a]);

  /// Sube un punto de [a] gastando lo que cuesta. Si no alcanza, devuelve el mismo estado.
  EstadoCarrera subir(EstadoCarrera e, Atributo a) {
    if (!puedeSubir(e, a)) return e;
    final costo = ModeloCarrera.costo(e.atributos[a]);
    return e.copyWith(
      atributos: e.atributos.con(a, e.atributos[a] + 1),
      phBanco: e.phBanco - costo,
      phGastados: e.phGastados + costo,
    );
  }

  // ---------- Objetivos ----------

  /// Tres objetivos del DT: uno de estadística según tu puesto, uno de equipo y uno personal.
  List<ObjetivoTemporada> objetivosPara(EstadoCarrera e, Random azar) {
    final s = e.carta.stats;
    double medio(double v) => max(0.5, (v * 0.95 * 2).round() / 2);
    final ObjetivoTemporada stat = switch (e.carta.rol) {
      RolCancha.baseDefensivo ||
      RolCancha.cerrojoDefensivo ||
      RolCancha.protectorAro ||
      RolCancha.especialista3D ||
      RolCancha.inyeccionEnergia => ObjetivoTemporada(TipoObjetivo.defensa, medio(s.robP + s.tapP)),
      _ => switch (e.posicion) {
        Posicion.base => ObjetivoTemporada(TipoObjetivo.asistencias, medio(s.app)),
        Posicion.alaPivot || Posicion.pivot => ObjetivoTemporada(TipoObjetivo.rebotes, medio(s.rpp)),
        _ => ObjetivoTemporada(TipoObjetivo.puntos, medio(s.ppp)),
      },
    };
    final equipo = e.numero.isOdd
        ? const ObjetivoTemporada(TipoObjetivo.playoffs, 1)
        : const ObjetivoTemporada(TipoObjetivo.victorias, 44);
    final personal = e.media >= 84
        ? const ObjetivoTemporada(TipoObjetivo.allStar, 1)
        : const ObjetivoTemporada(TipoObjetivo.partidos, 65);
    return [stat, equipo, personal];
  }

  // ---------- Fin de temporada ----------

  /// Cierra la temporada: resumen de tu jugador, objetivos cumplidos, puntos de habilidad extra, el
  /// cambio natural por la edad, y deja el estado listo para el receso. Determinístico.
  CierreTemporada cerrar(Temporada t, EstadoCarrera e, String Function(String id) nombreDe) {
    final marcaFinal = marca(t, e);
    final resumen = CarreraDinastia(liga).resumir(t, nombreDe);
    final l = t.lineas[e.jugadorId];
    final premios = t.calendario.isEmpty ? const <String>[] : _premiosDe(t, e);
    final resultados = [for (final o in e.objetivos) (o, o.avance(marcaFinal).$2)];
    final cumplidos = resultados.where((r) => r.$2).length;
    final phBase = max(0, phDeLinea(l).floor() - e.phAcreditados);
    final phObjetivos = cumplidos * 3;
    final phPremios = (resumen.campeon ? 4 : 0) + premios.length * 2 + (marcaFinal.allStar ? 2 : 0);
    final azar = Random(_hash('${e.raiz}-cierre-${e.numero}'));
    final edadNueva = e.edad + 1;
    final desarrollo = ModeloCarrera.desarrolloNatural(edadNueva, azar);
    final atributosNuevos = e.atributos.sumar(desarrollo);
    final insigniasNuevas = [
      for (final i in Insignia.de(atributosNuevos))
        if (!e.insignias.contains(i)) i,
    ];
    final temporada = TemporadaJugador(
      numero: e.numero,
      etiqueta: e.etiquetaTemporada,
      franquiciaId: t.franquiciaUsuarioId,
      edad: e.edad,
      media: e.media,
      pj: marcaFinal.pj,
      pts: marcaFinal.ppg,
      reb: marcaFinal.rpg,
      ast: marcaFinal.apg,
      victorias: marcaFinal.victorias,
      derrotas: marcaFinal.derrotas,
      resultado: resumen.resultado,
      campeon: resumen.campeon,
      allStar: marcaFinal.allStar,
      premios: premios,
      objetivos: cumplidos,
      objetivosTotal: resultados.length,
    );
    final hitos = <String>[
      ...e.hitos,
      if (resumen.campeon) '${e.etiquetaTemporada}: ¡campeón con ${_nombre(t.franquiciaUsuarioId)}!',
      for (final p in premios) '${e.etiquetaTemporada}: $p.',
      if (marcaFinal.allStar) '${e.etiquetaTemporada}: elegido para el All-Star.',
    ];
    final dConfianza = (cumplidos - (resultados.length - cumplidos)) * 2 + (resumen.campeon ? 4 : 0);
    final dMoral = (resumen.campeon ? 8 : 0) + (cumplidos >= 2 ? 4 : -3) + (resumen.victorias >= 50 ? 3 : 0);
    final dFans =
        (marcaFinal.allStar ? 6 : 0) + (resumen.campeon ? 8 : 0) + premios.length * 3 + (cumplidos >= 2 ? 2 : -1);
    final estado = e.copyWith(
      atributos: atributosNuevos,
      edad: edadNueva,
      contrato: e.contrato - 1,
      phBanco: e.phBanco + phBase + phObjetivos + phPremios,
      phAcreditados: 0,
      historial: [...e.historial, temporada],
      hitos: hitos,
      confianza: e.confianza + dConfianza,
      moral: e.moral + dMoral,
      fans: e.fans + dFans,
      cerrada: true,
      prensaHecha: 0,
    );
    return CierreTemporada(
      estado: estado,
      temporada: temporada,
      objetivos: resultados,
      phBase: phBase,
      phObjetivos: phObjetivos,
      phPremios: phPremios,
      desarrollo: desarrollo,
      insigniasNuevas: insigniasNuevas,
    );
  }

  List<String> _premiosDe(Temporada t, EstadoCarrera e) {
    final premios = calcularPremios(t, liga);
    return [
      for (final (nombre, g) in premios.de(t.franquiciaUsuarioId))
        if (g.jugador.id == e.jugadorId) nombre,
      for (var i = 0; i < premios.allNba.length; i++)
        if (premios.allNba[i].any((g) => g.jugador.id == e.jugadorId)) 'All-NBA ${i + 1}.º equipo',
    ];
  }

  // ---------- Prensa ----------

  /// Dos preguntas de prensa para este receso (distintas cada temporada).
  List<PreguntaPrensa> preguntasDelReceso(EstadoCarrera e) {
    final azar = Random(_hash('${e.raiz}-prensa-${e.numero}'));
    final banco = [..._bancoPrensa]..shuffle(azar);
    return banco.take(2).toList();
  }

  /// Aplica una respuesta de prensa: mueve confianza, ánimo, fans y relación.
  EstadoCarrera responderPrensa(EstadoCarrera e, RespuestaPrensa r) => e.copyWith(
    confianza: e.confianza + r.confianza,
    moral: e.moral + r.moral,
    fans: e.fans + r.fans,
    relacion: e.relacion + r.relacion,
    prensaHecha: e.prensaHecha + 1,
    hitos: [...e.hitos, if (r.fans.abs() + r.relacion.abs() >= 6) '${e.etiquetaTemporada}: ${r.reaccion}'],
  );

  static const _bancoPrensa = [
    PreguntaPrensa('Te toca más pelota que a los veteranos. ¿Cómo lo llevás con el vestuario?', [
      RespuestaPrensa(
        'Aprendo de ellos todos los días.',
        'Los veteranos agradecieron las palabras del joven.',
        relacion: 5,
        moral: 1,
      ),
      RespuestaPrensa(
        'La pelota tiene que ir a quien está caliente.',
        'Polémica: "la pelota va al que está caliente".',
        confianza: 2,
        relacion: -4,
        fans: 3,
      ),
      RespuestaPrensa('Prefiero no hablar de eso.', 'Sin declaraciones.'),
    ]),
    PreguntaPrensa('Los hinchas piden que el equipo gane más. ¿Es culpa tuya?', [
      RespuestaPrensa(
        'Es de todos, y yo soy el primero.',
        'El jugador se hizo cargo ante la prensa.',
        confianza: 3,
        fans: 3,
        relacion: 2,
      ),
      RespuestaPrensa(
        'El problema es que nos falta un refuerzo.',
        'Críticas al armado del plantel.',
        fans: 4,
        confianza: -5,
        relacion: -2,
      ),
      RespuestaPrensa('Estamos trabajando para mejorar.', 'Una respuesta de manual.', moral: 1),
    ]),
    PreguntaPrensa('¿Qué esperás de tu próxima temporada?', [
      RespuestaPrensa(
        'Ser All-Star y pelear el anillo.',
        'Grandes promesas del jugador.',
        moral: 3,
        fans: 4,
        confianza: -2,
      ),
      RespuestaPrensa('Ayudar al equipo en lo que haga falta.', 'Humildad y trabajo.', confianza: 3, relacion: 3),
      RespuestaPrensa('Ir partido a partido.', 'Frase clásica de vestuario.', moral: 1),
    ]),
    PreguntaPrensa('El entrenador dijo que te falta intensidad en defensa. ¿Qué le contestás?', [
      RespuestaPrensa(
        'Tiene razón: voy a trabajarlo.',
        'El jugador aceptó la crítica del DT.',
        confianza: 5,
        moral: -1,
      ),
      RespuestaPrensa(
        'Defiendo como me piden.',
        'Pequeño cruce con el cuerpo técnico.',
        confianza: -5,
        moral: 2,
        fans: 1,
      ),
      RespuestaPrensa(
        'Con lo que meto en ataque alcanza.',
        'Su respuesta cayó mal en el vestuario.',
        confianza: -7,
        relacion: -5,
        fans: 2,
      ),
    ]),
    PreguntaPrensa('Un rival dijo que sos sobrevalorado. ¿Qué opinás?', [
      RespuestaPrensa('Que lo diga en la cancha.', 'El jugador le contestó al rival.', moral: 4, fans: 4),
      RespuestaPrensa('Le deseo suerte.', 'Elegancia ante la provocación.', fans: 2, relacion: 2),
      RespuestaPrensa(
        'Se lo voy a recordar en el próximo cruce.',
        'Se calentó el clásico.',
        moral: 5,
        fans: 5,
        relacion: -2,
        confianza: -2,
      ),
    ]),
    PreguntaPrensa('Hay rumores de que querés irte. ¿Es cierto?', [
      RespuestaPrensa('Estoy muy cómodo acá.', 'El jugador calmó los rumores.', fans: 4, confianza: 3, relacion: 2),
      RespuestaPrensa('Veremos qué pasa en la agencia libre.', 'Los rumores siguen vivos.', fans: -4, confianza: -3),
      RespuestaPrensa('No hablo de contratos.', 'Silencio y misterio.'),
    ]),
    PreguntaPrensa('¿Quién fue tu mejor compañero esta temporada?', [
      RespuestaPrensa('Todos, el vestuario es una familia.', 'El grupo se sintió reconocido.', relacion: 6, moral: 2),
      RespuestaPrensa('El que me pasó la pelota en los finales.', 'Un guiño al armador.', relacion: 3, fans: 1),
      RespuestaPrensa(
        'Yo mismo, soy el que más trabaja.',
        'Dichos poco felices del joven.',
        relacion: -6,
        fans: 1,
        moral: 2,
      ),
    ]),
    PreguntaPrensa('Te lesionaste varias veces. ¿Te preocupa tu físico?', [
      RespuestaPrensa(
        'Voy a cuidarme más en el receso.',
        'Más fisioterapia en el plan del jugador.',
        moral: 2,
        confianza: 2,
      ),
      RespuestaPrensa('Son cosas del juego.', 'Sin drama.', moral: 1),
      RespuestaPrensa('Si me cuidan menos, juego igual.', 'El cuerpo técnico se preocupó.', confianza: -3, fans: 3),
    ]),
  ];

  // ---------- Contrato y traspasos ----------

  /// Ofertas de contrato: la renovación de tu equipo (salvo que pidas traspaso) y tres equipos más.
  List<OfertaContrato> ofertas(Temporada t, EstadoCarrera e, {required bool traspaso}) {
    final azar = Random(_hash('${e.raiz}-ofertas-${e.numero}-${traspaso ? 1 : 0}'));
    final otros = [
      for (final f in liga.franquicias)
        if (f.id != e.franquiciaId) f.id,
    ]..shuffle(azar);
    final lista = <OfertaContrato>[];
    if (!traspaso) {
      final rival = _titularDe(e.companeros, e.posicion);
      lista.add(
        OfertaContrato(
          franquiciaId: e.franquiciaId,
          rol: _rolOferta(e.media, rival?.$2, e.confianza),
          anios: 2 + azar.nextInt(3),
          nivelEquipo: _nivelPropio(t, e),
          rival: rival,
          renovacion: true,
        ),
      );
    }
    for (final id in otros.take(traspaso ? 4 : 3)) {
      final plantel = _plantelRival(t, id);
      final rival = plantel == null ? null : _titularDe(plantel.jugadores.toList(), e.posicion);
      lista.add(
        OfertaContrato(
          franquiciaId: id,
          rol: _rolOferta(e.media, rival?.$2, e.confianza + 10),
          anios: 1 + azar.nextInt(4),
          nivelEquipo: _nivelDe(plantel),
          rival: rival,
        ),
      );
    }
    return lista;
  }

  /// El mejor de [jugadores] en [posicion] (nombre y media): con quién competirías por el puesto.
  (String, int)? _titularDe(List<Jugador> jugadores, Posicion posicion) {
    final candidatos = [
      for (final j in jugadores)
        if (j.posiciones.first == posicion) j,
    ]..sort((a, b) => b.media.compareTo(a.media));
    final j = candidatos.firstOrNull;
    return j == null ? null : (j.nombre, j.media);
  }

  int _nivelPropio(Temporada t, EstadoCarrera e) {
    final ms = [for (final j in e.companeros) j.media]..sort();
    return ms.isEmpty ? 75 : (ms.reduce((a, b) => a + b) / ms.length).round();
  }

  Plantel? _plantelRival(Temporada t, String franquiciaId) {
    final r = t.rivales[franquiciaId];
    if (r == null) return null;
    try {
      return liga.plantelDe(r);
    } catch (_) {
      return null;
    }
  }

  int _nivelDe(Plantel? p) {
    if (p == null) return 78;
    final js = p.jugadores.toList();
    return (js.fold(0, (s, j) => s + j.media) / js.length).round();
  }

  /// El papel que te ofrecen según cuánto superás al que juega hoy en tu puesto: figura si lo pasás por
  /// bastante, titular si estás cerca, rotación si no llegás.
  static RolOferta _rolOferta(int media, int? mediaDelTitular, int confianza) {
    final ventaja = media - (mediaDelTitular ?? media - 2);
    if (ventaja >= 6 || (ventaja >= 3 && confianza >= 75)) return RolOferta.estrella;
    if (ventaja >= -3) return RolOferta.titular;
    return RolOferta.rotacion;
  }

  // ---------- Retiro ----------

  /// Podés retirarte desde los 34.
  static bool puedeRetirarse(EstadoCarrera e) => e.edad >= 34;

  /// El cuerpo no da más: a los 41, o desde los 36 con media menor a 66.
  static bool retiroForzoso(EstadoCarrera e) => e.edad >= 41 || (e.edad >= 36 && e.media < 66);

  EstadoCarrera retirar(EstadoCarrera e) => e.copyWith(
    retirado: true,
    hitos: [...e.hitos, '${e.etiquetaTemporada}: ${e.nombre} se retira a los ${e.edad} años. ${e.legado.veredicto}'],
  );

  // ---------- Siguiente temporada ----------

  /// Arma la temporada que sigue al receso. Con una [oferta] de otro equipo, te mudás: nuevos
  /// compañeros y nueva confianza según tu rol; con la renovación o sin oferta, te quedás y el equipo
  /// cambia algunas caras.
  Temporada siguiente(Temporada t, EstadoCarrera e, {OfertaContrato? oferta}) {
    final numero = e.numero + 1;
    final azar = Random(_hash('${e.raiz}-siguiente-$numero'));
    var franquicia = e.franquiciaId;
    var companeros = e.companeros;
    var ne = e;
    var rol = e.rolEquipo;
    final mudanza = oferta != null && oferta.franquiciaId != e.franquiciaId;
    final nivelPropio = _nivelPropio(t, e);
    var hitos = [...e.hitos];
    if (oferta != null) {
      rol = oferta.rol.rolEquipo;
      if (mudanza) {
        franquicia = oferta.franquiciaId;
        hitos.add(
          '${e.etiquetaDe(numero)}: ${e.nombre} firma ${oferta.anios} ${oferta.anios == 1 ? 'año' : 'años'} con '
          '${_nombre(franquicia)} como ${oferta.rol.etiqueta.toLowerCase()}.',
        );
      } else {
        hitos.add('${e.etiquetaDe(numero)}: renueva con ${_nombre(franquicia)} por ${oferta.anios} años.');
      }
      ne = ne.copyWith(
        contrato: oferta.anios,
        confianza: mudanza ? oferta.rol.confianza : max(e.confianza, oferta.rol.confianza - 10),
      );
    } else if (e.contrato <= 0) {
      ne = ne.copyWith(contrato: 1);
    }
    final objetivoEquipo = mudanza
        ? oferta.nivelEquipo.toDouble()
        : nivelPropio + (e.media - e.base.media) * 0.15 + (azar.nextDouble() - 0.4) * 2;
    final era = EstadoCarrera.epocaDeCierre(e.anioBase + numero);
    if (mudanza) {
      companeros = armarCompaneros(
        franquiciaId: franquicia,
        epoca: era,
        objetivo: objetivoEquipo,
        excluidos: {e.base.nbaPlayerId},
        azar: azar,
      );
      ne = ne.copyWith(relacion: 50, hitos: hitos);
    } else {
      // Se quedan los que no cambian de equipo; algunos se van y llegan caras nuevas.
      final fijos = [
        for (final j in companeros)
          if (azar.nextDouble() < 0.7) j,
      ];
      companeros = armarCompaneros(
        franquiciaId: franquicia,
        epoca: era,
        objetivo: objetivoEquipo,
        excluidos: {e.base.nbaPlayerId},
        azar: azar,
        fijos: fijos,
      );
    }
    ne = ne.copyWith(
      franquiciaId: franquicia,
      companeros: companeros,
      numero: numero,
      rolEquipo: mudanza ? rol : _rolConHisterecis(rol, ne.confianza),
      cerrada: false,
      pidioTraspaso: false,
      prensaHecha: 0,
      hitos: hitos,
      snapPj: 0,
      snapValor: 0,
      snapVictorias: 0,
      snapDerrotas: 0,
      phAcreditados: 0,
    );
    ne = ne.copyWith(objetivos: objetivosPara(ne, Random(_hash('${e.raiz}-obj-$numero'))));
    return _armarTemporada(
      id: '${e.raiz}-t$numero',
      estado: ne,
      franquiciaId: franquicia,
      dificultad: t.dificultad,
      origen: t,
    );
  }

  // ---------- Línea de tiempo ----------

  /// La carrera en voseo: una línea por temporada.
  List<String> narrar(EstadoCarrera e) {
    String n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    return [
      for (final s in e.historial)
        'Temporada ${s.numero} (${s.etiqueta}) · ${s.franquiciaId} · ${s.victorias}-${s.derrotas}. '
            '${n(s.pts)} pts, ${n(s.reb)} reb, ${n(s.ast)} ast con ${s.media} de media. ${_resultado(s)}',
    ];
  }

  static String _resultado(TemporadaJugador s) {
    final partes = [
      if (s.campeon) '¡Campeón!' else s.resultado,
      if (s.allStar) 'All-Star.',
      if (s.premios.isNotEmpty) '${s.premios.join(', ')}.',
    ];
    return partes.join(' ');
  }
}
