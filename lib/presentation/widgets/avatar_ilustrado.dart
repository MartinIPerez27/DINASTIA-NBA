import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/avatar_creado.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';

enum PeloEstilo { calvo, corto, rapado, rizado, mono, largo, vincha }

/// Rasgos del retrato de un jugador, todos derivados de un hash estable de su id: el mismo jugador
/// se ve igual siempre, en cualquier carta, y no dependen de la franquicia ni de la época.
class PerfilAvatar {
  const PerfilAvatar({
    required this.piel,
    required this.pelo,
    required this.estilo,
    required this.anchoCabeza,
    required this.altoCabeza,
    required this.barba,
  });

  final Color piel;
  final Color pelo;
  final PeloEstilo estilo;

  /// Factores sobre la cabeza base (≈ 0,92–1,08).
  final double anchoCabeza;
  final double altoCabeza;
  final bool barba;

  /// Tonos de piel de claro a oscuro: una escala amplia y neutra.
  static const pieles = [
    Color(0xFFF3D2B3),
    Color(0xFFE5B890),
    Color(0xFFCD955F),
    Color(0xFFA9703F),
    Color(0xFF7C4A2A),
    Color(0xFF52311F),
  ];

  static const pelos = [Color(0xFF16110E), Color(0xFF2D1E16), Color(0xFF4B3321), Color(0xFF7A5A36), Color(0xFF9A9A98)];

  /// Colores de pelo que ofrece el creador: los del retrato automático más tres (rubio, colorado, blanco).
  /// El orden coincide con el índice de `AvatarCreado.pelo`.
  static const pelosCreador = [...pelos, Color(0xFFD9B26A), Color(0xFF9C3B1E), Color(0xFFEDEDEA)];

  /// Hash FNV-1a de 32 bits: estable entre sesiones y plataformas (no usa `hashCode`).
  static int hash(String clave) {
    var h = 0x811c9dc5;
    for (final b in clave.codeUnits) {
      h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    // Mezcla final para repartir bien los bits bajos.
    h ^= h >> 16;
    h = (h * 0x45d9f3b) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h;
  }

  /// Retrato que armó el usuario al crear su jugador (código de `AvatarCreado`).
  factory PerfilAvatar.creado(AvatarCreado a) => PerfilAvatar(
    piel: pieles[a.piel.clamp(0, pieles.length - 1)],
    pelo: pelosCreador[a.pelo.clamp(0, pelosCreador.length - 1)],
    estilo: PeloEstilo.values[a.estilo.clamp(0, PeloEstilo.values.length - 1)],
    anchoCabeza: 0.92 + a.ancho * 0.02,
    altoCabeza: 0.95 + a.alto * 0.02,
    barba: a.barba && a.estilo != PeloEstilo.largo.index,
  );

  /// Retrato de la persona identificada por [clave] (id de Basketball-Reference o id de carta).
  factory PerfilAvatar.de(String clave) {
    final h = hash(clave);
    int toma(int desde, int n) => ((h >> desde) & 0xFF) % n;
    final estilo = PeloEstilo.values[toma(8, PeloEstilo.values.length)];
    return PerfilAvatar(
      piel: pieles[toma(0, pieles.length)],
      pelo: pelos[toma(16, pelos.length)],
      estilo: estilo,
      anchoCabeza: 0.92 + toma(24, 9) * 0.02,
      altoCabeza: 0.95 + toma(27, 8) * 0.02,
      barba: estilo != PeloEstilo.largo && toma(5, 4) == 0,
    );
  }
}

/// Retrato estilizado para quien no tiene foto: busto sobre el panel del tablero, con la camiseta de
/// la franquicia (sin dorsal: el catálogo no los tiene todos) y las iniciales del jugador. Rostro sin
/// rasgos a propósito: es una silueta, no un retrato.
class AvatarIlustrado extends StatelessWidget {
  const AvatarIlustrado({super.key, required this.jugador, required this.franquicia, this.iniciales = true});

  final Jugador jugador;
  final Franquicia franquicia;

  /// Iniciales en el pecho. Las cartas (que ya muestran el nombre y tapan el pecho) las omiten.
  final bool iniciales;

