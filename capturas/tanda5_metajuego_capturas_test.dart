// Tanda 5: misiones, pase de temporada, vestuario, cancha retro y revancha (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/metajuego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/misiones.dart';
import 'package:dinastia_nba/main.dart';
import 'package:dinastia_nba/presentation/pantallas/misiones_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/temporada_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/vestuario_pantalla.dart';
import 'package:dinastia_nba/presentation/partido/cancha_partido.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/tema/vestuario.dart';
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
  final hoy = DateTime(2026, 11, 13);
  final chi = franquiciaPorId('CHI');
  late Temporada temporada;

  PerfilEntrenador perfil({Map<CategoriaCosmetico, Cosmetico> elegidos = const {}}) {
    final misiones = [
      for (final (i, m) in Misiones.generar(hoy).indexed)
        i == 0
            ? m.conProgreso(m.objetivo)
            : i == 3
            ? m.conProgreso(m.objetivo).comoReclamada
            : m.conProgreso(m.objetivo ~/ 3),
    ];
    return PerfilEntrenador(
      xp: PerfilEntrenador.xpParaNivel(9) + 200,
      monedas: 640,
      metajuego: Metajuego(
        misiones: misiones,
        pase: '2026-T4',
        puntosPase: 1730,
        nivelesReclamados: {1, 2, 3, 4, 5, 6},
        cosmeticos: {Cosmetico.uniformeAlternativo, Cosmetico.canchaSetentas, Cosmetico.ledVerde, Cosmetico.pelotaAba},
        elegidos: elegidos,
      ),
    );
  }

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    temporada = liga.iniciar(Temporada(id: 'c5', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    for (var i = 0; i < 4; i++) {
      temporada = liga.simularProximo(temporada);
    }
  });

  tearDown(() => perfilApp.value = const PerfilEntrenador());

  void tel(WidgetTester t, {double ancho = 412, double alto = 915}) {
    t.view.physicalSize = Size(ancho, alto) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) => MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(chi), home: home);

  Future<void> foto(WidgetTester t, String nombre, {Finder? de}) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(de ?? find.byType(MaterialApp).first, matchesGoldenFile('salida/t5-meta-$nombre.png'));
  }

  testWidgets('misiones y pase', (t) async {
    tel(t, alto: 1100);
    perfilApp.value = perfil();
    await t.pumpWidget(app(MisionesPantalla(franquicia: chi, onPerfil: (p) => perfilApp.value = p, ahora: () => hoy)));
    await foto(t, 'misiones');
    // Cobrar algo (la misión cumplida o un nivel del pase).
    final antes = perfilApp.value;
    await t.tap(find.text('COBRAR').first);
    await t.pump();
    expect(perfilApp.value.xp + perfilApp.value.monedas, greaterThan(antes.xp + antes.monedas));
  });

  testWidgets('vestuario con cancha de los 70 y pelota ABA', (t) async {
    tel(t, alto: 1500);
    perfilApp.value = perfil(
      elegidos: {
        CategoriaCosmetico.cancha: Cosmetico.canchaSetentas,
        CategoriaCosmetico.pelota: Cosmetico.pelotaAba,
        CategoriaCosmetico.uniforme: Cosmetico.uniformeAlternativo,
      },
    );
    await t.pumpWidget(app(VestuarioPantalla(franquicia: chi, onPerfil: (p) => perfilApp.value = p)));
    await foto(t, 'vestuario');
  });

  testWidgets('canchas: de fábrica, 70, cuadros y barrio', (t) async {
    tel(t, alto: 520);
    final variantes = [
      (Cosmetico.canchaModerna, Cosmetico.pelotaClasica, Cosmetico.uniformeTitular, Cosmetico.ledEquipo),
      (Cosmetico.canchaSetentas, Cosmetico.pelotaAba, Cosmetico.uniformeClasico, Cosmetico.ledAmbar),
      (Cosmetico.canchaCuadros, Cosmetico.pelotaDorada, Cosmetico.uniformeAlternativo, Cosmetico.ledHielo),
      (Cosmetico.canchaBarrio, Cosmetico.pelotaAba, Cosmetico.uniformeTitular, Cosmetico.ledVerde),
    ];
    for (final (i, (cancha, pelota, uniforme, led)) in variantes.indexed) {
      final p = PerfilEntrenador(
        xp: PerfilEntrenador.xpParaNivel(20),
        metajuego: Metajuego(
          cosmeticos: Cosmetico.values.toSet(),
          elegidos: {
            CategoriaCosmetico.cancha: cancha,
            CategoriaCosmetico.pelota: pelota,
            CategoriaCosmetico.uniforme: uniforme,
            CategoriaCosmetico.led: led,
          },
        ),
      );
      await t.pumpWidget(
        app(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: VistaPreviaVestuario(franquicia: chi, perfil: p),
            ),
          ),
        ),
      );
      await foto(t, 'cancha-$i');
    }
  });

  testWidgets('cancha completa en vivo: retro + ABA', (t) async {
    tel(t, alto: 760);
    final estilo = Vestuario.estiloDe(Cosmetico.canchaSetentas, Cosmetico.pelotaAba);
    await t.pumpWidget(
      app(
        Scaffold(
          backgroundColor: Colors.black,
          body: CustomPaint(
            size: Size.infinite,
            painter: CanchaPartidoPainter(
              franquicia: chi,
              estilo: estilo,
              colorLed: Vestuario.ledDe(Cosmetico.ledAmbar)!,
              cartel: 'CHICAGO · DINASTÍA 82-0',
              camaraY: 30,
              balon: const Offset(25, 25),
              alturaBalon: 0.6,
              fichas: [
                for (final (k, o) in [(1, const Offset(14, 20)), (2, const Offset(36, 18)), (3, const Offset(25, 32))])
                  Ficha(
                    posicion: o,
                    relleno: const Color(0xFFF1E6CC),
                    texto: Colors.black,
                    ribete: Color(chi.colorPrimario),
                    etiqueta: '$k',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await foto(t, 'vivo');
  });

  testWidgets('revancha en el próximo partido', (t) async {
    tel(t, alto: 700);
    final proximo = liga.proximoDelUsuario(temporada)!;
    final rival = proximo.localId == 'CHI' ? proximo.visitanteId : proximo.localId;
    perfilApp.value = PerfilEntrenador(
      metajuego: Metajuego(
        rivalidades: {
          rival: Rivalidad(
            franquiciaId: rival,
            eliminaciones: 1,
            derrotas: 4,
            ronda: RondaPlayoff.finalConferencia.name,
            temporadaId: 'vieja',
            temporadaNumero: 3,
          ),
        },
      ),
    );
    await t.pumpWidget(app(TemporadaPantalla(temporada: temporada, liga: liga, onCambio: (_) {})));
    await foto(t, 'revancha');
  });

  testWidgets('inicio a 360 con la bandera de misiones', (t) async {
    tel(t, ancho: 360, alto: 760);
    perfilApp.value = perfil();
    await t.pumpWidget(const DinastiaNbaApp());
    await foto(t, 'inicio-360');
  });
}
