import '../entities/jugador.dart';
import '../entities/perfil.dart';
import '../entities/temporada.dart';
import '../motor.dart' show LineaEstadistica;

/// Qué se mide para evolucionar una carta del álbum.
enum MetricaEvo {
  puntos('Puntos', 'pts'),
  triples('Triples', 'triples'),
  rebotes('Rebotes', 'reb'),
  asistencias('Asistencias', 'ast'),
  robos('Robos', 'robos'),
  tapones('Tapones', 'tapones'),
  partidos('Partidos jugados', 'partidos'),
  victorias('Victorias', 'victorias'),
  partidos30('Partidos de 30+ puntos', 'de 30+');

  const MetricaEvo(this.nombre, this.unidad);
  final String nombre;
  final String unidad;
}

/// Un objetivo de evolución: 5 etapas, cada una suma +1 de media (solo en los modos del álbum).
class ObjetivoEvo {
  const ObjetivoEvo(this.id, this.nombre, this.metrica, this.metas);

  final String id;
  final String nombre;
  final MetricaEvo metrica;

  /// Acumulado necesario para cada etapa (5 valores crecientes).
  final List<int> metas;

  String get descripcion => '$nombre: ${metas.last} ${metrica.unidad}';
}

/// Estado de evolución de una carta.
class EvoCarta {
  const EvoCarta({required this.objetivoId, this.progreso = 0, this.etapa = 0});

  final String objetivoId;

  /// Acumulado desde que empezó la evolución.
  final int progreso;

  /// Etapas ya cobradas (cada una = +1 de media).
  final int etapa;

  ObjetivoEvo? get objetivo => Evoluciones.porId(objetivoId);
  bool get completa => etapa >= Evoluciones.maxNivel;

  /// Meta de la próxima etapa (null si ya está completa).
  int? get proximaMeta => completa ? null : objetivo?.metas[etapa];

  /// ¿Hay una etapa lista para cobrar?
  bool get listaParaCobrar => proximaMeta != null && progreso >= proximaMeta!;

  EvoCarta copyWith({int? progreso, int? etapa}) =>
      EvoCarta(objetivoId: objetivoId, progreso: progreso ?? this.progreso, etapa: etapa ?? this.etapa);

  factory EvoCarta.fromJson(Map<String, dynamic> j) =>
      EvoCarta(objetivoId: j['o'] as String, progreso: j['p'] as int? ?? 0, etapa: j['e'] as int? ?? 0);

  Map<String, dynamic> toJson() => {'o': objetivoId, 'p': progreso, 'e': etapa};
}

/// Evoluciones de cartas del álbum.
///
/// REGLA: la media evolucionada solo cuenta en los modos que usan tu álbum (`ModoJuego.usaAlbum`) y
/// en el draft con la regla "Mi colección". En el clásico, el draft común, los rivales, la escalera,
/// etc. la carta vale lo que dice el catálogo. El progreso, en cambio, se gana jugando con la carta
/// en cualquier modo.
///
/// Uso para otros modos:
/// ```dart
/// final media = mediaEvolucionada(perfil, jugador, usaAlbum: true);
/// final carta = aplicarEvolucion(perfil, jugador, usaAlbum: true); // copia con la media nueva
/// final plantel = aplicarEvoluciones(perfil, jugadores, usaAlbum: modo.usaAlbum);
/// ```
/// Para sumar progreso desde un modo propio: `registrarEvolucion(perfil, cartaId, MetricaEvo.victorias, 1)`.
class Evoluciones {
  const Evoluciones._();

  static const maxNivel = 5;

  /// Cuántas cartas pueden evolucionar a la vez (hay que elegir).
  static const maxActivas = 3;

