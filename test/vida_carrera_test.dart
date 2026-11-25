import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/estilo_creado.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/vida_carrera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(3));
  final carrera = CarreraJugador(liga);
  final creado = JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.escolta,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
    // Personalidad neutra para estas cuentas (el Showman y el Líder suman un poco a las decisiones).
    estilo: const EstiloCreado(personalidad: Personalidad.profesional),
  );
  EstadoCarrera nuevo() =>
      carrera.estadoCreado(raiz: 'v1', creado: creado, pick: 10, franquiciaId: 'CHI', potencial: 90);

  TemporadaJugador temp(int n, String f, {bool campeon = false, bool allStar = false, double pts = 20}) =>
      TemporadaJugador(
        numero: n,
        etiqueta: '20${20 + n}',
        franquiciaId: f,
        edad: 20 + n,
        media: 80,
        pj: 70,
        pts: pts,
        reb: 5,
        ast: 4,
        victorias: 45,
        derrotas: 37,
        resultado: '',
        campeon: campeon,
        allStar: allStar,
      );

  group('rutina', () {
    test('elegir rutina se guarda y suma un punto gratis al atributo al cerrar el año', () {
      var e = nuevo();
      expect(VidaCarrera.rutinaDe(e), isNull);
      e = VidaCarrera.elegirRutina(e, Rutina.tiro);
      expect(VidaCarrera.rutinaDe(e), Rutina.tiro);
      expect(VidaCarrera.efectoRutina(e), {Atributo.tiro: 1});
      expect(VidaCarrera.efectoRutina(VidaCarrera.elegirRutina(e, Rutina.recuperacion)), isEmpty);
      expect(VidaCarrera.factorLesion(VidaCarrera.elegirRutina(e, Rutina.recuperacion)), lessThan(0.5));
      final r = EstadoCarrera.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>);
      expect(VidaCarrera.rutinaDe(r), Rutina.tiro);
    });
  });

  group('eventos', () {
    test('hay un evento por temporada, es determinístico y no se repite', () {
      var e = nuevo();
      final ev = VidaCarrera.eventoPara(e);
      expect(ev, isNotNull);
      expect(VidaCarrera.eventoPara(e)?.id, ev!.id);
      e = VidaCarrera.resolver(e, ev, 0);
      expect(VidaCarrera.eventoPara(e), isNull, reason: 'ya lo resolviste este año');
      e = e.copyWith(numero: e.numero + 1);
      final otro = VidaCarrera.eventoPara(e);
      expect(otro, isNotNull);
      expect(otro!.id, isNot(ev.id), reason: 'no repite');
    });

    test('responder cambia el ánimo, los fans, la relación y los puntos, sin pasarse de los límites', () {
      final e0 = nuevo().copyWith(moral: 50, fans: 50, relacion: 50, confianza: 50, phBanco: 2);
      for (final ev in VidaCarrera.catalogo) {
        for (var i = 0; i < ev.opciones.length; i++) {
          final o = ev.opciones[i];
          final e = VidaCarrera.resolver(e0, ev, i);
          expect(e.moral, (50 + o.moral).clamp(0, 100), reason: ev.id);
          expect(e.fans, (50 + o.fans).clamp(0, 100), reason: ev.id);
          expect(e.relacion, (50 + o.relacion).clamp(0, 100), reason: ev.id);
          expect(e.phBanco, max(0, 2 + o.ph), reason: ev.id);
          expect(e.hitos.last, contains(ev.titulo));
          expect(e.uso['e:${ev.id}'], 1);
        }
      }
      expect(VidaCarrera.catalogo.length, greaterThanOrEqualTo(10));
      for (final ev in VidaCarrera.catalogo) {
        expect(ev.opciones.length, inInclusiveRange(2, 3));
      }
    });

    test('los eventos respetan su condición (el bajón de ánimo solo si estás mal)', () {
      final bien = nuevo().copyWith(moral: 90);
      for (var n = 1; n < 12; n++) {
        expect(VidaCarrera.eventoPara(bien.copyWith(numero: n))?.id, isNot('bajon'));
      }
    });
  });

  group('marca y legado', () {
    test('los patrocinios se desbloquean con lo que lográs', () {
      var e = nuevo().copyWith(fans: 50);
      expect(VidaCarrera.patrocinios(e), [Patrocinio.zapatillasLocales]);
      e = e.copyWith(fans: 80, historial: [temp(1, 'CHI', campeon: true, allStar: true)]);
      expect(VidaCarrera.patrocinios(e), containsAll([Patrocinio.marcaGlobal, Patrocinio.bebidaEnergetica]));
      expect(VidaCarrera.marca(e), greaterThan(VidaCarrera.marca(nuevo())));
      expect(VidaCarrera.fansPorPatrocinios(e), inInclusiveRange(1, 3));
    });

    test('la camiseta se retira en el club donde jugaste 6 años con huella; no en el de paso', () {
      final l = LegadoCarrera('X', [
        for (var i = 1; i <= 7; i++) temp(i, 'CHI', allStar: i <= 2),
        temp(8, 'BOS'),
        temp(9, 'LAL'),
      ]);
      final c = VidaCarrera.camisetas(l);
      expect(c.map((x) => x.franquiciaId), ['CHI']);
      expect(c.first.temporadas, 7);
      expect(VidaCarrera.camisetas(LegadoCarrera('Y', [for (var i = 1; i <= 7; i++) temp(i, 'CHI')])), isEmpty);
    });

    test('los récords personales son la mejor temporada en cada rubro', () {
      final l = LegadoCarrera('X', [temp(1, 'CHI', pts: 18), temp(2, 'CHI', pts: 31), temp(3, 'CHI', pts: 25)]);
      final r = VidaCarrera.records(l);
      expect(r.first.etiqueta, contains('Puntos'));
      expect(r.first.valor, 31);
      expect(VidaCarrera.records(const LegadoCarrera('Z', [])), isEmpty);
    });

    test('el epílogo cuenta qué pasa después: Salón, camiseta y un camino al retirarse', () {
      final e = nuevo().copyWith(
        retirado: true,
        historial: [for (var i = 1; i <= 12; i++) temp(i, 'CHI', campeon: i % 3 == 0, allStar: true)],
      );
      final lineas = VidaCarrera.epilogo(e);
      expect(lineas, isNotEmpty);
      expect(lineas.any((x) => x.contains('retira tu camiseta')), isTrue);
      expect(lineas.any((x) => x.contains('Salón')), isTrue);
      expect(VidaCarrera.epilogo(e), lineas, reason: 'determinístico');
    });
  });

  group('arquetipo', () {
    test('las habilidades de tu arquetipo salen más baratas', () {
      final e = nuevo().copyWith(phBanco: 100);
      final afin = VidaCarrera.afines(RolCancha.especialista3D);
      expect(afin, contains(Habilidad.triple));
      final noAfin = Habilidad.values.firstWhere((h) => !afin.contains(h) && h.atributo == Atributo.tiro);
      final base = ModeloCarrera.costo(Habilidad.valor(noAfin, e.atributos, e.espec));
      final propio = ModeloCarrera.costo(Habilidad.valor(Habilidad.triple, e.atributos, e.espec));
      expect(carrera.costoHabilidad(e, Habilidad.triple), lessThanOrEqualTo((propio / 2).ceil()));
      expect(carrera.costoHabilidad(e, noAfin), (base / 2).ceil().clamp(1, 99));
    });
    test('todos los arquetipos tienen tres habilidades afines', () {
      for (final r in RolCancha.values) {
        expect(VidaCarrera.afines(r).length, 3, reason: r.name);
      }
    });
  });
}
