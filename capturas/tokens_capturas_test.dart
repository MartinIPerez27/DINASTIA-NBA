// Capturas de la bandeja de tokens del draft (no corre en CI).
// Uso: flutter test capturas/tokens_capturas_test.dart --update-goldens → capturas/salida/tokens-*.png
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/tirada.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
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

  /// Draft a mitad: 2 cartas ubicadas y una tirada con una carta que tiene una versión mejor.
  Temporada escena() {
    final d = Draft(catalogo, azar: Random(4));
    for (final j in catalogo) {
      var t = Temporada(id: 't', franquiciaUsuarioId: 'MIA', rerollsRestantes: 0, tirada: Tirada.de(j));
      if (d.mejorVersionDe(t, j) == null || d.candidatos(t).length < 4) continue;
      // Dos cartas ya elegidas de otras tiradas.
      for (final seed in [1, 2]) {
        final r = Draft(catalogo, azar: Random(seed)).tirar(Temporada(id: 'x', franquiciaUsuarioId: 'MIA'));
        final c = Draft(catalogo).candidatos(r).where((x) => x.nbaPlayerId != j.nbaPlayerId).first;
        final p = t.plantel.posicionesDisponiblesPara(c);
        if (p.isNotEmpty) t = t.copyWith(plantel: t.plantel.asignar(c, p.first));
      }
      return t;
    }
    throw StateError('sin escena');
  }

  Future<void> abrir(WidgetTester tester, Size tamano, {int monedas = 460}) async {
    tester.view.physicalSize = tamano * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    perfilApp.value = PerfilEntrenador(monedas: monedas);
    addTearDown(() => perfilApp.value = const PerfilEntrenador());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('MIA')),
        home: DraftPantalla(temporada: escena(), onCambio: (_) {}, catalogo: catalogo, azar: Random(7)),
      ),
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> foto(String nombre) => expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre.png'));

  testWidgets('bandeja en teléfono', (t) async {
    await abrir(t, const Size(412, 915));
    await foto('tokens-telefono');
  });

  testWidgets('bandeja en teléfono chico y pocas monedas', (t) async {
    await abrir(t, const Size(360, 700), monedas: 60);
    await foto('tokens-telefono-chico');
  });

  testWidgets('hoja de mejor versión', (t) async {
    await abrir(t, const Size(412, 915));
    final d = Draft(catalogo);
    final tem = escena();
    final j = d.candidatos(tem).firstWhere((x) => d.mejorVersionDe(tem, x) != null);
    final carta = find.byWidgetPredicate((w) => w is CartaVertical && w.jugador == j);
    await t.ensureVisible(carta);
    await t.tap(carta);
    await t.pump();
    await t.tap(find.text('VERSIÓN'));
    await t.pumpAndSettle();
    await foto('tokens-hoja-version');
  });

  testWidgets('hoja de comodín', (t) async {
    await abrir(t, const Size(412, 915));
    await t.tap(find.text('COMODÍN'));
    await t.pumpAndSettle();
    await foto('tokens-hoja-comodin');
  });

  testWidgets('hoja de intercambio', (t) async {
    await abrir(t, const Size(412, 915), monedas: 800);
    await t.tap(find.text('CAMBIO'));
    await t.pumpAndSettle();
    await foto('tokens-hoja-intercambio');
  });

  testWidgets('bandeja en tablet', (t) async {
    await abrir(t, const Size(1340, 900) / 1.0);
    await foto('tokens-tablet');
  });
}
