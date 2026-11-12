import 'package:flutter/material.dart';

import '../../domain/entities/oferta.dart';
import 'carta_vertical.dart';
import 'texto_led.dart';

/// Hoja para elegir cómo se arma el plantel. Devuelve null si se cierra sin elegir.
Future<ModoDraft?> elegirModoDraft(BuildContext context) => showModalBottomSheet<ModoDraft>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿CÓMO ARMÁS TU PLANTEL?', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 16),
          for (final modo in ModoDraft.values) ...[
            _OpcionModo(modo: modo, onTap: () => Navigator.of(context).pop(modo)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  },
);

class _OpcionModo extends StatelessWidget {
  const _OpcionModo({required this.modo, required this.onTap});

  final ModoDraft modo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Semantics(
      button: true,
      label: '${modo.nombre}. ${modo.descripcion}',
      child: ExcludeSemantics(
        child: Material(
          color: esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 108,
                    height: 64,
                    child: modo == ModoDraft.ruleta ? const _MiniRuleta() : const _MiniCartas(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(modo.nombre.toUpperCase(), style: tema.textTheme.headlineSmall?.copyWith(fontSize: 22)),
                        const SizedBox(height: 2),
                        Text(
                          modo.descripcion,
                          style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniRuleta extends StatelessWidget {
  const _MiniRuleta();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final (i, v) in ['CHI', '90s', 'S+'].indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: esquema.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: esquema.outlineVariant),
              ),
              child: FittedBox(
                child: Padding(padding: const EdgeInsets.all(3), child: TextoLed(v, tamano: 16)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniCartas extends StatelessWidget {
  const _MiniCartas();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Transform.translate(
            offset: Offset((i - 2) * 16.0, ((i - 2).abs()) * 3.0),
            child: Transform.rotate(
              angle: (i - 2) * 0.12,
              child: SizedBox(
                width: 34,
                child: DorsoCarta(color: esquema.primary, carga: i == 2 ? 1 : 0),
              ),
            ),
          ),
      ],
    );
  }
}
