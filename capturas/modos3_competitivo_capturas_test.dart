// Divisiones, Conquista y Creador de torneos con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/competitivo.dart';
import 'package:dinastia_nba/presentation/modos/competitivo.dart';
import 'package:dinastia_nba/presentation/modos/elegir_alineacion.dart';
import 'package:dinastia_nba/presentation/modos/torneos.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(5));
  final album = {
    for (final j in catalogo)
      if (j.franquiciaId == 'CHI' || j.franquiciaId == 'BOS') j.id,
  };
  final cartas = mejorAlineacion([
    for (final j in catalogo)
      if (album.contains(j.id)) j,
  ])!;

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  void telefono(WidgetTester t) {
    t.view.physicalSize = const Size(412, 1500) * 2.5;
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

  Future<void> captura(WidgetTester t, String nombre) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-competitivo-$nombre.png'));
  }

  testWidgets('divisiones: a mitad de temporada y al terminarla', (t) async {
    telefono(t);
    final m = ModosCompetitivo(liga, azar: Random(6));
    var x = m.nuevaDivisiones(id: 'd', franquiciaId: 'CHI', dificultad: Dificultad.normal, cartas: cartas);
    for (var i = 0; i < 5; i++) {
      x = m.simularDivisiones(x);
    }
    await t.pumpWidget(app(DivisionesPantalla(temporada: x, liga: liga, onCambio: (_) {})));
    await t.pumpAndSettle();
    await captura(t, 'divisiones-mitad');
    x = m.simularTemporadaDivisiones(x);
    await t.pumpWidget(app(DivisionesPantalla(key: UniqueKey(), temporada: x, liga: liga, onCambio: (_) {})));
    await t.pumpAndSettle();
    await captura(t, 'divisiones-fin');
  });

  testWidgets('divisiones en tablet', (t) async {
    tablet(t);
    final m = ModosCompetitivo(liga, azar: Random(6));
    var x = m.nuevaDivisiones(id: 'd', franquiciaId: 'CHI', dificultad: Dificultad.dificil, cartas: cartas);
    for (var i = 0; i < 3; i++) {
      x = m.simularDivisiones(x);
    }
    await t.pumpWidget(app(DivisionesPantalla(temporada: x, liga: liga, onCambio: (_) {})));
    await t.pumpAndSettle();
    await captura(t, 'divisiones-tablet');
  });

  testWidgets('conquista: mapa con territorios y una batalla en curso', (t) async {
    telefono(t);
    final m = ModosCompetitivo(liga, azar: Random(9));
    var x = m.nuevaConquista(id: 'c', franquiciaId: 'CHI', dificultad: Dificultad.normal, cartas: cartas);
    final e = EstadoConquista.de(x)!.copyWith(
      conquistados: ['CHI', 'MIL', 'DET', 'CLE', 'IND', 'MIN', 'TOR', 'NYK', 'BOS'],
      victorias: 8,
      derrotas: 2,
      batallas: 10,
    );
    x = e.en(x);
    x = m.atacar(x, 'PHI');
    await t.pumpWidget(app(ConquistaPantalla(temporada: x, liga: liga, onCambio: (_) {})));
    await t.pumpAndSettle();
    await captura(t, 'conquista-batalla');
    await t.pumpWidget(
      app(ConquistaPantalla(key: UniqueKey(), temporada: m.cancelarAtaque(x), liga: liga, onCambio: (_) {})),
    );
    await t.pumpAndSettle();
    await captura(t, 'conquista-mapa');
  });

  testWidgets('conquista en tablet', (t) async {
    tablet(t);
    final m = ModosCompetitivo(liga, azar: Random(9));
    var x = m.nuevaConquista(id: 'c', franquiciaId: 'LAL', dificultad: Dificultad.normal, cartas: cartas);
    x = EstadoConquista.de(x)!
        .copyWith(
          conquistados: ['LAL', 'LAC', 'GSW', 'SAC', 'PHX', 'POR', 'UTA'],
          victorias: 6,
          derrotas: 1,
          batallas: 7,
        )
        .en(x);
    await t.pumpWidget(app(ConquistaPantalla(temporada: x, liga: liga, onCambio: (_) {})));
    await t.pumpAndSettle();
    await captura(t, 'conquista-tablet');
  });

  testWidgets('torneo: cuadro de eliminación con tu partido pendiente', (t) async {
    telefono(t);
    final m = ModosCompetitivo(liga, azar: Random(3));
    final usados = <int>{};
    final equipos = <EquipoTorneo>[];
    for (final id in ['BOS', 'LAL', 'GSW', 'MIA', 'SAS', 'DET', 'PHI', 'NYK', 'HOU', 'MIL', 'PHX']) {
      final r = m.esc.rivalTodosLosTiempos(id, usados)!;
      usados.addAll([for (final c in r.cartaIds.values) m.jugador(c)!.nbaPlayerId]);
      equipos.add(EquipoTorneo(nombre: '${franquiciaPorId(id).nombreCompleto} (Histórico)', rival: r));
    }
    equipos.add(
      EquipoTorneo(nombre: 'Mi equipo', rival: m.rivalDeAlineacion(cartas, 'CHI', '(mi equipo)'), usuario: true),
    );
    var x = m.nuevoTorneo(
      id: 'tt',
      franquiciaId: 'CHI',
      torneo: Torneo.crear(nombre: 'Copa Marcador', formato: FormatoTorneo.eliminacion, equipos: equipos, aGanar: 2),
    );
    x = m.simularCruceTorneo(x);
    await t.pumpWidget(app(TorneoPantalla(temporada: x, liga: liga, onCambio: (_) {}, onRepetir: (_) async {})));
    await t.pumpAndSettle();
    await captura(t, 'torneo-cuadro');
    await t.pumpWidget(
      app(
        TorneoPantalla(
          key: UniqueKey(),
          temporada: m.simularRestoTorneo(x),
          liga: liga,
          onCambio: (_) {},
          onRepetir: (_) async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await captura(t, 'torneo-campeon');
  });

  testWidgets('torneo: grupos + eliminación en tablet', (t) async {
    tablet(t);
    final m = ModosCompetitivo(liga, azar: Random(4));
    final usados = <int>{};
    final equipos = <EquipoTorneo>[];
    for (final id in ['BOS', 'LAL', 'GSW', 'MIA', 'SAS', 'DET', 'PHI', 'NYK', 'HOU', 'MIL']) {
      final r = m.esc.rivalTodosLosTiempos(id, usados)!;
      usados.addAll([for (final c in r.cartaIds.values) m.jugador(c)!.nbaPlayerId]);
      equipos.add(EquipoTorneo(nombre: franquiciaPorId(id).nombreCompleto, rival: r));
    }
    equipos.add(
      EquipoTorneo(nombre: 'Mi equipo', rival: m.rivalDeAlineacion(cartas, 'CHI', '(mi equipo)'), usuario: true),
    );
    equipos.add(EquipoTorneo(nombre: 'Utah Jazz', rival: m.esc.rivalTodosLosTiempos('UTA', usados)!));
    var x = m.nuevoTorneo(
      id: 'tg',
      franquiciaId: 'CHI',
      torneo: Torneo.crear(nombre: 'Mundialito', formato: FormatoTorneo.grupos, equipos: equipos),
    );
    x = m.simularTorneo(x);
    x = m.simularTorneo(x);
    await t.pumpWidget(app(TorneoPantalla(temporada: x, liga: liga, onCambio: (_) {}, onRepetir: (_) async {})));
    await t.pumpAndSettle();
    await captura(t, 'torneo-grupos-tablet');
  });

  testWidgets('armado del torneo y elegir equipo', (t) async {
    telefono(t);
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<Torneo>(
                  MaterialPageRoute(
                    builder: (_) => ConfigTorneoPantalla(
                      modos: ModosCompetitivo(liga, azar: Random(1)),
                      franquiciaId: 'CHI',
                      partidas: () async => const [],
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Completar a 16'));
    await t.pumpAndSettle();
    await captura(t, 'torneo-config');
    await t.tap(find.text('AGREGAR'));
    await t.pumpAndSettle();
    await captura(t, 'torneo-agregar');

    await t.pumpWidget(const SizedBox()); // se tira el navegador anterior
    await t.pumpWidget(
      app(
        ElegirAlineacionPantalla(
          key: UniqueKey(),
          pool: [
            for (final j in catalogo)
              if (album.contains(j.id)) j,
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('COMPLETAR CON LAS MEJORES'));
    await t.pumpAndSettle();
    await captura(t, 'elegir-equipo');
  });
}
