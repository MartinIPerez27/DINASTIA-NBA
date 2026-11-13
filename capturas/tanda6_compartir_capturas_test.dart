// Tanda 6: tarjetas para compartir y código de reto, con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/dinastia.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:dinastia_nba/domain/reto.dart';
import 'package:dinastia_nba/presentation/compartir/tarjeta_compartir.dart';
import 'package:dinastia_nba/presentation/modos/reto.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(6));
  late Temporada enCurso, campeon, reto, racha, dinastia;

  Plantel mejores(String franquicia) {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == franquicia).toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return p;
  }

  Temporada jugarRegular(Temporada t) {
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
    }
    return liga.simularOtrosHasta(t, 1 << 30);
  }

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);

    final base = Temporada(
      id: 'c6',
      franquiciaUsuarioId: 'CHI',
      plantel: mejores('CHI'),
      tacticaConfirmada: true,
      modo: ModoDraft.ruleta,
      datosModo: Reto.datosNuevos(3, azar: Random(8)),
    );
    var t = Reto.ligaPara(liga, base).iniciar(base);
    for (var i = 0; i < 31; i++) {
      t = liga.simularProximo(t);
    }
    enCurso = t;
    final regular = jugarRegular(t);
    for (var i = 0; i < 20; i++) {
      final fin = Liga(catalogo, franquicias, azar: Random(i)).simularRestoPlayoffs(regular);
      campeon = fin;
      if (fin.campeonId == 'CHI') break;
    }

    // Reto de un amigo que hizo 64-18, con la temporada regular terminada.
    final codigo = CodigoReto(
      semilla: 5150,
      franquiciaId: 'LAL',
      modo: ModoDraft.cartas,
      regla: ReglaDraft.libre,
      dificultad: Dificultad.dificil,
      victorias: 64,
      campeon: true,
    );
    final aceptada = Reto.aceptar(codigo, id: 'reto').copyWith(plantel: mejores('LAL'), tacticaConfirmada: true);
    reto = jugarRegular(Reto.ligaPara(liga, aceptada).iniciar(aceptada));

    final modos = ModosEscalera(liga, azar: Random(4));
    var r = modos.iniciar(
      Temporada(
        id: 'racha',
        franquiciaUsuarioId: 'BOS',
        plantel: mejores('BOS'),
        tacticaConfirmada: true,
        modoJuego: ModoJuego.racha,
      ),
    );
    while (!Escalera.de(r).terminada) {
      r = modos.simularPartido(r);
    }
    racha = r;

    dinastia = Temporada(
      id: 'din-t4',
      franquiciaUsuarioId: 'SAS',
      plantel: mejores('SAS'),
      tacticaConfirmada: true,
      modoJuego: ModoJuego.dinastia,
      datosModo: const EstadoDinastia(
        raiz: 'din',
        numero: 4,
        historial: [
          TemporadaPasada(numero: 1, victorias: 61, derrotas: 21, resultado: 'Campeón', campeon: true),
          TemporadaPasada(numero: 2, victorias: 58, derrotas: 24, resultado: 'Las Finales', campeon: false),
          TemporadaPasada(numero: 3, victorias: 66, derrotas: 16, resultado: 'Campeón', campeon: true),
        ],
      ).toJson(),
    );
    dinastia = jugarRegular(liga.iniciar(dinastia));
  });

  Future<void> tarjeta(WidgetTester tester, Temporada t, String nombre) async {
    tester.view.physicalSize = const Size(TarjetaCompartir.ancho, TarjetaCompartir.alto) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: TarjetaCompartir(temporada: t, liga: liga),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(TarjetaCompartir), matchesGoldenFile('salida/t6-compartir-$nombre.png'));
  }

  testWidgets('temporada en curso con código de reto', (t) => tarjeta(t, enCurso, 'curso'));
  testWidgets('temporada terminada (campeón si se dio)', (t) => tarjeta(t, campeon, 'campeon'));
  testWidgets('reto de un amigo', (t) => tarjeta(t, reto, 'reto'));
  testWidgets('racha infinita', (t) => tarjeta(t, racha, 'racha'));
  testWidgets('dinastía', (t) => tarjeta(t, dinastia, 'dinastia'));

  testWidgets('vista previa para compartir', (tester) async {
    tester.view.physicalSize = const Size(412, 900) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: CompartirPantalla(temporada: enCurso, liga: liga),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await expectLater(find.byType(CompartirPantalla), matchesGoldenFile('salida/t6-compartir-pantalla.png'));
  });

  testWidgets('ingresar código de reto', (tester) async {
    tester.view.physicalSize = const Size(412, 700) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final codigo = Reto.codigoDe(campeon)!.codificar();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: Scaffold(
          body: SafeArea(
            child: IngresarCodigoReto(inicial: codigo, onAceptar: (_) {}),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('salida/t6-compartir-codigo.png'));
  });
}
