import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/motor.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/jugador_avatar.dart';

enum _Alcance { equipo, liga }

enum _Tramo { regular, playoffs }

/// Una columna del STATS 82: sigla, cómo se calcula y cómo se muestra.
class _Columna {
  const _Columna(this.sigla, this.descripcion, this.valor, {this.decimales = 1, this.porcentaje = false});

  final String sigla, descripcion;
  final double? Function(Jugador j, LineaEstadistica l) valor;
  final int decimales;
  final bool porcentaje;

  String texto(Jugador j, LineaEstadistica l) {
    final v = valor(j, l);
    if (v == null) return '–';
    return porcentaje ? (100 * v).toStringAsFixed(1) : v.toStringAsFixed(decimales);
  }
}

double? _por(int v, LineaEstadistica l) => l.pj == 0 ? null : v / l.pj;
double? _pct(int i, int a) => a == 0 ? null : i / a;

final _columnas = <_Columna>[
  _Columna('PJ', 'Partidos jugados', (j, l) => l.pj.toDouble(), decimales: 0),
  _Columna('MIN/P', 'Minutos por partido', (j, l) => l.pj == 0 ? null : l.seg / 60 / l.pj),
  _Columna('PPP', 'Puntos por partido', (j, l) => _por(l.pts, l)),
  _Columna('RPP', 'Rebotes por partido', (j, l) => _por(l.reb, l)),
  _Columna('APP', 'Asistencias por partido', (j, l) => _por(l.ast, l)),
  _Columna('ROB/P', 'Robos por partido', (j, l) => _por(l.rob, l)),
  _Columna('TAP/P', 'Tapones por partido', (j, l) => _por(l.tap, l)),
  _Columna('PER/P', 'Pérdidas por partido', (j, l) => _por(l.per, l)),
  _Columna('%TC', 'Porcentaje de tiros de campo', (j, l) => _pct(l.tcI, l.tcA), porcentaje: true),
  _Columna('%T3', 'Porcentaje de triples', (j, l) => _pct(l.t3I, l.t3A), porcentaje: true),
  _Columna('%TL', 'Porcentaje de tiros libres', (j, l) => _pct(l.tlI, l.tlA), porcentaje: true),
  _Columna('IQ', 'Inteligencia de juego (1-99)', (j, l) => j.stats.iq.toDouble(), decimales: 0),
];

/// STATS 82 (GDD §8.2): box score de la temporada con cabeceras ordenables (tocá una para ordenar
/// de mayor a menor, otra vez para invertir) y el cuadro de honor con el MVP y el Máximo Anotador.
class Stats82Pantalla extends StatefulWidget {
  const Stats82Pantalla({super.key, required this.temporada, required this.liga});

  final Temporada temporada;
  final Liga liga;

  @override
  State<Stats82Pantalla> createState() => _Stats82PantallaState();
}

class _Stats82PantallaState extends State<Stats82Pantalla> {
  var _alcance = _Alcance.equipo;
  var _tramo = _Tramo.regular;
  var _orden = 2; // PPP
  var _ascendente = false;

  Temporada get _t => widget.temporada;

