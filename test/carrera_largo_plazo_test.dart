// Tests de largo plazo de los modos de carrera: simulan 15–20 temporadas con semillas fijas y fallan si
// alguien rompe el balance (jugador que llega a 99 a los 22, 82-0 todos los años, plantel que converge
// a 90, prestigio pegado a 100…). No dependen de medias de cartas puntuales del catálogo.
@Timeout(Duration(minutes: 9))
library;

import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/dinastia.dart';
import 'package:dinastia_nba/domain/modos/universitario.dart';
import 'package:flutter_test/flutter_test.dart';

String _nombreDe(String id) => franquiciaPorId(id).nombreCompleto;

/// Una temporada de Mi carrera ya cerrada.
typedef FilaCarrera = ({int edad, int media, double pts, double reb, double ast, int v, int d, bool campeon});

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  JugadorCreado jugadorCreado() => JugadorCreado(
    nombre: 'Test Uno',
    posicion: Posicion.escolta,
    rol: RolCancha.tiradorPantallas,
    fuertes: const [Atributo.tiro, Atributo.iq, Atributo.defensa],
    alturaCm: 195,
    pesoKg: 90,
  );

  /// Juega los partidos del usuario guardando cada [lote] como lo hace la pantalla.
  Temporada jugarRegular(Liga liga, CarreraJugador carrera, Temporada t, int lote) {
    var n = 0;
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
      if (++n % lote == 0) t = carrera.alGuardar(t);
    }
    return t;
  }

  /// Gasta todos los puntos de habilidad, atributo por atributo, donde más rinden.
  EstadoCarrera gastarTodo(CarreraJugador carrera, EstadoCarrera e) {
    while (true) {
      final w = ModeloCarrera.pesos(e.posicion);
      Atributo? mejor;
      var mv = -1.0;
      for (final a in Atributo.values) {
        if (!carrera.puedeSubir(e, a)) continue;
        final v = w[a]! / ModeloCarrera.costo(e.atributos[a]);
        if (v > mv) {
          mv = v;
          mejor = a;
        }
      }
      if (mejor == null) return e;
      e = carrera.subir(e, mejor);
    }
  }

  /// Una carrera completa de un jugador creado. Devuelve una fila por temporada.
  List<FilaCarrera> carreraCreada({
    required int semilla,
    required int potencial,
    required bool gastar,
    int pick = 14,
    int temporadas = 18,
    int lote = 20,
  }) {
    final liga = Liga(catalogo, franquicias, azar: Random(semilla));
    final carrera = CarreraJugador(liga);
    final e0 = carrera.estadoCreado(
      raiz: 'lp$semilla',
      creado: jugadorCreado(),
      pick: pick,
      franquiciaId: 'DAL',
      potencial: potencial,
    );
    var t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
    final filas = <FilaCarrera>[];
    for (var k = 1; k <= temporadas; k++) {
      t = jugarRegular(liga, carrera, t, lote);
      t = liga.simularOtrosHasta(carrera.alGuardar(t), 1 << 30);
      t = liga.simularRestoPlayoffs(t);
      t = carrera.alGuardar(t);
      final e = EstadoCarrera.de(t)!;
      final c = carrera.cerrar(t, e, _nombreDe);
      final s = c.temporada;
      filas.add((
        edad: s.edad,
        media: s.media,
        pts: s.pts,
        reb: s.reb,
        ast: s.ast,
        v: s.victorias,
        d: s.derrotas,
        campeon: s.campeon,
      ));
      var ne = c.estado;
      if (gastar) ne = gastarTodo(carrera, ne);
      if (CarreraJugador.retiroForzoso(ne)) break;
      t = carrera.siguiente(t, ne);
    }
    return filas;
  }

  int pico(List<FilaCarrera> f) => f.map((x) => x.media).reduce(max);
  int edadDelPico(List<FilaCarrera> f) => f.firstWhere((x) => x.media == pico(f)).edad;

  group('Mi carrera', () {
    late List<FilaCarrera> maximo88, sin88, maximo99;
    setUpAll(() {
      maximo88 = carreraCreada(semilla: 41, potencial: 88, gastar: true);
      sin88 = carreraCreada(semilla: 43, potencial: 88, gastar: false);
      maximo99 = carreraCreada(semilla: 44, potencial: 99, gastar: true);
      // ignore: avoid_print
      for (final (n, f) in [('max88', maximo88), ('sin88', sin88), ('max99', maximo99)]) {
        // ignore: avoid_print
        print('$n: ${[for (final x in f) '${x.edad}:${x.media}/${x.pts.round()}p/${x.v}'].join(' ')}');
      }
    });

    test('el techo oculto manda: nadie pasa de su potencial y gastar todo no regala el 99', () {
      expect(pico(maximo88), lessThanOrEqualTo(88));
      expect(pico(maximo88), greaterThanOrEqualTo(83), reason: 'gastando todo, llega cerca de su techo');
      expect(pico(maximo99), lessThanOrEqualTo(99));
      expect(pico(sin88), lessThan(pico(maximo88)), reason: 'sin gastar rinde menos');
      expect(pico(sin88), lessThanOrEqualTo(85));
    });

    test('el 99 es excepcional: nunca antes de los 25 y no se queda ahí', () {
      for (final f in [maximo88, sin88, maximo99]) {
        // Media de los 22 años: lejos del techo (antes se llegaba a 99 a los 24).
        expect(f.where((x) => x.edad <= 22).every((x) => x.media <= 90), isTrue);
        expect(f.where((x) => x.edad <= 24).every((x) => x.media <= 97), isTrue);
      }
      for (final x in maximo99.where((x) => x.media >= 99)) {
        expect(x.edad, greaterThanOrEqualTo(25));
      }
      final temporadasEn99 = maximo99.where((x) => x.media >= 99).length;
      expect(temporadasEn99, lessThanOrEqualTo(4), reason: 'incluso con potencial 99 no hay 15 años a 99');
    });

    test('pico entre los 25 y los 31, y declive real aunque se gasten todos los puntos', () {
      for (final f in [maximo88, maximo99]) {
        expect(edadDelPico(f), inInclusiveRange(25, 32));
        final viejos = f.where((x) => x.edad >= 34).toList();
        expect(viejos, isNotEmpty, reason: 'la carrera llega a los 34');
        expect(viejos.map((x) => x.media).reduce(max), lessThanOrEqualTo(pico(f) - 6));
        // Con la edad la media nunca vuelve a subir de forma sostenida: a los 33+ siempre baja o se sostiene.
        final tardios = f.where((x) => x.edad >= 31).toList();
        for (var i = 1; i < tardios.length; i++) {
          expect(tardios[i].media, lessThanOrEqualTo(tardios[i - 1].media + 1));
        }
      }
    });

    test('carreras creíbles: de 15 a 20 temporadas, con picos y bajones', () {
      for (final f in [maximo88, maximo99, sin88]) {
        expect(f.length, inInclusiveRange(15, 20));
        final victorias = f.map((x) => x.v).toList();
        expect(
          victorias.reduce(max) - victorias.reduce(min),
          greaterThanOrEqualTo(12),
          reason: 'hay buenos y malos años',
        );
      }
    });

    test('las estadísticas siguen a la media: un 99 no promedia 55 y un 70 no promedia 30', () {
      for (final f in [maximo88, maximo99, sin88]) {
        for (final x in f) {
          expect(x.pts, lessThanOrEqualTo(40), reason: 'edad ${x.edad} media ${x.media}: ${x.pts}');
          if (x.media <= 75) expect(x.pts, lessThanOrEqualTo(24));
          if (x.media >= 90) expect(x.pts, greaterThanOrEqualTo(18));
          expect(x.reb, lessThanOrEqualTo(14));
          expect(x.ast, lessThanOrEqualTo(12));
        }
        final mejor = f.reduce((a, b) => a.pts >= b.pts ? a : b);
        expect(mejor.pts, lessThanOrEqualTo(38));
      }
    });

    test('nada de 82-0 sistemático: ni siquiera con un 99 gastando todo', () {
      for (final f in [maximo88, maximo99, sin88]) {
        expect(f.where((x) => x.d == 0), isEmpty);
        expect(f.where((x) => x.v >= 78).length, lessThanOrEqualTo(2));
        final promedio = f.fold(0, (a, x) => a + x.v) / f.length;
        expect(promedio, lessThan(66));
        expect(f.where((x) => x.campeon).length, lessThanOrEqualTo((f.length * 0.5).floor()));
      }
    });
  });

  test('Mi carrera: el resultado no depende de cuántos partidos se simulan por paso', () {
    // Misma partida y misma semilla, guardando de a 1, de a 6 y todo junto.
    final resultados = <String>[];
    for (final lote in [1, 6, 82]) {
      final liga = Liga(catalogo, franquicias, azar: Random(77));
      final carrera = CarreraJugador(liga);
      final e0 = carrera.estadoCreado(
        raiz: 'paso',
        creado: jugadorCreado(),
        pick: 20,
        franquiciaId: 'DAL',
        potencial: 88,
      );
      var t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      t = jugarRegular(liga, carrera, t, lote);
      t = carrera.alGuardar(t);
      final e = EstadoCarrera.de(t)!;
      final c = carrera.cerrar(t, e, _nombreDe).estado;
      resultados.add(
        '${t.registroUsuario.victorias}-${t.registroUsuario.derrotas} conf ${e.confianza} moral ${e.moral} fans ${e.fans} '
        'ph ${e.phBanco} rol ${e.rolEquipo.name} | cierre conf ${c.confianza} moral ${c.moral} ph ${c.phBanco} '
        'atr ${c.atributos.toJson()}',
      );
    }
    expect(resultados[1], resultados[0]);
    expect(resultados[2], resultados[0]);
  });

  test('Mi carrera: la confianza no se satura a 100 con el tiempo', () {
    final liga = Liga(catalogo, franquicias, azar: Random(44));
    final carrera = CarreraJugador(liga);
    var e = carrera.estadoCreado(raiz: 'conf', creado: jugadorCreado(), pick: 3, franquiciaId: 'DAL', potencial: 99);
    var t = carrera.nuevaCarrera(estado: e, dificultad: Dificultad.normal);
    var en100 = 0;
    for (var k = 0; k < 6; k++) {
      t = jugarRegular(liga, carrera, t, 20);
      t = liga.simularRestoPlayoffs(liga.simularOtrosHasta(carrera.alGuardar(t), 1 << 30));
      t = carrera.alGuardar(t);
      e = EstadoCarrera.de(t)!;
      final c = carrera.cerrar(t, e, _nombreDe).estado;
      if (c.confianza >= 100) en100++;
      expect(c.moral, lessThanOrEqualTo(97));
      t = carrera.siguiente(t, gastarTodo(carrera, c));
    }
    expect(en100, 0);
  });

  group('Figura franquicia', () {
    test('sube de media y de estadísticas, y el equipo es competitivo en un plazo razonable', () {
      final liga = Liga(catalogo, franquicias, azar: Random(8));
      final carrera = CarreraDinastia(liga);
      final figura = (carrera.candidatosFigura(Random(1))..sort((a, b) => b.stats.ppp.compareTo(a.stats.ppp))).first;
      var t = carrera.nuevaFigura(id: 'figlp', franquiciaId: 'DET', figura: figura, dificultad: Dificultad.normal);
      final victorias = <int>[], medias = <int>[], puntos = <double>[], edades = <int>[], equipo = <double>[];
      for (var k = 0; k < 15; k++) {
        var x = liga.iniciar(t.copyWith(tacticaConfirmada: true));
        x = carrera.reforzarRivales(x);
        while (liga.proximoDelUsuario(x) != null) {
          x = liga.simularProximo(x);
        }
        x = liga.simularRestoPlayoffs(liga.simularOtrosHasta(x, 1 << 30));
        final estado = EstadoDinastia.de(x);
        if (estado.figuraRetirada) break;
        final j = [...x.plantel.jugadores, ...x.suplentes].firstWhere((j) => j.id == figura.id);
        final s = carrera.temporadaDeFigura(x, j);
        victorias.add(x.registroUsuario.victorias);
        equipo.add(x.plantel.jugadores.fold(0, (a, q) => a + q.media) / 6);
        medias.add(j.media);
        puntos.add(s.pts);
        edades.add(s.edad);
        final r = carrera.receso(x, _nombreDe);
        if (r.figura?.retirado ?? false) break;
        t = carrera.siguiente(x, r, {for (final e in r.opciones.entries) e.key: e.value.first});
      }
      // ignore: avoid_print
      print(
        'figura: ${[for (var i = 0; i < medias.length; i++) '${edades[i]}:${medias[i]}/${puntos[i].toStringAsFixed(1)}p/${victorias[i]}/eq${equipo[i].toStringAsFixed(0)}'].join(' ')}',
      );
      expect(medias.length, greaterThanOrEqualTo(11));
      final pico = medias.reduce(max);
      expect(pico, greaterThan(medias.first + 6));
      expect(pico, lessThanOrEqualTo(95));
      expect(medias.indexOf(pico), lessThan(medias.length - 3), reason: 'después del pico declina');
      expect(medias.last, lessThan(pico - 3));
      // Las estadísticas siguen a la media.
      expect(puntos.reduce(max), greaterThan(puntos.first + 4));
      expect(puntos.reduce(max), lessThanOrEqualTo(34));
      // Nada de 1-81 durante años: en 8 temporadas hay un equipo de playoffs y no hay 5 años por debajo de 20.
      expect(victorias.take(8).reduce(max), greaterThanOrEqualTo(42));
      expect(victorias.where((v) => v < 20).length, lessThanOrEqualTo(2));
      expect(victorias.where((v) => v >= 78).length, 0);
    }, timeout: const Timeout(Duration(minutes: 9)));
  });

  group('Dinastía', () {
    test('la liga reacciona: el plantel no converge a 90 ni gana todo', () {
      final liga = Liga(catalogo, franquicias, azar: Random(5));
      final carrera = CarreraDinastia(liga);
      var p = const Plantel();
      final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
      for (final pos in Posicion.values) {
        p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
      }
      var t = Temporada(
        id: 'dinlp',
        franquiciaUsuarioId: 'CHI',
        plantel: p,
        tacticaConfirmada: true,
        modoJuego: ModoJuego.dinastia,
        datosModo: CarreraDinastia.datosIniciales('dinlp'),
      );
      final victorias = <int>[], medias = <double>[];
      var anillos = 0;
      for (var k = 0; k < 13; k++) {
        var x = carrera.reforzarRivales(liga.iniciar(t.copyWith(tacticaConfirmada: true)));
        while (liga.proximoDelUsuario(x) != null) {
          x = liga.simularProximo(x);
        }
        x = liga.simularRestoPlayoffs(liga.simularOtrosHasta(x, 1 << 30));
        victorias.add(x.registroUsuario.victorias);
        final js6 = x.plantel.jugadores.toList();
        medias.add(js6.fold(0, (a, j) => a + j.media) / js6.length);
        if (x.campeonId == 'CHI') anillos++;
        final r = carrera.receso(x, _nombreDe);
        t = carrera.siguiente(x, r, {for (final e in r.opciones.entries) e.key: e.value.first});
      }
      // ignore: avoid_print
      print(
        'dinastia: ${[for (var i = 0; i < medias.length; i++) '${medias[i].toStringAsFixed(1)}/${victorias[i]}'].join(' ')} anillos $anillos',
      );
      expect(medias.skip(7).reduce(max), lessThan(88), reason: 'el plantel no converge a ~90');
      expect(victorias.where((v) => v >= 78).length, 0);
      expect(
        victorias.reduce(max) - victorias.reduce(min),
        greaterThanOrEqualTo(15),
        reason: 'hay años buenos y malos',
      );
      expect(anillos, lessThan(11), reason: 'no se gana todo');
    }, timeout: const Timeout(Duration(minutes: 9)));

    test('el ajuste de la liga sube con tu plantel y baja si estás hundido', () {
      final liga = Liga(catalogo, franquicias, azar: Random(6));
      final carrera = CarreraDinastia(liga);
      Temporada con(int media) {
        var p = const Plantel();
        final js = catalogo.where((j) => j.franquiciaId == 'LAL' && j.tier != Tier.sPlus).toList();
        for (final pos in Posicion.values) {
          final j = js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos));
          p = p.asignar(j.conMedia(media), pos);
        }
        return Temporada(
          id: 'aj',
          franquiciaUsuarioId: 'LAL',
          plantel: p,
          tacticaConfirmada: true,
          modoJuego: ModoJuego.dinastia,
        );
      }

      expect(carrera.ajusteRivales(con(92)), greaterThan(carrera.ajusteRivales(con(80))));
      expect(carrera.ajusteRivales(con(70)), lessThan(0));
      expect(carrera.ajusteRivales(con(99)), lessThanOrEqualTo(6));
    });
  });

  group('Universitario', () {
    const sim = Universitario();
    const programa = Programa(nombre: 'Lago Azul', mote: 'Cóndores', color1: 1, color2: 3);

    /// 15 temporadas fichando siempre a los mejores reclutas que alcanzan.
    (List<int> victorias, List<int> prestigio, int titulos) correr(int semilla) {
      var e = sim.nueva(semilla: semilla, programa: programa, creados: [jugadorCreado(), jugadorCreado()]);
      final v = <int>[], pr = <int>[];
      var titulos = 0;
      for (var k = 0; k < 15; k++) {
        e = sim.simularTorneo(sim.simularJornadas(e, 30));
        if (e.campeon == 0) titulos++;
        e = sim.cerrarTemporada(e);
        v.add(e.historial.last.v);
        pr.add(e.prestigio);
        var puntos = e.puntosReclutamiento();
        final firmados = <Recluta>[];
        final cupo = EstadoUniv.plantelMax - e.pasarDeAnio({}).$1.length;
        final orden = [...e.reclutas()]..sort((a, b) => b.estudiante.media.compareTo(a.estudiante.media));
        for (final r in orden) {
          if (firmados.length >= cupo || r.precio > puntos) continue;
          puntos -= r.precio;
          firmados.add(r);
        }
        e = sim.cerrarReceso(e, declarados: {}, firmados: firmados);
      }
      return (v, pr, titulos);
    }

    test('el prestigio no satura a 100, no se vuelve 28-2 y hay metas por temporada', () {
      for (final semilla in [7, 8, 9]) {
        final (v, pr, titulos) = correr(semilla);
        // ignore: avoid_print
        print('univ $semilla: v=$v prestigio=$pr titulos=$titulos');
        expect(pr.reduce(max), lessThan(100));
        expect(pr.where((x) => x >= 95).length, 0);
        expect(v.reduce(max), lessThanOrEqualTo(29), reason: 'un 30-0 no debería existir');
        expect(v.skip(5).where((x) => x >= 27).length, lessThanOrEqualTo(5));
        expect(v.skip(5).reduce((a, b) => a + b) / (v.length - 5), lessThan(27));
        expect(titulos, lessThanOrEqualTo(9));
      }
      expect(EstadoUniv.metaVictorias(30), lessThan(EstadoUniv.metaVictorias(90)));
    });
  });
}
