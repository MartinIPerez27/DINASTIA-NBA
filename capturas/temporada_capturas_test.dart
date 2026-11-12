// Temporada y partido en vivo con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/presentation/pantallas/partido_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/temporada_pantalla.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(7));
  late Temporada temporada;
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    temporada = liga.iniciar(Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    for (var i = 0; i < 12; i++) {
      temporada = liga.simularProximo(temporada);
    }
  });

  void tel(WidgetTester t) {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  testWidgets('hub', (t) async {
    tel(t);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: TemporadaPantalla(temporada: temporada, liga: liga, onCambio: (_) {}),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/temporada-hub.png'));
    await t.tap(find.text('Posiciones'));
    await t.pumpAndSettle();
    await t.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/temporada-tabla.png'));
  });

  testWidgets('vivo', (t) async {
    tel(t);
    final p = liga.proximoDelUsuario(temporada)!;
    final antes = liga.simularOtrosHasta(temporada, p.jornada);
    final motor = liga.motor(antes, p, azar: Random(3));
    String id(String f) => f == 'CHI' ? 'CHI' : antes.rivales[f]!.identidadId;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PartidoPantalla(
          motor: motor,
          usuarioLocal: p.localId == 'CHI',
          franquiciaUsuario: franquiciaPorId('CHI'),
          identidadLocal: franquiciaPorId(id(p.localId)),
          identidadVisitante: franquiciaPorId(id(p.visitanteId)),
          onTerminado: (_) {},
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    for (final (i, ms) in [(1, 250), (2, 250), (3, 250)]) {
      await t.pump(Duration(milliseconds: ms));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/vivo-$i.png'));
    }
  });
}
