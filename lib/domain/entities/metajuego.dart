/// Metajuego que se arrastra entre partidas: misiones, pase de temporada offline, cosméticos y
/// rivalidades. Vive dentro del perfil del entrenador ([PerfilEntrenador.metajuego]).
library;

enum TipoMision {
  ganarPartidos('Ganá {n} partidos', 'partidos ganados'),
  ganarPorMargen('Ganá {n} partidos por 15 o más', 'palizas'),
  triples('Meté {n} triples con tu plantel', 'triples'),
  rebotes('Bajá {n} rebotes con tu plantel', 'rebotes'),
  asistencias('Repartí {n} asistencias con tu plantel', 'asistencias'),
  jugarEnVivo('Jugá {n} partido(s) en vivo', 'en vivo'),
  ganarPlayoff('Ganá {n} partidos de playoffs', 'partidos de playoffs'),
  ficharSuplente('Fichá {n} suplente(s) para el banco largo', 'fichajes'),
  ganarDesafio('Ganá {n} partido(s) de un desafío (Racha, Camino al anillo…)', 'desafíos');

  const TipoMision(this.plantilla, this.unidad);
  final String plantilla;
  final String unidad;

  String texto(int n) => plantilla.replaceAll('{n}', '$n');
}

/// Una misión del día o de la semana, con su avance.
class Mision {
  const Mision({
    required this.id,
    required this.tipo,
    required this.objetivo,
    required this.semanal,
    this.progreso = 0,
    this.reclamada = false,
  });

  /// 'd-20261113-0' (diaria) o 'w-202646-1' (semanal): la fecha la hace única.
  final String id;
  final TipoMision tipo;
  final int objetivo;
  final bool semanal;
  final int progreso;
  final bool reclamada;

  bool get cumplida => progreso >= objetivo;
  String get texto => tipo.texto(objetivo);

  /// Premio: (XP, monedas, puntos del pase).
  (int, int, int) get premio => semanal ? (250, 120, 300) : (80, 40, 100);

  Mision conProgreso(int p) =>
      Mision(id: id, tipo: tipo, objetivo: objetivo, semanal: semanal, progreso: p, reclamada: reclamada);

  Mision get comoReclamada =>
      Mision(id: id, tipo: tipo, objetivo: objetivo, semanal: semanal, progreso: progreso, reclamada: true);

  factory Mision.fromJson(Map<String, dynamic> j) => Mision(
    id: j['id'] as String,
    tipo: TipoMision.values.byName(j['tipo'] as String),
    objetivo: j['obj'] as int,
    semanal: j['sem'] as bool? ?? false,
    progreso: j['p'] as int? ?? 0,
    reclamada: j['r'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'obj': objetivo,
    if (semanal) 'sem': true,
    if (progreso > 0) 'p': progreso,
    if (reclamada) 'r': true,
  };
}

enum CategoriaCosmetico {
  cancha('Cancha'),
  pelota('Pelota'),
  uniforme('Uniforme'),
  led('Carteles LED');

