import 'dart:math';

import 'package:flutter/animation.dart';

import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import 'cancha_partido.dart';
import 'jugadores_animados.dart';

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
    // Nadie camina más allá del borde de la cancha (ni para buscar una pelota que salió).
    destino = Offset(destino.dx.clamp(-2.5, Cancha94.ancho + 2.5), destino.dy.clamp(-2.5, Cancha94.largo + 2.5));
    final llega = max(hasta, inicio + max(0.05, (destino - origen).distance / 18));
    _k.add((inicio, origen));
    _k.add((llega, destino));
    alCambiar?.call();
    return llega;
  }
}

/// Un tramo del balón: en la mano de alguien, en el aire, o quieto (pelota muerta).
/// Cómo viaja la pelota en un pase: al pecho, picado (pica en el medio), globo (alto y lento) o por
/// detrás de la espalda (curva hacia un costado).
enum EstiloPase { pecho, picado, globo, detras }

class _Tramo {
  const _Tramo.lleva(this.s0, this.s1, this.poseedor)
    : desde = Offset.zero,
      hasta = Offset.zero,
      arco = 0,
      de = null,
      a = null,
      estilo = EstiloPase.pecho,
      curva = 0;
  const _Tramo.vuelo(
    this.s0,
    this.s1,
    this.desde,
    this.hasta,
    this.arco, {
    this.de,
    this.a,
    this.estilo = EstiloPase.pecho,
    this.curva = 0,
  }) : poseedor = null;
  const _Tramo.quieta(this.s0, this.s1, Offset p)
    : desde = p,
      hasta = p,
      arco = 0,
      poseedor = null,
      de = null,
      a = null,
      estilo = EstiloPase.pecho,
      curva = 0;

  final double s0, s1;
  final EstiloPase estilo;

