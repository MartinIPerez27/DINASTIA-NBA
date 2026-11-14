/// Retoques chicos y explícitos al rendimiento de un equipo en un partido (insignias del Camino al
/// anillo y otros modos). Los valores por defecto son neutros: un partido clásico no cambia.
///
/// Los "extra" se suman a la probabilidad de acierto (0.02 = +2 puntos porcentuales); los
/// "factor" multiplican la frecuencia de algo (1.2 = 20 % más).
class ModificadoresEquipo {
  const ModificadoresEquipo({
    this.tripleExtra = 0,
    this.interiorExtra = 0,
    this.asistidoExtra = 0,
    this.clutchExtra = 0,
    this.estrellaCuartoFinal = 0,
    this.quimicaExtra = 0,
    this.interiorRival = 0,
    this.fatigaFactor = 1,
    this.fatigaRivalFactor = 1,
    this.contraataqueFactor = 1,
    this.robosFactor = 1,
    this.reboteOfensivoFactor = 1,
  });

  static const neutros = ModificadoresEquipo();

  /// + al acierto en triples y en dobles propios.
  final double tripleExtra, interiorExtra;

  /// + al acierto de los tiros con asistencia.
  final double asistidoExtra;

  /// + al acierto en el clutch (últimos 5 minutos, partido cerrado).
  final double clutchExtra;

  /// + al acierto de tu máximo anotador en cancha en el último cuarto (y la prórroga).
  final double estrellaCuartoFinal;

  /// + al acierto de todos (química extra).
  final double quimicaExtra;

  /// − al acierto en dobles del rival (protección de aro).
  final double interiorRival;

  /// Cansancio propio (0.85 = 15 % menos) y del rival (1.12 = el rival se cansa 12 % más).
  final double fatigaFactor, fatigaRivalFactor;

  /// Frecuencia de contraataques después de un robo o un rebote defensivo.
  final double contraataqueFactor;

  /// Frecuencia de pérdidas que fuerza tu defensa.
  final double robosFactor;

  /// Probabilidad de tomar el rebote ofensivo.
  final double reboteOfensivoFactor;

  bool get esNeutro =>
      tripleExtra == 0 &&
      interiorExtra == 0 &&
      asistidoExtra == 0 &&
      clutchExtra == 0 &&
      estrellaCuartoFinal == 0 &&
      quimicaExtra == 0 &&
      interiorRival == 0 &&
      fatigaFactor == 1 &&
      fatigaRivalFactor == 1 &&
      contraataqueFactor == 1 &&
      robosFactor == 1 &&
      reboteOfensivoFactor == 1;

  /// Suma dos juegos de retoques (los extra se suman, los factores se multiplican).
  ModificadoresEquipo mas(ModificadoresEquipo o) => ModificadoresEquipo(
    tripleExtra: tripleExtra + o.tripleExtra,
    interiorExtra: interiorExtra + o.interiorExtra,
    asistidoExtra: asistidoExtra + o.asistidoExtra,
    clutchExtra: clutchExtra + o.clutchExtra,
    estrellaCuartoFinal: estrellaCuartoFinal + o.estrellaCuartoFinal,
    quimicaExtra: quimicaExtra + o.quimicaExtra,
    interiorRival: interiorRival + o.interiorRival,
    fatigaFactor: fatigaFactor * o.fatigaFactor,
    fatigaRivalFactor: fatigaRivalFactor * o.fatigaRivalFactor,
    contraataqueFactor: contraataqueFactor * o.contraataqueFactor,
    robosFactor: robosFactor * o.robosFactor,
    reboteOfensivoFactor: reboteOfensivoFactor * o.reboteOfensivoFactor,
  );
}
