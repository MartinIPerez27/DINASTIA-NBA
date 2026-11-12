import 'dart:math';

import 'package:flutter/animation.dart';

import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import 'cancha_partido.dart';

/// Aceleración y frenado de una carrera (seno exacto: el pico es π/2 veces la velocidad media).
double _suave(double u) => (1 - cos(pi * u)) / 2;

/// Recorrido de un jugador: puntos de paso (segundo, posición) unidos con aceleración y frenado.
class _Ruta {
  _Ruta(Offset inicio, {this.alCambiar}) : _k = [(0, inicio)];

  /// Aviso de que cambió el recorrido (las marcas de la defensa dependen de él).
  final void Function()? alCambiar;

  final List<(double, Offset)> _k;

  Offset en(double s) {
    if (s <= _k.first.$1) return _k.first.$2;
    for (var i = 1; i < _k.length; i++) {
      final (s1, p1) = _k[i];
      if (s <= s1) {
        final (s0, p0) = _k[i - 1];
        final u = s1 == s0 ? 1.0 : (s - s0) / (s1 - s0);
        return Offset.lerp(p0, p1, _suave(u))!;
      }
    }
    return _k.last.$2;
  }

  double get ultimo => _k.last.$1;

  /// Se queda donde está hasta [desde] y llega a [destino] en [hasta] (o cuando pueda: nunca más
  /// rápido que un sprint). Devuelve el segundo en que llega.
  double mover(double desde, double hasta, Offset destino) {
    final inicio = max(desde, _k.last.$1);
    final origen = en(inicio);
    final llega = max(hasta, inicio + max(0.05, (destino - origen).distance / 18));
    _k.add((inicio, origen));
    _k.add((llega, destino));
    alCambiar?.call();
    return llega;
  }
}

/// Un tramo del balón: en la mano de alguien, en el aire, o quieto (pelota muerta).
class _Tramo {
  const _Tramo.lleva(this.s0, this.s1, this.poseedor)
    : desde = Offset.zero,
      hasta = Offset.zero,
      arco = 0,
      de = null,
      a = null;
  const _Tramo.vuelo(this.s0, this.s1, this.desde, this.hasta, this.arco, {this.de, this.a}) : poseedor = null;
  const _Tramo.quieta(this.s0, this.s1, Offset p)
    : desde = p,
      hasta = p,
      arco = 0,
      poseedor = null,
      de = null,
      a = null;

  final double s0, s1;
  final Offset desde, hasta;
  final double arco; // altura máxima: ~0.15 pase, 1 tiro
  final String? poseedor;

  /// Si sale de la mano de alguien / termina en la mano de alguien, el vuelo empieza / termina
  /// exactamente donde está la pelota en esa mano (sin saltos al soltarla o recibirla).
  final String? de, a;
}

