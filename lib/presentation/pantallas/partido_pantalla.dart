import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import '../partido/cancha_partido.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Partido en vivo 2D (GDD §6): marcador LED desde 0-0, reloj por cuarto, fichas que se mueven, pases,
/// tiros con estela, cambios del Sexto Hombre e intervenciones del entrenador. Al terminar (o si el
/// usuario sale, que simula lo que falta) llama a [onTerminado] con el motor ya completo.
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

class _PartidoPantallaState extends State<PartidoPantalla> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this)..addStatusListener(_alTerminarEvento);
  EventoPartido? _evento;
  var _velocidad = 1;
  var _acelerar = false, _presion = false;
  var _marcador = (0, 0);
  var _cuarto = 1;
  var _reloj = 720.0;
  final _relato = <String>[];
  final _posiciones = <String, Offset>{}; // dónde quedó cada jugador al terminar la jugada anterior
  late List<Jugador> _canchaLocal = widget.motor.enCancha(true), _canchaVisitante = widget.motor.enCancha(false);
  bool _final = false, _registrado = false;

  MotorPartido get _m => widget.motor;

  static const _ataque = [Offset(25, 26), Offset(42, 19), Offset(8, 19), Offset(33, 11), Offset(18, 7)];
  static const _defensa = [Offset(25, 20), Offset(37, 15), Offset(13, 15), Offset(30, 8), Offset(21, 5)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _proximo());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _proximo() {
    if (!mounted || _m.terminado) return;
    final e = _m.siguiente();
    _canchaLocal = _m.enCancha(true);
    _canchaVisitante = _m.enCancha(false);
    final base = switch (e.tipo) {
      TipoEvento.tiro => e.contraataque ? 900 : 1150,
      TipoEvento.libres => 950,
      TipoEvento.perdida => 750,
      TipoEvento.cambio => 900,
      TipoEvento.tiempoMuerto => 1500,
      TipoEvento.finCuarto || TipoEvento.finPartido => 1600,
    };
    final reducido = MediaQuery.disableAnimationsOf(context);
    setState(() => _evento = e);
    _c.duration = Duration(milliseconds: reducido ? 250 : base ~/ _velocidad);
    _c.forward(from: 0);
  }

  void _alTerminarEvento(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    final e = _evento!;
    // Guardar dónde quedó cada ficha para que la próxima jugada arranque desde ahí.
    for (final (id, pos) in _fichasEn(e, 1).map((f) => (f.$1, f.$2))) {
      _posiciones[id] = pos;
    }
    setState(() {
      _marcador = (e.marcadorLocal, e.marcadorVisitante);
      _cuarto = e.cuarto;
      _reloj = e.reloj;
      _relato.insert(0, e.texto);
      if (_relato.length > 3) _relato.removeLast();
    });
    if (e.convertido && e.puntos > 0 && (e.local == widget.usuarioLocal)) HapticFeedback.lightImpact();
    if (e.tipo == TipoEvento.finPartido) {
      _terminar();
    } else {
      _proximo();
    }
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
    final seguir = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir del partido?'),
        content: const Text('Lo que falta se simula al instante con el resultado que salga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir mirando')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simular y salir')),
        ],
      ),
    );
    if (seguir != true || !mounted) return;
    _c.stop();
    _m.simularTodo();
    _terminar();
    if (mounted) Navigator.of(context).pop();
  }

  bool _haciaArriba(bool local) => (local) == (_cuarto <= 2);

  Offset _formacion(List<Offset> base, int i, bool haciaArriba) {
    final o = base[i];
    return Offset(o.dx, haciaArriba ? o.dy : Cancha94.largo - o.dy);
  }

  /// Posición de cada jugador en el instante t (0–1) de la jugada: corren desde donde estaban hasta su
  /// formación, con un vaivén leve para que se vean vivos.
  List<(String, Offset, bool)> _fichasEn(EventoPartido e, double t) {
    final ataqueLocal = e.local;
    final resultado = <(String, Offset, bool)>[];
    for (final local in [true, false]) {
      final jugadores = local ? _canchaLocal : _canchaVisitante;
      final ataca = local == ataqueLocal && e.tipo != TipoEvento.finCuarto && e.tipo != TipoEvento.tiempoMuerto;
      final haciaArriba = _haciaArriba(ataqueLocal);
      for (final (i, j) in jugadores.indexed) {
        var destino = _formacion(ataca ? _ataque : _defensa, i, haciaArriba);
        if (e.tipo == TipoEvento.finCuarto || e.tipo == TipoEvento.tiempoMuerto) {
          destino = Offset(local ? 8 + i * 1.5 : 42 - i * 1.5, 40 + i * 3.5); // a los bancos
        }
        if (ataca && e.contraataque && j.id == e.jugadorId) {
          destino = Cancha94.aro(haciaArriba) + Offset(0, haciaArriba ? 4 : -4);
        }
        final desde = _posiciones[j.id] ?? destino;
        final corrida = Curves.easeInOutCubic.transform((t / 0.45).clamp(0.0, 1.0));
        final vaiven = Offset(sin(t * 6 + i) * 0.8, cos(t * 5 + i * 2) * 0.8);
        resultado.add((j.id, Offset.lerp(desde, destino, corrida)! + vaiven * (1 - corrida * 0.5), local));
      }
    }
    return resultado;
  }

  /// Recorrido del balón: pases → tiro en arco hasta el aro → adentro o al rebote.
  (Offset, double) _balonEn(EventoPartido e, double t, Map<String, Offset> pos) {
    final aro = Cancha94.aro(_haciaArriba(e.local));
    Offset de(String? id) => pos[id] ?? const Offset(25, 47);
    switch (e.tipo) {
      case TipoEvento.tiro || TipoEvento.libres:
        final tirador = e.tipo == TipoEvento.libres
            ? Offset(25, _haciaArriba(e.local) ? 19 : Cancha94.largo - 19)
            : de(e.jugadorId);
        final inicio = e.asistenteId != null ? de(e.asistenteId) : tirador;
        if (t < 0.45) return (Offset.lerp(inicio, tirador, Curves.easeInOut.transform((t / 0.45).clamp(0, 1)))!, 0);
        if (t < 0.78) {
          final u = (t - 0.45) / 0.33;
          return (Offset.lerp(tirador, aro, u)!, sin(pi * u));
        }
        final u = (t - 0.78) / 0.22;
        if (e.convertido || e.reboteId == null) return (aro + Offset(0, u * 1.5), 0);
        return (Offset.lerp(aro, de(e.reboteId), Curves.easeOut.transform(u))!, 0.2 * (1 - u));
      case TipoEvento.perdida:
        return (Offset.lerp(de(e.jugadorId), de(e.defensorId ?? e.jugadorId), Curves.easeInOut.transform(t))!, 0);
      default:
        return (const Offset(25, 47), 0);
    }
  }

  Color _contraste(Color c) => c.computeLuminance() > 0.4 ? Colors.black : Colors.white;

  (Color, Color) _coloresRival(Franquicia rival) {
    final propio = Color(widget.franquiciaUsuario.colorPrimario);
    var color = Color(rival.colorPrimario);
    double distancia(Color a, Color b) => (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
    if (distancia(color, propio) < 0.35) color = Color(rival.colorSecundario);
    if (distancia(color, propio) < 0.35) color = propio.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    return (color, _contraste(color));
  }

  String _etiqueta(Jugador j) => j.dorsal > 0 ? '${j.dorsal}' : j.iniciales;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final usuarioLocal = widget.usuarioLocal;
    final rival = usuarioLocal ? widget.identidadVisitante : widget.identidadLocal;
    final (colorRival, textoRival) = _coloresRival(rival);
    final colorPropio = Color(widget.franquiciaUsuario.colorPrimario);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Marcador(
                    local: widget.identidadLocal,
                    visitante: widget.identidadVisitante,
                    puntos: _marcador,
                    cuarto: _cuarto,
                    reloj: _reloj,
                    onSalir: _salir,
                  ),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: Cancha94.proporcion,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final pie = c.maxWidth / (Cancha94.ancho + 2 * Cancha94.borde);
                            final escudo = 10 * pie;
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _c,
                                    builder: (context, _) {
                                      final e = _evento;
                                      final t = _c.value;
                                      final fichas = e == null ? const <(String, Offset, bool)>[] : _fichasEn(e, t);
                                      final pos = {for (final f in fichas) f.$1: f.$2};
                                      final (balon, altura) = e == null
                                          ? (const Offset(25, 47), 0.0)
                                          : _balonEn(e, t, pos);
                                      final estela = [
                                        if (e != null &&
                                            (e.tipo == TipoEvento.tiro || e.tipo == TipoEvento.libres) &&
                                            t > 0.45 &&
                                            t < 0.8)
                                          for (var k = 1; k <= 6; k++) _balonEn(e, max(0.45, t - k * 0.02), pos).$1,
                                      ];
                                      final todos = {
                                        for (final j in [..._canchaLocal, ..._canchaVisitante]) j.id: j,
                                      };
                                      return CustomPaint(
                                        painter: CanchaPartidoPainter(
                                          franquicia: widget.franquiciaUsuario,
                                          colorLed: esquema.primary,
                                          balon: balon,
                                          alturaBalon: altura,
                                          estela: estela,
                                          fichas: [
                                            for (final (id, p, local) in fichas)
                                              Ficha(
                                                posicion: p,
                                                relleno: local == usuarioLocal ? colorPropio : colorRival,
                                                texto: local == usuarioLocal ? _contraste(colorPropio) : textoRival,
                                                etiqueta: _etiqueta(todos[id]!),
                                                conBalon: e?.jugadorId == id && t < 0.5,
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  left: c.maxWidth / 2 - escudo / 2,
                                  top: (47 + Cancha94.borde) * pie - escudo / 2,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: 0.85,
                                      child: Escudo(widget.franquiciaUsuario, tamano: escudo),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  _Relato(lineas: _relato),
                  _Controles(
                    velocidad: _velocidad,
                    onVelocidad: (v) => setState(() => _velocidad = v),
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
                  _Estamina(
                    jugadores: [...(usuarioLocal ? _canchaLocal : _canchaVisitante), ?_m.enBanco(usuarioLocal)],
                    todos: _m.energias(usuarioLocal),
                    banco: _m.enBanco(usuarioLocal)?.id,
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

class _Marcador extends StatelessWidget {
  const _Marcador({
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
    final minutos = reloj ~/ 60, segundos = (reloj % 60).floor();
    final periodo = cuarto > 4 ? 'OT${cuarto > 5 ? cuarto - 4 : ''}' : 'Q$cuarto';
    Widget equipo(Franquicia f, int pts, bool derecha) => Expanded(
      child: Row(
        mainAxisAlignment: derecha ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!derecha) ...[Escudo(f, tamano: 30), const SizedBox(width: 6)],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                crossAxisAlignment: derecha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  TextoLed(f.id, tamano: 13, color: esquema.onSurfaceVariant),
                  TextoLed('$pts', tamano: 34, color: Color.lerp(colorLed(f), Colors.white, 0.1)),
                ],
              ),
            ),
          ),
          if (derecha) ...[const SizedBox(width: 6), Escudo(f, tamano: 30)],
        ],
      ),
    );
    return Semantics(
      label:
          '${local.nombre} ${puntos.$1}, ${visitante.nombre} ${puntos.$2}, $periodo, $minutos minutos $segundos segundos',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(onPressed: onSalir, icon: const Icon(Icons.close), tooltip: 'Salir del partido'),
              equipo(local, puntos.$1, false),
              Column(
                children: [
                  TextoLed(periodo, tamano: 14, color: esquema.onSurfaceVariant),
                  TextoLed('$minutos:${'$segundos'.padLeft(2, '0')}', tamano: 22),
                ],
              ),
              equipo(visitante, puntos.$2, true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Relato extends StatelessWidget {
  const _Relato({required this.lineas});

  final List<String> lineas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, l) in lineas.take(3).indexed)
              Text(
                l,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: i == 0
                      ? tema.colorScheme.onSurface
                      : tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.8 - i * 0.2),
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.velocidad,
    required this.onVelocidad,
    required this.tiemposMuertos,
    required this.onTiempoMuerto,
    required this.acelerar,
    required this.onAcelerar,
    required this.presion,
    required this.onPresion,
  });

  final int velocidad;
  final ValueChanged<int> onVelocidad;
  final int tiemposMuertos;
  final VoidCallback? onTiempoMuerto;
  final bool acelerar, presion;
  final ValueChanged<bool> onAcelerar, onPresion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
    child: Column(
      children: [
        Row(
          children: [
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

class _Estamina extends StatelessWidget {
  const _Estamina({required this.jugadores, required this.todos, required this.banco});

  final List<Jugador> jugadores;
  final Map<String, double> todos;

  /// Quién está en el banco (se ve atenuado).
  final String? banco;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          for (final j in jugadores)
            Expanded(
              child: Semantics(
                label: '${j.nombre}${j.id == banco ? ' (banco)' : ''}: estamina ${todos[j.id]!.round()}',
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: j.id == banco ? 0.45 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: [
                          Text(
                            j.nombre.split(' ').last.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontFamily: Fuentes.estadio,
                              fontVariations: const [FontVariation.weight(700)],
                              fontSize: 11,
                              color: esquema.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: todos[j.id]! / 100,
                              minHeight: 5,
                              color: todos[j.id]! < 60 ? esquema.error : esquema.primary,
                              backgroundColor: esquema.surfaceContainerLowest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
