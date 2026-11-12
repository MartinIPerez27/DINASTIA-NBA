import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/progreso.dart';
import '../tema/tema_franquicia.dart';

/// Avisos de recompensas (XP, logros, nivel, trofeos) arriba de la pantalla.
/// Un lote nuevo reemplaza al que se esté mostrando: nunca se encolan avisos viejos
/// (los que se perdieron quedan igual en el perfil).
abstract final class Avisos {
  static OverlayEntry? _actual;
  static Timer? _reloj;

  static void mostrar(OverlayState overlay, List<Novedad> novedades) {
    if (novedades.isEmpty) return;
    cerrar();
    final orden = [...novedades.where((n) => n.destacada), ...novedades.where((n) => !n.destacada)];
    final indice = ValueNotifier(0);
    final entrada = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        top: MediaQuery.paddingOf(context).top + 8,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ValueListenableBuilder(
              valueListenable: indice,
              builder: (context, i, _) =>
                  _Tarjeta(key: ValueKey(i), novedad: orden[i], extra: orden.length - 1 - i, onCerrar: cerrar),
            ),
          ),
        ),
      ),
    );
    _actual = entrada;
    overlay.insert(entrada);
    void siguiente() {
      _reloj = Timer(Duration(milliseconds: orden[indice.value].destacada ? 2800 : 1800), () {
        if (indice.value + 1 < orden.length) {
          indice.value++;
          siguiente();
        } else {
          cerrar();
        }
      });
    }

    siguiente();
  }

  static void cerrar() {
    _reloj?.cancel();
    _reloj = null;
    _actual?.remove();
    _actual = null;
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({super.key, required this.novedad, required this.extra, required this.onCerrar});

  final Novedad novedad;
  final int extra;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: sinAnimaciones ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, v, hijo) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * -12), child: hijo),
      ),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: novedad.destacada ? esquema.primary : esquema.outlineVariant, width: 1.5),
          ),
          child: InkWell(
            onTap: onCerrar,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  Icon(
                    novedad.destacada ? Icons.emoji_events_outlined : Icons.trending_up,
                    color: novedad.destacada ? esquema.primary : esquema.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          novedad.titulo,
                          style: TextStyle(
                            fontFamily: Fuentes.estadio,
                            fontVariations: const [FontVariation.weight(800)],
                            fontSize: novedad.destacada ? 20 : 17,
                            color: esquema.onSurface,
                          ),
                        ),
                        if (novedad.detalle case final d?)
                          Text(d, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (extra > 0)
                    Text('+$extra', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
