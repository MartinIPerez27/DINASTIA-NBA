import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/partido.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/rival.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/motor.dart';
import '../widgets/escudo.dart';
import '../widgets/indicador_forma.dart';
import '../widgets/texto_led.dart';
import 'partido_pantalla.dart';
import 'playbook_pantalla.dart';
import 'stats82_pantalla.dart';

enum _Vista { resultados, posiciones, plantel }

/// Temporada regular de 82 partidos (GDD §7): récord, próximo partido (en vivo o simulado),
/// resultados, tabla Este/Oeste y estadísticas de tu plantel.
class TemporadaPantalla extends StatefulWidget {
  const TemporadaPantalla({
    super.key,
    required this.temporada,
    required this.liga,
    required this.onCambio,
    this.onPlayoffs,
  });

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  /// Con la temporada regular terminada, pasa al cuadro de playoffs.
  final VoidCallback? onPlayoffs;

  @override
  State<TemporadaPantalla> createState() => _TemporadaPantallaState();
}

class _TemporadaPantallaState extends State<TemporadaPantalla> {
  late Temporada _t = widget.temporada;
  var _vista = _Vista.resultados;
  var _conferencia = Conferencia.este;
  var _ocupado = false;

  /// Simulación en curso: (hechos, total), para la barra de progreso.
  (int, int)? _progreso;

  /// Resumen de lo último que simulaste, dentro de la pantalla (no como aviso flotante: esos se
  /// encolaban y aparecían después, en medio de otro partido).
  String? _resumen;

  Liga get _liga => widget.liga;

  @override
  void initState() {
    super.initState();
    _conferencia = franquiciaPorId(_t.franquiciaUsuarioId).conferencia!;
  }

  void _guardar(Temporada t) {
    setState(() => _t = t);
    widget.onCambio(t);
  }

  Franquicia _identidad(String franquiciaId) =>
      franquiciaPorId(franquiciaId == _t.franquiciaUsuarioId ? franquiciaId : _t.rivales[franquiciaId]!.identidadId);

  String _detalleRival(String franquiciaId) => _t.rivales[franquiciaId]!.tipo.descripcion;

  /// "Detroit Pistons (90’)" para un plantel de época, "Boston Celtics (Histórico)" para el all-time.
  String _nombre(String franquiciaId) {
    final nombre = _identidad(franquiciaId).nombreCompleto;
    final r = _t.rivales[franquiciaId];
    if (r == null) return nombre;
    return '$nombre (${r.tipo == TipoRival.epoca ? r.epoca!.corta : 'Histórico'})';
  }

