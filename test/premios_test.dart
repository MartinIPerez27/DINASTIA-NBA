import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/all_star.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/historicos.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/noticias.dart';
import 'package:dinastia_nba/domain/premios.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(31));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final inicio = liga.iniciar(Temporada(id: 'pr', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  var mitad = inicio;
  for (var i = 0; i < 45; i++) {
    mitad = liga.simularProximo(mitad);
  }
  var fin = mitad;
  while (liga.proximoDelUsuario(fin) != null) {
    fin = liga.simularProximo(fin);
  }
  fin = liga.simularOtrosHasta(fin, 1 << 30);
  String nombre(String id) => franquiciaPorId(id == 'CHI' ? id : fin.rivales[id]!.identidadId).nombre;

  test('premios: el MVP coincide, el Sexto Hombre es sexto, All-NBA 2-2-1 sin repetir', () {
    final premios = calcularPremios(fin, liga);
    expect(premios.definitivos, isTrue);
    final (mvp, anotador) = liga.premios(fin);
    expect(premios.mvp!.jugadorId, mvp!.jugadorId);
    expect(premios.anotador!.jugadorId, anotador!.jugadorId);
    final sextos = {
      fin.plantel.en(Posicion.sextoHombre)!.id,
      for (final r in fin.rivales.values) r.cartaIds[Posicion.sextoHombre]!,
    };
    expect(sextos, contains(premios.sextoHombre!.jugadorId));
    expect(premios.defensor, isNotNull);
    expect(premios.masMejorado, isNotNull);
    expect(premios.allNba, hasLength(3));
    final ids = <String>{};
    for (final q in premios.allNba) {
      expect(q, hasLength(5));
      final grupos = [for (final g in q) GrupoPuesto.de(g.jugador)];
      expect(grupos.where((g) => g == GrupoPuesto.exterior), hasLength(2));
      expect(grupos.where((g) => g == GrupoPuesto.alero), hasLength(2));
      expect(grupos.where((g) => g == GrupoPuesto.pivot), hasLength(1));
      for (final g in q) {
        expect(ids.add(g.jugadorId), isTrue, reason: 'nadie en dos quintetos');
      }
    }
  });

  test('titulares: semanas completas, el más nuevo primero, deterministas', () {
    final lista = titulares(fin, liga, nombre: nombre);
    expect(lista, isNotEmpty);
    for (var i = 0; i + 1 < lista.length; i++) {
      expect(lista[i].jornada, greaterThanOrEqualTo(lista[i + 1].jornada));
    }
    expect(lista.any((n) => n.destacado), isTrue, reason: 'siempre hay algo de tu equipo');
    expect(titulares(fin, liga, nombre: nombre).map((n) => n.texto), lista.map((n) => n.texto));
    expect(titulares(inicio, liga, nombre: nombre), isEmpty);
    expect(carreraMvp(mitad, liga), hasLength(5));
  });

  test('récords: se persiguen con datos reales y se baten al final', () {
    // Un jugador que promedia 52 puntos persigue y bate el récord de Wilt.
    final estrella = fin.plantel.en(Posicion.escolta)!;
    final linea = LineaEstadistica()
      ..pj = 82
      ..pts = 52 * 82;
    final conRecord = fin.copyWith(lineas: {...fin.lineas, estrella.id: linea});
    final batidos = recordsBatidos(conRecord, liga);
    expect(batidos.any((r) => r.record == RecordNba.puntos && r.jugador == estrella), isTrue);
    expect(batidos.first.texto, contains('Wilt Chamberlain'));
    expect(recordsBatidos(mitad, liga), isEmpty, reason: 'recién al final de la temporada regular');
    for (final r in recordsEnJuego(mitad, liga)) {
      expect(r.texto, isNotEmpty);
    }
  });

  test('All-Star: después de la mitad, 12 por conferencia balanceados, determinista', () {
    expect(allStarDe(inicio, liga), isNull);
    expect(inicio.allStar, isNull);
    expect(mitad.allStar, isNotNull, reason: 'se juega y se guarda al cruzar la mitad');
    final a = allStarDe(mitad, liga)!;
    for (final lado in [a.este, a.oeste]) {
      expect(lado, hasLength(12));
      final grupos = [for (final j in lado) GrupoPuesto.de(j)];
      expect(grupos.where((g) => g == GrupoPuesto.exterior).length, greaterThanOrEqualTo(3));
      expect(grupos.where((g) => g == GrupoPuesto.alero).length, greaterThanOrEqualTo(3));
      expect(grupos.where((g) => g == GrupoPuesto.pivot).length, greaterThanOrEqualTo(2));
    }
    expect(a.puntosEste, isNot(a.puntosOeste));
    expect([...a.este, ...a.oeste], contains(a.mvp));
    // Determinista: jugarlo dos veces con las mismas estadísticas da lo mismo.
    final b1 = jugarAllStar(mitad, liga)!, b2 = jugarAllStar(mitad, liga)!;
    expect((b2.puntosEste, b2.puntosOeste, b2.mvp.id), (b1.puntosEste, b1.puntosOeste, b1.mvp.id));
  });

  test('All-Star guardado: no cambia aunque sigan los partidos ni al cerrar y abrir la app', () {
    final a = mitad.allStar!;
    expect(identical(fin.allStar, a) || fin.allStar!.mvp.id == a.mvp.id, isTrue);
    expect((fin.allStar!.puntosEste, fin.allStar!.puntosOeste), (a.puntosEste, a.puntosOeste));
    final copia = Temporada.fromJson(fin.toJson());
    final c = allStarDe(copia, liga)!;
    expect((c.puntosEste, c.puntosOeste, c.mvp.id), (a.puntosEste, a.puntosOeste, a.mvp.id));
    expect([for (final j in c.este) j.id], [for (final j in a.este) j.id]);
    expect(c.lineaMvp.pts, a.lineaMvp.pts);
    // Una partida guardada antes de esto (sin All-Star) lo arma al vuelo y lo guarda en el próximo partido.
    final vieja = Temporada.fromJson({...fin.toJson()}..remove('allStar'));
    expect(vieja.allStar, isNull);
    expect(allStarDe(vieja, liga), isNotNull);
  });

  test('cerrar la temporada reparte los premios nuevos a tus jugadores', () {
    final cerrada = liga.simularRestoPlayoffs(fin);
    final (perfil, _) = Progreso(liga).aplicar(const PerfilEntrenador(), fin, cerrada);
    final premios = calcularPremios(fin, liga);
    final mios = premios.allNba.expand((q) => q).where((g) => g.franquiciaId == 'CHI').length;
    expect(perfil.trofeos.where((t) => t.tipo == TipoTrofeo.allNba), hasLength(mios));
    final allStar = allStarDe(cerrada, liga)!;
    expect(perfil.trofeos.where((t) => t.tipo == TipoTrofeo.allStar), hasLength(allStar.de('CHI').length));
    if (allStar.de('CHI').length >= 3) expect(perfil.logros.keys, contains(Logro.tresAllStars));
    final copia = PerfilEntrenador.fromJson(perfil.toJson());
    expect(copia.trofeos.map((t) => t.tipo), perfil.trofeos.map((t) => t.tipo));
  });
}
