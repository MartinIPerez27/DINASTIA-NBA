import 'dart:math';

import 'all_star.dart';
import 'calendario.dart';
import 'entities/entrenador.dart';
import 'entities/franquicia.dart';
import 'entities/jugador.dart';
import 'entities/modo_juego.dart';
import 'entities/partido.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/rival.dart';
import 'entities/temporada.dart';
import 'modos/evoluciones.dart';
import 'motor.dart';
import 'playbook.dart';
import 'versiones.dart';

/// Temporada regular (GDD §7): rivales, calendario de 82 y simulación de los partidos de los demás.
class Liga {
  Liga(this.catalogo, this.franquicias, {Random? azar}) : _azar = azar ?? Random() {
    registrarVersiones(catalogo);
  }

  final List<Jugador> catalogo;
  final List<Franquicia> franquicias;
  final Random _azar;

  /// Nivel de evolución de una carta del álbum (lo conecta la app con el perfil). Solo se aplica en
  /// las partidas que usan el álbum (ver `partidaUsaAlbum`).
  int Function(String cartaId)? nivelEvolucion;

  late final Map<String, Jugador> _porId = {for (final j in catalogo) j.id: j};

  /// Prepara la temporada: calendario oficial y los 29 rivales (mitad históricos, mitad de época).
  /// [excluidos]: personas que tampoco pueden estar en los rivales (p. ej. tu plantel en el Modo espejo).
  Temporada iniciar(Temporada t, {Set<int> excluidos = const {}}) {
    if (!t.plantel.completo || !t.tacticaConfirmada) throw StateError('Faltan el plantel o las tácticas.');
    final propios = {for (final j in t.plantel.jugadores) j.nbaPlayerId, ...excluidos};
    final armada = t.copyWith(
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
    return t.suplentes.isEmpty ? _bancoInicial(armada) : armada;
  }

  /// Rotación de 8 desde el arranque: 2 suplentes del mercado de agentes libres (el mejor y el
  /// mejor de otro puesto). Se pueden liberar y cambiar desde el Plantel.
  Temporada _bancoInicial(Temporada t) {
    final libres = agentesLibres(t);
    if (libres.isEmpty) return t;
    final primero = libres.first;
    final segundo =
        libres.skip(1).where((j) => !j.posiciones.any(primero.posiciones.contains)).firstOrNull ??
        libres.skip(1).firstOrNull;
    return t.copyWith(suplentes: [primero, ?segundo]);
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
      p = p.asignar(cartaOReemplazo(_porId, catalogo, e.value, e.key, p), e.key);
    }
    return p;
  }

  /// Equipo listo para jugar, con los lesionados afuera: entran los suplentes (o, en los rivales,
  /// jugadores de su franquicia y época que no están en ningún plantel).
  EquipoPartido equipo(Temporada t, String franquiciaId, {Map<String, int>? lesiones}) {
    final les = lesiones ?? t.lesiones;
    if (franquiciaId == t.franquiciaUsuarioId) {
      var (plantel, reserva) = _conReemplazos(t.plantel, t.suplentes, les);
      // Evoluciones de cartas: solo en los modos que usan tu álbum.
      if (nivelEvolucion case final nivel? when partidaUsaAlbum(t)) {
        plantel = Plantel.deEmergencia({
          for (final pos in Posicion.values)
            if (plantel.en(pos) case final j?) pos: conNivelEvo(j, nivel(j.id)),
        });
        reserva = [for (final j in reserva) conNivelEvo(j, nivel(j.id))];
      }
      return EquipoPartido(
        identidadId: franquiciaId,
        plantel: plantel,
        tactica: t.tactica,
        entrenador: Entrenador.porId(t.entrenadorId),
        forma: t.forma,
        reserva: reserva,
      );
    }
    final r = t.rivales[franquiciaId]!;
    final base = plantelDe(r);
    final hayLesionados = base.jugadores.any((j) => les.containsKey(j.id));
    final (plantel, _) = hayLesionados
        ? _conReemplazos(base, _reemplazosRival(t, r, base, les), les)
        : (base, const <Jugador>[]);
    return EquipoPartido(identidadId: r.identidadId, plantel: plantel, tactica: r.tactica, forma: t.forma);
  }

