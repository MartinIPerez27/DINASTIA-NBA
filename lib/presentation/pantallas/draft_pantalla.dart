import 'package:flutter/material.dart';

import '../../data/catalogo_jugadores.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/temporada.dart';
import '../widgets/jugador_avatar.dart';

/// Provisoria hasta la Fase 3 (cancha con siluetas y tragamonedas): muestra el catálogo de cartas.
class DraftPantalla extends StatelessWidget {
  const DraftPantalla({super.key, required this.temporada});

  final Temporada temporada;

  @override
  Widget build(BuildContext context) {
    final franquicia = franquiciaPorId(temporada.franquiciaUsuarioId);
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Draft de los ${franquicia.nombre}')),
      body: FutureBuilder<List<Jugador>>(
        future: cargarCatalogo(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('No se pudo cargar el catálogo: ${snap.error}'));
          final jugadores = snap.data;
          if (jugadores == null) return const Center(child: CircularProgressIndicator());
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'La cancha con siluetas y el tragamonedas llegan en la Fase 3. '
                    'Mientras tanto, estas son las cartas disponibles.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.extent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    for (final j in jugadores)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: JugadorAvatar(jugador: j, franquicia: franquiciaPorId(j.franquiciaId)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(j.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            '${j.posiciones.first.etiqueta} · ${j.epoca.etiqueta} · ${j.tier.etiqueta}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
