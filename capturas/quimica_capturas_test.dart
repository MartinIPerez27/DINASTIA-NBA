// Medidor de química: fila del draft y detalle (no corre en CI).
import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/presentation/draft/quimica_panel.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
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
  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  testWidgets('química baja, media y alta + detalle', (t) async {
    t.view.physicalSize = const Size(412, 900) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final chi90 = catalogo.where((j) => j.equipo == 'CHI' && j.epoca.name == 'anios90').take(6).toList();
    final mezcla = [
      for (final f in ['BOS', 'LAL', 'MIA', 'DEN', 'PHX', 'UTA'])
        catalogo.firstWhere((j) => j.franquiciaId == f && j.epoca.name == 'anios2010'),
    ];
    final nada = [
      for (final (f, e) in [
        ('BOS', 'anios60'),
        ('LAL', 'anios80'),
        ('MIA', 'anios2000'),
        ('DEN', 'actualidad'),
        ('PHX', 'anios70'),
        ('UTA', 'anios90'),
      ])
        catalogo.firstWhere((j) => j.franquiciaId == f && j.epoca.name == e),
    ];
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                PanelQuimica(jugadores: nada),
                const SizedBox(height: 8),
                PanelQuimica(jugadores: mezcla),
                const SizedBox(height: 8),
                PanelQuimica(jugadores: chi90),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PanelQuimica(jugadores: chi90, compacto: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/quimica-filas.png'));
    await t.tap(find.byType(PanelQuimica).at(1));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/quimica.png'));
  });
}
