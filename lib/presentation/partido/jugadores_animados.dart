import 'dart:math';

import 'package:flutter/material.dart';

import '../tema/tema_franquicia.dart';

/// Hash estable (FNV-1a) de un texto: no cambia entre ejecuciones (a diferencia de `hashCode`),
/// así cada jugador tiene siempre el mismo tono de piel y las repeticiones se ven iguales.
int hashEstable(String texto) {
  var h = 0x811c9dc5;
  for (final c in texto.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Lo que está haciendo un jugador con el cuerpo (decide dónde van los brazos).
enum Pose {
  parado,
  corre,
  dribla,
  tira,
  bandeja,
  clava,
  defiende,
  contesta,
  rebotea,
  pasa,
  roba,
  pantalla,
  libre,
  tecnico,
}

/// Estado de ánimo tras una jugada importante.
enum Animo { neutro, celebra, bronca, manosCabeza }

/// Postura de un jugador en un instante: hacia dónde mira, cómo corre, qué hace con los brazos y
/// cómo se siente. La calcula `Coreografia.postura` a partir del recorrido real.
class PosturaJugador {
  const PosturaJugador({
    this.rumbo = 0,
    this.velocidad = 0,
    this.fase = 0,
    this.pose = Pose.parado,
    this.avance = 0,
    this.animo = Animo.neutro,
    this.intensidad = 0,
    this.giro = 0,
  });

  /// Radianes: 0 mira hacia arriba (−y), positivo en sentido horario.
  final double rumbo;

  /// Pies por segundo.
  final double velocidad;

  /// Ciclo de la carrera (radianes): los brazos y las zapatillas se alternan con él.
  final double fase;
  final Pose pose;

  /// Avance de la acción actual (0–1): soltar el tiro, mover el brazo de la volcada, etc.
  final double avance;
  final Animo animo;

  /// Cuánto se nota el ánimo (0–1).
  final double intensidad;

  /// Giro extra del cuerpo (la volcada de 360°), en radianes.
  final double giro;
}

const _pieles = [Color(0xFFF1C9A5), Color(0xFFD9A06B), Color(0xFF9A6A43), Color(0xFF5E3B22)];
const _pelos = [Color(0xFF1A1411), Color(0xFF2A1B12), Color(0xFF3B2A1C), Color(0xFF0E0E10)];

/// Cache de los rótulos (iniciales): el texto es lo más caro de dibujar y casi nunca cambia.
final _rotulos = <String, TextPainter>{};

TextPainter _rotulo(String texto, double tamano, Color color) {
  final clave = '$texto|${tamano.round()}|${color.toARGB32()}';
  var tp = _rotulos[clave];
  if (tp == null) {
    if (_rotulos.length > 400) _rotulos.clear();
    tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: const [FontVariation.weight(800)],
          fontSize: tamano.roundToDouble(),
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _rotulos[clave] = tp;
  }
  return tp;
}

/// Dibuja a un jugador visto desde arriba como una figura estilizada: sombra, zapatillas que se
/// alternan al correr, brazos según la pose, camiseta con los colores del equipo (ribete en las
/// sisas y el cuello), cabeza con pelo (la cara marca hacia dónde mira) y las iniciales como
/// identificador, siempre derechas para que se lean.
///
/// [c] es el centro en píxeles; [pie] los píxeles por pie; [salto] 0–1; [t] el tiempo (s) para los
/// gestos y las chispas.
void dibujarJugador(
  Canvas canvas, {
  required Offset c,
  required double pie,
  required PosturaJugador postura,
  required Color camiseta,
  required Color numero,
  required Color ribete,
  required String etiqueta,
  required int semilla,
  required double salto,
  required double opacidad,
  required double tiempo,
  required Color destello,
}) {
  final a = opacidad;
  final piel = _pieles[semilla % _pieles.length];
  final pelo = _pelos[(semilla >> 3) % _pelos.length];
  final p = postura;
  // Celebrar rebota; la bronca encoge un poco al jugador.
  final rebote = p.animo == Animo.celebra ? (sin(tiempo * 11 + semilla) * 0.5 + 0.5) * 0.14 * p.intensidad : 0.0;
  final encoge = p.animo == Animo.bronca ? 0.06 * p.intensidad : 0.0;
  final altura = salto.clamp(0.0, 1.0);
  final escala = 1 + 0.32 * altura + rebote - encoge;
  final u = pie * escala;
  final enAccion = p.pose != Pose.parado && p.pose != Pose.corre && p.pose != Pose.dribla && p.pose != Pose.defiende;
  final animoPisa = p.animo != Animo.neutro && !enAccion && altura < 0.05;

  // Sombra: se corre y se achica cuando salta (la luz viene de arriba a la izquierda).
  canvas.drawOval(
    Rect.fromCenter(
      center: c + Offset(pie * (0.45 + 1.6 * altura), pie * (0.7 + 2.3 * altura)),
      width: pie * 3.9 * (1 - 0.12 * altura),
      height: pie * 2.9 * (1 - 0.12 * altura),
    ),
    Paint()..color = Colors.black.withValues(alpha: (0.34 - 0.13 * altura) * a),
  );

  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(p.rumbo + p.giro);
  final fill = Paint();
  final trazo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // Zapatillas: al correr se alternan hacia adelante y atrás.
  final ritmo = (p.velocidad / 16).clamp(0.0, 1.0);
  final paso = sin(p.fase) * 1.25 * ritmo;
  final defensa = p.pose == Pose.defiende ? 0.55 : 0.0;
  for (final lado in [-1.0, 1.0]) {
    final y = 0.7 + lado * paso * 0.9;
    final x = lado * (0.85 + defensa);
    final zapatilla = Rect.fromCenter(center: Offset(x * u, y * u), width: 0.95 * u, height: 1.7 * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(zapatilla, Radius.circular(0.45 * u)),
      fill..color = const Color(0xFF14161A).withValues(alpha: a),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(zapatilla.deflate(0.28 * u), Radius.circular(0.2 * u)),
      fill..color = Colors.white.withValues(alpha: 0.85 * a),
    );
  }

  // Brazos (detrás del torso: se ve el hombro y la mano).
  final manos = _manos(p, tiempo, semilla);
  final grosor = 0.95 * u;
  for (final (i, lado) in [-1.0, 1.0].indexed) {
    final hombro = Offset(lado * 1.55 * u, -0.1 * u);
    final mano = manos[i] * u;
    final codo = Offset.lerp(hombro, mano, 0.5)! + Offset(lado * 0.35 * u, 0.15 * u);
    final brazo = Path()
      ..moveTo(hombro.dx, hombro.dy)
      ..quadraticBezierTo(codo.dx, codo.dy, mano.dx, mano.dy);
    canvas.drawPath(
      brazo,
      trazo
        ..color = piel.withValues(alpha: a)
        ..strokeWidth = grosor,
    );
    // Muñequera/puño: un punto del color de la camiseta cerca de la mano para que se lea el gesto.
    canvas.drawCircle(mano, 0.62 * u, fill..color = piel.withValues(alpha: a));
  }

  // Torso: camiseta con sisas y cuello en el segundo color.
  final torso = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(0, 0.15 * u), width: 3.9 * u, height: 3.0 * u),
    Radius.circular(1.25 * u),
  );
  canvas.drawRRect(torso, fill..color = camiseta.withValues(alpha: a));
  // Sombreado inferior para dar volumen.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(-1.95 * u, 0.9 * u, 3.9 * u, 0.75 * u), Radius.circular(0.7 * u)),
    fill..color = Colors.black.withValues(alpha: 0.16 * a),
  );
  canvas.drawRRect(
    torso.deflate(0.17 * u),
    trazo
      ..color = ribete.withValues(alpha: a)
      ..strokeWidth = 0.34 * u,
  );
  // Cabeza: el pelo cubre la nuca y la cara queda hacia adelante.
  final cabeza = Offset(0, (-0.75 + (p.animo == Animo.bronca ? 0.35 * p.intensidad : 0)) * u);
  canvas.drawCircle(cabeza, 0.98 * u, fill..color = piel.withValues(alpha: a));
  canvas.drawCircle(cabeza + Offset(0, 0.2 * u), 0.9 * u, fill..color = pelo.withValues(alpha: a));
  canvas.restore();

  // Iniciales derechas, sobre la camiseta (detrás de la cabeza, en la espalda).
  final rotulo = _rotulo(etiqueta, u * 1.55, numero.withValues(alpha: a));
  final atras = Offset(sin(p.rumbo + p.giro), -cos(p.rumbo + p.giro)) * (-0.2 * u) + Offset(0, 0.62 * u);
  rotulo.paint(canvas, c + atras - Offset(rotulo.width / 2, rotulo.height / 2));

  // Chispas de festejo y gotas de bronca, alrededor del cuerpo.
  if (animoPisa && p.intensidad > 0.05) {
    if (p.animo == Animo.celebra) {
      final chispa = Paint()
        ..color = destello.withValues(alpha: (0.5 + 0.4 * sin(tiempo * 14)) * a * p.intensidad)
        ..strokeWidth = max(1.4, pie * 0.28)
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 7; k++) {
        final ang = k * 2 * pi / 7 + tiempo * 1.7;
        final d = Offset(cos(ang), sin(ang));
        canvas.drawLine(c + d * pie * 3.1, c + d * pie * (3.9 + 0.4 * sin(tiempo * 9 + k)), chispa);
      }
    } else if (p.animo == Animo.manosCabeza) {
      final gota = Paint()..color = const Color(0xFFBFE3FF).withValues(alpha: 0.85 * a * p.intensidad);
      canvas.drawCircle(c + Offset(pie * 2.3, -pie * (2.0 - ((tiempo * 1.6) % 1) * 0.8)), pie * 0.42, gota);
    }
  }
}

