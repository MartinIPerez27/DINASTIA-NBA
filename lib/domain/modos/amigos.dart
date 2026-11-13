import 'dart:math';

import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/tactica.dart';
import '../entities/temporada.dart';
import '../motor.dart';
import '../playbook.dart';

/// Una persona de la partida entre amigos: su nombre, la franquicia con la que juega, su plantel
/// y su táctica.
class Participante {
  const Participante({
    required this.nombre,
    required this.franquiciaId,
    this.plantel = const Plantel(),
    this.tactica = const Tactica(),
    this.tacticaLista = false,
    this.sorteos = Participante.sorteosIniciales,
  });

  /// Veces que puede pedir otras cartas en su turno durante todo el draft.
  static const sorteosIniciales = 1;

  final String nombre;
  final String franquiciaId;
  final Plantel plantel;
  final Tactica tactica;
  final bool tacticaLista;
  final int sorteos;

  Participante copyWith({Plantel? plantel, Tactica? tactica, bool? tacticaLista, int? sorteos}) => Participante(
    nombre: nombre,
    franquiciaId: franquiciaId,
    plantel: plantel ?? this.plantel,
    tactica: tactica ?? this.tactica,
    tacticaLista: tacticaLista ?? this.tacticaLista,
    sorteos: sorteos ?? this.sorteos,
  );

  factory Participante.fromJson(Map<String, dynamic> j) => Participante(
    nombre: j['nombre'] as String,
    franquiciaId: j['franquicia'] as String,
    plantel: Plantel.fromJson(j['plantel'] as Map<String, dynamic>),
    tactica: Tactica.fromJson(j['tactica'] as Map<String, dynamic>),
    tacticaLista: j['tacticaLista'] as bool? ?? false,
    sorteos: j['sorteos'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'franquicia': franquiciaId,
    'plantel': plantel.toJson(),
    'tactica': tactica.toJson(),
    'tacticaLista': tacticaLista,
    'sorteos': sorteos,
  };
}

/// Un partido entre dos participantes (por índice). Sin jugar mientras [puntosLocal] es null.
class PartidoAmigos {
  const PartidoAmigos(this.local, this.visitante, {this.puntosLocal, this.puntosVisitante});

  final int local, visitante;
  final int? puntosLocal, puntosVisitante;

  bool get jugado => puntosLocal != null;
  int? get ganador => !jugado ? null : (puntosLocal! > puntosVisitante! ? local : visitante);

  PartidoAmigos conResultado(int pl, int pv) => PartidoAmigos(local, visitante, puntosLocal: pl, puntosVisitante: pv);

  factory PartidoAmigos.fromJson(List<dynamic> j) => PartidoAmigos(
    j[0] as int,
    j[1] as int,
    puntosLocal: j.length > 2 ? j[2] as int : null,
    puntosVisitante: j.length > 2 ? j[3] as int : null,
  );

  List<int> toJson() => [
    local,
    visitante,
    if (jugado) ...[puntosLocal!, puntosVisitante!],
  ];
}

/// Serie entre dos participantes: el duelo (al mejor de 7, localía 2-2-1-1-1) o la final del draft
/// en grupo (al mejor de 3, localía 1-1-1). [alto] es quien tiene la ventaja de localía.
class SerieAmigos {
  const SerieAmigos({required this.alto, required this.bajo, required this.victoriasParaGanar, this.juegos = const []});

  final int alto, bajo;
  final int victoriasParaGanar;
  final List<PartidoAmigos> juegos;

  int victoriasDe(int i) => juegos.where((j) => j.ganador == i).length;
  bool get terminada => victoriasDe(alto) >= victoriasParaGanar || victoriasDe(bajo) >= victoriasParaGanar;
  int? get ganador => !terminada ? null : (victoriasDe(alto) >= victoriasParaGanar ? alto : bajo);

  /// Quién es local en el próximo juego.
  int get localProximo {
    final n = juegos.length;
    final deAlto = victoriasParaGanar == 4 ? const {0, 1, 4, 6}.contains(n) : n.isEven;
    return deAlto ? alto : bajo;
  }

