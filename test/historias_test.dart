import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/contexto_narrativo.dart';
import 'package:dinastia_nba/domain/entities/metajuego.dart';
import 'package:dinastia_nba/domain/entities/partido.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/historias.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/misiones.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/rivalidades.dart';
import 'package:dinastia_nba/domain/tension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(31));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final inicio = liga.iniciar(Temporada(id: 'his', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  String nombre(String id) => franquiciaPorId(id == 'CHI' ? id : inicio.rivales[id]!.identidadId).nombre;

  /// Calendario con tus primeros partidos resueltos según [patron] ('G' ganado, 'P' perdido); el resto, sin jugar.
  Temporada conPatron(String patron, {bool picante = false}) {
    final propios = inicio.calendario.where((x) => x.participa('CHI')).toList()
      ..sort((a, b) => a.jornada.compareTo(b.jornada));
    final resueltos = <String, Partido>{};
    for (var i = 0; i < patron.length; i++) {
      final x = propios[i];
      final gano = patron[i] == 'G';
      final localGana = (x.localId == 'CHI') == gano;
      final (a, b) = picante ? (25, 24) : (28, 20);
      final (l, v) = localGana ? (a, b) : (b, a);
      resueltos[x.id] = x.conResultado([l, 25, 25, 25], [v, 25, 25, 25]);
    }
    return inicio.copyWith(calendario: [for (final x in inicio.calendario) resueltos[x.id] ?? x]);
  }

  Temporada conId(Temporada t, String id) => Temporada.fromJson({...t.toJson(), 'id': id});

  List<Historia> gen(Temporada t, {int mejor = 0}) =>
      Historias.generar(t, liga, nombre: nombre, mejorRachaHistorica: mejor);

  const rival = 'NYK';
  Temporada serie(int vAlto, int vBajo, {String id = 'p1'}) => conId(inicio, id).copyWith(
    series: [
      SeriePlayoff(
        ronda: RondaPlayoff.finalConferencia,
        altoId: 'CHI',
        bajoId: rival,
        victoriasAlto: vAlto,
        victoriasBajo: vBajo,
      ),
    ],
  );

  group('historias', () {
    test('antes de jugar nunca está vacío', () {
      final h = gen(inicio);
      expect(h, isNotEmpty);
      expect(h.first.tipo, TipoHistoria.inicio);
    });

    test('invictos y fin del invicto con reacciones', () {
      final h = gen(conPatron('G' * 10));
      expect(h.where((x) => x.tipo == TipoHistoria.invicto).map((x) => x.titulo), contains('INVICTOS: 10-0'));
      expect(h.firstWhere((x) => x.titulo == 'INVICTOS: 10-0').reaccion, isNotNull);
      final caida = gen(conPatron('${'G' * 10}P'));
      expect(caida.where((x) => x.tipo == TipoHistoria.caidaInvicto), hasLength(1));
      expect(caida.firstWhere((x) => x.tipo == TipoHistoria.caidaInvicto).reaccion, isNotNull);
    });

    test('rachas: se marcan al llegar a 5 y 8 y se cortan con una historia', () {
      final h = gen(conPatron('PGGGGGGGGP'));
      final rachas = h.where((x) => x.tipo == TipoHistoria.racha).map((x) => x.titulo).toList();
      expect(rachas, containsAll(['RACHA DE 5', 'RACHA DE 8']));
      expect(h.where((x) => x.tipo == TipoHistoria.finRacha).single.titulo, 'SE CORTÓ LA RACHA DE 8');
    });

    test('crisis a las 3 derrotas y respiro al cortarla', () {
      final h = gen(conPatron('GPPPG'));
      expect(h.where((x) => x.tipo == TipoHistoria.crisis), hasLength(1));
      expect(h.where((x) => x.tipo == TipoHistoria.respiro), hasLength(1));
      expect(gen(conPatron('GPPG')).where((x) => x.tipo == TipoHistoria.crisis), isEmpty);
    });

    test('récord personal cuando la racha supera tu mejor marca', () {
      final h = gen(conPatron('PGGGGGG'), mejor: 4);
      expect(h.where((x) => x.titulo == 'RÉCORD PERSONAL'), hasLength(1));
      expect(gen(conPatron('PGGGGGG'), mejor: 9).where((x) => x.titulo == 'RÉCORD PERSONAL'), isEmpty);
    });

    test('lesión de una figura tuya: drama con la duración', () {
      final estrella = inicio.plantel.jugadores.reduce((a, b) => a.media >= b.media ? a : b);
      final t = conPatron('GGG').copyWith(lesiones: {estrella.id: 12});
      final l = gen(t).where((x) => x.tipo == TipoHistoria.lesion).single;
      expect(l.titulo, startsWith('GOLPE DURÍSIMO'));
      expect(l.texto, contains('12'));
      expect(l.jugadorId, estrella.id);
      final corta = gen(conPatron('GGG').copyWith(lesiones: {estrella.id: 2}));
      expect(corta.where((x) => x.tipo == TipoHistoria.lesion).single.texto, contains('2 partidos'));
    });

    test('es determinista y nunca repite la misma historia seguida', () {
      final t = conPatron('GGGGGPGPPPGGGGGGGGGG');
      final a = gen(t), b = gen(t);
      expect([for (final x in a) x.clave], [for (final x in b) x.clave]);
      expect([for (final x in a) x.texto], [for (final x in b) x.texto]);
      for (var i = 1; i < a.length; i++) {
        expect(a[i].clave == a[i - 1].clave, isFalse);
      }
      expect(a.length, lessThanOrEqualTo(Historias.limite));
      for (final x in a) {
        expect(x.titulo.trim(), isNotEmpty);
        expect(x.texto.trim(), isNotEmpty);
      }
      // Más nueva primero.
      for (var i = 1; i < a.length; i++) {
        expect(a[i].jornada <= a[i - 1].jornada, isTrue);
      }
    });

    test('con una temporada simulada cada historia tiene contenido y hay hitos de liga', () {
      var t = inicio;
      for (var i = 0; i < 30; i++) {
        t = liga.simularProximo(t);
      }
      final h = gen(t);
      expect(h.any((x) => x.tipo == TipoHistoria.hito), isTrue);
      expect(h.last.tipo == TipoHistoria.resumen || h.any((x) => x.tipo == TipoHistoria.resumen), isTrue);
    });

    test('nuevas: lo que trae el último partido', () {
      final antes = conPatron('PGGGG');
      final despues = conPatron('PGGGGG');
      final nuevas = Historias.nuevas(antes, despues, liga, nombre: nombre);
      expect(nuevas.where((x) => x.tipo == TipoHistoria.racha).single.titulo, 'RACHA DE 5');
      expect(Historias.nuevas(despues, despues, liga, nombre: nombre), isEmpty);
    });

    test('hitos de una noche: 40 puntos y triple-doble', () {
      final noche = {
        'a': LineaEstadistica()
          ..pj = 1
          ..pts = 41
          ..reb = 5,
        'b': LineaEstadistica()
          ..pj = 1
          ..pts = 14
          ..reb = 11
          ..ast = 12,
        'c': LineaEstadistica()
          ..pj = 1
          ..pts = 8,
      };
      final h = Historias.hitosDeNoche(
        noche,
        nombreDe: (id) => 'Jugador $id',
        franquiciaDe: (id) => id == 'a' ? 'CHI' : 'LAL',
        usuarioId: 'CHI',
        jornada: 3,
      );
      expect(h.map((x) => x.titulo), containsAll(['41 PUNTOS', 'TRIPLE-DOBLE']));
      expect(h.firstWhere((x) => x.titulo == '41 PUNTOS').destacado, isTrue);
      expect(h.firstWhere((x) => x.titulo == 'TRIPLE-DOBLE').destacado, isFalse);
      expect(h, hasLength(2));
    });

    test('ultimoPartido resume resultado, récord y racha', () {
      final s = Historias.ultimoPartido(conPatron('GGG'), nombre: nombre)!;
      expect(s, contains('Ganaste'));
      expect(s, contains('3-0'));
      expect(s, contains('3 seguidas'));
      expect(Historias.ultimoPartido(inicio, nombre: nombre), isNull);
    });
  });

  group('rivalidades con mala sangre', () {
    test('te eliminan en 7: calor alto, relato con voseo y cantidad de juegos', () {
      final (m, _) = Rivalidades.registrar(const Metajuego(), serie(3, 3), serie(3, 4), numero: 2);
      final r = m.rivalidades[rival]!;
      expect(r.eliminaciones, 1);
      expect(r.juegosEliminacion, 7);
      expect(r.cerradas, 1);
      expect(r.calor, greaterThanOrEqualTo(50));
      final relato = MalaSangre.relato(m.rivalidades, serie(0, 0, id: 'otra'), rival, 'Knicks', numeroActual: 3)!;
      expect(relato.frase, 'Los Knicks te sacaron en 7 el año pasado. Hay cuenta pendiente.');
      expect(relato.nivel.index, greaterThanOrEqualTo(NivelRivalidad.caliente.index));
      expect(relato.fichas, contains('1 eliminación'));
    });

    test('se acumula con más derrotas y se enfría entre temporadas', () {
      var (m, _) = Rivalidades.registrar(const Metajuego(), serie(0, 0), serie(0, 1), numero: 1);
      final c1 = m.rivalidades[rival]!.calor;
      (m, _) = Rivalidades.registrar(m, serie(0, 1), serie(0, 2), numero: 1);
      final c2 = m.rivalidades[rival]!.calor;
      expect(c2, greaterThan(c1));
      final r = m.rivalidades[rival]!;
      expect(MalaSangre.vigente(r, 'p1'), c2);
      expect(MalaSangre.vigente(r, 'otra'), (c2 * 0.75).floor());
      // Nunca pasa de 100 ni baja de 0.
      final fuerte = MalaSangre.sumar(r, 500, 'p1');
      expect(fuerte.calor, 100);
      expect(MalaSangre.sumar(r, -500, 'p1').calor, 0);
    });

    test('la revancha cumplida baja un poco el calor y cuenta la serie ganada', () {
      var (m, _) = Rivalidades.registrar(const Metajuego(), serie(3, 3), serie(3, 4), numero: 1);
      final antes = m.rivalidades[rival]!.calor;
      final (m2, cumplidas) = Rivalidades.registrar(m, serie(3, 3, id: 'p2'), serie(4, 3, id: 'p2'), numero: 2);
      expect(cumplidas, [rival]);
      final r = m2.rivalidades[rival]!;
      expect(r.revanchas, 1);
      expect(r.victorias, greaterThan(0));
      expect(r.calor, greaterThan(0));
      expect(r.calor, lessThan(antes + MalaSangre.serieGanada + MalaSangre.serieGanadaEnSiete + 1));
    });

    test('partidos picantes suman calor aunque los ganes', () {
      final (m, _) = Rivalidades.registrar(
        const Metajuego(),
        conPatron('', picante: true),
        conPatron('G', picante: true),
        numero: 1,
      );
      expect(m.rivalidades.values.single.picantes, 1);
      expect(m.rivalidades.values.single.calor, MalaSangre.picante);
    });

    test('técnicas y expulsiones del partido en vivo suman picante', () {
      final m = MalaSangre.anotarPicante(const Metajuego(), rival, 'p1', tecnicas: 2, expulsiones: 1);
      expect(m.rivalidades[rival]!.calor, 8);
      expect(m.rivalidades[rival]!.picantes, 1);
      expect(MalaSangre.anotarPicante(m, rival, 'p1'), same(m));
    });

    test('JSON ida y vuelta, y perfiles viejos cargan', () {
      final (m, _) = Rivalidades.registrar(const Metajuego(), serie(3, 3), serie(3, 4), numero: 2);
      final vuelta = Metajuego.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(vuelta.rivalidades[rival]!.toJson(), m.rivalidades[rival]!.toJson());
      final vieja = Rivalidad.fromJson({'f': 'BOS', 'e': 1, 'd': 3});
      expect(vieja.calor, 0);
      expect(vieja.juegosEliminacion, isNull);
      expect(vieja.toJson(), {'f': 'BOS', 'e': 1, 'd': 3});
    });
  });

  group('presión y contexto narrativo', () {
    test('partido 7, eliminación, match point y ventaja', () {
      expect(presion(aGanar: 4, propias: 3, ajenas: 3).etiqueta, 'PARTIDO 7');
      expect(presion(aGanar: 4, propias: 3, ajenas: 3).nivel, NivelTension.maxima);
      expect(presion(aGanar: 4, propias: 1, ajenas: 3).etiqueta, 'ELIMINACIÓN');
      expect(presion(aGanar: 4, propias: 1, ajenas: 3).eliminacion, isTrue);
      expect(presion(aGanar: 4, propias: 3, ajenas: 2).matchPoint, isTrue);
      expect(presion(aGanar: 4, propias: 2, ajenas: 0).etiqueta, 'VENTAJA 2-0');
      expect(presion(aGanar: 4, propias: 0, ajenas: 0).nivel.index, lessThan(NivelTension.alta.index));
      expect(presion(aGanar: 1, propias: 0, ajenas: 0).decisivo, isTrue);
      // Más tensión a medida que se acerca el final.
      expect(
        presion(aGanar: 4, propias: 2, ajenas: 3).valor,
        greaterThan(presion(aGanar: 4, propias: 1, ajenas: 1).valor),
      );
    });

    test('consecuencias: "quedás 3-2 abajo"', () {
      SeriePlayoff s(int a, int b) => SeriePlayoff(
        ronda: RondaPlayoff.semifinalConferencia,
        altoId: 'CHI',
        bajoId: 'NYK',
        victoriasAlto: a,
        victoriasBajo: b,
      );
      expect(consecuenciaDeSerie(s(2, 2), s(2, 3), 'CHI'), 'Perdiste: quedás abajo 2-3. Un partido más y se termina.');
      expect(consecuenciaDeSerie(s(2, 2), s(3, 2), 'CHI'), contains('arriba 3-2'));
      expect(consecuenciaDeSerie(s(3, 3), s(4, 3), 'CHI'), contains('pasás de ronda'));
      expect(consecuenciaDeSerie(s(3, 3), s(3, 4), 'CHI'), contains('eliminado'));
      expect(consecuenciaDeSerie(s(1, 1), s(1, 1), 'CHI'), isNull);
      // Desde el lado del que tiene la serie en contra.
      expect(consecuenciaDeSerie(s(2, 2), s(2, 3), 'NYK'), contains('Ganaste'));
    });

    test('ContextoNarrativo: nunca vacío y recoge racha, rivalidad y presión', () {
      final t = conPatron('GGGGGG');
      final proximo = liga.proximoDelUsuario(t)!;
      final rivalId = proximo.localId == 'CHI' ? proximo.visitanteId : proximo.localId;
      final (m, _) = Rivalidades.registrar(
        const Metajuego(),
        serie(3, 3).copyWith(
          series: [
            SeriePlayoff(
              ronda: RondaPlayoff.finalConferencia,
              altoId: 'CHI',
              bajoId: rivalId,
              victoriasAlto: 3,
              victoriasBajo: 3,
            ),
          ],
        ),
        serie(3, 4).copyWith(
          series: [
            SeriePlayoff(
              ronda: RondaPlayoff.finalConferencia,
              altoId: 'CHI',
              bajoId: rivalId,
              victoriasAlto: 3,
              victoriasBajo: 4,
            ),
          ],
        ),
        numero: 1,
      );
      final ctx = ContextoNarrativo.de(conId(t, 'nueva'), liga, rivalidades: m.rivalidades, nombre: nombre);
      expect(ctx.rachaPropia, 6);
      expect(ctx.invicto, isTrue);
      expect(ctx.rivalidad!.nivel, isNot(NivelRivalidad.fria));
      expect(ctx.lineas, isNotEmpty);
      expect(ctx.lineas.length, lessThanOrEqualTo(5));
      expect(ctx.lineas.any((l) => l.contains('te sacaron')), isTrue);

      final sinNada = ContextoNarrativo.de(inicio, liga, nombre: nombre);
      expect(sinNada.lineas, isNotEmpty);
      final conSerie = ContextoNarrativo.de(
        inicio,
        liga,
        serie: SeriePlayoff(
          ronda: RondaPlayoff.finalesNba,
          altoId: 'CHI',
          bajoId: 'NYK',
          victoriasAlto: 3,
          victoriasBajo: 3,
        ),
        nombre: nombre,
      );
      expect(conSerie.esDecisivo, isTrue);
      expect(conSerie.lineas.first, startsWith('PARTIDO 7'));
    });
  });
}
