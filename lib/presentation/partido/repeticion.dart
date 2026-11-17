import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import 'cancha_partido.dart';
import 'coreografia.dart';
import '../tema/vestuario.dart';
import '../widgets/texto_led.dart';
import 'escena_cancha.dart';
import 'publico.dart';

/// Colores de las dos camisetas del partido (relleno, número y ribete).
class Equipaciones {
  const Equipaciones({
    required this.propio,
    required this.textoPropio,
    required this.ribetePropio,
    required this.rival,
    required this.textoRival,
    required this.ribeteRival,
  });

  final Color propio, textoPropio, ribetePropio, rival, textoRival, ribeteRival;
}

/// Una jugada guardada para volver a verla: la coreografía completa y qué tan buena fue.
class Destacada {
  const Destacada({
    required this.coreo,
    required this.frase,
    required this.puntaje,
    required this.atacaLocal,
    required this.cuarto,
    required this.reloj,
  });

  final Coreografia coreo;
  final String frase;
  final int puntaje;
  final bool atacaLocal;
  final int cuarto;
  final double reloj;

  /// Cuánto vale una jugada para el resumen (volcadas, triples, tapones, robos, finales apretados).
  static int valor(EventoPartido e, {required bool clutch}) {
    var v = 0;
    if (e.alleyOop) v += 6;
    if (e.volcada) v += 4;
    if (e.triple && e.convertido) v += 3;
    if (e.taponado) v += 3;
    if (e.tipo == TipoEvento.perdida && e.defensorId != null) v += 2;
    if (e.contraataque && e.convertido) v += 1;
    if (e.chicharra && e.convertido) v += e.desdeLejos ? 8 : 4;
    if (e.perdida == TipoPerdida.carga) v += 3;
    if (e.falta == TipoFalta.flagrante) v += 3;
    if (e.interferencia) v += 2;
    if (e.taponado && e.reboteOfensivo) v -= 1;
    if (clutch && e.puntos > 0) v += 3;
    return v;
  }
}

/// Plano de repetición: el de la transmisión, pero más cerca (la repetición siempre va de cerca).
({double x, double y, double zoom}) planoRepeticion(Coreografia coreo, double t) {
  final p = coreo.plano(t);
  return (x: p.x, y: p.y, zoom: min(1.6, max(p.zoom, 1.0) + 0.25));
}

/// Repetición en cámara lenta de una jugada, con cámara que la sigue de cerca.
class Repeticion extends StatefulWidget {
  const Repeticion({
    super.key,
    required this.destacada,
    required this.franquicia,
    required this.equipaciones,
    required this.jugadores,
    required this.usuarioLocal,
    this.escudo,
    this.lentitud = 2.5,
  });

  final Destacada destacada;
  final Franquicia franquicia;
  final Equipaciones equipaciones;
  final Map<String, Jugador> jugadores;
  final bool usuarioLocal;
  final ui.Image? escudo;

  /// Cuántas veces más lenta que a x1.
  final double lentitud;

  @override
  State<Repeticion> createState() => _RepeticionState();
}

class _RepeticionState extends State<Repeticion> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.destacada.coreo.duracion * 1000 * widget.lentitud).round()),
  );

  var _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final coreo = widget.destacada.coreo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 0.9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return CustomPaint(
                  size: Size.infinite,
                  painter: cuadroDeCancha(
                    coreo: coreo,
                    t: t,
                    atacaLocal: widget.destacada.atacaLocal,
                    usuarioLocal: widget.usuarioLocal,
                    franquicia: widget.franquicia,
                    equipaciones: widget.equipaciones,
                    jugadores: widget.jugadores,
                    colorLed: Vestuario.led() ?? esquema.primary,
                    estilo: Vestuario.cancha(),
                    escudo: widget.escudo,
                    plano: planoRepeticion(coreo, t),
                    tiempo: t * coreo.duracion * widget.lentitud,
                    ambiente: const AmbienteCancha(publico: PublicoEstado(excitacion: 0.7)),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.destacada.frase, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => _c.forward(from: 0),
          icon: const Icon(Icons.replay),
          label: const Text('REPETIR'),
        ),
      ],
    );
  }
}

/// Repetición instantánea durante el partido: corta a la jugada destacada, en cámara lenta alrededor del
/// momento clave (zoom, cartel "REPETICIÓN" y cortina del color del equipo) y avisa con [onTerminar]
/// cuando termina o cuando el usuario toca para saltearla.
class RepeticionEnVivo extends StatefulWidget {
  const RepeticionEnVivo({
    super.key,
    required this.destacada,
    required this.franquicia,
    required this.equipaciones,
    required this.jugadores,
    required this.usuarioLocal,
    required this.colorLed,
    required this.estilo,
    required this.onTerminar,
    this.escudo,
    this.playoffs = false,
    this.velocidad = 1,
    this.margenArriba = 0,
    this.margenAbajo = 0,
  });

