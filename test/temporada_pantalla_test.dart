import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/presentation/pantallas/partido_pantalla.dart';
import 'package:dinastia_nba/presentation/partido/sonido_partido.dart';
import 'package:dinastia_nba/presentation/partido/voz_relator.dart';
import 'package:dinastia_nba/presentation/pantallas/temporada_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    SonidoPartido.habilitado = false;
    VozRelator.habilitado = false;
  });
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(5));

  Temporada iniciada() {
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return liga.iniciar(Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  }

  void telefono(WidgetTester t) {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  testWidgets('temporada: simular un partido actualiza récord, resultados y tabla', (t) async {
    telefono(t);
    final guardadas = <Temporada>[];
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: TemporadaPantalla(temporada: iniciada(), liga: liga, onCambio: guardadas.add),
      ),
    );
    expect(find.text('JUGAR EN VIVO'), findsOneWidget);
    await t.tap(find.text('SIMULAR'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(guardadas.last.registroUsuario.jugados, 1);
    await t.tap(find.text('Posiciones'));
    await t.pumpAndSettle();
    expect(find.text('Chicago Bulls'), findsOneWidget);
    await t.tap(find.text('Plantel'));
    await t.pumpAndSettle();
    expect(find.textContaining('1 PJ'), findsWidgets);
  });

  testWidgets('simular toda la temporada: confirma, muestra progreso y termina en playoffs', (t) async {
    telefono(t);
    final guardadas = <Temporada>[];
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: TemporadaPantalla(temporada: iniciada(), liga: liga, onCambio: guardadas.add, onPlayoffs: () {}),
      ),
    );
    await t.ensureVisible(find.text('SIMULAR TODA LA TEMPORADA'));
    await t.tap(find.text('SIMULAR TODA LA TEMPORADA'));
    await t.pumpAndSettle();
    expect(find.text('¿Simular el resto de la temporada?'), findsOneWidget);
    await t.tap(find.text('SIMULAR 82'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('Simulando'), findsOneWidget);
    for (var i = 0; i < 400 && guardadas.isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 1));
    }
    await t.pump();
    expect(guardadas.last.registroUsuario.jugados, 82);
    expect(guardadas.last.fase, FaseTemporada.playoffs);
    expect(find.text('IR A LOS PLAYOFFS'), findsOneWidget);
  });

  testWidgets('partido en vivo: arranca 0-0, avanza y al salir se simula lo que falta', (t) async {
    telefono(t);
    final temporada = iniciada();
    final p = liga.proximoDelUsuario(temporada)!;
    final motor = liga.motor(temporada, p, azar: Random(1));
    MotorPartido? terminado;
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PartidoPantalla(
          motor: motor,
          usuarioLocal: p.localId == 'CHI',
          franquiciaUsuario: franquiciaPorId('CHI'),
          identidadLocal: franquiciaPorId(p.localId == 'CHI' ? 'CHI' : temporada.rivales[p.localId]!.identidadId),
          identidadVisitante: franquiciaPorId(
            p.visitanteId == 'CHI' ? 'CHI' : temporada.rivales[p.visitanteId]!.identidadId,
          ),
          onTerminado: (m) => terminado = m,
        ),
      ),
    );
    expect(find.text('Q1'), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(motor.puntosLocal + motor.puntosVisitante, greaterThan(0));
    await t.tap(find.textContaining('TIEMPO MUERTO ·'));
    await t.pump();
    expect(find.text('TIEMPO MUERTO · 4'), findsOneWidget);

    // Pausa: el partido no avanza hasta que se reanuda.
    await t.tap(find.byTooltip('Pausa'));
    await t.pump();
    final congelado = motor.puntosLocal + motor.puntosVisitante;
    final cuarto = motor.cuarto, reloj = motor.reloj;
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    expect((motor.puntosLocal + motor.puntosVisitante, motor.cuarto, motor.reloj), (congelado, cuarto, reloj));
    expect(find.text('PAUSA'), findsOneWidget);
    await t.tap(find.byTooltip('Seguir'));
    await t.pump();
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(motor.reloj, isNot(reloj));

    await t.tap(find.byTooltip('Salir del partido'));
    await t.pumpAndSettle();
    await t.tap(find.text('Simular y salir'));
    await t.pump();
    expect(terminado?.terminado, isTrue);
  });
}
