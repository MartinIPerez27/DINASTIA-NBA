import 'posicion.dart';

/// Arquetipos tácticos por posición (GDD §3.2). Dictan tendencias en el motor de posesiones.
enum RolCancha {
  // BASE
  organizadorPuro('Organizador Puro', 'Floor General', Posicion.base),
  anotadorExterior('Anotador Exterior', 'Scoring Guard', Posicion.base),
  penetradorAtletico('Penetrador Atlético', 'Slasher', Posicion.base),
  baseDefensivo('Base Defensivo / Perro de Presa', 'Lockdown Stopper', Posicion.base),

  // ESCOLTA
  superestrellaAclarados('Superestrella en Aclarados', 'Iso Master', Posicion.escolta),
  tiradorPantallas('Tirador de Pantallas', 'Catch & Shoot', Posicion.escolta),
  escoltaGenerador('Escolta Generador', 'Combo Guard', Posicion.escolta),
  especialista3D('Especialista 3&D', '3&D', Posicion.escolta),

  // ALERO
  controladorTotal('Controlador Total', 'Point Forward', Posicion.alero),
  anotadorTresNiveles('Anotador de Tres Niveles', 'Wing Assassin', Posicion.alero),
  cerrojoDefensivo('Cerrojo Defensivo', 'Wing Stopper', Posicion.alero),
  aleroCortador('Alero Cortador y Enérgico', 'Transition Slasher', Posicion.alero),

  // ALA-PÍVOT
  maestroPoste('Maestro del Poste Medio', 'Post Master', Posicion.alaPivot),
  alaPivotTirador('Ala-Pívot Tirador', 'Stretch Four', Posicion.alaPivot),
  fuerzaBruta('Fuerza Bruta y Rebote', 'Glass Cleaner', Posicion.alaPivot),
  distribuidorInterior('Distribuidor Interior', 'Playmaking Big', Posicion.alaPivot),

  // PÍVOT
  goliatPintura('Goliat de Pintura', 'Paint Dominator', Posicion.pivot),
  juegoDePies('Especialista en Juego de Pies', 'Footwork & Finesse', Posicion.pivot),
  protectorAro('Protector de Aro y Reboteador', 'Rim Protector', Posicion.pivot),
  pivotOrganizador('Pívot Organizador', 'Point Center', Posicion.pivot),
  pivotTirador('Pívot Tirador', 'Stretch Five', Posicion.pivot),

  // SEXTO HOMBRE
  microondas('Microondas Anotador', 'Instant Offense', Posicion.sextoHombre),
  directorSegundaUnidad('Director de Segunda Unidad', 'Bench Playmaker', Posicion.sextoHombre),
  inyeccionEnergia('Inyección de Energía y Defensa', 'Energy Defender', Posicion.sextoHombre);

  const RolCancha(this.etiqueta, this.apodo, this.posicion);

  final String etiqueta;

  /// Nombre original en inglés, mostrado en cursiva como en el GDD.
  final String apodo;

  /// Posición a la que pertenece el arquetipo en el catálogo.
  final Posicion posicion;
}
