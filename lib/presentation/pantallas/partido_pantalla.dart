import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import '../partido/cancha_partido.dart';
import '../partido/coreografia.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

enum _Panel { jugadores, relato }

/// Partido en vivo 2D estilo transmisión (GDD §6): cámara que sigue la jugada, posesiones continuas
/// (subida, pases, tiro con estela, rebote), marcador de TV con reloj corriendo desde 0-0, pausa,
/// intervenciones del entrenador y estadísticas en vivo de tu equipo. Al terminar (o si el usuario
/// sale, que simula lo que falta) llama a [onTerminado] con el motor completo.
class PartidoPantalla extends StatefulWidget {
  const PartidoPantalla({
    super.key,
    required this.motor,
    required this.usuarioLocal,
    required this.franquiciaUsuario,
    required this.identidadLocal,
    required this.identidadVisitante,
    required this.onTerminado,
  });

  final MotorPartido motor;
  final bool usuarioLocal;
  final Franquicia franquiciaUsuario;
  final Franquicia identidadLocal;
  final Franquicia identidadVisitante;
  final ValueChanged<MotorPartido> onTerminado;

  @override
  State<PartidoPantalla> createState() => _PartidoPantallaState();
}

class _PartidoPantallaState extends State<PartidoPantalla> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _c = AnimationController(vsync: this)
    ..addListener(_alAvanzar)
    ..addStatusListener(_alTerminarJugada);
  Coreografia? _coreo;
  var _velocidad = 2;
  var _pausado = false;
  var _acelerar = false, _presion = false;
  var _panel = _Panel.jugadores;
  var _marcador = (0, 0);
  var _cuarto = 1;
  var _relojDesde = 720.0, _relojHasta = 720.0;
  var _anotado = false;
  final _relato = <String>[];
  final _posiciones = <String, Offset>{};
  var _balonFin = const Offset(25, 47);
  String? _poseedorFin;
  var _segundaOportunidad = false;
  var _camara = 47.0;
  Duration? _ultimoCuadro;
  Map<String, LineaEstadistica> _box = {};
  bool _final = false, _registrado = false;

  MotorPartido get _m => widget.motor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _box = _copiaBox();
    WidgetsBinding.instance.addPostFrameCallback((_) => _proxima());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed && !_pausado && !_final) _alternarPausa();
  }

  Map<String, LineaEstadistica> _copiaBox() => {
    for (final e in (widget.usuarioLocal ? _m.boxLocal : _m.boxVisitante).entries)
      e.key: LineaEstadistica()..sumar(e.value),
  };

  bool _haciaArriba(bool local) => local == (_cuarto <= 2);

  void _proxima() {
    if (!mounted || _m.terminado) return;
    final e = _m.siguiente();
    final ataca = switch (e.tipo) {
      TipoEvento.tiro || TipoEvento.libres || TipoEvento.perdida || TipoEvento.cambio => e.local,
      _ => widget.usuarioLocal,
    };
    if (e.cuarto != _cuarto) _relojDesde = e.cuarto > 4 ? 300 : 720;
    _cuarto = e.tipo == TipoEvento.finCuarto ? e.cuarto - 1 : e.cuarto;
    _relojHasta = e.tipo == TipoEvento.finCuarto ? 0 : e.reloj;
    final saliente = e.tipo == TipoEvento.cambio ? widget.motor.enBanco(e.local) : null;
    _coreo = Coreografia(
      evento: e,
      atacantes: _m.enCancha(ataca),
      defensores: _m.enCancha(!ataca),
      haciaArriba: _haciaArriba(ataca),
      desde: Map.of(_posiciones),
      balonDesde: _balonFin,
      poseedorDesde: _poseedorFin,
      segundaOportunidad: _segundaOportunidad,
      saliente: saliente,
    );
    _anotado = false;
    final reducido = MediaQuery.disableAnimationsOf(context);
    _c.duration = Duration(milliseconds: reducido ? 300 : (_coreo!.duracion * 1000 / _velocidad).round());
    _c.forward(from: 0);
  }

  void _alAvanzar() {
    final coreo = _coreo;
    if (coreo == null) return;
    // Marcador y "+N" en el momento en que entra la pelota.
    final e = coreo.evento;
    if (!_anotado && e.puntos > 0 && _c.value >= coreo.momentoCanasta) {
      _anotado = true;
      setState(() => _marcador = (e.marcadorLocal, e.marcadorVisitante));
      if (e.local == widget.usuarioLocal) HapticFeedback.lightImpact();
    }
    // Cámara: sigue al balón con suavidad (resorte crítico).
    final ahora = _c.lastElapsedDuration ?? Duration.zero;
    final dt = _ultimoCuadro == null ? 0.016 : max(0, (ahora - _ultimoCuadro!).inMicroseconds) / 1e6;
    _ultimoCuadro = ahora;
    final objetivo = coreo.foco(_c.value);
    _camara += (objetivo - _camara) * (1 - exp(-dt * 3.5));
  }

  void _alTerminarJugada(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _ultimoCuadro = null;
    final coreo = _coreo!;
    final e = coreo.evento;
    for (final (id, pos, _, _) in _fichas(coreo, 1)) {
      _posiciones[id] = pos;
    }
    final (balon, _, poseedor) = coreo.balon(1);
    _balonFin = balon;
    _poseedorFin = e.convertido || e.tipo == TipoEvento.libres || e.tipo == TipoEvento.perdida
        ? e.defensorId
        : poseedor;
    _segundaOportunidad = e.tipo == TipoEvento.tiro && e.reboteOfensivo;
    setState(() {
      _marcador = (e.marcadorLocal, e.marcadorVisitante);
      _relojDesde = _relojHasta;
      _relato.insert(0, e.texto);
      if (_relato.length > 40) _relato.removeLast();
      _box = _copiaBox();
    });
    if (e.tipo == TipoEvento.finPartido) {
      _terminar();
    } else if (!_pausado) {
      _proxima();
    }
  }

  void _alternarPausa() {
    setState(() => _pausado = !_pausado);
    if (_pausado) {
      _c.stop();
    } else if (_c.isCompleted || _coreo == null) {
      _proxima();
    } else {
      _ultimoCuadro = null;
      _c.forward();
    }
  }

  void _cambiarVelocidad(int v) {
    final avance = _c.value;
    setState(() => _velocidad = v);
    final coreo = _coreo;
    if (coreo == null || MediaQuery.disableAnimationsOf(context)) return;
    _c.duration = Duration(milliseconds: (coreo.duracion * 1000 / v).round());
    if (_c.isAnimating) _c.forward(from: avance);
  }

  void _terminar() {
    if (_registrado) return;
    _registrado = true;
    widget.onTerminado(_m);
    setState(() => _final = true);
    HapticFeedback.heavyImpact();
  }

  Future<void> _salir() async {
    if (_final) {
      Navigator.of(context).pop();
      return;
    }
    final estabaPausado = _pausado;
    if (!estabaPausado) _alternarPausa();
    final salir = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir del partido?'),
        content: const Text('Lo que falta se simula al instante, con el resultado que salga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir mirando')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simular y salir')),
        ],
      ),
    );
    if (!mounted) return;
    if (salir != true) {
      if (!estabaPausado) _alternarPausa();
      return;
    }
    _c.stop();
    _m.simularTodo();
    _terminar();
    if (mounted) Navigator.of(context).pop();
  }

  /// Las 10 fichas (y el que sale en un cambio) en el instante t: (id, posición, local, opacidad).
  List<(String, Offset, bool, double)> _fichas(Coreografia coreo, double t) {
    final atacaLocal = coreo.atacantes.isNotEmpty && _m.enCancha(true).contains(coreo.atacantes.first);
    final resultado = <(String, Offset, bool, double)>[];
    final marcas = <Offset>[];
    for (final (i, j) in coreo.atacantes.indexed) {
      final p = coreo.atacante(j, i, t);
      marcas.add(p);
      resultado.add((j.id, p, atacaLocal, 1));
    }
    for (final (i, j) in coreo.defensores.indexed) {
      resultado.add((j.id, coreo.defensor(j, i, marcas[min(i, marcas.length - 1)], t), !atacaLocal, 1));
    }
    if (coreo.salienteEn(t) case (final p, final opacidad)) {
      resultado.add((coreo.saliente!.id, p, coreo.evento.local, opacidad));
    }
    return resultado;
  }

  Color _contraste(Color c) => c.computeLuminance() > 0.4 ? Colors.black : Colors.white;

  (Color, Color) _coloresRival(Franquicia rival) {
    final propio = Color(widget.franquiciaUsuario.colorPrimario);
    double distancia(Color a, Color b) => (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
    var color = Color(rival.colorPrimario);
    if (distancia(color, propio) < 0.35) color = Color(rival.colorSecundario);
    if (distancia(color, propio) < 0.35) color = propio.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    return (color, _contraste(color));
  }

  String _apellido(Jugador j) => j.nombre.split(' ').last.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final usuarioLocal = widget.usuarioLocal;
    final (colorRival, textoRival) = _coloresRival(usuarioLocal ? widget.identidadVisitante : widget.identidadLocal);
    final colorPropio = Color(widget.franquiciaUsuario.colorPrimario);
    final todos = {
      for (final local in [true, false]) ...{
        for (final j in [..._m.enCancha(local), ?_m.enBanco(local)]) j.id: j,
      },
    };
    final banner = switch (_coreo?.evento.tipo) {
      TipoEvento.tiempoMuerto => 'TIEMPO MUERTO',
      TipoEvento.finCuarto => _coreo!.evento.texto.toUpperCase(),
      TipoEvento.cambio => 'CAMBIO · ENTRA ${_apellido(todos[_coreo!.evento.entraId]!)}',
      _ => null,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: esquema.surfaceContainerLowest,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: _final ? null : _alternarPausa,
                          child: AnimatedBuilder(
                            animation: _c,
                            builder: (context, _) {
                              final coreo = _coreo;
                              if (coreo == null) {
                                return CustomPaint(
                                  painter: CanchaPartidoPainter(
                                    franquicia: widget.franquiciaUsuario,
                                    fichas: const [],
                                    balon: const Offset(25, 47),
                                    camaraY: _camara,
                                    colorLed: esquema.primary,
                                  ),
                                );
                              }
                              final t = _c.value;
                              final (balon, altura, poseedor) = coreo.balon(t);
                              final e = coreo.evento;
                              final estela = [
                                if (coreo.enTiro(t))
                                  for (var k = 1; k <= 7; k++) coreo.balon(max(0, t - k * 0.012)).$1,
                              ];
                              return CustomPaint(
                                painter: CanchaPartidoPainter(
                                  franquicia: widget.franquiciaUsuario,
                                  colorLed: esquema.primary,
                                  camaraY: _camara,
                                  margenArriba: 60,
                                  margenAbajo: 50,
                                  balon: balon,
                                  alturaBalon: altura,
                                  estela: estela,
                                  tanto: e.puntos > 0 && t >= coreo.momentoCanasta
                                      ? Tanto(
                                          '+${e.puntos}',
                                          coreo.aro,
                                          ((t - coreo.momentoCanasta) / (1 - coreo.momentoCanasta + 0.0001)).clamp(
                                            0,
                                            1,
                                          ),
                                        )
                                      : null,
                                  fichas: [
                                    for (final (id, p, local, opacidad) in _fichas(coreo, t))
                                      Ficha(
                                        posicion: p,
                                        relleno: local == usuarioLocal ? colorPropio : colorRival,
                                        texto: local == usuarioLocal ? _contraste(colorPropio) : textoRival,
                                        etiqueta: todos[id]!.dorsal > 0 ? '${todos[id]!.dorsal}' : todos[id]!.iniciales,
                                        conBalon: poseedor == id,
                                        nombre: poseedor == id ? _apellido(todos[id]!) : null,
                                        opacidad: opacidad,
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: AnimatedBuilder(
                            animation: _c,
                            builder: (context, _) => _MarcadorTV(
                              local: widget.identidadLocal,
                              visitante: widget.identidadVisitante,
                              puntos: _marcador,
                              cuarto: _cuarto,
                              reloj: _relojDesde + (_relojHasta - _relojDesde) * _c.value,
                              onSalir: _salir,
                            ),
                          ),
                        ),
                        if (banner != null) Center(child: _Banner(texto: banner)),
                        if (_relato.isNotEmpty)
                          Positioned(left: 12, right: 12, bottom: 10, child: _Zocalo(texto: _relato.first)),
                        if (_pausado && !_final)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _alternarPausa,
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.45),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _Banner(texto: 'PAUSA'),
                                      const SizedBox(height: 8),
                                      Text('Tocá para seguir', style: TextStyle(color: esquema.onSurface)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Controles(
                    pausado: _pausado,
                    onPausa: _final ? null : _alternarPausa,
                    velocidad: _velocidad,
                    onVelocidad: _cambiarVelocidad,
                    tiemposMuertos: _m.tiemposMuertos(usuarioLocal),
                    onTiempoMuerto: _final
                        ? null
                        : () {
                            if (_m.pedirTiempoMuerto(usuarioLocal)) HapticFeedback.mediumImpact();
                            setState(() {});
                          },
                    acelerar: _acelerar,
                    onAcelerar: (v) {
                      _m.acelerarRitmo(usuarioLocal, v);
                      setState(() => _acelerar = v);
                    },
                    presion: _presion,
                    onPresion: (v) {
                      _m.presionAlta(usuarioLocal, v);
                      setState(() => _presion = v);
                    },
                  ),
                  SizedBox(
                    height: 236,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SegmentedButton<_Panel>(
                            segments: const [
                              ButtonSegment(value: _Panel.jugadores, label: Text('Mis jugadores')),
                              ButtonSegment(value: _Panel.relato, label: Text('Relato')),
                            ],
                            selected: {_panel},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => setState(() => _panel = s.first),
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          ),
                        ),
                        Expanded(
                          child: _panel == _Panel.jugadores
                              ? _EstadisticasVivo(
                                  jugadores: [..._m.enCancha(usuarioLocal), ?_m.enBanco(usuarioLocal)],
                                  enCancha: {for (final j in _m.enCancha(usuarioLocal)) j.id},
                                  box: _box,
                                  energia: _m.energias(usuarioLocal),
                                )
                              : _RelatoCompleto(lineas: _relato),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_final)
                Positioned.fill(
                  child: _Final(
                    marcador: _marcador,
                    usuarioLocal: usuarioLocal,
                    local: widget.identidadLocal,
                    visitante: widget.identidadVisitante,
                    onContinuar: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marcador estilo transmisión, sobre la cancha.
class _MarcadorTV extends StatelessWidget {
  const _MarcadorTV({
    required this.local,
    required this.visitante,
    required this.puntos,
    required this.cuarto,
    required this.reloj,
    required this.onSalir,
  });

  final Franquicia local, visitante;
  final (int, int) puntos;
  final int cuarto;
  final double reloj;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final r = max(0.0, reloj);
    final minutos = r ~/ 60, segundos = (r % 60).floor();
    final periodo = cuarto > 4 ? 'OT${cuarto > 5 ? cuarto - 4 : ''}' : 'Q$cuarto';
    Widget equipo(Franquicia f, int pts, bool derecha) {
      final color = Color(f.colorPrimario);
      return Expanded(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withValues(alpha: 0.55), esquema.surfaceContainerLowest),
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(derecha ? 0 : 10),
              right: Radius.circular(derecha ? 10 : 0),
            ),
          ),
          child: Row(
            textDirection: derecha ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Escudo(f, tamano: 28),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  f.id,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontFamily: Fuentes.estadio,
                    fontVariations: [FontVariation.weight(800)],
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              FittedBox(child: TextoLed('$pts', tamano: 28, color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label:
          '${local.nombre} ${puntos.$1}, ${visitante.nombre} ${puntos.$2}, $periodo, $minutos minutos $segundos segundos',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Material(
              color: esquema.surfaceContainerLowest.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: IconButton(onPressed: onSalir, icon: const Icon(Icons.close), tooltip: 'Salir del partido'),
            ),
            const SizedBox(width: 6),
            equipo(local, puntos.$1, false),
            Container(
              height: 44,
              width: 74,
              color: esquema.surfaceContainerLowest,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: FittedBox(
                child: Column(
                  children: [
                    TextoLed(periodo, tamano: 12, color: esquema.onSurfaceVariant),
                    TextoLed('$minutos:${'$segundos'.padLeft(2, '0')}', tamano: 19),
                  ],
                ),
              ),
            ),
            equipo(visitante, puntos.$2, true),
          ],
        ),
      ),
    );
  }
}

/// Zócalo inferior con la última jugada, como en la tele.
class _Zocalo extends StatelessWidget {
  const _Zocalo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(texto),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerLowest.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: esquema.primary, width: 1)),
        ),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: esquema.onSurface, fontSize: 13),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: esquema.primary, width: 1.5),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: const [FontVariation.weight(800)],
          fontSize: 22,
          letterSpacing: 1.5,
          color: esquema.onSurface,
        ),
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.pausado,
    required this.onPausa,
    required this.velocidad,
    required this.onVelocidad,
    required this.tiemposMuertos,
    required this.onTiempoMuerto,
    required this.acelerar,
    required this.onAcelerar,
    required this.presion,
    required this.onPresion,
  });

  final bool pausado;
  final VoidCallback? onPausa;
  final int velocidad;
  final ValueChanged<int> onVelocidad;
  final int tiemposMuertos;
  final VoidCallback? onTiempoMuerto;
  final bool acelerar, presion;
  final ValueChanged<bool> onAcelerar, onPresion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
    child: Column(
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: onPausa,
              icon: Icon(pausado ? Icons.play_arrow : Icons.pause),
              tooltip: pausado ? 'Seguir' : 'Pausa',
            ),
            const SizedBox(width: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('x1')),
                ButtonSegment(value: 2, label: Text('x2')),
                ButtonSegment(value: 4, label: Text('x4')),
              ],
              selected: {velocidad},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onVelocidad(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: tiemposMuertos > 0 ? onTiempoMuerto : null,
                child: FittedBox(child: Text('TIEMPO MUERTO · $tiemposMuertos')),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(label: const Text('Acelerar ritmo'), selected: acelerar, onSelected: onAcelerar),
            FilterChip(label: const Text('Presión alta'), selected: presion, onSelected: onPresion),
          ],
        ),
      ],
    ),
  );
}

