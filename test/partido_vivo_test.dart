import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/relator.dart';
import 'package:dinastia_nba/presentation/pantallas/partido_pantalla.dart';
import 'package:dinastia_nba/presentation/pantallas/pospartido_pantalla.dart';
import 'package:dinastia_nba/presentation/partido/repeticion.dart';
import 'package:dinastia_nba/presentation/partido/sonido_partido.dart';
import 'package:dinastia_nba/presentation/partido/voz_relator.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(2));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final temporada = liga.iniciar(Temporada(id: 'v', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  final partido = liga.proximoDelUsuario(temporada)!;
  final usuarioLocal = partido.localId == 'CHI';

  setUpAll(() {
    SonidoPartido.habilitado = false;
    VozRelator.habilitado = false;
    JugadorAvatar.usarRed = false;
  });

  test('jugada clave: el triple pedido es un triple de tu mejor tirador', () {
    var triples = 0, pedidas = 0;
    for (var semilla = 0; semilla < 40; semilla++) {
      final m = liga.motor(temporada, partido, azar: Random(semilla));
      while (!m.terminado && pedidas < 1000) {
        if (m.ataqueDelUsuario) m.pedirJugada(JugadaClave.triple);
        final e = m.siguiente();
        if (e.jugadaClave == JugadaClave.triple) {
          pedidas++;
          if (e.triple) triples++;
        }
      }
    }
    expect(pedidas, greaterThan(100));
    expect(triples / pedidas, greaterThan(0.95));
  });

  test('faltas personales, sexta falta afuera, volcadas y alley-oops en muchos partidos', () {
    var volcadas = 0, alleys = 0, expulsiones = 0, cambiosPorExpulsion = 0;
    for (var semilla = 0; semilla < 60; semilla++) {
      final m = liga.motor(temporada, partido, azar: Random(100 + semilla));
      String? afuera;
      while (!m.terminado) {
        final e = m.siguiente();
        if (e.volcada) volcadas++;
        if (e.alleyOop) {
          alleys++;
          expect(e.asistenteId, isNotNull);
        }
        if (e.expulsadoId != null) {
          expulsiones++;
          afuera = e.expulsadoId;
        }
        if (e.tipo == TipoEvento.cambio && e.saleId == afuera && afuera != null) cambiosPorExpulsion++;
        if (afuera != null && e.tipo == TipoEvento.cambio) {
          expect(e.entraId, isNot(afuera), reason: 'el expulsado no vuelve');
        }
      }
      for (final l in [...m.boxLocal.values, ...m.boxVisitante.values]) {
        expect(l.fal, lessThanOrEqualTo(6));
      }
    }
    expect(volcadas, greaterThan(100));
    expect(alleys, greaterThan(10));
    expect(cambiosPorExpulsion, lessThanOrEqualTo(expulsiones));
  });

  test('cambio a mano: sale en la próxima jugada y entra el Sexto Hombre', () {
    final m = liga.motor(temporada, partido, azar: Random(7));
    m.rotacionAutomatica(usuarioLocal, false);
    final sexto = m.enBanco(usuarioLocal)!;
    final titular = m.enCancha(usuarioLocal).first;
    expect(m.cambiar(usuarioLocal, titular.id), isTrue);
    expect(m.cambioPendiente(usuarioLocal), titular.id);
    final e = m.siguiente();
    expect((e.tipo, e.saleId, e.entraId), (TipoEvento.cambio, titular.id, sexto.id));
    expect(m.enBanco(usuarioLocal), titular);
    // Sin rotación automática, nadie entra ni sale solo (salvo expulsiones).
    var automaticos = 0;
    while (!m.terminado) {
      final x = m.siguiente();
      if (x.tipo == TipoEvento.cambio && x.local == usuarioLocal && !x.texto.contains('Sexta falta')) automaticos++;
    }
    expect(automaticos, 0);
  });

  test('relator: una frase para cada jugada, con más emoción en volcadas y triples', () {
    final m = liga.motor(temporada, partido, azar: Random(9));
    final relator = Relator(azar: Random(1));
    final jugadores = <String, Jugador>{
      for (final local in [true, false])
        for (final j in [...m.enCancha(local), ?m.enBanco(local)]) j.id: j,
    };
    while (!m.terminado) {
      final e = m.siguiente();
      final f = relator.frase(e, jugadores);
      expect(f.trim(), isNotEmpty);
      if (e.tipo == TipoEvento.tiro && (e.volcada || (e.triple && e.convertido))) expect(f, contains('!'));
    }
  });

  testWidgets('en el final apretado aparece la jugada clave y el partido sigue al elegir', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final m = liga.motor(temporada, partido, azar: Random(3))
      ..cuarto = 4
      ..reloj = 240;
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PartidoPantalla(
          motor: m,
          usuarioLocal: usuarioLocal,
          franquiciaUsuario: franquiciaPorId('CHI'),
          identidadLocal: franquiciaPorId(usuarioLocal ? 'CHI' : temporada.rivales[partido.localId]!.identidadId),
          identidadVisitante: franquiciaPorId(
            usuarioLocal ? temporada.rivales[partido.visitanteId]!.identidadId : 'CHI',
          ),
          onTerminado: (_) {},
        ),
      ),
    );
    for (var i = 0; i < 60 && find.text('JUGADA CLAVE').evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('JUGADA CLAVE'), findsOneWidget);
    await t.tap(find.text('TRIPLE'));
    await t.pump();
    expect(find.text('JUGADA CLAVE'), findsNothing);
    await t.tap(find.byTooltip('Pausa'));
    await t.pump();
  });

  testWidgets('pospartido: jugador del partido, box score y repetición', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final m = liga.motor(temporada, partido, azar: Random(4))..simularTodo();
    final jugadores = <String, Jugador>{
      for (final local in [true, false])
        for (final j in [...m.enCancha(local), ?m.enBanco(local)]) j.id: j,
    };
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PospartidoPantalla(
          motor: m,
          usuarioLocal: usuarioLocal,
          identidadLocal: franquiciaPorId('CHI'),
          identidadVisitante: franquiciaPorId('BOS'),
          franquiciaUsuario: franquiciaPorId('CHI'),
          jugadores: jugadores,
          destacadas: const [],
          equipaciones: const Equipaciones(
            propio: Colors.red,
            textoPropio: Colors.white,
            ribetePropio: Colors.black,
            rival: Colors.green,
            textoRival: Colors.white,
            ribeteRival: Colors.white,
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('JUGADOR DEL PARTIDO'), findsOneWidget);
    expect(find.text('PTS'), findsWidgets);
  });

  testWidgets('saltar al último cuarto juega al instante y sigue en vivo', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final m = liga.motor(temporada, partido, azar: Random(8));
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PartidoPantalla(
          motor: m,
          usuarioLocal: usuarioLocal,
          franquiciaUsuario: franquiciaPorId('CHI'),
          identidadLocal: franquiciaPorId('CHI'),
          identidadVisitante: franquiciaPorId('BOS'),
          onTerminado: (_) {},
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byTooltip('Saltar a lo importante'));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Saltar al último cuarto'));
    await t.pump();
    expect(m.cuarto, greaterThanOrEqualTo(4));
    expect(find.text('Q4'), findsOneWidget);
    expect(m.puntosLocal + m.puntosVisitante, greaterThan(100));
    await t.tap(find.byTooltip('Pausa'));
    await t.pump();
  });
}
