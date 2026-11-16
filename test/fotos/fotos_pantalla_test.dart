import 'dart:io';

import 'package:dinastia_nba/core/fotos/gestor_fotos.dart';
import 'package:dinastia_nba/core/fotos/indice_fotos.dart';
import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/presentation/pantallas/fotos_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayudas_fotos.dart';

void main() {
  sqfliteFfiInit();
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync()).take(60).toList();
  final personas = GestorFotos.personasDe(catalogo);

  testWidgets('progreso, descargar todas, pausar, reanudar y fuentes y licencias', (t) async {
    late sq.Database db;
    late Directory carpeta;
    late GestorFotos g;
    await t.runAsync(() async {
      db = await databaseFactoryFfi.openDatabase(sq.inMemoryDatabasePath);
      await IndiceFotos.crearTabla(db);
      carpeta = carpetaTemporal();
      g = GestorFotos(
        indice: IndiceFotos(db),
        carpeta: carpeta,
        peticiones: peticionesDe(
          ClienteFalso((u) => u.host == 'cdn.nba.com' ? pngFalso() : estado(404)),
          reintentos: 0,
        ),
      );
    });
    addTearDown(() => carpeta.deleteSync(recursive: true));

    await t.pumpWidget(
      MaterialApp(
        home: FotosPantalla(gestor: g, catalogo: () async => catalogo),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('0 / ${personas.length}'), findsOneWidget);
    expect(find.text('Descargar todas (recomendado con wifi)'), findsOneWidget);
    expect(find.byKey(const Key('fotos-pausar')), findsNothing);

    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('fotos-descargar')));
      await t.pump();
      expect(find.byKey(const Key('fotos-pausar')), findsOneWidget);
      g.pausar();
      await g.terminar();
    });
    await t.pump();
    expect(find.byKey(const Key('fotos-reanudar')), findsOneWidget);

    await t.runAsync(() async {
      g.reanudar();
      await g.terminar();
    });
    await t.pump();
    final c = g.conteo(personas);
    expect(c.faltan, 0);
    expect(find.text('${c.listas} / ${personas.length}'), findsOneWidget);
    expect(find.byKey(const Key('fotos-descargar')), findsOneWidget);
    final barra = t.widget<LinearProgressIndicator>(find.byKey(const Key('fotos-progreso')));
    expect(barra.value, 1.0);
    expect(find.byKey(const Key('fotos-reintentar')), c.sin > 0 ? findsOneWidget : findsNothing);

    await t.tap(find.byKey(const Key('fotos-fuentes')));
    await t.pumpAndSettle();
    expect(find.text('CDN de la NBA'), findsOneWidget);
    expect(find.text('Wikipedia y Wikimedia Commons'), findsOneWidget);
    expect(find.text('Sports Reference / Basketball-Reference'), findsOneWidget);
    await t.runAsync(() => db.close());
  });

  testWidgets('sin gestor muestra el aviso', (t) async {
    GestorFotos.instancia = null;
    await t.pumpWidget(const MaterialApp(home: FotosPantalla()));
    expect(find.textContaining('no están disponibles'), findsOneWidget);
  });
}
