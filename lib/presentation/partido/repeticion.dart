import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import 'cancha_partido.dart';
import 'coreografia.dart';

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
    if (clutch && e.puntos > 0) v += 3;
    return v;
  }
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

  String _apellido(Jugador j) => j.nombre.split(' ').last.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final coreo = widget.destacada.coreo;
    final eq = widget.equipaciones;
    final atacaLocal = widget.destacada.atacaLocal;
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
                final (balon, altura, poseedor) = coreo.balon(t);
                final e = coreo.evento;
                EfectoAro? efecto;
                if (e.puntos > 0 && e.tipo == TipoEvento.tiro && t >= coreo.momentoCanasta) {
                  efecto = EfectoAro(
                    arriba: coreo.haciaArriba,
                    progreso: ((t - coreo.momentoCanasta) * coreo.duracion / 0.9).clamp(0, 1),
                    adentro: true,
                    fuerte: e.volcada,
                  );
                } else if (coreo.momentoAro case final m? when t >= m) {
                  efecto = EfectoAro(
                    arriba: coreo.haciaArriba,
                    progreso: ((t - m) * coreo.duracion / 0.7).clamp(0, 1),
                    adentro: false,
                  );
                }
                Ficha ficha(Jugador j, bool local, Offset p, double opacidad) {
                  final propio = local == widget.usuarioLocal;
                  return Ficha(
                    posicion: p,
                    relleno: propio ? eq.propio : eq.rival,
                    texto: propio ? eq.textoPropio : eq.textoRival,
                    ribete: propio ? eq.ribetePropio : eq.ribeteRival,
                    etiqueta: j.dorsal > 0 ? '${j.dorsal}' : j.iniciales,
                    conBalon: poseedor == j.id,
                    nombre: poseedor == j.id ? _apellido(j) : null,
                    opacidad: opacidad,
                  );
                }

                return CustomPaint(
                  size: Size.infinite,
                  painter: CanchaPartidoPainter(
                    franquicia: widget.franquicia,
                    colorLed: esquema.primary,
                    camaraY: coreo.foco(t),
                    camaraX: Cancha94.ancho / 2 + (balon.dx - Cancha94.ancho / 2) * 0.7,
                    zoom: min(1.35, coreo.zoom(t) + 0.12),
                    escudo: widget.escudo,
                    balon: balon,
                    alturaBalon: altura,
                    efectoAro: efecto,
                    estela: [
                      if (coreo.enTiro(t))
                        for (var k = 1; k <= 7; k++) coreo.balon(max(0, t - k * 0.012)).$1,
                    ],
                    fichas: [
                      for (final j in coreo.atacantes) ficha(j, atacaLocal, coreo.posicion(j.id, t), 1),
                      for (final j in coreo.defensores) ficha(j, !atacaLocal, coreo.posicion(j.id, t), 1),
                    ],
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
