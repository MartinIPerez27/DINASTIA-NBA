import 'package:flutter/material.dart';

import '../../domain/modos/carrera_jugador.dart';

/// Secundario → universidad → NBA: elegís cuántos años de universidad jugar y ves tu camino año por año.
/// Devuelve el [CaminoPrevio] elegido (el jugador ya listo para el draft).
class EtapasPreviasPantalla extends StatefulWidget {
  const EtapasPreviasPantalla({super.key, required this.creado, required this.semilla});

  final JugadorCreado creado;
  final int semilla;

  @override
  State<EtapasPreviasPantalla> createState() => _EtapasPreviasPantallaState();
}

class _EtapasPreviasPantallaState extends State<EtapasPreviasPantalla> {
  var _anios = 1;

  CaminoPrevio get _camino => EtapasPrevias.simular(widget.creado, widget.semilla, aniosUniversidad: _anios);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final camino = _camino;
    return Scaffold(
      appBar: AppBar(title: Text('El camino de ${widget.creado.nombre}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Después del secundario, ¿cuántos años jugás en la universidad?', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Cada año te pule los puntos fuertes (+1), pero llegás más grande al draft y con menos años de carrera. Saltar directo te da más años en la NBA.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var a = 0; a <= EtapasPrevias.maxUniversidad; a++)
                  ChoiceChip(
                    label: Text(a == 0 ? 'Directo al draft' : '$a ${a == 1 ? 'año' : 'años'}'),
                    selected: _anios == a,
                    onSelected: (_) => setState(() => _anios = a),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final t in camino.temporadas)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${t.etapa} ${t.anio} · ${t.edad} años · MED ${t.media}', style: tema.textTheme.titleSmall),
                      Text(
                        '${t.pts.toStringAsFixed(1).replaceAll('.', ',')} pts · ${t.reb.toStringAsFixed(1).replaceAll('.', ',')} reb · ${t.ast.toStringAsFixed(1).replaceAll('.', ',')} ast',
                        style: tema.textTheme.bodyMedium,
                      ),
                      for (final h in t.hitos) Text('• $h', style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Llegás al draft con ${camino.creado.edadInicial} años, media ${camino.creado.media} y proyección de pick n.º ${camino.pick}.',
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.of(context).pop(camino), child: const Text('IR AL COMBINE Y AL DRAFT')),
          ],
        ),
      ),
    );
  }
}
