// Tanda 2 (álbum, tienda, reglas) con tipografías reales (no corre en CI).
import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/presentation/pantallas/album_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
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
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    final mias = catalogo.where((j) => j.franquiciaId == 'BOS' || j.franquiciaId == 'CHI').take(40).map((j) => j.id);
    perfilApp.value = PerfilEntrenador(monedas: 620, coleccion: {...mias});
  });

  void tel(WidgetTester t) {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('BOS')), home: home);

  testWidgets('álbum y tienda', (t) async {
    tel(t);
    await t.pumpWidget(app(AlbumPantalla(catalogo: catalogo, onPerfil: (p) => perfilApp.value = p)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-album.png'));
    await t.tap(find.text('Tienda'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-tienda.png'));
    await t.tap(find.text('150'));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-apertura.png'));
  });

  testWidgets('reglas', (t) async {
    tel(t);
    await t.pumpWidget(
      app(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => elegirRegla(c, modo: ModoDraft.cartas, coleccionAlcanza: Future.value(false)),
                child: const Text('ABRIR'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ABRIR'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-reglas.png'));
  });
}
