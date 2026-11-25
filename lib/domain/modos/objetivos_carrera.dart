import 'dart:math';

import '../entities/enum_tolerante.dart';
import '../entities/posicion.dart';
import '../entities/rol_cancha.dart';
import 'carrera_jugador.dart';

// Objetivos de Mi carrera.
//
//  * De temporada: 22 tipos en 5 familias y 4 niveles. Al arrancar el año el DT te ofrece 8 y aceptás entre 4 y 6.
//  * De carrera: metas de varios años (10.000 puntos, primer anillo…), con premio una sola vez.
//  * Mini-objetivos por mes: uno cada 14 partidos, con premio chico.

/// Qué tan difícil es un objetivo y cuántos puntos de habilidad da.
enum NivelObjetivo {
  facil('Fácil', 1),
  normal('Normal', 2),
  dificil('Difícil', 4),
  elite('Élite', 6);

  const NivelObjetivo(this.etiqueta, this.puntos);
  final String etiqueta;
  final int puntos;
}

/// Familias de objetivos de temporada.
enum FamiliaObjetivo {
  estadistica('Estadística'),
  equipo('Equipo'),
  personal('Personal'),
  vestuario('Vestuario');

  const FamiliaObjetivo(this.etiqueta);
  final String etiqueta;
}

enum TipoObjetivo {
  // --- ya existían (los nombres se guardan en las partidas) ---
  puntos(FamiliaObjetivo.estadistica),
  rebotes(FamiliaObjetivo.estadistica),
  asistencias(FamiliaObjetivo.estadistica),
  defensa(FamiliaObjetivo.estadistica),
  victorias(FamiliaObjetivo.equipo),
  playoffs(FamiliaObjetivo.equipo),
  allStar(FamiliaObjetivo.personal),
  partidos(FamiliaObjetivo.personal),
  // --- nuevos ---
  robos(FamiliaObjetivo.estadistica),
  tapones(FamiliaObjetivo.estadistica),
  tiroCampo(FamiliaObjetivo.estadistica),
  triples(FamiliaObjetivo.estadistica),
  libres(FamiliaObjetivo.estadistica),
  triplesPorPartido(FamiliaObjetivo.estadistica),
  partidos30(FamiliaObjetivo.estadistica),
  dobles(FamiliaObjetivo.estadistica),
  triplesDobles(FamiliaObjetivo.estadistica),
  campeon(FamiliaObjetivo.equipo),
  jugadorDelMes(FamiliaObjetivo.personal),
  relacion(FamiliaObjetivo.vestuario),
  moral(FamiliaObjetivo.vestuario),
  confianza(FamiliaObjetivo.vestuario),
  fans(FamiliaObjetivo.vestuario);

  const TipoObjetivo(this.familia);
  final FamiliaObjetivo familia;

  /// Se muestra como número entero (victorias, partidos, cantidades) y no con decimales.
  bool get entero => const {
    victorias,
    partidos,
    partidos30,
    dobles,
    triplesDobles,
    jugadorDelMes,
    relacion,
    moral,
    confianza,
    fans,
  }.contains(this);

  /// Sí o no (se cumple o no): no hay "avance" para mostrar.
  bool get siNo => this == playoffs || this == allStar || this == campeon;
}

/// Un objetivo que te pide el DT para la temporada.
class ObjetivoTemporada {
  const ObjetivoTemporada(this.tipo, this.meta, {this.nivel = NivelObjetivo.normal});

  final TipoObjetivo tipo;
  final double meta;
  final NivelObjetivo nivel;