  /// Desvío lateral máximo (pies) del pase por detrás.
  final double curva;
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
  }) : _azar = Random(_semilla('${evento.jugadorId}|${evento.reloj}|${evento.marcadorLocal}|${evento.marcadorVisitante}')) {
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

  /// Semilla estable (FNV-1a): Object.hash cambia en cada ejecución, y la misma jugada tiene que
  /// dibujarse siempre igual (repeticiones, pruebas).
  static int _semilla(String clave) {
    var h = 0x811c9dc5;
    for (final c in clave.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }
  final _rutas = <String, _Ruta>{};
  final _marcas = <List<Offset>>[]; // recorrido de cada defensor, muestreado cada _paso
  final _velocidades = <Offset>[];
  final _relevos = <String, (double, _Ruta)>{}; // defensores que dejan la marca (robo, rebote, tapón)
  final _tramos = <_Tramo>[];
  double _inicioTiro = -1, _finTiro = -1, _canasta = -1, _golpeAro = -1, _tapon = -1;

  /// Desde dónde se tiró (para el mapa de tiros); null si no hubo tiro de campo.
  Offset? puntoTiro;

  /// Momento (en segundos a x1) en que suena el silbato (falta o infracción); null si no suena.
  double? _silbato;

  /// Desde qué segundo la defensa se acomoda en los carriles de los libres (-1: no hay libres).
  double _desdeCarriles = -1;

  /// Saltos de la jugada: (jugador, desde, hasta) en segundos (tapón, volcada, salto entre dos…).
  final _saltos = <(String, double, double)>[];

  /// Saltitos (el que se tira a robar, el que cierra sobre el tirador): la mitad de alto.
  final _saltosChicos = <(String, double, double)>[];

  /// Poses de acción: (jugador, desde, hasta, pose) en segundos. La última que cubre el instante manda.
  final _poses = <(String, double, double, Pose)>[];

  /// Giro completo del cuerpo en el aire (volcada de 360°): (jugador, desde, hasta).
  final _giros = <(String, double, double)>[];

  /// Órdenes a un defensor: (índice, desde, hasta, punto) en segundos. Mientras valen, en vez de
  /// seguir a su marca va a ese punto (cierre sobre el tirador, ayuda, bloqueo, protección del aro).
  final _ordenes = <(int, double, double, Offset)>[];

  /// Pantallas: (desde, hasta, el que la pone, el que la usa) en segundos.
  final _pantallas = <(double, double, String, String)>[];

  /// Cuánto está saltando [id] en el instante t (0 = en el piso, 1 = en lo más alto).
  double salto(String id, double t) {
    final s = t * duracion;
    var altura = 0.0;
    for (final (quien, s0, s1) in _saltos) {
      if (quien != id || s < s0 || s > s1) continue;
      altura = max(altura, sin(pi * (s - s0) / (s1 - s0)));
    }
    for (final (quien, s0, s1) in _saltosChicos) {
      if (quien != id || s < s0 || s > s1) continue;
      altura = max(altura, 0.5 * sin(pi * (s - s0) / (s1 - s0)));
    }
    return altura;
  }

  /// Momento (0–1) del silbato, o null.
  double? get momentoSilbato => _silbato == null ? null : _silbato! / duracion;

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

  /// Centro del corrillo de cada equipo en un tiempo muerto (junto a su banco, sobre la línea lateral).
  static Offset _centroCorrillo(bool atacante) => Offset(1.6, atacante ? 47 : 61);

  /// Lugar de cada jugador en el corrillo: en ronda alrededor del técnico.
  Offset _corrillo(int i, bool atacante) {
    final ang = -pi / 2 + (i + (atacante ? 0 : 0.5)) * 2 * pi / 5;
    return _centroCorrillo(atacante) + Offset(cos(ang), sin(ang)) * 2.5;
  }
  Offset _unidad(Offset o) => o.distance == 0 ? Offset.zero : o / o.distance;
  double _vuelo(Offset a, Offset b) => 0.3 + (a - b).distance / 55;

  // ---------------------------------------------------------------- posiciones

  /// Posición de cualquier jugador de la jugada en el instante t (0–1).
  Offset posicion(String id, double t) => _en(id, t * duracion);

  Offset _en(String id, double s) {
    final p = _enSinTope(id, s);
    // Tope final: nadie sale de la cancha más allá del borde, venga de donde venga.
    return Offset(p.dx.clamp(-3, Cancha94.ancho + 3), p.dy.clamp(-3, Cancha94.largo + 3));
  }

  Offset _enSinTope(String id, double s) {
    final ruta = _rutas[id];
    if (ruta != null) return ruta.en(s) + _vaiven(id.hashCode, s, 0.35);
    final i = defensores.indexWhere((j) => j.id == id);
    if (i < 0) return Offset.zero;
    final relevo = _relevos[id];
    if (relevo != null && s >= relevo.$1) return relevo.$2.en(s);
    return _baseDefensa(i, s);
  }

  Offset _destinoDefensa(int i, double s) {
    if (_pausa) return _corrillo(i, false);
    if (_desdeCarriles >= 0 && s >= _desdeCarriles - 0.6) return _p(_carrilDefensa[i % _carrilDefensa.length]);
    for (final (quien, s0, s1, punto) in _ordenes) {
      if (quien == i && s >= s0 && s <= s1) return punto;
    }
    final marca = _rutas[atacantes[min(i, atacantes.length - 1)].id]!.en(s);
    // Bloqueo: el que marca al que usa la pantalla se queda enganchado detrás del que la pone.
    for (final (s0, s1, pone, usa) in _pantallas) {
      if (s < s0 + 0.25 || s > s1 + 0.5) continue;
      if (atacantes[min(i, atacantes.length - 1)].id != usa) continue;
      final p = _rutas[pone]!.en(s);
      return p + _unidad(marca - aro) * 1.1;
    }
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
      final siguiente = p + _velocidades[i] * _paso;
      // Nadie se va más allá del borde de la cancha.
      muestras.add(
        Offset(siguiente.dx.clamp(-2.5, Cancha94.ancho + 2.5), siguiente.dy.clamp(-2.5, Cancha94.largo + 2.5)),
      );
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
      case TipoEvento.tiro when e.desdeLejos:
        _lanzamientoLargo(balonDesde, poseedorDesde);
      case TipoEvento.tiro:
        var (s, conductor) = _ponerEnJuego(balonDesde, poseedorDesde, rapido: e.contraataque || segundaOportunidad);
        if (e.contraataque) {
          _contraataque(s, conductor);
        } else if (segundaOportunidad && conductor == e.jugadorId) {
          if (e.volcada) {
            // Tap-in de volcada: sube hasta el aro antes de clavarla (no la tira desde lejos).
            final destino = _p(Offset(25 + (_azar.nextBool() ? 2.2 : -2.2), 3.2));
            final llega = _ruta(conductor, s).mover(s, s + 0.45, destino);
            _tramos.add(_Tramo.lleva(s, llega, conductor));
            _tirar(llega, destino, conductor);
          } else {
            final punto = _ruta(conductor, s).en(s);
            _tramos.add(_Tramo.lleva(s, s + 0.45, conductor));
            _tirar(s + 0.45, punto, conductor);
          }
        } else {
          (s, conductor) = _subir(s, conductor);
          _armarTiro(s, conductor);
        }
      case TipoEvento.libres:
        _silbato = 0;
        _libres(balonDesde, poseedorDesde);
      case TipoEvento.perdida:
        _perdida(balonDesde, poseedorDesde);
      case TipoEvento.falta:
        _falta(balonDesde, poseedorDesde);
      case TipoEvento.salto:
        _saltoEntreDos(balonDesde, poseedorDesde);
      case TipoEvento.cambio:
        final destino = desde[e.saleId] ?? _p(_formacion[atacantes.indexWhere((j) => j.id == e.entraId)]);
        _rutas[e.entraId]?.mover(0.1, 1.5, destino);
        _tramos.add(_Tramo.quieta(0, 1.7, balonDesde));
      case TipoEvento.tiempoMuerto || TipoEvento.finCuarto || TipoEvento.finPartido:
        for (final (i, j) in atacantes.indexed) {
          _rutas[j.id]!.mover(0, 1.6, _corrillo(i, true));
        }
        _tramos.add(_Tramo.vuelo(0, 0.8, balonDesde, const Offset(25, 47), 0.1));
        _tramos.add(_Tramo.quieta(0.8, e.tipo == TipoEvento.tiempoMuerto ? 3.1 : 2.8, const Offset(25, 47)));
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
  double _pasar(double s, String de, String a, Offset destino, {double arco = 0.15, EstiloPase? estilo}) {
    final origen = _en(de, s);
    final distancia = (origen - destino).distance;
    // Variedad: picado en distancias cortas, globo (o por detrás) cuando hay tiempo. El alley-oop
    // (arco alto) siempre es un globo.
    estilo ??= arco > 0.5
        ? EstiloPase.globo
        : distancia < 11
        ? switch (_azar.nextInt(10)) {
            < 4 => EstiloPase.picado,
            < 5 => EstiloPase.detras,
            _ => EstiloPase.pecho,
          }
        : (_azar.nextInt(10) < 3 ? EstiloPase.globo : EstiloPase.pecho);
    final alto = arco > 0.5;
    final vuelo = _vuelo(origen, destino) * (alto ? 1.5 : (estilo == EstiloPase.globo ? 1.2 : 1));
    final llega = _ruta(a, s).mover(s, s + vuelo, destino);
    final altura = switch (estilo) {
      EstiloPase.picado => 0.16,
      EstiloPase.globo => alto ? arco : 0.5,
      _ => arco,
    };
    final curva = estilo == EstiloPase.detras ? (_azar.nextBool() ? 1.0 : -1.0) * 1.1 : 0.0;
    _tramos.add(_Tramo.vuelo(s, llega, origen, destino, altura, de: de, a: a, estilo: estilo, curva: curva));
    _poses.add((de, s - 0.14, s + 0.3, Pose.pasa));
    return llega;
  }

  /// La jugada termina en volcada (o alley-oop): el que vuela llega hasta el aro.
  bool get volcada => evento.volcada;

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
    // La volcada se termina pegado al aro, entrando por uno de los costados.
    final punto = e.volcada ? _p(Offset(25 + (_azar.nextBool() ? 2.2 : -2.2), 3.2)) : _lugarDeTiro(i, e.triple);
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
    // Bloqueo directo en un ataque armado (no en la volcada ni el alley-oop, que ya son de por sí).
    final pantalleros = [
      for (final j in atacantes)
        if (j.id != quien && j.id != tirador) j.id,
    ];
    if (!e.volcada && !e.alleyOop && pantalleros.isNotEmpty && s < 4.5 && _azar.nextInt(100) < 35) {
      t = _pantalla(t, quien, pantalleros[_azar.nextInt(pantalleros.length)]);
    }
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
      t = _pasar(espera, quien, receptor, destino, arco: e.alleyOop && receptor == tirador ? 0.9 : 0.15);
      quien = receptor;
    }
    if (quien == tirador) {
      // Alley-oop: la toma en el aire y la clava sin pisar el piso.
      final listo = e.alleyOop ? t + 0.05 : _rutas[tirador]!.mover(t, t + (cadena.length > 1 ? 0.3 : 0.5), punto);
      _tramos.add(_Tramo.lleva(t, listo, tirador));
      _cierre(i, punto, listo);
      _tirar(listo, punto, tirador);
    }
  }

  /// Bloqueo directo: [pone] se clava junto al defensor de [usa], que lo bordea y ataca; el que
  /// defendía al que pone la pantalla ayuda, y el bloqueador se abre al aro. Devuelve cuándo termina.
  double _pantalla(double s, String usa, String pone) {
    final inicio = max(s, _rutas[pone]!.ultimo);
    final u = _rutas[usa]!.en(inicio);
    final haciaAro = _unidad(aro - u);
    final lado = u.dx < Cancha94.ancho / 2 ? 1.0 : -1.0;
    final perp = Offset(-haciaAro.dy, haciaAro.dx) * lado;
    final punto = u + haciaAro * 2.9 + perp * 1.5;
    final destinoUsa = u + haciaAro * 5.5 + perp * 2.4;
    final rueda = aro + _unidad(u - aro) * 7.5 - perp * 2.2;
    final iPone = atacantes.indexWhere((j) => j.id == pone);
    final llega = inicio + 0.8 + (_rutas[pone]!.en(inicio) - punto).distance / 22;
    _pantallas.add((llega - 0.2, llega + 0.9, pone, usa));
    if (iPone >= 0 && iPone < defensores.length) {
      _ordenes.add((iPone, llega + 0.2, llega + 1.4, destinoUsa + _unidad(aro - destinoUsa) * 3.4));
    }
    _olvidarMarcas();
    _rutas[pone]!.mover(inicio, llega, punto);
    _poses.add((pone, llega - 0.25, llega + 0.6, Pose.pantalla));
    final sale = llega + 0.05;
    _rutas[usa]!.mover(sale, sale + 0.9, destinoUsa);
    _rutas[pone]!.mover(llega + 0.35, llega + 1.4, rueda);
    final fin = sale + 0.9;
    _tramos.add(_Tramo.lleva(s, fin, usa));
    return fin;
  }

  /// El defensor del tirador cierra sobre él con la mano arriba (a veces con un saltito tardío).
  void _cierre(int marca, Offset punto, double tiro) {
    final e = evento;
    if (e.taponado || e.interferencia || marca >= defensores.length) return;
    final id = defensores[marca].id;
    if (e.defensorId == id) return;
    final cierra = punto + _unidad(aro - punto) * (1.9 + _azar.nextDouble() * 0.8);
    _ordenes.add((marca, tiro - 1.1, tiro + 0.5, cierra));
    _olvidarMarcas();
    _poses.add((id, tiro - 0.4, tiro + 0.5, Pose.contesta));
    if (_azar.nextInt(10) < 4) _saltosChicos.add((id, tiro - 0.1, tiro + 0.4));
  }

  /// Lugar del tiro: la zona habitual del jugador, con variedad (el triple sobre el arco, el doble
  /// cerca de su lugar pero dentro de la línea de tres).
  Offset _lugarDeTiro(int i, bool triple) {
    final base = (triple ? _puntoTriple : _puntoDoble)[i];
    const aroFondo = Offset(25, 5.25);
    if (triple) {
      final ang = atan2(base.dy - aroFondo.dy, base.dx - aroFondo.dx) + (_azar.nextDouble() - 0.5) * 0.6;
      final radio = 23.9 + _azar.nextDouble() * 2.2;
      var punto = aroFondo + Offset(cos(ang), sin(ang)) * radio;
      // En las esquinas la línea es recta, a 22 pies.
      if (punto.dy < 14) punto = Offset(punto.dx < 25 ? 2.2 + _azar.nextDouble() : 47.8 - _azar.nextDouble(), punto.dy);
      return _p(Offset(punto.dx.clamp(1.5, 48.5), max(1.5, punto.dy)));
    }
    var punto = base + Offset((_azar.nextDouble() - 0.5) * 7, (_azar.nextDouble() - 0.5) * 6);
    final desdeAro = punto - aroFondo;
    if (desdeAro.distance > 21) punto = aroFondo + desdeAro / desdeAro.distance * 21;
    return _p(Offset(punto.dx.clamp(4, 46), max(2, punto.dy)));
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
    // Hasta tres en carrera: un compañero abre el carril del otro lado y el conductor (si pasó) el suyo.
    final lado = bandeja.dx < Cancha94.ancho / 2 ? 1.0 : -1.0;
    final carril = <String, Offset>{};
    var nCarril = 0;
    for (final j in atacantes) {
      if (j.id == tirador || j.id == conductor) continue;
      if (nCarril++ == 0) carril[j.id] = _p(Offset(25 + lado * 13, 15));
    }
    if (conductor != tirador) carril[conductor] = _p(Offset(25 - lado * 12, 18));
    for (final (i, j) in atacantes.indexed) {
      if (j.id == tirador) continue;
      if (carril[j.id] case final c?) {
        final desde = j.id == conductor ? s + 0.35 : s + 0.1 * i;
        _rutas[j.id]!.mover(desde, llega, c);
        _rutas[j.id]!.mover(llega, llega + 1.2, _p(_formacion[i]));
      } else {
        _rutas[j.id]!.mover(s + 0.1 * i, llega + 1.2, _p(_formacion[i]));
      }
    }
    // Un defensor vuelve corriendo a proteger el aro.
    final marca = atacantes.indexWhere((j) => j.id == tirador);
    if (marca >= 0 && marca < defensores.length && !(evento.taponado && evento.defensorId == defensores[marca].id)) {
      _ordenes.add((marca, s + 0.1, llega + 0.5, bandeja + _unidad(aro - bandeja) * 2.4));
      _olvidarMarcas();
    }
    _tirar(llega, bandeja, tirador);
  }

  /// Tiro en arco (o tapón) y resultado: adentro, o rebote.
  void _tirar(double s, Offset punto, String tirador) {
    final e = evento;
    final distancia = (punto - aro).distance;
    _inicioTiro = s;
    puntoTiro = punto;
    _poses.add((
      tirador,
      s - (e.volcada ? 0.3 : 0.25),
      s + (e.volcada ? 0.55 : 0.4),
      e.volcada ? Pose.clava : (distancia < 6 && distancia <= 21 ? Pose.bandeja : Pose.tira),
    ));
    if (e.volcada && _azar.nextInt(100) < 25) _giros.add((tirador, s - 0.2, s + 0.4));
    if (e.taponado && e.defensorId != null) {
      _poses.add((e.defensorId!, s - 0.15, s + 0.55, Pose.contesta));
      // Tapón: el defensor salta al tiro y la manda lejos, hacia un costado.
      final tapa = s + 0.24;
      final cerca = punto + _unidad(aro - punto) * 1.4;
      _relevar(e.defensorId!, s - 0.5).mover(s - 0.5, tapa - 0.04, punto + _unidad(aro - punto) * 2.4);
      _saltos
        ..add((e.defensorId!, tapa - 0.32, tapa + 0.3))
        ..add((tirador, s - 0.08, s + 0.34));
      _tramos.add(_Tramo.vuelo(s, tapa, punto, cerca, 0.6, de: tirador));
      final haciaAro = aro - punto;
      final costado = _unidad(Offset(-haciaAro.dy, haciaAro.dx)) * (_azar.nextBool() ? 1 : -1);
      final lejos = cerca + costado * (6 + _azar.nextDouble() * 5) - _unidad(haciaAro) * (3 + _azar.nextDouble() * 4);
      final desvio = Offset(lejos.dx.clamp(1.5, Cancha94.ancho - 1.5), lejos.dy.clamp(1.5, Cancha94.largo - 1.5));
      _finTiro = tapa;
      _tapon = tapa;
      final cae = tapa + 0.5;
      _tramos.add(_Tramo.vuelo(tapa, cae, cerca, desvio, 0.45));
      _rebote(cae, desvio, lugar: desvio);
      return;
    }
    if (e.volcada) {
      // Volcada: la pelota baja de golpe al aro.
      _finTiro = s + 0.22;
      _tramos.add(_Tramo.vuelo(s, _finTiro, punto, aro, 0.35, de: tirador));
      _saltos.add((tirador, s - 0.2, _finTiro + 0.18));
    } else if (distancia > 40) {
      // Desde la otra mitad: una parábola larguísima.
      _finTiro = s + 1.7;
      _tramos.add(_Tramo.vuelo(s, _finTiro, punto, aro, 1.6, de: tirador));
      _saltos.add((tirador, s - 0.15, s + 0.3));
    } else {
      _finTiro = s + (distancia > 20 ? 1.0 : (distancia < 6 ? 0.55 : 0.8));
      _tramos.add(_Tramo.vuelo(s, _finTiro, punto, aro, 1, de: tirador));
      _saltos.add((tirador, s - 0.15, s + 0.25));
    }
    if (e.interferencia && e.defensorId != null) {
      // Interferencia: el defensor salta y la toca cuando ya bajaba; silbato y vale.
      _relevar(e.defensorId!, s).mover(s, _finTiro - 0.08, aro + _unidad(punto - aro) * 1.3);
      _saltos.add((e.defensorId!, _finTiro - 0.36, _finTiro + 0.2));
      _silbato = _finTiro;
    }
    if (e.convertido || e.reboteId == null) {
      _canasta = _finTiro;
      _tramos.add(_Tramo.vuelo(_finTiro, _finTiro + 0.35, aro, aro + Offset(0, haciaArriba ? -1.5 : 1.5), 0));
      // Las jugadas grandes dejan un rato para el festejo.
      final festejo = e.volcada || e.alleyOop ? 1.0 : (e.triple ? 0.8 : 0.7);
      _tramos.add(_Tramo.quieta(_finTiro + 0.35, _finTiro + festejo, aro + Offset(0, haciaArriba ? -1.5 : 1.5)));
    } else {
      _golpeAro = _finTiro;
      _rebote(_finTiro, aro);
    }
  }

  void _rebote(double s, Offset desdeBalon, {Offset? lugar}) {
    final e = evento;
    final quien = e.reboteId;
    lugar ??= aro + Offset((_azar.nextDouble() * 2 - 1) * 7, (haciaArriba ? 1 : -1) * (4 + _azar.nextDouble() * 6));
    if (quien == null) {
      _tramos.add(_Tramo.vuelo(s, s + 0.5, desdeBalon, lugar, 0.2));
      return;
    }
    final vuelo = s + max(0.6, _vuelo(desdeBalon, lugar));
    final atrapa = max(vuelo, _ruta(quien, _inicioTiro + 0.1).mover(_inicioTiro + 0.15, vuelo, lugar));
    _tramos.add(_Tramo.vuelo(s, atrapa, desdeBalon, lugar, 0.3, a: quien));
    _tramos.add(_Tramo.lleva(atrapa, atrapa + 0.4, quien));
    // Rebote disputado: uno de cada equipo pelea la pelota y todos saltan juntos.
    final pelean = <String>[quien];
    for (final equipo in [atacantes, defensores]) {
      final candidatos = [
        for (final j in equipo)
          if (j.id != quien && j.id != e.jugadorId && j.id != e.defensorId) j,
      ];
      if (candidatos.isEmpty) continue;
      final j = candidatos[_azar.nextInt(candidatos.length)];
      final destino = lugar + Offset(_azar.nextDouble() * 3.4 - 1.7, _azar.nextDouble() * 3.4 - 1.7);
      if (equipo == atacantes) {
        _rutas[j.id]!.mover(_inicioTiro + 0.2, atrapa - 0.3, destino);
      } else {
        _ruta(j.id, _inicioTiro + 0.1).mover(_inicioTiro + 0.2, atrapa - 0.3, destino);
      }
      pelean.add(j.id);
    }
    for (final id in pelean) {
      _saltos.add((id, atrapa - 0.42, atrapa + 0.18));
      _poses.add((id, atrapa - 0.45, atrapa + 0.25, Pose.rebotea));
    }
  }

  /// Tiros libres (los que diga el evento; 2 si no lo dice) desde el segundo [desde].
  void _libres(Offset balon, String? poseedor, {double desde = 0}) {
    final e = evento;
    final cantidad = e.libres > 0 ? e.libres : 2;
    _desdeCarriles = desde;
    _olvidarMarcas();
    final tirador = e.jugadorId!;
    final linea = _p(_lineaLibres);
    final ruta = _ruta(tirador, desde);
    final llega = ruta.mover(desde, desde + 0.6 + (ruta.en(desde) - linea).distance / 14, linea);
    var k = 0;
    for (final j in atacantes) {
      if (j.id == tirador) continue;
      _rutas[j.id]!.mover(desde + 0.2, llega, _p(_carrilAtaque[k++ % _carrilAtaque.length]));
    }
    final recibe = desde + (llega - desde) * 0.6;
    if (poseedor == tirador) {
      _tramos.add(_Tramo.lleva(desde, llega + 0.5, tirador));
    } else {
      final enMano = poseedor != null && (_rutas.containsKey(poseedor) || _relevos.containsKey(poseedor));
      final inicio = enMano ? _mano(poseedor, desde) : balon;
      _tramos.add(_Tramo.vuelo(desde, recibe, inicio, linea, 0.12, de: enMano ? poseedor : null, a: tirador));
      _tramos.add(_Tramo.lleva(recibe, llega + 0.5, tirador));
    }
    // Rutina: pica la pelota, respira, flexiona las rodillas y tira (un instante de silencio).
    var s = llega + 0.5;
    for (var i = 0; i < cantidad; i++) {
      final rutina = i == 0 ? 0.6 : 0.45;
      _tramos.add(_Tramo.lleva(s, s + rutina, tirador));
      _poses.add((tirador, s, s + rutina, Pose.libre));
      s += rutina;
      if (i == 0) _inicioTiro = s;
      if (i == cantidad - 1) break;
      _tramos.add(_Tramo.vuelo(s, s + 0.8, linea, aro, 0.8, de: tirador));
      _tramos.add(_Tramo.vuelo(s + 0.8, s + 1.3, aro, linea, 0.12, a: tirador));
      _tramos.add(_Tramo.lleva(s + 1.3, s + 1.8, tirador));
      s += 1.8;
    }
    _tramos.add(_Tramo.vuelo(s, s + 0.8, linea, aro, 0.8, de: tirador));
    _canasta = _finTiro = s + 0.8;
    _tramos.add(_Tramo.vuelo(_finTiro, _finTiro + 0.35, aro, aro + Offset(0, haciaArriba ? -1.5 : 1.5), 0));
  }

  /// Falta sin tiro: el que recibe la falta tiene la pelota, llega el infractor, silbato y saque
  /// lateral (o libres).
  void _falta(Offset balon, String? poseedor) {
    final e = evento;
    final rapida = e.falta == TipoFalta.intencional || e.falta == TipoFalta.tecnica;
    var (s, conductor) = _ponerEnJuego(balon, poseedor, rapido: rapida);
    // Con libres la falta llega en la subida (si no, la jugada se haría eterna); sin libres, en el
    // ataque armado.
    if (e.falta == TipoFalta.personal) (s, conductor) = _subir(s, conductor);
    final recibe = e.jugadorId!;
    if (e.falta != TipoFalta.tecnica && conductor != recibe && _rutas.containsKey(recibe)) {
      _tramos.add(_Tramo.lleva(s, s + 0.35, conductor));
      final destino = _rutas[recibe]!.en(s + 0.35) + Offset(_azar.nextDouble() * 4 - 2, 0);
      s = _pasar(s + 0.35, conductor, recibe, destino);
      conductor = recibe;
    }
    final contacto = s + (e.falta == TipoFalta.intencional ? 0.35 : 0.75);
    final infractor = e.defensorId;
    if (e.falta != TipoFalta.tecnica && infractor != null) {
      final punto = _en(conductor, contacto);
      _relevar(infractor, s).mover(s, contacto, punto + _unidad(aro - punto) * 1.7);
    }
    _tramos.add(_Tramo.lleva(s, contacto, conductor));
    _silbato = contacto;
    if (e.falta == TipoFalta.personal) {
      // Saque lateral: el que la tenía va hasta el costado y espera con la pelota.
      final donde = _en(conductor, contacto);
      final lateral = Offset(donde.dx < Cancha94.ancho / 2 ? -0.6 : Cancha94.ancho + 0.6, donde.dy);
      final llega = _rutas[conductor]!.mover(contacto + 0.35, contacto + 1.3, lateral);
      _tramos.add(_Tramo.lleva(contacto, llega + 0.6, conductor));
      return;
    }
    _tramos.add(_Tramo.lleva(contacto, contacto + 0.45, conductor));
    // El infractor también se va a su carril para los libres.
    if (infractor != null && _relevos.containsKey(infractor)) {
      final i = defensores.indexWhere((j) => j.id == infractor);
      _relevos[infractor]!.$2.mover(
        contacto + 0.5,
        contacto + 2.2,
        _p(_carrilDefensa[max(0, i) % _carrilDefensa.length]),
      );
    }
    _libres(balon, conductor, desde: contacto + 0.45);
  }

  /// Pelota retenida: los dos van al círculo central, salto entre dos y la toca para un compañero.
  void _saltoEntreDos(Offset balon, String? poseedor) {
    final e = evento;
    const centro = Offset(Cancha94.ancho / 2, Cancha94.largo / 2);
    final atacante = e.jugadorId!, defensor = e.defensorId!;
    final lado = haciaArriba ? 1.0 : -1.0;
    _silbato = 0.25;
    final enMano = poseedor != null && _rutas.containsKey(poseedor);
    final llegaA = _ruta(atacante, 0.3).mover(0.3, 1.6, centro + Offset(0, 2.4 * lado));
    final llegaD = _relevar(defensor, 0.3).mover(0.3, 1.6, centro - Offset(0, 2.4 * lado));
    final otros = [
      for (final j in atacantes)
        if (j.id != atacante) j.id,
    ];
    const alrededor = [Offset(-9, -5), Offset(9, -5), Offset(-9, 6), Offset(9, 6)];
    for (final (k, id) in otros.indexed) {
      _rutas[id]!.mover(0.4, 2.2, centro + alrededor[k % alrededor.length] * lado);
    }
    final listo = max(llegaA, llegaD) + 0.35;
    if (enMano) _tramos.add(_Tramo.lleva(0, 0.3, poseedor));
    final desde = enMano ? _mano(poseedor, 0.3) : balon;
    _tramos.add(_Tramo.vuelo(enMano ? 0.3 : 0, 1.0, desde, centro, 0.15, de: enMano ? poseedor : null));
    _tramos.add(_Tramo.quieta(1.0, listo, centro));
    // El árbitro la tira para arriba; los dos saltan y uno la toca.
    final toque = listo + 0.55;
    _tramos.add(_Tramo.vuelo(listo, toque, centro, centro, 1.1));
    _saltos
      ..add((atacante, toque - 0.4, toque + 0.25))
      ..add((defensor, toque - 0.38, toque + 0.25));
    final String receptor;
    final Offset destino;
    if (e.convertido) {
      receptor = otros[_azar.nextInt(otros.length)];
      destino = _rutas[receptor]!.en(toque + 0.5);
    } else {
      final companeros = [
        for (final j in defensores)
          if (j.id != defensor) j.id,
      ];
      receptor = companeros[_azar.nextInt(companeros.length)];
      destino = centro + Offset(_azar.nextDouble() * 12 - 6, -lado * (5 + _azar.nextDouble() * 3));
      _relevar(receptor, toque - 0.6).mover(toque - 0.6, toque + 0.5, destino);
    }
    final atrapa = toque + max(0.5, _vuelo(centro, destino));
    _tramos.add(_Tramo.vuelo(toque, atrapa, centro, destino, 0.3, a: receptor));
    _tramos.add(_Tramo.lleva(atrapa, atrapa + 0.6, receptor));
  }

  /// Lanzamiento desesperado con la chicharra, desde más allá de la mitad de la cancha.
  void _lanzamientoLargo(Offset balon, String? poseedor) {
    final e = evento;
    final tirador = e.jugadorId!;
    var (s, conductor) = _ponerEnJuego(balon, poseedor, rapido: true);
    final punto = _p(Offset(Cancha94.ancho / 2 + _azar.nextDouble() * 14 - 7, 52 + _azar.nextDouble() * 9));
    if (conductor != tirador) {
      _tramos.add(_Tramo.lleva(s, s + 0.25, conductor));
      s = _pasar(s + 0.25, conductor, tirador, punto);
    } else {
      final llega = _rutas[tirador]!.mover(s, s + 0.6, punto);
      _tramos.add(_Tramo.lleva(s, llega, tirador));
      s = llega;
    }
    _tramos.add(_Tramo.lleva(s, s + 0.2, tirador));
    _tirar(s + 0.2, _en(tirador, s + 0.2), tirador);
  }

  /// Pérdida: robo al pase o manotazo, pelota afuera, o infracción con silbato (pasos, dobles, falta en
  /// ataque, 24 segundos, 3 segundos, campo atrás).
  void _perdida(Offset balon, String? poseedor) {
    final e = evento;
    final tipo = e.perdida ?? (e.defensorId != null ? TipoPerdida.robo : TipoPerdida.afuera);
    var (s, conductor) = _ponerEnJuego(balon, poseedor, rapido: false);
    if (tipo != TipoPerdida.campoAtras) (s, conductor) = _subir(s, conductor);
    final ladron = e.defensorId;
    final otroAro = Cancha94.aro(!haciaArriba);
    void muerta(double desde, String quien) {
      _silbato = desde;
      _tramos.add(_Tramo.quieta(desde, desde + 0.9, _mano(quien, desde)));
    }

    switch (tipo) {
      case TipoPerdida.robo when ladron != null && _azar.nextBool():
        // Robo al pase: el defensor lee la línea y la corta.
        final receptor = atacantes[1 + _azar.nextInt(atacantes.length - 1)].id;
        final destino = _rutas[receptor]!.en(s + 0.6);
        final origen = _en(conductor, s + 0.4);
        _tramos.add(_Tramo.lleva(s, s + 0.4, conductor));
        final corte = Offset.lerp(origen, destino, 0.55)!;
        final atrapa = _escapar(ladron, s + 0.1, s + 0.4 + _vuelo(origen, corte), corte, otroAro);
        _tramos.add(_Tramo.vuelo(s + 0.4, atrapa, origen, corte, 0.12, de: conductor, a: ladron));
        // Lo vio venir: se tira a la línea de pase con el brazo estirado.
        _poses.add((ladron, atrapa - 0.4, atrapa + 0.12, Pose.roba));
        _saltosChicos.add((ladron, atrapa - 0.3, atrapa + 0.12));
      case TipoPerdida.robo when ladron != null:
        // Manotazo: le roba el dribbling al conductor.
        final punto = _en(conductor, s + 0.6);
        final atrapa = _escapar(ladron, s, s + 0.6, punto + _unidad(otroAro - punto) * 1.5, otroAro);
        _tramos.add(_Tramo.lleva(s, atrapa - 0.15, conductor));
        _tramos.add(_Tramo.vuelo(atrapa - 0.15, atrapa, punto, punto, 0.05, de: conductor, a: ladron));
        _poses.add((ladron, atrapa - 0.4, atrapa + 0.1, Pose.roba));
        _saltosChicos.add((ladron, atrapa - 0.25, atrapa + 0.1));
      case TipoPerdida.robo || TipoPerdida.afuera:
        // Pase (o dribbling) que se va afuera.
        final origen = _en(conductor, s + 0.4);
        final afuera = Offset(origen.dx < 25 ? -2.0 : Cancha94.ancho + 2, origen.dy + (haciaArriba ? -6 : 6));
        _tramos.add(_Tramo.lleva(s, s + 0.4, conductor));
        _tramos.add(_Tramo.vuelo(s + 0.4, s + 1.1, origen, afuera, 0.25, de: conductor));
        _tramos.add(_Tramo.quieta(s + 1.1, s + 1.6, afuera));
      case TipoPerdida.carga:
        // Penetración: el defensor se planta en el camino y recibe el choque; silbato.
        final origen = _en(conductor, s);
        final destino = _p(Offset(25 + _azar.nextDouble() * 8 - 4, 8.5));
        final ida = _unidad(destino - origen);
        final choque = destino - ida * 3.4;
        final plantado = destino - ida * 1.4;
        final quien = e.participanteId;
        if (quien != null) _relevar(quien, s).mover(s, s + 0.45, plantado);
        final llega = _rutas[conductor]!.mover(s + 0.1, s + 0.95, choque);
        if (quien != null) _relevos[quien]!.$2.mover(llega, llega + 0.3, plantado + ida * 1.6);
        _tramos.add(_Tramo.lleva(s, llega, conductor));
        muerta(llega, conductor);
      case TipoPerdida.pasos || TipoPerdida.dobles:
        // Arranca hacia el aro y el árbitro lo frena.
        final origen = _en(conductor, s);
        final llega = _rutas[conductor]!.mover(s, s + 0.7, origen + _unidad(aro - origen) * 6);
        _tramos.add(_Tramo.lleva(s, llega, conductor));
        muerta(llega, conductor);
      case TipoPerdida.tresSegundos:
        // Un interno se queda plantado en la pintura mientras la pelota está arriba.
        final grande = e.jugadorId != null && _rutas.containsKey(e.jugadorId) ? e.jugadorId! : atacantes.last.id;
        final pintura = _p(Offset(25 + _azar.nextDouble() * 6 - 3, 9));
        if (grande != conductor) {
          _rutas[grande]!.mover(s, s + 0.9, pintura);
          _tramos.add(_Tramo.lleva(s, s + 2.4, conductor));
          muerta(s + 2.4, conductor);
        } else {
          final llega = _rutas[grande]!.mover(s, s + 0.9, pintura);
          _tramos.add(_Tramo.lleva(s, llega + 1.4, conductor));
          muerta(llega + 1.4, conductor);
        }
      case TipoPerdida.campoAtras:
        // Cruza la mitad y vuelve a su campo con la pelota.
        final origen = _en(conductor, s);
        final x = origen.dx.clamp(12.0, 38.0);
        final mitad = Cancha94.largo / 2;
        final adelante = Offset(x, mitad + (haciaArriba ? -3.0 : 3.0));
        final atras = Offset(x + 2, mitad + (haciaArriba ? 2.5 : -2.5));
        final cruza = _rutas[conductor]!.mover(s, s + 0.8, adelante);
        final vuelve = _rutas[conductor]!.mover(cruza + 0.2, cruza + 0.9, atras);
        _tramos.add(_Tramo.lleva(s, vuelve, conductor));
        muerta(vuelve, conductor);
      case TipoPerdida.veinticuatro:
        // La pelota circula sin encontrar el tiro hasta que suena la bocina de posesión.
        var t = s;
        var quien = conductor;
        for (var k = 0; k < 3; k++) {
          final opciones = [
            for (final j in atacantes)
              if (j.id != quien) j.id,
          ];
          final receptor = opciones[_azar.nextInt(opciones.length)];
          final espera = max(t + 0.5 + _azar.nextDouble() * 0.4, _rutas[receptor]!.ultimo - 0.2);
          _tramos.add(_Tramo.lleva(t, espera, quien));
          t = _pasar(espera, quien, receptor, _rutas[receptor]!.en(espera));
          quien = receptor;
        }
        _tramos.add(_Tramo.lleva(t, t + 1.0, quien));
        muerta(t + 1.0, quien);
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
    var pos = Offset.lerp(desde, hasta, u)!;
    var altura = tr.arco * sin(pi * u);
    switch (tr.estilo) {
      case EstiloPase.picado:
        // Pica en el medio del camino: la altura vuelve a cero a mitad de vuelo.
        altura = tr.arco * sin(2 * pi * u).abs();
      case EstiloPase.detras:
        final ida = hasta - desde;
        if (ida.distance > 0.01) pos += _unidad(Offset(-ida.dy, ida.dx)) * (tr.curva * sin(pi * u));
      case _:
    }
    return (pos, altura, null);
  }

  Offset _mano(String id, double s) => _en(id, s) + const Offset(0.9, 0.5);

  /// Quién tiene la pelota al terminar la jugada (null = pelota muerta o adentro).
  String? get poseedorFinal => balon(1).$3;

  bool enTiro(double t) => _inicioTiro >= 0 && t * duracion >= _inicioTiro && t * duracion <= _finTiro;

  /// Momento (0–1) en que entra la pelota, para el "+2"/"+3" y el marcador.
  double get momentoCanasta => _canasta < 0 ? 1 : _canasta / duracion;

  /// Momento (0–1) en que la pelota pega en el aro y sale (tiro errado), o null.
  double? get momentoAro => _golpeAro < 0 ? null : _golpeAro / duracion;

  /// Momento (0–1) del manotazo del tapón, o null.
  double? get momentoTapon => _tapon < 0 ? null : _tapon / duracion;

  /// Cuenta de piques del dribbling hasta t (cambia en cada pique; -1 si nadie la tiene).
  int pique(double t) {
    if (balon(t).$3 == null) return -1;
    return (t * duracion * 3.6).floor();
  }

  /// La toma se acerca cuando la jugada está cerca del aro y se abre en las transiciones.
  double zoom(double t) {
    if (_pausa) return 1;
    final distancia = (balon(t).$1 - aro).distance;
    return 1 + 0.22 * (1 - ((distancia - 18) / 22).clamp(0.0, 1.0));
  }

  /// Hacia dónde mira la cámara: la pelota, tirada hacia el aro atacado (así el aro queda en cuadro).
  double foco(double t) {
    if (_pausa) return Cancha94.largo / 2;
    return balon(t).$1.dy * 0.5 + (aro.dy + (haciaArriba ? 16 : -16)) * 0.5;
  }

  // ---------------------------------------------------------------- cuerpo y ánimo

  static const _pasoRecorrido = 1 / 20;
  final _recorridos = <String, List<double>>{};

  /// Pies recorridos por [id] hasta el segundo [s] (para el ciclo de la carrera).
  double _recorrido(String id, double s) {
    final tabla = _recorridos.putIfAbsent(id, () {
      final r = <double>[0];
      var previa = _en(id, 0);
      for (var k = 1; k * _pasoRecorrido <= duracion + _pasoRecorrido; k++) {
        final p = _en(id, k * _pasoRecorrido);
        r.add(r.last + (p - previa).distance);
        previa = p;
      }
      return r;
    });
    final x = (s / _pasoRecorrido).clamp(0.0, tabla.length - 1.0);
    final k = x.floor();
    return tabla[k] + (tabla[min(k + 1, tabla.length - 1)] - tabla[k]) * (x - k);
  }

  /// Cómo está parado [id] en el instante t: hacia dónde mira (corre de frente; parado, mira la
  /// pelota o el aro), cómo mueve las piernas, qué hace con los brazos y cómo se siente.
  PosturaJugador postura(String id, double t) {
    final s = (t * duracion).clamp(0.0, duracion);
    final pos = _en(id, s);
    const h = 0.12;
    final a0 = max(0.0, s - h), a1 = min(duracion, s + h);
    final velocidad = a1 > a0 ? (_en(id, a1) - _en(id, a0)).distance / (a1 - a0) : 0.0;
    final b0 = max(0.0, s - 0.3), b1 = min(duracion, s + 0.3);
    final mov = b1 > b0 ? (_en(id, b1) - _en(id, b0)) / (b1 - b0) : Offset.zero;
    final (balonPos, _, poseedor) = balon(t);
    final esAtacante = _rutas.containsKey(id);
    final iDef = defensores.indexWhere((j) => j.id == id);
    // Hacia dónde mira quieto: el que tiene la pelota, al aro; el resto, a la pelota; en el
    // corrillo, al técnico.
    final Offset objetivo;
    if (_pausa) {
      objetivo = _centroCorrillo(esAtacante);
    } else if (poseedor == id) {
      objetivo = aro;
    } else if (iDef >= 0 && poseedor != null && _rutas.containsKey(poseedor)) {
      objetivo = _en(poseedor, s);
    } else {
      objetivo = balonPos;
    }
    final mira = (objetivo - pos).distance < 0.5 ? (haciaArriba ? 0.0 : pi) : rumboHacia(pos, objetivo);
    final w = ((mov.distance - 2.0) / 3.0).clamp(0.0, 1.0);
    var rumbo = w == 0 ? mira : mezclarAngulo(mira, rumboHacia(Offset.zero, mov), w);

    Pose? pose;
    var avance = 0.0;
    for (final (quien, s0, s1, p) in _poses.reversed) {
      if (quien == id && s >= s0 && s <= s1) {
        pose = p;
        avance = (s - s0) / (s1 - s0);
        break;
      }
    }
    final alto = salto(id, t);
    if (pose == null) {
      if (_pausa) {
        pose = Pose.parado;
      } else if (alto > 0.08) {
        pose = esAtacante && enTiro(t) ? Pose.tira : (esAtacante ? Pose.rebotea : Pose.contesta);
      } else if (poseedor == id) {
        pose = Pose.dribla;
      } else if (iDef >= 0 &&
          poseedor != null &&
          _rutas.containsKey(poseedor) &&
          (_en(poseedor, s) - pos).distance < 8 &&
          velocidad < 15) {
        pose = Pose.defiende;
      } else {
        pose = velocidad > 3 ? Pose.corre : Pose.parado;
      }
    }
    // Al tirar o clavar, el cuerpo mira al aro.
    if (pose == Pose.tira || pose == Pose.bandeja || pose == Pose.clava) {
      rumbo = mezclarAngulo(rumbo, rumboHacia(pos, aro), 0.85);
    }
    var giro = 0.0;
    for (final (quien, s0, s1) in _giros) {
      if (quien == id && s >= s0 && s <= s1) giro = 2 * pi * _suave((s - s0) / (s1 - s0));
    }
    final (animo, intensidad) = this.animo(id, t);
    return PosturaJugador(
      rumbo: rumbo,
      velocidad: velocidad,
      fase: _recorrido(id, s) / 4.2 * pi,
      pose: pose,
      avance: avance,
      animo: animo,
      intensidad: intensidad,
      giro: giro,
    );
  }

  /// Festejo, bronca o manos a la cabeza tras lo que pasó en la jugada (solo en las jugadas que
  /// valen: canasta grande, tapón, pérdida, falta, tiro errado importante).
  (Animo, double) animo(String id, double t) {
    final s = t * duracion;
    final e = evento;
    double rampa(double desde) => ((s - desde) / 0.3).clamp(0.0, 1.0);
    final iAt = atacantes.indexWhere((j) => j.id == id);
    final iDef = defensores.indexWhere((j) => j.id == id);
    final tirador = e.jugadorId;
    final marca = tirador == null ? -1 : atacantes.indexWhere((j) => j.id == tirador);
    switch (e.tipo) {
      case TipoEvento.tiro:
        if (e.taponado && _tapon >= 0) {
          final k = rampa(_tapon + 0.1);
          if (id == e.defensorId) return (Animo.celebra, k);
          if (id == tirador) return (Animo.manosCabeza, k * 0.9);
          return (Animo.neutro, 0);
        }
        if ((e.convertido || e.puntos > 0) && _canasta >= 0) {
          final grande = e.volcada || e.triple || e.alleyOop || e.chicharra;
          final k = rampa(_canasta + 0.1);
          if (id == tirador) return (Animo.celebra, k * (grande ? 1.0 : 0.45));
          if (!grande) return (Animo.neutro, 0);
          if (id == e.asistenteId) return (Animo.celebra, k * 0.8);
          if (iAt >= 0) return (Animo.celebra, k * 0.55);
          if (iDef >= 0 && iDef == marca) return (Animo.manosCabeza, k * 0.8);
          return (Animo.neutro, 0);
        }
        final fallo = _golpeAro >= 0 ? _golpeAro : _finTiro;
        if (id == tirador && fallo >= 0 && (e.triple || e.desdeLejos || e.chicharra)) {
          return (Animo.manosCabeza, rampa(fallo + 0.15) * 0.8);
        }
        return (Animo.neutro, 0);
      case TipoEvento.perdida:
        if (id == tirador && tirador != null) return (Animo.manosCabeza, rampa(duracion - 0.8) * 0.8);
        return (Animo.neutro, 0);
      case TipoEvento.falta:
        if (id == e.defensorId && _silbato != null) return (Animo.bronca, rampa(_silbato! + 0.1) * 0.8);
        return (Animo.neutro, 0);
      case _:
        return (Animo.neutro, 0);
    }
  }

  /// Los técnicos en las pausas (tiempo muerto, fin de cuarto): uno por equipo, de pie en el centro de
  /// su corrillo. Vacío durante el juego.
  List<({Offset pos, PosturaJugador postura, bool atacante})> tecnicos(double t) {
    if (!_pausa) return const [];
    final s = t * duracion;
    return [
      for (final atacante in [true, false])
        (
          pos: _centroCorrillo(atacante) + Offset(sin(s * 0.9 + (atacante ? 0 : 2)) * 0.4, cos(s * 0.7) * 0.5),
          postura: PosturaJugador(
            rumbo: pi / 2 + sin(s * 0.8 + (atacante ? 0 : 1.5)) * 1.1,
            pose: Pose.tecnico,
          ),
          atacante: atacante,
        ),
    ];
  }

  /// Plano de la cámara de transmisión en t: hacia dónde mira (x, y en pies) y cuánto se acerca. Sigue
  /// la pelota con anticipación (a la velocidad que lleva), se abre en los contraataques y se acerca en
  /// lo que se quiere ver de cerca: volcadas, tapones, triples de cierre y los tiempos muertos (al
  /// banco, con los técnicos).
  ({double x, double y, double zoom}) plano(double t) {
    final s = t * duracion;
    final e = evento;
    if (e.tipo == TipoEvento.tiempoMuerto) {
      final u = _suave((s / 1.1).clamp(0.0, 1.0));
      return (x: 25 + (7 - 25) * u, y: 54, zoom: 1 + 0.85 * u);
    }
    if (_pausa) return (x: Cancha94.ancho / 2, y: Cancha94.largo / 2, zoom: 1);
    final b = balon(t);
    final antes = balon(max(0.0, t - 0.08 / duracion)).$1, despues = balon(min(1.0, t + 0.08 / duracion)).$1;
    final dt = (min(1.0, t + 0.08 / duracion) - max(0.0, t - 0.08 / duracion)) * duracion;
    var vel = dt > 0 ? (despues - antes) / dt : Offset.zero;
    if (vel.distance > 40) vel = vel / vel.distance * 40;
    final rapido = e.contraataque;
    final anticipo = rapido ? 0.75 : 0.35;
    final pos = b.$1 + vel * anticipo;
    final dir = haciaArriba ? -1.0 : 1.0;
    var y = pos.dy * 0.5 + (aro.dy - dir * 16) * 0.5;
    var x = Cancha94.ancho / 2 + (pos.dx - Cancha94.ancho / 2) * 0.7;
    // La toma abierta del contraataque: no se acerca y mira más adelante.
    var zoom = rapido ? 1.0 : this.zoom(t);
    double campana(double centro, double ancho) => exp(-pow((s - centro) / ancho, 2));
    var cierre = 0.0;
    if (e.volcada && _finTiro >= 0) cierre = max(cierre, campana(_finTiro - 0.1, 0.55));
    if (e.taponado && _tapon >= 0) cierre = max(cierre, campana(_tapon, 0.5));
    if (e.triple && e.convertido && (e.chicharra || e.desdeLejos) && _canasta >= 0) {
      cierre = max(cierre, campana(_canasta, 0.8));
    }
    if (cierre > 0) {
      zoom = zoom + (1.5 - zoom) * cierre;
      y = y + (aro.dy - dir * 7 - y) * cierre * 0.8;
      x = x + (Cancha94.ancho / 2 + (aro.dx - Cancha94.ancho / 2) - x) * cierre * 0.5;
    }
    return (x: x, y: y, zoom: zoom);
  }

  /// Momento (0–1) más vistoso de la jugada (el tapón o la canasta), o null si no lo hay.
  double? get momentoClimax => _tapon >= 0 ? _tapon / duracion : (_canasta >= 0 && evento.puntos > 0 ? _canasta / duracion : null);
}
