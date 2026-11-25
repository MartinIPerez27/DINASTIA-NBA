import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(5));
  final carrera = CarreraJugador(liga);
  final creado = JugadorCreado(
    nombre: 'Tomás Ruiz',
    posicion: Posicion.alero,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
  );

  (Temporada, EstadoCarrera) nueva() {
    final e = carrera.estadoCreado(raiz: 'cu', creado: creado, pick: 5, franquiciaId: 'CHI');
    final t = carrera.nuevaCarrera(estado: e, dificultad: Dificultad.normal);
    return (t, EstadoCarrera.de(t)!);
  }

  group('carga', () {
    test('jugar mucho la sube, descansar la baja y nunca sale de 0-100', () {
      var c = 0;
      for (var i = 0; i < 200; i++) {
        c = CuerpoCarrera.nuevaCarga(c, 40 * 60);
      }
      expect(c, 100);
      expect(CuerpoCarrera.nuevaCarga(50, 0), lessThan(50));
      expect(CuerpoCarrera.nuevaCarga(0, 0), 0);
      expect(CuerpoCarrera.nuevaCarga(50, 20 * 60), lessThan(50), reason: 'pocos minutos no cargan');
    });

    test('con carga alta se lesiona más: el factor crece hasta ×1,8 sobre el base', () {
      final (_, e) = nueva();
      final base = CuerpoCarrera.factor(e);
      final cargado = CuerpoCarrera.factor(e.copyWith(uso: {...e.uso, 'cu:carga': 100}));
      expect(cargado, closeTo(base * 1.8, 0.001));
      expect(CuerpoCarrera.factor(e.copyWith(uso: {...e.uso, 'cu:carga': 30})), base);
    });

    test('el historial de lesiones suma propensión (hasta ×1,3)', () {
      final (_, e) = nueva();
      final base = CuerpoCarrera.factor(e);
      expect(CuerpoCarrera.factor(e.copyWith(uso: {...e.uso, 'cu:total': 2})), closeTo(base * 1.1, 0.001));
      expect(CuerpoCarrera.factor(e.copyWith(uso: {...e.uso, 'cu:total': 20})), closeTo(base * 1.3, 0.001));
    });
  });

  group('lesiones y rehabilitación', () {
    test('una lesión nueva recibe parte del cuerpo, partidos de baja y queda en el historial', () {
      final (t, e) = nueva();
      final conBaja = t.copyWith(lesiones: {...t.lesiones, e.jugadorId: 6});
      final (t2, e2) = CuerpoCarrera.alPartido(conBaja, e, 0, 3);
      final parte = CuerpoCarrera.activa(e2);
      expect(parte, isNotNull);
      expect(CuerpoCarrera.total(e2), 1);
      expect(CuerpoCarrera.veces(e2, parte!), 1);
      expect(t2.lesiones[e.jugadorId], greaterThanOrEqualTo(1));
      expect(e2.movimientos.last, contains(parte.etiqueta.toLowerCase()));
      // Con la misma lesión sigue igual: no se cuenta dos veces.
      final (_, e3) = CuerpoCarrera.alPartido(t2, e2, 0, 4);
      expect(CuerpoCarrera.total(e3), 1);
    });

    test('la rehabilitación cuidadosa alarga la baja y la acelerada la acorta; se elige una sola vez', () {
      (int, int, int) bajas() {
        final (t, e) = nueva();
        final (t1, e1) = CuerpoCarrera.alPartido(t.copyWith(lesiones: {e.jugadorId: 10}), e, 0, 1);
        final base = t1.lesiones[e.jugadorId]!;
        final c = CuerpoCarrera.elegirRehab(t1, e1, Rehab.cuidadosa).$1.lesiones[e.jugadorId]!;
        final a = CuerpoCarrera.elegirRehab(t1, e1, Rehab.acelerada).$1.lesiones[e.jugadorId]!;
        return (base, c, a);
      }

      final (base, cuidadosa, acelerada) = bajas();
      expect(cuidadosa, greaterThan(base));
      expect(acelerada, lessThan(base));
      final (t, e) = nueva();
      final (t1, e1) = CuerpoCarrera.alPartido(t.copyWith(lesiones: {e.jugadorId: 10}), e, 0, 1);
      final (t2, e2) = CuerpoCarrera.elegirRehab(t1, e1, Rehab.acelerada);
      final (t3, _) = CuerpoCarrera.elegirRehab(t2, e2, Rehab.cuidadosa);
      expect(t3.lesiones[e.jugadorId], t2.lesiones[e.jugadorId], reason: 'ya está elegida');
    });

    test('al recuperarte se cierra la lesión; con rehab acelerada a veces recaés, con la normal nunca', () {
      var recaidas = 0, normales = 0;
      for (var n = 0; n < 60; n++) {
        for (final r in [Rehab.acelerada, Rehab.normal]) {
          final (t, e) = nueva();
          final (t1, e1) = CuerpoCarrera.alPartido(t.copyWith(lesiones: {e.jugadorId: 4}), e, 0, n);
          final (t2, e2) = CuerpoCarrera.elegirRehab(t1, e1, r);
          final alta = t2.copyWith(lesiones: Map.of(t2.lesiones)..remove(e.jugadorId));
          final (t3, e3) = CuerpoCarrera.alPartido(alta, e2, 0, n + 10);
          if (t3.lesiones.containsKey(e.jugadorId)) {
            expect(CuerpoCarrera.activa(e3), isNotNull);
            r == Rehab.acelerada ? recaidas++ : normales++;
          } else {
            expect(CuerpoCarrera.activa(e3), isNull);
          }
        }
      }
      expect(normales, 0);
      expect(recaidas, inInclusiveRange(5, 35), reason: '≈30 % de 60');
    });

    test('lo ya lastimado se repite y se vuelve crónico a la tercera', () {
      final (_, e) = nueva();
      final cr = e.copyWith(uso: {...e.uso, 'cu:p${ParteCuerpo.rodilla.index}': 3});
      expect(CuerpoCarrera.cronicas(cr), [ParteCuerpo.rodilla]);
      expect(CuerpoCarrera.cronicas(e), isEmpty);
    });
  });

  group('descanso', () {
    test('solo con carga alta y sano: te deja un partido afuera y baja la carga a la mitad', () {
      final (t, e) = nueva();
      expect(CuerpoCarrera.puedeDescansar(t, e), isFalse);
      final c = e.copyWith(uso: {...e.uso, 'cu:carga': 80});
      expect(CuerpoCarrera.puedeDescansar(t, c), isTrue);
      final (t2, e2) = CuerpoCarrera.descansar(t, c);
      expect(t2.lesiones[e.jugadorId], 1);
      expect(CuerpoCarrera.carga(e2), 40);
      expect(CuerpoCarrera.puedeDescansar(t2, e2), isFalse);
    });
  });

  group('en la liga', () {
    test('el hook de Liga multiplica la chance de TU jugador y de nadie más', () {
      final (t, e) = nueva();
      final cargado = carrera.sincronizar(t, e.copyWith(uso: {...e.uso, 'cu:carga': 100}));
      expect(liga.factorLesionJugador!(cargado, e.jugadorId), greaterThan(1.3));
      expect(liga.factorLesionJugador!(cargado, 'otro'), 1.0);
    });

    test('un cargado se lesiona más que uno descansado en la misma temporada', () {
      int lesiones(int carga) {
        var total = 0;
        for (var s = 0; s < 6; s++) {
          final l = Liga(catalogo, franquicias, azar: Random(40 + s));
          final c = CarreraJugador(l);
          final e0 = c.estadoCreado(raiz: 'x$s', creado: creado, pick: 5, franquiciaId: 'CHI');
          var t = c.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
          final e = EstadoCarrera.de(t)!;
          final propios = t.calendario.where((p) => p.participa(t.franquiciaUsuarioId) && p.jornada > 0).take(60);
          for (final p in propios) {
            final cargada = c.sincronizar(
              t,
              EstadoCarrera.de(t)!.copyWith(uso: {...EstadoCarrera.de(t)!.uso, 'cu:carga': carga}),
            );
            final m = l.motor(cargada, p, azar: Random(p.id.hashCode))..simularTodo();
            t = l.registrar(cargada, p, m);
          }
          total += EstadoCarrera.de(t)!.uso['cu:total'] ?? 0;
          expect(e.jugadorId, isNotEmpty);
        }
        return total;
      }

      expect(lesiones(100), greaterThanOrEqualTo(lesiones(0)));
    });
  });
}