/// Box score en vivo de tu equipo (se actualiza al terminar cada jugada, sin adelantar resultados).
class _EstadisticasVivo extends StatelessWidget {
  const _EstadisticasVivo({required this.jugadores, required this.enCancha, required this.box, required this.energia});

  final List<Jugador> jugadores;
  final Set<String> enCancha;
  final Map<String, LineaEstadistica> box;
  final Map<String, double> energia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final cabecera = tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant, letterSpacing: 0.5);
    Widget celda(String texto, {TextStyle? estilo, double ancho = 34}) => SizedBox(
      width: ancho,
      child: Text(texto, textAlign: TextAlign.end, style: estilo),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      children: [
        Row(
          children: [
            Expanded(child: Text('JUGADOR', style: cabecera)),
            for (final c in ['MIN', 'PTS', 'REB', 'AST']) celda(c, estilo: cabecera),
            celda('TC', estilo: cabecera, ancho: 46),
          ],
        ),
        for (final j in jugadores)
          () {
            final l = box[j.id] ?? LineaEstadistica();
            final juega = enCancha.contains(j.id);
            final valores = TextStyle(
              fontFamily: Fuentes.led,
              fontVariations: const [FontVariation.weight(800)],
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: 15,
              color: juega ? esquema.onSurface : esquema.onSurfaceVariant,
            );
            return Semantics(
              label:
                  '${j.nombre}${juega ? '' : ', en el banco'}: ${l.pts} puntos, ${l.reb} rebotes, ${l.ast} asistencias',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: juega ? esquema.primary : esquema.outlineVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              j.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: juega ? esquema.onSurface : esquema.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FractionallySizedBox(
                              widthFactor: 0.7,
                              alignment: Alignment.centerLeft,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (energia[j.id] ?? 100) / 100,
                                  minHeight: 3,
                                  color: (energia[j.id] ?? 100) < 60 ? esquema.error : esquema.primary,
                                  backgroundColor: esquema.surfaceContainerHighest,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      celda('${(l.seg / 60).floor()}', estilo: valores),
                      celda('${l.pts}', estilo: valores.copyWith(color: juega ? esquema.primary : null)),
                      celda('${l.reb}', estilo: valores),
                      celda('${l.ast}', estilo: valores),
                      celda('${l.tcI}/${l.tcA}', estilo: valores, ancho: 46),
                    ],
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

class _RelatoCompleto extends StatelessWidget {
  const _RelatoCompleto({required this.lineas});

  final List<String> lineas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      itemCount: lineas.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          lineas[i],
          style: tema.textTheme.bodySmall?.copyWith(
            color: i == 0 ? tema.colorScheme.onSurface : tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({
    required this.marcador,
    required this.usuarioLocal,
    required this.local,
    required this.visitante,
    required this.onContinuar,
  });

  final (int, int) marcador;
  final bool usuarioLocal;
  final Franquicia local, visitante;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gano = usuarioLocal ? marcador.$1 > marcador.$2 : marcador.$2 > marcador.$1;
    return ColoredBox(
      color: tema.colorScheme.surfaceContainerLowest.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('FINAL', style: tema.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Escudo(local, tamano: 48),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextoLed('${marcador.$1}-${marcador.$2}', tamano: 52),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Escudo(visitante, tamano: 48),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                gano ? '¡VICTORIA!' : 'DERROTA',
                style: tema.textTheme.displayLarge?.copyWith(
                  fontSize: 44,
                  color: gano ? tema.colorScheme.primary : null,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onContinuar, child: const Text('CONTINUAR')),
            ],
          ),
        ),
      ),
    );
  }
}
