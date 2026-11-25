import 'dart:convert';
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
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
  );
  EstadoCarrera nuevo() => carrera.estadoCreado(raiz: 'o1', creado: creado, pick: 10, franquiciaId: 'CHI', potencial: 90);
  EstadoCarrera conOfrecidos() {
    final e = nuevo();
    final o = ObjetivosCarrera.ofrecer(e, Random(1));
    return e.copyWith(ofrecidos: o, objetivos: ObjetivosCarrera.porDefecto(o));
  }

  group('ofrecidos de temporada', () {
    test('son 8 de todas las familias, de varios niveles y sin repetir tipo', () {
      for (var seed = 0; seed < 30; seed++) {
        final o = ObjetivosCarrera.ofrecer(nuevo(), Random(seed));
        expect(o.length, ObjetivosCarrera.cantidadOfrecida);
        expect(o.map((x) => x.tipo).toSet().length, o.length, reason: 'seed $seed: sin repetidos');
        expect(o.map((x) => x.tipo.familia).toSet(), containsAll(FamiliaObjetivo.values));
        expect(o.map((x) => x.nivel).toSet().length, greaterThanOrEqualTo(3), reason: 'varios niveles');
        for (final x in o) {
          expect(x.meta, greaterThan(0), reason: x.texto);
          expect(x.texto, isNotEmpty);
        }
      }
    });

    test('hay 20 o más tipos de objetivo en 4 familias, y todos tienen texto y avance', () {
      expect(TipoObjetivo.values.length, greaterThanOrEqualTo(20));
      const m = MarcaTemporada(pj: 50, ppg: 20, rpg: 5, apg: 4, defensaPorPartido: 2, victorias: 40, derrotas: 10);
      for (final t in TipoObjetivo.values) {
        final o = ObjetivoTemporada(t, 1);
        expect(o.texto, isNotEmpty);
        o.avance(m);
      }
    });

    test('por defecto se aceptan 4 de los más fáciles; se puede elegir entre 4 y 6 hasta jugar', () {
      final e = conOfrecidos();
      expect(e.objetivos.length, 4);
      expect(e.objetivos.every((o) => o.nivel.index <= NivelObjetivo.normal.index || e.ofrecidos.where((x) => x.nivel.index <= 1).length < 4), isTrue);
      expect(ObjetivosCarrera.puedeElegir(e), isTrue);
      final seis = ObjetivosCarrera.elegir(e, {0, 1, 2, 3, 4, 5});
      expect(seis.objetivos.length, 6);
      expect(ObjetivosCarrera.elegir(e, {0, 1, 2}).objetivos.length, 4, reason: 'menos de 4: no cambia');
      expect(ObjetivosCarrera.elegir(e, {0, 1, 2, 3, 4, 5, 6}).objetivos.length, 4, reason: 'más de 6: no cambia');
      final jugado = e.copyWith(uso: {'sc:pj': 1});
      expect(ObjetivosCarrera.puedeElegir(jugado), isFalse);
      expect(ObjetivosCarrera.elegir(jugado, {0, 1, 2, 3, 4}).objetivos.length, 4);
    });

    test('los puntos dependen del nivel (1, 2, 4 y 6)', () {
      expect([for (final n in NivelObjetivo.values) n.puntos], [1, 2, 4, 6]);
      const f = ObjetivoTemporada(TipoObjetivo.puntos, 20, nivel: NivelObjetivo.facil);
      const d = ObjetivoTemporada(TipoObjetivo.puntos, 25, nivel: NivelObjetivo.dificil);
      const x = ObjetivoTemporada(TipoObjetivo.campeon, 1, nivel: NivelObjetivo.elite);
      expect(ObjetivosCarrera.puntosDe([(f, true), (d, false), (x, true)]), 7);
    });

    test('las metas suben con el nivel y los objetivos se guardan con su nivel', () {
      final e = nuevo();
      for (final t in [TipoObjetivo.puntos, TipoObjetivo.rebotes, TipoObjetivo.victorias, TipoObjetivo.tiroCampo]) {
        final metas = [for (final n in NivelObjetivo.values) ObjetivosCarrera.meta(t, n, e)];
        for (var i = 1; i < metas.length; i++) {
          expect(metas[i], greaterThanOrEqualTo(metas[i - 1]), reason: t.name);
        }
      }
      final r = EstadoCarrera.fromJson(jsonDecode(jsonEncode(conOfrecidos().toJson())) as Map<String, dynamic>);
      expect(r.ofrecidos.length, 8);
      expect(r.objetivos.map((o) => o.nivel), conOfrecidos().objetivos.map((o) => o.nivel));
    });
  });

  group('objetivos de carrera', () {
    TemporadaJugador temp(int n, {bool campeon = false, double pts = 30}) => TemporadaJugador(
      numero: n,
      etiqueta: '20${20 + n}',
      franquiciaId: 'CHI',
      edad: 20 + n,
      media: 85,
      pj: 80,
      pts: pts,
      reb: 8,
      ast: 5,
      victorias: 55,
      derrotas: 27,
      resultado: '',
      campeon: campeon,
    );

    test('se cumplen una sola vez y cobran puntos, fans y una línea en la historia', () {
      var e = nuevo().copyWith(historial: [temp(1, campeon: true), for (var i = 2; i <= 7; i++) temp(i)]);
      final logrados = ObjetivosCarrera.nuevosDeCarrera(e);
      expect(logrados, containsAll([ObjetivoCarrera.anillo1, ObjetivoCarrera.puntos10k, ObjetivoCarrera.partidos500]));
      expect(logrados, isNot(contains(ObjetivoCarrera.anillo3)));
      final antes = e.phBanco;
      e = ObjetivosCarrera.cobrarCarrera(e, logrados);
      expect(e.phBanco, antes + logrados.fold(0, (a, o) => a + o.puntos));
      expect(e.hitos.last, contains('objetivo de carrera'));
      expect(ObjetivosCarrera.nuevosDeCarrera(e), isEmpty, reason: 'no se cobra dos veces');
    });

    test('los contadores por partido cuentan para los de carrera', () {
      final e = nuevo().copyWith(uso: {'c:td': 12, 'c:p40': 5, 'c:p50': 1});
      final l = ObjetivosCarrera.nuevosDeCarrera(e);
      expect(l, containsAll([ObjetivoCarrera.triplesDobles10, ObjetivoCarrera.partidos40x5, ObjetivoCarrera.partidos50]));
      expect(l, isNot(contains(ObjetivoCarrera.triplesDobles50)));
    });
  });

  group('mini-objetivos y objetivos jugando de verdad', () {
    test('una temporada: el mes se cierra cada 14 partidos y todo se reinicia en la siguiente', () {
      final e0 = carrera.estadoCreado(raiz: 'o2', creado: creado, pick: 6, franquiciaId: 'MIA');
      var t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      final inicial = EstadoCarrera.de(t)!;
      expect(inicial.ofrecidos.length, 8);
      expect(inicial.objetivos.length, 4);
      for (var i = 0; i < 30; i++) {
        if (liga.proximoDelUsuario(t) == null) break;
        t = liga.simularProximo(t);
      }
      final e = EstadoCarrera.de(carrera.alGuardar(t))!;
      expect(e.uso['sc:pj'], greaterThanOrEqualTo(14));
      expect(ObjetivosCarrera.puedeElegir(e), isFalse, reason: 'ya se jugó');
      expect(e.uso['mes:n'], lessThan(14), reason: 'el mes se reinició');
      expect(ObjetivosCarrera.miniActual(e), isNotNull);
      // Cierre y siguiente: nuevos ofrecidos, contadores del año en cero.
      t = liga.simularRestoPlayoffs(liga.simularOtrosHasta(_resto(liga, t), 1 << 30));
      t = carrera.alGuardar(t);
      final c = carrera.cerrar(t, EstadoCarrera.de(t)!, (id) => franquiciaPorId(id).nombreCompleto);
      final sig = EstadoCarrera.de(carrera.siguiente(t, c.estado))!;
      expect(sig.ofrecidos.length, 8);
      expect(sig.objetivos.length, 4);
      expect(sig.uso.keys.where((k) => k.startsWith('sc:') || k.startsWith('mes:') || k.startsWith('gr:')), isEmpty);
      expect(sig.uso['c:pj'], greaterThan(0), reason: 'los de carrera siguen');
    });

    test('el mini-objetivo se cobra al cumplirse el mes', () {
      var e = nuevo();
      e = e.copyWith(uso: {...e.uso, 'sc:pj': 13, 'mes:n': 13, 'mes:pts': 1000, 'mo:tipo': MiniObjetivo.puntos.index, 'mo:meta': 150});
      expect(ObjetivosCarrera.valorMes(MiniObjetivo.puntos, e.uso), greaterThan(15));
      expect(ObjetivosCarrera.textoMini(MiniObjetivo.puntos, 15), contains('15,0'));
      expect(ObjetivosCarrera.textoMini(MiniObjetivo.victorias, 8), contains('8'));
    });
  });
}

Temporada _resto(Liga liga, Temporada t) {
  while (liga.proximoDelUsuario(t) != null) {
    t = liga.simularProximo(t);
  }
  return t;
}