/// Coreografía de una jugada (GDD §6), estilo "simcast": saque, subida de toda la cancha,
/// circulación, tiro y rebote, con tiempos reales (en segundos a x1). Cada jugada arranca exactamente
/// donde terminó la anterior. t va de 0 a 1 sobre [duracion].
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
  }) : _azar = Random(Object.hash(evento.jugadorId, evento.reloj, evento.marcadorLocal, evento.marcadorVisitante)) {
    for (final (i, j) in atacantes.indexed) {
      final entra = evento.tipo == TipoEvento.cambio && j.id == evento.entraId;
      final origen = entra ? _banco(0, true) : desde[j.id] ?? _p(_formacion[i]);
      _rutas[j.id] = _Ruta(origen, alCambiar: _olvidarMarcas);
    }
    _armar(balonDesde, poseedorDesde, segundaOportunidad);
    _tramos.sort((a, b) => a.s0.compareTo(b.s0));
    duracion = max(1.2, _tramos.map((t) => t.s1).reduce(max));
  }

  final EventoPartido evento;
  final List<Jugador> atacantes, defensores;

  /// El equipo que ataca va hacia el aro de arriba.
  final bool haciaArriba;

  /// En un cambio: el que sale (camina al banco y desaparece).
  final Jugador? saliente;

  /// Dónde quedó cada jugador al terminar la jugada anterior.
  final Map<String, Offset> desde;

  /// Segundos de la jugada a velocidad x1.
  late final double duracion;

  final Random _azar;
  final _rutas = <String, _Ruta>{};
  final _marcas = <List<Offset>>[]; // recorrido de cada defensor, muestreado cada _paso
  final _velocidades = <Offset>[];
  final _relevos = <String, (double, _Ruta)>{}; // defensores que dejan la marca (robo, rebote, tapón)
  final _tramos = <_Tramo>[];
  double _inicioTiro = -1, _finTiro = -1, _canasta = -1;

  Offset get aro => Cancha94.aro(haciaArriba);

  bool get _pausa =>
      evento.tipo == TipoEvento.tiempoMuerto ||
      evento.tipo == TipoEvento.finCuarto ||
      evento.tipo == TipoEvento.finPartido;

  // Puntos medidos desde la línea de fondo del aro atacado: (x, distancia).
  static const _formacion = [Offset(25, 28), Offset(43, 19), Offset(7, 19), Offset(33, 9), Offset(17, 6)];
  static const _puntoTriple = [Offset(25, 27), Offset(44, 22), Offset(6, 22), Offset(46.5, 5), Offset(3.5, 5)];
  static const _puntoDoble = [Offset(25, 18), Offset(36, 11), Offset(14, 11), Offset(29, 5), Offset(21, 4.5)];
  static const _lineaLibres = Offset(25, 19);
  static const _carrilAtaque = [Offset(15.5, 11.5), Offset(34.5, 11.5), Offset(34.5, 16), Offset(25, 30)];
  static const _carrilDefensa = [Offset(15.5, 7), Offset(34.5, 7), Offset(15.5, 16), Offset(8, 25), Offset(42, 25)];

  Offset _p(Offset o) => Offset(o.dx, haciaArriba ? o.dy : Cancha94.largo - o.dy);
  Offset _banco(int i, bool atacante) => Offset(-1.2, 41 + i * 2.6 + (atacante ? 0 : 14));
  Offset _unidad(Offset o) => o.distance == 0 ? Offset.zero : o / o.distance;
  double _vuelo(Offset a, Offset b) => 0.3 + (a - b).distance / 55;

  // ---------------------------------------------------------------- posiciones

  /// Posición de cualquier jugador de la jugada en el instante t (0–1).
  Offset posicion(String id, double t) => _en(id, t * duracion);

  Offset _en(String id, double s) {
    final ruta = _rutas[id];
    if (ruta != null) return ruta.en(s) + _vaiven(id.hashCode, s, 0.35);
    final i = defensores.indexWhere((j) => j.id == id);
    if (i < 0) return Offset.zero;
    final relevo = _relevos[id];
    if (relevo != null && s >= relevo.$1) return relevo.$2.en(s);
    return _baseDefensa(i, s);
  }

  Offset _destinoDefensa(int i, double s) {
    if (_pausa) return _banco(i, false);
    if (evento.tipo == TipoEvento.libres) return _p(_carrilDefensa[i % _carrilDefensa.length]);
    final marca = _rutas[atacantes[min(i, atacantes.length - 1)].id]!.en(s);
    return marca + _unidad(aro - marca) * 4.4;
  }

  static const _paso = 1 / 30;

  void _olvidarMarcas() {
    _marcas.clear();
    _velocidades.clear();
  }

  /// El defensor persigue su lugar (entre la marca y el aro) como una persona: con velocidad
  /// máxima y aceleración limitadas, así nunca "se teletransporta" aunque la marca pique.
  Offset _baseDefensa(int i, double s) {
    if (_marcas.isEmpty) {
      for (final (k, j) in defensores.indexed) {
        _marcas.add([desde[j.id] ?? _destinoDefensa(k, 0)]);
        _velocidades.add(Offset.zero);
      }
    }
    final muestras = _marcas[i];
    final hasta = (s / _paso).ceil() + 1;
    while (muestras.length <= hasta) {
      final p = muestras.last;
      final objetivo = _destinoDefensa(i, (muestras.length - 1) * _paso);
      var deseada = (objetivo - p) * 3.0;
      if (deseada.distance > 22) deseada = deseada / deseada.distance * 22;
      var cambio = deseada - _velocidades[i];
      if (cambio.distance > 45 * _paso) cambio = cambio / cambio.distance * 45 * _paso;
      _velocidades[i] += cambio;
      muestras.add(p + _velocidades[i] * _paso);
    }
    final x = (s / _paso).clamp(0.0, muestras.length - 1.0);
    final k = x.floor();
    final p = Offset.lerp(muestras[k], muestras[min(k + 1, muestras.length - 1)], x - k)!;
    return p + _vaiven(i * 31 + 7, s, 0.35);
  }

  Offset _vaiven(int semilla, double s, double amplitud) {
    final fase = (semilla % 97) / 97 * 2 * pi;
    return Offset(sin(s * 1.9 + fase) * amplitud, cos(s * 1.6 + fase * 1.3) * amplitud);
  }

  /// Un defensor deja su marca en [s]: a partir de ahí sigue su propia ruta.
  _Ruta _relevar(String id, double s) {
    final i = defensores.indexWhere((j) => j.id == id);
    final ruta = _Ruta(_baseDefensa(max(0, i), s));
    ruta._k[0] = (s, ruta._k[0].$2);
    _relevos[id] = (s, ruta);
    return ruta;
  }

  _Ruta _ruta(String id, double s) => _rutas[id] ?? _relevos[id]?.$2 ?? _relevar(id, s);

  /// En un cambio, el que sale camina al banco y se desvanece.
  (Offset, double)? salienteEn(double t) {
    final s = saliente;
    if (s == null) return null;
    final origen = desde[s.id] ?? _banco(0, true);
    final u = _suave((t / 0.85).clamp(0.0, 1.0));
    return (Offset.lerp(origen, _banco(0, true), u)!, 1 - ((t - 0.55) / 0.45).clamp(0.0, 1.0));
  }

  // ---------------------------------------------------------------- guion

  void _armar(Offset balonDesde, String? poseedorDesde, bool segundaOportunidad) {
    final e = evento;
    switch (e.tipo) {
      case TipoEvento.tiro:
        var (s, conductor) = _ponerEnJuego(balonDesde, poseedorDesde, rapido: e.contraataque || segundaOportunidad);
        if (e.contraataque) {
          _contraataque(s, conductor);
        } else if (segundaOportunidad && conductor == e.jugadorId) {
          final punto = _ruta(conductor, s).en(s);
          _tramos.add(_Tramo.lleva(s, s + 0.45, conductor));
          _tirar(s + 0.45, punto, conductor);
        } else {
          (s, conductor) = _subir(s, conductor);
          _armarTiro(s, conductor);
        }
      case TipoEvento.libres:
        _libres(balonDesde, poseedorDesde);
      case TipoEvento.perdida:
        _perdida(balonDesde, poseedorDesde);
      case TipoEvento.cambio:
        final destino = desde[e.saleId] ?? _p(_formacion[atacantes.indexWhere((j) => j.id == e.entraId)]);
        _rutas[e.entraId]?.mover(0.1, 1.5, destino);
        _tramos.add(_Tramo.quieta(0, 1.7, balonDesde));
      case TipoEvento.tiempoMuerto || TipoEvento.finCuarto || TipoEvento.finPartido:
        for (final (i, j) in atacantes.indexed) {
          _rutas[j.id]!.mover(0, 1.6, _banco(i, true));
        }
        _tramos.add(_Tramo.vuelo(0, 0.8, balonDesde, const Offset(25, 47), 0.1));
        _tramos.add(_Tramo.quieta(0.8, e.tipo == TipoEvento.tiempoMuerto ? 2.4 : 2.8, const Offset(25, 47)));
    }
  }

  /// Si nadie del ataque tiene la pelota, el más cercano la busca y saca hacia el base.
  /// Devuelve (segundo, quién la tiene).
  (double, String) _ponerEnJuego(Offset balon, String? poseedor, {required bool rapido}) {
    if (poseedor != null && _rutas.containsKey(poseedor)) return (0, poseedor);
    final cercano = atacantes.reduce(
      (a, b) => (_rutas[a.id]!.en(0) - balon).distance < (_rutas[b.id]!.en(0) - balon).distance ? a : b,
    );
    // Va a buscarla: su mano queda justo sobre la pelota.
    final punto = balon - const Offset(0.9, 0.5);
    final llega = _rutas[cercano.id]!.mover(0, 0.3 + (_rutas[cercano.id]!.en(0) - punto).distance / 14, punto);
    _tramos.add(_Tramo.quieta(0, llega, balon));
    if (rapido) {
      _tramos.add(_Tramo.lleva(llega, llega + 0.3, cercano.id));
      return (llega + 0.3, cercano.id);
    }
    final receptor = atacantes.first.id == cercano.id ? atacantes[1].id : atacantes.first.id;
    final hacia = Offset((punto.dx - 25).sign * -6 + punto.dx, punto.dy + (haciaArriba ? -9 : 9));
    final espera = llega + 0.45;
    _rutas[receptor]!.mover(0, espera + 0.4, Offset(hacia.dx.clamp(4, 46), hacia.dy.clamp(3, 91)));
    _tramos.add(_Tramo.lleva(llega, espera, cercano.id));
    return (_pasar(espera, cercano.id, receptor, _rutas[receptor]!.en(espera + 0.4)), receptor);
  }

  /// Pase de [de] a [a] que llega a [destino]; devuelve el segundo en que la recibe.
  double _pasar(double s, String de, String a, Offset destino) {
    final origen = _en(de, s);
    final llega = _ruta(a, s).mover(s, s + _vuelo(origen, destino), destino);
    _tramos.add(_Tramo.vuelo(s, llega, origen, destino, 0.15, de: de, a: a));
    return llega;
  }

  /// Subida de toda la cancha: si conduce un interno, primero la pasa al base.
  (double, String) _subir(double s, String conductor) {
    var t = s;
    var quien = conductor;
    final base = atacantes.first.id;
    if (quien != base && atacantes.indexWhere((j) => j.id == quien) >= 3) {
      final hacia = _rutas[quien]!.en(t) + Offset(0, haciaArriba ? -10 : 10);
      _tramos.add(_Tramo.lleva(t, t + 0.35, quien));
      t = _pasar(t + 0.35, quien, base, Offset(hacia.dx.clamp(6, 44), hacia.dy.clamp(4, 90)));
      quien = base;
    }
    final frente = _p(_formacion.first);
    final llega = _rutas[quien]!.mover(t, t + max(0.8, (_rutas[quien]!.en(t) - frente).distance / 17), frente);
    _tramos.add(_Tramo.lleva(t, llega, quien));
    for (final (i, j) in atacantes.indexed) {
      if (j.id == quien) continue;
      final destino = _p(_formacion[i]);
      final corre = max(llega - t, (_rutas[j.id]!.en(t) - destino).distance / 20);
      _rutas[j.id]!.mover(t + 0.1 * i, t + corre, destino);
    }
    return (llega, quien);
  }

  /// Circulación (1–2 pases de ida y vuelta), pase final del asistente y tiro.
  void _armarTiro(double s, String conductor) {
    final e = evento;
    final tirador = e.jugadorId!;
    final i = max(0, atacantes.indexWhere((j) => j.id == tirador));
    final punto = _p((e.triple ? _puntoTriple : _puntoDoble)[i]);
    final cadena = <String>[];
    final libres = [
      for (final j in atacantes)
        if (j.id != tirador) j.id,
    ];
    for (var k = 0; k < 1 + _azar.nextInt(2); k++) {
      cadena.add(libres[_azar.nextInt(libres.length)]);
    }
    if (e.asistenteId != null) cadena.add(e.asistenteId!);
    cadena.add(tirador);
    var quien = conductor;
    var t = s;
    for (final receptor in cadena) {
      if (receptor == quien) continue;
      // Se pasa cuando el receptor ya llegó a su lugar.
      final espera = max(t + 0.35 + _azar.nextDouble() * 0.3, _rutas[receptor]!.ultimo - 0.2);
      _tramos.add(_Tramo.lleva(t, espera, quien));
      final destino = receptor == tirador
          ? punto
          : _rutas[receptor]!.en(espera) +
                Offset(_azar.nextDouble() * 6 - 3, (_azar.nextDouble() * 4 - 1) * (haciaArriba ? 1 : -1));
      // El receptor se desmarca hacia la pelota antes del pase.
      _rutas[receptor]!.mover(espera - 0.5, espera + 0.05, destino);
      t = _pasar(espera, quien, receptor, destino);
      quien = receptor;
    }
    if (quien == tirador) {
      final listo = _rutas[tirador]!.mover(t, t + (cadena.length > 1 ? 0.3 : 0.5), punto);
      _tramos.add(_Tramo.lleva(t, listo, tirador));
      _tirar(listo, punto, tirador);
    }
  }

  /// Contraataque: el que corre sale disparado al aro; si no conduce él, recibe un pase largo.
  void _contraataque(double s, String conductor) {
    final tirador = evento.jugadorId!;
    final bandeja = _p(const Offset(24, 4.5));
    final llega = _ruta(tirador, s).mover(s, s + max(1.0, (_ruta(tirador, s).en(s) - bandeja).distance / 23), bandeja);
    if (conductor == tirador) {
      _tramos.add(_Tramo.lleva(s, llega, tirador));
    } else {
      final pase = s + 0.35;
      _tramos.add(_Tramo.lleva(s, pase, conductor));
      final destino = _rutas[tirador]?.en(llega - 0.35) ?? bandeja;
      final origen = _en(conductor, pase);
      _tramos.add(_Tramo.vuelo(pase, llega - 0.35, origen, destino, 0.25, de: conductor, a: tirador));
      _tramos.add(_Tramo.lleva(llega - 0.35, llega, tirador));
    }
    for (final (i, j) in atacantes.indexed) {
      if (j.id == tirador || j.id == conductor) continue;
      _rutas[j.id]!.mover(s + 0.1 * i, llega + 1.2, _p(_formacion[i]));
    }
    _tirar(llega, bandeja, tirador);
  }

  /// Tiro en arco (o tapón) y resultado: adentro, o rebote.
  void _tirar(double s, Offset punto, String tirador) {
    final e = evento;
    final distancia = (punto - aro).distance;
    _inicioTiro = s;
    if (e.taponado && e.defensorId != null) {
      _relevar(e.defensorId!, s - 0.45).mover(s - 0.45, s + 0.1, punto + _unidad(aro - punto) * 2.2);
      final desvio = punto + _unidad(aro - punto) * 2.5;
      _finTiro = s + 0.22;
      _tramos.add(_Tramo.vuelo(s, _finTiro, punto, desvio, 0.35, de: tirador));
      _rebote(_finTiro, desvio);
      return;
    }
    _finTiro = s + (distancia > 20 ? 1.0 : (distancia < 6 ? 0.55 : 0.8));
    _tramos.add(_Tramo.vuelo(s, _finTiro, punto, aro, 1, de: tirador));
    if (e.convertido || e.reboteId == null) {
      _canasta = _finTiro;
      _tramos.add(_Tramo.vuelo(_finTiro, _finTiro + 0.35, aro, aro + Offset(0, haciaArriba ? -1.5 : 1.5), 0));
      _tramos.add(_Tramo.quieta(_finTiro + 0.35, _finTiro + 0.7, aro + Offset(0, haciaArriba ? -1.5 : 1.5)));
    } else {
      _rebote(_finTiro, aro);
    }
  }

  void _rebote(double s, Offset desdeBalon) {
    final e = evento;
    final quien = e.reboteId;
    final lugar = aro + Offset((_azar.nextDouble() * 2 - 1) * 7, (haciaArriba ? 1 : -1) * (4 + _azar.nextDouble() * 6));
    if (quien == null) {
      _tramos.add(_Tramo.vuelo(s, s + 0.5, desdeBalon, lugar, 0.2));
      return;
    }
    final vuelo = s + max(0.6, _vuelo(desdeBalon, lugar));
    final atrapa = max(vuelo, _ruta(quien, _inicioTiro + 0.1).mover(_inicioTiro + 0.15, vuelo, lugar));
    _tramos.add(_Tramo.vuelo(s, atrapa, desdeBalon, lugar, 0.3, a: quien));
    _tramos.add(_Tramo.lleva(atrapa, atrapa + 0.4, quien));
  }

  void _libres(Offset balon, String? poseedor) {
    final e = evento;
    final tirador = e.jugadorId!;
    final linea = _p(_lineaLibres);
    final llega = _ruta(tirador, 0).mover(0, 0.6 + (_ruta(tirador, 0).en(0) - linea).distance / 14, linea);
    var k = 0;
    for (final j in atacantes) {
      if (j.id == tirador) continue;
      _rutas[j.id]!.mover(0.2, llega, _p(_carrilAtaque[k++ % _carrilAtaque.length]));
    }
    final inicio = poseedor != null && _rutas.containsKey(poseedor) ? _en(poseedor, 0) : balon;
    _tramos.add(_Tramo.vuelo(0, llega * 0.6, inicio, linea, 0.12, de: inicio == balon ? null : poseedor, a: tirador));
    _tramos.add(_Tramo.lleva(llega * 0.6, llega + 0.5, tirador));
    var s = llega + 0.5;
    _inicioTiro = s;
    _tramos.add(_Tramo.vuelo(s, s + 0.8, linea, aro, 0.8, de: tirador));
    _tramos.add(_Tramo.vuelo(s + 0.8, s + 1.3, aro, linea, 0.12, a: tirador));
    _tramos.add(_Tramo.lleva(s + 1.3, s + 1.8, tirador));
    s += 1.8;
    _tramos.add(_Tramo.vuelo(s, s + 0.8, linea, aro, 0.8, de: tirador));
    _canasta = _finTiro = s + 0.8;
    _tramos.add(_Tramo.vuelo(_finTiro, _finTiro + 0.35, aro, aro + Offset(0, haciaArriba ? -1.5 : 1.5), 0));
  }

  /// Pérdida: robo al pase, manotazo en el dribbling, pase afuera o infracción (pasos / falta en ataque).
  void _perdida(Offset balon, String? poseedor) {
    final e = evento;
    var (s, conductor) = _ponerEnJuego(balon, poseedor, rapido: false);
    (s, conductor) = _subir(s, conductor);
    final ladron = e.defensorId;
    final otroAro = Cancha94.aro(!haciaArriba);
    if (ladron != null && _azar.nextBool()) {
      // Robo al pase: el defensor lee la línea y la corta.
      final receptor = atacantes[1 + _azar.nextInt(atacantes.length - 1)].id;
      final destino = _rutas[receptor]!.en(s + 0.6);
      final origen = _en(conductor, s + 0.4);
      _tramos.add(_Tramo.lleva(s, s + 0.4, conductor));
      final corte = Offset.lerp(origen, destino, 0.55)!;
      final atrapa = _escapar(ladron, s + 0.1, s + 0.4 + _vuelo(origen, corte), corte, otroAro);
      _tramos.add(_Tramo.vuelo(s + 0.4, atrapa, origen, corte, 0.12, de: conductor, a: ladron));
    } else if (ladron != null) {
      // Manotazo: le roba el dribbling al conductor.
      final punto = _en(conductor, s + 0.6);
      final atrapa = _escapar(ladron, s, s + 0.6, punto + _unidad(otroAro - punto) * 1.5, otroAro);
      _tramos.add(_Tramo.lleva(s, atrapa - 0.15, conductor));
      _tramos.add(_Tramo.vuelo(atrapa - 0.15, atrapa, punto, punto, 0.05, de: conductor, a: ladron));
    } else if (_azar.nextBool()) {
      // Pase que se va afuera.
      final origen = _en(conductor, s + 0.4);
      final afuera = Offset(origen.dx < 25 ? -2.0 : Cancha94.ancho + 2, origen.dy + (haciaArriba ? -6 : 6));
      _tramos.add(_Tramo.lleva(s, s + 0.4, conductor));
      _tramos.add(_Tramo.vuelo(s + 0.4, s + 1.1, origen, afuera, 0.25, de: conductor));
      _tramos.add(_Tramo.quieta(s + 1.1, s + 1.6, afuera));
    } else {
      // Infracción: silbato, la pelota queda muerta donde estaba.
      _tramos.add(_Tramo.lleva(s, s + 0.7, conductor));
      _tramos.add(_Tramo.quieta(s + 0.7, s + 1.5, _en(conductor, s + 0.7)));
    }
  }

  /// El que roba agarra la pelota en [punto] (no antes de [plan]) y sale hacia el otro aro.
  /// Devuelve el segundo en que la agarra.
  double _escapar(String ladron, double sale, double plan, Offset punto, Offset otroAro) {
    final lejos = evento.contraataque ? 26.0 : 14.0;
    final ruta = _relevar(ladron, sale);
    final atrapa = ruta.mover(sale, plan, punto);
    final fin = atrapa + (evento.contraataque ? 1.3 : 1.0);
    ruta.mover(atrapa + 0.1, fin, punto + _unidad(otroAro - punto) * lejos);
    _tramos.add(_Tramo.lleva(atrapa, fin, ladron));
    return atrapa;
  }

  // ---------------------------------------------------------------- balón

  /// Balón en el instante t: posición, altura (0–1) y quién lo tiene.
  (Offset, double, String?) balon(double t) {
    final s = t * duracion;
    for (final tr in _tramos) {
      if (s >= tr.s0 && s <= tr.s1) return _balonEn(tr, s);
    }
    final previos = _tramos.where((tr) => tr.s1 <= s);
    return _balonEn(previos.isEmpty ? _tramos.first : previos.last, s.clamp(_tramos.first.s0, _tramos.last.s1));
  }

  (Offset, double, String?) _balonEn(_Tramo tr, double s) {
    if (tr.poseedor case final quien?) {
      // Pique del dribbling: la pelota baja y sube al costado de la mano.
      final pique = (sin(s * 2 * pi * 1.8)).abs() * 0.07;
      return (_mano(quien, min(s, tr.s1)), pique, quien);
    }
    final u = tr.s1 == tr.s0 ? 1.0 : ((s - tr.s0) / (tr.s1 - tr.s0)).clamp(0.0, 1.0);
    // En el aire la pelota va a velocidad constante; la altura dibuja el arco.
    final desde = tr.de == null ? tr.desde : _mano(tr.de!, tr.s0);
    final hasta = tr.a == null ? tr.hasta : _mano(tr.a!, tr.s1);
    return (Offset.lerp(desde, hasta, u)!, tr.arco * sin(pi * u), null);
  }

  Offset _mano(String id, double s) => _en(id, s) + const Offset(0.9, 0.5);

  /// Quién tiene la pelota al terminar la jugada (null = pelota muerta o adentro).
  String? get poseedorFinal => balon(1).$3;

  bool enTiro(double t) => _inicioTiro >= 0 && t * duracion >= _inicioTiro && t * duracion <= _finTiro;

  /// Momento (0–1) en que entra la pelota, para el "+2"/"+3" y el marcador.
  double get momentoCanasta => _canasta < 0 ? 1 : _canasta / duracion;

  /// Hacia dónde mira la cámara: la pelota, tirada hacia el aro atacado (así el aro queda en cuadro).
  double foco(double t) {
    if (_pausa) return Cancha94.largo / 2;
    return balon(t).$1.dy * 0.5 + (aro.dy + (haciaArriba ? 16 : -16)) * 0.5;
  }
}
