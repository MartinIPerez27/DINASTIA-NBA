import 'dart:math';

import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/rival.dart';
import '../entities/rol_cancha.dart';
import '../entities/temporada.dart';
import '../all_star.dart';
import '../liga.dart';
import '../playbook.dart';
import '../premios.dart';
import '../versiones.dart';

/// Cómo terminó una temporada de la dinastía (para la línea de tiempo y el Salón).
class TemporadaPasada {
  const TemporadaPasada({
    required this.numero,
    required this.victorias,
    required this.derrotas,
    required this.resultado,
    required this.campeon,
    this.rivalFinal,
    this.figura,
    this.premios = const [],
    this.momentos = const [],
    this.epoca,
  });

  final int numero;
  final int victorias, derrotas;

  /// 'Campeón', 'Las Finales', 'Final de conferencia', 'Semifinal de conferencia', '1.ª ronda',
  /// 'Play-In' o 'Sin playoffs'.
  final String resultado;
  final bool campeon;

  /// Rival en tu última serie (o en Las Finales si saliste campeón): "Boston Celtics (80’)".
  final String? rivalFinal;

  /// El que más puntos hizo de los tuyos.
  final String? figura;

  /// Premios de los tuyos: "Jordan, MVP".
  final List<String> premios;

  /// Lo que pasó en el receso: retiros, novatos, cambio de década.
  final List<String> momentos;

  /// Década en que se jugó (Reescribí la historia).
  final Epoca? epoca;

  TemporadaPasada conMomentos(List<String> nuevos) => TemporadaPasada(
    numero: numero,
    victorias: victorias,
    derrotas: derrotas,
    resultado: resultado,
    campeon: campeon,
    rivalFinal: rivalFinal,
    figura: figura,
    premios: premios,
    momentos: [...momentos, ...nuevos],
    epoca: epoca,
  );

  factory TemporadaPasada.fromJson(Map<String, dynamic> j) => TemporadaPasada(
    numero: j['n'] as int,
    victorias: j['v'] as int,
    derrotas: j['d'] as int,
    resultado: j['resultado'] as String,
    campeon: j['campeon'] as bool? ?? false,
    rivalFinal: j['rival'] as String?,
    figura: j['figura'] as String?,
    premios: (j['premios'] as List? ?? const []).cast<String>(),
    momentos: (j['momentos'] as List? ?? const []).cast<String>(),
    epoca: Epoca.values.asNameMap()[j['epoca']],
  );

  Map<String, dynamic> toJson() => {
    'n': numero,
    'v': victorias,
    'd': derrotas,
    'resultado': resultado,
    if (campeon) 'campeon': true,
    if (rivalFinal != null) 'rival': rivalFinal,
    if (figura != null) 'figura': figura,
    if (premios.isNotEmpty) 'premios': premios,
    if (momentos.isNotEmpty) 'momentos': momentos,
    if (epoca != null) 'epoca': epoca!.name,
  };
}

/// Estado de una dinastía (o de "Reescribí la historia") guardado en [Temporada.datosModo].
/// Una temporada de tu figura (Figura franquicia): su línea por partido, premios y cómo creció.
class TemporadaFigura {
  const TemporadaFigura({
    required this.numero,
    required this.edad,
    required this.media,
    required this.pj,
    required this.pts,
    required this.reb,
    required this.ast,
    this.premios = const [],
    this.allStar = false,
    this.campeon = false,
  });

  /// Temporada de la dinastía (1, 2, 3…) y edad de la figura en ella.
  final int numero, edad;

  /// Media con la que jugó esa temporada.
  final int media;

  /// Partidos y promedios por partido (temporada regular).
  final int pj;
  final double pts, reb, ast;

  /// Premios individuales ("MVP", "All-NBA 1.º equipo", "Máximo Anotador"…).
  final List<String> premios;
  final bool allStar, campeon;

  factory TemporadaFigura.fromJson(Map<String, dynamic> j) => TemporadaFigura(
    numero: j['n'] as int,
    edad: j['edad'] as int,
    media: j['media'] as int,
    pj: j['pj'] as int,
    pts: (j['pts'] as num).toDouble(),
    reb: (j['reb'] as num).toDouble(),
    ast: (j['ast'] as num).toDouble(),
    premios: (j['premios'] as List? ?? const []).cast<String>(),
    allStar: j['allStar'] as bool? ?? false,
    campeon: j['campeon'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'n': numero,
    'edad': edad,
    'media': media,
    'pj': pj,
    'pts': pts,
    'reb': reb,
    'ast': ast,
    if (premios.isNotEmpty) 'premios': premios,
    if (allStar) 'allStar': true,
    if (campeon) 'campeon': true,
  };
}

/// Lo que le pasó a tu figura en el receso: su temporada, cuánto creció y si cambió de rol.
class EvolucionFigura {
  const EvolucionFigura({
    required this.jugador,
    required this.temporada,
    required this.antes,
    required this.despues,
    this.rolNuevo,
    this.retirado = false,
  });

