import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/oferta.dart';
import '../../domain/entities/posicion.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/disposicion.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/escudo.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';

/// Modo cartas: 3 sobres cerrados para un puesto. Al tocar uno, se abre (la tapa se rasga y sube,
/// los otros se apagan) y recién ahí se reparten sus cartas con [onAbrir].
class ElegirSobre extends StatefulWidget {
  const ElegirSobre({super.key, required this.posicion, required this.sobres, required this.onAbrir, this.aviso});

  final Posicion posicion;
  final List<Sobre> sobres;
  final ValueChanged<int> onAbrir;

  /// Texto extra bajo el título (p. ej. el draft en serpiente).
  final String? aviso;

  static String titulo(Sobre s) => switch (s.tipo) {
    TipoSobre.epoca => 'SOBRE ${s.epoca!.etiqueta.toUpperCase()}',
    TipoSobre.franquicia => 'SOBRE ${franquiciaPorId(s.franquiciaId!).nombre.toUpperCase()}',
    TipoSobre.misterioso => 'SOBRE MISTERIOSO',
  };

  static String detalle(Sobre s) => switch (s.tipo) {
    TipoSobre.epoca => 'Todas las cartas de esa década',
    TipoSobre.franquicia => 'Todas las cartas de esa franquicia',
    TipoSobre.misterioso => 'Cualquier carta, con más chances de una grande',
  };

  @override
  State<ElegirSobre> createState() => _ElegirSobreState();
}

