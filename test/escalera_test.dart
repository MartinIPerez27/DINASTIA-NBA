import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/presentation/modos/escalera.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(5));

  Temporada nueva(ModoJuego modo, {Dificultad dificultad = Dificultad.normal}) {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return Temporada(
      id: 'e-${modo.name}',
      franquiciaUsuarioId: 'CHI',
      plantel: p,
      tacticaConfirmada: true,
      dificultad: dificultad,
      modoJuego: modo,
    );
  }

  test('los equipos históricos salen con su núcleo real', () {
    final modos = ModosEscalera(liga, azar: Random(1));
    for (final e in [
      ...mejoresEquipos,
      for (final s in escenarios) ...[s.usuario, s.rival],
    ]) {
      final p = modos.plantelHistorico(e);
      expect(p, isNotNull, reason: '${e.identidadId} ${e.etiqueta}');
      expect(p!.completo, isTrue);
      final nombres = {for (final j in p.jugadores) j.nombre};
      final enNucleo = e.nucleo.where(nombres.contains).length;
      expect(enNucleo, greaterThanOrEqualTo(5), reason: '${e.identidadId} ${e.etiqueta}: $nombres');
    }
    final bulls = modos.plantelHistorico(mejoresEquipos.last)!;
    expect(bulls.en(Posicion.escolta)!.nombre, 'Michael Jordan');
  });

  test('racha infinita: rivales al azar hasta perder, cada vez más fuertes', () {
    final modos = ModosEscalera(liga, azar: Random(2));
    var t = modos.iniciar(nueva(ModoJuego.racha));
    final primero = Escalera.de(t).actual!.rival.media;
    expect(primero, closeTo(72, 3), reason: "en Normal arranca cerca de 72");
    for (var i = 0; i < 60 && !Escalera.de(t).terminada; i++) {
      t = modos.simularPartido(t);
    }
    final e = Escalera.de(t);
    expect(e.terminada, isTrue);
    expect(e.eliminado, isTrue);
    expect(e.racha, e.cruces.length - 1);
    if (e.cruces.length > 15) expect(e.cruces.last.rival.media, greaterThan(primero));
    final copia = Escalera.fromJson(e.toJson());
    expect(copia.cruces.length, e.cruces.length);
    expect(copia.racha, e.racha);
  });

  test('camino al anillo: 10 escalones, 1 de 3 ventajas entre cada uno y Las Finales al final', () {
    final modos = ModosEscalera(liga, azar: Random(3));
    var t = modos.iniciar(nueva(ModoJuego.caminoAlAnillo));
    // Siempre gana: así se recorren los 10 (con victorias forzadas sobre el motor).
    for (var paso = 0; paso < 40 && !Escalera.de(t).terminada; paso++) {
      final e = Escalera.de(t);
      if (e.esperandoVentaja) {
        expect(e.ofrecidas, hasLength(3));
        t = modos.elegirVentaja(t, e.ofrecidas.first);
        continue;
      }
      t = _forzarVictoria(modos, t);
    }
    final e = Escalera.de(t);
    expect(e.completada, isTrue);
    expect(e.cruces, hasLength(ModosEscalera.largoCamino));
    expect(e.elegidas, hasLength(ModosEscalera.largoCamino - 1));
    expect(e.cruces.last.aGanar, 4, reason: 'Las Finales al mejor de 7');
    expect(e.cruces.last.titulo, contains('Las Finales'));
    expect(e.cruces[8].rival.media, greaterThan(e.cruces[0].rival.media + 5));
  });

  test('las ventajas del camino cambian el partido', () {
    final modos = ModosEscalera(liga, azar: Random(4));
    var t = modos.iniciar(nueva(ModoJuego.caminoAlAnillo));
    t = _forzarVictoria(modos, t);
    var e = Escalera.de(t);
    expect(e.esperandoVentaja, isTrue);
    expect(e.pendiente, isNull);
    final elegida = e.ofrecidas.contains(VentajaCamino.quimica) ? VentajaCamino.quimica : e.ofrecidas.first;
    t = modos.elegirVentaja(t, elegida);
    e = Escalera.de(t);
    expect(e.pendiente, isNotNull);
    if (elegida == VentajaCamino.quimica) {
      final propio = modos.equipoUsuario(t);
      expect(propio.forma.values.every((v) => v >= 1), isTrue);
    }
  });

  test('los mejores equipos de la historia: 10 al mejor de 3 y el último son los Bulls 96', () {
    final modos = ModosEscalera(liga, azar: Random(6));
    var t = modos.iniciar(nueva(ModoJuego.mejoresEquipos));
    expect(Escalera.de(t).actual!.aGanar, 2);
    for (var i = 0; i < 40 && !Escalera.de(t).terminada; i++) {
      t = _forzarVictoria(modos, t);
    }
    final e = Escalera.de(t);
    expect(e.completada, isTrue);
    expect(e.cruces.last.rival.identidadId, 'CHI');
    expect(e.cruces.last.rival.etiqueta, '1995-96');
  });

  test('Mundial: 32 sin repetir jugadores, cuadro sembrado y se completa hasta el campeón', () {
    final modos = ModosEscalera(liga, azar: Random(7));
    var t = modos.iniciar(nueva(ModoJuego.mundial));
    var e = Escalera.de(t);
    expect(e.cuadro, hasLength(32));
    expect(e.cuadro.where((r) => r == null), hasLength(1));
    final ids = <int>{};
    for (final r in e.cuadro.whereType<RivalEscalera>()) {
      for (final p in modos.plantelDe(r).jugadores) {
        expect(ids.add(p.nbaPlayerId), isTrue, reason: '${p.nombre} repetido');
      }
    }
    expect(e.cuadro.whereType<RivalEscalera>().map((r) => r.identidadId), containsAll(['SEA', 'NJN']));
    expect(e.pendiente!.titulo, contains('16avos'));
    // Se juega hasta el final (gane o pierda el usuario).
    for (var i = 0; i < 20 && Escalera.de(t).ganadores.length < 5; i++) {
      t = Escalera.de(t).pendiente == null ? modos.simularResto(t) : modos.simularPartido(t);
    }
    e = Escalera.de(t);
    expect(e.ganadores.map((r) => r.length), [16, 8, 4, 2, 1]);
    expect(e.terminada, isTrue);
    expect(Escalera.fromJson(e.toJson()).ganadores, e.ganadores);
  });

  test('escenario: plantel histórico, la serie arranca con el marcador real', () {
    final modos = ModosEscalera(liga, azar: Random(8));
    final esc = escenarioPorId('finales98')!;
    var t = modos.nuevaDeEscenario(esc, id: 'x');
    expect(t.fase, isNot(FaseTemporada.draft));
    expect(t.plantel.jugadores.map((j) => j.nombre), containsAll(['Karl Malone', 'John Stockton']));
    final c = Escalera.de(t).pendiente!;
    expect((c.propias, c.ajenas, c.aGanar), (2, 3, 4));
    expect(c.usuarioLocalProximo, isTrue, reason: 'el Juego 6 es en Salt Lake City');
    t = modos.simularCruce(t);
    expect(Escalera.de(t).terminada, isTrue);
    expect(Temporada.fromJson(t.toJson()).datosModo, t.datosModo);
  });

  test('metajuego: XP por partido, trofeo al completar y la mejor racha al Salón', () {
    final modos = ModosEscalera(liga, azar: Random(9));
    final progreso = Progreso(liga);
    var t = modos.nuevaDeEscenario(escenarioPorId('finales84')!, id: 'p');
    var perfil = const PerfilEntrenador();
    var antes = t;
    t = _forzarVictoria(modos, t);
    final (p, novedades) = progreso.aplicar(perfil, antes, t);
    perfil = p;
    expect(perfil.xp, greaterThan(0));
    expect(perfil.trofeos.map((x) => x.tipo), contains(TipoTrofeo.escenario));
    expect(perfil.logros.keys, contains(Logro.escenario));
    expect(perfil.logros.keys, isNot(contains(Logro.campeon)), reason: 'no es un anillo de temporada');
    expect(novedades, isNotEmpty);
    // Racha.
    var r = modos.iniciar(nueva(ModoJuego.racha));
    for (var i = 0; i < 3; i++) {
      antes = r;
      r = _forzarVictoria(modos, r);
      perfil = progreso.aplicar(perfil, antes, r).$1;
    }
    expect(perfil.mejorRacha, 3);
  });

  testWidgets('pantalla: muestra el cruce, simula y llega al final', (tester) async {
    JugadorAvatar.usarRed = false;
    tester.view.physicalSize = const Size(412, 900) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final modos = ModosEscalera(liga, azar: Random(10));
    var t = modos.nuevaDeEscenario(escenarioPorId('finales84')!, id: 'w');
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('LAL')),
        home: StatefulBuilder(
          builder: (context, setState) =>
              EscaleraPantalla(temporada: t, liga: liga, onCambio: (n) => setState(() => t = n), azar: Random(10)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Finales 1984: Juego 7'), findsWidgets);
    expect(find.text('JUGAR EN VIVO'), findsOneWidget);
    await tester.tap(find.text('SIMULAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(Escalera.de(t).terminada, isTrue);
    expect(find.text('JUGAR EN VIVO'), findsNothing);
  });
}

/// Registra una victoria del usuario en el partido pendiente (para recorrer los modos sin azar).
Temporada _forzarVictoria(ModosEscalera modos, Temporada t) {
  for (var i = 0; i < 200; i++) {
    final m = modos.motor(t)..simularTodo();
    final local = m.usuarioLocal!;
    final mios = local ? m.puntosLocal : m.puntosVisitante;
    final suyos = local ? m.puntosVisitante : m.puntosLocal;
    if (mios > suyos) return modos.registrar(t, m);
  }
  throw StateError('No ganó en 200 intentos');
}
