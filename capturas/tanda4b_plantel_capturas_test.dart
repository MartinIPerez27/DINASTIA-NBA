// Tanda 4b: pestaña Plantel con banco largo, lesión y acceso al mercado (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/presentation/pantallas/temporada_pantalla.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(21));
  late Temporada t;
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    t = liga.iniciar(Temporada(id: 'c4b', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    for (var i = 0; i < 20; i++) {
      t = liga.simularProximo(t);
    }
    // La temporada ya arranca con 2 suplentes: se libera uno para mostrar el fichaje.
    t = liga.firmar(t.copyWith(suplentes: t.suplentes.take(1).toList()), liga.agentesLibres(t).first);
    final titular = t.plantel.en(Posicion.values[1])!;
    t = t.copyWith(lesiones: {...t.lesiones, titular.id: 6});
  });

  testWidgets('plantel con banco largo y mercado', (tester) async {
    tester.view.physicalSize = const Size(412, 1500) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: TemporadaPantalla(temporada: t, liga: liga, onCambio: (_) {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Plantel'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Banco largo'), 300, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await expectLater(find.byType(TemporadaPantalla), matchesGoldenFile('salida/t4b-plantel.png'));
  });
}