  void _abrirPlaybook() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (c) => PlaybookPantalla(
        temporada: _t,
        onConfirmar: (t) {
          _guardar(t);
          Navigator.of(c).pop();
        },
      ),
    ),
  );

  Future<void> _jugarEnVivo(Partido p) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _resumen = null);
    final antes = _liga.simularOtrosHasta(_t, p.jornada);
    _guardar(antes);
    final motor = _liga.motor(antes, p);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: motor,
          usuarioLocal: p.localId == _t.franquiciaUsuarioId,
          franquiciaUsuario: franquiciaPorId(_t.franquiciaUsuarioId),
          identidadLocal: _identidad(p.localId),
          identidadVisitante: _identidad(p.visitanteId),
          onTerminado: (MotorPartido m) => _guardar(_liga.registrar(antes, p, m)),
        ),
      ),
    );
  }

  /// Simula el resto de la temporada regular (pide confirmación: no se puede volver atrás).
  Future<void> _simularTodo() async {
    final faltan = _t.calendario.where((p) => !p.jugado && p.participa(_t.franquiciaUsuarioId)).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Simular el resto de la temporada?'),
        content: Text('Se juegan los $faltan partidos que faltan sin mirarlos. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('SIMULAR $faltan')),
        ],
      ),
    );
    if (ok == true && mounted) await _simular(faltan);
  }

  Future<void> _simular(int partidos) async {
    final total = min(partidos, _t.calendario.where((p) => !p.jugado && p.participa(_t.franquiciaUsuarioId)).length);
    setState(() {
      _ocupado = true;
      _progreso = total > 1 ? (0, total) : null;
    });
    await Future<void>.delayed(Duration.zero);
    var t = _t;
    String? ultimo;
    var ganados = 0, jugados = 0;
    for (var i = 0; i < partidos && _liga.proximoDelUsuario(t) != null; i++) {
      // Le da aire a la pantalla entre partido y partido (barra de progreso, sin trabarse).
      if (i > 0) {
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        if (total > 1) setState(() => _progreso = (i, total));
      }
      final p = _liga.proximoDelUsuario(t)!;
      t = _liga.simularProximo(t);
      final jugado = t.calendario.firstWhere((x) => x.id == p.id);
      final gano = jugado.ganadorId == t.franquiciaUsuarioId;
      jugados++;
      if (gano) ganados++;
      final rivalId = p.localId == t.franquiciaUsuarioId ? p.visitanteId : p.localId;
      ultimo =
          '${gano ? 'Ganaste' : 'Perdiste'} ${jugado.puntosLocal}-${jugado.puntosVisitante} vs ${_nombre(rivalId)}.';
    }
    if (_liga.proximoDelUsuario(t) == null) t = _liga.simularOtrosHasta(t, 1 << 30);
    _guardar(t);
    setState(() {
      _ocupado = false;
      _progreso = null;
      if (ultimo != null) {
        _resumen = jugados == 1 ? ultimo : 'Simulaste $jugados: $ganados-${jugados - ganados}. Último: $ultimo';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final franquicia = franquiciaPorId(_t.franquiciaUsuarioId);
    final proximo = _liga.proximoDelUsuario(_t);

    return Scaffold(
      appBar: AppBar(
        title: Text('Temporada de los ${franquicia.nombre}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Stats82Pantalla(temporada: _t, liga: _liga),
              ),
            ),
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'STATS 82',
          ),
          IconButton(onPressed: _abrirPlaybook, icon: const Icon(Icons.tune), tooltip: 'Tácticas'),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList.list(
                children: [
                  _Encabezado(temporada: _t),
                  if (_resumen case final resumen?) ...[
                    const SizedBox(height: 8),
                    Text(resumen, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 12),
                  if (proximo != null)
                    _ProximoPartido(
                      partido: proximo,
                      local: proximo.localId == _t.franquiciaUsuarioId,
                      rival: _identidad(
                        proximo.localId == _t.franquiciaUsuarioId ? proximo.visitanteId : proximo.localId,
                      ),
                      nombre: _nombre(
                        proximo.localId == _t.franquiciaUsuarioId ? proximo.visitanteId : proximo.localId,
                      ),
                      detalle: _detalleRival(
                        proximo.localId == _t.franquiciaUsuarioId ? proximo.visitanteId : proximo.localId,
                      ),
                      figuras: () {
                        final rivalId = proximo.localId == _t.franquiciaUsuarioId
                            ? proximo.visitanteId
                            : proximo.localId;
                        final plantel = _liga.plantelDe(_t.rivales[rivalId]!);
                        final js = plantel.jugadores.toList()..sort((a, b) => b.media.compareTo(a.media));
                        return js.take(3).map((j) => '${j.nombre} ${j.media}').join(' · ');
                      }(),
                      contexto: () {
                        final rivalId = proximo.localId == _t.franquiciaUsuarioId
                            ? proximo.visitanteId
                            : proximo.localId;
                        final (v, d, partidos) = _t.historialContra(rivalId);
                        final (backToBack, gira) = _liga.desgaste(_t, proximo, _t.franquiciaUsuarioId);
                        return [
                          if (v + d > 0) 'Serie de la temporada: $v-$d' else 'Primer cruce de ${partidos.length}',
                          if (backToBack) 'Back-to-back',
                          if (gira >= 3) 'Gira: $gira.º seguido de visitante',
                        ];
                      }(),
                      ocupado: _ocupado,
                      onVivo: () => _jugarEnVivo(proximo),
                      onSimular: () => _simular(1),
                      onSimular10: () => _simular(10),
                      onSimularTodo: _simularTodo,
                      progreso: _progreso,
                    )
                  else
                    _FinTemporada(temporada: _t, onPlayoffs: widget.onPlayoffs),
                  const SizedBox(height: 16),
                  SegmentedButton<_Vista>(
                    segments: const [
                      ButtonSegment(value: _Vista.resultados, label: Text('Resultados')),
                      ButtonSegment(value: _Vista.posiciones, label: Text('Posiciones')),
                      ButtonSegment(value: _Vista.plantel, label: Text('Plantel')),
                    ],
                    selected: {_vista},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _vista = s.first),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: switch (_vista) {
                _Vista.resultados => _resultados(tema),
                _Vista.posiciones => _posiciones(tema),
                _Vista.plantel => _plantel(tema),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultados(ThemeData tema) {
    final mios = [
      for (final p in _t.calendario.reversed)
        if (p.jugado && p.participa(_t.franquiciaUsuarioId)) p,
    ];
    if (mios.isEmpty) {
      return SliverToBoxAdapter(child: Text('Todavía no jugaste ningún partido.', style: tema.textTheme.bodyMedium));
    }
    return SliverList.builder(
      itemCount: mios.length,
      itemBuilder: (_, i) {
        final p = mios[i];
        final local = p.localId == _t.franquiciaUsuarioId;
        final rivalId = local ? p.visitanteId : p.localId;
        final gano = p.ganadorId == _t.franquiciaUsuarioId;
        final rival = _identidad(rivalId);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Escudo(rival, tamano: 32),
          title: Text('${local ? 'vs' : '@'} ${_nombre(rivalId)}'),
          subtitle: Text('Jornada ${p.jornada}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextoLed(gano ? 'G' : 'P', tamano: 18, color: gano ? tema.colorScheme.primary : tema.colorScheme.error),
              const SizedBox(width: 8),
              TextoLed('${p.puntosLocal}-${p.puntosVisitante}', tamano: 18, color: tema.colorScheme.onSurface),
            ],
          ),
        );
      },
    );
  }

  Widget _posiciones(ThemeData tema) {
    final tabla = _t.standings(_conferencia, franquicias);
    final lider = tabla.first;
    return SliverList.list(
      children: [
        SegmentedButton<Conferencia>(
          segments: const [
            ButtonSegment(value: Conferencia.este, label: Text('Este')),
            ButtonSegment(value: Conferencia.oeste, label: Text('Oeste')),
          ],
          selected: {_conferencia},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _conferencia = s.first),
        ),
        const SizedBox(height: 8),
        for (final (i, r) in tabla.indexed) ...[
          if (i == 6) Divider(color: tema.colorScheme.outlineVariant),
          if (i == 10) Divider(color: tema.colorScheme.outlineVariant, thickness: 2),
          _FilaTabla(
            posicion: i + 1,
            franquicia: _identidad(r.franquiciaId),
            nombre: _nombre(r.franquiciaId),
            victorias: r.victorias,
            derrotas: r.derrotas,
            diferencia: ((lider.victorias - r.victorias) + (r.derrotas - lider.derrotas)) / 2,
            propia: r.franquiciaId == _t.franquiciaUsuarioId,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Del 1.º al 6.º van directo a los playoffs; del 7.º al 10.º juegan el Play-In. '
          'Desempates: enfrentamientos directos, récord en la conferencia y diferencia de puntos.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _plantel(ThemeData tema) => SliverList.list(
    children: [
      for (final p in Posicion.values)
        if (_t.plantel.en(p) case final j?)
          () {
            final l = _t.lineas[j.id];
            final pj = l?.pj ?? 0;
            String prom(int v) => pj == 0 ? '-' : (v / pj).toStringAsFixed(1);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Flexible(child: Text(j.nombre, overflow: TextOverflow.ellipsis)),
                  IndicadorForma(_t.forma[j.id] ?? 0),
                ],
              ),
              subtitle: Text(
                '${p.etiqueta} · $pj PJ · ${l == null || l.tcA == 0 ? '-' : (100 * l.tcI / l.tcA).toStringAsFixed(1)} %TC',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (sigla, v) in [('PPP', l?.pts ?? 0), ('RPP', l?.reb ?? 0), ('APP', l?.ast ?? 0)]) ...[
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextoLed(prom(v), tamano: 16, color: tema.colorScheme.onSurface),
                        Text(sigla, style: tema.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }(),
    ],
  );
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.temporada});

  final Temporada temporada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final r = temporada.registroUsuario;
    final invicto = r.derrotas == 0;
    final restantes = Temporada.partidosTemporadaRegular - r.jugados;
    return Semantics(
      label:
          'Récord ${r.victorias} victorias y ${r.derrotas} derrotas. Quedan $restantes partidos. '
          'Dificultad ${temporada.dificultad.nombre}.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextoLed('${r.victorias}-${r.derrotas}', tamano: 52),
                    const SizedBox(height: 4),
                    Text(
                      invicto
                          ? (r.jugados == 0 ? 'Rumbo al 82-0' : 'Invicto: quedan $restantes para el 82-0')
                          : 'Quedan $restantes partidos',
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextoLed(
                    '82-0',
                    tamano: 22,
                    color: invicto ? esquema.primary : esquema.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    temporada.dificultad.nombre.toUpperCase(),
                    style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant, letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProximoPartido extends StatelessWidget {
  const _ProximoPartido({
    required this.partido,
    this.contexto = const [],
    required this.local,
    required this.rival,
    required this.nombre,
    required this.detalle,
    required this.figuras,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onSimular10,
    required this.onSimularTodo,
    required this.progreso,
  });

  final Partido partido;

  /// Serie de la temporada contra ese rival, back-to-back, gira.
  final List<String> contexto;
  final bool local;
  final Franquicia rival;
  final String nombre, detalle;
  final String figuras;
  final bool ocupado;
  final VoidCallback onVivo, onSimular, onSimular10, onSimularTodo;
  final (int, int)? progreso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Escudo(rival, tamano: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${local ? 'vs' : '@'} $nombre'.toUpperCase(),
                      style: tema.textTheme.headlineSmall?.copyWith(fontSize: 22),
                    ),
                    Text(
                      'Jornada ${partido.jornada} · ${local ? 'de local' : 'de visitante'} · $detalle',
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary),
                    ),
                    if (contexto.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final c in contexto)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: c.startsWith('Back') || c.startsWith('Gira')
                                      ? esquema.error
                                      : esquema.outlineVariant,
                                ),
                              ),
                              child: Text(c, style: tema.textTheme.labelSmall),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      figuras,
                      maxLines: 2,
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: ocupado ? null : onVivo, child: const Text('JUGAR EN VIVO')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: ocupado ? null : onSimular,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('SIMULAR'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: ocupado ? null : onSimular10,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('SIMULAR 10'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (progreso case (final hechos, final total))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  LinearProgressIndicator(value: hechos / total, minHeight: 4, borderRadius: BorderRadius.circular(2)),
                  const SizedBox(height: 6),
                  Text(
                    'Simulando $hechos de $total…',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: ocupado ? null : onSimularTodo,
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('SIMULAR TODA LA TEMPORADA'),
            ),
        ],
      ),
    );
  }
}

class _FinTemporada extends StatelessWidget {
  const _FinTemporada({required this.temporada, required this.onPlayoffs});

  final Temporada temporada;
  final VoidCallback? onPlayoffs;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final perfecta = temporada.esTemporadaPerfecta;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: perfecta ? tema.colorScheme.primary : tema.colorScheme.outlineVariant,
          width: perfecta ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            perfecta ? '¡HAZAÑA INMORTAL: 82-0!' : 'TEMPORADA REGULAR TERMINADA',
            textAlign: TextAlign.center,
            style: tema.textTheme.headlineSmall,
          ),
          if (perfecta) Text('Trofeo Presidente para tu franquicia.', style: tema.textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onPlayoffs,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('IR A LOS PLAYOFFS'),
          ),
        ],
      ),
    );
  }
}

class _FilaTabla extends StatelessWidget {
  const _FilaTabla({
    required this.posicion,
    required this.franquicia,
    required this.nombre,
    required this.victorias,
    required this.derrotas,
    required this.diferencia,
    required this.propia,
  });

  final int posicion;
  final Franquicia franquicia;
  final String nombre;
  final int victorias, derrotas;
  final double diferencia;
  final bool propia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: propia ? esquema.primary.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$posicion', style: tema.textTheme.bodyMedium)),
          Escudo(franquicia, tamano: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis)),
          TextoLed('$victorias-$derrotas', tamano: 16, color: propia ? esquema.primary : esquema.onSurface),
          SizedBox(
            width: 44,
            child: Text(
              diferencia == 0 ? '-' : diferencia.toStringAsFixed(diferencia % 1 == 0 ? 0 : 1),
              textAlign: TextAlign.end,
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
