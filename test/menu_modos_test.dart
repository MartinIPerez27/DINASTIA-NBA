import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/modos/menu_modos.dart';
import 'package:dinastia_nba/presentation/modos/modos.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ajustesApp.value = const Ajustes(tutorialVisto: true));

  Widget app(Widget home) => MaterialApp(theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  void tamano(WidgetTester t, Size s, {double escala = 1}) {
    t.view.physicalSize = s * 2;
    t.view.devicePixelRatio = 2;
    t.platformDispatcher.textScaleFactorTestValue = escala;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  test('los 34 modos están en el menú, cada uno en una sola categoría', () {
    final todos = [for (final c in categoriasModos) ...c.modos];
    expect(ModoJuego.values, hasLength(34));
    expect(todos.toSet(), ModoJuego.values.toSet(), reason: 'no falta ni sobra ningún modo');
    expect(todos, hasLength(ModoJuego.values.length), reason: 'ninguno repetido');
    for (final m in ModoJuego.values) {
      expect(etiquetasModo(m), isNotEmpty, reason: '${m.name} tiene etiqueta de duración');
    }
  });

  test('primer nivel: Temporada 82-0 primero y Carrera segundo, 6 tarjetas en total', () {
    expect(categoriasModos.map((c) => c.titulo), [
      'Temporada 82-0',
      'Carrera',
      'Desafíos',
      'Historia y torneos',
      'Con amigos',
      'Minijuegos',
    ]);
  });

  for (final tam in [const Size(412, 915), const Size(360, 640)]) {
    testWidgets('cada modo se alcanza en 2 toques como mucho (${tam.width.toInt()}×${tam.height.toInt()})', (t) async {
      tamano(t, tam);
      for (final m in ModoJuego.values) {
        ModoJuego? elegido;
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(app(ModosPantalla(onElegir: (x) => elegido = x)));
        var toques = 0;
        final cat = categoriasModos.firstWhere((c) => c.modos.contains(m));
        if (cat.directa == null) {
          final tc = find.text(cat.titulo.toUpperCase());
          await t.scrollUntilVisible(tc, 100, scrollable: find.byType(Scrollable).last);
          await t.ensureVisible(tc);
          await t.pumpAndSettle();
          await t.tap(tc);
          toques++;
          await t.pumpAndSettle();
        }
        final tarjeta = find.text(cat.directa == null ? m.nombre : cat.titulo.toUpperCase());
        await t.scrollUntilVisible(tarjeta, 200, scrollable: find.byType(Scrollable).last);
        await t.ensureVisible(tarjeta.first);
        await t.pumpAndSettle();
        await t.tap(tarjeta.first);
        toques++;
        expect(elegido, m, reason: m.name);
        expect(toques, lessThanOrEqualTo(2), reason: m.name);
        expect(t.takeException(), isNull, reason: 'sin desbordes en ${m.name}');
      }
    });
  }

  testWidgets('tarjetas del primer nivel: ícono, nombre y una línea de descripción', (t) async {
    tamano(t, const Size(412, 915));
    await t.pumpWidget(app(ModosPantalla(onElegir: (_) {})));
    for (final c in categoriasModos) {
      expect(find.text(c.titulo.toUpperCase()), findsOneWidget);
      expect(find.text(c.descripcion), findsOneWidget);
      expect(find.byIcon(c.icono), findsWidgets);
    }
    expect(find.text('SEGUIR JUGANDO'), findsNothing, reason: 'sin partida guardada no hay tarjeta');
  });

  testWidgets('el submenú muestra descripción y etiqueta de duración', (t) async {
    tamano(t, const Size(412, 915));
    await t.pumpWidget(app(ModosPantalla(onElegir: (_) {})));
    await t.tap(find.text('CON AMIGOS'));
    await t.pumpAndSettle();
    expect(find.text(ModoJuego.duelo.descripcion), findsOneWidget);
    expect(find.text('MISMO DISPOSITIVO'), findsWidgets);
    expect(find.text('CORTO'), findsWidgets);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('¿A qué jugamos?'), findsOneWidget);
  });

  testWidgets('"Seguir jugando" va primero, muestra la última partida y la abre', (t) async {
    tamano(t, const Size(412, 915));
    var seguido = false;
    const guardada = Temporada(id: 'x', franquiciaUsuarioId: 'BOS', modoJuego: ModoJuego.racha);
    await t.pumpWidget(app(ModosPantalla(onElegir: (_) {}, guardada: guardada, onSeguir: () => seguido = true)));
    expect(find.text('SEGUIR JUGANDO'), findsOneWidget);
    expect(find.textContaining('Racha infinita'), findsOneWidget);
    expect(find.textContaining('Celtics'), findsOneWidget);
    expect(find.text('Armando el plantel'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('SEGUIR JUGANDO')).dy,
      lessThan(t.getTopLeft(find.text('TEMPORADA 82-0')).dy),
      reason: 'es la primera tarjeta',
    );
    await t.tap(find.text('SEGUIR JUGANDO'));
    expect(seguido, isTrue);
  });

  testWidgets('"Seguir jugando" de la temporada clásica muestra el récord', (t) async {
    tamano(t, const Size(412, 915));
    // El resumen sin calendario no inventa un récord.
    const sinJugar = Temporada(id: 'x', franquiciaUsuarioId: 'CHI');
    expect(resumenPartida(sinJugar).record, isNull);
  });

  testWidgets('con letra ×2,0 en un teléfono chico no hay desbordes', (t) async {
    tamano(t, const Size(360, 640), escala: 2);
    await t.pumpWidget(
      app(
        ModosPantalla(
          onElegir: (_) {},
          guardada: const Temporada(id: 'x', franquiciaUsuarioId: 'POR', modoJuego: ModoJuego.reescribi),
          onSeguir: () {},
        ),
      ),
    );
    expect(t.takeException(), isNull);
    for (final c in categoriasModos.where((c) => c.directa == null)) {
      final tc = find.text(c.titulo.toUpperCase());
      await t.scrollUntilVisible(tc, 100, scrollable: find.byType(Scrollable).last);
      await t.ensureVisible(tc);
      await t.pumpAndSettle();
      await t.tap(tc);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: c.titulo);
      await t.pageBack();
      await t.pumpAndSettle();
    }
  });

  testWidgets('tablet apaisada: dos paneles, categorías a la izquierda y modos a la derecha', (t) async {
    tamano(t, const Size(1280, 800));
    ModoJuego? elegido;
    await t.pumpWidget(app(ModosPantalla(onElegir: (x) => elegido = x)));
    expect(t.takeException(), isNull);
    // Abre en Carrera: sus modos ya están a la vista sin navegar.
    expect(find.text('Mi carrera'), findsOneWidget);
    await t.tap(find.text('MINIJUEGOS'));
    await t.pumpAndSettle();
    expect(find.text('Perfil perfecto'), findsOneWidget);
    expect(find.text('Mi carrera'), findsNothing);
    await t.tap(find.text('Adiviná la carta'));
    expect(elegido, ModoJuego.adivina);
    await t.tap(find.text('TEMPORADA 82-0'));
    expect(elegido, ModoJuego.clasico);
  });
}
