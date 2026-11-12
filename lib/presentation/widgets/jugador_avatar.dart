import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache_imagenes.dart';
import '../../core/foto_wikipedia.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';

/// Foto del jugador (cacheada en disco). Prueba sus fuentes en orden (NBA, Basketball-Reference,
/// Wikipedia) y, si ninguna carga, quedan las iniciales en el LED de la franquicia, que también
/// son el placeholder: nunca hay un hueco vacío.
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
        if (usarRed) _FotoEnCadena(urls: jugador.urlsFoto, recortar: recortar, animar: !sinAnimaciones),
      ],
    );
    return Semantics(
      label: jugador.nombre,
      image: true,
      child: recortar ? foto : AspectRatio(aspectRatio: proporcion, child: foto),
    );
  }
}

/// Prueba la primera URL; si falla, la siguiente; si no queda ninguna, no dibuja nada.
class _FotoEnCadena extends StatelessWidget {
  const _FotoEnCadena({required this.urls, required this.recortar, required this.animar});

  final List<String> urls;
  final bool recortar;
  final bool animar;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final siguiente = _FotoEnCadena(urls: urls.sublist(1), recortar: recortar, animar: animar);
    if (urls.first.startsWith('wiki:')) {
      return FutureBuilder<String?>(
        future: fotoWikipedia(urls.first.substring(5)),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
          final url = snap.data;
          return url == null
              ? siguiente
              : _FotoEnCadena(urls: [url, ...urls.sublist(1)], recortar: recortar, animar: animar);
        },
      );
    }
    return CachedNetworkImage(
      imageUrl: urls.first,
      cacheManager: cacheHeadshots,
      fit: recortar ? BoxFit.cover : BoxFit.contain,
      alignment: recortar ? const Alignment(0, -0.6) : Alignment.bottomCenter,
      fadeInDuration: animar ? const Duration(milliseconds: 180) : Duration.zero,
      fadeInCurve: Curves.easeOut,
      placeholder: (_, _) => const SizedBox.shrink(),
      errorWidget: (_, _, _) => siguiente,
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
