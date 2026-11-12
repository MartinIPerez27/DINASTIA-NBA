import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/copa.dart';
import 'package:dinastia_nba/domain/entities/franquicia.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/presentation/temporada/copa.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(31));
  final copa = CopaNba(liga);
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final inicio = liga.iniciar(Temporada(id: 'copa', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));

  /// Juega la temporada regular hasta que el próximo partido del usuario sea de la jornada [j].
  Temporada hasta(Temporada t, int j) {
    var x = t;
    while (liga.proximoDelUsuario(x) != null && liga.proximoDelUsuario(x)!.jornada < j) {
      x = liga.simularProximo(x);
    }
    return x;
  }

  final antesDeLaCopa = hasta(inicio, copa.jornadaCopa(inicio) - 1);
  final enLaCopa = hasta(antesDeLaCopa, copa.jornadaCopa(inicio));

  test('no arranca antes de su jornada', () {
    expect(copa.alDia(antesDeLaCopa).copa, isEmpty);
    expect(copa.alDia(inicio).copa, isEmpty);
  });

  test('cuartos con los 4 mejores de cada conferencia, a partido único, sin tocar el récord', () {
    final t = copa.alDia(enLaCopa);
    final cuartos = t.copa.where((s) => s.ronda == RondaPlayoff.copaCuartos).toList();
    expect(cuartos, hasLength(4));
    for (final (k, conf) in [Conferencia.este, Conferencia.oeste].indexed) {
      final tabla = enLaCopa.standings(conf, franquicias);
      expect((cuartos[k * 2].altoId, cuartos[k * 2].bajoId), (tabla[0].franquiciaId, tabla[3].franquiciaId));
      expect((cuartos[k * 2 + 1].altoId, cuartos[k * 2 + 1].bajoId), (tabla[1].franquiciaId, tabla[2].franquiciaId));
    }
    for (final s in t.copa) {
      expect(s.victoriasAlto + s.victoriasBajo, lessThanOrEqualTo(1), reason: 'partido único');
    }
    // Aislada de la temporada regular.
    expect(t.registroUsuario.jugados, enLaCopa.registroUsuario.jugados);
    expect([for (final x in t.calendario) x.jugado], [for (final x in enLaCopa.calendario) x.jugado]);
    expect(t.lineas.length, enLaCopa.lineas.length);
    // Si el usuario clasificó, su partido espera; el resto de su ronda ya se jugó.
    final pendiente = copa.pendienteDelUsuario(t);
    if (pendiente != null) {
      expect(t.copa.where((s) => s.ronda == pendiente.ronda && s != pendiente).every((s) => s.terminada), isTrue);
    } else {
      expect(copa.campeon(t), isNotNull, reason: 'sin el usuario, la Copa se juega entera');
    }
  });

  test('jugando cada partido del usuario la Copa llega al campeón (Este vs Oeste) y se guarda', () {
    var t = copa.alDia(enLaCopa);
    for (var i = 0; i < 5 && copa.campeon(t) == null; i++) {
      final s = copa.pendienteDelUsuario(t);
      if (s == null) break;
      t = copa.registrar(t, s, copa.motor(t, s)..simularTodo());
    }
    if (copa.campeon(t) == null) t = copa.alDia(hasta(t, copa.jornadaCopa(t) + CopaNba.gracia));
    expect(copa.campeon(t), isNotNull);
    expect(t.copa, hasLength(7));
    final finalCopa = t.copa.last;
    expect(finalCopa.ronda, RondaPlayoff.copaFinal);
    expect(
      {franquiciaPorId(finalCopa.altoId).conferencia, franquiciaPorId(finalCopa.bajoId).conferencia},
      {Conferencia.este, Conferencia.oeste},
    );
    final copia = Temporada.fromJson(t.toJson());
    expect(copa.campeon(copia), copa.campeon(t));
    expect(copia.copa.length, 7);
  });

  test('si el usuario deja pasar su partido, a las 4 jornadas se simula solo', () {
    final t = copa.alDia(enLaCopa);
    final pendiente = copa.pendienteDelUsuario(t);
    if (pendiente == null) return; // no clasificó con esta semilla
    final despues = copa.alDia(hasta(t, copa.jornadaCopa(t) + CopaNba.gracia));
    expect(copa.campeon(despues), isNotNull);
    expect(copa.pendienteDelUsuario(despues), isNull);
  });

  test('ganar la final da el trofeo y el logro, una sola vez', () {
    final finalGanada = SeriePlayoff(ronda: RondaPlayoff.copaFinal, altoId: 'CHI', bajoId: 'LAL', victoriasAlto: 1);
    final con = enLaCopa.copyWith(copa: [finalGanada]);
    final progreso = Progreso(liga);
    final (perfil, novedades) = progreso.aplicar(const PerfilEntrenador(), enLaCopa, con);
    expect(perfil.trofeos.map((t) => t.tipo), contains(TipoTrofeo.copa));
    expect(perfil.logros.keys, contains(Logro.copaNba));
    expect(novedades.any((n) => n.titulo.contains('Copa NBA')), isTrue);
    final (otraVez, _) = progreso.aplicar(perfil, con, con);
    expect(otraVez.trofeos.where((t) => t.tipo == TipoTrofeo.copa), hasLength(1));
    expect(PerfilEntrenador.fromJson(perfil.toJson()).trofeos.last.tipo, TipoTrofeo.copa);
  });

  testWidgets('tarjeta: oculta antes de la Copa; con partido pendiente, simular lo registra', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    Temporada? guardada;
    Widget app(Temporada t) => MaterialApp(
      theme: temaFranquicia(franquiciaPorId('CHI')),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TarjetaCopa(
            temporada: t,
            liga: liga,
            onCambio: (x) => guardada = x,
            franquiciaUsuario: franquiciaPorId('CHI'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(antesDeLaCopa));
    expect(find.text('COPA NBA'), findsNothing);

    final t = copa.alDia(enLaCopa);
    await tester.pumpWidget(app(t));
    expect(find.text('COPA NBA'), findsOneWidget);
    expect(find.text('CUARTOS'), findsOneWidget);
    final pendiente = copa.pendienteDelUsuario(t);
    if (pendiente == null) return;
    expect(find.text('JUGAR EN VIVO'), findsOneWidget);
    await tester.tap(find.text('SIMULAR'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(guardada, isNotNull);
    expect(
      guardada!.copa.firstWhere((s) => s.ronda == pendiente.ronda && s.altoId == pendiente.altoId).terminada,
      isTrue,
    );
  });
}
