import 'franquicia.dart';
import 'partido.dart';
import 'plantel.dart';
import 'tactica.dart';
import 'tirada.dart';

/// Fila de la tabla de posiciones (Standings).
class RegistroEquipo {
  const RegistroEquipo(this.franquiciaId, this.victorias, this.derrotas);

  final String franquiciaId;
  final int victorias;
  final int derrotas;

  int get jugados => victorias + derrotas;
  double get porcentaje => jugados == 0 ? 0 : victorias / jugados;
}

enum RondaPlayoff {
  primeraRonda('1ª Ronda de Conferencia'),
  semifinalConferencia('Semifinales de Conferencia'),
  finalConferencia('Finales de Conferencia'),
  finalesNba('Las Finales de la NBA');

  const RondaPlayoff(this.etiqueta);
  final String etiqueta;
}

/// Serie al mejor de 7 (GDD §7). [altoId] es la mejor siembra y tiene la ventaja de localía.
class SeriePlayoff {
  const SeriePlayoff({
    required this.ronda,
    required this.altoId,
    required this.bajoId,
    this.victoriasAlto = 0,
    this.victoriasBajo = 0,
  });

  static const victoriasParaGanar = 4;

  final RondaPlayoff ronda;
  final String altoId;
  final String bajoId;
  final int victoriasAlto;
  final int victoriasBajo;

  bool get terminada => victoriasAlto == victoriasParaGanar || victoriasBajo == victoriasParaGanar;

  String? get ganadorId => !terminada
      ? null
      : victoriasAlto == victoriasParaGanar
      ? altoId
      : bajoId;

  /// Formato 2-2-1-1-1: el mejor sembrado es local en los partidos 1, 2, 5 y 7.
  String get localProximoPartido => const {0, 1, 4, 6}.contains(victoriasAlto + victoriasBajo) ? altoId : bajoId;

  SeriePlayoff registrarVictoria(String franquiciaId) {
    if (terminada) throw StateError('La serie ya terminó.');
    if (franquiciaId != altoId && franquiciaId != bajoId) {
      throw ArgumentError('$franquiciaId no juega esta serie.');
    }
    final ganaAlto = franquiciaId == altoId;
    return SeriePlayoff(
      ronda: ronda,
      altoId: altoId,
      bajoId: bajoId,
      victoriasAlto: victoriasAlto + (ganaAlto ? 1 : 0),
      victoriasBajo: victoriasBajo + (ganaAlto ? 0 : 1),
    );
  }

  factory SeriePlayoff.fromJson(Map<String, dynamic> j) => SeriePlayoff(
    ronda: RondaPlayoff.values.byName(j['ronda'] as String),
    altoId: j['alto'] as String,
    bajoId: j['bajo'] as String,
    victoriasAlto: j['victoriasAlto'] as int,
    victoriasBajo: j['victoriasBajo'] as int,
  );

  Map<String, dynamic> toJson() => {
    'ronda': ronda.name,
    'alto': altoId,
    'bajo': bajoId,
    'victoriasAlto': victoriasAlto,
    'victoriasBajo': victoriasBajo,
  };
}

enum FaseTemporada { draft, tacticas, temporadaRegular, playoffs, finalizada }

/// Partida guardada: todo lo que el usuario construyó y jugó en una temporada.
class Temporada {
  const Temporada({
    required this.id,
    required this.franquiciaUsuarioId,
    this.plantel = const Plantel(),
    this.tactica = const Tactica(),
    this.rerollsRestantes = rerollsPorTemporada,
    this.calendario = const [],
    this.series = const [],
    this.tirada,
    this.tacticaConfirmada = false,
  });

  static const rerollsPorTemporada = 3;
  static const partidosTemporadaRegular = 82;
  static const clasificadosPorConferencia = 8;

  final String id;
  final String franquiciaUsuarioId;
  final Plantel plantel;
  final Tactica tactica;
  final int rerollsRestantes;
  final List<Partido> calendario;
  final List<SeriePlayoff> series;

  /// Tirada del tragamonedas pendiente de elegir carta (null si no hay).
  final Tirada? tirada;

  /// El usuario ya eligió su playbook (Fase 4); se puede seguir cambiando durante la temporada.
  final bool tacticaConfirmada;