  /// La figura ya con la media nueva (la carta que sigue en el plantel).
  final Jugador jugador;
  final TemporadaFigura temporada;
  final int antes, despues;

  /// Arquetipo que ganó por cómo jugó (null: el mismo).
  final RolCancha? rolNuevo;
  final bool retirado;

  int get cambio => despues - antes;
}

/// La carrera completa de tu figura: totales, anillos, premios y el veredicto del Salón.
class LegadoFigura {
  LegadoFigura(this.nombre, this.temporadas, {this.retirado = false});

  final String nombre;
  final List<TemporadaFigura> temporadas;
  final bool retirado;

  int get partidos => temporadas.fold(0, (a, s) => a + s.pj);
  int get puntos => temporadas.fold(0, (a, s) => a + (s.pts * s.pj).round());
  int get rebotes => temporadas.fold(0, (a, s) => a + (s.reb * s.pj).round());
  int get asistencias => temporadas.fold(0, (a, s) => a + (s.ast * s.pj).round());
  int get anillos => temporadas.where((s) => s.campeon).length;
  int get allStars => temporadas.where((s) => s.allStar).length;
  int premio(String nombre) => temporadas.where((s) => s.premios.contains(nombre)).length;
  int get mvps => premio('MVP');
  int get allNba => temporadas.where((s) => s.premios.any((p) => p.startsWith('All-NBA'))).length;
  int get mejorMedia => temporadas.fold(0, (a, s) => max(a, s.media));

  /// Puntos de "Salón de la Fama" (anillos, MVP, All-NBA, All-Star, puntos de carrera).
  int get puntosSalon => anillos * 4 + mvps * 6 + allNba * 2 + allStars + puntos ~/ 5000;

  /// Veredicto: del "Salón de la Fama en la primera votación" a "le faltó".
  String get veredicto {
    final p = puntosSalon;
    if (p >= 24) return 'Salón de la Fama en la primera votación: una leyenda de la NBA.';
    if (p >= 14) return 'Salón de la Fama: una carrera de las grandes.';
    if (p >= 7) return 'Candidato al Salón: le falta un empujón para entrar.';
    if (temporadas.length < 3) return 'Recién empieza: el legado se escribe temporada a temporada.';
    return 'Una carrera digna, sin llegar al Salón.';
  }
}

class EstadoDinastia {
  const EstadoDinastia({
    required this.raiz,
    this.numero = 1,
    this.edades = const {},
    this.anios = const {},
    this.historial = const [],
    this.epoca,
    this.temporadasEnEpoca = 0,
    this.figuraId,
    this.figura = const [],
    this.figuraRetirada = false,
  });

  /// Figura franquicia: tu figura (id de carta), sus temporadas jugadas y si ya se retiró.
  final String? figuraId;
  final List<TemporadaFigura> figura;
  final bool figuraRetirada;

  /// Id de la primera temporada: las siguientes son `<raiz>-t2`, `<raiz>-t3`…
  final String raiz;

  /// Número de la temporada en curso (1, 2, 3…).
  final int numero;

  /// Edad de cada carta del plantel (por id de carta).
  final Map<String, int> edades;

  /// Temporadas completas de cada carta con vos.
  final Map<String, int> anios;

  /// Temporadas terminadas, de la primera a la última.
  final List<TemporadaPasada> historial;

  /// Reescribí la historia: década en que se juega la temporada en curso.
  final Epoca? epoca;

  /// Reescribí: temporadas ya jugadas en [epoca] (cada [temporadasPorDecada] se pasa a la siguiente).
  final int temporadasEnEpoca;

  static const temporadasPorDecada = 3;

  int get titulos => historial.where((p) => p.campeon).length;