  /// Saca a los lesionados: cada titular lesionado lo reemplaza el mejor sano que pueda jugar ese puesto
  /// (el Sexto Hombre o un suplente; si nadie, el mejor aunque sea fuera de puesto). Devuelve el plantel
  /// del partido y los suplentes sanos que quedan en el banco largo.
  (Plantel, List<Jugador>) _conReemplazos(Plantel p, List<Jugador> extra, Map<String, int> les) {
    bool sano(Jugador j) => !les.containsKey(j.id);
    final sexto = p.sextoHombre;
    final disponibles = [if (sexto != null && sano(sexto)) sexto, ...extra.where(sano)];
    if (p.jugadores.every(sano)) return (p, extra.where(sano).toList());
    final puestos = <Posicion, Jugador>{};
    for (final pos in Posicion.titulares) {
      final j = p.en(pos);
      if (j == null) continue;
      if (sano(j) || disponibles.isEmpty) {
        puestos[pos] = j; // sano, o juega tocado porque no hay nadie más
        continue;
      }
      final aptos = disponibles.where((x) => x.puedeJugarEn(pos)).toList();
      final elegido = (aptos.isEmpty ? disponibles : aptos).reduce((a, b) => a.media >= b.media ? a : b);
      disponibles.remove(elegido);
      puestos[pos] = elegido;
    }
    if (disponibles.isNotEmpty) {
      final nuevoSexto = sexto != null && disponibles.contains(sexto)
          ? sexto
          : disponibles.reduce((a, b) => a.media >= b.media ? a : b);
      disponibles.remove(nuevoSexto);
      puestos[Posicion.sextoHombre] = nuevoSexto;
    }
    return (Plantel.deEmergencia(Map.unmodifiable(puestos)), disponibles);
  }

  /// Reemplazos para un rival: los mejores sanos de su franquicia (y de su época, si es de época)
  /// que no están en ningún plantel de la liga.
  List<Jugador> _reemplazosRival(Temporada t, Rival r, Plantel base, Map<String, int> les) {
    final ocupados = {
      for (final j in t.plantel.jugadores) j.nbaPlayerId,
      for (final j in t.suplentes) j.nbaPlayerId,
      for (final j in base.jugadores) j.nbaPlayerId,
    };
    final pool = [
      for (final j in catalogo)
        if (j.franquiciaId == r.franquiciaId &&
            (r.epoca == null || j.epoca == r.epoca) &&
            !ocupados.contains(j.nbaPlayerId) &&
            !les.containsKey(j.id))
          j,
    ]..sort((a, b) => b.media.compareTo(a.media));
    return pool.take(4).toList();
  }

  // ── Banco largo: agentes libres para firmar suplentes ──

  /// 8 agentes libres (cartas A y B que no están en ningún plantel). Cambian cada 10 jornadas.
  List<Jugador> agentesLibres(Temporada t) {
    final bloque = (proximoDelUsuario(t)?.jornada ?? 0) ~/ 10;
    final semilla = '${t.id}-$bloque'.codeUnits.fold(11, (h, c) => (h * 31 + c) & 0x7fffffff);
    final azar = Random(semilla);
    final ocupados = {
      for (final j in t.plantel.jugadores) j.nbaPlayerId,
      for (final j in t.suplentes) j.nbaPlayerId,
      for (final r in t.rivales.values)
        for (final id in r.cartaIds.values) ?_porId[id]?.nbaPlayerId,
    };
    final pool = [
      for (final j in catalogo)
        if ((j.tier == Tier.a || j.tier == Tier.b) &&
            j.media >= 72 &&
            j.media <= 86 &&
            !ocupados.contains(j.nbaPlayerId))
          j,
    ]..shuffle(azar);
    final elegidos = <Jugador>[];
    final personas = <int>{};
    // Variedad: al menos uno por puesto principal, después el resto.
    for (final pos in Posicion.titulares) {
      final j = pool.where((x) => x.posiciones.first == pos && !personas.contains(x.nbaPlayerId)).firstOrNull;
      if (j != null) {
        elegidos.add(j);
        personas.add(j.nbaPlayerId);
      }
    }
    for (final j in pool) {
      if (elegidos.length >= 8) break;
      if (personas.add(j.nbaPlayerId)) elegidos.add(j);
    }
    return elegidos..sort((a, b) => b.media.compareTo(a.media));
  }

