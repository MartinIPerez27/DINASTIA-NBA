import 'dart:math';

import 'entities/jugador.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/tactica.dart';
import 'playbook.dart';

/// Línea de box score (por partido o acumulada en la temporada).
class LineaEstadistica {
  LineaEstadistica();

  int pj = 0, pts = 0, reb = 0, ast = 0, rob = 0, tap = 0, per = 0;
  int tcI = 0, tcA = 0, t3I = 0, t3A = 0, tlI = 0, tlA = 0;
  double seg = 0;

  void sumar(LineaEstadistica o) {
    pj += o.pj;
    pts += o.pts;
    reb += o.reb;
    ast += o.ast;
    rob += o.rob;
    tap += o.tap;
    per += o.per;
    tcI += o.tcI;
    tcA += o.tcA;
    t3I += o.t3I;
    t3A += o.t3A;
    tlI += o.tlI;
    tlA += o.tlA;
    seg += o.seg;
  }

  factory LineaEstadistica.fromJson(Map<String, dynamic> j) {
    final v = (j['v'] as List).cast<num>();
    return LineaEstadistica()
      ..pj = v[0].toInt()
      ..pts = v[1].toInt()
      ..reb = v[2].toInt()
      ..ast = v[3].toInt()
      ..rob = v[4].toInt()
      ..tap = v[5].toInt()
      ..per = v[6].toInt()
      ..tcI = v[7].toInt()
      ..tcA = v[8].toInt()
      ..t3I = v[9].toInt()
      ..t3A = v[10].toInt()
      ..tlI = v[11].toInt()
      ..tlA = v[12].toInt()
      ..seg = v[13].toDouble();
  }

  Map<String, dynamic> toJson() => {
    'v': [pj, pts, reb, ast, rob, tap, per, tcI, tcA, t3I, t3A, tlI, tlA, seg.round()],
  };
}

/// Un equipo listo para jugar: identidad visual, 5 titulares + Sexto Hombre y su táctica.
class EquipoPartido {
  EquipoPartido({required this.identidadId, required this.plantel, required this.tactica});

  final String identidadId;
  final Plantel plantel;
  final Tactica tactica;
}

enum TipoEvento { tiro, libres, perdida, cambio, tiempoMuerto, finCuarto, finPartido }

/// Lo que pasó en una posesión (o una pausa), con el marcador después de la jugada.
class EventoPartido {
  const EventoPartido({
    required this.tipo,
    required this.local,
    required this.cuarto,
    required this.reloj,
    required this.marcadorLocal,
    required this.marcadorVisitante,
    required this.texto,
    this.jugadorId,
    this.asistenteId,
    this.defensorId,
    this.reboteId,
    this.reboteOfensivo = false,
    this.puntos = 0,
    this.convertido = false,
    this.triple = false,
    this.contraataque = false,
    this.taponado = false,
    this.entraId,
    this.saleId,
  });

  final TipoEvento tipo;

  /// Equipo que atacaba (o que hizo el cambio / pidió el tiempo).
  final bool local;
  final int cuarto;
  final double reloj;
  final int marcadorLocal;
  final int marcadorVisitante;
  final String texto;
  final String? jugadorId;
  final String? asistenteId;
  final String? defensorId;
  final String? reboteId;
  final bool reboteOfensivo;
  final int puntos;
  final bool convertido;
  final bool triple;
  final bool contraataque;
  final bool taponado;
  final String? entraId;
  final String? saleId;
}

/// Efectos de cada sistema sobre el juego (multiplicadores; 1 = neutro).
class _Efectos {
  const _Efectos({
    this.triples = 1,
    this.interior = 1,
    this.perdidas = 1,
    this.robos = 1,
    this.asistencias = 1,
    this.estrella = 1,
    this.contraataque = 1,
    this.fatiga = 1,
    this.tripleRival = 1,
    this.interiorRival = 1,
  });

  final double triples, interior, perdidas, robos, asistencias, estrella, contraataque, fatiga;

  /// Defensa: cómo cambia el acierto del rival en triples y cerca del aro.
  final double tripleRival, interiorRival;
}

