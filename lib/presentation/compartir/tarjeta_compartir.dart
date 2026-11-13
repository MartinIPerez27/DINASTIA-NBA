import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/modos/dinastia.dart';
import '../../domain/modos/escalera.dart';
import '../../domain/premios.dart';
import '../../domain/reto.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Lo que se cuenta en la tarjeta para compartir: el marcador grande, qué significa y el remate.
class ResumenCompartir {
  const ResumenCompartir({
    required this.led,
    required this.etiqueta,
    required this.titular,
    this.trofeo = false,
    this.lineas = const [],
    this.premios = const [],
    this.codigo,
  });

  final String led;
  final String etiqueta;
  final String titular;
  final bool trofeo;
  final List<String> lineas;
  final List<String> premios;
  final String? codigo;

  static bool _regularTerminada(Temporada t) => t.calendario.isNotEmpty && t.calendario.every((p) => p.jugado);

  /// Arma el resumen según el modo: temporada (y sus variantes), dinastía o escalera.
  factory ResumenCompartir.de(Temporada t, {Liga? liga}) {
    final u = t.franquiciaUsuarioId;
    final codigo = Reto.codigoDe(t)?.codificar();
    final m = t.modoJuego;
    if (m.usaTemporada) {
      final r = t.registroUsuario;
      final campeon = t.campeonId == u;
      final terminada = _regularTerminada(t);
      final eliminacion = t.eliminacion;
      final titular = switch (t) {
        _ when t.esTemporadaPerfecta && campeon => '¡82-0 Y CAMPEONES! LA HAZAÑA INMORTAL',
        _ when t.esTemporadaPerfecta => '¡82-0! LA TEMPORADA PERFECTA',
        _ when campeon => '¡CAMPEONES DE LA NBA!',
        _ when eliminacion != null => 'Afuera en ${eliminacion.ronda.etiqueta}',
        _ when t.fase == FaseTemporada.playoffs => 'En los playoffs',
        _ when t.fase == FaseTemporada.finalizada => 'Sin playoffs esta vez',
        _ when !terminada => 'Camino al 82-0',
        _ => 'Temporada regular terminada',
      };
      final lineas = <String>[
        if (m == ModoJuego.dinastia || m == ModoJuego.reescribi) _lineaDinastia(t, campeon),
        if (m == ModoJuego.reto) ?_lineaReto(t),
      ];
      final premios = liga == null || t.lineas.isEmpty
          ? const <String>[]
          : [for (final (nombre, g) in calcularPremios(t, liga).de(u)) '$nombre · ${apellido(g.jugador)}'];
      return ResumenCompartir(
        led: '${r.victorias}-${r.derrotas}',
        etiqueta: terminada ? 'TEMPORADA REGULAR' : 'EN CURSO · ${r.jugados} DE ${Temporada.partidosTemporadaRegular}',
        titular: titular,
        trofeo: campeon,
        lineas: lineas,
        premios: premios.take(3).toList(),
        codigo: codigo,
      );
    }
    final e = Escalera.de(t);
    final ganados = e.cruces.where((c) => c.ganado).length;
    final (led, etiqueta) = switch (m) {
      ModoJuego.racha => ('${e.racha}', 'RACHA'),
      ModoJuego.escenario => ('${e.actual?.propias ?? 0}-${e.actual?.ajenas ?? 0}', 'SERIE'),
      ModoJuego.mundial => ('${e.victorias}-${e.derrotas}', 'RÉCORD'),
      ModoJuego.caminoAlAnillo => ('$ganados/${e.total ?? 10}', 'ESCALONES'),
      _ => ('$ganados/${e.total ?? 10}', 'GANADOS'),
    };
    final escenario = m == ModoJuego.escenario ? escenarioPorId(e.escenarioId) : null;
    final titular = switch (m) {
      _ when e.completada => switch (m) {
        ModoJuego.caminoAlAnillo => '¡EL ANILLO ES TUYO!',
        ModoJuego.mejoresEquipos => '¡EL MEJOR DE LA HISTORIA!',
        ModoJuego.mundial => '¡CAMPEONES DEL MUNDO!',
        _ => '¡LA HISTORIA CAMBIÓ DE FINAL!',
      },
      ModoJuego.racha when e.eliminado => 'Racha de ${e.racha} seguidos',
      ModoJuego.mundial when e.ganadores.length < rondasMundial.length && !e.eliminado =>
        'Mundial: ${rondasMundial[e.ganadores.length]}',
      _ when e.eliminado => 'Se terminó el camino',
      _ => 'En camino',
    };
    return ResumenCompartir(
      led: led,
      etiqueta: etiqueta,
      titular: titular,
      trofeo: e.completada,
      lineas: [if (escenario != null) escenario.titulo, 'Partidos: ${e.victorias}-${e.derrotas}'],
    );
  }

