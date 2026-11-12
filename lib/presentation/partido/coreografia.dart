import 'dart:math';

import 'package:flutter/animation.dart';

import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import 'cancha_partido.dart';

/// Un tramo del recorrido del balón entre dos instantes de la jugada.
class _Tramo {
  const _Tramo(this.t0, this.t1, this.desde, this.hasta, {this.arco = 0, this.poseedor});

  final double t0, t1;
  final Offset desde, hasta;
  final double arco; // altura máxima (0 = picando en la mano; 1 = tiro)
  final String? poseedor;
}

/// Coreografía de una jugada (GDD §6): cómo se mueven los 10 jugadores y el balón durante el evento
/// del motor, partiendo exactamente de donde terminó la jugada anterior (sin saltos).
/// Todo en pies sobre la cancha de 94; t va de 0 a 1.
class Coreografia {
  Coreografia({
    required this.evento,
    required this.atacantes,
    required this.defensores,
    required this.haciaArriba,
    required this.desde,
    required Offset balonDesde,
    required String? poseedorDesde,
    required bool segundaOportunidad,
    this.saliente,
  }) {
    _armar(balonDesde, poseedorDesde, segundaOportunidad);
  }

  final EventoPartido evento;
  final List<Jugador> atacantes, defensores;

  /// El equipo que ataca va hacia el aro de arriba.
  final bool haciaArriba;

  /// En un cambio: el que sale (camina al banco y desaparece).
  final Jugador? saliente;

  /// Dónde quedó cada jugador al terminar la jugada anterior.
  final Map<String, Offset> desde;
  Offset? _lugarRebote;
  final _tramos = <_Tramo>[];
  final _destinos = <String, Offset>{};
  late final double duracion; // segundos a velocidad x1
  String? _tirador;
  double _inicioTiro = 1, _finCorrida = 0.4;

  Offset get aro => Cancha94.aro(haciaArriba);

  // Puntos de la cancha medidos desde la línea de fondo del aro atacado: (x, distancia).
  static const _formacion = [Offset(25, 27), Offset(42, 20), Offset(8, 20), Offset(33, 11), Offset(18, 7)];
  static const _puntoTriple = [Offset(25, 27), Offset(44, 22), Offset(6, 22), Offset(46.5, 5), Offset(3.5, 5)];
  static const _puntoDoble = [Offset(25, 16), Offset(35, 10), Offset(15, 10), Offset(29, 5), Offset(21, 4.5)];

  Offset _p(Offset o) => Offset(o.dx, haciaArriba ? o.dy : Cancha94.largo - o.dy);
  Offset _banco(int i, bool atacante) => Offset(-1.2, 41 + i * 2.6 + (atacante ? 0 : 14)); // costado de la cancha

