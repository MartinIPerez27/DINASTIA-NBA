// Tanda 4a (clima de temporada y premios) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/presentation/pantallas/stats82_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/temporada/clima_temporada.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(14));
  late Temporada mitad, fin;
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    var t = liga.iniciar(Temporada(id: 'c4', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    for (var i = 0; i < 46; i++) {
      t = liga.simularProximo(t);
    }
    mitad = liga.simularOtrosHasta(t, liga.proximoDelUsuario(t)!.jornada - 1);
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
    }
    fin = liga.simularOtrosHasta(t, 1 << 30);
  });

  void tel(WidgetTester t) {
    t.view.physicalSize = const Size(412, 1400) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  testWidgets('clima a mitad de temporada', (t) async {
    tel(t);
    await t.pumpWidget(
      app(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TitularesSemana(temporada: mitad, liga: liga),
              const SizedBox(height: 12),
              RecordsEnJuego(temporada: mitad, liga: liga),
              const SizedBox(height: 12),
              CarreraMvp(temporada: mitad, liga: liga),
              const SizedBox(height: 12),
              TarjetaAllStar(temporada: mitad, liga: liga),
            ],
          ),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4-clima.png'));
    await t.tap(find.text('VER PLANTELES'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4-allstar.png'));
  });

  testWidgets('premios en STATS 82', (t) async {
    tel(t);
    await t.pumpWidget(app(Stats82Pantalla(temporada: fin, liga: liga)));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4-premios.png'));
  });
}
