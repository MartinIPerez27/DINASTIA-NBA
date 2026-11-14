import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/modos/evoluciones.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';

/// Pestaña "Evoluciones" del Álbum: objetivos para subir la media de tus cartas (solo en los modos
/// que usan el álbum).
class EvolucionesVista extends StatelessWidget {
  const EvolucionesVista({super.key, required this.catalogo, required this.perfil, required this.onPerfil});

  final List<Jugador> catalogo;
  final PerfilEntrenador perfil;
  final ValueChanged<PerfilEntrenador> onPerfil;

  Jugador? _carta(String id) => catalogo.where((j) => j.id == id).firstOrNull;

  Future<void> _nueva(BuildContext context) async {
    final evo = PerfilEvoluciones.de(perfil);
    final elegidas = await showModalBottomSheet<Jugador>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ElegirCarta(
        cartas: [
          for (final j in catalogo)
            if (perfil.coleccion.contains(j.id) && !evo.cartas.containsKey(j.id)) j,
        ]..sort((a, b) => b.media.compareTo(a.media)),
      ),
    );
    if (elegidas == null || !context.mounted) return;
    final objetivo = await showModalBottomSheet<ObjetivoEvo>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _ElegirObjetivo(carta: elegidas),
    );
    if (objetivo == null) return;
    Haptica.media();
    onPerfil(evo.empezar(elegidas.id, objetivo.id).guardarEn(perfil));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final evo = PerfilEvoluciones.de(perfil);
    final entradas = evo.cartas.entries.toList()
      ..sort((a, b) => (a.value.completa ? 1 : 0).compareTo(b.value.completa ? 1 : 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Cumplí objetivos con una carta de tu álbum y sube de media (+1 por etapa, hasta +${Evoluciones.maxNivel}). '
          'Solo vale en los modos que usan tu álbum: Desafíos de armado, Divisiones, Creador de torneos, '
          'Conquista, Fantasy y el draft con "Mi colección". En el resto, la carta es la del catálogo.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: evo.activas >= Evoluciones.maxActivas || perfil.coleccion.isEmpty ? null : () => _nueva(context),
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            evo.activas >= Evoluciones.maxActivas
                ? 'YA TENÉS ${Evoluciones.maxActivas} EN CURSO'
                : perfil.coleccion.isEmpty
                ? 'TODAVÍA NO TENÉS CARTAS'
                : 'NUEVA EVOLUCIÓN (${evo.activas}/${Evoluciones.maxActivas})',
          ),
        ),
        const SizedBox(height: 12),
        if (entradas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Elegí una carta y un objetivo. Se avanza jugando con ella en cualquier modo.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium,
            ),
          ),
        for (final e in entradas)
          if (_carta(e.key) case final j?)
            _FilaEvolucion(
              carta: j,
              evo: e.value,
              onCobrar: () {
                final (nuevo, n) = evo.cobrar(e.key);
                if (n == 0) return;
                Haptica.media();
                onPerfil(nuevo.guardarEn(perfil));
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(content: Text('${j.nombre}: +$n de media en los modos del álbum.')));
              },
            ),
      ],
    );
  }
}

class _FilaEvolucion extends StatelessWidget {
  const _FilaEvolucion({required this.carta, required this.evo, required this.onCobrar});

  final Jugador carta;
  final EvoCarta evo;
  final VoidCallback onCobrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final objetivo = evo.objetivo;
    final meta = evo.proximaMeta;
    final previa = evo.etapa == 0 ? 0 : objetivo!.metas[evo.etapa - 1];
    final avance = meta == null ? 1.0 : ((evo.progreso - previa) / (meta - previa)).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: esquema.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: evo.listaParaCobrar ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextoLed('${(carta.media + evo.etapa).clamp(0, 99)}', tamano: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carta.nombre,
                        style: tema.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${carta.tramoConEquipo} · base ${carta.media}',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (evo.etapa > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: esquema.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'EVO +${evo.etapa}',
                      style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var k = 0; k < Evoluciones.maxNivel; k++)
                  Container(
                    width: 22,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: k < evo.etapa ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const Spacer(),
                Text(objetivo?.nombre ?? '', style: tema.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (evo.completa)
              Text('Evolución completa.', style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary))
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: avance, minHeight: 6),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${evo.progreso < meta! ? evo.progreso : meta} / $meta ${objetivo?.metrica.unidad ?? ''}',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                  FilledButton(
                    onPressed: evo.listaParaCobrar ? onCobrar : null,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                    child: const Text('COBRAR +1'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ElegirCarta extends StatefulWidget {
  const _ElegirCarta({required this.cartas});
  final List<Jugador> cartas;

  @override
  State<_ElegirCarta> createState() => _ElegirCartaState();
}

class _ElegirCartaState extends State<_ElegirCarta> {
  var _busca = '';

  @override
  Widget build(BuildContext context) {
    final filtradas = [
      for (final j in widget.cartas)
        if (j.nombre.toLowerCase().contains(_busca.toLowerCase())) j,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar en tu álbum'),
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtradas.length,
              itemBuilder: (context, i) {
                final j = filtradas[i];
                return ListTile(
                  leading: TextoLed('${j.media}', tamano: 22),
                  title: Text(j.nombre),
                  subtitle: Text('${j.tramoConEquipo} · ${j.tier.codigo}'),
                  onTap: () => Navigator.pop(context, j),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ElegirObjetivo extends StatelessWidget {
  const _ElegirObjetivo({required this.carta});
  final Jugador carta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿QUÉ LE PEDÍS A ${carta.nombre.toUpperCase()}?', style: tema.textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final o in Evoluciones.objetivos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.nombre),
              subtitle: Text('Etapas: ${o.metas.join(' · ')} ${o.metrica.unidad}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, o),
            ),
        ],
      ),
    );
  }
}

/// Para quien necesite el nivel de una carta sin importar el perfil global (p. ej. pruebas).
int nivelEvoDe(String cartaId) => nivelEvo(perfilApp.value, cartaId);
