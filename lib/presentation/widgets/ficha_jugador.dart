import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';
import 'carta_jugador.dart';
import 'escudo.dart';
import 'jugador_avatar.dart';
import 'texto_led.dart';

/// Ficha completa de la carta (GDD §8.1): las 11 estadísticas, rol, posiciones y dorsal.
Future<void> mostrarFichaJugador(BuildContext context, Jugador jugador) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => FichaJugador(jugador: jugador),
);

class FichaJugador extends StatelessWidget {
  const FichaJugador({super.key, required this.jugador});

  final Jugador jugador;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final franquicia = identidadDe(jugador);
    final s = jugador.stats;
    String pct(double v) => (v * 100).toStringAsFixed(1);
    // Datos que la NBA no registraba en esa época: estimados, con "~".
    String est(String campo, String valor) => jugador.estimadas.contains(campo) ? '~$valor' : valor;
    final sinTriple = jugador.epoca.index < Epoca.anios80.index; // la línea de tres llegó en 1979-80
    final datos = [
      ('PPP', 'Puntos por partido', s.ppp.toStringAsFixed(1)),
      ('RPP', 'Rebotes por partido', est('rpp', s.rpp.toStringAsFixed(1))),
      ('APP', 'Asistencias por partido', s.app.toStringAsFixed(1)),
      ('ROB/P', 'Robos por partido', est('robP', s.robP.toStringAsFixed(1))),
      ('TAP/P', 'Tapones por partido', est('tapP', s.tapP.toStringAsFixed(1))),
      ('PER/P', 'Pérdidas por partido', est('perP', s.perP.toStringAsFixed(1))),
      ('%TC', 'Porcentaje de tiros de campo', pct(s.pctTc)),
      ('%T3', 'Porcentaje de triples', sinTriple ? '—' : pct(s.pctT3)),
      ('%TL', 'Porcentaje de tiros libres', pct(s.pctTl)),
      ('MIN/P', 'Minutos por partido', est('minP', s.minP.toStringAsFixed(1))),
      ('IQ', 'Inteligencia de juego (1 a 99)', '${s.iq}'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: esquema.surfaceContainerLowest,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Center(
                  child: JugadorAvatar(jugador: jugador, franquicia: franquicia),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(jugador.nombre.toUpperCase(), style: tema.textTheme.displayLarge?.copyWith(fontSize: 40)),
              ),
              const SizedBox(width: 12),
              TextoLed(CartaJugador.codigoTier(jugador.tier), tamano: 32),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Escudo(franquicia, tamano: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${franquicia.nombreCompleto} · ${jugador.epoca.etiqueta} · '
                  '${jugador.tier.etiqueta} (${jugador.tier.descripcion})',
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(jugador.rol.etiqueta.toUpperCase(), style: tema.textTheme.headlineSmall),
          Text(
            jugador.rol.apodo,
            style: tema.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final p in jugador.posiciones) Chip(label: Text(p.etiqueta))],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final columnas = c.maxWidth > 420 ? 4 : 3;
              final ancho = (c.maxWidth - (columnas - 1) * 8) / columnas;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (sigla, nombre, valor) in datos)
                    Semantics(
                      label: '$nombre: $valor',
                      child: ExcludeSemantics(
                        child: Container(
                          width: ancho,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: esquema.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                child: TextoLed(
                                  valor,
                                  tamano: 26,
                                  color: sigla == 'IQ' ? esquema.primary : esquema.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sigla,
                                style: tema.textTheme.labelMedium?.copyWith(
                                  fontFamily: Fuentes.estadio,
                                  fontVariations: const [FontVariation.weight(700)],
                                  letterSpacing: 1,
                                  color: esquema.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (jugador.estimadas.isNotEmpty || sinTriple) ...[
            const SizedBox(height: 12),
            Text(
              [
                if (jugador.estimadas.isNotEmpty) '~ Estimado: la NBA no registraba ese dato en esa época.',
                if (sinTriple) '— Todavía no existía la línea de tres puntos.',
              ].join('\n'),
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