  void _armar(Offset balonDesde, String? poseedorDesde, bool segundaOportunidad) {
    final e = evento;
    final idx = {for (final (i, j) in atacantes.indexed) j.id: i};

    // Destinos por defecto: atacantes a su formación.
    for (final (i, j) in atacantes.indexed) {
      _destinos[j.id] = _p(_formacion[i]);
    }

    switch (e.tipo) {
      case TipoEvento.tiro:
        final i = idx[e.jugadorId] ?? 0;
        _tirador = e.jugadorId;
        final punto = e.contraataque ? _p(const Offset(24, 4.5)) : _p((e.triple ? _puntoTriple : _puntoDoble)[i]);
        final rapido = e.contraataque || segundaOportunidad;
        duracion = e.contraataque ? 2.3 : (segundaOportunidad ? 2.4 : 3.4);
        _finCorrida = rapido ? 0.18 : 0.38;
        _inicioTiro = rapido ? 0.55 : 0.7;
        final finTiro = _inicioTiro + 0.18;
        // Subida: el que tiene el balón lo lleva hasta el frente de ataque.
        final conductor = poseedorDesde != null && idx.containsKey(poseedorDesde) ? poseedorDesde : atacantes.first.id;
        final subida = e.contraataque ? punto : _p(const Offset(25, 30));
        if (conductor == e.jugadorId) _destinos[conductor] = punto;
        _tramos.add(_Tramo(0, _finCorrida, balonDesde, conductor == e.jugadorId ? punto : subida, poseedor: conductor));
        // Pases: del conductor al asistente (si hay) y de ahí al tirador.
        var desdeBalon = conductor == e.jugadorId ? punto : subida;
        var t = _finCorrida;
        final pasadores = [if (e.asistenteId != null && e.asistenteId != conductor) e.asistenteId!];
        final pasos = conductor == e.jugadorId ? <String>[] : [...pasadores, e.jugadorId!];
        final hueco = (_inicioTiro - _finCorrida) / max(1, pasos.length);
        for (final receptor in pasos) {
          final hasta = receptor == e.jugadorId ? punto : _destinos[receptor]!;
          _tramos.add(_Tramo(t, t + hueco * 0.85, desdeBalon, hasta, arco: 0.15, poseedor: null));
          _tramos.add(_Tramo(t + hueco * 0.85, t + hueco, hasta, hasta, poseedor: receptor));
          desdeBalon = hasta;
          t += hueco;
        }
        _destinos[e.jugadorId!] = punto;
        // Tiro en arco.
        _tramos.add(_Tramo(_inicioTiro, finTiro, punto, aro, arco: 1));
        // Resultado: adentro (cae bajo el aro) o rebote.
        if (e.convertido || e.reboteId == null) {
          _tramos.add(_Tramo(finTiro, 1, aro, aro + Offset(0, haciaArriba ? -1.5 : 1.5)));
        } else {
          final reboteador = e.reboteId!;
          final lugar = aro + Offset((e.reboteOfensivo ? -1 : 1) * 3.0, haciaArriba ? 5 : -5);
          _lugarRebote = lugar;
          _tramos.add(_Tramo(finTiro, 1, aro, lugar, arco: 0.25, poseedor: reboteador));
        }
      case TipoEvento.libres:
        duracion = 2.6;
        _tirador = e.jugadorId;
        final linea = _p(const Offset(25, 19));
        _destinos[e.jugadorId!] = linea;
        _finCorrida = 0.3;
        _tramos.add(_Tramo(0, 0.3, balonDesde, linea, poseedor: e.jugadorId));
        _inicioTiro = 0.4;
        _tramos.add(_Tramo(0.4, 0.62, linea, aro, arco: 0.8));
        _tramos.add(_Tramo(0.62, 0.7, aro, linea, arco: 0.1));
        _tramos.add(_Tramo(0.72, 0.94, linea, aro, arco: 0.8));
        _tramos.add(_Tramo(0.94, 1, aro, aro + Offset(0, haciaArriba ? -1.5 : 1.5)));
        // Los demás, a los costados de la zona.
        var k = 0;
        for (final j in atacantes) {
          if (j.id == e.jugadorId) continue;
          _destinos[j.id] = _p(Offset(k.isEven ? 15.5 : 34.5, 8 + (k ~/ 2) * 5.5));
          k++;
        }
      case TipoEvento.perdida:
        duracion = 2.2;
        final conductor = poseedorDesde != null && idx.containsKey(poseedorDesde) ? poseedorDesde : atacantes.first.id;
        _finCorrida = 0.45;
        final medio = _p(const Offset(25, 28));
        _tramos.add(_Tramo(0, 0.5, balonDesde, medio, poseedor: conductor));
        if (e.defensorId != null) {
          _tramos.add(_Tramo(0.55, 0.75, medio, medio, poseedor: e.defensorId));
          _tramos.add(_Tramo(0.75, 1, medio, _p(const Offset(25, 40)), poseedor: e.defensorId));
        } else {
          _tramos.add(_Tramo(0.5, 0.8, medio, const Offset(51, 47), arco: 0.3)); // afuera
          _tramos.add(_Tramo(0.8, 1, const Offset(51, 47), const Offset(51, 47)));
        }
      case TipoEvento.cambio:
        duracion = 1.8;
        _finCorrida = 0.9;
        _tramos.add(_Tramo(0, 1, balonDesde, const Offset(-1, 47)));
      case TipoEvento.tiempoMuerto || TipoEvento.finCuarto || TipoEvento.finPartido:
        duracion = e.tipo == TipoEvento.tiempoMuerto ? 2.4 : 2.6;
        _finCorrida = 0.7;
        for (final (i, j) in atacantes.indexed) {
          _destinos[j.id] = _banco(i, true);
        }
        _tramos.add(_Tramo(0, 1, balonDesde, const Offset(25, 47)));
    }
  }

