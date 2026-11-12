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
import '../widgets/texto_led.dart';
import 'partido_pantalla.dart';
import 'playbook_pantalla.dart';

enum _Vista { resultados, posiciones, plantel }

/// Temporada regular de 82 partidos (GDD §7): récord, próximo partido (en vivo o simulado),
/// resultados, tabla Este/Oeste y estadísticas de tu plantel.
class TemporadaPantalla extends StatefulWidget {
  const TemporadaPantalla({super.key, required this.temporada, required this.liga, required this.onCambio});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  @override
  State<TemporadaPantalla> createState() => _TemporadaPantallaState();
}

class _TemporadaPantallaState extends State<TemporadaPantalla> {
  late Temporada _t = widget.temporada;
  var _vista = _Vista.resultados;
  var _conferencia = Conferencia.este;
  var _ocupado = false;

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

  String _detalleRival(String franquiciaId) {
    final r = _t.rivales[franquiciaId]!;
    return r.tipo == TipoRival.epoca ? '${r.epoca!.etiqueta} (Época)' : 'Históricos';
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

  Future<void> _simular(int partidos) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    var t = _t;
    String? ultimo;
    var ganados = 0, jugados = 0;
    for (var i = 0; i < partidos && _liga.proximoDelUsuario(t) != null; i++) {
      final p = _liga.proximoDelUsuario(t)!;
      t = _liga.simularProximo(t);
      final jugado = t.calendario.firstWhere((x) => x.id == p.id);
      final gano = jugado.ganadorId == t.franquiciaUsuarioId;
      jugados++;
      if (gano) ganados++;
      final rival = _identidad(p.localId == t.franquiciaUsuarioId ? p.visitanteId : p.localId);
      ultimo = '${gano ? 'Ganaste' : 'Perdiste'} ${jugado.puntosLocal}-${jugado.puntosVisitante} vs ${rival.nombre}.';
    }
    if (_liga.proximoDelUsuario(t) == null) t = _liga.simularOtrosHasta(t, 1 << 30);
    _guardar(t);
    setState(() {
      _ocupado = false;
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
        actions: [IconButton(onPressed: _abrirPlaybook, icon: const Icon(Icons.tune), tooltip: 'Tácticas')],
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
                      ocupado: _ocupado,
                      onVivo: () => _jugarEnVivo(proximo),
                      onSimular: () => _simular(1),
                      onSimular10: () => _simular(10),
                    )
                  else
                    _FinTemporada(temporada: _t),
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
          title: Text('${local ? 'vs' : '@'} ${rival.nombreCompleto}'),
          subtitle: Text('Jornada ${p.jornada} · ${_detalleRival(rivalId)}'),
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
          if (i == Temporada.clasificadosPorConferencia) Divider(color: tema.colorScheme.outlineVariant),
          _FilaTabla(
            posicion: i + 1,
            franquicia: _identidad(r.franquiciaId),
            victorias: r.victorias,
            derrotas: r.derrotas,
            diferencia: ((lider.victorias - r.victorias) + (r.derrotas - lider.derrotas)) / 2,
            propia: r.franquiciaId == _t.franquiciaUsuarioId,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Los 8 primeros de cada conferencia van a los playoffs.',
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
              title: Text(j.nombre),
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
      label: 'Récord ${r.victorias} victorias y ${r.derrotas} derrotas. Quedan $restantes partidos.',
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
              TextoLed(
                '82-0',
                tamano: 22,
                color: invicto ? esquema.primary : esquema.onSurfaceVariant.withValues(alpha: 0.4),
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
    required this.local,
    required this.rival,
    required this.detalle,
    required this.figuras,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onSimular10,
  });

  final Partido partido;
  final bool local;
  final Franquicia rival;
  final String detalle;
  final String figuras;
  final bool ocupado;
  final VoidCallback onVivo, onSimular, onSimular10;

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
                      '${local ? 'vs' : '@'} ${rival.nombreCompleto}'.toUpperCase(),
                      style: tema.textTheme.headlineSmall?.copyWith(fontSize: 22),
                    ),
                    Text(
                      'Jornada ${partido.jornada} · ${local ? 'de local' : 'de visitante'} · $detalle',
                      style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary),
                    ),
                    const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}

class _FinTemporada extends StatelessWidget {
  const _FinTemporada({required this.temporada});

  final Temporada temporada;

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
          const SizedBox(height: 8),
          Text(
            'Los playoffs al mejor de 7 y el STATS 82 llegan en la Fase 6.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
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
    required this.victorias,
    required this.derrotas,
    required this.diferencia,
    required this.propia,
  });

  final int posicion;
  final Franquicia franquicia;
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
          Expanded(child: Text(franquicia.nombreCompleto, maxLines: 1, overflow: TextOverflow.ellipsis)),
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
