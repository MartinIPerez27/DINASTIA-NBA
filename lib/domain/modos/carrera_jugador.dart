import 'dart:math';

import '../efecto_en_vivo.dart';
import '../entities/avatar_creado.dart';
import '../entities/estilo_creado.dart';
import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/partido.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/rol_cancha.dart';
import '../entities/temporada.dart';
import '../liga.dart';
import '../motor.dart';
import '../playbook.dart';
import '../premios.dart';
import 'cuerpo_carrera.dart';
import 'dinastia.dart';
import 'economia_carrera.dart';
import 'habilidades.dart';
import 'minijuegos_carrera.dart';
import 'mundo_carrera.dart';
import 'narrativa_carrera.dart';
import 'objetivos_carrera.dart';
import 'plantel_carrera.dart';
import 'premios_carrera.dart';
import 'puntos_carrera.dart';
import 'seleccion_carrera.dart';
import 'vida_carrera.dart';

export 'cuerpo_carrera.dart';
export 'economia_carrera.dart';
export 'etapas_previas.dart';
export 'legado_carrera.dart';
export 'mapa_tiro.dart';
export 'minijuegos_carrera.dart';
export 'narrativa_carrera.dart';
export 'mundo_carrera.dart';
export 'objetivos_carrera.dart';
export 'generacion_carrera.dart';
export 'plantel_carrera.dart';
export 'premios_carrera.dart';
export 'puntos_carrera.dart';
export 'seleccion_carrera.dart';
export 'records_carrera.dart';

export 'habilidades.dart';
import '../entities/enum_tolerante.dart';

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
      ppp: r2(_pppRealista(ppp).clamp(2.0, 38.0)),
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
    Map<Habilidad, int> espec = const {},
    ContextoInsignia? ctx,
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
    // Especializaciones: cada punto de una habilidad mueve un poco la estadística que le toca.
    var extra = const EfectoStats();
    espec.forEach(
      (h, n) => extra = extra.mas(Habilidad.efectoPorPunto(h).por(min(n, Habilidad.maxEspecializacion).toDouble())),
    );
    // Insignias: cuenta el grado que ganaste desde que arrancaste (lo de arranque ya está en la base).
    final antes = ContextoInsignia(atributos: a0);
    final ahora = ctx ?? ContextoInsignia(atributos: a, espec: espec);
    var deInsignias = const EfectoStats();
    for (final i in Insignia.values) {
      final ganado = i.grado(ahora).factor - i.grado(antes).factor;
      if (ganado > 0) deInsignias = deInsignias.mas(i.efecto.por(ganado));
    }
    // Con tantas insignias los puntos que suman se moderan (si no, un jugador de tiro las junta todas) y
    // el total tiene tope: una carrera especializada no rompe el balance.
    extra = extra.mas(deInsignias).mas(EfectoStats(ppp: -0.4 * deInsignias.ppp));
    ppp += min(extra.ppp, 3.0);
    rpp += extra.rpp;
    app += extra.app;
    robP += extra.robP;
    tapP += extra.tapP;
    pctTc += extra.pctTc;
    pctT3 += extra.pctT3;
    pctTl += extra.pctTl;
    minP += extra.minP;
    perP += extra.perP;
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

  /// Los puntos por partido de la carta se acercan a un techo (~22) en vez de crecer sin límite: el
  /// motor reparte los tiros según esa cifra y una carta de 30+ termina promediando 50 por partido.
  static double _pppRealista(double x) => x <= 14 ? x : 14 + 8 * (1 - exp(-(x - 14) / 8));

  /// Escala las estadísticas de una carta de [mediaCarta] a un jugador de [media] (el novato que todavía
  /// no es lo que va a ser): menos producción, menos acierto y menos minutos.
  static EstadisticasJugador escalar(EstadisticasJugador s, {required int media, required int mediaCarta}) {
    final f = ((media - 55) / max(1, mediaCarta - 55)).clamp(0.35, 1.0);
    final falta = 1 - f;
    return _estadisticas(
      ppp: s.ppp * f,
      rpp: s.rpp * (0.55 + 0.45 * f),
      app: s.app * (0.55 + 0.45 * f),
      robP: s.robP * (0.7 + 0.3 * f),
      tapP: s.tapP * (0.7 + 0.3 * f),
      pctTc: s.pctTc - 0.09 * falta,
      pctT3: s.pctT3 > 0 ? s.pctT3 - 0.07 * falta : 0,
      pctTl: s.pctTl - 0.09 * falta,
      minP: s.minP * (0.7 + 0.3 * f),
      perP: s.perP * (1 + 0.5 * falta),
      iq: (s.iq * (0.7 + 0.3 * f)).round(),
    );
  }

  /// Cuánto cuesta subir un punto un atributo que ya está en [valor]: cada vez más caro, y de 90 para
  /// arriba, carísimo.
  static int costo(int valor) => valor >= 95
      ? 14
      : valor >= 90
      ? 9
      : valor >= 85
      ? 6
      : valor >= 78
      ? 4
      : valor >= 70
      ? 3
      : valor >= 60
      ? 2
      : 1;

  // ---------- Potencial oculto, edad y declive ----------

  /// El techo oculto de un jugador creado (de [semilla]): casi todos terminan entre 84 y 92; el 95 o más
  /// es excepcional (4 %) y el 99, rarísimo (menos de 1 %).
  static int potencialDe(String semilla) {
    final r = Random(_hashTexto('$semilla-potencial'));
    final u = r.nextDouble();
    if (u < 0.04) return 95 + r.nextInt(5);
    if (u < 0.17) return 92 + r.nextInt(3);
    if (u < 0.85) return 84 + r.nextInt(8);
    return 77 + r.nextInt(7);
  }

  /// Cuánto le falta a la media para el techo según la edad: nadie llega a su techo antes de los 26.
  static int brechaPorEdad(int edad) => switch (edad) {
    <= 19 => 12,
    20 => 10,
    21 => 8,
    22 => 6,
    23 => 4,
    24 => 3,
    25 => 1,
    _ => 0,
  };

  /// La media máxima que puede tener a esa [edad] un jugador con [potencial].
  /// Pasados los 28, el techo baja con los años aunque gastes todos los puntos: el cuerpo manda.
  static int techoPorEdad(int potencial, int edad) {
    var declive = 0.0;
    for (var x = 29; x <= edad; x++) {
      declive += declivePorEdad(x) * 0.8;
    }
    return max(55, (potencial - brechaPorEdad(edad) - declive).round());
  }

  /// El techo que se paga barato: el potencial, menos el desgaste del cuerpo desde los 29. Sin la brecha de
  /// juventud: un joven con potencial 95 puede comprar hasta 95 a los 22 años.
  static int techoBlando(int potencial, int edad) {
    var declive = 0.0;
    for (var x = 29; x <= edad; x++) {
      declive += declivePorEdad(x) * 1.0;
    }
    return max(55, (potencial - declive).round());
  }

  /// Qué parte de lo que le falta para el techo recupera solo en un año (sin gastar puntos).
  static double tasaCrecimiento(int edad) => switch (edad) {
    <= 20 => 0.12,
    21 => 0.11,
    22 => 0.10,
    23 => 0.09,
    24 => 0.08,
    25 => 0.06,
    26 => 0.05,
    27 => 0.03,
    28 => 0.02,
    _ => 0.0,
  };

  /// Cuántos puntos de media se pierden al cumplir [edad]: el cuerpo empieza a pasar factura a los 29.
  static double declivePorEdad(int edad) => switch (edad) {
    <= 28 => 0,
    29 => 0.5,
    30 => 1.0,
    31 => 1.6,
    32 => 2.2,
    33 => 2.8,
    34 => 3.3,
    35 => 3.8,
    36 => 4.2,
    _ => 4.6,
  };

  /// Cambio natural simple por edad (lo usa el Modo universitario). Mi carrera usa [desarrolloAnual].
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

  /// Probabilidad de una lesión grave en el año en que cumple [edad]: crece con los años.
  static double probabilidadLesion(int edad) => 0.04 + max(0, edad - 27) * 0.012;

  /// Cuánto rinde el entrenamiento a esa edad (puntos de habilidad por temporada): de veterano, poco.
  static double factorEntrenamiento(int edad) => edad <= 27
      ? 1.0
      : edad <= 30
      ? 0.8
      : edad <= 33
      ? 0.6
      : 0.4;

  /// Puntos de habilidad máximos que da el rendimiento en una temporada.
  static int topeLinea(int edad) => edad <= 23
      ? 12
      : edad <= 27
      ? 11
      : edad <= 30
      ? 9
      : edad <= 33
      ? 6
      : 4;

  /// Cambio de cada atributo en el receso, al cumplir [edad]: los jóvenes se acercan a su [potencial]
  /// (sin pasarse del techo de la edad), después del pico el cuerpo cae antes que la cabeza, y cada año
  /// trae su racha: a veces un salto, a veces un bajón, a veces una lesión ([lesion]).
  /// Determinístico con [azar].
  static Map<Atributo, int> desarrolloAnual({
    required int edad,
    required int media,
    required int potencial,
    required Random azar,
    bool lesion = false,
  }) {
    final brecha = max(0, potencial - media);
    final forma = (azar.nextDouble() + azar.nextDouble() - 1) * 2.4;
    var dM = brecha * tasaCrecimiento(edad) - declivePorEdad(edad) + forma;
    if (lesion) dM -= 3 + azar.nextInt(4);
    // Jugador que ya no está en el techo de su edad y es joven: la racha mala no lo hunde.
    if (edad <= 26 && dM < 0 && media < potencial - 4) dM *= 0.4;
    final d = dM / 1.5;
    double mult(Atributo a) => dM >= 0
        ? 1.0
        : switch (a) {
            Atributo.fisico => 1.5,
            Atributo.finalizacion => 1.2,
            Atributo.defensa => 1.0,
            Atributo.tiro => 0.8,
            Atributo.iq => 0.5,
          };
    return {for (final a in Atributo.values) a: (d * mult(a) + (azar.nextDouble() - 0.5) * 1.2).round()};
  }
}