  static String _lineaDinastia(Temporada t, bool campeonAhora) {
    final d = EstadoDinastia.de(t);
    final anillos = d.titulos + (campeonAhora ? 1 : 0);
    return 'Dinastía · temporada ${d.numero} · $anillos ${anillos == 1 ? 'anillo' : 'anillos'}';
  }

  static String? _lineaReto(Temporada t) {
    final (tuya, amigo, veredicto) = Reto.comparar(t);
    if (amigo == null) return 'Reto de un amigo · vos $tuya';
    return 'Reto: vos $tuya · tu amigo $amigo${veredicto == null ? '' : ' · ${veredicto.texto}'}';
  }
}

/// Tarjeta vertical (9:16) para compartir: escudo, marcador LED, plantel, premios y código de reto.
/// Mide siempre [ancho]×[alto] lógicos; a ×3 queda en 1080×1920.
class TarjetaCompartir extends StatelessWidget {
  const TarjetaCompartir({super.key, required this.temporada, this.liga});

  final Temporada temporada;
  final Liga? liga;

  static const ancho = 360.0;
  static const alto = 640.0;

  @override
  Widget build(BuildContext context) {
    final t = temporada;
    final f = franquiciaPorId(t.franquiciaUsuarioId);
    final r = ResumenCompartir.de(t, liga: liga);
    return Theme(
      data: temaFranquicia(f),
      child: Builder(
        builder: (context) {
          final tema = Theme.of(context);
          final esquema = tema.colorScheme;
          final dorado = const Color(0xFFF2C14E);
          // Material propio: la tarjeta se dibuja igual dentro de cualquier pantalla (o fuera de ella).
          return Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: ancho,
              height: alto,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: esquema.surfaceContainerLowest,
                  border: Border.all(color: esquema.primary, width: 3),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Escudo(f, tamano: 54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.nombreCompleto.toUpperCase(),
                                  maxLines: 2,
                                  style: _estadio(22, esquema.onSurface),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.modoJuego == ModoJuego.clasico ? 'Temporada 82-0' : t.modoJuego.nombre} · '
                                  '${t.dificultad.nombre}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: FittedBox(fit: BoxFit.scaleDown, child: TextoLed(r.led, tamano: 76)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.etiqueta,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, letterSpacing: 2, color: esquema.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (r.trofeo) ...[
                            Icon(Icons.emoji_events, color: dorado, size: 26),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              r.titular,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: _estadio(20, r.trofeo ? dorado : esquema.primary),
                            ),
                          ),
                        ],
                      ),
                      for (final l in r.lineas)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(fontSize: 12, color: esquema.onSurface),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: esquema.outlineVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      for (final p in Posicion.values)
                        if (t.plantel.en(p) case final j?)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 92,
                                  child: Text(
                                    p.etiqueta.toUpperCase(),
                                    style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: esquema.onSurfaceVariant),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    j.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextoLed('${j.media}', tamano: 18),
                              ],
                            ),
                          ),
                      if (r.premios.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in r.premios)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: dorado.withValues(alpha: 0.7)),
                                ),
                                child: Text(p, style: TextStyle(fontSize: 11, color: dorado)),
                              ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      if (r.codigo case final codigo?)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: esquema.primary.withValues(alpha: 0.6)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '¿TE ANIMÁS? JUGÁ MI MISMO DRAFT',
                                style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: esquema.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(fit: BoxFit.scaleDown, child: TextoLed(codigo, tamano: 26)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        'DINASTÍA NBA (82-0)',
                        textAlign: TextAlign.center,
                        style: _estadio(13, esquema.onSurfaceVariant).copyWith(letterSpacing: 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static TextStyle _estadio(double tamano, Color color) => TextStyle(
    fontFamily: Fuentes.estadio,
    fontVariations: const [FontVariation.weight(800)],
    fontSize: tamano,
    height: 1.05,
    color: color,
  );
}

/// Se puede compartir una partida con plantel armado (las de amigos tienen su propia pantalla).
bool sePuedeCompartir(Temporada t) => t.plantel.completo;

/// Botón para la barra de arriba: abre la vista previa para compartir.
class BotonCompartir extends StatelessWidget {
  const BotonCompartir({super.key, required this.temporada, this.liga});

  final Temporada temporada;
  final Liga? liga;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Compartir',
    icon: const Icon(Icons.ios_share),
    onPressed: sePuedeCompartir(temporada) ? () => compartirPartida(context, temporada, liga: liga) : null,
  );
}

