import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/album.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/tirada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/mercado.dart';
import 'package:dinastia_nba/domain/modos/amigos.dart';
import 'package:dinastia_nba/domain/modos/armado.dart';
import 'package:dinastia_nba/domain/tienda.dart';
import 'package:dinastia_nba/domain/tokens_draft.dart';
import 'package:dinastia_nba/domain/una_carta.dart';
import 'package:dinastia_nba/domain/variantes.dart';
import 'package:dinastia_nba/domain/version_catalogo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regla del dueño: UNA sola carta por persona en cada tirada, sobre, oferta o lista. Si en los 90 de los Bulls hay
/// dos Jordan (1990–93 y 1995–98), sale uno: el de mayor media de lo que cumple la tirada. Y una persona nunca
/// está dos veces en un plantel ni entre los rivales de una temporada.
void main() {
  final raw = File(rutaCatalogo).readAsStringSync();
  final catalogo = parsearCatalogo(raw);
  const base = Temporada(id: 't', franquiciaUsuarioId: 'CHI');

  String personasRepetidas(Iterable<Jugador> cartas) {
    final vistas = <String, Jugador>{};
    for (final j in cartas) {
      final previa = vistas[j.personaId];
      if (previa != null) return '${j.nombre}: ${previa.id} y ${j.id}';
      vistas[j.personaId] = j;
    }
    return '';
  }

  Jugador mejorDe(Iterable<Jugador> cartas) => cartas.reduce((a, b) => esMejorVersion(a, b) ? a : b);

  group('identidad de la persona', () {
    test('el catálogo real: el id de Basketball-Reference y la identidad de la NBA coinciden persona a persona', () {
      final porBbref = <String, Set<String>>{};
      for (final j in catalogo) {
        (porBbref[j.idBbref] ??= {}).add(j.personaId);
      }
      expect(porBbref.values.where((s) => s.length > 1), isEmpty, reason: 'una persona, una identidad');
      final porPersona = <String, Set<String>>{};
      for (final j in catalogo) {
        (porPersona[j.personaId] ??= {}).add(j.idBbref);
      }
      expect(porPersona.values.where((s) => s.length > 1), isEmpty, reason: 'dos personas con la misma identidad');
      expect(porPersona.length, greaterThan(4000));
    });

    test('un plantel no admite dos versiones de la misma persona (aunque sean de otra franquicia)', () {
      final jordan = catalogo.where((j) => j.idBbref == 'jordami01').toList();
      expect(jordan.length, greaterThan(2));
      final p = const Plantel().asignar(jordan.first, Posicion.escolta);
      for (final otra in jordan.skip(1)) {
        expect(p.contiene(otra), isTrue);
        expect(p.posicionesDisponiblesPara(otra), isEmpty);
        expect(() => p.asignar(otra, Posicion.alero), throwsA(isA<ReglaPlantelException>()));
      }
    });

    test('unaPorPersona: gana la de mayor media y, a igualdad, la más reciente; no depende del orden', () {
      final jordan = catalogo.where((j) => j.idBbref == 'jordami01' && j.franquiciaId == 'CHI').toList();
      expect(unaPorPersona(jordan), hasLength(1));
      expect(unaPorPersona(jordan.reversed).single.id, unaPorPersona(jordan).single.id);
      expect(unaPorPersona(jordan).single.id, mejorDe(jordan).id);
      final a = jordan.first;
      final empate = a.conMedia(a.media);
      expect(esMejorVersion(a, empate), isFalse, reason: 'misma carta: no es mejor que sí misma');
    });
  });

  group('ruleta: una carta por persona por tirada', () {
    test('Jordan, los 90 y Bulls: sale una sola carta, la de mayor media', () {
      final jordan = catalogo
          .where((j) => j.idBbref == 'jordami01' && j.franquiciaId == 'CHI' && j.epoca == Epoca.anios90)
          .toList();
      expect(jordan.length, greaterThanOrEqualTo(2), reason: 'el caso que motivó la regla');
      final draft = Draft(catalogo, azar: Random(1));
      final t = base.conTirada(const Tirada(franquiciaId: 'CHI', epoca: Epoca.anios90, tier: Tier.sPlus));
      final candidatos = draft.candidatos(t);
      expect(candidatos.where((j) => j.idBbref == 'jordami01'), hasLength(1));
      expect(candidatos.firstWhere((j) => j.idBbref == 'jordami01').id, mejorDe(jordan).id);
      expect(personasRepetidas(candidatos), isEmpty);
    });

    test('Curry en los 2010 de los Warriors y LeBron en los 2020 de los Lakers: una carta cada uno', () {
      final draft = Draft(catalogo, azar: Random(2));
      for (final (franquicia, epoca, bbref) in [
        ('GSW', Epoca.anios2010, 'curryst01'),
        ('LAL', Epoca.actualidad, 'jamesle01'),
      ]) {
        final cartas = catalogo.where((j) => j.idBbref == bbref && j.franquiciaId == franquicia && j.epoca == epoca);
        expect(cartas.length, greaterThanOrEqualTo(3), reason: bbref);
        final t = base.conTirada(Tirada(franquiciaId: franquicia, epoca: epoca, tier: Tier.s));
        final salen = draft.candidatos(t).where((j) => j.idBbref == bbref).toList();
        expect(salen, hasLength(1), reason: bbref);
        expect(salen.single.id, mejorDe(cartas).id);
      }
    });

    test(
      'las 1.295+ combinaciones: antes repetían personas, ahora todas las tiradas posibles traen una por persona',
      () {
        final draft = Draft(catalogo, azar: Random(3));
        final grupos = <(String, Epoca), List<Jugador>>{};
        for (final j in catalogo) {
          (grupos[(j.franquiciaId, j.epoca)] ??= []).add(j);
        }
        var conRepetidas = 0;
        for (final e in grupos.entries) {
          final (franquicia, epoca) = e.key;
          if (personasRepetidas(e.value).isNotEmpty) conRepetidas++;
          final t = base.conTirada(Tirada(franquiciaId: franquicia, epoca: epoca, tier: e.value.first.tier));
          final salen = draft.candidatos(t);
          expect(personasRepetidas(salen), isEmpty, reason: '$franquicia ${epoca.name}');
          expect(
            salen.length,
            {for (final j in e.value) j.personaId}.length,
            reason: 'una por persona, ninguna de menos',
          );
          // Cada una es la mejor de su persona dentro de esa franquicia y época.
          for (final c in salen) {
            expect(c.id, mejorDe(e.value.where((x) => x.personaId == c.personaId)).id);
          }
        }
        expect(conRepetidas, greaterThan(150), reason: 'el catálogo v3 tiene muchas franquicias+época con repetidas');
      },
    );

    test(
      'miles de tiradas con todas las reglas: nunca dos cartas de la misma persona y siempre hay una del Tier sorteado',
      () {
        final azarEsc = Random(77);
        final todas = [...catalogo]..shuffle(azarEsc);
        final album = {for (final j in todas.take(2500)) j.id};
        var tiradas = 0;
        for (final regla in [
          ReglaDraft.libre,
          ReglaDraft.unaDecada,
          ReglaDraft.franquiciaPura,
          ReglaDraft.underdog,
          ReglaDraft.coleccion,
        ]) {
          for (var seed = 0; seed < 90; seed++) {
            final azar = Random(seed * 31 + regla.index);
            final epoca = Epoca.values[azar.nextInt(Epoca.values.length)];
            final franq = franquicias[azar.nextInt(franquicias.length)].id;
            var t = Temporada(
              id: 's$seed',
              franquiciaUsuarioId: franq,
              regla: regla,
              epocaRegla: regla == ReglaDraft.unaDecada ? epoca : null,
              rerollsRestantes: 3,
            );
            final draft = Draft(catalogo, azar: azar, coleccion: album);
            while (!t.plantel.completo) {
              try {
                t = draft.tirar(t);
              } on StateError {
                break; // la regla ya no deja cartas para los puestos que faltan (p. ej. colección chica)
              }
              tiradas++;
              final ids = {for (final j in t.plantel.jugadores) j.personaId};
              // Un reroll reteniendo la rareza, de vez en cuando.
              if (azar.nextInt(3) == 0 && draft.puedeVolverATirar(t, const {Carrete.rareza})) {
                t = draft.tirar(t, retenidos: const {Carrete.rareza}, monedas: 1000);
                tiradas++;
              }
              final candidatos = draft.candidatos(t);
              final etiqueta = '${regla.name} semilla $seed ${t.tirada}';
              expect(candidatos, isNotEmpty, reason: etiqueta);
              expect(personasRepetidas(candidatos), isEmpty, reason: etiqueta);
              expect(candidatos.any((j) => ids.contains(j.personaId)), isFalse, reason: 'ya en el plantel: $etiqueta');
              expect(candidatos.every((j) => draft.permitida(t, j)), isTrue, reason: 'regla: $etiqueta');
              expect(candidatos.every((j) => t.tirada!.incluye(j)), isTrue, reason: etiqueta);
              expect(candidatos.any((j) => j.tier == t.tirada!.tier), isTrue, reason: 'rareza garantizada: $etiqueta');
              final j = candidatos[azar.nextInt(candidatos.length)];
              final puestos = draft.puestosPara(t, j);
              expect(puestos, isNotEmpty);
              t = draft.elegir(t, j, puestos[azar.nextInt(puestos.length)]);
              expect(personasRepetidas(t.plantel.jugadores), isEmpty, reason: etiqueta);
            }
          }
        }
        expect(tiradas, greaterThan(2500));
      },
    );

    test('mismo seed, misma tirada; y el azar por paso (código de reto) no depende de la lista de candidatos', () {
      List<String> jugar(int semilla, Random azarBase) {
        final draft = Draft(
          catalogo,
          azar: azarBase,
          azarPara: (t, paso) => Random(semilla * 1000003 + paso * 7919 + t.plantel.jugadores.length),
        );
        var t = base.copyWith(rerollsRestantes: 2);
        final salio = <String>[];
        while (!t.plantel.completo) {
          t = draft.tirar(t);
          final c = draft.candidatos(t);
          salio.add(
            '${t.tirada!.franquiciaId}-${t.tirada!.epoca.name}-${t.tirada!.tier.name}:${c.map((j) => j.id).join(',')}',
          );
          // Mirar los candidatos (y la ayuda de tokens) cuantas veces se quiera no mueve el sorteo.
          draft.candidatos(t);
          for (final x in c) {
            draft.mejorVersionDe(t, x);
          }
          t = draft.elegir(t, c.first, draft.puestosPara(t, c.first).first);
        }
        return salio;
      }

      // Dos dispositivos con azar base distinto: sin azarPara saldrían otras tiradas; con él, idénticas.
      expect(jugar(9, Random(1)), jugar(9, Random(2)));
      expect(jugar(9, Random(1)), isNot(jugar(10, Random(1))));
      final d1 = Draft(catalogo, azar: Random(5)), d2 = Draft(catalogo, azar: Random(5));
      expect(d1.candidatos(d1.tirar(base)).map((j) => j.id), d2.candidatos(d2.tirar(base)).map((j) => j.id));
    });

    test('la regla de tiradas entra en la versión del catálogo: un código viejo se detecta como otro catálogo', () {
      expect(reglaDeTirada, greaterThanOrEqualTo(2));
      expect(versionDe(raw) ^ reglaDeTirada, versionDe(raw) ^ reglaDeTirada);
      var h = 0x811c9dc5;
      for (final b in raw.codeUnits) {
        h = ((h ^ (b & 0xff)) * 0x01000193) & 0xffffffff;
      }
      expect(versionDe(raw), isNot(h), reason: 'ya no coincide con el hash de antes de la regla');
    });
  });

  group('tokens coherentes', () {
    test('Mejor versión: la de mayor media de ESA persona en todo el catálogo, con la regla vigente', () {
      var comprobadas = 0;
      for (final regla in [ReglaDraft.libre, ReglaDraft.unaDecada, ReglaDraft.franquiciaPura, ReglaDraft.underdog]) {
        for (var seed = 0; seed < 25; seed++) {
          final azar = Random(seed + 500);
          final epoca = Epoca.values[azar.nextInt(Epoca.values.length)];
          final franq = franquicias[azar.nextInt(franquicias.length)].id;
          final t0 = Temporada(
            id: 'mv$seed',
            franquiciaUsuarioId: franq,
            regla: regla,
            epocaRegla: regla == ReglaDraft.unaDecada ? epoca : null,
          );
          final draft = Draft(catalogo, azar: azar);
          final t = draft.tirar(t0);
          for (final j in draft.candidatos(t)) {
            final mejor = draft.mejorVersionDe(t, j);
            // Fuerza bruta: la mejor carta de esa persona que cumple la regla y entra en un puesto libre.
            final posibles = catalogo
                .where(
                  (c) =>
                      c.personaId == j.personaId &&
                      draft.permitida(t, c) &&
                      t.plantel.posicionesDisponiblesPara(c).isNotEmpty,
                )
                .toList();
            final esperada = mejorDe(posibles);
            if (esperada.media > j.media) {
              expect(mejor?.id, esperada.id, reason: '${regla.name} ${j.id}');
              expect(mejor!.personaId, j.personaId);
              expect(draft.permitida(t, mejor), isTrue, reason: 'respeta ${regla.name}');
              comprobadas++;
            } else {
              expect(mejor, isNull, reason: '${regla.name} ${j.id}: ya es la mejor que cumple la regla');
            }
          }
          // Y al aplicarla, la tirada sigue con una carta por persona y la persona no se duplica.
          final conMejora = draft.candidatos(t).where((j) => draft.mejorVersionDe(t, j) != null).toList();
          if (conMejora.isNotEmpty) {
            final j = conMejora.first;
            final nueva = draft.mejorVersion(t, j, monedas: 1000);
            final c = draft.candidatos(nueva);
            expect(personasRepetidas(c), isEmpty);
            expect(c.where((x) => x.personaId == j.personaId), hasLength(1));
            expect(c.where((x) => x.personaId == j.personaId).single.media, greaterThan(j.media));
            expect(c.length, draft.candidatos(t).length);
            // Mejor versión de nuevo con la misma carta: no se puede (ya está cambiada).
            expect(() => draft.mejorVersion(nueva, c.firstWhere((x) => x.personaId == j.personaId)), throwsA(anything));
          }
        }
      }
      expect(comprobadas, greaterThan(50));
    });

    test('Franquicia pura y Una sola década: si la mejor global viola la regla, se usa la mejor que sí cumple', () {
      final draft = Draft(catalogo, azar: Random(4));
      // LeBron en los Lakers: su mejor carta global es de Cleveland o Miami (no cumple Franquicia pura de LAL).
      final lebron = catalogo.where((j) => j.idBbref == 'jamesle01').toList();
      final global = mejorDe(lebron);
      expect(global.franquiciaId, isNot('LAL'));
      var t = Temporada(
        id: 'fp',
        franquiciaUsuarioId: 'LAL',
        regla: ReglaDraft.franquiciaPura,
        tirada: const Tirada(franquiciaId: 'LAL', epoca: Epoca.anios2010, tier: Tier.s),
      );
      final carta = draft.candidatos(t).where((j) => j.idBbref == 'jamesle01').toList();
      final lal = lebron.where((j) => j.franquiciaId == 'LAL').toList();
      if (carta.isNotEmpty) {
        final mejor = draft.mejorVersionDe(t, carta.single);
        final mejorLal = mejorDe(lal);
        if (mejor != null) expect(mejor.franquiciaId, 'LAL');
        expect(mejor == null || mejor.id == mejorLal.id, isTrue);
      }
      t = Temporada(
        id: 'fp2',
        franquiciaUsuarioId: 'LAL',
        regla: ReglaDraft.unaDecada,
        epocaRegla: Epoca.anios2010,
        tirada: t.tirada,
      );
      final de2010 = lebron.where((j) => j.epoca == Epoca.anios2010).toList();
      final c2 = draft.candidatos(t).where((j) => j.idBbref == 'jamesle01');
      for (final c in c2) {
        final mejor = draft.mejorVersionDe(t, c);
        expect(mejor == null || mejor.epoca == Epoca.anios2010, isTrue);
        expect(mejor == null || mejor.id == mejorDe(de2010).id, isTrue);
      }
    });

    test('Doble: dos PERSONAS distintas de la misma tirada', () {
      var comprobados = 0;
      for (var seed = 0; seed < 60; seed++) {
        final draft = Draft(catalogo, azar: Random(seed + 900));
        var t = draft.tirar(base.copyWith(rerollsRestantes: 3));
        if (draft.estadoDe(t, TokenDraft.doble, monedas: 1000) == EstadoToken.bloqueado) continue;
        t = draft.doble(t, monedas: 1000);
        final primeros = draft.candidatos(t);
        expect(personasRepetidas(primeros), isEmpty);
        final a = primeros.firstWhere((j) => draft.puestosPara(t, j).isNotEmpty);
        t = draft.elegir(t, a, draft.puestosPara(t, a).first);
        expect(t.tokens.picksExtra, 0);
        final segundos = draft.candidatos(t);
        expect(segundos.any((j) => j.personaId == a.personaId), isFalse, reason: 'ni otra versión de ${a.nombre}');
        expect(segundos, isNotEmpty);
        final b = segundos.first;
        t = draft.elegir(t, b, draft.puestosPara(t, b).first);
        expect(personasRepetidas(t.plantel.jugadores), isEmpty);
        expect(t.plantel.jugadores.length, 2);
        comprobados++;
      }
      expect(comprobados, greaterThan(20));
    });

    test(
      'Intercambio: las que entran son una por persona, ninguna ya en el plantel ni otra versión de la que sale',
      () {
        var comprobados = 0;
        for (var seed = 0; seed < 15; seed++) {
          final azar = Random(seed + 1300);
          final draft = Draft(catalogo, azar: azar);
          var t = base.copyWith(rerollsRestantes: 3);
          for (var i = 0; i < 3; i++) {
            t = draft.tirar(t);
            final c = draft.candidatos(t).first;
            t = draft.elegir(t, c, draft.puestosPara(t, c).first);
          }
          t = draft.tirar(t);
          for (final (puesto, sale, entran) in draft.opcionesIntercambio(t)) {
            expect(personasRepetidas(entran), isEmpty, reason: 'sale ${sale.id}');
            final otrosEnPlantel = {for (final x in t.plantel.quitar(puesto).jugadores) x.personaId};
            for (final e in entran) {
              expect(otrosEnPlantel.contains(e.personaId), isFalse);
              expect(e.personaId == sale.personaId, isFalse, reason: 'otra versión de quien sale');
              expect(t.tirada!.incluye(e), isTrue);
            }
            final nueva = draft.intercambiar(t, entran.first, puesto, monedas: 1000);
            expect(personasRepetidas(nueva.plantel.jugadores), isEmpty);
            comprobados++;
            // Una versión que la tirada no muestra para esa persona (la de menos media) no entra.
            final ocultas = catalogo.where(
              (c) =>
                  t.tirada!.incluye(c) &&
                  entran.any((e) => e.personaId == c.personaId && e.id != c.id) &&
                  c.personaId != sale.personaId,
            );
            for (final o in ocultas.take(2)) {
              expect(() => draft.intercambiar(t, o, puesto, monedas: 1000), throwsA(isA<ReglaPlantelException>()));
            }
            break;
          }
        }
        expect(comprobados, greaterThan(10));
      },
    );

    test('Comodín: la tirada fijada también trae una carta por persona y la rareza garantizada', () {
      for (var seed = 0; seed < 40; seed++) {
        final azar = Random(seed + 1700);
        final draft = Draft(catalogo, azar: azar);
        var t = draft.tirar(base.copyWith(rerollsRestantes: 3));
        final posibles = draft.franquiciasPosibles(t).toList()..sort();
        t = draft.comodin(t, franquiciaId: posibles[azar.nextInt(posibles.length)], monedas: 1000);
        final c = draft.candidatos(t);
        expect(personasRepetidas(c), isEmpty);
        expect(c.any((j) => j.tier == t.tirada!.tier), isTrue);
        t = draft.tirar(t); // y vuelve a tirar sin trabarse
        expect(personasRepetidas(draft.candidatos(t)), isEmpty);
      }
    });
  });

  group('modo Cartas: sobres, ofertas y serpiente', () {
    test('miles de cartas repartidas: cada sobre abierto trae una por persona, con todas las reglas', () {
      final azarEsc = Random(5);
      final album = {
        for (final j in ([...catalogo]..shuffle(azarEsc)).take(3000)) j.id,
      };
      var cartasVistas = 0;
      for (final regla in ReglaDraft.values) {
        for (var seed = 0; seed < 12; seed++) {
          final azar = Random(seed * 17 + regla.index);
          final epoca = Epoca.values[azar.nextInt(Epoca.values.length)];
          var t = Temporada(
            id: 'c$seed',
            franquiciaUsuarioId: franquicias[azar.nextInt(franquicias.length)].id,
            modo: ModoDraft.cartas,
            regla: regla,
            epocaRegla: regla == ReglaDraft.unaDecada ? epoca : null,
            rerollsRestantes: 2,
          );
          final draft = Draft(catalogo, azar: azar, coleccion: album);
          while (!t.plantel.completo) {
            final libres = Posicion.values
                .where((p) => !t.plantel.estaOcupada(p) && draft.puedeRepartir(t, p))
                .toList();
            if (libres.isEmpty) break;
            final puesto = libres[azar.nextInt(libres.length)];
            var conSobres = draft.repartir(t, puesto);
            if (azar.nextBool() &&
                draft.estadoDe(conSobres, TokenDraft.volverATirar, monedas: 0) == EstadoToken.gratis) {
              conSobres = draft.volverARepartir(conSobres);
            }
            final etiqueta = '${regla.name} semilla $seed ${puesto.name}';
            Temporada? elegida;
            for (var i = 0; i < conSobres.oferta!.sobres.length; i++) {
              final abierto = draft.abrirSobre(conSobres, i);
              final cartas = draft.cartasDeOferta(abierto);
              cartasVistas += cartas.length;
              expect(cartas, isNotEmpty, reason: etiqueta);
              expect(personasRepetidas(cartas), isEmpty, reason: 'sobre $i: $etiqueta');
              expect(cartas.every((j) => draft.permitida(abierto, j)), isTrue, reason: etiqueta);
              expect(cartas.every((j) => j.puedeJugarEn(puesto)), isTrue, reason: etiqueta);
              final yaEstan = {for (final j in abierto.plantel.jugadores) j.personaId};
              expect(cartas.any((j) => yaEstan.contains(j.personaId)), isFalse, reason: etiqueta);
              if (abierto.oferta!.sorpresaId != null) {
                expect(abierto.oferta!.cartaIds, contains(abierto.oferta!.sorpresaId));
              }
              if (regla == ReglaDraft.serpiente) {
                // Lo que se llevaron los rivales no se repite (ni entre ellos ni con tus opciones).
                final robadas = [
                  for (final ids in abierto.robos.values) ...ids.map(draft.jugador).whereType<Jugador>(),
                ];
                expect(personasRepetidas(robadas), isEmpty, reason: 'robos: $etiqueta');
                expect(robadas.any((r) => cartas.any((c) => c.personaId == r.personaId)), isFalse, reason: etiqueta);
              }
              elegida = abierto;
            }
            final cartas = draft.cartasDeOferta(elegida!);
            // Mejor versión en el modo Cartas: misma persona, una sola carta.
            for (final j in cartas) {
              final mejor = draft.mejorVersionDe(elegida, j);
              if (mejor == null) continue;
              expect(mejor.personaId, j.personaId);
              expect(draft.permitida(elegida, mejor), isTrue, reason: 'regla ${regla.name}');
              final cambiada = draft.mejorVersion(elegida, j, monedas: 1000);
              expect(personasRepetidas(draft.cartasDeOferta(cambiada)), isEmpty);
              break;
            }
            final j = cartas[azar.nextInt(cartas.length)];
            t = draft.fichar(elegida, j);
            expect(personasRepetidas(t.plantel.jugadores), isEmpty, reason: etiqueta);
          }
        }
      }
      expect(cartasVistas, greaterThan(1000));
    });

    test('un sobre cuenta personas: no ofrece una franquicia o época que solo tiene 5 cartas de 3 personas', () {
      final draft = Draft(catalogo, azar: Random(8));
      final t = draft.repartir(
        const Temporada(
          id: 'fpc',
          franquiciaUsuarioId: 'CHI',
          modo: ModoDraft.cartas,
          regla: ReglaDraft.franquiciaPura,
        ),
        Posicion.pivot,
      );
      for (final s in t.oferta!.sobres) {
        final abierto = draft.abrirSobre(t, t.oferta!.sobres.indexOf(s));
        final cartas = draft.cartasDeOferta(abierto);
        expect(cartas.length, greaterThanOrEqualTo(Draft.cartasPorReparto), reason: s.tipo.name);
        expect(personasRepetidas(cartas), isEmpty);
      }
    });
  });

  group('otros modos con listas de cartas', () {
    test('agentes libres: ocho personas distintas, ninguna en tu plantel ni en un rival; mismo seed, misma lista', () {
      final liga = Liga(catalogo, franquicias, azar: Random(12));
      var p = const Plantel();
      final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
      for (final pos in Posicion.values) {
        p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
      }
      final t = liga.iniciar(Temporada(id: 'al', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
      final libres = liga.agentesLibres(t);
      expect(libres, hasLength(8));
      expect(personasRepetidas(libres), isEmpty);
      final ocupadas = {
        for (final j in t.plantel.jugadores) j.personaId,
        for (final r in t.rivales.values)
          for (final id in r.cartaIds.values) liga.jugador(id)!.personaId,
      };
      expect(libres.any((j) => ocupadas.contains(j.personaId)), isFalse);
      expect(liga.agentesLibres(t).map((j) => j.id), libres.map((j) => j.id));
      // Y cada agente libre es la mejor versión de su persona dentro del filtro (A/B, media 72–86).
      for (final j in libres) {
        final mejores = catalogo.where(
          (c) => c.personaId == j.personaId && (c.tier == Tier.a || c.tier == Tier.b) && c.media >= 72 && c.media <= 86,
        );
        expect(j.id, mejorDe(mejores).id);
      }
      // Firmar a alguien que ya está en el plantel (otra versión) no hace nada.
      final otraVersion = catalogo.firstWhere(
        (c) => c.personaId == t.plantel.jugadores.first.personaId && c.id != t.plantel.jugadores.first.id,
        orElse: () => t.plantel.jugadores.first,
      );
      final conLugar = liga.liberar(t, t.suplentes.first);
      expect(liga.firmar(conLugar, otraVersion).suplentes.length, conLugar.suplentes.length);
    });

    test('Liga: ninguna persona dos veces entre tu plantel, tus suplentes y los 29 rivales (varias semillas)', () {
      for (var seed = 1; seed <= 6; seed++) {
        final liga = Liga(catalogo, franquicias, azar: Random(seed));
        final franq = franquicias[seed * 4 % franquicias.length].id;
        var p = const Plantel();
        final propias = catalogo.where((j) => j.franquiciaId == franq).toList()
          ..sort((a, b) => b.media.compareTo(a.media));
        for (final pos in Posicion.values) {
          p = p.asignar(propias.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
        }
        for (final dif in Dificultad.values) {
          final t = liga.iniciar(
            Temporada(id: 'l$seed', franquiciaUsuarioId: franq, plantel: p, tacticaConfirmada: true, dificultad: dif),
          );
          expect(t.rivales, hasLength(29));
          final todas = <Jugador>[
            ...t.plantel.jugadores,
            ...t.suplentes,
            for (final r in t.rivales.values) ...liga.plantelDe(r).jugadores,
          ];
          expect(personasRepetidas(todas), isEmpty, reason: 'semilla $seed ${dif.name}');
          expect(todas.length, 6 + t.suplentes.length + 29 * 6);
        }
      }
    });

    test(
      'Mercado de pases: no entra una carta de una persona que ya tenés (otra versión) en el plantel o el banco',
      () {
        final liga = Liga(catalogo, franquicias, azar: Random(31));
        final mercado = Mercado(liga);
        var p = const Plantel();
        final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
        for (final pos in Posicion.values) {
          p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
        }
        final t = liga.iniciar(Temporada(id: 'm', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
        var probados = 0;
        for (final rivalId in t.rivales.keys) {
          for (final (puesto, suyo) in mercado.pedibles(t, rivalId)) {
            final otra = catalogo.where((c) => c.personaId == suyo.personaId && c.id != suyo.id).firstOrNull;
            final mio = t.plantel.en(puesto)!;
            if (otra == null || !suyo.puedeJugarEn(puesto) || !mio.puedeJugarEn(puesto)) continue;
            final conBanco = t.copyWith(suplentes: [otra]);
            final r = mercado.evaluar(conBanco, mio, rivalId, suyo);
            expect(r.acepta, isFalse);
            expect(r.motivo, contains('otra carta'));
            probados++;
            break;
          }
          if (probados >= 3) break;
        }
        expect(probados, greaterThan(0));
      },
    );

    test(
      'Tienda: cada sobre de la tienda trae personas distintas (la mejor versión de cada una dentro de su rareza)',
      () {
        final tienda = Tienda(catalogo, azar: Random(21));
        var perfil = const PerfilEntrenador(monedas: 1000000);
        for (var i = 0; i < 150; i++) {
          for (final s in SobreTienda.values) {
            final (nuevo, apertura) = tienda.abrir(perfil, s);
            perfil = nuevo.copyWith(monedas: 1000000);
            expect(apertura.cartas, hasLength(s.cartas));
            expect(personasRepetidas(apertura.cartas), isEmpty, reason: '${s.nombre} $i');
          }
        }
      },
    );

    test('Draft en grupo (amigos): las cartas de cada turno son personas distintas y nadie repite una persona', () {
      final amigos = Amigos(catalogo, azar: Random(3));
      for (var semilla = 1; semilla <= 8; semilla++) {
        var p = amigos.nueva(
          duelo: false,
          personas: [('Ana', 'CHI'), ('Beto', 'LAL'), ('Caro', 'BOS')],
          semilla: semilla,
        );
        while (p.fase == FaseAmigos.draft) {
          final yo = p.participantes[p.eligeAhora];
          final c = amigos.candidatos(p);
          expect(personasRepetidas(c), isEmpty, reason: 'semilla $semilla turno ${p.turno}');
          if (p.turno % 4 == 0 && yo.sorteos > 0) {
            p = amigos.otrasCartas(amigos.verTurno(p));
            expect(personasRepetidas(amigos.candidatos(p)), isEmpty);
            continue;
          }
          final j = c[p.turno % c.length];
          final puestos = yo.plantel.posicionesDisponiblesPara(j);
          p = amigos.elegir(amigos.verTurno(p), j, puestos.first);
        }
        final todas = [for (final x in p.participantes) ...x.plantel.jugadores];
        expect(personasRepetidas(todas), isEmpty, reason: 'semilla $semilla');
      }
    });

    test('Tope salarial, Liga de 8 y Leyenda única: tableros, pozo y leyendas sin personas repetidas', () {
      final modos = ModosArmado(catalogo, azar: Random(4));
      for (var semilla = 1; semilla <= 12; semilla++) {
        final tablero = modos.tablero(semilla).map((id) => catalogo.firstWhere((j) => j.id == id)).toList();
        expect(personasRepetidas(tablero), isEmpty, reason: 'tablero $semilla');
        final pozo = modos.pozo(semilla).map((id) => catalogo.firstWhere((j) => j.id == id)).toList();
        expect(personasRepetidas(pozo), isEmpty, reason: 'pozo $semilla');
      }
      for (var i = 0; i < 20; i++) {
        expect(personasRepetidas(Variantes(catalogo, azar: Random(i)).leyendasParaElegir()), isEmpty);
      }
    });
  });

  group('álbum por jugador', () {
    final personasEnCatalogo = {for (final j in catalogo) j.personaId}.length;
    final jordan = catalogo.where((j) => j.idBbref == 'jordami01').toList()..sort((a, b) => b.media.compareTo(a.media));
    final curry = catalogo.where((j) => j.idBbref == 'curryst01').toList()..sort((a, b) => b.media.compareTo(a.media));

    test('una tarjeta por persona con sus versiones adentro; la principal es la de mayor media que tenés', () {
      final peor = jordan.last, mejor = jordan.first;
      final coleccion = {peor.id, mejor.id, curry.first.id, 'id-que-ya-no-existe'};
      final album = AlbumPorJugador(catalogo, coleccion);
      expect(album.personas, hasLength(2));
      final j = album.personas.firstWhere((x) => x.personaId == jordan.first.personaId);
      expect(j.tengo.map((c) => c.id), [mejor.id, peor.id]);
      expect(j.principal.id, mejor.id);
      expect(j.total.length, jordan.length);
      expect(j.faltan.length, jordan.length - 2);
      expect(j.tieneVarias, isTrue);
      final r = album.resumen;
      expect((r.personasTengo, r.versionesTengo, r.personasTotal), (2, 3, personasEnCatalogo));
      expect(r.versionesTotal, catalogo.length);
      expect(r.texto, '2 de ${miles(personasEnCatalogo)} jugadores · 3 versiones');
    });

    test('sin la mejor, la principal es la mejor que tenés; con una sola, "1 versión"', () {
      final album = AlbumPorJugador(catalogo, {jordan[2].id, jordan[3].id});
      expect(album.personas.single.principal.id, jordan[2].id);
      final una = AlbumPorJugador(catalogo, {curry.first.id});
      expect(una.resumen.texto, '1 de ${miles(personasEnCatalogo)} jugadores · 1 versión');
      expect(
        AlbumPorJugador(catalogo, const {}).resumen.texto,
        '0 de ${miles(personasEnCatalogo)} jugadores · 0 versiones',
      );
    });

    test('progreso por franquicia: personas y versiones, y el filtro muestra solo las versiones de esa franquicia', () {
      final gsw = curry.where((j) => j.franquiciaId == 'GSW').toList();
      final otra = jordan.firstWhere((j) => j.franquiciaId != 'CHI', orElse: () => jordan.last);
      final album = AlbumPorJugador(catalogo, {for (final j in gsw) j.id, otra.id});
      final r = album.deFranquicia('GSW');
      expect(r.personasTengo, 1);
      expect(r.versionesTengo, gsw.length);
      expect(r.personasTotal, {for (final j in catalogo.where((j) => j.franquiciaId == 'GSW')) j.personaId}.length);
      final filtradas = album.deLaFranquicia('GSW');
      expect(filtradas, hasLength(1));
      expect(filtradas.single.tengo.every((j) => j.franquiciaId == 'GSW'), isTrue);
      expect(filtradas.single.principal.id, mejorDe(gsw).id);
      expect(album.deLaFranquicia(null), hasLength(album.personas.length));
    });

    test('miles con punto y el perfil viejo (solo ids de carta) sigue igual', () {
      expect(miles(0), '0');
      expect(miles(999), '999');
      expect(miles(4070), '4.070');
      expect(miles(1234567), '1.234.567');
      final perfil = PerfilEntrenador.fromJson({
        'coleccion': [jordan.first.id, jordan.last.id],
      });
      expect(perfil.coleccion, {jordan.first.id, jordan.last.id});
      expect(AlbumPorJugador(catalogo, perfil.coleccion).personas, hasLength(1));
    });
  });
}
