import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import 'camara.dart';
import 'cancha_partido.dart';
import 'coreografia.dart';
import 'jugadores_animados.dart';
import 'publico.dart';
import 'racha.dart';
import 'repeticion.dart' show Equipaciones;

/// Arma el cuadro de la cancha en el instante [t] de una coreografía: 10 figuras con su cuerpo, la
/// pelota, el aro, los técnicos en las pausas y el ambiente. Lo usan la escena en vivo, la repetición
/// y las capturas, así se ven igual.
CanchaPartidoPainter cuadroDeCancha({
  required Coreografia coreo,
  required double t,
  required bool atacaLocal,
  required bool usuarioLocal,
  required Franquicia franquicia,
  required Equipaciones equipaciones,
  required Map<String, Jugador> jugadores,
  required Color colorLed,
  required EstiloCancha estilo,
  required ({double x, double y, double zoom}) plano,
  Map<String, double> energias = const {},
  RachaTiradores? racha,
  ui.Image? escudo,
  Offset temblor = Offset.zero,
  String cartel = '',
  double tiempo = 0,
  double margenArriba = 0,
  double margenAbajo = 0,
  AmbienteCancha ambiente = const AmbienteCancha(),
}) {
  final eq = equipaciones;
  final (balon, altura, poseedor) = coreo.balon(t);
  final e = coreo.evento;
  EfectoAro? efectoAro;
  if (e.puntos > 0 && e.tipo == TipoEvento.tiro && t >= coreo.momentoCanasta) {
    efectoAro = EfectoAro(
      arriba: coreo.haciaArriba,
      progreso: ((t - coreo.momentoCanasta) * coreo.duracion / 0.9).clamp(0, 1),
      adentro: true,
      fuerte: e.volcada,
    );
  } else if (coreo.momentoAro case final m? when t >= m) {
    efectoAro = EfectoAro(
      arriba: coreo.haciaArriba,
      progreso: ((t - m) * coreo.duracion / 0.7).clamp(0, 1),
      adentro: false,
    );
  }
  Ficha ficha(Jugador j, bool local, Offset p, double opacidad, {bool conPostura = true}) {
    final propio = local == usuarioLocal;
    return Ficha(
      posicion: p,
      relleno: propio ? eq.propio : eq.rival,
      texto: propio ? eq.textoPropio : eq.textoRival,
      ribete: propio ? eq.ribetePropio : eq.ribeteRival,
      energia: energias[j.id] ?? 1,
      etiqueta: j.iniciales,
      conBalon: poseedor == j.id,
      nombre: poseedor == j.id ? apellidoMayus(j) : null,
      opacidad: opacidad,
      salto: coreo.salto(j.id, t),
      postura: conPostura ? coreo.postura(j.id, t) : const PosturaJugador(pose: Pose.corre, velocidad: 6),
      semilla: hashEstable(j.id),
      enLlamas: racha?.enLlamas(j.id) ?? false,
    );
  }

  final propioAtaca = atacaLocal == usuarioLocal;
  final colAtaque = propioAtaca ? (eq.propio, eq.ribetePropio) : (eq.rival, eq.ribeteRival);
  final colDefensa = propioAtaca ? (eq.rival, eq.ribeteRival) : (eq.propio, eq.ribetePropio);
  final tecnicos = [
    for (final tec in coreo.tecnicos(t))
      Ficha(
        posicion: tec.pos,
        relleno: const Color(0xFF1F2430),
        texto: Colors.white,
        ribete: (tec.atacante ? colAtaque : colDefensa).$1,
        etiqueta: 'DT',
        postura: tec.postura,
        semilla: tec.atacante ? 5 : 9,
        esTecnico: true,
      ),
  ];
  final saliente = coreo.saliente;
  return CanchaPartidoPainter(
    franquicia: franquicia,
    colorLed: colorLed,
    estilo: estilo,
    escudo: escudo,
    camaraX: plano.x,
    camaraY: plano.y,
    zoom: plano.zoom,
    temblor: temblor,
    cartel: cartel,
    tiempo: tiempo,
    efectoAro: efectoAro,
    margenArriba: margenArriba,
    margenAbajo: margenAbajo,
    balon: balon,
    alturaBalon: altura,
    estela: [
      if (coreo.enTiro(t))
        for (var k = 1; k <= 7; k++) coreo.balon(max(0, t - k * 0.012)).$1,
    ],
    tanto: e.puntos > 0 && t >= coreo.momentoCanasta
        ? Tanto(
            '+${e.puntos}',
            coreo.aro,
            ((t - coreo.momentoCanasta) / (1 - coreo.momentoCanasta + 0.0001)).clamp(0, 1),
          )
        : null,
    ambiente: ambiente.conEscena(bancoAtaque: colAtaque, bancoDefensa: colDefensa, tecnicos: tecnicos),
    fichas: [
      for (final j in coreo.atacantes) ficha(j, atacaLocal, coreo.posicion(j.id, t), 1),
      for (final j in coreo.defensores) ficha(j, !atacaLocal, coreo.posicion(j.id, t), 1),
      ?_saliente(saliente, coreo.salienteEn(t), e.local, ficha),
    ],
  );
}

