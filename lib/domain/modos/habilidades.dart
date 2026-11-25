import 'dart:math';

import 'carrera_jugador.dart';

// Habilidades específicas e insignias de Mi carrera.
//
// Los cinco atributos generales (tiro, finalización, defensa, físico, IQ) siguen mandando en la media y
// en las estadísticas. Encima de cada uno hay habilidades específicas (el triple, las bandejas, la
// defensa perimetral…): cada una vale lo que el atributo general más lo que le sumaste a esa habilidad
// ("especialización"). Las insignias miran esos valores y lo que hiciste en tu carrera, y tienen cuatro
// grados: Bronce, Plata, Oro y Leyenda.

/// Habilidades específicas, agrupadas por el atributo general al que pertenecen. Las últimas cuatro son rasgos
/// mentales (se muestran aparte): valen lo mismo que el atributo de su grupo más lo que les sumes.
enum Habilidad {
  // ----- Tiro -----
  triple(Atributo.tiro, 'Triple', 'Tiros de tres: acierto desde larga distancia.'),
  mediaDistancia(Atributo.tiro, 'Media distancia', 'Tiros de dos fuera de la pintura.'),
  tiroLibre(Atributo.tiro, 'Tiro libre', 'Acierto desde la línea.'),
  tiroDeEsquina(Atributo.tiro, 'Triple de esquina', 'El triple más corto: quieto y con los pies puestos.'),
  tiroEnMovimiento(Atributo.tiro, 'Tiro en movimiento', 'Tirar tras un bloqueo o corriendo, sin frenarte.'),
  // ----- Finalización -----
  bandeja(Atributo.finalizacion, 'Bandejas', 'Terminar cerca del aro, con las dos manos.'),
  volcada(Atributo.finalizacion, 'Volcadas', 'Castigar al aro con potencia.'),
  poste(Atributo.finalizacion, 'Juego de poste', 'Jugadas de espaldas al aro.'),
  tiroCercano(Atributo.finalizacion, 'Tiro cercano', 'Tiros cortos dentro de la pintura.'),
  finalizacionContacto(Atributo.finalizacion, 'Terminar con contacto', 'Meter la bandeja aunque te golpeen.'),
  flotadora(Atributo.finalizacion, 'Flotadora', 'Tiro suave sobre los grandes.'),
  alleyOop(Atributo.finalizacion, 'Alley-oop', 'Recibir en el aire y rematar.'),
  // ----- Defensa -----
  defPerimetral(Atributo.defensa, 'Defensa perimetral', 'Aguantar a los exteriores uno contra uno.'),
  defInterior(Atributo.defensa, 'Defensa interior', 'Cuidar la pintura y proteger el aro.'),
  robo(Atributo.defensa, 'Robo', 'Manos rápidas: cortar pases y quitar la pelota.'),
  tapon(Atributo.defensa, 'Tapón', 'Cronometrar y tapar tiros.'),
  velocidadLateral(Atributo.defensa, 'Velocidad lateral', 'Seguir al rival de lado a lado.'),
  ayudaDefensiva(Atributo.defensa, 'Ayuda defensiva', 'Leer cuándo ayudar a un compañero.'),
  defensaDePoste(Atributo.defensa, 'Defensa de poste', 'Aguantar a los grandes de espaldas al aro.'),
  // ----- Físico -----
  velocidad(Atributo.fisico, 'Velocidad', 'Arranque y primer paso.'),
  fuerza(Atributo.fisico, 'Fuerza', 'Aguantar el contacto y ganar posición.'),
  salto(Atributo.fisico, 'Salto', 'Explosión vertical.'),
  resistencia(Atributo.fisico, 'Resistencia', 'Rendir los 48 minutos sin caerte.'),
  rebote(Atributo.fisico, 'Rebote defensivo', 'Posicionarte y ganar la pelota en tu aro.'),
  reboteOfensivo(Atributo.fisico, 'Rebote ofensivo', 'Pelear la segunda oportunidad.'),
  agilidad(Atributo.fisico, 'Agilidad', 'Cambiar de dirección sin perder el equilibrio.'),
  recuperacion(Atributo.fisico, 'Recuperación', 'Volver a tope entre posesiones y partidos.'),
  // ----- IQ y pase -----
  manejo(Atributo.iq, 'Manejo', 'Dribling seguro, sin perderla.'),
  velocidadConPelota(Atributo.iq, 'Velocidad con pelota', 'Subir rápido sin perder el control.'),
  pase(Atributo.iq, 'Pase', 'Precisión y variedad al asistir.'),
  vision(Atributo.iq, 'Visión de juego', 'Leer la defensa y anticipar.'),
  iqOfensivo(Atributo.iq, 'IQ ofensivo', 'Elegir la mejor jugada en cada posesión.'),
  iqDefensivo(Atributo.iq, 'IQ defensivo', 'Anticipar rotaciones y pases.'),
  creacionDeTiro(Atributo.iq, 'Crear tiro propio', 'Generarte un tiro sin ayuda.'),
  // ----- Rasgos mentales -----
  consistencia(Atributo.iq, 'Consistencia', 'Rendir parecido todas las noches.'),
  clutch(Atributo.iq, 'Clutch', 'Crecerte cuando el partido se aprieta.'),
  durabilidad(Atributo.fisico, 'Durabilidad', 'Menos lesiones y menos desgaste con los años.'),
  garra(Atributo.defensa, 'Garra', 'Ir a todas las pelotas: robos, rebotes y esfuerzo.');

