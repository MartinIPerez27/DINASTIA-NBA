import 'dart:math';

import '../entities/jugador.dart';
import '../entities/perfil.dart';
import '../entities/posicion.dart';
import '../entities/temporada.dart';
import '../progreso.dart';
import 'evoluciones.dart';

/// Fantasy NBA (al estilo de El Gran DT / ESPN fantasy).
///
/// OJO, honestidad: el juego es offline y no tiene una fuente de estadísticas en vivo. Los puntos de
/// cada semana salen de los PROMEDIOS REALES de la carta (puntos, rebotes, asistencias, robos,
/// tapones, pérdidas) de un año de la NBA, con la variación de un partido a otro, rachas y lesiones
/// simuladas. No son los números reales de cada partido de ese año.

/// Cómo piensa cada mánager de la IA al armar y manejar su equipo.
enum PersonalidadFantasy {
  triples('El Gurú de los Triples', 'Solo mira a los tiradores de larga distancia.'),
  defensivo('El Defensivo', 'Robos y tapones: la defensa también suma.'),
  estrellas('El Coleccionista de Leyendas', 'Gasta casi todo en figuras y rellena con baratos.'),
  contador('El Contador', 'Busca los puntos que más rinden por cada dólar.'),
  rebotero('El Rebotero', 'Pintura, rebotes y dobles-dobles.'),
  repartidor('El Repartidor', 'Asistencias y juego colectivo.'),
  equilibrado('El Equilibrado', 'Un poco de todo, sin riesgos.'),
  caotico('El Caótico', 'Elige con el corazón (y algo de azar).');

