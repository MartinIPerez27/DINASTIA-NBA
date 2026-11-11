import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/plantel.dart';
import '../../domain/entities/posicion.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';

/// Media cancha vista desde el tablero (GDD §4.1): parqué, pintura con los colores de la franquicia,
/// escudo en el círculo central y una silueta de camiseta por puesto.
/// Coordenadas en pies reales: ancho 50, del medio campo (y=0) a la línea de fondo (y=47).
class Cancha extends StatelessWidget {
  const Cancha({
    super.key,
    required this.franquicia,
    required this.plantel,
    this.resaltadas = const {},
    this.onTocar,
    this.recienUbicada,
  });

  final Franquicia franquicia;
  final Plantel plantel;

  /// Puestos libres donde puede ir la carta elegida.
  final Set<Posicion> resaltadas;
  final ValueChanged<Posicion>? onTocar;

  /// Puesto que se acaba de llenar: se "enciende" una vez.
  final Posicion? recienUbicada;

  static const _ancho = 50.0, _arriba = -7.0, _fondo = 47.0;
  static const proporcion = _ancho / (_fondo - _arriba);

  static const _ubicacion = {
    Posicion.base: Offset(25, 13),
    Posicion.escolta: Offset(42, 22),
    Posicion.alero: Offset(8, 22),
    Posicion.alaPivot: Offset(37, 37.5),
    Posicion.pivot: Offset(13, 37.5),
    Posicion.sextoHombre: Offset(44, 3.5),
  };

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: proporcion,
    child: LayoutBuilder(
      builder: (context, c) {
        final pie = c.maxWidth / _ancho;
        Offset px(Offset p) => Offset(p.dx * pie, (p.dy - _arriba) * pie);
        final escudo = 9 * pie;
        final puestoAncho = 10 * pie, puestoAlto = 12 * pie;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _Parque(Color(franquicia.colorPrimario), Color(franquicia.colorSecundario)),
                ),
              ),
              Positioned(
                left: px(const Offset(25, 0)).dx - escudo / 2,
                top: px(const Offset(25, 0)).dy - escudo / 2,
                child: ExcludeSemantics(child: Escudo(franquicia, tamano: escudo)),
              ),
              for (final p in Posicion.values)
                Positioned(
                  left: px(_ubicacion[p]!).dx - puestoAncho / 2,
                  top: px(_ubicacion[p]!).dy - puestoAlto / 2,
                  width: puestoAncho,
                  height: puestoAlto,
                  child: _Puesto(
                    posicion: p,
                    jugador: plantel.en(p),
                    franquicia: franquicia,
                    resaltado: resaltadas.contains(p),
                    encender: recienUbicada == p,
                    onTap: onTocar == null ? null : () => onTocar!(p),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _Puesto extends StatelessWidget {
  const _Puesto({
    required this.posicion,
    required this.jugador,
    required this.franquicia,
    required this.resaltado,
    required this.encender,
    this.onTap,
  });

  final Posicion posicion;
  final Jugador? jugador;
  final Franquicia franquicia;
  final bool resaltado;
  final bool encender;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final jugador = this.jugador;
    final led = esquema.primary;
    final etiqueta = jugador == null ? posicion.etiqueta : _apellido(jugador.nombre);

    final Widget camiseta;
    if (jugador == null) {
      camiseta = CustomPaint(
        size: Size.infinite,
        painter: _Camiseta(
          relleno: resaltado ? led.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.18),
          borde: resaltado ? led : Colors.white.withValues(alpha: 0.7),
          grosor: resaltado ? 2.5 : 1.5,
        ),
      );
    } else {
      final uniforme = Color(franquicia.colorPrimario);
      final ribete = Color(franquicia.colorSecundario);
      final numero = uniforme.computeLuminance() > 0.4 ? Colors.black : Colors.white;
      camiseta = TweenAnimationBuilder<double>(
        key: ValueKey(jugador.id),
        tween: Tween(begin: encender && !MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, luz, _) => CustomPaint(
          painter: _Camiseta(relleno: Color.lerp(uniforme, led, luz * 0.8)!, borde: ribete, grosor: 2),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: FittedBox(
                child: Text(
                  '${jugador.dorsal}',
                  style: TextStyle(
                    fontFamily: Fuentes.led,
                    fontVariations: const [FontVariation.weight(900)],
                    fontSize: 22,
                    color: numero,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: onTap != null && jugador == null,
      label: jugador == null
          ? '${posicion.etiqueta}, vacío${resaltado ? ', disponible' : ''}'
          : '${posicion.etiqueta}: ${jugador.nombre}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Expanded(child: camiseta),
              const SizedBox(height: 2),
              // Placa del tablero bajo cada puesto: legible sobre la madera.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: esquema.surfaceContainerLowest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: FittedBox(
                    child: Text(
                      etiqueta.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: Fuentes.estadio,
                        fontVariations: const [FontVariation.weight(700)],
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: resaltado ? led : esquema.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _apellido(String nombre) {
    final partes = nombre.split(' ');
    return partes.length > 1 ? partes.sublist(1).join(' ') : nombre;
  }
}

/// Silueta de musculosa de básquet.
class _Camiseta extends CustomPainter {
  const _Camiseta({required this.relleno, required this.borde, required this.grosor});

  final Color relleno;
  final Color borde;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / 100, size.height / 110);
    canvas.translate((size.width - 100 * s) / 2, (size.height - 110 * s) / 2);
    canvas.scale(s);
    final forma = Path()
      ..moveTo(28, 2)
      ..lineTo(39, 2)
      ..quadraticBezierTo(50, 18, 61, 2)
      ..lineTo(72, 2)
      ..lineTo(74, 10)
      ..quadraticBezierTo(78, 30, 94, 34)
      ..lineTo(94, 108)
      ..lineTo(6, 108)
      ..lineTo(6, 34)
      ..quadraticBezierTo(22, 30, 26, 10)
      ..close();
    canvas.drawPath(forma, Paint()..color = relleno);
    canvas.drawPath(
      forma,
      Paint()
        ..color = borde
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor / s
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Camiseta a) => a.relleno != relleno || a.borde != borde || a.grosor != grosor;
}

/// Parqué con la pintura de la franquicia. Madera mate, sin brillo: las luces del estadio están bajas.
class _Parque extends CustomPainter {
  const _Parque(this.pintura, this.secundario);

  final Color pintura;
  final Color secundario;

  @override
  void paint(Canvas canvas, Size size) {
    final pie = size.width / Cancha._ancho;
    Offset p(double x, double y) => Offset(x * pie, (y - Cancha._arriba) * pie);

    // Tablas de madera a lo largo de la cancha, con tonos y juntas pseudoaleatorias fijas.
    const madera = Color(0xFF8A6240);
    final tabla = size.width / 36;
    final azar = Random(82);
    for (var i = 0; i * tabla < size.width; i++) {
      final tono = HSLColor.fromColor(madera);
      final color = tono.withLightness((tono.lightness + (azar.nextDouble() - 0.5) * 0.05).clamp(0, 1)).toColor();
      canvas.drawRect(Rect.fromLTWH(i * tabla, 0, tabla, size.height), Paint()..color = color);
      final junta = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..strokeWidth = 0.6;
      canvas.drawLine(Offset(i * tabla, 0), Offset(i * tabla, size.height), junta);
      for (var y = azar.nextDouble() * 60; y < size.height; y += 50 + azar.nextDouble() * 40) {
        canvas.drawLine(Offset(i * tabla, y), Offset((i + 1) * tabla, y), junta);
      }
    }

    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, pie * 0.25);

    // Pintura (zona) y círculo central con los colores del equipo.
    canvas.drawRect(Rect.fromPoints(p(17, 28), p(33, 47)), Paint()..color = pintura);
    canvas.drawCircle(p(25, 0), 6 * pie, Paint()..color = pintura.withValues(alpha: 0.85));

    canvas.drawLine(p(0, 0), p(50, 0), linea); // medio campo
    canvas.drawCircle(p(25, 0), 6 * pie, linea);
    canvas.drawRect(Rect.fromPoints(p(17, 28), p(33, 47)), linea); // zona
    canvas.drawCircle(p(25, 28), 6 * pie, linea); // tiro libre
    canvas.drawLine(p(22, 43), p(28, 43), linea..strokeWidth = pie * 0.4); // tablero
    linea.strokeWidth = max(1.5, pie * 0.25);
    canvas.drawCircle(p(25, 41.75), 0.75 * pie, linea..color = secundario); // aro
    linea.color = Colors.white.withValues(alpha: 0.9);
    canvas.drawArc(Rect.fromCircle(center: p(25, 41.75), radius: 4 * pie), pi, pi, false, linea); // zona restringida

    // Triple: rectas en las esquinas y arco de 23.75 pies centrado en el aro.
    final angulo = asin((41.75 - 32.8) / 23.75);
    canvas.drawLine(p(3, 47), p(3, 32.8), linea);
    canvas.drawLine(p(47, 47), p(47, 32.8), linea);
    canvas.drawArc(
      Rect.fromCircle(center: p(25, 41.75), radius: 23.75 * pie),
      pi + angulo,
      pi - 2 * angulo,
      false,
      linea,
    );
  }

  @override
  bool shouldRepaint(_Parque a) => a.pintura != pintura || a.secundario != secundario;
}