  const Habilidad(this.atributo, this.etiqueta, this.descripcion);
  final Atributo atributo;
  final String etiqueta, descripcion;

  /// Lo máximo que se le puede sumar a una habilidad por encima de su atributo general.
  static const maxEspecializacion = 20;

  /// Los cuatro rasgos mentales.
  static const mentales = [consistencia, clutch, durabilidad, garra];

  bool get esMental => mentales.contains(this);

  /// Las habilidades técnicas de un atributo (sin los rasgos mentales).
  static List<Habilidad> de(Atributo a) => [
    for (final h in values)
      if (h.atributo == a && !h.esMental) h,
  ];

  /// Valor de la habilidad (25 a 99): el atributo general más su especialización.
  static int valor(Habilidad h, Atributos a, Map<Habilidad, int> espec) =>
      (a[h.atributo] + (espec[h] ?? 0)).clamp(25, 99);

  /// Estadísticas que mueve cada punto de especialización (sobre lo que ya da el atributo general).
  static EfectoStats efectoPorPunto(Habilidad h) => switch (h) {
    Habilidad.triple => const EfectoStats(pctT3: 0.0015),
    Habilidad.mediaDistancia => const EfectoStats(ppp: 0.04),
    Habilidad.tiroLibre => const EfectoStats(pctTl: 0.0025),
    Habilidad.tiroDeEsquina => const EfectoStats(pctT3: 0.0008, ppp: 0.01),
    Habilidad.tiroEnMovimiento => const EfectoStats(pctT3: 0.0006, ppp: 0.02),
    Habilidad.bandeja => const EfectoStats(pctTc: 0.001),
    Habilidad.volcada => const EfectoStats(ppp: 0.04),
    Habilidad.poste => const EfectoStats(ppp: 0.03, rpp: 0.01),
    Habilidad.tiroCercano => const EfectoStats(pctTc: 0.0008, ppp: 0.01),
    Habilidad.finalizacionContacto => const EfectoStats(pctTc: 0.0008, rpp: 0.005),
    Habilidad.flotadora => const EfectoStats(pctTc: 0.0006, ppp: 0.015),
    Habilidad.alleyOop => const EfectoStats(ppp: 0.025),
    Habilidad.defPerimetral => const EfectoStats(robP: 0.008),
    Habilidad.defInterior => const EfectoStats(tapP: 0.008),
    Habilidad.robo => const EfectoStats(robP: 0.012),
    Habilidad.tapon => const EfectoStats(tapP: 0.01),
    Habilidad.velocidadLateral => const EfectoStats(robP: 0.005),
    Habilidad.ayudaDefensiva => const EfectoStats(tapP: 0.004, robP: 0.003),
    Habilidad.defensaDePoste => const EfectoStats(tapP: 0.004, rpp: 0.006),
    Habilidad.velocidad => const EfectoStats(ppp: 0.02),
    Habilidad.fuerza => const EfectoStats(rpp: 0.03),
    Habilidad.salto => const EfectoStats(rpp: 0.02, tapP: 0.004),
    Habilidad.resistencia => const EfectoStats(minP: 0.08),
    Habilidad.rebote => const EfectoStats(rpp: 0.05),
    Habilidad.reboteOfensivo => const EfectoStats(rpp: 0.03, ppp: 0.01),
    Habilidad.agilidad => const EfectoStats(ppp: 0.01, robP: 0.004),
    Habilidad.recuperacion => const EfectoStats(minP: 0.05),
    Habilidad.manejo => const EfectoStats(perP: -0.012),
    Habilidad.velocidadConPelota => const EfectoStats(ppp: 0.015, perP: -0.004),
    Habilidad.pase => const EfectoStats(app: 0.05),
    Habilidad.vision => const EfectoStats(app: 0.03),
    Habilidad.iqOfensivo => const EfectoStats(app: 0.015, perP: -0.006, pctTc: 0.0004),
    Habilidad.iqDefensivo => const EfectoStats(robP: 0.004, tapP: 0.002),
    Habilidad.creacionDeTiro => const EfectoStats(ppp: 0.035),
    Habilidad.consistencia => const EfectoStats(pctTc: 0.0008, perP: -0.006),
    Habilidad.clutch => const EfectoStats(ppp: 0.02),
    Habilidad.durabilidad => const EfectoStats(minP: 0.06),
    Habilidad.garra => const EfectoStats(robP: 0.006, rpp: 0.012),
  };
}

