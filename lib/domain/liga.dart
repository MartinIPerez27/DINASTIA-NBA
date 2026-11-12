import 'dart:math';

import 'calendario.dart';
import 'entities/entrenador.dart';
import 'entities/franquicia.dart';
import 'entities/jugador.dart';
import 'entities/partido.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/rival.dart';
import 'entities/temporada.dart';
import 'motor.dart';
import 'playbook.dart';

/// Temporada regular (GDD §7): rivales, calendario de 82 y simulación de los partidos de los demás.
class Liga {
  Liga(this.catalogo, this.franquicias, {Random? azar}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final List<Franquicia> franquicias;
  final Random _azar;

  late final Map<String, Jugador> _porId = {for (final j in catalogo) j.id: j};

  /// Prepara la temporada: calendario oficial y los 29 rivales (mitad históricos, mitad de época).
  Temporada iniciar(Temporada t) {
    if (!t.plantel.completo || !t.tacticaConfirmada) throw StateError('Faltan el plantel o las tácticas.');
    final propios = {for (final j in t.plantel.jugadores) j.nbaPlayerId};
    return t.copyWith(
      calendario: generarCalendario(franquicias, _azar),
      rivales: {
        for (final f in franquicias)
          if (f.id != t.franquiciaUsuarioId)
            f.id: _armarRival(
              f.id,
              propios,
              t.dificultad,
              robadas: [for (final id in t.robos[f.id] ?? const <String>[]) ?_porId[id]],
            ),
      },
    );
  }

  /// [robadas]: cartas que ese rival se llevó en el draft en serpiente (entran sí o sí).
  Rival _armarRival(
    String franquiciaId,
    Set<int> excluidos,
    Dificultad dificultad, {
    List<Jugador> robadas = const [],
  }) {
    if (robadas.isNotEmpty) {
      var plantel = const Plantel();
      for (final j in robadas) {
        final puestos = plantel.posicionesDisponiblesPara(j);
        if (puestos.isNotEmpty) plantel = plantel.asignar(j, puestos.first);
      }
      final pool = [
        for (final j in catalogo)
          if (j.franquiciaId == franquiciaId && !excluidos.contains(j.nbaPlayerId)) j,
      ];
      final completo = _completarPlantel(plantel, pool, variedad: 3, objetivo: dificultad.mediaRivales);
      if (completo != null) return _rival(franquiciaId, TipoRival.historico, completo, franquiciaId);
    }
    final propias = [
      for (final j in catalogo)
        if (j.franquiciaId == franquiciaId && !excluidos.contains(j.nbaPlayerId)) j,
    ];
    final epocas = {for (final j in propias) j.epoca}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final tipo = _azar.nextBool() ? TipoRival.historico : TipoRival.epoca;
    if (tipo == TipoRival.epoca && epocas.isNotEmpty) {
      final epoca = epocas[_azar.nextInt(epocas.length)];
      final deEsaEpoca = propias.where((j) => j.epoca == epoca).toList();
      final plantel = _armarPlantel(
        deEsaEpoca,
        variedad: dificultad.mediaRivales == null ? 1 : 2,
        objetivo: dificultad.mediaRivales,
      );
      if (plantel != null) {
        final identidades = <String, int>{};
        for (final j in deEsaEpoca) {
          identidades[j.equipo] = (identidades[j.equipo] ?? 0) + 1;
        }
        final identidad = identidades.entries.reduce((a, b) => b.value > a.value ? b : a).key;
        return _rival(franquiciaId, TipoRival.epoca, plantel, identidad, epoca: epoca);
      }
    }
    final plantel = _armarPlantel(propias, variedad: 3, objetivo: dificultad.mediaRivales)!;
    return _rival(franquiciaId, TipoRival.historico, plantel, franquiciaId);
  }

  /// Arma 5 titulares + Sexto Hombre: por puesto, al azar entre los [variedad] de más media
  /// (o, con [objetivo], entre los de media más cercana a esa: así se regula la dificultad).
  Plantel? _armarPlantel(List<Jugador> pool, {required int variedad, int? objetivo}) =>
      _completarPlantel(const Plantel(), pool, variedad: variedad, objetivo: objetivo);

  Plantel? _completarPlantel(Plantel inicial, List<Jugador> pool, {required int variedad, int? objetivo}) {
    final ordenadas = [...pool]
      ..sort(
        (a, b) => objetivo == null
            ? b.media.compareTo(a.media)
            : (a.media - objetivo).abs().compareTo((b.media - objetivo).abs()),
      );
    var plantel = inicial;
    // Primero los puestos con menos candidatos, para no quedarse sin pívot o base.
    final puestos = [...Posicion.titulares]
      ..sort(
        (a, b) => ordenadas
            .where((j) => j.posiciones.contains(a))
            .length
            .compareTo(ordenadas.where((j) => j.posiciones.contains(b)).length),
      );
    for (final p in [...puestos, Posicion.sextoHombre]) {
      if (plantel.estaOcupada(p)) continue;
      final candidatos = ordenadas
          .where((j) => plantel.posicionesDisponiblesPara(j).contains(p))
          .take(variedad)
          .toList();
      if (candidatos.isEmpty) return null;
      plantel = plantel.asignar(candidatos[_azar.nextInt(candidatos.length)], p);
    }
    return plantel;
  }

  Rival _rival(String franquiciaId, TipoRival tipo, Plantel plantel, String identidad, {Epoca? epoca}) => Rival(
    franquiciaId: franquiciaId,
    tipo: tipo,
    epoca: epoca,
    identidadId: identidad,
    cartaIds: {for (final p in Posicion.values) p: plantel.en(p)!.id},
    tactica: recomendar(PerfilPlantel.de(plantel)).tactica,
  );

  Plantel plantelDe(Rival r) {
    var p = const Plantel();
    for (final e in r.cartaIds.entries) {
      p = p.asignar(_porId[e.value]!, e.key);
    }
    return p;
  }

  EquipoPartido equipo(Temporada t, String franquiciaId) {
    if (franquiciaId == t.franquiciaUsuarioId) {
      return EquipoPartido(
        identidadId: franquiciaId,
        plantel: t.plantel,
        tactica: t.tactica,
        entrenador: Entrenador.porId(t.entrenadorId),
        forma: t.forma,
      );
    }
    final r = t.rivales[franquiciaId]!;
    return EquipoPartido(identidadId: r.identidadId, plantel: plantelDe(r), tactica: r.tactica, forma: t.forma);
  }

  Partido? proximoDelUsuario(Temporada t) {
    for (final p in t.calendario) {
      if (!p.jugado && p.participa(t.franquiciaUsuarioId)) return p;
    }
    return null;
  }

  MotorPartido motor(Temporada t, Partido p, {Random? azar}) => MotorPartido(
    local: equipo(t, p.localId),
    visitante: equipo(t, p.visitanteId),
    usuarioLocal: p.localId == t.franquiciaUsuarioId,
    azar: azar ?? _azar,
  );

  Map<String, LineaEstadistica> _copia(Map<String, LineaEstadistica> lineas) => {
    for (final e in lineas.entries) e.key: LineaEstadistica()..sumar(e.value),
  };

  void _sumarBox(Map<String, LineaEstadistica> lineas, MotorPartido m) {
    for (final e in [...m.boxLocal.entries, ...m.boxVisitante.entries]) {
      (lineas[e.key] ??= LineaEstadistica()).sumar(e.value);
    }
  }

  /// Simula los partidos de los demás hasta la jornada indicada (incluida). Las estadísticas de
  /// todos quedan en la temporada (para el STATS 82 de la liga y los premios).
  Temporada simularOtrosHasta(Temporada t, int jornada) {
    var cambios = false;
    final lineas = _copia(t.lineas);
    final forma = Map.of(t.forma);
    final calendario = [
      for (final p in t.calendario)
        if (!p.jugado && p.jornada <= jornada && !p.participa(t.franquiciaUsuarioId))
          () {
            cambios = true;
            final m = motor(t, p)..simularTodo();
            _sumarBox(lineas, m);
            _actualizarForma(forma, m);
            return p.conResultado(m.parcialesLocal, m.parcialesVisitante);
          }()
        else
          p,
    ];
    return cambios ? t.copyWith(calendario: calendario, lineas: lineas, forma: forma) : t;
  }

  /// Registra el partido del usuario ya jugado (en vivo o simulado) y suma las estadísticas.
  Temporada registrar(Temporada t, Partido partido, MotorPartido m) {
    final lineas = _copia(t.lineas);
    _sumarBox(lineas, m);
    final forma = Map.of(t.forma);
    _actualizarForma(forma, m);
    final calendario = [
      for (final p in t.calendario) p.id == partido.id ? p.conResultado(m.parcialesLocal, m.parcialesVisitante) : p,
    ];
    return t.copyWith(calendario: calendario, lineas: lineas, forma: forma);
  }

  /// Forma de las cartas: rendir por encima de lo esperado sube la racha (hasta +3), rendir por
  /// debajo la baja (hasta −3), y con el tiempo todo vuelve a 0.
  void _actualizarForma(Map<String, int> forma, MotorPartido m) {
    for (final e in [...m.boxLocal.entries, ...m.boxVisitante.entries]) {
      final j = _porId[e.key];
      final l = e.value;
      if (j == null || l.seg < 300) continue;
      final s = j.stats;
      double valor(double pts, double reb, double ast, double rob, double tap, double per) =>
          pts + 0.7 * reb + 0.7 * ast + rob + tap - per;
      final minutos = l.seg / 60;
      final hizo =
          valor(
            l.pts.toDouble(),
            l.reb.toDouble(),
            l.ast.toDouble(),
            l.rob.toDouble(),
            l.tap.toDouble(),
            l.per.toDouble(),
          ) -
          0.5 * (l.tcA - l.tcI);
      final esperado =
          (valor(s.ppp, s.rpp, s.app, s.robP, s.tapP, s.perP) - 0.5 * s.ppp * (1 - s.pctTc) / 2) *
          minutos /
          max(s.minP, 12);
      final delta = esperado <= 0 ? 0 : (hizo / esperado > 1.3 ? 1 : (hizo / esperado < 0.7 ? -1 : 0));
      final antes = forma[j.id] ?? 0;
      final nueva = (antes * 0.8 + delta * 1.2).round().clamp(-3, 3);
      if (nueva == 0) {
        forma.remove(j.id);
      } else {
        forma[j.id] = nueva;
      }
    }
  }

  /// Simula el próximo partido del usuario sin mirarlo (y los de los demás de esas jornadas).
  Temporada simularProximo(Temporada t) {
    final p = proximoDelUsuario(t);
    if (p == null) return simularOtrosHasta(t, 1 << 30);
    final antes = simularOtrosHasta(t, p.jornada);
    final m = motor(antes, p)..simularTodo();
    return registrar(antes, p, m);
  }

  // ------------------------------------------------------------------ jugadores y premios

  Jugador? jugador(String cartaId) => _porId[cartaId];

  /// Franquicia de cada carta en esta temporada (tu plantel y los 29 rivales).
  Map<String, String> equipos(Temporada t) => {
    for (final j in t.plantel.jugadores) j.id: t.franquiciaUsuarioId,
    for (final r in t.rivales.values)
      for (final id in r.cartaIds.values) id: r.franquiciaId,
  };

  /// MVP y Máximo Anotador (GDD §8.2) entre los que jugaron al menos la mitad de los partidos.
  /// El MVP pondera la eficiencia por partido con el récord de su equipo.
  (Premio?, Premio?) premios(Temporada t) {
    final equipo = equipos(t);
    final maxPj = t.lineas.values.fold(0, (a, l) => max(a, l.pj));
    if (maxPj == 0) return (null, null);
    Premio? mvp, anotador;
    for (final e in t.lineas.entries) {
      final l = e.value;
      final f = equipo[e.key];
      if (f == null || l.pj * 2 < maxPj) continue;
      final eficiencia = (l.pts + l.reb + l.ast + l.rob + l.tap - (l.tcA - l.tcI) - (l.tlA - l.tlI) - l.per) / l.pj;
      final valor = eficiencia * (0.6 + 0.8 * t.registroDe(f).porcentaje);
      if (mvp == null || valor > mvp.valor) mvp = Premio(e.key, f, valor);
      final ppp = l.pts / l.pj;
      if (anotador == null || ppp > anotador.valor) anotador = Premio(e.key, f, ppp);
    }
    return (mvp, anotador);
  }

  // ------------------------------------------------------------------ playoffs (GDD §7)

  static const _cruces = [(0, 7), (3, 4), (2, 5), (1, 6)]; // 1-8, 4-5, 3-6, 2-7: así se cruzan después

  /// Arma la 1.ª ronda con los 8 mejores de cada conferencia (si la temporada regular terminó).
  Temporada iniciarPlayoffs(Temporada t) {
    if (t.series.isNotEmpty || t.calendario.isEmpty || t.calendario.any((p) => !p.jugado)) return t;
    final series = <SeriePlayoff>[];
    for (final conf in [Conferencia.este, Conferencia.oeste]) {
      final tabla = t.standings(conf, franquicias);
      for (final (a, b) in _cruces) {
        series.add(
          SeriePlayoff(ronda: RondaPlayoff.primeraRonda, altoId: tabla[a].franquiciaId, bajoId: tabla[b].franquiciaId),
        );
      }
    }
    return t.copyWith(series: series);
  }

  /// Partido que sigue en una serie (el local según el 2-2-1-1-1).
  Partido partidoDeSerie(SeriePlayoff s) {
    final local = s.localProximoPartido;
    final juego = s.victoriasAlto + s.victoriasBajo + 1;
    return Partido(
      id: 'po-${s.ronda.name}-${s.altoId}-${s.bajoId}-$juego',
      jornada: 0,
      localId: local,
      visitanteId: local == s.altoId ? s.bajoId : s.altoId,
    );
  }

  /// Registra un partido de playoffs del usuario y hace avanzar el resto del cuadro al mismo ritmo.
  Temporada registrarPlayoff(Temporada t, SeriePlayoff serie, MotorPartido m) {
    final lineas = _copia(t.lineasPlayoffs);
    _sumarBox(lineas, m);
    final p = partidoDeSerie(serie);
    final gano = m.puntosLocal > m.puntosVisitante ? p.localId : p.visitanteId;
    final series = [for (final s in t.series) _misma(s, serie) ? s.registrarVictoria(gano) : s];
    var nueva = t.copyWith(series: series, lineasPlayoffs: lineas);
    // Las otras series de la ronda juegan su partido en paralelo; si la tuya terminó, terminan todas.
    final termino = series.firstWhere((s) => _misma(s, serie)).terminada;
    for (final s in nueva.series.where((s) => s.ronda == serie.ronda && !_misma(s, serie)).toList()) {
      nueva = termino ? _simularSerie(nueva, s) : _simularJuego(nueva, s);
    }
    return _avanzar(nueva);
  }

  /// Simula el próximo partido de la serie del usuario.
  Temporada simularPartidoPlayoff(Temporada t) {
    final s = t.serieDelUsuario;
    if (s == null) return t;
    final p = partidoDeSerie(s);
    return registrarPlayoff(t, s, motor(t, p)..simularTodo());
  }

  /// Simula lo que falta de la serie del usuario.
  Temporada simularSerieUsuario(Temporada t) {
    var nueva = t;
    final ronda = t.serieDelUsuario?.ronda;
    while (ronda != null && nueva.serieDelUsuario?.ronda == ronda) {
      nueva = simularPartidoPlayoff(nueva);
    }
    return nueva;
  }

  /// Simula todo lo que queda hasta conocer al campeón.
  Temporada simularRestoPlayoffs(Temporada t) {
    var nueva = iniciarPlayoffs(t);
    while (nueva.campeonId == null && nueva.series.isNotEmpty) {
      if (nueva.serieDelUsuario != null) {
        nueva = simularPartidoPlayoff(nueva);
        continue;
      }
      final ronda = nueva.series.last.ronda;
      for (final s in nueva.series.where((s) => s.ronda == ronda && !s.terminada).toList()) {
        nueva = _simularSerie(nueva, s);
      }
      nueva = _avanzar(nueva);
    }
    return nueva;
  }

  bool _misma(SeriePlayoff a, SeriePlayoff b) => a.ronda == b.ronda && a.altoId == b.altoId && a.bajoId == b.bajoId;

  Temporada _simularJuego(Temporada t, SeriePlayoff serie) {
    final actual = t.series.firstWhere((s) => _misma(s, serie));
    if (actual.terminada) return t;
    final p = partidoDeSerie(actual);
    final m = motor(t, p)..simularTodo();
    final lineas = _copia(t.lineasPlayoffs);
    _sumarBox(lineas, m);
    final gano = m.puntosLocal > m.puntosVisitante ? p.localId : p.visitanteId;
    return t.copyWith(
      series: [for (final s in t.series) _misma(s, actual) ? s.registrarVictoria(gano) : s],
      lineasPlayoffs: lineas,
    );
  }

  Temporada _simularSerie(Temporada t, SeriePlayoff serie) {
    var nueva = t;
    while (!nueva.series.firstWhere((s) => _misma(s, serie)).terminada) {
      nueva = _simularJuego(nueva, serie);
    }
    return nueva;
  }

  /// Con la ronda terminada, arma la siguiente: los ganadores se cruzan en el orden del cuadro.
  Temporada _avanzar(Temporada t) {
    final ronda = t.series.last.ronda;
    final deRonda = t.series.where((s) => s.ronda == ronda).toList();
    if (ronda == RondaPlayoff.finalesNba || deRonda.any((s) => !s.terminada)) return t;
    final siguiente = RondaPlayoff.values[ronda.index + 1];
    final ganadores = [for (final s in deRonda) s.ganadorId!];
    final nuevas = <SeriePlayoff>[];
    for (var i = 0; i < ganadores.length; i += 2) {
      final (a, b) = (ganadores[i], ganadores[i + 1]);
      // Ventaja de localía: mejor siembra en la conferencia; en Las Finales, mejor récord.
      final aPrimero = siguiente == RondaPlayoff.finalesNba
          ? t.registroDe(a).porcentaje >= t.registroDe(b).porcentaje
          : _siembra(t, a) < _siembra(t, b);
      nuevas.add(SeriePlayoff(ronda: siguiente, altoId: aPrimero ? a : b, bajoId: aPrimero ? b : a));
    }
    return t.copyWith(series: [...t.series, ...nuevas]);
  }

  int _siembra(Temporada t, String franquiciaId) {
    final conf = franquicias.firstWhere((f) => f.id == franquiciaId).conferencia!;
    return t.standings(conf, franquicias).indexWhere((r) => r.franquiciaId == franquiciaId);
  }
}

/// Un premio de la temporada: a quién, de qué equipo y el valor que lo definió.
class Premio {
  const Premio(this.jugadorId, this.franquiciaId, this.valor);

  final String jugadorId;
  final String franquiciaId;
  final double valor;
}
