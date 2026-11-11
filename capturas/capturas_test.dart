// Capturas de pantalla con tipografías reales (no corre en CI).
// Uso: flutter test capturas --update-goldens  → capturas/salida/*.png
import 'dart:io';

import 'package:dinastia_nba/main.dart';
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

  Future<void> capturar(WidgetTester tester, String nombre, {Size tamano = const Size(412, 915)}) async {
    tester.view.physicalSize = tamano * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DinastiaNbaApp());
    for (final sigla in nombre.split('+').skip(1)) {
      final porTexto = find.text(sigla);
      if (porTexto.evaluate().isNotEmpty) {
        await tester.tap(porTexto.first);
      } else {
        final item = find.bySemanticsLabel(sigla);
        await tester.scrollUntilVisible(item, 120, scrollable: find.byType(Scrollable).last);
        await tester.tap(item);
      }
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(DinastiaNbaApp), matchesGoldenFile('salida/$nombre.png'));
  }

  testWidgets('inicio Bulls', (t) => capturar(t, 'inicio'));
  testWidgets('inicio Lakers', (t) => capturar(t, 'inicio+Oeste+Los Angeles Lakers'));
  testWidgets('inicio Celtics', (t) => capturar(t, 'inicio+Boston Celtics'));
  testWidgets('inicio Nets', (t) => capturar(t, 'inicio+Brooklyn Nets'));
  testWidgets('inicio Spurs', (t) => capturar(t, 'inicio+Oeste+San Antonio Spurs'));
  testWidgets(
    'inicio Blazers chico',
    (t) => capturar(t, 'inicio+Oeste+Portland Trail Blazers', tamano: const Size(360, 640)),
  );
}
