import 'entities/jugador.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';

/// Validación de la regla "Mi colección" por puesto.
///
/// Puestos que NO se pueden llenar con tus cartas aunque se acomoden bien (asignación completa: cada
/// carta ocupa un solo puesto). Vacío = el draft se puede terminar. El chequeo anterior era codicioso
/// y podía dar el visto bueno a una colección con la que el draft quedaba trabado.
List<Posicion> puestosSinCobertura(Iterable<Jugador> catalogo, Set<String> coleccion) {
  final propias = catalogo.where((j) => coleccion.contains(j.id)).toList();
  const vacio = Plantel();
  final aptas = {
    for (final p in Posicion.values)
      p: [
        for (final j in propias)
          if (vacio.posicionesDisponiblesPara(j).contains(p)) j,
      ],
  };
  final puestoDe = <String, Posicion>{}; // carta -> puesto
  bool colocar(Posicion p, Set<String> vistas) {
    for (final j in aptas[p]!) {
      if (!vistas.add(j.id)) continue;
      final ocupante = puestoDe[j.id];
      if (ocupante == null || colocar(ocupante, vistas)) {
        puestoDe[j.id] = p;
        return true;
      }
    }
    return false;
  }

  return [
    for (final p in Posicion.values)
      if (!colocar(p, {})) p,
  ];
}

/// ¿Alcanzan tus cartas para llenar los 6 puestos?
bool coleccionLlenaPuestos(Iterable<Jugador> catalogo, Set<String> coleccion) =>
    puestosSinCobertura(catalogo, coleccion).isEmpty;
