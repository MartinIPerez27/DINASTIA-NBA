// Insignias del Camino y Figura franquicia con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/dinastia.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:dinastia_nba/presentation/modos/carrera_pantallas.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/modos/escalera.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(4));
  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);
  void tel(WidgetTester t) {
    t.view.physicalSize = const Size(412, 1500) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  testWidgets('camino: elegir insignia y las activas', (t) async {
    tel(t);
    final modos = ModosEscalera(liga, azar: Random(3));
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    var temp = modos.iniciar(
      Temporada(
        id: 'cap',
        franquiciaUsuarioId: 'CHI',
        plantel: p,
        tacticaConfirmada: true,
        modoJuego: ModoJuego.caminoAlAnillo,
      ),
    );
    for (var i = 0; i < 2; i++) {
      temp = modos.registrar(temp, modos.motor(temp)..simularTodo());
      var e = Escalera.de(temp);
      if (e.terminada) break;
      if (i == 0) temp = modos.elegirInsignia(temp, e.insigniasOfrecidas.first);
    }
    await t.pumpWidget(app(EscaleraPantalla(temporada: temp, liga: liga, onCambio: (_) {})));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-carrera-insignias.png'));
  });

  testWidgets('figura: receso con evolución y legado', (t) async {
    tel(t);
    final carrera = CarreraDinastia(liga);
    final figura = carrera.candidatosFigura(Random(2)).first;
    var temp = carrera.nuevaFigura(id: 'figc', franquiciaId: 'SAC', figura: figura, dificultad: Dificultad.normal);
    temp = liga.iniciar(temp.copyWith(tacticaConfirmada: true));
    while (liga.proximoDelUsuario(temp) != null) {
      temp = liga.simularProximo(temp);
    }
    temp = liga.simularRestoPlayoffs(liga.simularOtrosHasta(temp, 1 << 30));
    await t.pumpWidget(
      app(
        RecesoPantalla(
          temporada: temp,
          carrera: carrera,
          nombreDe: (id) => franquiciaPorId(id).nombreCompleto,
          onArrancar: (_) async {},
        ),
      ),
    );
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-carrera-figura-receso.png'));
  });
}
