/// Los tokens del draft: ayudas que se gastan (con monedas del juego) durante el armado del plantel.
enum TokenDraft {
  volverATirar(
    'Volver a tirar',
    'VOLVER A TIRAR',
    'Descartás la tirada y los carretes giran de nuevo (podés retener hasta 2).',
  ),
  mejorVersion(
    'Mejor versión',
    'MEJOR VERSIÓN',
    'Cambiás una carta que salió por la versión de mayor media de esa misma persona.',
  ),
  doble('Doble', 'DOBLE', 'Con la misma tirada elegís dos jugadores, cada uno en su puesto.'),
  intercambio(
    'Intercambio',
    'INTERCAMBIO',
    'Cambiás una carta ya elegida por otra de esta tirada que juegue el mismo puesto.',
  ),
  comodin('Comodín', 'COMODÍN', 'Fijás la franquicia o la época de la próxima tirada.');

  const TokenDraft(this.nombre, this.rotulo, this.descripcion);
  final String nombre;

  /// Texto corto en mayúsculas para la bandeja.
  final String rotulo;
  final String descripcion;
}

/// Lo que se gastó de cada token en un draft, las monedas que costó y el estado de la tirada en
/// curso (cartas sustituidas por su mejor versión, pick extra del Doble). Vive en la
/// [Temporada] y va al JSON como `tokens` (opcional: las partidas viejas cargan vacías).
class TokensTemporada {
  const TokensTemporada({
    this.usos = const {},
    this.pagos = const {},
    this.gastadas = 0,
    this.sustituidas = const {},
    this.picksExtra = 0,
  });

  /// Veces que se usó cada token en este draft (gratis y de pago). Las fichas gratis de volver a
  /// tirar bajan además `Temporada.rerollsRestantes`.
  final Map<TokenDraft, int> usos;

  /// De esos usos, cuántos se pagaron con monedas (el precio sube con cada uno).
  final Map<TokenDraft, int> pagos;

  /// Monedas gastadas en tokens en esta partida.
  final int gastadas;

  /// Tirada en curso: id de la carta que salió → id de su mejor versión (Mejor versión).
  final Map<String, String> sustituidas;

  /// Doble: cuántas elecciones extra quedan con la tirada en curso.
  final int picksExtra;

  int usosDe(TokenDraft k) => usos[k] ?? 0;
  int pagosDe(TokenDraft k) => pagos[k] ?? 0;
  int get usosTotales => usos.values.fold(0, (a, b) => a + b);

  /// ¿Se pagó algo con monedas? Una partida así ya no se puede retar: las ventajas no serían iguales.
  bool get usoPagos => gastadas > 0 || pagos.values.any((n) => n > 0);

  bool get vacio => usos.isEmpty && pagos.isEmpty && gastadas == 0 && sustituidas.isEmpty && picksExtra == 0;

  /// Registra un uso (con [precio] > 0 se cuenta como de pago).
  TokensTemporada conUso(TokenDraft k, {int precio = 0}) => copyWith(
    usos: {...usos, k: usosDe(k) + 1},
    pagos: precio > 0 ? {...pagos, k: pagosDe(k) + 1} : null,
    gastadas: gastadas + precio,
  );

  /// Cierra la tirada en curso: sin sustituciones ni picks extra.
  TokensTemporada get sinTirada => copyWith(sustituidas: const {}, picksExtra: 0);

  TokensTemporada copyWith({
    Map<TokenDraft, int>? usos,
    Map<TokenDraft, int>? pagos,
    int? gastadas,
    Map<String, String>? sustituidas,
    int? picksExtra,
  }) => TokensTemporada(
    usos: usos ?? this.usos,
    pagos: pagos ?? this.pagos,
    gastadas: gastadas ?? this.gastadas,
    sustituidas: sustituidas ?? this.sustituidas,
    picksExtra: picksExtra ?? this.picksExtra,
  );

  factory TokensTemporada.fromJson(Map<String, dynamic> j) {
    Map<TokenDraft, int> mapa(Object? m) => {
      for (final e in (m as Map<String, dynamic>? ?? const {}).entries)
        ?TokenDraft.values.asNameMap()[e.key]: e.value as int,
    };
    return TokensTemporada(
      usos: mapa(j['usos']),
      pagos: mapa(j['pagos']),
      gastadas: j['gastadas'] as int? ?? 0,
      sustituidas: (j['sustituidas'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, v as String)),
      picksExtra: j['picksExtra'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (usos.isNotEmpty) 'usos': {for (final e in usos.entries) e.key.name: e.value},
    if (pagos.isNotEmpty) 'pagos': {for (final e in pagos.entries) e.key.name: e.value},
    if (gastadas > 0) 'gastadas': gastadas,
    if (sustituidas.isNotEmpty) 'sustituidas': sustituidas,
    if (picksExtra > 0) 'picksExtra': picksExtra,
  };
}
