import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/draft.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/misiones.dart';
import '../../domain/entities/metajuego.dart';
import '../../domain/modos/competitivo.dart';
import '../../domain/modos/escalera.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'competitivo_comun.dart';
import 'elegir_alineacion.dart';
import 'modos.dart';

/// Arranca el Creador de torneos: se arma el torneo y se juega como una partida más.
Future<void> iniciarCreadorDeTorneos(Franquicia enfocada, ContextoModos c, Liga liga) async {
  final modos = ModosCompetitivo(liga, perfil: () => perfilApp.value);
  final torneo = await Navigator.of(c.context).push<Torneo>(
    MaterialPageRoute(
      builder: (_) => ConfigTorneoPantalla(
        modos: modos,
        franquiciaId: enfocada.id,
        partidas: () async => await c.db?.temporadas() ?? const [],
      ),
    ),
  );
  if (torneo == null) return;
  final t = modos.nuevoTorneo(id: ContextoModos.nuevoId(), franquiciaId: enfocada.id, torneo: torneo);
  await c.guardar(t);
  await c.abrirTemporada(t);
}

// ═══════════════════════════════════════ Armado del torneo ══════════════════════════════════════

class ConfigTorneoPantalla extends StatefulWidget {
  const ConfigTorneoPantalla({super.key, required this.modos, required this.franquiciaId, required this.partidas});

  final ModosCompetitivo modos;

  /// La franquicia con la que jugás (el escudo de tu equipo).
  final String franquiciaId;

  /// Tus partidas guardadas (para usar sus planteles).
  final Future<List<Temporada>> Function() partidas;

  @override
  State<ConfigTorneoPantalla> createState() => _ConfigTorneoPantallaState();
}

class _ConfigTorneoPantallaState extends State<ConfigTorneoPantalla> {
  final _nombre = TextEditingController(text: 'Mi torneo');
  var _formato = FormatoTorneo.eliminacion;
  var _aGanar = 1;
  final _equipos = <EquipoTorneo>[];

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Set<int> get _excluidos => {
    for (final e in _equipos)
      for (final id in e.rival.cartaIds.values) ?widget.modos.jugador(id)?.nbaPlayerId,
  };

  String? get _error => Torneo.validar(_formato, _equipos.length);

