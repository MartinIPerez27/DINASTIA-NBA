import '../../data/historia_nba.dart';
import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/perfil.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/rival.dart';
import '../entities/temporada.dart';
import '../liga.dart';
import '../modificadores.dart';
import '../motor.dart';
import '../playbook.dart';
import '../progreso.dart' show Novedad;

/// Campeones reales por temporada (año de cierre) → franquicia actual. 2026 en adelante: sin dato.
const campeonesReales = <int, String>{
  1977: 'POR',
  1978: 'WAS',
  1979: 'OKC',
  1980: 'LAL',
  1981: 'BOS',
  1982: 'LAL',
  1983: 'PHI',
  1984: 'BOS',
  1985: 'LAL',
  1986: 'BOS',
  1987: 'LAL',
  1988: 'LAL',
  1989: 'DET',
  1990: 'DET',
  1991: 'CHI',
  1992: 'CHI',
  1993: 'CHI',
  1994: 'HOU',
  1995: 'HOU',
  1996: 'CHI',
  1997: 'CHI',
  1998: 'CHI',
  1999: 'SAS',
  2000: 'LAL',
  2001: 'LAL',
  2002: 'LAL',
  2003: 'SAS',
  2004: 'DET',
  2005: 'SAS',
  2006: 'MIA',
  2007: 'SAS',
  2008: 'BOS',
  2009: 'LAL',
  2010: 'LAL',
  2011: 'DAL',
  2012: 'MIA',
  2013: 'MIA',
  2014: 'SAS',
  2015: 'GSW',
  2016: 'CLE',
  2017: 'GSW',
  2018: 'GSW',
  2019: 'TOR',
  2020: 'LAL',
  2021: 'MIL',
  2022: 'GSW',
  2023: 'DEN',
  2024: 'BOS',
  2025: 'OKC',
};

/// "1995-96" para el año de cierre 1996.
String nombreTemporada(int anio) => '${anio - 1}-${(anio % 100).toString().padLeft(2, '0')}';

/// Década del catálogo a la que pertenece una temporada (por año de cierre).
Epoca epocaDeAnio(int anio) => anio >= 2020
    ? Epoca.actualidad
    : switch (anio ~/ 10 * 10) {
        1940 => Epoca.anios40,
        1950 => Epoca.anios50,
        1960 => Epoca.anios60,
        1970 => Epoca.anios70,
        1980 => Epoca.anios80,
        1990 => Epoca.anios90,
        2000 => Epoca.anios2000,
        _ => Epoca.anios2010,
      };

/// Plantel real de una franquicia en una temporada: 5 titulares + Sexto Hombre + 2 suplentes.
class PlantelReal {
  const PlantelReal(this.plantel, this.suplentes, this.identidadId, {required this.aproximado});

  final Plantel plantel;
  final List<Jugador> suplentes;
  final String identidadId;

  /// La franquicia no jugó esa temporada (o no hay cartas): se usó su plantel más cercano en el tiempo.
  final bool aproximado;

  Iterable<Jugador> get todos => [...plantel.jugadores, ...suplentes];
}

/// Una historia alternativa: una temporada real con el plantel de tu equipo cambiado.
class QueHubiera {
  const QueHubiera({
    required this.id,
    required this.titulo,
    required this.anio,
    required this.franquiciaId,
    required this.agregar,
    required this.relato,
  });

  final String id;
  final String titulo;
  final int anio;
  final String franquiciaId;

  /// Cartas que se suman sí o sí: (id de Basketball-Reference, franquicia de la carta, época de la carta).
  final List<(String, String, Epoca)> agregar;
  final String relato;
}

