// Cuadros del modo cartas con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:dinastia_nba/presentation/widgets/elegir_modo.dart';
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

  Future<void> foto(WidgetTester t, String nombre) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre.png'));
  }

  testWidgets('cartas: secuencia', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: DraftPantalla(
          temporada: const Temporada(id: 't', franquiciaUsuarioId: 'LAL', modo: ModoDraft.cartas),
          onCambio: (_) {},
          catalogo: catalogo,
          azar: Random(11),
        ),
      ),
    );
    await foto(t, 'cartas-0-cancha');
    await t.tap(find.bySemanticsLabel(RegExp('^PÍVOT, vacío')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16)); // arranca la coreografía
    for (final (ms, nombre) in [(450, '1-entrada'), (1300, '2-carga'), (500, '2b-giro'), (1700, '3-reveladas')]) {
      await t.pump(Duration(milliseconds: ms));
      await foto(t, 'cartas-$nombre');
    }
    await t.tap(find.byType(CartaVertical).at(2));
    await t.pump(const Duration(milliseconds: 300));
    await foto(t, 'cartas-4-elegida');
    await t.tap(find.textContaining('FICHAR A'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 260));
    await foto(t, 'cartas-5-vuelo');
    await t.pump(const Duration(seconds: 1));
    await foto(t, 'cartas-6-fichado');
  });

  testWidgets('hoja de modo', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => elegirModoDraft(c), child: const Text('abrir')),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await foto(t, 'cartas-modo');
  });
}
