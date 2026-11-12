import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache_imagenes.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';

/// Foto oficial del jugador (cacheada en disco) con fallback: iniciales en el LED de la franquicia.
/// El fallback también es el placeholder, así nunca hay un hueco vacío.
/// Con [recortar], llena su caja mostrando cabeza y hombros (para miniaturas cuadradas).
class JugadorAvatar extends StatelessWidget {
  const JugadorAvatar({super.key, required this.jugador, required this.franquicia, this.recortar = false});

  final Jugador jugador;
  final Franquicia franquicia;
  final bool recortar;

  /// Proporción nativa de los headshots del CDN (1040x760).
  static const proporcion = 1040 / 760;

  // shortcut: interruptor global para pruebas y capturas (el caché de fotos usa plugins nativos
  // que no existen en `flutter test`); pasar a inyección de dependencias si aparece otro caso.
  static bool usarRed = true;

  @override
  Widget build(BuildContext context) {
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    final fallback = _AvatarIniciales(jugador: jugador, franquicia: franquicia);

    final foto = Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        if (usarRed && jugador.nbaPlayerId > 0)
          CachedNetworkImage(
            imageUrl: jugador.headshotUrl,
            cacheManager: cacheHeadshots,
            fit: recortar ? BoxFit.cover : BoxFit.contain,
            alignment: recortar ? const Alignment(0, -0.6) : Alignment.bottomCenter,
            fadeInDuration: sinAnimaciones ? Duration.zero : const Duration(milliseconds: 180),
            fadeInCurve: Curves.easeOut,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
    return Semantics(
      label: jugador.nombre,
      image: true,
      child: recortar ? foto : AspectRatio(aspectRatio: proporcion, child: foto),
    );
  }
}

/// Sin foto: el panel del tablero con las iniciales encendidas en el LED de la franquicia de la carta.
class _AvatarIniciales extends StatelessWidget {
  const _AvatarIniciales({required this.jugador, required this.franquicia});

  final Jugador jugador;
  final Franquicia franquicia;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Center(
        child: ExcludeSemantics(
          child: Text(
            jugador.iniciales,
            style: TextStyle(
              fontFamily: Fuentes.estadio,
              fontVariations: const [FontVariation.weight(800)],
              color: colorLed(franquicia),
              fontSize: c.biggest.shortestSide * 0.42,
              height: 1,
            ),
          ),
        ),
      ),
    ),
  );
}