/// Un retoque sobre la línea estadística. Los valores se suman tal cual (o se multiplican por puntos/grados).
class EfectoStats {
  const EfectoStats({
    this.ppp = 0,
    this.rpp = 0,
    this.app = 0,
    this.robP = 0,
    this.tapP = 0,
    this.pctTc = 0,
    this.pctT3 = 0,
    this.pctTl = 0,
    this.minP = 0,
    this.perP = 0,
  });

  final double ppp, rpp, app, robP, tapP, pctTc, pctT3, pctTl, minP, perP;

  EfectoStats por(double k) => EfectoStats(
    ppp: ppp * k,
    rpp: rpp * k,
    app: app * k,
    robP: robP * k,
    tapP: tapP * k,
    pctTc: pctTc * k,
    pctT3: pctT3 * k,
    pctTl: pctTl * k,
    minP: minP * k,
    perP: perP * k,
  );

  EfectoStats mas(EfectoStats o) => EfectoStats(
    ppp: ppp + o.ppp,
    rpp: rpp + o.rpp,
    app: app + o.app,
    robP: robP + o.robP,
    tapP: tapP + o.tapP,
    pctTc: pctTc + o.pctTc,
    pctT3: pctT3 + o.pctT3,
    pctTl: pctTl + o.pctTl,
    minP: minP + o.minP,
    perP: perP + o.perP,
  );
}

/// Grado de una insignia. [ninguno] = todavía no la tenés.
enum GradoInsignia {
  ninguno('—', 0),
  bronce('Bronce', 1),
  plata('Plata', 2),
  oro('Oro', 3),
  leyenda('Leyenda', 4);

  const GradoInsignia(this.etiqueta, this.nivel);
  final String etiqueta;
  final int nivel;

  /// Cuánto de su efecto aplica el grado (Bronce = 1).
  double get factor => switch (this) {
    ninguno => 0,
    bronce => 1,
    plata => 1.5,
    oro => 2,
    leyenda => 2.5,
  };

