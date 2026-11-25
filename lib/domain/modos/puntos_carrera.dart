import 'dart:math';

import '../motor.dart' show LineaEstadistica;

// Cómo se ganan los puntos de habilidad en Mi carrera.
//
// Tres fuentes: el rendimiento de la temporada (sin tope por edad), la calificación de cada partido (de D a A+)
// y los objetivos y premios del cierre. Todo lo que se suma queda anotado para mostrarlo en el desglose.

/// Calificación de un partido y los puntos de habilidad que da.
enum Nota {
  aMas('A+', 0.40),
  a('A', 0.30),
  bMas('B+', 0.22),
  b('B', 0.16),
  cMas('C+', 0.11),
  c('C', 0.07),
  d('D', 0.03),
  f('F', 0);

  const Nota(this.etiqueta, this.puntos);
  final String etiqueta;
  final double puntos;

  static Nota deEtiqueta(String e) => values.firstWhere((n) => n.etiqueta == e, orElse: () => Nota.f);
}

class PuntosCarrera {
  const PuntosCarrera._();

  /// Seguro anti-abuso: lo máximo que da el rendimiento en una temporada (muy por encima de una temporada de MVP).
  static const topeRendimiento = 30.0;

  /// Cuánto rinde el rendimiento según la edad: el cuerpo veterano entrena menos (suave, sin pared).
  static double factorEdad(int edad) => edad <= 30
      ? 1.0
      : edad <= 33
      ? 0.85
      : 0.7;

  /// Valor de una línea (la de un partido o la de toda la temporada, sobre [pj]).
  static double valorLinea(LineaEstadistica l) => l.pts + 0.7 * l.reb + 0.7 * l.ast + l.rob + l.tap - l.per;

  /// Puntos de habilidad del rendimiento de la temporada: 0,08 por partido y un 20 % de lo que supera 6 por partido.
  static double rendimiento(LineaEstadistica? l, {int edad = 24}) {
    if (l == null || l.pj == 0) return 0;
    final porPartido = valorLinea(l) / l.pj;
    final base = l.pj * 0.08 + max(0.0, porPartido - 6) * 0.2;
    return min(topeRendimiento, base * factorEdad(edad));
  }

  /// Puntaje de un partido: la línea, con castigo por tiros errados, más un extra si ganó el equipo.
  static double puntajePartido(LineaEstadistica l, {required bool gano}) {
    final erradosTc = max(0, l.tcA - l.tcI), erradosTl = max(0, l.tlA - l.tlI);
    return valorLinea(l) + 0.3 * l.rob + 0.3 * l.tap - 0.1 * l.per - 0.6 * erradosTc - 0.3 * erradosTl + (gano ? 3 : 0);
  }

  /// La nota de un puntaje de partido.
  static Nota nota(double puntaje) => puntaje >= 45
      ? Nota.aMas
      : puntaje >= 36
      ? Nota.a
      : puntaje >= 29
      ? Nota.bMas
      : puntaje >= 23
      ? Nota.b
      : puntaje >= 17
      ? Nota.cMas
      : puntaje >= 12
      ? Nota.c
      : puntaje >= 7
      ? Nota.d
      : Nota.f;

  /// Partido con dobles-dobles y triples-dobles (puntos, rebotes, asistencias, robos y tapones).
  static int categoriasDobles(LineaEstadistica l) => [l.pts, l.reb, l.ast, l.rob, l.tap].where((v) => v >= 10).length;
}