  @override
  Widget build(BuildContext context) {
    final panel = Theme.of(context).colorScheme.surfaceContainerLowest;
    return LayoutBuilder(
      builder: (context, c) {
        final propio = AvatarCreado.deCodigo(jugador.avatar);
        final perfil = propio != null ? PerfilAvatar.creado(propio) : PerfilAvatar.de(jugador.idBbref);
        final primario = Color(franquicia.colorPrimario), secundario = Color(franquicia.colorSecundario);
        // Camiseta: el color principal; si se pierde contra el panel (negro, gris oscuro), el secundario.
        final camiseta = _contraste(primario, panel) >= 1.6 ? primario : secundario;
        final ribete = camiseta == primario ? secundario : primario;
        final led = colorLed(franquicia);
        final lado = c.biggest.shortestSide;
        final cuerpo = _Retrato(perfil: perfil, panel: panel, camiseta: camiseta, ribete: ribete, led: led);
        return ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: cuerpo),
              if (iniciales && lado >= 44)
                Positioned.fill(
                  child: _Iniciales(
                    texto: jugador.iniciales,
                    color: _legibleSobre(camiseta, ribete),
                    alto: c.maxHeight,
                    ancho: c.maxWidth,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static double _contraste(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
    return (claro + 0.05) / (oscuro + 0.05);
  }

  /// Color de las iniciales sobre la camiseta: el ribete si contrasta, si no blanco o negro.
  static Color _legibleSobre(Color camiseta, Color ribete) {
    if (_contraste(camiseta, ribete) >= 3) return ribete;
    return camiseta.computeLuminance() > 0.4 ? Colors.black : Colors.white;
  }
}

/// Iniciales en el pecho, ubicadas con la misma geometría que el retrato.
class _Iniciales extends StatelessWidget {
  const _Iniciales({required this.texto, required this.color, required this.alto, required this.ancho});

  final String texto;
  final Color color;
  final double alto, ancho;

  @override
  Widget build(BuildContext context) {
    final g = _Geometria(Size(ancho, alto));
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: g.y(116) - g.s * 9,
          height: g.s * 18,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                texto,
                style: TextStyle(
                  fontFamily: Fuentes.estadio,
                  fontVariations: const [FontVariation.weight(800)],
                  color: color,
                  fontSize: g.s * 16,
                  height: 1,
                  letterSpacing: g.s * 0.8,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Figura en un cuadro virtual de 100×130 unidades, apoyada abajo y centrada en la caja.
class _Geometria {
  _Geometria(this.tam) : s = min(tam.width * 0.94 / 100, tam.height * 0.97 / 130);

  final Size tam;
  final double s;

  double x(double u) => tam.width / 2 + (u - 50) * s;
  double y(double u) => tam.height - (130 - u) * s;
  Offset p(double ux, double uy) => Offset(x(ux), y(uy));
}

class _Retrato extends CustomPainter {
  _Retrato({
    required this.perfil,
    required this.panel,
    required this.camiseta,
    required this.ribete,
    required this.led,
  });

  final PerfilAvatar perfil;
  final Color panel, camiseta, ribete, led;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geometria(size);
    final s = g.s;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Fondo: panel con un resplandor LED detrás de la cabeza y la línea del tablero abajo.
    canvas.drawRect(Offset.zero & size, Paint()..color = panel);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [led.withValues(alpha: 0.22), led.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: g.p(50, 52), radius: 60 * s)),
    );

    final sombraPiel = Color.lerp(perfil.piel, Colors.black, 0.22)!;
    final pielPaint = Paint()..color = perfil.piel;

    // Hombros y brazos (piel): la camiseta es sin mangas.
    final hombros = Path()
      ..moveTo(g.x(4), g.y(130))
      ..cubicTo(g.x(4), g.y(110), g.x(14), g.y(98), g.x(34), g.y(94))
      ..lineTo(g.x(66), g.y(94))
      ..cubicTo(g.x(86), g.y(98), g.x(96), g.y(110), g.x(96), g.y(130))
      ..close();
    canvas.drawPath(hombros, pielPaint);

    // Cuello.
    final cuello = RRect.fromRectAndRadius(Rect.fromPoints(g.p(41, 70), g.p(59, 100)), Radius.circular(6 * s));
    canvas.drawRRect(cuello, Paint()..color = sombraPiel);

    // Camiseta: tirantes anchos, escote en U y sisas.
    final remera = Path()
      ..moveTo(g.x(20), g.y(130))
      ..cubicTo(g.x(20), g.y(116), g.x(24), g.y(104), g.x(30), g.y(97))
      ..lineTo(g.x(38), g.y(94))
      ..cubicTo(g.x(40), g.y(106), g.x(45), g.y(111), g.x(50), g.y(111))
      ..cubicTo(g.x(55), g.y(111), g.x(60), g.y(106), g.x(62), g.y(94))
      ..lineTo(g.x(70), g.y(97))
      ..cubicTo(g.x(76), g.y(104), g.x(80), g.y(116), g.x(80), g.y(130))
      ..close();
    canvas.drawPath(remera, Paint()..color = camiseta);
    // Ribete del escote y las sisas.
    final borde = Paint()
      ..color = ribete
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, 2.6 * s)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(g.x(38), g.y(94))
        ..cubicTo(g.x(40), g.y(106), g.x(45), g.y(111), g.x(50), g.y(111))
        ..cubicTo(g.x(55), g.y(111), g.x(60), g.y(106), g.x(62), g.y(94)),
      borde,
    );
    canvas.drawPath(
      Path()
        ..moveTo(g.x(30), g.y(97))
        ..cubicTo(g.x(24), g.y(104), g.x(20), g.y(116), g.x(20), g.y(130))
        ..moveTo(g.x(70), g.y(97))
        ..cubicTo(g.x(76), g.y(104), g.x(80), g.y(116), g.x(80), g.y(130)),
      borde,
    );

    // Cabeza (con sus proporciones propias) y orejas.
    final cx = 50.0, cy = 52.0;
    final rx = 18.0 * perfil.anchoCabeza, ry = 22.0 * perfil.altoCabeza;
    canvas.drawOval(Rect.fromCenter(center: g.p(cx - rx + 1, cy + 2), width: 7 * s, height: 11 * s), pielPaint);
    canvas.drawOval(Rect.fromCenter(center: g.p(cx + rx - 1, cy + 2), width: 7 * s, height: 11 * s), pielPaint);
    final cabeza = Rect.fromCenter(center: g.p(cx, cy), width: 2 * rx * s, height: 2 * ry * s);

    final peloPaint = Paint()..color = perfil.pelo;
    // Pelo que va detrás de la cabeza (largo).
    if (perfil.estilo == PeloEstilo.largo) {
      final detras = RRect.fromRectAndRadius(
        Rect.fromPoints(g.p(cx - rx - 3, cy - 8), g.p(cx + rx + 3, cy + 34)),
        Radius.circular(12 * s),
      );
      canvas.drawRRect(detras, peloPaint);
    }
    canvas.drawOval(cabeza, pielPaint);
    // Sombra suave del lado derecho para dar volumen.
    canvas.save();
    canvas.clipPath(Path()..addOval(cabeza));
    canvas.drawOval(
      cabeza.shift(Offset(rx * 0.5 * s, 0)).inflate(2 * s),
      Paint()..color = sombraPiel.withValues(alpha: 0.28),
    );
    canvas.restore();

    // Barba corta: sombra en la parte baja de la cara.
    if (perfil.barba) {
      canvas.save();
      canvas.clipPath(Path()..addOval(cabeza));
      canvas.drawRect(
        Rect.fromPoints(g.p(cx - rx - 2, cy + ry * 0.35), g.p(cx + rx + 2, cy + ry + 3)),
        Paint()..color = perfil.pelo.withValues(alpha: 0.78),
      );
      canvas.restore();
    }

    _pelo(canvas, g, cabeza, rx, ry, peloPaint);
    canvas.restore();
  }

  void _pelo(Canvas canvas, _Geometria g, Rect cabeza, double rx, double ry, Paint pelo) {
    final s = g.s;
    final arriba = cabeza.top;
    // Casquete: la parte alta de la cabeza.
    Path casquete(double bajada) => Path()
      ..moveTo(cabeza.left - 1.5 * s, cabeza.center.dy - ry * 0.12 * s)
      ..cubicTo(
        cabeza.left - 2 * s,
        arriba - 4 * s,
        cabeza.right + 2 * s,
        arriba - 4 * s,
        cabeza.right + 1.5 * s,
        cabeza.center.dy - ry * 0.12 * s,
      )
      ..cubicTo(
        cabeza.right - 2 * s,
        cabeza.center.dy - ry * bajada * s,
        cabeza.left + 2 * s,
        cabeza.center.dy - ry * bajada * s,
        cabeza.left - 1.5 * s,
        cabeza.center.dy - ry * 0.12 * s,
      );
    switch (perfil.estilo) {
      case PeloEstilo.calvo:
        // Un brillo suave en la coronilla.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cabeza.center.dx - rx * 0.3 * s, arriba + ry * 0.35 * s),
            width: rx * 0.7 * s,
            height: ry * 0.28 * s,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.16),
        );
      case PeloEstilo.rapado:
        canvas.drawPath(casquete(0.62), Paint()..color = perfil.pelo.withValues(alpha: 0.5));
      case PeloEstilo.corto || PeloEstilo.mono || PeloEstilo.vincha:
        canvas.drawPath(casquete(0.5), pelo);
      case PeloEstilo.largo:
        canvas.drawPath(casquete(0.42), pelo);
      case PeloEstilo.rizado:
        // Cúmulo de rulos redondos sobre la frente.
        for (var i = 0; i < 7; i++) {
          final t = i / 6;
          final ang = pi + t * pi;
          final centro = Offset(
            cabeza.center.dx + cos(ang) * rx * 0.92 * s,
            cabeza.center.dy - ry * 0.18 * s + sin(ang) * ry * 0.95 * s,
          );
          canvas.drawCircle(centro, 5.2 * s, pelo);
        }
        canvas.drawPath(casquete(0.55), pelo);
    }
    if (perfil.estilo == PeloEstilo.mono) {
      canvas.drawCircle(Offset(cabeza.center.dx, arriba - 3 * s), 6 * s, pelo);
    }
    if (perfil.estilo == PeloEstilo.vincha) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cabeza.left - 1 * s,
            cabeza.center.dy - ry * 0.42 * s,
            cabeza.right + 1 * s,
            cabeza.center.dy - ry * 0.26 * s,
          ),
          Radius.circular(2 * s),
        ),
        Paint()..color = ribete,
      );
    }
  }

  @override
  bool shouldRepaint(_Retrato old) =>
      old.perfil != perfil || old.panel != panel || old.camiseta != camiseta || old.ribete != ribete || old.led != led;
}
