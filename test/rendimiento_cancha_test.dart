import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/presentation/partido/cancha_partido.dart';
import 'package:dinastia_nba/presentation/partido/coreografia.dart';
import 'package:dinastia_nba/presentation/partido/escena_cancha.dart';
import 'package:dinastia_nba/presentation/partido/publico.dart';
import 'package:dinastia_nba/presentation/partido/repeticion.dart' show Equipaciones;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Costo de pintura de la cancha por cuadro, sin dispositivo: arma jugadas reales de un partido y
/// graba cada cuadro en un `PictureRecorder` (es el trabajo de Dart/CPU de `paint`: comandos,
/// texto y tramas; la rasterización de la GPU escala con la cantidad de comandos grabados).
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(5));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final temporada = liga.iniciar(Temporada(id: 'r', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));

  /// Primeras [n] jugadas de un partido encadenadas como en la pantalla.
  List<(Coreografia, bool)> jugadas(int n) {
    final m = liga.motor(temporada, liga.proximoDelUsuario(temporada)!, azar: Random(9));
    final posiciones = <String, Offset>{};
    var balon = const Offset(25, 47);
    String? poseedor;
    var segunda = false;
    final r = <(Coreografia, bool)>[];
    while (!m.terminado && r.length < n) {
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
      for (final j in [...c.atacantes, ...c.defensores]) {
        posiciones[j.id] = c.posicion(j.id, 1);
      }
      if (c.saliente case final s?) posiciones.remove(s.id);
      balon = c.balon(1).$1;
      poseedor = c.poseedorFinal;
      segunda = e.tipo == TipoEvento.tiro && e.reboteOfensivo;
      r.add((c, ataca));
    }
    return r;
  }

  /// Microsegundos medios de `paint` por cuadro sobre [tamano] (grabando, sin rasterizar), a la
  /// velocidad [velocidad] del partido (x1/x2/x4: a más velocidad, más jugada avanza por cuadro).
  double microsPorCuadro(List<(Coreografia, bool)> js, Size tamano, {int velocidad = 1, bool pausa = false}) {
    final franquicia = franquiciaPorId('CHI');
    var cuadros = 0;
    final reloj = Stopwatch();
    const equipaciones = Equipaciones(
      propio: Color(0xFFCE1141),
      textoPropio: Colors.white,
      ribetePropio: Colors.white,
      rival: Color(0xFFEEEEEE),
      textoRival: Colors.black,
      ribeteRival: Color(0xFF1D428A),
    );
    for (var vuelta = 0; vuelta < 2; vuelta++) {
      if (vuelta == 1) reloj.start();
      for (final (c, local) in js) {
        final pasos = max(2, (c.duracion * 60 / velocidad).round());
        for (var k = 0; k <= (pausa ? 20 : pasos); k++) {
          final t = pausa ? 0.5 : k / pasos;
          final painter = cuadroDeCancha(
            coreo: c,
            t: t,
            atacaLocal: local,
            usuarioLocal: true,
            franquicia: franquicia,
            equipaciones: equipaciones,
            jugadores: const {},
            colorLed: const Color(0xFFFDB927),
            estilo: const EstiloCancha(),
            plano: c.plano(t),
            cartel: 'CHICAGO · DINASTÍA 82-0',
            tiempo: t * c.duracion,
            margenArriba: 78,
            margenAbajo: 50,
            ambiente: const AmbienteCancha(publico: PublicoEstado(excitacion: 0.6)),
          );
          final grabador = ui.PictureRecorder();
          painter.paint(Canvas(grabador), tamano);
          grabador.endRecording().dispose();
          if (vuelta == 1) cuadros++;
        }
      }
    }
    return reloj.elapsedMicroseconds / cuadros;
  }

  test('costo de pintura por cuadro (teléfono y tablet, x1/x2/x4 y pausa)', () {
    final js = jugadas(30);
    final r = <String, double>{
      'teléfono x1': microsPorCuadro(js, const Size(390, 640)),
      'teléfono x2': microsPorCuadro(js, const Size(390, 640), velocidad: 2),
      'teléfono x4': microsPorCuadro(js, const Size(390, 640), velocidad: 4),
      'teléfono pausa': microsPorCuadro(js, const Size(390, 640), pausa: true),
      'tablet x1': microsPorCuadro(js, const Size(560, 900)),
    };
    // Antes (fichas circulares, sin público, medido con esta misma prueba y el pintor anterior):
    // teléfono 309 µs y tablet 338 µs por cuadro. Ahora se dibujan figuras con brazos, tribuna con ~450
    // personas, banco y técnicos, con los textos cacheados.
    // ignore: avoid_print
    print('RENDIMIENTO paint/cuadro (antes: teléfono 309 µs, tablet 338 µs): ${r.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(0)} µs').join(', ')}');
    // Presupuesto: un cuadro a 60 fps son 16 667 µs; la pintura de Dart debe quedar por debajo de un
    // cuarto (el resto es de la GPU y del resto de la pantalla). En JIT de pruebas es más lento que en AOT.
    for (final e in r.entries) {
      expect(e.value, lessThan(4200), reason: e.key);
    }
  });
}
