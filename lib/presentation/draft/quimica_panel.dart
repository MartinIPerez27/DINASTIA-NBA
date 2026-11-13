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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.nivel.etiqueta,
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: MedidorQuimica.color(q.nivel),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        MedidorQuimica(puntaje: q.puntaje, ancho: 72, alto: 6),
                      ],
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

  static String _efecto(double e) {
    final pct = (e * 100).toStringAsFixed(1).replaceAll('.', ',');
    return e > 0 ? '+$pct %' : (e < 0 ? '$pct %'.replaceFirst('-', '−') : '0 %');
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
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) =>
                    MedidorQuimica(puntaje: q.puntaje, ancho: c.maxWidth, alto: 12, conEscala: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    q.nivel.etiqueta,
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: MedidorQuimica.color(q.nivel),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(q.nivel.descripcion, style: tema.textTheme.bodyMedium)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'En el partido: ${_efecto(q.efectoTiro)} de acierto en cada tiro (va de −1 % con química 0 a '
                '+1 % con 100; 50 es neutro). Compañeros de la misma época suman más; un dúo legendario, '
                'todavía más.',
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

/// Barra de química en tres colores (baja / media / alta) con una marca donde está el plantel.
class MedidorQuimica extends StatelessWidget {
  const MedidorQuimica({super.key, required this.puntaje, required this.ancho, this.alto = 6, this.conEscala = false});

  final int puntaje;
  final double ancho, alto;

  /// Con los números de las franjas debajo (para el detalle).
  final bool conEscala;

  static Color color(NivelQuimica n) => switch (n) {
    NivelQuimica.baja => const Color(0xFFE5484D),
    NivelQuimica.media => const Color(0xFFF5B83D),
    NivelQuimica.alta => const Color(0xFF46C46E),
    NivelQuimica.excelente => const Color(0xFF2BE38A),
  };

  @override
  Widget build(BuildContext context) {
    final franjas = [
      (0, NivelQuimica.desdeMedia, NivelQuimica.baja),
      (NivelQuimica.desdeMedia, NivelQuimica.desdeAlta, NivelQuimica.media),
      (NivelQuimica.desdeAlta, NivelQuimica.desdeExcelente, NivelQuimica.alta),
      (NivelQuimica.desdeExcelente, 100, NivelQuimica.excelente),
    ];
    final marca = (puntaje.clamp(0, 100) / 100) * ancho;
    final barra = SizedBox(
      width: ancho,
      height: alto + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 3,
            height: alto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(alto / 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (desde, hasta, nivel) in franjas)
                    Expanded(
                      flex: hasta - desde,
                      child: ColoredBox(
                        color: color(nivel).withValues(alpha: NivelQuimica.de(puntaje) == nivel ? 1 : 0.35),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: (marca - 3).clamp(0, ancho - 6),
            top: 0,
            width: 6,
            height: alto + 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                // Panel mate (DESIGN.md): sin sombra, un borde del color del panel separa la marca.
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerLowest, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
    if (!conEscala) return barra;
    final estilo = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        barra,
        const SizedBox(height: 4),
        SizedBox(
          width: ancho,
          height: 16,
          child: Stack(
            children: [
              for (final (desde, hasta, nivel) in franjas)
                Positioned(
                  left: ancho * desde / 100,
                  width: ancho * (hasta - desde) / 100,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(nivel.etiqueta, style: estilo, maxLines: 1),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
