import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';
import 'escudo.dart';
import 'jugador_avatar.dart';
import 'texto_led.dart';

/// Carta compacta de jugador: foto, nombre, posición/época/equipo, Tier y PPP/RPP/APP en LED.
class CartaJugador extends StatelessWidget {
  const CartaJugador({super.key, required this.jugador, this.seleccionada = false, this.onTap});

  final Jugador jugador;
  final bool seleccionada;
  final VoidCallback? onTap;

  static const ancho = 236.0;
  static const alto = 104.0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final franquicia = franquiciaPorId(jugador.franquiciaId);
    final s = jugador.stats;

    return Semantics(
      button: onTap != null,
      selected: seleccionada,
      label:
          '${jugador.nombre}, ${jugador.posiciones.map((p) => p.etiqueta).join(' o ')}, '
          '${franquicia.nombre} ${jugador.epoca.etiqueta}, ${jugador.tier.etiqueta}, '
          '${s.ppp} puntos, ${s.rpp} rebotes, ${s.app} asistencias',
      child: ExcludeSemantics(
        child: Material(
          color: esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: seleccionada ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
              width: seleccionada ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: ancho,
              height: alto,
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: alto,
                    child: JugadorAvatar(jugador: jugador, franquicia: franquicia, recortar: true),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  jugador.nombre.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: Fuentes.estadio,
                                    fontVariations: [FontVariation.weight(700)],
                                    fontSize: 17,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TextoLed(_tier(jugador.tier), tamano: 16),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Escudo(franquicia, tamano: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${jugador.posiciones.first.etiqueta} · ${jugador.epoca.etiqueta}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              for (final (sigla, valor) in [('PPP', s.ppp), ('RPP', s.rpp), ('APP', s.app)])
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: _Dato(sigla, valor),
                                  ),
                                ),
                            ],
                          ),
                        ],
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

  static String _tier(Tier t) => switch (t) {
    Tier.a => 'A',
    Tier.s => 'S',
    Tier.sPlus => 'S+',
  };
}

class _Dato extends StatelessWidget {
  const _Dato(this.sigla, this.valor);

  final String sigla;
  final double valor;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextoLed(valor.toStringAsFixed(1), tamano: 15, color: esquema.onSurface),
        Text(sigla, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant)),
      ],
    );
  }
}
