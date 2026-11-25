import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/presentation/modos/carrera_equipo_pantallas.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final records = RecordsNba.fromJson(File('assets/database/records_nba.json').readAsStringSync());
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final creado = JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.anotadorTresNiveles,
    fuertes: const [Atributo.tiro, Atributo.finalizacion, Atributo.iq],
  );
  EstadoCarrera nuevo(String raiz) => CarreraJugador(Liga(catalogo, franquicias, azar: Random(1)))
      .estadoCreado(raiz: raiz, creado: creado, pick: 5, franquiciaId: 'CHI');

  FilaRecord? fila(ListaRecords l, String nombre) {
    for (final f in l.filas) {
      if (f.nombre == nombre) return f;
    }
    return null;
  }

  group('los datos reales', () {
    test('traen las marcas históricas que todos conocen (control contra la memoria)', () {
      expect(fila(records.carrera['puntos']!, 'Kareem Abdul-Jabbar')?.valor, 38387);
      expect(fila(records.carrera['rebotes']!, 'Wilt Chamberlain')?.valor, 23924);
      expect(fila(records.carrera['asistencias']!, 'John Stockton')?.valor, 15806);
      expect(fila(records.carrera['robos']!, 'John Stockton')?.valor, 3265);
      expect(fila(records.carrera['tapones']!, 'Hakeem Olajuwon')?.valor, 3830);
      expect(records.carrera['triples']!.record.nombre, 'Stephen Curry');
      expect(fila(records.temporada['puntos']!, 'Wilt Chamberlain')?.valor, 50.36);
      expect(fila(records.temporada['rebotes']!, 'Wilt Chamberlain')?.valor, 27.2);
      expect(fila(records.temporada['asistencias']!, 'John Stockton')?.valor, 14.54);
      expect(fila(records.temporada['tapones']!, 'Mark Eaton')?.valor, 5.56);
      expect(records.partido['puntos']!.record.valor, 100);
      expect(records.partido['puntos']!.record.nombre, 'Wilt Chamberlain');
      expect(records.partido['rebotes']!.record.valor, 55);
      expect(records.partido['asistencias']!.record.valor, 30);
      expect(records.partido['robos']!.record.valor, 11);
      expect(records.partido['tapones']!.record.valor, 17);
      expect(records.partido['triples']!.record.valor, 14);
    });

    test('las listas están ordenadas de mayor a menor y tienen suficiente largo', () {
      for (final seccion in [records.carrera, records.temporada, records.partido]) {
        for (final l in seccion.values) {
          expect(l.filas.length, greaterThanOrEqualTo(10), reason: l.clave);
          for (var i = 1; i < l.filas.length; i++) {
            expect(l.filas[i].valor, lessThanOrEqualTo(l.filas[i - 1].valor), reason: '${l.clave} #$i');
          }
        }
      }
      expect(records.fecha, isNotEmpty);
    });
  });

  group('tu camino', () {
    test('sin marca: sin puesto; con 40.000 puntos: puesto 2 y los de abajo superados', () {
      final l = records.carrera['puntos']!;
      final cero = RecordsCarrera.camino(l, 0);
      expect(cero.puesto, isNull);
      expect(cero.superados, isEmpty);
      final alto = RecordsCarrera.camino(l, 40000, ritmoPorTemporada: 2000);
      expect(alto.puesto, 2, reason: 'solo por debajo de LeBron');
      expect(alto.siguiente!.nombre, 'LeBron James');
      expect(alto.superados.map((f) => f.nombre), contains('Kareem Abdul-Jabbar'));
      expect(alto.progreso, greaterThan(0.9));
      expect(alto.faltan, greaterThan(0));
      expect(alto.temporadasParaSuperar, closeTo(alto.faltan / 2000, 1e-9));
      final record = RecordsCarrera.camino(l, l.record.valor + 1);
      expect(record.puesto, 1);
      expect(record.siguiente, isNull);
      expect(record.progreso, 1);
    });

    test('fuera del top: el próximo objetivo es el último de la lista', () {
      final l = records.carrera['rebotes']!;
      final c = RecordsCarrera.camino(l, 500);
      expect(c.puesto, isNull);
      expect(c.siguiente!.valor, l.filas.last.valor);
    });

    test('los contadores por partido suman lo mismo que la línea de la temporada, y el cierre guarda robos y tapones', () {
      final liga = Liga(catalogo, franquicias, azar: Random(2));
      final carrera = CarreraJugador(liga);
      var t = carrera.nuevaCarrera(estado: nuevo('rc1'), dificultad: Dificultad.normal);
      while (liga.proximoDelUsuario(t) != null) {
        t = liga.simularProximo(t);
      }
      t = liga.simularRestoPlayoffs(liga.simularOtrosHasta(carrera.alGuardar(t), 1 << 30));
      t = carrera.alGuardar(t);
      final e = EstadoCarrera.de(t)!;
      final l = t.lineas[e.jugadorId]!;
      // Con playoffs incluidos, los contadores de carrera son al menos lo de la temporada regular.
      expect(e.uso['c:pts'], greaterThanOrEqualTo(l.pts));
      expect(e.uso['c:reb'], greaterThanOrEqualTo(l.reb));
      expect(e.uso['c:t3'], greaterThanOrEqualTo(l.t3I));
      expect(RecordsCarrera.totalCarrera(e, 'puntos'), greaterThanOrEqualTo(l.pts));
      expect(e.uso['m:pts'], greaterThan(0));
      expect(RecordsCarrera.marcaPartido(e, 'puntos'), e.uso['m:pts']);
      final c = carrera.cerrar(t, e, (id) => franquiciaPorId(id).nombreCompleto);
      expect(RecordsCarrera.mejorTemporada(c.estado, 'puntos'), closeTo(c.temporada.pts, 1e-9));
      expect(RecordsCarrera.mejorTemporada(c.estado, 'robos'), greaterThanOrEqualTo(0));
      expect(c.estado.uso.containsKey('b:rob100'), isTrue);
      final caminos = RecordsCarrera.carrera(records, c.estado);
      expect(caminos.length, 7);
      expect(RecordsCarrera.hitos(c.estado).length, 5);
    });

    test('las partidas viejas (solo historial) cuentan por el mayor entre el historial y los contadores', () {
      final e = nuevo('rc2').copyWith(
        historial: [
          for (var i = 1; i <= 3; i++)
            TemporadaJugador(
              numero: i,
              etiqueta: '$i',
              franquiciaId: 'CHI',
              edad: 20 + i,
              media: 80,
              pj: 80,
              pts: 25,
              reb: 6,
              ast: 5,
              victorias: 50,
              derrotas: 32,
              resultado: '',
            ),
        ],
      );
      expect(RecordsCarrera.totalCarrera(e, 'puntos'), 3 * 80 * 25);
      expect(RecordsCarrera.totalCarrera(e.copyWith(uso: {'c:pts': 9000}), 'puntos'), 9000);
      expect(RecordsCarrera.totalCarrera(e, 'robos'), 0);
      expect(RecordsCarrera.mejorTemporada(e, 'asistencias'), 5);
    });
  });

  testWidgets('la pantalla muestra récord, tu puesto y las solapas', (t) async {
    t.view.physicalSize = const Size(412, 900) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final e = nuevo('rc3').copyWith(uso: {'c:pts': 30000, 'c:p40': 4, 'm:pts': 61});
    await t.pumpWidget(
      MaterialApp(theme: temaFranquicia(franquiciaPorId('CHI')), home: RecordsPantalla(estado: e, records: records)),
    );
    await t.pumpAndSettle();
    expect(find.text('Camino a los récords'), findsOneWidget);
    expect(find.text('CARRERA'), findsOneWidget);
    expect(find.textContaining('Récord: LeBron James'), findsOneWidget);
    expect(find.textContaining('Ocuparías el puesto n.º'), findsWidgets);
    expect(find.textContaining('YA SUPERASTE A'), findsOneWidget);
    await t.tap(find.text('PARTIDO'));
    await t.pumpAndSettle();
    expect(find.textContaining('Wilt Chamberlain'), findsWidgets);
    await t.tap(find.text('HITOS'));
    await t.pumpAndSettle();
    expect(find.text('Partidos de 40 puntos o más'), findsOneWidget);
  });
}
