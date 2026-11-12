// Copa NBA (Tanda 4b) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/copa.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/presentation/temporada/copa.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
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
  final copa = CopaNba(liga);
  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  testWidgets('copa: pendiente y campeón', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    var temp = liga.iniciar(Temporada(id: 'copa', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    while (liga.proximoDelUsuario(temp)!.jornada < copa.jornadaCopa(temp)) {
      temp = liga.simularProximo(temp);
    }
    final pendiente = copa.alDia(temp);
    var fin = pendiente;
    for (var i = 0; i < 5 && copa.campeon(fin) == null; i++) {
      final s = copa.pendienteDelUsuario(fin);
      if (s == null) break;
      fin = copa.registrar(fin, s, copa.motor(fin, s)..simularTodo());
    }
    Widget app(Temporada x) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaFranquicia(franquiciaPorId('CHI')),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TarjetaCopa(temporada: x, liga: liga, onCambio: (_) {}, franquiciaUsuario: franquiciaPorId('CHI')),
              ],
            ),
          ),
        ),
      ),
    );
    for (final (nombre, x) in [('pendiente', pendiente), ('final', fin)]) {
      await t.pumpWidget(app(x));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t4b-copa-$nombre.png'));
    }
  });
}