  String get texto => switch (tipo) {
    TipoObjetivo.puntos => 'Promediar ${_n(meta)} puntos',
    TipoObjetivo.rebotes => 'Promediar ${_n(meta)} rebotes',
    TipoObjetivo.asistencias => 'Promediar ${_n(meta)} asistencias',
    TipoObjetivo.defensa => 'Sumar ${_n(meta)} robos + tapones por partido',
    TipoObjetivo.victorias => 'Ganar ${meta.round()} partidos con el equipo',
    TipoObjetivo.playoffs => 'Meter al equipo en los playoffs',
    TipoObjetivo.allStar => 'Ser All-Star',
    TipoObjetivo.partidos => 'Jugar ${meta.round()} partidos',
    TipoObjetivo.robos => 'Promediar ${_n(meta)} robos',
    TipoObjetivo.tapones => 'Promediar ${_n(meta)} tapones',
    TipoObjetivo.tiroCampo => 'Acertar el ${_n(meta)} % de los tiros de campo',
    TipoObjetivo.triples => 'Acertar el ${_n(meta)} % de los triples',
    TipoObjetivo.libres => 'Acertar el ${_n(meta)} % de los libres',
    TipoObjetivo.triplesPorPartido => 'Meter ${_n(meta)} triples por partido',
    TipoObjetivo.partidos30 => 'Tener ${meta.round()} partidos de 30 puntos o más',
    TipoObjetivo.dobles => 'Lograr ${meta.round()} dobles-dobles',
    TipoObjetivo.triplesDobles => 'Lograr ${meta.round()} triples-dobles',
    TipoObjetivo.campeon => 'Salir campeón',
    TipoObjetivo.jugadorDelMes => 'Ser Jugador del mes ${meta.round() == 1 ? 'una vez' : '${meta.round()} veces'}',
    TipoObjetivo.relacion => 'Llegar a ${meta.round()} de relación con el vestuario',
    TipoObjetivo.moral => 'Terminar con ${meta.round()} de ánimo',
    TipoObjetivo.confianza => 'Llegar a ${meta.round()} de confianza del DT',
    TipoObjetivo.fans => 'Llegar a ${meta.round()} de fans',
  };

  static String _n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Valor actual del objetivo y si ya se cumple, con lo que se sabe de la temporada.
  (double, bool) avance(MarcaTemporada m) {
    // Los porcentajes y los promedios finos no cuentan con pocos partidos.
    final muestra = m.pj >= 20;
    final v = switch (tipo) {
      TipoObjetivo.puntos => m.ppg,
      TipoObjetivo.rebotes => m.rpg,
      TipoObjetivo.asistencias => m.apg,
      TipoObjetivo.defensa => m.defensaPorPartido,
      TipoObjetivo.victorias => m.victorias.toDouble(),
      TipoObjetivo.playoffs => m.playoffs ? 1.0 : 0.0,
      TipoObjetivo.allStar => m.allStar ? 1.0 : 0.0,
      TipoObjetivo.partidos => m.pj.toDouble(),
      TipoObjetivo.robos => m.robPorPartido,
      TipoObjetivo.tapones => m.tapPorPartido,
      TipoObjetivo.tiroCampo => muestra ? m.pctTc * 100 : 0.0,
      TipoObjetivo.triples => muestra ? m.pctT3 * 100 : 0.0,
      TipoObjetivo.libres => muestra ? m.pctTl * 100 : 0.0,
      TipoObjetivo.triplesPorPartido => m.t3PorPartido,
      TipoObjetivo.partidos30 => m.p30.toDouble(),
      TipoObjetivo.dobles => m.dobles.toDouble(),
      TipoObjetivo.triplesDobles => m.triplesDobles.toDouble(),
      TipoObjetivo.campeon => m.campeon ? 1.0 : 0.0,
      TipoObjetivo.jugadorDelMes => m.jugadorDelMes.toDouble(),
      TipoObjetivo.relacion => m.relacion.toDouble(),
      TipoObjetivo.moral => m.moral.toDouble(),
      TipoObjetivo.confianza => m.confianza.toDouble(),
      TipoObjetivo.fans => m.fans.toDouble(),
    };
    return (v, v >= meta - 1e-9);
  }

  Map<String, dynamic> toJson() => {'t': tipo.name, 'm': meta, 'n': nivel.name};

  factory ObjetivoTemporada.fromJson(Map<String, dynamic> j) => ObjetivoTemporada(
    TipoObjetivo.values.porNombreO(j['t']),
    (j['m'] as num).toDouble(),
    nivel: NivelObjetivo.values.asNameMap()[j['n']] ?? NivelObjetivo.normal,
  );
}

/// Lo que va haciendo el jugador en la temporada (por partido) y el equipo.
class MarcaTemporada {
  const MarcaTemporada({
    required this.pj,
    required this.ppg,
    required this.rpg,
    required this.apg,
    required this.defensaPorPartido,
    required this.victorias,
    required this.derrotas,
    this.playoffs = false,
    this.allStar = false,
    this.robPorPartido = 0,
    this.tapPorPartido = 0,
    this.pctTc = 0,
    this.pctT3 = 0,
    this.pctTl = 0,
    this.t3PorPartido = 0,
    this.p30 = 0,
    this.dobles = 0,
    this.triplesDobles = 0,
    this.campeon = false,
    this.jugadorDelMes = 0,
    this.relacion = 0,
    this.moral = 0,
    this.confianza = 0,
    this.fans = 0,
  });

