import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/medidor_tiro.dart';
import 'package:dinastia_nba/presentation/modos/minijuego_timing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final carrera = CarreraJugador(Liga(catalogo, franquicias, azar: Random(12)));
  EstadoCarrera nuevo() => carrera.estadoCreado(
    raiz: 'mj1',
    creado: JugadorCreado(
      nombre: 'Nico Vera',
      posicion: Posicion.escolta,
      rol: RolCancha.especialista3D,
      fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
    ),
    pick: 5,
    franquiciaId: 'CHI',
  );
  RondaTiming ronda(List<CalidadTiro> q) => RondaTiming(q);
  final todosPerfectos = ronda(List.filled(5, CalidadTiro.perfecto));

  group('entrenamiento interactivo', () {
    test('los puntos de habilidad dependen de cómo sale y solo hay una sesión por temporada', () {
      final e = nuevo();
      expect(EntrenamientoInteractivo.premioPH(ronda(List.filled(5, CalidadTiro.tarde))), 0);
      expect(EntrenamientoInteractivo.premioPH(ronda([CalidadTiro.perfecto, CalidadTiro.perfecto, CalidadTiro.perfecto, CalidadTiro.tarde, CalidadTiro.tarde])), 1);
      expect(EntrenamientoInteractivo.premioPH(todosPerfectos), 2);
      final n = EntrenamientoInteractivo.aplicar(e, Atributo.tiro, todosPerfectos);
      expect(n.phBanco, e.phBanco + 2);
      expect(n.atributos[Atributo.tiro], e.atributos[Atributo.tiro] + 1, reason: 'cinco perfectos suben el atributo');
      expect(EntrenamientoInteractivo.yaHecho(n), isTrue);
      expect(EntrenamientoInteractivo.aplicar(n, Atributo.tiro, todosPerfectos).phBanco, n.phBanco);
      expect(EntrenamientoInteractivo.yaHecho(e.copyWith(uso: EntrenamientoInteractivo.alCerrar(n.uso))), isFalse);
    });

    test('la zona verde crece con el atributo', () {
      final e = nuevo();
      final fuerte = e.copyWith(atributos: e.atributos.con(Atributo.defensa, 95));
      expect(EntrenamientoInteractivo.ventana(fuerte, Atributo.defensa), greaterThan(EntrenamientoInteractivo.ventana(e, Atributo.defensa)));
    });
  });

  group('concursos del All-Star', () {
    test('solo juegan los elegidos y cada concurso una vez por temporada', () {
      final e = nuevo();
      expect(ConcursosAllStar.disponible(e, false, Concurso.triples), isFalse);
      expect(ConcursosAllStar.disponible(e, true, Concurso.triples), isTrue);
      final r = ConcursosAllStar.resolver(e, Concurso.triples, ronda(List.filled(10, CalidadTiro.perfecto)));
      final n = ConcursosAllStar.aplicar(e, r);
      expect(ConcursosAllStar.disponible(n, true, Concurso.triples), isFalse);
      expect(ConcursosAllStar.disponible(n, true, Concurso.volcadas), isTrue);
    });

    test('el rival es determinista; todo perfecto gana y todo fallado pierde', () {
      final e = nuevo();
      expect(ConcursosAllStar.rivales(e, Concurso.triples), ConcursosAllStar.rivales(e, Concurso.triples));
      final gana = ConcursosAllStar.resolver(e, Concurso.triples, ronda(List.filled(10, CalidadTiro.perfecto)));
      expect(gana.gano, isTrue);
      final pierde = ConcursosAllStar.resolver(e, Concurso.volcadas, ronda(List.filled(5, CalidadTiro.tarde)));
      expect(pierde.gano, isFalse);
      expect(pierde.puesto, 5);
      final v = ConcursosAllStar.resolver(e, Concurso.volcadas, ronda(List.filled(5, CalidadTiro.perfecto)));
      expect(v.tuPuntaje, 50);
    });

    test('ganar suma fans, queda en los hitos y da premio hasta cerrar la temporada', () {
      final e = nuevo();
      final n = ConcursosAllStar.aplicar(e, ConcursosAllStar.resolver(e, Concurso.triples, ronda(List.filled(10, CalidadTiro.perfecto))));
      expect(n.fans, greaterThan(e.fans));
      expect(n.hitos.last, contains('campeón'));
      expect(ConcursosAllStar.premios(n), ['Campeón del concurso de triples']);
      final cerrado = n.copyWith(uso: ConcursosAllStar.alCerrar(n.uso));
      expect(ConcursosAllStar.premios(cerrado), isEmpty);
      expect(cerrado.uso['as:ganados'], 1, reason: 'el total de la carrera se conserva');
    });
  });

  testWidgets('el minijuego recorre los intentos y devuelve una calidad por intento', (t) async {
    RondaTiming? salida;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => salida = await Navigator.of(c).push<RondaTiming>(
                MaterialPageRoute(
                  builder: (_) => const MinijuegoTimingPantalla(titulo: 'Prueba', descripcion: 'd', intentos: 3, ventana: 0.2),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Prueba'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 820)); // casi llena: cerca del centro de la zona
      await t.tapAt(const Offset(200, 300));
      await t.pump(const Duration(milliseconds: 700));
    }
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(salida, isNotNull);
    expect(salida!.intentos, hasLength(3));
  });
}
