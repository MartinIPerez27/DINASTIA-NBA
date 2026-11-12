import '../motor.dart';

/// Logros (GDD: metajuego). Cada uno da XP y monedas la primera vez.
enum Logro {
  primeraVictoria('Primer triunfo', 'Ganá tu primer partido.'),
  racha10('Imparable', 'Ganá 10 partidos seguidos.'),
  racha30('Aplanadora', 'Ganá 30 partidos seguidos.'),
  mitadPerfecta('Media hazaña', 'Llegá a 41-0.'),
  sesenta('Club de los 60', 'Terminá la temporada con 60 victorias o más.'),
  setenta('Club de los 70', 'Terminá la temporada con 70 victorias o más.'),
  perfecta('Hazaña Inmortal', 'Terminá la temporada 82-0.'),
  playoffs('A los playoffs', 'Clasificá a los playoffs.'),
  barrida('Barrida', 'Ganá una serie de playoffs 4-0.'),
  finales('A Las Finales', 'Llegá a Las Finales de la NBA.'),
  campeon('El anillo', 'Ganá el campeonato.'),
  invictoPlayoffs('16-0', 'Salí campeón sin perder un partido de playoffs.'),
  campeonDificil('Contra viento y marea', 'Salí campeón en Difícil.'),
  campeonLeyenda('Leyenda entre leyendas', 'Salí campeón en Leyenda.'),
  mvpPropio('Tenés al MVP', 'Un jugador tuyo gana el MVP de la temporada.'),
  anotadorPropio('Máquina de puntos', 'Un jugador tuyo es el Máximo Anotador.'),
  tresTemporadas('Trayectoria', 'Terminá 3 temporadas.'),
  recordHistorico('Para la historia', 'Batí un récord de una temporada de la NBA.'),
  tresAllStars('Constelación', 'Tené 3 o más jugadores en el All-Star.'),
  copaNba('Campeón de la Copa NBA', 'Ganá la Copa NBA de mitad de temporada.');

