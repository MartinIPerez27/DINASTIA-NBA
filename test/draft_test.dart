import 'dart:convert';
import 'dart:math';

import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/tirada.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = EstadisticasJugador(
  ppp: 20,
  rpp: 5,
  app: 5,
  robP: 1,
  tapP: 1,
  pctTc: .5,
  pctT3: .35,
  pctTl: .8,
  minP: 34,
  perP: 2,
  iq: 80,
);

Jugador _carta(int id, String franquicia, Epoca epoca, Tier tier, List<Posicion> pos) => Jugador(
  id: '$id-$franquicia-${epoca.name}',
  nbaPlayerId: id,
  nombre: 'Jugador $id',
  franquiciaId: franquicia,
  epoca: epoca,
  tier: tier,
  posiciones: pos,
  rol: RolCancha.controladorTotal,
  dorsal: id % 99,
  stats: _stats,
);

final _catalogo = [
  _carta(1, 'CHI', Epoca.anios90, Tier.sPlus, [Posicion.escolta]),
  _carta(2, 'CHI', Epoca.anios90, Tier.s, [Posicion.alero]),
  _carta(3, 'CHI', Epoca.anios90, Tier.a, [Posicion.alaPivot]),
  _carta(4, 'LAL', Epoca.anios80, Tier.sPlus, [Posicion.base]),
  _carta(5, 'LAL', Epoca.anios2000, Tier.a, [Posicion.pivot]),
  _carta(6, 'BOS', Epoca.anios80, Tier.a, [Posicion.alero, Posicion.alaPivot]),
  _carta(7, 'SAS', Epoca.anios2000, Tier.s, [Posicion.alaPivot, Posicion.pivot]),
  _carta(8, 'GSW', Epoca.anios2010, Tier.a, [Posicion.base, Posicion.escolta]),
];

void main() {
  const nueva = Temporada(id: 't', franquiciaUsuarioId: 'CHI');

  test('la primera tirada es gratis y siempre trae candidatos que entran', () {
    final draft = Draft(_catalogo, azar: Random(1));
    for (var i = 0; i < 50; i++) {
      final t = draft.tirar(nueva);
      expect(t.rerollsRestantes, 3);
      expect(draft.candidatos(t), isNotEmpty);
    }
  });

  test('no se puede volver a tirar sin gastar ficha, y sin fichas no se tira', () {
    final draft = Draft(_catalogo, azar: Random(2));
    var t = draft.tirar(nueva);
    t = draft.tirar(t);
    expect(t.rerollsRestantes, 2);
    t = draft.tirar(draft.tirar(t));
    expect(t.rerollsRestantes, 0);
    expect(draft.puedeVolverATirar(t, const {}), isFalse);
    expect(() => draft.tirar(t), throwsStateError);
  });

  test('retener carretes: solo al volver a tirar, máximo 2, y se respetan', () {
    final draft = Draft(_catalogo, azar: Random(3));
    expect(() => draft.tirar(nueva, retenidos: {Carrete.franquicia}), throwsArgumentError);
    final primera = draft.tirar(nueva);
    expect(
      () => draft.tirar(primera, retenidos: Carrete.values.toSet()),
      throwsArgumentError,
      reason: 'los 3 carretes no se pueden retener',
    );
    for (var i = 0; i < 20; i++) {
      final otra = draft.tirar(primera, retenidos: {Carrete.franquicia});
      expect(otra.tirada!.franquiciaId, primera.tirada!.franquiciaId);
    }
  });

  test('retener una combinación sin cartas libres no deja tirar', () {
    final draft = Draft(_catalogo, azar: Random(4));
    // LAL 80s solo tiene a #4 (BASE); con la BASE ocupada, retener LAL + 80s no tiene opciones.
    final t = Temporada(
      id: 't',
      franquiciaUsuarioId: 'CHI',
      plantel: const Plantel().asignar(_catalogo[7], Posicion.base).asignar(_catalogo[2], Posicion.sextoHombre),
      tirada: const Tirada(franquiciaId: 'LAL', epoca: Epoca.anios80, tier: Tier.sPlus),
    );
    expect(draft.candidatos(t), isEmpty, reason: 'el #4 solo es BASE y el Sexto Hombre ya está ocupado');
    expect(draft.puedeVolverATirar(t, {Carrete.franquicia, Carrete.epoca}), isFalse);
    expect(draft.puedeVolverATirar(t, {Carrete.franquicia}), isTrue);
  });

  test('la rareza respeta los pesos 6/3/1', () {
    final draft = Draft(_catalogo, azar: Random(5));
    final conteo = {for (final t in Tier.values) t: 0};
    for (var i = 0; i < 5000; i++) {
      conteo.update(draft.tirar(nueva).tirada!.tier, (n) => n + 1);
    }
    expect(conteo[Tier.a]! / 5000, closeTo(0.6, 0.03));
    expect(conteo[Tier.s]! / 5000, closeTo(0.3, 0.03));
    expect(conteo[Tier.sPlus]! / 5000, closeTo(0.1, 0.03));
  });

  test('elegir: solo cartas de la tirada, en un puesto libre, y limpia la tirada', () {
    final draft = Draft(_catalogo, azar: Random(6));
    final t = nueva.conTirada(const Tirada(franquiciaId: 'CHI', epoca: Epoca.anios90, tier: Tier.sPlus));
    expect(() => draft.elegir(t, _catalogo[3], Posicion.base), throwsA(isA<ReglaPlantelException>()));
    final despues = draft.elegir(t, _catalogo[0], Posicion.escolta);
    expect(despues.plantel.en(Posicion.escolta), _catalogo[0]);
    expect(despues.tirada, isNull);
  });

  test('un draft completo llena los 6 puestos y la tirada se guarda en JSON', () {
    final draft = Draft(_catalogo, azar: Random(7));
    var t = nueva;
    while (!t.plantel.completo) {
      t = draft.tirar(t);
      final guardada = Temporada.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(guardada.tirada, t.tirada);
      final carta = draft.candidatos(t).first;
      t = draft.elegir(t, carta, t.plantel.posicionesDisponiblesPara(carta).first);
    }
    expect(t.plantel.jugadores.length, 6);
    expect(() => draft.tirar(t), throwsStateError);
  });

  test('estilo 82-0: sale todo el plantel de la franquicia y época, primero el Tier garantizado', () {
    final draft = Draft(_catalogo, azar: Random(8));
    final t = nueva.conTirada(const Tirada(franquiciaId: 'CHI', epoca: Epoca.anios90, tier: Tier.a));
    expect(draft.candidatos(t).map((j) => j.nbaPlayerId), [3, 1, 2]);
  });
}