const historiasAlternativas = <QueHubiera>[
  QueHubiera(
    id: 'jordan94',
    titulo: 'Jordan no se retira en 1993',
    anio: 1994,
    franquiciaId: 'CHI',
    agregar: [('jordami01', 'CHI', Epoca.anios90)],
    relato:
        'Octubre de 1993: Michael no anuncia nada y se presenta a la pretemporada. Los Bulls van por el '
        'cuarto anillo seguido. Esa temporada, sin él, ganaron 55 y cayeron con los Knicks.',
  ),
  QueHubiera(
    id: 'jordanPortland',
    titulo: 'Portland elige a Jordan en el draft del 84',
    anio: 1985,
    franquiciaId: 'POR',
    agregar: [('jordami01', 'CHI', Epoca.anios80)],
    relato:
        'Con la 2.ª elección, Portland elige a Michael Jordan en lugar de Sam Bowie. Jordan y Drexler en el '
        'mismo perímetro, desde la primera temporada.',
  ),
  QueHubiera(
    id: 'shaqKobe05',
    titulo: 'Shaq y Kobe siguen juntos en 2004-05',
    anio: 2005,
    franquiciaId: 'LAL',
    agregar: [('onealsh01', 'LAL', Epoca.anios2000)],
    relato:
        'Verano de 2004: nadie cambia a Shaquille. Kobe y Shaq, con tres anillos encima, van por el cuarto. '
        'Ese año real, sin Shaq, los Lakers no llegaron a los playoffs.',
  ),
  QueHubiera(
    id: 'pennyShaq97',
    titulo: 'Shaq se queda en Orlando',
    anio: 1997,
    franquiciaId: 'ORL',
    agregar: [('onealsh01', 'ORL', Epoca.anios90)],
    relato:
        'Shaq no firma con los Lakers en 1996. Penny Hardaway y Shaquille siguen juntos en el Magic que ya '
        'había llegado a Las Finales del 95.',
  ),
  QueHubiera(
    id: 'roySano',
    titulo: 'Brandon Roy con las rodillas sanas',
    anio: 2011,
    franquiciaId: 'POR',
    agregar: [('roybr01', 'POR', Epoca.anios2000)],
    relato:
        'Las rodillas de Brandon Roy aguantan. El Roy de tres All-Star seguidos acompaña a LaMarcus Aldridge '
        'en su mejor momento.',
  ),
  QueHubiera(
    id: 'sabonisJoven',
    titulo: 'Sabonis llega joven a Portland',
    anio: 1990,
    franquiciaId: 'POR',
    agregar: [('sabonar01', 'POR', Epoca.anios90)],
    relato:
        'Arvydas Sabonis cruza el Atlántico en 1989 y no en 1995, antes de las lesiones. Junto a Drexler, en '
        'el Portland que llegó a Las Finales del 90.',
  ),
  QueHubiera(
    id: 'durantOkc17',
    titulo: 'Durant se queda en Oklahoma City',
    anio: 2017,
    franquiciaId: 'OKC',
    agregar: [('duranke01', 'OKC', Epoca.anios2010)],
    relato:
        'Julio de 2016: Kevin Durant renueva con el Thunder. Westbrook y Durant, otra vez juntos, contra los '
        'Warriors del 73-9.',
  ),
  QueHubiera(
    id: 'lebronCle11',
    titulo: 'LeBron se queda en Cleveland',
    anio: 2011,
    franquiciaId: 'CLE',
    agregar: [('jamesle01', 'CLE', Epoca.anios2000)],
    relato:
        'No hay "Decision": LeBron renueva con los Cavaliers en 2010. Ese año real, sin él, Cleveland ganó 19 '
        'partidos.',
  ),
];

/// Un final real para jugar en vivo desde el marcador de entonces.
class MomentoClutch {
  const MomentoClutch({
    required this.id,
    required this.titulo,
    required this.partido,
    required this.anio,
    required this.localId,
    required this.visitanteId,
    required this.usuarioLocal,
    required this.reloj,
    required this.puntosLocal,
    required this.puntosVisitante,
    required this.ataqueLocal,
    required this.relato,
    this.cuarto = 4,
    this.basadoEn = false,
  });

