import 'dart:math';

import 'entities/franquicia.dart';
import 'entities/partido.dart';
import 'entities/temporada.dart';
import 'liga.dart';
import 'motor.dart';

/// Copa NBA de mitad de temporada: los 4 mejores de cada conferencia en ese momento, cuartos,
/// semis y final a partido único. No cuenta para el récord ni para las estadísticas de la
/// temporada. Los partidos de los demás se simulan solos; el del usuario espera a que lo juegue
/// (en vivo o simulado) y, si lo deja pasar, se simula a las 4 jornadas.
class CopaNba {
  CopaNba(this.liga, {this.azar});

  final Liga liga;

  /// Azar fijo para pruebas (si no, el de la liga).
  final Random? azar;

  /// Jornadas que el usuario puede dejar pasar antes de que su partido de Copa se simule solo.
  static const gracia = 4;

  int _ultimaJornada(Temporada t) => t.calendario.fold(0, (m, p) => max(m, p.jornada));

  /// Jornada en la que arranca la Copa (~35 % de la temporada).
  int jornadaCopa(Temporada t) => max(1, (_ultimaJornada(t) * 0.35).round());

  /// Jornada del próximo partido de temporada regular del usuario (o una más que la última si
  /// ya terminó).
  int _jornadaUsuario(Temporada t) => liga.proximoDelUsuario(t)?.jornada ?? _ultimaJornada(t) + 1;

  bool _empezo(Temporada t) => t.calendario.isNotEmpty && _jornadaUsuario(t) >= jornadaCopa(t);

  bool _delUsuario(SeriePlayoff s, Temporada t) =>
      s.altoId == t.franquiciaUsuarioId || s.bajoId == t.franquiciaUsuarioId;

  bool _misma(SeriePlayoff a, SeriePlayoff b) => a.ronda == b.ronda && a.altoId == b.altoId && a.bajoId == b.bajoId;

  /// Partido de la Copa del usuario que todavía no se jugó.
  SeriePlayoff? pendienteDelUsuario(Temporada t) {
    for (final s in t.copa) {
      if (!s.terminada && _delUsuario(s, t)) return s;
    }
    return null;
  }

  String? campeon(Temporada t) {
    for (final s in t.copa) {
      if (s.ronda == RondaPlayoff.copaFinal) return s.ganadorId;
    }
    return null;
  }

  bool usuarioEliminado(Temporada t) =>
      t.copa.any((s) => s.terminada && _delUsuario(s, t) && s.ganadorId != t.franquiciaUsuarioId);

  /// El usuario está en la Copa (clasificó).
  bool usuarioClasifico(Temporada t) => t.copa.any((s) => _delUsuario(s, t));

  /// Partido único: de local el mejor sembrado.
  Partido partido(SeriePlayoff s) =>
      Partido(id: 'copa-${s.ronda.name}-${s.altoId}-${s.bajoId}', jornada: 0, localId: s.altoId, visitanteId: s.bajoId);

  MotorPartido motor(Temporada t, SeriePlayoff s) => liga.motor(t, partido(s), azar: azar);

  /// Registra el partido de Copa del usuario y hace avanzar el resto del cuadro.
  Temporada registrar(Temporada t, SeriePlayoff s, MotorPartido m) {
    final p = partido(s);
    final gano = m.puntosLocal > m.puntosVisitante ? p.localId : p.visitanteId;
    final nueva = t.copyWith(copa: [for (final x in t.copa) _misma(x, s) ? x.registrarVictoria(gano) : x]);
    return alDia(nueva);
  }

  /// Pone la Copa al día: la arranca cuando corresponde, simula los partidos de los demás, avanza
  /// las rondas y frena cuando le toca jugar al usuario (salvo que lo haya dejado pasar).
  Temporada alDia(Temporada t) {
    if (!_empezo(t)) return t;
    var nueva = t.copa.isEmpty ? _iniciar(t) : t;
    final vencido = _jornadaUsuario(t) >= jornadaCopa(t) + gracia;
    for (var guarda = 0; guarda < 10; guarda++) {
      var cambio = false;
      for (final s in nueva.copa.where((s) => !s.terminada).toList()) {
        if (_delUsuario(s, nueva) && !vencido) continue;
        nueva = _simular(nueva, s);
        cambio = true;
      }
      final avanzada = _avanzar(nueva);
      if (avanzada.copa.length != nueva.copa.length) {
        nueva = avanzada;
        cambio = true;
      }
      if (!cambio) break;
    }
    return nueva;
  }

  Temporada _iniciar(Temporada t) {
    final cuartos = <SeriePlayoff>[];
    for (final conf in [Conferencia.este, Conferencia.oeste]) {
      final tabla = t.standings(conf, liga.franquicias);
      if (tabla.length < 4) return t;
      cuartos
        ..add(
          SeriePlayoff(ronda: RondaPlayoff.copaCuartos, altoId: tabla[0].franquiciaId, bajoId: tabla[3].franquiciaId),
        )
        ..add(
          SeriePlayoff(ronda: RondaPlayoff.copaCuartos, altoId: tabla[1].franquiciaId, bajoId: tabla[2].franquiciaId),
        );
    }
    return t.copyWith(copa: cuartos);
  }

  Temporada _simular(Temporada t, SeriePlayoff s) {
    final m = motor(t, s)..simularTodo();
    final p = partido(s);
    final gano = m.puntosLocal > m.puntosVisitante ? p.localId : p.visitanteId;
    return t.copyWith(copa: [for (final x in t.copa) _misma(x, s) ? x.registrarVictoria(gano) : x]);
  }

  /// Con una ronda terminada arma la siguiente (semis por conferencia; final Este vs Oeste).
  Temporada _avanzar(Temporada t) {
    if (t.copa.isEmpty) return t;
    final ronda = t.copa.last.ronda;
    final deRonda = t.copa.where((s) => s.ronda == ronda).toList();
    if (ronda == RondaPlayoff.copaFinal || deRonda.any((s) => !s.terminada)) return t;
    final siguiente = ronda == RondaPlayoff.copaCuartos ? RondaPlayoff.copaSemis : RondaPlayoff.copaFinal;
    final ganadores = [for (final s in deRonda) s.ganadorId!];
    final nuevas = <SeriePlayoff>[];
    for (var i = 0; i + 1 < ganadores.length; i += 2) {
      final (a, b) = (ganadores[i], ganadores[i + 1]);
      final aPrimero = t.registroDe(a).porcentaje >= t.registroDe(b).porcentaje;
      nuevas.add(SeriePlayoff(ronda: siguiente, altoId: aPrimero ? a : b, bajoId: aPrimero ? b : a));
    }
    return t.copyWith(copa: [...t.copa, ...nuevas]);
  }
}
