import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/presentation/partido/cancha_partido.dart';
import 'package:dinastia_nba/presentation/partido/coreografia.dart';
import 'package:dinastia_nba/presentation/partido/escena_cancha.dart';
import 'package:dinastia_nba/presentation/partido/marcador_vivo.dart';
import 'package:dinastia_nba/presentation/partido/repeticion.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final jugadores = <String, Jugador>{for (final j in catalogo) j.id: j};
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final temporada = liga.iniciar(Temporada(id: 'w', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  Coreografia? coreo;
  var atacaLocal = true;

  setUpAll(() {
    for (var g = 0; g < 10 && coreo == null; g++) {
      final m = liga.motor(temporada, temporada.calendario[g], azar: Random(60 + g));
      while (!m.terminado && coreo == null) {
        final e = m.siguiente();
        if (e.tipo == TipoEvento.tiro && e.convertido && e.triple) {
          coreo = Coreografia(
            evento: e,
            atacantes: List.of(m.enCancha(e.local)),
            defensores: List.of(m.enCancha(!e.local)),
            haciaArriba: true,
            desde: const {},
            balonDesde: const Offset(25, 47),
            poseedorDesde: null,
            segundaOportunidad: false,
          );
          atacaLocal = e.local;
        }
      }
    }
  });

  const equipaciones = Equipaciones(
    propio: Color(0xFFCE1141),
    textoPropio: Colors.white,
    ribetePropio: Colors.white,
    rival: Color(0xFFEEEEEE),
    textoRival: Colors.black,
    ribeteRival: Color(0xFF1D428A),
  );

  testWidgets('la escena en vivo pinta toda la jugada, con la cámara moviéndose, sin errores', (t) async {
    final c = coreo!;
    final ctrl = AnimationController(
      vsync: const TestVSync(),
      duration: Duration(seconds: c.duracion.ceil()),
    );
    addTearDown(ctrl.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 640,
          child: EscenaCancha(
            progreso: ctrl,
            coreo: c,
            atacaLocal: atacaLocal,
            usuarioLocal: true,
            franquicia: franquiciaPorId('CHI'),
            franquiciaLocal: franquiciaPorId('CHI'),
            franquiciaVisitante: franquiciaPorId('LAL'),
            equipaciones: equipaciones,
            jugadores: jugadores,
            energias: const {},
            estilo: const EstiloCancha(),
            colorLed: Colors.amber,
            cartel: (_, _) => 'PRUEBA',
            playoffs: true,
            clutch: true,
          ),
        ),
      ),
    );
    ctrl.forward();
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(t.takeException(), isNull);
    final estado = t.state<EscenaCanchaState>(find.byType(EscenaCancha));
    expect(estado.tiempo, greaterThan(1));
    expect(estado.camara.zoom, greaterThanOrEqualTo(1));
    ctrl.stop();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('la repetición instantánea corre en cámara lenta y avisa al terminar (o al tocarla)', (t) async {
    final c = coreo!;
    var termino = 0;
    await t.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 640,
          child: RepeticionEnVivo(
            destacada: Destacada(coreo: c, frase: 'x', puntaje: 7, atacaLocal: atacaLocal, cuarto: 1, reloj: 100),
            franquicia: franquiciaPorId('CHI'),
            equipaciones: equipaciones,
            jugadores: jugadores,
            usuarioLocal: true,
            colorLed: Colors.amber,
            estilo: const EstiloCancha(),
            onTerminar: () => termino++,
          ),
        ),
      ),
    );
    expect(find.text('REPETICIÓN'), findsWidgets);
    await t.pump(const Duration(seconds: 3));
    expect(termino, 0, reason: 'sigue pasando en cámara lenta');
    await t.pump(const Duration(seconds: 12));
    expect(termino, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('el marcador parpadea y muestra el +N al anotar, parcial, en llamas y probabilidad', (t) async {
    Widget marcador((int, int) puntos) => MaterialApp(
      theme: temaFranquicia(franquiciaPorId('CHI')),
      home: Scaffold(
        body: MarcadorVivo(
          local: franquiciaPorId('CHI'),
          visitante: franquiciaPorId('LAL'),
          puntos: puntos,
          cuarto: 4,
          reloj: 90,
          posesion: 14,
          faltas: const (2, 3),
          tiemposMuertos: const (3, 4),
          clutch: true,
          onSalir: () {},
          probabilidad: 0.62,
          parcial: const (true, 10),
          enLlamas: 'JORDAN',
        ),
      ),
    );
    await t.pumpWidget(marcador((90, 88)));
    expect(find.textContaining('PARCIAL 10-0'), findsOneWidget);
    expect(find.textContaining('EN LLAMAS · JORDAN'), findsOneWidget);
    await t.pumpWidget(marcador((93, 88)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('+3'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('+3'), findsNothing);
    // Apagar el pulso del clutch para cerrar la prueba.
    await t.pumpWidget(const SizedBox());
  });
}
