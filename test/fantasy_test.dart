import 'dart:convert';
import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/modos/evoluciones.dart';
import 'package:dinastia_nba/domain/modos/fantasy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final fantasy = Fantasy(catalogo);
  final pool = fantasy.poolDelAnio(1996);

  PartidaFantasy nueva({int rivales = 5, int semilla = 11, Dificultad d = Dificultad.normal}) =>
      fantasy.nueva(anio: 1996, dificultad: d, rivales: rivales, semilla: semilla, pool: pool);

  /// Arma un equipo válido para vos con lo más barato que entre, de a un puesto.
  PartidaFantasy conEquipoUsuario(PartidaFantasy f) {
    var x = f;
    final personas = <int>{};
    for (final pos in Posicion.values) {
      final j = pool.reversed.firstWhere((j) => j.puedeJugarEn(pos) && !personas.contains(j.nbaPlayerId));
      personas.add(j.nbaPlayerId);
      x = fantasy.ficharUsuario(x, pos, j);
    }
    return x;
  }

  test('puntos fantasy: pesos y bonus de doble-doble y triple-doble', () {
    expect(ReglasFantasy.puntos(20, 5, 5, 1, 1, 2), closeTo(20 + 6 + 7.5 + 3 + 3 - 2, 1e-9));
    const dd = LineaFantasy(20, 10, 2, 0, 0, 0);
    expect((dd.dobleDoble, dd.tripleDoble), (true, false));
    expect(dd.puntos, closeTo(20 + 12 + 3 + ReglasFantasy.bonusDobleDoble, 1e-9)); // 20 + 12 (reb) + 3 (2 ast) + bonus
    const td = LineaFantasy(20, 10, 10, 0, 0, 0);
    expect(td.tripleDoble, isTrue);
    expect(td.puntos, closeTo(20 + 12 + 15 + ReglasFantasy.bonusTripleDoble, 1e-9));
    const nada = LineaFantasy(9, 9, 9, 9, 9, 0);
    expect(nada.dobleDoble, isFalse);
  });

  test('el precio sube con la media y va de 1 a unos 13', () {
    var previo = 0;
    for (var m = 60; m <= 99; m++) {
      final p = ReglasFantasy.precio(m);
      expect(p, greaterThanOrEqualTo(previo));
      previo = p;
    }
    expect(ReglasFantasy.precio(60), 1);
    expect(ReglasFantasy.precio(99), inInclusiveRange(12, 14));
  });

  test('el pool de un año tiene a los jugadores de ese año, uno por persona', () {
    final nombres = pool.map((j) => j.nombre).toSet();
    expect(nombres, containsAll(['Michael Jordan', 'Scottie Pippen']));
    expect(pool.map((j) => j.nbaPlayerId).toSet().length, pool.length);
    expect(pool.length, greaterThan(150));
    for (final j in pool) {
      expect(j.temporadas!.$1 <= 1996 && 1996 <= j.temporadas!.$2, isTrue, reason: j.nombre);
    }
    expect(fantasy.alcanza(pool), isTrue);
    expect(fantasy.alcanza(const []), isFalse);
    for (final a in [Fantasy.primerAnio, 2000, 2010, Fantasy.ultimoAnio]) {
      expect(fantasy.alcanza(fantasy.poolDelAnio(a)), isTrue, reason: '$a');
    }
  });

  test('la IA arma equipos completos, dentro del presupuesto y sin repetir personas', () {
    for (final d in Dificultad.values) {
      final f = nueva(rivales: 7, d: d);
      expect(f.equipos, hasLength(8));
      expect(f.presupuesto, ReglasFantasy.presupuesto(d));
      for (final e in f.equipos.skip(1)) {
        expect(e.completo, isTrue, reason: e.nombre);
        expect(fantasy.costo(f, e), lessThanOrEqualTo(f.presupuesto), reason: e.nombre);
        expect(fantasy.validar(f, e), isEmpty, reason: e.nombre);
        for (final pos in Posicion.values) {
          expect(fantasy.carta(e.plantel[pos]!)!.puedeJugarEn(pos), isTrue);
        }
      }
    }
    expect(nueva(rivales: 3).equipos, hasLength(4));
    expect(nueva(rivales: 99).equipos, hasLength(8));
  });

  test('las personalidades arman distinto y la partida es determinista', () {
    final f = nueva(rivales: 7);
    final plantillas = {for (final e in f.equipos.skip(1)) e.ids.join(',')};
    expect(plantillas.length, greaterThanOrEqualTo(6), reason: 'casi todos los mánagers eligen distinto');
    expect({for (final e in f.equipos.skip(1)) e.personalidad}.length, 7);
    expect(jsonEncode(nueva().toJson()), jsonEncode(nueva().toJson()));
    expect(jsonEncode(nueva(semilla: 1).toJson()), isNot(jsonEncode(nueva(semilla: 2).toJson())));
    // "Estrellas" gasta más que "Contador" en promedio de media
    double mediaDe(PersonalidadFantasy p) {
      final e = f.equipos.firstWhere((e) => e.personalidad == p, orElse: () => f.equipos[1]);
      return e.ids.map((id) => fantasy.carta(id)!.media).reduce((a, b) => a + b) / 6;
    }

    expect(mediaDe(PersonalidadFantasy.estrellas), greaterThan(mediaDe(PersonalidadFantasy.contador) - 3));
  });

  test('el mundo simulado es determinista, con lesiones y rachas razonables', () {
    const m = MundoFantasy(77);
    final j = pool.first;
    expect(m.puntosSemana(j, 3), m.puntosSemana(j, 3));
    expect(const MundoFantasy(78).puntosSemana(j, 3), isNot(m.puntosSemana(j, 3)));
    var fuera = 0;
    for (final p in pool.take(60)) {
      for (var s = 0; s < ReglasFantasy.semanasTotales; s++) {
        if (m.lesionado(p.id, s)) fuera++;
        expect(m.racha(p.id, s), inInclusiveRange(0.78, 1.25));
      }
    }
    final tasa = fuera / (60 * ReglasFantasy.semanasTotales);
    expect(tasa, inInclusiveRange(0.02, 0.2));
    expect({for (var s = 0; s < 30; s++) m.partidosSemana(s)}, {3, 4});
  });

  test('el promedio simulado de una estrella se parece al de su carta', () {
    const m = MundoFantasy(5);
    final j = pool.first;
    var total = 0.0, partidos = 0;
    for (var s = 0; s < 40; s++) {
      for (var k = 0; k < m.partidosSemana(s); k++) {
        final l = m.partido(j, s, k);
        if (l != null) {
          total += l.puntos;
          partidos++;
        }
      }
    }
    final esperado = ReglasFantasy.promedio(j);
    expect(total / partidos, inInclusiveRange(esperado * 0.85, esperado * 1.3), reason: j.nombre);
  });

  test('armar tu equipo: puestos, presupuesto, personas repetidas y cambios por semana', () {
    var f = nueva();
    expect(f.fase, FaseFantasy.armado);
    final caro = pool.first;
    // Una carta que no juega ese puesto no entra
    final pos = Posicion.values.firstWhere((p) => !caro.puedeJugarEn(p) && p != Posicion.sextoHombre);
    expect(identical(fantasy.ficharUsuario(f, pos, caro), f), isTrue);
    f = conEquipoUsuario(f);
    expect(f.fase, FaseFantasy.regular);
    expect(fantasy.validar(f, f.tuEquipo), isEmpty);
    expect(fantasy.costo(f, f.tuEquipo), lessThanOrEqualTo(f.presupuesto));
    // Una persona dos veces: se rechaza
    final base = fantasy.carta(f.tuEquipo.plantel[Posicion.base]!)!;
    final otraCarta = Posicion.values.where((p) => p != Posicion.base && base.puedeJugarEn(p)).firstOrNull;
    if (otraCarta != null) expect(identical(fantasy.ficharUsuario(f, otraCarta, base), f), isTrue);
    // Sin pasarse del presupuesto: llenar de estrellas se frena
    var caros = f;
    for (final p in Posicion.values) {
      final j = pool.firstWhere((j) => j.puedeJugarEn(p) && !caros.tuEquipo.ids.contains(j.id));
      caros = fantasy.ficharUsuario(caros, p, j);
      expect(fantasy.costo(caros, caros.tuEquipo), lessThanOrEqualTo(caros.presupuesto));
    }
    // Antes de la 1.ª semana los cambios son libres; después, 1 por semana
    final jugada = fantasy.jugarSemana(f);
    expect(jugada.cambiosEstaSemana, 0);
    final pos2 = Posicion.values[1];
    final actual = jugada.tuEquipo.plantel[pos2]!;
    final cand = pool.reversed.where((j) => j.puedeJugarEn(pos2) && j.id != actual).take(40).toList();
    var x = jugada;
    var hechos = 0;
    for (final j in cand) {
      final y = fantasy.ficharUsuario(x, pos2, j);
      if (!identical(y, x)) {
        x = y;
        hechos++;
      }
    }
    expect(hechos, ReglasFantasy.cambiosPorSemana);
    expect(fantasy.jugarSemana(x).cambiosEstaSemana, 0, reason: 'se renuevan cada semana');
  });

  test('el capitán suma doble', () {
    final f = conEquipoUsuario(nueva());
    final tu = f.tuEquipo;
    final id = tu.ids.first;
    final (conCap, d1) = fantasy.puntosEquipo(f, tu.copyWith(capitan: id), 0);
    final (sinCap, d2) = fantasy.puntosEquipo(f, tu.copyWith(sinCapitan: true), 0);
    expect(conCap - sinCap, closeTo(d2[id]!, 1e-6));
    expect(d1, d2);
  });

  test('una temporada completa: 12 semanas, semis, final, tabla y campeón', () {
    final f = fantasy.simularTodo(conEquipoUsuario(nueva(rivales: 5)));
    expect(f.fase, FaseFantasy.terminada);
    expect(f.semanas, hasLength(ReglasFantasy.semanasTotales));
    expect(f.semanas.where((s) => s.fase == 'regular'), hasLength(12));
    expect(f.semanas.where((s) => s.fase == 'semis').single.cruces, hasLength(2));
    expect(f.semanas.where((s) => s.fase == 'final').single.cruces, hasLength(1));
    final tabla = f.tabla();
    expect(tabla, hasLength(6));
    expect(tabla.fold(0, (a, e) => a + e.victorias), tabla.fold(0, (a, e) => a + e.derrotas));
    // Todos juegan contra todos de forma pareja (con 6 equipos, 12 semanas = cada par 2 veces)
    expect(tabla.every((e) => e.victorias + e.derrotas == 12), isTrue);
    final finalistas = {
      ...f.semanas.last.cruces.first.a.let((a) => [a, f.semanas.last.cruces.first.b]),
    };
    expect(f.clasificados.toSet().containsAll(finalistas), isTrue);
    expect(finalistas.contains(f.campeon), isTrue);
    expect(f.puestoUsuario, inInclusiveRange(1, 6));
    // Determinismo de toda la liga
    final g = fantasy.simularTodo(conEquipoUsuario(nueva(rivales: 5)));
    expect(jsonEncode(g.toJson()), jsonEncode(f.toJson()));
  });

  test('los equipos impares descansan una semana y siempre hay cruces válidos', () {
    for (final n in [4, 5, 6, 7, 8]) {
      final vistos = <(int, int)>{};
      for (var s = 0; s < 12; s++) {
        final cruces = fantasy.crucesRegulares(n, s);
        expect(cruces, hasLength(n ~/ 2));
        final jugando = {
          for (final (a, b) in cruces) ...[a, b],
        };
        expect(jugando.length, cruces.length * 2, reason: 'nadie juega dos veces en la semana');
        expect(jugando.every((i) => i < n), isTrue);
        vistos.addAll(cruces);
      }
      expect(vistos.length, greaterThanOrEqualTo(n * (n - 1) ~/ 2 - n), reason: 'se juegan casi todos los cruces: $n');
    }
  });

  test('la partida se guarda y se lee (incluso dentro de una Temporada)', () {
    final f = fantasy.jugarSemana(fantasy.jugarSemana(conEquipoUsuario(nueva())));
    final copia = PartidaFantasy.fromJson(jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(copia.toJson()), jsonEncode(f.toJson()));
    final t = f.guardarEn(const Temporada(id: 'f', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.fantasy));
    final leida = Temporada.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(leida.modoJuego, ModoJuego.fantasy);
    expect(PartidaFantasy.de(leida)!.semanas, hasLength(2));
    expect(PartidaFantasy.de(const Temporada(id: 'x', franquiciaUsuarioId: 'CHI')), isNull);
  });

  test('las evoluciones del álbum solo cuentan cuando se juega con el álbum', () {
    final album = pool.take(40).map((j) => j.id).toSet();
    final poolAlbum = fantasy.poolAlbum(album);
    expect(poolAlbum.length, lessThanOrEqualTo(40));
    final jugador = poolAlbum.first;
    final perfil = PerfilEvoluciones({jugador.id: const EvoCarta(objetivoId: 'puntos', etapa: 5)})
        .guardarEn(const PerfilEntrenador());
    final conPerfil = Fantasy(catalogo, perfil: perfil);
    PartidaFantasy partida({required bool album}) => conPerfil.nueva(
      anio: album ? 0 : 1996,
      dificultad: Dificultad.normal,
      rivales: 3,
      semilla: 3,
      pool: album ? poolAlbum : pool,
      soloAlbum: album,
    );
    final pAlbum = partida(album: true), pAnio = partida(album: false);
    expect(conPerfil.precioDe(pAlbum, jugador), greaterThanOrEqualTo(conPerfil.precioDe(pAnio, jugador)));
    expect(conPerfil.precioDe(pAnio, jugador), ReglasFantasy.precio(jugador.media));
    final equipo = pAlbum.tuEquipo.copyWith(plantel: {Posicion.base: jugador.id});
    final sumaAlbum = [for (var s = 0; s < 10; s++) conPerfil.puntosEquipo(pAlbum, equipo, s).$1]
        .fold(0.0, (a, b) => a + b);
    final sumaAnio = [for (var s = 0; s < 10; s++) conPerfil.puntosEquipo(pAnio.copyWith(), equipo, s).$1]
        .fold(0.0, (a, b) => a + b);
    expect(sumaAlbum, greaterThan(sumaAnio), reason: '+10 % de producción con 5 etapas, solo en el álbum');
  });

  test('las recompensas: XP por semana ganada, y el podio da monedas y el logro del campeón', () {
    final f0 = conEquipoUsuario(nueva(rivales: 3));
    final t0 = f0.guardarEn(const Temporada(id: 'f', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.fantasy));
    final f1 = fantasy.jugarSemana(f0);
    final t1 = f1.guardarEn(t0);
    final (p1, nov) = premiarFantasy(const PerfilEntrenador(), t0, t1);
    expect(p1.xp, greaterThan(0));
    expect(nov, isNotEmpty);
    // Sin cambios no hay premio
    expect(premiarFantasy(const PerfilEntrenador(), t1, t1).$1.xp, 0);
    // Campeón: forzamos el resultado final
    final fin = fantasy.simularTodo(f0);
    final tFin = fin.guardarEn(t0);
    final (pf, _) = premiarFantasy(const PerfilEntrenador(), t1, tFin);
    expect(pf.xp, greaterThan(p1.xp));
    final tuyo = fin.campeon == PartidaFantasy.usuario;
    expect(pf.logros.containsKey(Logro.campeonFantasy), tuyo);
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
