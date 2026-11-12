import 'dart:math';

import 'entities/franquicia.dart';
import 'entities/partido.dart';

/// Calendario oficial de 82 partidos (GDD §7) para las 30 franquicias:
/// - 4 contra cada rival de división (16),
/// - contra los 10 de su conferencia fuera de su división: 4 contra 6 y 3 contra 4 (36),
/// - 2 contra cada equipo de la otra conferencia (30).
/// 41 de local y 41 de visitante. Los partidos se ordenan en jornadas (cada equipo juega como
/// mucho una vez por jornada).
List<Partido> generarCalendario(List<Franquicia> equipos, Random azar) {
  final cruces = <(String, String)>[]; // (local, visitante), un elemento por partido

  void serie(String a, String b, int partidos, int localesDeA) {
    for (var i = 0; i < partidos; i++) {
      cruces.add(i < localesDeA ? (a, b) : (b, a));
    }
  }

  final porConferencia = <Conferencia, List<List<String>>>{};
  for (final c in Conferencia.values) {
    porConferencia[c] = [
      for (final d in Division.values)
        if (d.conferencia == c)
          ([
            for (final f in equipos)
              if (f.division == d) f.id,
          ]..shuffle(azar)),
    ];
  }

  for (final divisiones in porConferencia.values) {
    // División: 4 partidos (2 y 2).
    for (final d in divisiones) {
      for (var i = 0; i < d.length; i++) {
        for (var j = i + 1; j < d.length; j++) {
          serie(d[i], d[j], 4, 2);
        }
      }
    }
    // Conferencia fuera de la división: el par (a, b) con (ia - ib) mod 5 ∈ {0, 1} juega 3 veces.
    // Así cada equipo tiene exactamente 4 rivales de 3 partidos, 2 con localía a favor y 2 en contra.
    for (var x = 0; x < divisiones.length; x++) {
      for (var y = x + 1; y < divisiones.length; y++) {
        for (var ia = 0; ia < 5; ia++) {
          for (var ib = 0; ib < 5; ib++) {
            final a = divisiones[x][ia], b = divisiones[y][ib];
            final dif = (ia - ib) % 5;
            if (dif == 0) {
              serie(a, b, 3, 2);
            } else if (dif == 1) {
              serie(b, a, 3, 2);
            } else {
              serie(a, b, 4, 2);
            }
          }
        }
      }
    }
  }
  // Otra conferencia: 2 partidos (1 y 1).
  final este = [
    for (final f in equipos)
      if (f.conferencia == Conferencia.este) f.id,
  ];
  final oeste = [
    for (final f in equipos)
      if (f.conferencia == Conferencia.oeste) f.id,
  ];
  for (final a in este) {
    for (final b in oeste) {
      serie(a, b, 2, 1);
    }
  }

  // Jornadas: primer día libre para ambos equipos, recorriendo los cruces en orden aleatorio.
  cruces.shuffle(azar);
  final ocupados = <int, Set<String>>{};
  final partidos = <Partido>[];
  for (final (i, (local, visitante)) in cruces.indexed) {
    var dia = 0;
    while (ocupados[dia]?.contains(local) == true || ocupados[dia]?.contains(visitante) == true) {
      dia++;
    }
    (ocupados[dia] ??= {})
      ..add(local)
      ..add(visitante);
    partidos.add(Partido(id: 'p$i', jornada: dia + 1, localId: local, visitanteId: visitante));
  }
  partidos.sort((a, b) => a.jornada.compareTo(b.jornada));
  return List.unmodifiable(partidos);
}