class _ElegirSobreState extends State<ElegirSobre> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  int? _elegido;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _abrir(int i) async {
    if (_elegido != null) return;
    Haptica.media();
    setState(() => _elegido = i);
    if (!MediaQuery.disableAnimationsOf(context)) await _c.forward();
    if (mounted) widget.onAbrir(i);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ColoredBox(
      color: esquema.surfaceContainerLowest.withValues(alpha: 0.985),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, c) {
              const separacion = 12.0;
              final ancho = min((c.maxWidth - 2 * separacion) / 3, esTabletApaisada(context) ? 230.0 : 170.0);
              return Column(
                children: [
                  Text(
                    '${widget.posicion.etiqueta}: ELEGÍ UN SOBRE',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.aviso ?? 'Cada sobre trae 5 cartas. Una viene boca abajo: la sorpresa.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final (i, s) in widget.sobres.indexed) ...[
                          if (i > 0) const SizedBox(width: separacion),
                          _SobreAnimado(
                            sobre: s,
                            ancho: ancho,
                            orden: i,
                            avance: _elegido == null ? 0 : _c.value,
                            elegido: _elegido == i,
                            apagado: _elegido != null && _elegido != i,
                            onTap: () => _abrir(i),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _elegido == null ? 'Tocá un sobre para abrirlo.' : ' ',
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Un sobre: entra con un pequeño escalonado; el elegido sube, la tapa se rasga y se vuela.
class _SobreAnimado extends StatefulWidget {
  const _SobreAnimado({
    required this.sobre,
    required this.ancho,
    required this.orden,
    required this.avance,
    required this.elegido,
    required this.apagado,
    required this.onTap,
  });

  final Sobre sobre;
  final double ancho;
  final int orden;
  final double avance; // 0–1 de la apertura
  final bool elegido, apagado;
  final VoidCallback onTap;

  @override
  State<_SobreAnimado> createState() => _SobreAnimadoState();
}

class _SobreAnimadoState extends State<_SobreAnimado> with SingleTickerProviderStateMixin {
  // Entrada escalonada con un solo controlador (sin timers): cada sobre arranca 90 ms después.
  late final _entrada = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 420 + 90 * widget.orden),
  );
  late final _curva = CurvedAnimation(
    parent: _entrada,
    curve: Interval(90 * widget.orden / (420 + 90 * widget.orden), 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MediaQuery.disableAnimationsOf(context) ? _entrada.value = 1 : _entrada.forward();
    });
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final s = widget.sobre;
    final color = switch (s.tipo) {
      TipoSobre.franquicia => colorLed(franquiciaPorId(s.franquiciaId!)),
      _ => esquema.primary,
    };
    // Apertura: el elegido sube y crece un poco (0–0.4), la tapa se va (0.35–0.85).
    final u = widget.avance;
    final sube = widget.elegido ? Curves.easeOutCubic.transform((u / 0.4).clamp(0, 1)) : 0.0;
    final tapa = widget.elegido ? Curves.easeInCubic.transform(((u - 0.35) / 0.5).clamp(0, 1)) : 0.0;
    final alto = widget.ancho / proporcionCarta;
    return AnimatedBuilder(
      animation: _curva,
      builder: (context, hijo) {
        final e = _curva.value;
        return Opacity(
          opacity: e * (widget.apagado ? (1 - u).clamp(0.15, 1) : 1),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - e) - 24 * sube),
            child: Transform.scale(scale: 1 + 0.08 * sube, child: hijo),
          ),
        );
      },
      child: Semantics(
        button: true,
        label: '${ElegirSobre.titulo(s)}. ${ElegirSobre.detalle(s)}',
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              width: widget.ancho,
              height: alto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: _CuerpoSobre(sobre: s, color: color),
                  ),
                  // Tapa (franja de arriba con el troquel): se rasga y sale volando.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -tapa * alto * 0.5,
                    height: alto * 0.16,
                    child: Opacity(
                      opacity: 1 - tapa,
                      child: Transform.rotate(
                        angle: -0.25 * tapa,
                        alignment: Alignment.centerLeft,
                        child: _Tapa(color: color),
                      ),
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

class _CuerpoSobre extends StatelessWidget {
  const _CuerpoSobre({required this.sobre, required this.color});

  final Sobre sobre;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final emblema = switch (sobre.tipo) {
          TipoSobre.epoca => TextoLed(sobre.epoca!.codigo, tamano: w * 0.32, color: color),
          TipoSobre.franquicia => Escudo(franquiciaPorId(sobre.franquiciaId!), tamano: w * 0.5),
          TipoSobre.misterioso => TextoLed('?', tamano: w * 0.5, color: color),
        };
        return DecoratedBox(
          decoration: BoxDecoration(
            color: esquema.surfaceContainer,
            borderRadius: BorderRadius.circular(w * 0.07),
            border: Border.all(color: color, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(w * 0.07),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: GrillaLedPainter(esquema.onSurface.withValues(alpha: 0.06))),
                Padding(
                  padding: EdgeInsets.fromLTRB(w * 0.08, w * 0.3, w * 0.08, w * 0.08),
                  child: Column(
                    children: [
                      Expanded(child: Center(child: emblema)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          ElegirSobre.titulo(sobre),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: Fuentes.estadio,
                            fontVariations: const [FontVariation.weight(800)],
                            fontSize: w * 0.13,
                            letterSpacing: 0.5,
                            color: esquema.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(height: w * 0.03),
                      Text(
                        ElegirSobre.detalle(sobre),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: TextStyle(fontSize: w * 0.075, color: esquema.onSurfaceVariant, height: 1.2),
                      ),
                      SizedBox(height: w * 0.04),
                      TextoLed('5 CARTAS', tamano: w * 0.08, color: color),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tapa del sobre con línea de troquel.
class _Tapa extends StatelessWidget {
  const _Tapa({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TapaPainter(color: color, fondo: Theme.of(context).colorScheme.surfaceContainerHighest),
  );
}

class _TapaPainter extends CustomPainter {
  _TapaPainter({required this.color, required this.fondo});

  final Color color, fondo;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.07;
    final rect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(rect, Paint()..color = fondo);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Troquel: línea punteada donde se rasga.
    final punto = Paint()..color = color.withValues(alpha: 0.8);
    for (var x = size.width * 0.06; x < size.width * 0.94; x += size.width * 0.06) {
      canvas.drawCircle(Offset(x, size.height - 3), 1.3, punto);
    }
  }

  @override
  bool shouldRepaint(_TapaPainter viejo) => viejo.color != color;
}
