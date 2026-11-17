// Decisiones en vivo (hoja de decisión, ajustes, entretiempo, resumen) en teléfono y tablet, con las
// tipografías reales (no corre en CI). Salida: capturas/salida/dec-*.png
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/decisiones_partido.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/presentation/pantallas/partido_pantalla.dart';
import 'package:dinastia_nba/presentation/partido/decisiones.dart';
import 'package:dinastia_nba/presentation/partido/sonido_partido.dart';
import 'package:dinastia_nba/presentation/partido/voz_relator.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/decisiones_util.dart';

Future<void> _fuente(String familia, List<String> archivos) async {
  final loader = FontLoader(familia);
  for (final a in archivos) {
    loader.addFont(Future.value(ByteData.sublistView(File(a).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
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
  });

  void tablet(WidgetTester t) {
    t.view.physicalSize = const Size(1340, 900) * 1.8;
    t.view.devicePixelRatio = 1.8;
    addTearDown(t.view.reset);
  }

  void telefono(WidgetTester t, {Size tam = const Size(412, 915)}) {
    t.view.physicalSize = tam * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  MotorPartido motor({int semilla = 4}) => MotorPartido(
    local: equipoDe(armarPlantel((j) => j.media >= 80 && j.franquiciaId == 'CHI' || j.media >= 84, 1), id: 'CHI'),
    visitante: equipoDe(armarPlantel((j) => j.media >= 80, 2), id: 'BOS'),
    usuarioLocal: true,
    azar: Random(semilla),
  );

  Widget pantalla(MotorPartido m) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: temaFranquicia(franquiciaPorId('CHI')),
    home: PartidoPantalla(
      motor: m,
      usuarioLocal: true,
      franquiciaUsuario: franquiciaPorId('CHI'),
      identidadLocal: franquiciaPorId('CHI'),
      identidadVisitante: franquiciaPorId('BOS'),
      onTerminado: (_) {},
    ),
  );

  Future<void> foto(WidgetTester t, String nombre) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/dec-$nombre.png'));
  }

  MotorPartido escena(int cuarto, double reloj, int p, int r, {bool ataca = true}) =>
      motor()
        ..arrancarEn(cuarto: cuarto, reloj: reloj, puntosLocal: p, puntosVisitante: r, ataqueLocal: ataca, energia: 80);

  for (final (nombre, preparar) in <(String, void Function(WidgetTester))>[
    ('telefono', (t) => telefono(t)),
    ('telefono-chico', (t) => telefono(t, tam: const Size(360, 700))),
    ('tablet', tablet),
  ]) {
    testWidgets('decisión: remontada ($nombre)', (t) async {
      preparar(t);
      await t.pumpWidget(pantalla(escena(3, 500, 50, 72)));
      await foto(t, '$nombre-remontada');
    });

    testWidgets('decisión: falta intencional ($nombre)', (t) async {
      preparar(t);
      await t.pumpWidget(pantalla(escena(4, 20, 90, 88)));
      await foto(t, '$nombre-falta-intencional');
    });

    testWidgets('decisión: último tiro y ajustes ($nombre)', (t) async {
      preparar(t);
      await t.pumpWidget(pantalla(escena(2, 15, 50, 50)));
      await foto(t, '$nombre-ultimo-tiro');
      await t.tap(find.text('SEGUIR IGUAL'));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text('Ajustes'));
      await t.pump(const Duration(milliseconds: 300));
      await foto(t, '$nombre-ajustes');
    });

    testWidgets('entretiempo ($nombre)', (t) async {
      preparar(t);
      await t.pumpWidget(pantalla(motor(semilla: 9)));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.tap(find.text('x4'));
      var vistos = 0;
      for (var i = 0; i < 6000 && find.text('ENTRETIEMPO').evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 300));
        if (find.text('SEGUIR IGUAL').evaluate().isNotEmpty) {
          vistos++;
          await t.tap(find.text('SEGUIR IGUAL'));
        }
      }
      expect(find.text('ENTRETIEMPO'), findsOneWidget);
      // ignore: avoid_print
      print('$nombre: decisiones ignoradas en el 1.º tiempo: $vistos');
      await foto(t, '$nombre-entretiempo');
      await t.drag(find.byType(ListView).last, const Offset(0, -500));
      await t.pump(const Duration(milliseconds: 300));
      await foto(t, '$nombre-entretiempo-ajustes');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  testWidgets('resumen de decisiones en el pospartido', (t) async {
    telefono(t);
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: ResumenDecisiones(
                registro: [
                  RegistroDecision(
                    tipo: TipoDecision.parcialContra,
                    cuarto: 2,
                    reloj: 301,
                    opcion: 'Zona 2-3',
                    aviso: 'Zona 2-3 cortó la racha: ellos 2 de 9 (14-6 en 3 min). Ayudó (≈ +6).',
                    impacto: 6,
                    veredicto: Veredicto.ayudo,
                  ),
                  RegistroDecision(
                    tipo: TipoDecision.tiradorEncendido,
                    cuarto: 3,
                    reloj: 410,
                    opcion: 'Aislar a Jordan',
                    aviso: 'Con Jordan como foco: 18 pts en total (9-11 en 3 min). No salió: ≈ -3.',
                    impacto: -3,
                    veredicto: Veredicto.empeoro,
                  ),
                  RegistroDecision(tipo: TipoDecision.faltas, cuarto: 3, reloj: 200),
                  RegistroDecision(
                    tipo: TipoDecision.ultimoTiro,
                    cuarto: 2,
                    reloj: 12,
                    opcion: 'Triple de Curry',
                    aviso: 'Triple buscado a Curry: ¡entró! +3.',
                    veredicto: Veredicto.ayudo,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await foto(t, 'resumen');
  });
}
