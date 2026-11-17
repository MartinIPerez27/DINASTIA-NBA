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
import 'package:flutter_test/flutter_test.dart';

import 'decisiones_util.dart';

void main() {
  setUpAll(() {
    SonidoPartido.habilitado = false;
    VozRelator.habilitado = false;
    JugadorAvatar.usarRed = false;
  });
  tearDown(() => ajustesApp.value = const Ajustes(tutorialVisto: true));

  MotorPartido escena(int cuarto, double reloj, int p, int r) => MotorPartido(
    local: equipoDe(armarPlantel((j) => j.media >= 80, 1), id: 'CHI'),
    visitante: equipoDe(armarPlantel((j) => j.media >= 80, 2), id: 'BOS'),
    usuarioLocal: true,
    azar: Random(4),
  )..arrancarEn(cuarto: cuarto, reloj: reloj, puntosLocal: p, puntosVisitante: r, ataqueLocal: true, energia: 80);

  Widget pantalla(MotorPartido m) => MaterialApp(
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

  void telefono(WidgetTester t, Size tam) {
    t.view.physicalSize = tam * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  for (final (nombre, tam) in [
    ('teléfono', const Size(412, 915)),
    ('teléfono chico', const Size(360, 640)),
    ('tablet', const Size(1340, 900)),
  ]) {
    testWidgets('la hoja de decisión frena el partido, muestra el porqué y se puede ignorar ($nombre)', (t) async {
      telefono(t, tam);
      final m = escena(3, 500, 50, 72);
      await t.pumpWidget(pantalla(m));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('REMONTADA'), findsOneWidget);
      expect(find.textContaining('Perdés por 22'), findsOneWidget);
      expect(find.text('SEGUIR IGUAL'), findsOneWidget);
      expect(find.textContaining('COSTO'), findsWidgets);
      expect(find.byType(TarjetaOpcion), findsAtLeastNWidgets(3));
      // El marcador sigue a la vista.
      expect(find.text('CHI'), findsWidgets);
      final puntos = m.puntosLocal + m.puntosVisitante;
      await t.pump(const Duration(seconds: 3));
      expect(m.puntosLocal + m.puntosVisitante, puntos, reason: 'mientras decidís, no se juega');
      await t.tap(find.text('SEGUIR IGUAL'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('REMONTADA'), findsNothing);
      expect(m.efecto(true), isNull, reason: 'ignorar no cambia nada');
    });
  }

  testWidgets('elegir una opción la aplica y queda a la vista con su tiempo', (t) async {
    telefono(t, const Size(412, 915));
    final m = escena(3, 500, 50, 72);
    await t.pumpWidget(pantalla(m));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byType(TarjetaOpcion).first);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(HojaDecision), findsNothing);
    expect(find.textContaining('en marcha'), findsOneWidget);
    expect(find.byType(ChipsEfectos), findsOneWidget);
  });

  testWidgets('si no tocás nada, se sigue igual cuando se acaba la espera', (t) async {
    telefono(t, const Size(412, 915));
    final m = escena(3, 500, 50, 72);
    await t.pumpWidget(pantalla(m));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(HojaDecision), findsOneWidget);
    await t.pump(const Duration(seconds: 15));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(HojaDecision), findsNothing);
    expect(m.efecto(true), isNull);
  });

  testWidgets('con las decisiones sugeridas apagadas el partido no se frena', (t) async {
    ajustesApp.value = const Ajustes(tutorialVisto: true, decisiones: false);
    telefono(t, const Size(412, 915));
    await t.pumpWidget(pantalla(escena(3, 500, 50, 72)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(HojaDecision), findsNothing);
    // El menú de ajustes sigue estando.
    await t.tap(find.text('Ajustes'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(HojaAjustes), findsOneWidget);
    expect(find.text('AJUSTES DEL ENTRENADOR'), findsOneWidget);
  });

  testWidgets('el menú de ajustes aplica un ajuste con costo', (t) async {
    ajustesApp.value = const Ajustes(tutorialVisto: true, decisiones: false);
    telefono(t, const Size(412, 915));
    final m = escena(2, 500, 40, 40);
    await t.pumpWidget(pantalla(m));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text('Ajustes'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('COSTO'), findsWidgets);
    await t.tap(find.text('ZONA 2-3'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(HojaAjustes), findsNothing);
    expect(m.efecto(true)?.defensa, isNotNull);
  });

  testWidgets('el resumen del pospartido cuenta las decisiones tomadas', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResumenDecisiones(
            registro: [
              RegistroDecision(
                tipo: TipoDecision.parcialContra,
                cuarto: 2,
                reloj: 300,
                opcion: 'Zona 2-3',
                aviso: 'Zona 2-3 cortó la racha: ellos 2 de 9.',
                impacto: 5,
                veredicto: Veredicto.ayudo,
              ),
              RegistroDecision(tipo: TipoDecision.faltas, cuarto: 3, reloj: 100),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Tus decisiones'), findsOneWidget);
    expect(find.textContaining('cortó la racha'), findsOneWidget);
    expect(find.textContaining('estimación'), findsOneWidget);
    expect(find.textContaining('Dejaste pasar 1'), findsOneWidget);
  });
}
