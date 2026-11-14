import 'dart:math';

import '../entities/franquicia.dart';
import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/perfil.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/rol_cancha.dart';
import '../entities/tactica.dart';
import '../entities/temporada.dart';
import '../motor.dart';
import '../playbook.dart';
import '../progreso.dart';
import '../quimica.dart';
import 'amigos.dart';

// ─────────────────────────────────────────────────────────────────────────────────────────────
// Modos de armado: Tope salarial, Liga de 8 contra la IA (los dos terminan en una liga de 8),
// Desafíos de armado con el álbum y el minijuego Adiviná la carta.
// ─────────────────────────────────────────────────────────────────────────────────────────────

/// Los modos de armado que se juegan como partida guardada (los otros dos viven en el perfil).
bool esPartidaArmada(ModoJuego m) => m == ModoJuego.topeSalarial || m == ModoJuego.ligaIA;

/// Un equipo de la liga de 8: el tuyo (índice 0) o uno de la IA.
class EquipoArmado {
  const EquipoArmado({
    required this.nombre,
    required this.franquiciaId,
    this.plantel = const Plantel(),
    this.tactica = const Tactica(),
    this.estilo,
  });

  final String nombre;
  final String franquiciaId;
  final Plantel plantel;
  final Tactica tactica;

  /// Personalidad del mánager de la IA (null: el tuyo, o un equipo del tope salarial).
  final EstiloGM? estilo;

  EquipoArmado copyWith({Plantel? plantel, Tactica? tactica}) => EquipoArmado(
    nombre: nombre,
    franquiciaId: franquiciaId,
    plantel: plantel ?? this.plantel,
    tactica: tactica ?? this.tactica,
    estilo: estilo,
  );

  factory EquipoArmado.fromJson(Map<String, dynamic> j) => EquipoArmado(
    nombre: j['nombre'] as String,
    franquiciaId: j['franquicia'] as String,
    plantel: Plantel.fromJson(j['plantel'] as Map<String, dynamic>),
    tactica: Tactica.fromJson(j['tactica'] as Map<String, dynamic>),
    estilo: EstiloGM.values.asNameMap()[j['estilo']],
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'franquicia': franquiciaId,
    'plantel': plantel.toJson(),
    'tactica': tactica.toJson(),
    if (estilo != null) 'estilo': estilo!.name,
  };
}

/// Personalidades de los mánagers de la IA en la Liga de 8: cada uno valora distinto las cartas.
enum EstiloGM {
  triples('El que ama los triples', 'Tiradores y espacio: si no tira de tres, no le interesa.'),
  defensivo('El defensivo', 'Robos, tapas y cerrojos. Los partidos feos le encantan.'),
  leyendas('El coleccionista de leyendas', 'Va siempre por la carta más rara.'),
  quimica('El de la química', 'Busca compañeros de equipo y de época.'),
  joven('El joven', 'Solo mira el básquet de los últimos años.'),
  nostalgico('El nostálgico', 'Para él, el básquet de verdad se jugaba antes.'),
  numeros('El de los números', 'Puntos, rebotes y asistencias: el que más llena la planilla.');