  FaseTemporada get fase {
    if (!plantel.completo) return FaseTemporada.draft;
    if (!tacticaConfirmada) return FaseTemporada.tacticas;
    if (calendario.isEmpty || calendario.any((p) => !p.jugado)) {
      return FaseTemporada.temporadaRegular;
    }
    final finales = series.where((s) => s.ronda == RondaPlayoff.finalesNba);
    if (finales.isNotEmpty && finales.first.terminada) return FaseTemporada.finalizada;
    return FaseTemporada.playoffs;
  }

  RegistroEquipo registroDe(String franquiciaId) {
    var v = 0, d = 0;
    for (final p in calendario) {
      if (!p.jugado || !p.participa(franquiciaId)) continue;
      p.ganadorId == franquiciaId ? v++ : d++;
    }
    return RegistroEquipo(franquiciaId, v, d);
  }

  RegistroEquipo get registroUsuario => registroDe(franquiciaUsuarioId);

  /// La Hazaña Inmortal: 82-0.
  bool get esTemporadaPerfecta => registroUsuario.victorias == partidosTemporadaRegular;

  /// Tabla de una conferencia ordenada por % de victorias (desempate: más victorias).
  List<RegistroEquipo> standings(Conferencia conf, Iterable<Franquicia> franquicias) {
    final tabla = [
      for (final f in franquicias)
        if (f.conferencia == conf) registroDe(f.id),
    ];
    tabla.sort((a, b) {
      final c = b.porcentaje.compareTo(a.porcentaje);
      return c != 0 ? c : b.victorias.compareTo(a.victorias);
    });
    return tabla;
  }

  Temporada usarReroll() {
    if (rerollsRestantes <= 0) throw StateError('No quedan fichas de Reroll.');
    return copyWith(rerollsRestantes: rerollsRestantes - 1);
  }

  Temporada copyWith({
    Plantel? plantel,
    Tactica? tactica,
    int? rerollsRestantes,
    List<Partido>? calendario,
    List<SeriePlayoff>? series,
    bool? tacticaConfirmada,
  }) => Temporada(
    id: id,
    franquiciaUsuarioId: franquiciaUsuarioId,
    plantel: plantel ?? this.plantel,
    tactica: tactica ?? this.tactica,
    rerollsRestantes: rerollsRestantes ?? this.rerollsRestantes,
    calendario: calendario == null ? this.calendario : List.unmodifiable(calendario),
    series: series == null ? this.series : List.unmodifiable(series),
    tirada: tirada,
    tacticaConfirmada: tacticaConfirmada ?? this.tacticaConfirmada,
  );

  Temporada conTirada(Tirada? nueva) => Temporada(
    id: id,
    franquiciaUsuarioId: franquiciaUsuarioId,
    plantel: plantel,
    tactica: tactica,
    rerollsRestantes: rerollsRestantes,
    calendario: calendario,
    series: series,
    tirada: nueva,
    tacticaConfirmada: tacticaConfirmada,
  );

  factory Temporada.fromJson(Map<String, dynamic> j) => Temporada(
    id: j['id'] as String,
    franquiciaUsuarioId: j['franquiciaUsuario'] as String,
    plantel: Plantel.fromJson(j['plantel'] as Map<String, dynamic>),
    tactica: Tactica.fromJson(j['tactica'] as Map<String, dynamic>),
    rerollsRestantes: j['rerollsRestantes'] as int,
    calendario: List.unmodifiable([
      for (final p in j['calendario'] as List) Partido.fromJson(p as Map<String, dynamic>),
    ]),
    series: List.unmodifiable([for (final s in j['series'] as List) SeriePlayoff.fromJson(s as Map<String, dynamic>)]),
    tirada: j['tirada'] == null ? null : Tirada.fromJson(j['tirada'] as Map<String, dynamic>),
    tacticaConfirmada: j['tacticaConfirmada'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'franquiciaUsuario': franquiciaUsuarioId,
    'plantel': plantel.toJson(),
    'tactica': tactica.toJson(),
    'rerollsRestantes': rerollsRestantes,
    'calendario': [for (final p in calendario) p.toJson()],
    'series': [for (final s in series) s.toJson()],
    if (tirada != null) 'tirada': tirada!.toJson(),
    'tacticaConfirmada': tacticaConfirmada,
  };
}