  Franquicia _identidad(String franquiciaId) =>
      franquiciaPorId(franquiciaId == _t.franquiciaUsuarioId ? franquiciaId : _t.rivales[franquiciaId]!.identidadId);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final equipos = widget.liga.equipos(_t);
    final lineas = _tramo == _Tramo.regular ? _t.lineas : _t.lineasPlayoffs;
    final propios = {for (final j in _t.plantel.jugadores) j.id};
    final filas = <(Jugador, LineaEstadistica, String)>[
      for (final id in _alcance == _Alcance.equipo ? propios : lineas.keys)
        if (widget.liga.jugador(id) case final j? when equipos[id] != null)
          (j, lineas[id] ?? LineaEstadistica(), equipos[id]!),
    ];
    if (_alcance == _Alcance.liga) filas.removeWhere((f) => f.$2.pj == 0);
    final columna = _columnas[_orden];
    filas.sort((a, b) {
      final va = columna.valor(a.$1, a.$2) ?? -1, vb = columna.valor(b.$1, b.$2) ?? -1;
      return _ascendente ? va.compareTo(vb) : vb.compareTo(va);
    });
    final mostradas = _alcance == _Alcance.liga ? filas.take(60).toList() : filas;
    final regularTerminada = _t.calendario.isNotEmpty && _t.calendario.every((p) => p.jugado);
    final (mvp, anotador) = widget.liga.premios(_t);
    final numeros = TextStyle(
      fontFamily: Fuentes.led,
      fontVariations: const [FontVariation.weight(800)],
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 15,
      color: esquema.onSurface,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('STATS 82')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (mvp != null || anotador != null)
              Row(
                children: [
                  if (mvp != null)
                    Expanded(
                      child: _Honor(
                        titulo: regularTerminada ? 'MVP de la Temporada' : 'Carrera al MVP',
                        jugador: widget.liga.jugador(mvp.jugadorId)!,
                        franquicia: _identidad(mvp.franquiciaId),
                        dato: () {
                          final l = _t.lineas[mvp.jugadorId]!;
                          return '${(l.pts / l.pj).toStringAsFixed(1)} PPP · ${(l.reb / l.pj).toStringAsFixed(1)} RPP · '
                              '${(l.ast / l.pj).toStringAsFixed(1)} APP';
                        }(),
                        propio: mvp.franquiciaId == _t.franquiciaUsuarioId,
                      ),
                    ),
                  if (mvp != null && anotador != null) const SizedBox(width: 10),
                  if (anotador != null)
                    Expanded(
                      child: _Honor(
                        titulo: 'Máximo Anotador',
                        jugador: widget.liga.jugador(anotador.jugadorId)!,
                        franquicia: _identidad(anotador.franquiciaId),
                        dato: '${anotador.valor.toStringAsFixed(1)} PPP',
                        propio: anotador.franquiciaId == _t.franquiciaUsuarioId,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SegmentedButton<_Alcance>(
                  segments: const [
                    ButtonSegment(value: _Alcance.equipo, label: Text('Mi equipo')),
                    ButtonSegment(value: _Alcance.liga, label: Text('Liga')),
                  ],
                  selected: {_alcance},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _alcance = s.first),
                ),
                if (_t.lineasPlayoffs.isNotEmpty)
                  SegmentedButton<_Tramo>(
                    segments: const [
                      ButtonSegment(value: _Tramo.regular, label: Text('Temporada')),
                      ButtonSegment(value: _Tramo.playoffs, label: Text('Playoffs')),
                    ],
                    selected: {_tramo},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _tramo = s.first),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tocá una sigla para ordenar; otra vez, para invertir.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            if (mostradas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Todavía no hay partidos jugados.', style: tema.textTheme.bodyMedium),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _orden + 1,
                  sortAscending: _ascendente,
                  columnSpacing: 18,
                  horizontalMargin: 0,
                  headingRowHeight: 44,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 52,
                  headingTextStyle: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant),
                  columns: [
                    const DataColumn(label: Text('JUGADOR')),
                    for (final (i, c) in _columnas.indexed)
                      DataColumn(
                        label: Text(c.sigla),
                        tooltip: c.descripcion,
                        numeric: true,
                        onSort: (_, _) => setState(() {
                          _ascendente = _orden == i ? !_ascendente : false;
                          _orden = i;
                        }),
                      ),
                  ],
                  rows: [
                    for (final (j, l, f) in mostradas)
                      DataRow(
                        color: f == _t.franquiciaUsuarioId && _alcance == _Alcance.liga
                            ? WidgetStatePropertyAll(esquema.primary.withValues(alpha: 0.08))
                            : null,
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Row(
                                children: [
                                  Escudo(_identidad(f), tamano: 20),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(j.nombre, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ),
                          for (final (i, c) in _columnas.indexed)
                            DataCell(
                              Text(
                                c.texto(j, l),
                                style: i == _orden ? numeros.copyWith(color: esquema.primary) : numeros,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cuadro de honor: foto, premio y el dato que lo justifica.
class _Honor extends StatelessWidget {
  const _Honor({
    required this.titulo,
    required this.jugador,
    required this.franquicia,
    required this.dato,
    required this.propio,
  });

  final String titulo, dato;
  final Jugador jugador;
  final Franquicia franquicia;
  final bool propio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: propio ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.6),
          width: propio ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: JugadorAvatar.proporcion,
            child: JugadorAvatar(jugador: jugador, franquicia: franquicia, recortar: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary)),
                const SizedBox(height: 2),
                Text(
                  jugador.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Fuentes.estadio,
                    fontVariations: [FontVariation.weight(800)],
                    fontSize: 20,
                  ),
                ),
                Row(
                  children: [
                    Escudo(franquicia, tamano: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dato,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
