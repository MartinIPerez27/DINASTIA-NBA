import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../../domain/modos/universitario.dart';
import '../../domain/motor.dart';
import '../pantallas/partido_pantalla.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/disposicion.dart';
import '../widgets/texto_led.dart';
import 'carrera_jugador.dart';
import 'creador_jugador.dart';
import 'modos.dart';
import 'universitario_pantallas.dart';

/// Modo universitario: un programa ficticio, una liga de 32 universidades inventadas y jugadores
/// que creás vos. Se simulan temporadas enteras, se recluta y los mejores pasan al draft.
Future<void> iniciarUniversitario(ContextoModos c) async {
  final nav = c.navegador.currentState!;
  final programa = await nav.push(MaterialPageRoute<Programa>(builder: (_) => const ProgramaConfigPantalla()));
  if (programa == null || !c.context.mounted) return;
  final creados = <JugadorCreado>[];
  while (creados.length < 5) {
    final j = await nav.push(
      MaterialPageRoute<JugadorCreado>(
        builder: (_) => CreadorJugadorPantalla(
          titulo: 'Tu clase: jugador ${creados.length + 1} de 5',
          textoBoton: creados.length + 1 < 2 ? 'GUARDAR Y SEGUIR' : 'AGREGAR A LA CLASE',
        ),
      ),
    );
    if (j == null) {
      if (creados.length >= 2) break;
      return;
    }
    creados.add(j);
    if (creados.length >= 2 && creados.length < 5) {
      if (!c.context.mounted) return;
      final otro = await showDialog<bool>(
        context: c.context,
        builder: (d) => AlertDialog(
          title: Text('${creados.length} jugadores creados'),
          content: const Text('Podés crear hasta 5. El resto del plantel lo genera el juego.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('EMPEZAR')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('CREAR OTRO')),
          ],
        ),
      );
      if (otro != true) break;
    }
  }
  if (creados.length < 2) return;
  final id = ContextoModos.nuevoId();
  final estado = const Universitario().nueva(semilla: int.parse(id) & 0x7fffffff, programa: programa, creados: creados);
  final t = Temporada(
    id: id,
    // La partida necesita una franquicia real asociada (tema y "Seguir" de Inicio): la de color más parecido.
    franquiciaUsuarioId: franquiciaParecida(programa).id,
    modoJuego: ModoJuego.universitario,
    datosModo: estado.aDatos(),
  );
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// La pantalla de la partida del modo universitario, o null si no lo es.
Future<Widget?> pantallaUniversitario(Temporada t, ContextoModos c) async {
  if (EstadoUniv.de(t) == null) return null;
  return UniversitarioPantalla(temporada: t, contexto: c);
}

enum _Vista { tabla, ranking, plantel, historia }

/// El centro del modo: próximo partido, simulación, torneo, premios y receso, más tablas, ranking,
/// plantel e historia del programa.
class UniversitarioPantalla extends StatefulWidget {
  const UniversitarioPantalla({super.key, required this.temporada, required this.contexto});

  final Temporada temporada;
  final ContextoModos contexto;

  @override
  State<UniversitarioPantalla> createState() => _UniversitarioPantallaState();
}

class _UniversitarioPantallaState extends State<UniversitarioPantalla> {
  static const _sim = Universitario();

  late Temporada _t = widget.temporada;
  late EstadoUniv _e = EstadoUniv.de(_t)!;
  late var _conferencia = _e.conferenciaDe[0];
  var _vista = _Vista.tabla;
  var _ocupado = false;
  String? _avance;

  void _guardar(EstadoUniv e) {
    final t = _t.copyWith(datosModo: e.aDatos());
    setState(() {
      _t = t;
      _e = e;
    });
    unawaited(widget.contexto.guardar(t));
  }

  Future<void> _simular(int jornadas) async {
    setState(() => _ocupado = true);
    var x = _e;
    final total = jornadas;
    for (var i = 0; i < total && x.fase == FaseUniv.regular; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      x = _sim.simularJornada(x);
      setState(() {
        _e = x;
        _avance = total > 1 ? 'Jornada ${x.jornada} de ${EstadoUniv.jornadas}…' : null;
      });
    }
    if (!mounted) return;
    _ocupado = false;
    _avance = null;
    _guardar(x);
  }

  Future<void> _simularTorneo({required bool todo}) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final x = todo ? _sim.simularTorneo(_e) : _sim.simularRonda(_e);
    if (!mounted) return;
    _ocupado = false;
    _guardar(x);
  }

  Future<void> _jugarEnVivo(JuegoU juego) async {
    final antes = _e;
    final torneo = antes.fase == FaseUniv.torneo;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: _sim.motor(antes, juego),
          usuarioLocal: juego.$1 == 0,
          franquiciaUsuario: antes.franquicia(0),
          identidadLocal: antes.franquicia(juego.$1),
          identidadVisitante: antes.franquicia(juego.$2),
          onTerminado: (MotorPartido m) {
            if (!mounted || !identical(_e, antes)) return;
            _guardar(torneo ? _sim.simularRonda(antes, motorUsuario: m) : _sim.simularJornada(antes, motorUsuario: m));
          },
        ),
      ),
    );
  }

  Future<void> _abrirReceso() async {
    final base = _e;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (c) => RecesoUnivPantalla(
          estado: base,
          onTerminar: (declarados, firmados) {
            Navigator.of(c).pop();
            if (mounted) _guardar(_sim.cerrarReceso(base, declarados: declarados, firmados: firmados));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: temaFranquicia(_e.programa.franquicia),
    child: Builder(builder: _construir),
  );

  /// Se arma con el contexto de adentro del [Theme] de la universidad (los colores del programa).
  Widget _construir(BuildContext context) {
    final f = _e.programa.franquicia;
    final izquierda = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _Cabecera(estado: _e),
        const SizedBox(height: 12),
        _panelFase(context),
      ],
    );
    final derecha = _tabs(context);
    final cuerpo = esTabletApaisada(context)
        ? Row(
            children: [
              Expanded(flex: 5, child: izquierda),
              Expanded(flex: 6, child: derecha),
            ],
          )
        : CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.list(
                  children: [
                    _Cabecera(estado: _e),
                    const SizedBox(height: 12),
                    _panelFase(context),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: _selectorVista()),
              SliverToBoxAdapter(child: _contenidoVista(context, scrollable: false)),
            ],
          );
    return Scaffold(
      appBar: AppBar(title: Text(f.nombreCompleto)),
      body: SafeArea(top: false, child: cuerpo),
    );
  }

  Widget _selectorVista() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: SegmentedButton<_Vista>(
      segments: const [
        ButtonSegment(
          value: _Vista.tabla,
          label: FittedBox(child: Text('Tabla')),
        ),
        ButtonSegment(
          value: _Vista.ranking,
          label: FittedBox(child: Text('Top 25')),
        ),
        ButtonSegment(
          value: _Vista.plantel,
          label: FittedBox(child: Text('Plantel')),
        ),
        ButtonSegment(
          value: _Vista.historia,
          label: FittedBox(child: Text('Historia')),
        ),
      ],
      selected: {_vista},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
      onSelectionChanged: (s) => setState(() => _vista = s.first),
    ),
  );

  Widget _tabs(BuildContext context) => Column(
    children: [
      _selectorVista(),
      Expanded(child: _contenidoVista(context, scrollable: true)),
    ],
  );

  Widget _contenidoVista(BuildContext context, {required bool scrollable}) {
    final hijos = switch (_vista) {
      _Vista.tabla => _tabla(context),
      _Vista.ranking => _ranking(context),
      _Vista.plantel => _plantel(context),
      _Vista.historia => _historia(context),
    };
    return scrollable
        ? ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: hijos)
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
          );
  }

  // ───────────────────────── Panel de la fase ─────────────────────────

  Widget _panelFase(BuildContext context) => switch (_e.fase) {
    FaseUniv.regular => _proximoPartido(context),
    FaseUniv.torneo => _torneo(context),
    FaseUniv.premios => _premios(context),
    FaseUniv.receso => _receso(context),
  };

  Widget _caja(BuildContext context, {required Widget child}) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.primary.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }

  Widget _rival(BuildContext context, int rival, bool local, {String? nota}) {
    final tema = Theme.of(context);
    final fr = _e.franquicia(rival);
    final suyo = EstadoUniv.fuerzaDe(_e.plantelDe(rival)).round();
    final mio = EstadoUniv.fuerzaDe(_e.plantel).round();
    final puesto = _e.ranking().indexOf(rival) + 1;
    return Row(
      children: [
        EscudoUniv(fr, tamano: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${local ? 'vs' : '@'} ${fr.nombreCompleto}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.titleMedium,
              ),
              Text(
                '${nota == null ? '' : '$nota · '}Nº$puesto del ranking · nivel $suyo (el tuyo: $mio)',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _proximoPartido(BuildContext context) {
    final tema = Theme.of(context);
    final cal = _e.calendario();
    final (juego, _) = _e.partidoUsuario(_e.jornada, cal)!;
    final local = juego.$1 == 0;
    final rival = local ? juego.$2 : juego.$1;
    final restantes = EstadoUniv.jornadas - _e.jornada;
    return _caja(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'JORNADA ${_e.jornada + 1} DE ${EstadoUniv.jornadas}',
            style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.primary),
          ),
          const SizedBox(height: 10),
          _rival(context, rival, local, nota: local ? 'de local' : 'de visitante'),
          const SizedBox(height: 14),
          if (_avance != null) ...[
            LinearProgressIndicator(value: _e.jornada / EstadoUniv.jornadas),
            const SizedBox(height: 6),
            Text(_avance!, textAlign: TextAlign.center, style: tema.textTheme.bodySmall),
          ] else ...[
            FilledButton.icon(
              onPressed: _ocupado ? null : () => _jugarEnVivo(juego),
              icon: const Icon(Icons.play_arrow),
              label: const Text('JUGAR EN VIVO'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (etiqueta, n) in [('PARTIDO', 1), ('SEMANA', 2), ('MES', 8)]) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _ocupado || n > restantes + 1 && n != 1 ? null : () => _simular(n),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), padding: EdgeInsets.zero),
                      child: FittedBox(child: Text(etiqueta)),
                    ),
                  ),
                  if (n != 8) const SizedBox(width: 8),
                ],
              ],
            ),
            TextButton(
              onPressed: _ocupado ? null : () => _simular(restantes),
              child: const Text('SIMULAR LO QUE QUEDA DE LA TEMPORADA'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _torneo(BuildContext context) {
    final tema = Theme.of(context);
    final g = _e.juegoTorneoUsuario;
    final r = _e.rondaActual.clamp(0, 3);
    return _caja(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TORNEO NACIONAL · ${EstadoUniv.nombresRondas[r].toUpperCase()}',
            style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.primary),
          ),
          const SizedBox(height: 10),
          if (g != null) ...[
            _rival(context, g[0] == 0 ? g[1] : g[0], g[0] == 0, nota: 'partido único'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _ocupado ? null : () => _jugarEnVivo((g[0], g[1])),
              icon: const Icon(Icons.play_arrow),
              label: const Text('JUGAR EN VIVO'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ] else
            Text(
              _e.resultadoTorneoUsuario == 'Sin torneo'
                  ? 'No entraste al torneo de 16. Se juega igual: simulalo para seguir.'
                  : 'Tu programa quedó eliminado (${_e.resultadoTorneoUsuario.toLowerCase()}). El torneo sigue sin vos.',
              style: tema.textTheme.bodyMedium,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _ocupado ? null : () => _simularTorneo(todo: false),
                  child: const Text('SIMULAR RONDA'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _ocupado ? null : () => _simularTorneo(todo: true),
                  child: const Text('SIMULAR TORNEO'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Llave(estado: _e),
        ],
      ),
    );
  }

  Widget _premios(BuildContext context) {
    final tema = Theme.of(context);
    final p = _e.premios();
    final campeon = _e.campeon;
    Widget fila(String titulo, PremioU x) {
      final mio = x.equipo == 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: mio ? tema.colorScheme.primary.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: mio ? tema.colorScheme.primary : Colors.transparent),
        ),
        child: Row(
          children: [
            SizedBox(width: 118, child: Text(titulo, style: tema.textTheme.labelSmall)),
            Expanded(
              child: Text(
                '${x.nombre} · ${x.posicion.etiqueta}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mio ? tema.textTheme.titleSmall : tema.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6),
            Text(_e.franquicia(x.equipo).id, style: tema.textTheme.labelSmall),
          ],
        ),
      );
    }

    return _caja(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FIN DE LA TEMPORADA ${_e.temporada}',
            style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          if (campeon != null)
            Row(
              children: [
                Icon(Icons.emoji_events, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    campeon == 0
                        ? '¡Campeones nacionales! Tu programa ganó el torneo.'
                        : 'Campeón nacional: ${_e.franquicia(campeon).nombreCompleto}.',
                    style: tema.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          fila('JUGADOR DEL AÑO', p.mejor),
          if (p.novato != null) fila('NOVATO DEL AÑO', p.novato!),
          const SizedBox(height: 4),
          for (final x in p.primerEquipo) fila('1.º EQUIPO ALL-AMERICAN', x),
          for (final x in p.segundoEquipo) fila('2.º EQUIPO ALL-AMERICAN', x),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _guardar(_sim.cerrarTemporada(_e)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('SEGUIR AL RECESO'),
          ),
        ],
      ),
    );
  }

  Widget _receso(BuildContext context) {
    final tema = Theme.of(context);
    final h = _e.historial.isEmpty ? null : _e.historial.last;
    return _caja(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RECESO', style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.primary)),
          const SizedBox(height: 8),
          if (h != null)
            Text(
              'Temporada ${h.numero}: ${h.v}-${h.d}, ${h.puestoConferencia}.º en tu conferencia, torneo: ${h.torneo.toLowerCase()}.',
              style: tema.textTheme.bodyMedium,
            ),
          const SizedBox(height: 4),
          Text(
            'Los de último año se van al draft, los demás crecen y reclutás a la nueva clase con tus puntos de reclutamiento.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _abrirReceso,
            icon: const Icon(Icons.school),
            label: const Text('ABRIR EL RECESO'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Pestañas ─────────────────────────

  Widget _fila(BuildContext context, {required int idx, required Widget cuerpo, Widget? numero}) {
    final tema = Theme.of(context);
    final mio = idx == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: mio ? tema.colorScheme.primary.withValues(alpha: 0.14) : tema.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mio ? tema.colorScheme.primary : Colors.transparent),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: numero ?? const SizedBox.shrink()),
          EscudoUniv(_e.franquicia(idx), tamano: 30),
          const SizedBox(width: 10),
          Expanded(child: cuerpo),
        ],
      ),
    );
  }

  List<Widget> _tabla(BuildContext context) {
    final tema = Theme.of(context);
    final tabla = _e.tablaConferencia(_conferencia);
    return [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var c = 0; c < 4; c++)
            ChoiceChip(
              label: Text(nombresConferencias[c]),
              selected: c == _conferencia,
              onSelected: (_) => setState(() => _conferencia = c),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_e.jornada == 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Todavía no se jugó: la tabla arranca en 0-0.', style: tema.textTheme.bodySmall),
        ),
      for (var i = 0; i < tabla.length; i++)
        _fila(
          context,
          idx: tabla[i].idx,
          numero: Text('${i + 1}', style: tema.textTheme.titleSmall),
          cuerpo: Row(
            children: [
              Expanded(
                child: Text(
                  _e.franquicia(tabla[i].idx).nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tabla[i].idx == 0 ? tema.textTheme.titleSmall : tema.textTheme.bodyMedium,
                ),
              ),
              Text('${tabla[i].v}-${tabla[i].d}', style: tema.textTheme.titleSmall),
              SizedBox(
                width: 62,
                child: Text(
                  '  conf ${tabla[i].vConf}-${tabla[i].dConf}',
                  style: tema.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _ranking(BuildContext context) {
    final tema = Theme.of(context);
    final orden = _e.ranking();
    final regs = {for (final r in _e.registros()) r.idx: r};
    final tuyo = orden.indexOf(0) + 1;
    return [
      Text(
        _e.jornada == 0 ? 'ENCUESTA DE PRETEMPORADA' : 'TOP 25 · DESPUÉS DE ${_e.jornada} JORNADAS',
        style: tema.textTheme.labelLarge,
      ),
      const SizedBox(height: 4),
      Text(
        tuyo <= 25 ? 'Tu programa es el Nº$tuyo.' : 'Tu programa es el Nº$tuyo: afuera del Top 25.',
        style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < 25; i++)
        _fila(
          context,
          idx: orden[i],
          numero: TextoLed('${i + 1}', tamano: 18),
          cuerpo: Row(
            children: [
              Expanded(
                child: Text(
                  _e.franquicia(orden[i]).nombreCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: orden[i] == 0 ? tema.textTheme.titleSmall : tema.textTheme.bodyMedium,
                ),
              ),
              Text('${regs[orden[i]]!.v}-${regs[orden[i]]!.d}', style: tema.textTheme.titleSmall),
            ],
          ),
        ),
    ];
  }

  List<Widget> _plantel(BuildContext context) {
    final tema = Theme.of(context);
    final lista = [..._e.plantel]..sort((a, b) => b.media.compareTo(a.media));
    return [
      Text(
        'Plantel de ${_e.programa.nombre.trim()} · nivel ${EstadoUniv.fuerzaDe(_e.plantel).round()}',
        style: tema.textTheme.labelLarge,
      ),
      const SizedBox(height: 8),
      for (final x in lista)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _EstudianteExpandible(estudiante: x),
        ),
    ];
  }

  List<Widget> _historia(BuildContext context) {
    final tema = Theme.of(context);
    final h = _e.historial.reversed.toList();
    return [
      _caja(
        context,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final (n, etiqueta) in [
              (_e.titulos, 'TÍTULOS'),
              (_e.historial.length, 'TEMPORADAS'),
              (_e.egresados.where((x) => x.pick != null).length, 'DRAFTEADOS'),
              (_e.prestigio, 'PRESTIGIO'),
            ])
              Column(
                children: [
                  TextoLed('$n', tamano: 28),
                  const SizedBox(height: 4),
                  Text(etiqueta, style: tema.textTheme.labelSmall),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text('SALÓN DE LA FAMA UNIVERSITARIO', style: tema.textTheme.labelLarge),
      const SizedBox(height: 8),
      if (h.isEmpty) const Text('Todavía no terminó ninguna temporada.'),
      for (final x in h)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tema.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: x.campeon ? tema.colorScheme.primary : tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('TEMPORADA ${x.numero}', style: tema.textTheme.titleSmall),
                  const Spacer(),
                  if (x.campeon) Icon(Icons.emoji_events, color: tema.colorScheme.primary, size: 20),
                  const SizedBox(width: 6),
                  TextoLed('${x.v}-${x.d}', tamano: 22),
                ],
              ),
              Text(
                '${x.puestoConferencia}.º en ${nombresConferencias[_e.conferenciaDe[0]]} · torneo: ${x.torneo.toLowerCase()}',
                style: tema.textTheme.bodySmall,
              ),
              for (final p in x.premios)
                Text('★ $p', style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.primary)),
              for (final p in x.picks) Text('Draft: $p', style: tema.textTheme.bodySmall),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Text('EGRESADOS', style: tema.textTheme.labelLarge),
      const SizedBox(height: 8),
      if (_e.egresados.isEmpty) const Text('Todavía no se fue nadie.'),
      for (final g in _e.egresados.reversed)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: tema.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              TextoLed('${g.media}', tamano: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                    Text(
                      '${g.posicion.etiqueta} · ${g.anios} años · temporada ${g.temporada} · ${g.destino}',
                      style: tema.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (g.pick != null && g.pick! <= 30)
                IconButton(
                  tooltip: 'Llevar a ${g.nombre} a Mi carrera',
                  icon: const Icon(Icons.sports_basketball),
                  onPressed: () => iniciarCarreraJugador(widget.contexto, creadoInicial: g.comoCreado),
                ),
            ],
          ),
        ),
    ];
  }
}

/// Encabezado del programa: escudo, nombre, récord, prestigio y puesto en el ranking.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.estado});

  final EstadoUniv estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mi = estado.registros()[0];
    final puesto = estado.ranking().indexOf(0) + 1;
    return Row(
      children: [
        EscudoUniv(estado.programa.franquicia, tamano: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                estado.programa.franquicia.nombreCompleto.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.titleLarge,
              ),
              Text(
                estado.etiquetaFase,
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('PRESTIGIO ', style: tema.textTheme.labelSmall),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: estado.prestigio / 100, minHeight: 5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextoLed('${mi.v}-${mi.d}', tamano: 30),
            Text('Nº$puesto', style: tema.textTheme.labelMedium),
          ],
        ),
      ],
    );
  }
}

/// El cuadro del torneo de 16: cada ronda con sus partidos.
class _Llave extends StatelessWidget {
  const _Llave({required this.estado});

  final EstadoUniv estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < estado.torneo.length; r++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(EstadoUniv.nombresRondas[r].toUpperCase(), style: tema.textTheme.labelSmall),
          ),
          for (final g in estado.torneo[r])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  _lado(context, g[0], g, gana: g[2] > g[3], jugado: g[2] != 0),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Center(
                      child: g[2] == 0 ? const Text('—') : Text('${g[2]}–${g[3]}', style: tema.textTheme.labelMedium),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _lado(context, g[1], g, gana: g[3] > g[2], jugado: g[2] != 0, derecha: true),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _lado(
    BuildContext context,
    int idx,
    List<int> g, {
    required bool gana,
    required bool jugado,
    bool derecha = false,
  }) {
    final tema = Theme.of(context);
    final f = estado.franquicia(idx);
    final estilo = (idx == 0 ? tema.textTheme.titleSmall : tema.textTheme.bodySmall)?.copyWith(
      fontWeight: jugado && gana ? FontWeight.w800 : null,
      color: jugado && !gana ? tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.6) : null,
    );
    return Expanded(
      child: Row(
        textDirection: derecha ? TextDirection.rtl : TextDirection.ltr,
        children: [
          EscudoUniv(f, tamano: 22),
          const SizedBox(width: 6),
          Expanded(
            child: Text(f.id, textAlign: derecha ? TextAlign.end : TextAlign.start, style: estilo),
          ),
        ],
      ),
    );
  }
}

