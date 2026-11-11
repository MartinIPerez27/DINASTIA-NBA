import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/plantel.dart';
import '../../domain/entities/posicion.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/escudo.dart';
import '../widgets/ficha_jugador.dart';
import '../widgets/jugador_avatar.dart';
import '../widgets/texto_led.dart';

/// Media cancha vista desde el tablero (GDD §2 y §4.1): parqué con la luz del estadio, borde y
/// nombre de la franquicia en la línea de fondo, escudo pintado en el centro y un puesto por
/// posición. Vacío: silueta de camiseta. Ocupado: la carta con su foto.
/// Coordenadas en pies reales: cancha de 0 a 50 de ancho, del medio campo (y=0) al fondo (y=47).
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

  // Vista: borde de 3 pies a los lados y 4 abajo; arriba se corta pasando el círculo central.
  static const _izq = -3.0, _der = 53.0, _arriba = -7.0, _abajo = 51.0;
  static const proporcion = (_der - _izq) / (_abajo - _arriba);

  static const _ubicacion = {
    Posicion.base: Offset(25, 14),
    Posicion.escolta: Offset(42, 22.5),
    Posicion.alero: Offset(8, 22.5),
    Posicion.alaPivot: Offset(37.5, 37),
    Posicion.pivot: Offset(12.5, 37),
    Posicion.sextoHombre: Offset(45, 3),
  };

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: proporcion,
    child: LayoutBuilder(
      builder: (context, c) {
        final pie = c.maxWidth / (_der - _izq);
        Offset px(Offset p) => Offset((p.dx - _izq) * pie, (p.dy - _arriba) * pie);
        final escudo = 13 * pie;
        final puestoAncho = 11 * pie, puestoAlto = 13 * pie;
        final centro = px(const Offset(25, 0));
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _Parque(franquicia))),
              // Escudo pintado sobre la madera, como en el piso real.
              Positioned(
                left: centro.dx - escudo / 2,
                top: centro.dy - escudo / 2,
                child: ExcludeSemantics(
                  child: Opacity(opacity: 0.92, child: Escudo(franquicia, tamano: escudo)),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _LuzEstadio())),
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
    final jugador = this.jugador;
    return jugador == null ? _vacio(context) : _ocupado(context, jugador);
  }

  Widget _vacio(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final led = esquema.primary;
    return Semantics(
      button: onTap != null,
      label: '${posicion.etiqueta}, vacío${resaltado ? ', disponible' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _Camiseta(
                    relleno: resaltado ? led.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.22),
                    borde: resaltado ? led : Colors.white.withValues(alpha: 0.75),
                    grosor: resaltado ? 2.5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _Placa(texto: posicion.etiqueta, color: resaltado ? led : esquema.onSurface),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ocupado(BuildContext context, Jugador jugador) {
    final esquema = Theme.of(context).colorScheme;
    final uniforme = Color(franquicia.colorPrimario);
    final sobreUniforme = uniforme.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    final animar = encender && !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: '${posicion.etiqueta}: ${jugador.nombre}',
      onLongPressHint: 'ver ficha completa',
      onLongPress: () => mostrarFichaJugador(context, jugador),
      child: ExcludeSemantics(
        child: GestureDetector(
          onLongPress: () => mostrarFichaJugador(context, jugador),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(jugador.id),
            tween: Tween(begin: animar ? 1 : 0, end: 0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, luz, carta) => DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                color: esquema.primary.withValues(alpha: luz * 0.55),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color.lerp(uniforme, esquema.primary, luz)!, width: 2),
              ),
              child: carta,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: esquema.surfaceContainerLowest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          JugadorAvatar(jugador: jugador, franquicia: franquicia, recortar: true),
                          Positioned(
                            top: 2,
                            right: 3,
                            child: TextoLed(CartaJugador.codigoTier(jugador.tier), tamano: 11),
                          ),
                        ],
                      ),
                    ),
                    // Placa con el uniforme de la franquicia: dorsal y apellido.
                    ColoredBox(
                      color: uniforme,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${jugador.dorsal} ${_apellido(jugador.nombre)}'.toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: Fuentes.estadio,
                              fontVariations: const [FontVariation.weight(800)],
                              fontSize: 12,
                              letterSpacing: 0.5,
                              color: sobreUniforme,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

/// Placa del tablero bajo cada puesto vacío: legible sobre la madera.
class _Placa extends StatelessWidget {
  const _Placa({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: FittedBox(
        child: Text(
          texto.toUpperCase(),
          maxLines: 1,
          style: TextStyle(
            fontFamily: Fuentes.estadio,
            fontVariations: const [FontVariation.weight(700)],
            fontSize: 12,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ),
    ),
  );
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

/// La luz del estadio: el centro iluminado y los bordes en penumbra (no es brillo decorativo,
/// es la iluminación de la escena; sin reflejos ni glow).
class _LuzEstadio extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.42)],
          stops: const [0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LuzEstadio a) => false;
}

/// Parqué y pintura de la franquicia.
class _Parque extends CustomPainter {
  const _Parque(this.franquicia);

  final Franquicia franquicia;

  @override
  void paint(Canvas canvas, Size size) {
    final pie = size.width / (Cancha._der - Cancha._izq);
    Offset p(double x, double y) => Offset((x - Cancha._izq) * pie, (y - Cancha._arriba) * pie);
    final pintura = Color(franquicia.colorPrimario);
    final secundario = Color(franquicia.colorSecundario);

    // Borde fuera de la cancha: color del equipo, oscurecido y mate.
    final hslBorde = HSLColor.fromColor(pintura);
    final borde = hslBorde.withLightness((hslBorde.lightness * 0.7).clamp(0.08, 0.4)).toColor();
    canvas.drawRect(Offset.zero & size, Paint()..color = borde);

    // Madera: tablas a lo largo con tono, juntas y vetas fijas (misma semilla siempre).
    final cancha = Rect.fromPoints(p(0, Cancha._arriba), p(50, 47));
    canvas.save();
    canvas.clipRect(cancha);
    const madera = Color(0xFF9A6B42);
    final tabla = cancha.width / 34;
    final azar = Random(82);
    final veta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var i = 0; i * tabla < cancha.width; i++) {
      final x = cancha.left + i * tabla;
      final hsl = HSLColor.fromColor(madera);
      final tono = hsl.withLightness((hsl.lightness + (azar.nextDouble() - 0.5) * 0.07).clamp(0, 1)).toColor();
      canvas.drawRect(Rect.fromLTWH(x, cancha.top, tabla, cancha.height), Paint()..color = tono);
      for (var v = 0; v < 3; v++) {
        final vx = x + tabla * (0.2 + 0.3 * v + azar.nextDouble() * 0.1);
        final ondula = tabla * 0.12;
        final camino = Path()..moveTo(vx, cancha.top);
        for (var y = cancha.top; y < cancha.bottom; y += 18) {
          camino.quadraticBezierTo(
            vx + (azar.nextBool() ? ondula : -ondula),
            y + 9,
            vx + (azar.nextDouble() - 0.5) * ondula,
            y + 18,
          );
        }
        canvas.drawPath(camino, veta..color = Colors.black.withValues(alpha: 0.05 + azar.nextDouble() * 0.05));
      }
      final junta = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..strokeWidth = 0.7;
      canvas.drawLine(Offset(x, cancha.top), Offset(x, cancha.bottom), junta);
      for (var y = cancha.top + azar.nextDouble() * 60; y < cancha.bottom; y += 50 + azar.nextDouble() * 40) {
        canvas.drawLine(Offset(x, y), Offset(x + tabla, y), junta);
      }
    }
    canvas.restore();

    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, pie * 0.22);
    final relleno = Paint()..color = Colors.white.withValues(alpha: 0.92);

    // Pintura de la zona en el color del equipo.
    canvas.drawRect(Rect.fromPoints(p(17, 28), p(33, 47)), Paint()..color = pintura);

    canvas.drawRect(cancha, linea); // laterales, fondo y medio campo cortado arriba
    canvas.drawLine(p(0, 0), p(50, 0), linea);
    canvas.drawCircle(p(25, 0), 6 * pie, linea);
    canvas.drawCircle(p(25, 0), 2 * pie, linea);
    canvas.drawRect(Rect.fromPoints(p(17, 28), p(33, 47)), linea);
    canvas.drawCircle(p(25, 28), 6 * pie, linea);

    // Marcas de la zona (posiciones de rebote en tiros libres) y los bloques.
    for (final y in [40.0, 36.5, 33.5, 30.5]) {
      canvas.drawLine(p(17, y), p(16, y), linea);
      canvas.drawLine(p(33, y), p(34, y), linea);
    }
    canvas.drawRect(Rect.fromPoints(p(16.2, 39.2), p(17, 40)), relleno);
    canvas.drawRect(Rect.fromPoints(p(33, 39.2), p(33.8, 40)), relleno);

    // Tablero, aro y zona restringida.
    canvas.drawLine(
      p(22, 43),
      p(28, 43),
      Paint()
        ..color = Colors.white
        ..strokeWidth = pie * 0.45,
    );
    canvas.drawCircle(
      p(25, 41.75),
      0.75 * pie,
      Paint()
        ..color = secundario.computeLuminance() > 0.08 ? secundario : const Color(0xFFE35205)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pie * 0.25,
    );
    canvas.drawArc(Rect.fromCircle(center: p(25, 41.75), radius: 4 * pie), pi, pi, false, linea);

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

    // Nombre de la franquicia en la línea de fondo (GDD §2).
    final colorNombre = _contraste(secundario, borde) >= 3 ? secundario : Colors.white;
    final nombre = TextPainter(
      text: TextSpan(
        text: franquicia.nombre.toUpperCase(),
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: const [FontVariation.weight(800)],
          fontSize: 2.8 * pie,
          letterSpacing: 1.2 * pie,
          color: colorNombre,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nombre.paint(canvas, p(25, 49) - Offset(nombre.width / 2, nombre.height / 2));
  }

  static double _contraste(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    return (max(x, y) + 0.05) / (min(x, y) + 0.05);
  }

  @override
  bool shouldRepaint(_Parque a) => a.franquicia != franquicia;
}