  const EstiloGM(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Cuánto vale [j] para un mánager con este estilo, dado lo que ya tiene en [plantel].
double valorParaEstilo(EstiloGM e, Jugador j, Plantel plantel) {
  final s = j.stats;
  final base = j.media.toDouble();
  return base +
      switch (e) {
        EstiloGM.triples =>
          (s.pctT3 > 0.33 ? 40 * (s.pctT3 - 0.33) + 3 : -4) +
              (const {
                    RolCancha.tiradorPantallas,
                    RolCancha.especialista3D,
                    RolCancha.anotadorExterior,
                    RolCancha.alaPivotTirador,
                    RolCancha.pivotTirador,
                  }.contains(j.rol)
                  ? 5
                  : 0),
        EstiloGM.defensivo =>
          4 * (s.robP + s.tapP) +
              (const {
                    RolCancha.baseDefensivo,
                    RolCancha.cerrojoDefensivo,
                    RolCancha.protectorAro,
                    RolCancha.especialista3D,
                  }.contains(j.rol)
                  ? 5
                  : 0),
        EstiloGM.leyendas => switch (j.tier) {
          Tier.sPlus => 10.0,
          Tier.s => 6.0,
          Tier.a => 1.0,
          Tier.b => 0.0,
        },
        EstiloGM.quimica =>
          (Quimica.de([...plantel.jugadores, j]).puntaje - Quimica.de(plantel.jugadores).puntaje) * 0.25,
        EstiloGM.joven => j.epoca.index * 1.2 - 5,
        EstiloGM.nostalgico => (Epoca.values.length - 1 - j.epoca.index) * 1.2 - 5,
        EstiloGM.numeros => (s.ppp + s.rpp + s.app) / 5 - 4,
      };
}

// ───────────────────────────────────── Tope salarial ─────────────────────────────────────────

/// Precio de una carta en el tope salarial: S+ $5, S $4, A alta (85+) $3, A $2, B $1.
int precioTope(Jugador j) => switch (j.tier) {
  Tier.sPlus => 5,
  Tier.s => 4,
  Tier.a => j.media >= 85 ? 3 : 2,
  Tier.b => 1,
};

/// Presupuesto según la dificultad: cuanto más difícil, menos plata para estrellas.
int presupuestoTope(Dificultad d) => switch (d) {
  Dificultad.normal => 15,
  Dificultad.dificil => 14,
  Dificultad.leyenda => 13,
};

/// El tablero del tope salarial: 25 cartas en 5 filas de precio ($5 arriba, $1 abajo) y 5 columnas
/// por puesto (base, escolta, alero, ala-pívot, pívot), más lo que compraste.
class EstadoTope {
  const EstadoTope({required this.presupuesto, required this.tablero, this.compra = const {}});

  static const filas = [5, 4, 3, 2, 1];

  final int presupuesto;

  /// 25 ids, fila por fila (precio de mayor a menor) y columna por puesto titular.
  final List<String> tablero;

  /// Lo comprado: puesto → id de carta.
  final Map<Posicion, String> compra;

  bool get completo => compra.length == Posicion.values.length;

  EstadoTope conCompra(Map<Posicion, String> c) => EstadoTope(presupuesto: presupuesto, tablero: tablero, compra: c);

  factory EstadoTope.fromJson(Map<String, dynamic> j) => EstadoTope(
    presupuesto: j['presupuesto'] as int,
    tablero: (j['tablero'] as List).cast<String>(),
    compra: {
      for (final e in (j['compra'] as Map<String, dynamic>? ?? {}).entries)
        Posicion.values.byName(e.key): e.value as String,
    },
  );

  Map<String, dynamic> toJson() => {
    'presupuesto': presupuesto,
    'tablero': tablero,
    if (compra.isNotEmpty) 'compra': {for (final e in compra.entries) e.key.name: e.value},
  };
}

// ───────────────────────────────── Liga de 8 contra la IA ────────────────────────────────────

/// Draft en serpiente de la Liga de 8: un pozo de cartas a la vista para todos.
class EstadoDraftIA {
  const EstadoDraftIA({required this.pozo, required this.orden, this.turno = 0, this.ultimas = const []});

  /// Elecciones de todo el draft: 8 equipos × 6 puestos.
  static const totalElecciones = 48;

  /// Ids del pozo (las que quedan sin elegir).
  final List<String> pozo;

  /// Orden de la primera ronda (índices de equipo); después va y vuelve.
  final List<int> orden;
  final int turno;

  /// Últimas elecciones (equipo, id), para el relato del draft.
  final List<(int, String)> ultimas;

  int quienElige(int turno) {
    final ronda = turno ~/ orden.length, k = turno % orden.length;
    return orden[ronda.isEven ? k : orden.length - 1 - k];
  }

  bool get terminado => turno >= totalElecciones;
  int get eligeAhora => quienElige(turno);
  int get ronda => turno ~/ orden.length + 1;

  EstadoDraftIA copyWith({List<String>? pozo, int? turno, List<(int, String)>? ultimas}) => EstadoDraftIA(
    pozo: pozo ?? this.pozo,
    orden: orden,
    turno: turno ?? this.turno,
    ultimas: ultimas ?? this.ultimas,
  );

  factory EstadoDraftIA.fromJson(Map<String, dynamic> j) => EstadoDraftIA(
    pozo: (j['pozo'] as List).cast<String>(),
    orden: (j['orden'] as List).cast<int>(),
    turno: j['turno'] as int? ?? 0,
    ultimas: [for (final x in j['ultimas'] as List? ?? const []) ((x as List)[0] as int, x[1] as String)],
  );

  Map<String, dynamic> toJson() => {
    'pozo': pozo,
    'orden': orden,
    'turno': turno,
    if (ultimas.isNotEmpty)
      'ultimas': [
        for (final (e, id) in ultimas) [e, id],
      ],
  };
}

// ───────────────────────────────────── La partida ────────────────────────────────────────────

enum FaseArmada { armado, liga, semis, finalLiga, terminada }

/// Estado de una partida de Tope salarial o Liga de 8 contra la IA ([Temporada.datosModo]).
/// Los dos terminan igual: liga de 8 a dos ruedas (14 partidos por equipo) y playoffs de 4 al
/// mejor de 3. El equipo del usuario es siempre el índice 0.
class PartidaArmada {
  const PartidaArmada({
    required this.semilla,
    required this.equipos,
    this.tope,
    this.draft,
    this.partidos = const [],
    this.semis = const [],
    this.finalSerie,
  });

  static const usuario = 0;

  final int semilla;
  final List<EquipoArmado> equipos;
  final EstadoTope? tope;
  final EstadoDraftIA? draft;

  /// Liga: ida y vuelta entre los 8, en orden de fechas.
  final List<PartidoAmigos> partidos;

  /// Semifinales (1.º vs 4.º, 2.º vs 3.º) y final, al mejor de 3.
  final List<SerieAmigos> semis;
  final SerieAmigos? finalSerie;

  FaseArmada get fase {
    if (partidos.isEmpty) return FaseArmada.armado;
    if (partidos.any((p) => !p.jugado)) return FaseArmada.liga;
    if (semis.any((s) => !s.terminada)) return FaseArmada.semis;
    if (finalSerie == null || !finalSerie!.terminada) return FaseArmada.finalLiga;
    return FaseArmada.terminada;
  }

  int? get campeon => finalSerie?.ganador;

  /// Partidos del usuario ganados y perdidos en total (liga y playoffs).
  (int, int) get recordUsuario {
    var v = 0, d = 0;
    for (final p in [...partidos, for (final s in semis) ...s.juegos, ...?finalSerie?.juegos]) {
      if (!p.jugado || (p.local != usuario && p.visitante != usuario)) continue;
      p.ganador == usuario ? v++ : d++;
    }
    return (v, d);
  }

  /// Tabla de la liga: % de victorias, victorias y diferencia de puntos.
  List<FilaAmigos> tabla() {
    final n = equipos.length;
    final v = List.filled(n, 0), d = List.filled(n, 0), dif = List.filled(n, 0);
    for (final p in partidos.where((p) => p.jugado)) {
      final g = p.ganador!;
      v[g]++;
      d[g == p.local ? p.visitante : p.local]++;
      dif[p.local] += p.puntosLocal! - p.puntosVisitante!;
      dif[p.visitante] += p.puntosVisitante! - p.puntosLocal!;
    }
    final filas = [for (var i = 0; i < n; i++) FilaAmigos(i, v[i], d[i], dif[i])];
    filas.sort((a, b) {
      for (final c in [b.victorias.compareTo(a.victorias), b.diferencia.compareTo(a.diferencia)]) {
        if (c != 0) return c;
      }
      return a.indice.compareTo(b.indice);
    });
    return filas;
  }

  PartidaArmada copyWith({
    List<EquipoArmado>? equipos,
    EstadoTope? tope,
    EstadoDraftIA? draft,
    List<PartidoAmigos>? partidos,
    List<SerieAmigos>? semis,
    SerieAmigos? finalSerie,
  }) => PartidaArmada(
    semilla: semilla,
    equipos: equipos ?? this.equipos,
    tope: tope ?? this.tope,
    draft: draft ?? this.draft,
    partidos: partidos ?? this.partidos,
    semis: semis ?? this.semis,
    finalSerie: finalSerie ?? this.finalSerie,
  );

  factory PartidaArmada.fromJson(Map<String, dynamic> j) => PartidaArmada(
    semilla: j['semilla'] as int,
    equipos: [for (final x in j['equipos'] as List) EquipoArmado.fromJson(x as Map<String, dynamic>)],
    tope: j['tope'] == null ? null : EstadoTope.fromJson(j['tope'] as Map<String, dynamic>),
    draft: j['draft'] == null ? null : EstadoDraftIA.fromJson(j['draft'] as Map<String, dynamic>),
    partidos: [for (final x in j['partidos'] as List? ?? const []) PartidoAmigos.fromJson(x as List)],
    semis: [for (final x in j['semis'] as List? ?? const []) SerieAmigos.fromJson(x as Map<String, dynamic>)],
    finalSerie: j['final'] == null ? null : SerieAmigos.fromJson(j['final'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'semilla': semilla,
    'equipos': [for (final e in equipos) e.toJson()],
    if (tope != null) 'tope': tope!.toJson(),
    if (draft != null) 'draft': draft!.toJson(),
    if (partidos.isNotEmpty) 'partidos': [for (final p in partidos) p.toJson()],
    if (semis.isNotEmpty) 'semis': [for (final s in semis) s.toJson()],
    if (finalSerie != null) 'final': finalSerie!.toJson(),
  };

  static PartidaArmada? de(Temporada t) =>
      t.datosModo.isEmpty || !esPartidaArmada(t.modoJuego) ? null : PartidaArmada.fromJson(t.datosModo);
}

extension TemporadaArmada on Temporada {
  Temporada conArmada(PartidaArmada p) => copyWith(datosModo: p.toJson());
}

/// Reglas de Tope salarial y Liga de 8 contra la IA. Puro salvo el azar de los partidos simulados.
class ModosArmado {
  ModosArmado(this.catalogo, {Random? azar}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final Random _azar;

  late final Map<String, Jugador> _porId = {for (final j in catalogo) j.id: j};

  Jugador? jugador(String id) => _porId[id];

  // ─── Equipos de la IA ───

  /// Nombres y franquicias de los 7 rivales (distintas de la tuya), fijos por semilla.
  List<String> _franquiciasRivales(int semilla, String propia, List<String> franquicias) =>
      ([...franquicias.where((f) => f != propia)]..shuffle(Random(semilla))).take(7).toList();

  // ─── Tope salarial ───

  /// Partida nueva de tope salarial: tu tablero y 7 rivales que arman con su propio tablero y el
  /// mismo presupuesto.
  PartidaArmada nuevoTope({
    required int semilla,
    required Dificultad dificultad,
    required String franquiciaUsuario,
    required List<String> franquicias,
    required String Function(String franquiciaId) nombreDe,
  }) {
    final presupuesto = presupuestoTope(dificultad);
    final rivales = _franquiciasRivales(semilla, franquiciaUsuario, franquicias);
    final usados = <int>{};
    final propio = tablero(semilla, excluir: usados);
    for (final id in propio) {
      usados.add(_porId[id]!.nbaPlayerId);
    }
    final equipos = [EquipoArmado(nombre: nombreDe(franquiciaUsuario), franquiciaId: franquiciaUsuario)];
    for (var k = 0; k < rivales.length; k++) {
      final suyo = tablero(semilla + 101 * (k + 1), excluir: usados);
      final plantel = mejorPlantelTope(suyo, presupuesto)!;
      for (final j in plantel.jugadores) {
        usados.add(j.nbaPlayerId);
      }
      equipos.add(
        EquipoArmado(
          nombre: nombreDe(rivales[k]),
          franquiciaId: rivales[k],
          plantel: plantel,
          tactica: recomendar(PerfilPlantel.de(plantel)).tactica,
        ),
      );
    }
    return PartidaArmada(
      semilla: semilla,
      equipos: equipos,
      tope: EstadoTope(presupuesto: presupuesto, tablero: propio),
    );
  }

  /// Un tablero de 25 cartas (5 precios × 5 puestos), sin personas repetidas ni de [excluir].
  /// La fila de $1 tiene un jugador por puesto: siempre se puede armar un plantel completo.
  List<String> tablero(int semilla, {Set<int> excluir = const {}}) {
    final azar = Random(semilla);
    final usados = {...excluir};
    final ids = <String>[];
    for (final precio in EstadoTope.filas) {
      for (final pos in Posicion.titulares) {
        bool sirve(Jugador j) => precioTope(j) == precio && !usados.contains(j.nbaPlayerId);
        var pool = [
          for (final j in catalogo)
            if (sirve(j) && j.posiciones.first == pos) j,
        ];
        if (pool.isEmpty) {
          pool = [
            for (final j in catalogo)
              if (sirve(j) && j.puedeJugarEn(pos)) j,
          ];
        }
        final j = pool[azar.nextInt(pool.length)];
        usados.add(j.nbaPlayerId);
        ids.add(j.id);
      }
    }
    return ids;
  }

  /// Precio total de lo comprado.
  int gastado(EstadoTope e) => e.compra.values.fold(0, (a, id) => a + precioTope(_porId[id]!));

  int restante(EstadoTope e) => e.presupuesto - gastado(e);

  /// Plantel con lo comprado.
  Plantel plantelTope(EstadoTope e) {
    var p = const Plantel();
    for (final x in e.compra.entries) {
      p = p.asignar(_porId[x.value]!, x.key);
    }
    return p;
  }

  /// ¿Se puede comprar [j] para [pos]? Devuelve el motivo si no.
  String? motivoNoCompra(EstadoTope e, Jugador j, Posicion pos) {
    if (!e.tablero.contains(j.id)) return 'No está en tu tablero.';
    if (e.compra.containsValue(j.id)) return 'Ya lo compraste.';
    if (e.compra.containsKey(pos)) return '${pos.etiqueta} ya está ocupado.';
    if (!j.puedeJugarEn(pos)) return '${j.nombre} no juega de ${pos.etiqueta.toLowerCase()}.';
    final faltan = Posicion.values.length - e.compra.length - 1;
    // Siempre tiene que quedar al menos $1 por cada puesto que falta.
    if (precioTope(j) + faltan > restante(e)) return 'No te alcanza: te quedan \$${restante(e)}.';
    return null;
  }

  EstadoTope comprar(EstadoTope e, Jugador j, Posicion pos) {
    final motivo = motivoNoCompra(e, j, pos);
    if (motivo != null) throw StateError(motivo);
    return e.conCompra({...e.compra, pos: j.id});
  }

  EstadoTope vender(EstadoTope e, Posicion pos) => e.conCompra({...e.compra}..remove(pos));

  /// El mejor plantel posible de un tablero con [presupuesto] (lo que arma la IA): un titular por
  /// columna y el Sexto Hombre entre el resto, maximizando la suma de medias.
  Plantel? mejorPlantelTope(List<String> tablero, int presupuesto) {
    final js = [for (final id in tablero) _porId[id]!];
    Jugador celda(int fila, int col) => js[fila * 5 + col];
    var mejor = -1;
    List<Jugador>? elegido;
    final precioMinimoSexto = js.map(precioTope).reduce(min);
    void buscar(int col, List<Jugador> tit, int costo, int suma) {
      if (costo + (5 - col) + precioMinimoSexto > presupuesto) return;
      if (col == 5) {
        for (final s in js) {
          if (tit.contains(s)) continue;
          final c = costo + precioTope(s);
          if (c > presupuesto) continue;
          final total = suma + s.media;
          if (total > mejor) {
            mejor = total;
            elegido = [...tit, s];
          }
        }
        return;
      }
      for (var f = 0; f < 5; f++) {
        final j = celda(f, col);
        buscar(col + 1, [...tit, j], costo + precioTope(j), suma + j.media);
      }
    }

    buscar(0, const [], 0, 0);
    if (elegido == null) return null;
    var p = const Plantel();
    for (var k = 0; k < 5; k++) {
      p = p.asignar(elegido![k], Posicion.titulares[k]);
    }
    return p.asignar(elegido![5], Posicion.sextoHombre);
  }

  /// Confirma el plantel comprado y arma la liga.
  PartidaArmada confirmarTope(PartidaArmada p) {
    final e = p.tope!;
    if (!e.completo) throw StateError('Faltan puestos por comprar.');
    final plantel = plantelTope(e);
    final equipos = [...p.equipos]
      ..[0] = p.equipos[0].copyWith(plantel: plantel, tactica: recomendar(PerfilPlantel.de(plantel)).tactica);
    return _conLiga(p.copyWith(equipos: equipos));
  }

  // ─── Liga de 8 contra la IA ───

  static const _pesos = {Tier.sPlus: 1, Tier.s: 3, Tier.a: 6, Tier.b: 4};

  /// Partida nueva de Liga de 8: pozo de 72 cartas a la vista y 7 mánagers con estilo.
  PartidaArmada nuevaLigaIA({
    required int semilla,
    required String franquiciaUsuario,
    required List<String> franquicias,
    required String Function(String franquiciaId) nombreDe,
  }) {
    final azar = Random(semilla);
    final rivales = _franquiciasRivales(semilla, franquiciaUsuario, franquicias);
    final estilos = [...EstiloGM.values]..shuffle(azar);
    final equipos = [
      EquipoArmado(nombre: nombreDe(franquiciaUsuario), franquiciaId: franquiciaUsuario),
      for (var k = 0; k < 7; k++)
        EquipoArmado(nombre: nombreDe(rivales[k]), franquiciaId: rivales[k], estilo: estilos[k]),
    ];
    final orden = [for (var i = 0; i < 8; i++) i]..shuffle(azar);
    return PartidaArmada(
      semilla: semilla,
      equipos: equipos,
      draft: EstadoDraftIA(pozo: pozo(semilla), orden: orden),
    );
  }

  /// Pozo del draft: 13 por puesto (según su puesto principal) y 7 libres, por rareza ponderada.
  List<String> pozo(int semilla) {
    final azar = Random(semilla * 7 + 3);
    final personas = <int>{};
    final ids = <String>[];
    Jugador sortear(List<Jugador> pool) {
      final total = pool.fold(0, (a, j) => a + _pesos[j.tier]!);
      var r = azar.nextInt(total);
      return pool.firstWhere((j) => (r -= _pesos[j.tier]!) < 0);
    }

    for (final pos in [for (final p in Posicion.titulares) ...List.filled(13, p), ...List.filled(7, null)]) {
      final pool = [
        for (final j in catalogo)
          if (!personas.contains(j.nbaPlayerId) && (pos == null || j.posiciones.first == pos)) j,
      ];
      final j = sortear(pool);
      personas.add(j.nbaPlayerId);
      ids.add(j.id);
    }
    return ids;
  }

  List<Jugador> cartasDelPozo(PartidaArmada p) => [for (final id in p.draft!.pozo) ?_porId[id]];

  /// Cartas del pozo que le sirven al equipo [i] (entran en algún puesto libre).
  List<Jugador> elegibles(PartidaArmada p, int i) => [
    for (final j in cartasDelPozo(p))
      if (p.equipos[i].plantel.posicionesDisponiblesPara(j).isNotEmpty) j,
  ];

  /// Puesto donde conviene poner [j]: el titular libre con menos opciones en el pozo; si no, el
  /// Sexto Hombre.
  Posicion puestoPara(PartidaArmada p, int i, Jugador j) {
    final libres = p.equipos[i].plantel.posicionesDisponiblesPara(j);
    final titulares = libres.where((x) => x != Posicion.sextoHombre).toList();
    if (titulares.isEmpty) return libres.first;
    final pozo = cartasDelPozo(p);
    titulares.sort(
      (a, b) => pozo.where((x) => x.puedeJugarEn(a)).length.compareTo(pozo.where((x) => x.puedeJugarEn(b)).length),
    );
    return titulares.first;
  }

  PartidaArmada _fichar(PartidaArmada p, int i, Jugador j, Posicion pos) {
    final d = p.draft!;
    final equipos = [...p.equipos]..[i] = p.equipos[i].copyWith(plantel: p.equipos[i].plantel.asignar(j, pos));
    final ultimas = [...d.ultimas, (i, j.id)];
    return p.copyWith(
      equipos: equipos,
      draft: d.copyWith(
        pozo: [...d.pozo]..remove(j.id),
        turno: d.turno + 1,
        ultimas: ultimas.length > 8 ? ultimas.sublist(ultimas.length - 8) : ultimas,
      ),
    );
  }

  /// El usuario elige [j] para [pos] en su turno; después eligen los mánagers hasta su próximo turno.
  PartidaArmada elegir(PartidaArmada p, Jugador j, Posicion pos) {
    final d = p.draft!;
    if (d.terminado || d.eligeAhora != PartidaArmada.usuario) throw StateError('No es tu turno.');
    if (!d.pozo.contains(j.id)) throw StateError('${j.nombre} ya no está en el pozo.');
    return avanzarIA(_fichar(p, PartidaArmada.usuario, j, pos));
  }

  /// Los mánagers de la IA eligen hasta que le toca al usuario (o termina el draft, y arranca la liga).
  PartidaArmada avanzarIA(PartidaArmada p) {
    var x = p;
    while (!x.draft!.terminado && x.draft!.eligeAhora != PartidaArmada.usuario) {
      final i = x.draft!.eligeAhora;
      final (j, pos) = eleccionIA(x, i);
      x = _fichar(x, i, j, pos);
    }
    if (x.draft!.terminado && x.partidos.isEmpty) {
      final equipos = [for (final e in x.equipos) e.copyWith(tactica: recomendar(PerfilPlantel.de(e.plantel)).tactica)];
      x = _conLiga(x.copyWith(equipos: equipos));
    }
    return x;
  }

  /// Qué elige el mánager [i] según su estilo (determinista por semilla y turno). Si en el pozo no
  /// queda nadie para sus puestos libres, ficha al mejor libre del catálogo (nunca se traba).
  (Jugador, Posicion) eleccionIA(PartidaArmada p, int i) {
    final e = p.equipos[i];
    final estilo = e.estilo ?? EstiloGM.numeros;
    final azar = Random(p.semilla * 131 + p.draft!.turno);
    var opciones = elegibles(p, i);
    if (opciones.isEmpty) {
      final tomados = {
        for (final x in p.equipos)
          for (final j in x.plantel.jugadores) j.nbaPlayerId,
        for (final j in cartasDelPozo(p)) j.nbaPlayerId,
      };
      opciones = [
        for (final j in catalogo)
          if (!tomados.contains(j.nbaPlayerId) && e.plantel.posicionesDisponiblesPara(j).isNotEmpty) j,
      ]..sort((a, b) => b.media.compareTo(a.media));
      opciones = opciones.take(10).toList();
    }
    // Primero los titulares: con el Sexto Hombre libre al final, no se gasta el pick en él antes.
    final faltanTitulares = Posicion.titulares.where((x) => !e.plantel.estaOcupada(x)).toList();
    double puntaje(Jugador j) {
      final libres = e.plantel.posicionesDisponiblesPara(j);
      final cubreTitular = libres.any(faltanTitulares.contains);
      return valorParaEstilo(estilo, j, e.plantel) + (cubreTitular ? 3 : 0) + azar.nextDouble() * 2;
    }

    final puntajes = {for (final j in opciones) j.id: puntaje(j)};
    opciones.sort((a, b) => puntajes[b.id]!.compareTo(puntajes[a.id]!));
    final j = opciones.first;
    if (p.draft!.pozo.contains(j.id)) return (j, puestoPara(p, i, j));
    // Fichado de afuera del pozo: igual entra al plantel (y se saca del pozo nada).
    return (j, e.plantel.posicionesDisponiblesPara(j).first);
  }

  // ─── La liga de 8 y sus playoffs ───

  PartidaArmada _conLiga(PartidaArmada p) => p.copyWith(partidos: Amigos.calendarioLiga(8, Random(p.semilla + 17)));

  /// Próximo partido a jugarse (de cualquiera), o null si terminó.
  (PartidoAmigos, int)? _proximo(PartidaArmada p) {
    switch (p.fase) {
      case FaseArmada.liga:
        final i = p.partidos.indexWhere((x) => !x.jugado);
        return (p.partidos[i], i);
      case FaseArmada.semis:
        // Alterna las dos semis juego a juego.
        final abiertas = [
          for (var k = 0; k < p.semis.length; k++)
            if (!p.semis[k].terminada) k,
        ];
        abiertas.sort((a, b) => p.semis[a].juegos.length.compareTo(p.semis[b].juegos.length));
        return (p.semis[abiertas.first].proximo, abiertas.first);
      case FaseArmada.finalLiga:
        return (p.finalSerie!.proximo, 0);
      default:
        return null;
    }
  }

  bool _delUsuario(PartidoAmigos x) => x.local == PartidaArmada.usuario || x.visitante == PartidaArmada.usuario;

  /// El próximo partido del usuario (si sigue en carrera).
  PartidoAmigos? proximoDelUsuario(PartidaArmada p) {
    switch (p.fase) {
      case FaseArmada.liga:
        return p.partidos.where((x) => !x.jugado && _delUsuario(x)).firstOrNull;
      case FaseArmada.semis:
        final s = p.semis.where((s) => !s.terminada && (s.alto == 0 || s.bajo == 0)).firstOrNull;
        return s?.proximo;
      case FaseArmada.finalLiga:
        final f = p.finalSerie!;
        return f.alto == 0 || f.bajo == 0 ? f.proximo : null;
      default:
        return null;
    }
  }

  MotorPartido motor(PartidaArmada p, PartidoAmigos x, {bool? usuarioLocal, Random? azar}) {
    EquipoPartido equipo(int i) {
      final e = p.equipos[i];
      return EquipoPartido(identidadId: e.franquiciaId, plantel: e.plantel, tactica: e.tactica);
    }

    return MotorPartido(
      local: equipo(x.local),
      visitante: equipo(x.visitante),
      usuarioLocal: usuarioLocal,
      azar: azar ?? _azar,
    );
  }

  /// Anota el resultado del próximo partido (que tiene que ser [m]).
  PartidaArmada registrar(PartidaArmada p, MotorPartido m) {
    final (x, k) = _proximo(p)!;
    final jugado = x.conResultado(m.puntosLocal, m.puntosVisitante);
    switch (p.fase) {
      case FaseArmada.liga:
        final partidos = [...p.partidos]..[k] = jugado;
        final nueva = p.copyWith(partidos: partidos);
        if (nueva.partidos.any((y) => !y.jugado)) return nueva;
        final t = nueva.tabla();
        return nueva.copyWith(
          semis: [
            SerieAmigos(alto: t[0].indice, bajo: t[3].indice, victoriasParaGanar: 2),
            SerieAmigos(alto: t[1].indice, bajo: t[2].indice, victoriasParaGanar: 2),
          ],
        );
      case FaseArmada.semis:
        final semis = [...p.semis]..[k] = p.semis[k].conJuego(jugado);
        final nueva = p.copyWith(semis: semis);
        if (semis.any((s) => !s.terminada)) return nueva;
        // Final: localía para el mejor ubicado en la tabla.
        final orden = [for (final f in nueva.tabla()) f.indice];
        final a = semis[0].ganador!, b = semis[1].ganador!;
        final (alto, bajo) = orden.indexOf(a) < orden.indexOf(b) ? (a, b) : (b, a);
        return nueva.copyWith(
          finalSerie: SerieAmigos(alto: alto, bajo: bajo, victoriasParaGanar: 2),
        );
      case FaseArmada.finalLiga:
        return p.copyWith(finalSerie: p.finalSerie!.conJuego(jugado));
      default:
        throw StateError('No hay partido pendiente.');
    }
  }

  PartidaArmada _simularUno(PartidaArmada p) {
    final (x, _) = _proximo(p)!;
    return registrar(p, motor(p, x)..simularTodo());
  }

  /// Simula los partidos ajenos hasta que el próximo sea del usuario (o, si quedó afuera, todo).
  PartidaArmada simularAjenos(PartidaArmada p) {
    var x = p;
    while (true) {
      final siguiente = _proximo(x);
      if (siguiente == null || _delUsuario(siguiente.$1)) return x;
      x = _simularUno(x);
    }
  }

  /// Simula el próximo partido del usuario (con los ajenos de antes).
  PartidaArmada simularProximoDelUsuario(PartidaArmada p) {
    var x = simularAjenos(p);
    if (_proximo(x) != null) x = _simularUno(x);
    return simularAjenos(x);
  }

  /// Simula lo que falta de la fase actual (la liga, las semis o la final).
  PartidaArmada simularFase(PartidaArmada p) {
    final fase = p.fase;
    var x = p;
    while (x.fase == fase && _proximo(x) != null) {
      x = _simularUno(x);
    }
    return x;
  }

  /// Simula todo hasta el final.
  PartidaArmada simularTodo(PartidaArmada p) {
    var x = p;
    while (_proximo(x) != null) {
      x = _simularUno(x);
    }
    return x;
  }
}

/// Metajuego de Tope salarial y Liga de 8: XP y monedas por partido; título → logro y trofeo de
/// monedas. No toca récords ni anillos de la temporada.
(PerfilEntrenador, List<Novedad>) premiarArmado(PerfilEntrenador perfil, Temporada antes, Temporada despues) {
  final a = PartidaArmada.de(antes), d = PartidaArmada.de(despues);
  if (d == null) return (perfil, const []);
  final (va, pa) = a?.recordUsuario ?? (0, 0);
  final (vd, pd) = d.recordUsuario;
  final ganados = vd - va, perdidos = pd - pa;
  var p = perfil;
  final novedades = <Novedad>[];
  final mult = switch (despues.dificultad) {
    Dificultad.normal => 1.0,
    Dificultad.dificil => 1.25,
    Dificultad.leyenda => 1.5,
  };
  if (ganados + perdidos > 0) {
    final xp = ((ganados * 30 + perdidos * 10) * mult).round();
    final monedas = ganados * 10 + perdidos * 3;
    p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
    novedades.add(Novedad('+$xp XP · +$monedas monedas'));
  }
  final campeonAhora = d.campeon == PartidaArmada.usuario && a?.campeon != PartidaArmada.usuario;
  if (campeonAhora) {
    p = p.copyWith(xp: p.xp + (300 * mult).round(), monedas: p.monedas + 120);
    novedades.add(
      Novedad('¡Campeón de la ${despues.modoJuego.nombre}!', detalle: '+${(300 * mult).round()} XP', destacada: true),
    );
    final logro = despues.modoJuego == ModoJuego.topeSalarial ? Logro.topeSalarial : Logro.ligaIA;
    if (!p.logros.containsKey(logro)) {
      p = p.copyWith(
        logros: {...p.logros, logro: DateTime.now().millisecondsSinceEpoch},
        xp: p.xp + 100,
        monedas: p.monedas + 50,
      );
      novedades.add(Novedad('Logro: ${logro.nombre}', detalle: logro.descripcion, destacada: true));
    }
  }
  return (p, novedades);
}

// ───────────────────────────────── Desafíos de armado ────────────────────────────────────────

/// Una condición de un desafío de armado, que se evalúa sobre el plantel (parcial o completo).
sealed class Condicion {
  const Condicion();

  String get texto;

  /// ¿La cumple este plantel? [conferenciaDe] da la conferencia de una franquicia (null si no tiene).
  bool cumple(List<Jugador> js, Conferencia? Function(String franquiciaId) conferenciaDe);
}

class QuimicaMinima extends Condicion {
  const QuimicaMinima(this.minimo);
  final int minimo;
  @override
  String get texto => 'Química $minimo o más';
  @override
  bool cumple(List<Jugador> js, _) => Quimica.de(js).puntaje >= minimo;
}

class DecadasDistintas extends Condicion {
  const DecadasDistintas(this.minimo, {this.maximo});
  final int minimo;
  final int? maximo;
  @override
  String get texto =>
      maximo == minimo ? 'Exactamente $minimo década${minimo == 1 ? '' : 's'}' : 'Al menos $minimo décadas distintas';
  @override
  bool cumple(List<Jugador> js, _) {
    final n = js.map((j) => j.epoca).toSet().length;
    return n >= minimo && (maximo == null || n <= maximo!);
  }
}

class DeConferencia extends Condicion {
  const DeConferencia(this.conferencia, this.cantidad, {this.exacto = false});
  final Conferencia conferencia;
  final int cantidad;
  final bool exacto;
  @override
  String get texto =>
      '${exacto ? 'Exactamente' : 'Al menos'} $cantidad del ${conferencia == Conferencia.este ? 'Este' : 'Oeste'}';
  @override
  bool cumple(List<Jugador> js, Conferencia? Function(String) conferenciaDe) {
    final n = js.where((j) => conferenciaDe(j.franquiciaId) == conferencia).length;
    return exacto ? n == cantidad : n >= cantidad;
  }
}

class MediaMinima extends Condicion {
  const MediaMinima(this.minimo);
  final int minimo;
  @override
  String get texto => 'Media del equipo $minimo o más';
  @override
  bool cumple(List<Jugador> js, _) => js.isNotEmpty && js.fold(0, (a, j) => a + j.media) / js.length >= minimo;
}

class MediaMaxima extends Condicion {
  const MediaMaxima(this.maximo);
  final int maximo;
  @override
  String get texto => 'Media del equipo $maximo o menos';
  @override
  bool cumple(List<Jugador> js, _) => js.isNotEmpty && js.fold(0, (a, j) => a + j.media) / js.length <= maximo;
}

class MismaFranquicia extends Condicion {
  const MismaFranquicia(this.cantidad);
  final int cantidad;
  @override
  String get texto => '$cantidad de la misma franquicia';
  @override
  bool cumple(List<Jugador> js, _) {
    final c = <String, int>{};
    for (final j in js) {
      c[j.franquiciaId] = (c[j.franquiciaId] ?? 0) + 1;
    }
    return c.values.any((n) => n >= cantidad);
  }
}

class TierMaximo extends Condicion {
  const TierMaximo(this.tier, this.cantidad);

  /// Como mucho [cantidad] cartas de [tier] o más.
  final Tier tier;
  final int cantidad;
  @override
  String get texto => cantidad == 0
      ? 'Sin cartas ${tier.codigo} o mejores'
      : 'Como mucho $cantidad carta${cantidad == 1 ? '' : 's'} ${tier.codigo} o mejor';
  @override
  bool cumple(List<Jugador> js, _) => js.where((j) => j.tier.index >= tier.index).length <= cantidad;
}

class TierMinimo extends Condicion {
  const TierMinimo(this.tier, this.cantidad);
  final Tier tier;
  final int cantidad;
  @override
  String get texto => 'Al menos $cantidad carta${cantidad == 1 ? '' : 's'} ${tier.codigo} o mejor';
  @override
  bool cumple(List<Jugador> js, _) => js.where((j) => j.tier.index >= tier.index).length >= cantidad;
}

class ConArquetipo extends Condicion {
  const ConArquetipo(this.roles, this.cantidad, this.nombre);
  final Set<RolCancha> roles;
  final int cantidad;
  final String nombre;
  @override
  String get texto => 'Al menos $cantidad $nombre';
  @override
  bool cumple(List<Jugador> js, _) => js.where((j) => roles.contains(j.rol)).length >= cantidad;
}

class DefensaMinima extends Condicion {
  const DefensaMinima(this.minimo);
  final double minimo;
  @override
  String get texto => 'Robos + tapas por jugador: ${minimo.toStringAsFixed(1)} o más';
  @override
  bool cumple(List<Jugador> js, _) =>
      js.isNotEmpty && js.fold(0.0, (a, j) => a + j.stats.robP + j.stats.tapP) / js.length >= minimo;
}

class UnaSolaDecada extends Condicion {
  const UnaSolaDecada();
  @override
  String get texto => 'Todos de la misma década';
  @override
  bool cumple(List<Jugador> js, _) => js.map((j) => j.epoca).toSet().length <= 1;
}

/// Un desafío de armado: condiciones, premio y cuántas cartas pide tener en el álbum.
class DesafioArmado {
  const DesafioArmado({
    required this.id,
    required this.titulo,
    required this.condiciones,
    required this.monedas,
    this.albumMinimo = 6,
  });

  final String id;
  final String titulo;
  final List<Condicion> condiciones;
  final int monedas;

  /// Cartas que conviene tener en el álbum para intentarlo (si no, aparece bloqueado).
  final int albumMinimo;

  /// Cada condición, y si el plantel la cumple.
  List<(Condicion, bool)> estado(List<Jugador> js, Conferencia? Function(String) conferenciaDe) => [
    for (final c in condiciones) (c, c.cumple(js, conferenciaDe)),
  ];

  /// Resuelto: plantel completo (6 puestos) y todas las condiciones.
  bool resuelto(Plantel p, Conferencia? Function(String) conferenciaDe) =>
      p.completo && condiciones.every((c) => c.cumple(p.jugadores.toList(), conferenciaDe));
}

const _tiradores = {
  RolCancha.tiradorPantallas,
  RolCancha.especialista3D,
  RolCancha.anotadorExterior,
  RolCancha.alaPivotTirador,
  RolCancha.pivotTirador,
};
const _defensores = {
  RolCancha.baseDefensivo,
  RolCancha.cerrojoDefensivo,
  RolCancha.protectorAro,
  RolCancha.especialista3D,
};
const _organizadores = {
  RolCancha.organizadorPuro,
  RolCancha.escoltaGenerador,
  RolCancha.controladorTotal,
  RolCancha.distribuidorInterior,
  RolCancha.pivotOrganizador,
};
const _interiores = {RolCancha.goliatPintura, RolCancha.maestroPoste, RolCancha.fuerzaBruta, RolCancha.juegoDePies};

/// Los 20 desafíos, de menor a mayor dificultad. Se desbloquean de a uno.
const desafiosArmado = <DesafioArmado>[
  DesafioArmado(id: 'd01', titulo: 'Primer quinteto', condiciones: [MediaMinima(72)], monedas: 40),
  DesafioArmado(id: 'd02', titulo: 'Química básica', condiciones: [QuimicaMinima(20)], monedas: 50),
  DesafioArmado(
    id: 'd03',
    titulo: 'Del Este',
    condiciones: [DeConferencia(Conferencia.este, 4)],
    monedas: 50,
    albumMinimo: 12,
  ),
  DesafioArmado(
    id: 'd04',
    titulo: 'Viaje en el tiempo',
    condiciones: [DecadasDistintas(3)],
    monedas: 60,
    albumMinimo: 12,
  ),
  DesafioArmado(
    id: 'd05',
    titulo: 'Tiradores',
    condiciones: [ConArquetipo(_tiradores, 2, 'tiradores')],
    monedas: 60,
    albumMinimo: 15,
  ),
  DesafioArmado(
    id: 'd06',
    titulo: 'Los obreros',
    condiciones: [TierMaximo(Tier.a, 1), MediaMinima(74)],
    monedas: 70,
    albumMinimo: 15,
  ),
  DesafioArmado(
    id: 'd07',
    titulo: 'Socios de siempre',
    condiciones: [MismaFranquicia(3), QuimicaMinima(35)],
    monedas: 80,
    albumMinimo: 20,
  ),
  DesafioArmado(
    id: 'd08',
    titulo: 'Muralla',
    condiciones: [DefensaMinima(2.0), ConArquetipo(_defensores, 2, 'defensores')],
    monedas: 80,
    albumMinimo: 20,
  ),
  DesafioArmado(
    id: 'd09',
    titulo: 'Costa a costa',
    condiciones: [DeConferencia(Conferencia.este, 3, exacto: true), DeConferencia(Conferencia.oeste, 3, exacto: true)],
    monedas: 90,
    albumMinimo: 20,
  ),
  DesafioArmado(
    id: 'd10',
    titulo: 'Una sola época',
    condiciones: [UnaSolaDecada(), MediaMinima(76)],
    monedas: 100,
    albumMinimo: 25,
  ),
  DesafioArmado(
    id: 'd11',
    titulo: 'Directores de orquesta',
    condiciones: [ConArquetipo(_organizadores, 2, 'organizadores'), QuimicaMinima(40)],
    monedas: 110,
    albumMinimo: 25,
  ),
  DesafioArmado(
    id: 'd12',
    titulo: 'Pintura pesada',
    condiciones: [ConArquetipo(_interiores, 2, 'jugadores interiores'), DefensaMinima(1.8)],
    monedas: 110,
    albumMinimo: 25,
  ),
  DesafioArmado(
    id: 'd13',
    titulo: 'Estrellas',
    condiciones: [TierMinimo(Tier.s, 2), MediaMinima(82)],
    monedas: 130,
    albumMinimo: 30,
  ),
  DesafioArmado(
    id: 'd14',
    titulo: 'Las cuatro décadas',
    condiciones: [DecadasDistintas(4), QuimicaMinima(30), MediaMinima(78)],
    monedas: 140,
    albumMinimo: 30,
  ),
  DesafioArmado(
    id: 'd15',
    titulo: 'Franquicia de culto',
    condiciones: [MismaFranquicia(4), QuimicaMinima(55)],
    monedas: 150,
    albumMinimo: 35,
  ),
  DesafioArmado(
    id: 'd16',
    titulo: 'Los olvidados',
    condiciones: [TierMaximo(Tier.a, 0), MediaMinima(70), QuimicaMinima(30)],
    monedas: 150,
    albumMinimo: 35,
  ),
  DesafioArmado(
    id: 'd17',
    titulo: 'Lluvia de triples',
    condiciones: [ConArquetipo(_tiradores, 3, 'tiradores'), MediaMinima(80)],
    monedas: 170,
    albumMinimo: 40,
  ),
  DesafioArmado(
    id: 'd18',
    titulo: 'El Este manda',
    condiciones: [DeConferencia(Conferencia.este, 5), QuimicaMinima(50), MediaMinima(80)],
    monedas: 190,
    albumMinimo: 45,
  ),
  DesafioArmado(
    id: 'd19',
    titulo: 'Los anillos olvidados',
    condiciones: [QuimicaMinima(70), DecadasDistintas(2, maximo: 2), MediaMinima(82)],
    monedas: 220,
    albumMinimo: 50,
  ),
  DesafioArmado(
    id: 'd20',
    titulo: 'La obra maestra',
    condiciones: [QuimicaMinima(80), TierMinimo(Tier.s, 3), MediaMinima(86), DefensaMinima(1.6)],
    monedas: 300,
    albumMinimo: 60,
  ),
];

/// Lo que guarda el perfil de los modos de armado sin partida: desafíos resueltos y récords del
/// minijuego. Va en [PerfilEntrenador.armado].
extension PerfilArmado on PerfilEntrenador {
  Set<String> get desafiosResueltos => {...(armado['resueltos'] as List? ?? const []).cast<String>()};

  int mejorAdivina(VarianteAdivina v) => (armado['adivina'] as Map<String, dynamic>? ?? const {})[v.name] as int? ?? 0;

  /// ¿Está desbloqueado el desafío [i]? (el primero siempre; el resto, con el anterior resuelto).
  bool desafioDesbloqueado(int i) => i == 0 || desafiosResueltos.contains(desafiosArmado[i - 1].id);

  PerfilEntrenador conDesafioResuelto(DesafioArmado d) {
    if (desafiosResueltos.contains(d.id)) return this;
    final resueltos = {...desafiosResueltos, d.id};
    var p = copyWith(
      armado: {...armado, 'resueltos': resueltos.toList()},
      monedas: monedas + d.monedas,
      xp: xp + d.monedas,
      metajuego: metajuego.copyWith(puntosPase: metajuego.puntosPase + d.monedas),
    );
    if (resueltos.length >= 10 && !p.logros.containsKey(Logro.desafiosArmado)) {
      p = p.copyWith(
        logros: {...p.logros, Logro.desafiosArmado: DateTime.now().millisecondsSinceEpoch},
        xp: p.xp + 100,
        monedas: p.monedas + 50,
      );
    }
    return p;
  }

  /// Cierra una sesión de Adiviná la carta: XP y monedas por acierto, récord y logro con 10/10.
  PerfilEntrenador conSesionAdivina(VarianteAdivina v, int aciertos, int rondas) {
    final previo = mejorAdivina(v);
    var p = copyWith(
      armado: {
        ...armado,
        'adivina': {...(armado['adivina'] as Map<String, dynamic>? ?? const {}), v.name: max(previo, aciertos)},
      },
      xp: xp + aciertos * 10,
      monedas: monedas + aciertos * 5,
    );
    if (aciertos == rondas && rondas >= 10 && !p.logros.containsKey(Logro.adivina)) {
      p = p.copyWith(
        logros: {...p.logros, Logro.adivina: DateTime.now().millisecondsSinceEpoch},
        xp: p.xp + 100,
        monedas: p.monedas + 50,
      );
    }
    return p;
  }
}

/// ¿El álbum alcanza para intentar el desafío? (cartas suficientes y un plantel completo posible).
bool albumAlcanza(DesafioArmado d, List<Jugador> album) {
  if (album.length < d.albumMinimo) return false;
  var plantel = const Plantel();
  final ordenadas = [...album]..sort((a, b) => a.posiciones.length.compareTo(b.posiciones.length));
  for (final p in Posicion.values) {
    final c = ordenadas.where((j) => plantel.posicionesDisponiblesPara(j).contains(p)).firstOrNull;
    if (c == null) return false;
    plantel = plantel.asignar(c, p);
  }
  return true;
}

// ───────────────────────────────── Adiviná la carta ──────────────────────────────────────────

enum VarianteAdivina {
  quien('¿Quién es?', 'Ves los números de una carta: elegí de quién son.'),
  masMenos('Más o menos', 'Dos cartas: ¿cuál tiene más media?');

  const VarianteAdivina(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Una pregunta: [opciones] (2 o 4) y cuál es la correcta.
class PreguntaAdivina {
  const PreguntaAdivina(this.objetivo, this.opciones, this.correcta);

  /// La carta de la que se muestran los números (en "Más o menos", la de más media).
  final Jugador objetivo;
  final List<Jugador> opciones;
  final int correcta;
}

/// Genera las preguntas del minijuego con cartas reconocibles (A o mejor, media 80+).
class Adivina {
  Adivina(this.catalogo, {Random? azar}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final Random _azar;

  static const rondas = 10;

  late final List<Jugador> _conocidas = [
    for (final j in catalogo)
      if (j.tier != Tier.b && j.media >= 80) j,
  ];

  PreguntaAdivina pregunta(VarianteAdivina v) => v == VarianteAdivina.quien ? _quien() : _masMenos();

  PreguntaAdivina _quien() {
    while (true) {
      final obj = _conocidas[_azar.nextInt(_conocidas.length)];
      // Opciones creíbles: mismo puesto principal y misma época, otras personas.
      final pares = [
        for (final j in _conocidas)
          if (j.nbaPlayerId != obj.nbaPlayerId && j.posiciones.first == obj.posiciones.first && j.epoca == obj.epoca) j,
      ]..shuffle(_azar);
      final elegidos = <Jugador>[];
      for (final j in pares) {
        if (elegidos.any((x) => x.nbaPlayerId == j.nbaPlayerId || x.nombre == j.nombre)) continue;
        elegidos.add(j);
        if (elegidos.length == 3) break;
      }
      if (elegidos.length < 3) continue;
      final opciones = [obj, ...elegidos]..shuffle(_azar);
      return PreguntaAdivina(obj, opciones, opciones.indexOf(obj));
    }
  }

  PreguntaAdivina _masMenos() {
    while (true) {
      final a = _conocidas[_azar.nextInt(_conocidas.length)];
      final b = _conocidas[_azar.nextInt(_conocidas.length)];
      if (a.nbaPlayerId == b.nbaPlayerId || a.media == b.media) continue;
      final opciones = [a, b];
      final correcta = a.media > b.media ? 0 : 1;
      return PreguntaAdivina(opciones[correcta], opciones, correcta);
    }
  }
}
