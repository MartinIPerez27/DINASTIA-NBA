import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/avatar_creado.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';

/// Los siete primeros son los del retrato automático; el resto solo los usa el creador de jugador (mismo orden que
/// `AvatarCreado.nombresEstilo`).
enum PeloEstilo {
  calvo,
  corto,
  rapado,
  rizado,
  mono,
  largo,
  vincha,
  afro,
  trenzas,
  rastas,
  mohicano,
  plano,
  undercut,
  degrade,
  ondas,
  peinadoAtras,
  raya,
  colitaAlta,
  dosMonos,
  rulosLargos;

  /// Cuántos usa el retrato automático (no cambia: así los jugadores sin foto se ven igual que siempre).
  static const automaticos = 7;
}

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
    this.barbaTipo = 0,
    this.conRostro = false,
    this.ojos = 0,
    this.cejas = 1,
    this.nariz = 1,
    this.boca = 0,
    this.orejas = 1,
    this.tatuaje = 0,
    this.gafas = 0,
    this.cinta = false,
    this.cuerpo = 2,
  });

  final Color piel;
  final Color pelo;
  final PeloEstilo estilo;

  /// Factores sobre la cabeza base (≈ 0,92–1,08).
  final double anchoCabeza;
  final double altoCabeza;
  final bool barba;

  /// Rasgos finos (solo el avatar creado los dibuja; el retrato automático sigue siendo una silueta).
  final bool conRostro, cinta;
  final int barbaTipo, ojos, cejas, nariz, boca, orejas, tatuaje, gafas, cuerpo;

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
    barba: a.barba > 0 && a.estilo != PeloEstilo.largo.index,
    barbaTipo: a.estilo == PeloEstilo.largo.index ? 0 : a.barba,
    conRostro: true,
    ojos: a.ojos,
    cejas: a.cejas,
    nariz: a.nariz,
    boca: a.boca,
    orejas: a.orejas,
    tatuaje: a.tatuaje,
    gafas: a.gafas,
    cinta: a.cinta,
    cuerpo: a.cuerpo,
  );

  /// Retrato de la persona identificada por [clave] (id de Basketball-Reference o id de carta).
  factory PerfilAvatar.de(String clave) {
    final h = hash(clave);
    int toma(int desde, int n) => ((h >> desde) & 0xFF) % n;
    final estilo = PeloEstilo.values[toma(8, PeloEstilo.automaticos)];
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

    // Complexión: el torso se ensancha o se afina alrededor del centro (solo el avatar creado).
    final factorCuerpo = perfil.conRostro ? const [0.88, 0.95, 1.0, 1.07, 1.14][perfil.cuerpo.clamp(0, 4)] : 1.0;
    canvas.save();
    canvas.translate(g.x(50), 0);
    canvas.scale(factorCuerpo, 1);
    canvas.translate(-g.x(50), 0);
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
    if (perfil.conRostro) _tatuajes(canvas, g);
    if (perfil.cinta) {
      // Cinta de brazo con los colores del equipo, sobre el hombro izquierdo.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromPoints(g.p(6, 108), g.p(17, 114)), Radius.circular(2 * s)),
        Paint()..color = ribete,
      );
    }
    canvas.restore();

    // Cabeza (con sus proporciones propias) y orejas.
    final cx = 50.0, cy = 52.0;
    final rx = 18.0 * perfil.anchoCabeza, ry = 22.0 * perfil.altoCabeza;
    final oreja = perfil.conRostro ? const [5.0, 7.0, 9.5][perfil.orejas.clamp(0, 2)] : 7.0;
    canvas.drawOval(Rect.fromCenter(center: g.p(cx - rx + 1, cy + 2), width: oreja * s, height: (oreja + 4) * s), pielPaint);
    canvas.drawOval(Rect.fromCenter(center: g.p(cx + rx - 1, cy + 2), width: oreja * s, height: (oreja + 4) * s), pielPaint);
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

    if (perfil.conRostro) {
      _rasgos(canvas, g, cabeza, rx, ry, sombraPiel);
      _barba(canvas, g, cabeza, cx, cy, rx, ry);
    } else if (perfil.barba) {
      // Barba corta: sombra en la parte baja de la cara.
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

  /// Ojos, cejas, nariz, boca y gafas.
  void _rasgos(Canvas canvas, _Geometria g, Rect cabeza, double rx, double ry, Color sombraPiel) {
    final s = g.s;
    final oscuro = Paint()..color = const Color(0xFF1A1210);
    final cy = cabeza.center.dy;
    final cx = cabeza.center.dx;
    final sepOjos = rx * 0.42 * s;
    final yOjos = cy - ry * 0.05 * s;
    // Ojos.
    final (ancho, alto, inclin) = switch (perfil.ojos) {
      1 => (4.6, 2.2, -0.25), // rasgados
      2 => (4.8, 3.6, 0.0), // grandes
      3 => (4.2, 2.6, 0.3), // caídos
      4 => (4.4, 2.0, 0.0), // serios
      5 => (3.2, 2.2, 0.0), // pequeños
      _ => (4.2, 2.8, 0.0), // clásicos
    };
    for (final lado in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx + lado * sepOjos, yOjos);
      canvas.rotate(inclin * lado);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: ancho * s * 1.6, height: alto * s), Paint()..color = Colors.white.withValues(alpha: 0.92));
      canvas.drawCircle(Offset(lado * 0.2 * s, 0), min(ancho, alto * 1.3) * 0.38 * s, oscuro);
      canvas.restore();
    }
    // Cejas.
    final grosor = const [0.9, 1.4, 2.2, 1.4, 1.8][perfil.cejas.clamp(0, 4)] * s;
    final ceja = Paint()
      ..color = perfil.pelo.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, grosor)
      ..strokeCap = StrokeCap.round;
    for (final lado in [-1.0, 1.0]) {
      final x0 = cx + lado * (sepOjos - 3.8 * s), x1 = cx + lado * (sepOjos + 3.8 * s);
      final yc = yOjos - 4.6 * s;
      final p = Path();
      if (perfil.cejas == 3) {
        p
          ..moveTo(x0, yc + 0.8 * s)
          ..quadraticBezierTo((x0 + x1) / 2, yc - 2.2 * s, x1, yc + 0.8 * s);
      } else if (perfil.cejas == 4) {
        final dentro = lado < 0 ? x1 : x0, fuera = lado < 0 ? x0 : x1;
        p
          ..moveTo(fuera, yc - 1.2 * s)
          ..lineTo(dentro, yc + 1.4 * s);
      } else {
        p
          ..moveTo(x0, yc)
          ..lineTo(x1, yc);
      }
      canvas.drawPath(p, ceja);
    }
    // Nariz.
    final trazo = Paint()
      ..color = sombraPiel.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.9, 1.2 * s)
      ..strokeCap = StrokeCap.round;
    final yNariz = cy + ry * 0.22 * s;
    final anchoNariz = const [2.4, 3.2, 4.6, 3.2, 2.8][perfil.nariz.clamp(0, 4)] * s;
    final p = Path()
      ..moveTo(cx - anchoNariz, yNariz)
      ..quadraticBezierTo(cx, yNariz + (perfil.nariz == 4 ? -1.4 : 1.6) * s, cx + anchoNariz, yNariz);
    canvas.drawPath(p, trazo);
    if (perfil.nariz == 3) {
      canvas.drawLine(Offset(cx, yOjos + 2 * s), Offset(cx - 0.6 * s, yNariz), trazo);
    }
    // Boca.
    final yBoca = cy + ry * 0.55 * s;
    final boca = Paint()
      ..color = const Color(0xFF5A2A22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, 1.5 * s)
      ..strokeCap = StrokeCap.round;
    final m = Path();
    switch (perfil.boca) {
      case 1:
        m
          ..moveTo(cx - 4 * s, yBoca)
          ..quadraticBezierTo(cx, yBoca + 3.2 * s, cx + 4 * s, yBoca);
      case 2:
        m
          ..moveTo(cx - 5.5 * s, yBoca - 0.4 * s)
          ..quadraticBezierTo(cx, yBoca + 5 * s, cx + 5.5 * s, yBoca - 0.4 * s);
        canvas.drawPath(m, boca);
        canvas.drawPath(
          Path()
            ..moveTo(cx - 4 * s, yBoca + 0.4 * s)
            ..quadraticBezierTo(cx, yBoca + 3.6 * s, cx + 4 * s, yBoca + 0.4 * s)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        m.reset();
      case 3:
        m
          ..moveTo(cx - 4 * s, yBoca + 0.8 * s)
          ..lineTo(cx + 1 * s, yBoca)
          ..lineTo(cx + 4.4 * s, yBoca - 1.2 * s);
      case 4:
        m
          ..moveTo(cx - 2.2 * s, yBoca)
          ..lineTo(cx + 2.2 * s, yBoca);
      default:
        m
          ..moveTo(cx - 3.8 * s, yBoca)
          ..lineTo(cx + 3.8 * s, yBoca);
    }
    canvas.drawPath(m, boca);
    // Gafas.
    if (perfil.gafas > 0) {
      final marco = Paint()
        ..color = const Color(0xFF111111)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, 1.4 * s);
      final cristal = Paint()..color = perfil.gafas == 3 ? const Color(0xFF0B0B0F).withValues(alpha: 0.92) : Colors.lightBlue.withValues(alpha: 0.18);
      switch (perfil.gafas) {
        case 2:
          for (final lado in [-1.0, 1.0]) {
            final c = Offset(cx + lado * sepOjos, yOjos);
            canvas.drawCircle(c, 5.4 * s, cristal);
            canvas.drawCircle(c, 5.4 * s, marco);
          }
          canvas.drawLine(Offset(cx - sepOjos + 5.4 * s, yOjos), Offset(cx + sepOjos - 5.4 * s, yOjos), marco);
        default:
          final r = RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - sepOjos - 6.5 * s, yOjos - 4 * s, cx + sepOjos + 6.5 * s, yOjos + 4 * s),
            Radius.circular(perfil.gafas == 1 ? 4 * s : 2 * s),
          );
          canvas.drawRRect(r, cristal);
          canvas.drawRRect(r, marco);
      }
    }
  }

  /// Seis tipos de barba y bigote.
  void _barba(Canvas canvas, _Geometria g, Rect cabeza, double cx, double cy, double rx, double ry) {
    if (perfil.barbaTipo == 0) return;
    final s = g.s;
    final tinta = Paint()..color = perfil.pelo.withValues(alpha: 0.88);
    canvas.save();
    canvas.clipPath(Path()..addOval(cabeza));
    switch (perfil.barbaTipo) {
      case 1: // sombra
        canvas.drawRect(
          Rect.fromPoints(g.p(cx - rx - 2, cy + ry * 0.35), g.p(cx + rx + 2, cy + ry + 3)),
          Paint()..color = perfil.pelo.withValues(alpha: 0.55),
        );
      case 4: // completa
        canvas.drawRect(Rect.fromPoints(g.p(cx - rx - 2, cy + ry * 0.18), g.p(cx + rx + 2, cy + ry + 3)), tinta);
        // Se deja libre la boca.
        canvas.drawOval(Rect.fromCenter(center: g.p(cx, cy + ry * 0.55), width: 11 * s, height: 6 * s), Paint()..color = perfil.piel);
      case 2: // candado: bigote + perilla
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: g.p(cx, cy + ry * 0.42), width: 14 * s, height: 2.6 * s), Radius.circular(1.5 * s)), tinta);
        canvas.drawOval(Rect.fromCenter(center: g.p(cx, cy + ry * 0.82), width: 10 * s, height: 9 * s), tinta);
      case 3: // perilla
        canvas.drawOval(Rect.fromCenter(center: g.p(cx, cy + ry * 0.82), width: 8 * s, height: 8 * s), tinta);
      case 5: // bigote
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: g.p(cx, cy + ry * 0.42), width: 15 * s, height: 3.2 * s), Radius.circular(1.6 * s)), tinta);
      case 6: // chivita
        canvas.drawOval(Rect.fromCenter(center: g.p(cx, cy + ry * 0.9), width: 4 * s, height: 5 * s), tinta);
    }
    canvas.restore();
  }

  /// Tatuajes sobre el cuello y los hombros (formas simples, de un solo color).
  void _tatuajes(Canvas canvas, _Geometria g) {
    final t = perfil.tatuaje;
    if (t == 0) return;
    final s = g.s;
    final tinta = Paint()
      ..color = const Color(0xFF1E2A44).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, 1.6 * s)
      ..strokeCap = StrokeCap.round;
    void hombro(double x) {
      canvas.drawPath(
        Path()
          ..moveTo(g.x(x), g.y(102))
          ..quadraticBezierTo(g.x(x + 5), g.y(106), g.x(x), g.y(112))
          ..moveTo(g.x(x + 4), g.y(100))
          ..quadraticBezierTo(g.x(x + 9), g.y(105), g.x(x + 4), g.y(110)),
        tinta,
      );
    }

    void cuello() {
      canvas.drawLine(g.p(43, 86), g.p(48, 90), tinta);
      canvas.drawLine(g.p(57, 86), g.p(52, 90), tinta);
      canvas.drawLine(g.p(46, 92), g.p(54, 92), tinta);
    }

    if (t == 1 || t == 4) hombro(10);
    if (t == 3) {
      hombro(10);
      hombro(84);
    }
    if (t == 2 || t == 4) cuello();
  }

  /// Los trece peinados que no usa el retrato automático.
  void _peloNuevo(Canvas canvas, _Geometria g, Rect cabeza, double rx, double ry, Paint pelo, Path Function(double) casquete) {
    final s = g.s;
    final arriba = cabeza.top;
    final cx = cabeza.center.dx;
    final trazo = Paint()
      ..color = Color.lerp(perfil.pelo, Colors.black, 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, 1.1 * s)
      ..strokeCap = StrokeCap.round;
    switch (perfil.estilo) {
      case PeloEstilo.afro:
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, arriba + ry * 0.12 * s), width: (2 * rx + 12) * s, height: ry * 0.95 * s), pelo);
      case PeloEstilo.trenzas:
        canvas.drawPath(casquete(0.5), pelo);
        for (var i = -3; i <= 3; i++) {
          canvas.drawLine(Offset(cx + i * rx * 0.26 * s, arriba - 1 * s), Offset(cx + i * rx * 0.3 * s, cabeza.center.dy - ry * 0.3 * s), trazo);
        }
      case PeloEstilo.rastas:
        canvas.drawPath(casquete(0.5), pelo);
        for (var i = -4; i <= 4; i++) {
          final x = cx + i * rx * 0.24 * s;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(x - 1.6 * s, arriba + ry * 0.2 * s, x + 1.6 * s, (i.abs() < 3 ? cabeza.center.dy - ry * 0.32 * s : cabeza.center.dy + ry * (0.3 + 0.08 * (i.abs() % 3)) * s)), Radius.circular(1.6 * s)),
            pelo,
          );
        }
      case PeloEstilo.mohicano:
        canvas.drawPath(casquete(0.62), Paint()..color = perfil.pelo.withValues(alpha: 0.35));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - 3.4 * s, arriba - 7 * s, cx + 3.4 * s, cabeza.center.dy - ry * 0.2 * s), Radius.circular(3 * s)), pelo);
      case PeloEstilo.plano:
        canvas.drawPath(casquete(0.5), pelo);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - rx * 0.8 * s, arriba - 6 * s, cx + rx * 0.8 * s, arriba + 4 * s), Radius.circular(2 * s)), pelo);
      case PeloEstilo.undercut:
        canvas.drawPath(casquete(0.62), Paint()..color = perfil.pelo.withValues(alpha: 0.4));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - rx * 0.7 * s, arriba - 4 * s, cx + rx * 0.7 * s, arriba + ry * 0.3 * s), Radius.circular(4 * s)), pelo);
      case PeloEstilo.degrade:
        canvas.drawPath(casquete(0.68), Paint()..color = perfil.pelo.withValues(alpha: 0.35));
        canvas.drawPath(casquete(0.48), Paint()..color = perfil.pelo.withValues(alpha: 0.8));
      case PeloEstilo.ondas:
        canvas.drawPath(casquete(0.5), pelo);
        for (var i = 0; i < 3; i++) {
          final y = arriba + ry * (0.1 + i * 0.12) * s;
          canvas.drawPath(
            Path()
              ..moveTo(cx - rx * 0.7 * s, y)
              ..quadraticBezierTo(cx - rx * 0.35 * s, y - 2 * s, cx, y)
              ..quadraticBezierTo(cx + rx * 0.35 * s, y + 2 * s, cx + rx * 0.7 * s, y),
            trazo,
          );
        }
      case PeloEstilo.peinadoAtras:
        canvas.drawPath(casquete(0.55), pelo);
        canvas.drawPath(
          Path()
            ..moveTo(cx - rx * 0.5 * s, cabeza.center.dy - ry * 0.35 * s)
            ..quadraticBezierTo(cx, arriba - 1 * s, cx + rx * 0.5 * s, cabeza.center.dy - ry * 0.35 * s),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * s,
        );
      case PeloEstilo.raya:
        canvas.drawPath(casquete(0.5), pelo);
        canvas.drawLine(Offset(cx - rx * 0.4 * s, arriba), Offset(cx - rx * 0.1 * s, cabeza.center.dy - ry * 0.3 * s), trazo);
      case PeloEstilo.colitaAlta:
        canvas.drawPath(casquete(0.5), pelo);
        canvas.drawCircle(Offset(cx + rx * 0.5 * s, arriba - 2 * s), 4.5 * s, pelo);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx + rx * 0.5 * s - 2 * s, arriba - 2 * s, cx + rx * 0.5 * s + 2 * s, arriba + 14 * s), Radius.circular(2 * s)), pelo);
      case PeloEstilo.dosMonos:
        canvas.drawPath(casquete(0.5), pelo);
        canvas.drawCircle(Offset(cx - rx * 0.6 * s, arriba - 1 * s), 5 * s, pelo);
        canvas.drawCircle(Offset(cx + rx * 0.6 * s, arriba - 1 * s), 5 * s, pelo);
      case PeloEstilo.rulosLargos:
        canvas.drawPath(casquete(0.5), pelo);
        for (var i = 0; i < 6; i++) {
          final lado = i.isEven ? -1.0 : 1.0;
          final y = cabeza.center.dy + (i ~/ 2) * 7 * s - ry * 0.1 * s;
          canvas.drawCircle(Offset(cx + lado * (rx + 1.5) * s, y), 4.2 * s, pelo);
        }
      default:
        break;
    }
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
      case _:
        _peloNuevo(canvas, g, cabeza, rx, ry, pelo, casquete);
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