  bool _agregar(EquipoTorneo e) {
    if (_equipos.any((x) => x.nombre == e.nombre)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('${e.nombre} ya está en el torneo.')));
      return false;
    }
    if (_equipos.length >= Torneo.maximoEquipos) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('El torneo ya tiene el máximo de equipos.')));
      return false;
    }
    setState(() {
      if (e.usuario) _equipos.removeWhere((x) => x.usuario);
      _equipos.add(e);
    });
    return true;
  }

  Future<void> _abrirAgregar() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _AgregarEquipo(
      modos: widget.modos,
      franquiciaId: widget.franquiciaId,
      partidas: widget.partidas,
      excluidos: () => _excluidos,
      yaEsta: (nombre) => _equipos.any((e) => e.nombre == nombre),
      agregar: _agregar,
    ),
  );

  void _autocompletar(int hasta) {
    final azar = Random();
    final ids = [
      for (final f in franquicias)
        if (!f.historica) f.id,
    ]..shuffle(azar);
    final tope = _formato == FormatoTorneo.liga ? min(hasta, Torneo.maximoLiga) : hasta;
    for (final id in ids) {
      if (_equipos.length >= tope) break;
      final nombre = '${franquiciaPorId(id).nombreCompleto} (Histórico)';
      if (_equipos.any((e) => e.nombre == nombre)) continue;
      final r = widget.modos.esc.rivalTodosLosTiempos(id, _excluidos);
      if (r != null) _agregar(EquipoTorneo(nombre: nombre, rival: r));
    }
  }

  void _crear() {
    final error = _error;
    if (error != null) return;
    final nombre = _nombre.text.trim().isEmpty ? 'Mi torneo' : _nombre.text.trim();
    Navigator.of(context).pop(
      Torneo.crear(
        nombre: nombre,
        formato: _formato,
        equipos: _equipos,
        aGanar: _formato == FormatoTorneo.liga ? 1 : _aGanar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final error = _error;
    final hayUsuario = _equipos.any((e) => e.usuario);

    final ajustes = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nombre,
          maxLength: 28,
          decoration: const InputDecoration(labelText: 'Nombre del torneo', counterText: ''),
        ),
        const SizedBox(height: 12),
        Text('FORMATO', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
        const SizedBox(height: 6),
        SegmentedButton<FormatoTorneo>(
          segments: [
            for (final f in FormatoTorneo.values)
              ButtonSegment(
                value: f,
                label: FittedBox(child: Text(f.nombre, maxLines: 1)),
              ),
          ],
          selected: {_formato},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _formato = s.first),
        ),
        const SizedBox(height: 4),
        Text(_formato.descripcion, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
        if (_formato != FormatoTorneo.liga) ...[
          const SizedBox(height: 12),
          Text('CADA CRUCE DEL CUADRO', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Único')),
              ButtonSegment(value: 2, label: Text('Al mejor de 3')),
              ButtonSegment(value: 3, label: Text('De 5')),
              ButtonSegment(value: 4, label: Text('De 7')),
            ],
            selected: {_aGanar},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _aGanar = s.first),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: error == null ? _crear : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('CREAR TORNEO'),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error, style: tema.textTheme.bodySmall?.copyWith(color: esquema.error)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            hayUsuario
                ? 'Jugás con tu equipo: vos manejás tus partidos.'
                : 'Sin tu equipo vas a mirar el torneo: simulás ronda por ronda.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ),
      ],
    );

    final lista = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'EQUIPOS · ${_equipos.length}/${Torneo.maximoEquipos}',
                style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary),
              ),
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _abrirAgregar,
              icon: const Icon(Icons.add),
              label: const Text('AGREGAR'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final n in const [8, 16, 32])
              ActionChip(label: Text('Completar a $n'), onPressed: () => _autocompletar(n)),
            if (_equipos.isNotEmpty) ActionChip(label: const Text('Vaciar'), onPressed: () => setState(_equipos.clear)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _equipos.isEmpty
              ? Center(
                  child: Text(
                    'Agregá equipos: franquicias, planteles históricos, tus partidas o tu equipo del álbum.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                )
              : ListView(
                  children: [
                    for (final (i, e) in _equipos.indexed)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          dense: true,
                          leading: Escudo(franquiciaPorId(e.rival.identidadId), tamano: 30),
                          title: Text(e.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Media ${e.media.toStringAsFixed(1)}${e.usuario ? ' · tu equipo' : ''}'),
                          trailing: IconButton(
                            tooltip: 'Sacar a ${e.nombre}',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _equipos.removeAt(i)),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Creador de torneos')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 420, child: SingleChildScrollView(child: ajustes)),
                    const SizedBox(width: 24),
                    Expanded(child: lista),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: [
                    Flexible(flex: 0, child: SingleChildScrollView(child: ajustes)),
                    const Divider(height: 24),
                    Expanded(child: lista),
                  ],
                ),
              ),
      ),
    );
  }
}

enum _Fuente { menu, franquicias, epocas, mejores, partidas }

class _AgregarEquipo extends StatefulWidget {
  const _AgregarEquipo({
    required this.modos,
    required this.franquiciaId,
    required this.partidas,
    required this.excluidos,
    required this.yaEsta,
    required this.agregar,
  });

  final ModosCompetitivo modos;
  final String franquiciaId;
  final Future<List<Temporada>> Function() partidas;
  final Set<int> Function() excluidos;
  final bool Function(String nombre) yaEsta;
  final bool Function(EquipoTorneo) agregar;

  @override
  State<_AgregarEquipo> createState() => _AgregarEquipoState();
}

