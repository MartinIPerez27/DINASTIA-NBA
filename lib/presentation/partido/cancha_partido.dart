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
    this.ribete,
    this.energia = 1,
  });

  final Offset posicion; // en pies
  final Color relleno;
  final Color texto;
  final String etiqueta;

  /// Apellido que se muestra bajo la ficha (solo para quien tiene la pelota).
  final String? nombre;
  final bool conBalon;
  final double opacidad;

  /// Segundo color de la camiseta (ribete del cuello y las sisas).
  final Color? ribete;

  /// Estamina 0–1: el aro de energía alrededor de la ficha se va apagando.
  final double energia;
}

/// Lo que le pasa al aro de un lado: la red se sacude al entrar la pelota o el aro vibra al rebotar.
class EfectoAro {
  const EfectoAro({required this.arriba, required this.progreso, required this.adentro, this.fuerte = false});

  final bool arriba;
  final double progreso; // 0–1
  final bool adentro;

  /// Volcada: además de la red, tiembla todo el aro y el tablero.
  final bool fuerte;
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
    this.camaraX = Cancha94.ancho / 2,
    this.zoom = 1,
    this.escudo,
    this.efectoAro,
    this.cartel = '',
    this.tiempo = 0,
  });

  /// Centro horizontal de la toma (en pies) y acercamiento (1 = cancha de lado a lado).
  final double camaraX, zoom;

  /// Escudo de la franquicia, pintado en el círculo central (GDD §2.2).
  final ui.Image? escudo;

  final EfectoAro? efectoAro;

  /// Texto de los carteles LED a los costados, y el tiempo (s) para que corra.
  final String cartel;
  final double tiempo;

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

  /// El piso (madera, pintura, líneas, nombres, escudo) se dibuja una vez por franquicia y escala.
  ui.Picture _pisoCacheado(double pie) {
    final clave = '${franquicia.id}-${pie.toStringAsFixed(2)}-${escudo != null}';
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
    final escala = pie * zoom;
    final alto = size.height / escala, ancho = size.width / escala;
    final arribaMin = -Cancha94.borde - margenArriba / escala;
    final arriba = (camaraY - alto / 2).clamp(
      arribaMin,
      max(arribaMin, Cancha94.largo + Cancha94.borde + margenAbajo / escala - alto),
    );
    final izquierda = (camaraX - ancho / 2).clamp(-Cancha94.borde, Cancha94.ancho + Cancha94.borde - ancho);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(zoom);
    canvas.translate(-(izquierda + Cancha94.borde) * pie, -(arriba + Cancha94.borde) * pie);
    canvas.drawPicture(_pisoCacheado(pie));
    Offset p(Offset o) => Offset((o.dx + Cancha94.borde) * pie, (o.dy + Cancha94.borde) * pie);
    _carteles(canvas, pie);

    // Fichas.
    final radio = 2.1 * pie;
    // El que tiene la pelota siempre arriba de los demás.
    for (final f in [...fichas.where((f) => !f.conBalon), ...fichas.where((f) => f.conBalon)]) {
      final c = p(f.posicion);
      final a = f.opacidad;
      canvas.drawCircle(
        c + Offset(radio * 0.12, radio * 0.22),
        radio,
        Paint()..color = Colors.black.withValues(alpha: 0.35 * a),
      );
      canvas.drawCircle(c, radio, Paint()..color = f.relleno.withValues(alpha: a));
      // Camiseta: ribete del segundo color en el borde, como el cuello y las sisas.
      if (f.ribete case final ribete?) {
        canvas.drawCircle(
          c,
          radio * 0.86,
          Paint()
            ..color = ribete.withValues(alpha: a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radio * 0.16,
        );
      }
      // Aro de energía: completo con el tanque lleno, se acorta (y se pone ámbar) con el cansancio.
      final energia = f.energia.clamp(0.0, 1.0);
      canvas.drawCircle(
        c,
        radio + pie * 0.32,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = pie * 0.28,
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radio + pie * 0.32),
        -pi / 2,
        2 * pi * energia,
        false,
        Paint()
          ..color = (energia < 0.6 ? const Color(0xFFFFB020) : Colors.white.withValues(alpha: 0.8)).withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = pie * 0.28
          ..strokeCap = StrokeCap.round,
      );
      if (f.conBalon) {
        canvas.drawCircle(
          c,
          radio + pie * 0.75,
          Paint()
            ..color = colorLed.withValues(alpha: a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.0, pie * 0.35),
        );
      }
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

    // Pelota baja (en la mano o cayendo por la red) debajo del aro; la que vuela, por encima.
    if (alturaBalon < 0.35) _pelota(canvas, p, pie);
    for (final arribaAro in [true, false]) {
      final efecto = efectoAro?.arriba == arribaAro ? efectoAro : null;
      _aro(canvas, p(Cancha94.aro(arribaAro)), pie, arribaAro, efecto);
    }
    if (alturaBalon >= 0.35) _pelota(canvas, p, pie);

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

  void _pelota(Canvas canvas, Offset Function(Offset) p, double pie) {
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
  }

  /// Aro visto desde arriba: base acolchada detrás del fondo, brazo, tablero de vidrio con su
  /// recuadro, aro naranja y red. La red se sacude al entrar la pelota; el aro vibra si rebota.
  void _aro(Canvas canvas, Offset centro, double pie, bool arriba, EfectoAro? efecto) {
    final s = arriba ? 1.0 : -1.0; // hacia adentro de la cancha
    Offset q(double x, double y) => centro + Offset(x * pie, y * s * pie);
    // Base y brazo.
    final base = Rect.fromPoints(q(-2.6, -8.4), q(2.6, -6.5));
    canvas.drawRRect(
      RRect.fromRectAndRadius(base.shift(Offset(pie * 0.3, pie * 0.4)), Radius.circular(pie * 0.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(pie * 0.5)),
      Paint()..color = const Color(0xFF1B1D21),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base.deflate(pie * 0.35), Radius.circular(pie * 0.3)),
      Paint()..color = Color(franquicia.colorPrimario).withValues(alpha: 0.85),
    );
    canvas.drawRect(Rect.fromPoints(q(-0.45, -6.6), q(0.45, -1.4)), Paint()..color = const Color(0xFF2A2D33));
    // Tablero: vidrio con borde blanco y el recuadro del tirador.
    var vibra = 0.0;
    if (efecto != null && (!efecto.adentro || efecto.fuerte)) {
      vibra = sin(efecto.progreso * pi * 9) * (1 - efecto.progreso) * (efecto.fuerte ? 0.7 : 0.35);
    }
    final tablero = Rect.fromPoints(q(-3 + vibra, -1.45), q(3 + vibra, -0.95));
    canvas.drawRect(
      tablero.shift(Offset(pie * 0.25, pie * 0.35)),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawRect(tablero, Paint()..color = const Color(0x55DDEEFF));
    canvas.drawRect(
      tablero,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, pie * 0.16),
    );
    canvas.drawLine(
      q(-1, -0.95),
      q(1, -0.95),
      Paint()
        ..color = Colors.white
        ..strokeWidth = max(1.2, pie * 0.2),
    );
    // Soporte del aro.
    canvas.drawLine(
      q(vibra, -0.95),
      q(vibra, -0.7),
      Paint()
        ..color = const Color(0xFFE35205)
        ..strokeWidth = pie * 0.3,
    );
    final c = centro + Offset(vibra * pie, 0);
    // Red: hilos del aro hacia el fondo de la red (que se sacude con la canasta).
    var caida = 0.0, abre = 1.0;
    if (efecto != null && efecto.adentro) {
      final u = efecto.progreso;
      caida = sin(u * pi) * 0.9 + sin(u * pi * 5) * (1 - u) * 0.2;
      abre = 1 + sin(u * pi) * 0.25;
    }
    final fondo = c + Offset(0, caida * s * pie);
    final radioRed = 0.45 * pie * abre;
    final hilo = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = max(0.7, pie * 0.07);
    for (var k = 0; k < 12; k++) {
      final ang = k * pi / 6;
      final arriba = c + Offset(cos(ang), sin(ang)) * 0.75 * pie;
      final abajo = fondo + Offset(cos(ang + pi / 12), sin(ang + pi / 12)) * radioRed;
      canvas.drawLine(arriba, abajo, hilo);
    }
    canvas.drawCircle(fondo, radioRed, hilo..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset.lerp(c, fondo, 0.5)!, (0.75 * pie + radioRed) / 2, hilo);
    // Aro.
    canvas.drawCircle(
      c + Offset(pie * 0.12, pie * 0.18),
      0.75 * pie,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pie * 0.2,
    );
    canvas.drawCircle(
      c,
      0.75 * pie,
      Paint()
        ..color = const Color(0xFFF26A1B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pie * 0.22,
    );
  }

  /// Carteles LED a lo largo de los costados, con el texto corriendo (estilo "El Marcador").
  void _carteles(Canvas canvas, double pie) {
    if (cartel.isEmpty) return;
    final estilo = TextStyle(
      fontFamily: Fuentes.led,
      fontVariations: const [FontVariation.weight(800)],
      fontSize: 1.7 * pie,
      color: colorLed,
      height: 1,
      letterSpacing: 0.3 * pie,
    );
    final tp = TextPainter(
      text: TextSpan(text: '$cartel   ·   ', style: estilo),
      textDirection: TextDirection.ltr,
    )..layout();
    final largo = (Cancha94.largo + 2 * Cancha94.borde) * pie;
    for (final izquierda in [true, false]) {
      final x = (izquierda ? Cancha94.borde * 0.45 : Cancha94.ancho + Cancha94.borde * 1.55) * pie;
      final franja = Rect.fromCenter(center: Offset(x, largo / 2), width: 2.2 * pie, height: largo);
      canvas.drawRect(franja, Paint()..color = const Color(0xFF0B0C0E));
      canvas.save();
      canvas.clipRect(franja);
      canvas.translate(x, 0);
      canvas.rotate(pi / 2); // el texto corre a lo largo de la cancha
      final corrimiento = (tiempo * 6 * pie) % tp.width;
      for (var d = -corrimiento; d < largo; d += tp.width) {
        tp.paint(canvas, Offset(d, -tp.height / 2));
      }
      canvas.restore();
    }
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
    final escudoCentral = escudo;
    if (escudoCentral == null) {
      canvas.drawCircle(p(25, 47), 6 * pie, Paint()..color = pintura.withValues(alpha: 0.85));
      canvas.drawCircle(p(25, 47), 2 * pie, linea);
    } else {
      // Escudo sobre la madera, como en las canchas de verdad.
      final lado = 10.5 * pie;
      final proporcion = escudoCentral.width / escudoCentral.height;
      final destino = Rect.fromCenter(
        center: p(25, 47),
        width: proporcion >= 1 ? lado : lado * proporcion,
        height: proporcion >= 1 ? lado / proporcion : lado,
      );
      canvas.drawImageRect(
        escudoCentral,
        Offset.zero & Size(escudoCentral.width.toDouble(), escudoCentral.height.toDouble()),
        destino,
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Colors.white.withValues(alpha: 0.92),
      );
    }
    canvas.drawCircle(p(25, 47), 6 * pie, linea);

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