  final String id;
  final String titulo;

  /// "Juego 6 de Las Finales 1998".
  final String partido;
  final int anio;
  final String localId, visitanteId;
  final bool usuarioLocal;
  final int cuarto;
  final double reloj;
  final int puntosLocal, puntosVisitante;
  final bool ataqueLocal;
  final String relato;

  /// El reloj o el marcador exactos son aproximados: "basado en" el partido real.
  final bool basadoEn;

  String get usuarioId => usuarioLocal ? localId : visitanteId;
  String get rivalId => usuarioLocal ? visitanteId : localId;
}

const momentosClutch = <MomentoClutch>[
  MomentoClutch(
    id: 'jordan98',
    titulo: 'El último tiro',
    partido: 'Juego 6 de Las Finales 1998, en Salt Lake City',
    anio: 1998,
    localId: 'UTA',
    visitanteId: 'CHI',
    usuarioLocal: false,
    reloj: 41.9,
    puntosLocal: 86,
    puntosVisitante: 83,
    ataqueLocal: false,
    relato: 'Stockton acaba de meter un triple. Jazz 86, Bulls 83, quedan 41,9 segundos y la pelota es tuya.',
  ),
  MomentoClutch(
    id: 'allen13',
    titulo: 'Ray Allen desde la esquina',
    partido: 'Juego 6 de Las Finales 2013, en Miami',
    anio: 2013,
    localId: 'MIA',
    visitanteId: 'SAS',
    usuarioLocal: true,
    reloj: 28.2,
    puntosLocal: 89,
    puntosVisitante: 94,
    ataqueLocal: true,
    relato: 'Los Spurs ganan por 5 y ya preparan la soga del campeón. Quedan 28,2 segundos.',
  ),
  MomentoClutch(
    id: 'tmac04',
    titulo: '13 puntos en 35 segundos',
    partido: 'Rockets-Spurs, 9 de diciembre de 2004, en Houston',
    anio: 2005,
    localId: 'HOU',
    visitanteId: 'SAS',
    usuarioLocal: true,
    reloj: 35,
    puntosLocal: 68,
    puntosVisitante: 76,
    ataqueLocal: true,
    relato: 'Abajo por 8 con 35 segundos. Media cancha ya se fue a su casa. Tracy McGrady no.',
  ),
  MomentoClutch(
    id: 'kawhi19',
    titulo: 'El tiro que picó cuatro veces',
    partido: 'Juego 7 de semifinales del Este 2019, en Toronto',
    anio: 2019,
    localId: 'TOR',
    visitanteId: 'PHI',
    usuarioLocal: true,
    reloj: 4.2,
    puntosLocal: 90,
    puntosVisitante: 90,
    ataqueLocal: true,
    relato: 'Butler acaba de empatar. 90-90, 4,2 segundos, saque para los Raptors.',
  ),
  MomentoClutch(
    id: 'kyrie16',
    titulo: 'El triple de Kyrie',
    partido: 'Juego 7 de Las Finales 2016, en Oakland',
    anio: 2016,
    localId: 'GSW',
    visitanteId: 'CLE',
    usuarioLocal: false,
    reloj: 110,
    puntosLocal: 89,
    puntosVisitante: 89,
    ataqueLocal: false,
    relato: 'Después del tapón de LeBron a Iguodala, 89-89. Nadie anota hace minutos. Pelota para Cleveland.',
    basadoEn: true,
  ),
  MomentoClutch(
    id: 'reggie95',
    titulo: '8 puntos en 9 segundos',
    partido: 'Juego 1 de semifinales del Este 1995, en el Madison Square Garden',
    anio: 1995,
    localId: 'NYK',
    visitanteId: 'IND',
    usuarioLocal: false,
    reloj: 18.7,
    puntosLocal: 105,
    puntosVisitante: 99,
    ataqueLocal: false,
    relato: 'Knicks 105, Pacers 99, quedan 18,7 segundos. Spike Lee ya festeja en primera fila.',
  ),
  MomentoClutch(
    id: 'magic87',
    titulo: 'El "baby sky-hook"',
    partido: 'Juego 4 de Las Finales 1987, en el Boston Garden',
    anio: 1987,
    localId: 'BOS',
    visitanteId: 'LAL',
    usuarioLocal: false,
    reloj: 7,
    puntosLocal: 106,
    puntosVisitante: 105,
    ataqueLocal: false,
    relato: 'Celtics 106, Lakers 105 en el Garden. Últimos segundos y la pelota para Magic.',
    basadoEn: true,
  ),
  MomentoClutch(
    id: 'shot89',
    titulo: '"The Shot"',
    partido: 'Juego 5 de primera ronda 1989, en Cleveland',
    anio: 1989,
    localId: 'CLE',
    visitanteId: 'CHI',
    usuarioLocal: false,
    reloj: 3,
    puntosLocal: 100,
    puntosVisitante: 99,
    ataqueLocal: false,
    relato: 'Cavaliers 100, Bulls 99. Quedan 3 segundos, saque para Chicago. Ehlo vs. Jordan.',
  ),
  MomentoClutch(
    id: 'dame19',
    titulo: 'Adiós desde 37 pies',
    partido: 'Juego 5 de primera ronda 2019, en Portland',
    anio: 2019,
    localId: 'POR',
    visitanteId: 'OKC',
    usuarioLocal: true,
    reloj: 18,
    puntosLocal: 115,
    puntosVisitante: 115,
    ataqueLocal: true,
    relato: '115-115 y la serie en juego. Lillard deja correr el reloj lejos, muy lejos del aro.',
    basadoEn: true,
  ),
  MomentoClutch(
    id: 'bird87',
    titulo: '¡Robo de Bird!',
    partido: 'Juego 5 de las Finales del Este 1987, en el Boston Garden',
    anio: 1987,
    localId: 'BOS',
    visitanteId: 'DET',
    usuarioLocal: true,
    reloj: 5,
    puntosLocal: 106,
    puntosVisitante: 107,
    ataqueLocal: false,
    relato: 'Detroit gana 107-106 y saca de costado con 5 segundos. Hay que robarla para ganar.',
  ),
  MomentoClutch(
    id: 'fisher04',
    titulo: '0,4 segundos',
    partido: 'Juego 5 de semifinales del Oeste 2004, en San Antonio',
    anio: 2004,
    localId: 'SAS',
    visitanteId: 'LAL',
    usuarioLocal: false,
    reloj: 0.4,
    puntosLocal: 73,
    puntosVisitante: 72,
    ataqueLocal: false,
    relato: 'Duncan la metió por encima de Shaq. Spurs 73, Lakers 72, quedan 0,4 segundos. Alcanza para un tiro.',
  ),
];

