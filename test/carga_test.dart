import 'dart:async';

import 'package:dinastia_nba/presentation/widgets/carga.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nav = GlobalKey<NavigatorState>();
  Widget app() => MaterialApp(
    navigatorKey: nav,
    home: const Scaffold(body: Text('inicio')),
  );

  testWidgets('si la espera tarda, muestra "Cargando…" y lo saca al terminar', (t) async {
    await t.pumpWidget(app());
    final c = Completer<int>();
    final r = conCarga(nav.currentState!, c.future);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Cargando…'), findsNothing, reason: 'todavía no pasó la demora');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Cargando…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    c.complete(7);
    expect(await r, 7);
    await t.pumpAndSettle();
    expect(find.text('Cargando…'), findsNothing);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('si es rápido no parpadea ningún indicador', (t) async {
    await t.pumpWidget(app());
    final r = conCarga(nav.currentState!, Future.value('ok'));
    expect(await r, 'ok');
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Cargando…'), findsNothing);
  });

  testWidgets('si falla, también saca el indicador y propaga el error', (t) async {
    await t.pumpWidget(app());
    final c = Completer<int>();
    final r = conCarga(nav.currentState!, c.future);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Cargando…'), findsOneWidget);
    c.completeError(StateError('x'));
    await expectLater(r, throwsStateError);
    await t.pumpAndSettle();
    expect(find.text('Cargando…'), findsNothing);
  });
}
