import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/draft/entrenadores.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

/// Varios cuadros seguidos: las animaciones arrancan a contar en su primer cuadro.
Future<void> animar(WidgetTester t, {int cuadros = 8}) async {
  for (var k = 0; k < cuadros; k++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  testWidgets('draft completo: tirar, elegir carta, tocar puesto, hasta llenar los 6', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final guardadas = <Temporada>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: DraftPantalla(
          temporada: const Temporada(id: 't', franquiciaUsuarioId: 'CHI'),
          onCambio: guardadas.add,
          catalogo: catalogo,
          azar: Random(82),
        ),
      ),
    );

    for (var eleccion = 1; eleccion <= 6; eleccion++) {
      await tester.tap(find.text('TIRAR'));
      expect(guardadas.last.tirada, isNotNull, reason: 'la tirada se guarda antes de terminar de girar');
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.byType(CartaVertical).first);
      await tester.pump();
      final libre = find.bySemanticsLabel(RegExp('disponible'));
      expect(libre, findsWidgets);
      await tester.tap(libre.first);
      await tester.pump(const Duration(seconds: 1));

      expect(guardadas.last.plantel.jugadores.length, eleccion);
      expect(guardadas.last.tirada, isNull);
    }

    expect(guardadas.last.plantel.completo, isTrue);
    expect(guardadas.last.rerollsRestantes, 3, reason: 'no se usó ninguna ficha');
    expect(find.text('QUÍMICA'), findsOneWidget, reason: 'medidor de química visible');

    // 7.º puesto: el entrenador, antes de las tácticas.
    expect(find.text('ELEGIR TÁCTICAS'), findsNothing);
    expect(find.text('SEGUIR SIN ENTRENADOR'), findsOneWidget);
    await tester.tap(find.text('ELEGIR ENTRENADOR'));
    await tester.pumpAndSettle();
    expect(find.text('7.º PUESTO: TU ENTRENADOR'), findsOneWidget);
    await tester.tap(find.byType(CartaEntrenador).first);
    await tester.pumpAndSettle();
    expect(guardadas.last.entrenadorId, isNotNull);
    expect(find.text('ELEGIR TÁCTICAS'), findsOneWidget);
  });

  testWidgets('volver a tirar gasta una ficha y respeta el carrete retenido', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final guardadas = <Temporada>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: DraftPantalla(
          temporada: const Temporada(id: 't', franquiciaUsuarioId: 'LAL'),
          onCambio: guardadas.add,
          catalogo: catalogo,
          azar: Random(1),
        ),
      ),
    );
    await tester.tap(find.text('TIRAR'));
    await tester.pump(const Duration(seconds: 2));
    final primera = guardadas.last.tirada!;

    await tester.tap(find.text('RETENER').first); // carrete de franquicia
    await tester.pump();
    await tester.tap(find.text('VOLVER A TIRAR · 1 FICHA'));
    await tester.pump(const Duration(seconds: 2));

    expect(guardadas.last.rerollsRestantes, 2);
    expect(guardadas.last.tirada!.franquiciaId, primera.franquiciaId);
  });

  testWidgets('modo cartas: tocar puesto, revelar 5, fichar y volar, hasta llenar los 6', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final guardadas = <Temporada>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('BOS')),
        home: DraftPantalla(
          temporada: const Temporada(id: 't', franquiciaUsuarioId: 'BOS', modo: ModoDraft.cartas),
          onCambio: guardadas.add,
          catalogo: catalogo,
          azar: Random(5),
        ),
      ),
    );
    expect(find.text('TIRAR'), findsNothing, reason: 'sin tragamonedas en el modo cartas');

    for (var eleccion = 1; eleccion <= 6; eleccion++) {
      await tester.tap(find.bySemanticsLabel(RegExp('disponible')).first);
      await tester.pump();
      expect(guardadas.last.oferta?.sinAbrir, isTrue, reason: 'primero se eligen los sobres');
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('ELEGÍ UN SOBRE'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.bySemanticsLabel(RegExp('^SOBRE')).at(eleccion % 3));
      for (var k = 0; k < 4; k++) {
        await tester.pump(const Duration(milliseconds: 300)); // se rasga la tapa
      }
      expect(guardadas.last.oferta!.cartaIds, hasLength(5), reason: 'el sobre abierto se guarda');
      await animar(tester, cuadros: 14); // entrada, carga y giro
      if (guardadas.last.oferta!.sorpresaId != null) {
        expect(find.byType(CartaVertical), findsNWidgets(4), reason: 'la sorpresa sigue boca abajo');
        await tester.tap(find.bySemanticsLabel(RegExp('Carta sorpresa')));
        await animar(tester);
      }
      expect(find.byType(CartaVertical), findsNWidgets(5));

      await tester.tap(find.byType(CartaVertical).at(1));
      await tester.pump();
      await tester.tap(find.textContaining('FICHAR A'));
      await tester.pump();
      expect(guardadas.last.plantel.jugadores.length, eleccion);
      expect(guardadas.last.oferta, isNull);
      await tester.pump(const Duration(seconds: 1)); // vuelo hasta el puesto
    }
    var completo = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('BOS')),
        home: DraftPantalla(
          temporada: guardadas.last,
          onCambio: guardadas.add,
          onCompleto: () => completo = true,
          catalogo: catalogo,
        ),
      ),
    );
    await tester.tap(find.text('SEGUIR SIN ENTRENADOR'));
    expect(completo, isTrue);
  });

  Future<List<Temporada>> abrirConRegla(WidgetTester tester, ReglaDraft regla, {int rondas = 1}) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final guardadas = <Temporada>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('NYK')),
        home: DraftPantalla(
          temporada: Temporada(id: 't', franquiciaUsuarioId: 'NYK', modo: ModoDraft.cartas, regla: regla),
          onCambio: guardadas.add,
          catalogo: catalogo,
          azar: Random(9),
        ),
      ),
    );
    return guardadas;
  }

  testWidgets('a ciegas: las 5 boca abajo, se ficha sin verlas', (tester) async {
    final guardadas = await abrirConRegla(tester, ReglaDraft.aCiegas);
    await tester.tap(find.bySemanticsLabel(RegExp('disponible')).first);
    await animar(tester, cuadros: 4);
    await tester.tap(find.bySemanticsLabel(RegExp('^SOBRE')).first);
    await animar(tester, cuadros: 18);
    expect(find.byType(CartaVertical), findsNothing);
    await tester.tap(find.bySemanticsLabel('Carta boca abajo').first);
    await tester.pump();
    await tester.tap(find.text('FICHAR A CIEGAS'));
    await tester.pump(const Duration(seconds: 1));
    expect(guardadas.last.plantel.jugadores, hasLength(1));
  });

  testWidgets('serpiente: en la 2.ª ronda se ve qué se llevaron los rivales', (tester) async {
    final guardadas = await abrirConRegla(tester, ReglaDraft.serpiente);
    for (var ronda = 1; ronda <= 2; ronda++) {
      await tester.tap(find.bySemanticsLabel(RegExp('disponible')).first);
      await animar(tester, cuadros: 4);
      if (ronda == 2) expect(find.textContaining('los rivales eligen antes'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^SOBRE')).first);
      await animar(tester, cuadros: 4);
      if (ronda == 2) {
        expect(find.text('TE GANARON DE MANO'), findsOneWidget);
        expect(find.textContaining('Se la llevaron los'), findsNWidgets(2));
        await tester.tap(find.text('VER LO QUE QUEDA'));
      }
      await animar(tester, cuadros: 14);
      if (guardadas.last.oferta!.sorpresaId != null) {
        await tester.tap(find.bySemanticsLabel(RegExp('Carta sorpresa')));
        await animar(tester);
      }
      await tester.tap(find.byType(CartaVertical).first);
      await tester.pump();
      await tester.tap(find.textContaining('FICHAR A'));
      await animar(tester, cuadros: 4); // vuelo hasta el puesto
    }
    expect(guardadas.last.plantel.jugadores, hasLength(2));
    expect(guardadas.last.robos.values.expand((l) => l), hasLength(2));
  });
}