  static GradoInsignia deNivel(int n) => values[n.clamp(0, 4)];
}

/// Todo lo que miran las insignias: atributos, especializaciones y lo hecho en la carrera.
class ContextoInsignia {
  const ContextoInsignia({
    required this.atributos,
    this.espec = const {},
    this.pts = 0,
    this.reb = 0,
    this.ast = 0,
    this.pj = 0,
    this.titulos = 0,
    this.allStar = 0,
    this.premios = 0,
    this.clutch = 0,
    this.fans = 40,
  });

  final Atributos atributos;
  final Map<Habilidad, int> espec;

  /// Totales de carrera (puntos, rebotes y asistencias sumados de todos los partidos).
  final int pts, reb, ast, pj;
  final int titulos, allStar, premios;

  /// Jugadas decisivas que resolviste en partidos en vivo (ver `EstadoCarrera.uso`).
  final int clutch;
  final int fans;

  int h(Habilidad x) => Habilidad.valor(x, atributos, espec);
  int a(Atributo x) => atributos[x];
}

/// Familia de una insignia (para ordenarlas en pantalla).
enum FamiliaInsignia {
  tiro('Tiro'),
  interior('Anotación interior'),
  creacion('Creación'),
  defensa('Defensa'),
  fisico('Físico'),
  mentalidad('Mentalidad');

  const FamiliaInsignia(this.etiqueta);
  final String etiqueta;
}

