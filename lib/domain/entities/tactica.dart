/// Playbook ofensivo (GDD §5.1).
enum SistemaOfensivo {
  paceAndSpace('Pace & Space', 'Ritmo alto, contraataque y bombardeo masivo de triples.'),
  trianguloOfensivo('Triángulo Ofensivo', 'Espaciado simétrico, cortes por la espalda y media distancia.'),
  sevenSeconds('Seven Seconds or Less', 'Posesiones de menos de 7 segundos; máxima aceleración.'),
  postInsideOut(
    'Post-Centric & Inside-Out',
    'Alimentar el poste bajo para forzar faltas y doblar a tiradores en esquinas.',
  ),
  motionOffense('Motion Offense', 'Pases rápidos continuos, pantallas indirectas y lectura sin balón.'),
  aislamiento('Aislamiento (Hero Ball)', 'Espaciado total para aclarados 1 contra 1 en los minutos finales.'),
  pickAndRollEspanol(
    'Pick & Roll Español',
    'Bloqueo central directo con un segundo bloqueo ciego a la espalda del pívot defensor.',
  ),
  cincoAbierto('5-Out (Quinteto Abierto)', 'Los 5 jugadores detrás de la línea de tres; pintura completamente vacía.'),
  dribbleDrive('Dribble Drive Motion', 'Penetración agresiva al corazón de la zona para colapsar y abrir el pase.'),
  princeton('Ataque Princeton', 'Paciencia extrema, cortes de puerta atrás y castigo a defensas que presionan arriba.');

  const SistemaOfensivo(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Playbook defensivo (GDD §5.2).
enum EsquemaDefensivo {
  dropCoverage('Drop Coverage', 'El pívot protege la pintura contra penetraciones; cede el triple tras bloqueo.'),
  switchAll('Switch All', 'Cambio de marca automático en todos los bloqueos perimetrales.'),
  cajaYUno(
    'Box & One (Caja y Uno)',
    'Cuatro defensores en zona de caja y un especialista secando a la estrella rival.',
  ),
  trapBlitz('Trap & Blitz Pick & Roll', 'Doble marca inmediata al base rival en cuanto cruza el bloqueo.'),
  presionTodaCancha('Presión en Toda la Cancha', 'Acoso desde el saque; maximiza robos pero desgasta estamina.'),
  zona23('Zona 2-3 Clásica', 'Muralla en la pintura para sellar rebotes defensivos; cede tiros lejanos.'),
  packLine('Pack-Line Defense', 'Cuatro defensores pisan la línea de pintura impidiendo bandejas.'),
  iceBlue('Defensa Ice / Blue PnR', 'Fuerza al base rival hacia la banda lateral negándole el centro de la pista.'),
  zona131('Zona 1-3-1 en Rombo', 'Zona agresiva en puntas y alas para cortar líneas de pase y forzar pérdidas.'),
  gritAndGrind('Grit & Grind', 'Defensa física de contacto a media cancha que reduce drásticamente el ritmo.');

  const EsquemaDefensivo(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
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
}
