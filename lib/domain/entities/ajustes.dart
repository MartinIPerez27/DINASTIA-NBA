/// Cómo se cuenta el partido: los dos personajes, solo el Relator, o todo en texto (sin voz).
enum ModoRelato {
  /// Relator y Comentarista, en pantalla y (si la voz está activa) en voz.
  completo('Relato completo', 'Relator y Comentarista dialogan.'),

  /// Solo las líneas del Relator, más sobrias.
  soloRelator('Solo Relator', 'Solo el Relator, sin el color del Comentarista.'),

  /// Los dos en pantalla pero nunca en voz, aunque la voz esté activada.
  soloTexto('Solo texto', 'Los dos en pantalla, sin voz.');

  const ModoRelato(this.nombre, this.descripcion);
  final String nombre, descripcion;
}

/// Preferencias del jugador.
class Ajustes {
  const Ajustes({
    this.velocidad = 2,
    this.sonido = true,
    this.vozRelator = false,
    this.vibracion = true,
    this.efectosReducidos = false,
    this.tutorialVisto = false,
    this.decisiones = true,
    this.modoRelato = ModoRelato.completo,
  });

  /// Velocidad con la que arranca el partido en vivo (1, 2 o 4).
  final int velocidad;
  final bool sonido;

  /// El relator lee las jugadas en voz alta (voz del sistema, sin internet).
  final bool vozRelator;
  final bool vibracion;

  /// Sin zoom de cámara ni efectos de pantalla (para celulares modestos o por gusto).
  final bool efectosReducidos;
  final bool tutorialVisto;

  /// El partido se frena para sugerirte decisiones (tiempo muerto, ajustes, el último tiro…).
  final bool decisiones;

  /// Relato completo, solo Relator o solo texto (la voz se activa aparte con [vozRelator]).
  final ModoRelato modoRelato;

  Ajustes copyWith({
    int? velocidad,
    bool? sonido,
    bool? vozRelator,
    bool? vibracion,
    bool? efectosReducidos,
    bool? tutorialVisto,
    bool? decisiones,
    ModoRelato? modoRelato,
  }) => Ajustes(
    velocidad: velocidad ?? this.velocidad,
    sonido: sonido ?? this.sonido,
    vozRelator: vozRelator ?? this.vozRelator,
    vibracion: vibracion ?? this.vibracion,
    efectosReducidos: efectosReducidos ?? this.efectosReducidos,
    tutorialVisto: tutorialVisto ?? this.tutorialVisto,
    decisiones: decisiones ?? this.decisiones,
    modoRelato: modoRelato ?? this.modoRelato,
  );

  factory Ajustes.fromJson(Map<String, dynamic> j) => Ajustes(
    velocidad: j['velocidad'] as int? ?? 2,
    sonido: j['sonido'] as bool? ?? true,
    vozRelator: j['voz'] as bool? ?? false,
    vibracion: j['vibracion'] as bool? ?? true,
    efectosReducidos: j['efectosReducidos'] as bool? ?? false,
    tutorialVisto: j['tutorialVisto'] as bool? ?? false,
    decisiones: j['decisiones'] as bool? ?? true,
    modoRelato: switch (j['modoRelato']) {
      final int i when i >= 0 && i < ModoRelato.values.length => ModoRelato.values[i],
      _ => ModoRelato.completo,
    },
  );

  Map<String, dynamic> toJson() => {
    'velocidad': velocidad,
    'sonido': sonido,
    'voz': vozRelator,
    'vibracion': vibracion,
    'efectosReducidos': efectosReducidos,
    'tutorialVisto': tutorialVisto,
    'decisiones': decisiones,
    'modoRelato': modoRelato.index,
  };
}