  static const objetivos = <ObjetivoEvo>[
    ObjetivoEvo('triples', 'Francotirador', MetricaEvo.triples, [10, 25, 50, 90, 150]),
    ObjetivoEvo('puntos', 'Goleador', MetricaEvo.puntos, [100, 300, 600, 1000, 1600]),
    ObjetivoEvo('rebotes', 'Dueño del rebote', MetricaEvo.rebotes, [40, 120, 250, 450, 700]),
    ObjetivoEvo('asistencias', 'Cerebro', MetricaEvo.asistencias, [30, 90, 180, 320, 500]),
    ObjetivoEvo('robos', 'Ladrón de guante blanco', MetricaEvo.robos, [8, 20, 40, 70, 110]),
    ObjetivoEvo('tapones', 'Muralla', MetricaEvo.tapones, [8, 20, 40, 70, 110]),
    ObjetivoEvo('victorias', 'Ganador', MetricaEvo.victorias, [3, 8, 16, 28, 45]),
    ObjetivoEvo('partidos', 'Incansable', MetricaEvo.partidos, [5, 15, 30, 55, 90]),
    ObjetivoEvo('noche30', 'Noches de 30', MetricaEvo.partidos30, [1, 3, 6, 10, 16]),
  ];

  static ObjetivoEvo? porId(String id) => objetivos.where((o) => o.id == id).firstOrNull;
}

/// Evoluciones del perfil, sin tocar la media de nadie por sí solas.
class PerfilEvoluciones {
  const PerfilEvoluciones([this.cartas = const {}]);

  final Map<String, EvoCarta> cartas;

  static PerfilEvoluciones de(PerfilEntrenador p) => PerfilEvoluciones.fromJson(p.evoluciones);

  factory PerfilEvoluciones.fromJson(Map<String, dynamic> j) => PerfilEvoluciones({
    for (final e in (j['cartas'] as Map<String, dynamic>? ?? const {}).entries)
      e.key: EvoCarta.fromJson(e.value as Map<String, dynamic>),
  });

  Map<String, dynamic> toJson() => {
    'cartas': {for (final e in cartas.entries) e.key: e.value.toJson()},
  };

  PerfilEntrenador guardarEn(PerfilEntrenador p) => p.copyWith(evoluciones: cartas.isEmpty ? const {} : toJson());

  /// Evoluciones en curso (incompletas).
  int get activas => cartas.values.where((c) => !c.completa).length;

  bool puedeEmpezar(String cartaId) => !cartas.containsKey(cartaId) && activas < Evoluciones.maxActivas;

  PerfilEvoluciones empezar(String cartaId, String objetivoId) {
    if (!puedeEmpezar(cartaId) || Evoluciones.porId(objetivoId) == null) return this;
    return PerfilEvoluciones({...cartas, cartaId: EvoCarta(objetivoId: objetivoId)});
  }

  /// Cobra todas las etapas listas de [cartaId]; devuelve cuántas.
  (PerfilEvoluciones, int) cobrar(String cartaId) {
    var c = cartas[cartaId];
    if (c == null) return (this, 0);
    var n = 0;
    while (c!.listaParaCobrar) {
      c = c.copyWith(etapa: c.etapa + 1);
      n++;
    }
    return n == 0 ? (this, 0) : (PerfilEvoluciones({...cartas, cartaId: c}), n);
  }

  PerfilEvoluciones sumar(String cartaId, MetricaEvo m, int cantidad) {
    final c = cartas[cartaId];
    if (c == null || c.completa || cantidad <= 0 || c.objetivo?.metrica != m) return this;
    // El progreso se frena en la meta final: no hace falta acumular de más.
    final tope = c.objetivo!.metas.last;
    return PerfilEvoluciones({...cartas, cartaId: c.copyWith(progreso: (c.progreso + cantidad).clamp(0, tope))});
  }
}

/// Etapas cobradas de una carta (0 a 5): lo que se suma a su media en los modos del álbum.
int nivelEvo(PerfilEntrenador p, String cartaId) {
  if (p.evoluciones.isEmpty) return 0;
  return PerfilEvoluciones.de(p).cartas[cartaId]?.etapa ?? 0;
}

/// Media de [j] con su evolución. Fuera de los modos del álbum ([usaAlbum] falso) es la del catálogo.
int mediaEvolucionada(PerfilEntrenador p, Jugador j, {required bool usaAlbum}) =>
    usaAlbum ? (j.media + nivelEvo(p, j.id)).clamp(0, 99) : j.media;

