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

  test('Play-In (7-8 y 9-10, después el último boleto) y cuadro 1-8, 4-5, 3-6, 2-7', () {
    final po = liga.iniciarPlayoffs(t);
    expect(po.series, hasLength(4));
    expect(po.series.every((s) => s.ronda == RondaPlayoff.playIn && s.victoriasParaGanar == 1), isTrue);
    final este = po.standings(Conferencia.este, franquicias);
    expect((po.series[0].altoId, po.series[0].bajoId), (este[6].franquiciaId, este[7].franquiciaId));
    expect((po.series[1].altoId, po.series[1].bajoId), (este[8].franquiciaId, este[9].franquiciaId));
    expect(liga.iniciarPlayoffs(po).series, hasLength(4), reason: 'no se arma dos veces');
    // Se juega todo el Play-In (con o sin el usuario) y se arma la 1.ª ronda.
    var x = po;
    while (x.series.last.ronda.esPlayIn) {
      x = x.serieDelUsuario != null ? liga.simularPartidoPlayoff(x) : liga.simularPlayIn(x);
    }
    final playIn = x.series.where((s) => s.ronda == RondaPlayoff.playIn).toList();
    final ultimo = x.series.where((s) => s.ronda == RondaPlayoff.playInFinal).toList();
    expect(ultimo, hasLength(2));
    final perdedor78 = playIn[0].ganadorId == playIn[0].altoId ? playIn[0].bajoId : playIn[0].altoId;
    expect((ultimo[0].altoId, ultimo[0].bajoId), (perdedor78, playIn[1].ganadorId));
    final primera = x.series.where((s) => s.ronda == RondaPlayoff.primeraRonda).toList();
    expect(primera, hasLength(8));
    expect((primera[0].altoId, primera[0].bajoId), (este[0].franquiciaId, ultimo[0].ganadorId), reason: '1 vs 8');
    expect((primera[1].altoId, primera[1].bajoId), (este[3].franquiciaId, este[4].franquiciaId), reason: '4 vs 5');
    expect((primera[3].altoId, primera[3].bajoId), (este[1].franquiciaId, playIn[0].ganadorId), reason: '2 vs 7');
    final s = primera.first;
    expect(liga.partidoDeSerie(s).localId, s.altoId, reason: 'juego 1 en casa del mejor sembrado');
  });

  test('desempates: con igual récord manda el enfrentamiento directo', () {
    for (final conf in Conferencia.values) {
      final tabla = t.standings(conf, franquicias);
      for (var i = 0; i + 1 < tabla.length; i++) {
        final a = tabla[i], b = tabla[i + 1];
        expect(a.porcentaje, greaterThanOrEqualTo(b.porcentaje));
        if (a.porcentaje == b.porcentaje) {
          final (va, vb) = t.enfrentamientos(a.franquiciaId, b.franquiciaId);
          expect(va, greaterThanOrEqualTo(vb), reason: '${a.franquiciaId} vs ${b.franquiciaId}');
        }
      }
    }
    final (v, d, partidos) = t.historialContra('BOS');
    expect(v + d, partidos.length);
  });

  test('los playoffs llegan hasta el campeón, con 15 series y se guardan', () {
    final fin = liga.simularRestoPlayoffs(t);
    expect(fin.series, hasLength(21), reason: '4 + 2 del Play-In y 15 de playoffs');
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
    while (po.series.last.ronda.esPlayIn) {
      po = po.serieDelUsuario != null ? liga.simularPartidoPlayoff(po) : liga.simularPlayIn(po);
    }
    final propia = po.serieDelUsuario;
    if (propia == null) return; // no clasificó con esta semilla: lo cubre el test anterior
    po = liga.simularPartidoPlayoff(po);
    final jugados = [
      for (final s in po.series.where((s) => s.ronda == RondaPlayoff.primeraRonda)) s.victoriasAlto + s.victoriasBajo,
    ];
    expect(jugados.toSet(), {1});
    po = liga.simularSerieUsuario(po);
    expect(po.series.where((s) => s.ronda == RondaPlayoff.primeraRonda).every((s) => s.terminada), isTrue);
    expect(po.series.where((s) => s.ronda == RondaPlayoff.semifinalConferencia), isNotEmpty, reason: '2.ª ronda');
  });
}
