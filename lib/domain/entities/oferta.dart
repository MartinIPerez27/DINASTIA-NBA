import 'posicion.dart';

/// Cómo se arma el plantel: tragamonedas de 3 carretes o reparto de 5 cartas por puesto.
enum ModoDraft {
  ruleta('Ruleta', 'Tirá los 3 carretes: franquicia, época y rareza.'),
  cartas('Cartas', 'Tocá un puesto y elegí 1 de 5 cartas reveladas.');

  const ModoDraft(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Las 5 cartas repartidas para un puesto (modo cartas). Se guarda para que reabrir no reparta otras.
class Oferta {
  const Oferta({required this.posicion, required this.cartaIds});

  final Posicion posicion;
  final List<String> cartaIds;

  factory Oferta.fromJson(Map<String, dynamic> j) => Oferta(
    posicion: Posicion.values.byName(j['posicion'] as String),
    cartaIds: List.unmodifiable((j['cartas'] as List).cast<String>()),
  );

  Map<String, dynamic> toJson() => {'posicion': posicion.name, 'cartas': cartaIds};
}
