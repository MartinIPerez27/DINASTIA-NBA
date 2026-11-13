import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/domain/variantes.dart';
import 'package:dinastia_nba/presentation/modos/variantes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  double media(Plantel p) => p.jugadores.fold(0, (a, j) => a + j.media) / p.jugadores.length;

  test('Solo entrenador: plantel completo al azar, a la altura de cada dificultad', () {
    for (final d in Dificultad.values) {
      final v = Variantes(catalogo, azar: Random(d.index));
      final p = v.alAzar(d);
      expect(p.completo, isTrue);
      expect(media(p), closeTo(Variantes.objetivo(d), 3), reason: d.name);
    }
    expect(
      Variantes(catalogo, azar: Random(1)).alAzar(Dificultad.normal).jugadores.map((j) => j.id),
      isNot(Variantes(catalogo, azar: Random(2)).alAzar(Dificultad.normal).jugadores.map((j) => j.id)),
      reason: 'cada partida, otro plantel',
    );
  });

  test('Leyenda única: 6 figuras (2 S+ y 4 S) y la elegida es titular', () {
    final v = Variantes(catalogo, azar: Random(3));
    final opciones = v.leyendasParaElegir();
    expect(opciones, hasLength(6));
    expect(opciones.where((j) => j.tier == Tier.sPlus), hasLength(2));
    expect(opciones.where((j) => j.tier == Tier.s), hasLength(4));
    expect({for (final j in opciones) j.nbaPlayerId}, hasLength(6));
    final p = v.conLeyenda(opciones.first, Dificultad.normal);
    expect(p.completo, isTrue);
    expect(p.titulares, contains(opciones.first));
    // El resto, cerca del objetivo (un escalón abajo): la leyenda no viene con más leyendas.
    final resto = p.jugadores.where((j) => j != opciones.first);
    expect(resto.fold(0, (a, j) => a + j.media) / 5, closeTo(Variantes.objetivo(Dificultad.normal) - 2, 3));
  });

  group('Modo espejo', () {
    final liga = Liga(catalogo, franquicias, azar: Random(5));
    final draft = Draft(catalogo, azar: Random(6));
    var t = const Temporada(id: 'e', franquiciaUsuarioId: 'BOS', modoJuego: ModoJuego.espejo);
    var pasadas = <String>[];
    while (!t.plantel.completo) {
      final tirada = draft.tirar(t);
      final j = draft.candidatos(tirada).first;
      final elegida = draft.elegir(tirada, j, tirada.plantel.posicionesDisponiblesPara(j).first);
      pasadas = Variantes.registrarPasadas(draft, tirada, elegida, pasadas);
      t = elegida;
    }
    t = t.copyWith(datosModo: {Variantes.clavePasadas: pasadas});

    test('anota lo que dejaste pasar y la IA arma su plantel con eso', () {
      expect(pasadas, isNotEmpty);
      final propios = {for (final j in t.plantel.jugadores) j.id};
      expect(pasadas.toSet().intersection(propios), isEmpty);
      final espejada = Variantes(catalogo, azar: Random(7)).espejar(t);
      expect(espejada.plantel.completo, isTrue);
      expect(espejada.plantel.jugadores.any((j) => t.plantel.contiene(j)), isFalse, reason: 'nadie en los dos');
      expect(Variantes(catalogo).plantelTuyo(espejada)!.jugadores.map((j) => j.id).toSet(), propios);
      expect(Variantes(catalogo).espejar(espejada), same(espejada), reason: 'no se espeja dos veces');
    });

    test('tu plantel del draft es un rival de tu conferencia (y no aparece en otro)', () {
      final espejada = Variantes(catalogo, azar: Random(7)).espejar(t).copyWith(tacticaConfirmada: true);
      final lista = Variantes(catalogo, azar: Random(8)).iniciar(liga, espejada);
      final rivalId = lista.datosModo[Variantes.claveRivalEspejo] as String;
      expect(franquiciaPorId(rivalId).conferencia, franquiciaPorId('BOS').conferencia);
      expect(lista.rivales[rivalId]!.cartaIds.values.toSet(), {for (final j in t.plantel.jugadores) j.id});
      final personas = {for (final j in t.plantel.jugadores) j.nbaPlayerId};
      for (final r in lista.rivales.entries.where((e) => e.key != rivalId)) {
        for (final id in r.value.cartaIds.values) {
          expect(personas.contains(liga.jugador(id)!.nbaPlayerId), isFalse, reason: '${r.key}: $id');
        }
      }
      expect(lista.calendario, hasLength(1230));
      final copia = Temporada.fromJson(lista.toJson());
      expect(copia.modoJuego, ModoJuego.espejo);
      expect(copia.datosModo[Variantes.claveRivalEspejo], rivalId);
    });
  });

  test('Desafío del día: misma fecha, mismo draft, misma franquicia y mismos rivales', () {
    final dia = DateTime(2026, 11, 13);
    expect(Variantes.semilla(dia), 20261113);
    expect(Variantes.idDelDia(dia), 'dia-20261113');
    expect(Variantes.franquiciaDelDia(dia, franquicias), Variantes.franquiciaDelDia(dia, franquicias));
    var t = Temporada(
      id: Variantes.idDelDia(dia),
      franquiciaUsuarioId: Variantes.franquiciaDelDia(dia, franquicias).id,
      modoJuego: ModoJuego.desafioDelDia,
      datosModo: const {'semilla': 20261113},
    );
    final a = Draft(catalogo, azar: Variantes.azarDraftDelDia(t)).tirar(t).tirada!;
    final b = Draft(catalogo, azar: Variantes.azarDraftDelDia(t)).tirar(t).tirada!;
    expect((a.franquiciaId, a.epoca, a.tier), (b.franquiciaId, b.epoca, b.tier));
    // Dos ligas con azar distinto arman los mismos rivales y calendario con la semilla del día.
    t = t.copyWith(plantel: Variantes(catalogo, azar: Random(1)).alAzar(Dificultad.normal), tacticaConfirmada: true);
    final x = Variantes(catalogo).iniciar(Liga(catalogo, franquicias, azar: Random(1)), t);
    final y = Variantes(catalogo).iniciar(Liga(catalogo, franquicias, azar: Random(99)), t);
    expect(x.rivales.map((k, r) => MapEntry(k, r.cartaIds)), y.rivales.map((k, r) => MapEntry(k, r.cartaIds)));
    expect([for (final p in x.calendario) p.id], [for (final p in y.calendario) p.id]);
  });

  test('Extremo: más lesiones, y quedar afuera es perder la partida', () {
    int lesiones(ModoJuego modo) {
      final liga = Liga(catalogo, franquicias, azar: Random(21));
      var t = liga.iniciar(
        Temporada(
          id: 'x',
          franquiciaUsuarioId: 'CHI',
          plantel: Variantes(catalogo, azar: Random(4)).alAzar(Dificultad.normal),
          tacticaConfirmada: true,
          modoJuego: modo,
        ),
      );
      var total = 0;
      for (var k = 0; k < 30; k++) {
        final antes = t.lesiones;
        t = liga.simularProximo(t);
        total += t.lesiones.keys.where((id) => !antes.containsKey(id)).length;
      }
      return total;
    }

    final normal = lesiones(ModoJuego.clasico), extremo = lesiones(ModoJuego.extremo);
    expect(extremo, greaterThan(normal), reason: 'clásico $normal · extremo $extremo');

    const base = Temporada(id: 'x', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.extremo);
    expect(Variantes.extremoPerdido(base), isFalse);
    final eliminado = base.copyWith(
      series: const [SeriePlayoff(ronda: RondaPlayoff.primeraRonda, altoId: 'BOS', bajoId: 'CHI', victoriasAlto: 4)],
    );
    expect(Variantes.extremoPerdido(eliminado), isTrue);
    final sinLugar = base.copyWith(
      series: const [SeriePlayoff(ronda: RondaPlayoff.primeraRonda, altoId: 'BOS', bajoId: 'MIA')],
    );
    expect(Variantes.extremoPerdido(sinLugar), isTrue);
    expect(Variantes.extremoPerdido(eliminado.copyWith()), isTrue);
  });

  test('metajuego: logros de campeón por variante, bonus Extremo y marca del Desafío del día', () {
    const finales = SeriePlayoff(ronda: RondaPlayoff.finalesNba, altoId: 'CHI', bajoId: 'LAL', victoriasAlto: 4);
    const antes = Temporada(id: 'x', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.extremo);
    final despues = antes.copyWith(series: const [finales]);
    expect(logrosDeVariante(antes, despues), [Logro.campeonExtremo]);
    expect(logrosDeVariante(despues, despues), isEmpty, reason: 'una sola vez');
    final novedades = <Novedad>[];
    final p = premiarVariante(const PerfilEntrenador(), antes, despues, novedades);
    expect((p.xp, p.monedas), (1000, 400));
    expect(novedades, hasLength(1));

    const dia = Temporada(
      id: 'dia-20261113',
      franquiciaUsuarioId: 'CHI',
      modoJuego: ModoJuego.desafioDelDia,
      datosModo: {'semilla': 20261113},
    );
    final perfil = premiarVariante(const PerfilEntrenador(desafiosDelDia: {'20261113': 0}), dia, dia, []);
    expect(perfil.desafiosDelDia['20261113'], 0);
    final copia = PerfilEntrenador.fromJson(const PerfilEntrenador(desafiosDelDia: {'20261112': 57}).toJson());
    expect(copia.desafiosDelDia, {'20261112': 57});
  });

  testWidgets('pantallas: presentación, elegir leyenda y el cambio del espejo', (tester) async {
    tester.view.physicalSize = const Size(412, 900) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final opciones = Variantes(catalogo, azar: Random(3)).leyendasParaElegir();
    Jugador? elegida;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectorLeyenda(opciones: opciones, onElegir: (j) => elegida = j),
        ),
      ),
    );
    await tester.tap(find.text(opciones.first.nombre.toUpperCase()).first);
    expect(elegida, opciones.first);

    var confirmado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntroVariante(
            modo: ModoJuego.desafioDelDia,
            puntos: const ['Uno', 'Dos'],
            boton: 'JUGAR',
            extra: DesafioDelDiaEncabezado(fecha: DateTime(2026, 11, 13), desafios: const {'20261112': 57}),
            onConfirmar: () => confirmado = true,
          ),
        ),
      ),
    );
    expect(find.text('13/11/2026'), findsOneWidget);
    expect(find.text('57 V'), findsOneWidget);
    await tester.tap(find.text('JUGAR'));
    expect(confirmado, isTrue);

    final v = Variantes(catalogo, azar: Random(9));
    var seguir = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EspejoRevelado(
          tuyo: v.alAzar(Dificultad.normal),
          ia: v.alAzar(Dificultad.normal),
          onSeguir: () => seguir = true,
        ),
      ),
    );
    expect(find.text('LO DIRIGÍS VOS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ELEGIR TÁCTICAS'), 200);
    await tester.tap(find.text('ELEGIR TÁCTICAS'));
    expect(seguir, isTrue);
    expect(tester.takeException(), isNull);
  });
}