const _ofensivos = {
  SistemaOfensivo.paceAndSpace: _Efectos(triples: 1.3, contraataque: 1.3, fatiga: 1.1),
  SistemaOfensivo.trianguloOfensivo: _Efectos(asistencias: 1.15, perdidas: 0.9, triples: 0.9),
  SistemaOfensivo.sevenSeconds: _Efectos(contraataque: 1.6, triples: 1.15, perdidas: 1.1, fatiga: 1.2),
  SistemaOfensivo.postInsideOut: _Efectos(interior: 1.3, triples: 1.05),
  SistemaOfensivo.motionOffense: _Efectos(asistencias: 1.2, perdidas: 0.92),
  SistemaOfensivo.aislamiento: _Efectos(estrella: 1.6, asistencias: 0.75, perdidas: 0.9),
  SistemaOfensivo.pickAndRollEspanol: _Efectos(asistencias: 1.15, interior: 1.1),
  SistemaOfensivo.cincoAbierto: _Efectos(triples: 1.45, interior: 0.85),
  SistemaOfensivo.dribbleDrive: _Efectos(interior: 1.2, estrella: 1.15, contraataque: 1.15),
  SistemaOfensivo.princeton: _Efectos(asistencias: 1.25, perdidas: 0.85, contraataque: 0.7, fatiga: 0.9),
};
const _defensivos = {
  EsquemaDefensivo.dropCoverage: _Efectos(interiorRival: 0.93, tripleRival: 1.04),
  EsquemaDefensivo.switchAll: _Efectos(tripleRival: 0.95, interiorRival: 1.02),
  EsquemaDefensivo.cajaYUno: _Efectos(estrella: 0.75, tripleRival: 1.02),
  EsquemaDefensivo.trapBlitz: _Efectos(robos: 1.25, tripleRival: 1.04, fatiga: 1.1),
  EsquemaDefensivo.presionTodaCancha: _Efectos(robos: 1.4, fatiga: 1.3, interiorRival: 1.03),
  EsquemaDefensivo.zona23: _Efectos(interiorRival: 0.9, tripleRival: 1.06),
  EsquemaDefensivo.packLine: _Efectos(interiorRival: 0.91, tripleRival: 1.03),
  EsquemaDefensivo.iceBlue: _Efectos(interiorRival: 0.96, tripleRival: 0.98),
  EsquemaDefensivo.zona131: _Efectos(robos: 1.3, tripleRival: 1.05, fatiga: 1.1),
  EsquemaDefensivo.gritAndGrind: _Efectos(interiorRival: 0.95, tripleRival: 0.97, fatiga: 1.1),
};

class _Lado {
  _Lado(this.equipo) {
    final perfil = PerfilPlantel.de(equipo.plantel);
    afinidadOfensiva = perfil.afinidad(equipo.tactica.ofensiva.rasgos);
    afinidadDefensiva = perfil.afinidad(equipo.tactica.defensiva.rasgos);
    for (final p in Posicion.titulares) {
      final j = equipo.plantel.en(p);
      if (j != null) enCancha.add(j);
    }
    banco = equipo.plantel.sextoHombre;
    for (final j in equipo.plantel.jugadores) {
      energia[j.id] = 100;
      box[j.id] = LineaEstadistica()..pj = 1;
    }
  }

  final EquipoPartido equipo;
  late final int afinidadOfensiva, afinidadDefensiva;
  final enCancha = <Jugador>[];
  Jugador? banco;
  final energia = <String, double>{};
  final box = <String, LineaEstadistica>{};
  final parciales = <int>[0];
  int tiemposMuertos = 5;
  int racha = 0; // puntos seguidos sin respuesta del rival
  bool acelerar = false, presion = false;

  int get puntos => parciales.fold(0, (a, b) => a + b);
  _Efectos get ofensivo => _ofensivos[equipo.tactica.ofensiva]!;
  _Efectos get defensivo => _defensivos[equipo.tactica.defensiva]!;
  double get ritmo => equipo.tactica.ofensiva.ritmo + equipo.tactica.defensiva.ritmo + (acelerar ? 1 : 0);
}

/// Motor de posesiones (GDD §6): cada llamada a [siguiente] juega una posesión (o una pausa) y
/// devuelve el evento. El marcador arranca 0-0 y nada se decide antes de jugarse.
/// La misma lógica sirve para mirar en vivo y para simular al instante ([simularTodo]).
class MotorPartido {
  MotorPartido({required EquipoPartido local, required EquipoPartido visitante, this.usuarioLocal, Random? azar})
    : _l = _Lado(local),
      _v = _Lado(visitante),
      _azar = azar ?? Random() {
    _ataqueLocal = _azar.nextBool(); // salto inicial
  }

