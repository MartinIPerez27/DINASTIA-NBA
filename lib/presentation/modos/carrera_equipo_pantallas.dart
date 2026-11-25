import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../widgets/disposicion.dart';
import '../widgets/texto_led.dart';

/// "Mi equipo": tus compañeros (edad, media, contrato) y cómo fue cambiando el plantel año a año.
class MiEquipoPantalla extends StatelessWidget {
  const MiEquipoPantalla({super.key, required this.estado});

  final EstadoCarrera estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final anio = estado.anioCierre;
    final quien = franquiciaPorId(estado.franquiciaId).nombreCompleto;
    final plantel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(quien.toUpperCase(), style: tema.textTheme.titleMedium),
        Text(
          '${estado.etiquetaTemporada} · ${estado.companeros.length + 1} jugadores con vos',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final j in [...estado.companeros]..sort((a, b) => b.media.compareTo(a.media)))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 44, child: TextoLed('${j.media}', tamano: 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(j.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodyMedium),
                      Text(
                        '${j.posiciones.first.etiqueta} · ${PlantelCarrera.edadEn(j, anio)} años',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${PlantelCarrera.contratoDe(estado, j)} ${PlantelCarrera.contratoDe(estado, j) == 1 ? 'año' : 'años'}',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
    final movimientos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MOVIMIENTOS DEL PLANTEL', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        if (estado.movimientos.isEmpty)
          Text(
            'Todavía no hubo cambios. Cada receso se van los que terminan contrato o se retiran, y llegan caras nuevas.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        for (final m in estado.movimientos.reversed)
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(m, style: tema.textTheme.bodySmall)),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mi equipo')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 8, 24), children: [plantel])),
                  Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(8, 8, 16, 24), children: [movimientos])),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [plantel, const SizedBox(height: 16), movimientos],
              ),
      ),
    );
  }
}

/// "Mi generación": los mejores elegidos de tu draft y qué hacen este año contra vos.
class GeneracionPantalla extends StatelessWidget {
  const GeneracionPantalla({super.key, required this.estado, required this.catalogo});

  final EstadoCarrera estado;
  final List<Jugador> catalogo;

  static String _n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final clase = GeneracionCarrera.clase(catalogo, estado);
    final anio = estado.anioCierre;
    final yo = estado.historial.isEmpty ? null : estado.historial.last;
    final filas = [
      for (final c in clase) (c, GeneracionCarrera.lineaEn(c, anio, anioDraft: estado.anioBase)),
    ];
    final rival = clase.isEmpty ? null : clase.first;
    return Scaffold(
      appBar: AppBar(title: Text('Clase del draft ${estado.anioBase}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              clase.any((c) => c.ficticio)
                  ? 'Esta clase se inventa para tu carrera: sus carreras evolucionan sola, año a año.'
                  : 'Los primeros elegidos de tu draft, con sus números reales de cada época.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            if (rival != null) ...[
              const SizedBox(height: 8),
              Text('TU RIVAL DE GENERACIÓN: ${rival.nombre.toUpperCase()} (pick ${rival.pick})', style: tema.textTheme.labelLarge),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 40, child: Text('PICK')),
                const Expanded(child: Text('JUGADOR')),
                SizedBox(width: 120, child: Text('PTS · REB · AST', textAlign: TextAlign.end, style: tema.textTheme.labelSmall)),
              ],
            ),
            const Divider(),
            if (yo != null)
              _fila(
                tema,
                esquema,
                'TÚ',
                '${estado.nombre} (pick ${estado.pick})',
                '${_n(yo.pts)} · ${_n(yo.reb)} · ${_n(yo.ast)}',
                destacado: true,
              ),
            for (final (c, l) in filas)
              _fila(
                tema,
                esquema,
                '${c.pick}',
                c.nombre,
                l == null
                    ? 'todavía no juega'
                    : (l.retirado ? 'retirado' : '${_n(l.pts)} · ${_n(l.reb)} · ${_n(l.ast)}'),
              ),
            const SizedBox(height: 8),
            Text(
              'Los números de los demás son los del año de tu última temporada cerrada (${estado.etiquetaTemporada}).',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(ThemeData tema, ColorScheme esquema, String pick, String nombre, String linea, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(pick, style: tema.textTheme.bodyMedium?.copyWith(color: destacado ? esquema.primary : null))),
          Expanded(
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodyMedium?.copyWith(color: destacado ? esquema.primary : null),
            ),
          ),
          SizedBox(width: 120, child: Text(linea, textAlign: TextAlign.end, style: tema.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// La decisión de la fecha límite de traspasos.
Future<void> mostrarFechaLimite(BuildContext context, ValueChanged<OpcionFechaLimite> alElegir, {String? rumor}) {
  return showDialog<void>(
    context: context,
    builder: (d) => SimpleDialog(
      title: const Text('Fecha límite de traspasos'),
      children: [
        if (rumor != null)
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(rumor)),
        for (final o in OpcionFechaLimite.values)
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(d).pop();
              alElegir(o);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.etiqueta, style: Theme.of(d).textTheme.titleSmall),
                Text(o.descripcion, style: Theme.of(d).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    ),
  );
}
