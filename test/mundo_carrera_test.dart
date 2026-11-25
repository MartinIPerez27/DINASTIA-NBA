import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/decisiones_partido.dart';
import 'package:dinastia_nba/domain/entities/estilo_creado.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/vida_carrera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  JugadorCreado creado({Personalidad? p}) => JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.anotadorTresNiveles,
    fuertes: const [Atributo.tiro, Atributo.finalizacion, Atributo.iq],
    estilo: p == null ? null : EstiloCreado(personalidad: p),
  );
  CarreraJugador nueva(int seed) => CarreraJugador(Liga(catalogo, franquicias, azar: Random(seed)));
  EstadoCarrera estado(CarreraJugador c, String raiz, {Personalidad? p}) =>
      c.estadoCreado(raiz: raiz, creado: creado(p: p), pick: 8, franquiciaId: 'CHI');

  group('personalidad', () {
    test('viaja con el jugador y tiene cuatro tipos; los reales reciben una fija', () {
      expect(Personalidad.values.length, 4);
      final c = JugadorCreado.fromJson(jsonDecode(jsonEncode(creado(p: Personalidad.showman).toJson())) as Map<String, dynamic>);
      expect(c.estilo!.personalidad, Personalidad.showman);
      final e = estado(nueva(1), 'ps1', p: Personalidad.lider);
      expect(VidaCarrera.personalidad(e), Personalidad.lider);
      final real = nueva(1).estadoReal(raiz: 'rr', carta: catalogo.firstWhere((j) => j.nbaPlayerId > 0));
      expect(VidaCarrera.personalidad(real), VidaCarrera.personalidad(real), reason: 'determinística');
    });

    test('cada personalidad inclina la carrera a su manera', () {
      final c = nueva(2);
      Map<Personalidad, EstadoCarrera> por() => {for (final p in Personalidad.values) p: estado(c, 'x-${p.name}', p: p)};
      final e = por();
      // Profesional: menos lesiones.
      expect(VidaCarrera.factorLesion(e[Personalidad.profesional]!), lessThan(VidaCarrera.factorLesion(e[Personalidad.showman]!)));
      // Competidor: más clutch en el partido, y carga el Takeover más rápido.
      final pc = PerfilVivo.de(e[Personalidad.competidor]!), pp = PerfilVivo.de(e[Personalidad.profesional]!);
      expect(pc.h(Habilidad.clutch), pp.h(Habilidad.clutch) + 5);
      // Eventos: el Showman suma fans, el Líder suma relación.
      final ev = VidaCarrera.catalogo.firstWhere((x) => x.id == 'zapatillas');
      final base = e[Personalidad.profesional]!.copyWith(fans: 50, relacion: 50);
      final sh = VidaCarrera.resolver(e[Personalidad.showman]!.copyWith(fans: 50, relacion: 50), ev, 0);
      expect(sh.fans, greaterThan(VidaCarrera.resolver(base, ev, 0).fans));
      final cena = VidaCarrera.catalogo.firstWhere((x) => x.id == 'cena');
      final li = VidaCarrera.resolver(e[Personalidad.lider]!.copyWith(relacion: 50), cena, 0);
      expect(li.relacion, greaterThan(VidaCarrera.resolver(base, cena, 0).relacion));
    });
  });

  group('química', () {
    test('sube con los partidos juntos, por niveles, y suma al equipo con tope', () {
      expect([for (final n in [0, 19, 20, 59, 60, 149, 150, 500]) NivelQuimica.deMinutos(n)], [
        NivelQuimica.ninguna, NivelQuimica.ninguna, NivelQuimica.bronce, NivelQuimica.bronce,
        NivelQuimica.plata, NivelQuimica.plata, NivelQuimica.oro, NivelQuimica.oro,
      ]);
      final c = nueva(3);
      var e = c.nuevaCarrera(estado: estado(c, 'q1'), dificultad: Dificultad.normal);
      var st = EstadoCarrera.de(e)!;
      expect(QuimicaCarrera.puntos(st), 0);
      expect(QuimicaCarrera.mods(st).esNeutro, isTrue);
      final uso = {...st.uso, for (final j in st.companeros) 'qm:${j.id}': 200};
      final lleno = st.copyWith(uso: uso);
      expect(QuimicaCarrera.puntos(lleno), st.companeros.length * 3);
      final m = QuimicaCarrera.mods(lleno);
      expect(m.asistidoExtra, 0.012, reason: 'con tope');
      expect(m.quimicaExtra, 0.006);
      e = e; // sin uso
    });

    test('jugando una temporada se arma química con los que más juegan y el partido lo cuenta', () {
      final liga = Liga(catalogo, franquicias, azar: Random(4));
      final c = CarreraJugador(liga);
      var t = c.nuevaCarrera(estado: estado(c, 'q2'), dificultad: Dificultad.normal);
      for (var i = 0; i < 40 && liga.proximoDelUsuario(t) != null; i++) {
        t = liga.simularProximo(t);
      }
      final e = EstadoCarrera.de(t)!;
      final juntos = [for (final j in e.companeros) QuimicaCarrera.partidosCon(e, j)];
      expect(juntos.reduce(max), greaterThan(20), reason: 'los titulares juegan casi todos los partidos con vos');
      expect(juntos.reduce(max), lessThanOrEqualTo(e.uso['c:pj']!));
      expect(QuimicaCarrera.puntos(e), greaterThan(0));
    });

    test('el equipo con química entra al motor como ajuste y el director lo conserva al decidir', () {
      final liga = Liga(catalogo, franquicias, azar: Random(5));
      final c = CarreraJugador(liga);
      var t = c.nuevaCarrera(estado: estado(c, 'q3'), dificultad: Dificultad.normal);
      final e = EstadoCarrera.de(t)!;
      final lleno = e.copyWith(uso: {...e.uso, for (final j in e.companeros) 'qm:${j.id}': 300});
      t = t.copyWith(datosModo: lleno.aDatos());
      final p = liga.proximoDelUsuario(t)!;
      final local = p.localId == t.franquiciaUsuarioId;
      final m = liga.motor(t, p);
      expect(m.efecto(local)?.mods.asistidoExtra, 0.012);
      final d = DirectorDecisiones(motor: m, propio: local);
      d.aplicarManual(d.menuTactico().firstWhere((o) => o.accion == AccionTactica.ritmoAlto));
      expect(m.efecto(local)?.mods.asistidoExtra, 0.012, reason: 'la química sigue después de una decisión');
      expect(m.efecto(local)?.ritmo, 1);
    });
  });

  group('rivales que se adaptan', () {
    test('al principio nadie te conoce; con el tiempo cierran lo que más hacés, y un juego equilibrado casi no se marca', () {
      final c = nueva(6);
      final e = estado(c, 'r1');
      expect(AdaptacionRival.aprendizaje(e), 0);
      expect(AdaptacionRival.efecto(e), isNull);
      expect(AdaptacionRival.informe(e).single, contains('casi no te conocen'));
      EstadoCarrera conUso(int pj, int pts, int t3) => e.copyWith(uso: {'c:pj': pj, 'c:pts': pts, 'c:t3': t3});
      // Tirador de triples: 60 % de sus puntos son de tres.
      final tirador = conUso(150, 3000, 600);
      final ef = AdaptacionRival.efecto(tirador)!;
      expect(ef.tripleRival, lessThan(1));
      expect(ef.interiorRival, 1);
      // Hombre de aro: casi sin triples.
      final aro = conUso(150, 3000, 20);
      expect(AdaptacionRival.efecto(aro)!.interiorRival, lessThan(1));
      // Equilibrado: 30 %.
      final equilibrado = conUso(150, 3000, 300);
      expect(AdaptacionRival.efecto(equilibrado), isNull);
      expect(AdaptacionRival.informe(equilibrado).join(' '), contains('equilibrado'));
      // Menos partidos, menos preparados.
      expect(AdaptacionRival.efecto(conUso(40, 800, 160))!.tripleRival, greaterThan(ef.tripleRival));
      expect(AdaptacionRival.informe(tirador).join(' '), contains('Te cierran el triple'));
    });

    test('el rival cerrando el triple le baja el acierto de tres a tu equipo en el motor', () {
      final liga = Liga(catalogo, franquicias, azar: Random(7));
      final c = CarreraJugador(liga);
      var t = c.nuevaCarrera(estado: estado(c, 'r2'), dificultad: Dificultad.normal);
      final e = EstadoCarrera.de(t)!.copyWith(uso: {'c:pj': 150, 'c:pts': 3000, 'c:t3': 700});
      t = t.copyWith(datosModo: e.aDatos());
      final p = liga.proximoDelUsuario(t)!;
      final local = p.localId == t.franquiciaUsuarioId;
      final m = liga.motor(t, p);
      expect(m.efecto(!local)?.tripleRival, lessThan(1));
      expect(m.efecto(local), isNull, reason: 'sin química todavía');
      // Los partidos entre IA no tocan nada.
      final otro = t.calendario.firstWhere((x) => !x.participa(t.franquiciaUsuarioId));
      final ia = liga.motor(t, otro);
      expect(ia.efecto(true), isNull);
      expect(ia.efecto(false), isNull);
    });
  });

  group('estadísticas avanzadas', () {
    test('las fórmulas dan lo que dicen (TS %, eFG %, porcentajes, valoración y por 36)', () {
      final e = estado(nueva(8), 'av1').copyWith(
        uso: {
          'c:pj': 100, 'c:pts': 2500, 'c:tcI': 900, 'c:tcA': 1900, 'c:t3': 200, 'c:t3A': 550,
          'c:tlI': 350, 'c:tlA': 420, 'c:ast': 500, 'c:per': 250, 'c:reb': 600, 'c:rob': 100, 'c:tap': 50,
          'c:fal': 200, 'c:seg': 100 * 34 * 60,
        },
      );
      final a = AvanzadasCarrera.de(e)!;
      expect(a.ts, closeTo(2500 / (2 * (1900 + 0.44 * 420)), 1e-9));
      expect(a.efg, closeTo((900 + 0.5 * 200) / 1900, 1e-9));
      expect(a.pctTc, closeTo(900 / 1900, 1e-9));
      expect(a.pctT3, closeTo(200 / 550, 1e-9));
      expect(a.pctTl, closeTo(350 / 420, 1e-9));
      expect(a.astPorPerdida, 2.0);
      expect(a.minutos, closeTo(34, 1e-9));
      expect(a.puntosPor36, closeTo(2500 / (100 * 34) * 36, 1e-9));
      final gs = (2500 + 0.4 * 900 - 0.7 * 1900 - 0.4 * 70 + 0.5 * 600 + 100 + 0.7 * 500 + 0.7 * 50 - 0.4 * 200 - 250) / 100;
      expect(a.valoracion, closeTo(gs, 1e-9));
      expect(AvanzadasCarrera.de(estado(nueva(8), 'av2')), isNull, reason: 'sin partidos no hay nada');
    });

    test('jugando un rato, los contadores se llenan y los números son creíbles', () {
      final liga = Liga(catalogo, franquicias, azar: Random(9));
      final c = CarreraJugador(liga);
      var t = c.nuevaCarrera(estado: estado(c, 'av3'), dificultad: Dificultad.normal);
      for (var i = 0; i < 30 && liga.proximoDelUsuario(t) != null; i++) {
        t = liga.simularProximo(t);
      }
      final a = AvanzadasCarrera.de(EstadoCarrera.de(t)!)!;
      expect(a.ts, inInclusiveRange(0.35, 0.8));
      expect(a.efg, inInclusiveRange(0.3, 0.75));
      expect(a.minutos, inInclusiveRange(5, 48));
      expect(a.pj, 30);
    });
  });

  group('bandeja de entrada', () {
    test('categoriza, ordena de lo nuevo a lo viejo y cuenta los no leídos', () {
      expect(BandejaCarrera.categoriaDe('2027–28: mini-objetivo del mes cumplido — Promediar 20 puntos.'), CategoriaMensaje.objetivos);
      expect(BandejaCarrera.categoriaDe('2027–28: Jugador del mes.'), CategoriaMensaje.premios);
      expect(BandejaCarrera.categoriaDe('2027–28: Fulano se retira a los 37 años.'), CategoriaMensaje.plantel);
      expect(BandejaCarrera.categoriaDe('2027–28: Rumor: varios equipos preguntan por Lucía.'), CategoriaMensaje.mercado);
      expect(BandejaCarrera.categoriaDe('2027–28: Algo cualquiera.'), CategoriaMensaje.general);
      final c = nueva(10);
      var e = estado(c, 'bd1');
      final et1 = e.etiquetaDe(1), et2 = e.etiquetaDe(2);
      e = e.copyWith(numero: 2, hitos: ['$et1: Jugador del mes.', '$et2: Jugador del mes.'], movimientos: ['$et1: Zutano se retira a los 36 años.']);
      final m = BandejaCarrera.mensajes(e);
      expect(m.length, 3);
      expect(m.first.texto, startsWith(et2), reason: 'lo más nuevo arriba');
      expect(m.map((x) => x.temporada), [2, 1, 1]);
      expect(BandejaCarrera.sinLeer(e), 3);
      final leido = BandejaCarrera.marcarLeidos(e);
      expect(BandejaCarrera.sinLeer(leido), 0);
      expect(BandejaCarrera.sinLeer(leido.copyWith(movimientos: [...e.movimientos, '$et2: Fulano termina contrato y firma con otro equipo.'])), 1);
    });
  });
}
