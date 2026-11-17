import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'cancha_partido.dart';

/// Cómo está la tribuna en un instante: qué tan alborotada, si hay ola o abucheo y el clima del partido.
class PublicoEstado {
  const PublicoEstado({
    this.excitacion = 0.15,
    this.ola = -1,
    this.abucheo = 0,
    this.tension = 0,
    this.playoffs = false,
    this.local = const Color(0xFF552583),
    this.visitante = const Color(0xFFCE1141),
  });

  /// 0 = sentados mirando; 1 = todos de pie con los brazos arriba.
  final double excitacion;

  /// Posición de la ola alrededor de la cancha (0–1), o negativo si no hay.
  final double ola;

  /// 0–1: la gente sacude la cabeza y el color se apaga.
  final double abucheo;

  /// Tensión del final apretado (0–1): nadie se mueve y la luz baja.
  final double tension;
  final bool playoffs;

  /// Colores de camiseta de la hinchada local y de la visitante.
  final Color local, visitante;
}

class _Persona {
  const _Persona(this.x, this.y, this.dx, this.dy, this.u, this.semilla, this.grupo, this.cartel);

  final double x, y;

  /// Hacia dónde está la cancha (vector unitario) desde esta persona.
  final double dx, dy;

  /// Posición alrededor del perímetro (0–1), para la ola.
  final double u;
  final int semilla;

  /// 0 local, 1 visitante, 2 blanco, 3 oscuro, 4 secundario.
  final int grupo;
  final bool cartel;
}

/// Tribunas alrededor de la cancha, con siluetas animadas (hombros y cabeza) que se levantan, saltan,
/// hacen la ola y abuchean. Todo se agrupa por color y se dibuja con pocas llamadas (`drawRawPoints`).
abstract final class Publico {
  static const _fondoGrada = Color(0xFF0B0C0E);
  static final List<_Persona> _gente = _armar();

  static List<_Persona> _armar() {
    final r = Random(33);
    final lista = <_Persona>[];
    const a = Cancha94.ancho, l = Cancha94.largo;
    void fila(double x0, double y0, double x1, double y1, double dx, double dy, double desdeU, double hastaU) {
      final largo = (Offset(x1 - x0, y1 - y0)).distance;
      final n = (largo / 1.55).floor();
      for (var k = 0; k < n; k++) {
        final f = (k + 0.5) / n;
        final g = r.nextDouble();
        lista.add(
          _Persona(
            x0 + (x1 - x0) * f + (r.nextDouble() - 0.5) * 0.25,
            y0 + (y1 - y0) * f + (r.nextDouble() - 0.5) * 0.25,
            dx,
            dy,
            desdeU + (hastaU - desdeU) * f,
            r.nextInt(1 << 20),
            g < 0.58 ? 0 : (g < 0.74 ? 2 : (g < 0.86 ? 3 : (g < 0.93 ? 4 : 1))),
            r.nextInt(14) == 0,
          ),
        );
      }
    }

    // Dos filas por lado, fuera del cartel LED (que ocupa de 1,5 a 3 pies desde el borde).
    for (final (i, d) in [3.9, 5.2].indexed) {
      final desfase = i * 0.75;
      fila(-d, -d + desfase, -d, l + d - desfase, 1, 0, 0, 0.3);
      fila(a + d, l + d - desfase, a + d, -d + desfase, -1, 0, 0.5, 0.8);
      fila(-d + 1, -d, a + d - 1, -d, 0, 1, 0.8, 1.0);
      fila(a + d - 1, l + d, -d + 1, l + d, 0, -1, 0.3, 0.5);
    }
    return lista;
  }

