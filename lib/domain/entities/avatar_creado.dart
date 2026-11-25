/// Rasgos del avatar que elige el usuario al crear su jugador. Son índices sobre las paletas y los estilos que
/// dibuja `AvatarIlustrado` (la entidad no depende de Flutter). Se guarda como un código corto en la carta
/// (`Jugador.avatar`): "piel.pelo.estilo.barba.ancho.alto.ojos.cejas.nariz.boca.orejas.tatuaje.gafas.cinta.cuerpo".
/// Los códigos viejos (solo los primeros seis) siguen cargando: lo que falta toma el valor por defecto.
class AvatarCreado {
  const AvatarCreado({
    this.piel = 2,
    this.pelo = 1,
    this.estilo = 1,
    this.barba = 0,
    this.ancho = 4,
    this.alto = 3,
    this.ojos = 0,
    this.cejas = 1,
    this.nariz = 1,
    this.boca = 0,
    this.orejas = 1,
    this.tatuaje = 0,
    this.gafas = 0,
    this.cinta = false,
    this.cuerpo = 2,
  });

  /// Cantidad de opciones de cada rasgo.
  static const pieles = 6, pelos = 8, estilos = 20, barbas = 7, anchos = 9, altos = 8;
  static const ojosN = 6, cejasN = 5, narices = 5, bocas = 5, orejasN = 3, tatuajes = 5, gafasN = 4, cuerpos = 5;

  static const nombresEstilo = [
    'Calvo', 'Corto', 'Rapado', 'Rizado', 'Moño', 'Largo', 'Vincha',
    'Afro', 'Trenzas', 'Rastas', 'Mohicano', 'Plano', 'Undercut', 'Degradé',
    'Ondas', 'Peinado atrás', 'Raya al costado', 'Colita alta', 'Dos moños', 'Rulos largos',
  ];
  static const nombresBarba = ['Sin barba', 'Sombra', 'Candado', 'Perilla', 'Completa', 'Bigote', 'Chivita'];
  static const nombresOjos = ['Clásicos', 'Rasgados', 'Grandes', 'Caídos', 'Serios', 'Pequeños'];
  static const nombresCejas = ['Finas', 'Medias', 'Gruesas', 'Arqueadas', 'Fruncidas'];
  static const nombresNariz = ['Chica', 'Media', 'Ancha', 'Aguileña', 'Respingada'];
  static const nombresBoca = ['Seria', 'Sonrisa', 'Sonrisa amplia', 'Mueca', 'Chiquita'];
  static const nombresOrejas = ['Chicas', 'Medias', 'Grandes'];
  static const nombresTatuaje = ['Ninguno', 'Hombro', 'Cuello', 'Los dos hombros', 'Cuello y hombro'];
  static const nombresGafas = ['Ninguna', 'Deportivas', 'Redondas', 'De sol'];
  static const nombresCuerpo = ['Delgado', 'Atlético', 'Normal', 'Fornido', 'Muy fornido'];

  final int piel, pelo, estilo, barba, ancho, alto;
  final int ojos, cejas, nariz, boca, orejas, tatuaje, gafas, cuerpo;
  final bool cinta;

  AvatarCreado copyWith({
    int? piel,
    int? pelo,
    int? estilo,
    int? barba,
    int? ancho,
    int? alto,
    int? ojos,
    int? cejas,
    int? nariz,
    int? boca,
    int? orejas,
    int? tatuaje,
    int? gafas,
    bool? cinta,
    int? cuerpo,
  }) => AvatarCreado(
    piel: piel ?? this.piel,
    pelo: pelo ?? this.pelo,
    estilo: estilo ?? this.estilo,
    barba: barba ?? this.barba,
    ancho: ancho ?? this.ancho,
    alto: alto ?? this.alto,
    ojos: ojos ?? this.ojos,
    cejas: cejas ?? this.cejas,
    nariz: nariz ?? this.nariz,
    boca: boca ?? this.boca,
    orejas: orejas ?? this.orejas,
    tatuaje: tatuaje ?? this.tatuaje,
    gafas: gafas ?? this.gafas,
    cinta: cinta ?? this.cinta,
    cuerpo: cuerpo ?? this.cuerpo,
  );

  String get codigo =>
      '$piel.$pelo.$estilo.$barba.$ancho.$alto.$ojos.$cejas.$nariz.$boca.$orejas.$tatuaje.$gafas.${cinta ? 1 : 0}.$cuerpo';

  /// Lee un [codigo]; tolera valores fuera de rango o cortados (usa el valor por defecto).
  static AvatarCreado? deCodigo(String? codigo) {
    if (codigo == null) return null;
    final p = codigo.split('.').map(int.tryParse).toList();
    const d = AvatarCreado();
    int v(int i, int max, int def) => i < p.length && p[i] != null ? p[i]!.clamp(0, max - 1) : def;
    return AvatarCreado(
      piel: v(0, pieles, d.piel),
      pelo: v(1, pelos, d.pelo),
      estilo: v(2, estilos, d.estilo),
      barba: v(3, barbas, d.barba),
      ancho: v(4, anchos, d.ancho),
      alto: v(5, altos, d.alto),
      ojos: v(6, ojosN, d.ojos),
      cejas: v(7, cejasN, d.cejas),
      nariz: v(8, narices, d.nariz),
      boca: v(9, bocas, d.boca),
      orejas: v(10, orejasN, d.orejas),
      tatuaje: v(11, tatuajes, d.tatuaje),
      gafas: v(12, gafasN, d.gafas),
      cinta: v(13, 2, 0) == 1,
      cuerpo: v(14, cuerpos, d.cuerpo),
    );
  }
}
