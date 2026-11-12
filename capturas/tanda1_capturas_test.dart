// Tanda 1 (perfil, partidas, ajustes, tutorial) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/main.dart';
import 'package:dinastia_nba/presentation/pantallas/ajustes_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/partidas_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/perfil_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/tutorial_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  late Temporada fin;
  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    ajustesApp.value = const Ajustes(tutorialVisto: true);
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'LAL').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    final inicio = liga.iniciar(Temporada(id: 'c', franquiciaUsuarioId: 'LAL', plantel: p, tacticaConfirmada: true));
    var t = inicio;
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
    }
    final regular = liga.simularOtrosHasta(t, 1 << 30);
    fin = liga.simularRestoPlayoffs(regular);
    final progreso = Progreso(liga);
    var (perfil, _) = progreso.aplicar(const PerfilEntrenador(), inicio, regular);
    (perfil, _) = progreso.aplicar(perfil, regular, fin);
    perfilApp.value = perfil;
  });

  void tel(WidgetTester t) {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('LAL')), home: home);

  Future<void> foto(WidgetTester t, String nombre) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t1-$nombre.png'));
  }

  testWidgets('inicio', (t) async {
    tel(t);
    await t.pumpWidget(const DinastiaNbaApp());
    await foto(t, 'inicio');
  });

  testWidgets('perfil', (t) async {
    tel(t);
    await t.pumpWidget(app(PerfilPantalla(jugador: liga.jugador)));
    await foto(t, 'perfil-resumen');
    for (final pestana in ['Vitrina', 'Logros', 'Salón de la Fama']) {
      await t.tap(find.text(pestana));
      await foto(t, 'perfil-$pestana');
    }
  });

  testWidgets('partidas, ajustes y tutorial', (t) async {
    tel(t);
    final otra = Temporada(id: 'x', franquiciaUsuarioId: 'BOS', dificultad: Dificultad.leyenda);
    await t.pumpWidget(app(PartidasPantalla(db: null, onContinuar: (_) {}, cargar: () async => [fin, otra])));
    await foto(t, 'partidas');
    await t.pumpWidget(app(AjustesPantalla(onCambio: (_) {}, onTutorial: () {})));
    await foto(t, 'ajustes');
    await t.pumpWidget(app(TutorialPantalla(onTerminar: () {})));
    await foto(t, 'tutorial');
  });
}
