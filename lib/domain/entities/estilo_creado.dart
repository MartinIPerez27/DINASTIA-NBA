/// El físico fino y el estilo de juego de tu jugador creado: no se dibujan, se juegan (la envergadura mueve las
/// estadísticas; el origen inclina los atributos de arranque; la forma de tirar y el festejo dan identidad y se
/// usarán en la barra de tiro y en el relato).
enum OrigenJugador {
  secundario('Secundario', 'Llegás directo del colegio: más físico que cabeza.'),
  universidad('Universidad', 'Cuatro años de básquet universitario: más lectura de juego, menos explosión.'),
  internacional('Internacional', 'Te formaste afuera: mejor tiro, algo menos de físico para la NBA.');

  const OrigenJugador(this.etiqueta, this.descripcion);
  final String etiqueta, descripcion;
}

class EstiloCreado {
  const EstiloCreado({
    this.envergadura = 0,
    this.mano = 0,
    this.origen = OrigenJugador.universidad,
    this.formaDeTiro = 0,
    this.festejo = 0,
  });

  /// Centímetros de brazos de más (o de menos) respecto de tu altura: de −10 a +15.
  final int envergadura;

  /// 0 derecho, 1 zurdo, 2 ambidiestro.
  final int mano;
  final OrigenJugador origen;
  final int formaDeTiro, festejo;

  static const envergaduraMin = -10, envergaduraMax = 15;
  static const manos = ['Derecho', 'Zurdo', 'Ambidiestro'];
  static const formas = ['Clásico', 'Rápido', 'Alto y liviano', 'Salto hacia atrás', 'Muñeca suelta'];
  static const festejos = ['Tranquilo', 'Puño al aire', 'Silencio al público', 'Brazos abiertos', 'Baile corto', 'Señalar al cielo'];

  EstiloCreado copyWith({int? envergadura, int? mano, OrigenJugador? origen, int? formaDeTiro, int? festejo}) => EstiloCreado(
    envergadura: (envergadura ?? this.envergadura).clamp(envergaduraMin, envergaduraMax),
    mano: mano ?? this.mano,
    origen: origen ?? this.origen,
    formaDeTiro: formaDeTiro ?? this.formaDeTiro,
    festejo: festejo ?? this.festejo,
  );

  String get codigo => '$envergadura.$mano.${origen.index}.$formaDeTiro.$festejo';

  static EstiloCreado? deCodigo(String? codigo) {
    if (codigo == null) return null;
    final p = codigo.split('.').map(int.tryParse).toList();
    int v(int i, int min, int max, int def) => i < p.length && p[i] != null ? p[i]!.clamp(min, max) : def;
    return EstiloCreado(
      envergadura: v(0, envergaduraMin, envergaduraMax, 0),
      mano: v(1, 0, manos.length - 1, 0),
      origen: OrigenJugador.values[v(2, 0, OrigenJugador.values.length - 1, 1)],
      formaDeTiro: v(3, 0, formas.length - 1, 0),
      festejo: v(4, 0, festejos.length - 1, 0),
    );
  }
}
