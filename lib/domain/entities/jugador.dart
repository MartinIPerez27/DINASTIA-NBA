import '../../core/nba_cdn.dart';
import 'posicion.dart';
import 'rol_cancha.dart';

/// Carrete 2 del tragamonedas (GDD §4.2).
enum Epoca {
  anios40('Años 40'),
  anios50('Años 50'),
  anios60('Años 60'),
  anios70('Años 70'),
  anios80('Años 80'),
  anios90('Años 90'),
  anios2000('Años 2000'),
  anios2010('Años 2010'),
  actualidad('Actualidad');

  const Epoca(this.etiqueta);
  final String etiqueta;

  /// Código corto para los LED: '40s'…'10s', 'HOY'.
  String get codigo => this == actualidad ? 'HOY' : '${etiqueta.substring(etiqueta.length - 2)}s';

  /// Para nombrar un plantel de época: "Detroit Pistons (90’)".
  String get corta => this == actualidad ? 'Hoy' : '${etiqueta.substring(etiqueta.length - 2)}’';
}

/// Carrete 3 del tragamonedas (GDD §4.2), de menor a mayor rareza.
enum Tier {
  b('Tier B', 'Rotación', 'B'),
  a('Tier A', 'All-Star / Titular', 'A'),
  s('Tier S', 'Leyenda', 'S'),
  sPlus('Tier S+', 'GOAT Histórico', 'S+');

  const Tier(this.etiqueta, this.descripcion, this.codigo);
  final String etiqueta;
  final String descripcion;
  final String codigo;
}

/// Línea estadística de la carta (GDD §8.1). Porcentajes como fracción 0–1, igual que nba_api.
class EstadisticasJugador {
  const EstadisticasJugador({
    required this.ppp,
    required this.rpp,
    required this.app,
    required this.robP,
    required this.tapP,
    required this.pctTc,
    required this.pctT3,
    required this.pctTl,
    required this.minP,
    required this.perP,
    required this.iq,
  }) : assert(iq >= 1 && iq <= 99, 'IQ va de 1 a 99');

  final double ppp; // Puntos Por Partido
  final double rpp; // Rebotes Por Partido
  final double app; // Asistencias Por Partido
  final double robP; // Robos Por Partido
  final double tapP; // Tapones Por Partido
  final double pctTc; // % Tiros de Campo
  final double pctT3; // % Triples
  final double pctTl; // % Tiros Libres
  final double minP; // Minutos Por Partido
  final double perP; // Pérdidas Por Partido
  final int iq; // Inteligencia de Juego 1–99

  factory EstadisticasJugador.fromJson(Map<String, dynamic> j) {
    final iq = j['iq'] as int;
    if (iq < 1 || iq > 99) throw FormatException('IQ fuera de rango (1–99): $iq');
    double d(String k) => (j[k] as num).toDouble();
    return EstadisticasJugador(
      ppp: d('ppp'),
      rpp: d('rpp'),
      app: d('app'),
      robP: d('robP'),
      tapP: d('tapP'),
      pctTc: d('pctTc'),
      pctT3: d('pctT3'),
      pctTl: d('pctTl'),
      minP: d('minP'),
      perP: d('perP'),
      iq: iq,
    );
  }

  Map<String, dynamic> toJson() => {
    'ppp': ppp,
    'rpp': rpp,
    'app': app,
    'robP': robP,
    'tapP': tapP,
    'pctTc': pctTc,
    'pctT3': pctT3,
    'pctTl': pctTl,
    'minP': minP,
    'perP': perP,
    'iq': iq,
  };
}

/// Una carta del draft. Un mismo jugador NBA puede tener varias cartas (otra época o franquicia),
/// por eso [id] identifica la carta y [nbaPlayerId] a la persona.
class Jugador {
  const Jugador({
    required this.id,
    required this.nbaPlayerId,
    required this.nombre,
    required this.franquiciaId,
    required this.epoca,
    required this.tier,
    required this.posiciones,
    required this.rol,
    required this.dorsal,
    required this.stats,
    this.media = 75,
    String? equipo,
    this.fotos = const ['n', 'b'],
    this.estimadas = const {},
  }) : equipo = equipo ?? franquiciaId;

