import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/fantasy.dart';
import '../widgets/disposicion.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Arranca un Fantasy NBA nuevo: elegís el año (o tu álbum), la dificultad y cuántos rivales.
Future<void> iniciarFantasy(ContextoModos c) async {
  final liga = await c.liga();
  final config = await c.navegador.currentState!.push<ConfigFantasy>(
    MaterialPageRoute(
      builder: (_) => FantasyConfigPantalla(catalogo: liga.catalogo, perfil: perfilApp.value),
    ),
  );
  if (config == null) return;
  final id = ContextoModos.nuevoId();
  final fantasy = Fantasy(liga.catalogo, perfil: perfilApp.value);
  final pool = config.anio == 0 ? fantasy.poolAlbum(perfilApp.value.coleccion) : fantasy.poolDelAnio(config.anio);
  final partida = fantasy.nueva(
    anio: config.anio,
    dificultad: config.dificultad,
    rivales: config.rivales,
    semilla: id.hashCode & 0x7fffffff,
    pool: pool,
    soloAlbum: config.anio == 0,
    nombreUsuario: config.nombre,
  );
  final t = Temporada(
    id: id,
    franquiciaUsuarioId: franquicias.firstWhere((f) => !f.historica).id,
    modoJuego: ModoJuego.fantasy,
    dificultad: config.dificultad,
    datosModo: {'fantasy': partida.toJson()},
  );
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// Pantalla propia del Fantasy para la partida [t] (o null si no es una).
Future<Widget?> pantallaFantasy(Temporada t, ContextoModos c) async {
  if (t.modoJuego != ModoJuego.fantasy || PartidaFantasy.de(t) == null) return null;
  final liga = await c.liga();
  return FantasyPantalla(temporada: t, catalogo: liga.catalogo, onGuardar: c.guardar);
}

/// Lo que se elige al empezar.
class ConfigFantasy {
  const ConfigFantasy({required this.anio, required this.dificultad, required this.rivales, required this.nombre});

  final int anio;
  final Dificultad dificultad;
  final int rivales;
  final String nombre;
}

// ─────────────────────────────────────────── Configuración ───────────────────────────────────────────

class FantasyConfigPantalla extends StatefulWidget {
  const FantasyConfigPantalla({super.key, required this.catalogo, required this.perfil});

  final List<Jugador> catalogo;
  final PerfilEntrenador perfil;

  @override
  State<FantasyConfigPantalla> createState() => _FantasyConfigState();
}

class _FantasyConfigState extends State<FantasyConfigPantalla> {
  late final _fantasy = Fantasy(widget.catalogo, perfil: widget.perfil);
  var _album = false;
  var _anio = 1996;
  var _rivales = 5;
  var _dificultad = Dificultad.normal;
  final _nombre = TextEditingController(text: 'Mi equipo');

  static const _famosos = [1986, 1996, 2001, 2009, 2013, 2016, 2021];

  List<Jugador> get _pool => _album ? _fantasy.poolAlbum(widget.perfil.coleccion) : _fantasy.poolDelAnio(_anio);

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final pool = _pool;
    final alcanza = _fantasy.alcanza(pool);
    return Scaffold(
      appBar: AppBar(title: const Text('Fantasy NBA')),
      body: SafeArea(
        child: AnchoMaximo(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Armás un quinteto y un Sexto Hombre con un presupuesto, y sumás los puntos fantasy de tus jugadores '
                'semana a semana contra mánagers de la IA. Capitán: suma doble.',
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: esquema.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Ojo: el juego es offline y no tiene estadísticas en vivo. Los puntos salen de los promedios reales '
                  'de cada carta (de ese tramo en su equipo), con variación de partido a partido, rachas y '
                  'lesiones simuladas. No son los números reales de cada partido de ese año.',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Un año de la NBA'), icon: Icon(Icons.event)),
                  ButtonSegment(value: true, label: Text('Mi álbum'), icon: Icon(Icons.collections_bookmark_outlined)),
                ],
                selected: {_album},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _album = s.first),
              ),
              const SizedBox(height: 12),
              if (_album)
                Text(
                  'Solo con las cartas de tu álbum, con sus evoluciones (cada etapa suma un 2 % de producción). '
                  'Tenés ${pool.length} jugadores distintos.',
                  style: tema.textTheme.bodySmall,
                )
              else ...[
                Row(
                  children: [
                    Text('TEMPORADA', style: tema.textTheme.labelLarge),
                    const Spacer(),
                    TextoLed(etiquetaAnio(_anio), tamano: 26),
                  ],
                ),
                Slider(
                  value: _anio.toDouble(),
                  min: Fantasy.primerAnio.toDouble(),
                  max: Fantasy.ultimoAnio.toDouble(),
                  divisions: Fantasy.ultimoAnio - Fantasy.primerAnio,
                  label: etiquetaAnio(_anio),
                  onChanged: (v) => setState(() => _anio = v.round()),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final a in _famosos)
                      ActionChip(label: Text(etiquetaAnio(a)), onPressed: () => setState(() => _anio = a)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${pool.length} jugadores disponibles ese año.', style: tema.textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('RIVALES DE LA IA', style: tema.textTheme.labelLarge),
                  const Spacer(),
                  TextoLed('$_rivales', tamano: 26),
                ],
              ),
              Slider(
                value: _rivales.toDouble(),
                min: ReglasFantasy.minimoRivales.toDouble(),
                max: ReglasFantasy.maximoRivales.toDouble(),
                divisions: ReglasFantasy.maximoRivales - ReglasFantasy.minimoRivales,
                label: '$_rivales',
                onChanged: (v) => setState(() => _rivales = v.round()),
              ),
              Text('DIFICULTAD · PRESUPUESTO', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<Dificultad>(
                segments: [
                  for (final d in Dificultad.values)
                    ButtonSegment(value: d, label: Text('${d.nombre}\n\$${ReglasFantasy.presupuesto(d)}')),
                ],
                selected: {_dificultad},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _dificultad = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombre,
                maxLength: 24,
                decoration: const InputDecoration(labelText: 'Nombre de tu equipo'),
              ),
              if (!alcanza)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _album
                        ? 'Tu álbum todavía no alcanza para armar un equipo (faltan puestos): conseguí más cartas.'
                        : 'Ese año no hay jugadores suficientes en todos los puestos. Probá con otro.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.error),
                  ),
                ),
              FilledButton(
                onPressed: !alcanza
                    ? null
                    : () => Navigator.pop(
                        context,
                        ConfigFantasy(
                          anio: _album ? 0 : _anio,
                          dificultad: _dificultad,
                          rivales: _rivales,
                          nombre: _nombre.text.trim().isEmpty ? 'Mi equipo' : _nombre.text.trim(),
                        ),
                      ),
                child: const Text('ARMAR MI EQUIPO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────── Partida ────────────────────────────────────────────

class FantasyPantalla extends StatefulWidget {
  const FantasyPantalla({super.key, required this.temporada, required this.catalogo, required this.onGuardar});

  final Temporada temporada;
  final List<Jugador> catalogo;
  final Future<void> Function(Temporada t) onGuardar;

  @override
  State<FantasyPantalla> createState() => _FantasyPantallaState();
}

class _FantasyPantallaState extends State<FantasyPantalla> {
  late Temporada _t = widget.temporada;
  late final Fantasy _fantasy = Fantasy(widget.catalogo, perfil: perfilApp.value);
  Posicion? _puesto;
  var _busca = '';
  var _orden = _Orden.media;
  var _simulando = false;

  PartidaFantasy get _f => PartidaFantasy.de(_t)!;

  void _guardar(PartidaFantasy f) {
    setState(() => _t = f.guardarEn(_t));
    widget.onGuardar(_t);
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(texto)));

  /// Pone una carta en el puesto elegido (o en el primero libre donde entre).
  void _fichar(Jugador j) {
    final f = _f;
    final tu = f.tuEquipo;
    Posicion? destino = _puesto;
    destino ??= Posicion.values.where((p) => !tu.plantel.containsKey(p) && j.puedeJugarEn(p)).firstOrNull;
    if (destino == null) {
      _aviso('Elegí primero el puesto que querés cambiar (tocalo en Equipo).');
      return;
    }
    if (!j.puedeJugarEn(destino)) {
      _aviso('${j.nombre} no juega de ${destino.etiqueta.toLowerCase()}.');
      return;
    }
    final nuevo = _fantasy.ficharUsuario(f, destino, j);
    if (identical(nuevo, f)) {
      final jugando = f.semanas.isNotEmpty;
      _aviso(
        jugando && f.cambiosEstaSemana >= ReglasFantasy.cambiosPorSemana
            ? 'Ya hiciste el cambio de esta semana.'
            : 'No entra: te pasás del presupuesto o ya tenés a esa persona.',
      );
      return;
    }
    Haptica.seleccion();
    _guardar(nuevo);
    setState(() => _puesto = null);
  }

  Future<void> _jugarSemana() async {
    final f = _f;
    final errores = _fantasy.validar(f, f.tuEquipo);
    if (errores.isNotEmpty) {
      _aviso(errores.first);
      return;
    }
    Haptica.media();
    _guardar(_fantasy.jugarSemana(f));
  }

  Future<void> _simularTodo() async {
    final f = _f;
    final errores = _fantasy.validar(f, f.tuEquipo);
    if (errores.isNotEmpty) {
      _aviso(errores.first);
      return;
    }
    setState(() => _simulando = true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    _guardar(_fantasy.simularTodo(f));
    if (mounted) setState(() => _simulando = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    final equipo = _Equipo(
      f: f,
      fantasy: _fantasy,
      puesto: _puesto,
      onPuesto: (p) => setState(() => _puesto = _puesto == p ? null : p),
      onCapitan: (id) => _guardar(_fantasy.elegirCapitan(f, id)),
    );
    final mercado = _Mercado(
      f: f,
      fantasy: _fantasy,
      puesto: _puesto,
      busca: _busca,
      orden: _orden,
      onBusca: (v) => setState(() => _busca = v),
      onOrden: (o) => setState(() => _orden = o),
      onPuesto: (p) => setState(() => _puesto = p),
      onFichar: _fichar,
    );
    final tabla = _Tabla(f: f);
    final semanas = _Semanas(f: f, fantasy: _fantasy);
    final tablet = esTabletApaisada(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Fantasy NBA · ${etiquetaAnio(f.anio)}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: TextoLed('\$${f.presupuesto - _fantasy.costo(f, f.tuEquipo)}', tamano: 22)),
          ),
        ],
      ),
      body: SafeArea(
        child: tablet
            ? Column(
                children: [
                  Expanded(
                    child: DosPaneles(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      flexIzquierda: 5,
                      flexDerecha: 6,
                      izquierda: equipo,
                      derecha: _Pestanas(mercado: mercado, tabla: tabla, semanas: semanas),
                    ),
                  ),
                  _Acciones(f: f, ocupado: _simulando, onJugar: _jugarSemana, onSimular: _simularTodo),
                ],
              )
            : DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Equipo'),
                        Tab(text: 'Mercado'),
                        Tab(text: 'Tabla'),
                        Tab(text: 'Semanas'),
                      ],
                    ),
                    Expanded(child: TabBarView(children: [equipo, mercado, tabla, semanas])),
                    _Acciones(f: f, ocupado: _simulando, onJugar: _jugarSemana, onSimular: _simularTodo),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.mercado, required this.tabla, required this.semanas});

  final Widget mercado, tabla, semanas;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Mercado'),
            Tab(text: 'Tabla'),
            Tab(text: 'Semanas'),
          ],
        ),
        Expanded(child: TabBarView(children: [mercado, tabla, semanas])),
      ],
    ),
  );
}

