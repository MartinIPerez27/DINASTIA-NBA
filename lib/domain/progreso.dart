import 'dart:math';

import 'all_star.dart';
import 'entities/perfil.dart';
import 'entities/temporada.dart';
import 'liga.dart';
import 'historicos.dart';
import 'motor.dart';
import 'premios.dart';

/// Algo que el jugador ganó y conviene mostrarle (XP, logro, nivel, trofeo).
class Novedad {
  const Novedad(this.titulo, {this.detalle, this.destacada = false});

  final String titulo;
  final String? detalle;

  /// Logros, niveles y trofeos: se muestran más grandes que el XP de cada partido.
  final bool destacada;
}

/// Progreso del entrenador (metajuego): compara la temporada antes y después de un cambio y
/// reparte XP, monedas, puntaje, logros, trofeos e historial. Puro: no guarda nada.
class Progreso {
  Progreso(this.liga);

  final Liga liga;

  static const _xpVictoria = 30, _xpDerrota = 10, _xpVictoriaPlayoff = 50, _xpDerrotaPlayoff = 15;
  static const _xpLogro = 100, _monedasLogro = 50;

  static double _multiplicador(Dificultad d) => switch (d) {
    Dificultad.normal => 1,
    Dificultad.dificil => 1.25,
    Dificultad.leyenda => 1.5,
  };

  (PerfilEntrenador, List<Novedad>) aplicar(PerfilEntrenador perfil, Temporada? antes, Temporada despues) {
    if (antes == null || antes.id != despues.id) return (perfil, const []);
    final novedades = <Novedad>[];
    final nivelAntes = perfil.nivel;
    var p = perfil;
    // Álbum: lo que fichás en el draft queda en tu colección.
    final nuevas = {for (final j in despues.plantel.jugadores) j.id}.difference(p.coleccion);
    if (nuevas.isNotEmpty) p = p.copyWith(coleccion: {...p.coleccion, ...nuevas});
    final mult = _multiplicador(despues.dificultad);
    final usuario = despues.franquiciaUsuarioId;

    // Partidos de temporada regular recién jugados.
    final jugadosAntes = {
      for (final x in antes.calendario)
        if (x.jugado) x.id,
    };
    var xp = 0, monedas = 0, puntaje = p.puntaje;
    var ganados = 0, perdidos = 0;
    for (final x in despues.calendario) {
      if (!x.jugado || jugadosAntes.contains(x.id) || !x.participa(usuario)) continue;
      final gano = x.ganadorId == usuario;
      gano ? ganados++ : perdidos++;
      xp += ((gano ? _xpVictoria : _xpDerrota) * mult).round();
      monedas += gano ? 10 : 3;
      puntaje = _elo(puntaje, despues, x.localId == usuario ? x.visitanteId : x.localId, gano);
    }
    // Partidos de playoffs recién jugados (por diferencia de victorias en cada serie).
    for (final s in despues.series) {
      if (s.altoId != usuario && s.bajoId != usuario) continue;
      final previa = antes.series.where((a) => a.ronda == s.ronda && a.altoId == s.altoId && a.bajoId == s.bajoId);
      final (vA, dA) = previa.isEmpty ? (0, 0) : _victorias(previa.first, usuario);
      final (v, d) = _victorias(s, usuario);
      final rival = s.altoId == usuario ? s.bajoId : s.altoId;
      for (var k = 0; k < v - vA; k++) {
        xp += (_xpVictoriaPlayoff * mult).round();
        monedas += 15;
        puntaje = _elo(puntaje, despues, rival, true);
      }
      for (var k = 0; k < d - dA; k++) {
        xp += (_xpDerrotaPlayoff * mult).round();
        monedas += 5;
        puntaje = _elo(puntaje, despues, rival, false);
      }
      ganados += v - vA;
      perdidos += d - dA;
    }
    if (ganados + perdidos > 0) {
      novedades.add(Novedad('+$xp XP · +$monedas monedas'));
      p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas, puntaje: puntaje);
    }

    // Logros.
    final logros = Map.of(p.logros);
    void lograr(Logro l) {
      if (logros.containsKey(l)) return;
      logros[l] = DateTime.now().millisecondsSinceEpoch;
      novedades.add(Novedad('Logro: ${l.nombre}', detalle: l.descripcion, destacada: true));
      p = p.copyWith(xp: p.xp + _xpLogro, monedas: p.monedas + _monedasLogro);
    }

