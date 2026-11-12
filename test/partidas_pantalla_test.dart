import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/pantallas/partidas_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home) => MaterialApp(theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  testWidgets('sin base de datos avisa que no se puede guardar', (t) async {
    await t.pumpWidget(app(PartidasPantalla(db: null, onContinuar: (_) {})));
    await t.pump();
    expect(find.textContaining('no se pueden guardar partidas'), findsOneWidget);
  });

  testWidgets('lista las partidas, la más reciente primero, y tocar una la continúa', (t) async {
    final partidas = [
      const Temporada(id: 'b', franquiciaUsuarioId: 'BOS', dificultad: Dificultad.leyenda),
      const Temporada(id: 'a', franquiciaUsuarioId: 'CHI'),
    ];
    Temporada? elegida;
    await t.pumpWidget(app(PartidasPantalla(db: null, cargar: () async => partidas, onContinuar: (x) => elegida = x)));
    await t.pump();
    expect(find.text('Boston Celtics'), findsOneWidget);
    expect(find.text('Chicago Bulls'), findsOneWidget);
    expect(find.textContaining('Draft · Leyenda'), findsOneWidget);
    expect(t.getTopLeft(find.text('Boston Celtics')).dy, lessThan(t.getTopLeft(find.text('Chicago Bulls')).dy));
    await t.tap(find.text('Chicago Bulls'));
    expect(elegida?.id, 'a');
  });

  testWidgets('sin partidas muestra cómo empezar', (t) async {
    await t.pumpWidget(app(PartidasPantalla(db: null, cargar: () async => const [], onContinuar: (_) {})));
    await t.pump();
    expect(find.textContaining('Todavía no tenés partidas'), findsOneWidget);
  });
}
