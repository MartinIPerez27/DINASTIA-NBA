import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rival.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(9));

  Temporada lista() {
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true);
  }

  test('29 rivales, mezcla de históricos y de época, sin tus jugadores', () {
    final t = liga.iniciar(lista());
    expect(t.rivales, hasLength(29));
    expect(t.rivales.containsKey('CHI'), isFalse);
    final tipos = t.rivales.values.map((r) => r.tipo).toSet();
    expect(tipos, containsAll(TipoRival.values));
    final mios = {for (final j in t.plantel.jugadores) j.nbaPlayerId};
    for (final r in t.rivales.values) {
      final plantel = liga.plantelDe(r);
      expect(plantel.completo, isTrue);
      expect(plantel.jugadores.where((j) => mios.contains(j.nbaPlayerId)), isEmpty, reason: r.franquiciaId);
      if (r.tipo == TipoRival.epoca) expect(plantel.jugadores.every((j) => j.epoca == r.epoca), isTrue);
    }
    expect(t.calendario, hasLength(1230));
    expect(t.fase, FaseTemporada.temporadaRegular);
  });

  test('simular partidos del usuario avanza la tabla y suma sus estadísticas; se guarda en JSON', () {
    var t = liga.iniciar(lista());
    for (var i = 0; i < 5; i++) {
      t = liga.simularProximo(t);
    }
    final r = t.registroUsuario;
    expect(r.jugados, 5);
    final jornada = t.calendario.where((p) => p.jugado && p.participa('CHI')).last.jornada;
    expect(
      t.calendario.where((p) => p.jornada <= jornada).every((p) => p.jugado),
      isTrue,
      reason: 'los demás partidos de esas jornadas también se jugaron',
    );
    expect(t.lineas.values.map((l) => l.pj).reduce(max), 5);

    final copia = Temporada.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(copia.registroUsuario.victorias, r.victorias);
    expect(copia.rivales.keys, t.rivales.keys);
    expect(copia.lineas.length, t.lineas.length);
  });
}
