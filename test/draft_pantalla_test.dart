import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

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
      expect(guardadas.last.oferta, isNotNull, reason: 'el reparto se guarda antes de revelarse');
      await tester.pump(); // la coreografía arranca en el cuadro siguiente
      await tester.pump(const Duration(seconds: 4)); // entrada, carga y giro de las 5
      expect(find.byType(CartaVertical), findsNWidgets(5));

      await tester.tap(find.byType(CartaVertical).at(1));
      await tester.pump();
      await tester.tap(find.textContaining('FICHAR A'));
      await tester.pump();
      expect(guardadas.last.plantel.jugadores.length, eleccion);
      expect(guardadas.last.oferta, isNull);
      await tester.pump(const Duration(seconds: 1)); // vuelo hasta el puesto
    }
    expect(find.text('ELEGIR TÁCTICAS'), findsOneWidget);
  });
}