class _AgregarEquipoState extends State<_AgregarEquipo> {
  var _fuente = _Fuente.menu;
  Franquicia? _franquicia;
  late final Future<List<Temporada>> _partidas = widget.partidas();

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _delAlbum() async {
    final liga = widget.modos.liga;
    final album = perfilApp.value.coleccion;
    if (!Draft.coleccionAlcanza(liga.catalogo, album)) {
      _aviso('Tu álbum todavía no alcanza para armar los 6 puestos.');
      return;
    }
    final cartas = await Navigator.of(context).push<Map<Posicion, String>>(
      MaterialPageRoute(
        builder: (_) => ElegirAlineacionPantalla(
          pool: [
            for (final j in liga.catalogo)
              if (album.contains(j.id)) j,
          ],
          titulo: 'Tu equipo del torneo',
          ayuda: 'Es el equipo que vas a jugar vos.',
        ),
      ),
    );
    if (cartas == null || !mounted) return;
    final r = widget.modos.rivalDeAlineacion(cartas, widget.franquiciaId, '(mi equipo)');
    if (widget.agregar(EquipoTorneo(nombre: 'Mi equipo', rival: r, usuario: true)) && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _franquiciaHistorica(Franquicia f) {
    final nombre = '${f.nombreCompleto} (Histórico)';
    if (widget.yaEsta(nombre)) return _aviso('$nombre ya está en el torneo.');
    final r = widget.modos.esc.rivalTodosLosTiempos(f.id, widget.excluidos());
    if (r == null) return _aviso('No alcanzan las cartas de ${f.nombre}.');
    if (widget.agregar(EquipoTorneo(nombre: nombre, rival: r))) setState(() {});
  }

  void _epoca(Franquicia f, Epoca e) {
    final nombre = '${f.nombreCompleto} (${e.corta})';
    if (widget.yaEsta(nombre)) return _aviso('$nombre ya está en el torneo.');
    final r = widget.modos.rivalMejorDeEpoca(f.id, e, widget.excluidos());
    if (r == null) return _aviso('Esa franquicia no tiene plantel completo en esa época.');
    if (widget.agregar(EquipoTorneo(nombre: nombre, rival: r))) setState(() {});
  }

  void _mejor(EquipoHistorico h) {
    final nombre = '${franquiciaPorId(h.identidadId).nombreCompleto} ${h.etiqueta}';
    if (widget.yaEsta(nombre)) return _aviso('$nombre ya está en el torneo.');
    if (widget.agregar(EquipoTorneo(nombre: nombre, rival: widget.modos.esc.rivalHistorico(h)))) setState(() {});
  }

  void _partida(Temporada t) {
    final f = franquiciaPorId(t.franquiciaUsuarioId);
    final r = widget.modos.rivalDePlantel(t.plantel, t.franquiciaUsuarioId, '');
    if (r == null) return;
    var nombre = '${f.nombreCompleto} (mi partida)';
    var n = 2;
    while (widget.yaEsta(nombre)) {
      nombre = '${f.nombreCompleto} (mi partida $n)';
      n++;
    }
    if (widget.agregar(EquipoTorneo(nombre: nombre, rival: r))) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final liga = widget.modos.liga;
    final actuales = [
      for (final f in liga.franquicias)
        if (!f.historica) f,
    ];

    Widget titulo(String t, {bool atras = true}) => Row(
      children: [
        if (atras)
          IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
              if (_fuente == _Fuente.epocas && _franquicia != null) {
                _franquicia = null;
              } else {
                _fuente = _Fuente.menu;
              }
            }),
          ),
        Expanded(child: Text(t.toUpperCase(), style: tema.textTheme.headlineSmall)),
      ],
    );