/// Abre la vista previa de la tarjeta, con los botones para compartir la imagen y el código de reto.
Future<void> compartirPartida(BuildContext context, Temporada t, {Liga? liga}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => CompartirPantalla(temporada: t, liga: liga),
  ),
);

class CompartirPantalla extends StatefulWidget {
  const CompartirPantalla({super.key, required this.temporada, this.liga});

  final Temporada temporada;
  final Liga? liga;

  @override
  State<CompartirPantalla> createState() => _CompartirPantallaState();
}

class _CompartirPantallaState extends State<CompartirPantalla> {
  final _tarjeta = GlobalKey();
  var _ocupado = false;

  CodigoReto? get _codigo => Reto.codigoDe(widget.temporada);

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _compartirImagen() async {
    setState(() => _ocupado = true);
    try {
      final png = await capturarPng(_tarjeta);
      if (png == null) throw StateError('Sin imagen');
      final carpeta = await getTemporaryDirectory();
      final archivo = File('${carpeta.path}/dinastia-nba-${widget.temporada.id}.png');
      await archivo.writeAsBytes(png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archivo.path, mimeType: 'image/png')],
          text: _textoCodigo() ?? 'Mi temporada en Dinastía NBA (82-0).',
        ),
      );
    } catch (e) {
      _aviso('No se pudo compartir la imagen en este dispositivo.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String? _textoCodigo() {
    final c = _codigo;
    if (c == null) return null;
    final f = franquiciaPorId(c.franquiciaId);
    final marca = c.marca == null ? '' : ' Yo hice ${c.marca}${c.campeon ? ' y salí campeón' : ''}.';
    return 'Te reto en Dinastía NBA (82-0): jugá mi mismo draft con los ${f.nombre} '
        '(${c.modo.nombre}, ${c.dificultad.nombre}).$marca Código: ${c.codificar()}';
  }

  Future<void> _compartirCodigo() async {
    final texto = _textoCodigo();
    if (texto == null) return;
    try {
      await SharePlus.instance.share(ShareParams(text: texto));
    } catch (e) {
      await _copiar();
    }
  }

  Future<void> _copiar() async {
    final c = _codigo;
    if (c == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: c.codificar()));
      _aviso('Código copiado: ${c.codificar()}');
    } catch (e) {
      _aviso('No se pudo copiar el código.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.temporada;
    final esquema = Theme.of(context).colorScheme;
    final codigo = _codigo;
    return Scaffold(
      appBar: AppBar(title: const Text('Compartir')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _tarjeta,
                    child: TarjetaCompartir(temporada: t, liga: widget.liga),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _ocupado ? null : _compartirImagen,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('COMPARTIR IMAGEN'),
                  ),
                  const SizedBox(height: 8),
                  if (codigo != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _compartirCodigo,
                            icon: const Icon(Icons.sports_score),
                            label: const Text('RETAR A UN AMIGO'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(tooltip: 'Copiar código', onPressed: _copiar, icon: const Icon(Icons.copy)),
                      ],
                    )
                  else
                    Text(
                      t.regla == ReglaDraft.coleccion
                          ? 'Las partidas de "Mi colección" no se pueden usar como reto: cada álbum es distinto.'
                          : t.modoJuego.usaTemporada &&
                                t.modoJuego != ModoJuego.clasico &&
                                t.modoJuego != ModoJuego.reto
                          ? 'Los retos son para la Temporada 82-0.'
                          : t.modoJuego.usaTemporada
                          ? 'Esta partida es de antes de los retos: no tiene código.'
                          : 'Compartí tu marca y desafiá a tus amigos a superarla.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La tarjeta en PNG a ×[pixelRatio] (1080×1920 a ×3). Null si todavía no se dibujó.
Future<List<int>?> capturarPng(GlobalKey clave, {double pixelRatio = 3}) async {
  final boundary = clave.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final imagen = await boundary.toImage(pixelRatio: pixelRatio);
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  return datos?.buffer.asUint8List();
}
