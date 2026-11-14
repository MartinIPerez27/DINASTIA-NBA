import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/metajuego.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/misiones.dart';
import '../../domain/modos/epocas.dart';
import '../../domain/modos/escalera.dart' show Cruce, RivalEscalera;
import '../../domain/motor.dart';
import '../../domain/premios.dart' show apellido;
import '../pantallas/partido_pantalla.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/disposicion.dart';
import '../widgets/elegir_modo.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Torneos por época, clase de draft y universidad.
bool esModoEpocas(ModoJuego m) => ModosEpocas.esModo(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarEpocas(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  final liga = await c.liga();
  final modos = ModosEpocas(liga);
  if (!c.context.mounted) return;
  if (m == ModoJuego.guantelete) {
    final dificultad = await elegirDificultad(c.context);
    if (dificultad == null) return;
    final t = modos.nuevoGuantelete(id: ContextoModos.nuevoId(), franquiciaId: enfocada.id, dificultad: dificultad);
    await c.guardar(t);
    await c.abrirTemporada(t);
    return;
  }
  final equipos = m == ModoJuego.camadas ? modos.equiposCamadas() : modos.equiposUniversidades();
  if (!c.context.mounted) return;
  final elegido = await showModalBottomSheet<int>(
    context: c.context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _ElegirEquipo(modo: m, equipos: equipos, liga: liga),
  );
  if (elegido == null || !c.context.mounted) return;
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null) return;
  final t = modos.nuevoCuadro(
    id: ContextoModos.nuevoId(),
    modo: m,
    equipos: equipos,
    elegido: elegido,
    dificultad: dificultad,
  );
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// Pantalla propia del modo para la partida [t] (estos modos no usan el flujo clásico).
Future<Widget?> pantallaEpocas(Temporada t, ContextoModos c) async {
  final liga = await c.liga();
  return EpocasPantalla(temporada: t, liga: liga, onCambio: c.guardar);
}

String _titulo(ModoJuego m) => switch (m) {
  ModoJuego.guantelete => 'Elegí tu punto de partida',
  ModoJuego.camadas => '¿Qué camada dirigís?',
  _ => '¿Qué universidad dirigís?',
};

/// Hoja para elegir tu equipo del cuadro (camadas o universidades).
class _ElegirEquipo extends StatelessWidget {
  const _ElegirEquipo({required this.modo, required this.equipos, required this.liga});

  final ModoJuego modo;
  final List<EquipoEpoca> equipos;
  final Liga liga;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_titulo(modo).toUpperCase(), style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            modo == ModoJuego.camadas
                ? 'Cada equipo es una clase de draft: la mejor carta de cada uno de sus jugadores.'
                : 'Cada equipo junta la mejor carta de sus ex alumnos. "Directo a la NBA" son los que llegaron sin '
                      'pasar por la universidad (del secundario o del exterior).',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final (i, e) in equipos.indexed)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: _Sigla(e),
                title: Text(e.nombre),
                subtitle: Text(_figuras(e.equipo, liga), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: TextoLed(e.equipo.media.toStringAsFixed(1), tamano: 18),
                onTap: () => Navigator.of(context).pop(i),
              ),
            ),
        ],
      ),
    );
  }
}

String _figuras(RivalEscalera r, Liga liga, {int cuantas = 3}) {
  final js = [for (final id in r.cartaIds.values) ?liga.jugador(id)]..sort((a, b) => b.media.compareTo(a.media));
  return js.take(cuantas).map((j) => '${apellido(j)} ${j.media}').join(' · ');
}

/// Sigla LED del equipo: '84 para una camada, DUKE para una universidad.
class _Sigla extends StatelessWidget {
  const _Sigla(this.equipo, {this.tamano = 16});

  final EquipoEpoca equipo;
  final double tamano;

