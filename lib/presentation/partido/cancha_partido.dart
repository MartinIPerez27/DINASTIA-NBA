import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../tema/tema_franquicia.dart';

/// Cancha completa vista desde arriba, en pies: 50 de ancho, 94 de largo (aro de arriba en y=5.25).
abstract final class Cancha94 {
  static const ancho = 50.0, largo = 94.0, borde = 3.0;
  static Offset aro(bool arriba) => Offset(25, arriba ? 5.25 : largo - 5.25);
}

class Ficha {
  const Ficha({
    required this.posicion,
    required this.relleno,
    required this.texto,
    required this.etiqueta,
    this.nombre,
    this.conBalon = false,
    this.opacidad = 1,
  });

  final Offset posicion; // en pies
  final Color relleno;
  final Color texto;
  final String etiqueta;

  /// Apellido que se muestra bajo la ficha (solo para quien tiene la pelota).
  final String? nombre;
  final bool conBalon;
  final double opacidad;
}

/// "+2"/"+3" que sube desde el aro al anotar.
class Tanto {
  const Tanto(this.texto, this.posicion, this.progreso);

  final String texto;
  final Offset posicion;
  final double progreso; // 0–1
}

/// Transmisión 2D (GDD §6): cancha del usuario vista desde arriba con una cámara que sigue la jugada,
/// 10 fichas, balón con estela y sombra según la altura, y la luz del estadio.
class CanchaPartidoPainter extends CustomPainter {
  CanchaPartidoPainter({
    required this.franquicia,
    required this.fichas,
    required this.balon,
    required this.camaraY,
    required this.colorLed,
    this.alturaBalon = 0,
    this.estela = const [],
    this.tanto,
    this.margenArriba = 0,
    this.margenAbajo = 0,
  });

  /// Píxeles tapados por el marcador (arriba) y el zócalo (abajo): la cámara puede pasarse del
  /// fondo para que el aro nunca quede debajo de un gráfico.
  final double margenArriba, margenAbajo;

  final Franquicia franquicia;
  final List<Ficha> fichas;
  final Offset balon;
  final double alturaBalon; // 0 = en la mano; 1 = punto más alto del tiro
  final List<Offset> estela;
  final double camaraY; // centro vertical de la vista, en pies
  final Color colorLed;
  final Tanto? tanto;

  static final _piso = <String, ui.Picture>{};

  /// El piso (madera, pintura, líneas, nombres) se dibuja una vez por franquicia y escala.
  ui.Picture _pisoCacheado(double pie) {
    final clave = '${franquicia.id}-${pie.toStringAsFixed(2)}';
    return _piso[clave] ??= () {
      final grabador = ui.PictureRecorder();
      _dibujarPiso(Canvas(grabador), pie);
      return grabador.endRecording();
    }();
  }

  static double altoVisible(Size size) => size.height / (size.width / (Cancha94.ancho + 2 * Cancha94.borde));

