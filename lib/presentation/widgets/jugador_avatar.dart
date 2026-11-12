import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache_imagenes.dart';
import '../../core/foto_wikipedia.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';

/// Foto del jugador (cacheada en disco). Prueba sus fuentes en orden (NBA, Basketball-Reference,
/// Wikipedia). Las iniciales aparecen solo mientras carga o si no hay ninguna foto: nunca debajo de
/// una foto (las de la NBA tienen fondo transparente y se verían superpuestas).
/// Las fotos de archivo (con fondos de cualquier tipo) se muestran a dos tonos: el fondo pasa a ser
/// el color del equipo, como un retrato de estudio, y se funde con el panel abajo.
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
    final panel = Theme.of(context).colorScheme.surfaceContainerLowest;
    final iniciales = _AvatarIniciales(jugador: jugador, franquicia: franquicia);
    final foto = ColoredBox(
      color: panel,
      child: usarRed
          ? _FotoEnCadena(
              urls: jugador.urlsFoto,
              recortar: recortar,
              animar: !MediaQuery.disableAnimationsOf(context),
              sinFoto: iniciales,
              duotono: _duotono(panel, Color.lerp(colorLed(franquicia), Colors.white, 0.2)!),
              panel: panel,
            )
          : iniciales,
    );
    return Semantics(
      label: jugador.nombre,
      image: true,
      child: recortar ? foto : AspectRatio(aspectRatio: proporcion, child: foto),
    );
  }

  /// Mapea la luminancia de la foto entre el panel (sombras) y un tono claro del equipo (luces).
  static ColorFilter _duotono(Color oscuro, Color claro) {
    List<double> fila(double o, double c) => [(c - o) * 0.2126, (c - o) * 0.7152, (c - o) * 0.0722, 0, o * 255];
    return ColorFilter.matrix([
      ...fila(oscuro.r, claro.r),
      ...fila(oscuro.g, claro.g),
      ...fila(oscuro.b, claro.b),
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}

/// Prueba la primera URL; si falla, la siguiente; sin ninguna, muestra [sinFoto].
class _FotoEnCadena extends StatelessWidget {
  const _FotoEnCadena({
    required this.urls,
    required this.recortar,
    required this.animar,
    required this.sinFoto,
    required this.duotono,
    required this.panel,
  });

  final List<String> urls;
  final bool recortar;
  final bool animar;
  final Widget sinFoto;
  final ColorFilter duotono;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return sinFoto;
    final siguiente = _FotoEnCadena(
      urls: urls.sublist(1),
      recortar: recortar,
      animar: animar,
      sinFoto: sinFoto,
      duotono: duotono,
      panel: panel,
    );
    final url = urls.first;
    if (url.startsWith('wiki:')) {
      return FutureBuilder<String?>(
        future: fotoWikipedia(url.substring(5)),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return sinFoto;
          final resuelta = snap.data;
          return resuelta == null
              ? siguiente
              : _FotoEnCadena(
                  urls: [resuelta, ...urls.sublist(1)],
                  recortar: recortar,
                  animar: animar,
                  sinFoto: sinFoto,
                  duotono: duotono,
                  panel: panel,
                );
        },
      );
    }
    final archivo = !url.contains('cdn.nba.com');
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: cacheHeadshots,
      fadeInDuration: animar ? const Duration(milliseconds: 180) : Duration.zero,
      fadeInCurve: Curves.easeOut,
      placeholder: (_, _) => sinFoto,
      errorWidget: (_, _, _) => siguiente,
      imageBuilder: (_, imagen) {
        final dibujo = Image(
          image: imagen,
          fit: recortar || archivo ? BoxFit.cover : BoxFit.contain,
          alignment: recortar || archivo ? const Alignment(0, -0.6) : Alignment.bottomCenter,
          width: double.infinity,
          height: double.infinity,
        );
        if (!archivo) return dibujo;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(colorFilter: duotono, child: dibujo),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [panel.withValues(alpha: 0), panel.withValues(alpha: 0), panel],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
          ],
        );
      },
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
