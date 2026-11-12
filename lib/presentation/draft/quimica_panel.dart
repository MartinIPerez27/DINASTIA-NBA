import 'package:flutter/material.dart';

import '../../domain/entities/entrenador.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/quimica.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/texto_led.dart';

/// Medidor de química (0–100) con sus vínculos. Compacto: una fila con el LED, la barra y el mejor
/// vínculo; tocándolo se abre el detalle.
class PanelQuimica extends StatelessWidget {
  const PanelQuimica({super.key, required this.jugadores, this.entrenador, this.compacto = false});

  final List<Jugador> jugadores;
  final Entrenador? entrenador;

  /// Solo "QUÍMICA" + LED + barra (para encabezados angostos).
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final q = Quimica.de(jugadores, entrenador: entrenador);
    final duos = [
      for (final v in q.vinculos)
        if (v.tipo == TipoVinculo.duo) v.nombreDuo!,
    ];
    final resumen = duos.isNotEmpty
        ? 'Dúo legendario: ${duos.join(' · ')}'
        : q.vinculos.isEmpty
        ? 'Sin vínculos todavía: misma franquicia o época suman.'
        : '${q.vinculos.length} vínculo${q.vinculos.length == 1 ? '' : 's'} en el plantel';
    return Semantics(
      button: true,
      label: 'Química ${q.puntaje} de 100. $resumen. Ver detalle',
      child: ExcludeSemantics(
        child: Material(
          color: esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _detalle(context, q),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Text('QUÍMICA', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    TextoLed('${q.puntaje}', tamano: 22),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(value: q.puntaje / 100, minHeight: 5),
                      ),
                    ),
                    if (!compacto) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          resumen,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: duos.isNotEmpty ? esquema.primary : esquema.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    Icon(Icons.chevron_right, color: esquema.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _detalle(BuildContext context, Quimica q) {
    final porId = {for (final j in jugadores) j.id: j};
    String nombre(String id) => porId[id]?.nombre.split(' ').last ?? entrenador?.nombre ?? id;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final tema = Theme.of(context);
        final esquema = tema.colorScheme;
        final orden = [...q.vinculos]..sort((a, b) => b.tipo.puntos.compareTo(a.tipo.puntos));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('QUÍMICA', style: tema.textTheme.headlineSmall),
                  const Spacer(),
                  TextoLed('${q.puntaje}', tamano: 36),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Compañeros de la misma época suman más; un dúo legendario, todavía más. '
                'En el partido vale hasta un punto de acierto.',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (orden.isEmpty) Text('Todavía no hay vínculos.', style: tema.textTheme.bodyMedium),
              for (final v in orden)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    v.tipo == TipoVinculo.duo ? Icons.star : Icons.link,
                    color: v.tipo == TipoVinculo.duo ? esquema.primary : esquema.onSurfaceVariant,
                  ),
                  title: Text(
                    v.tipo == TipoVinculo.duo
                        ? v.nombreDuo!
                        : v.tipo == TipoVinculo.entrenador
                        ? '${entrenador?.nombre} → ${nombre(v.a)}'
                        : '${nombre(v.a)} + ${nombre(v.b)}',
                    style: v.tipo == TipoVinculo.duo
                        ? const TextStyle(fontFamily: Fuentes.estadio, fontVariations: [FontVariation.weight(800)])
                        : null,
                  ),
                  subtitle: Text(v.tipo.nombre),
                  trailing: TextoLed('+${v.tipo.puntos}', tamano: 16),
                ),
            ],
          ),
        );
      },
    );
  }
}
