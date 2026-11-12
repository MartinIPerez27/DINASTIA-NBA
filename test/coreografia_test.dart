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
import 'package:flutter_test/flutter_test.dart';

/// Encadena las coreografías de un partido entero como lo hace la pantalla en vivo.
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(5));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final temporada = liga.iniciar(Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));

  test('un partido completo: sin saltos, dentro de la cancha y con tiempos de transmisión', () {
    final partido = liga.proximoDelUsuario(temporada)!;
    final m = liga.motor(temporada, partido, azar: Random(9));
    final posiciones = <String, Offset>{};
    var balon = const Offset(25, 47);
    String? poseedor;
    var segunda = false;
    var cuarto = 1;
    var robos = 0, posesiones = 0;
    var segundos = 0.0;
    while (!m.terminado) {
      final e = m.siguiente();
      final ataca = switch (e.tipo) {
        TipoEvento.tiro || TipoEvento.libres || TipoEvento.perdida || TipoEvento.cambio => e.local,
        _ => true,
      };
      cuarto = e.tipo == TipoEvento.finCuarto ? e.cuarto - 1 : e.cuarto;
      final c = Coreografia(
        evento: e,
        atacantes: List.of(m.enCancha(ataca)),
        defensores: List.of(m.enCancha(!ataca)),
        haciaArriba: ataca == (cuarto <= 2),
        desde: Map.of(posiciones),
        balonDesde: balon,
        poseedorDesde: poseedor,
        segundaOportunidad: segunda,
        saliente: e.tipo == TipoEvento.cambio ? m.enBanco(e.local) : null,
      );
      expect(c.duracion, inInclusiveRange(1.2, 16), reason: '${e.tipo}: ${e.texto}');
      segundos += c.duracion;
      if (e.tipo == TipoEvento.tiro || e.tipo == TipoEvento.perdida) posesiones++;
      if (e.tipo == TipoEvento.perdida && e.defensorId != null) {
        robos++;
        expect(c.poseedorFinal, e.defensorId, reason: 'el que roba termina con la pelota');
      }
      // Continuidad: al arrancar, cada jugador está donde quedó.
      for (final j in [...c.atacantes, ...c.defensores]) {
        if (posiciones[j.id] case final antes?) {
          expect((c.posicion(j.id, 0) - antes).distance, lessThan(1.5), reason: '${e.tipo} ${j.nombre}');
        }
      }
      // Nadie se teletransporta: a 60 cuadros por segundo, nunca más que un sprint (~30 pies/s en el pico).
      for (final j in [...c.atacantes, ...c.defensores]) {
        var previa = c.posicion(j.id, 0);
        final pasos = (c.duracion * 60).ceil();
        for (var k = 1; k <= pasos; k++) {
          final ahora = c.posicion(j.id, k / pasos);
          expect(
            (ahora - previa).distance * 60,
            lessThan(32),
            reason:
                '${e.tipo} ${j.nombre} ${c.atacantes.contains(j) ? "ataca" : "defiende"} en $k/$pasos contra=${e.contraataque} t2=$segunda',
          );
          expect(ahora.dx, inInclusiveRange(-4, 54));
          expect(ahora.dy, inInclusiveRange(-4, 98));
          previa = ahora;
        }
      }
      // La pelota tampoco salta: en el aire, a lo sumo un pase tenso (~90 pies/s).
      var previaBalon = c.balon(0).$1;
      expect((previaBalon - balon).distance, lessThan(3), reason: 'la pelota arranca donde quedó: ${e.texto}');
      final pasosBalon = (c.duracion * 60).ceil();
      for (var k = 1; k <= pasosBalon; k++) {
        final ahora = c.balon(k / pasosBalon).$1;
        expect(
          (ahora - previaBalon).distance * 60,
          lessThan(95),
          reason:
              'pelota: ${e.texto} en $k/$pasosBalon: '
              '${[for (var q = k - 3; q <= k + 2; q++) c.balon(q / pasosBalon)].map((b) => '(${b.$1.dx.toStringAsFixed(1)},${b.$1.dy.toStringAsFixed(1)} ${b.$3})').join(' ')}',
        );
        previaBalon = ahora;
      }
      for (final j in [...c.atacantes, ...c.defensores]) {
        posiciones[j.id] = c.posicion(j.id, 1);
      }
      if (c.saliente case final s?) posiciones.remove(s.id);
      final fin = c.balon(1);
      balon = fin.$1;
      poseedor = c.poseedorFinal;
      segunda = e.tipo == TipoEvento.tiro && e.reboteOfensivo;
    }
    expect(robos, greaterThan(0));
    // A x2 (la velocidad por defecto) un partido dura entre 8 y 20 minutos.
    expect(segundos / 2 / 60, inInclusiveRange(8, 20), reason: '$posesiones posesiones');
  });
}