    final cuerpo = switch (_fuente) {
      _Fuente.menu => [
        titulo('Agregar equipo', atras: false),
        const SizedBox(height: 8),
        for (final (icono, nombre, detalle, accion) in <(IconData, String, String, VoidCallback)>[
          (
            Icons.shield_outlined,
            'Franquicias actuales',
            'Lo mejor de toda la historia de cada una.',
            () => setState(() => _fuente = _Fuente.franquicias),
          ),
          (
            Icons.history,
            'Planteles de una época',
            'El mejor equipo de una franquicia en una década.',
            () => setState(() => _fuente = _Fuente.epocas),
          ),
          (
            Icons.military_tech_outlined,
            'Los mejores de la historia',
            'Bulls 96, Celtics 86, Warriors 2017…',
            () => setState(() => _fuente = _Fuente.mejores),
          ),
          (
            Icons.folder_outlined,
            'Mis partidas',
            'El plantel de una temporada que armaste.',
            () => setState(() => _fuente = _Fuente.partidas),
          ),
          (Icons.style_outlined, 'Mi equipo del álbum', 'El que jugás vos. Solo uno por torneo.', _delAlbum),
        ])
          ListTile(
            leading: Icon(icono, color: esquema.primary),
            title: Text(nombre),
            subtitle: Text(detalle),
            trailing: const Icon(Icons.chevron_right),
            onTap: accion,
          ),
      ],
      _Fuente.franquicias => [
        titulo('Franquicias'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in actuales)
              FilterChip(
                avatar: Escudo(f, tamano: 20),
                label: Text(f.id),
                tooltip: f.nombreCompleto,
                selected: widget.yaEsta('${f.nombreCompleto} (Histórico)'),
                onSelected: (_) => _franquiciaHistorica(f),
              ),
          ],
        ),
      ],
      _Fuente.epocas when _franquicia == null => [
        titulo('¿De qué franquicia?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in actuales)
              ActionChip(
                avatar: Escudo(f, tamano: 20),
                label: Text(f.id),
                tooltip: f.nombreCompleto,
                onPressed: () => setState(() => _franquicia = f),
              ),
          ],
        ),
      ],
      _Fuente.epocas => [
        titulo('${_franquicia!.nombreCompleto}: ¿qué época?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in Epoca.values.skip(1))
              FilterChip(
                label: Text(e.etiqueta),
                selected: widget.yaEsta('${_franquicia!.nombreCompleto} (${e.corta})'),
                onSelected: (_) => _epoca(_franquicia!, e),
              ),
          ],
        ),
      ],
      _Fuente.mejores => [
        titulo('Los mejores de la historia'),
        for (final h in mejoresEquipos)
          ListTile(
            leading: Escudo(franquiciaPorId(h.identidadId), tamano: 28),
            title: Text('${franquiciaPorId(h.identidadId).nombreCompleto} ${h.etiqueta}'),
            trailing: widget.yaEsta('${franquiciaPorId(h.identidadId).nombreCompleto} ${h.etiqueta}')
                ? Icon(Icons.check, color: esquema.primary)
                : const Icon(Icons.add),
            onTap: () => _mejor(h),
          ),
      ],
      _Fuente.partidas => [
        titulo('Mis partidas'),
        FutureBuilder<List<Temporada>>(
          future: _partidas,
          builder: (context, snap) {
            final lista = [
              for (final t in snap.data ?? const <Temporada>[])
                if (t.plantel.completo) t,
            ];
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (lista.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No tenés partidas con plantel completo todavía.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                ),
              );
            }
            return Column(
              children: [
                for (final t in lista)
                  ListTile(
                    leading: Escudo(franquiciaPorId(t.franquiciaUsuarioId), tamano: 28),
                    title: Text('${franquiciaPorId(t.franquiciaUsuarioId).nombreCompleto} · ${t.modoJuego.nombre}'),
                    subtitle: Text(
                      t.plantel.titulares.map((j) => apellidoCorto(j)).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.add),
                    onTap: () => _partida(t),
                  ),
              ],
            );
          },
        ),
      ],
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cuerpo),
    );
  }
}

/// "Knicks", "Pistons (90’)", "Bulls 1995-96": el nombre del equipo sin la ciudad, para los cruces.
String nombreCortoTorneo(EquipoTorneo e) {
  if (e.usuario) return e.nombre;
  final apodo = franquiciaPorId(e.rival.identidadId).nombre;
  final etiqueta = e.rival.etiqueta;
  return etiqueta.isEmpty || etiqueta == '(Histórico)' ? apodo : '$apodo $etiqueta';
}

