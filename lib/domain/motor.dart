import 'dart:math';

import 'entities/entrenador.dart';
import 'entities/jugador.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/tactica.dart';
import 'playbook.dart';
import 'quimica.dart';
import 'modificadores.dart';

/// Línea de box score (por partido o acumulada en la temporada).
class LineaEstadistica {
  LineaEstadistica();

  int pj = 0, pts = 0, reb = 0, ast = 0, rob = 0, tap = 0, per = 0;

  /// Faltas personales (con 6 queda afuera del partido).
  int fal = 0;
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
    fal += o.fal;
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
      ..seg = v[13].toDouble()
      ..fal = v.length > 14 ? v[14].toInt() : 0;
  }

  Map<String, dynamic> toJson() => {
    'v': [pj, pts, reb, ast, rob, tap, per, tcI, tcA, t3I, t3A, tlI, tlA, seg.round(), fal],
  };
}

/// Un equipo listo para jugar: identidad visual, 5 titulares + Sexto Hombre y su táctica.
class EquipoPartido {
  EquipoPartido({
    required this.identidadId,
    required this.plantel,
    required this.tactica,
    this.entrenador,
    this.forma = const {},
    this.energiaInicial = 100,
    this.reserva = const [],
    this.modificadores = ModificadoresEquipo.neutros,
  });

  final String identidadId;
  final Plantel plantel;
  final Tactica tactica;
  final Entrenador? entrenador;

  /// Forma de cada carta (−3 a +3), que se suma a su media en este partido.
  final Map<String, int> forma;

  /// Energía con la que arrancan (menos en un back-to-back o al final de una gira larga).
  final double energiaInicial;

  /// Suplentes del banco largo (además del Sexto Hombre): entran cuando alguien está fundido.
  final List<Jugador> reserva;

  /// Retoques del modo (insignias del Camino al anillo); neutros en un partido clásico.
  final ModificadoresEquipo modificadores;
}

enum TipoEvento { tiro, libres, perdida, falta, salto, cambio, tiempoMuerto, finCuarto, finPartido }

/// Cómo se perdió la pelota (los robos llevan además [EventoPartido.defensorId]).
enum TipoPerdida {
  robo('Robo'),
  afuera('Pelota afuera'),
  pasos('Pasos'),
  dobles('Doble dribbling'),
  carga('Falta en ataque'),
  veinticuatro('Violación de 24 segundos'),
  tresSegundos('3 segundos en la zona'),
  campoAtras('Campo atrás');

  const TipoPerdida(this.nombre);
  final String nombre;

  /// Infracciones: suena el silbato y la pelota queda muerta.
  bool get silbato => this != robo && this != afuera;
}

/// Faltas sin tiro (el evento [TipoEvento.falta]).
enum TipoFalta {
  /// Falta personal sin bonus: saque lateral, la posesión sigue.
  personal('Falta personal'),

  /// Con 5 faltas del equipo en el cuarto: 2 libres.
  bonus('Falta en bonus'),

  /// En el final, el que pierde frena el reloj mandando al peor tirador de libres a la línea.
  intencional('Falta intencional'),

  /// 1 libre y la posesión sigue; con 2 técnicas, expulsado. No cuenta como falta personal.
  tecnica('Falta técnica'),

  /// 2 libres y además la posesión.
  flagrante('Falta flagrante');

  const TipoFalta(this.nombre);
  final String nombre;
}

/// Jugada que pide el entrenador en el final apretado (GDD: jugada clave en el clutch).
enum JugadaClave {
  aislamiento('Aislamiento', 'La pelota a tu figura: uno contra uno.'),
  pickAndRoll('Pick & roll', 'Base y grande: doble cerca del aro, con asistencia.'),
  triple('Triple', 'Tu mejor tirador busca la de tres.');

  const JugadaClave(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

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
    this.volcada = false,
    this.alleyOop = false,
    this.jugadaClave,
    this.expulsadoId,
    this.perdida,
    this.falta,
    this.libres = 0,
    this.interferencia = false,
    this.chicharra = false,
    this.desdeLejos = false,
    this.participanteId,
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

  /// La canasta fue una volcada (y si vino de un pase alto, un alley-oop).
  final bool volcada;
  final bool alleyOop;

  /// Jugada clave que pidió el entrenador del usuario para esta posesión.
  final JugadaClave? jugadaClave;

  /// Jugador que se fue con 6 faltas (o 2 técnicas) en esta jugada.
  final String? expulsadoId;

  /// Pérdida: robo, pelota afuera o infracción.
  final TipoPerdida? perdida;

  /// Falta sin tiro (en [TipoEvento.falta]; el que la comete va en [defensorId]).
  final TipoFalta? falta;

  /// Tiros libres que se tiraron en la jugada (los convertidos suman [puntos]).
  final int libres;

  /// Interferencia: el defensor tocó la pelota bajando al aro y la canasta vale.
  final bool interferencia;

  /// El tiro se fue con el reloj del cuarto en cero (y [desdeLejos]: un lanzamiento desesperado
  /// desde más allá de la mitad de la cancha).
  final bool chicharra, desdeLejos;

  /// Otro jugador de la jugada: el que recibe la falta en ataque.
  final String? participanteId;
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
    final dt = equipo.entrenador;
    // El entrenador potencia su sistema y su esquema preferidos.
    afinidadOfensiva =
        perfil.afinidad(equipo.tactica.ofensiva.rasgos) + (dt?.ofensiva == equipo.tactica.ofensiva ? 12 : 0);
    afinidadDefensiva =
        perfil.afinidad(equipo.tactica.defensiva.rasgos) + (dt?.defensiva == equipo.tactica.defensiva ? 12 : 0);
    quimica = Quimica.de(equipo.plantel.jugadores, entrenador: dt);
    for (final p in Posicion.titulares) {
      final j = equipo.plantel.en(p);
      if (j != null) enCancha.add(j);
    }
    banco = equipo.plantel.sextoHombre;
    reserva.addAll(equipo.reserva);
    for (final j in equipo.reserva) {
      energia[j.id] = equipo.energiaInicial;
      box[j.id] = LineaEstadistica(); // PJ recién cuando entra
    }
    for (final j in equipo.plantel.jugadores) {
      energia[j.id] = equipo.energiaInicial;
      box[j.id] = LineaEstadistica()..pj = 1;
    }
  }