/// Posición de las manos (izquierda, derecha) en pies, en el marco del cuerpo (adelante = −y).
List<Offset> _manos(PosturaJugador p, double t, int semilla) {
  final balanceo = sin(p.fase);
  final ritmo = (p.velocidad / 16).clamp(0.0, 1.0);
  final animo = p.animo;
  final k = p.intensidad;
  // Con una pose de acción, manda la acción; si no, el ánimo.
  switch (p.pose) {
    case Pose.tira:
      final suelta = Curves.easeOut.transform(p.avance.clamp(0.0, 1.0));
      return [Offset(-0.75, -2.4 - 0.5 * suelta), Offset(0.75, -2.6 - 0.9 * suelta)];
    case Pose.bandeja:
      final suelta = Curves.easeOut.transform(p.avance.clamp(0.0, 1.0));
      return [Offset(-1.2, -1.2), Offset(0.4, -2.6 - 1.0 * suelta)];
    case Pose.clava:
      final ang = p.avance * 2 * pi * 1.25;
      return [const Offset(-1.0, -2.6), Offset(sin(ang) * 2.7, -cos(ang) * 2.7)];
    case Pose.defiende:
      final lateral = sin(t * 5.2 + semilla) * 0.35;
      return [Offset(-3.0 + lateral, -1.5), Offset(3.0 + lateral, -1.5)];
    case Pose.contesta:
      return [const Offset(-2.4, -0.8), Offset(0.35, -3.3 - 0.4 * sin(t * 12))];
    case Pose.rebotea:
      return [Offset(-1.45 - 0.4 * sin(t * 9 + semilla), -2.9), Offset(1.45 + 0.4 * sin(t * 9 + semilla), -2.9)];
    case Pose.pasa:
      final empuja = Curves.easeOut.transform(p.avance.clamp(0.0, 1.0));
      return [Offset(-0.7, -1.0 - 1.7 * empuja), Offset(0.7, -1.0 - 1.7 * empuja)];
    case Pose.roba:
      return [const Offset(-2.2, -0.6), Offset(1.0, -3.5)];
    case Pose.pantalla:
      return [const Offset(0.6, -1.1), const Offset(-0.6, -1.1)];
    case Pose.libre:
      final flexion = p.avance < 0.5 ? 0.0 : (p.avance - 0.5) * 2;
      return [Offset(-0.55, -1.25 - 1.1 * flexion), Offset(0.55, -1.25 - 1.1 * flexion)];
    case Pose.tecnico:
      // Señala y explica en la pizarra: un brazo marca, el otro se queda en la cadera.
      return [Offset(-1.9, 0.2), Offset(1.9 + sin(t * 3 + semilla), -2.4 + cos(t * 2.4) * 0.5)];
    case Pose.dribla:
      return [Offset(-1.8, -1.4), Offset(2.0, -1.2 + 0.5 * sin(t * 2 * pi * 1.8))];
    case Pose.parado || Pose.corre:
      break;
  }
  switch (animo) {
    case Animo.celebra:
      final f = sin(t * 10 + semilla) * 0.35;
      return [Offset(-2.5 + f, -2.7 * k - 0.4), Offset(2.5 - f, -2.7 * k - 0.4)];
    case Animo.manosCabeza:
      return [Offset(-0.62, -0.85 * k), Offset(0.62, -0.85 * k)].map((o) => Offset(o.dx, o.dy - 0.3)).toList();
    case Animo.bronca:
      return [Offset(-2.7, 0.6 + 0.4 * k), Offset(2.7, 0.6 + 0.4 * k)];
    case Animo.neutro:
      break;
  }
  return [Offset(-2.05, 0.1 + balanceo * 1.5 * ritmo), Offset(2.05, 0.1 - balanceo * 1.5 * ritmo)];
}

