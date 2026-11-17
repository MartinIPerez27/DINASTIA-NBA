import 'entities/jugador.dart';

/// REGLA DEL DUEÑO: en una misma tirada, sobre, oferta o lista hay UNA sola carta por persona (si el
/// catálogo tiene varias versiones de Jordan en los años 90 de los Bulls, sale una).
///
/// Orden de las operaciones: primero se filtra por lo que pide la tirada (franquicia, época, rareza,
/// regla del draft, puesto libre…) y DESPUÉS se agrupa por persona ([Jugador.personaId]) quedándose con
/// la mejor versión de lo que pasó el filtro: mayor media y, a igualdad, la más reciente (último año
/// del tramo; con otro empate, el id mayor). El resultado no depende del orden de entrada.

/// ¿[a] es mejor versión que [b] para mostrarse en una tirada? Mayor media; desempate: más reciente.
bool esMejorVersion(Jugador a, Jugador b) {
  if (a.media != b.media) return a.media > b.media;
  final fa = a.temporadas?.$2 ?? 0, fb = b.temporadas?.$2 ?? 0;
  if (fa != fb) return fa > fb;
  return a.id.compareTo(b.id) > 0;
}

/// La mejor versión de cada persona entre [cartas], en el orden en que aparece cada persona por
/// primera vez (el orden de entrada es el del catálogo, así que es determinista).
List<Jugador> unaPorPersona(Iterable<Jugador> cartas) {
  final mejor = <String, Jugador>{};
  for (final j in cartas) {
    final previa = mejor[j.personaId];
    if (previa == null || esMejorVersion(j, previa)) mejor[j.personaId] = j;
  }
  return mejor.values.toList();
}

/// Lo mismo, pero por grupo: una persona puede aparecer una vez en CADA grupo (franquicia + época).
/// Sirve para armar todas las tiradas posibles a la vez.
List<Jugador> unaPorPersonaYGrupo<G>(Iterable<Jugador> cartas, G Function(Jugador) grupo) {
  final mejor = <(G, String), Jugador>{};
  for (final j in cartas) {
    final k = (grupo(j), j.personaId);
    final previa = mejor[k];
    if (previa == null || esMejorVersion(j, previa)) mejor[k] = j;
  }
  return mejor.values.toList();
}

/// Personas distintas en [cartas] (para tests y auditorías).
bool hayPersonasRepetidas(Iterable<Jugador> cartas) {
  final vistas = <String>{};
  return cartas.any((j) => !vistas.add(j.personaId));
}