String apellidoCorto(Jugador j) {
  final partes = j.nombre.split(' ');
  return partes.length > 1 ? partes.last : j.nombre;
}

// ═════════════════════════════════════════ El torneo ════════════════════════════════════════════

class TorneoPantalla extends StatefulWidget {
  const TorneoPantalla({
    super.key,
    required this.temporada,
    required this.liga,
    required this.onCambio,
    required this.onRepetir,
    this.azar,
  });

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  /// Arma otra partida con los mismos equipos y formato.
  final Future<void> Function(Temporada nueva) onRepetir;
  final Random? azar;

  @override
  State<TorneoPantalla> createState() => _TorneoPantallaState();
}

class _TorneoPantallaState extends State<TorneoPantalla> {
  late Temporada _t = widget.temporada;
  late final _modos = ModosCompetitivo(widget.liga, azar: widget.azar, perfil: () => perfilApp.value);
  var _ocupado = false;

  @override
  void didUpdateWidget(TorneoPantalla vieja) {
    super.didUpdateWidget(vieja);
    if (!identical(vieja.temporada, widget.temporada)) _t = widget.temporada;
  }

  Torneo get _torneo => Torneo.de(_t)!;
  Franquicia get _propia => franquiciaPorId(_t.franquiciaUsuarioId);

  void _guardar(Temporada t) {
    final (va, _) = _torneo.recordUsuario;
    final (vd, _) = Torneo.de(t)!.recordUsuario;
    if (vd > va) Misiones.anotar(TipoMision.ganarDesafio, vd - va);
    setState(() => _t = t);
    widget.onCambio(t);
  }

  Future<void> _vivo() async {
    final antes = _t;
    final torneo = _torneo;
    final l = torneo.pendienteUsuario!;
    final otro = torneo.usuario == l.a ? l.b : l.a;
    await jugarEnVivo(
      context,
      motor: _modos.motorTorneo(antes),
      propia: _propia,
      rival: franquiciaPorId(torneo.equipos[otro].rival.identidadId),
      alTerminar: (m) => _guardar(_modos.registrarTorneo(antes, m)),
    );
  }

  Future<void> _simular(Temporada Function(Temporada) f) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    _guardar(f(_t));
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _repetir() async {
    final viejo = _torneo;
    final nuevo = Torneo.crear(
      nombre: viejo.nombre,
      formato: viejo.formato,
      aGanar: viejo.aGanar,
      equipos: viejo.equipos,
    );
    final t = _modos.nuevoTorneo(id: ContextoModos.nuevoId(), franquiciaId: _t.franquiciaUsuarioId, torneo: nuevo);
    await widget.onRepetir(t);
  }