BoxDecoration _caja(ColorScheme esquema, {bool resaltada = false}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: resaltada ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5)),
);

class _Acciones extends StatelessWidget {
  const _Acciones({required this.f, required this.ocupado, required this.onJugar, required this.onSimular});

  final PartidaFantasy f;
  final bool ocupado;
  final VoidCallback onJugar, onSimular;

  String get _etiqueta => switch (f.fase) {
    FaseFantasy.armado => 'COMPLETÁ TU EQUIPO',
    FaseFantasy.regular => 'JUGAR LA SEMANA ${f.semanaActual + 1}',
    FaseFantasy.semis => 'JUGAR LAS SEMIFINALES',
    FaseFantasy.finalPlayoff => 'JUGAR LA FINAL',
    FaseFantasy.terminada => 'LIGA TERMINADA',
  };

  @override
  Widget build(BuildContext context) {
    final puede = f.fase != FaseFantasy.armado && f.fase != FaseFantasy.terminada && !ocupado;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: FilledButton(onPressed: puede ? onJugar : null, child: Text(_etiqueta)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: puede ? onSimular : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('SIMULAR TODO'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────── Equipo ───────────────────────────────────────────

class _Equipo extends StatelessWidget {
  const _Equipo({
    required this.f,
    required this.fantasy,
    required this.puesto,
    required this.onPuesto,
    required this.onCapitan,
  });

  final PartidaFantasy f;
  final Fantasy fantasy;
  final Posicion? puesto;
  final ValueChanged<Posicion> onPuesto;
  final ValueChanged<String> onCapitan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tu = f.tuEquipo;
    final costo = fantasy.costo(f, tu);
    final semana = f.semanaActual;
    final ultima = f.semanas.isEmpty ? null : f.semanas.last;
    final jugando = f.semanas.isNotEmpty && f.fase != FaseFantasy.terminada;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        if (f.fase == FaseFantasy.terminada) _Final(f: f),
        Row(
          children: [
            Expanded(child: Text(tu.nombre.toUpperCase(), style: tema.textTheme.titleLarge, maxLines: 1)),
            Text('GASTADO ', style: tema.textTheme.labelMedium),
            TextoLed('\$$costo/${f.presupuesto}', tamano: 20),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          f.fase == FaseFantasy.armado
              ? 'Tocá un puesto y elegí del mercado. Al completarlo ya podés jugar la primera semana.'
              : jugando
              ? 'Cambios esta semana: ${f.cambiosEstaSemana}/${ReglasFantasy.cambiosPorSemana}. Tocá la estrella para elegir capitán (suma doble).'
              : 'Tocá un puesto para cambiarlo antes de la primera semana (sin límite).',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final pos in Posicion.values)
          Builder(
            builder: (context) {
              final id = tu.plantel[pos];
              final j = id == null ? null : fantasy.carta(id);
              final fuera = j != null && f.fase != FaseFantasy.terminada && f.mundo.semanasFuera(j.id, semana) > 0;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: _caja(esquema, resaltada: puesto == pos),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onPuesto(pos),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            pos.etiqueta,
                            style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                          ),
                        ),
                        if (j == null)
                          Expanded(
                            child: Text(
                              '— vacío —',
                              style: tema.textTheme.bodyMedium?.copyWith(color: esquema.outline),
                            ),
                          )
                        else ...[
                          TextoLed('${j.media}', tamano: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(j.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  fuera
                                      ? 'LESIONADO · ${f.mundo.semanasFuera(j.id, semana)} sem'
                                      : '${j.tramoConEquipo} · ${ReglasFantasy.promedio(j).toStringAsFixed(1)} pts/partido',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tema.textTheme.bodySmall?.copyWith(
                                    color: fuera ? esquema.error : esquema.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (ultima != null && ultima.detalleUsuario.containsKey(j.id))
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                '${ultima.detalleUsuario[j.id]!.toStringAsFixed(0)} pts',
                                style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary),
                              ),
                            ),
                          Text('\$${fantasy.precioDe(f, j)}', style: tema.textTheme.labelLarge),
                          IconButton(
                            tooltip: tu.capitan == j.id ? 'Capitán' : 'Hacer capitán',
                            icon: Icon(
                              tu.capitan == j.id ? Icons.star : Icons.star_border,
                              color: tu.capitan == j.id ? esquema.primary : esquema.outline,
                            ),
                            onPressed: () => onCapitan(j.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        if (ultima != null) ...[
          const SizedBox(height: 8),
          Text(
            'Última semana: ${ultima.puntosEquipo[PartidaFantasy.usuario].toStringAsFixed(1)} puntos '
            '(los números a la derecha de cada jugador).',
            style: tema.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({required this.f});
  final PartidaFantasy f;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final puesto = f.puestoUsuario;
    final campeon = f.equipos[f.campeon!];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _caja(esquema, resaltada: puesto == 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            puesto == 1 ? '¡CAMPEÓN DEL FANTASY!' : 'LIGA TERMINADA · PUESTO $puesto',
            style: tema.textTheme.titleLarge?.copyWith(color: puesto == 1 ? esquema.primary : null),
          ),
          const SizedBox(height: 4),
          Text(
            puesto == 1
                ? 'Le ganaste la final a ${f.equipos[f.subcampeon!].nombre}.'
                : 'Campeón: ${campeon.nombre}${campeon.personalidad == null ? '' : ' (${campeon.personalidad!.descripcion})'}',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('VOLVER AL INICIO'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────── Mercado ───────────────────────────────────────────

enum _Orden {
  media('Media'),
  promedio('Pts fantasy'),
  precio('Precio'),
  valor('Valor/\$');

  const _Orden(this.etiqueta);
  final String etiqueta;
}

class _Mercado extends StatelessWidget {
  const _Mercado({
    required this.f,
    required this.fantasy,
    required this.puesto,
    required this.busca,
    required this.orden,
    required this.onBusca,
    required this.onOrden,
    required this.onPuesto,
    required this.onFichar,
  });

  final PartidaFantasy f;
  final Fantasy fantasy;
  final Posicion? puesto;
  final String busca;
  final _Orden orden;
  final ValueChanged<String> onBusca;
  final ValueChanged<_Orden> onOrden;
  final ValueChanged<Posicion?> onPuesto;
  final ValueChanged<Jugador> onFichar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final semana = f.semanaActual;
    final tu = f.tuEquipo.ids.toSet();
    var cartas = [
      for (final id in f.poolIds)
        if (fantasy.carta(id) case final j?
            when (puesto == null || j.puedeJugarEn(puesto!)) && j.nombre.toLowerCase().contains(busca.toLowerCase()))
          j,
    ];
    double clave(Jugador j) => switch (orden) {
      _Orden.media => j.media.toDouble(),
      _Orden.promedio => ReglasFantasy.promedio(j),
      _Orden.precio => fantasy.precioDe(f, j).toDouble(),
      _Orden.valor => ReglasFantasy.promedio(j) / fantasy.precioDe(f, j),
    };
    cartas = cartas..sort((a, b) => clave(b).compareTo(clave(a)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar jugador'),
            onChanged: onBusca,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: puesto == null,
                  onSelected: (_) => onPuesto(null),
                ),
              ),
              for (final p in Posicion.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(p.etiqueta),
                    selected: puesto == p,
                    onSelected: (_) => onPuesto(puesto == p ? null : p),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final o in _Orden.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(o.etiqueta),
                    selected: orden == o,
                    onSelected: (_) => onOrden(o),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: min(cartas.length, 200),
            itemBuilder: (context, i) {
              final j = cartas[i];
              final enEquipo = tu.contains(j.id);
              final fuera = f.mundo.lesionado(j.id, semana);
              return ListTile(
                dense: true,
                leading: TextoLed('${j.media}', tamano: 22),
                title: Text(j.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  fuera
                      ? 'LESIONADO · ${j.tramoConEquipo}'
                      : '${j.tramoConEquipo} · ${j.posiciones.map((p) => p.etiqueta).join('/')} · '
                            '${ReglasFantasy.promedio(j).toStringAsFixed(1)} pts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fuera ? esquema.error : null),
                ),
                trailing: Text(
                  enEquipo ? 'EN TU EQUIPO' : '\$${fantasy.precioDe(f, j)}',
                  style: tema.textTheme.labelLarge?.copyWith(color: enEquipo ? esquema.primary : null),
                ),
                onTap: enEquipo ? null : () => onFichar(j),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────── Tabla y semanas ───────────────────────────────────────

class _Tabla extends StatelessWidget {
  const _Tabla({required this.f});
  final PartidaFantasy f;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final filas = f.tabla();
    final clasifican = min(4, f.equipos.length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        Text(
          'Pasan los $clasifican primeros a las semifinales (1.º-$clasifican.º y 2.º-${clasifican - 1}.º).',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final (i, fila) in filas.indexed)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: _caja(esquema, resaltada: fila.indice == PartidaFantasy.usuario),
            child: Row(
              children: [
                SizedBox(width: 26, child: TextoLed('${i + 1}', tamano: 18)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.equipos[fila.indice].nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (f.equipos[fila.indice].personalidad case final p?)
                        Text(
                          p.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                TextoLed('${fila.victorias}-${fila.derrotas}', tamano: 20),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  child: Text(
                    fila.puntos.toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: tema.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Semanas extends StatelessWidget {
  const _Semanas({required this.f, required this.fantasy});
  final PartidaFantasy f;
  final Fantasy fantasy;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    if (f.semanas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Todavía no se jugó ninguna semana. Cada semana tiene 3 o 4 partidos de cada jugador.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium,
          ),
        ),
      );
    }
    String nombre(int i) => f.equipos[i].nombre;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        for (final (k, s) in f.semanas.indexed.toList().reversed)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: _caja(esquema),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (s.fase) {
                  'semis' => 'SEMIFINALES',
                  'final' => 'FINAL',
                  _ => 'SEMANA ${k + 1}',
                }, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
                for (final c in s.cruces)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre(c.a),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: c.ganador == c.a ? FontWeight.w800 : null),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${c.puntosA.toStringAsFixed(0)} - ${c.puntosB.toStringAsFixed(0)}',
                            style: tema.textTheme.labelLarge,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            nombre(c.b),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: c.ganador == c.b ? FontWeight.w800 : null),
                          ),
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
