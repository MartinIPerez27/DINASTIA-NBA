import 'dart:math';

import 'package:dinastia_nba/domain/decisiones_partido.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'decisiones_util.dart';

/// Contexto de medición: plantillas de los dos lados y desgaste inicial del usuario.
class _Contexto {
  _Contexto(this.nombre, this.propio, this.rival, {this.energia = 100});
  final String nombre;
  final Plantel Function(int) propio, rival;
  final double energia;
}

const _tactica = Tactica(ofensiva: SistemaOfensivo.pickAndRollEspanol, defensiva: EsquemaDefensivo.iceBlue);

const _opciones = <AccionTactica>[
  AccionTactica.defensaIndividual,
  AccionTactica.zona,
  AccionTactica.presion,
  AccionTactica.cajaYUno,
  AccionTactica.ritmoAlto,
  AccionTactica.ritmoBajo,
  AccionTactica.focoAislamiento,
  AccionTactica.focoPickAndRoll,
  AccionTactica.circulaPelota,
  AccionTactica.hack,
  AccionTactica.quintetoChico,
  AccionTactica.quintetoGrande,
  AccionTactica.descansar,
];

bool _grande(Jugador j) => j.posiciones.first == Posicion.pivot || j.posiciones.first == Posicion.alaPivot;
bool _exterior(Jugador j) => !_grande(j);

/// Mide, para una acción, cuánto cambia el margen del usuario en la ventana que dura el ajuste.
/// Devuelve (diferencia media contra el control, error estándar, energía final media).
(double, double, double) _medir(_Contexto c, AccionTactica? accion, int n, {int base = 0}) {
  final difs = <double>[];
  var energia = 0.0;
  for (var s = 0; s < n; s++) {
    final m =
        MotorPartido(
          local: equipoDe(c.propio(s % 9), id: 'CHI', t: _tactica).con(c.energia),
          visitante: equipoDe(c.rival(s % 9), id: 'BOS', t: _tactica),
          usuarioLocal: true,
          azar: Random(base + 7919 * s + 13),
        )..arrancarEn(
          cuarto: 2,
          reloj: 600,
          puntosLocal: 46,
          puntosVisitante: 46,
          ataqueLocal: s.isEven,
          energia: c.energia,
        );
    final d = DirectorDecisiones(motor: m, propio: true);
    final t0 = d.ahora;
    final antes = m.puntosLocal - m.puntosVisitante;
    if (accion != null) {
      final o = d.menuTactico().where((o) => o.accion == accion).firstOrNull;
      if (o == null) {
        difs.add(double.nan);
        continue;
      }
      d.aplicarManual(o);
    }
    while (!m.terminado && d.ahora - t0 < 360) {
      d.observar(m.siguiente());
      d.tick();
    }
    difs.add((m.puntosLocal - m.puntosVisitante - antes).toDouble());
    energia += m.energias(true).values.take(5).fold(0.0, (a, b) => a + b) / 5;
  }
  final v = difs.where((x) => !x.isNaN).toList();
  if (v.isEmpty) return (double.nan, 0, 0);
  final media = v.reduce((a, b) => a + b) / v.length;
  final varianza = v.fold(0.0, (a, x) => a + (x - media) * (x - media)) / max(1, v.length - 1);
  return (media, sqrt(varianza / v.length), energia / n);
}

extension on EquipoPartido {
  EquipoPartido con(double energia) =>
      EquipoPartido(identidadId: identidadId, plantel: plantel, tactica: tactica, energiaInicial: energia);
}

