// Fantasy NBA, Perfil perfecto y Evoluciones con tipografías reales (no corre en CI).
import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/modos/evoluciones.dart';
import 'package:dinastia_nba/domain/modos/fantasy.dart';
import 'package:dinastia_nba/domain/modos/perfil_perfecto.dart';
import 'package:dinastia_nba/presentation/modos/fantasy.dart';
import 'package:dinastia_nba/presentation/modos/perfil_perfecto.dart';
import 'package:dinastia_nba/presentation/pantallas/evoluciones_vista.dart';
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
  final fantasy = Fantasy(catalogo);
  final pool = fantasy.poolDelAnio(1996);

  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  void telefono(WidgetTester t) {
    t.view.physicalSize = const Size(412, 900) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  PartidaFantasy equipoArmado() {
    var f = fantasy.nueva(anio: 1996, dificultad: Dificultad.normal, rivales: 5, semilla: 42, pool: pool);
    // Un equipo razonable: lo mejor que entre en el presupuesto, puesto por puesto.
    final personas = <int>{};
    final puestos = [
      Posicion.alero,
      Posicion.pivot,
      Posicion.base,
      Posicion.escolta,
      Posicion.alaPivot,
      Posicion.sextoHombre,
    ];
    for (final (i, pos) in puestos.indexed) {
      // Lo mejor que entre sin dejar sin plata a los puestos que faltan (1 por cada uno).
      final tope = f.presupuesto - fantasy.costo(f, f.tuEquipo) - (puestos.length - i - 1);
      final j = pool.firstWhere(
        (j) => j.puedeJugarEn(pos) && !personas.contains(j.nbaPlayerId) && fantasy.precioDe(f, j) <= tope,
      );
      personas.add(j.nbaPlayerId);
      f = fantasy.ficharUsuario(f, pos, j);
    }
    return f;
  }

  Temporada envolver(PartidaFantasy f) =>
      f.guardarEn(const Temporada(id: 'cap', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.fantasy));

  testWidgets('fantasy: configuración, armado y mercado', (t) async {
    telefono(t);
    perfilApp.value = const PerfilEntrenador();
    await t.pumpWidget(app(FantasyConfigPantalla(catalogo: catalogo, perfil: const PerfilEntrenador())));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-config.png'));

    final vacia = fantasy.nueva(anio: 1996, dificultad: Dificultad.normal, rivales: 5, semilla: 42, pool: pool);
    await t.pumpWidget(app(FantasyPantalla(temporada: envolver(vacia), catalogo: catalogo, onGuardar: (_) async {})));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-armado.png'));
    await t.tap(find.text('Mercado'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-mercado.png'));
  });

  testWidgets('fantasy: a mitad de temporada, tabla y final', (t) async {
    telefono(t);
    var f = equipoArmado();
    for (var i = 0; i < 5; i++) {
      f = fantasy.jugarSemana(f);
    }
    await t.pumpWidget(app(FantasyPantalla(temporada: envolver(f), catalogo: catalogo, onGuardar: (_) async {})));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-equipo.png'));
    await t.tap(find.text('Tabla'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-tabla.png'));
    await t.tap(find.text('Semanas'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-semanas.png'));

    final fin = fantasy.simularTodo(f);
    await t.pumpWidget(app(FantasyPantalla(temporada: envolver(fin), catalogo: catalogo, onGuardar: (_) async {})));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-final.png'));
  });

  testWidgets('fantasy en tablet apaisada', (t) async {
    t.view.physicalSize = const Size(1340, 900) * 1.8;
    t.view.devicePixelRatio = 1.8;
    addTearDown(t.view.reset);
    var f = equipoArmado();
    for (var i = 0; i < 4; i++) {
      f = fantasy.jugarSemana(f);
    }
    await t.pumpWidget(app(FantasyPantalla(temporada: envolver(f), catalogo: catalogo, onGuardar: (_) async {})));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-tablet.png'));
  });

  testWidgets('perfil perfecto: menú, nivel y resuelto', (t) async {
    telefono(t);
    final pp = generadorPP(catalogo);
    var p = const PerfilEntrenador();
    for (var n = 1; n <= 12; n++) {
      p = ProgresoPP.registrar(p, clave: n, estrellas: n % 3 + 1).$1;
    }
    perfilApp.value = p;
    addTearDown(() => perfilApp.value = const PerfilEntrenador());
    await t.pumpWidget(app(PerfilPerfectoMenu(generador: pp, onPerfil: (_) {}, fecha: 20261113)));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-pp-menu.png'));

    for (final nivel in [14, 60]) {
      await t.pumpWidget(app(PerfilPerfectoNivel(key: ValueKey(nivel), generador: pp, nivel: nivel, onPerfil: (_) {})));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 60));
      }
      final n = pp.generar(nivel);
      // Llenamos la mitad de los casilleros con la respuesta correcta.
      for (var f = 0; f < n.n; f++) {
        if (f >= (n.n + 1) ~/ 2) break;
        for (var c = 1; c < n.categorias.length; c++) {
          final v = n.solucion[c].indexOf(f);
          await t.tap(find.text('?').first);
          await t.pumpAndSettle();
          await t.tap(find.descendant(of: find.byType(ListTile), matching: find.text(n.categorias[c].etiquetas[v])));
          await t.pumpAndSettle();
        }
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-pp-nivel$nivel.png'));
    }
    // Resuelto
    final n = pp.generar(14);
    await t.pumpWidget(app(PerfilPerfectoNivel(key: const ValueKey(1400), generador: pp, nivel: 14, onPerfil: (_) {})));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    for (var f = 0; f < n.n; f++) {
      for (var c = 1; c < n.categorias.length; c++) {
        final v = n.solucion[c].indexOf(f);
        await t.tap(find.text('?').first);
        await t.pumpAndSettle();
        await t.tap(find.descendant(of: find.byType(ListTile), matching: find.text(n.categorias[c].etiquetas[v])));
        await t.pumpAndSettle();
      }
    }
    await t.tap(find.widgetWithText(FilledButton, 'VERIFICAR'));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-pp-resuelto.png'));
  });

  testWidgets('evoluciones en el álbum', (t) async {
    telefono(t);
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    final cartas = chi.take(6).toList();
    final evo = PerfilEvoluciones({
      cartas[0].id: const EvoCarta(objetivoId: 'triples', progreso: 31, etapa: 1),
      cartas[1].id: const EvoCarta(objetivoId: 'victorias', progreso: 9, etapa: 2),
      cartas[2].id: const EvoCarta(objetivoId: 'puntos', progreso: 1650, etapa: 5),
    });
    var perfil = evo.guardarEn(PerfilEntrenador(coleccion: {for (final c in cartas) c.id}));
    await t.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, set) => Scaffold(
            appBar: AppBar(title: const Text('Álbum · Evoluciones')),
            body: EvolucionesVista(catalogo: catalogo, perfil: perfil, onPerfil: (p) => set(() => perfil = p)),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-fantasy-evoluciones.png'));
  });
}