Ficha? _saliente(
  Jugador? j,
  (Offset, double)? en,
  bool local,
  Ficha Function(Jugador, bool, Offset, double, {bool conPostura}) ficha,
) => j == null || en == null ? null : ficha(j, local, en.$1, en.$2, conPostura: false);

String apellidoMayus(Jugador j) {
  final partes = j.nombre.split(' ');
  return (partes.length > 1 ? partes.last : j.nombre).toUpperCase();
}

/// La cancha en vivo: pinta la jugada en curso sin reconstruir widgets (el pintor se repinta con el
/// controlador de la jugada y un ticker propio), con la cámara de transmisión, la tribuna que
/// reacciona, el banco, los técnicos en las pausas y el humo del tirador encendido.
class EscenaCancha extends StatefulWidget {
  const EscenaCancha({
    super.key,
    required this.progreso,
    required this.coreo,
    required this.atacaLocal,
    required this.usuarioLocal,
    required this.franquicia,
    required this.franquiciaLocal,
    required this.franquiciaVisitante,
    required this.equipaciones,
    required this.jugadores,
    required this.energias,
    required this.estilo,
    required this.colorLed,
    required this.cartel,
    this.escudo,
    this.margenArriba = 0,
    this.margenAbajo = 0,
    this.pausado = false,
    this.playoffs = false,
    this.clutch = false,
    this.racha,
    this.reducido = false,
  });

  final Animation<double> progreso;
  final Coreografia? coreo;
  final bool atacaLocal, usuarioLocal;
  final Franquicia franquicia, franquiciaLocal, franquiciaVisitante;
  final Equipaciones equipaciones;
  final Map<String, Jugador> jugadores;
  final Map<String, double> energias;
  final EstiloCancha estilo;
  final Color colorLed;
  final String Function(Coreografia? coreo, double t) cartel;
  final ui.Image? escudo;
  final double margenArriba, margenAbajo;
  final bool pausado, playoffs, clutch, reducido;
  final RachaTiradores? racha;

  @override
  State<EscenaCancha> createState() => EscenaCanchaState();
}

