import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de balance automáticas: si un cambio en el motor o en los rivales desarma la
/// dificultad, esto falla. Simula temporadas completas con un plantel "típico" de draft y con el
/// mejor plantel histórico posible, en cada dificultad.
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  Plantel mejor(String f) {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == f).toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return p;
  }

  // Draft típico de ruleta: rareza B10/A6/S3/S+1, franquicia y época al azar, la mejor carta.
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

  /// (% de victorias, puntos por equipo y partido) en [temporadas] temporadas.
  (double, double) medir(Dificultad d, Plantel Function(int) plantel, {int temporadas = 3}) {
    var v = 0, n = 0, puntos = 0;
    for (var k = 0; k < temporadas; k++) {
      final liga = Liga(catalogo, franquicias, azar: Random(1000 + k));
      var t = liga.iniciar(
        Temporada(id: 'b', franquiciaUsuarioId: 'CHI', plantel: plantel(k), tacticaConfirmada: true, dificultad: d),
      );
      while (liga.proximoDelUsuario(t) != null) {
        final p = liga.proximoDelUsuario(t)!;
        t = liga.simularProximo(t);
        final j = t.calendario.firstWhere((x) => x.id == p.id);
        n++;
        puntos += j.puntosLocal + j.puntosVisitante;
        if (j.ganadorId == 'CHI') v++;
      }
    }
    return (v / n, puntos / n / 2);
  }

  final resultados = <Dificultad, (double, double, double)>{};
  setUpAll(() {
    for (final d in Dificultad.values) {
      final (tip, pts) = medir(d, (k) => tipico(Random(500 + k)));
      final (top, _) = medir(d, (k) => mejor(['CHI', 'LAL', 'BOS'][k]));
      resultados[d] = (tip, top, pts);
      // ignore: avoid_print
      print(
        '${d.name}: típico ${(100 * tip).round()}% · mejor ${(100 * top).round()}% · ${pts.toStringAsFixed(1)} pts',
      );
    }
  });

  test('Normal: un draft típico compite y uno de leyendas domina', () {
    final (tip, top, _) = resultados[Dificultad.normal]!;
    expect(tip, inInclusiveRange(0.45, 0.78));
    expect(top, greaterThanOrEqualTo(0.9));
  });

  test('Difícil: el draft típico pierde más de lo que gana y el mejor plantel igual sufre alguna', () {
    final (tip, top, _) = resultados[Dificultad.dificil]!;
    expect(tip, inInclusiveRange(0.2, 0.4));
    expect(top, inInclusiveRange(0.75, 0.96));
  });

  test('Leyenda: el draft típico sufre y el mejor plantel no arrasa', () {
    final (tip, top, _) = resultados[Dificultad.leyenda]!;
    expect(tip, lessThanOrEqualTo(0.3));
    expect(top, inInclusiveRange(0.5, 0.9));
  });

  test('cada dificultad es más dura que la anterior', () {
    final n = resultados[Dificultad.normal]!, d = resultados[Dificultad.dificil]!, l = resultados[Dificultad.leyenda]!;
    expect(n.$1 > d.$1 && d.$1 > l.$1, isTrue, reason: 'draft típico');
    expect(n.$2 >= d.$2 && d.$2 > l.$2, isTrue, reason: 'mejor plantel');
  });

  test('anotación creíble', () {
    for (final (_, _, pts) in resultados.values) {
      expect(pts, inInclusiveRange(90, 118));
    }
  });
}
