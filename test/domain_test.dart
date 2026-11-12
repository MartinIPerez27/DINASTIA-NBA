import 'dart:convert';
import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/franquicia.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/partido.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Cartas de prueba propias: el catálogo real se regenera con tools/extraer_cartas.py.
  const statsPrueba = EstadisticasJugador(
    ppp: 25,
    rpp: 6,
    app: 5,
    robP: 1,
    tapP: 1,
    pctTc: .5,
    pctT3: .35,
    pctTl: .8,
    minP: 36,
    perP: 3,
    iq: 90,
  );
  final fixtures = <String, (int, List<Posicion>)>{
    'Michael Jordan': (893, [Posicion.escolta, Posicion.alero]),
    'Kobe Bryant': (977, [Posicion.escolta, Posicion.alero]),
    "Shaquille O'Neal": (406, [Posicion.pivot]),
    'LeBron James': (2544, [Posicion.alero, Posicion.alaPivot]),
    'Magic Johnson': (77142, [Posicion.base, Posicion.alero]),
    'Larry Bird': (1449, [Posicion.alero, Posicion.alaPivot]),
    'Tim Duncan': (1495, [Posicion.alaPivot, Posicion.pivot]),
    'Nikola Jokić': (203999, [Posicion.pivot, Posicion.alaPivot]),
    'Manu Ginóbili': (1938, [Posicion.escolta, Posicion.base]),
    'Stephen Curry': (201939, [Posicion.base, Posicion.escolta]),
    'Giannis Antetokounmpo': (203507, [Posicion.alaPivot, Posicion.alero, Posicion.pivot]),
  };
  Jugador carta(String nombre, {String franquicia = 'CHI', Epoca epoca = Epoca.anios90}) {
    final (id, posiciones) = fixtures[nombre]!;
    return Jugador(
      id: '$id-$franquicia-${epoca.name}',
      nbaPlayerId: id,
      nombre: nombre,
      franquiciaId: franquicia,
      epoca: epoca,
      tier: Tier.s,
      posiciones: posiciones,
      rol: RolCancha.controladorTotal,
      dorsal: 23,
      stats: statsPrueba,
    );
  }

  group('Catálogo y franquicias', () {
    test('el catálogo empaquetado parsea y cada carta apunta a una franquicia real', () {
      final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
      expect(catalogo, isNotEmpty);
      for (final j in catalogo) {
        expect(() => franquiciaPorId(j.franquiciaId), returnsNormally, reason: j.nombre);
      }
      expect(catalogo.map((j) => j.id).toSet().length, catalogo.length, reason: 'ids únicos');
    });

    test('30 franquicias, 15 por conferencia, 5 por división', () {
      expect(franquicias.length, 30);
      expect(franquicias.map((f) => f.id).toSet().length, 30);
      expect(franquicias.where((f) => f.conferencia == Conferencia.este).length, 15);
      for (final d in Division.values) {
        expect(franquicias.where((f) => f.division == d).length, 5, reason: d.etiqueta);
      }
    });

    test('acepta las variantes de etiqueta del GDD', () {
      expect(Posicion.desdeEtiqueta('PIVOT'), Posicion.pivot);
      expect(Posicion.desdeEtiqueta('PÍVOT'), Posicion.pivot);
      expect(Posicion.desdeEtiqueta('SEXTO-HOMBRE'), Posicion.sextoHombre);
      expect(Posicion.desdeEtiqueta('ala-pívot'), Posicion.alaPivot);
      expect(() => Posicion.desdeEtiqueta('LIBERO'), throwsFormatException);
    });
  });

  group('Plantel — regla de no duplicación', () {
    test('una posición ocupada queda bloqueada', () {
      final p = const Plantel().asignar(carta('Michael Jordan'), Posicion.escolta);
      expect(p.posicionesDisponiblesPara(carta('Kobe Bryant')), [Posicion.alero, Posicion.sextoHombre]);
      expect(() => p.asignar(carta('Kobe Bryant'), Posicion.escolta), throwsA(isA<ReglaPlantelException>()));
    });

    test('solo posiciones elegibles; el Sexto Hombre acepta a cualquiera', () {
      expect(
        () => const Plantel().asignar(carta("Shaquille O'Neal"), Posicion.base),
        throwsA(isA<ReglaPlantelException>()),
      );
      final p = const Plantel().asignar(carta("Shaquille O'Neal"), Posicion.sextoHombre);
      expect(p.sextoHombre?.nombre, "Shaquille O'Neal");
    });

    test('dos cartas del mismo jugador de distinta época no conviven', () {
      final cle = carta('LeBron James', franquicia: 'CLE', epoca: Epoca.anios2010);
      final lal = carta('LeBron James', franquicia: 'LAL', epoca: Epoca.actualidad);
      expect(cle == lal, isFalse, reason: 'son cartas distintas');
      final p = const Plantel().asignar(cle, Posicion.alero);
      expect(p.posicionesDisponiblesPara(lal), isEmpty);
    });

    test('el mismo jugador no entra dos veces', () {
      final p = const Plantel().asignar(carta('LeBron James'), Posicion.alero);
      expect(p.posicionesDisponiblesPara(carta('LeBron James')), isEmpty);
      expect(() => p.asignar(carta('LeBron James'), Posicion.base), throwsA(isA<ReglaPlantelException>()));
    });

    test('se completa con 6 jugadores', () {
      final p = const Plantel()
          .asignar(carta('Magic Johnson'), Posicion.base)
          .asignar(carta('Michael Jordan'), Posicion.escolta)
          .asignar(carta('Larry Bird'), Posicion.alero)
          .asignar(carta('Tim Duncan'), Posicion.alaPivot)
          .asignar(carta('Nikola Jokić'), Posicion.pivot);
      expect(p.completo, isFalse);
      expect(p.titulares.length, 5);
      expect(p.asignar(carta('Manu Ginóbili'), Posicion.sextoHombre).completo, isTrue);
    });
  });

  group('Partido', () {
    const partido = Partido(id: 'j1', jornada: 1, localId: 'CHI', visitanteId: 'BOS');

    test('arranca 0-0 y sin ganador', () {
      expect((partido.puntosLocal, partido.puntosVisitante), (0, 0));
      expect(partido.jugado, isFalse);
      expect(partido.ganadorId, isNull);
    });

    test('resultado válido, con prórroga', () {
      final r = partido.conResultado([25, 25, 25, 25, 12], [30, 20, 25, 25, 8]);
      expect((r.puntosLocal, r.puntosVisitante), (112, 108));
      expect(r.ganadorId, 'CHI');
    });

    test('rechaza empates, menos de 4 cuartos y rejugar', () {
      expect(() => partido.conResultado([25, 25, 25, 25], [25, 25, 25, 25]), throwsArgumentError);
      expect(() => partido.conResultado([30, 30], [20, 20]), throwsArgumentError);
      final r = partido.conResultado([30, 25, 25, 25], [20, 25, 25, 25]);
      expect(() => r.conResultado([30, 25, 25, 25], [20, 25, 25, 25]), throwsStateError);
    });
  });

  group('Temporada', () {
    test('serie al mejor de 7 termina en 4 victorias, localía 2-2-1-1-1', () {
      var s = const SeriePlayoff(ronda: RondaPlayoff.finalesNba, altoId: 'CHI', bajoId: 'LAL');
      final locales = <String>[];
      for (final g in ['CHI', 'LAL', 'LAL', 'CHI', 'CHI', 'LAL', 'CHI']) {
        locales.add(s.localProximoPartido);
        s = s.registrarVictoria(g);
      }
      expect(locales, ['CHI', 'CHI', 'LAL', 'LAL', 'CHI', 'LAL', 'CHI']);
      expect(s.ganadorId, 'CHI');
      expect(() => s.registrarVictoria('CHI'), throwsStateError);
    });

    test('3 rerolls por temporada', () {
      var t = const Temporada(id: 't1', franquiciaUsuarioId: 'CHI');
      t = t.usarReroll().usarReroll().usarReroll();
      expect(t.rerollsRestantes, 0);
      expect(t.usarReroll, throwsStateError);
    });

    test('standings, fase y guardado JSON ida y vuelta', () {
      final plantel = const Plantel()
          .asignar(carta('Stephen Curry'), Posicion.base)
          .asignar(carta('Michael Jordan'), Posicion.escolta)
          .asignar(carta('LeBron James'), Posicion.alero)
          .asignar(carta('Giannis Antetokounmpo'), Posicion.alaPivot)
          .asignar(carta("Shaquille O'Neal"), Posicion.pivot)
          .asignar(carta('Manu Ginóbili'), Posicion.sextoHombre);
      final t = Temporada(
        id: 't1',
        franquiciaUsuarioId: 'CHI',
        plantel: plantel,
        tacticaConfirmada: true,
        calendario: [
          const Partido(
            id: 'p1',
            jornada: 1,
            localId: 'CHI',
            visitanteId: 'BOS',
          ).conResultado([30, 30, 30, 30], [20, 20, 20, 20]),
          const Partido(id: 'p2', jornada: 2, localId: 'MIA', visitanteId: 'CHI'),
        ],
      );
      expect(t.fase, FaseTemporada.temporadaRegular);
      expect(t.standings(Conferencia.este, franquicias).first.franquiciaId, 'CHI');
      expect(t.registroDe('BOS').derrotas, 1);

      final copia = Temporada.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(copia.toJson()), jsonEncode(t.toJson()));
      expect(copia.plantel.en(Posicion.pivot)?.nombre, "Shaquille O'Neal");
      expect(copia.fase, FaseTemporada.temporadaRegular);
    });
  });
}
