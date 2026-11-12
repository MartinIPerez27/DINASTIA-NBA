// Mercado de pases con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/mercado.dart';
import 'package:dinastia_nba/presentation/pantallas/mercado_pantalla.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(31));
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  testWidgets('mercado', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    final temporada = liga.iniciar(
      Temporada(
        id: 'cm',
        franquiciaUsuarioId: 'CHI',
        plantel: p,
        tacticaConfirmada: true,
        dificultad: Dificultad.leyenda,
      ),
    );
    final mercado = Mercado(liga);
    // Pedimos la mejor carta del mismo puesto que tenga el primer rival (probablemente un "no").
    final mio = temporada.plantel.en(Posicion.base)!;
    final rival = temporada.rivales.keys.first;
    final suyo = mercado.pedibles(temporada, rival).firstWhere((e) => e.$1 == Posicion.base).$2;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: MercadoPantalla(temporada: temporada, liga: liga, onCambio: (_) {}),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4b-mercado-1.png'));
    Future<void> tocar(Finder f) async {
      await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    await tocar(find.byKey(ValueKey('mia-${mio.id}')));
    await tocar(find.byKey(ValueKey('rival-$rival')));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4b-mercado-2.png'));
    await tocar(find.byKey(ValueKey('suya-${suyo.id}')));
    await tocar(find.textContaining('PROPONER'));
    final aviso = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(RegExp('dicen que no|Trato hecho')),
    );
    await t.scrollUntilVisible(aviso, 200, scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4b-mercado-3.png'));
    // Cerrado: pasó la fecha límite.
    var cerrada = temporada;
    while (liga.proximoDelUsuario(cerrada)!.jornada <= mercado.jornadaLimite(temporada)) {
      cerrada = liga.simularProximo(cerrada);
    }
    await t.pumpWidget(
      MaterialApp(
        key: const ValueKey('cerrado'),
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: MercadoPantalla(temporada: cerrada, liga: liga, onCambio: (_) {}),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4b-mercado-4.png'));
  });
}
