/// Grupos del menú de modos.
enum GrupoModo {
  principal('La temporada'),
  rapido('Partidas rápidas'),
  desafio('Desafíos'),
  torneo('Torneos históricos'),
  carrera('Gestión y carrera'),
  amigos('Con amigos, en el mismo dispositivo');

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
  duelo(GrupoModo.amigos, 'Duelo', 'Dos personas, dos drafts, una serie al mejor de 7.');

  const ModoJuego(this.grupo, this.nombre, this.descripcion);
  final GrupoModo grupo;
  final String nombre;
  final String descripcion;

  /// Si la partida usa la temporada de 82 (calendario y rivales de liga). Los de escalera y el
  /// duelo arman sus propios cruces.
  bool get usaTemporada => !const {racha, caminoAlAnillo, mejoresEquipos, mundial, escenario, duelo}.contains(this);
}
