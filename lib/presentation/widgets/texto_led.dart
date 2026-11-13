import 'package:flutter/material.dart';

import '../tema/tema_franquicia.dart';
import '../tema/vestuario.dart';

/// Texto en puntos LED. Detrás, los mismos dígitos en "8" quedan apagados, como en un tablero real.
class TextoLed extends StatelessWidget {
  const TextoLed(this.texto, {super.key, required this.tamano, this.color});

  final String texto;
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Sin color pedido: el tema de LED del vestuario o, de fábrica, el color de la franquicia.
    final encendido = color ?? Vestuario.led() ?? Theme.of(context).colorScheme.primary;
    final estilo = TextStyle(
      fontFamily: Fuentes.led,
      fontSize: tamano,
      height: 1,
      fontVariations: const [FontVariation.weight(800)],
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: texto,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Text(
              texto.replaceAll(RegExp(r'[0-9]'), '8'),
              style: estilo.copyWith(color: encendido.withValues(alpha: 0.12)),
            ),
            Text(texto, style: estilo.copyWith(color: encendido)),
          ],
        ),
      ),
    );
  }
}

/// Celda numérica de tabla (box score, stats) en puntos LED, con su dígito fantasma apagado detrás
/// como [TextoLed], pero con el estilo de la tabla (tamaño, color, alineación).
class CeldaLed extends StatelessWidget {
  const CeldaLed(this.texto, {super.key, required this.estilo, this.textAlign});

  final String texto;
  final TextStyle estilo;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final color = estilo.color ?? DefaultTextStyle.of(context).style.color ?? Colors.white;
    final base = estilo.copyWith(
      fontFamily: Fuentes.led,
      fontVariations: const [FontVariation.weight(800)],
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: texto,
      child: ExcludeSemantics(
        child: Stack(
          alignment: switch (textAlign) {
            TextAlign.end || TextAlign.right => AlignmentDirectional.centerEnd,
            TextAlign.center => AlignmentDirectional.center,
            _ => AlignmentDirectional.centerStart,
          },
          children: [
            Text(
              texto.replaceAll(RegExp(r'[0-9]'), '8'),
              textAlign: textAlign,
              style: base.copyWith(color: color.withValues(alpha: 0.12)),
            ),
            Text(
              texto,
              textAlign: textAlign,
              style: base.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
