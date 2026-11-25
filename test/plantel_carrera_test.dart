import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  JugadorCreado creado({int? anio, int? edad, int dorsal = 0}) => JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
    anioDraft: anio,
    edadInicial: edad,
    nacimiento: anio == null || edad == null ? null : anio - edad,
    dorsal: dorsal,
  );

  group('arranque a elección', () {
    test('el año, la edad y el número viajan con el jugador y definen época y carta', () {
      final liga = Liga(catalogo, franquicias, azar: Random(1));
      final carrera = CarreraJugador(liga);
      final c = JugadorCreado.fromJson(jsonDecode(jsonEncode(creado(anio: 1995, edad: 23, dorsal: 23).toJson())) as Map<String, dynamic>);
      expect((c.anioDraft, c.edadInicial, c.dorsal), (1995, 23, 23));
      final e = carrera.estadoCreado(raiz: 'a1', creado: c, pick: 5, franquiciaId: 'CHI');
      expect(e.anioBase, 1995);
      expect(e.edad, 23);
      expect(e.epoca, Epoca.anios90);
      expect(e.carta.dorsal, 23);
      final sinElegir = carrera.estadoCreado(raiz: 'a2', creado: creado(), pick: 5, franquiciaId: 'CHI');
      expect((sinElegir.anioBase, sinElegir.edad, sinElegir.carta.dorsal), (2026, 20, 0), reason: 'partidas viejas igual');
    });
  });

  group('plantilla con edad y contratos', () {
    test('cada compañero arranca con contrato de 1 a 4 años y la edad sale del año', () {
      final liga = Liga(catalogo, franquicias, azar: Random(2));
      final carrera = CarreraJugador(liga);
      final e0 = carrera.estadoCreado(raiz: 'p1', creado: creado(anio: 2005, edad: 20), pick: 8, franquiciaId: 'DAL');
      final t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      final e = EstadoCarrera.de(t)!;
      expect(e.companeros.length, CarreraJugador.maxCompaneros);
      for (final j in e.companeros) {
        expect(PlantelCarrera.contratoDe(e, j), inInclusiveRange(1, 4));
        expect(PlantelCarrera.edadEn(j, 2006), inInclusiveRange(17, 45));
      }
    });

    test('los retiros solo llegan con la edad y la rotación es determinística', () {
      expect(PlantelCarrera.probabilidadRetiro(30), 0);
      expect(PlantelCarrera.probabilidadRetiro(34), 0);
      expect(PlantelCarrera.probabilidadRetiro(37), greaterThan(PlantelCarrera.probabilidadRetiro(35)));
      expect(PlantelCarrera.probabilidadRetiro(42), lessThanOrEqualTo(0.95));
      final liga = Liga(catalogo, franquicias, azar: Random(3));
      final carrera = CarreraJugador(liga);
      final e = EstadoCarrera.de(
        carrera.nuevaCarrera(
          estado: carrera.estadoCreado(raiz: 'p2', creado: creado(anio: 2010, edad: 20), pick: 8, franquiciaId: 'LAL'),
          dificultad: Dificultad.normal,
        ),
      )!;
      RotacionPlantel r(int semilla) => PlantelCarrera.rotar(
        e,
        Random(semilla),
        anio: 2012,
        nombreDe: (id) => id,
        franquicias: const ['BOS', 'MIA'],
      );
      expect(r(1).quedan.map((j) => j.id), r(1).quedan.map((j) => j.id));
      expect(r(1).movimientos, r(1).movimientos);
      expect(r(1).quedan.length + r(1).movimientos.length, e.companeros.length);
    });

    test('varias temporadas: el plantel se mantiene en 7, queda el registro de movimientos y hay contratos nuevos', () {
      final liga = Liga(catalogo, franquicias, azar: Random(4));
      final carrera = CarreraJugador(liga);
      var t = carrera.nuevaCarrera(
        estado: carrera.estadoCreado(raiz: 'p3', creado: creado(anio: 2000, edad: 19), pick: 4, franquiciaId: 'SAS'),
        dificultad: Dificultad.normal,
      );
      for (var n = 1; n <= 4; n++) {
        while (liga.proximoDelUsuario(t) != null) {
          t = liga.simularProximo(t);
        }
        t = liga.simularRestoPlayoffs(liga.simularOtrosHasta(carrera.alGuardar(t), 1 << 30));
        t = carrera.alGuardar(t);
        final e = EstadoCarrera.de(t)!;
        final c = carrera.cerrar(t, e, (id) => franquiciaPorId(id).nombreCompleto);
        t = carrera.siguiente(t, c.estado);
      }
      final e = EstadoCarrera.de(t)!;
      expect(e.companeros.length, CarreraJugador.maxCompaneros);
      expect(e.movimientos, isNotEmpty);
      expect(e.movimientos.any((m) => m.contains('llega')), isTrue, reason: 'cada baja trae un reemplazo');
      for (final j in e.companeros) {
        expect(e.uso.containsKey('ct:${j.id}'), isTrue, reason: j.nombre);
      }
      final r = EstadoCarrera.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>);
      expect(r.movimientos, e.movimientos);
    });
  });

  group('fecha límite de traspasos', () {
    test('rumor en el partido 35, decisión en el 49 y la elección tiene consecuencias', () {
      final liga = Liga(catalogo, franquicias, azar: Random(5));
      final carrera = CarreraJugador(liga);
      var t = carrera.nuevaCarrera(
        estado: carrera.estadoCreado(raiz: 'f1', creado: creado(), pick: 12, franquiciaId: 'MIA'),
        dificultad: Dificultad.normal,
      );
      var vistoRumor = false;
      while ((EstadoCarrera.de(t)!.uso['sc:pj'] ?? 0) < 50) {
        if (liga.proximoDelUsuario(t) == null) break;
        t = liga.simularProximo(t);
        final e = EstadoCarrera.de(t)!;
        if ((e.uso['sc:pj'] ?? 0) >= CarreraJugador.partidoRumor && (e.uso['sc:pj'] ?? 0) < CarreraJugador.partidoFechaLimite) {
          vistoRumor = vistoRumor || e.movimientos.any((m) => m.contains('Rumor'));
        }
      }
      var e = EstadoCarrera.de(t)!;
      expect(vistoRumor, isTrue);
      expect(e.uso['tr:pend'], 1);
      expect(e.companeros.length, CarreraJugador.maxCompaneros);
      final pide = carrera.resolverFechaLimite(e, OpcionFechaLimite.pedirTraspaso);
      expect(pide.pidioTraspaso, isTrue);
      expect(pide.uso.containsKey('tr:pend'), isFalse);
      expect(pide.relacion, lessThan(e.relacion));
      final ext = carrera.resolverFechaLimite(e, OpcionFechaLimite.extender);
      expect(ext.contrato, e.contrato + 1);
      expect(ext.confianza, greaterThan(e.confianza));
      expect(carrera.resolverFechaLimite(pide, OpcionFechaLimite.extender).contrato, pide.contrato, reason: 'ya resuelta');
      e = carrera.resolverFechaLimite(e, OpcionFechaLimite.quedarme);
      expect(e.uso['tr:hecho'], 1);
    });
  });

  group('mi generación', () {
    EstadoCarrera estado(int anio) {
      final liga = Liga(catalogo, franquicias, azar: Random(6));
      return CarreraJugador(liga).estadoCreado(raiz: 'g$anio', creado: creado(anio: anio, edad: 20), pick: 5, franquiciaId: 'CHI');
    }

    test('con datos reales: los primeros elegidos de ese draft, ordenados, y su línea de cada año', () {
      final e = estado(1996);
      final clase = GeneracionCarrera.clase(catalogo, e);
      expect(clase.length, GeneracionCarrera.tamano);
      expect(clase.every((c) => !c.ficticio), isTrue);
      expect([for (final c in clase) c.pick], ([for (final c in clase) c.pick]..sort()));
      expect(clase.first.pick, 1);
      final l = GeneracionCarrera.lineaEn(clase.first, 2000, anioDraft: 1996);
      expect(l, isNotNull);
      expect(GeneracionCarrera.lineaEn(clase.first, 1996, anioDraft: 1996), isNull, reason: 'todavía no juega');
    });

    test('draft 2026: los elegidos reales (ya se jugó el draft) con números proyectados y determinísticos', () {
      final real = GeneracionCarrera.deJson2026(File('assets/database/draft_2026.json').readAsStringSync());
      expect(real.length, 60);
      expect([for (final c in real) c.pick], List.generate(60, (i) => i + 1));
      final e = estado(2026);
      final clase = GeneracionCarrera.clase(catalogo, e, clase2026: real);
      expect(clase.length, GeneracionCarrera.tamano);
      expect(clase.first.nombre, 'AJ Dybantsa');
      expect(clase.every((c) => !c.ficticio && c.proyectado && c.equipo != null), isTrue);
      final c = clase.first;
      final l3 = GeneracionCarrera.lineaEn(c, 2029, anioDraft: 2026)!;
      expect(l3.pts, greaterThan(2));
      expect(GeneracionCarrera.lineaEn(c, 2029, anioDraft: 2026)!.pts, l3.pts, reason: 'determinístico');
      expect(GeneracionCarrera.lineaEn(c, 2045, anioDraft: 2026)!.retirado, isTrue);
      expect(GeneracionCarrera.lineaEn(c, 2026, anioDraft: 2026), isNull);
    });

    test('un año sin datos de nadie cae en una clase ficticia (por si acaso)', () {
      final e = estado(2026);
      final a = GeneracionCarrera.clase(catalogo, e), b = GeneracionCarrera.clase(catalogo, e);
      expect(a.any((c) => c.ficticio), isTrue, reason: 'sin la clase real cargada');
      expect([for (final c in a) c.nombre], [for (final c in b) c.nombre]);
    });
  });
}