  const PersonalidadFantasy(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Reglas y constantes del juego (afinables).
class ReglasFantasy {
  const ReglasFantasy._();

  static const semanasRegulares = 12;
  static const semanasTotales = 14; // 12 + semifinales + final
  static const cambiosPorSemana = 1;
  static const minimoRivales = 3, maximoRivales = 7;

  static const pesoReb = 1.2, pesoAst = 1.5, pesoRob = 3.0, pesoTap = 3.0, pesoPer = -1.0;
  static const bonusDobleDoble = 2.0, bonusTripleDoble = 5.0;

  /// Presupuesto (millones) por dificultad. Una carta cuesta según su media: ver [precio].
  static int presupuesto(Dificultad d) => switch (d) {
    Dificultad.normal => 48,
    Dificultad.dificil => 44,
    Dificultad.leyenda => 40,
  };

  /// Precio de una carta: de 1 (suplente) a unos 13 (leyenda).
  static int precio(int media) => max(1, ((media - 62) / 2.8).round());

  static double puntos(
    num pts,
    num reb,
    num ast,
    num rob,
    num tap,
    num per, {
    bool dobleDoble = false,
    bool tripleDoble = false,
  }) =>
      pts +
      pesoReb * reb +
      pesoAst * ast +
      pesoRob * rob +
      pesoTap * tap +
      pesoPer * per.abs() +
      (tripleDoble ? bonusTripleDoble : (dobleDoble ? bonusDobleDoble : 0));

  /// Puntos fantasy por partido que promedia la carta (sin bonus ni variación).
  static double promedio(Jugador j) {
    final s = j.stats;
    return puntos(s.ppp, s.rpp, s.app, s.robP, s.tapP, s.perP);
  }
}

/// Una línea simulada de un partido.
class LineaFantasy {
  const LineaFantasy(this.pts, this.reb, this.ast, this.rob, this.tap, this.per);

  final int pts, reb, ast, rob, tap, per;

  int get categorias10 => [pts, reb, ast, rob, tap].where((v) => v >= 10).length;
  bool get dobleDoble => categorias10 >= 2;
  bool get tripleDoble => categorias10 >= 3;

  double get puntos =>
      ReglasFantasy.puntos(pts, reb, ast, rob, tap, per, dobleDoble: dobleDoble, tripleDoble: tripleDoble);
}

/// Un hash estable (FNV-1a) para sembrar cada partido: el mismo resultado siempre.
int _semilla(Object a, [Object b = '', Object c = '', Object d = '']) {
  var h = 0x811c9dc5;
  for (final u in '$a|$b|$c|$d'.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h;
}

double _normal(Random r) {
  final u = max(1e-9, r.nextDouble()), v = r.nextDouble();
  return sqrt(-2 * log(u)) * cos(2 * pi * v);
}

/// El mundo del fantasy en un año: lesiones, rachas y partidos de cada jugador, todo determinista
/// según la semilla (no depende del orden en que se simule).
class MundoFantasy {
  const MundoFantasy(this.semilla);

  final int semilla;

  /// Semanas que falta el jugador (0 si juega) al empezar la semana [semana].
  int semanasFuera(String id, int semana) {
    var fuera = 0;
    for (var w = 0; w <= semana; w++) {
      if (fuera > 0) {
        if (w == semana) return fuera;
        fuera--;
        continue;
      }
      final r = Random(_semilla(semilla, 'les', id, w));
      if (r.nextDouble() < 0.035) {
        fuera = 1 + r.nextInt(4);
        if (w == semana) return fuera;
        fuera--;
      }
    }
    return 0;
  }

  bool lesionado(String id, int semana) => semanasFuera(id, semana) > 0;

  /// Racha de la semana: 0,82 (fría) a 1,2 (caliente), con memoria de la semana anterior.
  double racha(String id, int semana) {
    var f = 0.0;
    for (var w = 0; w <= semana; w++) {
      f = 0.5 * f + 0.2 * _normal(Random(_semilla(semilla, 'forma', id, w)));
    }
    return (1 + f).clamp(0.78, 1.25);
  }

  /// Partidos de la semana (3 o 4, iguales para todos).
  int partidosSemana(int semana) => 3 + (_semilla(semilla, 'pj', semana) % 2);

  /// Línea simulada del partido [k] de la semana, o null si descansa o está lesionado.
  /// [mejora] multiplica la producción (evoluciones de las cartas del álbum).
  LineaFantasy? partido(Jugador j, int semana, int k, {double mejora = 1}) {
    if (lesionado(j.id, semana)) return null;
    final r = Random(_semilla(semilla, 'pj', j.id, semana * 10 + k));
    // Los que juegan muchos minutos a veces descansan (back-to-back, cuidado físico).
    if (j.stats.minP >= 28 && r.nextDouble() < 0.06) return null;
    final f = racha(j.id, semana) * mejora;
    final s = j.stats;
    int cuenta(double media, double desvio) => max(0, (media + desvio * _normal(r)).round());
    return LineaFantasy(
      cuenta(s.ppp * f, 0.33 * s.ppp + 1.5),
      cuenta(s.rpp * (0.5 + 0.5 * f), 0.4 * sqrt(max(s.rpp, 0.5)) + 0.9),
      cuenta(s.app * (0.5 + 0.5 * f), 0.45 * sqrt(max(s.app, 0.5)) + 0.7),
      cuenta(s.robP, 0.7 * sqrt(max(s.robP, 0.3)) + 0.3),
      cuenta(s.tapP, 0.8 * sqrt(max(s.tapP, 0.25)) + 0.2),
      cuenta(s.perP, 0.6 * sqrt(max(s.perP, 0.5)) + 0.4),
    );
  }

  /// Puntos de un jugador en la semana (0 si no jugó).
  double puntosSemana(Jugador j, int semana, {double mejora = 1}) {
    var total = 0.0;
    for (var k = 0; k < partidosSemana(semana); k++) {
      total += partido(j, semana, k, mejora: mejora)?.puntos ?? 0;
    }
    return total;
  }
}

/// El equipo de un mánager (vos o la IA).
class EquipoFantasy {
  const EquipoFantasy({required this.nombre, required this.plantel, this.capitan, this.personalidad});

  final String nombre;

  /// Posición → id de carta (5 titulares + Sexto Hombre).
  final Map<Posicion, String> plantel;
  final String? capitan;
  final PersonalidadFantasy? personalidad;

  bool get esUsuario => personalidad == null;
  bool get completo => plantel.length == Posicion.values.length;
  List<String> get ids => [for (final p in Posicion.values) ?plantel[p]];

  EquipoFantasy copyWith({Map<Posicion, String>? plantel, String? capitan, bool sinCapitan = false}) => EquipoFantasy(
    nombre: nombre,
    plantel: plantel ?? this.plantel,
    capitan: sinCapitan ? null : (capitan ?? this.capitan),
    personalidad: personalidad,
  );

  factory EquipoFantasy.fromJson(Map<String, dynamic> j) => EquipoFantasy(
    nombre: j['n'] as String,
    plantel: {
      for (final e in (j['p'] as Map<String, dynamic>).entries) Posicion.values.byName(e.key): e.value as String,
    },
    capitan: j['c'] as String?,
    personalidad: j['a'] == null ? null : PersonalidadFantasy.values.byName(j['a'] as String),
  );

  Map<String, dynamic> toJson() => {
    'n': nombre,
    'p': {for (final e in plantel.entries) e.key.name: e.value},
    if (capitan != null) 'c': capitan,
    if (personalidad != null) 'a': personalidad!.name,
  };
}

/// Un cruce de la semana: índices de equipos y sus puntos.
class CruceFantasy {
  const CruceFantasy(this.a, this.b, this.puntosA, this.puntosB);

  final int a, b;
  final double puntosA, puntosB;

  int get ganador => puntosA >= puntosB ? a : b;

  factory CruceFantasy.fromJson(List<dynamic> j) =>
      CruceFantasy(j[0] as int, j[1] as int, (j[2] as num).toDouble(), (j[3] as num).toDouble());
  List<dynamic> toJson() => [a, b, double.parse(puntosA.toStringAsFixed(1)), double.parse(puntosB.toStringAsFixed(1))];
}

/// Una semana ya jugada.
class SemanaFantasy {
  const SemanaFantasy({
    required this.cruces,
    required this.puntosEquipo,
    this.detalleUsuario = const {},
    this.fase = 'regular',
  });

  final List<CruceFantasy> cruces;

  /// Puntos de cada equipo (por índice).
  final List<double> puntosEquipo;

  /// Puntos de cada jugador de tu equipo esa semana (id → puntos); lesionados con 0.
  final Map<String, double> detalleUsuario;

  /// 'regular', 'semis' o 'final'.
  final String fase;

  factory SemanaFantasy.fromJson(Map<String, dynamic> j) => SemanaFantasy(
    cruces: [for (final c in j['c'] as List) CruceFantasy.fromJson(c as List)],
    puntosEquipo: [for (final v in j['e'] as List) (v as num).toDouble()],
    detalleUsuario: (j['d'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
    fase: j['f'] as String? ?? 'regular',
  );

  Map<String, dynamic> toJson() => {
    'c': [for (final c in cruces) c.toJson()],
    'e': [for (final v in puntosEquipo) double.parse(v.toStringAsFixed(1))],
    if (detalleUsuario.isNotEmpty) 'd': detalleUsuario.map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(1)))),
    'f': fase,
  };
}

/// Fila de la tabla.
class FilaFantasy {
  const FilaFantasy(this.indice, this.victorias, this.derrotas, this.puntos);

  final int indice, victorias, derrotas;
  final double puntos;
}

enum FaseFantasy { armado, regular, semis, finalPlayoff, terminada }

/// "2015-16" para el año de cierre 2016.
String etiquetaAnio(int anio) => anio == 0 ? 'Mi álbum' : '${anio - 1}-${(anio % 100).toString().padLeft(2, '0')}';

/// La partida de Fantasy NBA, guardada en `Temporada.datosModo`.
class PartidaFantasy {
  const PartidaFantasy({
    required this.anio,
    required this.semilla,
    required this.presupuesto,
    required this.equipos,
    this.soloAlbum = false,
    this.semanas = const [],
    this.cambiosEstaSemana = 0,
    this.poolIds = const [],
  });

  /// Año de cierre de la temporada NBA elegida (0 = tu álbum, sin año).
  final int anio;
  final int semilla;
  final int presupuesto;

  /// Equipos: el tuyo es el 0.
  final List<EquipoFantasy> equipos;
  final bool soloAlbum;
  final List<SemanaFantasy> semanas;
  final int cambiosEstaSemana;

  /// Cartas disponibles (ids), para poder volver a armar el mercado igual.
  final List<String> poolIds;

  static const usuario = 0;

  EquipoFantasy get tuEquipo => equipos[usuario];
  MundoFantasy get mundo => MundoFantasy(semilla);

  int get semanaActual => semanas.length;

  FaseFantasy get fase {
    if (!tuEquipo.completo) return FaseFantasy.armado;
    final n = semanas.length;
    if (n < ReglasFantasy.semanasRegulares) return FaseFantasy.regular;
    if (n == ReglasFantasy.semanasRegulares) return FaseFantasy.semis;
    if (n == ReglasFantasy.semanasRegulares + 1) return FaseFantasy.finalPlayoff;
    return FaseFantasy.terminada;
  }

  /// Tabla de la temporada regular: victorias y, para desempatar, puntos a favor.
  List<FilaFantasy> tabla() {
    final v = List.filled(equipos.length, 0), d = List.filled(equipos.length, 0);
    final pf = List.filled(equipos.length, 0.0);
    for (final s in semanas.where((s) => s.fase == 'regular')) {
      for (final c in s.cruces) {
        v[c.ganador]++;
        d[c.ganador == c.a ? c.b : c.a]++;
      }
    }
    for (final s in semanas.where((s) => s.fase == 'regular')) {
      for (var i = 0; i < equipos.length; i++) {
        pf[i] += s.puntosEquipo[i];
      }
    }
    return [for (var i = 0; i < equipos.length; i++) FilaFantasy(i, v[i], d[i], pf[i])]..sort((a, b) {
      final c = b.victorias.compareTo(a.victorias);
      return c != 0 ? c : b.puntos.compareTo(a.puntos);
    });
  }

  /// Clasificados a los playoffs (4, o todos si son menos).
  List<int> get clasificados => [for (final f in tabla().take(min(4, equipos.length))) f.indice];

  /// Campeón (null mientras se juegan los playoffs).
  int? get campeon {
    final fin = semanas.where((s) => s.fase == 'final');
    return fin.isEmpty ? null : fin.first.cruces.first.ganador;
  }

  /// Subcampeón.
  int? get subcampeon {
    final fin = semanas.where((s) => s.fase == 'final');
    if (fin.isEmpty) return null;
    final c = fin.first.cruces.first;
    return c.ganador == c.a ? c.b : c.a;
  }

  /// Puesto final del usuario: 1 campeón, 2 subcampeón, 3 semifinalista, o su puesto en la tabla.
  int get puestoUsuario {
    if (campeon == usuario) return 1;
    if (subcampeon == usuario) return 2;
    if (fase == FaseFantasy.terminada && clasificados.contains(usuario)) return 3;
    return tabla().indexWhere((f) => f.indice == usuario) + 1;
  }

  PartidaFantasy copyWith({
    List<EquipoFantasy>? equipos,
    List<SemanaFantasy>? semanas,
    int? cambiosEstaSemana,
    List<String>? poolIds,
  }) => PartidaFantasy(
    anio: anio,
    semilla: semilla,
    presupuesto: presupuesto,
    soloAlbum: soloAlbum,
    equipos: equipos ?? this.equipos,
    semanas: semanas ?? this.semanas,
    cambiosEstaSemana: cambiosEstaSemana ?? this.cambiosEstaSemana,
    poolIds: poolIds ?? this.poolIds,
  );

  static PartidaFantasy? de(Temporada t) {
    final j = t.datosModo['fantasy'];
    return j is Map<String, dynamic> ? PartidaFantasy.fromJson(j) : null;
  }

  Temporada guardarEn(Temporada t) => t.copyWith(datosModo: {...t.datosModo, 'fantasy': toJson()});

  factory PartidaFantasy.fromJson(Map<String, dynamic> j) => PartidaFantasy(
    anio: j['anio'] as int,
    semilla: j['semilla'] as int,
    presupuesto: j['presupuesto'] as int,
    soloAlbum: j['album'] as bool? ?? false,
    equipos: [for (final e in j['equipos'] as List) EquipoFantasy.fromJson(e as Map<String, dynamic>)],
    semanas: [for (final s in j['semanas'] as List? ?? const []) SemanaFantasy.fromJson(s as Map<String, dynamic>)],
    cambiosEstaSemana: j['cambios'] as int? ?? 0,
    poolIds: (j['pool'] as List? ?? const []).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'anio': anio,
    'semilla': semilla,
    'presupuesto': presupuesto,
    if (soloAlbum) 'album': true,
    'equipos': [for (final e in equipos) e.toJson()],
    'semanas': [for (final s in semanas) s.toJson()],
    if (cambiosEstaSemana > 0) 'cambios': cambiosEstaSemana,
    'pool': poolIds,
  };
}

/// La lógica del juego: mercado, armado de la IA, semanas y playoffs.
class Fantasy {
  Fantasy(this.catalogo, {this._perfil}) {
    _porId = {for (final j in catalogo) j.id: j};
  }

  final List<Jugador> catalogo;
  final PerfilEntrenador? _perfil;
  late final Map<String, Jugador> _porId;

  Jugador? carta(String id) => _porId[id];

  /// Años de la NBA que se pueden elegir (con suficientes jugadores).
  static const primerAnio = 1980, ultimoAnio = 2025;

  /// Cartas de un año: la del tramo que lo contiene (la más ajustada si hay varias de una misma
  /// persona). Son promedios del tramo en esa franquicia, no del año puntual.
  List<Jugador> poolDelAnio(int anio) {
    final mejor = <int, Jugador>{};
    int ancho(Jugador j) => j.temporadas == null ? 99 : j.temporadas!.$2 - j.temporadas!.$1;
    for (final j in catalogo) {
      final t = j.temporadas;
      if (t == null || anio < t.$1 || anio > t.$2) continue;
      if (j.stats.minP < 10) continue;
      final previa = mejor[j.nbaPlayerId];
      if (previa == null || ancho(j) < ancho(previa) || (ancho(j) == ancho(previa) && j.media > previa.media)) {
        mejor[j.nbaPlayerId] = j;
      }
    }
    return mejor.values.toList()..sort((a, b) => b.media.compareTo(a.media));
  }

  /// Cartas de tu álbum (una por persona: la de más media).
  List<Jugador> poolAlbum(Set<String> coleccion) {
    final mejor = <int, Jugador>{};
    for (final j in catalogo) {
      if (!coleccion.contains(j.id)) continue;
      final previa = mejor[j.nbaPlayerId];
      if (previa == null || j.media > previa.media) mejor[j.nbaPlayerId] = j;
    }
    return mejor.values.toList()..sort((a, b) => b.media.compareTo(a.media));
  }

  /// ¿Alcanza el pool para armar un equipo (6 puestos, al presupuesto mínimo)?
  bool alcanza(List<Jugador> pool) {
    var libres = {...Posicion.values};
    for (final p in Posicion.titulares) {
      if (pool.where((j) => j.puedeJugarEn(p)).length < 3) libres = libres..remove(p);
    }
    return libres.length == Posicion.values.length && pool.length >= 12;
  }

  /// Nivel de evolución para una carta si la partida usa el álbum.
  double _mejora(PartidaFantasy f, String id) {
    final p = _perfil;
    if (p == null || !f.soloAlbum) return 1;
    return 1 + 0.02 * nivelEvo(p, id);
  }

  int precioDe(PartidaFantasy f, Jugador j) {
    final p = _perfil;
    return ReglasFantasy.precio(p != null && f.soloAlbum ? mediaEvolucionada(p, j, usaAlbum: true) : j.media);
  }

  int costo(PartidaFantasy f, EquipoFantasy e) =>
      e.ids.fold(0, (a, id) => a + (_porId[id] == null ? 0 : precioDe(f, _porId[id]!)));

  /// Nueva partida: tu equipo vacío y las IA ya armadas.
  PartidaFantasy nueva({
    required int anio,
    required Dificultad dificultad,
    required int rivales,
    required int semilla,
    required List<Jugador> pool,
    bool soloAlbum = false,
    String nombreUsuario = 'Tu equipo',
  }) {
    final n = rivales.clamp(ReglasFantasy.minimoRivales, ReglasFantasy.maximoRivales);
    final r = Random(_semilla(semilla, 'ia'));
    final personalidades = [...PersonalidadFantasy.values]..shuffle(r);
    var f = PartidaFantasy(
      anio: anio,
      semilla: semilla,
      presupuesto: ReglasFantasy.presupuesto(dificultad),
      soloAlbum: soloAlbum,
      poolIds: [for (final j in pool) j.id],
      equipos: [
        EquipoFantasy(nombre: nombreUsuario, plantel: const {}),
        for (var i = 0; i < n; i++)
          EquipoFantasy(nombre: personalidades[i].nombre, plantel: const {}, personalidad: personalidades[i]),
      ],
    );
    final equipos = [f.equipos.first];
    for (var i = 1; i < f.equipos.length; i++) {
      final e = f.equipos[i];
      final plantel = _armarIA(f, e.personalidad!, pool, Random(_semilla(semilla, 'armado', i)));
      equipos.add(e.copyWith(plantel: plantel, capitan: _mejorCapitan(f, plantel.values.toList(), 0)));
    }
    return f.copyWith(equipos: equipos);
  }

  /// Cuánto le gusta una carta a cada personalidad (más alto = mejor).
  double _gusto(PersonalidadFantasy p, Jugador j, Random r) {
    final s = j.stats;
    final base = ReglasFantasy.promedio(j);
    return switch (p) {
      PersonalidadFantasy.triples => base * 0.5 + 40 * s.pctT3 + (s.ppp >= 15 ? 6 : 0),
      PersonalidadFantasy.defensivo => base * 0.6 + 6 * (s.robP + s.tapP),
      PersonalidadFantasy.estrellas => j.media * 1.0 + base * 0.3,
      PersonalidadFantasy.contador => base,
      PersonalidadFantasy.rebotero => base * 0.5 + 2.2 * s.rpp + 2 * s.tapP,
      PersonalidadFantasy.repartidor => base * 0.5 + 3.5 * s.app,
      PersonalidadFantasy.equilibrado => base,
      PersonalidadFantasy.caotico => base * 0.4 + r.nextDouble() * 40,
    };
  }

  Map<Posicion, String> _armarIA(PartidaFantasy f, PersonalidadFantasy pers, List<Jugador> pool, Random r) {
    final elegido = <Posicion, Jugador>{};
    var restante = f.presupuesto;
    // Los puestos con menos candidatos primero, como en el armado del draft.
    final puestos = [...Posicion.values]
      ..sort(
        (a, b) => pool.where((j) => j.puedeJugarEn(a)).length.compareTo(pool.where((j) => j.puedeJugarEn(b)).length),
      );
    final personas = <int>{};
    for (var i = 0; i < puestos.length; i++) {
      final pos = puestos[i];
      final faltan = puestos.length - i - 1;
      final maximo = restante - faltan; // deja al menos 1 por cada puesto que falta
      final candidatos = [
        for (final j in pool)
          if (j.puedeJugarEn(pos) && !personas.contains(j.nbaPlayerId) && precioDe(f, j) <= maximo) j,
      ];
      if (candidatos.isEmpty) continue;
      // "Contador" y "Equilibrado" buscan valor por dólar; "Estrellas" gasta lo que haga falta.
      double valor(Jugador j) {
        final g = _gusto(pers, j, r);
        final precio = precioDe(f, j);
        return switch (pers) {
          PersonalidadFantasy.contador => g / (precio + 2),
          PersonalidadFantasy.equilibrado => g / sqrt(precio + 1),
          PersonalidadFantasy.estrellas => g + (i < 3 ? precio * 3.0 : -precio * 3.0),
          _ => g / pow(precio + 4, 0.35),
        };
      }

      candidatos.sort((a, b) => valor(b).compareTo(valor(a)));
      // Un poco de azar entre los mejores: no todas las ligas son iguales.
      final j = candidatos[r.nextInt(min(3, candidatos.length))];
      elegido[pos] = j;
      personas.add(j.nbaPlayerId);
      restante -= precioDe(f, j);
    }
    return {for (final e in elegido.entries) e.key: e.value.id};
  }

  String? _mejorCapitan(PartidaFantasy f, List<String> ids, int semana) {
    String? mejor;
    var mejorValor = -1.0;
    for (final id in ids) {
      final j = _porId[id];
      if (j == null || f.mundo.lesionado(id, semana)) continue;
      final v = ReglasFantasy.promedio(j);
      if (v > mejorValor) {
        mejorValor = v;
        mejor = id;
      }
    }
    return mejor;
  }

  /// Errores de armado de tu equipo (vacío = válido).
  List<String> validar(PartidaFantasy f, EquipoFantasy e) {
    final errores = <String>[];
    if (!e.completo) errores.add('Faltan ${Posicion.values.length - e.plantel.length} puestos.');
    if (costo(f, e) > f.presupuesto) errores.add('Te pasaste del presupuesto (${costo(f, e)} > ${f.presupuesto}).');
    final personas = <int>{};
    for (final id in e.ids) {
      final j = _porId[id];
      if (j != null && !personas.add(j.nbaPlayerId)) errores.add('${j.nombre} está dos veces.');
    }
    return errores;
  }

  /// Pone una carta en un puesto de tu equipo (durante el armado, o como cambio semanal).
  PartidaFantasy ficharUsuario(PartidaFantasy f, Posicion pos, Jugador j) {
    if (!j.puedeJugarEn(pos)) return f;
    final tu = f.tuEquipo;
    // Hasta jugar la primera semana el equipo se arma sin límite de cambios.
    final jugando = f.semanas.isNotEmpty;
    if (jugando && (f.cambiosEstaSemana >= ReglasFantasy.cambiosPorSemana) && tu.plantel[pos] != j.id) return f;
    if (tu.plantel[pos] == j.id) return f;
    final nuevo = {...tu.plantel, pos: j.id};
    // Nadie dos veces: si esa persona ya estaba en otro puesto, se rechaza.
    final repetida = tu.plantel.entries.any((e) => e.key != pos && _porId[e.value]?.nbaPlayerId == j.nbaPlayerId);
    if (repetida) return f;
    final equipo = tu.copyWith(plantel: nuevo);
    if (costo(f, equipo) > f.presupuesto) return f;
    final equipos = [...f.equipos]..[0] = equipo;
    return f.copyWith(equipos: equipos, cambiosEstaSemana: jugando ? f.cambiosEstaSemana + 1 : f.cambiosEstaSemana);
  }

  PartidaFantasy elegirCapitan(PartidaFantasy f, String cartaId) {
    if (!f.tuEquipo.ids.contains(cartaId)) return f;
    final equipos = [...f.equipos]..[0] = f.tuEquipo.copyWith(capitan: cartaId);
    return f.copyWith(equipos: equipos);
  }

  /// Puntos de un equipo en una semana (el capitán suma doble).
  (double, Map<String, double>) puntosEquipo(PartidaFantasy f, EquipoFantasy e, int semana) {
    final detalle = <String, double>{};
    var total = 0.0;
    for (final id in e.ids) {
      final j = _porId[id];
      if (j == null) continue;
      final p = f.mundo.puntosSemana(j, semana, mejora: _mejora(f, id));
      detalle[id] = p;
      total += id == e.capitan ? 2 * p : p;
    }
    return (total, detalle);
  }

  /// Cruces de la semana regular [semana] (todos contra todos, rotando; con impares uno descansa).
  List<(int, int)> crucesRegulares(int equipos, int semana) {
    final n = equipos.isOdd ? equipos + 1 : equipos;
    final resto = [for (var i = 1; i < n; i++) i];
    final k = semana % resto.length;
    final rot = [0, ...resto.skip(resto.length - k), ...resto.take(resto.length - k)];
    final cruces = <(int, int)>[];
    for (var i = 0; i < n ~/ 2; i++) {
      final a = rot[i], b = rot[n - 1 - i];
      if (a < equipos && b < equipos) cruces.add((a, b));
    }
    return cruces;
  }

  /// Los mánagers de la IA ajustan su equipo para la semana: reemplazan lesionados por el mejor
  /// reemplazo que alcance y eligen capitán.
  EquipoFantasy _ajusteIA(PartidaFantasy f, EquipoFantasy e, int semana, List<Jugador> pool) {
    var plantel = {...e.plantel};
    final r = Random(_semilla(f.semilla, 'ajuste', e.nombre, semana));
    final jugadores = e.copyWith(plantel: plantel);
    var costoActual = costo(f, jugadores);
    for (final entrada in plantel.entries.toList()) {
      final j = _porId[entrada.value];
      if (j == null || !f.mundo.lesionado(j.id, semana)) continue;
      final enUso = plantel.values.map((id) => _porId[id]?.nbaPlayerId).toSet();
      final libre = costoActual - precioDe(f, j);
      final cand = [
        for (final c in pool)
          if (c.puedeJugarEn(entrada.key) &&
              !enUso.contains(c.nbaPlayerId) &&
              !f.mundo.lesionado(c.id, semana) &&
              libre + precioDe(f, c) <= f.presupuesto)
            c,
      ]..sort((a, b) => _gusto(e.personalidad!, b, r).compareTo(_gusto(e.personalidad!, a, r)));
      if (cand.isNotEmpty) {
        plantel[entrada.key] = cand.first.id;
        costoActual = libre + precioDe(f, cand.first);
      }
    }
    return e.copyWith(plantel: plantel, capitan: _mejorCapitan(f, plantel.values.toList(), semana));
  }

  /// Juega la semana que viene: ajustes de la IA, puntos, cruces y, si toca, semis o final.
  PartidaFantasy jugarSemana(PartidaFantasy f) {
    final fase = f.fase;
    if (fase == FaseFantasy.armado || fase == FaseFantasy.terminada) return f;
    final semana = f.semanaActual;
    final pool = [for (final id in f.poolIds) ?_porId[id]];
    final equipos = [
      f.equipos.first,
      for (var i = 1; i < f.equipos.length; i++) _ajusteIA(f, f.equipos[i], semana, pool),
    ];
    // Si tu capitán está lesionado esa semana, el que mejor rinda (y esté sano) toma la cinta.
    final tu = equipos.first;
    if (tu.capitan == null || f.mundo.lesionado(tu.capitan!, semana)) {
      equipos[0] = tu.copyWith(capitan: _mejorCapitan(f, tu.ids, semana));
    }
    final ff = f.copyWith(equipos: equipos);
    final puntos = <double>[];
    Map<String, double> detalleUsuario = const {};
    for (var i = 0; i < equipos.length; i++) {
      final (p, d) = puntosEquipo(ff, equipos[i], semana);
      puntos.add(p);
      if (i == PartidaFantasy.usuario) detalleUsuario = d;
    }
    List<(int, int)> pares;
    String nombreFase;
    switch (fase) {
      case FaseFantasy.regular:
        pares = crucesRegulares(equipos.length, semana);
        nombreFase = 'regular';
      case FaseFantasy.semis:
        final c = ff.clasificados;
        pares = c.length >= 4 ? [(c[0], c[3]), (c[1], c[2])] : [(c[0], c[c.length - 1])];
        nombreFase = 'semis';
      case _:
        final semis = ff.semanas.lastWhere((s) => s.fase == 'semis');
        final g = [for (final c in semis.cruces) c.ganador];
        pares = [(g.first, g.length > 1 ? g.last : g.first)];
        nombreFase = 'final';
    }
    final cruces = [for (final (a, b) in pares) CruceFantasy(a, b, puntos[a], puntos[b])];
    final semanaJugada = SemanaFantasy(
      cruces: cruces,
      puntosEquipo: puntos,
      detalleUsuario: detalleUsuario,
      fase: nombreFase,
    );
    return ff.copyWith(semanas: [...ff.semanas, semanaJugada], cambiosEstaSemana: 0);
  }

  /// Juega todo lo que falta (con tu equipo tal cual y el capitán automático).
  PartidaFantasy simularTodo(PartidaFantasy f) {
    var x = f;
    while (x.fase != FaseFantasy.terminada && x.fase != FaseFantasy.armado) {
      x = jugarSemana(x);
    }
    return x;
  }
}

/// Metajuego del Fantasy: XP por semana ganada, y el título (y el podio) dan monedas y logro.
(PerfilEntrenador, List<Novedad>) premiarFantasy(PerfilEntrenador perfil, Temporada antes, Temporada despues) {
  final a = PartidaFantasy.de(antes), d = PartidaFantasy.de(despues);
  if (d == null) return (perfil, const []);
  final novedades = <Novedad>[];
  var p = perfil;
  final semanasAntes = a?.semanas.length ?? 0;
  var ganadas = 0, jugadas = 0;
  for (final s in d.semanas.skip(semanasAntes)) {
    jugadas++;
    for (final c in s.cruces) {
      if ((c.a == PartidaFantasy.usuario || c.b == PartidaFantasy.usuario) && c.ganador == PartidaFantasy.usuario) {
        ganadas++;
      }
    }
  }
  if (jugadas > 0) {
    final xp = ganadas * 25 + (jugadas - ganadas) * 8;
    p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + ganadas * 8);
    novedades.add(Novedad('+$xp XP · +${ganadas * 8} monedas'));
  }
  if (d.fase == FaseFantasy.terminada && a?.fase != FaseFantasy.terminada) {
    final puesto = d.puestoUsuario;
    final (xp, monedas) = switch (puesto) {
      1 => (400, 200),
      2 => (200, 100),
      3 => (100, 50),
      _ => (50, 0),
    };
    p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
    novedades.add(
      Novedad(
        puesto == 1 ? '¡Campeón del Fantasy NBA!' : 'Fantasy NBA terminado: puesto $puesto',
        detalle: '+$xp XP · +$monedas monedas',
        destacada: puesto == 1,
      ),
    );
    if (puesto == 1 && !p.logros.containsKey(Logro.campeonFantasy)) {
      p = p.copyWith(logros: {...p.logros, Logro.campeonFantasy: DateTime.now().millisecondsSinceEpoch});
    }
  }
  return (p, novedades);
}