  final EquipoPartido equipo;
  late final int afinidadOfensiva, afinidadDefensiva;
  late final Quimica quimica;

  /// Media de la carta con su forma del momento.
  int media(Jugador j) => j.media + (equipo.forma[j.id] ?? 0);

  ModificadoresEquipo get mods => equipo.modificadores;

  /// Orden del entrenador: un gran técnico baja las pérdidas (hasta −6 %).
  double get ordenEntrenador => 1 - ((equipo.entrenador?.nivel ?? 80) - 80) / 320;
  final enCancha = <Jugador>[];
  Jugador? banco;
  final reserva = <Jugador>[];
  final energia = <String, double>{};
  final box = <String, LineaEstadistica>{};
  final parciales = <int>[0];
  int tiemposMuertos = 5;
  int faltas = 0; // faltas del equipo en el cuarto
  bool rotacionAuto = true;

  /// −1 = pocos minutos para el Sexto Hombre, 0 = normal, 1 = muchos.
  int minutosBanco = 0;

  /// Cambio pedido a mano (o forzado por la 6.ª falta): sale este jugador en la próxima pausa.
  String? salePendiente;
  final expulsados = <String>{};

  /// Faltas técnicas de cada uno (con 2, expulsado).
  final tecnicas = <String, int>{};

  /// Posesiones jugadas desde el último cambio automático (evita cambios en cadena).
  int posesionesDesdeCambio = 99;
  double recuperoTiempoMuerto = 10; // energía que devuelve cada tiempo muerto
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