    final r = despues.registroUsuario;
    final playoffsGanados = despues.series.fold(0, (a, s) => a + _victorias(s, usuario).$1);
    if (r.victorias + playoffsGanados > 0) lograr(Logro.primeraVictoria);
    final racha = _rachaMaxima(despues);
    if (racha >= 10) lograr(Logro.racha10);
    if (racha >= 30) lograr(Logro.racha30);
    if (r.derrotas == 0 && r.victorias >= 41) lograr(Logro.mitadPerfecta);
    final regularTerminada = despues.calendario.isNotEmpty && despues.calendario.every((x) => x.jugado);
    if (regularTerminada) {
      if (r.victorias >= 60) lograr(Logro.sesenta);
      if (r.victorias >= 70) lograr(Logro.setenta);
      if (despues.esTemporadaPerfecta) lograr(Logro.perfecta);
      final (mvp, anotador) = liga.premios(despues);
      if (mvp?.franquiciaId == usuario) lograr(Logro.mvpPropio);
      if (anotador?.franquiciaId == usuario) lograr(Logro.anotadorPropio);
    }
    // El Play-In no cuenta como playoffs (ni para barridas ni para el 16-0).
    final propias = despues.series
        .where((s) => !s.ronda.esPlayIn && (s.altoId == usuario || s.bajoId == usuario))
        .toList();
    if (propias.isNotEmpty) lograr(Logro.playoffs);
    if (propias.any((s) => s.terminada && s.ganadorId == usuario && _victorias(s, usuario).$2 == 0)) {
      lograr(Logro.barrida);
    }
    if (propias.any((s) => s.ronda == RondaPlayoff.finalesNba)) lograr(Logro.finales);
    final campeon = despues.campeonId == usuario;
    if (campeon) {
      lograr(Logro.campeon);
      if (propias.every((s) => _victorias(s, usuario).$2 == 0)) lograr(Logro.invictoPlayoffs);
      if (despues.dificultad == Dificultad.dificil) lograr(Logro.campeonDificil);
      if (despues.dificultad == Dificultad.leyenda) lograr(Logro.campeonLeyenda);
    }
    // All-Star: 3 o más convocados tuyos.
    if (!logros.containsKey(Logro.tresAllStars)) {
      final allStar = allStarDe(despues, liga);
      if (allStar != null && allStar.de(usuario).length >= 3) lograr(Logro.tresAllStars);
    }
    if (regularTerminada && recordsBatidos(despues, liga).isNotEmpty) lograr(Logro.recordHistorico);
    p = p.copyWith(logros: logros);

    // Cierre de temporada: Salón de la Fama, vitrina y carrera de cada carta.
    if (despues.campeonId != null && !p.temporadasCerradas.contains(despues.id)) {
      p = _cerrar(p, despues, novedades);
      if (p.historial.length >= 3) {
        lograr(Logro.tresTemporadas);
        p = p.copyWith(logros: logros);
      }
    }

