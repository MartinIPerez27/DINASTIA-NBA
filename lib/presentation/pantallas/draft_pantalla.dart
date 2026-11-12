import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/catalogo_jugadores.dart';
import '../../data/franquicias.dart';
import '../../domain/draft.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/oferta.dart';
import '../../domain/entities/plantel.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/entities/tirada.dart';
import '../draft/cancha.dart';
import '../draft/revelado_cartas.dart';
import '../draft/tragamonedas_panel.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/carta_vertical.dart';

/// Draft 82-0 (GDD §4). Modo ruleta: tirar los carretes, elegir una de las cartas que salieron y
/// tocar su puesto. Modo cartas: tocar un puesto, se revelan 5 cartas y se ficha una.
/// Cada cambio se informa con [onCambio] para guardarlo al instante.
class DraftPantalla extends StatefulWidget {
  const DraftPantalla({
    super.key,
    required this.temporada,
    required this.onCambio,
    this.onCompleto,
    this.catalogo,
    this.azar,
  });

  final Temporada temporada;
  final ValueChanged<Temporada> onCambio;

  /// Con el plantel completo, el botón principal pasa a las tácticas.
  final VoidCallback? onCompleto;

  /// Solo para tests; en la app se carga el catálogo empaquetado.
  final List<Jugador>? catalogo;
  final Random? azar;

  @override
  State<DraftPantalla> createState() => _DraftPantallaState();
}

class _DraftPantallaState extends State<DraftPantalla> {
  late Temporada _t = widget.temporada;
  Draft? _draft;
  Object? _errorCatalogo;
  int _vuelta = 0;
  bool _girando = false;
  Set<Carrete> _retenidos = {};
  Jugador? _elegida;
  Posicion? _ubicada;
  Timer? _finGiro;
  final _clavesPuestos = {for (final p in Posicion.values) p: GlobalKey()};

  /// Mientras una carta vuela a la cancha, se muestra el plantel de antes (el puesto sigue vacío).
  Plantel? _plantelAntes;

  bool get _modoCartas => _t.modo == ModoDraft.cartas;

  @override
  void initState() {
    super.initState();
    final catalogo = widget.catalogo;
    if (catalogo != null) {
      _draft = Draft(catalogo, azar: widget.azar);
    } else {
      cargarCatalogo().then(
        (c) => mounted ? setState(() => _draft = Draft(c, azar: widget.azar)) : null,
        onError: (Object e) => mounted ? setState(() => _errorCatalogo = e) : null,
      );
    }
  }

  @override
  void dispose() {
    _finGiro?.cancel();
    super.dispose();
  }

  void _guardar(Temporada nueva) {
    _t = nueva;
    widget.onCambio(nueva);
  }

  void _tirar() {
    final Temporada nueva;
    try {
      nueva = _draft!.tirar(_t, retenidos: _retenidos);
    } on Error catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    final animar = !MediaQuery.disableAnimationsOf(context);
    HapticFeedback.lightImpact();
    setState(() {
      _guardar(nueva);
      _vuelta++;
      _girando = animar;
      _elegida = null;
      _ubicada = null;
      if (!animar) _retenidos = {};
    });
    if (animar) {
      _finGiro?.cancel();
      _finGiro = Timer(
        TragamonedasPanel.duracionGiro + const Duration(milliseconds: 150),
        () => setState(() {
          _girando = false;
          _retenidos = {};
        }),
      );
    }
  }

  void _retener(Carrete c) => setState(() {
    if (!_retenidos.remove(c) && _retenidos.length < Draft.maxRetenidos) _retenidos.add(c);
  });

