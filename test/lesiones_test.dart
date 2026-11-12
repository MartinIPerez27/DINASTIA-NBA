import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(31));
  var p = const Plantel();
  final js = catalogo.where((j) => j.franquiciaId == 'DAL').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final inicio = liga.iniciar(Temporada(id: 'les', franquiciaUsuarioId: 'DAL', plantel: p, tacticaConfirmada: true));

  test('agentes libres: 8, fuera de todos los planteles, estables en el bloque; firmar y liberar', () {
    final libres = liga.agentesLibres(inicio);
    expect(libres, hasLength(8));
    final ocupados = {
      for (final j in inicio.plantel.jugadores) j.nbaPlayerId,
      for (final r in inicio.rivales.values) ...liga.plantelDe(r).jugadores.map((j) => j.nbaPlayerId),
    };
    expect(libres.every((j) => !ocupados.contains(j.nbaPlayerId)), isTrue);
    expect(liga.agentesLibres(inicio).map((j) => j.id), libres.map((j) => j.id));
    var t = liga.firmar(liga.firmar(inicio, libres[0]), libres[1]);
    expect(t.suplentes, hasLength(2));
    expect(() => liga.firmar(t, libres[2]), throwsStateError);
    t = liga.liberar(t, libres[0]);
    expect(t.suplentes.single.id, libres[1].id);
    expect(Temporada.fromJson(t.toJson()).suplentes.single.id, libres[1].id);
  });

  test('un titular lesionado no juega: lo reemplaza el sano que puede jugar ese puesto', () {
    final libres = liga.agentesLibres(inicio);
    var t = liga.firmar(inicio, libres.firstWhere((j) => j.puedeJugarEn(Posicion.base)));
    final base = t.plantel.en(Posicion.base)!;
    t = t.copyWith(lesiones: {base.id: 5});
    final e = liga.equipo(t, 'DAL');
    expect(e.plantel.jugadores.map((j) => j.id), isNot(contains(base.id)));
    expect(e.plantel.en(Posicion.base)!.puedeJugarEn(Posicion.base), isTrue);
    expect(e.plantel.titulares, hasLength(5));
  });

  test('en una temporada hay lesiones (todas de 1 a 25 partidos), se curan y el balance no se rompe', () {
    var t = inicio;
    var maximo = 0, lesionesVistas = <String>{};
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
      lesionesVistas.addAll(t.lesiones.keys);
      for (final n in t.lesiones.values) {
        expect(n, inInclusiveRange(1, 25));
        maximo = max(maximo, n);
      }
    }
    expect(lesionesVistas.length, inInclusiveRange(20, 220), reason: '~2-3 por equipo en 30 equipos');
    expect(t.registroUsuario.jugados, 82);
    expect(Temporada.fromJson(t.toJson()).lesiones, t.lesiones);
  });

  test('el banco largo entra cuando un titular está fundido y el Sexto no puede', () {
    final libres = liga.agentesLibres(inicio);
    final t = liga.firmar(liga.firmar(inicio, libres[0]), libres[1]);
    final partido = liga.proximoDelUsuario(t)!;
    var usados = 0;
    for (var semilla = 0; semilla < 20; semilla++) {
      final m = liga.motor(t, partido, azar: Random(semilla))..simularTodo();
      final box = partido.localId == 'DAL' ? m.boxLocal : m.boxVisitante;
      usados += t.suplentes.where((j) => (box[j.id]?.pj ?? 0) > 0).length;
    }
    expect(usados, greaterThan(0));
  });
}
