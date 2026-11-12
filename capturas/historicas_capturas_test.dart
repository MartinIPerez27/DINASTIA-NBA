// Cartas históricas con tipografías reales (no corre en CI).
import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_jugador.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:dinastia_nba/presentation/widgets/ficha_jugador.dart';
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
  final c = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final ids = [
    'mikange01-LAL-50',
    'paytoga01-OKC-90',
    'russebi01-BOS-60',
    'roberos01-SAC-60',
    'rodmade01-DET-90',
    'maravpe01-UTA-70',
  ];
  final cartas = [for (final id in ids) c.firstWhere((j) => j.id == id)];
  final stags = c.firstWhere((j) => j.equipo == 'CHS');
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
  });

  testWidgets('historicas', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('OKC')),
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final j in cartas) SizedBox(width: 124, child: CartaVertical(jugador: j))],
                ),
                const SizedBox(height: 12),
                CartaJugador(jugador: stags),
                const SizedBox(height: 8),
                CartaJugador(jugador: cartas[2]),
              ],
            ),
          ),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/historicas.png'));
  });

  testWidgets('ficha russell', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('BOS')),
        home: Scaffold(
          body: SingleChildScrollView(child: FichaJugador(jugador: cartas[2])),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/ficha-russell.png'));
  });
}
