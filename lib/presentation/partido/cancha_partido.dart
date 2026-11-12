import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../tema/tema_franquicia.dart';

/// Cancha completa vista desde arriba, en pies: 50 de ancho, 94 de largo (aro de arriba en y=5.25).
abstract final class Cancha94 {
  static const ancho = 50.0, largo = 94.0, borde = 2.5;
  static const proporcion = (ancho + 2 * borde) / (largo + 2 * borde);
  static Offset aro(bool arriba) => Offset(25, arriba ? 5.25 : largo - 5.25);
}

class Ficha {
  const Ficha({
    required this.posicion,
    required this.relleno,
    required this.texto,
    required this.etiqueta,
    this.conBalon = false,
  });

  final Offset posicion; // en pies
  final Color relleno;
  final Color texto;
  final String etiqueta;
  final bool conBalon;
}

/// Pinta la cancha (parqué con la pintura de la franquicia del usuario, GDD §6), las 10 fichas,
/// el balón y su estela al tirar. Todo en coordenadas de pies; el pintor escala a la pantalla.
class CanchaPartidoPainter extends CustomPainter {
  CanchaPartidoPainter({
    required this.franquicia,
    required this.fichas,
    required this.balon,
    this.alturaBalon = 0,
    this.estela = const [],
    required this.colorLed,
  });

  final Franquicia franquicia;
  final List<Ficha> fichas;
  final Offset balon;
  final double alturaBalon; // 0 = en mano; 1 = punto más alto del tiro
  final List<Offset> estela;
  final Color colorLed;

  @override
  void paint(Canvas canvas, Size size) {
    final pie = size.width / (Cancha94.ancho + 2 * Cancha94.borde);
    Offset p(Offset o) => Offset((o.dx + Cancha94.borde) * pie, (o.dy + Cancha94.borde) * pie);
    final pintura = Color(franquicia.colorPrimario);

    // Borde y madera.
    final hsl = HSLColor.fromColor(pintura);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = hsl.withLightness((hsl.lightness * 0.7).clamp(0.08, 0.4)).toColor(),
    );
    final cancha = Rect.fromPoints(p(Offset.zero), p(const Offset(Cancha94.ancho, Cancha94.largo)));
    canvas.save();
    canvas.clipRect(cancha);
    final azar = Random(94);
    const madera = Color(0xFF9A6B42);
    final tabla = cancha.width / 26;
    for (var i = 0; i * tabla < cancha.width; i++) {
      final tono = HSLColor.fromColor(madera);
      canvas.drawRect(
        Rect.fromLTWH(cancha.left + i * tabla, cancha.top, tabla, cancha.height),
        Paint()..color = tono.withLightness((tono.lightness + (azar.nextDouble() - 0.5) * 0.06).clamp(0, 1)).toColor(),
      );
      canvas.drawLine(
        Offset(cancha.left + i * tabla, cancha.top),
        Offset(cancha.left + i * tabla, cancha.bottom),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = 0.6,
      );
    }
    canvas.restore();

    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, pie * 0.2);
    canvas.drawRect(cancha, linea);
    canvas.drawLine(p(const Offset(0, 47)), p(const Offset(50, 47)), linea);
    canvas.drawCircle(p(const Offset(25, 47)), 6 * pie, Paint()..color = pintura.withValues(alpha: 0.85));
    canvas.drawCircle(p(const Offset(25, 47)), 6 * pie, linea);
    for (final arriba in [true, false]) {
      double y(double d) => arriba ? d : Cancha94.largo - d;
      final zona = Rect.fromPoints(p(Offset(17, y(0))), p(Offset(33, y(19))));
      canvas.drawRect(zona, Paint()..color = pintura);
      canvas.drawRect(zona, linea);
      canvas.drawCircle(p(Offset(25, y(19))), 6 * pie, linea);
      canvas.drawLine(
        p(Offset(22, y(4))),
        p(Offset(28, y(4))),
        Paint()
          ..color = Colors.white
          ..strokeWidth = pie * 0.4,
      );
      canvas.drawCircle(
        p(Cancha94.aro(arriba)),
        0.75 * pie,
        Paint()
          ..color = const Color(0xFFE35205)
          ..style = PaintingStyle.stroke
          ..strokeWidth = pie * 0.25,
      );
      // Triple: rectas en las esquinas + arco de 23.75 pies.
      final aro = p(Cancha94.aro(arriba));
      final ang = asin(8.95 / 23.75);
      canvas.drawLine(p(Offset(3, y(0))), p(Offset(3, y(14.2))), linea);
      canvas.drawLine(p(Offset(47, y(0))), p(Offset(47, y(14.2))), linea);
      canvas.drawArc(
        Rect.fromCircle(center: aro, radius: 23.75 * pie),
        arriba ? ang : pi + ang,
        pi - 2 * ang,
        false,
        linea,
      );
    }

    // Fichas.
    final radio = 2.3 * pie;
    for (final f in fichas) {
      final c = p(f.posicion);
      canvas.drawCircle(c + Offset(0, radio * 0.15), radio, Paint()..color = Colors.black.withValues(alpha: 0.35));
      canvas.drawCircle(c, radio, Paint()..color = f.relleno);
      canvas.drawCircle(
        c,
        radio,
        Paint()
          ..color = f.conBalon ? colorLed : f.texto.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.conBalon ? max(2, pie * 0.4) : 1,
      );
      final texto = TextPainter(
        text: TextSpan(
          text: f.etiqueta,
          style: TextStyle(
            fontFamily: Fuentes.estadio,
            fontVariations: const [FontVariation.weight(800)],
            fontSize: radio * 0.95,
            color: f.texto,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      texto.paint(canvas, c - Offset(texto.width / 2, texto.height / 2));
    }

    // Estela y balón (más grande cuanto más alto va el tiro).
    for (final (i, e) in estela.indexed) {
      canvas.drawCircle(
        p(e),
        pie * 0.9 * (1 - i / max(estela.length, 1)),
        Paint()..color = const Color(0xFFFFB347).withValues(alpha: 0.5 * (1 - i / max(estela.length, 1))),
      );
    }
    final b = p(balon);
    final rb = pie * (0.95 + 0.7 * alturaBalon);
    canvas.drawCircle(
      b + Offset(0, pie * (0.3 + 1.5 * alturaBalon)),
      rb * 0.9,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawCircle(b, rb, Paint()..color = const Color(0xFFE8792B));
    canvas.drawCircle(
      b,
      rb,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(CanchaPartidoPainter a) => true;
}