  final _Lado _l, _v;
  final Random _azar;

  /// Lado que maneja el usuario (null: los dos los maneja la máquina, como en la simulación rápida).
  final bool? usuarioLocal;
  late bool _ataqueLocal;
  int cuarto = 1;
  double reloj = _duracionCuarto;
  bool terminado = false;
  bool _contraataque = false;
  bool _pausaPendiente = false;

  static const _duracionCuarto = 720.0, _duracionProrroga = 300.0, _localia = 0.012;

  int get puntosLocal => _l.puntos;
  int get puntosVisitante => _v.puntos;
  List<int> get parcialesLocal => List.unmodifiable(_l.parciales);
  List<int> get parcialesVisitante => List.unmodifiable(_v.parciales);
  Map<String, LineaEstadistica> get boxLocal => _l.box;
  Map<String, LineaEstadistica> get boxVisitante => _v.box;
  Map<String, double> energias(bool local) => Map.unmodifiable((local ? _l : _v).energia);
  List<Jugador> enCancha(bool local) => List.unmodifiable((local ? _l : _v).enCancha);
  Jugador? enBanco(bool local) => (local ? _l : _v).banco;
  int tiemposMuertos(bool local) => (local ? _l : _v).tiemposMuertos;

  /// Intervenciones del entrenador (GDD §6).
  void acelerarRitmo(bool local, bool activo) => (local ? _l : _v).acelerar = activo;
  void presionAlta(bool local, bool activo) => (local ? _l : _v).presion = activo;

  /// Tiempo muerto: recupera 10 de estamina a todos y corta la racha rival. Se aplica en la próxima pausa.
  bool pedirTiempoMuerto(bool local) {
    final lado = local ? _l : _v;
    if (lado.tiemposMuertos == 0 || terminado) return false;
    lado.tiemposMuertos--;
    for (final id in lado.energia.keys) {
      lado.energia[id] = min(100, lado.energia[id]! + 10);
    }
    (local ? _v : _l).racha = 0;
    _pausaPendiente = true;
    return true;
  }

  /// Juega todo lo que falta sin eventos visibles.
  void simularTodo() {
    while (!terminado) {
      siguiente();
    }
  }

  EventoPartido siguiente() {
    if (terminado) throw StateError('El partido terminó.');
    if (_pausaPendiente) {
      _pausaPendiente = false;
      return _evento(TipoEvento.tiempoMuerto, _ataqueLocal, 'Tiempo muerto.');
    }
    if (reloj <= 0) return _cerrarCuarto();
    // La máquina pide tiempo muerto para cortar una racha de 10 puntos.
    for (final local in [true, false]) {
      final rival = local ? _v : _l;
      if (usuarioLocal != local && rival.racha >= 10 && pedirTiempoMuerto(local)) return siguiente();
    }
    final cambio = _rotar(_l, true) ?? _rotar(_v, false);
    if (cambio != null) return cambio;
    return _posesion();
  }

  EventoPartido _cerrarCuarto() {
    final empate = _l.puntos == _v.puntos;
    if (cuarto >= 4 && !empate) {
      terminado = true;
      return _evento(TipoEvento.finPartido, true, 'Final: ${_l.puntos}-${_v.puntos}.');
    }
    cuarto++;
    reloj = cuarto > 4 ? _duracionProrroga : _duracionCuarto;
    _l.parciales.add(0);
    _v.parciales.add(0);
    for (final lado in [_l, _v]) {
      for (final id in lado.energia.keys) {
        lado.energia[id] = min(100, lado.energia[id]! + 12); // descanso entre cuartos
      }
    }
    if (cuarto == 3) _ataqueLocal = !_ataqueLocal;
    final texto = cuarto > 4 ? 'Empate: ¡prórroga!' : 'Fin del ${cuarto - 1}.º cuarto.';
    return _evento(TipoEvento.finCuarto, true, texto);
  }

