import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Marcador estilo transmisión, sobre la cancha: los dígitos LED parpadean al anotar, muestra el parcial
/// (p. ej. "10-0"), "EN LLAMAS" para el tirador encendido, resalta el momento clutch y lleva una barrita
/// con la probabilidad de ganar del usuario que se mueve con transición.
class MarcadorVivo extends StatefulWidget {
  const MarcadorVivo({
    super.key,
    required this.local,
    required this.visitante,
    required this.puntos,
    required this.cuarto,
    required this.reloj,
    required this.posesion,
    required this.faltas,
    required this.tiemposMuertos,
    required this.clutch,
    required this.onSalir,
    this.usuarioLocal = true,
    this.probabilidad,
    this.parcial,
    this.enLlamas,
  });

  final Franquicia local, visitante;
  final (int, int) puntos;
  final int cuarto;
  final double reloj;

  /// Reloj de posesión (24 segundos).
  final double posesion;
  final (int, int) faltas, tiemposMuertos;
  final bool clutch;
  final VoidCallback onSalir;
  final bool usuarioLocal;

  /// Probabilidad de ganar del usuario (0–1), o null si todavía no hay.
  final double? probabilidad;

  /// Parcial en curso: (¿del local?, puntos seguidos) o null.
  final (bool, int)? parcial;

  /// Apellido del tirador "en llamas", o null.
  final String? enLlamas;

  @override
  State<MarcadorVivo> createState() => _MarcadorVivoState();
}

class _MarcadorVivoState extends State<MarcadorVivo> with TickerProviderStateMixin {
  late final AnimationController _anotacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  late final AnimationController _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  var _anoto = 0; // 0 nadie, 1 local, 2 visitante
  var _suma = 0;

  @override
  void initState() {
    super.initState();
    if (widget.clutch) _pulso.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MarcadorVivo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final (l0, v0) = oldWidget.puntos;
    final (l1, v1) = widget.puntos;
    if (l1 > l0 || v1 > v0) {
      _anoto = l1 > l0 ? 1 : 2;
      _suma = l1 > l0 ? l1 - l0 : v1 - v0;
      if (MediaQuery.disableAnimationsOf(context)) {
        _anotacion.value = 1;
      } else {
        _anotacion.forward(from: 0);
      }
    }
    if (widget.clutch && !_pulso.isAnimating) _pulso.repeat(reverse: true);
    if (!widget.clutch && _pulso.isAnimating) {
      _pulso.stop();
      _pulso.value = 0;
    }
  }