class EscenaCanchaState extends State<EscenaCancha> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_alCuadro);
  final _tick = ValueNotifier<int>(0);
  final camara = CamaraTransmision();
  Duration _ultimo = Duration.zero;
  double tiempo = 0;
  double _excitacion = 0.12, _abucheo = 0, _tension = 0, _destello = 0, _levAtaque = 0, _levDefensa = 0;
  double _ola = -1, _proximaOla = 25, _humo = 0;
  Coreografia? _coreoPrevia;

  @override
  void initState() {
    super.initState();
    if (!widget.pausado) _ticker.start();
  }

  @override
  void didUpdateWidget(EscenaCancha oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pausado && _ticker.isActive) {
      _ticker.stop();
    } else if (!widget.pausado && !_ticker.isActive) {
      _ultimo = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  void _alCuadro(Duration elapsed) {
    final dt = _ultimo == Duration.zero ? 0.016 : min(0.1, (elapsed - _ultimo).inMicroseconds / 1e6);
    _ultimo = elapsed;
    tiempo += dt;
    final coreo = widget.coreo;
    final t = widget.progreso.value;
    camara.avanzar(coreo, t, dt, reducido: widget.reducido);
    _reaccionar(coreo, t, dt);
    _tick.value++;
  }

  /// Tribuna, banco y destellos según lo que pasó en la jugada.
  void _reaccionar(Coreografia? coreo, double t, double dt) {
    var excita = widget.playoffs ? 0.28 : 0.12;
    var abuchea = 0.0;
    var levAtaque = 0.0, levDefensa = 0.0;
    var destello = 0.0;
    var fuego = false;
    if (coreo != null) {
      final e = coreo.evento;
      final grande = e.volcada || e.triple || e.alleyOop || e.chicharra || e.contraataque;
      if (e.puntos > 0 && t >= coreo.momentoCanasta) {
        if (e.local) {
          excita = grande ? 1.0 : 0.6;
        } else {
          abuchea = grande ? 0.9 : 0.35;
          excita = 0.1;
        }
        if (grande) {
          levAtaque = 1;
          destello = max(0.0, 1 - (t - coreo.momentoCanasta) * coreo.duracion / 1.0);
        }
      }
      if (e.taponado && coreo.momentoTapon != null && t >= coreo.momentoTapon!) {
        if (!e.local) excita = 0.9;
        destello = 0.7;
      }
      if (e.tipo == TipoEvento.tiempoMuerto) {
        levAtaque = levDefensa = (coreo.duracion * t > 1.0) ? 1 : 0;
      }
      if (widget.clutch) excita = max(excita, 0.35);
      for (final j in [...coreo.atacantes, ...coreo.defensores]) {
        if (widget.racha?.enLlamas(j.id) ?? false) fuego = true;
      }
    }
    if (!identical(coreo, _coreoPrevia)) _coreoPrevia = coreo;
    _excitacion += (excita - _excitacion) * (1 - exp(-dt * (excita > _excitacion ? 6 : 0.7)));
    _abucheo += (abuchea - _abucheo) * (1 - exp(-dt * (abuchea > _abucheo ? 5 : 1.2)));
    _tension += ((widget.clutch ? 1.0 : 0.0) - _tension) * (1 - exp(-dt * 1.5));
    _levAtaque += (levAtaque - _levAtaque) * (1 - exp(-dt * 5));
    _levDefensa += (levDefensa - _levDefensa) * (1 - exp(-dt * 5));
    _destello = destello;
    _humo += ((fuego ? 1.0 : 0.0) - _humo) * (1 - exp(-dt * 2));
    // La ola: arranca cuando la hinchada está al rojo vivo (como mucho una cada 25 s) y da la vuelta.
    if (_ola >= 0) {
      _ola += dt / 4.5;
      if (_ola > 1) _ola = -1;
    } else {
      _proximaOla -= dt;
      if (_proximaOla <= 0 && _excitacion > 0.8) {
        _ola = 0;
        _proximaOla = 25;
      }
    }
  }

  AmbienteCancha get ambiente => AmbienteCancha(
    publico: PublicoEstado(
      excitacion: _excitacion,
      ola: _ola,
      abucheo: _abucheo,
      tension: _tension,
      playoffs: widget.playoffs,
      local: Color(widget.franquiciaLocal.colorPrimario),
      visitante: Color(widget.franquiciaVisitante.colorPrimario),
    ),
    luzDramatica: max(widget.playoffs ? 0.6 : 0.0, _tension),
    destello: _destello,
    levantadoAtaque: _levAtaque,
    levantadoDefensa: _levDefensa,
    humo: _humo,
  );

  CanchaPartidoPainter _cuadro() {
    final coreo = widget.coreo;
    final esquema = ambiente;
    if (coreo == null) {
      return CanchaPartidoPainter(
        franquicia: widget.franquicia,
        fichas: const [],
        balon: const Offset(25, 47),
        camaraY: camara.y,
        camaraX: camara.x,
        zoom: camara.zoom,
        colorLed: widget.colorLed,
        estilo: widget.estilo,
        escudo: widget.escudo,
        cartel: widget.cartel(null, 0),
        tiempo: tiempo,
        margenArriba: widget.margenArriba,
        margenAbajo: widget.margenAbajo,
        ambiente: esquema,
      );
    }
    final t = widget.progreso.value;
    return cuadroDeCancha(
      coreo: coreo,
      t: t,
      atacaLocal: widget.atacaLocal,
      usuarioLocal: widget.usuarioLocal,
      franquicia: widget.franquicia,
      equipaciones: widget.equipaciones,
      jugadores: widget.jugadores,
      colorLed: widget.colorLed,
      estilo: widget.estilo,
      plano: (x: camara.x, y: camara.y, zoom: camara.zoom),
      energias: widget.energias,
      racha: widget.racha,
      escudo: widget.escudo,
      temblor: camara.temblor,
      cartel: widget.cartel(coreo, t),
      tiempo: tiempo,
      margenArriba: widget.margenArriba,
      margenAbajo: widget.margenAbajo,
      ambiente: esquema,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EscenaPainter(this, Listenable.merge([widget.progreso, _tick])),
      ),
    );
  }
}

class _EscenaPainter extends CustomPainter {
  _EscenaPainter(this.estado, Listenable repaint) : super(repaint: repaint);

  final EscenaCanchaState estado;

  @override
  void paint(Canvas canvas, Size size) => estado._cuadro().paint(canvas, size);

  @override
  bool shouldRepaint(_EscenaPainter old) => old.estado != estado;
}