  double _suave(double t, double a, double b) => Curves.easeInOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  /// Posición de un atacante en el instante t.
  Offset atacante(Jugador j, int i, double t) {
    final destino = _destinos[j.id]!;
    final origen = desde[j.id] ?? (evento.tipo == TipoEvento.cambio ? _banco(0, true) : destino);
    final p = Offset.lerp(origen, destino, _suave(t, 0, _finCorrida))!;
    return _aRebote(j, p, t) + _vaiven(i, t, quieto: t > _inicioTiro);
  }

  /// Defensor: entre su marca y el aro, a ~4,5 pies; en las pausas, al banco.
  Offset defensor(Jugador j, int i, Offset marca, double t) {
    final pausa =
        evento.tipo == TipoEvento.tiempoMuerto ||
        evento.tipo == TipoEvento.finCuarto ||
        evento.tipo == TipoEvento.finPartido;
    final destino = pausa ? _banco(i, false) : marca + _unidad(aro - marca) * 4.6;
    final origen = desde[j.id] ?? destino;
    final llegada = _suave(t, 0, pausa ? _finCorrida : _finCorrida * 0.8);
    final p = Offset.lerp(origen, destino, llegada)!;
    // Una vez armada la defensa, sigue a su marca en tiempo real.
    return _aRebote(j, llegada >= 1 ? destino + _vaiven(i + 5, t, quieto: false) * 0.5 : p, t);
  }

  /// Quien toma el rebote sale a buscarlo recién cuando el tiro va en el aire.
  Offset _aRebote(Jugador j, Offset p, double t) {
    final lugar = _lugarRebote;
    if (lugar == null || j.id != evento.reboteId) return p;
    return Offset.lerp(p, lugar, _suave(t, _inicioTiro + 0.08, 1))!;
  }

  /// En un cambio, el que sale camina al banco y se desvanece.
  (Offset, double)? salienteEn(double t) {
    final s = saliente;
    if (s == null) return null;
    final origen = desde[s.id] ?? _banco(0, true);
    return (Offset.lerp(origen, _banco(0, true), _suave(t, 0, 0.8))!, 1 - _suave(t, 0.5, 1));
  }

  Offset _vaiven(int i, double t, {required bool quieto}) {
    final amplitud = quieto ? 0.3 : 0.9;
    return Offset(sin(t * 7 + i * 1.7) * amplitud, cos(t * 6 + i * 2.3) * amplitud);
  }

  Offset _unidad(Offset o) => o.distance == 0 ? Offset.zero : o / o.distance;

  /// Balón: posición, altura del arco (0–1) y quién lo tiene.
  (Offset, double, String?) balon(double t) {
    for (final tr in _tramos) {
      if (t >= tr.t0 && t <= tr.t1) {
        final u = tr.t1 == tr.t0 ? 1.0 : (t - tr.t0) / (tr.t1 - tr.t0);
        final curva = tr.arco >= 0.8 ? u : Curves.easeInOut.transform(u);
        return (Offset.lerp(tr.desde, tr.hasta, curva)!, tr.arco * sin(pi * u), tr.poseedor);
      }
    }
    final ultimo = _tramos.last;
    return (ultimo.hasta, 0, ultimo.poseedor);
  }

  /// Hacia dónde mira la cámara: la pelota, tirada hacia el aro atacado (así el aro queda en cuadro).
  double foco(double t) {
    final pausa =
        evento.tipo == TipoEvento.tiempoMuerto ||
        evento.tipo == TipoEvento.finCuarto ||
        evento.tipo == TipoEvento.finPartido;
    if (pausa) return Cancha94.largo / 2;
    return balon(t).$1.dy * 0.45 + (aro.dy + (haciaArriba ? 16 : -16)) * 0.55;
  }

  bool enTiro(double t) => t >= _inicioTiro && t <= _inicioTiro + 0.2 && _tirador != null;

  /// Momento en que el balón entra (para el "+2"/"+3" y el marcador).
  double get momentoCanasta => evento.tipo == TipoEvento.libres ? 0.94 : _inicioTiro + 0.18;
}
