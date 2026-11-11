import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache_imagenes.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';

/// Foto oficial del jugador (cacheada en disco) con fallback vectorial: degradado de la
/// franquicia + iniciales. El fallback también es el placeholder, así nunca hay un hueco vacío.
class JugadorAvatar extends StatelessWidget {
  const JugadorAvatar({super.key, required this.jugador, required this.franquicia});

  final Jugador jugador;
  final Franquicia franquicia;

  /// Proporción nativa de los headshots del CDN (1040x760).
  static const proporcion = 1040 / 760;

  @override
  Widget build(BuildContext context) {
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    final fallback = _AvatarIniciales(jugador: jugador, franquicia: franquicia);

    return Semantics(
      label: jugador.nombre,
      image: true,
      child: AspectRatio(
        aspectRatio: proporcion,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fallback,
            CachedNetworkImage(
              imageUrl: jugador.headshotUrl,
              cacheManager: cacheHeadshots,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              fadeInDuration: sinAnimaciones ? Duration.zero : const Duration(milliseconds: 180),
              fadeInCurve: Curves.easeOut,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarIniciales extends StatelessWidget {
  const _AvatarIniciales({required this.jugador, required this.franquicia});

  final Jugador jugador;
  final Franquicia franquicia;

  @override
  Widget build(BuildContext context) {
    final primario = Color(franquicia.colorPrimario);
    final secundario = Color(franquicia.colorSecundario);
    // Texto blanco o negro según cuál contraste más con el color dominante.
    final texto = primario.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return LayoutBuilder(
      builder: (context, c) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primario, Color.lerp(primario, secundario, 0.35)!],
          ),
        ),
        child: Center(
          child: ExcludeSemantics(
            child: Text(
              jugador.iniciales,
              style: TextStyle(
                color: texto,
                fontSize: c.biggest.shortestSide * 0.38,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
