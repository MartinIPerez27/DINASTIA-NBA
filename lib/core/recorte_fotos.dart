import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_imagenes.dart';

final _recortes = <String, Future<File?>>{};
Future<void> _cola = Future.value();

/// Foto de archivo (Basketball-Reference, Wikipedia) sin fondo, como los recortes de la NBA.
/// El fondo se quita en el celular con ML Kit (gratis y sin internet: el modelo viene en la app)
/// y el PNG queda guardado, así cada foto se procesa una sola vez.
/// Devuelve null si no se pudo (sin persona clara en la foto, error, o plataforma sin ML Kit).
Future<File?> recorteSinFondo(String url) => _recortes.putIfAbsent(url, () {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return Future.value();
  // De a una: la grilla de la ruleta no dispara decenas de segmentaciones a la vez.
  final resultado = _cola.then((_) => _recortar(url));
  _cola = resultado.then((_) {}, onError: (_) {});
  return resultado;
});

Future<File?> _recortar(String url) async {
  SelfieSegmenter? segmentador;
  try {
    final carpeta = Directory('${(await getApplicationSupportDirectory()).path}/recortes');
    final destino = File('${carpeta.path}/${_clave(url)}.png');
    final fallido = File('${carpeta.path}/${_clave(url)}.sin');
    if (await destino.exists()) return destino;
    if (await fallido.exists()) return null;
    await carpeta.create(recursive: true);

    final original = await cacheHeadshots.getSingleFile(url);
    final codec = await ui.instantiateImageCodec(await original.readAsBytes());
    final cuadro = (await codec.getNextFrame()).image;
    final ancho = cuadro.width, alto = cuadro.height;
    final rgba = (await cuadro.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    cuadro.dispose();

    segmentador = SelfieSegmenter(mode: SegmenterMode.single);
    final mascara = await segmentador.processImage(InputImage.fromFilePath(original.path));
    if (mascara == null || mascara.width == 0 || mascara.height == 0) return null;

    var frente = 0;
    for (var y = 0; y < alto; y++) {
      final my = (y * mascara.height ~/ alto) * mascara.width;
      for (var x = 0; x < ancho; x++) {
        final c = mascara.confidences[my + x * mascara.width ~/ ancho];
        final alfa = ((c - 0.35) / 0.3).clamp(0.0, 1.0);
        if (alfa > 0.5) frente++;
        rgba[(y * ancho + x) * 4 + 3] = (alfa * 255).round();
      }
    }
    final fraccion = frente / (ancho * alto);
    if (fraccion < 0.04 || fraccion > 0.92) {
      await fallido.writeAsString('');
      return null;
    }

    final completado = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, ancho, alto, ui.PixelFormat.rgba8888, completado.complete);
    final recorte = await completado.future;
    final png = await recorte.toByteData(format: ui.ImageByteFormat.png);
    recorte.dispose();
    if (png == null) return null;
    await destino.writeAsBytes(png.buffer.asUint8List(), flush: true);
    return destino;
  } catch (e) {
    debugPrint('Sin recorte para $url: $e');
    return null;
  } finally {
    await segmentador?.close();
  }
}

/// Nombre de archivo estable por URL (FNV-1a de 64 bits en hex).
String _clave(String url) {
  var h = 0xcbf29ce484222325;
  for (final b in utf8.encode(url)) {
    h ^= b;
    h *= 0x100000001b3; // desborda en 64 bits, como corresponde a FNV
  }
  return h.toUnsigned(64).toRadixString(16);
}