  @override
  void dispose() {
    _anotacion.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final esquema = Theme.of(context).colorScheme;
    final r = max(0.0, w.reloj);
    final minutos = r ~/ 60, segundos = (r % 60).floor();
    final periodo = w.cuarto > 4 ? 'OT${w.cuarto > 5 ? w.cuarto - 4 : ''}' : 'Q${w.cuarto}';

    Widget equipo(Franquicia f, int pts, bool derecha, int quien) {
      final color = Color(f.colorPrimario);
      return Expanded(
        child: AnimatedBuilder(
          animation: _anotacion,
          builder: (context, _) {
            final v = _anotacion.value;
            final anotando = _anoto == quien && v < 1;
            // Los dígitos parpadean (apagado/encendido) los primeros 600 ms y quedan fijos.
            final prendido = !anotando || v > 0.65 || (v * 14).floor().isEven;
            final fondo = anotando
                ? Color.lerp(Colors.white, color, Curves.easeOut.transform(v))!.withValues(alpha: 0.35 * (1 - v))
                : Colors.transparent;
            return Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  fondo,
                  Color.alphaBlend(color.withValues(alpha: 0.55), esquema.surfaceContainerLowest),
                ),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(derecha ? 0 : 10),
                  right: Radius.circular(derecha ? 10 : 0),
                ),
              ),
              child: Row(
                textDirection: derecha ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Escudo(f, tamano: 28),
                  const SizedBox(width: 6),
                  // La sigla entera siempre (se achica si no entra, nunca se corta) y los puntos al borde.
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: derecha ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(
                        f.id,
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: Fuentes.estadio,
                          fontVariations: [FontVariation.weight(800)],
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: derecha ? Alignment.centerLeft : Alignment.centerRight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          TextoLed('$pts', tamano: 28, color: prendido ? Colors.white : Colors.white24),
                          if (anotando)
                            Positioned(
                              top: -14 * v,
                              right: derecha ? null : -2,
                              left: derecha ? -2 : null,
                              child: Opacity(
                                opacity: (1 - v).clamp(0.0, 1.0),
                                child: Text(
                                  '+$_suma',
                                  style: TextStyle(
                                    fontFamily: Fuentes.estadio,
                                    fontVariations: const [FontVariation.weight(800)],
                                    fontSize: 14,
                                    color: esquema.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Debajo de cada equipo: tiempos muertos que le quedan (puntitos) y faltas del cuarto.
    Widget detalle(int tm, int f, bool derecha) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          textDirection: derecha ? TextDirection.rtl : TextDirection.ltr,
          children: [
            for (var k = 0; k < 5; k++)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: k < tm ? Colors.white : Colors.white.withValues(alpha: 0.18),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: derecha ? Alignment.centerLeft : Alignment.centerRight,
                child: Text(
                  f >= 5 ? 'BONUS' : 'FALTAS $f',
                  style: TextStyle(
                    fontFamily: Fuentes.estadio,
                    fontVariations: const [FontVariation.weight(700)],
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: f >= 5 ? const Color(0xFFFFB020) : Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget chip(String texto, Color color, {Color? fondo}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fondo ?? esquema.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        texto,
        maxLines: 1,
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: const [FontVariation.weight(800)],
          fontSize: 12,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );

    final p24 = w.posesion.ceil().clamp(0, 24);
    final parcial = w.parcial;
    final fuego = w.enLlamas;
    final propioLocal = w.usuarioLocal;
    final probabilidad = w.probabilidad;
    final competencia = w.puntos.$1 - w.puntos.$2;
    return Semantics(
      label:
          '${w.local.nombre} ${w.puntos.$1}, ${w.visitante.nombre} ${w.puntos.$2}, $periodo, $minutos minutos $segundos segundos'
          '${w.clutch ? ', momento clutch' : ''}'
          '${parcial == null ? '' : ', parcial de ${parcial.$2} a 0'}'
          '${fuego == null ? '' : ', $fuego en llamas'}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Material(
                  color: esquema.surfaceContainerLowest.withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  child: IconButton(onPressed: w.onSalir, icon: const Icon(Icons.close), tooltip: 'Salir del partido'),
                ),
                const SizedBox(width: 6),
                equipo(w.local, w.puntos.$1, false, 1),
                AnimatedBuilder(
                  animation: _pulso,
                  builder: (context, _) => Container(
                    height: 44,
                    width: 74,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        esquema.primary.withValues(alpha: 0.22 * _pulso.value),
                        esquema.surfaceContainerLowest,
                      ),
                      border: w.clutch
                          ? Border.symmetric(
                              horizontal: BorderSide(
                                color: esquema.primary.withValues(alpha: 0.4 + 0.6 * _pulso.value),
                              ),
                            )
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: FittedBox(
                      child: Column(
                        children: [
                          TextoLed(periodo, tamano: 12, color: esquema.onSurfaceVariant),
                          TextoLed('$minutos:${'$segundos'.padLeft(2, '0')}', tamano: 19),
                        ],
                      ),
                    ),
                  ),
                ),
                equipo(w.visitante, w.puntos.$2, true, 2),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 54),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: esquema.surfaceContainerLowest.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(probabilidad == null ? 8 : 0)),
                    ),
                    child: Row(
                      children: [
                        detalle(w.tiemposMuertos.$1, w.faltas.$1, false),
                        SizedBox(
                          width: 74,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextoLed('$p24', tamano: 14, color: p24 <= 5 ? esquema.error : const Color(0xFFFFB020)),
                                if (w.clutch) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    'CLUTCH',
                                    style: TextStyle(
                                      fontFamily: Fuentes.estadio,
                                      fontVariations: const [FontVariation.weight(800)],
                                      fontSize: 11,
                                      color: esquema.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        detalle(w.tiemposMuertos.$2, w.faltas.$2, true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Probabilidad de ganar del usuario: una barrita que se desliza hacia donde va el partido.
            if (probabilidad != null)
              Padding(
                padding: const EdgeInsets.only(left: 54),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: probabilidad.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    final izquierda = propioLocal ? v : 1 - v;
                    return SizedBox(
                      height: 5,
                      child: Row(
                        children: [
                          Expanded(
                            flex: max(1, (izquierda * 1000).round()),
                            child: ColoredBox(color: Color(w.local.colorPrimario)),
                          ),
                          Expanded(
                            flex: max(1, ((1 - izquierda) * 1000).round()),
                            child: ColoredBox(color: Color(w.visitante.colorPrimario).withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // Parcial y tirador encendido, solo cuando los hay.
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: parcial != null || fuego != null ? 4 : 0),
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (parcial != null)
                      chip(
                        'PARCIAL ${parcial.$1 ? '${parcial.$2}-0' : '0-${parcial.$2}'} · ${parcial.$1 ? w.local.id : w.visitante.id}',
                        Color(parcial.$1 ? w.local.colorPrimario : w.visitante.colorPrimario).withValues(alpha: 1),
                      ),
                    if (fuego != null) chip('EN LLAMAS · $fuego', const Color(0xFFFF8A1F)),
                    if (competencia.abs() <= 3 && w.clutch) chip('PARTIDO CERRADO', esquema.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