  static String texto(EquipoEpoca e) {
    if (int.tryParse(e.clave) case final anio?) return "'${(anio % 100).toString().padLeft(2, '0')}";
    if (e.clave.isEmpty) return 'NBA';
    final limpio = e.nombre.replaceAll(RegExp('[^A-Za-z ]'), '').trim();
    final palabras = limpio.split(' ').where((p) => p.isNotEmpty).toList();
    if (palabras.length > 1) return palabras.map((p) => p[0]).join().toUpperCase();
    return limpio.substring(0, limpio.length.clamp(0, 4)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tamano * 3.2,
    child: TextoLed(texto(equipo), tamano: tamano),
  );
}

/// Pantalla de los tres modos: mini-draft y reclutas (guantelete), tu cruce, el camino o el cuadro.
class EpocasPantalla extends StatefulWidget {
  const EpocasPantalla({super.key, required this.temporada, required this.liga, required this.onCambio});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  @override
  State<EpocasPantalla> createState() => _EpocasPantallaState();
}

class _EpocasPantallaState extends State<EpocasPantalla> {
  late Temporada _t = widget.temporada;
  late final _modos = ModosEpocas(widget.liga);
  var _ocupado = false;

  EstadoEpocas get _e => EstadoEpocas.de(_t);

  @override
  void didUpdateWidget(EpocasPantalla vieja) {
    super.didUpdateWidget(vieja);
    if (!identical(vieja.temporada, widget.temporada)) _t = widget.temporada;
  }

  void _guardar(Temporada t) {
    final (ganados, _, _) = progresoEpocas(_t, t);
    if (ganados > 0) Misiones.anotar(TipoMision.ganarDesafio, ganados);
    setState(() => _t = t);
    widget.onCambio(t);
  }

  Franquicia get _propia => franquiciaPorId(_t.franquiciaUsuarioId);

  Future<void> _vivo() async {
    final antes = _t;
    final motor = _modos.motor(antes);
    final rival = franquiciaPorId(_e.pendiente!.rival.identidadId);
    final local = motor.usuarioLocal!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: motor,
          usuarioLocal: local,
          franquiciaUsuario: _propia,
          identidadLocal: local ? _propia : rival,
          identidadVisitante: local ? rival : _propia,
          onTerminado: (MotorPartido m) => _guardar(_modos.registrar(antes, m)),
        ),
      ),
    );
  }

  Future<void> _simular({bool cruce = false}) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    _guardar(cruce ? _modos.simularCruce(_t) : _modos.simularPartido(_t));
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _reclutar(Jugador j) async {
    final puestos = ModosEpocas.puestosPara(j);
    final p = await showModalBottomSheet<Posicion>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿A QUIÉN REEMPLAZA ${apellido(j).toUpperCase()}?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final p in puestos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.etiqueta),
                  subtitle: Text(_nombreEn(p)),
                  trailing: const Icon(Icons.swap_horiz),
                  onTap: () => Navigator.of(context).pop(p),
                ),
            ],
          ),
        ),
      ),
    );
    if (p == null) return;
    _guardar(_modos.reclutar(_t, cartaId: j.id, p: p));
  }

  String _nombreEn(Posicion p) {
    final id = _e.propio?.cartaIds[p];
    final j = id == null ? null : widget.liga.jugador(id);
    return j == null ? '—' : '${j.nombre} · ${j.media}';
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final modo = _t.modoJuego;
    final principal = <Widget>[
      _Encabezado(temporada: _t, estado: e),
      const SizedBox(height: 12),
      if (e.enDraft)
        _MiniDraft(estado: e, liga: widget.liga, onElegir: (id) => _guardar(_modos.elegirDraft(_t, id)))
      else if (e.terminado)
        _Final(temporada: _t, estado: e, onSalir: () => Navigator.of(context).popUntil((r) => r.isFirst))
      else if (e.reclutando)
        _Reclutar(
          rival: e.cruce!.rival,
          opciones: _modos.reclutables(_t),
          onElegir: _reclutar,
          onSeguir: () => _guardar(_modos.reclutar(_t)),
        )
      else if (e.pendiente case final c?)
        _ProximoCruce(
          cruce: c,
          liga: widget.liga,
          propia: _propia,
          ocupado: _ocupado,
          onVivo: _vivo,
          onSimular: () => _simular(),
          onSimularSerie: c.esSerie ? () => _simular(cruce: true) : null,
        ),
      if (e.propio case final propio?) ...[const SizedBox(height: 16), _TuEquipo(equipo: propio, liga: widget.liga)],
    ];
    final secundario = <Widget>[
      if (!e.enDraft) modo == ModoJuego.guantelete ? _Camino(estado: e, propia: _propia) : _Cuadro(estado: e),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(modo.nombre)),
      body: esTabletApaisada(context)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: ListView(padding: const EdgeInsets.fromLTRB(24, 4, 12, 32), children: principal),
                ),
                Expanded(
                  flex: 6,
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 24, 32), children: secundario),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [...principal, const SizedBox(height: 16), ...secundario],
            ),
    );
  }
}

