// Capturas del menú de modos nuevo (teléfono y tablet) con tipografías reales.
// Uso: flutter test capturas/menu_modos_capturas_test.dart --update-goldens  → capturas/salida/menu-*.png
import 'dart:io';

import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/modos/modos.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _cargarFuente(String familia, List<String> archivos) async {
  final loader = FontLoader(familia);
  for (final a in archivos) {
    loader.addFont(Future.value(ByteData.sublistView(File(a).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    final mf = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
    await _cargarFuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _cargarFuente('Doto', ['assets/fonts/Doto.ttf']);
    await _cargarFuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
  });

  const guardada = Temporada(id: 'x', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.racha);

  Future<void> cap(WidgetTester t, String nombre, Size tam, {String? toque, bool seguir = true}) async {
    t.view.physicalSize = tam * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: ModosPantalla(onElegir: (_) {}, guardada: seguir ? guardada : null, onSeguir: () {}),
      ),
    );
    if (toque != null) {
      await t.tap(find.text(toque));
      await t.pumpAndSettle();
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre.png'));
  }

  testWidgets('menú teléfono', (t) => cap(t, 'menu-telefono', const Size(412, 915)));
  testWidgets('menú teléfono chico', (t) => cap(t, 'menu-telefono-chico', const Size(360, 640)));
  testWidgets('submenú desafíos', (t) => cap(t, 'menu-submenu-desafios', const Size(412, 915), toque: 'DESAFÍOS'));
  testWidgets('submenú amigos chico', (t) => cap(t, 'menu-submenu-amigos', const Size(360, 640), toque: 'CON AMIGOS'));
  testWidgets('menú tablet', (t) => cap(t, 'menu-tablet', const Size(1280, 800)));
  testWidgets('menú tablet desafíos', (t) => cap(t, 'menu-tablet-desafios', const Size(1280, 800), toque: 'DESAFÍOS'));
}