  /// Rotación del Sexto Hombre: entra por el titular más cansado y sale cuando se agota.
  EventoPartido? _rotar(_Lado lado, bool local) {
    final banco = lado.banco;
    if (banco == null) return null;
    final cierre = cuarto >= 4 && reloj < 150 && (_l.puntos - _v.puntos).abs() <= 8;
    final cansado = lado.enCancha.reduce((a, b) => lado.energia[a.id]! < lado.energia[b.id]! ? a : b);
    final debeEntrar = lado.energia[cansado.id]! < 62 && lado.energia[banco.id]! > 75;
    final debeVolver = lado.energia[banco.id]! > 92 && lado.energia[cansado.id]! < 70;
    if (cierre && banco.media < cansado.media - 3) return null;
    if (!debeEntrar && !debeVolver) return null;
    lado.enCancha[lado.enCancha.indexOf(cansado)] = banco;
    lado.banco = cansado;
    return _evento(
      TipoEvento.cambio,
      local,
      'Cambio: entra ${banco.nombre} por ${cansado.nombre}.',
      entraId: banco.id,
      saleId: cansado.id,
    );
  }

  EventoPartido _posesion() {
    final ataque = _ataqueLocal ? _l : _v;
    final defensa = _ataqueLocal ? _v : _l;
    final contraataque = _contraataque;
    _contraataque = false;

    final ritmo = (ataque.ritmo + defensa.ritmo) / 2;
    var segundos = contraataque ? 6.0 + _azar.nextDouble() * 3 : 13.0 - 1.6 * ritmo + _azar.nextDouble() * 6;
    segundos = min(segundos, reloj);
    reloj -= segundos;
    _fatiga(ataque, segundos);
    _fatiga(defensa, segundos);

    // Pérdida (con o sin robo).
    final perdidas = _media(ataque.enCancha, (j) => j.stats.perP * 36 / max(j.stats.minP, 12)) / 2.4;
    final robos = _media(defensa.enCancha, (j) => j.stats.robP * 36 / max(j.stats.minP, 12)) / 1.3;
    final pPerdida =
        (0.125 *
                perdidas *
                (0.6 + 0.4 * robos) *
                ataque.ofensivo.perdidas *
                defensa.defensivo.robos *
                (defensa.presion ? 1.3 : 1) *
                (1 - (ataque.equipo.plantel.jugadores.map((j) => j.stats.iq).reduce(max) - 75) / 400))
            .clamp(0.06, 0.22);
    if (_azar.nextDouble() < pPerdida) {
      final quien = _elegir(ataque.enCancha, (j) => j.stats.perP + 0.5);
      ataque.box[quien.id]!.per++;
      final hayRobo = _azar.nextDouble() < 0.55;
      final ladron = hayRobo ? _elegir(defensa.enCancha, (j) => j.stats.robP + 0.3) : null;
      if (ladron != null) {
        defensa.box[ladron.id]!.rob++;
        _contraataque = _azar.nextDouble() < 0.45 * defensa.ofensivo.contraataque;
      }
      _cambiarPosesion();
      return _evento(
        TipoEvento.perdida,
        ataque == _l,
        ladron != null ? 'Robo de ${ladron.nombre} a ${quien.nombre}.' : 'Pérdida de ${quien.nombre}.',
        jugadorId: quien.id,
        defensorId: ladron?.id,
        contraataque: _contraataque,
      );
    }

    // Tiro: quién y de dónde.
    final efectoEstrella = ataque.ofensivo.estrella * defensa.defensivo.estrella;
    final estrella = ataque.enCancha.reduce((a, b) => a.stats.ppp > b.stats.ppp ? a : b);
    final tirador = _elegir(
      ataque.enCancha,
      (j) => pow(j.stats.ppp * 36 / max(j.stats.minP, 12), 1.3) * (j == estrella ? efectoEstrella : 1).toDouble(),
    );
    final s = tirador.stats;
    final tasaTriple = _tasaTriples(tirador) * ataque.ofensivo.triples;
    final triple = !contraataque && _azar.nextDouble() < tasaTriple.clamp(0.0, 0.75);
    final asistente = _azar.nextDouble() < 0.58 * ataque.ofensivo.asistencias
        ? _elegir([
            for (final j in ataque.enCancha)
              if (j != tirador) j,
          ], (j) => j.stats.app + 0.3)
        : null;

    var p = triple ? s.pctT3.clamp(0.22, 0.46) : _pctDos(tirador);
    p *= triple ? defensa.defensivo.tripleRival : defensa.defensivo.interiorRival;
    p += (tirador.media - 80) / 400; // las cartas de más media rinden más que sus porcentajes
    p += (ataque.afinidadOfensiva - defensa.afinidadDefensiva) / 1500;
    p -= _media(defensa.enCancha, (j) => j.stats.robP + j.stats.tapP) / 60;
    if (contraataque) p += 0.14;
    if (asistente != null) p += 0.02;
    if (ataque == _l) p += _localia;
    if (ataque.racha >= 8) p += 0.02;
    final energia = ataque.energia[tirador.id]!;
    if (energia < 60) p -= (60 - energia) / 400;
    p = p.clamp(0.15, 0.8);

    final falta = _azar.nextDouble() < 0.07 + s.pctTl * 0.04 + (triple ? 0 : 0.03);
    final convertido = _azar.nextDouble() < p;
    final caja = ataque.box[tirador.id]!;
    caja.tcA++;
    if (triple) caja.t3A++;

    if (convertido) {
      final puntos = triple ? 3 : 2;
      caja.tcI++;
      if (triple) caja.t3I++;
      if (asistente != null) ataque.box[asistente.id]!.ast++;
      final extra = falta ? _libres(ataque, tirador, 1) : 0;
      caja.pts += puntos + extra;
      _anotar(ataque, defensa, puntos + extra);
      _cambiarPosesion();
      final texto = StringBuffer(triple ? '¡Triple de ${tirador.nombre}!' : 'Doble de ${tirador.nombre}.');
      if (asistente != null) texto.write(' Asistencia de ${asistente.nombre}.');
      if (falta) texto.write(extra > 0 ? ' ¡Y la falta!' : ' Falla el adicional.');
      return _evento(
        TipoEvento.tiro,
        ataque == _l,
        texto.toString(),
        jugadorId: tirador.id,
        asistenteId: asistente?.id,
        puntos: puntos + extra,
        convertido: true,
        triple: triple,
        contraataque: contraataque,
      );
    }

    // Falla: falta en el tiro, tapón o rebote.
    if (falta) {
      final anotados = _libres(ataque, tirador, triple ? 3 : 2);
      caja.pts += anotados;
      _anotar(ataque, defensa, anotados);
      _cambiarPosesion();
      return _evento(
        TipoEvento.libres,
        ataque == _l,
        'Falta sobre ${tirador.nombre}: $anotados/${triple ? 3 : 2} libres.',
        jugadorId: tirador.id,
        puntos: anotados,
        convertido: anotados > 0,
        triple: triple,
      );
    }
    Jugador? taponador;
    if (!triple && _azar.nextDouble() < (_media(defensa.enCancha, (j) => j.stats.tapP) / 6).clamp(0.03, 0.2)) {
      taponador = _elegir(defensa.enCancha, (j) => j.stats.tapP + 0.1);
      defensa.box[taponador.id]!.tap++;
    }
    final rebOf =
        (ataque.enCancha.fold(0.0, (a, j) => a + j.stats.rpp) /
                max(1.0, defensa.enCancha.fold(0.0, (a, j) => a + j.stats.rpp)) *
                0.26)
            .clamp(0.15, 0.38);
    final ofensivo = _azar.nextDouble() < rebOf;
    final reboteador = _elegir(ofensivo ? ataque.enCancha : defensa.enCancha, (j) => j.stats.rpp + 0.5);
    (ofensivo ? ataque : defensa).box[reboteador.id]!.reb++;
    if (!ofensivo) {
      _cambiarPosesion();
      _contraataque = _azar.nextDouble() < 0.12 * defensa.ofensivo.contraataque + (defensa.acelerar ? 0.08 : 0);
    }
    final texto = StringBuffer(
      taponado(taponador, tirador) ?? (triple ? 'Falla el triple ${tirador.nombre}.' : 'Falla ${tirador.nombre}.'),
    );
    texto.write(ofensivo ? ' Rebote ofensivo de ${reboteador.nombre}.' : ' Rebote de ${reboteador.nombre}.');
    return _evento(
      TipoEvento.tiro,
      ataque == _l,
      texto.toString(),
      jugadorId: tirador.id,
      defensorId: taponador?.id,
      reboteId: reboteador.id,
      reboteOfensivo: ofensivo,
      triple: triple,
      contraataque: contraataque,
      taponado: taponador != null,
    );
  }

