import 'package:flutter/material.dart';

/// Forma de una carta en la temporada: ▲2 (en racha) o ▼1 (fría). Nada si está en 0.
class IndicadorForma extends StatelessWidget {
  const IndicadorForma(this.forma, {super.key});

  final int forma;

  @override
  Widget build(BuildContext context) {
    if (forma == 0) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    final sube = forma > 0;
    return Semantics(
      label: sube ? 'En racha, más $forma' : 'Frío, menos ${-forma}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            '${sube ? '▲' : '▼'}${forma.abs()}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sube ? esquema.primary : esquema.error),
          ),
        ),
      ),
    );
  }
}