  static EstadoDinastia de(Temporada t) {
    final d = t.datosModo;
    if (d.isEmpty) return EstadoDinastia(raiz: t.id);
    return EstadoDinastia(
      raiz: d['raiz'] as String? ?? t.id,
      numero: d['numero'] as int? ?? 1,
      edades: (d['edades'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, v as int)),
      anios: (d['anios'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, v as int)),
      historial: [
        for (final x in d['historial'] as List? ?? const []) TemporadaPasada.fromJson(x as Map<String, dynamic>),
      ],
      epoca: Epoca.values.asNameMap()[d['epoca']],
      temporadasEnEpoca: d['enEpoca'] as int? ?? 0,
      figuraId: d['figuraId'] as String?,
      figura: [for (final x in d['figura'] as List? ?? const []) TemporadaFigura.fromJson(x as Map<String, dynamic>)],
      figuraRetirada: d['figuraRetirada'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'raiz': raiz,
    'numero': numero,
    if (edades.isNotEmpty) 'edades': edades,
    if (anios.isNotEmpty) 'anios': anios,
    if (historial.isNotEmpty) 'historial': [for (final p in historial) p.toJson()],
    if (epoca != null) 'epoca': epoca!.name,
    if (temporadasEnEpoca > 0) 'enEpoca': temporadasEnEpoca,
    if (figuraId != null) 'figuraId': figuraId,
    if (figura.isNotEmpty) 'figura': [for (final x in figura) x.toJson()],
    if (figuraRetirada) 'figuraRetirada': true,
  };
}

/// Una carta que se retira en el receso.
class Retiro {
  const Retiro(this.jugador, this.edad, this.temporadas, this.frase);

  final Jugador jugador;
  final int edad;

  /// Temporadas con vos.
  final int temporadas;
  final String frase;
}

/// Lo que pasa entre una temporada y la siguiente: todos cumplen un año, los veteranos bajan, algunos
/// se retiran y los puestos libres se cubren con un mini-draft (1 de 3 por puesto).
class Receso {
  const Receso({
    required this.pasada,
    required this.plantel,
    required this.suplentes,
    required this.cambios,
    required this.edades,
    required this.retiros,
    required this.opciones,
    required this.epocaNueva,
    this.figura,
  });

  /// Figura franquicia: cómo le fue a tu figura y cuánto creció.
  final EvolucionFigura? figura;

  /// Resumen de la temporada que terminó.
  final TemporadaPasada pasada;

  /// Plantel con los que siguen (ya envejecidos); los puestos de los retirados quedan vacíos.
  final Plantel plantel;
  final List<Jugador> suplentes;

  /// Cambio de media de cada carta que sigue (por id).
  final Map<String, int> cambios;

  /// Edad nueva de cada carta que sigue.
  final Map<String, int> edades;
  final List<Retiro> retiros;

  /// Mini-draft: 3 novatos por puesto vacío. Si no hay vacantes, 3 para el banco largo
  /// ([Posicion.sextoHombre] como clave, opcional).
  final Map<Posicion, List<Jugador>> opciones;

  /// Reescribí: la década de la temporada que viene (si cambia, es un momento de la historia).
  final Epoca? epocaNueva;

  List<Posicion> get vacantes => [
    for (final p in Posicion.values)
      if (!plantel.estaOcupada(p)) p,
  ];

  /// Sin vacantes, el mini-draft es para el banco largo y se puede saltear.
  bool get draftParaElBanco => vacantes.isEmpty;
}

/// Reglas de los modos de carrera (Dinastía y Reescribí la historia).
class CarreraDinastia {
  CarreraDinastia(this.liga);

  final Liga liga;

  late final Map<String, VersionCarta> _versiones = calcularVersiones(liga.catalogo);

  static bool esCarrera(Temporada t) =>
      t.modoJuego == ModoJuego.dinastia ||
      t.modoJuego == ModoJuego.reescribi ||
      t.modoJuego == ModoJuego.figuraFranquicia;

  static int _hash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

  /// Edad con la que llega una carta: según su etapa (Novato 22, Prime 27, Veterano 32).
  int edadInicial(Jugador j) {
    final base = switch (_versiones[j.id]) {
      VersionCarta.novato => 22,
      VersionCarta.veterano => 32,
      _ => 27,
    };
    return base + _hash(j.id) % 3 - 1;
  }

  /// Cuánto cambia la media al cumplir [edad] (sin el azar).
  static int cambioPorEdad(int edad) => switch (edad) {
    <= 23 => 3,
    <= 25 => 2,
    <= 27 => 1,
    <= 30 => 0,
    <= 32 => -2,
    <= 34 => -3,
    _ => -4,
  };

  /// Probabilidad de retirarse a esa edad.
  static double probabilidadRetiro(int edad) => switch (edad) {
    < 34 => 0,
    34 => 0.15,
    35 => 0.35,
    36 => 0.6,
    _ => 0.85,
  };

  // ---------- Arranque ----------

  /// Datos iniciales de una dinastía nueva.
  static Map<String, dynamic> datosIniciales(String id, {Epoca? epoca}) =>
      EstadoDinastia(raiz: id, epoca: epoca).toJson();

  /// Décadas en las que [franquiciaId] tiene cartas para armar los 6 puestos.
  List<Epoca> epocasPosibles(String franquiciaId) => [
    for (final e in Epoca.values)
      if (plantelDeEpoca(franquiciaId, e) != null) e,
  ];

  /// El plantel real de una franquicia en una década: el mejor por puesto.
  Plantel? plantelDeEpoca(String franquiciaId, Epoca epoca, {Set<int> excluidos = const {}}) => _armar([
    for (final j in liga.catalogo)
      if (j.franquiciaId == franquiciaId && j.epoca == epoca && !excluidos.contains(j.nbaPlayerId)) j,
  ]);

  /// Arma 5 + Sexto Hombre: primero los puestos con menos candidatos; en cada uno, el de más media
  /// (o el más cercano a [objetivo]).
  Plantel? _armar(List<Jugador> pool, {int? objetivo}) {
    final ordenadas = [...pool]
      ..sort(
        (a, b) => objetivo == null
            ? b.media.compareTo(a.media)
            : (a.media - objetivo).abs().compareTo((b.media - objetivo).abs()),
      );
    var plantel = const Plantel();
    final puestos = [...Posicion.titulares]
      ..sort(
        (a, b) => ordenadas
            .where((j) => j.posiciones.contains(a))
            .length
            .compareTo(ordenadas.where((j) => j.posiciones.contains(b)).length),
      );
    for (final p in [...puestos, Posicion.sextoHombre]) {
      final candidato = ordenadas.where((j) => plantel.posicionesDisponiblesPara(j).contains(p)).firstOrNull;
      if (candidato == null) return null;
      plantel = plantel.asignar(candidato, p);
    }
    return plantel;
  }

  /// Reescribí la historia: la temporada 1 con el plantel real de esa década, lista para tácticas.
  Temporada reescribir({
    required String id,
    required String franquiciaId,
    required Epoca epoca,
    required Dificultad dificultad,
    int rerolls = Temporada.rerollsPorTemporada,
  }) {
    final plantel = plantelDeEpoca(franquiciaId, epoca);
    if (plantel == null) throw StateError('No hay plantel de $franquiciaId en ${epoca.etiqueta}.');
    return Temporada(
      id: id,
      franquiciaUsuarioId: franquiciaId,
      plantel: plantel,
      dificultad: dificultad,
      rerollsRestantes: rerolls,
      modoJuego: ModoJuego.reescribi,
      datosModo: datosIniciales(id, epoca: epoca),
    );
  }

  /// Reescribí: los rivales juegan con su plantel de la misma década (si no alcanza, el histórico).
  Temporada rivalesDeEpoca(Temporada t) {
    final epoca = EstadoDinastia.de(t).epoca;
    if (t.modoJuego != ModoJuego.reescribi || epoca == null) return t;
    final propios = {
      for (final j in [...t.plantel.jugadores, ...t.suplentes]) j.nbaPlayerId,
    };
    final rivales = {...t.rivales};
    // Franquicias que no existían en esa década (o sin cartas suficientes): la década más cercana.
    final cercanas = [...Epoca.values]
      ..sort((a, b) => (a.index - epoca.index).abs().compareTo((b.index - epoca.index).abs()));
    for (final id in t.rivales.keys) {
      List<Jugador> pool = const [];
      Plantel? plantel;
      Epoca usada = epoca;
      for (final e in cercanas) {
        pool = [
          for (final j in liga.catalogo)
            if (j.franquiciaId == id && j.epoca == e && !propios.contains(j.nbaPlayerId)) j,
        ];
        plantel = _armar(pool, objetivo: t.dificultad.mediaRivales);
        usada = e;
        if (plantel != null) break;
      }
      if (plantel == null) continue;
      final identidades = <String, int>{};
      for (final j in pool) {
        identidades[j.equipo] = (identidades[j.equipo] ?? 0) + 1;
      }
      final identidad = identidades.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      rivales[id] = Rival(
        franquiciaId: id,
        tipo: TipoRival.epoca,
        epoca: usada,
        identidadId: identidad,
        cartaIds: {for (final p in Posicion.values) p: plantel.en(p)!.id},
        tactica: recomendar(PerfilPlantel.de(plantel)).tactica,
      );
    }
    return t.copyWith(rivales: rivales);
  }

  // ---------- Fin de temporada ----------

  /// Resumen de la temporada terminada (récord, hasta dónde llegó, premios de los tuyos).
  /// [nombreDe]: nombre completo de una franquicia o identidad histórica por id.
  TemporadaPasada resumir(Temporada t, String Function(String id) nombreDe) {
    final usuario = t.franquiciaUsuarioId;
    final r = t.registroUsuario;
    final todas = t.series.where((s) => s.altoId == usuario || s.bajoId == usuario).toList();
    final playoffs = todas.where((s) => !s.ronda.esPlayIn).toList();
    final propias = playoffs.isNotEmpty ? playoffs : todas;
    final campeon = t.campeonId == usuario;
    final resultado = campeon
        ? 'Campeón'
        : propias.isEmpty
        ? 'Sin playoffs'
        : switch (propias.last.ronda) {
            RondaPlayoff.playIn || RondaPlayoff.playInFinal => 'Play-In',
            RondaPlayoff.primeraRonda => '1.ª ronda',
            RondaPlayoff.semifinalConferencia => 'Semifinal de conferencia',
            RondaPlayoff.finalConferencia => 'Final de conferencia',
            RondaPlayoff.finalesNba => 'Las Finales',
            _ => 'Sin playoffs',
          };
    String? rivalFinal;
    if (propias.isNotEmpty) {
      final s = propias.last;
      final id = s.altoId == usuario ? s.bajoId : s.altoId;
      rivalFinal = nombreRival(t, id, nombreDe);
    }
    final figura = t.plantel.jugadores.toList()
      ..sort((a, b) => (t.lineas[b.id]?.pts ?? 0).compareTo(t.lineas[a.id]?.pts ?? 0));
    final premios = t.calendario.isEmpty
        ? const <String>[]
        : [for (final (nombre, g) in calcularPremios(t, liga).de(usuario)) '${apellido(g.jugador)}, $nombre'];
    return TemporadaPasada(
      numero: EstadoDinastia.de(t).numero,
      victorias: r.victorias,
      derrotas: r.derrotas,
      resultado: resultado,
      campeon: campeon,
      rivalFinal: rivalFinal,
      figura: figura.isEmpty ? null : figura.first.nombre,
      premios: premios,
      epoca: EstadoDinastia.de(t).epoca,
    );
  }

  /// "Detroit Pistons (90’)" o "Boston Celtics (Histórico)".
  static String nombreRival(Temporada t, String id, String Function(String id) nombreDe) {
    final r = t.rivales[id];
    final nombre = nombreDe(r?.identidadId ?? id);
    if (r == null) return nombre;
    return '$nombre (${r.tipo == TipoRival.epoca ? r.epoca!.corta : 'Histórico'})';
  }

  /// El receso después de [t] (terminada). Determinístico: abrirlo dos veces da lo mismo.
  Receso receso(Temporada t, String Function(String id) nombreDe) {
    final estado = EstadoDinastia.de(t);
    final azar = Random(_hash('${t.id}-receso'));
    final edades = <String, int>{};
    final cambios = <String, int>{};
    final retiros = <Retiro>[];

    EvolucionFigura? figura;
    Jugador? envejecer(Jugador j, {required bool puedeRetirarse}) {
      if (j.id == estado.figuraId && !estado.figuraRetirada) {
        final ev = evolucionFigura(t, j, azar);
        figura = ev;
        if (ev.retirado) {
          final temporadas = (estado.anios[j.id] ?? 0) + 1;
          retiros.add(Retiro(j, ev.temporada.edad + 1, temporadas, _despedidaFigura(j, ev)));
          return null;
        }
        edades[j.id] = ev.temporada.edad + 1;
        cambios[j.id] = ev.cambio;
        return ev.jugador;
      }
      final edad = (estado.edades[j.id] ?? edadInicial(j)) + 1;
      final temporadas = (estado.anios[j.id] ?? 0) + 1;
      final cambio = (cambioPorEdad(edad) + azar.nextInt(3) - 1).clamp(-6, 4);
      final media = (j.media + cambio).clamp(60, 99);
      final retira = puedeRetirarse && (azar.nextDouble() < probabilidadRetiro(edad) || media < 66);
      if (retira) {
        retiros.add(Retiro(j, edad, temporadas, _despedida(j, edad, temporadas, azar)));
        return null;
      }
      edades[j.id] = edad;
      cambios[j.id] = media - j.media;
      return _conMedia(j, media);
    }

    var plantel = const Plantel();
    // Como mucho 3 retiros por receso: si no, el plantel se desarma de golpe.
    final porEdad =
        [
          for (final p in Posicion.values)
            if (t.plantel.en(p) case final j?) (p, j),
        ]..sort(
          (a, b) =>
              (estado.edades[b.$2.id] ?? edadInicial(b.$2)).compareTo(estado.edades[a.$2.id] ?? edadInicial(a.$2)),
        );
    for (final (p, j) in porEdad) {
      final sigue = envejecer(j, puedeRetirarse: retiros.length < 3);
      if (sigue != null) plantel = Plantel.deEmergencia({..._mapa(plantel), p: sigue});
    }
    final suplentes = [for (final j in t.suplentes) ?envejecer(j, puedeRetirarse: true)];

    // Reescribí: cada 3 temporadas se pasa a la década siguiente.
    Epoca? epocaNueva = estado.epoca;
    if (t.modoJuego == ModoJuego.reescribi && estado.epoca != null) {
      if (estado.temporadasEnEpoca + 1 >= EstadoDinastia.temporadasPorDecada && estado.epoca != Epoca.actualidad) {
        epocaNueva = Epoca.values[estado.epoca!.index + 1];
      }
    }

    final vacantes = [
      for (final p in Posicion.values)
        if (!plantel.estaOcupada(p)) p,
    ];
    final ocupados = {
      for (final j in [...plantel.jugadores, ...suplentes]) j.nbaPlayerId,
      for (final r in retiros) r.jugador.nbaPlayerId,
    };
    final opciones = <Posicion, List<Jugador>>{};
    final yaOfrecidos = <int>{};
    final puestos = vacantes.isEmpty && suplentes.length < Temporada.maxSuplentes ? [Posicion.sextoHombre] : vacantes;
    for (final p in puestos) {
      final elegidas = _novatos(t, p, epocaNueva, {...ocupados, ...yaOfrecidos}, azar);
      yaOfrecidos.addAll(elegidas.map((j) => j.nbaPlayerId));
      opciones[p] = elegidas;
    }
    return Receso(
      pasada: resumir(t, nombreDe),
      plantel: plantel,
      suplentes: suplentes,
      cambios: cambios,
      edades: edades,
      retiros: retiros,
      opciones: opciones,
      epocaNueva: epocaNueva,
      figura: figura,
    );
  }

  // ── Figura franquicia ──

  /// Figuras para elegir: cartas jóvenes (versión Novato) de las últimas décadas, media 72–80.
  List<Jugador> candidatosFigura(Random azar, {int cuantos = 8}) {
    const recientes = {Epoca.anios2000, Epoca.anios2010, Epoca.actualidad};
    bool sirve(Jugador j) =>
        j.media >= 72 && j.media <= 80 && j.posiciones.first != Posicion.sextoHombre && j.tier != Tier.sPlus;
    final novatos = [
      for (final j in liga.catalogo)
        if (sirve(j) && _versiones[j.id] == VersionCarta.novato) j,
    ]..shuffle(azar);
    final otros = [
      for (final j in liga.catalogo)
        if (sirve(j) && recientes.contains(j.epoca) && _versiones[j.id] != VersionCarta.novato) j,
    ]..shuffle(azar);
    final vistos = <int>{};
    return [
      for (final j in [...novatos, ...otros])
        if (vistos.add(j.nbaPlayerId)) j,
    ].take(cuantos).toList();
  }

  /// Partida nueva de Figura franquicia: tu figura (20 años) y el resto, cartas B (franquicia débil).
  Temporada nuevaFigura({
    required String id,
    required String franquiciaId,
    required Jugador figura,
    required Dificultad dificultad,
    int rerolls = 0,
    Random? azar,
  }) {
    final r = azar ?? Random(_hash(id));
    var plantel = const Plantel();
    final puesto = figura.posiciones.firstWhere((p) => p != Posicion.sextoHombre, orElse: () => Posicion.base);
    plantel = plantel.asignar(figura, puesto);
    final pool = [
      for (final j in liga.catalogo)
        if (j.tier == Tier.b && j.media >= 66 && j.media <= 76 && j.nbaPlayerId != figura.nbaPlayerId) j,
    ]..shuffle(r);
    final usados = {figura.nbaPlayerId};
    for (final p in Posicion.values) {
      if (plantel.estaOcupada(p)) continue;
      final j = pool.firstWhere((x) => !usados.contains(x.nbaPlayerId) && plantel.posicionesDisponiblesPara(x).contains(p));
      usados.add(j.nbaPlayerId);
      plantel = plantel.asignar(j, p);
    }
    return Temporada(
      id: id,
      franquiciaUsuarioId: franquiciaId,
      plantel: plantel,
      dificultad: dificultad,
      rerollsRestantes: rerolls,
      modoJuego: ModoJuego.figuraFranquicia,
      datosModo: EstadoDinastia(
        raiz: id,
        figuraId: figura.id,
        edades: {figura.id: 20},
      ).toJson(),
    );
  }

  /// Cuánto crece tu figura en el receso: por edad (más de joven, baja después de los 31), por
  /// cómo jugó y por los premios. De 22 a 30 años: +1 a +5; después puede bajar.
  static int crecimientoFigura(int edad, TemporadaFigura s) {
    final porEdad = switch (edad) {
      <= 22 => 3,
      <= 25 => 2,
      <= 28 => 1,
      <= 31 => 0,
      <= 33 => -2,
      _ => -3,
    };
    final valor = s.pts + 0.7 * s.reb + 0.7 * s.ast;
    final porJuego = s.pj < 20 ? 0 : (valor >= 32 ? 2 : (valor >= 22 ? 1 : (valor < 10 ? -1 : 0)));
    final porPremios =
        (s.premios.contains('MVP') ? 2 : 0) +
        (s.premios.any((p) => p.startsWith('All-NBA')) ? 1 : 0) +
        (s.allStar ? 1 : 0);
    final total = porEdad + porJuego + min(2, porPremios);
    return (edad <= 30 ? total.clamp(1, 5) : total.clamp(-5, 2)).toInt();
  }

  /// Arquetipo que gana tu figura por cómo jugó (null: sigue igual).
  static RolCancha? rolPorJuego(Jugador j, TemporadaFigura s) {
    if (s.pj < 20) return null;
    final p = j.posiciones.first;
    RolCancha? nuevo;
    if (s.ast >= 7) {
      nuevo = switch (p) {
        Posicion.base => RolCancha.organizadorPuro,
        Posicion.escolta => RolCancha.escoltaGenerador,
        Posicion.alero => RolCancha.controladorTotal,
        Posicion.alaPivot => RolCancha.distribuidorInterior,
        Posicion.pivot => RolCancha.pivotOrganizador,
        Posicion.sextoHombre => RolCancha.directorSegundaUnidad,
      };
    } else if (s.pts >= 25) {
      nuevo = switch (p) {
        Posicion.base => RolCancha.anotadorExterior,
        Posicion.escolta => RolCancha.superestrellaAclarados,
        Posicion.alero => RolCancha.anotadorTresNiveles,
        Posicion.alaPivot => RolCancha.maestroPoste,
        Posicion.pivot => RolCancha.goliatPintura,
        Posicion.sextoHombre => RolCancha.microondas,
      };
    } else if (s.reb >= 11 && (p == Posicion.pivot || p == Posicion.alaPivot)) {
      nuevo = p == Posicion.pivot ? RolCancha.protectorAro : RolCancha.fuerzaBruta;
    }
    return nuevo == j.rol ? null : nuevo;
  }

  /// La temporada de tu figura (línea, premios, All-Star, anillo).
  TemporadaFigura temporadaDeFigura(Temporada t, Jugador j) {
    final estado = EstadoDinastia.de(t);
    final l = t.lineas[j.id];
    final pj = l?.pj ?? 0;
    double por(int x) => pj == 0 ? 0 : x / pj;
    final premios = <String>[];
    if (t.calendario.isNotEmpty) {
      final pr = calcularPremios(t, liga);
      for (final (nombre, g) in pr.de(t.franquiciaUsuarioId)) {
        if (g.jugador.id == j.id) premios.add(nombre);
      }
      for (final (i, quinteto) in pr.allNba.indexed) {
        if (quinteto.any((g) => g.jugador.id == j.id)) premios.add('All-NBA ${i + 1}.º equipo');
      }
    }
    final allStar = t.calendario.isEmpty ? null : allStarDe(t, liga);
    return TemporadaFigura(
      numero: estado.numero,
      edad: estado.edades[j.id] ?? 20,
      media: j.media,
      pj: pj,
      pts: por(l?.pts ?? 0),
      reb: por(l?.reb ?? 0),
      ast: por(l?.ast ?? 0),
      premios: premios,
      allStar: allStar != null && [...allStar.este, ...allStar.oeste].any((x) => x.id == j.id),
      campeon: t.campeonId == t.franquiciaUsuarioId,
    );
  }

  /// Receso de tu figura: crece (o baja) y puede cambiar de arquetipo. No se retira antes de los
  /// 35 salvo que caiga por debajo de 70.
  EvolucionFigura evolucionFigura(Temporada t, Jugador j, Random azar) {
    final s = temporadaDeFigura(t, j);
    final edadNueva = s.edad + 1;
    final cambio = crecimientoFigura(s.edad, s);
    final media = (j.media + cambio).clamp(60, 99);
    final retira = media < 70 || (edadNueva >= 35 && azar.nextDouble() < probabilidadRetiro(edadNueva));
    final rol = rolPorJuego(j, s);
    var nueva = _conMedia(j, media);
    if (rol != null) nueva = Jugador.fromJson({...nueva.toJson(), 'rol': rol.name});
    return EvolucionFigura(jugador: nueva, temporada: s, antes: j.media, despues: media, rolNuevo: rol, retirado: retira);
  }

  /// El legado de tu figura hasta ahora (más la temporada en curso si ya terminó).
  LegadoFigura? legado(Temporada t) {
    final estado = EstadoDinastia.de(t);
    final id = estado.figuraId;
    if (id == null) return null;
    final j = [...t.plantel.jugadores, ...t.suplentes].where((x) => x.id == id).firstOrNull ?? liga.jugador(id);
    final temporadas = [...estado.figura];
    if (j != null && !estado.figuraRetirada && t.fase == FaseTemporada.finalizada) {
      temporadas.add(temporadaDeFigura(t, j));
    }
    return LegadoFigura(j?.nombre ?? 'Tu figura', temporadas, retirado: estado.figuraRetirada);
  }

  String _despedidaFigura(Jugador j, EvolucionFigura ev) {
    final legado = LegadoFigura(j.nombre, [ev.temporada]);
    return '${apellido(j)}, tu figura, se retira a los ${ev.temporada.edad + 1}. ${legado.veredicto}';
  }

  static Map<Posicion, Jugador> _mapa(Plantel p) => {for (final x in Posicion.values) x: ?p.en(x)};

  /// Novatos para un puesto. Dinastía: cartas jóvenes (Novato, o de una sola época) de nivel medio.
  /// Reescribí: primero los de tu franquicia de la década siguiente, después los de la liga.
  List<Jugador> _novatos(Temporada t, Posicion p, Epoca? epoca, Set<int> excluidos, Random azar) {
    bool libre(Jugador j) => j.puedeJugarEn(p) && !excluidos.contains(j.nbaPlayerId);
    final List<Jugador> pool;
    if (t.modoJuego == ModoJuego.reescribi && epoca != null) {
      final siguiente = epoca == Epoca.actualidad ? epoca : Epoca.values[epoca.index + 1];
      final propios = [
        for (final j in liga.catalogo)
          if (j.franquiciaId == t.franquiciaUsuarioId && j.epoca == siguiente && libre(j)) j,
      ]..shuffle(azar);
      final liga_ = [
        for (final j in liga.catalogo)
          if (j.epoca == siguiente && j.franquiciaId != t.franquiciaUsuarioId && libre(j) && j.media <= 88) j,
      ]..shuffle(azar);
      pool = [...propios.take(2), ...liga_];
    } else {
      pool = [
        for (final j in liga.catalogo)
          if (libre(j) &&
              j.media >= 72 &&
              j.media <= 84 &&
              (_versiones[j.id] == VersionCarta.novato || !_versiones.containsKey(j.id)) &&
              j.tier != Tier.sPlus)
            j,
      ]..shuffle(azar);
    }
    final vistos = <int>{};
    return [
      for (final j in pool)
        if (vistos.add(j.nbaPlayerId)) j,
    ].take(3).toList();
  }

  /// Media con la que llega un novato: en Reescribí viene de su década de esplendor, así que arranca
  /// más abajo y crece con los años.
  int mediaNovato(Temporada t, Jugador j) => t.modoJuego == ModoJuego.reescribi ? max(65, j.media - 6) : j.media;

  static Jugador _conMedia(Jugador j, int media) => media == j.media ? j : j.conMedia(media);

  String _despedida(Jugador j, int edad, int temporadas, Random azar) {
    final a = apellido(j);
    final opciones = [
      'Se retira $a a los $edad, después de $temporadas ${temporadas == 1 ? 'temporada' : 'temporadas'} con vos. ¡Gracias, ídolo!',
      '$a cuelga las zapatillas a los $edad. La camiseta queda en el recuerdo.',
      'Último baile para $a: se retira a los $edad y se lleva la ovación de pie.',
    ];
    return opciones[azar.nextInt(opciones.length)];
  }

  /// La temporada siguiente: los que siguen, los novatos elegidos ([elegidos], por puesto; en el
  /// mini-draft del banco, con [Posicion.sextoHombre] como clave, va a los suplentes), mismo
  /// entrenador y suplentes. Rivales y calendario se arman de nuevo al confirmar las tácticas.
  Temporada siguiente(Temporada t, Receso r, Map<Posicion, Jugador> elegidos) {
    final estado = EstadoDinastia.de(t);
    final edades = {...r.edades};
    final anios = <String, int>{};
    var plantel = _mapa(r.plantel);
    var suplentes = [...r.suplentes];
    final momentos = [for (final x in r.retiros) x.frase];
    for (final e in elegidos.entries) {
      final novato = _conMedia(e.value, mediaNovato(t, e.value));
      edades[novato.id] = 20 + _hash(novato.id) % 3;
      if (r.draftParaElBanco) {
        if (suplentes.length < Temporada.maxSuplentes) suplentes = [...suplentes, novato];
      } else {
        plantel = {...plantel, e.key: novato};
      }
      momentos.add('Llega ${novato.nombre} en el draft de novatos.');
    }
    if (r.vacantes.any((p) => !plantel.containsKey(p))) {
      throw StateError('Faltan novatos para cubrir los puestos libres.');
    }
    for (final j in [...plantel.values, ...suplentes]) {
      anios[j.id] = (estado.anios[j.id] ?? 0) + (r.edades.containsKey(j.id) ? 1 : 0);
    }
    final cambiaDecada = r.epocaNueva != estado.epoca;
    if (cambiaDecada && r.epocaNueva != null) momentos.add('Empiezan ${r.epocaNueva!.etiqueta.toLowerCase()}.');
    final nuevoEstado = EstadoDinastia(
      raiz: estado.raiz,
      numero: estado.numero + 1,
      edades: edades,
      anios: anios,
      historial: [...estado.historial, r.pasada.conMomentos(momentos)],
      epoca: r.epocaNueva,
      temporadasEnEpoca: cambiaDecada ? 0 : estado.temporadasEnEpoca + 1,
      figuraId: estado.figuraId,
      figura: [...estado.figura, ?r.figura?.temporada],
      figuraRetirada: estado.figuraRetirada || (r.figura?.retirado ?? false),
    );
    // Plantel: se arma respetando las reglas cuando se puede (novatos en su puesto).
    var nuevo = const Plantel();
    for (final e in plantel.entries) {
      nuevo = nuevo.asignar(e.value, e.key);
    }
    return Temporada(
      id: '${estado.raiz}-t${estado.numero + 1}',
      franquiciaUsuarioId: t.franquiciaUsuarioId,
      plantel: nuevo,
      tactica: t.tactica,
      modo: t.modo,
      dificultad: t.dificultad,
      regla: t.regla,
      epocaRegla: t.epocaRegla,
      entrenadorId: t.entrenadorId,
      suplentes: suplentes,
      modoJuego: t.modoJuego,
      datosModo: nuevoEstado.toJson(),
    );
  }
}

/// Línea de tiempo narrada en voseo: una frase por temporada.
List<String> narrar(TemporadaPasada p) {
  final record = '${p.victorias}-${p.derrotas}';
  final contra = p.rivalFinal == null ? '' : ' ante ${p.rivalFinal}';
  final principal = switch (p.resultado) {
    'Campeón' =>
      p.victorias >= 70
          ? '¡$record y campeones$contra! Una temporada para la historia.'
          : '$record y ¡campeones$contra!',
    'Las Finales' => '$record. Llegaron a Las Finales y se les escapó el anillo$contra.',
    'Final de conferencia' => '$record. Cayeron en la final de conferencia$contra.',
    'Semifinal de conferencia' => '$record. Se quedaron en las semifinales de conferencia$contra.',
    '1.ª ronda' => '$record. Afuera en primera ronda$contra.',
    'Play-In' => '$record. No pasaron del Play-In$contra.',
    _ => '$record. Sin playoffs: temporada para olvidar.',
  };
  return [
    principal,
    if (p.premios.isNotEmpty) 'Premios: ${p.premios.join(' · ')}.',
    if (p.figura != null && p.premios.isEmpty) 'La figura: ${p.figura}.',
    ...p.momentos,
  ];
}
