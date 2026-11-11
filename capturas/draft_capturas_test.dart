// Capturas del draft con tipografías reales (no corre en CI).
// Uso: flutter test capturas --update-goldens  → capturas/salida/*.png
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_jugador.dart';
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

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
  });

  /// [elecciones] cartas ubicadas; luego, si [tirarAlFinal], una tirada más con la primera carta elegida.
  Future<void> capturar(
    WidgetTester tester,
    String nombre,
    String equipo,
    int elecciones, {
    bool tirarAlFinal = true,
    Size tamano = const Size(412, 915),
  }) async {
    tester.view.physicalSize = tamano * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId(equipo)),
        home: DraftPantalla(
          temporada: Temporada(id: 't', franquiciaUsuarioId: equipo),
          onCambio: (_) {},
          catalogo: catalogo,
          azar: Random(7),
        ),
      ),
    );
    for (var i = 0; i < elecciones; i++) {
      await tester.tap(find.text('TIRAR'));
      await tester.pump(); // el giro arranca en el cuadro siguiente al toque
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(CartaJugador).first);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp('disponible')).first);
      await tester.pump(const Duration(seconds: 1));
    }
    if (tirarAlFinal && elecciones < 6) {
      await tester.tap(find.text('TIRAR'));
      await tester.pump(); // el giro arranca en el cuadro siguiente al toque
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(CartaJugador).first);
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(DraftPantalla), matchesGoldenFile('salida/$nombre.png'));
  }

  testWidgets('draft vacío', (t) => capturar(t, 'draft-vacio', 'CHI', 0, tirarAlFinal: false));
  testWidgets('draft tirada', (t) => capturar(t, 'draft-tirada', 'CHI', 0));
  testWidgets('draft a mitad', (t) => capturar(t, 'draft-mitad', 'BOS', 3));
  testWidgets('draft completo', (t) => capturar(t, 'draft-completo', 'LAL', 6));
  testWidgets('ficha jugador', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(child: CartaJugador(jugador: catalogo.first)),
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(CartaJugador));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/ficha.png'));
  });
  testWidgets('draft chico', (t) => capturar(t, 'draft-chico', 'GSW', 2, tamano: const Size(360, 640)));
}
