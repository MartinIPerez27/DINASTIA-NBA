import 'dart:convert';
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
import 'package:dinastia_nba/domain/modos/evoluciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(7));
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  var p = const Plantel();
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final estrella = p.en(Posicion.base)!;

  PerfilEntrenador conEvo(String id, String objetivo, {int progreso = 0, int etapa = 0}) {
    final evo = PerfilEvoluciones({id: EvoCarta(objetivoId: objetivo, progreso: progreso, etapa: etapa)});
    return evo.guardarEn(const PerfilEntrenador());
  }

  test('los objetivos tienen 5 metas crecientes y ids únicos', () {
    expect({for (final o in Evoluciones.objetivos) o.id}, hasLength(Evoluciones.objetivos.length));
    for (final o in Evoluciones.objetivos) {
      expect(o.metas, hasLength(Evoluciones.maxNivel));
      for (var i = 1; i < o.metas.length; i++) {
        expect(o.metas[i], greaterThan(o.metas[i - 1]), reason: o.id);
      }
    }
  });

  test('empezar, sumar solo la métrica del objetivo, cobrar por etapas y respetar el máximo de activas', () {
    var evo = const PerfilEvoluciones().empezar('a', 'triples');
    expect(evo.cartas['a']!.objetivoId, 'triples');
    evo = evo.sumar('a', MetricaEvo.puntos, 50); // otra métrica: no cuenta
    expect(evo.cartas['a']!.progreso, 0);
    evo = evo.sumar('a', MetricaEvo.triples, 30);
    expect(evo.cartas['a']!.listaParaCobrar, isTrue);
    final (cobrado, n) = evo.cobrar('a');
    expect(n, 2, reason: 'metas 10 y 25');
    expect(cobrado.cartas['a']!.etapa, 2);
    expect(cobrado.cobrar('a').$2, 0);
    // tope de 3 activas
    evo = cobrado.empezar('b', 'puntos').empezar('c', 'robos');
    expect(evo.activas, 3);
    expect(evo.puedeEmpezar('d'), isFalse);
    expect(evo.empezar('d', 'puntos').cartas.containsKey('d'), isFalse);
    // una carta ya evolucionando no se empieza de nuevo
    expect(evo.empezar('a', 'robos').cartas['a']!.objetivoId, 'triples');
  });

  test('completar libera un lugar y el progreso no pasa de la meta final', () {
    var evo = const PerfilEvoluciones().empezar('a', 'victorias').empezar('b', 'puntos').empezar('c', 'robos');
    evo = evo.sumar('a', MetricaEvo.victorias, 9999);
    expect(evo.cartas['a']!.progreso, 45);
    final (completa, n) = evo.cobrar('a');
    expect(n, Evoluciones.maxNivel);
    expect(completa.cartas['a']!.completa, isTrue);
    expect(completa.activas, 2);
    expect(completa.puedeEmpezar('d'), isTrue);
  });

  test('la media evolucionada solo cuenta en los modos del álbum', () {
    final perfil = conEvo(estrella.id, 'puntos', etapa: 3);
    expect(nivelEvo(perfil, estrella.id), 3);
    expect(mediaEvolucionada(perfil, estrella, usaAlbum: false), estrella.media);
    expect(mediaEvolucionada(perfil, estrella, usaAlbum: true), (estrella.media + 3).clamp(0, 99));
    expect(aplicarEvolucion(perfil, estrella, usaAlbum: false), same(estrella));
    expect(aplicarEvolucion(perfil, estrella, usaAlbum: true).media, (estrella.media + 3).clamp(0, 99));
    expect(aplicarEvoluciones(perfil, [estrella], usaAlbum: false).single, same(estrella));
    // una carta sin evolución no cambia
    final otra = chi.firstWhere((j) => j.id != estrella.id);
    expect(aplicarEvolucion(perfil, otra, usaAlbum: true), same(otra));
  });

  test('qué partidas usan el álbum', () {
    for (final m in ModoJuego.values) {
      final t = Temporada(id: 'x', franquiciaUsuarioId: 'CHI', modoJuego: m);
      expect(partidaUsaAlbum(t), m.usaAlbum, reason: m.name);
    }
    expect(
      partidaUsaAlbum(const Temporada(id: 'x', franquiciaUsuarioId: 'CHI', regla: ReglaDraft.coleccion)),
      isTrue,
    );
    expect(partidaUsaAlbum(const Temporada(id: 'x', franquiciaUsuarioId: 'CHI')), isFalse);
  });

  test('Liga aplica la evolución solo a las partidas del álbum (no en el clásico ni a los rivales)', () {
    final evolucionada = Liga(catalogo, franquicias, azar: Random(7))..nivelEvolucion = (id) => id == estrella.id ? 4 : 0;
    Temporada base(ModoJuego m, {ReglaDraft regla = ReglaDraft.libre}) => evolucionada.iniciar(
      Temporada(id: 'e', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true, modoJuego: m, regla: regla),
    );
    int media(Temporada t) => evolucionada.equipo(t, 'CHI').plantel.en(Posicion.base)!.media;
    expect(media(base(ModoJuego.clasico)), estrella.media);
    expect(media(base(ModoJuego.racha)), estrella.media);
    expect(media(base(ModoJuego.desafiosArmado)), (estrella.media + 4).clamp(0, 99));
    expect(media(base(ModoJuego.clasico, regla: ReglaDraft.coleccion)), (estrella.media + 4).clamp(0, 99));
    // los rivales nunca se evolucionan
    final t = base(ModoJuego.desafiosArmado);
    final rival = t.rivales.keys.first;
    for (final j in evolucionada.equipo(t, rival).plantel.jugadores) {
      expect(j.media, catalogo.firstWhere((c) => c.id == j.id).media);
    }
  });

  test('el progreso sale de lo que jugó la carta entre dos estados de la temporada', () {
    final perfil = conEvo(estrella.id, 'partidos');
    var t = liga.iniciar(Temporada(id: 'p', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    final antes = t;
    for (var i = 0; i < 6; i++) {
      t = liga.simularProximo(t);
    }
    final nuevo = avanzarEvoluciones(perfil, antes, t);
    final c = PerfilEvoluciones.de(nuevo).cartas[estrella.id]!;
    expect(c.progreso, greaterThanOrEqualTo(4), reason: 'jugó la mayoría de los 6 partidos');
    expect(c.progreso, lessThanOrEqualTo(6));
    // sin evoluciones en el perfil no pasa nada
    expect(avanzarEvoluciones(const PerfilEntrenador(), antes, t).evoluciones, isEmpty);
  });

  test('el perfil se guarda y se lee con las evoluciones (y uno viejo, sin ellas, sigue cargando)', () {
    final perfil = conEvo('x', 'rebotes', progreso: 55, etapa: 1);
    final copia = PerfilEntrenador.fromJson(jsonDecode(jsonEncode(perfil.toJson())) as Map<String, dynamic>);
    final c = PerfilEvoluciones.de(copia).cartas['x']!;
    expect((c.objetivoId, c.progreso, c.etapa), ('rebotes', 55, 1));
    final viejo = PerfilEntrenador.fromJson(const {'xp': 10});
    expect(viejo.evoluciones, isEmpty);
    expect(nivelEvo(viejo, 'x'), 0);
  });

  test('registrarEvolucion suma desde un modo propio', () {
    final perfil = conEvo('x', 'victorias');
    expect(PerfilEvoluciones.de(registrarEvolucion(perfil, 'x', MetricaEvo.victorias, 2)).cartas['x']!.progreso, 2);
    expect(registrarEvolucion(perfil, 'x', MetricaEvo.puntos, 2), same(perfil));
  });
}