  final Destacada destacada;
  final Franquicia franquicia;
  final Equipaciones equipaciones;
  final Map<String, Jugador> jugadores;
  final bool usuarioLocal, playoffs;
  final Color colorLed;
  final EstiloCancha estilo;
  final VoidCallback onTerminar;
  final ui.Image? escudo;

  /// Velocidad del partido (x1, x2, x4): la repetición dura menos si se juega rápido.
  final int velocidad;
  final double margenArriba, margenAbajo;

  /// Cuánto más lenta va la repetición alrededor del momento clave.
  static const lentitudClave = 3.0;

  /// Segundos de la jugada (a velocidad normal) que muestra la repetición antes del momento clave.
  static const antes = 3.0;

  @override
  State<RepeticionEnVivo> createState() => _RepeticionEnVivoState();
}

class _RepeticionEnVivoState extends State<RepeticionEnVivo> with SingleTickerProviderStateMixin {
  late final Coreografia _coreo = widget.destacada.coreo;
  late final double _clave = (_coreo.momentoClimax ?? 0.85) * _coreo.duracion;
  late final double _desde = max(0.0, _clave - RepeticionEnVivo.antes);

  /// Tabla del tiempo de repetición (0–1 del controlador) al segundo de la jugada, con cámara lenta
  /// alrededor del momento clave.
  late final List<double> _tabla = () {
    const n = 160;
    final fin = _coreo.duracion;
    double peso(double s) => (s > _clave - 0.5 && s < _clave + 0.9) ? RepeticionEnVivo.lentitudClave : 1.0;
    final acum = <double>[0];
    for (var k = 1; k <= n; k++) {
      final s = _desde + (fin - _desde) * (k - 0.5) / n;
      acum.add(acum.last + peso(s) * (fin - _desde) / n);
    }
    return acum;
  }();

  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (_tabla.last * 1000 / (widget.velocidad >= 4 ? 1.6 : 1)).round() + 900),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onTerminar();
      });

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Segundo de la jugada (0–1 de su duración) para el avance [u] de la repetición.
  double _t(double u) {
    // Los primeros y últimos 0,45 s son de la cortina; el resto es la jugada.
    final v = ((u - 0.06) / 0.88).clamp(0.0, 1.0);
    final real = v * _tabla.last;
    var k = 1;
    while (k < _tabla.length - 1 && _tabla[k] < real) {
      k++;
    }
    final f = ((real - _tabla[k - 1]) / max(1e-9, _tabla[k] - _tabla[k - 1])).clamp(0.0, 1.0);
    final s = _desde + (_coreo.duracion - _desde) * ((k - 1) + f) / (_tabla.length - 1);
    return (s / _coreo.duracion).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final d = widget.destacada;
    final propio = d.atacaLocal == widget.usuarioLocal;
    final cortina = propio ? widget.equipaciones.propio : widget.equipaciones.rival;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTerminar,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final u = _c.value;
            final t = _t(u);
            final cortinaU = u < 0.06 ? 1 - u / 0.06 : (u > 0.94 ? (u - 0.94) / 0.06 : 0.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: cuadroDeCancha(
                    coreo: _coreo,
                    t: t,
                    atacaLocal: d.atacaLocal,
                    usuarioLocal: widget.usuarioLocal,
                    franquicia: widget.franquicia,
                    equipaciones: widget.equipaciones,
                    jugadores: widget.jugadores,
                    colorLed: widget.colorLed,
                    estilo: widget.estilo,
                    escudo: widget.escudo,
                    plano: planoRepeticion(_coreo, t),
                    cartel: 'REPETICIÓN',
                    tiempo: u * 6,
                    margenArriba: widget.margenArriba,
                    margenAbajo: widget.margenAbajo,
                    ambiente: AmbienteCancha(
                      publico: PublicoEstado(excitacion: 0.9, playoffs: widget.playoffs),
                      luzDramatica: widget.playoffs ? 0.6 : 0.2,
                    ),
                  ),
                ),
                // Tinte frío de repetición.
                const IgnorePointer(child: ColoredBox(color: Color(0x143060FF))),
                Positioned(
                  left: 12,
                  top: widget.margenArriba + 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: esquema.surfaceContainerLowest.withValues(alpha: 0.92),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (u * 8).floor().isEven ? esquema.error : esquema.error.withValues(alpha: 0.25),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextoLed('REPETICIÓN', tamano: 16, color: widget.colorLed),
                      ],
                    ),
                  ),
                ),
                if (cortinaU > 0)
                  IgnorePointer(
                    child: FractionallySizedBox(
                      alignment: u < 0.5 ? Alignment.centerRight : Alignment.centerLeft,
                      widthFactor: cortinaU,
                      child: ColoredBox(color: cortina),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: widget.margenAbajo + 6,
                  child: Text(
                    'Tocá para seguir',
                    style: TextStyle(color: esquema.onSurface.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
