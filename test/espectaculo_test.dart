import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/presentation/partido/coreografia.dart';
import 'package:dinastia_nba/presentation/partido/jugadores_animados.dart';
import 'package:dinastia_nba/presentation/partido/racha.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las animaciones nuevas (cuerpos, poses, ánimos, pases variados, pantallas, rebotes disputados, técnicos y
/// cámara) sobre partidos completos: aparecen, son finitas y respetan las garantías de la coreografía.
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final temporada = liga.iniciar(Temporada(id: 'e', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));

  final poses = <Pose>{};
  final animos = <Animo>{};
  var conTecnicos = 0;
  var maxZoom = 0.0, minZoom = 9.0;
  final climax = <EventoPartido>[];

  setUpAll(() {
    for (var g = 0; g < 4; g++) {
      final m = liga.motor(temporada, temporada.calendario[g], azar: Random(40 + g));
      final posiciones = <String, Offset>{};
      var balon = const Offset(25, 47);
      String? poseedor;
      var segunda = false;
      while (!m.terminado) {
        final e = m.siguiente();
        final ataca = switch (e.tipo) {
          TipoEvento.tiro ||
          TipoEvento.libres ||
          TipoEvento.perdida ||
          TipoEvento.falta ||
          TipoEvento.salto ||
          TipoEvento.cambio => e.local,
          _ => true,
        };
        final cuarto = e.tipo == TipoEvento.finCuarto ? e.cuarto - 1 : e.cuarto;
        final c = Coreografia(
          evento: e,
          atacantes: List.of(m.enCancha(ataca)),
          defensores: List.of(m.enCancha(!ataca)),
          haciaArriba: ataca == (cuarto <= 2),
          desde: Map.of(posiciones),
          balonDesde: balon,
          poseedorDesde: poseedor,
          segundaOportunidad: segunda,
          saliente: e.tipo == TipoEvento.cambio ? liga.jugador(e.saleId ?? '') : null,
        );
        const pasos = 24;
        for (var k = 0; k <= pasos; k++) {
          final t = k / pasos;
          final (pelota, _, tiene) = c.balon(t);
          final plano = c.plano(t);
          expect(plano.zoom, inInclusiveRange(1, 1.9), reason: e.texto);
          expect(plano.x.isFinite && plano.y.isFinite, isTrue);
          maxZoom = max(maxZoom, plano.zoom);
          minZoom = min(minZoom, plano.zoom);
          for (final j in [...c.atacantes, ...c.defensores]) {
            final q = c.postura(j.id, t);
            expect(
              q.rumbo.isFinite && q.fase.isFinite && q.velocidad.isFinite,
              isTrue,
              reason: '${e.tipo} ${j.nombre}',
            );
            expect(q.intensidad, inInclusiveRange(0, 1));
            expect(c.salto(j.id, t), inInclusiveRange(0, 1));
            poses.add(q.pose);
            if (q.animo != Animo.neutro && q.intensidad > 0.3) animos.add(q.animo);
            // La pelota sigue anclada a las manos de quien la tiene.
            if (tiene == j.id) {
              expect((pelota - c.posicion(j.id, t)).distance, lessThan(1.6), reason: '${e.tipo} ${j.nombre}');
            }
          }
          if (c.tecnicos(t).isNotEmpty) conTecnicos++;
        }
        if (c.momentoClimax case final mc?) {
          expect(mc, inInclusiveRange(0, 1));
          climax.add(e);
        }
        for (final j in [...c.atacantes, ...c.defensores]) {
          posiciones[j.id] = c.posicion(j.id, 1);
        }
        if (c.saliente case final s?) posiciones.remove(s.id);
        balon = c.balon(1).$1;
        poseedor = c.poseedorFinal;
        segunda = e.tipo == TipoEvento.tiro && e.reboteOfensivo;
      }
    }
  });

  test('aparecen las poses nuevas: pase, pantalla, cierre, rebote, robo, libres, volcada, técnicos', () {
    for (final pose in [
      Pose.corre,
      Pose.dribla,
      Pose.tira,
      Pose.defiende,
      Pose.contesta,
      Pose.rebotea,
      Pose.pasa,
      Pose.pantalla,
      Pose.roba,
      Pose.libre,
    ]) {
      expect(poses, contains(pose), reason: 'nunca apareció $pose: $poses');
    }
    expect(conTecnicos, greaterThan(0), reason: 'los técnicos aparecen en los tiempos muertos');
  });

  test('tras jugadas importantes hay festejo y manos a la cabeza', () {
    expect(animos, containsAll([Animo.celebra, Animo.manosCabeza]));
  });

  test('la cámara se abre en los contraataques y se acerca en lo vistoso', () {
    expect(minZoom, closeTo(1, 0.01));
    expect(maxZoom, greaterThan(1.3));
    expect(climax, isNotEmpty);
  });

  test('rachas: "en llamas" con 3 aciertos seguidos y parcial de 7 o más', () {
    EventoPartido tiro(String id, bool entra, {bool local = true}) => EventoPartido(
      tipo: TipoEvento.tiro,
      local: local,
      cuarto: 1,
      reloj: 500,
      marcadorLocal: 0,
      marcadorVisitante: 0,
      texto: '',
      jugadorId: id,
      convertido: entra,
      puntos: entra ? 2 : 0,
    );
    final r = RachaTiradores();
    for (var i = 0; i < 3; i++) {
      r.registrar(tiro('a', true));
    }
    expect(r.enLlamas('a'), isTrue);
    expect(r.parcial, isNull, reason: '6 puntos todavía no es un parcial');
    r.registrar(tiro('a', true));
    expect(r.parcial, (true, 8));
    r.registrar(tiro('a', false));
    expect(r.enLlamas('a'), isFalse);
    r.registrar(tiro('b', true, local: false));
    expect(r.parcial, isNull);
  });

  test('el hash de los jugadores es estable (mismo tono de piel siempre)', () {
    expect(hashEstable('lebron-2012'), hashEstable('lebron-2012'));
    expect(hashEstable('a'), isNot(hashEstable('b')));
    expect(hashEstable('abc'), 0x1A47E90B);
  });
}
