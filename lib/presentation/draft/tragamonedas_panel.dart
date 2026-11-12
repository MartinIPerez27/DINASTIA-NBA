import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/tirada.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import '../widgets/haptica.dart';

/// Los 3 carretes en LED (GDD §4.2). Cada vez que cambia [vuelta], los carretes no retenidos
/// giran y frenan de a uno, con vibración en cada parada.
class TragamonedasPanel extends StatelessWidget {
  const TragamonedasPanel({
    super.key,
    required this.tirada,
    required this.vuelta,
    required this.retenidos,
    required this.puedeRetener,
    required this.onRetener,
    this.identidad = _identidadPropia,
  });

  final Tirada? tirada;

  /// Contador de tiradas: al cambiar, arranca el giro.
  final int vuelta;
  final Set<Carrete> retenidos;
  final bool puedeRetener;
  final ValueChanged<Carrete> onRetener;

  /// Id de la identidad que se muestra en el carrete de franquicia (Thunder + 90s → 'SEA').
  final String Function(Tirada) identidad;

  static String _identidadPropia(Tirada t) => t.franquiciaId;

  static const duracionGiro = Duration(milliseconds: 1100);
  static const _paradas = {
    Carrete.franquicia: Duration(milliseconds: 500),
    Carrete.epoca: Duration(milliseconds: 800),
    Carrete.rareza: duracionGiro,
  };

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final c in Carrete.values) ...[
        if (c != Carrete.franquicia) const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              _Carrete(
                carrete: c,
                identidad: identidad,
                tirada: tirada,
                vuelta: vuelta,
                girar: !retenidos.contains(c),
                parada: _paradas[c]!,
              ),
              const SizedBox(height: 4),
              FilterChip(
                label: const Text('RETENER'),
                selected: retenidos.contains(c),
                onSelected: puedeRetener || retenidos.contains(c) ? (_) => onRetener(c) : null,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                tooltip: 'Retener ${c.etiqueta.toLowerCase()} al volver a tirar',
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _Carrete extends StatefulWidget {
  const _Carrete({
    required this.carrete,
    required this.identidad,
    required this.tirada,
    required this.vuelta,
    required this.girar,
    required this.parada,
  });

  final Carrete carrete;
  final String Function(Tirada) identidad;
  final Tirada? tirada;
  final int vuelta;
  final bool girar;
  final Duration parada;

  @override
  State<_Carrete> createState() => _CarreteState();
}

class _CarreteState extends State<_Carrete> {
  final _azar = Random();
  Timer? _ciclo, _freno;
  Tirada? _visible;

  @override
  void initState() {
    super.initState();
    _visible = widget.tirada;
  }

  @override
  void didUpdateWidget(_Carrete anterior) {
    super.didUpdateWidget(anterior);
    if (widget.vuelta == anterior.vuelta) {
      if (_ciclo == null) _visible = widget.tirada;
      return;
    }
    if (!widget.girar || MediaQuery.disableAnimationsOf(context)) {
      _visible = widget.tirada;
      return;
    }
    _ciclo?.cancel();
    _freno?.cancel();
    _ciclo = Timer.periodic(const Duration(milliseconds: 70), (_) => setState(() => _visible = _alAzar()));
    _freno = Timer(widget.parada, () {
      _ciclo?.cancel();
      _ciclo = null;
      Haptica.media();
      setState(() => _visible = widget.tirada);
    });
  }

  Tirada _alAzar() => Tirada(
    franquiciaId: franquicias[_azar.nextInt(franquicias.length)].id,
    epoca: Epoca.values[_azar.nextInt(Epoca.values.length)],
    tier: Tier.values[_azar.nextInt(Tier.values.length)],
  );

  @override
  void dispose() {
    _ciclo?.cancel();
    _freno?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final t = _visible;
    final girando = _ciclo != null;
    final apagado = esquema.onSurfaceVariant;

    final (String valor, String detalle) = t == null
        ? ('--', widget.carrete.etiqueta)
        : switch (widget.carrete) {
            Carrete.franquicia => (widget.identidad(t), franquiciaPorId(widget.identidad(t)).nombre),
            Carrete.epoca => (t.epoca.codigo, t.epoca.etiqueta),
            Carrete.rareza => (t.tier.codigo, t.tier.descripcion),
          };

    return Semantics(
      liveRegion: true,
      label:
          '${widget.carrete.etiqueta}: ${girando
              ? 'girando'
              : t == null
              ? 'sin tirar'
              : detalle}',
      child: ExcludeSemantics(
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.carrete == Carrete.franquicia && t != null) ...[
                    Escudo(franquiciaPorId(widget.identidad(t)), tamano: 22),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: FittedBox(
                      child: TextoLed(valor, tamano: 26, color: t == null || girando ? apagado : esquema.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                girando ? ' ' : detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