  final String id;
  final int nbaPlayerId;
  final String nombre;
  final String franquiciaId;
  final Epoca epoca;
  final Tier tier;

  /// Posiciones naturales según su carrera real; la primera es la principal.
  final List<Posicion> posiciones;
  final RolCancha rol;
  final int dorsal;
  final EstadisticasJugador stats;

  /// Valoración general 60–99 (eficiencia y premios en el tramo), estilo carta de Ultimate Team.
  final int media;

  /// Identidad con la que jugó en ese tramo (p. ej. 'SEA' para una carta del Thunder de los 90).
  final String equipo;

  /// Fuentes de foto en orden: 'n' (CDN NBA), 'b' (Basketball-Reference), 'w' (Wikipedia, se busca
  /// por nombre desde el celular) o `w:<url>` (Wikipedia ya resuelta).
  final List<String> fotos;

  /// Datos que la NBA no registraba en esa época y fueron estimados (p. ej. 'robP', 'tapP').
  final Set<String> estimadas;

  /// Id de Basketball-Reference (prefijo del id de carta).
  String get idBbref => id.split('-').first;

  /// URLs de foto en el orden en que se prueban (`wiki:<nombre>` = buscar en Wikipedia).
  List<String> get urlsFoto => [
    for (final f in fotos)
      if (f == 'n' && nbaPlayerId > 0)
        NbaCdn.headshot(nbaPlayerId)
      else if (f == 'b')
        'https://www.basketball-reference.com/req/202106291/images/headshots/$idBbref.jpg'
      else if (f == 'w')
        'wiki:$nombre'
      else if (f.startsWith('w:'))
        f.substring(2),
  ];

  String get iniciales {
    final partes = nombre.split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (partes.first[0] + ultima).toUpperCase();
  }

  /// Cualquier jugador puede ocupar el Sexto Hombre (GDD §3.3, excepción a la no duplicación).
  bool puedeJugarEn(Posicion p) => p == Posicion.sextoHombre || posiciones.contains(p);

  factory Jugador.fromJson(Map<String, dynamic> j) {
    final posiciones = [for (final p in j['posiciones'] as List) Posicion.desdeEtiqueta(p as String)];
    if (posiciones.isEmpty) throw FormatException('${j['nombre']} no tiene posiciones');
    return Jugador(
      id: j['id'] as String,
      nbaPlayerId: j['nbaPlayerId'] as int,
      nombre: j['nombre'] as String,
      franquiciaId: j['franquicia'] as String,
      epoca: Epoca.values.byName(j['epoca'] as String),
      tier: Tier.values.byName(j['tier'] as String),
      posiciones: List.unmodifiable(posiciones),
      rol: RolCancha.values.byName(j['rol'] as String),
      dorsal: j['dorsal'] as int,
      stats: EstadisticasJugador.fromJson(j['stats'] as Map<String, dynamic>),
      media: j['media'] as int? ?? 75,
      equipo: j['equipo'] as String?,
      fotos: List.unmodifiable((j['fotos'] as List?)?.cast<String>() ?? const ['n', 'b']),
      estimadas: Set.unmodifiable((j['estimadas'] as List?)?.cast<String>() ?? const <String>[]),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nbaPlayerId': nbaPlayerId,
    'nombre': nombre,
    'franquicia': franquiciaId,
    'epoca': epoca.name,
    'tier': tier.name,
    'posiciones': [for (final p in posiciones) p.etiqueta],
    'rol': rol.name,
    'dorsal': dorsal,
    'stats': stats.toJson(),
    'media': media,
    'equipo': equipo,
    'fotos': fotos,
    if (estimadas.isNotEmpty) 'estimadas': estimadas.toList(),
  };

  @override
  bool operator ==(Object other) => other is Jugador && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Jugador($id, $nombre)';
}