BoxDecoration _panel(ColorScheme esquema, {bool resaltado = false}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: resaltado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
    width: resaltado ? 1.5 : 1,
  ),
);

const _titular = TextStyle(
  fontFamily: Fuentes.estadio,
  fontVariations: [FontVariation.weight(800)],
  fontSize: 20,
  letterSpacing: 0.5,
);

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.temporada, required this.estado});

  final Temporada temporada;
  final EstadoEpocas estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = estado;
    final (led, etiqueta, detalle) = switch (temporada.modoJuego) {
      ModoJuego.guantelete when e.enDraft => (
        '${e.elegidas.length}/6',
        'ELEGIDOS',
        'Armá tu equipo con leyendas de los 40 y 50. Después, vencé al campeón de cada década hasta hoy: '
            'cada victoria te deja reclutar a uno del rival.',
      ),
      ModoJuego.guantelete => (
        '${e.historial.where((c) => c.ganado).length}/${ModosEpocas.decadas.length}',
        'DÉCADAS',
        'Series al mejor de 3 contra el mejor equipo de cada década. Si perdés, se termina.',
      ),
      _ => (
        e.usuario >= 0 ? _Sigla.texto(e.equipos[e.usuario]) : '',
        e.usuario >= 0 ? e.equipos[e.usuario].nombre.toUpperCase() : '',
        temporada.modoJuego == ModoJuego.camadas
            ? 'Cuadro de ${e.equipos.length} clases de draft. Partido único hasta cuartos; semis y final al mejor de 3.'
            : 'Cuadro de ${e.equipos.length} universidades. Partido único hasta cuartos; semis y final al mejor de 3.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(temporada.modoJuego.nombre.toUpperCase(), style: _titular),
                const SizedBox(height: 4),
                Text(detalle, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  temporada.dificultad.nombre.toUpperCase(),
                  style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Column(
              children: [
                FittedBox(child: TextoLed(led, tamano: 36)),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: tema.textTheme.labelSmall?.copyWith(letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini-draft del guantelete: 4 cartas de los 40 y 50 por puesto.
class _MiniDraft extends StatelessWidget {
  const _MiniDraft({required this.estado, required this.liga, required this.onElegir});

  final EstadoEpocas estado;
  final Liga liga;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final puesto = estado.puestoDraft;
    final cartas = [for (final id in estado.ofertas) ?liga.jugador(id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ELEGÍ TU ${puesto?.etiqueta ?? ''}', style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final columnas = c.maxWidth >= 560 ? 4 : 2;
            final ancho = (c.maxWidth - 8 * (columnas - 1)) / columnas;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final j in cartas)
                  SizedBox(
                    width: ancho,
                    child: Semantics(
                      button: true,
                      label: 'Elegir a ${j.nombre}',
                      child: GestureDetector(
                        onTap: () => onElegir(j.id),
                        child: CartaVertical(jugador: j),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (estado.elegidas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('TU EQUIPO HASTA AHORA', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
          for (final e in estado.elegidas.entries)
            if (liga.jugador(e.value) case final j?)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(j.nombre),
                subtitle: Text('${e.key.etiqueta} · ${j.tramoConEquipo}'),
                trailing: TextoLed('${j.media}', tamano: 16),
              ),
        ],
      ],
    );
  }
}

/// Después de cada década: reclutás a uno del rival (o seguís igual).
class _Reclutar extends StatelessWidget {
  const _Reclutar({required this.rival, required this.opciones, required this.onElegir, required this.onSeguir});

  final RivalEscalera rival;
  final List<Jugador> opciones;
  final ValueChanged<Jugador> onElegir;
  final VoidCallback onSeguir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¡DÉCADA SUPERADA!', style: _titular.copyWith(color: esquema.primary)),
          const SizedBox(height: 4),
          Text(
            'Le ganaste a ${franquiciaPorId(rival.identidadId).nombreCompleto} ${rival.etiqueta}. '
            'Reclutá a uno de ellos: reemplaza a uno de los tuyos.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final j in opciones)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(j.nombre),
                    subtitle: Text('${j.posiciones.map((p) => p.etiqueta).join(' / ')} · ${j.tramoConEquipo}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [TextoLed('${j.media}', tamano: 18), const Icon(Icons.chevron_right)],
                    ),
                    onTap: () => onElegir(j),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onSeguir, child: const Text('SEGUIR SIN CAMBIOS')),
        ],
      ),
    );
  }
}

/// El cruce que sigue: escudos, formato, figuras del rival y los botones.
class _ProximoCruce extends StatelessWidget {
  const _ProximoCruce({
    required this.cruce,
    required this.liga,
    required this.propia,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    this.onSimularSerie,
  });

  final Cruce cruce;
  final Liga liga;
  final Franquicia propia;
  final bool ocupado;
  final VoidCallback onVivo, onSimular;
  final VoidCallback? onSimularSerie;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final rival = franquiciaPorId(cruce.rival.identidadId);
    final formato = cruce.aGanar == 1 ? 'Partido único' : 'Al mejor de ${cruce.aGanar * 2 - 1}';
    final local = cruce.usuarioLocalProximo ? 'de local' : 'de visitante';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(cruce.titulo.toUpperCase(), style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Escudo(propia, tamano: 52),
              Expanded(
                child: Column(
                  children: [
                    if (cruce.esSerie) TextoLed('${cruce.propias}-${cruce.ajenas}', tamano: 34) else const Text('VS'),
                    if (cruce.esSerie)
                      Text('Juego ${cruce.juego + 1}', style: tema.textTheme.labelSmall?.copyWith(letterSpacing: 1)),
                  ],
                ),
              ),
              Escudo(rival, tamano: 52),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cruce.rival.etiqueta.startsWith('(')
                ? '${rival.nombreCompleto} ${cruce.rival.etiqueta}'
                : cruce.rival.etiqueta,
            textAlign: TextAlign.center,
            style: tema.textTheme.titleMedium,
          ),
          Text(
            '$formato · $local · media ${cruce.rival.media.toStringAsFixed(1)}',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.primary),
          ),
          const SizedBox(height: 2),
          Text(_figuras(cruce.rival, liga), textAlign: TextAlign.center, style: tema.textTheme.bodySmall),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: ocupado ? null : onVivo,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('JUGAR EN VIVO'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: ocupado ? null : onSimular,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  child: const Text('SIMULAR'),
                ),
              ),
              if (onSimularSerie != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: ocupado ? null : onSimularSerie,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: const Text('SIMULAR SERIE'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TuEquipo extends StatelessWidget {
  const _TuEquipo({required this.equipo, required this.liga});

  final RivalEscalera equipo;
  final Liga liga;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('TU EQUIPO', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1))),
            TextoLed(equipo.media.toStringAsFixed(1), tamano: 16),
          ],
        ),
        for (final p in Posicion.values)
          if (equipo.cartaIds[p] case final id?)
            if (liga.jugador(id) case final j?)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(j.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${p.etiqueta} · ${j.tramoConEquipo}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: TextoLed('${j.media}', tamano: 16),
              ),
      ],
    );
  }
}