  final int pj;
  final double ppg, rpg, apg, defensaPorPartido;
  final int victorias, derrotas;
  final bool playoffs, allStar;
  final double robPorPartido, tapPorPartido, pctTc, pctT3, pctTl, t3PorPartido;

  /// Partidos de 30+, dobles-dobles y triples-dobles de la temporada.
  final int p30, dobles, triplesDobles;
  final bool campeon;
  final int jugadorDelMes, relacion, moral, confianza, fans;

  MarcaTemporada conCampeon(bool c) => MarcaTemporada(
    pj: pj,
    ppg: ppg,
    rpg: rpg,
    apg: apg,
    defensaPorPartido: defensaPorPartido,
    victorias: victorias,
    derrotas: derrotas,
    playoffs: playoffs,
    allStar: allStar,
    robPorPartido: robPorPartido,
    tapPorPartido: tapPorPartido,
    pctTc: pctTc,
    pctT3: pctT3,
    pctTl: pctTl,
    t3PorPartido: t3PorPartido,
    p30: p30,
    dobles: dobles,
    triplesDobles: triplesDobles,
    campeon: c,
    jugadorDelMes: jugadorDelMes,
    relacion: relacion,
    moral: moral,
    confianza: confianza,
    fans: fans,
  );
}

// ---------- Objetivos de carrera ----------

/// Metas de varias temporadas. Cada una se cumple una sola vez y da puntos de habilidad y fans.
enum ObjetivoCarrera {
  puntos10k('10.000 puntos de carrera', 6),
  puntos20k('20.000 puntos de carrera', 10),
  puntos30k('30.000 puntos de carrera', 16),
  partidos500('500 partidos jugados', 5),
  partidos1000('1.000 partidos jugados', 10),
  anillo1('Tu primer anillo', 8),
  anillo3('Tres anillos', 12),
  anillo5('Cinco anillos', 18),
  allStar5('5 veces All-Star', 8),
  allStar10('10 veces All-Star', 14),
  allNba3('3 veces en el mejor quinteto', 10),
  mvp1('Ser MVP de la liga', 14),
  triplesDobles10('10 triples-dobles', 6),
  triplesDobles50('50 triples-dobles', 12),
  partidos40x5('5 partidos de 40 puntos o más', 6),
  partidos50('Un partido de 50 puntos', 8);

  const ObjetivoCarrera(this.texto, this.puntos);
  final String texto;
  final int puntos;

  /// Cuánto lleva y cuánto pide (para la barra de progreso).
  (int, int) avance(EstadoCarrera e) {
    final l = e.legado;
    return switch (this) {
      puntos10k => (l.puntos, 10000),
      puntos20k => (l.puntos, 20000),
      puntos30k => (l.puntos, 30000),
      partidos500 => (l.partidos, 500),
      partidos1000 => (l.partidos, 1000),
      anillo1 => (l.anillos, 1),
      anillo3 => (l.anillos, 3),
      anillo5 => (l.anillos, 5),
      allStar5 => (l.allStars, 5),
      allStar10 => (l.allStars, 10),
      allNba3 => (l.allNba, 3),
      mvp1 => (l.mvps, 1),
      triplesDobles10 => (e.uso['c:td'] ?? 0, 10),
      triplesDobles50 => (e.uso['c:td'] ?? 0, 50),
      partidos40x5 => (e.uso['c:p40'] ?? 0, 5),
      partidos50 => (e.uso['c:p50'] ?? 0, 1),
    };
  }

  bool lograda(EstadoCarrera e) => (e.uso['oc:$name'] ?? 0) > 0;
}

// ---------- Mini-objetivos por mes ----------

/// Una meta corta de un "mes" (14 partidos de temporada regular).
enum MiniObjetivo {
  puntos('Promediar %s puntos en el mes'),
  rebotes('Promediar %s rebotes en el mes'),
  asistencias('Promediar %s asistencias en el mes'),
  victorias('Ganar %s partidos en el mes'),
  partidos25('Tener %s partidos de 25 puntos o más');