  @override
  void paint(Canvas canvas, Size size) {
    final pie = size.width / (Cancha94.ancho + 2 * Cancha94.borde);
    final visible = size.height / pie;
    final arriba = (camaraY - visible / 2).clamp(
      -Cancha94.borde - margenArriba / pie,
      max(-Cancha94.borde - margenArriba / pie, Cancha94.largo + Cancha94.borde + margenAbajo / pie - visible),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -(arriba + Cancha94.borde) * pie);
    canvas.drawPicture(_pisoCacheado(pie));
    Offset p(Offset o) => Offset((o.dx + Cancha94.borde) * pie, (o.dy + Cancha94.borde) * pie);

    // Fichas.
    final radio = 2.1 * pie;
    for (final f in fichas) {
      final c = p(f.posicion);
      final a = f.opacidad;
      canvas.drawCircle(
        c + Offset(radio * 0.12, radio * 0.22),
        radio,
        Paint()..color = Colors.black.withValues(alpha: 0.35 * a),
      );
      canvas.drawCircle(c, radio, Paint()..color = f.relleno.withValues(alpha: a));
      canvas.drawCircle(
        c,
        radio - 0.6,
        Paint()
          ..color = (f.conBalon ? colorLed : f.texto.withValues(alpha: 0.75)).withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.conBalon ? max(2.2, pie * 0.45) : 1.2,
      );
      _texto(canvas, f.etiqueta, c, radio * 0.95, f.texto.withValues(alpha: a), FontWeight.w800);
      if (f.nombre != null) {
        final placa = TextPainter(
          text: TextSpan(
            text: f.nombre,
            style: TextStyle(
              fontFamily: Fuentes.estadio,
              fontVariations: const [FontVariation.weight(700)],
              fontSize: radio * 0.75,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final rect = Rect.fromCenter(
          center: c + Offset(0, radio * 1.75),
          width: placa.width + radio * 0.8,
          height: placa.height + radio * 0.2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radio * 0.3)),
          Paint()..color = const Color(0xD90F1012),
        );
        placa.paint(canvas, rect.center - Offset(placa.width / 2, placa.height / 2));
      }
    }

    // Estela, sombra y balón (más grande cuanto más alto va el tiro).
    for (final (i, e) in estela.indexed) {
      final k = 1 - i / max(estela.length, 1);
      canvas.drawCircle(p(e), pie * 0.95 * k, Paint()..color = const Color(0xFFFFB347).withValues(alpha: 0.45 * k));
    }
    final b = p(balon);
    final rb = pie * (1.0 + 0.75 * alturaBalon);
    canvas.drawCircle(
      b + Offset(pie * (0.4 + 2.2 * alturaBalon), pie * (0.5 + 2.6 * alturaBalon)),
      rb * 0.85,
      Paint()..color = Colors.black.withValues(alpha: 0.3 * (1 - alturaBalon * 0.5)),
    );
    canvas.drawCircle(b, rb, Paint()..color = const Color(0xFFE8792B));
    final costura = Paint()
      ..color = const Color(0xFF3A1A08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, rb * 0.12);
    canvas.drawLine(b - Offset(rb, 0), b + Offset(rb, 0), costura);
    canvas.drawArc(Rect.fromCircle(center: b - Offset(rb * 1.1, 0), radius: rb * 0.9), -0.9, 1.8, false, costura);
    canvas.drawArc(Rect.fromCircle(center: b + Offset(rb * 1.1, 0), radius: rb * 0.9), pi - 0.9, 1.8, false, costura);
    canvas.drawCircle(
      b,
      rb,
      Paint()
        ..color = const Color(0xFF3A1A08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, rb * 0.1),
    );

    // Tanto: sube y se desvanece sobre el aro.
    final t = tanto;
    if (t != null) {
      final sube = Curves.easeOutCubic.transform(t.progreso);
      final c = p(t.posicion) - Offset(0, sube * pie * 6);
      _texto(canvas, t.texto, c, pie * 3.4, colorLed.withValues(alpha: (1 - t.progreso).clamp(0, 1)), FontWeight.w800);
    }
    canvas.restore();

    // Luz del estadio sobre la toma: centro iluminado, bordes en penumbra.
    final toma = Offset.zero & size;
    canvas.drawRect(
      toma,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38)],
          stops: const [0.55, 1],
        ).createShader(toma),
    );
  }

  void _texto(Canvas canvas, String texto, Offset centro, double tamano, Color color, FontWeight peso) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: [FontVariation.weight(peso.value.toDouble())],
          fontSize: tamano,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  void _dibujarPiso(Canvas canvas, double pie) {
    Offset p(double x, double y) => Offset((x + Cancha94.borde) * pie, (y + Cancha94.borde) * pie);
    final pintura = Color(franquicia.colorPrimario);
    final secundario = Color(franquicia.colorSecundario);
    final total = Rect.fromLTWH(
      0,
      0,
      (Cancha94.ancho + 2 * Cancha94.borde) * pie,
      (Cancha94.largo + 2 * Cancha94.borde) * pie,
    );

    // Borde fuera de la cancha: color del equipo, mate.
    final hsl = HSLColor.fromColor(pintura);
    final borde = hsl.withLightness((hsl.lightness * 0.7).clamp(0.08, 0.4)).toColor();
    canvas.drawRect(total, Paint()..color = borde);

    // Madera con tablas, juntas y vetas.
    final cancha = Rect.fromPoints(p(0, 0), p(Cancha94.ancho, Cancha94.largo));
    canvas.save();
    canvas.clipRect(cancha);
    const madera = Color(0xFFA2724A);
    final tabla = cancha.width / 30;
    final azar = Random(94);
    final veta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var i = 0; i * tabla < cancha.width; i++) {
      final x = cancha.left + i * tabla;
      final tono = HSLColor.fromColor(madera);
      canvas.drawRect(
        Rect.fromLTWH(x, cancha.top, tabla, cancha.height),
        Paint()..color = tono.withLightness((tono.lightness + (azar.nextDouble() - 0.5) * 0.07).clamp(0, 1)).toColor(),
      );
      for (var v = 0; v < 2; v++) {
        final vx = x + tabla * (0.3 + 0.4 * v);
        final camino = Path()..moveTo(vx, cancha.top);
        for (var y = cancha.top; y < cancha.bottom; y += 22) {
          camino.quadraticBezierTo(vx + (azar.nextBool() ? 1.5 : -1.5), y + 11, vx + (azar.nextDouble() - 0.5), y + 22);
        }
        canvas.drawPath(camino, veta..color = Colors.black.withValues(alpha: 0.05 + azar.nextDouble() * 0.05));
      }
      final junta = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..strokeWidth = 0.6;
      canvas.drawLine(Offset(x, cancha.top), Offset(x, cancha.bottom), junta);
      for (var y = cancha.top + azar.nextDouble() * 70; y < cancha.bottom; y += 60 + azar.nextDouble() * 50) {
        canvas.drawLine(Offset(x, y), Offset(x + tabla, y), junta);
      }
    }
    canvas.restore();

    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.3, pie * 0.22);
    canvas.drawRect(cancha, linea);
    canvas.drawLine(p(0, 47), p(50, 47), linea);
    canvas.drawCircle(p(25, 47), 6 * pie, Paint()..color = pintura.withValues(alpha: 0.85));
    canvas.drawCircle(p(25, 47), 6 * pie, linea);
    canvas.drawCircle(p(25, 47), 2 * pie, linea);

    for (final arriba in [true, false]) {
      double y(double d) => arriba ? d : Cancha94.largo - d;
      final zona = Rect.fromPoints(p(17, y(0)), p(33, y(19)));
      canvas.drawRect(zona, Paint()..color = pintura);
      canvas.drawRect(zona, linea);
      canvas.drawCircle(p(25, y(19)), 6 * pie, linea);
      for (final d in [7.0, 10.5, 13.5, 16.5]) {
        canvas.drawLine(p(17, y(d)), p(16, y(d)), linea);
        canvas.drawLine(p(33, y(d)), p(34, y(d)), linea);
      }
      canvas.drawLine(
        p(22, y(4)),
        p(28, y(4)),
        Paint()
          ..color = Colors.white
          ..strokeWidth = pie * 0.45,
      );
      canvas.drawCircle(
        p(25, y(5.25)),
        0.75 * pie,
        Paint()
          ..color = const Color(0xFFE35205)
          ..style = PaintingStyle.stroke
          ..strokeWidth = pie * 0.28,
      );
      final aro = p(25, y(5.25));
      canvas.drawArc(Rect.fromCircle(center: aro, radius: 4 * pie), arriba ? 0 : pi, pi, false, linea);
      final ang = asin(8.95 / 23.75);
      canvas.drawLine(p(3, y(0)), p(3, y(14.2)), linea);
      canvas.drawLine(p(47, y(0)), p(47, y(14.2)), linea);
      canvas.drawArc(
        Rect.fromCircle(center: aro, radius: 23.75 * pie),
        arriba ? ang : pi + ang,
        pi - 2 * ang,
        false,
        linea,
      );

      // Nombre de la franquicia en cada línea de fondo (GDD §2).
      final nombre = TextPainter(
        text: TextSpan(
          text: franquicia.nombre.toUpperCase(),
          style: TextStyle(
            fontFamily: Fuentes.estadio,
            fontVariations: const [FontVariation.weight(800)],
            fontSize: 2.2 * pie,
            letterSpacing: 1.2 * pie,
            color: secundario.computeLuminance() > 0.08 ? secundario : Colors.white,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final centro = p(25, arriba ? -1.5 : Cancha94.largo + 1.5);
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      if (!arriba) canvas.rotate(pi);
      nombre.paint(canvas, Offset(-nombre.width / 2, -nombre.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CanchaPartidoPainter a) => true;
}