  PartidoAmigos get proximo {
    final local = localProximo;
    return PartidoAmigos(local, local == alto ? bajo : alto);
  }

  SerieAmigos conJuego(PartidoAmigos p) =>
      SerieAmigos(alto: alto, bajo: bajo, victoriasParaGanar: victoriasParaGanar, juegos: [...juegos, p]);

  factory SerieAmigos.fromJson(Map<String, dynamic> j) => SerieAmigos(
    alto: j['alto'] as int,
    bajo: j['bajo'] as int,
    victoriasParaGanar: j['aGanar'] as int,
    juegos: [for (final x in j['juegos'] as List) PartidoAmigos.fromJson(x as List)],
  );

  Map<String, dynamic> toJson() => {
    'alto': alto,
    'bajo': bajo,
    'aGanar': victoriasParaGanar,
    'juegos': [for (final p in juegos) p.toJson()],
  };
}

/// Fila de la tabla de la liga entre amigos.
class FilaAmigos {
  const FilaAmigos(this.indice, this.victorias, this.derrotas, this.diferencia);

  final int indice, victorias, derrotas, diferencia;
}

enum FaseAmigos { draft, tacticas, liga, serie, terminada }

/// Estado de una partida entre amigos (Draft en grupo o Duelo), guardado en [Temporada.datosModo].
class PartidaAmigos {
  const PartidaAmigos({
    required this.duelo,
    required this.participantes,
    required this.semilla,
    this.turno = 0,
    this.candidatos = const [],
    this.turnoVisto = false,
    this.liga = const [],
    this.serie,
  });

  /// Cartas que se ofrecen en cada turno del draft.
  static const cartasPorTurno = 4;

  final bool duelo;
  final List<Participante> participantes;
  final int semilla;

  /// Elección en curso del draft (0 … participantes × 6 − 1).
  final int turno;

  /// Ids de las cartas que se ofrecen en este turno (fijas: cerrar la app no regala otras).
  final List<String> candidatos;

  /// Si quien elige ya confirmó que tiene el dispositivo.
  final bool turnoVisto;

  /// Calendario de la liga (solo el draft en grupo): ida y vuelta entre todos.
  final List<PartidoAmigos> liga;

  /// El duelo, o la final del draft en grupo.
  final SerieAmigos? serie;

  int get cantidad => participantes.length;
  int get totalElecciones => cantidad * Posicion.values.length;

  /// Draft en serpiente: 1→N, N→1, 1→N…
  int quienElige(int turno) {
    final ronda = turno ~/ cantidad, k = turno % cantidad;
    return ronda.isEven ? k : cantidad - 1 - k;
  }

  int get eligeAhora => quienElige(turno);
  int get ronda => turno ~/ cantidad + 1;

  /// Primero sin táctica confirmada (null si ya están todos).
  int? get pendienteDeTactica {
    for (var i = 0; i < cantidad; i++) {
      if (!participantes[i].tacticaLista) return i;
    }
    return null;
  }

  FaseAmigos get fase {
    if (turno < totalElecciones) return FaseAmigos.draft;
    if (pendienteDeTactica != null) return FaseAmigos.tacticas;
    if (!duelo && liga.any((p) => !p.jugado)) return FaseAmigos.liga;
    if (serie == null || !serie!.terminada) return FaseAmigos.serie;
    return FaseAmigos.terminada;
  }

  int? get campeon => serie?.ganador;

  PartidaAmigos copyWith({
    List<Participante>? participantes,
    int? turno,
    List<String>? candidatos,
    bool? turnoVisto,
    List<PartidoAmigos>? liga,
    SerieAmigos? serie,
  }) => PartidaAmigos(
    duelo: duelo,
    participantes: participantes ?? this.participantes,
    semilla: semilla,
    turno: turno ?? this.turno,
    candidatos: candidatos ?? this.candidatos,
    turnoVisto: turnoVisto ?? this.turnoVisto,
    liga: liga ?? this.liga,
    serie: serie ?? this.serie,
  );