  @override
  Widget build(BuildContext context) {
    final torneo = _torneo;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final campeon = torneo.campeon;
    final pendiente = torneo.pendienteUsuario;

    final Widget accion;
    if (campeon != null) {
      accion = _Campeon(
        torneo: torneo,
        campeon: campeon,
        onRepetir: _repetir,
        onSalir: () => Navigator.of(context).popUntil((r) => r.isFirst),
      );
    } else if (pendiente != null) {
      final otro = torneo.usuario == pendiente.a ? pendiente.b : pendiente.a;
      final local = torneo.usuario == pendiente.a ? pendiente.aLocalProximo : !pendiente.aLocalProximo;
      accion = TarjetaRival(
        titulo: '${pendiente.fase}${pendiente.aGanar > 1 ? ' · juego ${pendiente.juegos.length + 1}' : ''}',
        rival: torneo.equipos[otro].rival,
        propia: _propia,
        liga: widget.liga,
        local: local,
        ocupado: _ocupado,
        onVivo: _vivo,
        onSimular: () => _simular(_modos.simularTorneo),
        detalle: pendiente.aGanar > 1
            ? 'serie ${torneo.usuario == pendiente.a ? pendiente.victoriasA : pendiente.victoriasB}-'
                  '${torneo.usuario == pendiente.a ? pendiente.victoriasB : pendiente.victoriasA}'
            : null,
        extra: [
          if (pendiente.aGanar > 1)
            TextButton(
              onPressed: _ocupado ? null : () => _simular(_modos.simularCruceTorneo),
              child: const Text('SIMULAR EL CRUCE'),
            ),
          TextButton(
            onPressed: _ocupado ? null : () => _simular(_modos.simularRestoTorneo),
            child: const Text('SIMULAR TODO EL TORNEO'),
          ),
        ],
      );
    } else {
      accion = Container(
        padding: const EdgeInsets.all(16),
        decoration: panelCompetitivo(esquema, resaltado: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              torneo.conUsuario ? 'TE ELIMINARON' : 'MIRANDO EL TORNEO',
              style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary),
            ),
            const SizedBox(height: 6),
            Text(
              torneo.conUsuario ? 'Seguí el resto del torneo desde afuera.' : 'Simulá de a una ronda o todo junto.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _ocupado ? null : () => _simular(_modos.simularRondaTorneo),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text('SIMULAR ${torneo.rondaActual == null ? 'LO QUE SIGUE' : 'LA RONDA'}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _ocupado ? null : () => _simular(_modos.simularRestoTorneo),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('SIMULAR TODO'),
            ),
          ],
        ),
      );
    }

    final encabezado = Container(
      padding: const EdgeInsets.all(16),
      decoration: panelCompetitivo(esquema),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(torneo.nombre.toUpperCase(), style: tema.textTheme.titleLarge),
                Text(
                  '${torneo.formato.nombre} · ${torneo.equipos.length} equipos'
                  '${torneo.formato == FormatoTorneo.liga ? '' : ' · ${torneo.aGanar == 1 ? 'partido único' : 'al mejor de ${torneo.aGanar * 2 - 1}'}'}',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (torneo.conUsuario) TextoLed('${torneo.recordUsuario.$1}-${torneo.recordUsuario.$2}', tamano: 30),
        ],
      ),
    );

    final contenido = _Cuadro(torneo: torneo);

    return Scaffold(
      appBar: AppBar(title: const Text('Creador de torneos')),
      backgroundColor: esquema.surface,
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 440, child: ListView(children: [encabezado, const SizedBox(height: 12), accion])),
                    const SizedBox(width: 24),
                    Expanded(child: ListView(children: [contenido])),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [encabezado, const SizedBox(height: 12), accion, const SizedBox(height: 12), contenido],
              ),
      ),
    );
  }
}

class _Campeon extends StatelessWidget {
  const _Campeon({required this.torneo, required this.campeon, required this.onRepetir, required this.onSalir});

  final Torneo torneo;
  final int campeon;
  final VoidCallback onRepetir, onSalir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = torneo.equipos[campeon];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelCompetitivo(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CAMPEÓN',
            textAlign: TextAlign.center,
            style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary),
          ),
          const SizedBox(height: 8),
          Center(child: Escudo(franquiciaPorId(e.rival.identidadId), tamano: 72)),
          const SizedBox(height: 8),
          Text(e.nombre, textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
          if (e.usuario)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('¡Ganaste tu torneo!', textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRepetir,
            icon: const Icon(Icons.replay),
            label: const Text('REPETIR EL TORNEO'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSalir,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('VOLVER AL INICIO'),
          ),
        ],
      ),
    );
  }
}

/// Las tablas (liga o grupos) y los cruces del cuadro.
class _Cuadro extends StatelessWidget {
  const _Cuadro({required this.torneo});

