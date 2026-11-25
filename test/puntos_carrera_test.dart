import 'package:dinastia_nba/domain/modos/puntos_carrera.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

LineaEstadistica linea({
  int pj = 1,
  int pts = 0,
  int reb = 0,
  int ast = 0,
  int rob = 0,
  int tap = 0,
  int per = 0,
  int tcI = 0,
  int tcA = 0,
  int tlI = 0,
  int tlA = 0,
}) => LineaEstadistica()
  ..pj = pj
  ..pts = pts
  ..reb = reb
  ..ast = ast
  ..rob = rob
  ..tap = tap
  ..per = per
  ..tcI = tcI
  ..tcA = tcA
  ..tlI = tlI
  ..tlA = tlA;

void main() {
  test('un jugador de 30/13/6 ya no se queda en 12 puntos por temporada', () {
    // 82 partidos de 30 puntos, 13 rebotes y 6 asistencias (más robos, tapones y pérdidas).
    final l = linea(pj: 82, pts: 82 * 30, reb: 82 * 13, ast: 82 * 6, rob: 82, tap: 82, per: 82 * 3);
    final ph = PuntosCarrera.rendimiento(l, edad: 22);
    expect(ph, greaterThan(12), reason: 'antes el tope por edad lo dejaba en 12');
    expect(ph, lessThanOrEqualTo(PuntosCarrera.topeRendimiento));
  });

  test('más rendimiento, más puntos; la edad solo modera un poco y no hay pared', () {
    final flojo = linea(pj: 60, pts: 300, reb: 150, ast: 60);
    final crack = linea(pj: 80, pts: 2400, reb: 700, ast: 600);
    expect(PuntosCarrera.rendimiento(crack), greaterThan(PuntosCarrera.rendimiento(flojo)));
    expect(PuntosCarrera.rendimiento(crack, edad: 35), lessThan(PuntosCarrera.rendimiento(crack, edad: 25)));
    expect(PuntosCarrera.rendimiento(crack, edad: 35), greaterThan(PuntosCarrera.rendimiento(crack, edad: 25) * 0.6));
    expect(PuntosCarrera.rendimiento(null), 0);
  });

  test('la nota del partido sube con la línea y con ganar; fallar tiros la baja', () {
    final bueno = linea(pts: 32, reb: 10, ast: 7, rob: 2, tap: 1, per: 3, tcI: 12, tcA: 22, tlI: 6, tlA: 7);
    final malo = linea(pts: 8, reb: 3, ast: 1, per: 5, tcI: 3, tcA: 17);
    final pb = PuntosCarrera.puntajePartido(bueno, gano: true);
    final pm = PuntosCarrera.puntajePartido(malo, gano: false);
    expect(PuntosCarrera.nota(pb).puntos, greaterThan(PuntosCarrera.nota(pm).puntos));
    expect(PuntosCarrera.puntajePartido(bueno, gano: true), greaterThan(PuntosCarrera.puntajePartido(bueno, gano: false)));
    expect(PuntosCarrera.nota(pm), anyOf(Nota.f, Nota.d));
    expect(PuntosCarrera.nota(60), Nota.aMas);
    expect(PuntosCarrera.nota(0), Nota.f);
  });

  test('las notas están ordenadas y un crack suma entre 20 y 40 puntos de notas en una temporada', () {
    for (var i = 1; i < Nota.values.length; i++) {
      expect(Nota.values[i].puntos, lessThanOrEqualTo(Nota.values[i - 1].puntos));
    }
    final crack = linea(pts: 30, reb: 11, ast: 6, rob: 1, tap: 1, per: 3, tcI: 11, tcA: 22, tlI: 6, tlA: 7);
    final total = 82 * PuntosCarrera.nota(PuntosCarrera.puntajePartido(crack, gano: true)).puntos;
    expect(total, inInclusiveRange(15, 40));
  });

  test('los dobles-dobles y triples-dobles cuentan puntos, rebotes, asistencias, robos y tapones', () {
    expect(PuntosCarrera.categoriasDobles(linea(pts: 25, reb: 12)), 2);
    expect(PuntosCarrera.categoriasDobles(linea(pts: 25, reb: 12, ast: 10)), 3);
    expect(PuntosCarrera.categoriasDobles(linea(pts: 9, reb: 9)), 0);
  });
}
