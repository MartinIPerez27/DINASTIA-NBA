import '../../core/nba_cdn.dart';
import 'posicion.dart';
import 'rol_cancha.dart';

/// Carrete 2 del tragamonedas (GDD §4.2).
enum Epoca {
  anios80('Años 80'),
  anios90('Años 90'),
  anios2000('Años 2000'),
  anios2010('Años 2010'),
  actualidad('Actualidad');

  const Epoca(this.etiqueta);
  final String etiqueta;
}

/// Carrete 3 del tragamonedas (GDD §4.2).
enum Tier {
  a('Tier A', 'All-Star'),
  s('Tier S', 'Leyenda'),
  sPlus('Tier S+', 'GOAT Histórico');

  const Tier(this.etiqueta, this.descripcion);
  final String etiqueta;
  final String descripcion;
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
  });

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

  String get headshotUrl => NbaCdn.headshot(nbaPlayerId);

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
  };

  @override
  bool operator ==(Object other) => other is Jugador && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Jugador($id, $nombre)';
}
