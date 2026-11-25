import 'dart:math';

import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'decisiones_util.dart';

/// El control de tiro: el partido se frena en tus tiros y tu defensa, y tu timing cambia el acierto.
void main() {
  MotorPartido partido(int semilla) {
    final a = armarPlantel((j) => j.media >= 80, 100 + semilla % 7);
    final b = armarPlantel((j) => j.media >= 80, 200 + semilla % 5);
    return MotorPartido(
      local: EquipoPartido(identidadId: 'CHI', plantel: a, tactica: const Tactica()),
      visitante: equipoDe(b, id: 'BOS'),
      usuarioLocal: true,
      azar: Random(semilla),
    );
  }

  /// El mismo partido sin frenar nunca (no usa [MotorPartido.simularTodo]: ese pone a la máquina a manejar tu equipo).
  MotorPartido plano(int semilla) {
    final m = partido(semilla);
    var guardia = 0;
    while (!m.terminado && guardia++ < 5000) {
      m.siguiente();
    }
    return m;
  }

  /// Juega todo el partido resolviendo cada momento con [delta] (si es tuyo) o [deltaDef] (si es de tu marca).
  (MotorPartido, int, int) jugar(int semilla, {required ModoMedidor modo, double delta = 0, double deltaDef = 0}) {
    final m = partido(semilla);
    m.medidorId = m.enCancha(true).first.id;
    m.modoMedidor = modo;
    var tiros = 0, defensas = 0;
    var guardia = 0;
    while (!m.terminado && guardia++ < 5000) {
      final e = m.siguienteInteractivo();
      if (e == null) {
        final mo = m.momentoPendiente!;
        if (mo.tipo == TipoMomento.tiro) {
          tiros++;
          m.resolverMomento(delta);
        } else {
          defensas++;
          m.resolverMomento(deltaDef);
        }
      }
    }
    return (m, tiros, defensas);
  }

  test('en automático nada se frena y el partido es el de siempre', () {
    final (a, tiros, defensas) = jugar(3, modo: ModoMedidor.automatico);
    expect((tiros, defensas), (0, 0));
    final b = plano(3);
    expect((a.puntosLocal, a.puntosVisitante), (b.puntosLocal, b.puntosVisitante));
  });

  test('con timing neutro (0) el partido sale idéntico al que no se frenó, aunque se frene en cada tiro', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final base = plano(seed);
      final (frenado, tiros, defensas) = jugar(seed, modo: ModoMedidor.todos);
      expect(tiros + defensas, greaterThan(10), reason: 'se frenó varias veces (seed $seed)');
      expect((frenado.puntosLocal, frenado.puntosVisitante), (base.puntosLocal, base.puntosVisitante), reason: 'seed $seed');
      final id = frenado.medidorId!;
      expect(frenado.boxLocal[id]!.pts, base.boxLocal[id]!.pts, reason: 'mismo box (seed $seed)');
    }
  });

  test('un buen timing hace que tu jugador acierte más, y uno malo, menos', () {
    var bien = 0.0, mal = 0.0;
    var tirosBien = 0, tirosMal = 0, hechosBien = 0, hechosMal = 0;
    for (var seed = 0; seed < 40; seed++) {
      final (b, tb, _) = jugar(seed, modo: ModoMedidor.todos, delta: 0.15);
      final (m, tm, _) = jugar(seed + 1000, modo: ModoMedidor.todos, delta: -0.15);
      final cb = b.boxLocal[b.medidorId!]!, cm = m.boxLocal[m.medidorId!]!;
      bien += cb.tcI / max(1, cb.tcA);
      mal += cm.tcI / max(1, cm.tcA);
      tirosBien += tb;
      tirosMal += tm;
      hechosBien += cb.tcI;
      hechosMal += cm.tcI;
    }
    expect(tirosBien, greaterThan(500), reason: 'muchos tiros para medir');
    expect(bien / 40, greaterThan(mal / 40 + 0.15), reason: 'acierto con buen timing ${bien / 40} vs mal ${mal / 40}');
    expect(hechosBien, greaterThan(hechosMal));
    expect(tirosMal, greaterThan(500));
  });

  test('si marcás bien, tu rival acierta menos; el tapón del timing perfecto también suma', () {
    var conDef = 0.0, sinDef = 0.0;
    var defensas = 0;
    for (var seed = 0; seed < 40; seed++) {
      final bueno = partido(seed);
      bueno.medidorId = bueno.enCancha(true).first.id;
      bueno.modoMedidor = ModoMedidor.todos;
      final malo = partido(seed + 500);
      malo.medidorId = malo.enCancha(true).first.id;
      malo.modoMedidor = ModoMedidor.todos;
      for (final (m, delta, bonus) in [(bueno, -0.15, 0.12), (malo, 0.15, 0.0)]) {
        var tiros = 0, hechos = 0;
        var guardia = 0;
        while (!m.terminado && guardia++ < 5000) {
          final e = m.siguienteInteractivo();
          if (e == null) {
            final mo = m.momentoPendiente!;
            if (mo.tipo == TipoMomento.defensa) {
              defensas++;
              final r = m.resolverMomento(delta, bonusTapon: bonus);
              tiros++;
              if (r.convertido) hechos++;
              if (m == bueno) {
                conDef += r.convertido ? 1 : 0;
              } else {
                sinDef += r.convertido ? 1 : 0;
              }
            } else {
              m.resolverMomento(0);
            }
          }
        }
        expect(tiros, greaterThanOrEqualTo(hechos));
      }
    }
    expect(defensas, greaterThan(300));
    expect(conDef, lessThan(sinDef * 0.8), reason: 'marcando bien le anotan bastante menos: $conDef vs $sinDef');
  });

  test('en "solo importantes" solo se frena en el final apretado, la chicharra o lo que marque medidorImportante', () {
    final (_, tiros, defensas) = jugar(7, modo: ModoMedidor.importantes);
    final (_, todosTiros, todosDef) = jugar(7, modo: ModoMedidor.todos);
    expect(tiros + defensas, lessThan((todosTiros + todosDef) / 2));
    // Con un "importante" siempre prendido se frena en todo.
    final m = partido(7);
    m.medidorId = m.enCancha(true).first.id;
    m.modoMedidor = ModoMedidor.importantes;
    m.medidorImportante = () => true;
    var frenos = 0;
    var guardia = 0;
    while (!m.terminado && guardia++ < 5000) {
      if (m.siguienteInteractivo() == null) {
        frenos++;
        m.resolverMomento(0);
      }
    }
    expect(frenos, greaterThan(todosTiros ~/ 2));
  });

  test('siguiente() nunca se frena (simular, saltar y otros modos), y no se puede resolver sin un momento pendiente', () {
    final m = partido(9);
    m.medidorId = m.enCancha(true).first.id;
    m.modoMedidor = ModoMedidor.todos;
    var n = 0;
    while (!m.terminado && n++ < 5000) {
      m.siguiente();
    }
    expect(m.terminado, isTrue);
    expect(m.momentoPendiente, isNull);
    expect(() => m.resolverMomento(0), throwsStateError);
  });
}
