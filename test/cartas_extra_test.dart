import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/entrenador.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/quimica.dart';
import 'package:dinastia_nba/domain/tienda.dart';
import 'package:dinastia_nba/domain/versiones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  Jugador carta(String id) => catalogo.firstWhere((j) => j.id == id);

  test('química: dúos legendarios, compañeros de época y el entrenador suman; 0 a 100', () {
    final jordan = carta('jordami01-CHI-90'), pippen = carta('pippesc01-CHI-90');
    final q = Quimica.de([jordan, pippen]);
    expect(q.vinculos.single.tipo, TipoVinculo.duo);
    expect(q.vinculos.single.nombreDuo, 'Jordan y Pippen');
    final conPhil = Quimica.de([jordan, pippen], entrenador: Entrenador.porId('jackson'));
    expect(conPhil.puntaje, greaterThan(q.puntaje));
    final sueltos = Quimica.de([carta('jordami01-CHI-90'), carta('duncati01-SAS-00')]);
    expect(sueltos.puntaje, lessThan(q.puntaje));
    final bulls = catalogo.where((j) => j.equipo == 'CHI' && j.epoca == Epoca.anios90).take(6);
    expect(Quimica.de(bulls).puntaje, 100);
    for (final (a, b, _) in Quimica.duos) {
      expect(catalogo.any((j) => j.idBbref == a), isTrue, reason: a);
      expect(catalogo.any((j) => j.idBbref == b), isTrue, reason: b);
    }
  });

  test('versiones: Novato, Prime y Veterano de una misma leyenda', () {
    final v = calcularVersiones(catalogo);
    final lebron = catalogo.where((j) => j.idBbref == 'jamesle01').toList();
    expect(lebron.length, greaterThan(1));
    final primes = lebron.where((j) => v[j.id] == VersionCarta.prime);
    expect(primes, isNotEmpty);
    expect(
      {for (final j in primes) j.epoca},
      hasLength(1),
      reason: 'el Prime es una sola década (puede haber varias franquicias)',
    );
    expect(lebron.any((j) => v[j.id] == VersionCarta.veterano || v[j.id] == VersionCarta.novato), isTrue);
    final unaSola = catalogo.firstWhere(
      (j) =>
          catalogo.where((o) => o.nbaPlayerId == j.nbaPlayerId && o.nbaPlayerId > 0).length == 1 && j.nbaPlayerId > 0,
    );
    expect(v[unaSola.id], isNull);
  });

  test('tienda: cuesta monedas, suma al álbum y las repetidas devuelven monedas', () {
    final tienda = Tienda(catalogo, azar: Random(1));
    expect(() => tienda.abrir(const PerfilEntrenador(), SobreTienda.comun), throwsStateError);
    var (p, a) = tienda.abrir(const PerfilEntrenador(monedas: 2000), SobreTienda.leyenda);
    expect(a.cartas, hasLength(3));
    expect(a.cartas.every((c) => c.tier == Tier.s || c.tier == Tier.sPlus), isTrue);
    expect(p.monedas, 800);
    expect(p.coleccion, containsAll(a.cartas.map((c) => c.id)));
    final conTodo = p.copyWith(coleccion: {for (final j in catalogo) j.id}, monedas: 150);
    (p, a) = tienda.abrir(conTodo, SobreTienda.comun);
    expect(a.repetidas, hasLength(5));
    expect(p.monedas, 5 * Tienda.monedasPorRepetida);
  });

  test('forma y robos: la forma se mueve entre −3 y +3, y lo robado llega al rival', () {
    final liga = Liga(catalogo, franquicias, azar: Random(4));
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'MIA').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    final robada = carta('jordami01-CHI-90');
    var t = liga.iniciar(
      Temporada(
        id: 'f',
        franquiciaUsuarioId: 'MIA',
        plantel: p,
        tacticaConfirmada: true,
        robos: {
          'BOS': [robada.id],
        },
        entrenadorId: 'spoelstra',
      ),
    );
    expect(liga.plantelDe(t.rivales['BOS']!).jugadores.map((j) => j.id), contains(robada.id));
    for (var i = 0; i < 15; i++) {
      t = liga.simularProximo(t);
    }
    expect(t.forma, isNotEmpty);
    expect(t.forma.values.every((f) => f >= -3 && f <= 3 && f != 0), isTrue);
    expect(Temporada.fromJson(t.toJson()).forma, t.forma);
  });
}
