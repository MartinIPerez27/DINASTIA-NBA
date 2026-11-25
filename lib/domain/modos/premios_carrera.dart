import 'dart:math';

import '../motor.dart' show LineaEstadistica;
import '../entities/temporada.dart';
import '../liga.dart';
import '../premios.dart' show candidatos;
import 'carrera_jugador.dart';

// Premios extra de Mi carrera (los de siempre —MVP, Defensor, Sexto Hombre, Más Mejorado, All-NBA— los calcula la
// liga). Acá están los de la semana y el mes, el Novato del año, el MVP de las Finales, el Clutch Player,
// el All-Defensive y los líderes de la liga.
//
// Todo sale de lo que hizo tu jugador contra el resto de la liga en la misma temporada (no hay un registro por
// semana de toda la liga, así que se compara contra los mejores promedios "hasta ahora"). Son aproximaciones
// honestas: están pensadas para que un jugador de élite los gane seguido y uno de rotación casi nunca.

/// Puntos de habilidad que da cada premio (los que no figuran valen 1).
class PremiosCarrera {
  const PremiosCarrera._();

  /// Partidos de una "semana".
  static const partidosPorSemana = 4;

  static double puntos(String premio) {
    if (premio.startsWith('Jugador de la semana')) return 0.25 * _veces(premio);
    if (premio.startsWith('Jugador del mes')) return 1.0 * _veces(premio);
    if (premio.startsWith('Novato del mes')) return 0.5 * _veces(premio);
    return switch (premio) {
      'MVP' => 4,
      'Defensor del Año' => 3,
      'Máximo Anotador' => 2,
      'Sexto Hombre del Año' => 2,
      'Jugador Más Mejorado' => 2,
      'Novato del año' => 3,
      'MVP de las Finales' => 3,
      'Clutch Player' => 2,
      _ when premio.startsWith('All-NBA 1') => 3,
      _ when premio.startsWith('All-NBA 2') => 2,
      _ when premio.startsWith('All-Defensive 1') => 2,
      _ when premio.startsWith('Quinteto de novatos 1') => 1.5,
      _ => 1,
    };
  }

  /// "Jugador del mes ×3" → 3 (sin "×", 1).
  static int _veces(String p) => int.tryParse(p.split('×').last.trim()) ?? 1;

  /// Puntos de habilidad de una lista de premios (con tope de 12 por temporada).
  static double puntosDe(List<String> premios) => min(12.0, premios.fold(0.0, (a, p) => a + puntos(p)));

  // ---- semana y mes (se evalúan mientras se juega) ----

  /// Valor por partido del jugador número [puesto] de la liga hasta ahora (0 si todavía no hay datos).
  static double umbral(Temporada t, int puesto) {
    final maxPj = t.lineas.values.fold(0, (a, l) => max(a, l.pj));
    if (maxPj < 8) return 0;
    final valores = [
      for (final l in t.lineas.values)
        if (l.pj * 10 >= maxPj * 6) _valor(l),
    ]..sort((a, b) => b.compareTo(a));
    return valores.length >= puesto ? valores[puesto - 1] : 0;
  }

  static double _valor(LineaEstadistica l) => (l.pts + 0.7 * l.reb + 0.7 * l.ast + l.rob + l.tap - l.per) / max(1, l.pj);

  /// Suma el partido a la ventana de la semana y, cada 4 partidos, decide si fuiste Jugador de la semana.
  static EstadoCarrera alPartido(EstadoCarrera e, Temporada t, LineaEstadistica l, bool gano, int n) {
    final uso = {
      ...e.uso,
      'sem:n': (e.uso['sem:n'] ?? 0) + 1,
      'sem:val': (e.uso['sem:val'] ?? 0) + (l.pts + 0.7 * l.reb + 0.7 * l.ast + l.rob + l.tap - l.per).round(),
      if (gano) 'sem:w': (e.uso['sem:w'] ?? 0) + 1,
    };
    var ne = e.copyWith(uso: uso);
    if (n % partidosPorSemana != 0) return ne;
    final prom = (ne.uso['sem:val'] ?? 0) / partidosPorSemana;
    final gana = (ne.uso['sem:w'] ?? 0) >= 3;
    final u = umbral(t, 10);
    final limpio = {
      for (final x in ne.uso.entries)
        if (!x.key.startsWith('sem:')) x.key: x.value,
    };
    ne = ne.copyWith(uso: limpio);
    if (u > 0 && gana && prom >= u * 1.15) {
      ne = ne.copyWith(uso: {...ne.uso, 'sc:semana': (ne.uso['sc:semana'] ?? 0) + 1});
    }
    return ne;
  }