  Temporada firmar(Temporada t, Jugador j) {
    if (t.suplentes.length >= Temporada.maxSuplentes) throw StateError('El banco largo ya está completo.');
    if (t.suplentes.any((x) => x.nbaPlayerId == j.nbaPlayerId)) return t;
    return t.copyWith(suplentes: [...t.suplentes, j]);
  }

  Temporada liberar(Temporada t, Jugador j) => t.copyWith(
    suplentes: [
      for (final x in t.suplentes)
        if (x.id != j.id) x,
    ],
  );

  Partido? proximoDelUsuario(Temporada t) {
    for (final p in t.calendario) {
      if (!p.jugado && p.participa(t.franquiciaUsuarioId)) return p;
    }
    return null;
  }

  MotorPartido motor(Temporada t, Partido p, {Random? azar, Map<String, int>? lesiones}) => MotorPartido(
    local: _conDesgaste(equipo(t, p.localId, lesiones: lesiones), t, p, p.localId),
    visitante: _conDesgaste(equipo(t, p.visitanteId, lesiones: lesiones), t, p, p.visitanteId),
    usuarioLocal: p.localId == t.franquiciaUsuarioId,
    azar: azar ?? _azar,
  );

  /// Calendario con desgaste: ¿jugó la noche anterior (back-to-back)? ¿cuántos partidos seguidos
  /// lleva de visitante (gira)? Solo en temporada regular.
  (bool, int) desgaste(Temporada t, Partido p, String franquiciaId) {
    if (p.jornada <= 0) return (false, 0);
    final propios = [
      for (final x in t.calendario)
        if (x.participa(franquiciaId) && x.jornada <= p.jornada) x,
    ]..sort((a, b) => a.jornada.compareTo(b.jornada));
    final i = propios.indexWhere((x) => x.id == p.id);
    if (i < 0) return (false, 0);
    // Las jornadas están comprimidas (casi todos juegan día por medio): como en la NBA real, ~18 %
    // de los partidos de cada equipo son la segunda noche seguida, fijos según el calendario.
    final semilla = '$franquiciaId-${p.jornada}'.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);
    final backToBack = i > 0 && propios[i - 1].jornada == p.jornada - 1 && semilla % 100 < 18;
    var gira = 0;
    for (var k = i; k >= 0 && propios[k].visitanteId == franquiciaId; k--) {
      gira++;
    }
    return (backToBack, gira);
  }

  EquipoPartido _conDesgaste(EquipoPartido e, Temporada t, Partido p, String franquiciaId) {
    final (backToBack, gira) = desgaste(t, p, franquiciaId);
    final energia = 100.0 - (backToBack ? 7 : 0) - (gira >= 3 ? min(5, (gira - 2) * 1.5) : 0);
    if (energia >= 100) return e;
    return EquipoPartido(
      identidadId: e.identidadId,
      plantel: e.plantel,
      tactica: e.tactica,
      entrenador: e.entrenador,
      forma: e.forma,
      energiaInicial: energia,
      reserva: e.reserva,
    );
  }

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
    final lesiones = Map.of(t.lesiones);
    final equipoDe = equipos(t);
    final calendario = [
      for (final p in t.calendario)
        if (!p.jugado && p.jornada <= jornada && !p.participa(t.franquiciaUsuarioId))
          () {
            cambios = true;
            final m = motor(t, p, lesiones: lesiones)..simularTodo();
            _sumarBox(lineas, m);
            _actualizarForma(forma, m);
            _actualizarLesiones(lesiones, p, m, equipoDe, extremo: t.modoJuego == ModoJuego.extremo);
            return p.conResultado(m.parcialesLocal, m.parcialesVisitante);
          }()
        else
          p,
    ];
    return cambios
        ? _conAllStar(t.copyWith(calendario: calendario, lineas: lineas, forma: forma, lesiones: lesiones))
        : t;
  }

  /// Registra el partido del usuario ya jugado (en vivo o simulado) y suma las estadísticas.
  Temporada registrar(Temporada t, Partido partido, MotorPartido m) {
    final lineas = _copia(t.lineas);
    _sumarBox(lineas, m);
    final forma = Map.of(t.forma);
    _actualizarForma(forma, m);
    final lesiones = Map.of(t.lesiones);
    if (partido.jornada > 0) {
      _actualizarLesiones(lesiones, partido, m, equipos(t), extremo: t.modoJuego == ModoJuego.extremo);
    }
    final calendario = [
      for (final p in t.calendario) p.id == partido.id ? p.conResultado(m.parcialesLocal, m.parcialesVisitante) : p,
    ];
    return _conAllStar(t.copyWith(calendario: calendario, lineas: lineas, forma: forma, lesiones: lesiones));
  }

  /// Al cruzar la mitad de la temporada se juega el All-Star y queda guardado en la partida: así es
  /// el mismo aunque se cierre la app y sigan cambiando las estadísticas.
  Temporada _conAllStar(Temporada t) {
    if (t.allStar != null || t.calendario.isEmpty) return t;
    final a = jugarAllStar(t, this);
    return a == null ? t : t.copyWith(allStar: a);
  }

  /// Lesiones: los lesionados de los dos equipos se pierden este partido (uno menos); y cada uno que
  /// jugó tiene una chance chica de lesionarse (casi siempre poco tiempo; a veces, semanas).
  /// En Extremo ([extremo]) son el doble de probables y duran 50 % más.
  void _actualizarLesiones(
    Map<String, int> lesiones,
    Partido p,
    MotorPartido m,
    Map<String, String> equipoDe, {
    bool extremo = false,
  }) {
    String? equipo(String id) => equipoDe[id] ?? _porId[id]?.franquiciaId;
    for (final id in lesiones.keys.toList()) {
      final f = equipo(id);
      if (f != p.localId && f != p.visitanteId) continue;
      final quedan = lesiones[id]! - 1;
      if (quedan <= 0) {
        lesiones.remove(id);
      } else {
        lesiones[id] = quedan;
      }
    }
    for (final e in [...m.boxLocal.entries, ...m.boxVisitante.entries]) {
      final chance = probabilidadLesion * (extremo ? 2 : 1);
      if (e.value.seg < 60 || lesiones.containsKey(e.key) || _azar.nextDouble() >= chance) continue;
      final r = _azar.nextDouble();
      final dias = r < 0.6 ? 1 + _azar.nextInt(3) : (r < 0.9 ? 4 + _azar.nextInt(7) : 11 + _azar.nextInt(15));
      lesiones[e.key] = extremo ? (dias * 1.5).ceil() : dias;
    }
  }

  /// Chance de lesionarse en cada partido que juega (≈ 2-3 lesiones por equipo por temporada).
  static const probabilidadLesion = 0.005;

  /// Forma de las cartas: rendir por encima de lo esperado sube la racha (hasta +3), rendir por
  /// debajo la baja (hasta −3), y con el tiempo todo vuelve a 0.
  /// Forma (−3 a +3, se suma a la media): cómo rindió cada uno en el partido comparado con su
  /// carta (puntos, rebotes, asistencias, robos, tapas, pérdidas y tiros errados, por minuto)
  /// y relativo a sus compañeros: la pelota se reparte, así que en un equipo de figuras no todos
  /// pueden llegar a sus números reales. Un partido muy bueno suma 1, uno muy flojo resta 1 y uno
  /// normal la acerca 1 a cero: hacen falta varios partidos seguidos para llegar a ±3.
  void _actualizarForma(Map<String, int> forma, MotorPartido m) {
    for (final box in [m.boxLocal, m.boxVisitante]) {
      double valor(double pts, double reb, double ast, double rob, double tap, double per) =>
          pts + 0.7 * reb + 0.7 * ast + rob + tap - per;
      final rendimiento = <String, (double, double)>{};
      for (final e in box.entries) {
        final j = _porId[e.key];
        final l = e.value;
        if (j == null || l.seg < 300) continue;
        final s = j.stats;
        final hizo =
            valor(
              l.pts.toDouble(),
              l.reb.toDouble(),
              l.ast.toDouble(),
              l.rob.toDouble(),
              l.tap.toDouble(),
              l.per.toDouble(),
            ) -
            0.5 * (l.tcA - l.tcI); // tiros errados (tcA: intentados, tcI: convertidos)
        final esperado =
            (valor(s.ppp, s.rpp, s.app, s.robP, s.tapP, s.perP) - 0.5 * s.ppp * (1 - s.pctTc) / 2) *
            (l.seg / 60) /
            max(s.minP, 12);
        if (esperado > 0) rendimiento[j.id] = (hizo, esperado);
      }
      if (rendimiento.isEmpty) continue;
      final equipo =
          rendimiento.values.fold(0.0, (a, x) => a + x.$1) / rendimiento.values.fold(0.0, (a, x) => a + x.$2);
      for (final MapEntry(key: id, value: (hizo, esperado)) in rendimiento.entries) {
        final relativo = equipo <= 0 ? 1.0 : hizo / esperado / equipo;
        final delta = relativo > 1.3 ? 1 : (relativo < 0.7 ? -1 : 0);
        final antes = forma[id] ?? 0;
        final nueva = (delta != 0 ? antes + delta : antes - antes.sign).clamp(-3, 3);
        if (nueva == 0) {
          forma.remove(id);
        } else {
          forma[id] = nueva;
        }
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

  /// Anota (o reemplaza) una carta propia de una partida, como el jugador de Mi carrera: premios,
  /// forma y All-Star lo buscan por id. Tiene que tener un id que no sea de ninguna carta del catálogo.
  void registrarCarta(Jugador j) => _porId[j.id] = j;

  /// Franquicia de cada carta en esta temporada (tu plantel y los 29 rivales).
  Map<String, String> equipos(Temporada t) => {
    for (final j in t.plantel.jugadores) j.id: t.franquiciaUsuarioId,
    for (final j in t.suplentes) j.id: t.franquiciaUsuarioId,
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

  /// Con la temporada regular terminada arranca el Play-In (GDD: 7.º a 10.º de cada conferencia):
  /// 7 vs 8 (el ganador es el 7.º) y 9 vs 10; después, el perdedor del 7-8 contra el ganador del 9-10
  /// por el 8.º puesto. Del 1.º al 6.º entran directo.
  Temporada iniciarPlayoffs(Temporada t) {
    if (t.series.isNotEmpty || t.calendario.isEmpty || t.calendario.any((p) => !p.jugado)) return t;
    final series = <SeriePlayoff>[];
    for (final conf in [Conferencia.este, Conferencia.oeste]) {
      final tabla = t.standings(conf, franquicias);
      series
        ..add(SeriePlayoff(ronda: RondaPlayoff.playIn, altoId: tabla[6].franquiciaId, bajoId: tabla[7].franquiciaId))
        ..add(SeriePlayoff(ronda: RondaPlayoff.playIn, altoId: tabla[8].franquiciaId, bajoId: tabla[9].franquiciaId));
    }
    return t.copyWith(series: series);
  }

  /// Si tu equipo entró directo, el Play-In de los demás se juega al instante.
  Temporada simularPlayIn(Temporada t) {
    var nueva = iniciarPlayoffs(t);
    while (nueva.series.isNotEmpty && nueva.series.last.ronda.esPlayIn && nueva.serieDelUsuario == null) {
      final ronda = nueva.series.last.ronda;
      for (final s in nueva.series.where((s) => s.ronda == ronda && !s.terminada).toList()) {
        nueva = _simularSerie(nueva, s);
      }
      final antes = nueva.series.length;
      nueva = _avanzar(nueva);
      if (nueva.series.length == antes) break;
    }
    return nueva;
  }

  /// ¿Se está jugando el Play-In sin el usuario (que espera en la 1.ª ronda)?
  bool esperandoPlayIn(Temporada t) =>
      t.series.isNotEmpty && t.series.last.ronda.esPlayIn && t.serieDelUsuario == null && t.eliminacion == null;

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
    if (ronda == RondaPlayoff.playIn) {
      // Por conferencia: [7 vs 8, 9 vs 10] → perdedor del 7-8 contra ganador del 9-10.
      final finales = <SeriePlayoff>[];
      for (var i = 0; i < deRonda.length; i += 2) {
        final sieteOcho = deRonda[i], nueveDiez = deRonda[i + 1];
        final perdedor = sieteOcho.ganadorId == sieteOcho.altoId ? sieteOcho.bajoId : sieteOcho.altoId;
        finales.add(SeriePlayoff(ronda: RondaPlayoff.playInFinal, altoId: perdedor, bajoId: nueveDiez.ganadorId!));
      }
      return t.copyWith(series: [...t.series, ...finales]);
    }
    if (ronda == RondaPlayoff.playInFinal) {
      final primera = <SeriePlayoff>[];
      final sieteOcho = t.series.where((s) => s.ronda == RondaPlayoff.playIn).toList();
      for (final (k, conf) in [Conferencia.este, Conferencia.oeste].indexed) {
        final tabla = t.standings(conf, franquicias);
        final siembra = [
          for (final r in tabla.take(6)) r.franquiciaId,
          sieteOcho[k * 2].ganadorId!,
          deRonda[k].ganadorId!,
        ];
        for (final (a, b) in _cruces) {
          primera.add(SeriePlayoff(ronda: RondaPlayoff.primeraRonda, altoId: siembra[a], bajoId: siembra[b]));
        }
      }
      return t.copyWith(series: [...t.series, ...primera]);
    }
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

/// La carta [id] del catálogo o, si ya no existe (una partida guardada con un catálogo anterior),
/// un reemplazo que pueda jugar en [puesto]: de la misma franquicia y época, si no de la misma
/// franquicia, si no cualquiera; siempre el de más media que no esté ya en [actual]. Así una
/// partida vieja nunca se rompe por una carta que se quitó.
Jugador cartaOReemplazo(
  Map<String, Jugador> porId,
  Iterable<Jugador> catalogo,
  String id,
  Posicion puesto,
  Plantel actual,
) {
  if (porId[id] case final j?) return j;
  final partes = id.split('-');
  final franquicia = partes.length >= 3 ? partes[partes.length - 2] : '';
  final epoca = partes.length >= 3 ? partes.last : '';
  final ocupados = {for (final j in actual.jugadores) j.nbaPlayerId};
  bool sirve(Jugador j) => j.puedeJugarEn(puesto) && !ocupados.contains(j.nbaPlayerId);
  for (final filtro in <bool Function(Jugador)>[
    (j) => j.franquiciaId == franquicia && j.id.endsWith('-$epoca'),
    (j) => j.franquiciaId == franquicia,
    (_) => true,
  ]) {
    Jugador? mejor;
    for (final j in catalogo) {
      if (filtro(j) && sirve(j) && (mejor == null || j.media > mejor.media)) mejor = j;
    }
    if (mejor != null) return mejor;
  }
  throw StateError('El catálogo no tiene a nadie para $puesto.');
}
