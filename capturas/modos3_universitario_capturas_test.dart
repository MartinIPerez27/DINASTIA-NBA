// Modo universitario con tipografías reales (no corre en CI).
import 'dart:io';

import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/universitario.dart';
import 'package:dinastia_nba/presentation/modos/modos.dart';
import 'package:dinastia_nba/presentation/modos/universitario.dart';
import 'package:dinastia_nba/presentation/modos/universitario_pantallas.dart';
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

JugadorCreado _c(String n, Posicion p) => JugadorCreado(
  nombre: n,
  posicion: p,
  rol: JugadorCreado.rolesDe(p).first,
  fuertes: const [Atributo.tiro, Atributo.iq, Atributo.defensa],
);

void main() {
  const sim = Universitario();
  const programa = Programa(nombre: 'Lago Azul', mote: 'Cóndores', color1: 1, color2: 3);
  final base = sim.nueva(
    semilla: 11,
    programa: programa,
    creados: [_c('Ana Pérez', Posicion.base), _c('Beto Ruiz', Posicion.pivot), _c('Cris Gómez', Posicion.alero)],
  );
  Temporada tem(EstadoUniv e) =>
      Temporada(id: 'u', franquiciaUsuarioId: 'DAL', modoJuego: ModoJuego.universitario, datosModo: e.aDatos());
  final contexto = ContextoModos(
    liga: () async => throw UnimplementedError(),
    db: null,
    navegador: GlobalKey<NavigatorState>(),
    guardar: (_) async {},
    abrirTemporada: (t, {reemplazar = false}) async {},
  );

  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  Future<void> captura(
    WidgetTester t,
    Widget w,
    String nombre, {
    Size tam = const Size(412, 1100),
    double dpr = 2.5,
  }) async {
    t.view.physicalSize = tam * dpr;
    t.view.devicePixelRatio = dpr;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: w));
    await t.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/$nombre.png'));
  }

  testWidgets('programa: nombre, mote y colores', (t) async {
    await captura(t, const ProgramaConfigPantalla(), 'm3-universitario-programa', tam: const Size(412, 900));
  });

  testWidgets('centro: pretemporada (teléfono)', (t) async {
    await captura(t, UniversitarioPantalla(temporada: tem(base), contexto: contexto), 'm3-universitario-inicio');
  });

  testWidgets('centro: media temporada, tabla y Top 25 (teléfono)', (t) async {
    final mitad = sim.simularJornadas(base, 15);
    await captura(t, UniversitarioPantalla(temporada: tem(mitad), contexto: contexto), 'm3-universitario-mitad');
    await t.tap(find.text('Top 25'));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-universitario-top25.png'));
  });

  testWidgets('centro: torneo y premios (tablet)', (t) async {
    final torneo = sim.simularRonda(sim.simularJornadas(base, 30));
    await captura(
      t,
      UniversitarioPantalla(temporada: tem(torneo), contexto: contexto),
      'm3-universitario-torneo-tablet',
      tam: const Size(1280, 800),
      dpr: 1.5,
    );
    final premios = sim.simularTorneo(sim.simularJornadas(base, 30));
    await captura(t, UniversitarioPantalla(temporada: tem(premios), contexto: contexto), 'm3-universitario-premios');
  });

  testWidgets('receso: draft, crecimiento y reclutas', (t) async {
    final receso = sim.cerrarTemporada(sim.simularTorneo(sim.simularJornadas(base, 30)));
    await captura(
      t,
      RecesoUnivPantalla(estado: receso, onTerminar: (_, _) {}),
      'm3-universitario-receso-tablet',
      tam: const Size(1280, 800),
      dpr: 1.5,
    );
    await captura(
      t,
      RecesoUnivPantalla(estado: receso, onTerminar: (_, _) {}),
      'm3-universitario-receso',
      tam: const Size(412, 900),
    );
  });

  testWidgets('historia después de dos temporadas (teléfono)', (t) async {
    var e = sim.cerrarTemporada(sim.simularTorneo(sim.simularJornadas(base, 30)));
    e = sim.cerrarReceso(e, declarados: {}, firmados: e.reclutas().take(2).toList());
    e = sim.cerrarTemporada(sim.simularTorneo(sim.simularJornadas(e, 30)));
    await captura(t, UniversitarioPantalla(temporada: tem(e), contexto: contexto), 'm3-universitario-historia');
    await t.tap(find.text('Historia'));
    await t.pump();
    await t.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-universitario-historia2.png'));
  });
}
