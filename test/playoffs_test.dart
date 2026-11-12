import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/franquicia.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(11));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  var t = liga.iniciar(Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  while (liga.proximoDelUsuario(t) != null) {
    t = liga.simularProximo(t);
  }
  t = liga.simularOtrosHasta(t, 1 << 30);

  test('la temporada regular deja estadísticas de toda la liga y premios', () {
    expect(t.fase, FaseTemporada.playoffs);
    expect(t.lineas.length, greaterThan(150), reason: 'todos los planteles, no solo el tuyo');
    final (mvp, anotador) = liga.premios(t);
    expect(mvp, isNotNull);
    expect(anotador, isNotNull);
    final l = t.lineas[anotador!.jugadorId]!;
    for (final otra in t.lineas.values.where((o) => o.pj * 2 >= l.pj)) {
      expect(otra.pts / otra.pj, lessThanOrEqualTo(l.pts / l.pj + 1e-9));
    }
  });

  test('cuadro 1-8, 4-5, 3-6, 2-7 por conferencia y localía 2-2-1-1-1', () {
    final po = liga.iniciarPlayoffs(t);
    expect(po.series, hasLength(8));
    final este = po.standings(Conferencia.este, franquicias);
    expect((po.series[0].altoId, po.series[0].bajoId), (este[0].franquiciaId, este[7].franquiciaId));
    expect((po.series[1].altoId, po.series[1].bajoId), (este[3].franquiciaId, este[4].franquiciaId));
    final s = po.series.first;
    expect(liga.partidoDeSerie(s).localId, s.altoId, reason: 'juego 1 en casa del mejor sembrado');
    expect(liga.iniciarPlayoffs(po).series, hasLength(8), reason: 'no se arma dos veces');
  });

  test('los playoffs llegan hasta el campeón, con 15 series y se guardan', () {
    final fin = liga.simularRestoPlayoffs(t);
    expect(fin.series, hasLength(15));
    expect(fin.series.every((s) => s.terminada), isTrue);
    expect(fin.campeonId, isNotNull);
    expect(fin.fase, FaseTemporada.finalizada);
    expect(fin.series.where((s) => s.ronda == RondaPlayoff.finalesNba), hasLength(1));
    final finales = fin.series.last;
    expect(
      {franquiciaPorId(finales.altoId).conferencia, franquiciaPorId(finales.bajoId).conferencia},
      {Conferencia.este, Conferencia.oeste},
    );
    expect(fin.lineasPlayoffs, isNotEmpty);
    final copia = Temporada.fromJson(fin.toJson());
    expect(copia.campeonId, fin.campeonId);
    expect(copia.lineasPlayoffs.length, fin.lineasPlayoffs.length);
  });

  test('el usuario juega su serie partido a partido y el resto de la ronda avanza a la par', () {
    var po = liga.iniciarPlayoffs(t);
    final propia = po.serieDelUsuario;
    if (propia == null) return; // no clasificó con esta semilla: lo cubre el test anterior
    po = liga.simularPartidoPlayoff(po);
    final jugados = [
      for (final s in po.series.where((s) => s.ronda == RondaPlayoff.primeraRonda)) s.victoriasAlto + s.victoriasBajo,
    ];
    expect(jugados.toSet(), {1});
    po = liga.simularSerieUsuario(po);
    expect(po.series.where((s) => s.ronda == RondaPlayoff.primeraRonda).every((s) => s.terminada), isTrue);
    expect(po.series.length, greaterThan(8), reason: 'ya se armó la 2.ª ronda');
  });
}