/// Insignias: cada una tiene cuatro grados que se ganan subiendo habilidades y jugando una carrera
/// grande. Mejoran las estadísticas según el grado.
enum Insignia {
  // --- Tiro ---
  francotirador(FamiliaInsignia.tiro, 'Francotirador', 'Triple 80+: más acierto en triples y libres.'),
  tiradorDeEsquina(FamiliaInsignia.tiro, 'Tirador de esquina', 'Triple de esquina 82+: la esquina es tuya.'),
  codoDeOro(FamiliaInsignia.tiro, 'Codo de oro', 'Media distancia 80+: tiros de dos fuera de la pintura.'),
  libreSeguro(FamiliaInsignia.tiro, 'Libre seguro', 'Tiro libre 82+: casi nunca falla desde la línea.'),
  sangreFria(FamiliaInsignia.tiro, 'Sangre fría', 'Tiro e IQ 75+: más puntos en los finales.'),
  clutch(FamiliaInsignia.tiro, 'Clutch', 'Resolvé jugadas decisivas en partidos en vivo y tené IQ 70+.'),
  // --- Anotación interior ---
  finalizador(FamiliaInsignia.interior, 'Finalizador', 'Finalización 80+: más acierto en el aro.'),
  cazadorDeBandejas(FamiliaInsignia.interior, 'Cazador de bandejas', 'Bandejas 82+: no perdona cerca del aro.'),
  flotadoraLetal(FamiliaInsignia.interior, 'Flotadora letal', 'Flotadora 82+: le ganás a los grandes por arriba.'),
  rematador(FamiliaInsignia.interior, 'Rematador', 'Alley-oop 80+ y Salto 70+: lo que te tiran, adentro.'),
  volcador(FamiliaInsignia.interior, 'Volcador', 'Volcadas 80+ y Salto 70+: castigo con potencia.'),
  reyDelPoste(FamiliaInsignia.interior, 'Rey del poste', 'Poste 80+ y Fuerza 65+: dominás de espaldas.'),
  // --- Creación ---
  maestroDelPase(FamiliaInsignia.creacion, 'Maestro del pase', 'Pase 82+: más asistencias y menos pérdidas.'),
  manejoDeSeda(FamiliaInsignia.creacion, 'Manejo de seda', 'Manejo 82+: casi no la perdés.'),
  visionario(FamiliaInsignia.creacion, 'Visionario', 'Visión 82+: ves el pase que nadie ve.'),
  director(FamiliaInsignia.creacion, 'Director', 'Pase y Visión 78+: manejás el ritmo del equipo.'),
  // --- Defensa ---
  muralla(FamiliaInsignia.defensa, 'Muralla', 'Defensa 80+ y Físico 65+: más robos y tapones.'),
  reptil(FamiliaInsignia.defensa, 'Reptil', 'Defensa perimetral 82+: se pega al rival como un chicle.'),
  ancla(FamiliaInsignia.defensa, 'Ancla', 'Defensa interior 82+: cuida el aro.'),
  ladron(FamiliaInsignia.defensa, 'Ladrón', 'Robo 82+: cortá pases y corré.'),
  aniquilador(FamiliaInsignia.defensa, 'Aniquilador', 'Tapón 82+: nada pasa por tu zona.'),
  cerebroDefensivo(FamiliaInsignia.defensa, 'Cerebro defensivo', 'IQ defensivo y Ayuda defensiva 80+: siempre estás donde hace falta.'),
  // --- Físico ---
  atleta(FamiliaInsignia.fisico, 'Atleta', 'Físico 82+: más rebotes.'),
  pulmones(FamiliaInsignia.fisico, 'Pulmones', 'Resistencia 82+: jugás más minutos.'),
  rebotero(FamiliaInsignia.fisico, 'Rebotero', 'Rebote 82+: la pelota rebota donde estás vos.'),
  tanque(FamiliaInsignia.fisico, 'Tanque', 'Fuerza 85+: nadie te mueve.'),
  volador(FamiliaInsignia.fisico, 'Volador', 'Salto y Velocidad 80+: arriba del aro.'),
  incansable(FamiliaInsignia.fisico, 'Incansable', 'Durabilidad y Resistencia 82+: el cuerpo aguanta todo.'),
  // --- Mentalidad / carrera ---
  completo(FamiliaInsignia.mentalidad, 'Completo', 'Todos los atributos en 70+: un poco de todo.'),
  consistente(FamiliaInsignia.mentalidad, 'Consistente', 'Consistencia 82+: rendís igual todas las noches.'),
  peleador(FamiliaInsignia.mentalidad, 'Peleador', 'Garra 82+: vas a todas las pelotas.'),
  lider(FamiliaInsignia.mentalidad, 'Líder', 'IQ 78+ y la afición de tu lado: el vestuario te sigue.'),
  ganador(FamiliaInsignia.mentalidad, 'Ganador', 'Ganá títulos: el anillo es lo que cuenta.'),
  maquina(FamiliaInsignia.mentalidad, 'Máquina', 'Jugá cientos de partidos: la constancia es tu marca.'),
  estrella(FamiliaInsignia.mentalidad, 'Estrella', 'Ser All-Star y ganar premios: el rostro de la liga.');

  const Insignia(this.familia, this.etiqueta, this.descripcion);
  final FamiliaInsignia familia;
  final String etiqueta, descripcion;