/// Las décadas del guantelete: las superadas, la actual y las que vienen.
class _Camino extends StatelessWidget {
  const _Camino({required this.estado, required this.propia});

  final EstadoEpocas estado;
  final Franquicia propia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('EL CAMINO', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
        const SizedBox(height: 4),
        for (final (i, d) in ModosEpocas.decadas.indexed)
          () {
            final jugado = i < estado.historial.length ? estado.historial[i] : null;
            final rival = i < estado.equipos.length ? estado.equipos[i].equipo : null;
            final actual = i == estado.etapa && !estado.terminado;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(width: 44, child: TextoLed(d.codigo, tamano: 14)),
              title: Text(
                rival == null ? d.etiqueta : '${franquiciaPorId(rival.identidadId).nombreCompleto} ${rival.etiqueta}',
                style: actual ? TextStyle(color: esquema.primary, fontWeight: FontWeight.w700) : null,
              ),
              trailing: jugado != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          jugado.ganado ? Icons.check : Icons.close,
                          size: 16,
                          color: jugado.ganado ? esquema.primary : esquema.error,
                        ),
                        const SizedBox(width: 4),
                        TextoLed('${jugado.propias}-${jugado.ajenas}', tamano: 14),
                      ],
                    )
                  : actual
                  ? Icon(Icons.play_arrow, color: esquema.primary)
                  : Icon(Icons.lock_outline, size: 16, color: esquema.outline),
            );
          }(),
      ],
    );
  }
}

