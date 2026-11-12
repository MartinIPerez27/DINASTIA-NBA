import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/posicion.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/ficha_jugador.dart';

/// Escena del modo cartas: 5 cartas entran boca abajo, las raras cargan sus LED y se dan vuelta
/// de a una. Se toca una para elegirla y "FICHAR" la confirma. Mantener apretada abre su ficha.
class ReveladoCartas extends StatefulWidget {
  const ReveladoCartas({
    super.key,
    required this.posicion,
    required this.cartas,
    required this.rerollsRestantes,
    required this.onFichar,
    required this.onVolverARepartir,
  });

  final Posicion posicion;
  final List<Jugador> cartas;
  final int rerollsRestantes;

  /// Recibe la carta y el rectángulo (global) desde donde vuela a la cancha.
  final void Function(Jugador carta, Rect origen) onFichar;
  final VoidCallback? onVolverARepartir;

  @override
  State<ReveladoCartas> createState() => _ReveladoCartasState();
}

class _ReveladoCartasState extends State<ReveladoCartas> {
  final _claves = <String, GlobalKey>{};
  final _reveladas = <String>{};
  Jugador? _elegida;

  bool get _todasReveladas => _reveladas.length == widget.cartas.length;

  @override
  void didUpdateWidget(ReveladoCartas anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.cartas.map((j) => j.id).join() != widget.cartas.map((j) => j.id).join()) {
      _reveladas.clear();
      _elegida = null;
    }
  }

  void _fichar() {
    final elegida = _elegida;
    final caja = _claves[elegida?.id]?.currentContext?.findRenderObject() as RenderBox?;
    if (elegida == null || caja == null) return;
    widget.onFichar(elegida, caja.localToGlobal(Offset.zero) & caja.size);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final elegida = _elegida;
    final apellido = elegida?.nombre.split(' ').skip(1).join(' ');

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: LayoutBuilder(
            builder: (context, c) {
              const separacion = 10.0;
              final porAncho = (c.maxWidth - 2 * separacion) / 3;
              final porAlto = ((c.maxHeight - 190) / 2 - separacion) * proporcionCarta;
              final ancho = min(min(porAncho, porAlto), 150.0);
              return Column(
                children: [
                  Text(
                    '${widget.posicion.etiqueta}: ELEGÍ 1 DE ${widget.cartas.length}',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _todasReveladas ? 'Tocá una carta. Mantenela apretada para ver su ficha.' : ' ',
                    style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: separacion,
                    runSpacing: separacion,
                    children: [
                      for (final (i, j) in widget.cartas.indexed)
                        SizedBox(
                          key: _claves.putIfAbsent(j.id, GlobalKey.new),
                          width: ancho,
                          child: _CartaRevelable(
                            key: ValueKey(j.id),
                            jugador: j,
                            orden: i,
                            elegida: elegida == j,
                            atenuada: elegida != null && elegida != j,
                            onRevelada: () => setState(() => _reveladas.add(j.id)),
                            onTap: _todasReveladas
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _elegida = elegida == j ? null : j);
                                  }
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: elegida == null ? null : _fichar,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    child: Text(elegida == null ? 'ELEGÍ UNA CARTA' : 'FICHAR A ${apellido!.toUpperCase()}'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _todasReveladas && widget.rerollsRestantes > 0 ? widget.onVolverARepartir : null,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(widget.rerollsRestantes == 0 ? 'SIN FICHAS DE REROLL' : 'VOLVER A REPARTIR · 1 FICHA'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Una carta con su coreografía: entra (stagger), carga si es rara, se da vuelta y avisa.
class _CartaRevelable extends StatefulWidget {
  const _CartaRevelable({
    super.key,
    required this.jugador,
    required this.orden,
    required this.elegida,
    required this.atenuada,
    required this.onRevelada,
    this.onTap,
  });

  final Jugador jugador;
  final int orden;
  final bool elegida;
  final bool atenuada;
  final VoidCallback onRevelada;
  final VoidCallback? onTap;

  @override
  State<_CartaRevelable> createState() => _CartaRevelableState();
}

class _CartaRevelableState extends State<_CartaRevelable> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _entrada, _carga, _giro, _destello;
  bool _avisada = false;

  // Tiempos (ms) de la coreografía de esta carta.
  static const _entradaMs = 280, _pausaMs = 250, _giroMs = 420, _destelloMs = 450, _entreCartasMs = 260;

  int get _cargaMs => switch (widget.jugador.tier) {
    Tier.sPlus => 650,
    Tier.s => 350,
    Tier.a => 0,
  };

  @override
  void initState() {
    super.initState();
    final inicioEntrada = widget.orden * 70;
    final inicioCarga = inicioEntrada + _entradaMs + _pausaMs + widget.orden * _entreCartasMs;
    final inicioGiro = inicioCarga + _cargaMs;
    final total = inicioGiro + _giroMs + _destelloMs;
    Interval tramo(int desde, int dura, Curve curva) =>
        Interval(desde / total, min(1, (desde + max(dura, 1)) / total), curve: curva);

    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _entrada = CurvedAnimation(parent: _c, curve: tramo(inicioEntrada, _entradaMs, Curves.easeOutCubic));
    _carga = CurvedAnimation(parent: _c, curve: tramo(inicioCarga, _cargaMs, Curves.easeInCubic));
    _giro = CurvedAnimation(parent: _c, curve: tramo(inicioGiro, _giroMs, Curves.easeInOutCubic));
    _destello = CurvedAnimation(parent: _c, curve: tramo(inicioGiro + _giroMs, _destelloMs, Curves.easeOutCubic));
    _c.addListener(_alGirar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MediaQuery.disableAnimationsOf(context) ? _c.value = 1 : _c.forward();
    });
  }

  void _alGirar() {
    if (_avisada || _giro.value < 0.5) return;
    _avisada = true;
    switch (widget.jugador.tier) {
      case Tier.sPlus:
        HapticFeedback.heavyImpact();
      case Tier.s:
        HapticFeedback.mediumImpact();
      case Tier.a:
        HapticFeedback.selectionClick();
    }
    widget.onRevelada();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final led = colorLed(franquiciaPorId(widget.jugador.franquiciaId));
    return Semantics(
      button: widget.onTap != null,
      selected: widget.elegida,
      label: _avisada
          ? '${widget.jugador.nombre}, media ${widget.jugador.media}, ${widget.jugador.tier.etiqueta}'
          : 'Carta boca abajo',
      onLongPressHint: 'ver ficha completa',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: _avisada ? () => mostrarFichaJugador(context, widget.jugador) : null,
          child: AnimatedScale(
            scale: widget.elegida ? 1.06 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: widget.atenuada ? 0.45 : 1,
              duration: const Duration(milliseconds: 180),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final angulo = _giro.value * pi;
                  final frente = angulo > pi / 2;
                  final carta = frente
                      ? Stack(
                          children: [
                            CartaVertical(jugador: widget.jugador, seleccionada: widget.elegida),
                            // Destello de encendido al terminar de girar (más fuerte cuanto más rara).
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: led.withValues(
                                      alpha:
                                          (1 - _destello.value) *
                                          switch (widget.jugador.tier) {
                                            Tier.sPlus => 0.65,
                                            Tier.s => 0.4,
                                            Tier.a => 0.0,
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : DorsoCarta(carga: _carga.value, color: led);
                  return Opacity(
                    opacity: _entrada.value,
                    child: Transform.translate(
                      offset: Offset(0, 40 * (1 - _entrada.value)),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(frente ? angulo - pi : angulo),
                        child: carta,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
