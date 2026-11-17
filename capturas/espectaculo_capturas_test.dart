// Espectáculo del partido en vivo: figuras animadas, cámara, tribuna, banco, técnicos, playoffs y
// tablet. Con tipografías reales (no corre en CI): flutter test capturas/espectaculo_capturas_test.dart --update-goldens
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/presentation/partido/cancha_partido.dart';
import 'package:dinastia_nba/presentation/partido/coreografia.dart';
import 'package:dinastia_nba/presentation/partido/escena_cancha.dart';
import 'package:dinastia_nba/presentation/partido/publico.dart';
import 'package:dinastia_nba/presentation/partido/repeticion.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
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
  final jugadores = <String, Jugador>{for (final j in catalogo) j.id: j};
  final liga = Liga(catalogo, franquicias, azar: Random(12));
  final buscadas = <String, (Coreografia, bool)>{};
  String? clase(EventoPartido e) {
    if (e.volcada && !buscadas.containsKey('volcada')) return 'volcada';
    if (e.taponado && !buscadas.containsKey('tapon')) return 'tapon';
    if (e.contraataque && e.convertido && !e.volcada && !buscadas.containsKey('contra')) return 'contra';
    if (e.tipo == TipoEvento.tiempoMuerto && !buscadas.containsKey('tiempo')) return 'tiempo';
    if (e.triple && e.convertido && !e.chicharra && !buscadas.containsKey('triple')) return 'triple';
    if (e.tipo == TipoEvento.libres && !buscadas.containsKey('libres')) return 'libres';
    return null;
  }

  late Temporada temporada;
  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'LAL').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    temporada = liga.iniciar(Temporada(id: 'es', franquiciaUsuarioId: 'LAL', plantel: p, tacticaConfirmada: true));
    for (var g = 0; g < 120 && buscadas.length < 6; g++) {
      final m = liga.motor(temporada, temporada.calendario[g], azar: Random(700 + g));
      final posiciones = <String, Offset>{};
      var balon = const Offset(25, 47);
      String? poseedor;
      var segunda = false;
      while (!m.terminado) {
        final e = m.siguiente();
        final ataca = switch (e.tipo) {
          TipoEvento.tiempoMuerto || TipoEvento.finCuarto || TipoEvento.finPartido => true,
          _ => e.local,
        };
        final cuarto = e.tipo == TipoEvento.finCuarto ? e.cuarto - 1 : e.cuarto;
        final c = Coreografia(
          evento: e,
          atacantes: List.of(m.enCancha(ataca)),
          defensores: List.of(m.enCancha(!ataca)),
          haciaArriba: ataca == (cuarto <= 2),
          desde: Map.of(posiciones),
          balonDesde: balon,
          poseedorDesde: poseedor,
          segundaOportunidad: segunda,
          saliente: e.tipo == TipoEvento.cambio ? liga.jugador(e.saleId ?? '') : null,
        );
        final k = clase(e);
        if (k != null) buscadas[k] = (c, ataca);
        for (final j in [...c.atacantes, ...c.defensores]) {
          posiciones[j.id] = c.posicion(j.id, 1);
        }
        if (c.saliente case final s?) posiciones.remove(s.id);
        balon = c.balon(1).$1;
        poseedor = c.poseedorFinal;
        segunda = e.tipo == TipoEvento.tiro && e.reboteOfensivo;
      }
    }
  });

  const equipaciones = Equipaciones(
    propio: Color(0xFF552583),
    textoPropio: Colors.white,
    ribetePropio: Color(0xFFFDB927),
    rival: Color(0xFFEEEEEE),
    textoRival: Colors.black,
    ribeteRival: Color(0xFF1D428A),
  );

  /// Momento vistoso de una jugada (0–1).
  double clave(Coreografia c) => c.momentoClimax ?? c.momentoSilbato ?? 0.55;

  Widget cuadro(String nombre, double t, Size tam, {bool playoffs = false, double excita = 0.8, double abuchea = 0}) {
    final (c, local) = buscadas[nombre]!;
    return SizedBox(
      width: tam.width,
      height: tam.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: cuadroDeCancha(
            coreo: c,
            t: t,
            atacaLocal: local,
            usuarioLocal: true,
            franquicia: franquiciaPorId('LAL'),
            equipaciones: equipaciones,
            jugadores: jugadores,
            colorLed: const Color(0xFFFDB927),
            estilo: const EstiloCancha(),
            plano: c.plano(t),
            cartel: '¡TRIPLE!',
            tiempo: 3.1 + t * 4,
            margenArriba: 0,
            margenAbajo: 0,
            ambiente: AmbienteCancha(
              publico: PublicoEstado(
                excitacion: excita,
                abucheo: abuchea,
                playoffs: playoffs,
                ola: playoffs ? 0.3 : -1,
                local: const Color(0xFF552583),
                visitante: const Color(0xFFCE1141),
              ),
              luzDramatica: playoffs ? 0.7 : 0,
              destello: excita > 0.9 ? 0.6 : 0,
              levantadoAtaque: excita > 0.9 ? 1 : 0,
              humo: 1,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> sacar(WidgetTester t, Widget hijo, String archivo, Size ventana) async {
    t.view.physicalSize = ventana * 1.5;
    t.view.devicePixelRatio = 1.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(8), child: hijo)),
      ),
    );
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(archivo));
  }

  testWidgets('teléfono: tiro, volcada, tapón, contraataque, tiempo muerto, playoffs', (t) async {
    expect(buscadas.keys, containsAll(['volcada', 'tapon', 'contra', 'tiempo', 'triple']));
    const tam = Size(300, 470);
    await sacar(
      t,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          cuadro('triple', (clave(buscadas['triple']!.$1) - 0.1).clamp(0, 1), tam),
          cuadro('volcada', clave(buscadas['volcada']!.$1), tam, excita: 1),
          cuadro('tapon', clave(buscadas['tapon']!.$1) + 0.03, tam),
          cuadro('contra', clave(buscadas['contra']!.$1) - 0.15, tam, excita: 0.3),
          cuadro('tiempo', 0.7, tam, excita: 0.4),
          cuadro('triple', clave(buscadas['triple']!.$1) + 0.02, tam, playoffs: true, excita: 1),
        ],
      ),
      'salida/espectaculo-telefono.png',
      const Size(960, 1000),
    );
  });

  testWidgets('tablet: volcada y playoffs a toda altura', (t) async {
    const tam = Size(470, 860);
    await sacar(
      t,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          cuadro('volcada', clave(buscadas['volcada']!.$1), tam, excita: 1),
          const SizedBox(width: 8),
          cuadro('libres', 0.55, tam, playoffs: true, excita: 0.5),
        ],
      ),
      'salida/espectaculo-tablet.png',
      const Size(1000, 880),
    );
  });

  testWidgets('repetición instantánea (volcada) en teléfono, en plena cámara lenta', (t) async {
    t.view.physicalSize = const Size(412, 700) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final (c, local) = buscadas['volcada']!;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: Scaffold(
          body: RepeticionEnVivo(
            destacada: Destacada(coreo: c, frase: 'x', puntaje: 7, atacaLocal: local, cuarto: 3, reloj: 200),
            franquicia: franquiciaPorId('LAL'),
            equipaciones: equipaciones,
            jugadores: jugadores,
            usuarioLocal: true,
            colorLed: const Color(0xFFFDB927),
            estilo: const EstiloCancha(),
            playoffs: true,
            onTerminar: () {},
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 3600));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/espectaculo-repeticion.png'));
    await t.pumpWidget(const SizedBox());
  });
}
