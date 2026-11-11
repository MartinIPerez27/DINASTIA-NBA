import 'package:flutter/material.dart';

import 'data/catalogo_jugadores.dart';
import 'data/franquicias.dart';
import 'domain/entities/jugador.dart';
import 'presentation/widgets/jugador_avatar.dart';

void main() => runApp(const DinastiaNbaApp());

class DinastiaNbaApp extends StatelessWidget {
  const DinastiaNbaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dinastía NBA (82-0)',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFCE1141), brightness: Brightness.dark),
    home: const _CatalogoFase1(),
  );
}

/// Pantalla provisoria de Fase 1: comprueba catálogo + fotos + fallback. La reemplaza la Fase 2.
class _CatalogoFase1 extends StatelessWidget {
  const _CatalogoFase1();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catálogo de cartas')),
    body: FutureBuilder<List<Jugador>>(
      future: cargarCatalogo(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error al cargar: ${snap.error}'));
        final jugadores = snap.data;
        if (jugadores == null) return const Center(child: CircularProgressIndicator());
        return GridView.extent(
          maxCrossAxisExtent: 220,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final j in jugadores)
              Column(
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
                    '${j.posiciones.first.etiqueta} · ${j.tier.etiqueta}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}