  String? taponado(Jugador? taponador, Jugador tirador) =>
      taponador == null ? null : '¡Tapón de ${taponador.nombre} a ${tirador.nombre}!';

  double _tasaTriples(Jugador j) {
    // Fracción de tiros que son triples, a partir de los porcentajes: %TC = f·%T3 + (1-f)·%T2.
    final s = j.stats;
    if (s.pctT3 <= 0) return 0;
    final posicion = j.posiciones.first;
    final base = switch (posicion) {
      Posicion.base || Posicion.escolta => 0.38,
      Posicion.alero => 0.32,
      Posicion.alaPivot => 0.2,
      _ => 0.08,
    };
    return (base * (s.pctT3 / 0.36)).clamp(0.0, 0.6);
  }

  double _pctDos(Jugador j) {
    final s = j.stats;
    final f = _tasaTriples(j);
    final dos = f < 0.95 ? (s.pctTc - f * s.pctT3) / (1 - f) : s.pctTc;
    return dos.clamp(0.38, 0.66);
  }

  int _libres(_Lado lado, Jugador tirador, int cantidad) {
    var anotados = 0;
    final caja = lado.box[tirador.id]!;
    for (var i = 0; i < cantidad; i++) {
      caja.tlA++;
      if (_azar.nextDouble() < tirador.stats.pctTl.clamp(0.4, 0.95)) {
        caja.tlI++;
        anotados++;
      }
    }
    return anotados;
  }

