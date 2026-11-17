import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/tirada.dart';
import 'package:dinastia_nba/domain/tokens_draft.dart';
import 'package:dinastia_nba/presentation/draft/bandeja_tokens.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  /// Una carta con una versión mejor de la misma persona en otra franquicia o tramo (sin fijar medias).
  final (low, best) = () {
    final d = Draft(catalogo);
    for (final j in catalogo) {
      final t = Temporada(id: 'x', franquiciaUsuarioId: 'CHI', tirada: Tirada.de(j));
      final m = d.mejorVersionDe(t, j);
      // Solo vale la carta que la tirada muestra (una por persona: la de más media de su franquicia y época).
      if (m != null && d.candidatos(t).length >= 3 && d.candidatos(t).contains(j)) return (j, m);
    }
    throw StateError('el catálogo no tiene versiones');
  }();

  Future<List<Temporada>> abrir(
    WidgetTester tester,
    Temporada t, {
    int monedas = 0,
    List<PerfilEntrenador>? perfiles,
    Size tamano = const Size(412, 915),
  }) async {
    tester.view.physicalSize = tamano * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    perfilApp.value = PerfilEntrenador(monedas: monedas);
    addTearDown(() => perfilApp.value = const PerfilEntrenador());
    final guardadas = <Temporada>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: DraftPantalla(
          key: UniqueKey(),
          temporada: t,
          onCambio: guardadas.add,
          onPerfil: perfiles?.add,
          catalogo: catalogo,
          azar: Random(3),
        ),
      ),
    );
    await tester.pump();
    return guardadas;
  }

  Temporada conTirada({int fichas = 0, ModoJuego modo = ModoJuego.clasico}) =>
      Temporada(id: 't', franquiciaUsuarioId: 'CHI', rerollsRestantes: fichas, modoJuego: modo, tirada: Tirada.de(low));

  Finder ficha(String rotulo) => find.bySemanticsLabel(RegExp('^$rotulo, '));

  testWidgets('la bandeja muestra los 5 tokens con su estado y las monedas en la barra', (tester) async {
    await abrir(tester, conTirada(fichas: 1), monedas: 200);
    expect(find.byType(BandejaTokens), findsOneWidget);
    expect(ficha('Volver a tirar'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Volver a tirar, gratis')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Mejor versión, cuesta 150 monedas\$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Doble, cuesta 200 monedas\$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Comodín, cuesta 120 monedas\$')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Intercambio, todavía no se puede usar')),
      findsOneWidget,
      reason: 'sin cartas elegidas',
    );
    expect(find.bySemanticsLabel('200 monedas'), findsOneWidget);
  });

  testWidgets('con pocas monedas los tokens aparecen caros y explican cuánto falta', (tester) async {
    await abrir(tester, conTirada(), monedas: 100);
    expect(find.bySemanticsLabel(RegExp('Volver a tirar, cuesta 50 monedas\$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Mejor versión, cuesta 150 monedas y no te alcanzan')), findsOneWidget);
    await tester.tap(find.text('VERSIÓN'));
    await tester.pump();
    expect(find.text('Te faltan 50 monedas para mejor versión.'), findsOneWidget);
  });

  testWidgets('volver a tirar con monedas: confirma el gasto, descuenta del perfil y guarda', (tester) async {
    final perfiles = <PerfilEntrenador>[];
    final guardadas = await abrir(tester, conTirada(), monedas: 120, perfiles: perfiles);
    expect(find.text('VOLVER A TIRAR · 50 MONEDAS'), findsOneWidget);
    await tester.tap(find.text('VOLVER A TIRAR · 50 MONEDAS'));
    await tester.pumpAndSettle();
    expect(find.text('PAGAR 50 MONEDAS'), findsOneWidget);
    expect(guardadas, isEmpty, reason: 'todavía no se pagó');
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(guardadas, isEmpty);
    expect(perfilApp.value.monedas, 120);

    await tester.tap(find.text('VOLVER A TIRAR · 50 MONEDAS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAGAR 50 MONEDAS'));
    await tester.pump(const Duration(seconds: 2));
    expect(guardadas.last.tokens.gastadas, 50);
    expect(guardadas.last.tokens.pagosDe(TokenDraft.volverATirar), 1);
    expect(perfilApp.value.monedas, 70);
    expect(perfiles.single.monedas, 70, reason: 'el perfil se guarda al instante');
    final siguiente = find.widgetWithText(OutlinedButton, 'VOLVER A TIRAR · 100 MONEDAS');
    expect(siguiente, findsOneWidget, reason: 'el precio sube');
    expect(tester.widget<OutlinedButton>(siguiente).onPressed, isNull, reason: 'te quedan 70: no alcanza');
  });

  testWidgets('mejor versión: muestra cuál es y por qué, y cambia la carta por la mejor', (tester) async {
    final guardadas = await abrir(tester, conTirada(fichas: 1), monedas: 500);
    await tester.tap(find.text('VERSIÓN'));
    await tester.pump();
    expect(find.textContaining('Tocá primero la carta'), findsOneWidget);

    final carta = find.byWidgetPredicate((w) => w is CartaVertical && w.jugador == low);
    await tester.ensureVisible(carta);
    await tester.tap(carta);
    await tester.pump();
    await tester.tap(find.text('VERSIÓN'));
    await tester.pumpAndSettle();
    expect(find.text('MEJOR VERSIÓN'), findsOneWidget);
    expect(find.textContaining('media ${best.media}'), findsWidgets);
    expect(find.textContaining('${best.equipo} ${best.tramo}'), findsWidgets);
    expect(find.text('CAMBIAR POR 150 MONEDAS'), findsOneWidget);
    await tester.tap(find.text('CAMBIAR POR 150 MONEDAS'));
    await tester.pumpAndSettle();

    expect(guardadas.last.tokens.sustituidas, {low.id: best.id});
    expect(perfilApp.value.monedas, 350);
    final ahora = find.byWidgetPredicate((w) => w is CartaVertical && w.jugador == best);
    await tester.ensureVisible(ahora);
    expect(ahora, findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is CartaVertical && w.jugador == low), findsNothing);
  });

  testWidgets('doble: se activa pagando y la tirada sigue abierta para el segundo jugador', (tester) async {
    final guardadas = await abrir(tester, conTirada(fichas: 1), monedas: 300);
    await tester.tap(find.text('DOBLE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAGAR 200 MONEDAS'));
    await tester.pumpAndSettle();
    expect(guardadas.last.tokens.picksExtra, 1);
    expect(perfilApp.value.monedas, 100);
    expect(find.textContaining('DOBLE ACTIVO'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Doble, agotado')), findsOneWidget);
  });

  testWidgets('modos: Desafío del día trae el kit gratis; Reto y espejo, menos; Extremo, nada', (tester) async {
    await abrir(tester, conTirada(fichas: 2, modo: ModoJuego.desafioDelDia), monedas: 0);
    expect(find.bySemanticsLabel(RegExp('Mejor versión, gratis')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Doble, gratis')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Comodín')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Intercambio')), findsNothing);
    expect(find.byType(Monedero), findsNothing, reason: 'no se cobra nada');

    await abrir(tester, conTirada(fichas: 2, modo: ModoJuego.reto), monedas: 0);
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('^Volver a tirar')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Mejor versión')), findsNothing);

    for (final modo in [ModoJuego.extremo, ModoJuego.espejo]) {
      await abrir(tester, conTirada(fichas: 0, modo: modo), monedas: 9999);
      await tester.pump();
      expect(find.byType(BandejaTokens), findsNothing, reason: '$modo');
      expect(find.text('SIN FICHAS DE REROLL'), findsOneWidget, reason: 'nunca se cobran monedas sin querer');
    }
  });
}