  const MiniObjetivo(this.plantilla);
  final String plantilla;

  static const partidosPorMes = 14;
}

/// Servicios de objetivos. Todo determinístico y sin pantalla.
class ObjetivosCarrera {
  const ObjetivosCarrera._();

  static const minAceptados = 4, maxAceptados = 6, cantidadOfrecida = 8;

  // ---- ofrecidos de temporada ----

  static double _redondear(double v, double paso) => max(paso, (v / paso).round() * paso);

  /// La meta de [tipo] en [nivel] para [e], según lo que viene haciendo.
  static double meta(TipoObjetivo tipo, NivelObjetivo nivel, EstadoCarrera e) {
    final s = e.carta.stats;
    final u = e.historial.isEmpty ? null : e.historial.last;
    final i = nivel.index;
    const m = [0.9, 1.03, 1.15, 1.3];
    double escala(double base, double paso) => _redondear(base * m[i], paso);
    double pct(double base) => (base * 100).clamp(30, 95) + const [-2.0, 0.0, 2.0, 4.0][i];
    int porNivel(List<int> v) => v[i];
    final cuerpo = s.rpp + s.app;
    return switch (tipo) {
      TipoObjetivo.puntos => escala(u?.pts ?? s.ppp, 0.5),
      TipoObjetivo.rebotes => escala(u?.reb ?? s.rpp, 0.5),
      TipoObjetivo.asistencias => escala(u?.ast ?? s.app, 0.5),
      TipoObjetivo.defensa => escala(s.robP + s.tapP, 0.1),
      TipoObjetivo.robos => escala(s.robP, 0.1),
      TipoObjetivo.tapones => escala(s.tapP, 0.1),
      TipoObjetivo.tiroCampo => pct(s.pctTc),
      TipoObjetivo.triples => pct(s.pctT3),
      TipoObjetivo.libres => pct(s.pctTl),
      TipoObjetivo.triplesPorPartido => escala(max(0.6, s.ppp * 0.09), 0.1),
      TipoObjetivo.partidos30 => porNivel(s.ppp >= 24 ? const [4, 10, 18, 28] : const [1, 3, 6, 10]).toDouble(),
      TipoObjetivo.dobles => porNivel(cuerpo >= 12 ? const [8, 18, 30, 45] : const [3, 8, 14, 22]).toDouble(),
      TipoObjetivo.triplesDobles => porNivel(cuerpo >= 14 ? const [2, 5, 10, 18] : const [1, 2, 4, 7]).toDouble(),
      TipoObjetivo.victorias => (e.media >= 88 ? const [48, 54, 60, 66] : (e.media >= 80 ? const [40, 47, 54, 60] : const [30, 38, 46, 52]))[i].toDouble(),
      TipoObjetivo.playoffs || TipoObjetivo.allStar || TipoObjetivo.campeon => 1,
      TipoObjetivo.partidos => porNivel(const [50, 60, 70, 78]).toDouble(),
      TipoObjetivo.jugadorDelMes => porNivel(const [1, 1, 2, 3]).toDouble(),
      TipoObjetivo.relacion => porNivel(const [55, 65, 78, 90]).toDouble(),
      TipoObjetivo.moral => porNivel(const [55, 65, 78, 90]).toDouble(),
      TipoObjetivo.confianza => porNivel(const [55, 65, 78, 90]).toDouble(),
      TipoObjetivo.fans => porNivel(const [45, 60, 75, 90]).toDouble(),
    };
  }

  /// Niveles que tienen sentido para un tipo (los de sí o no tienen uno solo).
  static List<NivelObjetivo> _niveles(TipoObjetivo t, EstadoCarrera e) => switch (t) {
    TipoObjetivo.playoffs => const [NivelObjetivo.normal],
    TipoObjetivo.campeon => const [NivelObjetivo.elite],
    TipoObjetivo.allStar => [e.media >= 86 ? NivelObjetivo.normal : NivelObjetivo.dificil],
    TipoObjetivo.partidos => const [NivelObjetivo.facil, NivelObjetivo.normal],
    _ => NivelObjetivo.values,
  };