  /// Tabla de la liga: % de victorias, victorias, diferencia de puntos y, por último, el orden de
  /// inscripción.
  List<FilaAmigos> tabla() {
    final v = List.filled(cantidad, 0), d = List.filled(cantidad, 0), dif = List.filled(cantidad, 0);
    for (final p in liga.where((p) => p.jugado)) {
      final g = p.ganador!;
      v[g]++;
      d[g == p.local ? p.visitante : p.local]++;
      dif[p.local] += p.puntosLocal! - p.puntosVisitante!;
      dif[p.visitante] += p.puntosVisitante! - p.puntosLocal!;
    }
    final filas = [for (var i = 0; i < cantidad; i++) FilaAmigos(i, v[i], d[i], dif[i])];
    double pct(FilaAmigos f) => f.victorias + f.derrotas == 0 ? 0 : f.victorias / (f.victorias + f.derrotas);
    filas.sort((a, b) {
      for (final c in [
        pct(b).compareTo(pct(a)),
        b.victorias.compareTo(a.victorias),
        b.diferencia.compareTo(a.diferencia),
      ]) {
        if (c != 0) return c;
      }
      return a.indice.compareTo(b.indice);
    });
    return filas;
  }

  factory PartidaAmigos.fromJson(Map<String, dynamic> j) => PartidaAmigos(
    duelo: j['duelo'] as bool,
    participantes: [for (final x in j['participantes'] as List) Participante.fromJson(x as Map<String, dynamic>)],
    semilla: j['semilla'] as int,
    turno: j['turno'] as int? ?? 0,
    candidatos: (j['candidatos'] as List? ?? const []).cast<String>(),
    turnoVisto: j['turnoVisto'] as bool? ?? false,
    liga: [for (final x in j['liga'] as List? ?? const []) PartidoAmigos.fromJson(x as List)],
    serie: j['serie'] == null ? null : SerieAmigos.fromJson(j['serie'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'duelo': duelo,
    'participantes': [for (final p in participantes) p.toJson()],
    'semilla': semilla,
    'turno': turno,
    'candidatos': candidatos,
    'turnoVisto': turnoVisto,
    if (liga.isNotEmpty) 'liga': [for (final p in liga) p.toJson()],
    if (serie != null) 'serie': serie!.toJson(),
  };

  static PartidaAmigos? de(Temporada t) =>
      t.datosModo.isEmpty || !esModoDeAmigos(t.modoJuego) ? null : PartidaAmigos.fromJson(t.datosModo);

  static bool esModoDeAmigos(ModoJuego m) => m == ModoJuego.draftEnGrupo || m == ModoJuego.duelo;
}

/// Reglas de la partida entre amigos. Pura salvo el azar de los partidos simulados.
///
/// El draft es compartido y por turnos (en serpiente): en cada turno se ofrecen
/// [PartidaAmigos.cartasPorTurno] cartas que entran en algún puesto libre de quien elige, sin
/// personas repetidas entre todos los planteles. Las cartas de cada turno salen de una semilla, así
/// que quedan fijas aunque se cierre la app.
class Amigos {
  Amigos(this.catalogo, {Random? azar}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final Random _azar;

  late final Map<String, Jugador> _porId = {for (final j in catalogo) j.id: j};

  Jugador? jugador(String id) => _porId[id];

  /// Peso de cada rareza al sortear las cartas de un turno.
  static const _pesos = {Tier.sPlus: 1, Tier.s: 3, Tier.a: 6, Tier.b: 4};

  /// Partida nueva, con las cartas del primer turno ya sorteadas.
  PartidaAmigos nueva({
    required bool duelo,
    required List<(String nombre, String franquiciaId)> personas,
    int? semilla,
  }) {
    if (personas.length < 2 || personas.length > (duelo ? 2 : 8)) {
      throw ArgumentError('Cantidad de personas inválida: ${personas.length}');
    }
    if (personas.map((p) => p.$2).toSet().length != personas.length) {
      throw ArgumentError('Cada persona juega con una franquicia distinta.');
    }
    final p = PartidaAmigos(
      duelo: duelo,
      participantes: [for (final (n, f) in personas) Participante(nombre: n, franquiciaId: f)],
      semilla: semilla ?? _azar.nextInt(1 << 30),
    );
    return p.copyWith(candidatos: _sortear(p, 0));
  }

  Set<int> _tomados(PartidaAmigos p) => {
    for (final x in p.participantes)
      for (final j in x.plantel.jugadores) j.nbaPlayerId,
  };

  /// Sorteo del turno (con [extra] para "otras cartas"): determinista por semilla y turno.
  List<String> _sortear(PartidaAmigos p, int extra) {
    if (p.turno >= p.totalElecciones) return const [];
    final quien = p.participantes[p.eligeAhora];
    final tomados = _tomados(p);
    final azar = Random(p.semilla * 31 + p.turno * 7919 + extra);
    final pool = [
      for (final j in catalogo)
        if (!tomados.contains(j.nbaPlayerId) && quien.plantel.posicionesDisponiblesPara(j).isNotEmpty) j,
    ];
    final elegidas = <Jugador>[];
    while (elegidas.length < PartidaAmigos.cartasPorTurno && pool.isNotEmpty) {
      final total = pool.fold(0, (a, j) => a + _pesos[j.tier]!);
      var r = azar.nextInt(total);
      final j = pool.firstWhere((j) => (r -= _pesos[j.tier]!) < 0);
      elegidas.add(j);
      pool.removeWhere((x) => x.nbaPlayerId == j.nbaPlayerId);
    }
    elegidas.sort((a, b) => b.media.compareTo(a.media));
    return [for (final j in elegidas) j.id];
  }

  List<Jugador> candidatos(PartidaAmigos p) => [for (final id in p.candidatos) ?_porId[id]];

  /// Quien elige confirmó que tiene el dispositivo.
  PartidaAmigos verTurno(PartidaAmigos p) => p.copyWith(turnoVisto: true);

  /// Pide otras cartas en su turno (una vez por draft).
  PartidaAmigos otrasCartas(PartidaAmigos p) {
    final i = p.eligeAhora;
    final x = p.participantes[i];
    if (x.sorteos <= 0) throw StateError('${x.nombre} ya no puede pedir otras cartas.');
    final ps = [...p.participantes]..[i] = x.copyWith(sorteos: x.sorteos - 1);
    final nueva = p.copyWith(participantes: ps);
    return nueva.copyWith(candidatos: _sortear(nueva, 1000 + x.sorteos));
  }

  /// Quien tiene el turno ficha [j] en el puesto [pos]; pasa el turno.
  PartidaAmigos elegir(PartidaAmigos p, Jugador j, Posicion pos) {
    if (!p.candidatos.contains(j.id)) throw StateError('${j.nombre} no está entre las cartas del turno.');
    if (_tomados(p).contains(j.nbaPlayerId)) throw StateError('${j.nombre} ya está en otro plantel.');
    final i = p.eligeAhora;
    final x = p.participantes[i];
    final ps = [...p.participantes]..[i] = x.copyWith(plantel: x.plantel.asignar(j, pos));
    final siguiente = p.copyWith(participantes: ps, turno: p.turno + 1, turnoVisto: false, candidatos: const []);
    return siguiente.copyWith(candidatos: _sortear(siguiente, 0));
  }

  /// Táctica que sugiere el playbook para el plantel de [i].
  Tactica recomendada(PartidaAmigos p, int i) => recomendar(PerfilPlantel.de(p.participantes[i].plantel)).tactica;

  /// [i] confirma su táctica. Cuando están todas, arma la liga (grupo) o el duelo.
  PartidaAmigos confirmarTactica(PartidaAmigos p, int i, Tactica t) {
    final ps = [...p.participantes]..[i] = p.participantes[i].copyWith(tactica: t, tacticaLista: true);
    var nueva = p.copyWith(participantes: ps);
    if (nueva.pendienteDeTactica != null) return nueva;
    if (nueva.duelo) {
      // Localía al azar (fija por semilla) para el duelo.
      final alto = Random(nueva.semilla).nextInt(2);
      nueva = nueva.copyWith(
        serie: SerieAmigos(alto: alto, bajo: 1 - alto, victoriasParaGanar: 4),
      );
    } else {
      nueva = nueva.copyWith(liga: calendarioLiga(nueva.cantidad, Random(nueva.semilla)));
    }
    return nueva;
  }

  /// Ida y vuelta, todos contra todos, por fechas (método del círculo) y con las fechas de vuelta
  /// invirtiendo la localía.
  static List<PartidoAmigos> calendarioLiga(int n, Random azar) {
    final equipos = [for (var i = 0; i < n; i++) i]..shuffle(azar);
    if (equipos.length.isOdd) equipos.add(-1); // libre
    final m = equipos.length;
    final ida = <PartidoAmigos>[];
    for (var fecha = 0; fecha < m - 1; fecha++) {
      for (var k = 0; k < m ~/ 2; k++) {
        final a = equipos[k], b = equipos[m - 1 - k];
        if (a < 0 || b < 0) continue;
        ida.add((fecha + k).isEven ? PartidoAmigos(a, b) : PartidoAmigos(b, a));
      }
      equipos.insert(1, equipos.removeLast());
    }
    return [...ida, for (final p in ida) PartidoAmigos(p.visitante, p.local)];
  }

  /// Próximo partido por jugar: de la liga, o de la serie (duelo / final).
  PartidoAmigos? proximo(PartidaAmigos p) => switch (p.fase) {
    FaseAmigos.liga => p.liga.firstWhere((x) => !x.jugado),
    FaseAmigos.serie => p.serie?.proximo ?? _serieFinal(p).proximo,
    _ => null,
  };

  /// La final del grupo, entre los dos primeros de la tabla (al mejor de 3, localía del primero).
  SerieAmigos _serieFinal(PartidaAmigos p) {
    final t = p.tabla();
    return SerieAmigos(alto: t[0].indice, bajo: t[1].indice, victoriasParaGanar: 2);
  }

  /// Motor para un partido entre dos participantes. [usuarioLocal] decide quién maneja la jugada
  /// clave en vivo (el local); null para simular.
  MotorPartido motor(PartidaAmigos p, PartidoAmigos x, {bool? usuarioLocal, Random? azar}) {
    EquipoPartido equipo(int i) {
      final q = p.participantes[i];
      return EquipoPartido(identidadId: q.franquiciaId, plantel: q.plantel, tactica: q.tactica);
    }

    return MotorPartido(
      local: equipo(x.local),
      visitante: equipo(x.visitante),
      usuarioLocal: usuarioLocal,
      azar: azar ?? _azar,
    );
  }

  /// Anota el resultado del próximo partido.
  PartidaAmigos registrar(PartidaAmigos p, MotorPartido m) {
    final x = proximo(p);
    if (x == null) throw StateError('No hay partido pendiente.');
    final jugado = x.conResultado(m.puntosLocal, m.puntosVisitante);
    switch (p.fase) {
      case FaseAmigos.liga:
        final i = p.liga.indexWhere((y) => !y.jugado);
        final liga = [...p.liga]..[i] = jugado;
        final nueva = p.copyWith(liga: liga);
        // Terminada la liga, queda armada la final.
        return nueva.liga.every((y) => y.jugado) ? nueva.copyWith(serie: _serieFinal(nueva)) : nueva;
      case FaseAmigos.serie:
        return p.copyWith(serie: (p.serie ?? _serieFinal(p)).conJuego(jugado));
      default:
        throw StateError('No hay partido pendiente.');
    }
  }

  /// Simula el próximo partido al instante.
  PartidaAmigos simularProximo(PartidaAmigos p) {
    final x = proximo(p);
    if (x == null) return p;
    final m = motor(p, x)..simularTodo();
    return registrar(p, m);
  }

  /// Simula todo lo que queda de la fase actual (la liga entera, o la serie).
  PartidaAmigos simularFase(PartidaAmigos p) {
    final fase = p.fase;
    var x = p;
    while (x.fase == fase && proximo(x) != null) {
      x = simularProximo(x);
    }
    return x;
  }
}

extension TemporadaAmigos on Temporada {
  /// La misma partida con el estado de amigos actualizado.
  Temporada conAmigos(PartidaAmigos p) => copyWith(datosModo: p.toJson());
}
