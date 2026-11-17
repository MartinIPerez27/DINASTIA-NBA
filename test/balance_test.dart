import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/entrenador.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/playbook.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de balance automáticas (motor v2). Dos usuarios:
///  * "típico": un draft de ruleta (rareza B10/A6/S3/S+1, franquicia y época al azar, la mejor carta) que
///    NO toca la táctica ni elige entrenador (como medía el test viejo, para comparar con él);
///  * "experto": el mejor plantel histórico de una franquicia con la táctica RECOMENDADA y el mejor
///    entrenador disponible para ese plantel (MOT-03 / MOT-12: antes se medía un usuario sin táctica ni
///    entrenador y el 82-0 del mejor plantel salía mucho más raro de lo que era).
/// Metas (decididas con el dueño): mejor plantel 82-0 en ≈ 15–30 % de las temporadas en Normal, ≈ 3–5 % en
/// Difícil y ≈ 0–1 % en Leyenda; drafts típicos ≈ 55–62 % / 28–32 % / 7–13 % de victorias.
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  const temporadasTipicas = 8, temporadasExperto = 16;

  Plantel mejor(String f) {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == f).toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return p;
  }

  Plantel tipico(Random r) {
    while (true) {
      var p = const Plantel();
      for (final pos in Posicion.values) {
        for (var intento = 0; intento < 60; intento++) {
          final x = r.nextInt(20);
          final tier = x < 10 ? Tier.b : (x < 16 ? Tier.a : (x < 19 ? Tier.s : Tier.sPlus));
          final f = franquicias[r.nextInt(franquicias.length)].id;
          final candidatas = catalogo
              .where((j) => j.franquiciaId == f && j.tier == tier && p.posicionesDisponiblesPara(j).contains(pos))
              .toList();
          if (candidatas.isEmpty) continue;
          final epocas = {for (final j in candidatas) j.epoca}.toList();
          final e = epocas[r.nextInt(epocas.length)];
          final de = candidatas.where((j) => j.epoca == e).toList()..sort((a, b) => b.media.compareTo(a.media));
          p = p.asignar(de.first, pos);
          break;
        }
      }
      if (p.completo) return p;
    }
  }

  /// La mejor combinación táctica + entrenador para un plantel: la recomendada o la que trae cada DT, con el
  /// bonus de afinidad del entrenador (+12), su nivel y sin juntar ritmos opuestos.
  (Tactica, Entrenador) mejorConfiguracion(Plantel p) {
    final perfil = PerfilPlantel.de(p);
    final rec = recomendar(perfil).tactica;
    (Tactica, Entrenador)? mejorC;
    var mejorPuntaje = double.negativeInfinity;
    for (final c in Entrenador.todos) {
      for (final t in [rec, Tactica(ofensiva: c.ofensiva, defensiva: c.defensiva)]) {
        final puntaje =
            perfil.afinidad(t.ofensiva.rasgos) +
            perfil.afinidad(t.defensiva.rasgos) +
            (c.ofensiva == t.ofensiva ? 12 : 0) +
            (c.defensiva == t.defensiva ? 12 : 0) +
            c.nivel * 0.6 -
            8.0 * (t.ofensiva.ritmo - t.defensiva.ritmo).abs();
        if (puntaje > mejorPuntaje) {
          mejorPuntaje = puntaje;
          mejorC = (t, c);
        }
      }
    }
    return mejorC!;
  }

  /// (% de victorias, puntos por equipo y partido, victorias de cada temporada).
  (double, double, List<int>) medir(
    Dificultad d,
    Plantel Function(int) plantel,
    int temporadas, {
    bool experto = false,
  }) {
    var v = 0, n = 0, puntos = 0;
    final victorias = <int>[];
    for (var k = 0; k < temporadas; k++) {
      final p = plantel(k);
      final (tactica, dt) = experto ? mejorConfiguracion(p) : (const Tactica(), null);
      final liga = Liga(catalogo, franquicias, azar: Random(1000 + k));
      var t = liga.iniciar(
        Temporada(
          id: 'b',
          franquiciaUsuarioId: 'CHI',
          plantel: p,
          tactica: tactica,
          entrenadorId: dt?.id,
          tacticaConfirmada: true,
          dificultad: d,
        ),
      );
      var ganados = 0;
      while (liga.proximoDelUsuario(t) != null) {
        final partido = liga.proximoDelUsuario(t)!;
        t = liga.simularProximo(t);
        final j = t.calendario.firstWhere((x) => x.id == partido.id);
        n++;
        puntos += j.puntosLocal + j.puntosVisitante;
        if (j.ganadorId == 'CHI') {
          v++;
          ganados++;
        }
      }
      victorias.add(ganados);
    }
    return (v / n, puntos / n / 2, victorias);
  }

  final tipicos = <Dificultad, (double, double)>{};
  final expertos = <Dificultad, (double, double, double)>{}; // % victorias, % de temporadas 82-0, puntos
  test('mediciones (todas las dificultades)', () {
    for (final d in Dificultad.values) {
      final (tip, pts, _) = medir(d, (k) => tipico(Random(500 + k)), temporadasTipicas);
      final (top, ptsTop, vics) = medir(
        d,
        (k) => mejor(['CHI', 'LAL', 'BOS', 'GSW'][k % 4]),
        temporadasExperto,
        experto: true,
      );
      final perfectas = vics.where((x) => x == 82).length / vics.length;
      tipicos[d] = (tip, pts);
      expertos[d] = (top, perfectas, ptsTop);
      // ignore: avoid_print
      print(
        '${d.name}: típico ${(100 * tip).round()}% (${pts.toStringAsFixed(1)} pts) · mejor plantel con táctica '
        'recomendada y mejor DT ${(100 * top).round()}% · 82-0 en ${(100 * perfectas).round()}% de '
        '${vics.length} temporadas (${vics.reduce(min)}–${vics.reduce(max)} victorias)',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('Normal: un draft típico compite y el mejor plantel experto hace 82-0 con frecuencia', () {
    final (tip, _) = tipicos[Dificultad.normal]!;
    final (top, perfectas, _) = expertos[Dificultad.normal]!;
    expect(tip, inInclusiveRange(0.45, 0.72));
    expect(top, greaterThanOrEqualTo(0.96));
    expect(perfectas, inInclusiveRange(0.06, 0.55), reason: 'meta ≈ 15–30 % de las temporadas');
  });

  test('Difícil: el draft típico pierde más de lo que gana y el 82-0 es raro', () {
    final (tip, _) = tipicos[Dificultad.dificil]!;
    final (top, perfectas, _) = expertos[Dificultad.dificil]!;
    expect(tip, inInclusiveRange(0.2, 0.42));
    expect(top, inInclusiveRange(0.88, 0.99));
    expect(perfectas, lessThanOrEqualTo(0.25), reason: 'meta ≈ 3–5 %');
  });

  test('Leyenda: el draft típico sufre y el 82-0 es una hazaña (casi imposible)', () {
    final (tip, _) = tipicos[Dificultad.leyenda]!;
    final (top, perfectas, _) = expertos[Dificultad.leyenda]!;
    expect(tip, lessThanOrEqualTo(0.25));
    expect(top, inInclusiveRange(0.5, 0.95));
    expect(perfectas, lessThanOrEqualTo(0.07), reason: 'meta ≤ 1 %');
  });

  test('cada dificultad es más dura que la anterior', () {
    final n = tipicos[Dificultad.normal]!, d = tipicos[Dificultad.dificil]!, l = tipicos[Dificultad.leyenda]!;
    expect(n.$1 > d.$1 && d.$1 > l.$1, isTrue, reason: 'draft típico');
    final en = expertos[Dificultad.normal]!, ed = expertos[Dificultad.dificil]!, el = expertos[Dificultad.leyenda]!;
    expect(en.$1 >= ed.$1 && ed.$1 > el.$1, isTrue, reason: 'mejor plantel');
    expect(en.$2 >= ed.$2 && ed.$2 >= el.$2, isTrue, reason: 'temporadas perfectas');
  });

  test('anotación creíble (NBA moderna: 105–120 por equipo)', () {
    for (final (_, pts) in tipicos.values) {
      expect(pts, inInclusiveRange(104, 124));
    }
    for (final (_, _, pts) in expertos.values) {
      expect(pts, inInclusiveRange(104, 124));
    }
  });
}
