// Tanda 3 (partido en vivo) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/presentation/pantallas/partido_pantalla.dart';
import 'package:dinastia_nba/presentation/partido/sonido_partido.dart';
import 'package:dinastia_nba/presentation/partido/voz_relator.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(12));
  late Temporada temporada;
  setUpAll(() async {
    SonidoPartido.habilitado = false;
    VozRelator.habilitado = false;
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'LAL').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    temporada = liga.iniciar(Temporada(id: 'c3', franquiciaUsuarioId: 'LAL', plantel: p, tacticaConfirmada: true));
  });

  testWidgets('partido entero: jugada clave, equipo, resumen y repetición', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final partido = liga.proximoDelUsuario(temporada)!;
    final local = partido.localId == 'LAL';
    final motor = liga.motor(temporada, partido, azar: Random(5))
      ..cuarto = 4
      ..reloj = 280;
    String id(String f) => f == 'LAL' ? 'LAL' : temporada.rivales[f]!.identidadId;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: PartidoPantalla(
          motor: motor,
          usuarioLocal: local,
          franquiciaUsuario: franquiciaPorId('LAL'),
          identidadLocal: franquiciaPorId(id(partido.localId)),
          identidadVisitante: franquiciaPorId(id(partido.visitanteId)),
          onTerminado: (_) {},
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 80 && find.text('JUGADA CLAVE').evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t3-jugada-clave.png'));
    await t.tap(find.text('No preguntar más en este partido'));
    await t.pump();
    await t.tap(find.text('PICK & ROLL'));
    await t.tap(find.text('x4'));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t3-equipo.png'));
    for (var i = 0; i < 1500 && find.text('CONTINUAR').evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.pump(const Duration(seconds: 1));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t3-final.png'));
    await t.tap(find.text('RESUMEN Y REPETICIONES'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t3-resumen.png'));
    final jugadas = find.byIcon(Icons.slow_motion_video);
    if (jugadas.evaluate().isNotEmpty) {
      await t.tap(jugadas.first);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t3-repeticion.png'));
    }
  });
}
