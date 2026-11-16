import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/main.dart';
import 'package:dinastia_nba/presentation/pantallas/album_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/inicio_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/escala_texto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ajustesApp.value = const Ajustes(tutorialVisto: true));

  void pantalla(WidgetTester t, Size s, {double escala = 1}) {
    t.view.physicalSize = s * 2;
    t.view.devicePixelRatio = 2;
    t.platformDispatcher.textScaleFactorTestValue = escala;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  Widget inicio({Map<String, VoidCallback>? toques}) {
    final f = franquiciaPorId('CHI');
    VoidCallback? cb(String k) => toques == null ? () {} : () => toques[k] = () {};
    return MaterialApp(
      theme: temaFranquicia(f),
      home: InicioPantalla(
        franquicias: franquicias,
        enfocada: f,
        onEnfocar: (_) {},
        onDirigir: (_) {},
        onPerfil: cb('perfil'),
        onPartidas: cb('partidas'),
        onAjustes: cb('ajustes'),
        onAlbum: cb('album'),
        onModos: cb('modos'),
        onMisiones: cb('misiones'),
      ),
    );
  }

  testWidgets('Inicio dibuja el acceso a Álbum, Misiones, Perfil, Partidas, Ajustes y Modos', (t) async {
    pantalla(t, const Size(360, 640));
    final toques = <String, VoidCallback>{};
    await t.pumpWidget(inicio(toques: toques));
    for (final (clave, buscar) in <(String, Finder)>[
      ('album', find.byTooltip('Álbum y tienda')),
      ('misiones', find.byTooltip('Misiones y pase')),
      ('partidas', find.byTooltip('Partidas guardadas')),
      ('ajustes', find.byTooltip('Ajustes')),
      ('perfil', find.bySemanticsLabel(RegExp('Tu carrera'))),
      ('modos', find.text('MODOS DE JUEGO')),
    ]) {
      expect(buscar, findsOneWidget, reason: clave);
      await t.tap(buscar);
      expect(toques.containsKey(clave), isTrue, reason: 'tocar $clave llama a su callback');
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('el botón del Álbum abre el Álbum y la Tienda de la app', (t) async {
    pantalla(t, const Size(412, 915));
    await t.pumpWidget(const DinastiaNbaApp());
    await t.tap(find.byTooltip('Álbum y tienda'));
    // El catálogo grande se lee en otro isolate.
    for (var i = 0; i < 20 && find.byType(AlbumPantalla).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlbumPantalla), findsOneWidget);
    expect(find.text('Tienda'), findsWidgets);
  });

  testWidgets('"Modos de juego" abre el menú nuevo y desde ahí, un submenú', (t) async {
    pantalla(t, const Size(412, 915));
    await t.pumpWidget(const DinastiaNbaApp());
    await t.tap(find.text('MODOS DE JUEGO'));
    await t.pumpAndSettle();
    expect(find.text('¿A qué jugamos?'), findsOneWidget);
    expect(find.text('CARRERA'), findsOneWidget);
    await t.tap(find.text('MINIJUEGOS'));
    await t.pumpAndSettle();
    expect(find.text('Perfil perfecto'), findsOneWidget);
  });

  for (final tam in [const Size(360, 640), const Size(412, 915), const Size(1280, 800)]) {
    for (final escala in [1.0, 1.5, 2.0]) {
      testWidgets('Inicio sin desbordes a ${tam.width.toInt()}×${tam.height.toInt()} con letra ×$escala', (t) async {
        pantalla(t, tam, escala: escala);
        await t.pumpWidget(inicio());
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('la app topa la escala de texto en ×1,5', (t) async {
    pantalla(t, const Size(360, 640), escala: 2);
    late double visto;
    await t.pumpWidget(
      MaterialApp(
        builder: conTopeEscalaTexto,
        home: Builder(
          builder: (c) {
            visto = MediaQuery.textScalerOf(c).scale(10) / 10;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(visto, topeEscalaTexto);
  });

  testWidgets('Inicio cumple la guía de contraste de texto con el equipo por defecto', (t) async {
    pantalla(t, const Size(412, 915));
    final guia = t.ensureSemantics();
    await t.pumpWidget(inicio());
    await expectLater(t, meetsGuideline(textContrastGuideline));
    guia.dispose();
  });
}
