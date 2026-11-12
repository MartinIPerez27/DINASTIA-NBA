import 'dart:math';

import 'entities/franquicia.dart';
import 'entities/jugador.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/tactica.dart';
import 'entities/temporada.dart';
import 'liga.dart';
import 'motor.dart';
import 'premios.dart';

/// Fin de semana All-Star: 12 por conferencia y un partido Este vs. Oeste.
class AllStar {
  const AllStar({
    required this.este,
    required this.oeste,
    required this.puntosEste,
    required this.puntosOeste,
    required this.mvp,
    required this.lineaMvp,
    required this.equipos,
  });

  /// Los 12 de cada conferencia (los 6 primeros jugaron de titulares y sexto).
  final List<Jugador> este, oeste;
  final int puntosEste, puntosOeste;
  final Jugador mvp;
  final LineaEstadistica lineaMvp;

  /// Franquicia de cada convocado (id de carta → franquicia).
  final Map<String, String> equipos;

  /// Convocados de una franquicia.
  List<Jugador> de(String franquiciaId) => [...este, ...oeste].where((j) => equipos[j.id] == franquiciaId).toList();
}

/// El All-Star se juega cuando la temporada pasa la mitad (lo que sigue para el usuario es después
/// de la jornada del medio). Antes devuelve null. Determinista: misma temporada, mismo All-Star.
AllStar? allStarDe(Temporada t, Liga liga) {
  if (t.calendario.isEmpty) return null;
  if (_jugados[t.id] case final previo?) return previo;
  final resultado = _jugar(t, liga);
  if (resultado != null) _jugados[t.id] = resultado;
  return resultado;
}

// shortcut: el All-Star se arma con las estadísticas del momento en que se mira por primera vez
// (pasada la mitad) y queda fijo mientras la app está abierta. Para fijarlo entre sesiones habría
// que guardarlo en la Temporada.
final _jugados = <String, AllStar>{};

/// Solo para pruebas: olvida los All-Star ya jugados.
void olvidarAllStars() => _jugados.clear();

AllStar? _jugar(Temporada t, Liga liga) {
  final total = t.calendario.fold(0, (a, p) => max(a, p.jornada));
  final proximo = liga.proximoDelUsuario(t);
  if (proximo != null && proximo.jornada <= total ~/ 2) return null;
  final conferencias = {for (final f in liga.franquicias) f.id: f.conferencia};
  final base = candidatos(t, liga);
  final equipos = {for (final g in base) g.jugadorId: g.franquiciaId};
  List<Galardon> convocar(Conferencia conf) {
    final pool = base.where((g) => conferencias[g.franquiciaId] == conf).toList();
    final elegidos = <Galardon>[];
    final personas = <int>{};
    void sumar(Galardon g) {
      if (elegidos.contains(g) || (g.jugador.nbaPlayerId > 0 && personas.contains(g.jugador.nbaPlayerId))) return;
      elegidos.add(g);
      personas.add(g.jugador.nbaPlayerId);
    }

    for (final (grupo, cupo) in [(GrupoPuesto.exterior, 3), (GrupoPuesto.alero, 3), (GrupoPuesto.pivot, 2)]) {
      for (final g in pool.where((g) => GrupoPuesto.de(g.jugador) == grupo).take(cupo)) {
        sumar(g);
      }
    }
    for (final g in pool) {
      if (elegidos.length >= 12) break;
      sumar(g);
    }
    elegidos.sort((a, b) => b.valor.compareTo(a.valor));
    return elegidos.take(12).toList();
  }

  final este = convocar(Conferencia.este), oeste = convocar(Conferencia.oeste);
  if (este.length < 6 || oeste.length < 6) return null;
  final plantelEste = _plantel(este), plantelOeste = _plantel(oeste);
  if (plantelEste == null || plantelOeste == null) return null;
  final motor = MotorPartido(
    local: EquipoPartido(
      identidadId: 'ESTE',
      plantel: plantelEste,
      tactica: const Tactica(ofensiva: SistemaOfensivo.paceAndSpace),
    ),
    visitante: EquipoPartido(
      identidadId: 'OESTE',
      plantel: plantelOeste,
      tactica: const Tactica(ofensiva: SistemaOfensivo.paceAndSpace),
    ),
    azar: Random(Object.hash(t.id, 'all-star')),
  )..simularTodo();
  final box = {...motor.boxLocal, ...motor.boxVisitante};
  double valor(LineaEstadistica l) => l.pts + 0.7 * l.reb + 0.7 * l.ast + l.rob + l.tap - l.per;
  final ganadores = motor.puntosLocal > motor.puntosVisitante ? motor.boxLocal : motor.boxVisitante;
  final mvpId = ganadores.entries.reduce((a, b) => valor(a.value) >= valor(b.value) ? a : b).key;
  final todos = [...este, ...oeste];
  return AllStar(
    este: [for (final g in este) g.jugador],
    oeste: [for (final g in oeste) g.jugador],
    puntosEste: motor.puntosLocal,
    puntosOeste: motor.puntosVisitante,
    mvp: todos.firstWhere((g) => g.jugadorId == mvpId).jugador,
    lineaMvp: box[mvpId]!,
    equipos: equipos,
  );
}

/// Quinteto + sexto con los convocados, cada uno en un puesto que juega (el mejor disponible).
Plantel? _plantel(List<Galardon> convocados) {
  var plantel = const Plantel();
  for (final p in [...Posicion.titulares, Posicion.sextoHombre]) {
    final candidato = convocados.where((g) => plantel.posicionesDisponiblesPara(g.jugador).contains(p)).firstOrNull;
    if (candidato == null) return null;
    plantel = plantel.asignar(candidato.jugador, p);
  }
  return plantel;
}
