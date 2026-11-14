import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/data/historia_nba.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/rival.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/historia.dart';
import 'package:dinastia_nba/presentation/modos/historia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(4));
  final huecos = HistoriaNba.leerHuecos(
    jsonDecode(File('assets/database/temporadas_huecos.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final h = HistoriaNba(liga, huecos: huecos);
  Set<String> nombres(PlantelReal r) => {for (final j in r.todos) j.nombre};

  test('plantel real: los Bulls del 96 tienen a Jordan, Pippen y Rodman', () {
    final r = h.plantelReal('CHI', 1996)!;
    expect(r.plantel.completo, isTrue);
    expect(nombres(r), containsAll(['Michael Jordan', 'Scottie Pippen', 'Dennis Rodman']));
    expect(r.aproximado, isFalse);
    expect(r.identidadId, 'CHI');
    expect(r.suplentes, hasLength(Temporada.maxSuplentes));
    expect(r.todos.map((j) => j.nbaPlayerId).toSet(), hasLength(r.todos.length), reason: 'sin personas repetidas');
  });

  test('los tramos con huecos se respetan: LeBron no está en Cleveland en 2011, sí en Miami', () {
    expect(nombres(h.plantelReal('CLE', 2011)!), isNot(contains('LeBron James')));
    expect(nombres(h.plantelReal('MIA', 2011)!), contains('LeBron James'));
    expect(nombres(h.plantelReal('CLE', 2016)!), contains('LeBron James'));
    // Identidad de época: Oklahoma City en 1996 eran los SuperSonics.
    expect(h.plantelReal('OKC', 1996)!.identidadId, 'SEA');
  });

  test('todas las franquicias tienen plantel en cada temporada jugable', () {
    for (final anio in [HistoriaNba.primerAnio, 1985, 1996, 2005, 2016, HistoriaNba.ultimoAnio]) {
      for (final f in franquicias) {
        final r = h.plantelReal(f.id, anio);
        expect(r, isNotNull, reason: '${f.id} $anio');
        // Toronto no existía en 1985: plantel de su época más cercana.
        if (registrosReales[anio]![f.id] == null) expect(r!.aproximado, isTrue);
      }
    }
    expect(HistoriaNba.resultadoReal('CHI', 1996), '72-10 y campeones');
    expect(HistoriaNba.resultadoReal('TOR', 1985), isNull);
  });

  test('historias alternativas: solo cartas que existen, y el forzado está en el plantel', () {
    for (final q in historiasAlternativas) {
      final forzados = h.forzadosDe(q);
      expect(forzados, hasLength(q.agregar.length), reason: q.id);
      final t = h.nuevaTemporada(id: q.id, franquiciaId: q.franquiciaId, anio: q.anio, historia: q);
      expect(t.plantel.completo, isTrue, reason: q.id);
      for (final f in forzados) {
        expect(t.plantel.contiene(f), isTrue, reason: '${q.id}: ${f.nombre}');
      }
      expect(t.modoJuego, ModoJuego.queHubiera);
      expect(HistoriaNba.historiaDe(Temporada.fromJson(t.toJson()))?.id, q.id);
    }
  });

  test('temporada real: rivales con su plantel real de ese año, sin personas repetidas, y JSON', () {
    final t = h.nuevaTemporada(id: 'r96', franquiciaId: 'SAC', anio: 1996).copyWith(tacticaConfirmada: true);
    final lista = h.iniciarLiga(t);
    expect(lista.calendario, hasLength(1230));
    expect(lista.rivales, hasLength(29));
    final chi = liga.plantelDe(lista.rivales['CHI']!);
    expect({for (final j in chi.jugadores) j.nombre}, contains('Michael Jordan'));
    expect(lista.rivales['OKC']!.identidadId, 'SEA');
    expect(lista.rivales.values.every((r) => r.tipo == TipoRival.epoca), isTrue);
    final personas = [
      for (final j in [...lista.plantel.jugadores, ...lista.suplentes]) j.nbaPlayerId,
      for (final r in lista.rivales.values)
        for (final id in r.cartaIds.values) liga.jugador(id)!.nbaPlayerId,
    ];
    expect(personas.toSet(), hasLength(personas.length));
    final copia = Temporada.fromJson(lista.toJson());
    expect(HistoriaNba.anioDe(copia), 1996);
    expect(copia.modoJuego, ModoJuego.temporadaReal);
    expect(lista.fase, FaseTemporada.temporadaRegular);
  });

  test('momentos clutch: el motor arranca con el marcador, el cuarto y el reloj reales', () {
    for (final m in momentosClutch) {
      final motor = h.motor(m);
      expect(
        (motor.puntosLocal, motor.puntosVisitante, motor.cuarto, motor.reloj),
        (m.puntosLocal, m.puntosVisitante, m.cuarto, m.reloj),
        reason: m.id,
      );
      expect(motor.parcialesLocal, hasLength(m.cuarto));
      expect(motor.faltas(true), 4);
      final primero = motor.siguiente();
      if (m.reloj > 3) expect(primero.local, m.ataqueLocal, reason: '${m.id}: arranca con la pelota quien la tenía');
      motor.simularTodo();
      expect(motor.terminado, isTrue);
      expect(motor.cuarto, greaterThanOrEqualTo(4));
    }
    // Las figuras de esos finales están en cancha.
    final (_, bulls) = h.equipos(momentosClutch.first);
    expect({for (final j in bulls.plantel.jugadores) j.nombre}, contains('Michael Jordan'));
    var t = HistoriaNba.partidaMomentos('CHI');
    t = HistoriaNba.conSuperado(HistoriaNba.conSuperado(t, 'jordan98'), 'jordan98');
    expect(HistoriaNba.superados(Temporada.fromJson(t.toJson())), {'jordan98'});
  });

  test('el arranque por defecto del motor no cambia (0-0, 1.er cuarto, 12 minutos)', () {
    final p = liga.proximoDelUsuario(
      h.iniciarLiga(h.nuevaTemporada(id: 'x', franquiciaId: 'CHI', anio: 1996).copyWith(tacticaConfirmada: true)),
    )!;
    final m = liga.motor(
      liga.iniciar(h.nuevaTemporada(id: 'y', franquiciaId: 'CHI', anio: 1996).copyWith(tacticaConfirmada: true)),
      p,
    );
    expect((m.puntosLocal, m.puntosVisitante, m.cuarto, m.reloj), (0, 0, 1, 720.0));
  });

  testWidgets('pantalla de momentos clutch: lista los finales y marca los superados', (tester) async {
    JugadorAvatar.usarRed = false;
    var t = HistoriaNba.conSuperado(HistoriaNba.partidaMomentos('CHI'), 'jordan98');
    await tester.pumpWidget(
      MaterialApp(
        home: MomentosClutchPantalla(temporada: t, historia: h, onCambio: (x) => t = x),
      ),
    );
    await tester.pump();
    expect(find.text('EL ÚLTIMO TIRO'), findsOneWidget);
    expect(find.textContaining('1 de ${momentosClutch.length}'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
