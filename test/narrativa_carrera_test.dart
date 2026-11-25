import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(6));
  final carrera = CarreraJugador(liga);
  final records = RecordsNba.fromJson(File('assets/database/records_nba.json').readAsStringSync());
  EstadoCarrera nuevo({String raiz = 'na1'}) {
    final e = carrera.estadoCreado(
      raiz: raiz,
      creado: JugadorCreado(
        nombre: 'Gaby Ríos',
        posicion: Posicion.escolta,
        rol: RolCancha.especialista3D,
        fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
      ),
      pick: 6,
      franquiciaId: 'CHI',
    );
    return carrera.nuevaCarrera(estado: e, dificultad: Dificultad.normal).let((t) => EstadoCarrera.de(t)!);
  }

  TemporadaJugador anio(int n, {double pts = 22, double reb = 5, double ast = 5}) => TemporadaJugador(
    numero: n,
    etiqueta: '20${20 + n}',
    franquiciaId: 'CHI',
    edad: 20 + n,
    media: 82,
    pj: 70,
    pts: pts,
    reb: reb,
    ast: ast,
    victorias: 45,
    derrotas: 37,
    resultado: '',
    campeon: false,
    allStar: false,
  );

  group('mapa de tiro', () {
    test('reparte pintura, media distancia y triples y marca la zona más rentable', () {
      final e = nuevo().copyWith(uso: {'c:tcI': 390, 'c:tcA': 800, 'c:pinI': 150, 'c:pinA': 200, 'c:t3': 90, 'c:t3A': 300});
      final m = MapaTiro.de(e);
      expect(m.intentos, 800);
      expect(m.zonas[0].pct, 0.75);
      expect(m.zonas[1].intentos, 300);
      expect(m.zonas[1].hechos, 150);
      expect(m.mejor!.nombre, 'Pintura');
      expect(m.zonas[0].veredicto, 'zona caliente');
      expect(m.zonas[2].veredicto, 'zona fría');
      expect(m.consejo, contains('pintura'));
    });

    test('el motor lleva los tiros de pintura y los suma al partido', () {
      final t = carrera.nuevaCarrera(
        estado: carrera.estadoCreado(
          raiz: 'mt1',
          creado: JugadorCreado(
            nombre: 'Pivote Tester',
            posicion: Posicion.pivot,
            rol: RolCancha.especialista3D,
            fuertes: const [Atributo.finalizacion, Atributo.fisico, Atributo.defensa],
          ),
          pick: 3,
          franquiciaId: 'CHI',
        ),
        dificultad: Dificultad.normal,
      );
      var pin = 0, tc = 0;
      for (final p in t.calendario.where((p) => p.participa(t.franquiciaUsuarioId)).take(8)) {
        final m = liga.motor(t, p, azar: Random(3))..simularTodo();
        for (final l in [...m.boxLocal.values, ...m.boxVisitante.values]) {
          pin += l.pinA;
          tc += l.tcA;
          expect(l.pinI, lessThanOrEqualTo(l.pinA));
          expect(l.pinA, lessThanOrEqualTo(l.tcA - l.t3A));
        }
      }
      expect(pin, greaterThan(0));
      expect(pin, lessThan(tc));
    });
  });

  group('rival y mentor', () {
    test('el rival es de otra franquicia, tu puesto y tu época, y es estable dentro del bloque de 3 temporadas', () {
      final e = nuevo();
      final r = RivalidadCarrera.rival(e, liga.catalogo)!;
      expect(r.franquiciaId, isNot(e.franquiciaId));
      expect(r.posiciones.first, e.posicion);
      expect(r.epoca, e.epoca);
      expect(RivalidadCarrera.rival(e.copyWith(numero: 2), liga.catalogo)!.id, r.id);
    });

    test('al cerrar, el duelo suma una victoria o derrota y el mentor da un punto si el vestuario te quiere', () {
      final e = nuevo().copyWith(relacion: 80);
      final conMentor = RivalidadCarrera.alCerrar(e, anio(1, pts: 40, reb: 10, ast: 10), liga.catalogo);
      expect(RivalidadCarrera.ganados(conMentor), 1);
      expect(conMentor.phBanco, e.phBanco + 1);
      final flojo = RivalidadCarrera.alCerrar(e.copyWith(relacion: 20), anio(1, pts: 2, reb: 1, ast: 1), liga.catalogo);
      expect(RivalidadCarrera.perdidos(flojo), 1);
      expect(flojo.phBanco, e.phBanco);
    });
  });

  group('redes', () {
    test('publicar una vez por temporada: la polémica da más seguidores pero cuesta relación', () {
      final e = nuevo().copyWith(relacion: 50);
      final h = RedesCarrera.publicar(e, PostRedes.highlight);
      final p = RedesCarrera.publicar(e, PostRedes.polemica);
      expect(RedesCarrera.seguidores(p), greaterThan(RedesCarrera.seguidores(h)));
      expect(p.relacion, e.relacion - 3);
      expect(RedesCarrera.publicar(h, PostRedes.polemica).uso['rs:seg'], h.uso['rs:seg'], reason: 'solo una vez');
      final cerrado = RedesCarrera.alCerrar(h, anio(1));
      expect(RedesCarrera.yaPublico(cerrado), isFalse);
      expect(RedesCarrera.seguidores(cerrado), greaterThan(RedesCarrera.seguidores(h)));
    });

    test('los seguidores suman plata de marcas', () {
      final e = nuevo();
      final fama = e.copyWith(uso: {...e.uso, 'rs:seg': 4000});
      expect(EconomiaCarrera.patrocinios(fama), greaterThan(EconomiaCarrera.patrocinios(e)));
    });
  });

  group('relator con memoria', () {
    test('se acuerda de tus puntos, tus 40 y tu mejor año', () {
      var e = nuevo();
      e = e.copyWith(
        uso: {...e.uso, 'c:pts': 9400, 'c:p40': 3, 'm:pts': 52},
        historial: [anio(1), anio(2, pts: 27), anio(3, pts: 24)],
      );
      final m = RelatorCarrera.memorias(e).join(' | ');
      expect(m, contains('9400'));
      expect(m, contains('600 para llegar a 10000'));
      expect(m, contains('3 partidos de 40'));
      expect(m, contains('52'));
      expect(m, contains('2022'));
      expect(RelatorCarrera.previa(e), isNotNull);
      expect(RelatorCarrera.previa(nuevo()), isNull);
    });
  });

  group('cuadro de honor', () {
    test('sin números no entrás; con números de leyenda sí', () {
      final e = nuevo();
      expect(CuadroDeHonor.evaluar(records, e).nivel, contains('fuera'));
      final leyenda = e.copyWith(uso: {...e.uso, 'c:pts': 39000, 'c:reb': 15000, 'c:ast': 11000});
      final c = CuadroDeHonor.evaluar(records, leyenda);
      expect(c.top10, greaterThanOrEqualTo(2));
      expect(c.nivel, anyOf(contains('Inmortal'), contains('Leyenda')));
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
