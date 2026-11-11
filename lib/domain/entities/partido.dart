/// Un partido del calendario. Sin spoilers (GDD §6): mientras no se juega, el marcador es 0-0.
/// Los puntos se guardan por periodo; del 5.º en adelante son prórrogas (la NBA no tiene empates).
class Partido {
  const Partido({
    required this.id,
    required this.jornada,
    required this.localId,
    required this.visitanteId,
    this.periodosLocal = const [],
    this.periodosVisitante = const [],
  });

  final String id;
  final int jornada;
  final String localId;
  final String visitanteId;
  final List<int> periodosLocal;
  final List<int> periodosVisitante;

  static const cuartosReglamentarios = 4;

  int get puntosLocal => periodosLocal.fold(0, (a, b) => a + b);
  int get puntosVisitante => periodosVisitante.fold(0, (a, b) => a + b);
  bool get jugado => periodosLocal.isNotEmpty;

  String? get ganadorId => !jugado
      ? null
      : puntosLocal > puntosVisitante
      ? localId
      : visitanteId;

  bool participa(String franquiciaId) => localId == franquiciaId || visitanteId == franquiciaId;

  Partido conResultado(List<int> local, List<int> visitante) {
    if (jugado) throw StateError('El partido $id ya se jugó.');
    if (local.length != visitante.length || local.length < cuartosReglamentarios) {
      throw ArgumentError('Se requieren al menos 4 periodos por equipo.');
    }
    if (local.any((p) => p < 0) || visitante.any((p) => p < 0)) {
      throw ArgumentError('Puntos negativos.');
    }
    final l = local.fold(0, (a, b) => a + b);
    final v = visitante.fold(0, (a, b) => a + b);
    if (l == v) throw ArgumentError('Empate: falta jugar la prórroga.');
    return Partido(
      id: id,
      jornada: jornada,
      localId: localId,
      visitanteId: visitanteId,
      periodosLocal: List.unmodifiable(local),
      periodosVisitante: List.unmodifiable(visitante),
    );
  }

  factory Partido.fromJson(Map<String, dynamic> j) => Partido(
    id: j['id'] as String,
    jornada: j['jornada'] as int,
    localId: j['local'] as String,
    visitanteId: j['visitante'] as String,
    periodosLocal: List.unmodifiable((j['periodosLocal'] as List).cast<int>()),
    periodosVisitante: List.unmodifiable((j['periodosVisitante'] as List).cast<int>()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'jornada': jornada,
    'local': localId,
    'visitante': visitanteId,
    'periodosLocal': periodosLocal,
    'periodosVisitante': periodosVisitante,
  };
}
