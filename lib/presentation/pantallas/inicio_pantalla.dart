import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/temporada.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import '../widgets/haptica.dart';

/// Inicio: el marcador del estadio. Al recorrer franquicias, toda la app se tiñe en vivo
/// ([onEnfocar]); el botón principal confirma ([onDirigir]).
class InicioPantalla extends StatelessWidget {
  const InicioPantalla({
    super.key,
    required this.franquicias,
    required this.enfocada,
    required this.onEnfocar,
    required this.onDirigir,
    this.guardada,
    this.onSeguir,
    this.onPerfil,
    this.onPartidas,
    this.onAjustes,
    this.onAlbum,
    this.onModos,
  });

  final List<Franquicia> franquicias;
  final Franquicia enfocada;
  final ValueChanged<Franquicia> onEnfocar;
  final ValueChanged<Franquicia> onDirigir;
  final Temporada? guardada;
  final VoidCallback? onSeguir;

  /// Tu carrera (nivel, vitrina, logros), las partidas guardadas y los ajustes.
  final VoidCallback? onPerfil, onPartidas, onAjustes;

  /// Álbum de cartas y tienda de sobres.
  final VoidCallback? onAlbum;

  /// Menú con el resto de los modos (desafíos, torneos, carrera, con amigos).
  final VoidCallback? onModos;

  void _enfocar(Franquicia f) {
    if (f == enfocada) return;
    Haptica.seleccion();
    onEnfocar(f);
  }

