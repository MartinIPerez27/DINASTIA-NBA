import 'dart:convert';

import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/playbook.dart';
import 'package:flutter_test/flutter_test.dart';

var _id = 0;
Jugador _j(
  List<Posicion> pos,
  RolCancha rol, {
  double ppp = 15,
  double rpp = 5,
  double app = 3,
  double rob = 1,
  double tap = 0.5,
  double tc = 0.46,
  double t3 = 0.35,
  int iq = 75,
}) => Jugador(
  id: '${++_id}',
  nbaPlayerId: _id,
  nombre: 'Jugador $_id',
  franquiciaId: 'CHI',
  epoca: Epoca.anios2010,
  tier: Tier.a,
  posiciones: pos,
  rol: rol,
  dorsal: _id,
  stats: EstadisticasJugador(
    ppp: ppp,
    rpp: rpp,
    app: app,
    robP: rob,
    tapP: tap,
    pctTc: tc,
    pctT3: t3,
    pctTl: 0.8,
    minP: 34,
    perP: 2,
    iq: iq,
  ),
);

Plantel _plantel(List<Jugador> js) {
  var p = const Plantel();
  for (final (i, j) in js.indexed) {
    p = p.asignar(j, Posicion.values[i]);
  }
  return p;
}

void main() {
  test('plantel de tiradores: ofensiva de triple', () {
    final perfil = PerfilPlantel.de(
      _plantel([
        _j([Posicion.base, Posicion.sextoHombre], RolCancha.anotadorExterior, t3: 0.43, app: 6),
        _j([Posicion.escolta], RolCancha.tiradorPantallas, t3: 0.42),
        _j([Posicion.alero], RolCancha.especialista3D, t3: 0.40),
        _j([Posicion.alaPivot], RolCancha.alaPivotTirador, t3: 0.39),
        _j([Posicion.pivot], RolCancha.pivotTirador, t3: 0.37),
        _j([Posicion.escolta], RolCancha.microondas, t3: 0.40),
      ]),
    );
    final r = recomendar(perfil);
    expect([
      SistemaOfensivo.paceAndSpace,
      SistemaOfensivo.cincoAbierto,
      SistemaOfensivo.sevenSeconds,
    ], contains(r.tactica.ofensiva));
    expect(perfil.figuras[Rasgo.triple]!.stats.pctT3, 0.43);
  });

  test('plantel de gigantes: poste y protección del aro', () {
    final perfil = PerfilPlantel.de(
      _plantel([
        _j([Posicion.base], RolCancha.organizadorPuro, app: 8, t3: 0.30),
        _j([Posicion.escolta], RolCancha.superestrellaAclarados, t3: 0.30),
        _j([Posicion.alero], RolCancha.aleroCortador, t3: 0.28, rpp: 8),
        _j([Posicion.alaPivot], RolCancha.maestroPoste, ppp: 26, tc: 0.56, rpp: 12, tap: 2.4, t3: 0.1),
        _j([Posicion.pivot], RolCancha.goliatPintura, ppp: 28, tc: 0.58, rpp: 12, tap: 3, t3: 0.05),
        _j([Posicion.pivot], RolCancha.protectorAro, tap: 3, rpp: 11, t3: 0.0),
      ]),
    );
    final r = recomendar(perfil);
    expect(r.tactica.ofensiva, SistemaOfensivo.postInsideOut);
    expect([EsquemaDefensivo.dropCoverage, EsquemaDefensivo.zona23], contains(r.tactica.defensiva));
    expect(perfil.motivos(EsquemaDefensivo.dropCoverage.rasgos).first.$1, Rasgo.proteccionAro);
  });

  test('afinidad entre 1 y 99 para todos los sistemas, también con plantel vacío', () {
    for (final perfil in [PerfilPlantel.de(const Plantel())]) {
      for (final o in SistemaOfensivo.values) {
        expect(perfil.afinidad(o.rasgos), inInclusiveRange(1, 99));
      }
      expect(recomendar(perfil).tactica, isNotNull);
    }
  });

  test('ritmo opuesto penaliza: la recomendación nunca junta extremos si hay alternativa pareja', () {
    final perfil = PerfilPlantel.de(
      _plantel([
        for (final pos in [
          Posicion.base,
          Posicion.escolta,
          Posicion.alero,
          Posicion.alaPivot,
          Posicion.pivot,
          Posicion.alero,
        ])
          _j([pos], RolCancha.controladorTotal),
      ]),
    );
    final r = recomendar(perfil);
    expect((r.tactica.ofensiva.ritmo - r.tactica.defensiva.ritmo).abs(), lessThan(2));
  });

  test('fase de tácticas entre el draft y la temporada, y se guarda en JSON', () {
    final completo = _plantel([
      for (final pos in Posicion.titulares) _j([pos], RolCancha.controladorTotal),
      _j([Posicion.alero], RolCancha.microondas),
    ]);
    final t = Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: completo);
    expect(t.fase, FaseTemporada.tacticas);
    final confirmada = t.copyWith(
      tactica: const Tactica(ofensiva: SistemaOfensivo.princeton, defensiva: EsquemaDefensivo.packLine),
      tacticaConfirmada: true,
    );
    expect(confirmada.fase, FaseTemporada.temporadaRegular);
    final copia = Temporada.fromJson(jsonDecode(jsonEncode(confirmada.toJson())) as Map<String, dynamic>);
    expect(copia.tacticaConfirmada, isTrue);
    expect(copia.tactica, confirmada.tactica);
    expect(copia.conTirada(null).tacticaConfirmada, isTrue, reason: 'conTirada no pierde el dato');
  });
}