  /// Puntaje de la insignia (0 a 99+). Los grados salen de [_umbrales].
  int puntaje(ContextoInsignia c) => switch (this) {
    Insignia.francotirador => c.h(Habilidad.triple),
    Insignia.codoDeOro => c.h(Habilidad.mediaDistancia),
    Insignia.libreSeguro => c.h(Habilidad.tiroLibre),
    Insignia.sangreFria => min(c.a(Atributo.iq), c.a(Atributo.tiro)) + 5,
    Insignia.clutch => c.clutch == 0 ? 0 : min(c.a(Atributo.iq) + 4, 60 + c.clutch * 4),
    Insignia.finalizador => c.a(Atributo.finalizacion),
    Insignia.cazadorDeBandejas => c.h(Habilidad.bandeja),
    Insignia.volcador => min(c.h(Habilidad.volcada), c.h(Habilidad.salto) + 10),
    Insignia.reyDelPoste => min(c.h(Habilidad.poste), c.h(Habilidad.fuerza) + 15),
    Insignia.maestroDelPase => c.h(Habilidad.pase),
    Insignia.manejoDeSeda => c.h(Habilidad.manejo),
    Insignia.visionario => c.h(Habilidad.vision),
    Insignia.director => min(c.h(Habilidad.pase), c.h(Habilidad.vision)) + 4,
    Insignia.muralla => min(c.a(Atributo.defensa), c.a(Atributo.fisico) + 15),
    Insignia.reptil => c.h(Habilidad.defPerimetral),
    Insignia.ancla => c.h(Habilidad.defInterior),
    Insignia.ladron => c.h(Habilidad.robo),
    Insignia.aniquilador => c.h(Habilidad.tapon),
    Insignia.atleta => c.a(Atributo.fisico),
    Insignia.pulmones => c.h(Habilidad.resistencia),
    Insignia.rebotero => c.h(Habilidad.rebote),
    Insignia.tanque => c.h(Habilidad.fuerza) - 3,
    Insignia.volador => min(c.h(Habilidad.salto), c.h(Habilidad.velocidad)),
    Insignia.tiradorDeEsquina => c.h(Habilidad.tiroDeEsquina),
    Insignia.flotadoraLetal => c.h(Habilidad.flotadora),
    Insignia.rematador => min(c.h(Habilidad.alleyOop), c.h(Habilidad.salto) + 10),
    Insignia.cerebroDefensivo => min(c.h(Habilidad.iqDefensivo), c.h(Habilidad.ayudaDefensiva)) + 2,
    Insignia.incansable => min(c.h(Habilidad.durabilidad), c.h(Habilidad.resistencia)),
    Insignia.consistente => c.h(Habilidad.consistencia),
    Insignia.peleador => c.h(Habilidad.garra),
    Insignia.completo => Atributo.values.map(c.a).reduce(min) + 10,
    Insignia.lider => c.a(Atributo.iq) >= 78 && c.fans >= 60 ? c.a(Atributo.iq) : 0,
    // Los de carrera: no dependen de los atributos, solo de lo vivido.
    Insignia.ganador => 79 + c.titulos * 6,
    Insignia.maquina => c.pj < 160 ? 0 : 80 + (c.pj - 160) ~/ 120 * 5,
    Insignia.estrella => c.allStar + c.premios == 0 ? 0 : 80 + c.allStar * 3 + c.premios * 2,
  };

  /// Puntaje de Bronce; cada grado siguiente pide 6, 12 y 17 más.
  int get _bronce => switch (this) {
    Insignia.francotirador || Insignia.codoDeOro || Insignia.finalizador || Insignia.volcador => 80,
    Insignia.libreSeguro || Insignia.cazadorDeBandejas || Insignia.maestroDelPase => 82,
    Insignia.manejoDeSeda || Insignia.visionario || Insignia.reptil || Insignia.ancla => 82,
    Insignia.ladron || Insignia.aniquilador || Insignia.atleta || Insignia.pulmones || Insignia.rebotero => 82,
    Insignia.reyDelPoste => 80,
    Insignia.tanque => 82,
    Insignia.volador || Insignia.muralla => 80,
    Insignia.sangreFria => 80,
    Insignia.director => 82,
    Insignia.clutch => 74,
    Insignia.completo => 80,
    Insignia.lider => 78,
    Insignia.tiradorDeEsquina ||
    Insignia.flotadoraLetal ||
    Insignia.incansable ||
    Insignia.consistente ||
    Insignia.peleador => 82,
    Insignia.rematador || Insignia.cerebroDefensivo => 80,
    Insignia.ganador || Insignia.maquina || Insignia.estrella => 80,
  };

  static const _saltos = [0, 6, 12, 17];

  /// Grado que tenés con [c].
  GradoInsignia grado(ContextoInsignia c) {
    final p = puntaje(c);
    var n = 0;
    for (var i = 0; i < _saltos.length; i++) {
      if (p >= _bronce + _saltos[i]) n = i + 1;
    }
    return GradoInsignia.deNivel(n);
  }