  void _anotar(_Lado ataque, _Lado defensa, int puntos) {
    if (puntos == 0) return;
    ataque.parciales[ataque.parciales.length - 1] += puntos;
    ataque.racha += puntos;
    defensa.racha = 0;
  }

  void _fatiga(_Lado lado, double segundos) {
    final extra = (lado.presion ? 0.25 : 0) + (lado.acelerar ? 0.2 : 0);
    for (final j in lado.enCancha) {
      final aguante = 36 / max(j.stats.minP, 20);
      lado.energia[j.id] = max(
        0,
        lado.energia[j.id]! - segundos / 60 * 1.9 * aguante * (lado.ofensivo.fatiga + extra) * lado.defensivo.fatiga,
      );
      lado.box[j.id]!.seg += segundos;
    }
    final banco = lado.banco;
    if (banco != null) lado.energia[banco.id] = min(100, lado.energia[banco.id]! + segundos / 60 * 4);
  }

  void _cambiarPosesion() => _ataqueLocal = !_ataqueLocal;

  double _media(List<Jugador> js, double Function(Jugador) f) =>
      js.isEmpty ? 0 : js.fold(0.0, (a, j) => a + f(j)) / js.length;

  Jugador _elegir(List<Jugador> js, double Function(Jugador) peso) {
    final pesos = [for (final j in js) max(0.001, peso(j))];
    var dado = _azar.nextDouble() * pesos.fold(0.0, (a, b) => a + b);
    for (final (i, w) in pesos.indexed) {
      dado -= w;
      if (dado <= 0) return js[i];
    }
    return js.last;
  }

  EventoPartido _evento(
    TipoEvento tipo,
    bool local,
    String texto, {
    String? jugadorId,
    String? asistenteId,
    String? defensorId,
    String? reboteId,
    bool reboteOfensivo = false,
    int puntos = 0,
    bool convertido = false,
    bool triple = false,
    bool contraataque = false,
    bool taponado = false,
    String? entraId,
    String? saleId,
  }) {
    return EventoPartido(
      tipo: tipo,
      local: local,
      cuarto: cuarto,
      reloj: reloj,
      marcadorLocal: _l.puntos,
      marcadorVisitante: _v.puntos,
      texto: texto,
      jugadorId: jugadorId,
      asistenteId: asistenteId,
      defensorId: defensorId,
      reboteId: reboteId,
      reboteOfensivo: reboteOfensivo,
      puntos: puntos,
      convertido: convertido,
      triple: triple,
      contraataque: contraataque,
      taponado: taponado,
      entraId: entraId,
      saleId: saleId,
    );
  }
}
