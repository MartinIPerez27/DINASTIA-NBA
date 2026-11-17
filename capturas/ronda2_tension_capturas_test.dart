import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/historias.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/bitacora.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:dinastia_nba/domain/rivalidades.dart';
import 'package:dinastia_nba/domain/scouting.dart';
import 'package:dinastia_nba/domain/tension.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/ficha_rival.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:dinastia_nba/presentation/widgets/titulares.dart';
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

// Ronda 2: historias, ficha de rival, tensión y bitácora (teléfono y tablet). No corre en CI.
void main() {
  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  });
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  var p = const Plantel();
  for (final pos in Posicion.values) {
    p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final rivalJs = (catalogo.where((j) => j.franquiciaId == 'LAL').toList()..sort((a, b) => b.media.compareTo(a.media)))
      .take(6)
      .toList();
  RivalEscalera rival() => RivalEscalera(
    identidadId: 'LAL',
    etiqueta: '(Histórico)',
    cartaIds: {for (final (i, j) in rivalJs.indexed) Posicion.values[i]: j.id},
    tactica: const Tactica(),
    media: 88,
  );
  Cruce unico(bool gana, int a, int b) => Cruce(
    rival: rival(),
    titulo: 'Escalón 1 de 10',
    marcadores: [(a, b)],
    propias: gana ? 1 : 0,
    ajenas: gana ? 0 : 1,
  );

  for (final (nombre, tam) in [('tel', const Size(412, 1900)), ('tablet', const Size(1280, 1500))]) {
    testWidgets('ronda 2 tensión $nombre', (t) async {
      t.view.physicalSize = tam * 2.5;
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      var tt = liga.iniciar(Temporada(id: 'w', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
      for (var i = 0; i < 25; i++) {
        tt = liga.simularProximo(tt);
      }
      final hist = Historias.generar(
        tt,
        liga,
        nombre: (id) => franquiciaPorId(id == 'CHI' ? id : tt.rivales[id]!.identidadId).nombre,
      );
      final e = Escalera(
        cruces: [
          for (var i = 0; i < 6; i++) unico(true, 110, 100 + i),
          Cruce(rival: rival(), titulo: 'x'),
        ],
      );
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: temaFranquicia(franquiciaPorId('CHI')),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BannerTension(presion: presion(aGanar: 4, propias: 3, ajenas: 3, peso: 10)),
                const SizedBox(height: 10),
                FichaRival(
                  identidad: franquiciaPorId('LAL'),
                  nombre: 'Los Angeles Lakers (Histórico)',
                  scouting: FichaScouting.de(rivalJs, propios: p.jugadores.toList()),
                  tactica: const Tactica(),
                  jefe: true,
                  introJefe: 'La última puerta: el campeón que quiere cerrarte el camino al anillo.',
                  rivalidad: const RelatoRivalidad(
                    nivel: NivelRivalidad.malaSangre,
                    calor: 62,
                    frase: 'Los Lakers te sacaron en 6 el año pasado. Hay cuenta pendiente.',
                    fichas: ['1 eliminación', '2 series cerradas', 'Duelos: 4-9'],
                  ),
                  evento: const EventoCruce(
                    tipo: TipoEventoCruce.figuraLesionada,
                    titulo: 'BAJA EN EL RIVAL',
                    texto: 'Su figura llega tocada.',
                    efecto: 'Rival −2 de forma',
                    rivalMenos: 2,
                  ),
                  historial: 'Corrida: 6-0',
                ),
                const SizedBox(height: 10),
                TrasElPartido(historias: hist.take(2).toList(), resumen: 'Ganaste 110-100. Quedás 12-1.'),
                const SizedBox(height: 10),
                for (final h in hist.take(3)) ...[
                  TarjetaHistoria(historia: h, principal: h == hist.first),
                  const SizedBox(height: 8),
                ],
                BitacoraCorrida(entradas: Bitacora.de(e, (r) => r.etiqueta)),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/r2-tension-$nombre.png'));
    });
  }
}
