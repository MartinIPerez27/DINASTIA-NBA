import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/modificadores.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/playbook.dart';
import 'package:flutter_test/flutter_test.dart';

/// Insignias del Camino al anillo: cada efecto se nota en partidos simulados y los retoques por
/// defecto no cambian nada.
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  Plantel de(String f, int saltear) {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == f).toList()..sort((a, b) => b.media.compareTo(a.media));
    final pool = js.skip(saltear).toList();
    for (final pos in Posicion.values) {
      p = p.asignar(pool.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return p;
  }

  final a = de('CHI', 12), b = de('BOS', 12);
  EquipoPartido eq(Plantel p, String id, [ModificadoresEquipo m = ModificadoresEquipo.neutros]) =>
      EquipoPartido(identidadId: id, plantel: p, tactica: recomendar(PerfilPlantel.de(p)).tactica, modificadores: m);

  /// Suma estadísticas de [n] partidos con [propios] para el local (CHI) y [rival] para BOS.
  Map<String, double> jugar(
    ModificadoresEquipo propios, {
    ModificadoresEquipo rival = ModificadoresEquipo.neutros,
    int n = 120,
  }) {
    var t3I = 0, t3A = 0, perRival = 0, rebLocal = 0, puntos = 0, dosRival = 0, dosRivalA = 0, victorias = 0;
    for (var k = 0; k < n; k++) {
      final m = MotorPartido(
        local: eq(a, 'CHI', propios),
        visitante: eq(b, 'BOS', rival),
        usuarioLocal: true,
        azar: Random(k),
      )..simularTodo();
      for (final l in m.boxLocal.values) {
        t3I += l.t3I;
        t3A += l.t3A;
        rebLocal += l.reb;
      }
      for (final l in m.boxVisitante.values) {
        perRival += l.per;
        dosRival += l.tcI - l.t3I;
        dosRivalA += l.tcA - l.t3A;
      }
      puntos += m.puntosLocal;
      if (m.puntosLocal > m.puntosVisitante) victorias++;
    }
    return {
      'pct3': t3I / max(1, t3A),
      'perdidasRival': perRival / n,
      'rebotes': rebLocal / n,
      'puntos': puntos / n,
      'pct2Rival': dosRival / max(1, dosRivalA),
      'victorias': victorias / n,
    };
  }

  final base = jugar(ModificadoresEquipo.neutros);

  test('los retoques por defecto son neutros', () {
    expect(ModificadoresEquipo.neutros.esNeutro, isTrue);
    expect(EquipoPartido(identidadId: 'X', plantel: a, tactica: eq(a, 'X').tactica).modificadores.esNeutro, isTrue);
    expect(InsigniaCamino.suma(const [], a.jugadores).esNeutro, isTrue);
    expect(InsigniaCamino.refuerzo.efecto(a.jugadores).esNeutro, isTrue, reason: 'el refuerzo es un suplente');
    // Misma semilla, mismo partido: sin retoques da exactamente lo mismo que antes.
    final otra = jugar(ModificadoresEquipo.neutros);
    expect(otra, base);
  });

  test('Splash sube el porcentaje de triples', () {
    final con = jugar(const ModificadoresEquipo(tripleExtra: 0.04));
    expect(con['pct3']!, greaterThan(base['pct3']! + 0.015));
  });

  test('Zona prohibida baja los dobles del rival', () {
    final con = jugar(const ModificadoresEquipo(interiorRival: 0.045));
    expect(con['pct2Rival']!, lessThan(base['pct2Rival']! - 0.015));
  });

  test('Manos rápidas fuerza más pérdidas y Segunda chance da más rebotes', () {
    expect(
      jugar(const ModificadoresEquipo(robosFactor: 1.35))['perdidasRival']!,
      greaterThan(base['perdidasRival']! + 1),
    );
    expect(jugar(const ModificadoresEquipo(reboteOfensivoFactor: 1.4))['rebotes']!, greaterThan(base['rebotes']! + 1));
  });

  test('las insignias se suman: varias juntas ganan claramente más', () {
    final js = a.jugadores;
    final cuatro = InsigniaCamino.suma([
      InsigniaCamino.splash,
      InsigniaCamino.pizarron,
      InsigniaCamino.zonaProhibida,
      InsigniaCamino.bancoProfundo,
    ], js);
    expect(cuatro.fatigaFactor, closeTo(0.75, 1e-9));
    final con = jugar(cuatro);
    expect(con['victorias']!, greaterThan(base['victorias']! + 0.06));
    expect(con['puntos']!, greaterThan(base['puntos']!));
  });

  test('requisitos: versión completa o chica según el plantel, con el efecto en palabras', () {
    for (final v in InsigniaCamino.values) {
      final texto = v.detalle(a.jugadores);
      expect(texto, isNotEmpty);
      if (v.requisito != null) expect(texto, contains(v.cumple(a.jugadores) ? 'completo' : 'versión chica'));
    }
    // Un plantel sin tiradores recibe el Splash chico.
    final sinTiro = [
      for (final j in catalogo.take(400))
        if (j.stats.pctT3 < 0.2) j,
    ].take(6).toList();
    expect(InsigniaCamino.splash.cumple(sinTiro), isFalse);
    expect(
      InsigniaCamino.splash.efecto(sinTiro).tripleExtra,
      lessThan(InsigniaCamino.splash.efecto(a.jugadores).tripleExtra + 1e-9),
    );
  });
}