void main() {
  final contextos = <_Contexto>[
    _Contexto(
      'rival de triples',
      (s) => armarPlantel((j) => j.media >= 78, 300 + s),
      (s) => armarPlantel((j) => _exterior(j) && j.stats.pctT3 >= 0.37 && j.media >= 74, 400 + s),
    ),
    _Contexto(
      'rival de pintura',
      (s) => armarPlantel((j) => j.media >= 78, 300 + s),
      (s) => armarPlantel((j) => (_grande(j) || j.stats.pctT3 < 0.3) && j.media >= 74, 500 + s),
    ),
    _Contexto(
      'estrella propia',
      (s) => armarPlantel((j) => j.media >= 90 || (j.media <= 77 && j.media >= 70), 600 + s, top: 400),
      (s) => armarPlantel((j) => j.media >= 78, 700 + s),
    ),
    _Contexto(
      'parejo',
      (s) => armarPlantel((j) => j.media >= 76 && j.media <= 84, 800 + s, top: 400),
      (s) => armarPlantel((j) => j.media >= 76 && j.media <= 84, 900 + s, top: 400),
    ),
    _Contexto(
      'propio de tiradores',
      (s) => armarPlantel((j) => _exterior(j) && j.stats.pctT3 >= 0.37 && j.media >= 74, 1200 + s),
      (s) => armarPlantel((j) => j.media >= 78, 300 + s),
    ),
    _Contexto(
      'propio de grandes',
      (s) => armarPlantel((j) => (_grande(j) || j.stats.pctT3 < 0.3) && j.media >= 74, 1300 + s),
      (s) => armarPlantel((j) => j.media >= 78, 300 + s),
    ),
    _Contexto(
      'propio cansado',
      (s) => armarPlantel((j) => j.media >= 78, 300 + s),
      (s) => armarPlantel((j) => j.media >= 78, 1000 + s),
      energia: 55,
    ),
    _Contexto(
      'rival sin libres',
      (s) => armarPlantel((j) => j.media >= 78, 300 + s),
      (s) => armarPlantel((j) => j.media >= 70 && j.stats.pctTl <= 0.58, 1100 + s, top: 400),
    ),
  ];

  test('tabla de efecto medido por contexto', () {
    const n = 400;
    final filas = <String, List<(double, double, double)>>{};
    final control = <(double, double, double)>[];
    for (final c in contextos) {
      control.add(_medir(c, null, n));
    }
    for (final a in _opciones) {
      filas[a.name] = [for (final c in contextos) _medir(c, a, n)];
    }
    final sb = StringBuffer('\n| opción | ${contextos.map((c) => c.nombre).join(' | ')} |\n');
    sb.writeln('|---|${contextos.map((_) => '---').join('|')}|');
    sb.writeln('| (control: margen en 6 min) | ${control.map((x) => x.$1.toStringAsFixed(2)).join(' | ')} |');
    for (final e in filas.entries) {
      final celdas = <String>[];
      for (var i = 0; i < contextos.length; i++) {
        final x = e.value[i];
        celdas.add(x.$1.isNaN ? 'n/d' : '${(x.$1 - control[i].$1).toStringAsFixed(2)}±${x.$2.toStringAsFixed(2)}');
      }
      sb.writeln('| ${e.key} | ${celdas.join(' | ')} |');
    }
    // ignore: avoid_print
    print(sb);

    // Ninguna opción gana en todos los contextos (con un error estándar de margen) ni es siempre la mejor.
    final mejores = <String>{};
    for (var i = 0; i < contextos.length; i++) {
      final validas = filas.entries.where((e) => !e.value[i].$1.isNaN).toList()
        ..sort((a, b) => b.value[i].$1.compareTo(a.value[i].$1));
      mejores.add(validas.first.key);
    }
    for (final e in filas.entries) {
      final medidas = e.value.where((x) => !x.$1.isNaN).toList();
      final todasPositivas = medidas.every((x) => x.$1 - control[e.value.indexOf(x)].$1 - x.$2 > 0);
      expect(todasPositivas, isFalse, reason: '${e.key} no puede ganar en todos los contextos');
      final alguna = medidas.any((x) => x.$1 - control[e.value.indexOf(x)].$1 > 0.1);
      final algunaMala = medidas.any((x) => x.$1 - control[e.value.indexOf(x)].$1 < 0.05);
      expect(alguna || algunaMala, isTrue);
    }
    expect(mejores.length, greaterThanOrEqualTo(3), reason: 'la mejor opción cambia con el contexto: $mejores');
    // El hack solo rinde contra un tirador de libres muy flojo.
    final hack = filas['hack']!;
    final iSin = contextos.indexWhere((c) => c.nombre == 'rival sin libres');
    for (var i = 0; i < contextos.length; i++) {
      if (i != iSin && !hack[i].$1.isNaN) {
        expect(hack[i].$1 - control[i].$1, lessThan(hack[iSin].$1 - control[iSin].$1 + 0.01));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
