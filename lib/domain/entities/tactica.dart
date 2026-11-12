/// Rasgos del plantel que cada sistema necesita (0 a 1, ver `domain/playbook.dart`).
enum Rasgo {
  triple('Triple', '%T3'),
  creacion('Creación', 'APP'),
  poste('Juego interior', 'PPP'),
  transicion('Transición', 'ROB/P'),
  aislamiento('Anotador estrella', 'PPP'),
  iq('Lectura de juego', 'IQ'),
  defensaExterior('Defensa exterior', 'ROB/P'),
  proteccionAro('Protección del aro', 'TAP/P'),
  rebote('Rebote', 'RPP'),
  versatilidad('Versatilidad', 'posiciones'),
  fisico('Físico y aire', 'MIN/P');

  const Rasgo(this.etiqueta, this.sigla);
  final String etiqueta;

  /// Estadística que se muestra como evidencia del rasgo.
  final String sigla;
}

/// Playbook ofensivo (GDD §5.1). [rasgos]: peso de cada rasgo en la afinidad.
/// [ritmo]: -1 lento a +1 rápido (la Fase 5 lo usa para la cantidad de posesiones).
enum SistemaOfensivo {
  paceAndSpace('Pace & Space', 'Ritmo alto, contraataque y bombardeo masivo de triples.', 1, {
    Rasgo.triple: 3,
    Rasgo.transicion: 2,
    Rasgo.creacion: 1,
  }),
  trianguloOfensivo('Triángulo Ofensivo', 'Espaciado simétrico, cortes por la espalda y media distancia.', -0.5, {
    Rasgo.iq: 3,
    Rasgo.poste: 1,
    Rasgo.creacion: 1,
    Rasgo.versatilidad: 1,
  }),
  sevenSeconds('Seven Seconds or Less', 'Posesiones de menos de 7 segundos; máxima aceleración.', 1, {
    Rasgo.transicion: 3,
    Rasgo.triple: 2,
    Rasgo.creacion: 2,
    Rasgo.fisico: 1,
  }),
  postInsideOut(
    'Post-Centric & Inside-Out',
    'Alimentar el poste bajo para forzar faltas y doblar a tiradores en esquinas.',
    -0.5,
    {Rasgo.poste: 3, Rasgo.triple: 2, Rasgo.rebote: 1},
  ),
  motionOffense('Motion Offense', 'Pases rápidos continuos, pantallas indirectas y lectura sin balón.', 0, {
    Rasgo.iq: 3,
    Rasgo.creacion: 2,
    Rasgo.triple: 1,
  }),
  aislamiento('Aislamiento (Hero Ball)', 'Espaciado total para aclarados 1 contra 1 en los minutos finales.', -0.5, {
    Rasgo.aislamiento: 4,
    Rasgo.iq: 1,
  }),
  pickAndRollEspanol(
    'Pick & Roll Español',
    'Bloqueo central directo con un segundo bloqueo ciego a la espalda del pívot defensor.',
    0,
    {Rasgo.creacion: 3, Rasgo.poste: 1, Rasgo.triple: 1},
  ),
  cincoAbierto(
    '5-Out (Quinteto Abierto)',
    'Los 5 jugadores detrás de la línea de tres; pintura completamente vacía.',
    0.5,
    {Rasgo.triple: 3, Rasgo.versatilidad: 2, Rasgo.creacion: 1},
  ),
  dribbleDrive(
    'Dribble Drive Motion',
    'Penetración agresiva al corazón de la zona para colapsar y abrir el pase.',
    0.5,
    {Rasgo.transicion: 2, Rasgo.aislamiento: 2, Rasgo.triple: 1},
  ),
  princeton(
    'Ataque Princeton',
    'Paciencia extrema, cortes de puerta atrás y castigo a defensas que presionan arriba.',
    -1,
    {Rasgo.iq: 3, Rasgo.versatilidad: 2, Rasgo.creacion: 1},
  );

  const SistemaOfensivo(this.nombre, this.descripcion, this.ritmo, this.rasgos);
  final String nombre;
  final String descripcion;
  final double ritmo;
  final Map<Rasgo, int> rasgos;
}