    if (p.nivel > nivelAntes) {
      final nuevas = [
        for (final v in Ventaja.values)
          if (v.nivel > nivelAntes && v.nivel <= p.nivel) v.descripcion,
      ];
      novedades.add(
        Novedad(
          '¡Nivel ${p.nivel}!',
          detalle: nuevas.isEmpty ? null : 'Nueva ventaja: ${nuevas.join(' · ')}',
          destacada: true,
        ),
      );
    }
    return (p, novedades);
  }

  PerfilEntrenador _cerrar(PerfilEntrenador p, Temporada t, List<Novedad> novedades) {
    final usuario = t.franquiciaUsuarioId;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final todas = t.series.where((s) => s.altoId == usuario || s.bajoId == usuario).toList();
    // Si quedó afuera en el Play-In, ese es el resultado; si no, cuenta la última serie de playoffs.
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
          };
    final (xp, monedas) = switch (resultado) {
      'Campeón' => (600, 250),
      'Las Finales' => (300, 120),
      'Final de conferencia' => (200, 80),
      'Semifinal de conferencia' => (120, 50),
      '1.ª ronda' => (60, 25),
      _ => (0, 10),
    };
    final mult = _multiplicador(t.dificultad);
    final r = t.registroUsuario;
    final (mvp, anotador) = liga.premios(t);
    final propiosIds = {for (final j in t.plantel.jugadores) j.id};
    final figuras = t.plantel.jugadores.toList()
      ..sort((a, b) => (t.lineas[b.id]?.pts ?? 0).compareTo(t.lineas[a.id]?.pts ?? 0));

    final trofeos = [...p.trofeos];
    void trofeo(TipoTrofeo tipo, {String? detalle}) {
      trofeos.add(Trofeo(tipo: tipo, temporadaId: t.id, franquiciaId: usuario, detalle: detalle, fecha: ahora));
      novedades.add(Novedad('Trofeo: ${tipo.nombre}', detalle: detalle, destacada: true));
    }

    if (campeon) {
      trofeo(TipoTrofeo.anillo);
      trofeo(TipoTrofeo.larryOBrien);
    }
    final mejorRecord = t.rivales.keys.every((id) => t.registroDe(id).victorias < r.victorias);
    if (mejorRecord) trofeo(TipoTrofeo.presidente);
    if (t.esTemporadaPerfecta) trofeo(TipoTrofeo.perfecta);
    if (mvp != null && propiosIds.contains(mvp.jugadorId)) {
      trofeo(TipoTrofeo.mvp, detalle: liga.jugador(mvp.jugadorId)?.nombre);
    }
    if (anotador != null && propiosIds.contains(anotador.jugadorId)) {
      trofeo(TipoTrofeo.anotador, detalle: liga.jugador(anotador.jugadorId)?.nombre);
    }
    // Premios completos, quintetos, All-Star y récords.
    final premios = calcularPremios(t, liga);
    for (final (tipo, g) in [
      (TipoTrofeo.dpoy, premios.defensor),
      (TipoTrofeo.sextoHombre, premios.sextoHombre),
      (TipoTrofeo.mip, premios.masMejorado),
    ]) {
      if (g != null && g.franquiciaId == usuario) trofeo(tipo, detalle: g.jugador.nombre);
    }
    for (final (i, quinteto) in premios.allNba.indexed) {
      for (final g in quinteto.where((g) => g.franquiciaId == usuario)) {
        trofeo(TipoTrofeo.allNba, detalle: '${i + 1}.º quinteto: ${g.jugador.nombre}');
      }
    }
    for (final j in allStarDe(t, liga)?.de(usuario) ?? const []) {
      trofeo(TipoTrofeo.allStar, detalle: j.nombre);
    }
    for (final r in recordsBatidos(t, liga)) {
      trofeo(TipoTrofeo.record, detalle: r.texto);
    }

    final carrera = Map.of(p.carrera);
    for (final id in propiosIds) {
      final linea = LineaEstadistica();
      if (t.lineas[id] case final l?) linea.sumar(l);
      if (t.lineasPlayoffs[id] case final l?) linea.sumar(l);
      final previa = carrera[id];
      if (previa != null) linea.sumar(previa.$2);
      carrera[id] = ((previa?.$1 ?? 0) + 1, linea);
    }

    final resumen = ResumenTemporada(
      temporadaId: t.id,
      franquiciaId: usuario,
      dificultad: t.dificultad.nombre,
      victorias: r.victorias,
      derrotas: r.derrotas,
      resultado: resultado,
      campeon: campeon,
      figuras: [for (final j in figuras.take(3)) j.nombre],
      mvp: mvp == null ? null : liga.jugador(mvp.jugadorId)?.nombre,
      fecha: ahora,
    );
    novedades.add(Novedad('Temporada cerrada: $resultado', detalle: '${r.victorias}-${r.derrotas}', destacada: true));
    return p.copyWith(
      xp: p.xp + (xp * mult).round(),
      monedas: p.monedas + monedas,
      trofeos: trofeos,
      historial: [resumen, ...p.historial],
      carrera: carrera,
      temporadasCerradas: {...p.temporadasCerradas, t.id},
    );
  }

  /// (victorias, derrotas) del usuario en una serie.
  (int, int) _victorias(SeriePlayoff s, String usuario) => s.altoId == usuario
      ? (s.victoriasAlto, s.victoriasBajo)
      : s.bajoId == usuario
      ? (s.victoriasBajo, s.victoriasAlto)
      : (0, 0);

  int _rachaMaxima(Temporada t) {
    var actual = 0, maxima = 0;
    final propios = t.calendario.where((x) => x.jugado && x.participa(t.franquiciaUsuarioId)).toList()
      ..sort((a, b) => a.jornada.compareTo(b.jornada));
    for (final x in propios) {
      actual = x.ganadorId == t.franquiciaUsuarioId ? actual + 1 : 0;
      maxima = max(maxima, actual);
    }
    return maxima;
  }

  /// Puntaje tipo Elo: el rival vale más cuanto mayor es la media de su plantel.
  int _elo(int puntaje, Temporada t, String rivalId, bool gano) {
    final rival = t.rivales[rivalId];
    var media = 80.0;
    if (rival != null) {
      final js = liga.plantelDe(rival).jugadores;
      media = js.fold(0, (a, j) => a + j.media) / js.length;
    }
    final fuerza = 1000 + (media - 80) * 25;
    final esperado = 1 / (1 + pow(10, (fuerza - puntaje) / 400));
    return (puntaje + 20 * ((gano ? 1 : 0) - esperado)).round();
  }
}
