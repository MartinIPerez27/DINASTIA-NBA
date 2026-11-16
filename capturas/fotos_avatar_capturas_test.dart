// Capturas del avatar ilustrado y de la pantalla de fotos (no corre en CI).
import 'dart:io';

import 'package:dinastia_nba/core/fotos/gestor_fotos.dart';
import 'package:dinastia_nba/core/fotos/indice_fotos.dart';
import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/presentation/pantallas/fotos_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:dinastia_nba/presentation/widgets/ficha_jugador.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/fotos/ayudas_fotos.dart';

Future<void> _fuente(String familia, List<String> archivos) async {
  final loader = FontLoader(familia);
  for (final a in archivos) {
    loader.addFont(Future.value(ByteData.sublistView(File(a).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  sqfliteFfiInit();
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
  });

  testWidgets('avatares ilustrados', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final ids = [
      'jordami01-CHI-90',
      'ewingpa01-NYK-90',
      'moncrsi01-MIL-80',
      'jamesle01-CLE-10',
      'hardati01-MIA-90',
      'englial01-DEN-80',
    ];
    final cartas = [for (final id in ids) catalogo.firstWhere((j) => j.id == id)];
    final extra = catalogo.where((j) => j.fotos.length == 2).skip(300).take(8).toList();
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('NYK')),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final j in cartas.take(3)) SizedBox(width: 124, height: 210, child: CartaVertical(jugador: j)),
                  ],
                ),
                const SizedBox(height: 8),
                FichaJugador(jugador: cartas[0]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final j in [...cartas, ...extra])
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: JugadorAvatar(jugador: j, franquicia: franquiciaPorId(j.franquiciaId), recortar: true),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final j in extra.take(6))
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: JugadorAvatar(jugador: j, franquicia: franquiciaPorId(j.franquiciaId), recortar: true),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/avatar-ilustrado.png'));
  });

  testWidgets('pantalla de fotos', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    late GestorFotos g;
    late sq.Database db;
    await t.runAsync(() async {
      db = await databaseFactoryFfi.openDatabase(sq.inMemoryDatabasePath);
      await IndiceFotos.crearTabla(db);
      final indice = IndiceFotos(db);
      final personas = GestorFotos.personasDe(catalogo);
      final ahora = DateTime(2026, 11, 1);
      for (var i = 0; i < 1800; i++) {
        await indice.guardar(
          FotoIndexada(
            persona: personas[i].clave,
            estado: EstadoFoto.ok,
            fecha: ahora,
            nombre: personas[i].nombre,
            ruta: 'x.png',
            fuente: i % 3 == 0 ? 'wikipedia' : 'nba',
            licencia: 'CC BY-SA 4.0',
            autor: 'Autor Ejemplo',
            urlPagina: 'https://commons.wikimedia.org/wiki/File:Ejemplo.jpg',
          ),
        );
      }
      g = GestorFotos(
        indice: indice,
        carpeta: carpetaTemporal(),
        peticiones: peticionesDe(ClienteFalso((_) => estado(404))),
      );
      await g.cargar();
    });
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('NYK')),
        home: FotosPantalla(gestor: g, catalogo: () async => catalogo),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/fotos-pantalla.png'));
    await t.tap(find.byKey(const Key('fotos-fuentes')));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/fotos-fuentes.png'));
  });
}
