import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/decisiones_partido.dart';
import '../../domain/motor.dart' show JugadaClave;
import '../tema/tema_franquicia.dart';
import '../widgets/texto_led.dart';

/// Hoja de decisión del partido en vivo: una pregunta corta, 3 o 4 opciones con su efecto y su costo, y
/// "seguir igual". Si no tocás nada, se sigue igual cuando se acaba la espera (la barra de arriba).
///
/// En el teléfono va como hoja sobre la cancha (debajo del marcador); en la tablet, en el panel derecho.
class HojaDecision extends StatefulWidget {
  const HojaDecision({
    super.key,
    required this.decision,
    required this.onElegir,
    this.onNoSugerir,
    this.conEspera = true,
  });

  final DecisionPartido decision;

  /// Opción elegida, o null si se ignora (toque en "Seguir igual" o se acabó la espera).
  final ValueChanged<OpcionDecision?> onElegir;

  /// "No sugerir más en este partido".
  final VoidCallback? onNoSugerir;

  /// Si la barra de espera corre (las capturas la apagan).
  final bool conEspera;

  @override
  State<HojaDecision> createState() => _HojaDecisionState();
}

class _HojaDecisionState extends State<HojaDecision> {
  Timer? _timer;
  late double _resta = widget.decision.segundosEspera.toDouble();

