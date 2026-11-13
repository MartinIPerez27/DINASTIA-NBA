import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/posicion.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/disposicion.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/escudo.dart';
import '../widgets/ficha_jugador.dart';
import '../widgets/haptica.dart';

/// Escena del modo cartas: 5 cartas entran boca abajo, las raras cargan sus LED y se dan vuelta
/// de a una. Se toca una para elegirla y "FICHAR" la confirma. Mantener apretada abre su ficha.
/// La [sorpresaId] queda boca abajo hasta que la tocás; con [ciega] ninguna se da vuelta.
/// Si hubo [robadas] (draft en serpiente), primero se muestra qué se llevaron los rivales.
class ReveladoCartas extends StatefulWidget {
  const ReveladoCartas({
    super.key,
    required this.posicion,
    required this.cartas,
    required this.rerollsRestantes,
    required this.onFichar,
    required this.onVolverARepartir,
    this.sorpresaId,
    this.ciega = false,
    this.robadas = const [],
  });

  /// Carta que viene boca abajo hasta tocarla.
  final String? sorpresaId;

  /// Draft a ciegas: todas boca abajo, se elige sin verlas.
  final bool ciega;

  /// Cartas que los rivales eligieron antes que vos, con la franquicia que se las llevó.
  final List<(Jugador, Franquicia)> robadas;

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
  late bool _viendoRobos = widget.robadas.isNotEmpty;
  Timer? _finRobos;

  bool get _todasReveladas => _reveladas.length == widget.cartas.length;

  @override
  void initState() {
    super.initState();
    if (_viendoRobos) _finRobos = Timer(const Duration(milliseconds: 2800), _seguir);
  }

  @override
  void dispose() {
    _finRobos?.cancel();
    super.dispose();
  }

  void _seguir() {
    _finRobos?.cancel();
    if (mounted && _viendoRobos) setState(() => _viendoRobos = false);
  }

