import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/epocas.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart' show RivalEscalera;
import 'package:dinastia_nba/presentation/modos/epocas.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(4));
  final modos = ModosEpocas(liga, azar: Random(4));

  Set<String> personas(RivalEscalera r) => {for (final id in r.cartaIds.values) liga.jugador(id)!.idBbref};
  List<String> nombres(RivalEscalera r) => [for (final id in r.cartaIds.values) liga.jugador(id)!.nombre];

  test('draft, universidad y nacimiento vienen en el catálogo y sobreviven al JSON', () {
    final jordan = catalogo.firstWhere((j) => j.id == 'jordami01-CHI-90');
    expect(jordan.draft, (1984, 3));
    expect(jordan.universidad, 'North Carolina');
    expect(jordan.nacimiento, 1963);
    final copia = Jugador.fromJson(jsonDecode(jsonEncode(jordan.toJson())) as Map<String, dynamic>);
    expect((copia.draft, copia.universidad, copia.nacimiento), (jordan.draft, jordan.universidad, jordan.nacimiento));
    expect(jordan.conMedia(90).draft, (1984, 3));
    final dirk = catalogo.firstWhere((j) => j.idBbref == 'nowitdi01');
    expect(dirk.universidad, isNull, reason: 'llegó del exterior');
    expect(catalogo.where((j) => j.nacimiento != null).length, catalogo.length);
  });

  test('camada 1984: Jordan, Olajuwon, Barkley y Stockton; nadie repetido en ningún equipo', () {
    final camadas = modos.equiposCamadas();
    expect(camadas, hasLength(8));
    final c84 = camadas.firstWhere((e) => e.clave == '1984');
    expect(nombres(c84.equipo), containsAll(['Michael Jordan', 'Hakeem Olajuwon', 'Charles Barkley', 'John Stockton']));
    for (final e in camadas) {
      expect(personas(e.equipo), hasLength(6), reason: e.nombre);
    }
    for (var i = 0; i + 1 < camadas.length; i++) {
      expect(camadas[i].equipo.media, greaterThanOrEqualTo(camadas[i + 1].equipo.media));
    }
  });

  test('universidades: 16 equipos con Duke, North Carolina (Jordan) y los que llegaron sin universidad', () {
    final unis = modos.equiposUniversidades();
    expect(unis, hasLength(16));
    final duke = unis.firstWhere((e) => e.clave == 'Duke');
    final pool = ModosEpocas.mejorCartaPorPersona(catalogo.where((j) => j.universidad == 'Duke'));
    expect(pool.map((j) => j.nombre), containsAll(['Grant Hill', 'Kyrie Irving']));
    expect(personas(duke.equipo), hasLength(6));
    final unc = unis.firstWhere((e) => e.clave == 'North Carolina');
    expect(unc.nombre, 'North Carolina');
    expect(nombres(unc.equipo), contains('Michael Jordan'));
    final sin = unis.firstWhere((e) => e.clave == '');
    expect(nombres(sin.equipo), anyOf(contains('LeBron James'), contains('Kobe Bryant'), contains('Nikola Jokić')));
    for (final e in unis) {
      expect(personas(e.equipo), hasLength(6), reason: e.nombre);
    }
  });

  test('guantelete: mini-draft de los 40/50, cruce con el campeón de los 50, recluta y avanza', () {
    var t = modos.nuevoGuantelete(id: 'g1', franquiciaId: 'BOS', dificultad: Dificultad.normal);
    expect(EstadoEpocas.de(t).enDraft, isTrue);
    for (var i = 0; i < 6; i++) {
      final e = EstadoEpocas.de(t);
      expect(e.ofertas, hasLength(ModosEpocas.cartasPorOferta));
      for (final id in e.ofertas) {
        final j = liga.jugador(id)!;
        expect([Epoca.anios40, Epoca.anios50], contains(j.epoca));
        expect(j.puedeJugarEn(e.puestoDraft!), isTrue);
      }
      expect(modos.ofertaDraft(t, e.puestoDraft!, e.elegidas), e.ofertas, reason: 'fijas para la partida');
      t = modos.elegirDraft(t, e.ofertas.first);
    }
    var e = EstadoEpocas.de(t);
    expect(e.enDraft, isFalse);
    expect(t.plantel.completo, isTrue);
    expect(e.cruce!.rival.etiqueta, '(50’)');
    expect(personas(e.propio!).intersection(personas(e.cruce!.rival)), isEmpty);
    // Forzamos la victoria de la década (2-0) para probar el recluta.
    final ganado = e.cruce!.conResultado(100, 90).conResultado(101, 95);
    t = e.copyWith(cruce: ganado, historial: [ganado], reclutando: true).en(t);
    final opciones = modos.reclutables(t);
    expect(opciones, isNotEmpty);
    final recluta = opciones.first;
    final puesto = ModosEpocas.puestosPara(recluta).first;
    t = modos.reclutar(t, cartaId: recluta.id, p: puesto);
    e = EstadoEpocas.de(t);
    expect(e.etapa, 1);
    expect(e.reclutando, isFalse);
    expect(e.propio!.cartaIds[puesto], recluta.id);
    expect(t.plantel.en(puesto)!.id, recluta.id);
    expect(e.cruce!.rival.etiqueta, '(60’)');
    expect(personas(e.propio!).intersection(personas(e.cruce!.rival)), isEmpty);
    // Seguir sin reclutar también avanza.
    final ganado2 = e.cruce!.conResultado(100, 90).conResultado(101, 95);
    t = e.copyWith(cruce: ganado2, historial: [...e.historial, ganado2], reclutando: true).en(t);
    t = modos.reclutar(t);
    expect(EstadoEpocas.de(t).etapa, 2);
  });

  test('cuadro de camadas: se juega hasta el campeón y guarda logros y premios', () {
    final camadas = modos.equiposCamadas();
    var t = modos.nuevoCuadro(
      id: 'c1',
      modo: ModoJuego.camadas,
      equipos: camadas,
      elegido: 0,
      dificultad: Dificultad.normal,
    );
    final inicio = t;
    expect(EstadoEpocas.de(t).pendiente!.titulo, 'Cuartos de final');
    for (var guarda = 0; guarda < 20 && !EstadoEpocas.de(t).terminado; guarda++) {
      t = modos.simularCruce(t);
    }
    final e = EstadoEpocas.de(t);
    expect(e.terminado, isTrue);
    expect(e.campeonCuadro, isNotNull);
    expect(e.ganadores.last, hasLength(1));
    expect(e.ganadores.expand((r) => r).every((g) => g >= 0), isTrue);
    final (ganados, perdidos, completo) = progresoEpocas(inicio, t);
    expect(ganados + perdidos, e.todosLosMarcadores.length);
    expect(completo, e.campeon);
    expect(logrosDeEpocas(inicio, t), e.campeon ? [isNotNull] : isEmpty);
  });

  test('JSON: la partida se guarda y se recupera igual', () {
    final unis = modos.equiposUniversidades();
    final t = modos.nuevoCuadro(
      id: 'u1',
      modo: ModoJuego.universidades,
      equipos: unis,
      elegido: 3,
      dificultad: Dificultad.dificil,
    );
    final copia = Temporada.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(EstadoEpocas.de(copia).toJson()), jsonEncode(EstadoEpocas.de(t).toJson()));
    expect(copia.modoJuego, ModoJuego.universidades);
    final g = modos.nuevoGuantelete(id: 'g2', franquiciaId: 'LAL', dificultad: Dificultad.normal);
    final g2 = Temporada.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(EstadoEpocas.de(g2).ofertas, EstadoEpocas.de(g).ofertas);
  });

  testWidgets('pantalla: mini-draft y después el cruce', (tester) async {
    tester.view.physicalSize = const Size(412, 1400) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    var t = modos.nuevoGuantelete(id: 'g3', franquiciaId: 'BOS', dificultad: Dificultad.normal);
    Widget app(Temporada x) => MaterialApp(
      theme: temaFranquicia(franquiciaPorId('BOS')),
      home: EpocasPantalla(temporada: x, liga: liga, onCambio: (n) => t = n),
    );
    await tester.pumpWidget(app(t));
    expect(find.textContaining('ELEGÍ TU BASE'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Elegir a ')).first);
    await tester.pump();
    expect(EstadoEpocas.de(t).elegidas, hasLength(1));
    while (EstadoEpocas.de(t).enDraft) {
      t = modos.elegirDraft(t, EstadoEpocas.de(t).ofertas.first);
    }
    await tester.pumpWidget(app(t));
    await tester.pump();
    expect(find.text('JUGAR EN VIVO'), findsOneWidget);
    expect(find.text('EL CAMINO'), findsOneWidget);
  });
}
