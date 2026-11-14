// Torneos por época (guantelete, camadas, universidades) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/epocas.dart';
import 'package:dinastia_nba/presentation/modos/epocas.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _fuente(String familia, List<String> archivos) async {
  final loader = FontLoader(familia);
  for (final a in archivos) {
    loader.addFont(Future.value(ByteData.sublistView(File(a).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(4));
  final modos = ModosEpocas(liga, azar: Random(4));
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  Future<void> captura(
    WidgetTester t,
    Temporada x,
    String archivo, {
    Size tam = const Size(412, 1500),
    double dpr = 2.5,
  }) async {
    t.view.physicalSize = tam * dpr;
    t.view.devicePixelRatio = dpr;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('BOS')),
        home: EpocasPantalla(temporada: x, liga: liga, onCambio: (_) {}),
      ),
    );
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$archivo.png'));
  }

  testWidgets('guantelete: mini-draft', (t) async {
    final x = modos.nuevoGuantelete(id: 'cg', franquiciaId: 'BOS', dificultad: Dificultad.normal);
    await captura(t, x, 'm3-epocas-draft', tam: const Size(412, 1100));
  });

  testWidgets('guantelete: reclutar tras ganar la década', (t) async {
    var x = modos.nuevoGuantelete(id: 'cg2', franquiciaId: 'BOS', dificultad: Dificultad.normal);
    while (EstadoEpocas.de(x).enDraft) {
      x = modos.elegirDraft(x, EstadoEpocas.de(x).ofertas.first);
    }
    final e = EstadoEpocas.de(x);
    final ganado = e.cruce!.conResultado(101, 90).conResultado(99, 95);
    x = e.copyWith(cruce: ganado, historial: [ganado], reclutando: true).en(x);
    await captura(t, x, 'm3-epocas-reclutar');
  });

  testWidgets('guantelete: tu cruce con el camino', (t) async {
    var x = modos.nuevoGuantelete(id: 'cg3', franquiciaId: 'BOS', dificultad: Dificultad.normal);
    while (EstadoEpocas.de(x).enDraft) {
      x = modos.elegirDraft(x, EstadoEpocas.de(x).ofertas.first);
    }
    await captura(t, x, 'm3-epocas-cruce', tam: const Size(412, 1500));
  });

  testWidgets('camadas: cuadro tras una ronda', (t) async {
    var x = modos.nuevoCuadro(
      id: 'cc',
      modo: ModoJuego.camadas,
      equipos: modos.equiposCamadas(),
      elegido: 0,
      dificultad: Dificultad.normal,
    );
    x = modos.simularCruce(x);
    await captura(t, x, 'm3-epocas-camadas');
  });

  testWidgets('universidades: tablet horizontal', (t) async {
    final x = modos.nuevoCuadro(
      id: 'cu',
      modo: ModoJuego.universidades,
      equipos: modos.equiposUniversidades(),
      elegido: 2,
      dificultad: Dificultad.normal,
    );
    await captura(t, x, 'm3-epocas-universidades-tablet', tam: const Size(1340, 900), dpr: 1.8);
  });
}
