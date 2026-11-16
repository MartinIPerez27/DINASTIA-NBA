import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rival.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/version_catalogo.dart';
import 'package:dinastia_nba/domain/versiones.dart';
import 'package:flutter_test/flutter_test.dart';

/// Catálogo v3: una carta es un tramo real (jugador + franquicia + ventana de temporadas).
void main() {
  final raw = File(rutaCatalogo).readAsStringSync();
  final (catalogo, legado) = parsearCatalogoCompleto(raw);

  test('todos los ids del catálogo anterior siguen existiendo (activos o legado)', () {
    final viejos = (jsonDecode(File('test/fixtures/catalogo_v2_ids.json').readAsStringSync()) as List).cast<String>();
    expect(viejos, hasLength(11323));
    final nuevos = {for (final j in catalogo) j.id, ...legado.keys};
    expect(viejos.where((id) => !nuevos.contains(id)), isEmpty);
    expect(nuevos.length, catalogo.length + legado.length, reason: 'ids repetidos');
  });

  test('las cartas legado no salen en los sorteos pero se encuentran por id', () {
    expect(legado, isNotEmpty);
    expect(legado.length, lessThan(20));
    expect(catalogo.any((j) => j.legado), isFalse);
    cartasLegado = legado;
    final liga = Liga(catalogo, franquicias, azar: Random(1));
    final una = legado.values.first;
    expect(liga.jugador(una.id)?.id, una.id);
    cartasLegado = const {};
  });

  test('cada carta trae una ventana de temporadas coherente con su época y ninguna usa datos parciales', () {
    for (final j in catalogo) {
      final (a, b) = j.temporadas!;
      expect(a <= b, isTrue, reason: j.id);
      expect(b <= 2026, isTrue, reason: j.id);
      expect(j.dorsal, 0);
    }
  });

  test('Porziņģis: una carta por equipo y la última es la más baja', () {
    final p = catalogo.where((j) => j.idBbref == 'porzikr01').toList()
      ..sort((a, b) => a.temporadas!.$1.compareTo(b.temporadas!.$1));
    expect({for (final j in p) j.franquiciaId}, containsAll(['DAL', 'WAS', 'BOS', 'ATL', 'GSW']));
    expect({for (final j in p) j.media}.length, greaterThanOrEqualTo(4));
    expect(p.last.media, lessThan(p.map((j) => j.media).reduce(max)));
  });

  test('Curry y LeBron: ventanas separadas dentro de la misma década y franquicia', () {
    final curry = catalogo.where((j) => j.idBbref == 'curryst01').toList();
    expect(curry.length, greaterThanOrEqualTo(5));
    final porVentana = {for (final j in curry) j.temporadas};
    expect(porVentana.length, curry.length);
    final lebron = catalogo.where((j) => j.idBbref == 'jamesle01').toList();
    expect(lebron.length, greaterThanOrEqualTo(8));
    expect({for (final j in lebron) j.franquiciaId}, containsAll(['CLE', 'MIA', 'LAL']));
  });

  test('versiones: por carta, no por década', () {
    final v = calcularVersiones(catalogo);
    final curry = catalogo.where((j) => j.idBbref == 'curryst01').toList()
      ..sort((a, b) => a.temporadas!.$1.compareTo(b.temporadas!.$1));
    expect(v[curry.first.id], VersionCarta.novato);
    expect(v[curry.last.id], VersionCarta.veterano);
    expect(curry.where((j) => v[j.id] == VersionCarta.prime), hasLength(1));
  });

  test('el draft sigue funcionando con las ventanas: tirar, elegir y completar un plantel', () {
    final draft = Draft(catalogo, azar: Random(4));
    var t = Temporada(id: 't', franquiciaUsuarioId: 'GSW', plantel: const Plantel());
    for (final pos in Posicion.values) {
      t = draft.tirar(t);
      final carta = draft.candidatos(t).firstWhere((j) => t.plantel.posicionesDisponiblesPara(j).contains(pos));
      t = draft.elegir(t, carta, pos);
    }
    expect(t.plantel.completo, isTrue);
  });

  test('rivales de época: equipos de un año real (tramos cercanos) y plantel completo', () {
    final liga = Liga(catalogo, franquicias, azar: Random(3));
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    final t = liga.iniciar(Temporada(id: 'v3', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    for (final r in t.rivales.values.where((r) => r.tipo == TipoRival.epoca)) {
      final plantel = liga.plantelDe(r);
      expect(plantel.completo, isTrue);
      expect(plantel.jugadores.every((j) => j.epoca == r.epoca), isTrue);
    }
  });

  test('una partida guardada con el catálogo anterior sigue cargando y jugando', () {
    cartasLegado = legado;
    final json = jsonDecode(File('test/fixtures/partida_v2.json').readAsStringSync()) as Map<String, dynamic>;
    final t = Temporada.fromJson(json);
    final liga = Liga(catalogo, franquicias, azar: Random(2));
    for (final r in t.rivales.values) {
      expect(liga.plantelDe(r).completo, isTrue, reason: r.franquiciaId);
    }
    final siguiente = liga.simularProximo(t);
    expect(siguiente.registroUsuario.jugados, t.registroUsuario.jugados + 1);
    cartasLegado = const {};
  });
}