/// Lógica de los modos de historia: rosters reales por temporada, historias alternativas y finales.
class HistoriaNba {
  HistoriaNba(this.liga, {this.huecos = const {}});

  final Liga liga;

  /// Años exactos de las cartas cuyo tramo tiene huecos (se fue y volvió en la misma década):
  /// assets/database/temporadas_huecos.json. Sin esto, se usa el rango [primera, última].
  final Map<String, Set<int>> huecos;

  static Map<String, Set<int>> leerHuecos(Map<String, dynamic> json) => {
    for (final e in json.entries) e.key: {...(e.value as List).cast<int>()},
  };

  /// A cuántos años de [anio] jugó esa carta en su franquicia (0: jugó ese año).
  int distancia(Jugador j, int anio) {
    if (huecos[j.id] case final anios?) {
      return anios.map((a) => (a - anio).abs()).reduce((a, b) => a < b ? a : b);
    }
    final (a, b) = j.temporadas!;
    return anio < a ? a - anio : (anio > b ? anio - b : 0);
  }

  /// Temporadas que se pueden jugar: desde la fusión con la ABA (1976-77), casi todas las
  /// franquicias actuales ya existen; antes, más de la mitad no había nacido.
  static const primerAnio = 1977, ultimoAnio = 2026;
  static List<int> get anios => [for (var a = ultimoAnio; a >= primerAnio; a--) a];