/// Un estudiante de tu plantel, con sus atributos al tocarlo.
class _EstudianteExpandible extends StatelessWidget {
  const _EstudianteExpandible({required this.estudiante});

  final Estudiante estudiante;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final e = estudiante;
    final linea = e.pj > 0
        ? '${(e.pts / e.pj).toStringAsFixed(1)} pts · ${(e.reb / e.pj).toStringAsFixed(1)} reb · ${(e.ast / e.pj).toStringAsFixed(1)} ast · ${e.pj} PJ'
        : null;
    return Material(
      color: tema.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tema.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: TextoLed('${e.media}', tamano: 26),
        title: Row(
          children: [
            Flexible(
              child: Text(e.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
            ),
            if (e.creado) ...[const SizedBox(width: 6), Icon(Icons.edit, size: 13, color: tema.colorScheme.primary)],
          ],
        ),
        subtitle: Text(
          '${e.posicion.etiqueta} · ${e.etiquetaAnio}${linea == null ? '' : '\n$linea'}',
          style: tema.textTheme.bodySmall,
        ),
        trailing: Estrellas(e.estrellas, tamano: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${e.rol.etiqueta} · ${e.alturaCm} cm · ${e.pesoKg} kg',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 6),
          BarrasAtributos(e.atributos),
        ],
      ),
    );
  }
}