  /// Lo que pide el grado siguiente (null si ya está en Leyenda), en el mismo puntaje que [puntaje].
  int? umbralDe(GradoInsignia g) => g.nivel >= 4 ? null : _bronce + _saltos[g.nivel];

  /// Compatibilidad: la tenés (Bronce o más) con solo los atributos generales.
  bool la(Atributos a) => grado(ContextoInsignia(atributos: a)).nivel >= 1;

  /// Las que tenés (Bronce o más) con solo los atributos generales.
  static List<Insignia> de(Atributos a) => [
    for (final i in values)
      if (i.la(a)) i,
  ];

  /// Grados de todas las insignias con [c].
  static Map<Insignia, GradoInsignia> grados(ContextoInsignia c) => {for (final i in values) i: i.grado(c)};

  /// Lo que suma cada grado a las estadísticas (se aplica por el grado ganado desde que arrancaste).
  EfectoStats get efecto => switch (this) {
    Insignia.francotirador => const EfectoStats(pctT3: 0.015, pctTl: 0.015),
    Insignia.codoDeOro => const EfectoStats(ppp: 0.25, pctTc: 0.004),
    Insignia.libreSeguro => const EfectoStats(pctTl: 0.02, ppp: 0.1),
    Insignia.sangreFria => const EfectoStats(ppp: 0.8),
    Insignia.clutch => const EfectoStats(ppp: 0.3, pctTc: 0.004),
    Insignia.finalizador => const EfectoStats(pctTc: 0.015),
    Insignia.cazadorDeBandejas => const EfectoStats(pctTc: 0.01, ppp: 0.15),
    Insignia.volcador => const EfectoStats(ppp: 0.3, rpp: 0.2),
    Insignia.reyDelPoste => const EfectoStats(ppp: 0.3, rpp: 0.3),
    Insignia.maestroDelPase => const EfectoStats(app: 0.8, perP: -0.2),
    Insignia.manejoDeSeda => const EfectoStats(perP: -0.3, app: 0.2),
    Insignia.visionario => const EfectoStats(app: 0.6),
    Insignia.director => const EfectoStats(app: 0.4, ppp: 0.1),
    Insignia.muralla => const EfectoStats(robP: 0.15, tapP: 0.2),
    Insignia.reptil => const EfectoStats(robP: 0.2),
    Insignia.ancla => const EfectoStats(tapP: 0.25, rpp: 0.2),
    Insignia.ladron => const EfectoStats(robP: 0.25),
    Insignia.aniquilador => const EfectoStats(tapP: 0.3),
    Insignia.atleta => const EfectoStats(rpp: 0.8),
    Insignia.pulmones => const EfectoStats(minP: 1.2),
    Insignia.rebotero => const EfectoStats(rpp: 0.7),
    Insignia.tanque => const EfectoStats(rpp: 0.4, pctTc: 0.005),
    Insignia.volador => const EfectoStats(ppp: 0.2, tapP: 0.1, rpp: 0.3),
    Insignia.tiradorDeEsquina => const EfectoStats(pctT3: 0.01),
    Insignia.flotadoraLetal => const EfectoStats(pctTc: 0.008, ppp: 0.1),
    Insignia.rematador => const EfectoStats(ppp: 0.2, rpp: 0.1),
    Insignia.cerebroDefensivo => const EfectoStats(robP: 0.1, tapP: 0.1),
    Insignia.incansable => const EfectoStats(minP: 0.8),
    Insignia.consistente => const EfectoStats(pctTc: 0.006, perP: -0.1),
    Insignia.peleador => const EfectoStats(robP: 0.1, rpp: 0.3),
    Insignia.completo => const EfectoStats(ppp: 0.4, rpp: 0.3, app: 0.3),
    Insignia.lider => const EfectoStats(app: 0.4, perP: -0.1),
    Insignia.ganador => const EfectoStats(ppp: 0.1, app: 0.1),
    Insignia.maquina => const EfectoStats(minP: 0.6),
    Insignia.estrella => const EfectoStats(ppp: 0.15, app: 0.1),
  };
}