  /// Récord real de una franquicia en una temporada (null: no jugó).
  static (int, int)? recordReal(String franquiciaId, int anio) => switch (registrosReales[anio]?[franquiciaId]) {
    (_, final w, final l) => (w, l),
    null => null,
  };

  /// Con qué identidad jugó una franquicia esa temporada ('SEA' para OKC en 1996); si no jugó, la actual.
  static String identidad(String franquiciaId, int anio) => registrosReales[anio]?[franquiciaId]?.$1 ?? franquiciaId;

  /// "64-18 y campeones", "45-37", o null si no jugó.
  static String? resultadoReal(String franquiciaId, int anio) {
    final r = recordReal(franquiciaId, anio);
    if (r == null) return null;
    return '${r.$1}-${r.$2}${campeonesReales[anio] == franquiciaId ? ' y campeones' : ''}';
  }

  /// Plantel real de [franquiciaId] en la temporada [anio] (año de cierre): las cartas de esa
  /// franquicia cuyo tramo incluye ese año, las mejores por media en un puesto que juegan. Sin
  /// cartas ese año (no existía), el tramo más cercano. [forzados] entran sí o sí; [excluidos]
  /// (personas, por nbaPlayerId) no entran.
  PlantelReal? plantelReal(
    String franquiciaId,
    int anio, {
    Set<int> excluidos = const {},
    List<Jugador> forzados = const [],
  }) {
    final propias = [
      for (final j in liga.catalogo)
        if (j.franquiciaId == franquiciaId && j.temporadas != null && !excluidos.contains(j.nbaPlayerId)) j,
    ];
    for (final tolerancia in const [0, 1, 2, 4, 8, 80]) {
      // Una carta por persona: la de tramo más cercano (y más corto) a ese año.
      final porPersona = <int, Jugador>{};
      for (final j in propias.where((j) => distancia(j, anio) <= tolerancia)) {
        final previa = porPersona[j.nbaPlayerId];
        if (previa == null || _mejorTramo(j, previa, anio)) porPersona[j.nbaPlayerId] = j;
      }
      for (final f in forzados) {
        porPersona.remove(f.nbaPlayerId);
      }
      final pool = [...porPersona.values]..sort((a, b) => b.media.compareTo(a.media));
      final plantel = _armar(pool, forzados);
      if (plantel == null) continue;
      final usados = {for (final j in plantel.jugadores) j.nbaPlayerId};
      final suplentes = pool.where((j) => !usados.contains(j.nbaPlayerId)).take(Temporada.maxSuplentes).toList();
      final identidad = registrosReales[anio]?[franquiciaId]?.$1 ?? _identidadMayoritaria(plantel);
      return PlantelReal(
        plantel,
        suplentes,
        identidad,
        aproximado: tolerancia > 0 || recordReal(franquiciaId, anio) == null,
      );
    }
    return null;
  }

  bool _mejorTramo(Jugador nueva, Jugador previa, int anio) {
    int largo(Jugador j) => j.temporadas!.$2 - j.temporadas!.$1;
    final d = distancia(nueva, anio).compareTo(distancia(previa, anio));
    if (d != 0) return d < 0;
    return largo(nueva) < largo(previa);
  }

