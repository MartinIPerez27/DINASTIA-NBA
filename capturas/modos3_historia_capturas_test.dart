// Modos de historia (Momentos clutch y objetivo de Temporada real) con tipografías reales (no corre en CI).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/historia.dart';
import 'package:dinastia_nba/presentation/modos/historia.dart';
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
  final h = HistoriaNba(
    liga,
    huecos: HistoriaNba.leerHuecos(
      jsonDecode(File('assets/database/temporadas_huecos.json').readAsStringSync()) as Map<String, dynamic>,
    ),
  );
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  testWidgets('momentos clutch, teléfono', (t) async {
    t.view.physicalSize = const Size(412, 1500) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final partida = HistoriaNba.conSuperado(HistoriaNba.partidaMomentos('CHI'), 'jordan98');
    await t.pumpWidget(app(MomentosClutchPantalla(temporada: partida, historia: h, onCambio: (_) {})));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-historia-clutch.png'));
  });

  testWidgets('momentos clutch, tablet', (t) async {
    t.view.physicalSize = const Size(1340, 900) * 1.8;
    t.view.devicePixelRatio = 1.8;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      app(MomentosClutchPantalla(temporada: HistoriaNba.partidaMomentos('CHI'), historia: h, onCambio: (_) {})),
    );
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-historia-clutch-tablet.png'));
  });

  testWidgets('objetivo de la temporada real', (t) async {
    t.view.physicalSize = const Size(412, 800) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final q = historiasAlternativas.first;
    final partida = h.nuevaTemporada(id: 'q', franquiciaId: q.franquiciaId, anio: q.anio, historia: q);
    await t.pumpWidget(
      app(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: FilledButton(onPressed: () => mostrarObjetivo(c, partida), child: const Text('x')),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('x'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-historia-objetivo.png'));
  });
}
