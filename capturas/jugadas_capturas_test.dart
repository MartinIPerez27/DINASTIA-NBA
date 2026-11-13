// Jugadas nuevas del partido en vivo (falta en ataque, infracción, lanzamiento con la chicharra,
// salto entre dos, tapón): tres cuadros de cada coreografía, con tipografías reales (no corre en CI).
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/relator.dart';
import 'package:dinastia_nba/presentation/partido/cancha_partido.dart';
import 'package:dinastia_nba/presentation/partido/coreografia.dart';
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
  final jugadores = {for (final j in catalogo) j.id: j};
  final liga = Liga(catalogo, franquicias, azar: Random(12));
  late Temporada temporada;
  // Clase de jugada → (coreografía, local atacaba).
  final buscadas = <String, (Coreografia, bool)>{};
  bool quiero(EventoPartido e) => switch (e) {
    EventoPartido(perdida: TipoPerdida.carga) => !buscadas.containsKey('carga'),
    EventoPartido(perdida: TipoPerdida.campoAtras || TipoPerdida.tresSegundos) => !buscadas.containsKey('infraccion'),
    EventoPartido(desdeLejos: true) => !buscadas.containsKey('chicharra'),
    EventoPartido(tipo: TipoEvento.salto) => !buscadas.containsKey('salto'),
    EventoPartido(taponado: true) => !buscadas.containsKey('tapon'),
    _ => false,
  };
  String clase(EventoPartido e) => switch (e) {
    EventoPartido(perdida: TipoPerdida.carga) => 'carga',
    EventoPartido(perdida: TipoPerdida.campoAtras || TipoPerdida.tresSegundos) => 'infraccion',
    EventoPartido(desdeLejos: true) => 'chicharra',
    EventoPartido(tipo: TipoEvento.salto) => 'salto',
    _ => 'tapon',
  };

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
    temporada = liga.iniciar(Temporada(id: 'cj', franquiciaUsuarioId: 'LAL', plantel: p, tacticaConfirmada: true));
    for (var g = 0; g < 80 && buscadas.length < 5; g++) {
      final m = liga.motor(temporada, temporada.calendario[g], azar: Random(900 + g));
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
        if (quiero(e)) buscadas[clase(e)] = (c, ataca);
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

  /// Momento clave de la jugada (0–1): tapón, silbato, pico del salto o mitad del vuelo.
  double clave(Coreografia c) {
    if (c.momentoTapon case final t?) return t;
    if (c.momentoSilbato case final t? when c.evento.tipo != TipoEvento.salto) return t;
    final ids = [c.evento.jugadorId, c.evento.defensorId].nonNulls;
    var mejor = 0.6, pico = 0.0;
    for (var k = 0; k <= 200; k++) {
      for (final id in ids) {
        final s = c.salto(id, k / 200);
        if (s > pico) (pico, mejor) = (s, k / 200);
      }
    }
    if (c.evento.desdeLejos) {
      for (var k = 0; k <= 200; k++) {
        if (c.enTiro(k / 200)) return k / 200 + 0.08;
      }
    }
    return mejor;
  }

  Widget cuadro(Coreografia c, bool atacaLocal, double t) {
    final (balon, altura, poseedor) = c.balon(t);
    return SizedBox(
      width: 300,
      height: 330,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: CanchaPartidoPainter(
            franquicia: franquiciaPorId('LAL'),
            colorLed: const Color(0xFFFDB927),
            camaraY: c.foco(t),
            camaraX: Cancha94.ancho / 2 + (balon.dx - Cancha94.ancho / 2) * 0.7,
            zoom: c.zoom(t),
            balon: balon,
            alturaBalon: altura,
            fichas: [
              for (final (lista, local) in [(c.atacantes, atacaLocal), (c.defensores, !atacaLocal)])
                for (final j in lista)
                  Ficha(
                    posicion: c.posicion(j.id, t),
                    relleno: local ? const Color(0xFF552583) : const Color(0xFFEEEEEE),
                    texto: local ? Colors.white : Colors.black,
                    etiqueta: j.iniciales,
                    conBalon: poseedor == j.id,
                    nombre: poseedor == j.id ? j.nombre.split(' ').last.toUpperCase() : null,
                    salto: c.salto(j.id, t),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('cinco jugadas nuevas, tres cuadros cada una', (t) async {
    t.view.physicalSize = const Size(960, 2080) * 1.5;
    t.view.devicePixelRatio = 1.5;
    addTearDown(t.view.reset);
    expect(buscadas.keys, containsAll(['carga', 'infraccion', 'chicharra', 'salto', 'tapon']));
    final relator = Relator(azar: Random(2));
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final nombre in ['carga', 'infraccion', 'chicharra', 'salto', 'tapon']) ...[
                  Text(
                    '${nombre.toUpperCase()} · ${relator.frase(buscadas[nombre]!.$1.evento, jugadores)}',
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final d in [-0.18, 0.0, 0.14]) ...[
                        cuadro(
                          buscadas[nombre]!.$1,
                          buscadas[nombre]!.$2,
                          (clave(buscadas[nombre]!.$1) + d).clamp(0.0, 1.0),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/jugadas-todas.png'));
  });
}