int _hashTexto(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

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
    this.atributosFijos,
    this.pickFijo,
    this.edadInicial,
    this.avatar,
    this.anioDraft,
    this.dorsal = 0,
    this.estilo,
  });

  final String nombre;

  /// Puesto titular (nunca Sexto Hombre).
  final Posicion posicion;
  final RolCancha rol;

  /// Los tres atributos fuertes (+4 cada uno al arrancar).
  final List<Atributo> fuertes;
  final int alturaCm, pesoKg;
  final int? nacimiento;

  /// Cómo se ve (null: retrato automático, como en las partidas anteriores).
  final AvatarCreado? avatar;

  /// Un jugador que ya viene hecho (un egresado del Modo universitario): conserva sus atributos, su
  /// elección real del draft y su edad, en vez de arrancar de cero como uno recién creado.
  final Atributos? atributosFijos;
  final int? pickFijo, edadInicial;

  /// Año del draft en el que arranca (null: 2026) y número de camiseta (0 a 99).
  final int? anioDraft;
  final int dorsal;

  /// Envergadura, mano, origen, forma de tirar y festejo (null en jugadores viejos: sin ajustes).
  final EstiloCreado? estilo;

  static const anioMin = 1980, anioMax = 2026, edadMin = 18, edadMax = 28;

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
    if (atributosFijos != null) return atributosFijos!;
    var a = ModeloCarrera.desdePerfil(rol, posicion, 58.5, altura: alturaCm, peso: pesoKg);
    for (final f in fuertes) {
      a = a.con(f, a[f] + 4);
    }
    // El origen inclina un poco el arranque (solo si lo elegiste).
    switch (estilo?.origen) {
      case OrigenJugador.secundario:
        a = a.con(Atributo.fisico, a[Atributo.fisico] + 2).con(Atributo.iq, a[Atributo.iq] - 1);
      case OrigenJugador.universidad:
        a = a.con(Atributo.iq, a[Atributo.iq] + 2).con(Atributo.fisico, a[Atributo.fisico] - 1);
      case OrigenJugador.internacional:
        a = a.con(Atributo.tiro, a[Atributo.tiro] + 2).con(Atributo.fisico, a[Atributo.fisico] - 1);
      case null:
    }
    return a;
  }

  int get media => ModeloCarrera.mediaDe(atributos, posicion);

  EstadisticasJugador get estadisticas {
    final s = ModeloCarrera.estadisticasDe(atributos, posicion, media);
    final env = estilo?.envergadura ?? 0;
    if (env == 0) return s;
    // Brazos largos: más tapones, robos y rebotes (cada centímetro de envergadura suma un poquito).
    return EstadisticasJugador(
      ppp: s.ppp,
      rpp: s.rpp + 0.012 * env,
      app: s.app,
      robP: max(0.2, s.robP + 0.004 * env),
      tapP: max(0.0, s.tapP + 0.007 * env),
      pctTc: s.pctTc,
      pctT3: s.pctT3,
      pctTl: s.pctTl,
      minP: s.minP,
      perP: s.perP,
      iq: s.iq,
    );
  }

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
        dorsal: dorsal,
        stats: estadisticas,
        media: media,
        fotos: const [],
        temporadas: anio == null ? null : (anio, anio),
        nacimiento: nacimiento,
        avatar: avatar?.codigo,
      );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'pos': posicion.name,
    'rol': rol.name,
    'fuertes': [for (final f in fuertes) f.name],
    'altura': alturaCm,
    'peso': pesoKg,
    if (nacimiento != null) 'nacimiento': nacimiento,
    if (avatar != null) 'avatar': avatar!.codigo,
    if (atributosFijos != null) 'atrFijos': atributosFijos!.toJson(),
    if (pickFijo != null) 'pickFijo': pickFijo,
    if (edadInicial != null) 'edadInicial': edadInicial,
    if (anioDraft != null) 'anioDraft': anioDraft,
    if (estilo != null) 'estilo': estilo!.codigo,
    if (dorsal != 0) 'dorsal': dorsal,
  };

  factory JugadorCreado.fromJson(Map<String, dynamic> j) => JugadorCreado(
    nombre: j['nombre'] as String,
    posicion: Posicion.values.porNombreO(j['pos']),
    rol: RolCancha.values.porNombreO(j['rol']),
    fuertes: [for (final f in j['fuertes'] as List) ?Atributo.values.porNombre(f)],
    alturaCm: j['altura'] as int? ?? 198,
    pesoKg: j['peso'] as int? ?? 95,
    nacimiento: j['nacimiento'] as int?,
    avatar: AvatarCreado.deCodigo(j['avatar'] as String?),
    atributosFijos: j['atrFijos'] == null ? null : Atributos.fromJson(j['atrFijos'] as Map<String, dynamic>),
    pickFijo: j['pickFijo'] as int?,
    edadInicial: j['edadInicial'] as int?,
    anioDraft: j['anioDraft'] as int?,
    estilo: EstiloCreado.deCodigo(j['estilo'] as String?),
    dorsal: j['dorsal'] as int? ?? 0,
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
/// Cláusula extra de un contrato.
enum ClausulaContrato {
  ninguna('Sin cláusulas', ''),
  opcionJugador('Opción del jugador', 'El último año podés renegociar: la renovación te paga 12 % más.'),
  noTraspaso('No traspasable', 'El club no puede traspasarte en la fecha límite.'),
  bonoTitulo('Bono por título', 'Cobrás 4 M extra si salís campeón.');

  const ClausulaContrato(this.etiqueta, this.descripcion);
  final String etiqueta, descripcion;
}

class OfertaContrato {
  const OfertaContrato({
    required this.franquiciaId,
    required this.rol,
    required this.anios,
    required this.nivelEquipo,
    this.rival,
    this.renovacion = false,
    this.salario = 0,
    this.clausula = ClausulaContrato.ninguna,
    this.limitadoPorTope = false,
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

  /// Sueldo anual en millones (0 = no calculado), cláusula, y si el tope salarial del equipo lo recortó.
  final double salario;
  final ClausulaContrato clausula;
  final bool limitadoPorTope;
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
    this.espec = const {},
    this.uso = const {},
    this.companeros = const [],
    this.objetivos = const [],
    this.ofrecidos = const [],
    this.movimientos = const [],
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
    this._potencial,
    this.confBase,
    this.moralBase,
    this.fansBase,
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

  /// Lo que le sumaste a cada habilidad específica por encima de su atributo general (0 a 20).
  final Map<Habilidad, int> espec;

  /// Contadores de la carrera que usan las insignias y los logros ('clutch': jugadas decisivas en vivo…).
  final Map<String, int> uso;

  /// Los siete compañeros del equipo (la IA arma el resto).
  final List<Jugador> companeros;
  final List<ObjetivoTemporada> objetivos;

  /// Los 8 objetivos que el DT ofreció para la temporada (de ahí se aceptan entre 4 y 6).
  final List<ObjetivoTemporada> ofrecidos;

  /// Cómo cambió el plantel año a año (retiros, traspasos, llegadas), para la pantalla "Mi equipo".
  final List<String> movimientos;
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

  /// Techo oculto de la media de este jugador (null en partidas viejas: se estima con lo que tiene).
  final int? _potencial;

  /// Confianza, ánimo y fans con los que arrancó la temporada: el rendimiento del año se mide contra
  /// ellos (no suma por cada tanda de partidos que se guarda: el resultado no depende de cómo simulás).
  final int? confBase, moralBase, fansBase;

  int get potencial => _potencial ?? min(ModeloCarrera.tope, max(ModeloCarrera.potencialDe(raiz), media + 2));

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

  /// Totales de carrera para las insignias (temporadas cerradas).
  ContextoInsignia get contexto => ContextoInsignia(
    atributos: atributos,
    espec: espec,
    pts: historial.fold(0, (x, h) => x + (h.pts * h.pj).round()),
    reb: historial.fold(0, (x, h) => x + (h.reb * h.pj).round()),
    ast: historial.fold(0, (x, h) => x + (h.ast * h.pj).round()),
    pj: historial.fold(0, (x, h) => x + h.pj),
    titulos: historial.where((h) => h.campeon).length,
    allStar: historial.where((h) => h.allStar).length,
    premios: historial.fold(0, (x, h) => x + h.premios.length),
    clutch: uso['clutch'] ?? 0,
    fans: fans,
  );

  /// Grado actual de cada insignia (las de grado ninguno todavía no las tenés).
  Map<Insignia, GradoInsignia> get grados => Insignia.grados(contexto);

  /// Las que tenés (Bronce o más).
  List<Insignia> get insignias => [
    for (final e in grados.entries)
      if (e.value.nivel >= 1) e.key,
  ];

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
    dorsal: base.dorsal,
    stats: ModeloCarrera.estadisticasActuales(
      base: base.stats,
      a0: atributosBase,
      a: atributos,
      relacion: relacion,
      moral: moral,
      espec: espec,
      ctx: contexto,
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
    avatar: base.avatar,
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
    Map<Habilidad, int>? espec,
    Map<String, int>? uso,
    List<Jugador>? companeros,
    List<ObjetivoTemporada>? objetivos,
    List<ObjetivoTemporada>? ofrecidos,
    List<String>? movimientos,
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
    int? potencial,
    int? confBase,
    int? moralBase,
    int? fansBase,
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
    espec: espec ?? this.espec,
    uso: uso ?? this.uso,
    companeros: companeros ?? this.companeros,
    objetivos: objetivos ?? this.objetivos,
    ofrecidos: ofrecidos ?? this.ofrecidos,
    movimientos: movimientos ?? this.movimientos,
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
    potencial: potencial ?? _potencial,
    confBase: confBase ?? this.confBase,
    moralBase: moralBase ?? this.moralBase,
    fansBase: fansBase ?? this.fansBase,
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
    if (espec.isNotEmpty) 'esp': {for (final e in espec.entries) e.key.name: e.value},
    if (uso.isNotEmpty) 'uso': uso,
    'comp': [for (final j in companeros) j.toJson()],
    'objetivos': [for (final o in objetivos) o.toJson()],
    if (ofrecidos.isNotEmpty) 'ofrecidos': [for (final o in ofrecidos) o.toJson()],
    if (movimientos.isNotEmpty) 'movs': movimientos,
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
    if (_potencial != null) 'pot': _potencial,
    if (confBase != null) 'cb': confBase,
    if (moralBase != null) 'mb': moralBase,
    if (fansBase != null) 'fb': fansBase,
  };

  factory EstadoCarrera.fromJson(Map<String, dynamic> j) => EstadoCarrera(
    raiz: j['raiz'] as String,
    base: Jugador.fromJson(j['base'] as Map<String, dynamic>),
    atributosBase: Atributos.fromJson(j['a0'] as Map<String, dynamic>),
    atributos: Atributos.fromJson(j['a'] as Map<String, dynamic>),
    edad: j['edad'] as int,
    anioBase: j['anioBase'] as int,
    franquiciaId: j['franq'] as String,
    rolEquipo: RolEquipo.values.porNombreO(j['rol']),
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
    espec: {
      for (final h in Habilidad.values)
        if (((j['esp'] as Map?)?[h.name] as num?)?.toInt() case final n? when n > 0) h: n,
    },
    uso: {for (final e in ((j['uso'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()},
    companeros: [for (final x in j['comp'] as List? ?? const []) Jugador.fromJson(x as Map<String, dynamic>)],
    objetivos: [
      for (final x in j['objetivos'] as List? ?? const []) ObjetivoTemporada.fromJson(x as Map<String, dynamic>),
    ],
    ofrecidos: [
      for (final x in j['ofrecidos'] as List? ?? const []) ObjetivoTemporada.fromJson(x as Map<String, dynamic>),
    ],
    movimientos: [for (final x in j['movs'] as List? ?? const []) x as String],
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
    potencial: j['pot'] as int?,
    confBase: j['cb'] as int?,
    moralBase: j['mb'] as int?,
    fansBase: j['fb'] as int?,
  );

  /// El estado de una partida de Mi carrera (null si no es una).
  /// Suma [nuevo] a los contadores [actual] de la carrera.
  static Map<String, int> sumarUso(Map<String, int> actual, Map<String, int> nuevo) => {
    ...actual,
    for (final e in nuevo.entries) e.key: (actual[e.key] ?? 0) + e.value,
  };

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
    this.gradosNuevos = const {},
    this.objetivosCarrera = const [],
  });

  final EstadoCarrera estado;
  final TemporadaJugador temporada;

  /// Cada objetivo y si se cumplió.
  final List<(ObjetivoTemporada, bool)> objetivos;
  final int phBase, phObjetivos, phPremios;

  /// Cambio natural de atributos por la edad (aplicado en [estado]).
  final Map<Atributo, int> desarrollo;

  /// Insignias que ganaste o subiste de grado este año.
  final List<Insignia> insigniasNuevas;

  /// Grado de cada insignia al cerrar el año.
  final Map<Insignia, GradoInsignia> gradosNuevos;

  /// Objetivos de carrera que se cumplieron con esta temporada.
  final List<ObjetivoCarrera> objetivosCarrera;
}

// -------------------------------------------------------------------------------------------
// El servicio: todo lo que necesita Liga
// -------------------------------------------------------------------------------------------

class CarreraJugador {
  CarreraJugador(this.liga) {
    liga.alRegistrarPartido = (t, p, m) => t.modoJuego == ModoJuego.carreraJugador ? alPartido(t, p, m) : t;
    liga.factorLesionJugador = (t, id) {
      if (t.modoJuego != ModoJuego.carreraJugador) return 1.0;
      final e = EstadoCarrera.de(t);
      return e == null || e.retirado || e.jugadorId != id ? 1.0 : CuerpoCarrera.factor(e);
    };
    liga.alCrearMotor = (t, p, m) {
      if (t.modoJuego != ModoJuego.carreraJugador) return;
      final e = EstadoCarrera.de(t);
      if (e == null || e.retirado) return;
      final local = p.localId == t.franquiciaUsuarioId;
      // La química con tus compañeros suma a tu equipo; los rivales, ya preparados, cierran lo que más hacés.
      final quimica = QuimicaCarrera.mods(e);
      if (!quimica.esNeutro) m.aplicarEfecto(local, EfectoEnVivo(mods: quimica));
      final rival = AdaptacionRival.efecto(e);
      if (rival != null) m.aplicarEfecto(!local, rival);
    };
  }

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
    final pick = jc.pickFijo ?? (18 - (puntaje - 67) * 1.6 + (azar.nextDouble() - 0.5) * 8).round().clamp(1, 60);
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

  /// Qué tan fuerte es el equipo que te elige: los peores equipos eligen primero (y con los años
  /// el equipo se acerca al nivel de la liga: ver [siguiente]).
  static double nivelEquipoPorPick(int pick) => 76 + (pick.clamp(1, 30) - 1) * 0.15;

  /// Nivel al que tiende un equipo con los años.
  static const nivelLiga = 79.0;

  /// Techo oculto de un jugador real: la media de su mejor carta (con una pizca de variación por
  /// persona). Un 99 real conserva su techo, pero arranca como novato.
  int potencialReal(Jugador carta) {
    var mejor = carta.media;
    for (final j in liga.catalogo) {
      if (j.nbaPlayerId == carta.nbaPlayerId && j.media > mejor) mejor = j.media;
    }
    return (mejor + (_hash('${carta.nbaPlayerId}-pot') % 3) - 1).clamp(70, ModeloCarrera.tope);
  }

  /// Media con la que arranca un real que va a llegar a [potencial]: un novato razonable, que sube
  /// con los años, y no la carta de su década. Un draft alto trae un poco más. Nunca más que su carta
  /// más temprana (que ya es su versión de novato cuando tiene varias).
  static int mediaNovato({required int potencial, required int pick, required int mediaCarta}) {
    final bonus = pick <= 5 ? 3 : (pick <= 14 ? 1.5 : (pick <= 30 ? 0 : -2));
    final formula = (64 + (potencial - 70) * 0.5 + bonus).round().clamp(62, 80);
    return min(formula, mediaCarta);
  }

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
    final potencial = potencialReal(carta);
    final media = mediaNovato(potencial: potencial, pick: eleccion, mediaCarta: carta.media);
    // La carta de arranque es el novato: la misma persona, con la producción que tiene a esa edad.
    final novato = Jugador.fromJson({
      ...carta.toJson(),
      'media': media,
      'stats': ModeloCarrera.escalar(carta.stats, media: media, mediaCarta: carta.media).toJson(),
    });
    final objetivo = 55 + (media - 60) / 1.5;
    final a0 = ModeloCarrera.desdePerfil(carta.rol, pos, objetivo);
    final confianza = confianzaInicial(eleccion, media);
    return EstadoCarrera(
      raiz: raiz,
      base: novato,
      potencial: potencial,
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
    int? anioInicial,
    int? edad,
    int? potencial,
  }) {
    final anioBase = anioInicial ?? creado.anioDraft ?? 2026;
    final a0 = creado.atributos;
    final carta = creado.comoCarta(id: 'mc-$raiz', franquiciaId: franquiciaId, anio: anioBase + 1);
    final confianza = confianzaInicial(pick, carta.media);
    final edadInicial = edad ?? creado.edadInicial ?? 20;
    // El techo no puede quedar por debajo de lo que ya tiene (un egresado que llega con 89).
    final techo = max(potencial ?? ModeloCarrera.potencialDe(raiz), min(ModeloCarrera.tope, carta.media + 3));
    return EstadoCarrera(
      raiz: raiz,
      base: carta,
      potencial: techo,
      atributosBase: a0,
      atributos: a0,
      edad: edadInicial,
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
    final objetivoEquipo = nivelEquipoPorPick(estado.pick);
    final companeros = armarCompaneros(
      franquiciaId: estado.franquiciaId,
      epoca: estado.epoca,
      objetivo: objetivoEquipo,
      excluidos: {estado.base.nbaPlayerId},
      azar: azar,
    );
    final ofrecidos1 = ObjetivosCarrera.ofrecer(estado, Random(_hash('${estado.raiz}-obj-1')));
    final e = estado.copyWith(
      uso: PlantelCarrera.contratosIniciales(
        estado.copyWith(companeros: companeros),
        Random(_hash('${estado.raiz}-contratos')),
      ),
      companeros: companeros,
      ofrecidos: ofrecidos1,
      objetivos: ObjetivosCarrera.porDefecto(ofrecidos1),
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
    // Con qué ánimo arranca la temporada: el rendimiento del año se mide contra eso.
    final e = estado.copyWith(
      rolEquipo: rol,
      confBase: estado.confianza,
      moralBase: estado.moral,
      fansBase: estado.fans,
    );
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

  /// Puntos de habilidad que da el rendimiento de una línea de temporada (sin tope por edad; ver [PuntosCarrera]).
  static double phDeLinea(LineaEstadistica? l, {int edad = 24}) => PuntosCarrera.rendimiento(l, edad: edad);

  static double _valorTotal(LineaEstadistica l) => l.pts + 0.7 * l.reb + 0.7 * l.ast + l.rob + l.tap - l.per;

  /// Confianza, ánimo y fans a esta altura de la temporada (con [l] y el récord [victorias]-[derrotas]).
  ///
  /// Sale SOLO de lo acumulado en el año y del ánimo con el que arrancó: guardar de a 1, de a 6 o todo
  /// junto da exactamente lo mismo. Cada valor tiende a un "mérito" (cómo rindió, cómo ganó el equipo y
  /// cuánto más que sus compañeros es tu jugador), así que no se pegan al 100 ni al piso.
  (int, int, int) animoDeLaTemporada(EstadoCarrera e, LineaEstadistica? l, int victorias, int derrotas) {
    final c0 = (e.confBase ?? e.confianza).toDouble();
    final m0 = (e.moralBase ?? e.moral).toDouble();
    final f0 = (e.fansBase ?? e.fans).toDouble();
    if (l == null || l.pj == 0) return (c0.round(), m0.round(), f0.round());
    final promedio = _valorTotal(l) / l.pj;
    final esperado = max(4.0, (e.media - 58) * 0.75);
    final ratio = (promedio / esperado).clamp(0.0, 2.5);
    final tasa = victorias + derrotas == 0 ? 0.5 : victorias / (victorias + derrotas);
    final peso = min(1.0, l.pj / 40.0);
    final nivel = e.companeros.isEmpty ? e.media.toDouble() : _nivelPropio(e).toDouble();
    final sobreElEquipo = ((e.media - nivel) * 1.2).clamp(-15.0, 30.0);
    final meritoConfianza = (50 + (ratio - 1) * 40 + (tasa - 0.5) * 20 + sobreElEquipo).clamp(10.0, 96.0);
    final meritoMoral = (55 + (ratio - 1) * 25 + (tasa - 0.5) * 70).clamp(15.0, 95.0);
    final meritoFans = (40 + (ratio - 0.9) * 30 + (tasa - 0.5) * 30 + max(0.0, sobreElEquipo) * 0.6).clamp(10.0, 95.0);
    return (
      (c0 + (meritoConfianza - c0) * 0.55 * peso).round(),
      (m0 + (meritoMoral - m0) * 0.6 * peso).round(),
      (f0 + (meritoFans - f0) * 0.5 * peso).round(),
    );
  }

  /// Se llama en cada guardado de la temporada: acredita puntos y actualiza la confianza, el ánimo y
  /// los fans con lo acumulado del año (no depende de cada cuántos partidos se guarda). El rol no
  /// cambia en plena temporada: el DT lo revisa en el receso.
  /// Después de cada partido de tu equipo: la calificación (puntos de habilidad) y los hitos de la carrera.
  Temporada alPartido(Temporada t, Partido p, MotorPartido m) {
    final actual = EstadoCarrera.de(t);
    if (actual == null || actual.retirado) return t;
    var e = actual;
    if (p.localId != t.franquiciaUsuarioId && p.visitanteId != t.franquiciaUsuarioId) return t;
    final l = m.boxLocal[e.jugadorId] ?? m.boxVisitante[e.jugadorId];
    // Cuerpo: carga acumulada, lesión nueva (parte y gravedad) o alta. Va antes de mirar si jugaste.
    final cuerpo = CuerpoCarrera.alPartido(t, e, l?.seg ?? 0, e.uso['c:pj'] ?? 0);
    t = cuerpo.$1;
    e = cuerpo.$2;
    if (l == null || (l.pj == 0 && l.seg <= 0)) return sincronizar(t, e);
    final local = p.localId == t.franquiciaUsuarioId;
    final gano = local ? m.puntosLocal > m.puntosVisitante : m.puntosVisitante > m.puntosLocal;
    final nota = PuntosCarrera.nota(PuntosCarrera.puntajePartido(l, gano: gano));
    // Los puntos de la nota son fracciones: se juntan en centésimas y se pasan al banco cuando completan uno.
    final centesimas = (e.uso['gc'] ?? 0) + (nota.puntos * 100).round();
    final enteros = centesimas ~/ 100;
    int mejor(String k, int v) => max(e.uso[k] ?? 0, v);
    final dobles = PuntosCarrera.categoriasDobles(l);
    final regular = p.jornada > 0;
    var uso = {
      ...e.uso,
      'gc': centesimas % 100,
      'gr:${nota.etiqueta}': (e.uso['gr:${nota.etiqueta}'] ?? 0) + 1,
      'dg:nota': (e.uso['dg:nota'] ?? 0) + (nota.puntos * 100).round(),
      'c:pj': (e.uso['c:pj'] ?? 0) + 1,
      'c:pts': (e.uso['c:pts'] ?? 0) + l.pts,
      'c:reb': (e.uso['c:reb'] ?? 0) + l.reb,
      'c:ast': (e.uso['c:ast'] ?? 0) + l.ast,
      'c:rob': (e.uso['c:rob'] ?? 0) + l.rob,
      'c:tap': (e.uso['c:tap'] ?? 0) + l.tap,
      'c:t3': (e.uso['c:t3'] ?? 0) + l.t3I,
      'c:tcI': (e.uso['c:tcI'] ?? 0) + l.tcI,
      'c:tcA': (e.uso['c:tcA'] ?? 0) + l.tcA,
      'c:t3A': (e.uso['c:t3A'] ?? 0) + l.t3A,
      'c:pinI': (e.uso['c:pinI'] ?? 0) + l.pinI,
      'c:pinA': (e.uso['c:pinA'] ?? 0) + l.pinA,
      'c:tlI': (e.uso['c:tlI'] ?? 0) + l.tlI,
      'c:tlA': (e.uso['c:tlA'] ?? 0) + l.tlA,
      'c:per': (e.uso['c:per'] ?? 0) + l.per,
      'c:fal': (e.uso['c:fal'] ?? 0) + l.fal,
      'c:seg': (e.uso['c:seg'] ?? 0) + l.seg.round(),
      if (l.pts >= 30) 'c:p30': (e.uso['c:p30'] ?? 0) + 1,
      if (l.pts >= 40) 'c:p40': (e.uso['c:p40'] ?? 0) + 1,
      if (l.pts >= 50) 'c:p50': (e.uso['c:p50'] ?? 0) + 1,
      if (dobles >= 2) 'c:dd': (e.uso['c:dd'] ?? 0) + 1,
      if (dobles >= 3) 'c:td': (e.uso['c:td'] ?? 0) + 1,
      'm:pts': mejor('m:pts', l.pts),
      'm:reb': mejor('m:reb', l.reb),
      'm:ast': mejor('m:ast', l.ast),
      'm:rob': mejor('m:rob', l.rob),
      'm:tap': mejor('m:tap', l.tap),
      'm:t3': mejor('m:t3', l.t3I),
    };
    // Química: un partido más con cada compañero que jugó.
    final cajas = local ? m.boxLocal : m.boxVisitante;
    final jugaron = [
      for (final x in cajas.entries)
        if (x.value.seg > 0 && x.key != e.jugadorId) x.key,
    ];
    var ne = e.copyWith(uso: QuimicaCarrera.alPartido(e.copyWith(uso: uso), jugaron), phBanco: e.phBanco + enteros);
    // Temporada regular: contadores del año y del "mes" (14 partidos), con su mini-objetivo.
    if (regular) {
      if (ne.uso['mo:tipo'] == null) ne = ne.copyWith(uso: {...ne.uso, ...ObjetivosCarrera.fijarMini(ne)});
      final n = (ne.uso['sc:pj'] ?? 0) + 1;
      final u = {
        ...ne.uso,
        'sc:pj': n,
        if (l.pts >= 30) 'sc:p30': (ne.uso['sc:p30'] ?? 0) + 1,
        if (dobles >= 2) 'sc:dd': (ne.uso['sc:dd'] ?? 0) + 1,
        if (dobles >= 3) 'sc:td': (ne.uso['sc:td'] ?? 0) + 1,
        'mes:n': (ne.uso['mes:n'] ?? 0) + 1,
        'mes:pts': (ne.uso['mes:pts'] ?? 0) + l.pts,
        'mes:reb': (ne.uso['mes:reb'] ?? 0) + l.reb,
        'mes:ast': (ne.uso['mes:ast'] ?? 0) + l.ast,
        'mes:val': (ne.uso['mes:val'] ?? 0) + PuntosCarrera.valorLinea(l).round(),
        if (gano) 'mes:w': (ne.uso['mes:w'] ?? 0) + 1,
        if (l.pts >= 25) 'mes:p25': (ne.uso['mes:p25'] ?? 0) + 1,
      };
      ne = ne.copyWith(uso: u);
      final margen = (m.puntosLocal - m.puntosVisitante).abs();
      if (gano && margen <= 5 && l.pts >= 20) {
        ne = ne.copyWith(uso: {...ne.uso, 'sc:clutch': (ne.uso['sc:clutch'] ?? 0) + 1});
      }
      ne = PremiosCarrera.alPartido(ne, t, l, gano, n);
      if (n == 35 || n == 49) ne = _traspasos(ne, n);
      if (n % MiniObjetivo.partidosPorMes == 0) ne = _cerrarMes(ne, t);
    }
    return sincronizar(t, ne);
  }

  /// Los partidos de temporada regular en que se mueve el mercado: rumores y la fecha límite de traspasos.
  static const partidoRumor = 35, partidoFechaLimite = 49;

  /// Rumores (partido 35) y fecha límite (partido 49): a veces un compañero cambia de equipo, y siempre te toca decidir.
  EstadoCarrera _traspasos(EstadoCarrera e, int n) {
    final azar = Random(_hash('${e.raiz}-fecha-${e.numero}'));
    final sobreMi = (e.contrato <= 1 || e.confianza < 45) && azar.nextDouble() < 0.7;
    final idx = e.companeros.isEmpty ? 0 : azar.nextInt(e.companeros.length);
    final seConcreta = azar.nextDouble() < 0.6;
    final etiqueta = e.etiquetaTemporada;
    if (e.companeros.isEmpty) return e;
    if (n == partidoRumor) {
      final texto = sobreMi
          ? 'Rumor: varios equipos preguntan por ${e.nombre}.'
          : 'Rumor: ${e.companeros[idx].nombre} está en la mira de otros equipos.';
      return e.copyWith(
        uso: {...e.uso, 'tr:rumor': sobreMi ? 1 : 2, 'tr:idx': idx, 'tr:real': seConcreta ? 1 : 0},
        movimientos: [...e.movimientos, '$etiqueta: $texto'],
        hitos: sobreMi ? [...e.hitos, '$etiqueta: $texto'] : null,
      );
    }
    // Fecha límite: el rumor sobre un compañero se concreta (o no) y te toca decidir a vos.
    var ne = e;
    final rumor = e.uso['tr:rumor'] ?? 0;
    final iRumor = (e.uso['tr:idx'] ?? 0).clamp(0, e.companeros.length - 1);
    if (rumor == 2) {
      final saliente = e.companeros[iRumor];
      if ((e.uso['tr:real'] ?? 0) == 1) {
        final fijos = [
          for (var i = 0; i < e.companeros.length; i++)
            if (i != iRumor) e.companeros[i],
        ];
        final nuevos = armarCompaneros(
          franquiciaId: e.franquiciaId,
          epoca: e.epoca,
          objetivo: _nivelPropio(e).toDouble(),
          excluidos: {e.base.nbaPlayerId, saliente.nbaPlayerId},
          azar: azar,
          fijos: fijos,
        );
        final llega = nuevos.where((j) => !fijos.contains(j)).toList();
        final destino = liga.franquicias.where((f) => f.id != e.franquiciaId).toList()[azar.nextInt(29)];
        final uso = {...e.uso, for (final j in llega) 'ct:${j.id}': 1 + azar.nextInt(3)}..remove('ct:${saliente.id}');
        ne = e.copyWith(
          companeros: nuevos,
          uso: uso,
          movimientos: [
            ...e.movimientos,
            '$etiqueta: fecha límite: ${saliente.nombre} es traspasado a ${_nombre(destino.id)}'
                '${llega.isEmpty ? '' : ' y llega ${llega.first.nombre}'}.',
          ],
        );
      } else {
        ne = e.copyWith(movimientos: [...e.movimientos, '$etiqueta: fecha límite: ${saliente.nombre} se queda, el rumor quedó en nada.']);
      }
    }
    // El rumor era sobre vos y se concreta: si no tenés la confianza del club, te traspasan sin preguntarte.
    if (rumor == 1 && (e.uso['tr:real'] ?? 0) == 1 && e.confianza < 60 && e.uso['ec:cl'] != ClausulaContrato.noTraspaso.index + 1) {
      return ne.copyWith(
        pidioTraspaso: true,
        confianza: ne.confianza - 3,
        uso: {...ne.uso, 'tr:hecho': 1, 'tr:forzado': 1},
        hitos: [...ne.hitos, '$etiqueta: fecha límite: el club decide traspasar a ${e.nombre} al final de la temporada.'],
        movimientos: [...ne.movimientos, '$etiqueta: el club decidió traspasarte; elegís destino en el receso.'],
      );
    }
    return ne.copyWith(uso: {...ne.uso, 'tr:pend': 1});
  }

  /// Lo que elegís en la fecha límite de traspasos. Cierra la decisión pendiente.
  EstadoCarrera resolverFechaLimite(EstadoCarrera e, OpcionFechaLimite o) {
    if ((e.uso['tr:pend'] ?? 0) == 0) return e;
    final uso = {...e.uso}
      ..remove('tr:pend')
      ..['tr:hecho'] = 1;
    final etiqueta = e.etiquetaTemporada;
    return switch (o) {
      OpcionFechaLimite.quedarme => e.copyWith(uso: uso, hitos: [...e.hitos, '$etiqueta: ${e.nombre} pasa la fecha límite de traspasos sin cambios.']),
      OpcionFechaLimite.pedirTraspaso => e.copyWith(
        uso: uso,
        pidioTraspaso: true,
        relacion: e.relacion - 5,
        confianza: e.confianza - 4,
        hitos: [...e.hitos, '$etiqueta: ${e.nombre} pide el traspaso en la fecha límite.'],
      ),
      OpcionFechaLimite.extender => e.copyWith(
        uso: uso,
        contrato: e.contrato + 1,
        confianza: e.confianza + 3,
        fans: e.fans + 1,
        hitos: [...e.hitos, '$etiqueta: ${e.nombre} extiende su contrato un año más.'],
      ),
    };
  }

  /// Termina el "mes": cobra el mini-objetivo si se cumplió y deja listo el del mes siguiente.
  EstadoCarrera _cerrarMes(EstadoCarrera e, Temporada t) {
    final mini = ObjetivosCarrera.miniActual(e);
    var ne = PremiosCarrera.alCerrarMes(e, t);
    if (mini != null && ObjetivosCarrera.valorMes(mini.$1, e.uso) >= mini.$2 - 1e-9) {
      ne = ne.copyWith(
        phBanco: ne.phBanco + 1,
        uso: {...ne.uso, 'dg:mes': (ne.uso['dg:mes'] ?? 0) + 100, 'sc:minis': (ne.uso['sc:minis'] ?? 0) + 1},
        hitos: [...ne.hitos, '${ne.etiquetaTemporada}: mini-objetivo del mes cumplido — ${ObjetivosCarrera.textoMini(mini.$1, mini.$2)}.'],
      );
    }
    final limpio = {
      for (final x in ne.uso.entries)
        if (!x.key.startsWith('mes:') && !x.key.startsWith('mo:')) x.key: x.value,
    };
    ne = ne.copyWith(uso: limpio);
    return ne.copyWith(uso: {...ne.uso, ...ObjetivosCarrera.fijarMini(ne)});
  }


  Temporada alGuardar(Temporada t) {
    final e = EstadoCarrera.de(t);
    if (e == null || e.retirado) return t;
    final l = t.lineas[e.jugadorId];
    final registro = t.registroUsuario;
    var ne = e;
    if (l != null && l.pj > e.snapPj) {
      final (confianza, moral, fans) = animoDeLaTemporada(e, l, registro.victorias, registro.derrotas);
      final acreditar = max(0, phDeLinea(l, edad: e.edad).floor() - e.phAcreditados);
      ne = e.copyWith(
        uso: acreditar == 0 ? null : EstadoCarrera.sumarUso(e.uso, {'dg:rend': acreditar * 100}),
        confianza: confianza,
        moral: moral,
        fans: fans,
        phBanco: e.phBanco + acreditar,
        phAcreditados: e.phAcreditados + acreditar,
        snapPj: l.pj,
        snapValor: _valorTotal(l),
        snapVictorias: registro.victorias,
        snapDerrotas: registro.derrotas,
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

  /// Rol que el DT te daría hoy, con la confianza actual (el cambio se hace en el receso).
  static RolEquipo rolProyectado(EstadoCarrera e) => _rolConHisterecis(e.rolEquipo, e.confianza);

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
      robPorPartido: pj == 0 ? 0 : l!.rob / pj,
      tapPorPartido: pj == 0 ? 0 : l!.tap / pj,
      pctTc: pj == 0 || l!.tcA == 0 ? 0 : l.tcI / l.tcA,
      pctT3: pj == 0 || l!.t3A == 0 ? 0 : l.t3I / l.t3A,
      pctTl: pj == 0 || l!.tlA == 0 ? 0 : l.tlI / l.tlA,
      t3PorPartido: pj == 0 ? 0 : l!.t3I / pj,
      p30: e.uso['sc:p30'] ?? 0,
      dobles: e.uso['sc:dd'] ?? 0,
      triplesDobles: e.uso['sc:td'] ?? 0,
      jugadorDelMes: e.uso['sc:mes'] ?? 0,
      relacion: (e.relacion + (VidaCarrera.personalidad(e) == Personalidad.lider ? 2 : 0)).clamp(0, 100),
      moral: e.moral,
      confianza: e.confianza,
      fans: e.fans,
    );
  }

  /// ¿Estás entre los convocados al All-Star de esta temporada?
  bool esAllStar(Temporada t, EstadoCarrera e) => _esAllStar(t, e);

  bool _esAllStar(Temporada t, EstadoCarrera e) {
    final a = t.allStar;
    if (a == null) return false;
    return [...a.este, ...a.oeste].any((j) => j.id == e.jugadorId);
  }

  // ---------- Puntos de habilidad ----------

  /// Se puede subir si no está al máximo (99) y alcanzan los puntos. No hay techo duro: pasarse del
  /// potencial o de lo que da la edad solo sale más caro ([costoMejora]).
  bool puedeSubir(EstadoCarrera e, Atributo a) => e.atributos[a] < ModeloCarrera.tope && e.phBanco >= costoMejora(e, a);

  /// Subir un punto de [a] dejaría la media por encima de tu potencial (descontado el desgaste del cuerpo
  /// desde los 29): se puede, pero cuesta más (ver [costoMejora]). La juventud no te frena.
  bool enTecho(EstadoCarrera e, Atributo a) {
    if (e.atributos[a] >= ModeloCarrera.tope) return false;
    final tras = e.copyWith(atributos: e.atributos.con(a, e.atributos[a] + 1));
    return tras.media > ModeloCarrera.techoBlando(e.potencial, e.edad);
  }

  /// Recargo por cada punto de media sobre el techo blando y recargo máximo (×).
  static const recargoPorExceso = 0.75, multiplicadorMaximo = 5.0;

  /// Lo que cuesta hoy subir un punto de [a]: el costo del nivel, y si la media pasaría tu techo blando,
  /// un 25 % más por cada punto de media de exceso (hasta ×2).
  int costoMejora(EstadoCarrera e, Atributo a) {
    final base = ModeloCarrera.costo(e.atributos[a]);
    if (e.atributos[a] >= ModeloCarrera.tope) return base;
    final tras = e.copyWith(atributos: e.atributos.con(a, e.atributos[a] + 1));
    final exceso = tras.media - ModeloCarrera.techoBlando(e.potencial, e.edad);
    return exceso <= 0 ? base : (base * min(multiplicadorMaximo, 1 + recargoPorExceso * exceso)).ceil();
  }

  /// Puntos acumulados a partir de los cuales conviene gastar (la pantalla avisa).
  static const puntosSinUsarAviso = 12;

  /// Aviso cuando tenés muchos puntos guardados (null: nada que avisar).
  String? avisoPuntosSinUsar(EstadoCarrera e) => e.phBanco >= puntosSinUsarAviso
      ? 'Tenés ${e.phBanco} puntos sin gastar: usalos en atributos o insignias. Pasarte del potencial se puede, pero sale más caro.'
      : null;

  /// Sube un punto de [a] gastando lo que cuesta. Si no alcanza, devuelve el mismo estado.
  EstadoCarrera subir(EstadoCarrera e, Atributo a) {
    if (!puedeSubir(e, a)) return e;
    final costo = costoMejora(e, a);
    return e.copyWith(
      atributos: e.atributos.con(a, e.atributos[a] + 1),
      phBanco: e.phBanco - costo,
      phGastados: e.phGastados + costo,
    );
  }

  // ---------- Habilidades específicas ----------

  /// Lo que cuesta sumar un punto a la habilidad [h]: la mitad (redondeada hacia arriba) de lo que costaría
  /// subir un atributo general a su valor actual. Es más barato porque mueve menos cosas.
  int costoHabilidad(EstadoCarrera e, Habilidad h) {
    final mitad = ModeloCarrera.costo(Habilidad.valor(h, e.atributos, e.espec)) / 2;
    final afin = VidaCarrera.afines(e.base.rol).contains(h);
    return max(1, (afin ? mitad * 0.7 : mitad).ceil());
  }

  bool puedeSubirHabilidad(EstadoCarrera e, Habilidad h) =>
      (e.espec[h] ?? 0) < Habilidad.maxEspecializacion &&
      Habilidad.valor(h, e.atributos, e.espec) < ModeloCarrera.tope &&
      e.phBanco >= costoHabilidad(e, h);

  /// Suma un punto a la habilidad [h] gastando lo que cuesta. Si no se puede, devuelve el mismo estado.
  EstadoCarrera subirHabilidad(EstadoCarrera e, Habilidad h) {
    if (!puedeSubirHabilidad(e, h)) return e;
    final costo = costoHabilidad(e, h);
    return e.copyWith(
      espec: {...e.espec, h: (e.espec[h] ?? 0) + 1},
      phBanco: e.phBanco - costo,
      phGastados: e.phGastados + costo,
    );
  }

  // ---------- Objetivos ----------

  // ---------- Fin de temporada ----------

  /// Cierra la temporada: resumen de tu jugador, objetivos cumplidos, puntos de habilidad extra, el
  /// cambio natural por la edad, y deja el estado listo para el receso. Determinístico.
  CierreTemporada cerrar(Temporada t, EstadoCarrera e, String Function(String id) nombreDe) {
    final resumen = CarreraDinastia(liga).resumir(t, nombreDe);
    final marcaFinal = marca(t, e).conCampeon(resumen.campeon);
    final l = t.lineas[e.jugadorId];
    final premios = [
      if (t.calendario.isNotEmpty) ..._premiosDe(t, e),
      ...PremiosCarrera.delCierre(t, liga, e, campeon: resumen.campeon),
      ...ConcursosAllStar.premios(e),
    ];
    final resultados = [for (final o in e.objetivos) (o, o.avance(marcaFinal).$2)];
    final cumplidos = resultados.where((r) => r.$2).length;
    final phBase = max(0, phDeLinea(l, edad: e.edad).floor() - e.phAcreditados);
    final entrena = ModeloCarrera.factorEntrenamiento(e.edad);
    final phObjetivos = (ObjetivosCarrera.puntosDe(resultados) * entrena).floor();
    final phPremios =
        (min(12.0, PremiosCarrera.puntosDe(premios) + (resumen.campeon ? 2 : 0) + (marcaFinal.allStar ? 1 : 0)) * entrena)
            .floor();
    final azar = Random(_hash('${e.raiz}-cierre-${e.numero}'));
    final edadNueva = e.edad + 1;
    final lesion = azar.nextDouble() < ModeloCarrera.probabilidadLesion(edadNueva) * VidaCarrera.factorLesion(e);
    final crecimiento = ModeloCarrera.desarrolloAnual(
      edad: edadNueva,
      media: e.media,
      potencial: e.potencial,
      azar: azar,
      lesion: lesion,
    );
    // Nadie crece por encima del techo de su edad (ni de su potencial): se recorta lo que sobre.
    var atributosNuevos = e.atributos.sumar(crecimiento);
    final techo = max(ModeloCarrera.techoPorEdad(e.potencial, edadNueva), e.media).toInt();
    final pesos = ModeloCarrera.pesos(e.posicion);
    while (e.copyWith(atributos: atributosNuevos).media > techo) {
      final mayor = Atributo.values
          .where((a) => atributosNuevos[a] > e.atributos[a])
          .fold<Atributo?>(
            null,
            (m, a) => m == null || pesos[a]! * atributosNuevos[a] > pesos[m]! * atributosNuevos[m] ? a : m,
          );
      if (mayor == null) break;
      atributosNuevos = atributosNuevos.con(mayor, atributosNuevos[mayor] - 1);
    }
    // La rutina de entrenamiento suma lo suyo después del tope (es trabajo tuyo, no del cuerpo).
    atributosNuevos = atributosNuevos.sumar(VidaCarrera.efectoRutina(e));
    final desarrollo = {for (final a in Atributo.values) a: atributosNuevos[a] - e.atributos[a]};
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
      if (lesion) '${e.etiquetaTemporada}: una lesión grave le cuesta el físico. Le va a costar volver.',
    ];
    // El ánimo del año sale de lo acumulado (no de cuántas veces se guardó); lo del cierre suma poco.
    final (confianzaAnio, moralAnio, fansAnio) = animoDeLaTemporada(e, l, marcaFinal.victorias, marcaFinal.derrotas);
    final sinJugar = (l?.pj ?? 0) == 0 ? 4 : 0;
    final dConfianza = (cumplidos - (resultados.length - cumplidos)) * 2 + (resumen.campeon ? 3 : 0) + sinJugar;
    final dMoral =
        (resumen.campeon ? 4 : 0) +
        (cumplidos >= 2 ? 2 : -2) +
        (resumen.victorias >= 50 ? 1 : 0) +
        (VidaCarrera.rutinaDe(e) == Rutina.recuperacion ? 3 : 0) +
        (VidaCarrera.personalidad(e) == Personalidad.profesional ? 1 : 0);
    final dFans =
        (marcaFinal.allStar ? 3 : 0) +
        (resumen.campeon ? 4 : 0) +
        min(3, premios.length) +
        (cumplidos >= 2 ? 1 : -1) +
        VidaCarrera.fansPorPatrocinios(e) +
        (VidaCarrera.personalidad(e) == Personalidad.showman ? 3 : 0);
    final cerrado = e.copyWith(
      atributos: atributosNuevos,
      edad: edadNueva,
      contrato: e.contrato - 1,
      phBanco: e.phBanco + phBase + phObjetivos + phPremios,
      phAcreditados: 0,
      historial: [...e.historial, temporada],
      uso: {
        ...e.uso,
        'dg:obj': phObjetivos * 100,
        'dg:prem': phPremios * 100,
        // Mejores promedios de una temporada (para los récords): los de puntos, rebotes y asistencias salen del historial.
        'b:rob100': max(e.uso['b:rob100'] ?? 0, (marcaFinal.robPorPartido * 100).round()),
        'b:tap100': max(e.uso['b:tap100'] ?? 0, (marcaFinal.tapPorPartido * 100).round()),
      }..remove('rutina'),
      hitos: hitos,
      confianza: (confianzaAnio + dConfianza).clamp(0, 98).toInt(),
      moral: (moralAnio + dMoral).clamp(VidaCarrera.personalidad(e) == Personalidad.profesional ? 35 : 0, 97).toInt(),
      fans: (fansAnio + dFans).clamp(0, 98).toInt(),
      cerrada: true,
      prensaHecha: 0,
      relacion: e.relacion + (VidaCarrera.personalidad(e) == Personalidad.lider ? 2 : 0),
    );
    // Objetivos de carrera que se cumplieron con esta temporada sumada.
    final torneo = SeleccionCarrera.jugar(e, media: e.media, ppg: marcaFinal.ppg);
    final conSeleccion = torneo == null ? cerrado : SeleccionCarrera.aplicar(cerrado, torneo, e.etiquetaTemporada);
    final conRivales = RedesCarrera.alCerrar(RivalidadCarrera.alCerrar(conSeleccion, temporada, liga.catalogo), temporada);
    final conPlata0 = EconomiaCarrera.alCerrar(conRivales);
    final conPlata = conPlata0.copyWith(uso: EntrenamientoInteractivo.alCerrar(ConcursosAllStar.alCerrar(conPlata0.uso)));
    final logradosCarrera = ObjetivosCarrera.nuevosDeCarrera(conPlata);
    final estado = ObjetivosCarrera.cobrarCarrera(conPlata, logradosCarrera);
    // Insignias que ganaste o subiste de grado este año (con la carrera ya sumada).
    final antesG = e.grados;
    final gradosNuevos = estado.grados;
    return CierreTemporada(
      estado: estado,
      temporada: temporada,
      objetivos: resultados,
      phBase: phBase,
      phObjetivos: phObjetivos,
      phPremios: phPremios,
      desarrollo: desarrollo,
      insigniasNuevas: [
        for (final i in Insignia.values)
          if (gradosNuevos[i]!.nivel > antesG[i]!.nivel) i,
      ],
      gradosNuevos: gradosNuevos,
      objetivosCarrera: logradosCarrera,
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
      final rol = _rolOferta(e.media, rival?.$2, e.confianza);
      final nivel = _nivelPropio(e);
      final cond = _condiciones(e, rol, nivel, azar, renovando: true);
      lista.add(
        OfertaContrato(
          franquiciaId: e.franquiciaId,
          rol: rol,
          anios: 2 + azar.nextInt(3),
          nivelEquipo: nivel,
          rival: rival,
          renovacion: true,
          salario: cond.$1,
          clausula: cond.$2,
          limitadoPorTope: cond.$3,
        ),
      );
    }
    for (final id in otros.take((traspaso ? 4 : 3) + EconomiaCarrera.ofertasExtra(e))) {
      final plantel = _plantelRival(t, id);
      final rival = plantel == null ? null : _titularDe(plantel.jugadores.toList(), e.posicion);
      final rol = _rolOferta(e.media, rival?.$2, e.confianza + 10);
      final nivel = _nivelDe(plantel);
      final cond = _condiciones(e, rol, nivel, azar, renovando: false);
      lista.add(
        OfertaContrato(
          franquiciaId: id,
          rol: rol,
          anios: 1 + azar.nextInt(4),
          nivelEquipo: nivel,
          rival: rival,
          salario: cond.$1,
          clausula: cond.$2,
          limitadoPorTope: cond.$3,
        ),
      );
    }
    return lista;
  }

  /// Espacio salarial de un equipo (millones): los más armados ya gastaron casi todo el tope.
  static double espacioSalarial(int nivelEquipo) => (75 - (nivelEquipo - 70) * 3.0).clamp(8.0, 70.0).toDouble();

  /// Sueldo, cláusula y si el tope lo recortó: lo que quiere pagar el equipo según tu rol, con el tope salarial por encima.
  (double, ClausulaContrato, bool) _condiciones(EstadoCarrera e, RolOferta rol, int nivelEquipo, Random azar, {required bool renovando}) {
    final factorRol = switch (rol) {
      RolOferta.estrella => 1.15,
      RolOferta.titular => 1.0,
      RolOferta.rotacion => 0.8,
    };
    final opcion = e.uso['ec:cl'] == ClausulaContrato.opcionJugador.index + 1 && e.contrato <= 1;
    final deseado = EconomiaCarrera.sueldoBase(e.copyWith(numero: max(e.numero, 20))) *
        factorRol *
        (1 + 0.05 * EconomiaCarrera.nivel(e, Personal.agente)) *
        (renovando && opcion ? 1.12 : 1.0);
    final tope = espacioSalarial(nivelEquipo);
    final r = azar.nextDouble();
    final clausula = r < 0.35
        ? ClausulaContrato.opcionJugador
        : r < 0.6
        ? ClausulaContrato.noTraspaso
        : r < 0.8
        ? ClausulaContrato.bonoTitulo
        : ClausulaContrato.ninguna;
    final salario = min(deseado, tope) * (clausula == ClausulaContrato.noTraspaso ? 0.95 : 1.0);
    return (double.parse(salario.toStringAsFixed(1)), clausula, deseado > tope);
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

  int _nivelPropio(EstadoCarrera e) {
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
    final nivelPropio = _nivelPropio(e);
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
        uso: {
          ...ne.uso,
          if (oferta.salario > 0) 'ec:sal': (oferta.salario * 10).round(),
          'ec:cl': oferta.clausula.index + 1,
        },
      );
    } else if (e.contrato <= 0) {
      ne = ne.copyWith(contrato: 1);
    }
    // El equipo tiende al nivel de la liga (los malos mejoran, los buenos se desarman) y un crack ayuda
    // un poco; cada año trae su suerte en el armado.
    final objetivoEquipo = mudanza
        ? oferta.nivelEquipo.toDouble()
        : (nivelPropio * 0.6 + nivelLiga * 0.4 + (e.media - 80) * 0.08 + (azar.nextDouble() - 0.5) * 5).clamp(
            68.0,
            86.0,
          );
    final era = EstadoCarrera.epocaDeCierre(e.anioBase + numero);
    var movs = [...e.movimientos];
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
      final rot = PlantelCarrera.rotar(
        e,
        azar,
        anio: e.anioBase + numero,
        nombreDe: _nombre,
        franquicias: [for (final f in liga.franquicias) if (f.id != franquicia) f.id],
      );
      final fijos = rot.quedan;
      movs = [...movs, ...rot.movimientos];
      companeros = armarCompaneros(
        franquiciaId: franquicia,
        epoca: era,
        objetivo: objetivoEquipo,
        excluidos: {e.base.nbaPlayerId},
        azar: azar,
        fijos: fijos,
      );
    }
    final (usoContratos, llegadas) = PlantelCarrera.contratos(
      ne,
      mudanza ? const [] : e.companeros,
      companeros,
      azar,
      anio: e.anioBase + numero,
    );
    movs = [
      ...movs,
      if (mudanza) '${e.etiquetaDe(numero)}: nuevo equipo, nuevo plantel en ${_nombre(franquicia)}.' else ...llegadas,
    ];
    ne = ne.copyWith(
      uso: usoContratos,
      movimientos: movs,
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
    final nuevosOfrecidos = ObjetivosCarrera.ofrecer(ne, Random(_hash('${e.raiz}-obj-$numero')));
    ne = ne.copyWith(
      ofrecidos: nuevosOfrecidos,
      objetivos: ObjetivosCarrera.porDefecto(nuevosOfrecidos),
      uso: {
        for (final x in ne.uso.entries)
          if (!const ['dg:', 'gr:', 'sc:', 'mes:', 'mo:', 'sem:', 'tr:'].any(x.key.startsWith)) x.key: x.value,
      },
    );
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
