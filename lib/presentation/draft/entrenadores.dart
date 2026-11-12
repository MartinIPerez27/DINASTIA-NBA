import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/entrenador.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';

/// Hoja con las 3 cartas de entrenador para el 7.º puesto. Devuelve el elegido (null si se cierra).
Future<Entrenador?> elegirEntrenador(BuildContext context, List<Entrenador> opciones, {Entrenador? actual}) =>
    showModalBottomSheet<Entrenador>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final tema = Theme.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('7.º PUESTO: TU ENTRENADOR', style: tema.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Su sistema y su esquema rinden más si los usás en el playbook; si dirigió la franquicia '
                'de tus jugadores, suma química.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              for (final e in opciones) ...[
                CartaEntrenador(
                  entrenador: e,
                  elegido: actual?.id == e.id,
                  onTap: () {
                    Haptica.media();
                    Navigator.of(context).pop(e);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );

/// Carta de entrenador: monograma LED, nombre, nivel, sistema y esquema preferidos, frase y escudos.
class CartaEntrenador extends StatelessWidget {
  const CartaEntrenador({super.key, required this.entrenador, this.elegido = false, this.onTap});

  final Entrenador entrenador;
  final bool elegido;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = entrenador;
    return Semantics(
      button: onTap != null,
      selected: elegido,
      label: '${e.nombre}, nivel ${e.nivel}. ${e.ofensiva.nombre} y ${e.defensiva.nombre}. ${e.frase}',
      child: ExcludeSemantics(
        child: Material(
          color: esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: elegido ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.6),
              width: elegido ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Monograma(entrenador: e, tamano: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.nombre.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: Fuentes.estadio,
                                  fontVariations: [FontVariation.weight(800)],
                                  fontSize: 22,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            TextoLed('${e.nivel}', tamano: 26),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.ofensiva.nombre} · ${e.defensiva.nombre}',
                          style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(e.frase, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [for (final f in e.franquicias) Escudo(franquiciaPorId(f), tamano: 22)],
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

/// Monograma del entrenador al estilo del tablero: iniciales en LED sobre el panel, con el color de
/// su franquicia principal.
class Monograma extends StatelessWidget {
  const Monograma({super.key, required this.entrenador, required this.tamano});

  final Entrenador entrenador;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = colorLed(franquiciaPorId(entrenador.franquicias.first));
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: esquema.surfaceContainer,
        borderRadius: BorderRadius.circular(tamano * 0.18),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(tamano * 0.18),
            child: CustomPaint(painter: _Puntos(esquema.onSurface.withValues(alpha: 0.06))),
          ),
          Center(
            child: TextoLed(entrenador.iniciales, tamano: tamano * 0.42, color: color),
          ),
        ],
      ),
    );
  }
}

class _Puntos extends CustomPainter {
  _Puntos(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const paso = 6.0;
    for (var y = paso / 2; y < size.height; y += paso) {
      for (var x = paso / 2; x < size.width; x += paso) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(_Puntos viejo) => viejo.color != color;
}

/// Chip compacto del entrenador elegido (o el hueco vacío), para encabezados.
class ChipEntrenador extends StatelessWidget {
  const ChipEntrenador({super.key, required this.entrenador, required this.onTap});

  final Entrenador? entrenador;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = entrenador;
    return Semantics(
      button: onTap != null,
      label: e == null ? 'Sin entrenador. Elegir entrenador' : 'Entrenador: ${e.nombre}. Cambiar',
      child: ExcludeSemantics(
        child: Material(
          color: esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: e == null ? esquema.outlineVariant : esquema.primary),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e != null)
                      Monograma(entrenador: e, tamano: 34)
                    else
                      Icon(Icons.sports, color: esquema.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e == null ? 'SIN ENTRENADOR' : e.nombre.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: Fuentes.estadio,
                              fontVariations: [FontVariation.weight(800)],
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            e == null ? 'Tocá para elegir (7.º puesto)' : '${e.ofensiva.nombre} · nivel ${e.nivel}',
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
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
    );
  }
}
