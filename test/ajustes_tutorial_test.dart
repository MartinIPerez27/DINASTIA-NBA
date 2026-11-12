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
    for (var i = 0; i < 4; i++) {
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
}