  /// Los 8 objetivos que el DT te ofrece para la temporada [e.numero]: de todas las familias y de varios niveles.
  static List<ObjetivoTemporada> ofrecer(EstadoCarrera e, Random azar) {
    final defensivo = const {
      RolCancha.baseDefensivo,
      RolCancha.cerrojoDefensivo,
      RolCancha.protectorAro,
      RolCancha.especialista3D,
      RolCancha.inyeccionEnergia,
    }.contains(e.carta.rol);
    final principal = defensivo
        ? TipoObjetivo.defensa
        : switch (e.posicion) {
            Posicion.base => TipoObjetivo.asistencias,
            Posicion.alaPivot || Posicion.pivot => TipoObjetivo.rebotes,
            _ => TipoObjetivo.puntos,
          };
    final s = e.carta.stats;
    T uno<T>(List<T> l) => l[azar.nextInt(l.length)];
    final secundaria = uno([
      for (final t in [TipoObjetivo.puntos, TipoObjetivo.rebotes, TipoObjetivo.asistencias, TipoObjetivo.robos, TipoObjetivo.tapones])
        if (t != principal) t,
    ]);
    final eficiencia = uno([TipoObjetivo.tiroCampo, if (s.pctT3 > 0.2) TipoObjetivo.triples, TipoObjetivo.libres]);
    final conteo = uno([
      if (s.ppp >= 20) TipoObjetivo.partidos30,
      TipoObjetivo.dobles,
      if (s.rpp + s.app >= 10) TipoObjetivo.triplesDobles,
      if (s.pctT3 > 0.2) TipoObjetivo.triplesPorPartido,
    ]);
    final equipo1 = TipoObjetivo.victorias;
    final equipo2 = e.numero.isOdd || e.media < 80 ? TipoObjetivo.playoffs : TipoObjetivo.campeon;
    final personal = e.media >= 78 ? TipoObjetivo.allStar : TipoObjetivo.partidos;
    final vestuario = uno([TipoObjetivo.relacion, TipoObjetivo.moral, TipoObjetivo.confianza, TipoObjetivo.fans]);
    final tipos = [principal, secundaria, eficiencia, conteo, equipo1, equipo2, personal, vestuario];
    // Niveles repartidos: de lo fácil a lo élite, mezclados.
    final reparto = [NivelObjetivo.normal, NivelObjetivo.normal, NivelObjetivo.facil, NivelObjetivo.dificil, NivelObjetivo.normal, NivelObjetivo.facil, NivelObjetivo.dificil, NivelObjetivo.elite]..shuffle(azar);
    final ofrecidos = <ObjetivoTemporada>[];
    for (var k = 0; k < tipos.length; k++) {
      final permitidos = _niveles(tipos[k], e);
      final nivel = permitidos.contains(reparto[k]) ? reparto[k] : permitidos[azar.nextInt(permitidos.length)];
      ofrecidos.add(ObjetivoTemporada(tipos[k], meta(tipos[k], nivel, e), nivel: nivel));
    }
    return ofrecidos;
  }

  /// Los que se aceptan sin que elijas: los 4 de menor nivel (en el orden ofrecido).
  static List<ObjetivoTemporada> porDefecto(List<ObjetivoTemporada> ofrecidos) {
    final orden = [...ofrecidos]..sort((a, b) => a.nivel.index.compareTo(b.nivel.index));
    final elegidos = orden.take(minAceptados).toSet();
    return [
      for (final o in ofrecidos)
        if (elegidos.contains(o)) o,
    ];
  }

  /// Se puede cambiar la elección hasta que se juega el primer partido de la temporada.
  static bool puedeElegir(EstadoCarrera e) => e.snapPj == 0 && (e.uso['sc:pj'] ?? 0) == 0 && e.ofrecidos.isNotEmpty;

  /// Acepta los ofrecidos de [indices] (entre [minAceptados] y [maxAceptados]).
  static EstadoCarrera elegir(EstadoCarrera e, Set<int> indices) {
    final validos = indices.where((i) => i >= 0 && i < e.ofrecidos.length).toList()..sort();
    if (!puedeElegir(e) || validos.length < minAceptados || validos.length > maxAceptados) return e;
    return e.copyWith(objetivos: [for (final i in validos) e.ofrecidos[i]]);
  }

