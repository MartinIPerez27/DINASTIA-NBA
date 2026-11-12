import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_imagenes.dart';

final _recortes = <String, Future<File?>>{};
Future<void> _cola = Future.value();

/// Alto mínimo del recorte guardado: las fotos de Basketball-Reference miden 120×180 y, mostradas
/// grandes, se pixelan; se agrandan con filtrado de calidad antes de guardarlas.
const _altoMinimo = 480;

/// Foto de archivo (Basketball-Reference, Wikipedia) sin fondo, como los recortes de la NBA.
/// El fondo se quita en el celular con ML Kit (gratis y sin internet: el modelo viene en la app)
/// y el PNG queda guardado (agrandado, con bordes suaves y recortado a la silueta), así cada foto
/// se procesa una sola vez.
/// Devuelve null si no se pudo (sin persona en la foto, error, o plataforma sin ML Kit).
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
    // v2: la versión anterior descartaba los primeros planos (la cara ocupa casi toda la foto)
    // y los marcaba como fallidos para siempre; con otra carpeta se vuelven a procesar.
    final carpeta = Directory('${(await getApplicationSupportDirectory()).path}/recortes_v2');
    final destino = File('${carpeta.path}/${_clave(url)}.png');
    final fallido = File('${carpeta.path}/${_clave(url)}.sin');
    if (await destino.exists()) return destino;
    if (await fallido.exists()) return null;
    await carpeta.create(recursive: true);

    final original = await cacheHeadshots.getSingleFile(url);
    final codec = await ui.instantiateImageCodec(await original.readAsBytes());
    final cuadro = (await codec.getNextFrame()).image;

    segmentador = SelfieSegmenter(mode: SegmenterMode.single);
    final mascara = await segmentador.processImage(InputImage.fromFilePath(original.path));
    if (mascara == null || mascara.width == 0 || mascara.height == 0) {
      cuadro.dispose();
      return null;
    }

    final escala = max(1.0, _altoMinimo / cuadro.height);
    final ancho = (cuadro.width * escala).round(), alto = (cuadro.height * escala).round();
    final rgba = await agrandarParaRecorte(cuadro, ancho, alto);
    cuadro.dispose();

    final png = await recortarConMascara(
      rgba,
      ancho,
      alto,
      mascara.confidences.map((c) => c.toDouble()).toList(),
      mascara.width,
      mascara.height,
    );
    if (png == null) {
      await fallido.writeAsString('');
      return null;
    }
    await destino.writeAsBytes(png, flush: true);
    return destino;
  } catch (e) {
    debugPrint('Sin recorte para $url: $e');
    return null;
  } finally {
    await segmentador?.close();
  }
}

/// Dibuja la imagen al tamaño pedido con filtrado de alta calidad y devuelve sus píxeles RGBA.
Future<Uint8List> agrandarParaRecorte(ui.Image imagen, int ancho, int alto) async {
  final grabador = ui.PictureRecorder();
  ui.Canvas(grabador).drawImageRect(
    imagen,
    ui.Rect.fromLTWH(0, 0, imagen.width.toDouble(), imagen.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final grande = await grabador.endRecording().toImage(ancho, alto);
  final datos = await grande.toByteData(format: ui.ImageByteFormat.rawRgba);
  grande.dispose();
  return datos!.buffer.asUint8List();
}

/// Aplica la máscara de ML Kit como transparencia y devuelve el PNG recortado a la silueta.
/// La máscara se suaviza (desenfoque 3×3) y se interpola, así los bordes no quedan dentados
/// aunque la foto original sea chica. Devuelve null si no hay una persona clara (<4 % de la foto).
Future<Uint8List?> recortarConMascara(
  Uint8List rgba,
  int ancho,
  int alto,
  List<double> confianzas,
  int anchoMascara,
  int altoMascara,
) async {
  final suave = _desenfocar(confianzas, anchoMascara, altoMascara);
  double muestra(double mx, double my) {
    final x0 = mx.floor().clamp(0, anchoMascara - 1), y0 = my.floor().clamp(0, altoMascara - 1);
    final x1 = min(x0 + 1, anchoMascara - 1), y1 = min(y0 + 1, altoMascara - 1);
    final fx = (mx - x0).clamp(0.0, 1.0), fy = (my - y0).clamp(0.0, 1.0);
    final a = suave[y0 * anchoMascara + x0] * (1 - fx) + suave[y0 * anchoMascara + x1] * fx;
    final b = suave[y1 * anchoMascara + x0] * (1 - fx) + suave[y1 * anchoMascara + x1] * fx;
    return a * (1 - fy) + b * fy;
  }

  var frente = 0;
  var izq = ancho, der = -1, arriba = alto, abajo = -1;
  for (var y = 0; y < alto; y++) {
    final my = (y + 0.5) * altoMascara / alto - 0.5;
    for (var x = 0; x < ancho; x++) {
      final c = muestra((x + 0.5) * anchoMascara / ancho - 0.5, my);
      // Transición suave (smoothstep) entre 0,3 y 0,7 de confianza.
      final u = ((c - 0.3) / 0.4).clamp(0.0, 1.0);
      // Donde la persona toca el borde lateral de la foto original (hombros cortados), el corte
      // recto se disimula fundiéndolo en un 7 % del ancho.
      final lado = (min(x, ancho - 1 - x) / (0.07 * ancho)).clamp(0.0, 1.0);
      final alfa = u * u * (3 - 2 * u) * lado * lado * (3 - 2 * lado);
      rgba[(y * ancho + x) * 4 + 3] = (alfa * 255).round();
      if (alfa > 0.5) frente++;
      if (alfa > 0.1) {
        izq = min(izq, x);
        der = max(der, x);
        arriba = min(arriba, y);
        abajo = max(abajo, y);
      }
    }
  }
  if (frente / (ancho * alto) < 0.04 || der < izq) return null;

  // Recorte a la silueta con un margen chico: el encuadre en pantalla queda predecible.
  final margen = (0.02 * max(ancho, alto)).round();
  izq = max(0, izq - margen);
  arriba = max(0, arriba - margen);
  der = min(ancho - 1, der + margen);
  abajo = min(alto - 1, abajo + margen);
  final w = der - izq + 1, h = abajo - arriba + 1;
  final recorte = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    final desde = ((arriba + y) * ancho + izq) * 4;
    recorte.setRange(y * w * 4, (y + 1) * w * 4, rgba, desde);
  }

  final completado = Completer<ui.Image>();
  ui.decodeImageFromPixels(recorte, w, h, ui.PixelFormat.rgba8888, completado.complete);
  final imagen = await completado.future;
  final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  return png?.buffer.asUint8List();
}

List<double> _desenfocar(List<double> c, int w, int h) {
  final salida = List<double>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var suma = 0.0;
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          suma += c[yy * w + xx];
          n++;
        }
      }
      salida[y * w + x] = suma / n;
    }
  }
  return salida;
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