  @override
  Widget build(BuildContext context) {
    final guardada = this.guardada;
    final delGuardado = guardada == null ? null : franquicias.firstWhere((f) => f.id == guardada.franquiciaUsuarioId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BarraCarrera(onPerfil: onPerfil, onPartidas: onPartidas, onAjustes: onAjustes, onAlbum: onAlbum),
                    const SizedBox(height: 8),
                    const _Encabezado(),
                    const SizedBox(height: 16),
                    Expanded(child: _Tablero(franquicia: enfocada)),
                    const SizedBox(height: 16),
                    SegmentedButton<Conferencia>(
                      segments: const [
                        ButtonSegment(value: Conferencia.este, label: Text('Este')),
                        ButtonSegment(value: Conferencia.oeste, label: Text('Oeste')),
                      ],
                      selected: {enfocada.conferencia!},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => _enfocar(franquicias.firstWhere((f) => f.conferencia == s.first)),
                    ),
                    const SizedBox(height: 8),
                    _CintaLed(
                      franquicias: [
                        for (final f in franquicias)
                          if (f.conferencia == enfocada.conferencia) f,
                      ],
                      enfocada: enfocada,
                      onTocar: _enfocar,
                    ),
                    const SizedBox(height: 12),
                    if (guardada != null && delGuardado != null) ...[
                      OutlinedButton(
                        onPressed: onSeguir,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: Text('Seguir la temporada de los ${delGuardado.nombre}'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      onPressed: () => onDirigir(enfocada),
                      child: Text('Dirigir a los ${enfocada.nombre}'.toUpperCase()),
                    ),
                    if (onModos != null)
                      TextButton.icon(
                        onPressed: onModos,
                        icon: const Icon(Icons.grid_view_rounded),
                        label: const Text('OTROS MODOS DE JUEGO'),
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

/// Nivel y monedas del entrenador (abre tu carrera), partidas guardadas y ajustes.
class _BarraCarrera extends StatelessWidget {
  const _BarraCarrera({
    required this.onPerfil,
    required this.onPartidas,
    required this.onAjustes,
    required this.onAlbum,
  });

  final VoidCallback? onPerfil, onPartidas, onAjustes, onAlbum;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ValueListenableBuilder(
      valueListenable: perfilApp,
      builder: (context, perfil, _) => Row(
        children: [
          Semantics(
            button: true,
            label: 'Tu carrera: nivel ${perfil.nivel}, ${perfil.monedas} monedas',
            child: ExcludeSemantics(
              child: Material(
                color: esquema.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: InkWell(
                  onTap: onPerfil,
                  borderRadius: BorderRadius.circular(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('NIV', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
                          const SizedBox(width: 6),
                          TextoLed('${perfil.nivel}', tamano: 20),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 42,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(value: perfil.avanceNivel, minHeight: 4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.toll, size: 18, color: esquema.onSurfaceVariant),
                          const SizedBox(width: 4),
                          TextoLed('${perfil.monedas}', tamano: 18, color: esquema.onSurface),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPartidas,
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Partidas guardadas',
          ),
          IconButton(onPressed: onAjustes, icon: const Icon(Icons.settings_outlined), tooltip: 'Ajustes'),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        'DINASTÍA',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontVariations: const [FontVariation.weight(800)], letterSpacing: 3),
      ),
      const Spacer(),
      const TextoLed('82-0', tamano: 44),
    ],
  );
}

/// La pantalla del tablero: escudo, ciudad y nombre de la franquicia enfocada.
class _Tablero extends StatelessWidget {
  const _Tablero({required this.franquicia});

  final Franquicia franquicia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: CustomPaint(
        painter: _GrillaLed(esquema.onSurface.withValues(alpha: 0.05)),
        child: AnimatedSwitcher(
          duration: sinAnimaciones ? Duration.zero : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: LayoutBuilder(
            key: ValueKey(franquicia.id),
            builder: (context, c) {
              final escudo = (c.maxHeight * 0.5).clamp(72.0, 280.0);
              return Padding(
                padding: const EdgeInsets.all(20),
                // En pantallas bajas el bloque entero se achica en vez de desbordarse.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: (c.maxWidth - 40).clamp(0, double.infinity),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Escudo(franquicia, tamano: escudo),
                        SizedBox(height: escudo * 0.15),
                        Text(
                          franquicia.ciudad.toUpperCase(),
                          style: tema.textTheme.headlineSmall?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            franquicia.nombre.toUpperCase(),
                            maxLines: 1,
                            style: tema.textTheme.displayLarge?.copyWith(fontSize: 76),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${franquicia.conferencia!.etiqueta} · División ${franquicia.division!.etiqueta}',
                          style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Los LED apagados del tablero: una grilla de puntos tenue, el material del panel.
class _GrillaLed extends CustomPainter {
  const _GrillaLed(this.color);

  final Color color;
  static const _paso = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()..color = color;
    for (var y = _paso; y < size.height - _paso / 2; y += _paso) {
      for (var x = _paso; x < size.width - _paso / 2; x += _paso) {
        canvas.drawCircle(Offset(x, y), 1.2, pintura);
      }
    }
  }

  @override
  bool shouldRepaint(_GrillaLed anterior) => anterior.color != color;
}

/// La cinta LED que rodea el estadio: siglas de la conferencia, la enfocada encendida.
class _CintaLed extends StatefulWidget {
  const _CintaLed({required this.franquicias, required this.enfocada, required this.onTocar});

  final List<Franquicia> franquicias;
  final Franquicia enfocada;
  final ValueChanged<Franquicia> onTocar;

  @override
  State<_CintaLed> createState() => _CintaLedState();
}

class _CintaLedState extends State<_CintaLed> {
  final _claves = <String, GlobalKey>{};

  @override
  void didUpdateWidget(_CintaLed anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.enfocada != widget.enfocada) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _claves[widget.enfocada.id]?.currentContext;
        if (ctx == null || !mounted) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in widget.franquicias)
            _ItemCinta(
              key: _claves.putIfAbsent(f.id, GlobalKey.new),
              franquicia: f,
              encendida: f == widget.enfocada,
              colorLed: esquema.primary,
              onTap: () => widget.onTocar(f),
            ),
        ],
      ),
    );
  }
}

class _ItemCinta extends StatelessWidget {
  const _ItemCinta({
    super.key,
    required this.franquicia,
    required this.encendida,
    required this.colorLed,
    required this.onTap,
  });

  final Franquicia franquicia;
  final bool encendida;
  final Color colorLed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final apagado = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: encendida,
      label: franquicia.nombreCompleto,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: encendida ? 1 : 0.45,
                  duration: const Duration(milliseconds: 150),
                  child: Escudo(franquicia, tamano: 36),
                ),
                const SizedBox(height: 6),
                TextoLed(franquicia.id, tamano: 18, color: encendida ? colorLed : apagado),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 3,
                  width: encendida ? 28 : 0,
                  decoration: BoxDecoration(color: colorLed, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
