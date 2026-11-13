import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/tactica.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/amigos.dart';
import '../../domain/motor.dart';
import '../pantallas/partido_pantalla.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Modos para jugar con amigos pasándose el dispositivo.
bool esModoAmigos(ModoJuego m) => const {ModoJuego.draftEnGrupo, ModoJuego.duelo}.contains(m);

/// Arranca una partida nueva: quiénes juegan y con qué franquicia, y después el draft por turnos.
Future<void> iniciarAmigos(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  final duelo = m == ModoJuego.duelo;
  final personas = await c.navegador.currentState!.push<List<(String, String)>>(
    MaterialPageRoute(
      builder: (_) => ConfigAmigosPantalla(duelo: duelo, enfocada: enfocada),
    ),
  );
  if (personas == null) return;
  final liga = await c.liga();
  final partida = Amigos(liga.catalogo).nueva(duelo: duelo, personas: personas);
  final t = Temporada(
    id: ContextoModos.nuevoId(),
    franquiciaUsuarioId: personas.first.$2,
    modoJuego: m,
    datosModo: partida.toJson(),
  );
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// Pantalla propia del modo para la partida [t], o null si no es una partida entre amigos.
Future<Widget?> pantallaAmigos(Temporada t, ContextoModos c) async {
  if (!esModoAmigos(t.modoJuego) || PartidaAmigos.de(t) == null) return null;
  final liga = await c.liga();
  return AmigosPantalla(temporada: t, catalogo: liga.catalogo, onGuardar: c.guardar);
}

List<Franquicia> get _oficiales => [
  for (final f in franquicias)
    if (!f.historica) f,
];

// ─────────────────────────────────────────── Configuración ───────────────────────────────────────────

/// Quiénes juegan (2 a 8 en el grupo, 2 en el duelo), cómo se llaman y con qué franquicia.
/// Devuelve la lista de (nombre, franquicia) o null si se cierra.
class ConfigAmigosPantalla extends StatefulWidget {
  const ConfigAmigosPantalla({super.key, required this.duelo, required this.enfocada});

  final bool duelo;
  final Franquicia enfocada;

  @override
  State<ConfigAmigosPantalla> createState() => _ConfigAmigosPantallaState();
}

class _ConfigAmigosPantallaState extends State<ConfigAmigosPantalla> {
  late var _cantidad = widget.duelo ? 2 : 4;
  final _nombres = [for (var i = 0; i < 8; i++) TextEditingController()];
  late final _franquicias = () {
    final otras = _oficiales.where((f) => f.id != widget.enfocada.id).toList()..shuffle();
    return [widget.enfocada.id, for (final f in otras.take(7)) f.id];
  }();

  @override
  void dispose() {
    for (final c in _nombres) {
      c.dispose();
    }
    super.dispose();
  }

  String _nombre(int i) => _nombres[i].text.trim().isEmpty ? 'Jugador ${i + 1}' : _nombres[i].text.trim();

  void _elegirFranquicia(int i, String id) {
    setState(() {
      // Si otro ya la tenía, intercambian.
      final j = _franquicias.indexOf(id);
      if (j >= 0) _franquicias[j] = _franquicias[i];
      _franquicias[i] = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.duelo ? 'Duelo' : 'Draft en grupo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                widget.duelo
                    ? 'Dos personas, un dispositivo. Draft alternado y serie al mejor de 7.'
                    : 'De 2 a 8 personas eligen por turnos en serpiente, juegan una liga ida y vuelta y '
                          'los dos primeros van a la final.',
                style: tema.textTheme.bodyMedium,
              ),
              if (!widget.duelo) ...[
                const SizedBox(height: 16),
                Text('¿CUÁNTOS SON?', style: tema.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var n = 2; n <= 8; n++)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: _cantidad == n,
                        onSelected: (_) => setState(() => _cantidad = n),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              for (var i = 0; i < _cantidad; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(width: 44, child: Center(child: Escudo(franquiciaPorId(_franquicias[i]), tamano: 40))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nombres[i],
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Jugador ${i + 1}',
                            hintText: 'Nombre',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _franquicias[i],
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final f in _oficiales) DropdownMenuItem(value: f.id, child: TextoLed(f.id, tamano: 18)),
                        ],
                        onChanged: (id) => id == null ? null : _elegirFranquicia(i, id),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('EMPEZAR EL DRAFT'),
                onPressed: () =>
                    Navigator.of(context).pop([for (var i = 0; i < _cantidad; i++) (_nombre(i), _franquicias[i])]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────── Partida ───────────────────────────────────────────

/// La partida entre amigos de punta a punta: draft por turnos, tácticas, liga o serie y campeón.
class AmigosPantalla extends StatefulWidget {
  const AmigosPantalla({super.key, required this.temporada, required this.catalogo, required this.onGuardar});

  final Temporada temporada;
  final List<Jugador> catalogo;
  final Future<void> Function(Temporada t) onGuardar;

  @override
  State<AmigosPantalla> createState() => _AmigosPantallaState();
}

class _AmigosPantallaState extends State<AmigosPantalla> {
  late Temporada _t = widget.temporada;
  late PartidaAmigos _p = PartidaAmigos.de(_t)!;
  late final _a = Amigos(widget.catalogo);
  var _ocupado = false;

  /// Táctica: quién ya confirmó que tiene el dispositivo (no se guarda: al volver, se pasa de nuevo).
  int? _tacticaVista;

  void _cambiar(PartidaAmigos p) {
    setState(() {
      _p = p;
      _t = _t.conAmigos(p);
    });
    widget.onGuardar(_t);
  }

  Franquicia _f(int i) => franquiciaPorId(_p.participantes[i].franquiciaId);

  Future<void> _vivo(PartidoAmigos x) async {
    final antes = _p;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: _a.motor(antes, x, usuarioLocal: true),
          usuarioLocal: true,
          franquiciaUsuario: _f(x.local),
          identidadLocal: _f(x.local),
          identidadVisitante: _f(x.visitante),
          onTerminado: (MotorPartido m) {
            if (mounted && identical(_p, antes)) _cambiar(_a.registrar(antes, m));
          },
        ),
      ),
    );
  }

  Future<void> _simular({required bool todo}) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    final p = todo ? _a.simularFase(_p) : _a.simularProximo(_p);
    if (!mounted) return;
    _ocupado = false;
    _cambiar(p);
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _p.duelo ? 'Duelo' : 'Draft en grupo';
    final cuerpo = switch (_p.fase) {
      FaseAmigos.draft when !_p.turnoVisto => _PasarDispositivo(
        participante: _p.participantes[_p.eligeAhora],
        detalle: 'Ronda ${_p.ronda} de ${Posicion.values.length} · elección ${_p.turno + 1} de ${_p.totalElecciones}',
        onListo: () => _cambiar(_a.verTurno(_p)),
      ),
      FaseAmigos.draft => _TurnoDraft(
        partida: _p,
        candidatos: _a.candidatos(_p),
        onElegir: (j, pos) => _cambiar(_a.elegir(_p, j, pos)),
        onOtras: () => _cambiar(_a.otrasCartas(_p)),
      ),
      FaseAmigos.tacticas when _tacticaVista != _p.pendienteDeTactica => _PasarDispositivo(
        participante: _p.participantes[_p.pendienteDeTactica!],
        detalle: 'Ahora, tu táctica',
        onListo: () => setState(() => _tacticaVista = _p.pendienteDeTactica),
      ),
      FaseAmigos.tacticas => _ElegirTactica(
        participante: _p.participantes[_p.pendienteDeTactica!],
        recomendada: _a.recomendada(_p, _p.pendienteDeTactica!),
        onConfirmar: (t) => _cambiar(_a.confirmarTactica(_p, _p.pendienteDeTactica!, t)),
      ),
      FaseAmigos.liga => _VistaLiga(
        partida: _p,
        proximo: _a.proximo(_p)!,
        ocupado: _ocupado,
        onVivo: _vivo,
        onSimular: () => _simular(todo: false),
        onSimularTodo: () => _simular(todo: true),
      ),
      FaseAmigos.serie => _VistaSerie(
        partida: _p,
        serie: _p.serie!,
        ocupado: _ocupado,
        onVivo: _vivo,
        onSimular: () => _simular(todo: false),
        onSimularTodo: () => _simular(todo: true),
      ),
      FaseAmigos.terminada => _Campeon(partida: _p),
    };
    // Cada turno se ve con los colores de quien tiene el dispositivo.
    final tema = switch (_p.fase) {
      FaseAmigos.draft => temaFranquicia(_f(_p.eligeAhora)),
      FaseAmigos.tacticas => temaFranquicia(_f(_p.pendienteDeTactica!)),
      FaseAmigos.terminada => temaFranquicia(_f(_p.campeon!)),
      _ => Theme.of(context),
    };
    return Theme(
      data: tema,
      child: Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: SafeArea(child: cuerpo),
      ),
    );
  }
}

/// "Le toca a Martín. Pasale el dispositivo."
class _PasarDispositivo extends StatelessWidget {
  const _PasarDispositivo({required this.participante, required this.detalle, required this.onListo});

  final Participante participante;
  final String detalle;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final f = franquiciaPorId(participante.franquiciaId);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Escudo(f, tamano: 120),
            const SizedBox(height: 20),
            Text('LE TOCA A', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            FittedBox(child: TextoLed(participante.nombre.toUpperCase(), tamano: 44)),
            const SizedBox(height: 8),
            Text(f.nombreCompleto, style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(detalle, style: tema.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Text('Pasale el dispositivo.', style: tema.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onListo,
              icon: const Icon(Icons.front_hand_outlined),
              label: Text('SOY ${participante.nombre.toUpperCase()}, ESTOY LISTO'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turno del draft: las cartas del turno, a qué puesto va y el tablero de todos.
class _TurnoDraft extends StatefulWidget {
  const _TurnoDraft({required this.partida, required this.candidatos, required this.onElegir, required this.onOtras});

  final PartidaAmigos partida;
  final List<Jugador> candidatos;
  final void Function(Jugador j, Posicion pos) onElegir;
  final VoidCallback onOtras;

  @override
  State<_TurnoDraft> createState() => _TurnoDraftState();
}

class _TurnoDraftState extends State<_TurnoDraft> {
  Jugador? _elegida;
  Posicion? _puesto;

  @override
  void didUpdateWidget(_TurnoDraft old) {
    super.didUpdateWidget(old);
    if (old.partida.turno != widget.partida.turno || old.partida.candidatos != widget.partida.candidatos) {
      _elegida = null;
      _puesto = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final p = widget.partida;
    final yo = p.participantes[p.eligeAhora];
    final puestos = _elegida == null ? const <Posicion>[] : yo.plantel.posicionesDisponiblesPara(_elegida!);

    final eleccion = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Escudo(franquiciaPorId(yo.franquiciaId), tamano: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Elige ${yo.nombre}',
                style: tema.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextoLed('R${p.ronda}', tamano: 22),
          ],
        ),
        const SizedBox(height: 8),
        _PlantelCompacto(participante: yo),
        const SizedBox(height: 12),
        Text('TOCÁ UNA CARTA', style: tema.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final j in widget.candidatos)
              SizedBox(
                width: CartaJugador.ancho,
                child: CartaJugador(
                  jugador: j,
                  seleccionada: _elegida?.id == j.id,
                  onTap: () => setState(() {
                    _elegida = j;
                    final libres = yo.plantel.posicionesDisponiblesPara(j);
                    _puesto = libres.isEmpty ? null : libres.first;
                  }),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_elegida != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pos in puestos)
                ChoiceChip(
                  label: Text(pos.etiqueta),
                  selected: _puesto == pos,
                  onSelected: (_) => setState(() => _puesto = pos),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _puesto == null ? null : () => widget.onElegir(_elegida!, _puesto!),
            child: Text(
              'FICHAR A ${_elegida!.nombre.toUpperCase()}${_puesto == null ? '' : ' COMO ${_puesto!.etiqueta.toUpperCase()}'}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
        TextButton.icon(
          onPressed: yo.sorteos > 0 ? widget.onOtras : null,
          icon: const Icon(Icons.refresh),
          label: Text(yo.sorteos > 0 ? 'OTRAS CARTAS (${yo.sorteos})' : 'SIN CAMBIOS DE CARTAS'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth >= 900;
        if (ancho) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: eleccion),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _Tablero(partida: p),
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              eleccion,
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text('Tablero del draft'),
                tilePadding: EdgeInsets.zero,
                children: [_Tablero(partida: p)],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Los 6 puestos de un plantel, en una línea por puesto.
class _PlantelCompacto extends StatelessWidget {
  const _PlantelCompacto({required this.participante});

  final Participante participante;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final pos in Posicion.values)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(
              '${pos.etiqueta}: ${participante.plantel.en(pos)?.nombre ?? '—'}',
              style: tema.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Todos los planteles, para ver qué se llevó cada uno.
class _Tablero extends StatelessWidget {
  const _Tablero({required this.partida});

  final PartidaAmigos partida;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('TABLERO DEL DRAFT', style: tema.textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final (i, x) in partida.participantes.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Escudo(franquiciaPorId(x.franquiciaId), tamano: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        x.nombre,
                        style: tema.textTheme.titleSmall?.copyWith(
                          color: i == partida.eligeAhora && partida.fase == FaseAmigos.draft
                              ? tema.colorScheme.primary
                              : null,
                        ),
                      ),
                      Text(
                        x.plantel.jugadores.isEmpty
                            ? 'Sin fichajes'
                            : [for (final j in x.plantel.jugadores) '${j.nombre} ${j.media}'].join(' · '),
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Táctica de cada persona: la recomendada del playbook o una a mano.
class _ElegirTactica extends StatefulWidget {
  const _ElegirTactica({required this.participante, required this.recomendada, required this.onConfirmar});

  final Participante participante;
  final Tactica recomendada;
  final ValueChanged<Tactica> onConfirmar;

  @override
  State<_ElegirTactica> createState() => _ElegirTacticaState();
}

class _ElegirTacticaState extends State<_ElegirTactica> {
  late var _ofensiva = widget.recomendada.ofensiva;
  late var _defensiva = widget.recomendada.defensiva;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('La táctica de ${widget.participante.nombre}', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            _PlantelCompacto(participante: widget.participante),
            const SizedBox(height: 16),
            Text('OFENSIVA', style: tema.textTheme.labelLarge),
            RadioGroup<SistemaOfensivo>(
              groupValue: _ofensiva,
              onChanged: (v) => setState(() => _ofensiva = v!),
              child: Column(
                children: [
                  for (final o in SistemaOfensivo.values)
                    RadioListTile<SistemaOfensivo>(
                      value: o,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(o.nombre + (o == widget.recomendada.ofensiva ? ' · recomendada' : '')),
                      subtitle: Text(o.descripcion),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('DEFENSIVA', style: tema.textTheme.labelLarge),
            RadioGroup<EsquemaDefensivo>(
              groupValue: _defensiva,
              onChanged: (v) => setState(() => _defensiva = v!),
              child: Column(
                children: [
                  for (final d in EsquemaDefensivo.values)
                    RadioListTile<EsquemaDefensivo>(
                      value: d,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(d.nombre + (d == widget.recomendada.defensiva ? ' · recomendada' : '')),
                      subtitle: Text(d.descripcion),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => widget.onConfirmar(Tactica(ofensiva: _ofensiva, defensiva: _defensiva)),
              child: const Text('CONFIRMAR TÁCTICA'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Próximo partido con sus botones (en vivo, simular, simular todo).
class _ProximoAmigos extends StatelessWidget {
  const _ProximoAmigos({
    required this.partida,
    required this.partido,
    required this.titulo,
    required this.textoTodo,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onSimularTodo,
  });

  final PartidaAmigos partida;
  final PartidoAmigos partido;
  final String titulo, textoTodo;
  final bool ocupado;
  final ValueChanged<PartidoAmigos> onVivo;
  final VoidCallback onSimular, onSimularTodo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final l = partida.participantes[partido.local], v = partida.participantes[partido.visitante];
    Widget lado(Participante x) => Expanded(
      child: Column(
        children: [
          Escudo(franquiciaPorId(x.franquiciaId), tamano: 56),
          const SizedBox(height: 6),
          Text(x.nombre, style: tema.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          TextoLed(x.franquiciaId, tamano: 16),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo.toUpperCase(), style: tema.textTheme.labelLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              children: [
                lado(l),
                Text('vs', style: tema.textTheme.titleLarge),
                lado(v),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'De local: ${l.nombre}. En vivo, la jugada clave la elige el local.',
              style: tema.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: ocupado ? null : () => onVivo(partido),
              icon: const Icon(Icons.play_arrow),
              label: const Text('JUGAR EN VIVO'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: ocupado ? null : onSimular, child: const Text('SIMULAR')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: ocupado ? null : onSimularTodo,
                    child: FittedBox(child: Text(textoTodo)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Liga del grupo: tabla con LED, próximo partido y resultados.
class _VistaLiga extends StatelessWidget {
  const _VistaLiga({
    required this.partida,
    required this.proximo,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onSimularTodo,
  });

  final PartidaAmigos partida;
  final PartidoAmigos proximo;
  final bool ocupado;
  final ValueChanged<PartidoAmigos> onVivo;
  final VoidCallback onSimular, onSimularTodo;

  @override
  Widget build(BuildContext context) {
    final jugados = partida.liga.where((p) => p.jugado).length;
    final proximoCard = _ProximoAmigos(
      partida: partida,
      partido: proximo,
      titulo: 'Liga · partido ${jugados + 1} de ${partida.liga.length}',
      textoTodo: 'SIMULAR LA LIGA',
      ocupado: ocupado,
      onVivo: onVivo,
      onSimular: onSimular,
      onSimularTodo: onSimularTodo,
    );
    final tabla = _TablaAmigos(partida: partida);
    final resultados = _Resultados(partida: partida, partidos: partida.liga.where((p) => p.jugado).toList().reversed);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [proximoCard, resultados]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [tabla]),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [proximoCard, const SizedBox(height: 12), tabla, const SizedBox(height: 12), resultados],
        );
      },
    );
  }
}

class _TablaAmigos extends StatelessWidget {
  const _TablaAmigos({required this.partida});

  final PartidaAmigos partida;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final filas = partida.tabla();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('TABLA', style: tema.textTheme.labelLarge),
            Text('Los dos primeros juegan la final al mejor de 3.', style: tema.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final (pos, f) in filas.indexed) ...[
              if (pos == 2) const Divider(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 22, child: TextoLed('${pos + 1}', tamano: 16)),
                    Escudo(franquiciaPorId(partida.participantes[f.indice].franquiciaId), tamano: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        partida.participantes[f.indice].nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.titleSmall,
                      ),
                    ),
                    TextoLed('${f.victorias}-${f.derrotas}', tamano: 20),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 48,
                      child: Text(
                        f.diferencia > 0 ? '+${f.diferencia}' : '${f.diferencia}',
                        textAlign: TextAlign.end,
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Resultados extends StatelessWidget {
  const _Resultados({required this.partida, required this.partidos});

  final PartidaAmigos partida;
  final Iterable<PartidoAmigos> partidos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (partidos.isEmpty) return const SizedBox.shrink();
    String n(int i) => partida.participantes[i].nombre;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RESULTADOS', style: tema.textTheme.labelLarge),
          for (final p in partidos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${n(p.local)} vs ${n(p.visitante)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  TextoLed('${p.puntosLocal}-${p.puntosVisitante}', tamano: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// El duelo (al mejor de 7) o la final del grupo (al mejor de 3).
class _VistaSerie extends StatelessWidget {
  const _VistaSerie({
    required this.partida,
    required this.serie,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onSimularTodo,
  });

  final PartidaAmigos partida;
  final SerieAmigos serie;
  final bool ocupado;
  final ValueChanged<PartidoAmigos> onVivo;
  final VoidCallback onSimular, onSimularTodo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final a = partida.participantes[serie.alto], b = partida.participantes[serie.bajo];
    final nombreSerie = partida.duelo ? 'Duelo · al mejor de 7' : 'La final · al mejor de 3';
    Widget lado(Participante x, int i) => Expanded(
      child: Column(
        children: [
          Escudo(franquiciaPorId(x.franquiciaId), tamano: 64),
          const SizedBox(height: 6),
          Text(x.nombre, style: tema.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          TextoLed('${serie.victoriasDe(i)}', tamano: 56),
        ],
      ),
    );
    final marcador = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(nombreSerie.toUpperCase(), style: tema.textTheme.labelLarge),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                lado(a, serie.alto),
                Padding(padding: const EdgeInsets.only(bottom: 16), child: TextoLed('-', tamano: 40)),
                lado(b, serie.bajo),
              ],
            ),
          ],
        ),
      ),
    );
    final proximo = _ProximoAmigos(
      partida: partida,
      partido: serie.proximo,
      titulo: 'Juego ${serie.juegos.length + 1}',
      textoTodo: 'SIMULAR LA SERIE',
      ocupado: ocupado,
      onVivo: onVivo,
      onSimular: onSimular,
      onSimularTodo: onSimularTodo,
    );
    final resultados = _Resultados(partida: partida, partidos: serie.juegos.reversed);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [marcador, resultados]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [proximo]),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [marcador, const SizedBox(height: 12), proximo, resultados],
        );
      },
    );
  }
}

/// El campeón y cómo llegó.
class _Campeon extends StatelessWidget {
  const _Campeon({required this.partida});

  final PartidaAmigos partida;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final serie = partida.serie!;
    final g = partida.campeon!;
    final perdedor = g == serie.alto ? serie.bajo : serie.alto;
    final x = partida.participantes[g];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.emoji_events, size: 72, color: tema.colorScheme.primary),
            const SizedBox(height: 8),
            Center(child: Escudo(franquiciaPorId(x.franquiciaId), tamano: 96)),
            const SizedBox(height: 12),
            Center(child: FittedBox(child: TextoLed('¡${x.nombre.toUpperCase()} CAMPEÓN!', tamano: 36))),
            const SizedBox(height: 8),
            Text(
              '${partida.duelo ? 'Ganó el duelo' : 'Ganó la final'} ${serie.victoriasDe(g)}-${serie.victoriasDe(perdedor)} '
              'contra ${partida.participantes[perdedor].nombre}.',
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _PlantelCompacto(participante: x),
            if (!partida.duelo) ...[const SizedBox(height: 16), _TablaAmigos(partida: partida)],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('VOLVER AL INICIO'),
            ),
          ],
        ),
      ),
    );
  }
}