  const CategoriaCosmetico(this.nombre);
  final String nombre;
}

/// Premios estéticos (sin dinero real). El primero de cada categoría es el de siempre y viene de
/// fábrica; el resto se gana en el pase de temporada ([nivelPase]) o con el nivel de entrenador
/// ([nivelEntrenador]).
enum Cosmetico {
  canchaModerna(CategoriaCosmetico.cancha, 'Parquet moderno', 'La cancha de siempre.'),
  canchaSetentas(CategoriaCosmetico.cancha, 'Parquet de los 70', 'Madera miel oscura y pintura gastada.', nivelPase: 4),
  canchaCuadros(
    CategoriaCosmetico.cancha,
    'Parquet a cuadros',
    'Tablas en damero, como los estadios viejos.',
    nivelEntrenador: 8,
  ),
  canchaBarrio(
    CategoriaCosmetico.cancha,
    'Cemento de barrio',
    'Playground: cemento gris y líneas pintadas a mano.',
    nivelPase: 14,
  ),
  pelotaClasica(CategoriaCosmetico.pelota, 'Pelota naranja', 'La de cuero de siempre.'),
  pelotaAba(CategoriaCosmetico.pelota, 'Pelota ABA', 'Roja, blanca y azul: la de la vieja liga rival.', nivelPase: 8),
  pelotaDorada(CategoriaCosmetico.pelota, 'Pelota dorada', 'Para entrenadores de nivel 12 o más.', nivelEntrenador: 12),
  uniformeTitular(CategoriaCosmetico.uniforme, 'Titular', 'La camiseta de tu franquicia.'),
  uniformeAlternativo(CategoriaCosmetico.uniforme, 'Alternativo', 'Los colores al revés.', nivelPase: 2),
  uniformeClasico(
    CategoriaCosmetico.uniforme,
    'Clásico crema',
    'Camiseta retro color crema con ribete de tu color.',
    nivelPase: 12,
  ),
  ledEquipo(CategoriaCosmetico.led, 'Color del equipo', 'Los LED con el color de tu franquicia.'),
  ledAmbar(CategoriaCosmetico.led, 'Ámbar', 'Como los tableros de bombitas de los 70.', nivelEntrenador: 4),
  ledVerde(CategoriaCosmetico.led, 'Verde fósforo', 'Monitor de los 80.', nivelPase: 6),
  ledHielo(CategoriaCosmetico.led, 'Hielo', 'Celeste frío, de estadio nuevo.', nivelPase: 10),
  ledOro(CategoriaCosmetico.led, 'Oro', 'Para el que completó el pase.', nivelPase: 20);

  const Cosmetico(this.categoria, this.nombre, this.descripcion, {this.nivelPase, this.nivelEntrenador});
  final CategoriaCosmetico categoria;
  final String nombre;
  final String descripcion;
  final int? nivelPase;
  final int? nivelEntrenador;

  bool get deFabrica => nivelPase == null && nivelEntrenador == null;

  static Cosmetico porDefecto(CategoriaCosmetico c) => values.firstWhere((x) => x.categoria == c && x.deFabrica);

  /// "Pase: nivel 8" / "Nivel 12 de entrenador" / "De fábrica".
  String get origen => nivelPase != null
      ? 'Pase: nivel $nivelPase'
      : nivelEntrenador != null
      ? 'Nivel $nivelEntrenador de entrenador'
      : 'De fábrica';
}

/// Una franquicia que te viene ganando: te eliminó en playoffs o te ganó muchos partidos.
class Rivalidad {
  const Rivalidad({
    required this.franquiciaId,
    this.eliminaciones = 0,
    this.derrotas = 0,
    this.ronda,
    this.temporadaId,
    this.temporadaNumero,
    this.revanchas = 0,
  });

  final String franquiciaId;
  final int eliminaciones;

  /// Partidos que te ganó (temporada regular y playoffs).
  final int derrotas;

  /// Última eliminación: ronda ("Finales de Conferencia"), en qué partida y qué temporada de tu carrera fue.
  final String? ronda;
  final String? temporadaId;
  final int? temporadaNumero;

  /// Series que le ganaste después de que te eliminara.
  final int revanchas;

  /// Hay cuenta pendiente: te eliminó más veces de las que te vengaste, o te ganó 5 o más partidos.
  bool get pendiente => eliminaciones > revanchas || derrotas >= 5;

  Rivalidad copyWith({
    int? eliminaciones,
    int? derrotas,
    String? ronda,
    String? temporadaId,
    int? temporadaNumero,
    int? revanchas,
  }) => Rivalidad(
    franquiciaId: franquiciaId,
    eliminaciones: eliminaciones ?? this.eliminaciones,
    derrotas: derrotas ?? this.derrotas,
    ronda: ronda ?? this.ronda,
    temporadaId: temporadaId ?? this.temporadaId,
    temporadaNumero: temporadaNumero ?? this.temporadaNumero,
    revanchas: revanchas ?? this.revanchas,
  );

