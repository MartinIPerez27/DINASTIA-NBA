import 'jugador.dart';
import 'posicion.dart';

/// Cómo se arma el plantel: tragamonedas de 3 carretes o reparto de 5 cartas por puesto.
enum ModoDraft {
  ruleta('Ruleta', 'Tirá los 3 carretes: franquicia, época y rareza.'),
  cartas('Cartas', 'Elegí 1 de 3 sobres, abrilo y fichá 1 de sus 5 cartas.');

  const ModoDraft(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

enum TipoSobre { epoca, franquicia, misterioso }

/// Sobre cerrado del modo Cartas: de una época, de una franquicia o misterioso (todo el catálogo,
/// con más chances de una carta grande).
class Sobre {
  const Sobre(this.tipo, {this.epoca, this.franquiciaId});

  final TipoSobre tipo;
  final Epoca? epoca;
  final String? franquiciaId;

  bool incluye(Jugador j) => switch (tipo) {
    TipoSobre.epoca => j.epoca == epoca,
    TipoSobre.franquicia => j.franquiciaId == franquiciaId,
    TipoSobre.misterioso => true,
  };

  factory Sobre.fromJson(Map<String, dynamic> j) => Sobre(
    TipoSobre.values.byName(j['tipo'] as String),
    epoca: j['epoca'] == null ? null : Epoca.values.byName(j['epoca'] as String),
    franquiciaId: j['franquicia'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'tipo': tipo.name,
    if (epoca != null) 'epoca': epoca!.name,
    if (franquiciaId != null) 'franquicia': franquiciaId,
  };
}

/// Lo que hay sobre la mesa para un puesto (modo cartas): primero 3 sobres cerrados; al abrir uno,
/// sus cartas. Se guarda para que reabrir la app no reparta otras.
class Oferta {
  const Oferta({
    required this.posicion,
    this.cartaIds = const [],
    this.sobres = const [],
    this.sorpresaId,
    this.robadas = const [],
    this.ciega = false,
  });

  final Posicion posicion;
  final List<String> cartaIds;

  /// Sobres para elegir (vacío una vez abierto).
  final List<Sobre> sobres;

  /// La carta que viene boca abajo hasta que la fichás o la das vuelta.
  final String? sorpresaId;

  /// Draft en serpiente: cartas que los rivales eligieron antes que vos (id de carta, franquicia).
  final List<(String, String)> robadas;

  /// Draft a ciegas: todas boca abajo.
  final bool ciega;

  bool get sinAbrir => cartaIds.isEmpty && sobres.isNotEmpty;

  factory Oferta.fromJson(Map<String, dynamic> j) => Oferta(
    posicion: Posicion.values.byName(j['posicion'] as String),
    cartaIds: List.unmodifiable((j['cartas'] as List? ?? const []).cast<String>()),
    sobres: [for (final s in j['sobres'] as List? ?? const []) Sobre.fromJson(s as Map<String, dynamic>)],
    sorpresaId: j['sorpresa'] as String?,
    robadas: [for (final r in j['robadas'] as List? ?? const []) ((r as List)[0] as String, r[1] as String)],
    ciega: j['ciega'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'posicion': posicion.name,
    'cartas': cartaIds,
    if (sobres.isNotEmpty) 'sobres': [for (final s in sobres) s.toJson()],
    if (sorpresaId != null) 'sorpresa': sorpresaId,
    if (robadas.isNotEmpty)
      'robadas': [
        for (final (id, f) in robadas) [id, f],
      ],
    if (ciega) 'ciega': true,
  };
}
