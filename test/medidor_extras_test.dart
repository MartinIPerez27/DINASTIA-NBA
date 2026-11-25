import 'dart:math';

import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/modos/medidor_tiro.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'decisiones_util.dart';

/// Libres, rebote, robo y pase con la barra: con timing neutro el partido es idéntico; con buen timing, mejor.
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

  MotorPartido plano(int semilla) {
    final m = partido(semilla);
    var guardia = 0;
    while (!m.terminado && guardia++ < 5000) {
      m.siguiente();
    }
    return m;
  }

  /// Juega resolviendo cada momento con la calidad [q] y cuenta cuántos hubo de cada tipo.
  (MotorPartido, Map<TipoMomento, int>) jugar(int semilla, {Set<TipoMomento>? activos, CalidadTiro? q, bool cero = false}) {
    final m = partido(semilla);
    m.medidorId = m.enCancha(true).first.id;
    m.modoMedidor = ModoMedidor.todos;
    if (activos != null) m.momentosActivos = activos;
    final cuenta = <TipoMomento, int>{};
    var guardia = 0;
    while (!m.terminado && guardia++ < 8000) {
      final e = m.siguienteInteractivo();
      // Resolver un momento puede abrir otro (libres tras la falta, tiro tras el pase): se sigue hasta que no haya más.
      while (e == null && m.momentoPendiente != null) {
        final mo = m.momentoPendiente!;
        cuenta[mo.tipo] = (cuenta[mo.tipo] ?? 0) + 1;
        if (cero) {
          m.resolverMomento(0);
        } else {
          switch (mo.tipo) {
            case TipoMomento.tiro:
              m.resolverMomento(MedidorTiro.deltaTiro(q!));
            case TipoMomento.defensa:
              final (d, t) = MedidorTiro.efectoDefensa(q!);
              m.resolverMomento(d, bonusTapon: t);
            default:
              m.resolverMomento(MedidorTiro.efectoExtra(mo.tipo, q!));
          }
        }
      }
    }
    return (m, cuenta);
  }

  final todos = {TipoMomento.tiro, TipoMomento.defensa, ...AjustesMedidor.posiblesExtras};

  test('con todos los momentos activos y timing neutro, el partido es idéntico al de siempre', () {
    final total = <TipoMomento, int>{};
    for (final s in [3, 8, 11, 12]) {
      final (a, cuenta) = jugar(s, activos: todos, cero: true);
      final b = plano(s);
      expect((a.puntosLocal, a.puntosVisitante), (b.puntosLocal, b.puntosVisitante), reason: 'semilla $s');
      cuenta.forEach((k, v) => total[k] = (total[k] ?? 0) + v);
    }
    for (final t in TipoMomento.values) {
      expect(total[t] ?? 0, greaterThan(0), reason: 'hubo momentos de $t');
    }
  });

  test('sin activarlos, los momentos extra nunca frenan el partido', () {
    final (_, cuenta) = jugar(5, cero: true);
    expect(cuenta.keys.toSet().difference({TipoMomento.tiro, TipoMomento.defensa}), isEmpty);
  });

  test('simular o saltar jugadas nunca se traba aunque haya momentos encadenados', () {
    final m = partido(4);
    m.medidorId = m.enCancha(true).first.id;
    m.modoMedidor = ModoMedidor.todos;
    m.momentosActivos = todos;
    var guardia = 0;
    while (!m.terminado && guardia++ < 5000) {
      m.siguiente();
    }
    expect(m.terminado, isTrue);
    final b = partido(4)
      ..medidorId = null;
    b.simularTodo();
    expect(b.terminado, isTrue);
  });

  test('mejor timing en libres, rebote, robo y pase mejora al equipo; peor timing lo empeora', () {
    var bien = 0, mal = 0;
    for (final s in [1, 2, 3, 4, 5, 6]) {
      final (b, _) = jugar(s, activos: todos, q: CalidadTiro.perfecto);
      final (m, _) = jugar(s, activos: todos, q: CalidadTiro.tarde);
      bien += b.puntosLocal - b.puntosVisitante;
      mal += m.puntosLocal - m.puntosVisitante;
    }
    expect(bien, greaterThan(mal));
  });

  test('un solo tipo activo: solo ese tipo (más tiro y defensa) frena el partido', () {
    final (_, cuenta) = jugar(2, activos: {TipoMomento.tiro, TipoMomento.defensa, TipoMomento.libres}, cero: true);
    expect(cuenta.keys.toSet().difference({TipoMomento.tiro, TipoMomento.defensa, TipoMomento.libres}), isEmpty);
    expect(cuenta[TipoMomento.libres] ?? 0, greaterThan(0));
  });

  test('los ajustes guardan qué momentos extra querés', () {
    const a = AjustesMedidor(extras: {TipoMomento.rebote, TipoMomento.pase});
    expect(a.momentos, containsAll([TipoMomento.tiro, TipoMomento.defensa, TipoMomento.rebote, TipoMomento.pase]));
    expect(a.momentos.contains(TipoMomento.libres), isFalse);
    expect(a.aUso['cfg:x:rebote'], 1);
    expect(a.aUso['cfg:x:libres'], 0);
  });
}
