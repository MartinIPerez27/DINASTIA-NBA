/// Grupos del menú de modos.
enum GrupoModo {
  principal('La temporada'),
  rapido('Partidas rápidas'),
  desafio('Desafíos'),
  historia('Historia de la NBA'),
  torneo('Torneos históricos'),
  carrera('Gestión y carrera'),
  amigos('Con amigos, en el mismo dispositivo'),
  competitivo('Competitivo y torneos'),
  minijuegos('Minijuegos');

  const GrupoModo(this.etiqueta);
  final String etiqueta;
}

/// A qué se juega en una partida guardada. El clásico es draft + 82 partidos + playoffs; el resto
/// guarda lo suyo en [Temporada.datosModo].
enum ModoJuego {
  clasico(GrupoModo.principal, 'Temporada 82-0', 'Armá tu plantel y buscá la temporada perfecta.'),
  dinastia(GrupoModo.carrera, 'Dinastía', 'Temporadas encadenadas: tus cartas envejecen, se retiran y hay mini-draft.'),
  reescribi(
    GrupoModo.carrera,
    'Reescribí la historia',
    'Una franquicia real en una década concreta, varias temporadas, con los novatos de cada época.',
  ),
  soloEntrenador(GrupoModo.carrera, 'Solo entrenador', 'Te toca un plantel al azar: vos manejás tácticas y rotación.'),
  desafioDelDia(GrupoModo.desafio, 'Desafío del día', 'El mismo draft para todos según la fecha.'),
  escenario(
    GrupoModo.desafio,
    'Escenarios históricos',
    'Momentos reales para reescribir: "Ganá las Finales del 98 con los Jazz".',
  ),
  caminoAlAnillo(
    GrupoModo.desafio,
    'Camino al anillo',
    '10 rivales históricos cada vez más duros. Si perdés, se termina.',
  ),
  extremo(GrupoModo.desafio, 'Extremo', 'Sin fichas para volver a tirar, lesiones largas y una sola partida.'),
  leyendaUnica(GrupoModo.desafio, 'Leyenda única', 'Elegís una figura; el resto del plantel sale al azar.'),
  espejo(GrupoModo.desafio, 'Modo espejo', 'Jugás la temporada con el plantel que la IA armó en tu contra.'),
  racha(GrupoModo.rapido, 'Racha infinita', 'Rivales al azar hasta que pierdas. El récord va al Salón.'),
  mejoresEquipos(
    GrupoModo.torneo,
    'Los mejores equipos de la historia',
    'Tu equipo contra los Bulls 96, Celtics 86, Lakers 87, Warriors 2017…',
  ),
  mundial(
    GrupoModo.torneo,
    'Mundial de franquicias',
    'Cuadro de 32: tu equipo contra todas las franquicias y dos clásicos (Sonics, Nets).',
  ),
  draftEnGrupo(
    GrupoModo.amigos,
    'Draft en grupo',
    'De 2 a 8 personas eligen por turnos y juegan una liga entre ellas.',
  ),
  duelo(GrupoModo.amigos, 'Duelo', 'Dos personas, dos drafts, una serie al mejor de 7.'),
  reto(
    GrupoModo.amigos,
    'Reto de un amigo',
    'Ingresá su código y jugá su mismo draft, con los mismos rivales. ¿Quién hace mejor récord?',
  ),
  // Historia de la NBA
  temporadaReal(
    GrupoModo.historia,
    'Temporada real',
    'Un año real con los 30 planteles de entonces: superá lo que pasó.',
  ),
  queHubiera(GrupoModo.historia, '¿Qué hubiera pasado si…?', 'Momentos famosos con la historia cambiada.'),
  ultimoCuarto(
    GrupoModo.historia,
    'Momentos clutch',
    'Entrás al final de partidos reales con el marcador de entonces.',
  ),
  // Torneos
  guantelete(GrupoModo.torneo, 'Guantelete de las décadas', 'De los 40 a los 2020: vencé al campeón de cada década.'),
  camadas(GrupoModo.torneo, 'Batalla de camadas', 'Cada equipo es una clase de draft: 84, 96, 2003…'),
  universidades(
    GrupoModo.torneo,
    'Torneo de universidades',
    'Duke, North Carolina, Kentucky, UCLA… con sus ex alumnos.',
  ),
  // Armado
  topeSalarial(GrupoModo.desafio, 'Tope salarial', 'Armá el quinteto con \$15: estrellas caras, obreros baratos.'),
  desafiosArmado(GrupoModo.desafio, 'Desafíos de armado', 'Acertijos de quinteto con las cartas de tu álbum.'),
  ligaIA(GrupoModo.rapido, 'Liga de 8 contra la IA', 'Draft en serpiente contra 7 mánagers con estilo propio.'),
  // Carrera
  figuraFranquicia(GrupoModo.carrera, 'Figura franquicia', 'Elegís un novato y armás todo alrededor de él.'),
  // Carrera inmersiva (tipo MyCareer)
  carreraJugador(GrupoModo.carrera, 'Mi carrera', 'Un jugador real o creado por vos: del draft al Salón de la Fama.'),
  universitario(
    GrupoModo.carrera,
    'Modo universitario',
    'Jugadores ficticios: simulá temporadas enteras y llegá al draft.',
  ),
  // Competitivo y torneos
  divisiones(GrupoModo.competitivo, 'Divisiones', 'Diez divisiones: ascendé o descendé según tus puntos.'),
  creadorTorneos(GrupoModo.competitivo, 'Creador de torneos', 'Elegí equipos y formato: liga, eliminación o grupos.'),
  conquista(
    GrupoModo.competitivo,
    'Conquista',
    'Un mapa con las 30 franquicias: cada victoria conquista un territorio.',
  ),
  fantasy(
    GrupoModo.competitivo,
    'Fantasy NBA',
    'Elegí quinteto y sexto hombre; puntos por el rendimiento real. Contra la IA.',
  ),
  perfilPerfecto(
    GrupoModo.minijuegos,
    'Perfil perfecto',
    'Acertijos de lógica: deducí quién es cada jugador con las pistas.',
  ),
  adivina(GrupoModo.minijuegos, 'Adiviná la carta', 'Quién es por sus números, o cuál de dos tiene más media.');

  const ModoJuego(this.grupo, this.nombre, this.descripcion);
  final GrupoModo grupo;
  final String nombre;
  final String descripcion;

  /// Modos que usan las cartas de tu álbum: ahí valen las evoluciones de cartas (en el resto, no).
  bool get usaAlbum => const {desafiosArmado, divisiones, creadorTorneos, conquista, fantasy}.contains(this);

  /// Si la partida usa la temporada de 82 (calendario y rivales de liga). Los de escalera y el
  /// duelo arman sus propios cruces.
  bool get usaTemporada => !const {
    racha,
    caminoAlAnillo,
    mejoresEquipos,
    mundial,
    escenario,
    duelo,
    ultimoCuarto,
    queHubiera,
    guantelete,
    camadas,
    universidades,
    topeSalarial,
    desafiosArmado,
    ligaIA,
    adivina,
    divisiones,
    creadorTorneos,
    conquista,
    fantasy,
    perfilPerfecto,
    universitario,
  }.contains(this);
}
