/// Los 6 puestos del plantel (GDD §3.1).
enum Posicion {
  base('BASE'),
  escolta('ESCOLTA'),
  alero('ALERO'),
  alaPivot('ALA-PÍVOT'),
  pivot('PÍVOT'),
  sextoHombre('SEXTO HOMBRE');

  const Posicion(this.etiqueta);

  /// Texto visible en la UI, en español latino.
  final String etiqueta;

  static const titulares = [base, escolta, alero, alaPivot, pivot];

  bool get esTitular => this != sextoHombre;

  /// Acepta las variantes que usa el GDD: 'PIVOT'/'PÍVOT', 'SEXTO-HOMBRE'/'SEXTO HOMBRE'.
  static Posicion desdeEtiqueta(String texto) {
    final buscado = _normalizar(texto);
    for (final p in values) {
      if (_normalizar(p.etiqueta) == buscado) return p;
    }
    throw FormatException('Posición desconocida: $texto');
  }

  static String _normalizar(String s) => s.trim().toUpperCase().replaceAll('Í', 'I').replaceAll('-', ' ');
}
