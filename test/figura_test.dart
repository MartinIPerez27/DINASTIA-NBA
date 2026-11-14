import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/dinastia.dart';
import 'package:flutter_test/flutter_test.dart';

String nombre(String id) => franquiciaPorId(id).nombreCompleto;

/// Figura franquicia: un joven en un equipo flojo que crece según cómo juega.
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  final carrera = CarreraDinastia(liga);

  Temporada jugarEntera(Temporada t) {
    var x = liga.iniciar(t.copyWith(tacticaConfirmada: true));
    while (liga.proximoDelUsuario(x) != null) {
      x = liga.simularProximo(x);
    }
    x = liga.simularOtrosHasta(x, 1 << 30);
    return liga.simularRestoPlayoffs(x);
  }

  TemporadaFigura linea({
    int pj = 70,
    double pts = 12,
    double reb = 4,
    double ast = 3,
    List<String> premios = const [],
  }) => TemporadaFigura(numero: 1, edad: 22, media: 76, pj: pj, pts: pts, reb: reb, ast: ast, premios: premios);

  test('crecimiento: +1 a +5 de joven según cómo jugó; después de los 31 baja', () {
    expect(CarreraDinastia.crecimientoFigura(20, linea(pts: 6, reb: 2, ast: 1)), inInclusiveRange(1, 5));
    expect(
      CarreraDinastia.crecimientoFigura(21, linea(pts: 28, reb: 8, ast: 7, premios: ['MVP', 'All-NBA 1.º equipo'])),
      5,
    );
    expect(
      CarreraDinastia.crecimientoFigura(22, linea(pts: 24, reb: 6, ast: 5)),
      greaterThan(CarreraDinastia.crecimientoFigura(22, linea(pts: 9, reb: 3, ast: 2))),
    );
    expect(CarreraDinastia.crecimientoFigura(29, linea(pts: 5, reb: 1, ast: 1)), 1, reason: 'antes de 31, nunca baja');
    expect(CarreraDinastia.crecimientoFigura(34, linea(pts: 12)), lessThan(0));
    expect(
      CarreraDinastia.crecimientoFigura(23, linea(pj: 10, pts: 30)),
      CarreraDinastia.crecimientoFigura(23, linea(pj: 10)),
      reason: 'con pocos partidos no cuenta el rendimiento',
    );
  });

  test('rol: un base que reparte 7+ pasa a organizador; un pívot de 11 rebotes, a protector', () {
    final base = catalogo.firstWhere((j) => j.posiciones.first == Posicion.base && j.rol != RolCancha.organizadorPuro);
    expect(CarreraDinastia.rolPorJuego(base, linea(ast: 8.5)), RolCancha.organizadorPuro);
    final pivot = catalogo.firstWhere((j) => j.posiciones.first == Posicion.pivot && j.rol != RolCancha.protectorAro);
    expect(CarreraDinastia.rolPorJuego(pivot, linea(reb: 12, ast: 2, pts: 14)), RolCancha.protectorAro);
    expect(CarreraDinastia.rolPorJuego(base, linea(pj: 5, ast: 9)), isNull);
  });

  test('candidatos y partida nueva: figura joven, el resto cartas B, JSON y partidas viejas', () {
    final candidatos = carrera.candidatosFigura(Random(1));
    expect(candidatos, hasLength(8));
    expect(candidatos.map((j) => j.nbaPlayerId).toSet(), hasLength(8));
    expect(candidatos.every((j) => j.media >= 72 && j.media <= 80), isTrue);
    final figura = candidatos.first;
    final t = carrera.nuevaFigura(id: 'fig', franquiciaId: 'DET', figura: figura, dificultad: Dificultad.normal);
    expect(t.plantel.completo, isTrue);
    expect(t.modoJuego, ModoJuego.figuraFranquicia);
    expect(t.plantel.jugadores.where((j) => j.id == figura.id), hasLength(1));
    expect(t.plantel.jugadores.where((j) => j.id != figura.id).every((j) => j.tier == Tier.b), isTrue);
    expect(t.fase, FaseTemporada.tacticas);
    final estado = EstadoDinastia.de(Temporada.fromJson(t.toJson()));
    expect(estado.figuraId, figura.id);
    expect(estado.edades[figura.id], 20);
    expect(CarreraDinastia.esCarrera(t), isTrue);
    // Partida vieja de Dinastía: sin figura.
    expect(
      EstadoDinastia.de(Temporada(id: 'x', franquiciaUsuarioId: 'CHI', datosModo: const {'raiz': 'x'})).figuraId,
      isNull,
    );
  });

  test('dos temporadas: la figura crece, cambia de media en el plantel y queda su legado', () {
    final figura = carrera.candidatosFigura(Random(2)).first;
    var t = jugarEntera(
      carrera.nuevaFigura(id: 'fig2', franquiciaId: 'SAC', figura: figura, dificultad: Dificultad.normal),
    );
    expect(t.fase, FaseTemporada.finalizada);
    final r1 = carrera.receso(t, nombre);
    final ev = r1.figura!;
    expect(ev.temporada.pj, greaterThan(40));
    expect(ev.cambio, inInclusiveRange(1, 5), reason: 'a los 20, siempre crece');
    expect(ev.retirado, isFalse);
    expect(r1.plantel.jugadores.firstWhere((j) => j.id == figura.id).media, ev.despues);
    final elegidos = {
      for (final e in r1.opciones.entries)
        if (!r1.draftParaElBanco) e.key: e.value.first,
    };
    var t2 = carrera.siguiente(t, r1, elegidos);
    final e2 = EstadoDinastia.de(t2);
    expect(e2.figuraId, figura.id);
    expect(e2.figura, hasLength(1));
    expect(e2.edades[figura.id], 21);
    expect(t2.plantel.jugadores.firstWhere((j) => j.id == figura.id).media, ev.despues);
    t2 = jugarEntera(t2);
    final r2 = carrera.receso(t2, nombre);
    expect(r2.figura!.antes, ev.despues);
    final legado = carrera.legado(t2)!;
    expect(legado.temporadas, hasLength(2));
    expect(legado.puntos, greaterThan(0));
    expect(legado.veredicto, isNotEmpty);
    // JSON de la temporada siguiente con la carrera de la figura.
    final t3 = carrera.siguiente(t2, r2, {
      for (final e in r2.opciones.entries)
        if (!r2.draftParaElBanco) e.key: e.value.first,
    });
    expect(EstadoDinastia.de(Temporada.fromJson(t3.toJson())).figura, hasLength(2));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('retiro: no antes de los 35 salvo que caiga por debajo de 70', () {
    final figura = carrera.candidatosFigura(Random(3)).first;
    var t = carrera.nuevaFigura(id: 'fig3', franquiciaId: 'SAC', figura: figura, dificultad: Dificultad.normal);
    // Edad 30: no se retira aunque no haya jugado.
    t = t.copyWith(
      datosModo: {
        ...t.datosModo,
        'edades': {figura.id: 30},
      },
    );
    for (var s = 0; s < 20; s++) {
      expect(carrera.evolucionFigura(t, figura, Random(s)).retirado, isFalse);
    }
    // Media muy baja: se retira a cualquier edad.
    final caida = figura.conMedia(64);
    expect(carrera.evolucionFigura(t, caida, Random(1)).retirado, isTrue);
    // A los 38, casi seguro.
    t = t.copyWith(
      datosModo: {
        ...t.datosModo,
        'edades': {figura.id: 38},
      },
    );
    final retiros = [for (var s = 0; s < 20; s++) carrera.evolucionFigura(t, figura, Random(s)).retirado];
    expect(retiros.where((x) => x).length, greaterThan(10));
  });

  test('legado: veredicto según anillos y premios', () {
    TemporadaFigura s({bool campeon = false, List<String> premios = const [], bool allStar = false}) => TemporadaFigura(
      numero: 1,
      edad: 25,
      media: 90,
      pj: 80,
      pts: 25,
      reb: 6,
      ast: 6,
      campeon: campeon,
      premios: premios,
      allStar: allStar,
    );
    final grande = LegadoFigura('X', [
      for (var i = 0; i < 6; i++) s(campeon: i.isEven, premios: ['MVP', 'All-NBA 1.º equipo'], allStar: true),
    ]);
    expect(grande.veredicto, contains('primera votación'));
    final normal = LegadoFigura('Y', [for (var i = 0; i < 5; i++) s()]);
    expect(normal.veredicto, contains('sin llegar al Salón'));
    expect(normal.puntos, 5 * 80 * 25);
  });
}