/// Silueta sentada (banco, técnico en la pizarra…) sin brazos animados: para el banco de suplentes.
void dibujarSentado(
  Canvas canvas, {
  required Offset c,
  required double pie,
  required Color camiseta,
  required Color ribete,
  required int semilla,
  required double levantado,
  required double tiempo,
}) {
  final piel = _pieles[semilla % _pieles.length];
  final pelo = _pelos[(semilla >> 3) % _pelos.length];
  // Sentado mira a la cancha (derecha en pantalla); de pie, crece y alza los brazos.
  final alza = levantado.clamp(0.0, 1.0);
  final u = pie * (1 + 0.2 * alza);
  final salto = alza > 0.6 ? (sin(tiempo * 9 + semilla) * 0.5 + 0.5) * 0.12 : 0.0;
  final fill = Paint();
  canvas.drawOval(
    Rect.fromCenter(center: c + Offset(pie * 0.4, pie * 0.6), width: pie * 3.2, height: pie * 2.6),
    fill..color = Colors.black.withValues(alpha: 0.3),
  );
  canvas.save();
  canvas.translate(c.dx, c.dy - salto * pie * 2);
  canvas.rotate(pi / 2);
  final trazo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.85 * u
    ..color = piel;
  if (alza > 0.05) {
    for (final lado in [-1.0, 1.0]) {
      canvas.drawLine(Offset(lado * 1.4 * u, 0), Offset(lado * (1.9 + 0.6 * alza) * u, -2.3 * alza * u), trazo);
    }
  } else {
    for (final lado in [-1.0, 1.0]) {
      canvas.drawLine(Offset(lado * 1.4 * u, 0), Offset(lado * 1.2 * u, -0.9 * u), trazo);
    }
  }
  final torso = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(0, 0.1 * u), width: 3.5 * u, height: 2.6 * u),
    Radius.circular(1.1 * u),
  );
  canvas.drawRRect(torso, fill..color = camiseta);
  canvas.drawRRect(
    torso.deflate(0.15 * u),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3 * u
      ..color = ribete,
  );
  canvas.drawCircle(Offset(0, -0.6 * u), 0.92 * u, fill..color = piel);
  canvas.drawCircle(Offset(0, -0.42 * u), 0.84 * u, fill..color = pelo);
  canvas.restore();
}

/// Colores de una camiseta para figuras de relleno (público, banco).
Color mezclar(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Útil en pruebas: el ángulo de rumbo entre dos puntos (0 = arriba).
double rumboHacia(Offset desde, Offset hasta) {
  final d = hasta - desde;
  return atan2(d.dx, -d.dy);
}

/// Interpolación de ángulos por el camino corto.
double mezclarAngulo(double a, double b, double t) {
  var d = (b - a) % (2 * pi);
  if (d > pi) d -= 2 * pi;
  if (d < -pi) d += 2 * pi;
  return a + d * t;
}

/// Pelo y piel, expuestos para el público (misma paleta).
({Color piel, Color pelo}) tonosDe(int semilla) =>
    (piel: _pieles[semilla % _pieles.length], pelo: _pelos[(semilla >> 3) % _pelos.length]);
