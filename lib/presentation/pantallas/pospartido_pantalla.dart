import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import '../partido/repeticion.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/jugador_avatar.dart';
import '../widgets/texto_led.dart';

/// Pospartido: el jugador del partido, el box score de los dos equipos y las mejores jugadas
/// para volver a ver en cámara lenta.
class PospartidoPantalla extends StatelessWidget {
  const PospartidoPantalla({
    super.key,
    required this.motor,
    required this.usuarioLocal,
    required this.identidadLocal,
    required this.identidadVisitante,
    required this.franquiciaUsuario,
    required this.jugadores,
    required this.destacadas,
    required this.equipaciones,
    this.escudo,
  });

  final MotorPartido motor;
  final bool usuarioLocal;
  final Franquicia identidadLocal, identidadVisitante, franquiciaUsuario;
  final Map<String, Jugador> jugadores;
  final List<Destacada> destacadas;
  final Equipaciones equipaciones;
  final ui.Image? escudo;

  /// Valoración de un partido (estilo "game score"): premia lo que suma y castiga lo que resta.
  static double valoracion(LineaEstadistica l) =>
      l.pts +
      0.4 * l.tcI -
      0.7 * l.tcA -
      0.4 * (l.tlA - l.tlI) +
      0.7 * l.reb +
      0.7 * l.ast +
      l.rob +
      0.7 * l.tap -
      l.per -
      0.4 * l.fal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ganoLocal = motor.puntosLocal > motor.puntosVisitante;
    final ganador = ganoLocal ? motor.boxLocal : motor.boxVisitante;
    final figura = ganador.entries.reduce((a, b) => valoracion(a.value) >= valoracion(b.value) ? a : b);
    final jugadorFigura = jugadores[figura.key]!;
    final linea = figura.value;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Resumen del partido')),
        body: AnchoMaximo(
          ancho: 960,
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Escudo(identidadLocal, tamano: 44),
                    const SizedBox(width: 12),
                    TextoLed('${motor.puntosLocal}-${motor.puntosVisitante}', tamano: 40),
                    const SizedBox(width: 12),
                    Escudo(identidadVisitante, tamano: 44),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: esquema.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: esquema.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        height: 110,
                        child: JugadorAvatar(
                          jugador: jugadorFigura,
                          franquicia: ganoLocal ? identidadLocal : identidadVisitante,
                          recortar: true,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JUGADOR DEL PARTIDO',
                                style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary),
                              ),
                              Text(
                                jugadorFigura.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: Fuentes.estadio,
                                  fontVariations: [FontVariation.weight(800)],
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${linea.pts} PTS · ${linea.reb} REB · ${linea.ast} AST · ${linea.tcI}/${linea.tcA} TC',
                                style: tema.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (destacadas.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Las mejores jugadas', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  for (final (i, d) in destacadas.indexed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: esquema.surfaceContainerHighest,
                        child: TextoLed('${i + 1}', tamano: 18),
                      ),
                      title: Text(d.frase, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${d.cuarto > 4 ? 'Prórroga' : '${d.cuarto}.º cuarto'} · '
                        '${d.reloj ~/ 60}:${(d.reloj % 60).floor().toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.slow_motion_video),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          insetPadding: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Repeticion(
                                destacada: d,
                                franquicia: franquiciaUsuario,
                                equipaciones: equipaciones,
                                jugadores: jugadores,
                                usuarioLocal: usuarioLocal,
                                escudo: escudo,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                TabBar(
                  tabs: [
                    Tab(text: identidadLocal.nombre),
                    Tab(text: identidadVisitante.nombre),
                  ],
                ),
                SizedBox(
                  height: 360,
                  child: TabBarView(
                    children: [
                      _Box(box: motor.boxLocal, jugadores: jugadores),
                      _Box(box: motor.boxVisitante, jugadores: jugadores),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.box, required this.jugadores});

  final Map<String, LineaEstadistica> box;
  final Map<String, Jugador> jugadores;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final numeros = TextStyle(
      fontFamily: Fuentes.led,
      fontVariations: const [FontVariation.weight(800)],
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 14,
      color: tema.colorScheme.onSurface,
    );
    final filas = box.entries.toList()..sort((a, b) => b.value.pts.compareTo(a.value.pts));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        horizontalMargin: 0,
        headingTextStyle: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        columns: [
          const DataColumn(label: Text('JUGADOR')),
          for (final c in ['MIN', 'PTS', 'REB', 'AST', 'ROB', 'TAP', 'TC', 'T3', 'TL', 'F'])
            DataColumn(label: Text(c), numeric: true),
        ],
        rows: [
          for (final e in filas)
            DataRow(
              cells: [
                DataCell(Text(jugadores[e.key]?.nombre ?? '–')),
                for (final v in [
                  '${(e.value.seg / 60).round()}',
                  '${e.value.pts}',
                  '${e.value.reb}',
                  '${e.value.ast}',
                  '${e.value.rob}',
                  '${e.value.tap}',
                  '${e.value.tcI}/${e.value.tcA}',
                  '${e.value.t3I}/${e.value.t3A}',
                  '${e.value.tlI}/${e.value.tlA}',
                  '${e.value.fal}',
                ])
                  DataCell(Text(v, style: numeros)),
              ],
            ),
        ],
      ),
    );
  }
}
