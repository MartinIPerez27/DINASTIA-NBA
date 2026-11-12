import 'dart:math';

import 'entities/jugador.dart';
import 'entities/temporada.dart';
import 'liga.dart';
import 'motor.dart';

/// Récords históricos de una temporada de la NBA (los reales).
enum RecordNba {
  puntos('Puntos por partido', 50.4, 'Wilt Chamberlain', '1961-62', 'PPP'),
  rebotes('Rebotes por partido', 27.2, 'Wilt Chamberlain', '1960-61', 'RPP'),
  asistencias('Asistencias por partido', 14.5, 'John Stockton', '1989-90', 'APP'),
  robos('Robos por partido', 3.67, 'Alvin Robertson', '1985-86', 'ROB/P'),
  tapones('Tapones por partido', 5.56, 'Mark Eaton', '1984-85', 'TAP/P'),
  victorias('Victorias en una temporada', 73, 'Golden State Warriors', '2015-16', 'V'),
  racha('Racha de victorias', 33, 'Los Angeles Lakers', '1971-72', 'seguidas');

  const RecordNba(this.nombre, this.marca, this.dueno, this.temporada, this.sigla);
  final String nombre;
  final double marca;
  final String dueno;
  final String temporada;
  final String sigla;

  bool get deEquipo => this == victorias || this == racha;

  int get decimales => switch (this) {
    robos || tapones => 2,
    victorias || racha => 0,
    _ => 1,
  };

  double? valor(LineaEstadistica l) => l.pj == 0
      ? null
      : switch (this) {
          puntos => l.pts / l.pj,
          rebotes => l.reb / l.pj,
          asistencias => l.ast / l.pj,
          robos => l.rob / l.pj,
          tapones => l.tap / l.pj,
          _ => null,
        };
}

/// Un récord en juego (o ya batido) por tu equipo o uno de tus jugadores.
class Persecucion {
  const Persecucion({required this.record, required this.actual, this.jugador, this.proyectado, this.batido = false});

  final RecordNba record;
  final Jugador? jugador;
  final double actual;

  /// Victorias proyectadas a 82 (solo para el récord de victorias).
  final double? proyectado;
  final bool batido;

  String get texto {
    String n(double v) => v.toStringAsFixed(record.decimales).replaceAll('.', ',');
    final marca = '${n(record.marca)} de ${record.dueno} (${record.temporada})';
    if (batido) {
      return record.deEquipo
          ? '¡Récord histórico! ${n(actual)} ${record.sigla}: superaron el $marca.'
          : '¡Récord histórico! ${jugador!.nombre}: ${n(actual)} ${record.sigla}, más que el $marca.';
    }
    return switch (record) {
      RecordNba.victorias => 'Van camino a ${n(proyectado!)} victorias. Récord: $marca.',
      RecordNba.racha => '${n(actual)} al hilo. Récord: $marca.',
      _ => '${jugador!.nombre}: ${n(actual)} ${record.sigla}. Récord: $marca.',
    };
  }
}

/// Racha actual de victorias del usuario en la temporada regular.
int rachaActual(Temporada t) {
  var racha = 0;
  final jugados = t.calendario.where((p) => p.jugado && p.participa(t.franquiciaUsuarioId)).toList()
    ..sort((a, b) => a.jornada.compareTo(b.jornada));
  for (final p in jugados.reversed) {
    if (p.ganadorId != t.franquiciaUsuarioId) break;
    racha++;
  }
  return racha;
}

int rachaMaxima(Temporada t) {
  var actual = 0, maxima = 0;
  final jugados = t.calendario.where((p) => p.jugado && p.participa(t.franquiciaUsuarioId)).toList()
    ..sort((a, b) => a.jornada.compareTo(b.jornada));
  for (final p in jugados) {
    actual = p.ganadorId == t.franquiciaUsuarioId ? actual + 1 : 0;
    maxima = max(maxima, actual);
  }
  return maxima;
}

/// Récords que tu equipo o tus jugadores están persiguiendo (desde los 10 partidos).
List<Persecucion> recordsEnJuego(Temporada t, Liga liga) {
  final r = t.registroUsuario;
  if (r.jugados < 10) return const [];
  final lista = <Persecucion>[];
  for (final j in t.plantel.jugadores) {
    final l = t.lineas[j.id];
    if (l == null || l.pj < 10) continue;
    for (final rec in RecordNba.values.where((x) => !x.deEquipo)) {
      final v = rec.valor(l)!;
      if (v >= rec.marca * 0.9) lista.add(Persecucion(record: rec, actual: v, jugador: j));
    }
  }
  final proyectado = r.victorias / r.jugados * Temporada.partidosTemporadaRegular;
  if (proyectado >= 70) {
    lista.add(Persecucion(record: RecordNba.victorias, actual: r.victorias.toDouble(), proyectado: proyectado));
  }
  final racha = rachaActual(t);
  if (racha >= 20) lista.add(Persecucion(record: RecordNba.racha, actual: racha.toDouble()));
  return lista;
}

/// Récords batidos al terminar la temporada regular (vacío mientras se juega).
List<Persecucion> recordsBatidos(Temporada t, Liga liga) {
  if (t.calendario.isEmpty || t.calendario.any((p) => !p.jugado)) return const [];
  final lista = <Persecucion>[];
  final minimo = Temporada.partidosTemporadaRegular ~/ 2;
  for (final j in t.plantel.jugadores) {
    final l = t.lineas[j.id];
    if (l == null || l.pj < minimo) continue;
    for (final rec in RecordNba.values.where((x) => !x.deEquipo)) {
      final v = rec.valor(l)!;
      if (v > rec.marca) lista.add(Persecucion(record: rec, actual: v, jugador: j, batido: true));
    }
  }
  final v = t.registroUsuario.victorias;
  if (v > RecordNba.victorias.marca) {
    lista.add(Persecucion(record: RecordNba.victorias, actual: v.toDouble(), batido: true));
  }
  final racha = rachaMaxima(t);
  if (racha > RecordNba.racha.marca) {
    lista.add(Persecucion(record: RecordNba.racha, actual: racha.toDouble(), batido: true));
  }
  return lista;
}
