// Encuadre de fotos de archivo (Basketball-Reference) recortadas vs. headshots de la NBA, en las
// cartas reales. No corre en CI: necesita fotos de muestra en SCRATCH (ver más abajo) y simula la
// máscara de ML Kit con la distancia al color del fondo (ML Kit no corre en `flutter test`).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:dinastia_nba/core/recorte_fotos.dart';
import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_jugador.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:dinastia_nba/presentation/widgets/ficha_jugador.dart';
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

/// Carpeta con las muestras: {idBbref}.jpg (Basketball-Reference) y nba{playerId}.png (CDN).
final _muestras = Platform.environment['MUESTRAS_FOTOS'] ?? '';

/// Recorta una foto de Basketball-Reference con el mismo proceso que la app, pero con una máscara
/// aproximada (distancia al color del fondo, a la resolución original como la de ML Kit).
Future<File> _recortar(String idBbref) async {
  final bytes = File('$_muestras/$idBbref.jpg').readAsBytesSync();
  final imagen = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
  final w = imagen.width, h = imagen.height;
  final px = (await imagen.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  List<int> color(int x, int y) => [for (var k = 0; k < 3; k++) px[(y * w + x) * 4 + k]];
  final esquinas = [color(1, 1), color(w - 2, 1), color(1, h ~/ 3), color(w - 2, h ~/ 3)];
  final fondo = [for (var k = 0; k < 3; k++) esquinas.map((c) => c[k]).reduce((a, b) => a + b) / esquinas.length];
  final confianzas = [
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++)
        () {
          final c = color(x, y);
          final d = sqrt(List.generate(3, (k) => pow(c[k] - fondo[k], 2)).reduce((a, b) => a + b));
          return d > 45 ? 1.0 : 0.0; // binaria y dentada, como el peor caso
        }(),
  ];
  final escala = max(1.0, 480 / h);
  final ancho = (w * escala).round(), alto = (h * escala).round();
  final rgba = await agrandarParaRecorte(imagen, ancho, alto);
  final png = await recortarConMascara(rgba, ancho, alto, confianzas, w, h);
  final salida = File('capturas/salida/recorte-$idBbref.png')..writeAsBytesSync(png!);
  return salida;
}

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  setUpAll(() async {
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
  });
  tearDownAll(() => JugadorAvatar.imagenesDePrueba = null);

  testWidgets('fotos de archivo vs NBA', (t) async {
    if (_muestras.isEmpty) return;
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final recortes = <String, File>{};
    await t.runAsync(() async {
      for (final id in ['ewingpa01', 'moncrsi01', 'englial01', 'hardati01']) {
        recortes[id] = await _recortar(id);
      }
    });
    ImageProvider? archivo(String url) {
      if (url.contains('cdn.nba.com')) {
        final f = File('$_muestras/nba${url.split('/').last}');
        return f.existsSync() ? MemoryImage(f.readAsBytesSync()) : null;
      }
      final r = recortes[url.split('/').last.replaceAll('.jpg', '')];
      return r == null ? null : MemoryImage(r.readAsBytesSync());
    }

    final futuros = <String, Future<ImageProvider?>>{};
    JugadorAvatar.imagenesDePrueba = (url) => futuros.putIfAbsent(url, () => Future.value(archivo(url)));
    final cartas = [
      for (final id in [
        'ewingpa01-NYK-90',
        'jordami01-CHI-90',
        'moncrsi01-MIL-80',
        'jamesle01-CLE-10',
        'hardati01-MIA-90',
        'englial01-DEN-80',
      ])
        catalogo.firstWhere((j) => j.id == id),
    ];
    await t.runAsync(() async {
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: temaFranquicia(franquiciaPorId('NYK')),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final j in cartas.take(3))
                        SizedBox(width: 124, height: 210, child: CartaVertical(jugador: j)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final j in cartas.skip(2).take(2))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CartaJugador(jugador: j),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final j in [cartas[0], cartas[1]]) FichaJugador(jugador: j),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final j in cartas)
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: SizedBox(
                            width: 58,
                            height: 58,
                            child: ClipOval(
                              child: JugadorAvatar(
                                jugador: j,
                                franquicia: franquiciaPorId(j.franquiciaId),
                                recortar: true,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    // Las imágenes se decodifican fuera del reloj falso del test.
    await t.pump();
    final imagenes = find.byType(Image).evaluate().toList();
    debugPrint('imagenes: ${imagenes.length}');
    await t.runAsync(() async {
      // Las cargas que arrancaron en la zona falsa no terminan nunca: se reinician en la real.
      imageCache.clear();
      for (final e in imagenes) {
        await precacheImage((e.widget as Image).image, e).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('timeout ${(e.widget as Image).image}');
          },
        );
      }
    });
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await t.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/fotos-archivo.png'));
  });
}