  @override
  void didUpdateWidget(ReveladoCartas anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.cartas.map((j) => j.id).join() != widget.cartas.map((j) => j.id).join()) {
      _reveladas.clear();
      _elegida = null;
      _viendoRobos = widget.robadas.isNotEmpty;
      if (_viendoRobos) _finRobos = Timer(const Duration(milliseconds: 2800), _seguir);
    }
  }

  void _fichar() {
    final elegida = _elegida;
    final caja = _claves[elegida?.id]?.currentContext?.findRenderObject() as RenderBox?;
    if (elegida == null || caja == null) return;
    widget.onFichar(elegida, caja.localToGlobal(Offset.zero) & caja.size);
  }

  /// Draft en serpiente: lo que se llevaron los rivales antes de que elijas.
  Widget _robos(BuildContext context) {
    final tema = Theme.of(context);
    return ColoredBox(
      color: tema.colorScheme.surfaceContainerLowest.withValues(alpha: 0.97),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'TE GANARON DE MANO',
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                'En esta ronda los rivales eligen antes que vos.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (j, f) in widget.robadas)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 130,
                        child: Column(
                          children: [
                            CartaVertical(jugador: j),
                            const SizedBox(height: 10),
                            Escudo(f, tamano: 36),
                            const SizedBox(height: 4),
                            Text(
                              'Se la llevaron los ${f.nombre}',
                              textAlign: TextAlign.center,
                              style: tema.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _seguir,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('VER LO QUE QUEDA'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_viendoRobos) return _robos(context);
    final tema = Theme.of(context);
    final elegida = _elegida;
    final apellido = elegida?.nombre.split(' ').skip(1).join(' ');

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.985),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: LayoutBuilder(
            builder: (context, c) {
              const separacion = 10.0;
              final porAncho = (c.maxWidth - 2 * separacion) / 3;
              final porAlto = ((c.maxHeight - 190) / 2 - separacion) * proporcionCarta;
              final ancho = min(min(porAncho, porAlto), esTabletApaisada(context) ? 200.0 : 150.0);
              return Column(
                children: [
                  Text(
                    '${widget.posicion.etiqueta}: ELEGÍ 1 DE ${widget.cartas.length}',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    !_todasReveladas
                        ? ' '
                        : widget.ciega
                        ? 'A ciegas: elegí sin ver. Se revela cuando la fichás.'
                        : widget.robadas.isNotEmpty
                        ? 'Los rivales ya eligieron ${widget.robadas.length}. Tocá una de las que quedan.'
                        : 'Tocá una carta. La sorpresa se da vuelta al tocarla.',
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
                            oculta: widget.ciega || j.id == widget.sorpresaId,
                            destapable: !widget.ciega,
                            onRevelada: () => setState(() => _reveladas.add(j.id)),
                            onTap: _todasReveladas
                                ? () {
                                    Haptica.seleccion();
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
                    child: Text(
                      elegida == null
                          ? 'ELEGÍ UNA CARTA'
                          : widget.ciega
                          ? 'FICHAR A CIEGAS'
                          : 'FICHAR A ${apellido!.toUpperCase()}',
                    ),
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
    this.oculta = false,
    this.destapable = true,
  });

  final Jugador jugador;
  final int orden;
  final bool elegida;
  final bool atenuada;
  final VoidCallback onRevelada;
  final VoidCallback? onTap;

  /// Queda boca abajo después de entrar (sorpresa o a ciegas).
  final bool oculta;

  /// Si está oculta, ¿se puede dar vuelta tocándola? (la sorpresa sí; a ciegas no).
  final bool destapable;

  @override
  State<_CartaRevelable> createState() => _CartaRevelableState();
}

class _CartaRevelableState extends State<_CartaRevelable> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _entrada, _carga, _giro, _destello;
  bool _avisada = false;

  /// Avance (0–1) en el que una carta oculta se queda esperando, ya adentro y boca abajo.
  late final double _espera;
  bool _destapada = false;

  // Tiempos (ms) de la coreografía de esta carta.
  static const _entradaMs = 280, _pausaMs = 250, _giroMs = 420, _destelloMs = 450, _entreCartasMs = 260;

  int get _cargaMs => switch (widget.jugador.tier) {
    Tier.sPlus => 650,
    Tier.s => 350,
    Tier.a || Tier.b => 0,
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
    _espera = (inicioEntrada + _entradaMs) / total;
    _c.addListener(_alGirar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sinAnimar = MediaQuery.disableAnimationsOf(context);
      if (widget.oculta) {
        // Entra y se queda boca abajo: cuenta como "lista" para poder elegir.
        sinAnimar ? _c.value = _espera : _c.animateTo(_espera);
        Future<void>.delayed(Duration(milliseconds: sinAnimar ? 0 : (_espera * total).round()), () {
          if (mounted) widget.onRevelada();
        });
      } else {
        sinAnimar ? _c.value = 1 : _c.forward();
      }
    });
  }

  void _destapar() {
    if (_destapada) return;
    setState(() => _destapada = true);
    Haptica.ligera();
    MediaQuery.disableAnimationsOf(context) ? _c.value = 1 : _c.forward();
  }

  void _alGirar() {
    if (_avisada || _giro.value < 0.5 || (widget.oculta && !_destapada)) return;
    _avisada = true;
    switch (widget.jugador.tier) {
      case Tier.sPlus:
        Haptica.fuerte();
      case Tier.s:
        Haptica.media();
      case Tier.a:
      case Tier.b:
        Haptica.seleccion();
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
    final led = colorLed(identidadDe(widget.jugador));
    return Semantics(
      button: widget.onTap != null,
      selected: widget.elegida,
      label: _avisada
          ? '${widget.jugador.nombre}, media ${widget.jugador.media}, ${widget.jugador.tier.etiqueta}'
          : widget.oculta && widget.destapable
          ? 'Carta sorpresa boca abajo: tocala para darla vuelta'
          : 'Carta boca abajo',
      onLongPressHint: 'ver ficha completa',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: widget.oculta && widget.destapable && !_destapada ? _destapar : widget.onTap,
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
                                            Tier.a || Tier.b => 0.0,
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : widget.oculta && widget.destapable && !_destapada
                      ? _DorsoSorpresa(tier: widget.jugador.tier)
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

/// Dorso de la carta sorpresa: el marco insinúa la rareza (sin decir quién es).
class _DorsoSorpresa extends StatelessWidget {
  const _DorsoSorpresa({required this.tier});

  final Tier tier;

  static Color colorRareza(Tier t) => switch (t) {
    Tier.sPlus => const Color(0xFFFFC94D),
    Tier.s => const Color(0xFFC9D2DC),
    Tier.a => const Color(0xFFC08457),
    Tier.b => const Color(0xFF6E7681),
  };

  @override
  Widget build(BuildContext context) {
    final color = colorRareza(tier);
    return Stack(
      children: [
        DorsoCarta(carga: 0.55, color: color),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color),
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              child: Text(
                'SORPRESA',
                style: TextStyle(
                  fontFamily: Fuentes.estadio,
                  fontVariations: const [FontVariation.weight(800)],
                  fontSize: 12,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