  /// Puntos de habilidad que dan los [resultados] (objetivo, cumplido), con el factor de edad ya aplicado afuera.
  static int puntosDe(List<(ObjetivoTemporada, bool)> resultados) =>
      resultados.where((r) => r.$2).fold(0, (a, r) => a + r.$1.nivel.puntos);

  // ---- objetivos de carrera ----

  /// Los de carrera que se cumplieron ahora (y todavía no estaban marcados).
  static List<ObjetivoCarrera> nuevosDeCarrera(EstadoCarrera e) => [
    for (final o in ObjetivoCarrera.values)
      if (!o.lograda(e) && o.avance(e).$1 >= o.avance(e).$2) o,
  ];

  /// Marca los [logrados] y suma sus premios (puntos, fans y una línea en la historia).
  static EstadoCarrera cobrarCarrera(EstadoCarrera e, List<ObjetivoCarrera> logrados) {
    if (logrados.isEmpty) return e;
    final pts = logrados.fold(0, (a, o) => a + o.puntos);
    return e.copyWith(
      phBanco: e.phBanco + pts,
      fans: e.fans + 3 * logrados.length,
      uso: {
        ...e.uso,
        for (final o in logrados) 'oc:${o.name}': 1,
        'dg:obj': (e.uso['dg:obj'] ?? 0) + pts * 100,
      },
      hitos: [...e.hitos, for (final o in logrados) '${e.etiquetaTemporada}: objetivo de carrera cumplido — ${o.texto}.'],
    );
  }

  // ---- mini-objetivos por mes ----

  static int mesActual(EstadoCarrera e) => (e.uso['sc:pj'] ?? 0) ~/ MiniObjetivo.partidosPorMes + 1;

  /// El mini-objetivo del mes en curso (null si todavía no se fijó o ya terminó la temporada regular).
  static (MiniObjetivo, double)? miniActual(EstadoCarrera e) {
    final t = e.uso['mo:tipo'], m = e.uso['mo:meta'];
    if (t == null || m == null || t < 0 || t >= MiniObjetivo.values.length) return null;
    return (MiniObjetivo.values[t], m / 10);
  }

  /// Fija el mini-objetivo del mes según lo que venís haciendo (determinístico por carrera, temporada y mes).
  static Map<String, int> fijarMini(EstadoCarrera e) {
    final azar = Random(e.raiz.hashCode ^ (e.numero * 131) ^ (mesActual(e) * 17));
    final s = e.carta.stats;
    final u = e.historial.isEmpty ? null : e.historial.last;
    final tipo = MiniObjetivo.values[azar.nextInt(MiniObjetivo.values.length)];
    final double meta = switch (tipo) {
      MiniObjetivo.puntos => _redondear((u?.pts ?? s.ppp) * 1.03, 0.5),
      MiniObjetivo.rebotes => _redondear((u?.reb ?? s.rpp) * 1.03, 0.5),
      MiniObjetivo.asistencias => _redondear((u?.ast ?? s.app) * 1.03, 0.5),
      MiniObjetivo.victorias => (e.media >= 85 ? 9 : (e.media >= 78 ? 8 : 7)).toDouble(),
      MiniObjetivo.partidos25 => (s.ppp >= 24 ? 5 : (s.ppp >= 18 ? 3 : 1)).toDouble(),
    };
    return {'mo:tipo': tipo.index, 'mo:meta': (meta * 10).round()};
  }

  /// Valor que lleva el mes en el mini-objetivo [tipo].
  static double valorMes(MiniObjetivo tipo, Map<String, int> uso) {
    final n = max(1, uso['mes:n'] ?? 0);
    return switch (tipo) {
      MiniObjetivo.puntos => (uso['mes:pts'] ?? 0) / n,
      MiniObjetivo.rebotes => (uso['mes:reb'] ?? 0) / n,
      MiniObjetivo.asistencias => (uso['mes:ast'] ?? 0) / n,
      MiniObjetivo.victorias => (uso['mes:w'] ?? 0).toDouble(),
      MiniObjetivo.partidos25 => (uso['mes:p25'] ?? 0).toDouble(),
    };
  }

  static String textoMini(MiniObjetivo t, double meta) =>
      t.plantilla.replaceFirst('%s', t == MiniObjetivo.victorias || t == MiniObjetivo.partidos25 ? '${meta.round()}' : meta.toStringAsFixed(1).replaceAll('.', ','));
}
