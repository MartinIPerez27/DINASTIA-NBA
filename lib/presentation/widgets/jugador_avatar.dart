import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache_imagenes.dart';
import '../../core/foto_wikipedia.dart';
import '../../core/recorte_fotos.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';

/// Foto del jugador (cacheada en disco). Prueba sus fuentes en orden (NBA, Basketball-Reference,
/// Wikipedia). Las iniciales aparecen solo mientras carga o si no hay ninguna foto: nunca debajo de
/// una foto (las de la NBA tienen fondo transparente y se verían superpuestas).
/// Las fotos de archivo (con fondos de cualquier tipo) se recortan en el celular para quitarles el
/// fondo y quedan sobre el panel negro como las de la NBA; si no se pueden recortar, se pasa a la
/// fuente siguiente (nunca se muestra una foto con su fondo).
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

  /// Solo para capturas: resuelve cada URL a una imagen local (las de la NBA, tal cual; las de
  /// archivo, ya recortadas) para ver el encuadre real sin red ni ML Kit.
  static Future<ImageProvider?> Function(String url)? imagenesDePrueba;

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
}

/// Prueba la primera URL; si falla, la siguiente; sin ninguna, muestra [sinFoto].
class _FotoEnCadena extends StatelessWidget {
  const _FotoEnCadena({
    required this.urls,
    required this.recortar,
    required this.animar,
    required this.sinFoto,
    required this.panel,
  });

  final List<String> urls;
  final bool recortar;
  final bool animar;
  final Widget sinFoto;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return sinFoto;
    final siguiente = _FotoEnCadena(
      urls: urls.sublist(1),
      recortar: recortar,
      animar: animar,
      sinFoto: sinFoto,
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
                  panel: panel,
                );
        },
      );
    }
    final prueba = JugadorAvatar.imagenesDePrueba;
    if (prueba != null && url.contains('cdn.nba.com')) {
      return FutureBuilder<ImageProvider?>(
        future: prueba(url),
        builder: (context, snap) => snap.data == null
            ? sinFoto
            : Image(
                image: snap.data!,
                fit: recortar ? BoxFit.cover : BoxFit.contain,
                alignment: recortar ? const Alignment(0, -0.6) : Alignment.bottomCenter,
                width: double.infinity,
                height: double.infinity,
              ),
      );
    }
    if (!url.contains('cdn.nba.com')) {
      return FutureBuilder<ImageProvider?>(
        future: prueba != null ? prueba(url) : recorteSinFondo(url).then((f) => f == null ? null : FileImage(f)),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return sinFoto;
          final recorte = snap.data;
          if (recorte == null) return siguiente;
          return _RecorteArchivo(
            imagen: recorte,
            recortar: recortar,
            animar: animar,
            panel: panel,
            siguiente: siguiente,
          );
        },
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: cacheHeadshots,
      fadeInDuration: animar ? const Duration(milliseconds: 180) : Duration.zero,
      fadeInCurve: Curves.easeOut,
      placeholder: (_, _) => sinFoto,
      errorWidget: (_, _, _) => siguiente,
      imageBuilder: (_, imagen) => Image(
        image: imagen,
        fit: recortar ? BoxFit.cover : BoxFit.contain,
        alignment: recortar ? const Alignment(0, -0.6) : Alignment.bottomCenter,
        width: double.infinity,
        height: double.infinity,
      ),
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

/// Recorte de una foto de archivo, encuadrado como los headshots de la NBA: cabeza arriba, del mismo
/// tamaño, y el pecho que se funde en el panel (las fotos de archivo cortan a la altura del pecho;
/// las de la NBA llegan hasta el borde de abajo). Se ve igual en la caja apaisada y en miniaturas.
class _RecorteArchivo extends StatelessWidget {
  const _RecorteArchivo({
    required this.imagen,
    required this.recortar,
    required this.animar,
    required this.panel,
    required this.siguiente,
  });

  final ImageProvider imagen;
  final bool recortar;
  final bool animar;
  final Color panel;
  final Widget siguiente;

  /// Alto del recorte respecto del cuadro de 1040×760 y dónde empieza: en los headshots de la NBA
  /// la cabeza ocupa ~52 % del alto y arranca casi pegada arriba; en los primeros planos de
  /// Basketball-Reference la cabeza es ~64 % de la foto, así que el recorte va al ~82 % del alto,
  /// desde el 4 %.
  static const _alto = 0.82, _arriba = 0.04;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // Cuadro virtual de 1040×760 ubicado exactamente como quedaría un headshot de la NBA en esta
      // caja (cover arriba en miniaturas, contain abajo en la caja apaisada): así la cabeza de la
      // foto de archivo tiene el mismo tamaño y lugar que la de la NBA en cualquier carta.
      final w = c.maxWidth, h = c.maxHeight;
      final escala = recortar ? max(w / 1040, h / 760) : min(w / 1040, h / 760);
      final cuadroAlto = 760 * escala;
      final cuadroArriba = recortar ? (h - cuadroAlto) * 0.2 : h - cuadroAlto;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: cuadroArriba + cuadroAlto * _arriba,
            left: 0,
            right: 0,
            height: cuadroAlto * _alto,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.68, 1],
              ).createShader(r),
              child: Image(
                image: imagen,
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => siguiente,
                frameBuilder: (_, hijo, cuadro, sincronica) => sincronica || !animar
                    ? hijo
                    : AnimatedOpacity(
                        opacity: cuadro == null ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: hijo,
                      ),
              ),
            ),
          ),
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
