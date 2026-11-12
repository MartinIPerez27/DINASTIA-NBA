import 'jugador.dart';
import 'tactica.dart';

/// Carta de entrenador (7.º puesto). Su sistema y su esquema preferidos rinden más si tu playbook
/// los usa, y su nivel ordena al equipo (menos pérdidas). Si dirigió la franquicia de tus
/// jugadores, suma química.
class Entrenador {
  const Entrenador({
    required this.id,
    required this.nombre,
    required this.franquicias,
    required this.epoca,
    required this.ofensiva,
    required this.defensiva,
    required this.nivel,
    required this.frase,
  });

  final String id;
  final String nombre;

  /// Franquicias que dirigió con éxito (para la química).
  final Set<String> franquicias;
  final Epoca epoca;
  final SistemaOfensivo ofensiva;
  final EsquemaDefensivo defensiva;

  /// 75–99, como la media de una carta.
  final int nivel;
  final String frase;

  String get iniciales => nombre.split(' ').map((p) => p[0]).take(2).join();

  static Entrenador? porId(String? id) => id == null ? null : _porId[id];
  static final _porId = {for (final e in todos) e.id: e};

  static const todos = [
    Entrenador(
      id: 'jackson',
      nombre: 'Phil Jackson',
      franquicias: {'CHI', 'LAL'},
      epoca: Epoca.anios90,
      ofensiva: SistemaOfensivo.trianguloOfensivo,
      defensiva: EsquemaDefensivo.switchAll,
      nivel: 99,
      frase: '11 anillos: el Maestro Zen del Triángulo.',
    ),
    Entrenador(
      id: 'auerbach',
      nombre: 'Red Auerbach',
      franquicias: {'BOS'},
      epoca: Epoca.anios60,
      ofensiva: SistemaOfensivo.sevenSeconds,
      defensiva: EsquemaDefensivo.presionTodaCancha,
      nivel: 98,
      frase: 'Contraataque y el habano de la victoria.',
    ),
    Entrenador(
      id: 'popovich',
      nombre: 'Gregg Popovich',
      franquicias: {'SAS'},
      epoca: Epoca.anios2010,
      ofensiva: SistemaOfensivo.motionOffense,
      defensiva: EsquemaDefensivo.packLine,
      nivel: 98,
      frase: 'La pelota se mueve, el ego no.',
    ),
    Entrenador(
      id: 'riley',
      nombre: 'Pat Riley',
      franquicias: {'LAL', 'MIA', 'NYK'},
      epoca: Epoca.anios80,
      ofensiva: SistemaOfensivo.paceAndSpace,
      defensiva: EsquemaDefensivo.gritAndGrind,
      nivel: 96,
      frase: 'Showtime en L.A., dureza en Nueva York.',
    ),
    Entrenador(
      id: 'kerr',
      nombre: 'Steve Kerr',
      franquicias: {'GSW'},
      epoca: Epoca.anios2010,
      ofensiva: SistemaOfensivo.motionOffense,
      defensiva: EsquemaDefensivo.switchAll,
      nivel: 95,
      frase: 'Strength in Numbers.',
    ),
    Entrenador(
      id: 'daly',
      nombre: 'Chuck Daly',
      franquicias: {'DET'},
      epoca: Epoca.anios80,
      ofensiva: SistemaOfensivo.postInsideOut,
      defensiva: EsquemaDefensivo.gritAndGrind,
      nivel: 93,
      frase: 'Los Bad Boys y las Jordan Rules.',
    ),
    Entrenador(
      id: 'sloan',
      nombre: 'Jerry Sloan',
      franquicias: {'UTA'},
      epoca: Epoca.anios90,
      ofensiva: SistemaOfensivo.pickAndRollEspanol,
      defensiva: EsquemaDefensivo.iceBlue,
      nivel: 92,
      frase: 'El pick and roll perfecto de Stockton y Malone.',
    ),
    Entrenador(
      id: 'dantoni',
      nombre: "Mike D'Antoni",
      franquicias: {'PHX', 'HOU'},
      epoca: Epoca.anios2000,
      ofensiva: SistemaOfensivo.sevenSeconds,
      defensiva: EsquemaDefensivo.switchAll,
      nivel: 88,
      frase: 'Siete segundos o menos.',
    ),
    Entrenador(
      id: 'spoelstra',
      nombre: 'Erik Spoelstra',
      franquicias: {'MIA'},
      epoca: Epoca.anios2010,
      ofensiva: SistemaOfensivo.cincoAbierto,
      defensiva: EsquemaDefensivo.zona23,
      nivel: 93,
      frase: 'Cultura Heat: nadie trabaja más.',
    ),
    Entrenador(
      id: 'holzman',
      nombre: 'Red Holzman',
      franquicias: {'NYK'},
      epoca: Epoca.anios70,
      ofensiva: SistemaOfensivo.princeton,
      defensiva: EsquemaDefensivo.trapBlitz,
      nivel: 90,
      frase: 'Los Knicks del 70 y del 73: pase y defensa.',
    ),
    Entrenador(
      id: 'brown',
      nombre: 'Larry Brown',
      franquicias: {'DET', 'PHI'},
      epoca: Epoca.anios2000,
      ofensiva: SistemaOfensivo.dribbleDrive,
      defensiva: EsquemaDefensivo.gritAndGrind,
      nivel: 89,
      frase: 'Jugá bien, jugá bien.',
    ),
    Entrenador(
      id: 'tomjanovich',
      nombre: 'Rudy Tomjanovich',
      franquicias: {'HOU'},
      epoca: Epoca.anios90,
      ofensiva: SistemaOfensivo.postInsideOut,
      defensiva: EsquemaDefensivo.dropCoverage,
      nivel: 88,
      frase: 'Nunca subestimes el corazón de un campeón.',
    ),
    Entrenador(
      id: 'carlisle',
      nombre: 'Rick Carlisle',
      franquicias: {'DAL', 'IND'},
      epoca: Epoca.anios2010,
      ofensiva: SistemaOfensivo.motionOffense,
      defensiva: EsquemaDefensivo.cajaYUno,
      nivel: 87,
      frase: 'Le ganó al Big Three con una caja y uno.',
    ),
    Entrenador(
      id: 'thibodeau',
      nombre: 'Tom Thibodeau',
      franquicias: {'CHI', 'NYK', 'BOS'},
      epoca: Epoca.anios2010,
      ofensiva: SistemaOfensivo.aislamiento,
      defensiva: EsquemaDefensivo.iceBlue,
      nivel: 85,
      frase: 'Defensa los 48 minutos.',
    ),
    Entrenador(
      id: 'wilkens',
      nombre: 'Lenny Wilkens',
      franquicias: {'SEA', 'OKC', 'ATL', 'CLE'},
      epoca: Epoca.anios70,
      ofensiva: SistemaOfensivo.motionOffense,
      defensiva: EsquemaDefensivo.zona131,
      nivel: 86,
      frase: 'El campeón del 79 con los Sonics.',
    ),
    Entrenador(
      id: 'karl',
      nombre: 'George Karl',
      franquicias: {'SEA', 'OKC', 'MIL', 'DEN'},
      epoca: Epoca.anios90,
      ofensiva: SistemaOfensivo.paceAndSpace,
      defensiva: EsquemaDefensivo.trapBlitz,
      nivel: 85,
      frase: 'Payton y Kemp volando en Seattle.',
    ),
    Entrenador(
      id: 'rivers',
      nombre: 'Doc Rivers',
      franquicias: {'BOS', 'LAC'},
      epoca: Epoca.anios2010,
      ofensiva: SistemaOfensivo.pickAndRollEspanol,
      defensiva: EsquemaDefensivo.switchAll,
      nivel: 84,
      frase: 'Ubuntu: el Big Three de Boston.',
    ),
    Entrenador(
      id: 'mazzulla',
      nombre: 'Joe Mazzulla',
      franquicias: {'BOS'},
      epoca: Epoca.actualidad,
      ofensiva: SistemaOfensivo.cincoAbierto,
      defensiva: EsquemaDefensivo.switchAll,
      nivel: 86,
      frase: 'Triples, matemática y anillo.',
    ),
  ];
}
