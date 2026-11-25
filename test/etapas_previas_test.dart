import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/presentation/modos/etapas_previas_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final carrera = CarreraJugador(Liga(catalogo, franquicias, azar: Random(14)));
  final jc = JugadorCreado(
    nombre: 'Dani Soto',
    posicion: Posicion.base,
    rol: JugadorCreado.rolesDe(Posicion.base).first,
    fuertes: const [Atributo.tiro, Atributo.iq, Atributo.defensa],
  );

  test('es determinista y arma 3 años de secundario más los de universidad', () {
    final a = EtapasPrevias.simular(jc, 77, aniosUniversidad: 2);
    final b = EtapasPrevias.simular(jc, 77, aniosUniversidad: 2);
    expect(a.temporadas.length, 5);
    expect([for (final t in a.temporadas) t.etapa], ['Secundario', 'Secundario', 'Secundario', 'Universidad', 'Universidad']);
    expect(a.pick, b.pick);
    expect(a.ranking, b.ranking);
    expect(a.hitos, b.hitos);
    expect(a.ranking, inInclusiveRange(1, 150));
    expect(a.pick, inInclusiveRange(1, 60));
    expect(a.hitos.any((h) => h.contains('ranking de reclutas')), isTrue);
    expect(a.hitos.last, contains('draft'));
  });

  test('más años de universidad: más atributos y más edad; saltar directo da la edad mínima', () {
    final directo = EtapasPrevias.simular(jc, 5, aniosUniversidad: 0).creado;
    final uno = EtapasPrevias.simular(jc, 5, aniosUniversidad: 1).creado;
    final tres = EtapasPrevias.simular(jc, 5, aniosUniversidad: 3).creado;
    expect(directo.edadInicial, 18);
    expect(uno.edadInicial, 19);
    expect(tres.edadInicial, 21);
    expect(tres.media, greaterThan(uno.media));
    expect(uno.media, greaterThanOrEqualTo(directo.media));
    expect(tres.error, isNull);
  });

  test('las medias de cada año suben hasta la del draft y las estadísticas son razonables', () {
    final c = EtapasPrevias.simular(jc, 9, aniosUniversidad: 3);
    final medias = [for (final t in c.temporadas) t.media];
    for (var i = 1; i < medias.length; i++) {
      expect(medias[i], greaterThanOrEqualTo(medias[i - 1]));
    }
    expect(medias.last, lessThanOrEqualTo(c.creado.media));
    for (final t in c.temporadas) {
      expect(t.pts, inInclusiveRange(8, 38));
      expect(t.reb, greaterThanOrEqualTo(0));
    }
  });

  test('el pick fijado pasa por el combine y por el estado de la carrera con el camino en la historia', () {
    final c = EtapasPrevias.simular(jc, 21, aniosUniversidad: 1);
    expect(carrera.combine(c.creado, Random(1)).pick, c.pick);
    final e = carrera.estadoCreado(raiz: 'ep1', creado: c.creado, pick: c.pick, franquiciaId: 'CHI');
    expect(e.edad, c.creado.edadInicial);
    expect(e.pick, c.pick);
  });

  testWidgets('la pantalla muestra el camino y devuelve el elegido', (t) async {
    t.view.physicalSize = const Size(412, 1800) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    CaminoPrevio? salida;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => salida = await Navigator.of(c).push<CaminoPrevio>(
                MaterialPageRoute(builder: (_) => EtapasPreviasPantalla(creado: jc, semilla: 3)),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.textContaining('Secundario'), findsWidgets);
    await t.tap(find.text('3 años'));
    await t.pumpAndSettle();
    expect(find.textContaining('Universidad'), findsWidgets);
    await t.tap(find.text('IR AL COMBINE Y AL DRAFT'));
    await t.pumpAndSettle();
    expect(salida, isNotNull);
    expect(salida!.temporadas.length, 6);
  });
}