  /// Dibuja las tribunas (la cámara ya está aplicada; las coordenadas son pies del mundo).
  static void dibujar(
    Canvas canvas,
    double pie,
    PublicoEstado e,
    double t,
    Color secundario,
    Color luz, {
    Rect? visible,
  }) {
    const a = Cancha94.ancho, l = Cancha94.largo, b = Cancha94.borde;
    Offset p(double x, double y) => Offset((x + b) * pie, (y + b) * pie);
    // Fondo oscuro de las gradas: un marco alrededor de la cancha.
    final fondo = Paint()..color = _fondoGrada;
    const g0 = 3.2;
    canvas.drawRect(Rect.fromPoints(p(-b, -b), p(-g0, l + b)), fondo);
    canvas.drawRect(Rect.fromPoints(p(a + g0, -b), p(a + b, l + b)), fondo);
    canvas.drawRect(Rect.fromPoints(p(-b, -b), p(a + b, -g0)), fondo);
    canvas.drawRect(Rect.fromPoints(p(-b, l + g0), p(a + b, l + b)), fondo);
    // Escalones: líneas tenues.
    final escalon = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = max(0.8, pie * 0.12);
    for (final d in [4.55, 5.85]) {
      canvas.drawLine(p(-d, -b), p(-d, l + b), escalon);
      canvas.drawLine(p(a + d, -b), p(a + d, l + b), escalon);
      canvas.drawLine(p(-b, -d), p(a + b, -d), escalon);
      canvas.drawLine(p(-b, l + d), p(a + b, l + d), escalon);
    }

    // Colores de cada grupo, apagados por el abucheo y la tensión, más vivos en playoffs.
    final apagado = (e.abucheo * 0.45 + e.tension * 0.2).clamp(0.0, 0.6);
    final vivo = e.playoffs ? 1.0 : 0.82;
    Color tono(Color c) => Color.lerp(c, Colors.black, 0.28 + apagado * 0.6 - (vivo - 0.82) * 0.5)!;
    final colores = [
      tono(e.local),
      tono(e.visitante),
      tono(const Color(0xFFE9E9E4)),
      tono(const Color(0xFF3A3C42)),
      tono(secundario),
    ];
    final cuerpos = List.generate(5, (_) => <double>[]);
    final cabezasClaras = <double>[], cabezasOscuras = <double>[];
    final brazos = <double>[];
    final carteles = <(Offset, int)>[];
    final salto = e.excitacion;
    // Solo se dibuja la gente que entra en cuadro (en pies del mundo, con un margen).
    final v = visible?.inflate(3);
    for (final q in _gente) {
      if (v != null && !v.contains(Offset(q.x, q.y))) continue;
      final r = (q.semilla % 997) / 997;
      // Cuánto se levanta: la excitación general, repartida al azar, más la ola que pasa.
      var arriba = (salto * (0.35 + 0.9 * r) - 0.15).clamp(0.0, 1.0);
      if (e.ola >= 0) {
        var du = (q.u - e.ola).abs();
        du = min(du, 1 - du);
        arriba = max(arriba, exp(-pow(du / 0.05, 2)).toDouble());
      }
      // Saltitos al ritmo de la hinchada cuando está muy arriba.
      final bote = arriba > 0.55 ? (sin(t * 8 + q.semilla) * 0.5 + 0.5) * 0.35 * arriba : 0.0;
      final sacude = e.abucheo > 0.1 ? sin(t * 17 + q.semilla) * 0.3 * e.abucheo : 0.0;
      final respira = sin(t * 1.3 + q.semilla) * 0.12 * (1 - e.tension);
      // Se acerca a la cancha cuando se para.
      final x = q.x + q.dx * (arriba * 0.45 + bote * 0.4) + (q.dy != 0 ? sacude + respira : 0);
      final y = q.y + q.dy * (arriba * 0.45 + bote * 0.4) + (q.dx != 0 ? sacude + respira : 0);
      final c = p(x, y);
      cuerpos[q.grupo]
        ..add(c.dx)
        ..add(c.dy);
      final cab = c + Offset(q.dx * 0.15 * pie, q.dy * 0.15 * pie);
      final lista = r > 0.5 ? cabezasClaras : cabezasOscuras;
      lista
        ..add(cab.dx)
        ..add(cab.dy);
      if (arriba > 0.45) {
        // Brazos arriba: dos rayitas hacia adelante y para los costados.
        final lateral = Offset(-q.dy, q.dx);
        for (final lado in [-1.0, 1.0]) {
          final mano = c + Offset(q.dx, q.dy) * pie * (1.3 * arriba) + lateral * pie * (0.9 * lado);
          brazos
            ..add(c.dx + lateral.dx * pie * 0.7 * lado)
            ..add(c.dy + lateral.dy * pie * 0.7 * lado)
            ..add(mano.dx)
            ..add(mano.dy);
        }
      }
      if (q.cartel && e.playoffs) carteles.add((c + Offset(q.dx, q.dy) * pie * 1.7, q.semilla));
    }
    final cuerpo = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = pie * 1.45;
    for (var g = 0; g < 5; g++) {
      if (cuerpos[g].isEmpty) continue;
      cuerpo.color = colores[g];
      canvas.drawRawPoints(ui.PointMode.points, Float32List.fromList(cuerpos[g]), cuerpo);
    }
    if (brazos.isNotEmpty) {
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(brazos),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = pie * 0.42
          ..color = tono(const Color(0xFFD9A06B)),
      );
    }
    final cabeza = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = pie * 0.95;
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(cabezasClaras),
      cabeza..color = tono(const Color(0xFFD9A06B)),
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(cabezasOscuras),
      cabeza..color = tono(const Color(0xFF4A2E1B)),
    );
    // Carteles y banderines de playoffs.
    for (final (c, semilla) in carteles) {
      final bandera = Rect.fromCenter(
        center: c + Offset(0, sin(t * 3 + semilla) * pie * 0.2),
        width: pie * 2.1,
        height: pie * 1.3,
      );
      canvas.drawRect(
        bandera,
        Paint()..color = semilla.isEven ? Colors.white.withValues(alpha: 0.85) : e.local.withValues(alpha: 0.9),
      );
    }
    if (e.playoffs) {
      // Hilo de banderines de colores a lo largo de la grada del fondo.
      final hilo = Paint()
        ..strokeWidth = max(1, pie * 0.12)
        ..color = const Color(0x55FFFFFF);
      canvas.drawLine(p(-2.5, -3.4), p(a + 2.5, -3.4), hilo);
      for (var k = 0; k < 22; k++) {
        final x = -2.5 + (a + 5) * k / 21;
        final c = p(x, -3.4);
        final ondea = sin(t * 2 + k) * pie * 0.18;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - pie * 0.55, c.dy)
            ..lineTo(c.dx + pie * 0.55, c.dy)
            ..lineTo(c.dx + ondea, c.dy + pie * 1.5),
          Paint()..color = [colores[0], const Color(0xFFE9E9E4), colores[4]][k % 3].withValues(alpha: 0.9),
        );
      }
    }
  }
}
