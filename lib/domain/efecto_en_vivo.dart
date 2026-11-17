import 'entities/tactica.dart';
import 'modificadores.dart';

/// Ajuste temporal de un equipo durante un partido en vivo (decisiones del entrenador). El motor lo lee
/// por equipo (`MotorPartido.aplicarEfecto`); si no hay ninguno, el partido es idéntico al de siempre.
///
/// Todo es opcional y neutro por defecto. Los "factor" multiplican (1 = neutro); los "extra" se suman a la
/// probabilidad de acierto (0.02 = +2 puntos porcentuales).
class EfectoEnVivo {
  const EfectoEnVivo({
    this.mods = ModificadoresEquipo.neutros,
    this.defensa,
    this.ataque,
    this.ritmo = 0,
    this.tripleRival = 1,
    this.interiorRival = 1,
    this.robosFactor = 1,
    this.fatigaFactor = 1,
    this.foco,
    this.focoPeso = 1,
    this.focoExtra = 0,
    this.faltar = 0,
    this.linea,
    this.lineaRiesgo = 0,
    this.aguantar = false,
  });

  /// Retoques de acierto, fatiga, rebote, etc. (se suman a los del equipo mientras dura).
  final ModificadoresEquipo mods;

  /// Esquema defensivo / sistema ofensivo que reemplazan a los del plantel mientras dura.
  final EsquemaDefensivo? defensa;
  final SistemaOfensivo? ataque;

  /// Se suma al ritmo del equipo (+1 acelera, −1 enfría el partido).
  final double ritmo;

  /// Multiplican el acierto del rival en triples y en dobles (0.92 = lo cerrás un 8 %).
  final double tripleRival, interiorRival;

  /// Multiplican las pérdidas que fuerza tu defensa y el cansancio propio.
  final double robosFactor, fatigaFactor;

  /// Jugador al que se le busca más ([focoPeso] veces más tiros) y cuánto le cuesta en puntería.
  final String? foco;
  final double focoPeso, focoExtra;

  /// Probabilidad, en cada posesión rival, de frenar el juego con una falta intencional al peor tirador de
  /// libres (hack) o a quien tenga la pelota al final.
  final double faltar;

  /// Quién recibe la pelota cuando el rival hace falta intencional, y el riesgo de perderla en el saque.
  final String? linea;
  final double lineaRiesgo;

  /// No sentar a nadie por faltas mientras dura (el entrenador se la juega con el cargado).
  final bool aguantar;

  bool get esNeutro =>
      mods.esNeutro &&
      defensa == null &&
      ataque == null &&
      ritmo == 0 &&
      tripleRival == 1 &&
      interiorRival == 1 &&
      robosFactor == 1 &&
      fatigaFactor == 1 &&
      foco == null &&
      focoExtra == 0 &&
      faltar == 0 &&
      linea == null &&
      !aguantar;

  /// Junta dos ajustes (los extra se suman, los factores se multiplican; lo "elegido" se queda con el último).
  EfectoEnVivo mas(EfectoEnVivo o) => EfectoEnVivo(
    mods: mods.mas(o.mods),
    defensa: o.defensa ?? defensa,
    ataque: o.ataque ?? ataque,
    ritmo: ritmo + o.ritmo,
    tripleRival: tripleRival * o.tripleRival,
    interiorRival: interiorRival * o.interiorRival,
    robosFactor: robosFactor * o.robosFactor,
    fatigaFactor: fatigaFactor * o.fatigaFactor,
    foco: o.foco ?? foco,
    focoPeso: o.foco != null ? o.focoPeso : focoPeso,
    focoExtra: o.foco != null ? o.focoExtra : focoExtra,
    faltar: faltar > o.faltar ? faltar : o.faltar,
    linea: o.linea ?? linea,
    lineaRiesgo: o.linea != null ? o.lineaRiesgo : lineaRiesgo,
    aguantar: aguantar || o.aguantar,
  );
}
