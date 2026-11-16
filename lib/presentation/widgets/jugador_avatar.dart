import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache_imagenes.dart';
import '../../core/fotos/fuentes_foto.dart';
import '../../core/fotos/gestor_fotos.dart';
import '../../core/fotos/indice_fotos.dart';
import '../../core/nba_cdn.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import 'avatar_ilustrado.dart';

/// Foto del jugador. Lee primero del índice local (fotos descargadas una vez y guardadas para siempre
/// en el celular por el [GestorFotos]); lo que falta lo pide el gestor, con ritmo y sin repetir los
/// 404. Mientras tanto (o si no hay foto) se ve un retrato ilustrado propio con la camiseta de la
/// franquicia: nunca una foto con las iniciales debajo (las de la NBA tienen fondo transparente).
/// Las fotos de archivo (Wikipedia, Commons) llegan ya recortadas (sin fondo) desde el gestor y quedan
/// sobre el panel negro como las de la NBA. Las de la NBA se muestran desde la red al instante si
/// todavía no se bajaron.
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
  /// archivo, ya recortadas) para ver el encuadre real sin red ni ML Kit. Las de archivo llegan como
  /// `prueba:archivo/<idBbref>`.
  static Future<ImageProvider?> Function(String url)? imagenesDePrueba;

  @override
  Widget build(BuildContext context) {
    final panel = Theme.of(context).colorScheme.surfaceContainerLowest;
    final ilustrado = AvatarIlustrado(jugador: jugador, franquicia: franquicia, iniciales: !recortar);
    final foto = ColoredBox(
      color: panel,
      child: usarRed
          ? _FotoPersona(
              jugador: jugador,
              recortar: recortar,
              animar: !MediaQuery.disableAnimationsOf(context),
              sinFoto: ilustrado,
              panel: panel,
            )
          : ilustrado,
    );
    return Semantics(
      label: jugador.nombre,
      image: true,
      child: recortar ? foto : AspectRatio(aspectRatio: proporcion, child: foto),
    );
  }
}

/// Foto de la persona: del índice local si está; si no, la pide al gestor.
class _FotoPersona extends StatefulWidget {
  const _FotoPersona({
    required this.jugador,
    required this.recortar,
    required this.animar,
    required this.sinFoto,
    required this.panel,
  });

  final Jugador jugador;
  final bool recortar;
  final bool animar;
  final Widget sinFoto;
  final Color panel;

  @override
  State<_FotoPersona> createState() => _FotoPersonaState();
}

class _FotoPersonaState extends State<_FotoPersona> {
  late final PersonaFoto? _persona = GestorFotos.personaDe(widget.jugador);

  @override
  void initState() {
    super.initState();
    final persona = _persona, gestor = GestorFotos.instancia;
    if (persona != null && gestor != null && JugadorAvatar.imagenesDePrueba == null) {
      // Fuera del build: pedir una foto notifica al gestor.
      scheduleMicrotask(() => gestor.solicitar(persona));
    }
  }

  Widget _imagenNba(ImageProvider imagen) => Image(
    image: imagen,
    fit: widget.recortar ? BoxFit.cover : BoxFit.contain,
    alignment: widget.recortar ? const Alignment(0, -0.6) : Alignment.bottomCenter,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, _, _) => widget.sinFoto,
  );

  Widget _recorte(ImageProvider imagen) => _RecorteArchivo(
    imagen: imagen,
    recortar: widget.recortar,
    animar: widget.animar,
    panel: widget.panel,
    siguiente: widget.sinFoto,
  );

  Widget _redNba(String url) => CachedNetworkImage(
    imageUrl: url,
    cacheManager: cacheHeadshots,
    fadeInDuration: widget.animar ? const Duration(milliseconds: 180) : Duration.zero,
    fadeInCurve: Curves.easeOut,
    placeholder: (_, _) => widget.sinFoto,
    errorWidget: (_, _, _) => widget.sinFoto,
    imageBuilder: (_, imagen) => _imagenNba(imagen),
  );

  @override
  Widget build(BuildContext context) {
    final persona = _persona;
    if (persona == null) return widget.sinFoto;

    final prueba = JugadorAvatar.imagenesDePrueba;
    if (prueba != null) return _deprueba(prueba, persona);

    final gestor = GestorFotos.instancia;
    final urlNba = persona.usaNba && persona.nbaPlayerId > 0 ? NbaCdn.headshot(persona.nbaPlayerId) : null;
    if (gestor == null) return urlNba == null ? widget.sinFoto : _redNba(urlNba);

    return ListenableBuilder(
      listenable: gestor.escuchar(persona.clave),
      builder: (context, _) {
        final fila = gestor.de(persona.clave);
        final archivo = gestor.archivoMostrable(persona.clave);
        if (archivo != null) {
          return fila!.esNba ? _imagenNba(FileImage(archivo)) : _recorte(FileImage(archivo));
        }
        // Aún sin archivo local: la NBA se ve al instante desde la red (y el gestor la baja); lo
        // demás espera el retrato ilustrado hasta que el gestor la tenga.
        if (urlNba != null && fila?.estado != EstadoFoto.sin) return _redNba(urlNba);
        return widget.sinFoto;
      },
    );
  }

  Widget _deprueba(Future<ImageProvider?> Function(String) prueba, PersonaFoto persona) {
    final urls = [if (persona.usaNba) NbaCdn.headshot(persona.nbaPlayerId), 'prueba:archivo/${persona.clave}'];
    return FutureBuilder<(String, ImageProvider)?>(
      future: _primera(prueba, urls),
      builder: (context, snap) {
        final r = snap.data;
        if (r == null) return widget.sinFoto;
        return r.$1.contains('cdn.nba.com') ? _imagenNba(r.$2) : _recorte(r.$2);
      },
    );
  }

  Future<(String, ImageProvider)?> _primera(Future<ImageProvider?> Function(String) prueba, List<String> urls) async {
    for (final u in urls) {
      final i = await prueba(u);
      if (i != null) return (u, i);
    }
    return null;
  }
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