  factory Rivalidad.fromJson(Map<String, dynamic> j) => Rivalidad(
    franquiciaId: j['f'] as String,
    eliminaciones: j['e'] as int? ?? 0,
    derrotas: j['d'] as int? ?? 0,
    ronda: j['ronda'] as String?,
    temporadaId: j['t'] as String?,
    temporadaNumero: j['n'] as int?,
    revanchas: j['rev'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'f': franquiciaId,
    if (eliminaciones > 0) 'e': eliminaciones,
    if (derrotas > 0) 'd': derrotas,
    if (ronda != null) 'ronda': ronda,
    if (temporadaId != null) 't': temporadaId,
    if (temporadaNumero != null) 'n': temporadaNumero,
    if (revanchas > 0) 'rev': revanchas,
  };
}

/// Estado del metajuego dentro del perfil.
class Metajuego {
  const Metajuego({
    this.misiones = const [],
    this.pase = '',
    this.puntosPase = 0,
    this.nivelesReclamados = const {},
    this.cosmeticos = const {},
    this.elegidos = const {},
    this.rivalidades = const {},
  });

  /// Misiones vigentes (3 del día y 3 de la semana).
  final List<Mision> misiones;

  /// Pase vigente ('2026-T4': uno por trimestre) y sus puntos.
  final String pase;
  final int puntosPase;
  final Set<int> nivelesReclamados;

  /// Cosméticos ganados (los de fábrica no hace falta guardarlos) y el elegido de cada categoría.
  final Set<Cosmetico> cosmeticos;
  final Map<CategoriaCosmetico, Cosmetico> elegidos;

  /// Rivalidades por franquicia.
  final Map<String, Rivalidad> rivalidades;

  Cosmetico elegido(CategoriaCosmetico c) => elegidos[c] ?? Cosmetico.porDefecto(c);

  Metajuego copyWith({
    List<Mision>? misiones,
    String? pase,
    int? puntosPase,
    Set<int>? nivelesReclamados,
    Set<Cosmetico>? cosmeticos,
    Map<CategoriaCosmetico, Cosmetico>? elegidos,
    Map<String, Rivalidad>? rivalidades,
  }) => Metajuego(
    misiones: misiones ?? this.misiones,
    pase: pase ?? this.pase,
    puntosPase: puntosPase ?? this.puntosPase,
    nivelesReclamados: nivelesReclamados ?? this.nivelesReclamados,
    cosmeticos: cosmeticos ?? this.cosmeticos,
    elegidos: elegidos ?? this.elegidos,
    rivalidades: rivalidades ?? this.rivalidades,
  );

  factory Metajuego.fromJson(Map<String, dynamic> j) => Metajuego(
    misiones: [for (final m in j['misiones'] as List? ?? const []) Mision.fromJson(m as Map<String, dynamic>)],
    pase: j['pase'] as String? ?? '',
    puntosPase: j['puntos'] as int? ?? 0,
    nivelesReclamados: {...(j['reclamados'] as List? ?? const []).cast<int>()},
    cosmeticos: {
      for (final c in (j['cosmeticos'] as List? ?? const []).cast<String>()) ?Cosmetico.values.asNameMap()[c],
    },
    elegidos: {
      for (final e in (j['elegidos'] as Map<String, dynamic>? ?? {}).entries)
        ?CategoriaCosmetico.values.asNameMap()[e.key]: ?Cosmetico.values.asNameMap()[e.value],
    },
    rivalidades: {
      for (final r in j['rivalidades'] as List? ?? const [])
        (r as Map<String, dynamic>)['f'] as String: Rivalidad.fromJson(r),
    },
  );

  Map<String, dynamic> toJson() => {
    if (misiones.isNotEmpty) 'misiones': [for (final m in misiones) m.toJson()],
    if (pase.isNotEmpty) 'pase': pase,
    if (puntosPase > 0) 'puntos': puntosPase,
    if (nivelesReclamados.isNotEmpty) 'reclamados': nivelesReclamados.toList()..sort(),
    if (cosmeticos.isNotEmpty) 'cosmeticos': [for (final c in cosmeticos) c.name],
    if (elegidos.isNotEmpty) 'elegidos': {for (final e in elegidos.entries) e.key.name: e.value.name},
    if (rivalidades.isNotEmpty) 'rivalidades': [for (final r in rivalidades.values) r.toJson()],
  };
}
