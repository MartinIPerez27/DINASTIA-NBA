import 'package:flutter/material.dart';

import '../tema/tema_franquicia.dart';

/// Texto en puntos LED. Detrás, los mismos dígitos en "8" quedan apagados, como en un tablero real.
class TextoLed extends StatelessWidget {
  const TextoLed(this.texto, {super.key, required this.tamano, this.color});

  final String texto;
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final encendido = color ?? Theme.of(context).colorScheme.primary;
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