/// Playbook defensivo (GDD §5.2). Mismos campos que [SistemaOfensivo].
enum EsquemaDefensivo {
  dropCoverage('Drop Coverage', 'El pívot protege la pintura contra penetraciones; cede el triple tras bloqueo.', 0, {
    Rasgo.proteccionAro: 3,
    Rasgo.rebote: 1,
  }),
  switchAll('Switch All', 'Cambio de marca automático en todos los bloqueos perimetrales.', 0, {
    Rasgo.versatilidad: 3,
    Rasgo.defensaExterior: 2,
  }),
  cajaYUno(
    'Box & One (Caja y Uno)',
    'Cuatro defensores en zona de caja y un especialista secando a la estrella rival.',
    -0.5,
    {Rasgo.defensaExterior: 2, Rasgo.rebote: 1, Rasgo.iq: 1},
  ),
  trapBlitz('Trap & Blitz Pick & Roll', 'Doble marca inmediata al base rival en cuanto cruza el bloqueo.', 0.5, {
    Rasgo.defensaExterior: 2,
    Rasgo.fisico: 2,
    Rasgo.iq: 1,
  }),
  presionTodaCancha('Presión en Toda la Cancha', 'Acoso desde el saque; maximiza robos pero desgasta estamina.', 1, {
    Rasgo.fisico: 3,
    Rasgo.defensaExterior: 2,
    Rasgo.transicion: 1,
  }),
  zona23('Zona 2-3 Clásica', 'Muralla en la pintura para sellar rebotes defensivos; cede tiros lejanos.', -0.5, {
    Rasgo.proteccionAro: 2,
    Rasgo.rebote: 2,
  }),
  packLine('Pack-Line Defense', 'Cuatro defensores pisan la línea de pintura impidiendo bandejas.', -0.5, {
    Rasgo.iq: 2,
    Rasgo.proteccionAro: 1,
    Rasgo.rebote: 1,
  }),
  iceBlue('Defensa Ice / Blue PnR', 'Fuerza al base rival hacia la banda lateral negándole el centro de la pista.', 0, {
    Rasgo.iq: 2,
    Rasgo.defensaExterior: 2,
    Rasgo.proteccionAro: 1,
  }),
  zona131('Zona 1-3-1 en Rombo', 'Zona agresiva en puntas y alas para cortar líneas de pase y forzar pérdidas.', 0.5, {
    Rasgo.defensaExterior: 2,
    Rasgo.transicion: 2,
    Rasgo.fisico: 1,
  }),
  gritAndGrind('Grit & Grind', 'Defensa física de contacto a media cancha que reduce drásticamente el ritmo.', -1, {
    Rasgo.rebote: 2,
    Rasgo.fisico: 2,
    Rasgo.proteccionAro: 1,
  });

  const EsquemaDefensivo(this.nombre, this.descripcion, this.ritmo, this.rasgos);
  final String nombre;
  final String descripcion;
  final double ritmo;
  final Map<Rasgo, int> rasgos;
}

/// Combinación elegida por el usuario para la temporada.
class Tactica {
  const Tactica({this.ofensiva = SistemaOfensivo.motionOffense, this.defensiva = EsquemaDefensivo.switchAll});

  final SistemaOfensivo ofensiva;
  final EsquemaDefensivo defensiva;

  Tactica copyWith({SistemaOfensivo? ofensiva, EsquemaDefensivo? defensiva}) =>
      Tactica(ofensiva: ofensiva ?? this.ofensiva, defensiva: defensiva ?? this.defensiva);

  factory Tactica.fromJson(Map<String, dynamic> j) => Tactica(
    ofensiva: SistemaOfensivo.values.byName(j['ofensiva'] as String),
    defensiva: EsquemaDefensivo.values.byName(j['defensiva'] as String),
  );

  Map<String, dynamic> toJson() => {'ofensiva': ofensiva.name, 'defensiva': defensiva.name};

  @override
  bool operator ==(Object other) => other is Tactica && other.ofensiva == ofensiva && other.defensiva == defensiva;

  @override
  int get hashCode => Object.hash(ofensiva, defensiva);
}
