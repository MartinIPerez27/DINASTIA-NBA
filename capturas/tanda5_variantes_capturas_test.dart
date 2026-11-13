// Tanda 5: variantes de la temporada (Leyenda única, Extremo, Espejo, Desafío del día), con
// tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/variantes.dart';
import 'package:dinastia_nba/presentation/modos/modos.dart';
import 'package:dinastia_nba/presentation/modos/variantes.dart';
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
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });

  void tel(WidgetTester t, {double alto = 900}) {
    t.view.physicalSize = Size(412, alto) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home, {String franquicia = 'CHI'}) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId(franquicia)), home: home);

  Future<void> foto(WidgetTester t, String nombre) async {
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/t5-variantes-$nombre.png'));
  }

  testWidgets('leyenda única', (t) async {
    tel(t, alto: 1000);
    final opciones = Variantes(catalogo, azar: Random(3)).leyendasParaElegir();
    await t.pumpWidget(
      app(
        Scaffold(
          body: SafeArea(
            child: SelectorLeyenda(opciones: opciones, onElegir: (_) {}),
          ),
        ),
      ),
    );
    await foto(t, 'leyenda');
  });

  testWidgets('extremo', (t) async {
    tel(t, alto: 640);
    await t.pumpWidget(
      app(
        Scaffold(
          body: SafeArea(
            child: IntroVariante(
              modo: ModoJuego.extremo,
              puntos: const [
                'Sin fichas para volver a tirar: lo que sale, sale.',
                'Dificultad Difícil fija (en Leyenda, con estas lesiones, no se puede jugar).',
                'Lesiones el doble de frecuentes y un 50 % más largas.',
                'Una sola partida a la vez: si quedás afuera de los playoffs o te eliminan, está perdida.',
                'Si salís campeón: +1000 XP, +400 monedas y el logro Sobreviviente.',
              ],
              boton: 'ACEPTO EL RIESGO',
              onConfirmar: () {},
            ),
          ),
        ),
      ),
    );
    await foto(t, 'extremo');
  });

  testWidgets('desafío del día', (t) async {
    tel(t, alto: 640);
    final dia = DateTime(2026, 11, 13);
    final f = Variantes.franquiciaDelDia(dia, franquicias);
    await t.pumpWidget(
      app(
        Scaffold(
          body: SafeArea(
            child: IntroVariante(
              modo: ModoJuego.desafioDelDia,
              puntos: [
                'Hoy dirigís a los ${f.nombreCompleto}, con draft de ${Variantes.modoDelDia(dia).nombre}.',
                'Mismas tiradas, mismos sobres y mismos rivales para todos los que lo jueguen hoy.',
                'Dificultad Normal y 3 fichas para volver a tirar. Un solo intento por día.',
                'Tu puntaje son las victorias de la temporada regular.',
              ],
              extra: DesafioDelDiaEncabezado(fecha: dia, desafios: const {'20261110': 49, '20261112': 61}),
              boton: 'JUGAR EL DESAFÍO DE HOY',
              onConfirmar: () {},
            ),
          ),
        ),
        franquicia: f.id,
      ),
    );
    await foto(t, 'dia');
  });

  testWidgets('espejo', (t) async {
    tel(t, alto: 1150);
    final v = Variantes(catalogo, azar: Random(12));
    final tuyo = v.alAzar(Dificultad.dificil);
    final ia = v.alAzar(Dificultad.normal);
    await t.pumpWidget(app(EspejoRevelado(tuyo: tuyo, ia: ia, onSeguir: () {})));
    await foto(t, 'espejo');
  });

  testWidgets('menú de modos', (t) async {
    tel(t, alto: 1500);
    await t.pumpWidget(app(ModosPantalla(onElegir: (_) {})));
    await foto(t, 'menu');
  });

  test('temporada de ejemplo serializa el modo', () {
    const x = Temporada(id: 'a', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.soloEntrenador);
    expect(Temporada.fromJson(x.toJson()).modoJuego, ModoJuego.soloEntrenador);
  });
}