  const Logro(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

enum TipoTrofeo {
  anillo('Anillo de campeón'),
  larryOBrien('Trofeo Larry O’Brien'),
  presidente('Trofeo Presidente'),
  mvp('MVP de la Temporada'),
  anotador('Máximo Anotador'),
  perfecta('Temporada 82-0'),
  dpoy('Defensor del Año'),
  sextoHombre('Sexto Hombre del Año'),
  mip('Jugador Más Mejorado'),
  allNba('Quinteto All-NBA'),
  allStar('All-Star'),
  record('Récord histórico'),
  copa('Copa NBA');

  const TipoTrofeo(this.nombre);
  final String nombre;
}

/// Un trofeo de la vitrina.
class Trofeo {
  const Trofeo({
    required this.tipo,
    required this.temporadaId,
    required this.franquiciaId,
    this.detalle,
    required this.fecha,
  });

  final TipoTrofeo tipo;
  final String temporadaId;
  final String franquiciaId;
  final String? detalle; // p. ej. el nombre del MVP
  final int fecha;

  factory Trofeo.fromJson(Map<String, dynamic> j) => Trofeo(
    tipo: TipoTrofeo.values.byName(j['tipo'] as String),
    temporadaId: j['temporada'] as String,
    franquiciaId: j['franquicia'] as String,
    detalle: j['detalle'] as String?,
    fecha: j['fecha'] as int,
  );

  Map<String, dynamic> toJson() => {
    'tipo': tipo.name,
    'temporada': temporadaId,
    'franquicia': franquiciaId,
    if (detalle != null) 'detalle': detalle,
    'fecha': fecha,
  };
}

/// Una temporada terminada, para el Salón de la Fama y la historia de tu dinastía.
class ResumenTemporada {
  const ResumenTemporada({
    required this.temporadaId,
    required this.franquiciaId,
    required this.dificultad,
    required this.victorias,
    required this.derrotas,
    required this.resultado,
    required this.campeon,
    required this.figuras,
    required this.fecha,
    this.mvp,
  });

  final String temporadaId;
  final String franquiciaId;
  final String dificultad;
  final int victorias, derrotas;

  /// "Campeón", "Las Finales", "Final de conferencia", "Semifinal", "1.ª ronda" o "Sin playoffs".
  final String resultado;
  final bool campeon;
  final List<String> figuras;
  final String? mvp;
  final int fecha;

  factory ResumenTemporada.fromJson(Map<String, dynamic> j) => ResumenTemporada(
    temporadaId: j['temporada'] as String,
    franquiciaId: j['franquicia'] as String,
    dificultad: j['dificultad'] as String,
    victorias: j['v'] as int,
    derrotas: j['d'] as int,
    resultado: j['resultado'] as String,
    campeon: j['campeon'] as bool,
    figuras: (j['figuras'] as List).cast<String>(),
    mvp: j['mvp'] as String?,
    fecha: j['fecha'] as int,
  );

  Map<String, dynamic> toJson() => {
    'temporada': temporadaId,
    'franquicia': franquiciaId,
    'dificultad': dificultad,
    'v': victorias,
    'd': derrotas,
    'resultado': resultado,
    'campeon': campeon,
    'figuras': figuras,
    if (mvp != null) 'mvp': mvp,
    'fecha': fecha,
  };
}

/// Ventajas del entrenador que se desbloquean con el nivel.
enum Ventaja {
  fichaExtra(3, '+1 ficha para volver a tirar en cada draft'),
  tiempoMuertoExtra(6, '+1 tiempo muerto en cada partido en vivo'),
  segundaFichaExtra(10, '+1 ficha más para volver a tirar (2 en total)'),
  descansoLargo(15, 'Los tiempos muertos recuperan el doble de energía');

  const Ventaja(this.nivel, this.descripcion);
  final int nivel;
  final String descripcion;
}

/// Perfil del entrenador: progreso que se arrastra de partida en partida.
class PerfilEntrenador {
  const PerfilEntrenador({
    this.xp = 0,
    this.monedas = 0,
    this.puntaje = 1000,
    this.logros = const {},
    this.trofeos = const [],
    this.historial = const [],
    this.carrera = const {},
    this.temporadasCerradas = const {},
    this.coleccion = const {},
  });

  final int xp;
  final int monedas;

  /// Puntaje personal (tipo Elo): sube al ganarle a rivales fuertes, baja al perder con débiles.
  final int puntaje;

  /// Logro → fecha (ms) en que se consiguió.
  final Map<Logro, int> logros;
  final List<Trofeo> trofeos;
  final List<ResumenTemporada> historial;

  /// Carrera de cada carta con vos: id de carta → (temporadas, estadísticas acumuladas).
  final Map<String, (int, LineaEstadistica)> carrera;

  /// Temporadas ya cerradas (para no premiar dos veces).
  final Set<String> temporadasCerradas;

  /// Álbum: cartas que son tuyas (las que fichaste en un draft y las de los sobres de la tienda).
  final Set<String> coleccion;

  /// XP total necesaria para llegar a un nivel: 0, 150, 450, 900, 1500…
  static int xpParaNivel(int nivel) => 75 * nivel * (nivel - 1);

  int get nivel {
    var n = 1;
    while (xpParaNivel(n + 1) <= xp) {
      n++;
    }
    return n;
  }

  /// Avance dentro del nivel actual (0–1).
  double get avanceNivel {
    final desde = xpParaNivel(nivel), hasta = xpParaNivel(nivel + 1);
    return (xp - desde) / (hasta - desde);
  }

  bool tiene(Ventaja v) => nivel >= v.nivel;

  int get fichasExtra => (tiene(Ventaja.fichaExtra) ? 1 : 0) + (tiene(Ventaja.segundaFichaExtra) ? 1 : 0);

  PerfilEntrenador copyWith({
    int? xp,
    int? monedas,
    int? puntaje,
    Map<Logro, int>? logros,
    List<Trofeo>? trofeos,
    List<ResumenTemporada>? historial,
    Map<String, (int, LineaEstadistica)>? carrera,
    Set<String>? temporadasCerradas,
    Set<String>? coleccion,
  }) => PerfilEntrenador(
    xp: xp ?? this.xp,
    monedas: monedas ?? this.monedas,
    puntaje: puntaje ?? this.puntaje,
    logros: logros ?? this.logros,
    trofeos: trofeos ?? this.trofeos,
    historial: historial ?? this.historial,
    carrera: carrera ?? this.carrera,
    temporadasCerradas: temporadasCerradas ?? this.temporadasCerradas,
    coleccion: coleccion ?? this.coleccion,
  );

  factory PerfilEntrenador.fromJson(Map<String, dynamic> j) => PerfilEntrenador(
    xp: j['xp'] as int? ?? 0,
    monedas: j['monedas'] as int? ?? 0,
    puntaje: j['puntaje'] as int? ?? 1000,
    logros: {
      for (final e in (j['logros'] as Map<String, dynamic>? ?? {}).entries)
        ?Logro.values.asNameMap()[e.key]: e.value as int,
    },
    trofeos: [for (final t in j['trofeos'] as List? ?? const []) Trofeo.fromJson(t as Map<String, dynamic>)],
    historial: [
      for (final h in j['historial'] as List? ?? const []) ResumenTemporada.fromJson(h as Map<String, dynamic>),
    ],
    carrera: {
      for (final e in (j['carrera'] as Map<String, dynamic>? ?? {}).entries)
        e.key: (
          (e.value as Map<String, dynamic>)['t'] as int,
          LineaEstadistica.fromJson((e.value as Map<String, dynamic>)['l'] as Map<String, dynamic>),
        ),
    },
    temporadasCerradas: {...(j['cerradas'] as List? ?? const []).cast<String>()},
    coleccion: {...(j['coleccion'] as List? ?? const []).cast<String>()},
  );

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'monedas': monedas,
    'puntaje': puntaje,
    'logros': {for (final e in logros.entries) e.key.name: e.value},
    'trofeos': [for (final t in trofeos) t.toJson()],
    'historial': [for (final h in historial) h.toJson()],
    'carrera': {
      for (final e in carrera.entries) e.key: {'t': e.value.$1, 'l': e.value.$2.toJson()},
    },
    'cerradas': temporadasCerradas.toList(),
    'coleccion': coleccion.toList(),
  };
}