/// El cuadro de camadas o universidades, ronda por ronda.
class _Cuadro extends StatelessWidget {
  const _Cuadro({required this.estado});

  final EstadoEpocas estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final n = estado.equipos.length;
    final rondas = ModosEpocas.nombresRondas(n);
    final modos = estado;
    List<int> participantes(int r) => r == 0 ? ModosEpocas.ordenLlaves(n) : modos.ganadores[r - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('EL CUADRO', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
        for (var r = 0; r < estado.ganadores.length; r++) ...[
          const SizedBox(height: 10),
          Text(rondas[r], style: tema.textTheme.titleSmall?.copyWith(color: esquema.primary)),
          for (var k = 0; k + 1 < participantes(r).length; k += 2)
            () {
              final (a, b) = (participantes(r)[k], participantes(r)[k + 1]);
              final g = estado.ganadores[r][k ~/ 2];
              final texto = estado.marcadores[r][k ~/ 2];
              final tuya = a == estado.usuario || b == estado.usuario;
              Widget lado(int i) => Expanded(
                child: Row(
                  children: [
                    _Sigla(estado.equipos[i], tamano: 12),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        estado.equipos[i].nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: g == i ? FontWeight.w700 : FontWeight.w400,
                          color: g >= 0 && g != i ? esquema.onSurfaceVariant.withValues(alpha: 0.6) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: _panel(esquema, resaltado: tuya),
                child: Row(
                  children: [
                    lado(a),
                    SizedBox(width: 70, child: Center(child: g < 0 ? const Text('vs') : TextoLed(texto, tamano: 13))),
                    lado(b),
                  ],
                ),
              );
            }(),
        ],
      ],
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({required this.temporada, required this.estado, required this.onSalir});

  final Temporada temporada;
  final EstadoEpocas estado;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = estado;
    final campeon = e.campeon;
    final String detalle;
    if (temporada.modoJuego == ModoJuego.guantelete) {
      final ganadas = e.historial.where((c) => c.ganado).length;
      detalle = campeon
          ? '¡Le ganaste a todas las décadas! De los pioneros de los 40 a las figuras de hoy.'
          : 'Llegaste hasta ${ModosEpocas.decadas[ganadas].etiqueta}: $ganadas de ${ModosEpocas.decadas.length} décadas superadas.';
    } else {
      final c = e.campeonCuadro;
      detalle = campeon
          ? '¡${e.equipos[e.usuario].nombre} campeón!'
          : c == null
          ? 'Quedaste afuera.'
          : 'Quedaste afuera. Campeón: ${e.equipos[c].nombre}.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema, resaltado: campeon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(campeon ? Icons.emoji_events : Icons.flag_outlined, size: 48, color: esquema.primary),
          const SizedBox(height: 8),
          Text(
            campeon ? '¡LO LOGRASTE!' : 'SE TERMINÓ',
            textAlign: TextAlign.center,
            style: _titular.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 6),
          Text(detalle, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onSalir, child: const Text('VOLVER AL INICIO')),
        ],
      ),
    );
  }
}
