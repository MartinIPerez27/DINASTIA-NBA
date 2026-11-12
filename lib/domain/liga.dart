import 'dart:math';

import 'calendario.dart';
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
          if (f.id != t.franquiciaUsuarioId) f.id: _armarRival(f.id, propios),
      },
    );
  }

  Rival _armarRival(String franquiciaId, Set<int> excluidos) {
    final propias = [
      for (final j in catalogo)
        if (j.franquiciaId == franquiciaId && !excluidos.contains(j.nbaPlayerId)) j,
    ];
    final epocas = {for (final j in propias) j.epoca}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final tipo = _azar.nextBool() ? TipoRival.historico : TipoRival.epoca;
    if (tipo == TipoRival.epoca && epocas.isNotEmpty) {
      final epoca = epocas[_azar.nextInt(epocas.length)];
      final deEsaEpoca = propias.where((j) => j.epoca == epoca).toList();
      final plantel = _armarPlantel(deEsaEpoca, variedad: 1);
      if (plantel != null) {
        final identidades = <String, int>{};
        for (final j in deEsaEpoca) {
          identidades[j.equipo] = (identidades[j.equipo] ?? 0) + 1;
        }
        final identidad = identidades.entries.reduce((a, b) => b.value > a.value ? b : a).key;
        return _rival(franquiciaId, TipoRival.epoca, plantel, identidad, epoca: epoca);
      }
    }
    return _rival(franquiciaId, TipoRival.historico, _armarPlantel(propias, variedad: 4)!, franquiciaId);
  }

  /// Arma 5 titulares + Sexto Hombre: por puesto, al azar entre los [variedad] de más media.
  Plantel? _armarPlantel(List<Jugador> pool, {required int variedad}) {
    final ordenadas = [...pool]..sort((a, b) => b.media.compareTo(a.media));
    var plantel = const Plantel();
    // Primero los puestos con menos candidatos, para no quedarse sin pívot o base.
    final puestos = [...Posicion.titulares]
      ..sort(
        (a, b) => ordenadas
            .where((j) => j.posiciones.contains(a))
            .length
            .compareTo(ordenadas.where((j) => j.posiciones.contains(b)).length),
      );
    for (final p in [...puestos, Posicion.sextoHombre]) {
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
      return EquipoPartido(identidadId: franquiciaId, plantel: t.plantel, tactica: t.tactica);
    }
    final r = t.rivales[franquiciaId]!;
    return EquipoPartido(identidadId: r.identidadId, plantel: plantelDe(r), tactica: r.tactica);
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

  /// Simula los partidos de los demás hasta la jornada indicada (incluida).
  Temporada simularOtrosHasta(Temporada t, int jornada) {
    var cambios = false;
    final calendario = [
      for (final p in t.calendario)
        if (!p.jugado && p.jornada <= jornada && !p.participa(t.franquiciaUsuarioId))
          () {
            cambios = true;
            final m = motor(t, p)..simularTodo();
            return p.conResultado(m.parcialesLocal, m.parcialesVisitante);
          }()
        else
          p,
    ];
    return cambios ? t.copyWith(calendario: calendario) : t;
  }

  /// Registra el partido del usuario ya jugado (en vivo o simulado) y suma sus estadísticas.
  Temporada registrar(Temporada t, Partido partido, MotorPartido m) {
    final local = partido.localId == t.franquiciaUsuarioId;
    final lineas = {for (final e in t.lineas.entries) e.key: LineaEstadistica()..sumar(e.value)};
    for (final e in (local ? m.boxLocal : m.boxVisitante).entries) {
      (lineas[e.key] ??= LineaEstadistica()).sumar(e.value);
    }
    final calendario = [
      for (final p in t.calendario) p.id == partido.id ? p.conResultado(m.parcialesLocal, m.parcialesVisitante) : p,
    ];
    return t.copyWith(calendario: calendario, lineas: lineas);
  }

  /// Simula el próximo partido del usuario sin mirarlo (y los de los demás de esas jornadas).
  Temporada simularProximo(Temporada t) {
    final p = proximoDelUsuario(t);
    if (p == null) return simularOtrosHasta(t, 1 << 30);
    final antes = simularOtrosHasta(t, p.jornada);
    final m = motor(antes, p)..simularTodo();
    return registrar(antes, p, m);
  }
}
