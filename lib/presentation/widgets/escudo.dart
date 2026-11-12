import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/franquicia.dart';
import '../tema/tema_franquicia.dart';

/// Escudo empaquetado en assets (funciona offline). Las identidades históricas sin escudo real usan
/// uno tipográfico: círculo con sus colores y su sigla.
class Escudo extends StatelessWidget {
  const Escudo(this.franquicia, {super.key, required this.tamano});

  final Franquicia franquicia;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final ruta = franquicia.rutaEscudo;
    final etiqueta = 'Escudo de ${franquicia.nombreCompleto}';
    if (ruta == null) return _EscudoTipografico(franquicia, tamano: tamano, etiqueta: etiqueta);
    if (ruta.endsWith('.svg')) {
      return SvgPicture.asset(ruta, width: tamano, height: tamano, semanticsLabel: etiqueta);
    }
    return Image.asset(
      ruta,
      width: tamano,
      height: tamano,
      semanticLabel: etiqueta,
      errorBuilder: (_, _, _) => _EscudoTipografico(franquicia, tamano: tamano, etiqueta: etiqueta),
    );
  }
}

class _EscudoTipografico extends StatelessWidget {
  const _EscudoTipografico(this.franquicia, {required this.tamano, required this.etiqueta});

  final Franquicia franquicia;
  final double tamano;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final fondo = Color(franquicia.colorPrimario);
    final aro = Color(franquicia.colorSecundario);
    final texto = fondo.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    return Semantics(
      label: etiqueta,
      image: true,
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          shape: BoxShape.circle,
          border: Border.all(color: aro, width: tamano * 0.07),
        ),
        child: Padding(
          padding: EdgeInsets.all(tamano * 0.14),
          child: FittedBox(
            child: Text(
              franquicia.nombre.toUpperCase(),
              style: TextStyle(
                fontFamily: Fuentes.estadio,
                fontVariations: const [FontVariation.weight(800)],
                color: texto,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El escudo como imagen (para pintarlo en la cancha). Null si la identidad no tiene escudo real.
Future<ui.Image?> imagenEscudo(Franquicia f, {int lado = 512}) async {
  final ruta = f.rutaEscudo;
  if (ruta == null) return null;
  try {
    if (ruta.endsWith('.svg')) {
      final info = await vg.loadPicture(SvgAssetLoader(ruta), null);
      final escala = lado / max(info.size.width, info.size.height);
      final grabador = ui.PictureRecorder();
      Canvas(grabador)
        ..scale(escala)
        ..drawPicture(info.picture);
      final imagen = await grabador.endRecording().toImage(
        (info.size.width * escala).round(),
        (info.size.height * escala).round(),
      );
      info.picture.dispose();
      return imagen;
    }
    final datos = await rootBundle.load(ruta);
    final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List(), targetWidth: lado);
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}
