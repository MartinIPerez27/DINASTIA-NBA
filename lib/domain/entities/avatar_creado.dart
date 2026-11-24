/// Rasgos del avatar que elige el usuario al crear su jugador. Son índices sobre las paletas y los
/// estilos que dibuja `AvatarIlustrado` (la entidad no depende de Flutter). Se guarda como un código
/// corto en la carta (`Jugador.avatar`).
class AvatarCreado {
  const AvatarCreado({this.piel = 2, this.pelo = 1, this.estilo = 1, this.barba = false, this.ancho = 4, this.alto = 3});

  /// Cantidad de opciones de cada rasgo.
  static const pieles = 6, pelos = 8, estilos = 7, anchos = 9, altos = 8;

  final int piel, pelo, estilo, ancho, alto;
  final bool barba;

  AvatarCreado copyWith({int? piel, int? pelo, int? estilo, bool? barba, int? ancho, int? alto}) => AvatarCreado(
    piel: piel ?? this.piel,
    pelo: pelo ?? this.pelo,
    estilo: estilo ?? this.estilo,
    barba: barba ?? this.barba,
    ancho: ancho ?? this.ancho,
    alto: alto ?? this.alto,
  );

  /// Código compacto: "piel.pelo.estilo.barba.ancho.alto".
  String get codigo => '$piel.$pelo.$estilo.${barba ? 1 : 0}.$ancho.$alto';

  /// Lee un [codigo]; tolera valores fuera de rango o cortados (usa el valor por defecto).
  static AvatarCreado? deCodigo(String? codigo) {
    if (codigo == null) return null;
    final p = codigo.split('.').map(int.tryParse).toList();
    int v(int i, int max, int def) => i < p.length && p[i] != null ? p[i]!.clamp(0, max - 1) : def;
    return AvatarCreado(
      piel: v(0, pieles, 2),
      pelo: v(1, pelos, 1),
      estilo: v(2, estilos, 1),
      barba: v(3, 2, 0) == 1,
      ancho: v(4, anchos, 4),
      alto: v(5, altos, 3),
    );
  }
}
