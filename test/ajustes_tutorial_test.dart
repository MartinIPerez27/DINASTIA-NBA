import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/presentation/pantallas/ajustes_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/tutorial_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home) => MaterialApp(theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  testWidgets('ajustes: cada cambio avisa el valor nuevo', (t) async {
    ajustesApp.value = const Ajustes();
    final cambios = <Ajustes>[];
    await t.pumpWidget(app(AjustesPantalla(onCambio: cambios.add, onTutorial: () {})));
    await t.tap(find.text('Sonido'));
    await t.pump();
    expect(cambios.last.sonido, isFalse);
    await t.tap(find.text('x4'));
    await t.pump();
    expect(cambios.last.velocidad, 4);
    expect(cambios.last.sonido, isFalse, reason: 'no pisa el cambio anterior');
  });

  testWidgets('ajustes: "Ver el tutorial" llama a onTutorial', (t) async {
    var abierto = false;
    await t.pumpWidget(app(AjustesPantalla(onCambio: (_) {}, onTutorial: () => abierto = true)));
    await t.scrollUntilVisible(find.text('Ver el tutorial'), 100);
    await t.tap(find.text('Ver el tutorial'));
    expect(abierto, isTrue);
  });

  testWidgets('tutorial: avanza página a página y Empezar termina', (t) async {
    var terminado = false;
    await t.pumpWidget(app(TutorialPantalla(onTerminar: () => terminado = true)));
    expect(find.text('ELEGÍ TU FRANQUICIA'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await t.tap(find.text('SIGUIENTE'));
      await t.pumpAndSettle();
    }
    expect(find.text('TU CARRERA'), findsOneWidget);
    expect(terminado, isFalse);
    await t.tap(find.text('EMPEZAR'));
    expect(terminado, isTrue);
  });

  testWidgets('tutorial: Saltar termina enseguida', (t) async {
    var terminado = false;
    await t.pumpWidget(app(TutorialPantalla(onTerminar: () => terminado = true)));
    await t.tap(find.text('Saltar'));
    expect(terminado, isTrue);
  });

  for (final escala in [1.0, 1.5, 2.0]) {
    for (final tam in [const Size(360, 640), const Size(412, 915)]) {
      testWidgets('tutorial: sin desbordes a ${tam.width.toInt()}×${tam.height.toInt()} con texto ×$escala', (t) async {
        t.view.physicalSize = tam * 2;
        t.view.devicePixelRatio = 2;
        t.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(() {
          t.view.reset();
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await t.pumpWidget(app(TutorialPantalla(onTerminar: () {})));
        for (var i = 0; i < 6; i++) {
          expect(t.takeException(), isNull, reason: 'página ${i + 1}');
          await t.tap(find.text('SIGUIENTE'));
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull, reason: 'última página');
        expect(find.text('EMPEZAR'), findsOneWidget);
      });
    }
  }

  testWidgets('tutorial: cuenta los modos, las fichas y el álbum', (t) async {
    await t.pumpWidget(app(TutorialPantalla(onTerminar: () {})));
    final textos = <String>[];
    for (var i = 0; i < 7; i++) {
      textos.addAll(t.widgetList<Text>(find.byType(Text)).map((x) => x.data ?? ''));
      if (i < 6) {
        await t.tap(find.text('SIGUIENTE'));
        await t.pumpAndSettle();
      }
    }
    final todo = textos.join(' ');
    expect(todo, contains('Modos de juego'));
    expect(todo, contains('tokens'));
    expect(todo, contains('Álbum'));
  });
}