  final Torneo torneo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final fases = <String>[];
    for (final l in torneo.llaves) {
      if (l.ko && !fases.contains(l.fase)) fases.add(l.fase);
    }
    final r = torneo.rondaActual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (torneo.formato == FormatoTorneo.liga) _Tabla(torneo: torneo, fase: null, titulo: 'TABLA'),
        if (torneo.formato == FormatoTorneo.grupos)
          for (var k = 0; k < torneo.grupos.length; k++) ...[
            _Tabla(
              torneo: torneo,
              fase: 'Grupo ${String.fromCharCode(65 + k)}',
              titulo: 'GRUPO ${String.fromCharCode(65 + k)}',
            ),
            const SizedBox(height: 12),
          ],
        if (torneo.formato != FormatoTorneo.eliminacion && r != null && !torneo.llaves.any((l) => l.ko && l.ronda == r))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Fixture(
              titulo: 'FECHA ${r + 1}',
              torneo: torneo,
              llaves: [
                for (final l in torneo.llaves)
                  if (l.ronda == r && !l.ko) l,
              ],
            ),
          ),
        for (final f in fases) ...[
          const SizedBox(height: 12),
          _Fixture(
            titulo: f.toUpperCase(),
            torneo: torneo,
            llaves: [
              for (final l in torneo.llaves)
                if (l.ko && l.fase == f && !l.bye) l,
            ],
            pasan: [
              for (final l in torneo.llaves)
                if (l.ko && l.fase == f && l.bye) l.a,
            ],
          ),
        ],
        if (torneo.llaves.isEmpty)
          Text('Sin partidos.', style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.torneo, required this.fase, required this.titulo});

  final Torneo torneo;
  final String? fase;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final filas = torneo.tabla(fase);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: panelCompetitivo(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
          const SizedBox(height: 6),
          for (final (i, f) in filas.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: tema.textTheme.labelMedium)),
                  Escudo(franquiciaPorId(torneo.equipos[f.equipo].rival.identidadId), tamano: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      torneo.equipos[f.equipo].nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        fontWeight: torneo.usuario == f.equipo ? FontWeight.w800 : null,
                        color: torneo.usuario == f.equipo ? esquema.primary : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 56, child: TextoLed('${f.victorias}-${f.derrotas}', tamano: 14)),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${f.diferencia > 0 ? '+' : ''}${f.diferencia}',
                      textAlign: TextAlign.end,
                      style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Fixture extends StatelessWidget {
  const _Fixture({required this.titulo, required this.torneo, required this.llaves, this.pasan = const []});

  final String titulo;
  final Torneo torneo;
  final List<Llave> llaves;

  /// Equipos que pasan directo de esta ronda.
  final List<int> pasan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: panelCompetitivo(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
          const SizedBox(height: 6),
          for (final l in llaves) _FilaLlave(torneo: torneo, llave: l),
          if (pasan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pasan directo: ${pasan.map((i) => torneo.equipos[i].nombre).join(', ')}',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaLlave extends StatelessWidget {
  const _FilaLlave({required this.torneo, required this.llave});

  final Torneo torneo;
  final Llave llave;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final a = torneo.equipos[llave.a], b = torneo.equipos[llave.b];
    final nombreA = nombreCortoTorneo(a), nombreB = nombreCortoTorneo(b);
    final mia = torneo.usuario >= 0 && llave.involucra(torneo.usuario);
    final gana = llave.ganador;
    final marcador = llave.aGanar > 1
        ? '${llave.victoriasA}-${llave.victoriasB}'
        : (llave.juegos.isEmpty ? 'vs' : '${llave.juegos.first.$1}-${llave.juegos.first.$2}');
    TextStyle? estilo(int i) => tema.textTheme.bodyMedium?.copyWith(
      fontWeight: gana == i ? FontWeight.w800 : null,
      color: gana != null && gana != i ? esquema.onSurfaceVariant.withValues(alpha: 0.6) : null,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: mia
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: esquema.primary.withValues(alpha: 0.7)),
            )
          : null,
      child: Row(
        children: [
          Escudo(franquiciaPorId(a.rival.identidadId), tamano: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(nombreA, maxLines: 1, overflow: TextOverflow.ellipsis, style: estilo(llave.a)),
          ),
          SizedBox(width: 76, child: Center(child: TextoLed(marcador, tamano: 14))),
          Expanded(
            child: Text(
              nombreB,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: estilo(llave.b),
            ),
          ),
          const SizedBox(width: 6),
          Escudo(franquiciaPorId(b.rival.identidadId), tamano: 20),
        ],
      ),
    );
  }
}
