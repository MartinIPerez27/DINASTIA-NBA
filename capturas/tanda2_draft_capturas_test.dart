// Tanda 2 (sobres, sorpresa, serpiente, entrenador, química) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/entrenador.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/playbook_pantalla.dart';
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
  Jugador carta(String id) => catalogo.firstWhere((j) => j.id == id);

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  void tel(WidgetTester t) {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Future<void> cuadros(WidgetTester t, int n) async {
    for (var k = 0; k < n; k++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  final dos = const Plantel()
      .asignar(carta('jordami01-CHI-90'), Posicion.escolta)
      .asignar(carta('pippesc01-CHI-90'), Posicion.alero);

  testWidgets('sobres y sorpresa', (t) async {
    tel(t);
    final draft = Draft(catalogo, azar: Random(4));
    final base = Temporada(id: 'c', franquiciaUsuarioId: 'CHI', modo: ModoDraft.cartas, plantel: dos);
    final conSobres = draft.repartir(base, Posicion.base);
    await t.pumpWidget(app(DraftPantalla(temporada: conSobres, onCambio: (_) {}, catalogo: catalogo)));
    await cuadros(t, 6);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-sobres.png'));

    // Abriendo: la tapa se rasga.
    await t.tap(find.bySemanticsLabel(RegExp('^SOBRE')).at(2));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 380));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-sobre-abriendo.png'));
    await cuadros(t, 20);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-cartas-sorpresa.png'));
  });

  testWidgets('serpiente: te ganaron de mano', (t) async {
    tel(t);
    final draft = Draft(catalogo, azar: Random(6));
    var s = Temporada(id: 's', franquiciaUsuarioId: 'CHI', modo: ModoDraft.cartas, regla: ReglaDraft.serpiente);
    s = s.copyWith(plantel: const Plantel().asignar(carta('jordami01-CHI-90'), Posicion.escolta));
    final abierto = draft.abrirSobre(draft.repartir(s, Posicion.pivot), 2);
    await t.pumpWidget(app(DraftPantalla(temporada: abierto, onCambio: (_) {}, catalogo: catalogo)));
    await cuadros(t, 3);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-serpiente.png'));
  });

  testWidgets('plantel completo: química y entrenador', (t) async {
    tel(t);
    var p = dos
        .asignar(carta('rodmade01-CHI-90'), Posicion.alaPivot)
        .asignar(carta('harpero01-CHI-90'), Posicion.base)
        .asignar(carta('longllu01-CHI-90'), Posicion.pivot)
        .asignar(carta('kukocto01-CHI-90'), Posicion.sextoHombre);
    final completa = Temporada(id: 'k', franquiciaUsuarioId: 'CHI', plantel: p);
    await t.pumpWidget(app(DraftPantalla(temporada: completa, onCambio: (_) {}, catalogo: catalogo)));
    await cuadros(t, 4);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-completo.png'));
    await t.tap(find.text('ELEGIR ENTRENADOR'));
    await cuadros(t, 4);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-entrenadores.png'));
    await t.tapAt(const Offset(200, 40));
    await cuadros(t, 4);
    await t.tap(find.text('QUÍMICA'));
    await cuadros(t, 4);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-quimica.png'));

    final conDt = completa.copyWith(entrenadorId: Entrenador.todos.first.id);
    await t.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PlaybookPantalla(temporada: conDt, onConfirmar: (_) {}),
      ),
    );
    await cuadros(t, 3);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t2-playbook.png'));
  });
}
