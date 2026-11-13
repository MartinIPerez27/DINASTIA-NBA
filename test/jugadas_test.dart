import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/relator.dart';
import 'package:dinastia_nba/presentation/partido/coreografia.dart';
import 'package:flutter_test/flutter_test.dart';

/// Todas las jugadas de un partido NBA, a tasas creíbles (por partido, sumando los dos equipos).
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(3));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final t = liga.iniciar(Temporada(id: 'jug', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  final jugadores = {for (final j in catalogo) j.id: j};

  const partidos = 40;
  final cuenta = <String, int>{};
  void suma(String k, [int v = 1]) => cuenta[k] = (cuenta[k] ?? 0) + v;
  final faltasPersonales = <(int, bool)>[]; // (faltas del equipo que la comete, ¿era bonus?)
  final intencionales = <EventoPartido>[];
  final fallasIntencional = <String>[];
  final finesDeCuarto = <EventoPartido>[];
  var puntosInterferencia = true;
  final relator = Relator(azar: Random(1));
  final frases = <String>[];

  setUpAll(() {
    for (final (i, pa) in t.calendario.take(partidos).indexed) {
      final m = liga.motor(t, pa, azar: Random(100 + i));
      while (!m.terminado) {
        final antes = (m.puntosLocal, m.puntosVisitante, m.cuarto, m.reloj);
        final enCanchaAtaque = {
          for (final local in [true, false]) local: m.enCancha(local),
        };
        final e = m.siguiente();
        frases.add(relator.frase(e, jugadores));
        if (e.taponado) suma('tapones');
        if (e.taponado && e.reboteOfensivo) suma('tapones recuperados');
        if (e.tipo == TipoEvento.perdida) {
          suma('perdidas');
          suma('perdida ${e.perdida!.name}');
        }
        if (e.tipo == TipoEvento.falta) suma('falta ${e.falta!.name}');
        if (e.tipo == TipoEvento.salto) suma('salto');
        if (e.desdeLejos) suma('desde lejos');
        if (e.chicharra && e.tipo == TipoEvento.tiro) finesDeCuarto.add(e);
        if (e.interferencia) {
          suma('interferencia');
          final hechos = e.local ? e.marcadorLocal - antes.$1 : e.marcadorVisitante - antes.$2;
          if (!e.convertido || hechos != e.puntos || e.puntos < 2) puntosInterferencia = false;
        }
        if (e.expulsadoId != null) suma('expulsiones');
        if (e.tipo == TipoEvento.falta && (e.falta == TipoFalta.personal || e.falta == TipoFalta.bonus)) {
          faltasPersonales.add((m.faltas(!e.local), e.falta == TipoFalta.bonus));
        }
        if (e.falta == TipoFalta.intencional) {
          intencionales.add(e);
          // Al peor tirador de libres de los que estaban en cancha.
          final enCancha = enCanchaAtaque[e.local]!;
          final peor = enCancha.reduce((a, b) => a.stats.pctTl <= b.stats.pctTl ? a : b);
          if (jugadores[e.jugadorId]!.stats.pctTl > peor.stats.pctTl) fallasIntencional.add('no fue al peor tirador');
          final ventaja = e.local ? antes.$1 - antes.$2 : antes.$2 - antes.$1;
          if (antes.$3 < 4 || antes.$4 > 35 || ventaja < 3 || ventaja > 8) {
            fallasIntencional.add('cuarto ${antes.$3}, reloj ${antes.$4}, ventaja $ventaja');
          }
        }
      }
      for (final l in [...m.boxLocal.values, ...m.boxVisitante.values]) {
        suma('faltas', l.fal);
        suma('libres', l.tlA);
        suma('robos', l.rob);
        suma('puntos', l.pts);
      }
    }
  });

  double porPartido(String k) => (cuenta[k] ?? 0) / partidos;

  test('tasas por partido como en la NBA (los dos equipos)', () {
    final resumen = {for (final k in cuenta.keys.toList()..sort()) k: porPartido(k).toStringAsFixed(2)};
    expect(porPartido('tapones'), inInclusiveRange(7, 14), reason: '$resumen');
    expect(porPartido('robos'), inInclusiveRange(11, 19), reason: '$resumen');
    expect(porPartido('perdidas'), inInclusiveRange(21, 32), reason: '$resumen');
    expect(porPartido('faltas'), inInclusiveRange(33, 47), reason: '$resumen');
    expect(porPartido('libres'), inInclusiveRange(36, 54), reason: '$resumen');
    expect(porPartido('puntos') / 2, inInclusiveRange(90, 118), reason: '$resumen');
    // Las jugadas raras aparecen, pero poco.
    expect(porPartido('falta tecnica'), inInclusiveRange(0.1, 0.9), reason: '$resumen');
    expect(porPartido('salto'), inInclusiveRange(0.05, 0.8), reason: '$resumen');
    expect(porPartido('interferencia'), inInclusiveRange(0.1, 0.9), reason: '$resumen');
    expect(porPartido('falta flagrante'), lessThanOrEqualTo(0.2), reason: '$resumen');
    expect(porPartido('expulsiones'), lessThan(0.5), reason: '$resumen');
    expect(porPartido('tapones recuperados'), greaterThan(porPartido('tapones') * 0.2), reason: '$resumen');
    for (final tipo in TipoPerdida.values) {
      expect(cuenta['perdida ${tipo.name}'] ?? 0, greaterThan(0), reason: 'nunca hubo ${tipo.nombre}: $resumen');
    }
    for (final tipo in [TipoFalta.personal, TipoFalta.bonus, TipoFalta.intencional, TipoFalta.tecnica]) {
      expect(cuenta['falta ${tipo.name}'] ?? 0, greaterThan(0), reason: 'nunca hubo ${tipo.nombre}: $resumen');
    }
    expect(cuenta['desde lejos'] ?? 0, greaterThan(0), reason: '$resumen');
  });

  test('faltas de equipo: hasta la 4.ª saque lateral, desde la 5.ª en el cuarto, bonus con 2 libres', () {
    expect(faltasPersonales, isNotEmpty);
    for (final (faltas, bonus) in faltasPersonales) {
      expect(bonus, faltas >= 5, reason: '$faltas faltas del equipo');
    }
  });

  test('falta intencional: solo en el final, del que pierde de 3 a 8, al peor tirador de libres', () {
    expect(intencionales, isNotEmpty);
    expect(fallasIntencional, isEmpty);
    for (final e in intencionales) {
      expect(e.libres, 2);
      expect(e.puntos, inInclusiveRange(0, 2));
    }
  });

  test('interferencia: la canasta vale para el tirador', () => expect(puntosInterferencia, isTrue));

  test('la chicharra: los tiros con el reloj en cero cierran el cuarto', () {
    expect(finesDeCuarto, isNotEmpty);
    for (final e in finesDeCuarto) {
      expect(e.reloj, 0, reason: e.texto);
    }
  });

  test('dos técnicas al mismo jugador: expulsado (y no cuentan como faltas personales)', () {
    final pa = liga.proximoDelUsuario(t)!;
    final m = liga.motor(t, pa, azar: Random(7));
    final tecnicas = <String, int>{};
    String? expulsado;
    for (var i = 0; i < 12 && expulsado == null; i++) {
      final e = m.tecnicaDePrueba();
      expect(e.tipo, TipoEvento.falta);
      expect(e.falta, TipoFalta.tecnica);
      expect(e.libres, 1);
      tecnicas[e.defensorId!] = (tecnicas[e.defensorId!] ?? 0) + 1;
      if (e.expulsadoId != null) {
        expulsado = e.expulsadoId;
        expect(tecnicas[expulsado], 2);
      }
    }
    expect(expulsado, isNotNull);
    expect(m.expulsado(expulsado!), isTrue);
    final box = {...m.boxLocal, ...m.boxVisitante};
    expect(box[expulsado]!.fal, 0, reason: 'la técnica no es falta personal');
    // En la próxima pausa sale: el siguiente evento es el cambio.
    final cambio = m.siguiente();
    expect(cambio.tipo, TipoEvento.cambio);
    expect(cambio.saleId, expulsado);
  });

  test('el relator tiene frase para todo (sin nombres vacíos)', () {
    expect(frases.where((f) => f.trim().isEmpty), isEmpty);
    expect(frases.where((f) => f.contains('  ') || f.contains(' :')), isEmpty);
  });

  test('coreografía de todas las jugadas nuevas: continua, dentro de la cancha y sin teletransporte', () {
    final vistos = <String>{};
    for (var g = 0; g < 6; g++) {
      final m = liga.motor(t, t.calendario[g], azar: Random(500 + g));
      final posiciones = <String, Offset>{};
      var balon = const Offset(25, 47);
      String? poseedor;
      var segunda = false;
      var cuarto = 1;
      while (!m.terminado) {
        final e = m.siguiente();
        final ataca = switch (e.tipo) {
          TipoEvento.tiro ||
          TipoEvento.libres ||
          TipoEvento.perdida ||
          TipoEvento.falta ||
          TipoEvento.salto ||
          TipoEvento.cambio => e.local,
          _ => true,
        };
        cuarto = e.tipo == TipoEvento.finCuarto ? e.cuarto - 1 : e.cuarto;
        final c = Coreografia(
          evento: e,
          atacantes: List.of(m.enCancha(ataca)),
          defensores: List.of(m.enCancha(!ataca)),
          haciaArriba: ataca == (cuarto <= 2),
          desde: Map.of(posiciones),
          balonDesde: balon,
          poseedorDesde: poseedor,
          segundaOportunidad: segunda,
          saliente: e.tipo == TipoEvento.cambio ? liga.jugador(e.saleId ?? '') : null,
        );
        final clase = e.falta?.name ?? e.perdida?.name ?? (e.desdeLejos ? 'lejos' : e.tipo.name);
        vistos.add(clase);
        expect(c.duracion, inInclusiveRange(1.2, 16), reason: '$clase: ${e.texto}');
        if (e.falta != null && e.falta != TipoFalta.personal) expect(c.momentoSilbato, isNotNull, reason: e.texto);
        if (e.perdida?.silbato ?? false) expect(c.momentoSilbato, isNotNull, reason: e.texto);
        if (e.taponado) expect(c.momentoTapon, isNotNull);
        for (final j in [...c.atacantes, ...c.defensores]) {
          if (posiciones[j.id] case final antes?) {
            expect((c.posicion(j.id, 0) - antes).distance, lessThan(1.5), reason: '$clase ${j.nombre}');
          }
          var previa = c.posicion(j.id, 0);
          final pasos = (c.duracion * 60).ceil();
          for (var k = 1; k <= pasos; k++) {
            final ahora = c.posicion(j.id, k / pasos);
            expect((ahora - previa).distance * 60, lessThan(32), reason: '$clase ${j.nombre} $k/$pasos');
            expect(ahora.dx, inInclusiveRange(-4, 54), reason: '$clase ${j.nombre}');
            expect(ahora.dy, inInclusiveRange(-4, 98), reason: '$clase ${j.nombre}');
            previa = ahora;
          }
        }
        var previaBalon = c.balon(0).$1;
        expect((previaBalon - balon).distance, lessThan(3), reason: 'la pelota arranca donde quedó: $clase');
        final pasosBalon = (c.duracion * 60).ceil();
        for (var k = 1; k <= pasosBalon; k++) {
          final ahora = c.balon(k / pasosBalon).$1;
          expect((ahora - previaBalon).distance * 60, lessThan(95), reason: 'pelota en $clase $k/$pasosBalon');
          previaBalon = ahora;
        }
        // Salta el que tapa (y el que tira).
        if (e.taponado) {
          final pico = [for (var k = 0; k <= 100; k++) c.salto(e.defensorId!, k / 100)].reduce(max);
          expect(pico, greaterThan(0.9));
        }
        for (final j in [...c.atacantes, ...c.defensores]) {
          posiciones[j.id] = c.posicion(j.id, 1);
        }
        if (c.saliente case final s?) posiciones.remove(s.id);
        balon = c.balon(1).$1;
        poseedor = c.poseedorFinal;
        segunda = e.tipo == TipoEvento.tiro && e.reboteOfensivo;
      }
    }
    expect(vistos, containsAll(['personal', 'bonus', 'robo', 'afuera', 'carga', 'tiro', 'libres']));
    // 6 partidos completos de coreografía: con toda la suite en paralelo puede pasar los 30 s por defecto.
  }, timeout: const Timeout(Duration(minutes: 3)));
}
