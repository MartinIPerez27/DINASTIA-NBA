/// Preferencias del jugador.
class Ajustes {
  const Ajustes({
    this.velocidad = 2,
    this.sonido = true,
    this.vozRelator = false,
    this.vibracion = true,
    this.efectosReducidos = false,
    this.tutorialVisto = false,
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

  Ajustes copyWith({
    int? velocidad,
    bool? sonido,
    bool? vozRelator,
    bool? vibracion,
    bool? efectosReducidos,
    bool? tutorialVisto,
  }) => Ajustes(
    velocidad: velocidad ?? this.velocidad,
    sonido: sonido ?? this.sonido,
    vozRelator: vozRelator ?? this.vozRelator,
    vibracion: vibracion ?? this.vibracion,
    efectosReducidos: efectosReducidos ?? this.efectosReducidos,
    tutorialVisto: tutorialVisto ?? this.tutorialVisto,
  );

  factory Ajustes.fromJson(Map<String, dynamic> j) => Ajustes(
    velocidad: j['velocidad'] as int? ?? 2,
    sonido: j['sonido'] as bool? ?? true,
    vozRelator: j['voz'] as bool? ?? false,
    vibracion: j['vibracion'] as bool? ?? true,
    efectosReducidos: j['efectosReducidos'] as bool? ?? false,
    tutorialVisto: j['tutorialVisto'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'velocidad': velocidad,
    'sonido': sonido,
    'voz': vozRelator,
    'vibracion': vibracion,
    'efectosReducidos': efectosReducidos,
    'tutorialVisto': tutorialVisto,
  };
}