  /// Al cerrar el "mes": Jugador del mes (o Novato del mes en tu primera temporada). Se evalúa con los
  /// contadores `mes:*` que todavía no se reiniciaron.
  static EstadoCarrera alCerrarMes(EstadoCarrera e, Temporada t) {
    final n = max(1, e.uso['mes:n'] ?? 0);
    final prom = (e.uso['mes:val'] ?? 0) / n;
    final victorias = e.uso['mes:w'] ?? 0;
    final u = umbral(t, 5);
    if (u <= 0) return e;
    var ne = e;
    if (prom >= u * 1.0 && victorias >= n * 0.6) {
      ne = ne.copyWith(
        fans: ne.fans + 2,
        uso: {...ne.uso, 'sc:mes': (ne.uso['sc:mes'] ?? 0) + 1},
        hitos: [...ne.hitos, '${ne.etiquetaTemporada}: Jugador del mes.'],
      );
    } else if (ne.numero == 1 && prom >= umbral(t, 12) * 0.9 && victorias >= n * 0.4) {
      ne = ne.copyWith(
        uso: {...ne.uso, 'sc:novMes': (ne.uso['sc:novMes'] ?? 0) + 1},
        hitos: [...ne.hitos, '${ne.etiquetaTemporada}: Novato del mes.'],
      );
    }
    return ne;
  }

  // ---- al cierre de la temporada ----

  /// Premios del cierre que no calcula la liga: semana, mes, novato, Finales, clutch, defensa y líderes.
  static List<String> delCierre(Temporada t, Liga liga, EstadoCarrera e, {required bool campeon}) {
    final premios = <String>[];
    final semanas = e.uso['sc:semana'] ?? 0, meses = e.uso['sc:mes'] ?? 0, novMes = e.uso['sc:novMes'] ?? 0;
    if (semanas > 0) premios.add(semanas == 1 ? 'Jugador de la semana' : 'Jugador de la semana ×$semanas');
    if (meses > 0) premios.add(meses == 1 ? 'Jugador del mes' : 'Jugador del mes ×$meses');
    if (novMes > 0) premios.add(novMes == 1 ? 'Novato del mes' : 'Novato del mes ×$novMes');
    if (t.calendario.isEmpty) return premios;
    final base = candidatos(t, liga);
    final yo = base.indexWhere((g) => g.jugador.id == e.jugadorId);
    if (yo < 0) return premios;
    final puesto = yo + 1;
    // Novato del año y quinteto de novatos (tu primera temporada).
    if (e.numero == 1) {
      if (puesto <= 20) {
        premios.add('Novato del año');
      } else if (puesto <= 40) {
        premios.add('Quinteto de novatos 1.er equipo');
      } else if (puesto <= 70) {
        premios.add('Quinteto de novatos 2.º equipo');
      }
    }
    // MVP de las Finales: campeón y el mejor de tu equipo.
    if (campeon) {
      final mios = base.where((g) => g.franquiciaId == t.franquiciaUsuarioId).toList();
      if (mios.isNotEmpty && mios.first.jugador.id == e.jugadorId) premios.add('MVP de las Finales');
    }
    // Clutch Player: partidos apretados ganados con 20 puntos o más.
    if ((e.uso['sc:clutch'] ?? 0) >= 6) premios.add('Clutch Player');
    // All-Defensive y líderes de la liga.
    double def(LineaEstadistica l) => l.pj == 0 ? 0 : (1.3 * l.rob + 1.2 * l.tap) / l.pj;
    final porDefensa = [...base]..sort((a, b) => def(b.linea).compareTo(def(a.linea)));
    final posDef = porDefensa.indexWhere((g) => g.jugador.id == e.jugadorId) + 1;
    if (posDef >= 1 && posDef <= 5) {
      premios.add('All-Defensive 1.er equipo');
    } else if (posDef >= 6 && posDef <= 10) {
      premios.add('All-Defensive 2.º equipo');
    }
    String? lider(double Function(LineaEstadistica) f, String nombre) {
      final orden = [...base]..sort((a, b) => f(b.linea).compareTo(f(a.linea)));
      return orden.first.jugador.id == e.jugadorId ? 'Líder de la liga en $nombre' : null;
    }

    for (final p in [
      lider((l) => l.pts / max(1, l.pj), 'puntos'),
      lider((l) => l.reb / max(1, l.pj), 'rebotes'),
      lider((l) => l.ast / max(1, l.pj), 'asistencias'),
      lider((l) => l.rob / max(1, l.pj), 'robos'),
      lider((l) => l.tap / max(1, l.pj), 'tapones'),
    ]) {
      if (p != null) premios.add(p);
    }
    return premios;
  }
}