  void _tocarPuesto(Posicion p) {
    if (_modoCartas) {
      if (_t.oferta != null || _plantelAntes != null || !_draft!.puedeRepartir(_t, p)) return;
      HapticFeedback.lightImpact();
      setState(() {
        _guardar(_draft!.repartir(_t, p));
        _ubicada = null;
      });
      return;
    }
    final elegida = _elegida;
    if (elegida == null || !_t.plantel.posicionesDisponiblesPara(elegida).contains(p)) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _guardar(_draft!.elegir(_t, elegida, p));
      _elegida = null;
      _ubicada = p;
    });
  }

  void _volverARepartir() => setState(() => _guardar(_draft!.volverARepartir(_t)));

  /// Se guarda al instante; la carta vuela desde la escena del reparto hasta su puesto.
  void _fichar(Jugador carta, Rect origen) {
    final posicion = _t.oferta!.posicion;
    final antes = _t.plantel;
    final caja = _clavesPuestos[posicion]!.currentContext?.findRenderObject() as RenderBox?;
    setState(() => _guardar(_draft!.fichar(_t, carta)));
    if (MediaQuery.disableAnimationsOf(context) || caja == null) {
      HapticFeedback.heavyImpact();
      setState(() => _ubicada = posicion);
      return;
    }
    setState(() => _plantelAntes = antes);
    late final OverlayEntry vuelo;
    vuelo = OverlayEntry(
      builder: (_) => _CartaEnVuelo(
        jugador: carta,
        origen: origen,
        destino: caja.localToGlobal(Offset.zero) & caja.size,
        onFin: () {
          vuelo.remove();
          HapticFeedback.heavyImpact();
          if (mounted) {
            setState(() {
              _plantelAntes = null;
              _ubicada = posicion;
            });
          }
        },
      ),
    );
    Overlay.of(context).insert(vuelo);
  }

  @override
  Widget build(BuildContext context) {
    final franquicia = franquiciaPorId(_t.franquiciaUsuarioId);
    final draft = _draft;
    final elegida = _elegida;

    return Scaffold(
      appBar: AppBar(
        title: Text('Draft de los ${franquicia.nombre}'),
        actions: [_Fichas(_t.rerollsRestantes), const SizedBox(width: 16)],
      ),
      body: SafeArea(
        top: false,
        child: switch ((draft, _errorCatalogo)) {
          (_, final Object e) => Center(child: Text('No se pudo cargar el catálogo: $e')),
          (null, _) => const Center(child: CircularProgressIndicator()),
          (final Draft draft, _) => Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: Cancha(
                          franquicia: franquicia,
                          plantel: _plantelAntes ?? _t.plantel,
                          resaltadas: _modoCartas
                              ? (_t.oferta == null && _plantelAntes == null
                                    ? {
                                        for (final p in Posicion.values)
                                          if (!_t.plantel.estaOcupada(p)) p,
                                      }
                                    : const {})
                              : elegida == null
                              ? const {}
                              : _t.plantel.posicionesDisponiblesPara(elegida).toSet(),
                          onTocar: _tocarPuesto,
                          recienUbicada: _ubicada,
                          clavesPuestos: _clavesPuestos,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_t.plantel.completo && !_modoCartas) ...[
                      TragamonedasPanel(
                        identidad: draft.identidadDeTirada,
                        tirada: _t.tirada,
                        vuelta: _vuelta,
                        retenidos: _retenidos,
                        puedeRetener:
                            !_girando &&
                            _t.tirada != null &&
                            _t.rerollsRestantes > 0 &&
                            _retenidos.length < Draft.maxRetenidos,
                        onRetener: _retener,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _zonaInferior(draft),
                  ],
                ),
              ),
              if (_modoCartas && _t.oferta != null)
                Positioned.fill(
                  child: ReveladoCartas(
                    posicion: _t.oferta!.posicion,
                    cartas: draft.cartasDeOferta(_t),
                    rerollsRestantes: _t.rerollsRestantes,
                    onFichar: _fichar,
                    onVolverARepartir: _volverARepartir,
                  ),
                ),
            ],
          ),
        },
      ),
    );
  }

  Widget _zonaInferior(Draft draft) {
    final tema = Theme.of(context);
    final ayuda = tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant);

    if (_t.plantel.completo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¡Plantel completo! Mantené apretada una carta para ver su ficha.',
            style: ayuda,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: widget.onCompleto, child: const Text('ELEGIR TÁCTICAS')),
        ],
      );
    }

    if (_modoCartas) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            _t.oferta == null ? 'Tocá un puesto marcado en la cancha: se revelan 5 cartas y fichás una.' : '',
            style: ayuda,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_t.tirada == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: CartaJugador.alto,
            child: Center(
              child: Text(
                'Tirá los carretes: salen estrellas de una franquicia, una época y una rareza.',
                style: ayuda,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _tirar, child: const Text('TIRAR')),
        ],
      );
    }

    final candidatos = _girando ? const <Jugador>[] : draft.candidatos(_t);
    final puedeVolver = !_girando && draft.puedeVolverATirar(_t, _retenidos);
    final String texto;
    if (_girando) {
      texto = ' ';
    } else if (_retenidos.isNotEmpty && !puedeVolver && _t.rerollsRestantes > 0) {
      texto = 'No quedan cartas con esos carretes retenidos.';
    } else if (_elegida != null) {
      texto = 'Tocá un puesto marcado en la cancha.';
    } else {
      texto = 'Elegí una carta y tocá su puesto en la cancha.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: CartaJugador.alto,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: candidatos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => CartaJugador(
              jugador: candidatos[i],
              seleccionada: candidatos[i] == _elegida,
              onTap: () => setState(() => _elegida = candidatos[i] == _elegida ? null : candidatos[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(texto, style: ayuda, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: puedeVolver ? _tirar : null,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(_t.rerollsRestantes == 0 ? 'SIN FICHAS DE REROLL' : 'VOLVER A TIRAR · 1 FICHA'),
        ),
      ],
    );
  }
}

/// Fichas de Reroll como LED: encendidas las que quedan.
class _Fichas extends StatelessWidget {
  const _Fichas(this.restantes);

  final int restantes;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Fichas de Reroll: $restantes de ${Temporada.rerollsPorTemporada}',
      child: Row(
        children: [
          for (var i = 0; i < Temporada.rerollsPorTemporada; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < restantes ? esquema.primary : null,
                border: Border.all(color: i < restantes ? esquema.primary : esquema.onSurfaceVariant, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// La carta elegida vuela desde el reparto hasta su puesto en la cancha.
class _CartaEnVuelo extends StatefulWidget {
  const _CartaEnVuelo({required this.jugador, required this.origen, required this.destino, required this.onFin});

  final Jugador jugador;
  final Rect origen;
  final Rect destino;
  final VoidCallback onFin;

  @override
  State<_CartaEnVuelo> createState() => _CartaEnVueloState();
}

class _CartaEnVueloState extends State<_CartaEnVuelo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFin();
    })
    ..forward();
  late final _curva = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curva,
    builder: (context, _) {
      final rect = Rect.lerp(widget.origen, widget.destino, _curva.value)!;
      return Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: FittedBox(
            child: SizedBox(
              width: widget.origen.width,
              child: CartaVertical(jugador: widget.jugador, seleccionada: true),
            ),
          ),
        ),
      );
    },
  );
}