  @override
  void initState() {
    super.initState();
    if (widget.conEspera) {
      _timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted) return;
        setState(() => _resta -= 0.2);
        if (_resta <= 0) {
          t.cancel();
          widget.onElegir(null);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final d = widget.decision;
    return LayoutBuilder(
      builder: (context, c) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(8),
          constraints: BoxConstraints(maxWidth: 520, maxHeight: c.maxHeight.isFinite ? c.maxHeight - 16 : 640),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: esquema.primary, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.conEspera)
                LinearProgressIndicator(
                  value: (_resta / d.segundosEspera).clamp(0, 1),
                  minHeight: 3,
                  color: esquema.primary,
                  backgroundColor: esquema.surfaceContainerHighest,
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(_icono(d.tipo), color: esquema.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                d.tipo.titulo.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: Fuentes.estadio,
                                  fontVariations: [FontVariation.weight(800)],
                                  fontSize: 22,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(d.situacion, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
                      const SizedBox(height: 6),
                      Text(d.motivo, style: tema.textTheme.bodyMedium),
                      const SizedBox(height: 10),
                      for (final o in d.opciones) ...[
                        TarjetaOpcion(opcion: o, onTap: () => widget.onElegir(o)),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => widget.onElegir(null),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: const Text('SEGUIR IGUAL'),
                      ),
                    ),
                    if (widget.onNoSugerir != null) ...[
                      const SizedBox(width: 8),
                      TextButton(onPressed: widget.onNoSugerir, child: const Text('No sugerir más')),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icono(TipoDecision t) => switch (t) {
    TipoDecision.parcialContra => Icons.trending_down,
    TipoDecision.cansancio => Icons.battery_2_bar,
    TipoDecision.faltas => Icons.flag,
    TipoDecision.rivalCaliente => Icons.local_fire_department,
    TipoDecision.tiradorEncendido => Icons.whatshot,
    TipoDecision.remontada => Icons.trending_up,
    TipoDecision.ventajaGrande => Icons.shield,
    TipoDecision.ultimoTiro => Icons.timer,
    TipoDecision.faltaIntencional => Icons.sports,
    TipoDecision.finalConVentaja => Icons.lock_clock,
    TipoDecision.entretiempo => Icons.pause_circle,
    TipoDecision.ajusteManual => Icons.tune,
    TipoDecision.tuPlan => Icons.sports_basketball,
    TipoDecision.tuMomento => Icons.bolt,
    TipoDecision.tuMarca => Icons.shield_outlined,
    TipoDecision.tuEnergia => Icons.battery_3_bar,
    TipoDecision.tuClutch => Icons.timer,
    TipoDecision.takeover => Icons.local_fire_department,
  };
}

/// Una opción con lo que hace y lo que cuesta (botón grande).
class TarjetaOpcion extends StatelessWidget {
  const TarjetaOpcion({super.key, required this.opcion, required this.onTap, this.seleccionada = false});

  final OpcionDecision opcion;
  final VoidCallback onTap;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Semantics(
      button: true,
      label: '${opcion.titulo}. ${opcion.efecto} Costo: ${opcion.costo}',
      child: ExcludeSemantics(
        child: Material(
          color: seleccionada ? esquema.primaryContainer.withValues(alpha: 0.4) : esquema.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: seleccionada || opcion.recomendada ? esquema.primary : esquema.outlineVariant),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          opcion.titulo.toUpperCase(),
                          style: tema.textTheme.titleSmall?.copyWith(letterSpacing: 0.6),
                        ),
                      ),
                      if (opcion.recomendada)
                        Text('SUGERIDA', style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(opcion.efecto, style: tema.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'COSTO  ',
                          style: tema.textTheme.labelSmall?.copyWith(color: esquema.error, letterSpacing: 0.6),
                        ),
                        TextSpan(text: opcion.costo),
                      ],
                    ),
                    style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menú de ajustes tácticos (el botón AJUSTES): todo lo que se puede pedir ahora, con su costo.
class HojaAjustes extends StatelessWidget {
  const HojaAjustes({
    super.key,
    required this.opciones,
    required this.onElegir,
    required this.onCerrar,
    this.espera = 0,
    this.activos = const [],
  });

  final List<OpcionDecision> opciones;
  final ValueChanged<OpcionDecision> onElegir;
  final VoidCallback onCerrar;

  /// Segundos de juego que faltan para el próximo ajuste (0: ya se puede).
  final int espera;
  final List<String> activos;

  static String _grupo(CategoriaAjuste c) => switch (c) {
    CategoriaAjuste.defensa => 'DEFENSA',
    CategoriaAjuste.ritmo => 'RITMO',
    CategoriaAjuste.foco => 'ATAQUE',
    CategoriaAjuste.quinteto => 'QUINTETO',
    CategoriaAjuste.descanso => 'DESCANSO',
    CategoriaAjuste.jugada => 'PRÓXIMA JUGADA',
    CategoriaAjuste.falta => 'FALTAS',
    _ => 'OTROS',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final grupos = <String, List<OpcionDecision>>{};
    for (final o in opciones) {
      grupos.putIfAbsent(_grupo(o.accion.categoria), () => []).add(o);
    }
    return LayoutBuilder(
      builder: (context, c) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(8),
          constraints: BoxConstraints(maxWidth: 520, maxHeight: c.maxHeight.isFinite ? c.maxHeight - 16 : 640),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: esquema.primary, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 0),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: esquema.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('AJUSTES DEL ENTRENADOR', style: tema.textTheme.titleMedium)),
                    IconButton(onPressed: onCerrar, icon: const Icon(Icons.close), tooltip: 'Cerrar'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  espera > 0
                      ? 'Tu cuerpo técnico necesita ${espera ~/ 60}:${(espera % 60).toString().padLeft(2, '0')} de juego '
                            'para otro ajuste.'
                      : 'Cada ajuste dura unos minutos de juego y tiene un costo. Uno por vez en cada grupo.',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
              if (activos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: Text('En marcha: ${activos.join(' · ')}', style: tema.textTheme.labelMedium),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  children: [
                    for (final e in grupos.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Text(e.key, style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary)),
                      ),
                      for (final o in e.value) ...[
                        Opacity(
                          opacity: espera > 0 ? 0.45 : 1,
                          child: TarjetaOpcion(opcion: o, onTap: espera > 0 ? () {} : () => onElegir(o)),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entretiempo: números por jugador, qué falló, qué anduvo y ajustes para el 3.er cuarto.
class HojaEntretiempo extends StatefulWidget {
  const HojaEntretiempo({super.key, required this.informe, required this.onSeguir});

  final InformeEntretiempo informe;

  /// Ajustes elegidos y la jugada preferida para el final (null: que decida el equipo).
  final void Function(List<OpcionDecision> elegidas, JugadaClave? preferida) onSeguir;

  @override
  State<HojaEntretiempo> createState() => _HojaEntretiempoState();
}

class _HojaEntretiempoState extends State<HojaEntretiempo> {
  final _elegidas = <CategoriaAjuste, OpcionDecision>{};
  final _descansos = <String, OpcionDecision>{};
  JugadaClave? _preferida;

  void _alternar(OpcionDecision o) {
    setState(() {
      final c = o.accion.categoria;
      if (_elegidas[c]?.id == o.id) {
        _elegidas.remove(c);
      } else {
        _elegidas[c] = o;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final inf = widget.informe;
    final estilo = TextStyle(
      fontFamily: Fuentes.led,
      fontVariations: const [FontVariation.weight(800)],
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 14,
      color: esquema.onSurface,
    );
    final cabecera = tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant);
    Widget celda(String t, {TextStyle? s, double ancho = 30}) => SizedBox(
      width: ancho,
      child: Text(t, textAlign: TextAlign.end, style: s ?? estilo),
    );
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(t, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary, letterSpacing: 0.8)),
    );
    Widget grupo(String nombre, List<OpcionDecision> ops) {
      if (ops.isEmpty) return const SizedBox.shrink();
      final c = ops.first.accion.categoria;
      final sel = _elegidas[c];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nombre, style: tema.textTheme.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final o in ops)
                ChoiceChip(
                  label: Text(o.titulo),
                  selected: sel?.id == o.id,
                  onSelected: (_) => _alternar(o),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (sel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: sel.efecto),
                    TextSpan(
                      text: '  Costo: ${sel.costo}',
                      style: TextStyle(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
                style: tema.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 6),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(8),
          constraints: BoxConstraints(maxWidth: 560, maxHeight: c.maxHeight.isFinite ? c.maxHeight - 16 : 700),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: esquema.primary, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    Icon(Icons.pause_circle, color: esquema.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ENTRETIEMPO',
                          style: const TextStyle(
                            fontFamily: Fuentes.estadio,
                            fontVariations: [FontVariation.weight(800)],
                            fontSize: 22,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    TextoLed('${inf.propios}-${inf.rivales}', tamano: 22),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  children: [
                    titulo('TUS JUGADORES'),
                    Row(
                      children: [
                        Expanded(child: Text('JUGADOR', style: cabecera)),
                        for (final t in ['MIN', 'PTS', 'REB', 'AST']) celda(t, s: cabecera),
                        celda('TC', s: cabecera, ancho: 54),
                        celda('F', s: cabecera, ancho: 22),
                      ],
                    ),
                    for (final f in inf.filas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                f.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: f.enCancha ? esquema.onSurface : esquema.onSurfaceVariant,
                                ),
                              ),
                            ),
                            celda('${f.minutos}'),
                            celda('${f.pts}', s: estilo.copyWith(color: esquema.primary)),
                            celda('${f.reb}'),
                            celda('${f.ast}'),
                            celda('${f.tcI}/${f.tcA}', ancho: 54),
                            celda(
                              '${f.faltas}',
                              s: estilo.copyWith(color: f.faltas >= 4 ? esquema.error : null),
                              ancho: 22,
                            ),
                          ],
                        ),
                      ),
                    titulo('QUÉ ANDUVO'),
                    for (final t in inf.bien)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: esquema.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(t, style: tema.textTheme.bodySmall)),
                          ],
                        ),
                      ),
                    titulo('QUÉ FALLÓ'),
                    for (final t in inf.mal)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 16, color: esquema.error),
                            const SizedBox(width: 6),
                            Expanded(child: Text(t, style: tema.textTheme.bodySmall)),
                          ],
                        ),
                      ),
                    titulo('AJUSTES PARA EL 3.º CUARTO (OPCIONALES)'),
                    grupo('Defensa', inf.defensas),
                    grupo('Ritmo', inf.ritmos),
                    grupo('Quinteto', inf.quintetos),
                    grupo('Foco en un jugador', inf.focos),
                    if (inf.descansos.isNotEmpty) ...[
                      Text('Descanso', style: tema.textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final o in inf.descansos)
                            FilterChip(
                              label: Text(o.titulo),
                              selected: _descansos.containsKey(o.id),
                              visualDensity: VisualDensity.compact,
                              onSelected: (v) => setState(() => v ? _descansos[o.id] = o : _descansos.remove(o.id)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text('Jugada preferida para el final', style: tema.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Que decida el equipo'),
                          selected: _preferida == null,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() => _preferida = null),
                        ),
                        for (final j in JugadaClave.values)
                          ChoiceChip(
                            label: Text(j.nombre),
                            selected: _preferida == j,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _preferida = j),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: FilledButton(
                  onPressed: () => widget.onSeguir([..._elegidas.values, ..._descansos.values], _preferida),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(
                    _elegidas.isEmpty && _descansos.isEmpty && _preferida == null
                        ? 'SEGUIR AL 3.º CUARTO'
                        : 'APLICAR Y SEGUIR AL 3.º CUARTO',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ajustes en marcha y cuánto les queda ("Zona 2-3 · 2:10").
class ChipsEfectos extends StatelessWidget {
  const ChipsEfectos({super.key, required this.efectos, required this.ahora});

  final List<EfectoActivo> efectos;
  final double ahora;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final visibles = [
      for (final e in efectos)
        if (!e.opcion.accion.unaJugada || e.restante(ahora) > 0) e,
    ];
    if (visibles.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final e in visibles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLowest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: esquema.primary),
            ),
            child: Text(
              e.opcion.accion.unaJugada
                  ? e.opcion.titulo
                  : '${e.opcion.titulo} · ${e.restante(ahora) ~/ 60}:${(e.restante(ahora) % 60).floor().toString().padLeft(2, '0')}',
              style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// Aviso corto después del efecto ("la zona cortó la racha: 0 de 6 de ellos").
class AvisoDecision extends StatelessWidget {
  const AvisoDecision({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: esquema.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 18, color: esquema.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Resumen del pospartido: las decisiones que tomaste y su impacto aproximado.
class ResumenDecisiones extends StatelessWidget {
  const ResumenDecisiones({super.key, required this.registro});

  final List<RegistroDecision> registro;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tomadas = registro.where((r) => !r.ignorada).toList();
    final ignoradas = registro.where((r) => r.ignorada && r.tipo != TipoDecision.entretiempo).length;
    if (tomadas.isEmpty && ignoradas == 0) return const SizedBox.shrink();
    final total = registro.fold(0, (a, r) => a + (r.impacto ?? 0));
    String cuando(RegistroDecision r) =>
        '${r.cuarto > 4 ? 'OT' : 'Q${r.cuarto}'} ${r.reloj ~/ 60}:${(r.reloj % 60).floor().toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Tus decisiones', style: tema.textTheme.titleMedium),
        const SizedBox(height: 6),
        if (tomadas.isEmpty)
          Text(
            'Ignoraste las $ignoradas sugerencias: el equipo jugó como lo armaste.',
            style: tema.textTheme.bodySmall,
          ),
        for (final r in tomadas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (r.veredicto) {
                    Veredicto.ayudo => Icons.thumb_up_alt_outlined,
                    Veredicto.empeoro => Icons.thumb_down_alt_outlined,
                    _ => Icons.remove_circle_outline,
                  },
                  size: 18,
                  color: switch (r.veredicto) {
                    Veredicto.ayudo => esquema.primary,
                    Veredicto.empeoro => esquema.error,
                    _ => esquema.onSurfaceVariant,
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${cuando(r)} · ${r.opcion}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (r.aviso != null) TextSpan(text: '\n${r.aviso}'),
                      ],
                    ),
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (tomadas.any((r) => r.impacto != null))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'En conjunto, a ojo: ${total >= 0 ? '+' : ''}$total puntos de diferencia mientras duraron los ajustes. '
              'Es una estimación: un partido tiene mucha suerte adentro.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ),
        if (ignoradas > 0 && tomadas.isNotEmpty)
          Text(
            'Dejaste pasar $ignoradas ${ignoradas == 1 ? 'sugerencia' : 'sugerencias'}.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// Alto máximo cómodo de la hoja en el teléfono (para quien necesite acotarla).
double altoHoja(BuildContext context) => min(MediaQuery.sizeOf(context).height * 0.7, 640);