  static String _identidadMayoritaria(Plantel p) {
    final cuenta = <String, int>{};
    for (final j in p.jugadores) {
      cuenta[j.equipo] = (cuenta[j.equipo] ?? 0) + 1;
    }
    return cuenta.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// 5 titulares + Sexto Hombre: primero los forzados, después los puestos con menos candidatos,
  /// cada uno con el de más media que lo juegue.
  static Plantel? _armar(List<Jugador> pool, List<Jugador> forzados) {
    var plantel = const Plantel();
    for (final f in forzados) {
      final puestos = plantel.posicionesDisponiblesPara(f).where((p) => p != Posicion.sextoHombre).toList();
      if (puestos.isEmpty) return null;
      plantel = plantel.asignar(f, puestos.first);
    }
    final candidatos = pool.take(12).toList();
    final libres = [...Posicion.titulares.where((p) => !plantel.estaOcupada(p))]
      ..sort(
        (a, b) => candidatos
            .where((j) => j.posiciones.contains(a))
            .length
            .compareTo(candidatos.where((j) => j.posiciones.contains(b)).length),
      );
    for (final p in [...libres, Posicion.sextoHombre]) {
      final j = [
        ...candidatos,
        ...pool.skip(12),
      ].where((j) => plantel.posicionesDisponiblesPara(j).contains(p)).firstOrNull;
      if (j == null) return null;
      plantel = plantel.asignar(j, p);
    }
    return plantel;
  }

  Rival _rival(String franquiciaId, int anio, PlantelReal r) => Rival(
    franquiciaId: franquiciaId,
    tipo: TipoRival.epoca,
    epoca: epocaDeAnio(anio),
    identidadId: r.identidadId,
    cartaIds: {for (final p in Posicion.values) p: r.plantel.en(p)!.id},
    tactica: recomendar(PerfilPlantel.de(r.plantel)).tactica,
  );

  /// Cartas forzadas de una historia alternativa (las que existen en el catálogo).
  List<Jugador> forzadosDe(QueHubiera h) => [
    for (final (bbref, franquicia, epoca) in h.agregar)
      ?liga.catalogo.where((j) => j.idBbref == bbref && j.franquiciaId == franquicia && j.epoca == epoca).firstOrNull,
  ];

  /// Partida nueva de Temporada real (o de una historia alternativa, con [historia]).
  Temporada nuevaTemporada({
    required String id,
    required String franquiciaId,
    required int anio,
    QueHubiera? historia,
  }) {
    final r = plantelReal(franquiciaId, anio, forzados: historia == null ? const [] : forzadosDe(historia))!;
    return Temporada(
      id: id,
      franquiciaUsuarioId: franquiciaId,
      plantel: r.plantel,
      suplentes: r.suplentes,
      rerollsRestantes: 0,
      modoJuego: historia == null ? ModoJuego.temporadaReal : ModoJuego.queHubiera,
      datosModo: {'anio': anio, 'historia': ?historia?.id},
    );
  }

  static int anioDe(Temporada t) => t.datosModo['anio'] as int? ?? ultimoAnio;
  static QueHubiera? historiaDe(Temporada t) =>
      historiasAlternativas.where((h) => h.id == t.datosModo['historia']).firstOrNull;

  /// Con las tácticas confirmadas: calendario de 82 y los 29 rivales con su plantel REAL de esa
  /// temporada (la dificultad no cambia nada: los planteles son los que fueron).
  Temporada iniciarLiga(Temporada t) {
    final base = t.calendario.isEmpty ? liga.iniciar(t) : t;
    final anio = anioDe(t);
    final usadas = {
      for (final j in [...t.plantel.jugadores, ...t.suplentes]) j.nbaPlayerId,
    };
    final rivales = {...base.rivales};
    for (final id in base.rivales.keys) {
      final r = plantelReal(id, anio, excluidos: usadas);
      if (r == null) continue;
      usadas.addAll(r.todos.map((j) => j.nbaPlayerId));
      rivales[id] = _rival(id, anio, r);
    }
    return base.copyWith(rivales: rivales);
  }

  // ---------- Momentos clutch ----------

  static const idMomentos = 'momentos-clutch';

  static Set<String> superados(Temporada t) => {...(t.datosModo['superados'] as List? ?? const []).cast<String>()};

  static Temporada partidaMomentos(String franquiciaId) => Temporada(
    id: idMomentos,
    franquiciaUsuarioId: franquiciaId,
    modoJuego: ModoJuego.ultimoCuarto,
    datosModo: const {'superados': <String>[]},
  );

  static Temporada conSuperado(Temporada t, String momentoId) => t.copyWith(
    datosModo: {
      ...t.datosModo,
      'superados': [...superados(t), momentoId]..sort(),
    },
  );

  /// Impulso del momento histórico para tu lado: la cancha empuja, la figura se agranda y la
  /// defensa sale a presionar. Sin esto, remontar 8 en 35 segundos es casi imposible (como fue).
  static const impulsoHistorico = ModificadoresEquipo(
    estrellaCuartoFinal: 0.04,
    tripleExtra: 0.03,
    clutchExtra: 0.02,
    robosFactor: 1.5,
  );

  /// Equipos reales de un momento (sin repetir personas); tu lado lleva [impulsoHistorico].
  (EquipoPartido, EquipoPartido) equipos(MomentoClutch m) {
    final local = plantelReal(m.localId, m.anio)!;
    final visitante = plantelReal(m.visitanteId, m.anio, excluidos: {for (final j in local.todos) j.nbaPlayerId})!;
    EquipoPartido equipo(PlantelReal r, bool propio) => EquipoPartido(
      identidadId: r.identidadId,
      plantel: r.plantel,
      tactica: recomendar(PerfilPlantel.de(r.plantel)).tactica,
      reserva: r.suplentes,
      modificadores: propio ? impulsoHistorico : ModificadoresEquipo.neutros,
    );
    return (equipo(local, m.usuarioLocal), equipo(visitante, !m.usuarioLocal));
  }

  MotorPartido motor(MomentoClutch m) {
    final (local, visitante) = equipos(m);
    return MotorPartido(local: local, visitante: visitante, usuarioLocal: m.usuarioLocal)..arrancarEn(
      cuarto: m.cuarto,
      reloj: m.reloj,
      puntosLocal: m.puntosLocal,
      puntosVisitante: m.puntosVisitante,
      ataqueLocal: m.ataqueLocal,
      faltasLocal: 4,
      faltasVisitante: 4,
    );
  }

  static bool gano(MomentoClutch m, MotorPartido motor) =>
      m.usuarioLocal ? motor.puntosLocal > motor.puntosVisitante : motor.puntosVisitante > motor.puntosLocal;
}

// ---------- Metajuego ----------

/// XP y monedas por cada final real que el usuario da vuelta por primera vez.
const xpMomentoClutch = 80, monedasMomentoClutch = 40;

List<String> _nuevosSuperados(Temporada antes, Temporada despues) => despues.modoJuego != ModoJuego.ultimoCuarto
    ? const []
    : HistoriaNba.superados(despues).difference(HistoriaNba.superados(antes)).toList();

/// Logros de los modos de historia (todos los Momentos clutch).
List<Logro> logrosDeHistoria(Temporada antes, Temporada despues) =>
    _nuevosSuperados(antes, despues).isNotEmpty && HistoriaNba.superados(despues).length >= momentosClutch.length
    ? const [Logro.clutchHistorico]
    : const [];

PerfilEntrenador premiarHistoria(PerfilEntrenador p, Temporada antes, Temporada despues, List<Novedad> novedades) {
  final nuevos = _nuevosSuperados(antes, despues);
  if (nuevos.isEmpty) return p;
  final xp = xpMomentoClutch * nuevos.length, monedas = monedasMomentoClutch * nuevos.length;
  novedades.add(Novedad('Momento clutch: +$xp XP · +$monedas monedas', destacada: true));
  return p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
}
