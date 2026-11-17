// Capturas del álbum por jugador (versiones) y de una tirada con una sola carta por persona (no corre en CI).
// Uso: flutter test capturas/una_carta_capturas_test.dart --update-goldens → capturas/salida/una-carta-*.png
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/tirada.dart';
import 'package:dinastia_nba/presentation/pantallas/album_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
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

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  void pantalla(WidgetTester t, Size s) {
    t.view.physicalSize = s * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    addTearDown(() => perfilApp.value = const PerfilEntrenador());
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  Set<String> coleccion() {
    final ids = <String>{};
    for (final bbref in ['jordami01', 'curryst01', 'jamesle01', 'porzikr01']) {
      ids.addAll(catalogo.where((j) => j.idBbref == bbref).take(3).map((j) => j.id));
    }
    final resto = catalogo.where((j) => j.franquiciaId == 'CHI').take(14).map((j) => j.id);
    return {...ids, ...resto};
  }

  testWidgets('álbum con versiones: teléfono, selector y tablet', (t) async {
    perfilApp.value = PerfilEntrenador(monedas: 300, coleccion: coleccion());
    pantalla(t, const Size(412, 915));
    await t.pumpWidget(app(AlbumPantalla(catalogo: catalogo, onPerfil: (p) => perfilApp.value = p)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/una-carta-album-telefono.png'));
    await t.tap(find.byKey(ValueKey('versiones-${catalogo.firstWhere((j) => j.idBbref == 'jordami01').personaId}')));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/una-carta-album-selector.png'));
    pantalla(t, const Size(1180, 820));
    await t.pumpWidget(app(AlbumPantalla(catalogo: catalogo, onPerfil: (p) => perfilApp.value = p)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/una-carta-album-tablet.png'));
  });

  testWidgets('tirada: Bulls de los 90, una sola carta de Jordan', (t) async {
    perfilApp.value = const PerfilEntrenador(monedas: 300);
    pantalla(t, const Size(412, 915));
    final tirada = Temporada(
      id: 't',
      franquiciaUsuarioId: 'CHI',
      rerollsRestantes: 0,
      tirada: const Tirada(franquiciaId: 'CHI', epoca: Epoca.anios90, tier: Tier.sPlus),
    );
    await t.pumpWidget(app(DraftPantalla(temporada: tirada, onCambio: (_) {}, catalogo: catalogo, azar: Random(7))));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await t.pump(const Duration(seconds: 1));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/una-carta-tirada.png'));
  });
}
