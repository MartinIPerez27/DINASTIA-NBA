// Tanda 5: Dinastía y Reescribí la historia (receso, línea de tiempo, playoffs) con tipografías reales.
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/dinastia.dart';
import 'package:dinastia_nba/presentation/modos/carrera.dart';
import 'package:dinastia_nba/presentation/modos/carrera_pantallas.dart';
import 'package:dinastia_nba/presentation/pantallas/playoffs_pantalla.dart';
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
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  final carrera = CarreraDinastia(liga);
  late Temporada terminada, tercera;

  Temporada jugar(Temporada t) {
    var x = liga.iniciar(t.copyWith(tacticaConfirmada: true));
    x = carrera.rivalesDeEpoca(x);
    while (liga.proximoDelUsuario(x) != null) {
      x = liga.simularProximo(x);
    }
    x = liga.simularOtrosHasta(x, 1 << 30);
    return liga.simularRestoPlayoffs(x);
  }

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    // Reescribí la historia con los Celtics de los 80: tres temporadas.
    var t = carrera.reescribir(id: 'cap', franquiciaId: 'BOS', epoca: Epoca.anios80, dificultad: Dificultad.normal);
    for (var i = 0; i < 2; i++) {
      final fin = jugar(t);
      final r = carrera.receso(fin, nombreFranquicia);
      t = carrera.siguiente(fin, r, {for (final e in r.opciones.entries) e.key: e.value.first});
    }
    tercera = t;
    // La tercera, terminada y con el plantel ya veterano (para que haya retiros y novatos).
    final fin = jugar(tercera);
    final estado = EstadoDinastia.de(fin);
    terminada = fin.copyWith(
      datosModo: EstadoDinastia(
        raiz: estado.raiz,
        numero: estado.numero,
        edades: {for (final j in fin.plantel.jugadores) j.id: 35},
        historial: estado.historial,
        epoca: estado.epoca,
        temporadasEnEpoca: estado.temporadasEnEpoca,
      ).toJson(),
    );
  });

  void tel(WidgetTester t, {double alto = 1500}) {
    t.view.physicalSize = Size(412, alto) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('BOS')), home: home);

  Future<void> fotos(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
  }

  testWidgets('receso: retiros, envejecimiento y draft de novatos', (t) async {
    tel(t, alto: 2600);
    Temporada? nueva;
    await t.pumpWidget(
      app(
        RecesoPantalla(
          temporada: terminada,
          carrera: carrera,
          nombreDe: nombreFranquicia,
          onArrancar: (n) async => nueva = n,
        ),
      ),
    );
    await t.pump();
    await fotos(t);
    final receso = carrera.receso(terminada, nombreFranquicia);
    for (final e in receso.opciones.entries) {
      final f = find.text(e.value.first.nombre.toUpperCase());
      final carta = f.evaluate().isNotEmpty ? f : find.text(e.value.first.nombre);
      await t.ensureVisible(carta.first);
      await t.tap(carta.first);
      await t.pump(const Duration(milliseconds: 400));
    }
    await t.scrollUntilVisible(find.textContaining('ARRANCAR'), -400, scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await t.pump();
    await expectLater(find.byType(RecesoPantalla), matchesGoldenFile('salida/t5-dinastia-receso.png'));
    await t.scrollUntilVisible(find.textContaining('ARRANCAR'), 400, scrollable: find.byType(Scrollable).first);
    await t.tap(find.textContaining('ARRANCAR'));
    await t.pump();
    expect(nueva, isNotNull);
    expect(EstadoDinastia.de(nueva!).numero, 4);
  });

  testWidgets('historia narrada', (t) async {
    tel(t);
    await t.pumpWidget(app(HistoriaDinastiaPantalla(temporada: tercera)));
    await t.pump();
    await expectLater(find.byType(HistoriaDinastiaPantalla), matchesGoldenFile('salida/t5-dinastia-historia.png'));
  });

  testWidgets('playoffs terminados: siguiente temporada', (t) async {
    tel(t, alto: 900);
    await t.pumpWidget(
      app(
        PlayoffsPantalla(
          temporada: terminada,
          liga: liga,
          onCambio: (_) {},
          acciones: [IconButton(onPressed: () {}, icon: const Icon(Icons.timeline))],
          onSiguienteTemporada: (_) {},
        ),
      ),
    );
    await t.pump();
    expect(find.text('SIGUIENTE TEMPORADA'), findsOneWidget);
    await expectLater(find.byType(PlayoffsPantalla), matchesGoldenFile('salida/t5-dinastia-playoffs.png'));
  });
}
