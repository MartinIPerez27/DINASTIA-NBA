import 'package:flutter/material.dart';

import '../../domain/relato/contexto_relato.dart';

/// Color propio de cada personaje: el Relator con el color de la franquicia, el Comentarista con el terciario.
Color colorPersonaje(ColorScheme esquema, Personaje p) => p == Personaje.relator ? esquema.primary : esquema.tertiary;

IconData iconoPersonaje(Personaje p) => p == Personaje.relator ? Icons.mic : Icons.record_voice_over;

/// Panel "Relato" del partido en vivo: las líneas más nuevas arriba, cada una con el nombre, el color y el
/// ícono de su personaje. La última jugada pesa más; las intensas van en negrita.
class PanelRelato extends StatelessWidget {
  const PanelRelato({super.key, required this.lineas});

  /// Más nueva primero.
  final List<LineaRelato> lineas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    if (lineas.isEmpty) {
      return Center(child: Text('Ya empieza la transmisión…', style: tema.textTheme.bodySmall));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      itemCount: lineas.length,
      itemBuilder: (_, i) {
        final l = lineas[i];
        final color = colorPersonaje(esquema, l.personaje);
        final nueva = i < 2;
        // Un nuevo bloque (otro personaje que el de más abajo) lleva el nombre arriba.
        return Padding(
          padding: EdgeInsets.only(top: i > 0 && lineas[i - 1].personaje == l.personaje ? 2 : 7, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(right: 10, top: 1),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: Icon(iconoPersonaje(l.personaje), size: 15, color: color),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.personaje.nombre.toUpperCase(),
                      style: tema.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      l.texto,
                      style: (nueva ? tema.textTheme.bodyMedium : tema.textTheme.bodySmall)?.copyWith(
                        color: nueva ? esquema.onSurface : esquema.onSurfaceVariant,
                        fontWeight: l.intensidad >= 3 ? FontWeight.w700 : null,
                        fontStyle: l.personaje == Personaje.comentarista ? FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
