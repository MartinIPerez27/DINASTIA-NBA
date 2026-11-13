// Tanda 6: tablet apaisada (11" 2K) con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/main.dart';
import 'package:dinastia_nba/presentation/pantallas/album_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/draft_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/partido_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/partidas_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/perfil_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/playbook_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/playoffs_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/temporada_pantalla.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(7));
  late Temporada temporada, playoffs, fin;
  late Plantel plantel;
  setUpAll(() async {
    SonidoPartido.habilitado = false;
    VozRelator.habilitado = false;
    JugadorAvatar.usarRed = false;
    ajustesApp.value = const Ajustes(tutorialVisto: true);
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    plantel = p;
    final inicio = liga.iniciar(Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    temporada = inicio;
    for (var i = 0; i < 12; i++) {
      temporada = liga.simularProximo(temporada);
    }
    var t = temporada;
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
    }
    final regular = liga.simularOtrosHasta(t, 1 << 30);
    var po = liga.iniciarPlayoffs(regular);
    while (po.series.last.ronda.esPlayIn) {
      po = po.serieDelUsuario != null ? liga.simularPartidoPlayoff(po) : liga.simularPlayIn(po);
    }
    playoffs = liga.simularPartidoPlayoff(liga.simularPartidoPlayoff(po));
    fin = liga.simularRestoPlayoffs(playoffs);
    final progreso = Progreso(liga);
    var (perfil, _) = progreso.aplicar(const PerfilEntrenador(), inicio, regular);
    (perfil, _) = progreso.aplicar(perfil, regular, fin);
    perfilApp.value = perfil;
  });

  void tablet(WidgetTester t) {
    t.view.physicalSize = const Size(1340, 900) * 1.8;
    t.view.devicePixelRatio = 1.8;
    addTearDown(t.view.reset);
  }

  void telefono(WidgetTester t) {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  Future<void> foto(WidgetTester t, String nombre, {bool asentar = true}) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    if (asentar) {
      await t.pumpAndSettle();
    } else {
      for (var k = 0; k < 8; k++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t6-tablet-$nombre.png'));
  }

  Widget vivo(Temporada base) {
    final p = liga.proximoDelUsuario(base)!;
    final antes = liga.simularOtrosHasta(base, p.jornada);
    final motor = liga.motor(antes, p, azar: Random(3));
    String id(String f) => f == 'CHI' ? 'CHI' : antes.rivales[f]!.identidadId;
    return app(
      PartidoPantalla(
        motor: motor,
        usuarioLocal: p.localId == 'CHI',
        franquiciaUsuario: franquiciaPorId('CHI'),
        identidadLocal: franquiciaPorId(id(p.localId)),
        identidadVisitante: franquiciaPorId(id(p.visitanteId)),
        onTerminado: (_) {},
      ),
    );
  }

  testWidgets('vivo', (t) async {
    tablet(t);
    await t.pumpWidget(vivo(temporada));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.tap(find.text('x4'));
    for (var i = 0; i < 200; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t6-tablet-vivo.png'));
    await t.tap(find.text('Partido'));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t6-tablet-vivo-partido.png'));
  });

  testWidgets('vivo en el teléfono (sin cambios)', (t) async {
    telefono(t);
    await t.pumpWidget(vivo(temporada));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t6-telefono-vivo.png'));
  });

  testWidgets('draft ruleta y cartas', (t) async {
    tablet(t);
    final dos = Plantel()
        .asignar(plantel.en(Posicion.escolta)!, Posicion.escolta)
        .asignar(plantel.en(Posicion.alero)!, Posicion.alero);
    final draft = Draft(catalogo, azar: Random(4));
    final ruleta = draft.tirar(Temporada(id: 'r', franquiciaUsuarioId: 'CHI', plantel: dos));
    await t.pumpWidget(app(DraftPantalla(temporada: ruleta, onCambio: (_) {}, catalogo: catalogo)));
    await foto(t, 'draft-ruleta', asentar: false);
    final sobres = draft.repartir(
      Temporada(id: 'c', franquiciaUsuarioId: 'CHI', modo: ModoDraft.cartas, plantel: dos),
      Posicion.base,
    );
    await t.pumpWidget(app(DraftPantalla(key: UniqueKey(), temporada: sobres, onCambio: (_) {}, catalogo: catalogo)));
    await foto(t, 'draft-cartas', asentar: false);
  });

  testWidgets('temporada', (t) async {
    tablet(t);
    await t.pumpWidget(app(TemporadaPantalla(temporada: temporada, liga: liga, onCambio: (_) {})));
    await foto(t, 'temporada');
    await t.tap(find.text('Posiciones'));
    await foto(t, 'temporada-posiciones');
  });

  testWidgets('playoffs', (t) async {
    tablet(t);
    await t.pumpWidget(app(PlayoffsPantalla(temporada: playoffs, liga: liga, onCambio: (_) {})));
    await foto(t, 'playoffs');
    await t.pumpWidget(app(PlayoffsPantalla(key: UniqueKey(), temporada: fin, liga: liga, onCambio: (_) {})));
    await foto(t, 'playoffs-campeon');
  });

  testWidgets('inicio', (t) async {
    tablet(t);
    await t.pumpWidget(const DinastiaNbaApp());
    await foto(t, 'inicio');
  });

  testWidgets('perfil, álbum, partidas y playbook', (t) async {
    tablet(t);
    await t.pumpWidget(app(PerfilPantalla(jugador: liga.jugador)));
    await foto(t, 'perfil');
    await t.pumpWidget(app(AlbumPantalla(catalogo: catalogo, onPerfil: (_) {})));
    await foto(t, 'album');
    await t.pumpWidget(app(PartidasPantalla(db: null, onContinuar: (_) {}, cargar: () async => [fin, temporada])));
    await foto(t, 'partidas');
    await t.pumpWidget(
      app(
        PlaybookPantalla(
          temporada: Temporada(id: 'p', franquiciaUsuarioId: 'CHI', plantel: plantel),
          onConfirmar: (_) {},
        ),
      ),
    );
    await foto(t, 'playbook');
  });
}
