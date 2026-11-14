// Modos v3: tope salarial, liga de 8 contra la IA, desafíos de armado y adiviná la carta (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/armado.dart';
import 'package:dinastia_nba/presentation/modos/armado.dart';
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
  final liga = Liga(catalogo, franquicias);
  final modos = ModosArmado(catalogo, azar: Random(4));
  final ids = [for (final f in franquicias) f.id];
  String nombre(String id) => franquiciaPorId(id).nombreCompleto;

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  void tel(WidgetTester t, {double alto = 1500}) {
    t.view.physicalSize = Size(412, alto) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  void tablet(WidgetTester t) {
    t.view.physicalSize = const Size(1340, 900) * 1.8;
    t.view.devicePixelRatio = 1.8;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  Temporada tempo(ModoJuego m, PartidaArmada p) =>
      Temporada(id: 'c', franquiciaUsuarioId: 'CHI', modoJuego: m, dificultad: Dificultad.normal).conArmada(p);

  PartidaArmada tope() {
    final p = modos.nuevoTope(
      semilla: 21,
      dificultad: Dificultad.normal,
      franquiciaUsuario: 'CHI',
      franquicias: ids,
      nombreDe: nombre,
    );
    var e = p.tope!;
    final js = [for (final id in e.tablero) modos.jugador(id)!];
    e = modos.comprar(
      e,
      js[0],
      js[0].posiciones.contains(js[0].posiciones.first) ? js[0].posiciones.first : js[0].posiciones.first,
    );
    e = modos.comprar(
      e,
      js[16],
      modos.motivoNoCompra(e, js[16], js[16].posiciones.first) == null
          ? js[16].posiciones.first
          : js[16].posiciones.last,
    );
    return p.copyWith(tope: e);
  }

  PartidaArmada draft({int picks = 2}) {
    var p = modos.avanzarIA(
      modos.nuevaLigaIA(semilla: 33, franquiciaUsuario: 'CHI', franquicias: ids, nombreDe: nombre),
    );
    for (var k = 0; k < picks && !p.draft!.terminado; k++) {
      final j = modos.elegibles(p, 0).reduce((a, b) => a.media >= b.media ? a : b);
      p = modos.elegir(p, j, modos.puestoPara(p, 0, j));
    }
    return p;
  }

  Future<void> foto(WidgetTester t, String nombre) async {
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-armado-$nombre.png'));
  }

  testWidgets('tope salarial', (t) async {
    tel(t, alto: 1700);
    await t.pumpWidget(
      app(ArmadoPantalla(temporada: tempo(ModoJuego.topeSalarial, tope()), liga: liga, onCambio: (_) {})),
    );
    await foto(t, 'tope');
  });

  testWidgets('tope salarial tablet', (t) async {
    tablet(t);
    await t.pumpWidget(
      app(ArmadoPantalla(temporada: tempo(ModoJuego.topeSalarial, tope()), liga: liga, onCambio: (_) {})),
    );
    await foto(t, 'tope-tablet');
  });

  testWidgets('draft contra la IA', (t) async {
    tel(t, alto: 1900);
    await t.pumpWidget(app(ArmadoPantalla(temporada: tempo(ModoJuego.ligaIA, draft()), liga: liga, onCambio: (_) {})));
    await foto(t, 'draft');
  });

  testWidgets('draft contra la IA tablet', (t) async {
    tablet(t);
    await t.pumpWidget(app(ArmadoPantalla(temporada: tempo(ModoJuego.ligaIA, draft()), liga: liga, onCambio: (_) {})));
    await foto(t, 'draft-tablet');
  });

  testWidgets('liga de 8 a mitad y en playoffs', (t) async {
    tel(t, alto: 1700);
    var p = draft(picks: 6);
    for (var k = 0; k < 7; k++) {
      p = modos.simularProximoDelUsuario(p);
    }
    await t.pumpWidget(app(ArmadoPantalla(temporada: tempo(ModoJuego.ligaIA, p), liga: liga, onCambio: (_) {})));
    await foto(t, 'liga');
    p = modos.simularFase(p);
    await t.pumpWidget(app(ArmadoPantalla(temporada: tempo(ModoJuego.ligaIA, p), liga: liga, onCambio: (_) {})));
    await foto(t, 'playoffs');
    p = modos.simularTodo(p);
    await t.pumpWidget(app(ArmadoPantalla(temporada: tempo(ModoJuego.ligaIA, p), liga: liga, onCambio: (_) {})));
    await foto(t, 'final');
  });

  testWidgets('desafíos de armado', (t) async {
    tel(t, alto: 1600);
    final album = catalogo.where((j) => j.franquiciaId == 'CHI' || j.franquiciaId == 'BOS').take(45).map((j) => j.id);
    perfilApp.value = PerfilEntrenador(coleccion: {...album}).conDesafioResuelto(desafiosArmado[0]);
    await t.pumpWidget(app(DesafiosArmadoPantalla(catalogo: catalogo, onPerfil: (_) {})));
    await foto(t, 'desafios');
    await t.pumpWidget(
      app(
        DesafioPantalla(
          desafio: desafiosArmado[6],
          album: [
            for (final j in catalogo)
              if (perfilApp.value.coleccion.contains(j.id)) j,
          ],
          onResuelto: () {},
        ),
      ),
    );
    await t.pump();
    final cartas = find.byWidgetPredicate(
      (w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('album-'),
    );
    for (var k = 0; k < 4; k++) {
      await t.tap(cartas.at(k));
      await t.pump();
    }
    await foto(t, 'desafio');
    perfilApp.value = const PerfilEntrenador();
  });

  testWidgets('adiviná la carta', (t) async {
    tel(t, alto: 1000);
    await t.pumpWidget(
      app(AdivinaPantalla(catalogo: catalogo, variante: VarianteAdivina.quien, azar: Random(5), onPerfil: (_) {})),
    );
    await foto(t, 'quien');
    await t.tap(find.byKey(const ValueKey('opcion-1')));
    await foto(t, 'quien-respondida');
    await t.pumpWidget(
      app(AdivinaPantalla(catalogo: catalogo, variante: VarianteAdivina.masMenos, azar: Random(6), onPerfil: (_) {})),
    );
    await t.tap(find.byKey(const ValueKey('opcion-0')));
    await foto(t, 'masmenos');
  });
}
