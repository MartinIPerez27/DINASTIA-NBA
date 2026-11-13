// Tanda 5: modos con amigos (Draft en grupo y Duelo) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/modos/amigos.dart';
import 'package:dinastia_nba/presentation/modos/amigos.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_jugador.dart';
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
  final amigos = Amigos(catalogo, azar: Random(8));
  const grupo = [('Martín', 'CHI'), ('Lucía', 'BOS'), ('Nico', 'LAL'), ('Sofi', 'GSW'), ('Juan', 'MIA')];

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  PartidaAmigos avanzarDraft(PartidaAmigos p, int elecciones) {
    for (var k = 0; k < elecciones && p.fase == FaseAmigos.draft; k++) {
      final yo = p.participantes[p.eligeAhora];
      final j = amigos.candidatos(p).first;
      p = amigos.elegir(amigos.verTurno(p), j, yo.plantel.posicionesDisponiblesPara(j).first);
    }
    return p;
  }

  PartidaAmigos conTacticas(PartidaAmigos p) {
    for (int? i = p.pendienteDeTactica; i != null; i = p.pendienteDeTactica) {
      p = amigos.confirmarTactica(p, i, amigos.recomendada(p, i));
    }
    return p;
  }

  Future<void> sacar(WidgetTester t, PartidaAmigos p, String archivo, {Size tamano = const Size(412, 915)}) async {
    t.view.physicalSize = tamano * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: AmigosPantalla(
          key: ValueKey(archivo),
          temporada: Temporada(
            id: 'c5',
            franquiciaUsuarioId: 'CHI',
            modoJuego: p.duelo ? ModoJuego.duelo : ModoJuego.draftEnGrupo,
            datosModo: p.toJson(),
          ),
          catalogo: catalogo,
          onGuardar: (_) async {},
        ),
      ),
    );
    await t.pump();
    if (find.byType(CartaJugador).evaluate().isNotEmpty) {
      await t.tap(find.byType(CartaJugador).at(1));
      await t.pump();
    }
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    await expectLater(find.byType(AmigosPantalla), matchesGoldenFile('salida/$archivo'));
  }

  testWidgets('pasar el dispositivo', (t) async {
    final p = avanzarDraft(amigos.nueva(duelo: false, personas: grupo, semilla: 3), 7);
    await sacar(t, p, 't5-amigos-1-pasar.png');
  });

  testWidgets('turno del draft (teléfono)', (t) async {
    final p = amigos.verTurno(avanzarDraft(amigos.nueva(duelo: false, personas: grupo, semilla: 3), 12));
    await sacar(t, p, 't5-amigos-2-draft.png', tamano: const Size(412, 1300));
  });

  testWidgets('turno del draft (tablet horizontal)', (t) async {
    final p = amigos.verTurno(avanzarDraft(amigos.nueva(duelo: false, personas: grupo, semilla: 3), 17));
    await sacar(t, p, 't5-amigos-3-draft-tablet.png', tamano: const Size(1280, 800));
  });

  testWidgets('liga (teléfono y tablet)', (t) async {
    var p = conTacticas(avanzarDraft(amigos.nueva(duelo: false, personas: grupo, semilla: 3), 99));
    for (var k = 0; k < 11; k++) {
      p = amigos.simularProximo(p);
    }
    await sacar(t, p, 't5-amigos-4-liga.png', tamano: const Size(412, 1400));
    await sacar(t, p, 't5-amigos-5-liga-tablet.png', tamano: const Size(1280, 800));
  });

  testWidgets('duelo en serie y campeón', (t) async {
    var p = conTacticas(
      avanzarDraft(amigos.nueva(duelo: true, personas: [('Martín', 'CHI'), ('Lucía', 'NYK')], semilla: 4), 99),
    );
    for (var k = 0; k < 3; k++) {
      p = amigos.simularProximo(p);
    }
    await sacar(t, p, 't5-amigos-6-duelo.png', tamano: const Size(412, 1100));
    await sacar(t, amigos.simularFase(p), 't5-amigos-7-campeon.png', tamano: const Size(412, 1000));
  });

  testWidgets('configuración', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: ConfigAmigosPantalla(duelo: false, enfocada: franquiciaPorId('CHI')),
      ),
    );
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    await expectLater(find.byType(ConfigAmigosPantalla), matchesGoldenFile('salida/t5-amigos-0-config.png'));
  });
}
