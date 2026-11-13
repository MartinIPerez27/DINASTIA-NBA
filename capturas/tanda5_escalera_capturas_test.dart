// Tanda 5: modos de escalera con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:dinastia_nba/presentation/modos/escalera.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(31));
  final modos = ModosEscalera(liga, azar: Random(12));
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  Temporada nueva(ModoJuego m) {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return modos.iniciar(
      Temporada(id: m.name, franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true, modoJuego: m),
    );
  }

  /// Gana el partido pendiente (reintenta la simulación hasta ganar).
  Temporada ganar(Temporada t) {
    for (var i = 0; i < 300; i++) {
      final m = modos.motor(t)..simularTodo();
      final local = m.usuarioLocal!;
      if ((local ? m.puntosLocal : m.puntosVisitante) > (local ? m.puntosVisitante : m.puntosLocal)) {
        return modos.registrar(t, m);
      }
    }
    return t;
  }

  Future<void> capturar(WidgetTester tester, Temporada t, String nombre, {double alto = 1400}) async {
    tester.view.physicalSize = Size(412, alto) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId(t.franquiciaUsuarioId)),
        home: EscaleraPantalla(temporada: t, liga: liga, onCambio: (_) {}),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t5-escalera-$nombre.png'));
  }

  testWidgets('racha', (tester) async {
    var t = nueva(ModoJuego.racha);
    for (var i = 0; i < 6; i++) {
      t = ganar(t);
    }
    await capturar(tester, t, 'racha');
  });

  testWidgets('camino con ventajas', (tester) async {
    var t = nueva(ModoJuego.caminoAlAnillo);
    t = ganar(t);
    t = modos.elegirVentaja(t, Escalera.de(t).ofrecidas.first);
    t = ganar(t);
    await capturar(tester, t, 'camino');
  });

  testWidgets('mejores equipos', (tester) async {
    var t = nueva(ModoJuego.mejoresEquipos);
    for (var i = 0; i < 5; i++) {
      t = ganar(t);
    }
    await capturar(tester, t, 'mejores');
  });

  testWidgets('mundial', (tester) async {
    var t = nueva(ModoJuego.mundial);
    t = ganar(t);
    await capturar(tester, t, 'mundial', alto: 1600);
  });

  testWidgets('escenario', (tester) async {
    final t = modos.nuevaDeEscenario(escenarioPorId('finales98')!, id: 'esc');
    await capturar(tester, t, 'escenario', alto: 1000);
  });

  testWidgets('final del camino', (tester) async {
    var t = nueva(ModoJuego.caminoAlAnillo);
    for (var i = 0; i < 40 && !Escalera.de(t).terminada; i++) {
      final e = Escalera.de(t);
      t = e.esperandoVentaja ? modos.elegirVentaja(t, e.ofrecidas.first) : ganar(t);
    }
    await capturar(tester, t, 'final', alto: 1100);
  });
}