/// Copia de [j] con la media evolucionada (o la misma carta si no aplica o no evolucionó).
Jugador aplicarEvolucion(PerfilEntrenador p, Jugador j, {required bool usaAlbum}) {
  final media = mediaEvolucionada(p, j, usaAlbum: usaAlbum);
  return media == j.media ? j : j.conMedia(media);
}

List<Jugador> aplicarEvoluciones(PerfilEntrenador p, Iterable<Jugador> js, {required bool usaAlbum}) => [
  for (final j in js) aplicarEvolucion(p, j, usaAlbum: usaAlbum),
];

/// Con el nivel ya conocido (lo usa `Liga`, que no ve el perfil).
Jugador conNivelEvo(Jugador j, int nivel) => nivel <= 0 ? j : j.conMedia((j.media + nivel).clamp(0, 99));

/// ¿Esta partida usa las cartas del álbum (y por lo tanto sus evoluciones)?
bool partidaUsaAlbum(Temporada t) => t.modoJuego.usaAlbum || t.regla == ReglaDraft.coleccion;

/// Suma progreso a una carta desde un modo propio.
PerfilEntrenador registrarEvolucion(PerfilEntrenador p, String cartaId, MetricaEvo m, int cantidad) {
  if (p.evoluciones.isEmpty) return p;
  final antes = PerfilEvoluciones.de(p);
  final despues = antes.sumar(cartaId, m, cantidad);
  return identical(antes, despues) ? p : despues.guardarEn(p);
}

/// Progreso de las evoluciones a partir de lo que pasó entre [antes] y [despues] (lo llama
/// `Progreso.aplicar`): líneas de tus jugadores, victorias y noches de 30. Los partidos de 30+ solo
/// se detectan cuando se jugó un único partido entre los dos estados (en vivo); una simulación en
/// bloque cuenta puntos, triples, etc., pero no noches de 30.
PerfilEntrenador avanzarEvoluciones(PerfilEntrenador p, Temporada antes, Temporada despues) {
  if (p.evoluciones.isEmpty) return p;
  var evo = PerfilEvoluciones.de(p);
  if (evo.cartas.isEmpty) return p;
  final usuario = despues.franquiciaUsuarioId;
  final jugadosAntes = {
    for (final x in antes.calendario)
      if (x.jugado) x.id,
  };
  var ganados = 0, jugados = 0;
  for (final x in despues.calendario) {
    if (!x.jugado || jugadosAntes.contains(x.id) || !x.participa(usuario)) continue;
    jugados++;
    if (x.ganadorId == usuario) ganados++;
  }
  final propios = {
    for (final j in [...despues.plantel.jugadores, ...despues.suplentes]) j.id,
  };
  for (final id in propios) {
    if (!evo.cartas.containsKey(id)) continue;
    final a = LineaEstadistica(), d = LineaEstadistica();
    for (final l in [antes.lineas[id], antes.lineasPlayoffs[id]]) {
      if (l != null) a.sumar(l);
    }
    for (final l in [despues.lineas[id], despues.lineasPlayoffs[id]]) {
      if (l != null) d.sumar(l);
    }
    final pj = d.pj - a.pj;
    if (pj <= 0) continue;
    evo = evo
        .sumar(id, MetricaEvo.partidos, pj)
        .sumar(id, MetricaEvo.puntos, d.pts - a.pts)
        .sumar(id, MetricaEvo.triples, d.t3I - a.t3I)
        .sumar(id, MetricaEvo.rebotes, d.reb - a.reb)
        .sumar(id, MetricaEvo.asistencias, d.ast - a.ast)
        .sumar(id, MetricaEvo.robos, d.rob - a.rob)
        .sumar(id, MetricaEvo.tapones, d.tap - a.tap);
    // Victorias: las del equipo mientras jugó (aproximado: jugó todos los partidos nuevos).
    if (jugados > 0) evo = evo.sumar(id, MetricaEvo.victorias, (ganados * pj / jugados).round());
    if (pj == 1 && d.pts - a.pts >= 30) evo = evo.sumar(id, MetricaEvo.partidos30, 1);
  }
  return evo.guardarEn(p);
}
