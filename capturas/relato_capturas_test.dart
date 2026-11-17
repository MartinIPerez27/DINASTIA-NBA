// Panel de relato (Relator y Comentarista) en teléfono y tablet, con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/domain/relato/contexto_relato.dart';
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
    ajustesApp.value = const Ajustes(tutorialVisto: true, decisiones: false);
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

  Future<void> captura(WidgetTester t, Size tam, double dpr, String nombre) async {
    t.view.physicalSize = tam * dpr;
    t.view.devicePixelRatio = dpr;
    addTearDown(t.view.reset);
    final partido = liga.proximoDelUsuario(temporada)!;
    final local = partido.localId == 'LAL';
    final motor = liga.motor(temporada, partido, azar: Random(5))
      ..cuarto = 4
      ..reloj = 200;
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
          contexto: const ContextoRelato(
            playoffs: true,
            ronda: 'Semifinales de Conferencia',
            juegoSerie: 5,
            victoriasLocalSerie: 2,
            victoriasVisitanteSerie: 2,
            rivalidad: 'un clásico de la liga',
          ),
          onTerminado: (_) {},
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    final relato = find.text('Relato');
    if (relato.evaluate().isNotEmpty) await t.tap(relato);
    await t.pump();
    if (find.text('No preguntar más en este partido').evaluate().isNotEmpty) {
      await t.tap(find.text('No preguntar más en este partido'));
      await t.pump();
      await t.tap(find.text('PICK & ROLL'));
    }
    await t.tap(find.text('x4'));
    for (var i = 0; i < 140; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre.png'));
  }

  testWidgets('relato en teléfono', (t) => captura(t, const Size(412, 915), 2.5, 'relato-telefono'));
  testWidgets('relato en tablet', (t) => captura(t, const Size(1340, 900), 1.8, 'relato-tablet'));
}
