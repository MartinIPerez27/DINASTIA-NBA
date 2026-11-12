import 'package:flutter/material.dart';

import '../../domain/entities/jugador.dart';
import '../../domain/entities/oferta.dart';
import '../../domain/entities/temporada.dart';
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

/// Hoja para elegir las reglas del draft (modos de draft). Devuelve la regla y, para "Una sola
/// década", la época. Null si se cierra sin elegir.
Future<(ReglaDraft, Epoca?)?> elegirRegla(
  BuildContext context, {
  required ModoDraft modo,
  required Future<bool> coleccionAlcanza,
}) async {
  final regla = await showModalBottomSheet<ReglaDraft>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final tema = Theme.of(context);
      final esquema = tema.colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿CON QUÉ REGLAS?', style: tema.textTheme.headlineSmall),
            const SizedBox(height: 12),
            for (final r in ReglaDraft.values)
              if (!r.soloCartas || modo == ModoDraft.cartas)
                FutureBuilder<bool>(
                  future: r == ReglaDraft.coleccion ? coleccionAlcanza : Future.value(true),
                  builder: (context, alcanza) {
                    final bloqueada = r == ReglaDraft.coleccion && alcanza.data != true;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      enabled: !bloqueada,
                      minVerticalPadding: 10,
                      title: Text(
                        r.nombre.toUpperCase(),
                        style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 0.5),
                      ),
                      subtitle: Text(
                        bloqueada
                            ? 'Tu álbum todavía no alcanza para los 6 puestos: fichá o abrí sobres en la tienda.'
                            : r.descripcion,
                      ),
                      trailing: Icon(
                        r == ReglaDraft.libre ? Icons.all_inclusive : Icons.chevron_right,
                        color: bloqueada ? esquema.outlineVariant : esquema.primary,
                      ),
                      onTap: bloqueada ? null : () => Navigator.of(context).pop(r),
                    );
                  },
                ),
          ],
        ),
      );
    },
  );
  if (regla == null || !context.mounted) return null;
  if (regla != ReglaDraft.unaDecada) return (regla, null);
  final epoca = await showModalBottomSheet<Epoca>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿QUÉ DÉCADA?', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Desde los 50: los 40 no tienen suficientes cartas en todos los puestos.
                for (final e in Epoca.values.skip(1))
                  ActionChip(
                    label: TextoLed(e.codigo, tamano: 18),
                    onPressed: () => Navigator.of(context).pop(e),
                    tooltip: e.etiqueta,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return epoca == null ? null : (regla, epoca);
}

/// Hoja para elegir la dificultad (qué tan fuertes son los 29 rivales). Null si se cierra.
Future<Dificultad?> elegirDificultad(BuildContext context) => showModalBottomSheet<Dificultad>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿QUÉ TAN DURA LA LIGA?', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 16),
          for (final (i, d) in Dificultad.values.indexed) ...[
            Semantics(
              button: true,
              label: '${d.nombre}. ${d.descripcion}',
              child: ExcludeSemantics(
                child: Material(
                  color: esquema.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(d),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Barras de intensidad, como un vúmetro del tablero.
                          SizedBox(
                            width: 44,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (var k = 0; k < 3; k++) ...[
                                  if (k > 0) const SizedBox(width: 4),
                                  Expanded(
                                    child: Container(
                                      height: 12.0 + k * 10,
                                      decoration: BoxDecoration(
                                        color: k <= i ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.nombre.toUpperCase(),
                                  style: tema.textTheme.headlineSmall?.copyWith(fontSize: 22),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  d.descripcion,
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
            ),
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
