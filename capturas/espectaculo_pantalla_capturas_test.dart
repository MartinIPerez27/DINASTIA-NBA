// La pantalla de partido completa con el espectáculo (HUD, tribuna, repetición instantánea) en teléfono y
// tablet horizontal. Con tipografías reales (no corre en CI).
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
  final liga = Liga(catalogo, franquicias, azar: Random(2));
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
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    temporada = liga.iniciar(Temporada(id: 'ep', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  });

  Future<void> pantalla(WidgetTester t, Size tam, String nombre, {required bool tablet}) async {
    t.view.physicalSize = tam * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final partido = liga.proximoDelUsuario(temporada)!;
    final usuarioLocal = partido.localId == 'CHI';
    final m = liga.motor(temporada, partido, azar: Random(21))
      ..cuarto = 2
      ..reloj = 500;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PartidoPantalla(
          motor: m,
          usuarioLocal: usuarioLocal,
          franquiciaUsuario: franquiciaPorId('CHI'),
          identidadLocal: franquiciaPorId(usuarioLocal ? 'CHI' : temporada.rivales[partido.localId]!.identidadId),
          identidadVisitante: franquiciaPorId(
            usuarioLocal ? temporada.rivales[partido.visitanteId]!.identidadId : 'CHI',
          ),
          onTerminado: (_) {},
          playoffs: true,
        ),
      ),
    );
    // Juego en vivo.
    for (var i = 0; i < 70; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre-juego.png'));
    // Hasta que corte a la repetición (si hay alguna jugada destacada).
    for (var i = 0; i < 4000 && find.text('REPETICIÓN').evaluate().length < 2; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre-repeticion.png'));
    await t.pumpWidget(const SizedBox());
  }

  testWidgets('teléfono', (t) => pantalla(t, const Size(412, 915), 'espectaculo-pantalla-telefono', tablet: false));
  testWidgets('tablet horizontal', (t) => pantalla(t, const Size(1280, 800), 'espectaculo-pantalla-tablet', tablet: true));
}