  /// Arranca el partido en un momento dado (Momentos clutch: el final de un partido real).
  /// Llamar antes de la primera jugada. Los puntos previos se reparten en los cuartos ya jugados
  /// (las estadísticas individuales cuentan desde acá) y los titulares arrancan con [energia]
  /// (es el final del partido: ya vienen cansados).
  void arrancarEn({
    required int cuarto,
    required double reloj,
    required int puntosLocal,
    required int puntosVisitante,
    required bool ataqueLocal,
    int faltasLocal = 0,
    int faltasVisitante = 0,
    double energia = 75,
  }) {
    this.cuarto = cuarto;
    this.reloj = reloj;
    _ataqueLocal = ataqueLocal;
    for (final (lado, puntos, faltas) in [(_l, puntosLocal, faltasLocal), (_v, puntosVisitante, faltasVisitante)]) {
      lado.parciales
        ..clear()
        ..addAll([for (var k = 0; k < cuarto; k++) puntos ~/ cuarto + (k < puntos % cuarto ? 1 : 0)]);
      lado.faltas = faltas;
      for (final j in lado.enCancha) {
        lado.energia[j.id] = energia;
      }
    }
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

  /// Suplentes del banco largo que todavía no entraron (o que volvieron al banco).
  List<Jugador> reservas(bool local) => List.unmodifiable((local ? _l : _v).reserva);
  int tiemposMuertos(bool local) => (local ? _l : _v).tiemposMuertos;

  // ── Jugada clave, cambios y minutos (intervenciones del entrenador del usuario) ──

  JugadaClave? _jugadaClave;

  /// ¿La próxima posesión es del usuario? (para ofrecerle la jugada clave).
  bool get ataqueDelUsuario => usuarioLocal != null && _ataqueLocal == usuarioLocal;

  /// Pide una jugada para la próxima posesión del usuario.
  void pedirJugada(JugadaClave jugada) => _jugadaClave = jugada;

  void rotacionAutomatica(bool local, bool activa) => (local ? _l : _v).rotacionAuto = activa;
  bool esRotacionAutomatica(bool local) => (local ? _l : _v).rotacionAuto;

  void minutosDelBanco(bool local, int nivel) => (local ? _l : _v).minutosBanco = nivel.clamp(-1, 1);
  int nivelMinutosBanco(bool local) => (local ? _l : _v).minutosBanco;

  /// Saca a [saleId] para que entre el Sexto Hombre en la próxima jugada.
  bool cambiar(bool local, String saleId) {
    final lado = local ? _l : _v;
    if (lado.banco == null || !lado.enCancha.any((j) => j.id == saleId)) return false;
    if (lado.expulsados.contains(lado.banco!.id)) return false;
    lado.salePendiente = saleId;
    return true;
  }

  /// Jugador que sale en la próxima jugada por un cambio pedido (null si no hay).
  String? cambioPendiente(bool local) => (local ? _l : _v).salePendiente;

  bool expulsado(String id) => _l.expulsados.contains(id) || _v.expulsados.contains(id);

  /// Forma de las cartas en este partido (−3 a +3).
  Map<String, int> get forma => {..._l.equipo.forma, ..._v.equipo.forma};

  /// Faltas del equipo en el cuarto que se está jugando.
  int faltas(bool local) => (local ? _l : _v).faltas;

  /// Momento clutch: últimos 5 minutos del 4.º cuarto (o prórroga) con 6 puntos o menos de diferencia.
  bool get momentoClutch => cuarto >= 4 && reloj <= 300 && (_l.puntos - _v.puntos).abs() <= 6;

  /// Sangre fría en los finales (no hay estadística de clutch en los datos): se deduce del nivel de la
  /// carta (premios), su IQ y su %TL. Va de -0.5 (se achica) a ~1.6 (vive para ese momento).
  static double clutch(Jugador j) {
    final nivel = switch (j.tier) {
      Tier.sPlus => 1.0,
      Tier.s => 0.6,
      Tier.a => 0.2,
      Tier.b => -0.2,
    };
    return (nivel + (j.stats.iq - 75) / 50 + (j.stats.pctTl - 0.75) * 2).clamp(-0.5, 1.6);
  }

  /// Cuánto pesa en el tiro la diferencia de media entre el tirador y la defensa en cancha.
  static const pesoDiferencia = 1 / 225;

  /// Ventajas del entrenador del usuario (por nivel): tiempos muertos extra y descanso más largo.
  void ventajasUsuario({int tiemposExtra = 0, bool descansoLargo = false}) {
    final lado = usuarioLocal == null ? null : (usuarioLocal! ? _l : _v);
    if (lado == null) return;
    lado.tiemposMuertos += tiemposExtra;
    if (descansoLargo) lado.recuperoTiempoMuerto = 20;
  }

  /// Intervenciones del entrenador (GDD §6).
  void acelerarRitmo(bool local, bool activo) => (local ? _l : _v).acelerar = activo;
  void presionAlta(bool local, bool activo) => (local ? _l : _v).presion = activo;

  /// Tiempo muerto: recupera 10 de estamina a todos y corta la racha rival. Se aplica en la próxima pausa.
  bool pedirTiempoMuerto(bool local) {
    final lado = local ? _l : _v;
    if (lado.tiemposMuertos == 0 || terminado) return false;
    lado.tiemposMuertos--;
    for (final id in lado.energia.keys) {
      lado.energia[id] = min(100, lado.energia[id]! + lado.recuperoTiempoMuerto);
    }
    (local ? _v : _l).racha = 0;
    _pausaPendiente = true;
    return true;
  }

  /// Solo para pruebas: técnica a un defensor del equipo que no ataca (1 libre, sigue la posesión).
  EventoPartido tecnicaDePrueba() => _tecnica(_ataqueLocal ? _l : _v, _ataqueLocal ? _v : _l);

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
    final pedido = _cambioPedido(_l, true) ?? _cambioPedido(_v, false);
    if (pedido != null) return pedido;
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
    _l.faltas = 0;
    _v.faltas = 0;
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
  /// Cambio pedido a mano o por la 6.ª falta.
  EventoPartido? _cambioPedido(_Lado lado, bool local) {
    final saleId = lado.salePendiente;
    final banco = lado.banco;
    if (saleId == null) return null;
    lado.salePendiente = null;
    final i = lado.enCancha.indexWhere((j) => j.id == saleId);
    if (banco == null || i < 0 || lado.expulsados.contains(banco.id)) return null;
    final sale = lado.enCancha[i];
    lado.enCancha[i] = banco;
    lado.banco = sale;
    final motivo = lado.expulsados.contains(sale.id) ? 'Sexta falta de ${sale.nombre}: ' : 'Cambio: ';
    return _evento(
      TipoEvento.cambio,
      local,
      '${motivo}entra ${banco.nombre} por ${sale.nombre}.',
      entraId: banco.id,
      saleId: sale.id,
    );
  }

  EventoPartido? _rotar(_Lado lado, bool local) {
    final banco = lado.banco;
    if (banco == null || !lado.rotacionAuto || lado.expulsados.contains(banco.id)) return null;
    if (lado.posesionesDesdeCambio < 2) return null;
    final cierre = cuarto >= 4 && reloj < 150 && (_l.puntos - _v.puntos).abs() <= 8;
    // Cargado de faltas: 2 en el 1.º cuarto, 3 en el 2.º, 4 en el 3.º, 5 en el último → al banco.
    final limite = min(cuarto, 4) + 1;
    final enProblemas = lado.enCancha.where((j) => lado.box[j.id]!.fal >= limite).toList();
    if (enProblemas.isNotEmpty && !cierre && lado.energia[banco.id]! > 60 && lado.box[banco.id]!.fal < limite) {
      final sale = enProblemas.first;
      lado.posesionesDesdeCambio = 0;
      lado.enCancha[lado.enCancha.indexOf(sale)] = banco;
      lado.banco = sale;
      return _evento(
        TipoEvento.cambio,
        local,
        'Cambio: ${sale.nombre} se sienta cargado de faltas; entra ${banco.nombre}.',
        entraId: banco.id,
        saleId: sale.id,
      );
    }
    final cansado = lado.enCancha.reduce((a, b) => lado.energia[a.id]! < lado.energia[b.id]! ? a : b);
    // Banco largo: si alguien está fundido y el Sexto no puede, entra un suplente descansado.
    final reserva = lado.reserva.where((j) => lado.energia[j.id]! > 80 && !lado.expulsados.contains(j.id)).toList();
    final liquidado = cuarto >= 4 && (_l.puntos - _v.puntos).abs() >= 18;
    final fundido = lado.energia[cansado.id]! < 56 && lado.energia[banco.id]! < 78;
    if (reserva.isNotEmpty && (fundido || (liquidado && !lado.reserva.contains(cansado)))) {
      final entra = reserva.reduce((a, b) => a.media >= b.media ? a : b);
      lado.posesionesDesdeCambio = 0;
      lado.enCancha[lado.enCancha.indexOf(cansado)] = entra;
      lado.reserva
        ..remove(entra)
        ..add(cansado);
      lado.box[entra.id]!.pj = 1;
      return _evento(
        TipoEvento.cambio,
        local,
        'Cambio: entra ${entra.nombre} desde el banco largo por ${cansado.nombre}.',
        entraId: entra.id,
        saleId: cansado.id,
      );
    }
    final umbralEntra = 62 + lado.minutosBanco * 10, umbralVuelve = 92 + lado.minutosBanco * 4;
    final debeEntrar = lado.energia[cansado.id]! < umbralEntra && lado.energia[banco.id]! > 75;
    final debeVolver = lado.energia[banco.id]! > umbralVuelve && lado.energia[cansado.id]! < umbralEntra + 8;
    if (cierre && banco.media < cansado.media - 3) return null;
    if (lado.box[cansado.id]!.fal >= 5 && lado.box[banco.id]!.fal >= 5) return null;
    if (!debeEntrar && !debeVolver) return null;
    lado.posesionesDesdeCambio = 0;
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

  /// Lo que queda del reloj de 24 en la posesión en curso (menos tras un saque lateral; 14 tras un
  /// rebote ofensivo).
  double _restoPosesion = 24;

  /// Segundos que ya se jugaron de esta posesión antes de un corte (saque lateral, técnica, salto
  /// ganado): la jugada que sigue usa lo que queda.
  double _yaJugado = 0;

  /// Gasta [segundos] del reloj (con su desgaste); nunca menos de lo que queda, nunca cero si queda.
  double _consumir(_Lado ataque, _Lado defensa, double segundos) {
    final gasto = min(reloj, max(0.5, segundos));
    reloj -= gasto;
    _fatiga(ataque, gasto);
    _fatiga(defensa, gasto);
    return gasto;
  }

  /// Suma una falta personal (y de equipo) a [j]; con la 6.ª queda afuera. Devuelve su id si se fue.
  String? _faltaPersonal(_Lado lado, Jugador j, {bool deEquipo = true}) {
    if (deEquipo) lado.faltas++;
    final linea = lado.box[j.id]!;
    linea.fal++;
    if (linea.fal == 6) {
      lado.expulsados.add(j.id);
      lado.salePendiente = j.id;
      return j.id;
    }
    return null;
  }

  /// Quién comete una falta defensiva: más los grandes que van a taponar y los que presionan.
  /// El que está cargado de faltas se cuida (pega mucho menos).
  Jugador _infractor(_Lado defensa) => _elegir(
    defensa.enCancha,
    (j) => (j.stats.tapP + j.stats.robP * 0.6 + 0.6) * pow((6 - defensa.box[j.id]!.fal).clamp(0, 6) / 6, 2.5),
  );

  /// Probabilidades por posesión de lo que corta el juego (calibradas a un partido NBA).
  static const _pFaltaSinTiro = 0.085, _pTecnica = 0.0016, _pFlagrante = 0.0004, _pSalto = 0.0016;

  EventoPartido _posesion() {
    final ataque = _ataqueLocal ? _l : _v;
    final defensa = _ataqueLocal ? _v : _l;
    _l.posesionesDesdeCambio++;
    _v.posesionesDesdeCambio++;
    final contraataque = _contraataque;
    _contraataque = false;
    final diferencia = ataque.puntos - defensa.puntos;
    final finalPartido = cuarto >= 4 && reloj <= 60;

    // Final: el que pierde por poco frena el reloj con una falta al peor tirador de libres. Abajo por
    // 1 o 2 con menos de 24 segundos (ya no hay reloj de posesión que lo salve), también.
    final faltaPorPoco = diferencia >= 1 && diferencia <= 2 && reloj <= 24 && reloj > 1.5;
    if (cuarto >= 4 && reloj <= 35 && (faltaPorPoco || (diferencia >= 3 && diferencia <= min(8, 3 + reloj / 5)))) {
      return _faltaIntencional(ataque, defensa);
    }

    final ritmo = (ataque.ritmo + defensa.ritmo) / 2;
    var segundos = contraataque ? 6.0 + _azar.nextDouble() * 3 : 11.6 - 1.6 * ritmo + _azar.nextDouble() * 5.5;
    segundos = max(1.5, segundos - _yaJugado);
    _yaJugado = 0;
    // Final apretado: el que pierde se apura; el que gana hace correr el reloj.
    if (finalPartido && diferencia < 0) segundos = 4 + _azar.nextDouble() * 4;
    if (finalPartido && diferencia > 0) segundos = 17 + _azar.nextDouble() * 5;
    segundos = min(segundos, _restoPosesion - 0.5);
    final inicio = reloj;

    // Jugadas que cortan la posesión antes del final (siempre gastan reloj: nunca se traban).
    if (inicio > 3) {
      final dado = _azar.nextDouble();
      if (dado < _pTecnica) return _tecnica(ataque, defensa);
      if (dado < _pTecnica + _pFlagrante) return _flagrante(ataque, defensa);
      if (dado < _pTecnica + _pFlagrante + _pSalto) return _saltoEntreDos(ataque, defensa);
      if (!contraataque && _azar.nextDouble() < _pFaltaSinTiro * (defensa.presion ? 1.25 : 1)) {
        return _faltaSinTiro(ataque, defensa, segundos);
      }
    }

    // Pérdida (con o sin robo).
    final perdidas = _media(ataque.enCancha, (j) => j.stats.perP * 36 / max(j.stats.minP, 12)) / 2.4;
    final robos = _media(defensa.enCancha, (j) => j.stats.robP * 36 / max(j.stats.minP, 12)) / 1.3;
    final pPerdida =
        (0.178 *
                perdidas *
                (0.6 + 0.4 * robos) *
                ataque.ofensivo.perdidas *
                ataque.ordenEntrenador *
                defensa.defensivo.robos *
                defensa.mods.robosFactor *
                (defensa.presion ? 1.3 : 1) *
                (1 - (ataque.equipo.plantel.jugadores.map((j) => j.stats.iq).reduce(max) - 75) / 400))
            .clamp(0.09, 0.3);
    if (inicio > 3 && _azar.nextDouble() < pPerdida) return _perdida(ataque, defensa, segundos, robos);

    // El tiro se va con el reloj del cuarto: si queda poco, se tira lo que salga (y si queda casi
    // nada, desde donde esté, más allá de la mitad de la cancha).
    final chicharra = segundos >= inicio;
    final desdeLejos = inicio <= 2.6 && !contraataque;
    _consumir(ataque, defensa, desdeLejos ? inicio : segundos);
    return _tiro(ataque, defensa, contraataque: contraataque, chicharra: chicharra, desdeLejos: desdeLejos);
  }

  EventoPartido _faltaIntencional(_Lado ataque, _Lado defensa) {
    _consumir(ataque, defensa, 1 + _azar.nextDouble() * 2.5);
    final tirador = ataque.enCancha.reduce((a, b) => a.stats.pctTl <= b.stats.pctTl ? a : b);
    final infractor = defensa.enCancha.reduce((a, b) => defensa.box[a.id]!.fal <= defensa.box[b.id]!.fal ? a : b);
    final expulsado = _faltaPersonal(defensa, infractor);
    final anotados = _libres(ataque, tirador, 2);
    ataque.box[tirador.id]!.pts += anotados;
    _anotar(ataque, defensa, anotados);
    _cambiarPosesion();
    return _evento(
      TipoEvento.falta,
      ataque == _l,
      'Falta intencional de ${infractor.nombre} sobre ${tirador.nombre}: $anotados/2 libres.',
      jugadorId: tirador.id,
      defensorId: infractor.id,
      puntos: anotados,
      convertido: anotados > 0,
      falta: TipoFalta.intencional,
      libres: 2,
      expulsadoId: expulsado,
    );
  }

  /// Falta sin tiro: saque lateral (la posesión sigue con menos reloj de 24) o, en bonus, 2 libres.
  EventoPartido _faltaSinTiro(_Lado ataque, _Lado defensa, double segundos) {
    final gasto = _consumir(ataque, defensa, 2 + _azar.nextDouble() * max(1, segundos - 3));
    final infractor = _infractor(defensa);
    final recibe = _elegir(ataque.enCancha, (j) => j.stats.ppp + j.stats.app + 3);
    final expulsado = _faltaPersonal(defensa, infractor);
    if (defensa.faltas < 5) {
      _restoPosesion = max(14, _restoPosesion - gasto);
      _yaJugado += gasto;
      return _evento(
        TipoEvento.falta,
        ataque == _l,
        'Falta de ${infractor.nombre} sobre ${recibe.nombre}. Saque lateral.',
        jugadorId: recibe.id,
        defensorId: infractor.id,
        falta: TipoFalta.personal,
        expulsadoId: expulsado,
      );
    }
    final anotados = _libres(ataque, recibe, 2);
    ataque.box[recibe.id]!.pts += anotados;
    _anotar(ataque, defensa, anotados);
    _cambiarPosesion();
    return _evento(
      TipoEvento.falta,
      ataque == _l,
      'Falta de ${infractor.nombre} con el equipo en bonus: ${recibe.nombre}, $anotados/2 libres.',
      jugadorId: recibe.id,
      defensorId: infractor.id,
      puntos: anotados,
      convertido: anotados > 0,
      falta: TipoFalta.bonus,
      libres: 2,
      expulsadoId: expulsado,
    );
  }

  /// Técnica a un defensor que protesta: 1 libre para el mejor tirador y la posesión sigue.
  EventoPartido _tecnica(_Lado ataque, _Lado defensa) {
    final gasto = _consumir(ataque, defensa, 2 + _azar.nextDouble() * 4);
    _restoPosesion = max(14, _restoPosesion - gasto);
    _yaJugado += gasto;
    final infractor = _elegir(defensa.enCancha, (j) => 1 + (90 - j.stats.iq).clamp(0, 30) / 10);
    final tirador = ataque.enCancha.reduce((a, b) => a.stats.pctTl >= b.stats.pctTl ? a : b);
    final tecnicas = defensa.tecnicas[infractor.id] = (defensa.tecnicas[infractor.id] ?? 0) + 1;
    String? expulsado;
    if (tecnicas >= 2 && defensa.expulsados.add(infractor.id)) {
      defensa.salePendiente = infractor.id;
      expulsado = infractor.id;
    }
    final anotados = _libres(ataque, tirador, 1);
    ataque.box[tirador.id]!.pts += anotados;
    _anotar(ataque, defensa, anotados);
    return _evento(
      TipoEvento.falta,
      ataque == _l,
      'Técnica a ${infractor.nombre} por protestar. ${tirador.nombre}: $anotados/1.'
      '${expulsado != null ? ' ¡Segunda técnica: expulsado!' : ''}',
      jugadorId: tirador.id,
      defensorId: infractor.id,
      puntos: anotados,
      convertido: anotados > 0,
      falta: TipoFalta.tecnica,
      libres: 1,
      expulsadoId: expulsado,
    );
  }

  /// Flagrante: 2 libres y la pelota sigue siendo del que la recibió.
  EventoPartido _flagrante(_Lado ataque, _Lado defensa) {
    _consumir(ataque, defensa, 2 + _azar.nextDouble() * 5);
    _restoPosesion = 24;
    final infractor = _infractor(defensa);
    final recibe = _elegir(ataque.enCancha, (j) => j.stats.ppp + 2);
    final expulsado = _faltaPersonal(defensa, infractor);
    final anotados = _libres(ataque, recibe, 2);
    ataque.box[recibe.id]!.pts += anotados;
    _anotar(ataque, defensa, anotados);
    return _evento(
      TipoEvento.falta,
      ataque == _l,
      'Falta flagrante de ${infractor.nombre} sobre ${recibe.nombre}: $anotados/2 y la pelota sigue.',
      jugadorId: recibe.id,
      defensorId: infractor.id,
      puntos: anotados,
      convertido: anotados > 0,
      falta: TipoFalta.flagrante,
      libres: 2,
      expulsadoId: expulsado,
    );
  }

  /// Pelota retenida: salto entre dos; [EventoPartido.convertido] si la gana el que atacaba.
  EventoPartido _saltoEntreDos(_Lado ataque, _Lado defensa) {
    final gasto = _consumir(ataque, defensa, 3 + _azar.nextDouble() * 5);
    final a = _elegir(ataque.enCancha, (j) => j.stats.rpp + 1);
    final d = _elegir(defensa.enCancha, (j) => j.stats.rpp + 1);
    double alcance(Jugador j) => j.stats.rpp + j.stats.tapP * 2 + 2;
    final gana = _azar.nextDouble() < alcance(a) / (alcance(a) + alcance(d));
    if (gana) {
      _restoPosesion = max(14, _restoPosesion - gasto);
      _yaJugado += gasto;
    } else {
      _cambiarPosesion();
    }
    return _evento(
      TipoEvento.salto,
      ataque == _l,
      'Pelota retenida entre ${a.nombre} y ${d.nombre}: salto entre dos, la gana ${gana ? a.nombre : d.nombre}.',
      jugadorId: a.id,
      defensorId: d.id,
      convertido: gana,
    );
  }

  /// Pérdida: robo, pelota afuera o infracción (pasos, dobles, falta en ataque, 24, 3 segundos,
  /// campo atrás).
  EventoPartido _perdida(_Lado ataque, _Lado defensa, double segundos, double robos) {
    final dado = _azar.nextDouble();
    final pRobo = (0.44 + 0.12 * robos * defensa.defensivo.robos).clamp(0.4, 0.66);
    final tipo = dado < pRobo
        ? TipoPerdida.robo
        : _elegirPeso({
            TipoPerdida.afuera: 0.27,
            TipoPerdida.carga: 0.24,
            TipoPerdida.pasos: 0.16,
            TipoPerdida.veinticuatro: 0.11,
            TipoPerdida.tresSegundos: 0.09,
            TipoPerdida.dobles: 0.06,
            TipoPerdida.campoAtras: 0.07,
          });
    _consumir(ataque, defensa, switch (tipo) {
      TipoPerdida.veinticuatro => _restoPosesion,
      TipoPerdida.campoAtras => 3 + _azar.nextDouble() * 4,
      _ => segundos,
    });
    final quien = switch (tipo) {
      TipoPerdida.tresSegundos => _elegir(ataque.enCancha, (j) => j.stats.rpp + 0.5),
      TipoPerdida.carga => _elegir(ataque.enCancha, (j) => j.stats.ppp + j.stats.perP * 4),
      _ => _elegir(ataque.enCancha, (j) => j.stats.perP + 0.5),
    };
    ataque.box[quien.id]!.per++;
    Jugador? ladron, recibe;
    String? expulsado;
    if (tipo == TipoPerdida.robo) {
      ladron = _elegir(defensa.enCancha, (j) => j.stats.robP + 0.3);
      defensa.box[ladron.id]!.rob++;
      _contraataque = _azar.nextDouble() < 0.45 * defensa.ofensivo.contraataque * defensa.mods.contraataqueFactor;
    }
    if (tipo == TipoPerdida.carga) {
      // La falta en ataque es personal y del equipo (sin libres).
      recibe = _elegir(defensa.enCancha, (j) => j.stats.iq / 20 + j.stats.rpp / 4);
      expulsado = _faltaPersonal(ataque, quien);
    }
    _cambiarPosesion();
    final texto = switch (tipo) {
      TipoPerdida.robo => 'Robo de ${ladron!.nombre} a ${quien.nombre}.',
      TipoPerdida.afuera => 'Pérdida de ${quien.nombre}: la pelota se va afuera.',
      TipoPerdida.carga => 'Falta en ataque de ${quien.nombre}: ${recibe!.nombre} recibió la carga.',
      TipoPerdida.veinticuatro => 'Violación de 24 segundos: no llegaron a tirar.',
      _ => '${tipo.nombre}: pierde la pelota ${quien.nombre}.',
    };
    return _evento(
      TipoEvento.perdida,
      ataque == _l,
      expulsado == null ? texto : '$texto ¡Sexta falta de ${quien.nombre}: se va a las duchas!',
      jugadorId: quien.id,
      defensorId: ladron?.id,
      contraataque: _contraataque,
      perdida: tipo,
      participanteId: recibe?.id,
      expulsadoId: expulsado,
    );
  }

  T _elegirPeso<T>(Map<T, double> pesos) {
    var dado = _azar.nextDouble() * pesos.values.fold(0.0, (a, b) => a + b);
    for (final e in pesos.entries) {
      dado -= e.value;
      if (dado <= 0) return e.key;
    }
    return pesos.keys.last;
  }

  EventoPartido _tiro(
    _Lado ataque,
    _Lado defensa, {
    required bool contraataque,
    required bool chicharra,
    required bool desdeLejos,
  }) {
    // Tiro: quién y de dónde (o la jugada que pidió el entrenador del usuario).
    final jugada = (ataque == _l) == usuarioLocal ? _jugadaClave : null;
    if ((ataque == _l) == usuarioLocal) _jugadaClave = null;
    final clutch = momentoClutch;
    // En el final apretado, la pelota busca al que más se agranda.
    final efectoEstrella = ataque.ofensivo.estrella * defensa.defensivo.estrella * (clutch ? 1.6 : 1);
    final estrella = ataque.enCancha.reduce((a, b) => a.stats.ppp > b.stats.ppp ? a : b);
    bool interior(Jugador j) => j.posiciones.contains(Posicion.pivot) || j.posiciones.contains(Posicion.alaPivot);
    final Jugador tirador;
    final bool triple;
    Jugador? asistente;
    // Abajo por 3 en el final, la máquina busca el triple del empate; abajo por 4 a 9 con menos de 40
    // segundos, también (de a dos no alcanza).
    final abajo = defensa.puntos - ataque.puntos;
    final porElTriple =
        jugada == null && cuarto >= 4 && ((abajo == 3 && reloj <= 24) || (abajo >= 4 && abajo <= 9 && reloj <= 40));
    switch (desdeLejos ? null : (porElTriple ? JugadaClave.triple : jugada)) {
      case JugadaClave.aislamiento:
        tirador = ataque.enCancha.reduce((a, b) => ataque.media(a) >= ataque.media(b) ? a : b);
        triple = _azar.nextDouble() < _tasaTriples(tirador) * 0.6;
      case JugadaClave.pickAndRoll:
        final grandes = ataque.enCancha.where(interior).toList();
        final organizador = ataque.enCancha.reduce((a, b) => a.stats.app >= b.stats.app ? a : b);
        tirador = grandes.isNotEmpty && _azar.nextDouble() < 0.6
            ? grandes.reduce((a, b) => a.stats.ppp >= b.stats.ppp ? a : b)
            : organizador;
        triple = false;
        if (tirador != organizador) asistente = organizador;
      case JugadaClave.triple:
        tirador = ataque.enCancha.reduce(
          (a, b) => a.stats.pctT3 * _tasaTriples(a) >= b.stats.pctT3 * _tasaTriples(b) ? a : b,
        );
        triple = tirador.stats.pctT3 > 0;
      case null:
        tirador = desdeLejos
            ? _elegir(ataque.enCancha, (j) => j.stats.app + 1)
            : _elegir(
                ataque.enCancha,
                (j) =>
                    pow(j.stats.ppp * 36 / max(j.stats.minP, 12), 1.3) *
                    (j == estrella ? efectoEstrella : 1).toDouble() *
                    (clutch ? 1 + 0.4 * max(0, MotorPartido.clutch(j)) : 1),
              );
        final tasaTriple = _tasaTriples(tirador) * ataque.ofensivo.triples;
        triple = desdeLejos || (!contraataque && _azar.nextDouble() < tasaTriple.clamp(0.0, 0.75));
    }
    final s = tirador.stats;
    if (!desdeLejos && (jugada == null || jugada == JugadaClave.triple)) {
      asistente = _azar.nextDouble() < 0.58 * ataque.ofensivo.asistencias
          ? _elegir([
              for (final j in ataque.enCancha)
                if (j != tirador) j,
            ], (j) => j.stats.app + 0.3)
          : null;
    }

    var p = triple ? s.pctT3.clamp(0.22, 0.46) : _pctDos(tirador);
    p *= triple ? defensa.defensivo.tripleRival : defensa.defensivo.interiorRival;
    // La calidad manda: las cartas de más media rinden más y una defensa de cracks cierra más.
    final mediaTirador = ataque.media(tirador);
    p += (mediaTirador - _media(defensa.enCancha, (j) => defensa.media(j).toDouble())) * pesoDiferencia;
    p += 0.035 + (mediaTirador - 82) / 400;
    p += ataque.quimica.efectoTiro;
    if (clutch) p += MotorPartido.clutch(tirador) * 0.03;
    // La jugada bien elegida vale: aislar a un crack, el pick & roll cerca del aro, el triple abierto.
    p += switch (jugada) {
      JugadaClave.aislamiento => 0.02 + (ataque.media(tirador) - 85) / 400,
      JugadaClave.pickAndRoll => 0.04,
      JugadaClave.triple => 0.03,
      null => 0,
    };
    p += (ataque.afinidadOfensiva - defensa.afinidadDefensiva) / 1500;
    p -= _media(defensa.enCancha, (j) => j.stats.robP + j.stats.tapP) / 60;
    if (contraataque) p += 0.14;
    if (asistente != null) p += 0.02;
    // Retoques del modo (neutros en un partido clásico).
    p += (triple ? ataque.mods.tripleExtra : ataque.mods.interiorExtra - defensa.mods.interiorRival) +
        ataque.mods.quimicaExtra +
        (asistente != null ? ataque.mods.asistidoExtra : 0) +
        (clutch ? ataque.mods.clutchExtra : 0) +
        (cuarto >= 4 && tirador == estrella ? ataque.mods.estrellaCuartoFinal : 0);
    if (ataque == _l) p += _localia;
    if (ataque.racha >= 8) p += 0.02;
    final energia = ataque.energia[tirador.id]!;
    if (energia < 60) p -= (60 - energia) / 400;
    if (chicharra && !desdeLejos) p -= 0.05; // apurado, con la mano en la cara
    p = p.clamp(0.15, 0.8);
    // Lanzamiento desesperado desde la otra mitad: entra muy de vez en cuando.
    if (desdeLejos) p = 0.035;

    // Falta en el tiro: casi siempre al que va a la pintura; con falta, entra mucho menos (2+1).
    final falta = !desdeLejos && _azar.nextDouble() < (triple ? 0.022 : 0.112 + s.pctTl * 0.05);
    String? expulsado;
    if (falta) expulsado = _faltaPersonal(defensa, _infractor(defensa));
    if (falta) p *= 0.4;
    String conExpulsion(String texto) {
      if (expulsado == null) return texto;
      final j = defensa.enCancha.firstWhere((x) => x.id == expulsado);
      return '$texto ¡Sexta falta de ${j.nombre}: se va a las duchas!';
    }

    var convertido = _azar.nextDouble() < p;
    final caja = ataque.box[tirador.id]!;
    // Tapón (también algún triple) e interferencia (el defensor la toca bajando: vale igual).
    Jugador? taponador, interfiere;
    if (!convertido && !falta && !desdeLejos) {
      final pTapon = (_media(defensa.enCancha, (j) => j.stats.tapP) / 3.0).clamp(0.045, 0.28) * (triple ? 0.18 : 1);
      if (_azar.nextDouble() < pTapon) {
        taponador = _elegir(defensa.enCancha, (j) => j.stats.tapP + 0.1);
        defensa.box[taponador.id]!.tap++;
      } else if (!triple && _azar.nextDouble() < 0.0085) {
        interfiere = _elegir(defensa.enCancha, (j) => j.stats.tapP + 0.05);
        convertido = true;
      }
    }
    // La falta en un tiro errado no cuenta como tiro de campo.
    if (convertido || !falta) {
      caja.tcA++;
      if (triple) caja.t3A++;
    }
    _restoPosesion = 24;

    if (convertido) {
      final puntos = triple ? 3 : 2;
      caja.tcI++;
      if (triple) caja.t3I++;
      if (asistente != null) ataque.box[asistente.id]!.ast++;
      final extra = falta ? _libres(ataque, tirador, 1) : 0;
      caja.pts += puntos + extra;
      _anotar(ataque, defensa, puntos + extra);
      _cambiarPosesion();
      // Volcadas: más en contraataque y para los grandes y los atléticos; con pase alto, alley-oop.
      final atletico = interior(tirador) || tirador.posiciones.contains(Posicion.alero);
      final volcada =
          interfiere == null &&
          !triple &&
          _azar.nextDouble() < (contraataque ? 0.55 : (atletico ? 0.24 : 0.07)) * (0.8 + s.tapP / 2.5);
      final alleyOop = volcada && asistente != null && _azar.nextDouble() < 0.4;
      final texto = StringBuffer(
        desdeLejos
            ? '¡DESDE SU CASA, ${tirador.nombre}, SOBRE LA CHICHARRA!'
            : triple
            ? '¡Triple de ${tirador.nombre}!'
            : alleyOop
            ? '¡Alley-oop de ${asistente.nombre} para ${tirador.nombre}!'
            : volcada
            ? '¡Volcada de ${tirador.nombre}!'
            : 'Doble de ${tirador.nombre}.',
      );
      if (interfiere != null) texto.write(' Interferencia de ${interfiere.nombre}: vale igual.');
      if (asistente != null && !alleyOop) texto.write(' Asistencia de ${asistente.nombre}.');
      if (falta) texto.write(extra > 0 ? ' ¡Y la falta!' : ' Falla el adicional.');
      if (chicharra && !desdeLejos) texto.write(' ¡Sobre la chicharra!');
      if (clutch && MotorPartido.clutch(tirador) >= 1) texto.write(' ¡Sangre fría!');
      return _evento(
        TipoEvento.tiro,
        ataque == _l,
        conExpulsion(texto.toString()),
        jugadorId: tirador.id,
        asistenteId: asistente?.id,
        defensorId: interfiere?.id,
        puntos: puntos + extra,
        convertido: true,
        triple: triple,
        contraataque: contraataque,
        volcada: volcada,
        alleyOop: alleyOop,
        jugadaClave: jugada,
        expulsadoId: expulsado,
        libres: falta ? 1 : 0,
        interferencia: interfiere != null,
        chicharra: chicharra,
        desdeLejos: desdeLejos,
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
        conExpulsion('Falta sobre ${tirador.nombre}: $anotados/${triple ? 3 : 2} libres.'),
        jugadorId: tirador.id,
        puntos: anotados,
        convertido: anotados > 0,
        triple: triple,
        jugadaClave: jugada,
        expulsadoId: expulsado,
        libres: triple ? 3 : 2,
      );
    }
    // Rebote (con el reloj del cuarto en cero no hay rebote: termina el cuarto).
    final rebOf = taponador != null
        ? 0.42
        : (ataque.enCancha.fold(0.0, (a, j) => a + j.stats.rpp) /
                  max(1.0, defensa.enCancha.fold(0.0, (a, j) => a + j.stats.rpp)) *
                  0.26)
              .clamp(0.15, 0.38);
    final ofensivo = _azar.nextDouble() < rebOf * ataque.mods.reboteOfensivoFactor;
    final reboteador = _elegir(ofensivo ? ataque.enCancha : defensa.enCancha, (j) => j.stats.rpp + 0.5);
    (ofensivo ? ataque : defensa).box[reboteador.id]!.reb++;
    if (ofensivo) {
      _restoPosesion = 14;
    } else {
      _cambiarPosesion();
      _contraataque =
          _azar.nextDouble() <
          0.12 * defensa.ofensivo.contraataque * defensa.mods.contraataqueFactor + (defensa.acelerar ? 0.08 : 0);
    }
    final texto = StringBuffer(
      desdeLejos
          ? 'Lanzamiento desde la otra mitad de ${tirador.nombre}: no entra.'
          : taponado(taponador, tirador) ??
                (triple ? 'Falla el triple ${tirador.nombre}.' : 'Falla ${tirador.nombre}.'),
    );
    if (taponador != null && ofensivo) {
      texto.write(' La recupera ${reboteador.nombre}.');
    } else {
      texto.write(ofensivo ? ' Rebote ofensivo de ${reboteador.nombre}.' : ' Rebote de ${reboteador.nombre}.');
    }
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
      chicharra: chicharra,
      desdeLejos: desdeLejos,
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
      final presion = momentoClutch ? MotorPartido.clutch(tirador) * 0.03 - 0.02 : 0;
      if (_azar.nextDouble() < (tirador.stats.pctTl + presion).clamp(0.4, 0.95)) {
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
        lado.energia[j.id]! -
            segundos /
                60 *
                1.9 *
                aguante *
                (lado.ofensivo.fatiga + extra) *
                lado.defensivo.fatiga *
                lado.mods.fatigaFactor *
                (identical(lado, _l) ? _v : _l).mods.fatigaRivalFactor,
      );
      lado.box[j.id]!.seg += segundos;
    }
    final banco = lado.banco;
    if (banco != null) lado.energia[banco.id] = min(100, lado.energia[banco.id]! + segundos / 60 * 4);
  }

  void _cambiarPosesion() {
    _ataqueLocal = !_ataqueLocal;
    _restoPosesion = 24;
    _yaJugado = 0;
  }

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
    bool volcada = false,
    bool alleyOop = false,
    JugadaClave? jugadaClave,
    String? expulsadoId,
    TipoPerdida? perdida,
    TipoFalta? falta,
    int libres = 0,
    bool interferencia = false,
    bool chicharra = false,
    bool desdeLejos = false,
    String? participanteId,
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
      volcada: volcada,
      alleyOop: alleyOop,
      jugadaClave: jugadaClave,
      expulsadoId: expulsadoId,
      perdida: perdida,
      falta: falta,
      libres: libres,
      interferencia: interferencia,
      chicharra: chicharra,
      desdeLejos: desdeLejos,
      participanteId: participanteId,
    );
  }
}
