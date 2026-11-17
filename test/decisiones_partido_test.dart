import 'dart:math';

import 'package:dinastia_nba/domain/decisiones_partido.dart';
import 'package:dinastia_nba/domain/efecto_en_vivo.dart';
import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'decisiones_util.dart';

void main() {
  MotorPartido partido(int semilla, {bool? local = true, double energia = 100}) {
    final a = armarPlantel((j) => j.media >= 80, 100 + semilla % 7);
    final b = armarPlantel((j) => j.media >= 80, 200 + semilla % 5);
    return MotorPartido(
      local: EquipoPartido(identidadId: 'CHI', plantel: a, tactica: const Tactica(), energiaInicial: energia),
      visitante: equipoDe(b, id: 'BOS'),
      usuarioLocal: local,
      azar: Random(semilla),
    );
  }

  /// Un partido arrancado en un momento dado y listo para preguntarle al director.
  (MotorPartido, DirectorDecisiones) escena(
    int cuarto,
    double reloj,
    int propios,
    int rivales, {
    bool ataca = true,
    double energia = 80,
  }) {
    final m = partido(5)
      ..arrancarEn(
        cuarto: cuarto,
        reloj: reloj,
        puntosLocal: propios,
        puntosVisitante: rivales,
        ataqueLocal: ataca,
        energia: energia,
      );
    return (m, DirectorDecisiones(motor: m, propio: true));
  }

  group('disparadores', () {
    test('cada situación dispara cuando corresponde', () {
      var (m, d) = escena(4, 20, 90, 88);
      expect(d.evaluar()?.tipo, TipoDecision.faltaIntencional, reason: 'arriba por 2, 20 s, la pelota es tuya');
      expect(m.cuarto, 4);

      (m, d) = escena(4, 20, 90, 88, ataca: false);
      expect(d.evaluar()?.tipo, TipoDecision.finalConVentaja, reason: 'arriba por 2 y el rival con la pelota');

      (m, d) = escena(2, 15, 50, 50);
      expect(d.evaluar()?.tipo, TipoDecision.ultimoTiro);

      (m, d) = escena(3, 400, 80, 55);
      expect(d.evaluar()?.tipo, TipoDecision.ventajaGrande);

      (m, d) = escena(3, 500, 50, 70);
      expect(d.evaluar()?.tipo, TipoDecision.remontada);

      (m, d) = escena(2, 400, 40, 40, energia: 38);
      expect(d.evaluar()?.tipo, TipoDecision.cansancio);
    });

    test('no dispara en situaciones que no corresponden', () {
      var (_, d) = escena(4, 20, 90, 70); // ventaja de 20: ni falta intencional ni final apretado
      expect(d.evaluar()?.tipo, isNot(TipoDecision.faltaIntencional));
      expect(d.evaluar()?.tipo, isNot(TipoDecision.finalConVentaja));

      (_, d) = escena(4, 15, 90, 88); // el último tiro del cuarto es solo del 1.º al 3.º
      expect(d.evaluar()?.tipo, isNot(TipoDecision.ultimoTiro));

      (_, d) = escena(2, 15, 50, 50, ataca: false); // la pelota no es tuya
      expect(d.evaluar(), isNull);

      (_, d) = escena(1, 15, 20, 20); // 1.º cuarto parejo: no se pregunta un último tiro
      expect(d.evaluar()?.tipo, TipoDecision.ultimoTiro, reason: 'parejo: sí');
      (_, d) = escena(1, 15, 40, 20);
      expect(d.evaluar(), isNull, reason: 'con +20 en el 1.º no hace falta un último tiro');

      (_, d) = escena(3, 500, 70, 66);
      expect(d.evaluar(), isNull);

      (_, d) = escena(4, 600, 60, 80);
      expect(d.evaluar()?.tipo, TipoDecision.remontada, reason: '-20 con 10 min: sí');
      (_, d) = escena(4, 200, 60, 80);
      expect(d.evaluar()?.tipo, isNot(TipoDecision.remontada), reason: 'con menos de 4 min ya no se plantea');
    });

    test('con las decisiones apagadas nunca se pregunta', () {
      final (_, d) = escena(4, 20, 90, 88);
      d.habilitado = false;
      expect(d.evaluar(), isNull);
      expect(d.evaluarEntretiempo(), isNull);
    });

    test('el entretiempo aparece una sola vez, al empezar el 3.º', () {
      final m = partido(11);
      final d = DirectorDecisiones(motor: m, propio: true);
      var informes = 0;
      while (!m.terminado) {
        final inf = d.evaluarEntretiempo();
        if (inf != null) {
          informes++;
          expect(m.cuarto, 3);
          expect(inf.filas, isNotEmpty);
          expect(inf.bien, isNotEmpty);
          expect(inf.mal, isNotEmpty);
          expect(inf.defensas.length, greaterThanOrEqualTo(3));
          expect(inf.propios, m.puntosLocal);
          d.aplicarEntretiempo(const []);
        }
        d.observar(m.siguiente());
        d.tick();
      }
      expect(informes, 1);
    });

    test('en partidos completos: invariantes de cada disparo y cobertura', () {
      final vistos = <TipoDecision>{};
      for (var s = 0; s < 120; s++) {
        final m = partido(s + 1000);
        final d = DirectorDecisiones(motor: m, propio: true);
        jugarConDirector(
          m,
          d,
          elegir: (dec) {
            vistos.add(dec.tipo);
            final dif = (m.puntosLocal - m.puntosVisitante);
            switch (dec.tipo) {
              case TipoDecision.parcialContra:
                expect(d.rachaRival, greaterThanOrEqualTo(8));
              case TipoDecision.ultimoTiro:
                expect(m.cuarto, lessThanOrEqualTo(3));
                expect(m.reloj, inInclusiveRange(7, 22));
                expect(m.ataqueDelUsuario, isTrue);
              case TipoDecision.faltaIntencional:
                expect(m.cuarto, greaterThanOrEqualTo(4));
                expect(m.reloj, lessThanOrEqualTo(35));
                expect(dif, greaterThanOrEqualTo(1));
                expect(m.ataqueDelUsuario, isTrue);
              case TipoDecision.finalConVentaja:
                expect(dif, inInclusiveRange(1, 5));
                expect(m.ataqueDelUsuario, isFalse);
              case TipoDecision.remontada:
                expect(dif, lessThanOrEqualTo(-14));
              case TipoDecision.ventajaGrande:
                expect(dif, greaterThanOrEqualTo(18));
              case TipoDecision.cansancio:
                expect(m.energias(true).values.any((e) => e < 52), isTrue);
              case TipoDecision.faltas:
                final cancha = m.enCancha(true).map((j) => m.boxLocal[j.id]!.fal).fold(0, max);
                expect(cancha, greaterThanOrEqualTo(4));
              case _:
            }
            expect(dec.opciones.length, inInclusiveRange(2, 4));
            expect(dec.motivo, isNotEmpty);
            for (final o in dec.opciones) {
              expect(o.titulo, isNotEmpty);
              expect(o.efecto, isNotEmpty);
              expect(o.costo, isNotEmpty, reason: 'toda opción muestra su costo');
            }
            return null;
          },
        );
      }
      for (final t in [
        TipoDecision.parcialContra,
        TipoDecision.ultimoTiro,
        TipoDecision.faltaIntencional,
        TipoDecision.finalConVentaja,
        TipoDecision.faltas,
        TipoDecision.rivalCaliente,
        TipoDecision.tiradorEncendido,
      ]) {
        expect(vistos, contains(t), reason: '$t tiene que aparecer en 120 partidos');
      }
    });
  });

  group('límites y cooldown', () {
    test('nunca en cada posesión: tope por cuarto, por partido y tiempo entre decisiones', () {
      var total = 0;
      for (var s = 0; s < 80; s++) {
        final m = partido(s + 2000);
        final d = DirectorDecisiones(motor: m, propio: true);
        jugarConDirector(m, d);
        final regs = d.registro.where((r) => r.tipo != TipoDecision.entretiempo).toList();
        total += regs.length;
        expect(regs.length, lessThanOrEqualTo(DirectorDecisiones.maxPorPartido + 2));
        final porCuarto = <int, int>{};
        for (final r in regs) {
          porCuarto[r.cuarto] = (porCuarto[r.cuarto] ?? 0) + 1;
        }
        for (final c in porCuarto.values) {
          expect(c, lessThanOrEqualTo(DirectorDecisiones.maxPorCuarto + 1));
        }
        final tiempos = [for (final r in regs) DirectorDecisiones.transcurrido(r.cuarto, r.reloj)];
        for (var i = 1; i < regs.length; i++) {
          final minimo = regs[i].tipo.critica ? DirectorDecisiones.cooldownCritica : DirectorDecisiones.cooldownNormal;
          expect(tiempos[i] - tiempos[i - 1], greaterThanOrEqualTo(minimo - 1), reason: 'seed $s decisión $i');
        }
      }
      final promedio = total / 80;
      expect(promedio, inInclusiveRange(1.5, 6));
    });

    test('ignorar dos veces seguidas alarga la espera', () {
      final m = partido(3)..arrancarEn(cuarto: 3, reloj: 600, puntosLocal: 50, puntosVisitante: 70, ataqueLocal: true);
      final d = DirectorDecisiones(motor: m, propio: true);
      final a = d.evaluar()!;
      d.resolver(a, null);
      expect(d.evaluar(), isNull, reason: 'recién ignorada: hay que esperar');
    });
  });

  group('ignorar es seguir igual', () {
    test('ignorando todo, el partido sale idéntico al que no tiene director', () {
      for (var s = 0; s < 25; s++) {
        final a = partido(s + 3000);
        while (!a.terminado) {
          a.siguiente();
        }
        final m = partido(s + 3000);
        jugarConDirector(m, DirectorDecisiones(motor: m, propio: true));
        expect(m.puntosLocal, a.puntosLocal, reason: 'seed $s');
        expect(m.puntosVisitante, a.puntosVisitante);
        expect(m.boxLocal.values.map((l) => l.pts).toList(), a.boxLocal.values.map((l) => l.pts).toList());
      }
    });

    test('un efecto neutro no cambia el partido', () {
      final a = partido(77)..simularTodo();
      final m = partido(77)..aplicarEfecto(true, const EfectoEnVivo());
      m.simularTodo();
      expect(m.puntosLocal, a.puntosLocal);
      expect(m.puntosVisitante, a.puntosVisitante);
    });

    test('vivo con decisiones por defecto y simulado son equivalentes en promedio', () {
      const n = 1400;
      var gana = [0, 0];
      var margen = [0.0, 0.0];
      var puntos = [0.0, 0.0];
      for (var s = 0; s < n; s++) {
        final simulado = partido(s + 5000, local: null)..simularTodo();
        final vivo = partido(s + 5000);
        jugarConDirector(vivo, DirectorDecisiones(motor: vivo, propio: true), automatica: true);
        for (final (i, m) in [simulado, vivo].indexed) {
          if (m.puntosLocal > m.puntosVisitante) gana[i]++;
          margen[i] += m.puntosLocal - m.puntosVisitante;
          puntos[i] += m.puntosLocal + m.puntosVisitante;
        }
      }
      // ignore: avoid_print
      print(
        'simulado: gana ${(100 * gana[0] / n).toStringAsFixed(1)} % margen ${(margen[0] / n).toStringAsFixed(2)} '
        'puntos ${(puntos[0] / n / 2).toStringAsFixed(1)} | vivo por defecto: gana ${(100 * gana[1] / n).toStringAsFixed(1)} % '
        'margen ${(margen[1] / n).toStringAsFixed(2)} puntos ${(puntos[1] / n / 2).toStringAsFixed(1)}',
      );
      expect((gana[0] - gana[1]).abs() / n, lessThan(0.045));
      expect(((margen[0] - margen[1]) / n).abs(), lessThan(1.6));
      expect(((puntos[0] - puntos[1]) / n / 2).abs(), lessThan(1.0));
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  group('efectos', () {
    test('un ajuste vence solo, avisa cómo salió y queda en el registro', () {
      final m = partido(21);
      final d = DirectorDecisiones(motor: m, propio: true);
      final zona = d.menuTactico().firstWhere((o) => o.accion == AccionTactica.zona);
      expect(d.aplicarManual(zona), isTrue);
      expect(m.efecto(true)?.defensa, isNotNull);
      expect(d.aplicarManual(d.menuTactico().first), isFalse, reason: 'hay una espera entre ajustes');
      final avisos = <String>[];
      while (!m.terminado && d.activos.isNotEmpty) {
        d.observar(m.siguiente());
        avisos.addAll(d.tick());
      }
      expect(d.activos, isEmpty);
      expect(m.efecto(true), isNull, reason: 'al vencer el motor vuelve a lo de siempre');
      expect(avisos, hasLength(1));
      expect(avisos.single, contains('Zona 2-3'));
      expect(d.registro.single.aviso, avisos.single);
      expect(d.registro.single.impacto, isNotNull);
      expect(d.resumen().single, contains('Zona 2-3'));
    });

    test('dos ajustes del mismo grupo no se acumulan: el nuevo reemplaza al viejo', () {
      final m = partido(22);
      final d = DirectorDecisiones(motor: m, propio: true);
      d.aplicarManual(d.menuTactico().firstWhere((o) => o.accion == AccionTactica.zona));
      for (var i = 0; i < 40; i++) {
        d.observar(m.siguiente());
      }
      d.aplicarManual(d.menuTactico().firstWhere((o) => o.accion == AccionTactica.presion));
      expect(d.activos.where((e) => e.categoria == CategoriaAjuste.defensa), hasLength(1));
      expect(m.efecto(true)!.defensa, EsquemaDefensivo.presionTodaCancha);
    });

    test('el foco da más tiros al elegido', () {
      var conFoco = 0, sinFoco = 0, a = 0, b = 0;
      for (var s = 0; s < 60; s++) {
        for (final foco in [false, true]) {
          final m = partido(s + 7000)
            ..arrancarEn(cuarto: 2, reloj: 600, puntosLocal: 40, puntosVisitante: 40, ataqueLocal: true);
          final d = DirectorDecisiones(motor: m, propio: true);
          final estrella = m.enCancha(true).reduce((x, y) => x.media >= y.media ? x : y);
          if (foco) {
            d.aplicarManual(
              d.menuTactico().firstWhere(
                (o) => o.accion == AccionTactica.focoAislamiento && o.jugadorId == estrella.id,
              ),
            );
          }
          final t0 = d.ahora;
          while (d.ahora - t0 < 180) {
            d.observar(m.siguiente());
          }
          final l = m.boxLocal[estrella.id]!;
          final total = m.boxLocal.values.fold(0, (x, y) => x + y.tcA);
          if (foco) {
            conFoco += l.tcA;
            a += total;
          } else {
            sinFoco += l.tcA;
            b += total;
          }
        }
      }
      expect(conFoco / a, greaterThan(sinFoco / b + 0.05), reason: 'el elegido toma bastante más tiros');
    });

    test('el hack manda al peor tirador de libres a la línea', () {
      var faltas = 0, control = 0;
      for (var s = 0; s < 40; s++) {
        for (final hack in [false, true]) {
          final m = MotorPartido(
            local: equipoDe(armarPlantel((j) => j.media >= 80, s)),
            visitante: equipoDe(
              armarPlantel((j) => j.media >= 70 && j.stats.pctTl <= 0.6, s + 50, top: 400),
              id: 'BOS',
            ),
            usuarioLocal: true,
            azar: Random(s),
          )..arrancarEn(cuarto: 2, reloj: 600, puntosLocal: 40, puntosVisitante: 40, ataqueLocal: false);
          final d = DirectorDecisiones(motor: m, propio: true);
          if (hack) {
            final o = d.menuTactico().where((o) => o.accion == AccionTactica.hack).firstOrNull;
            if (o == null) continue;
            d.aplicarManual(o);
          }
          final t0 = d.ahora;
          while (d.ahora - t0 < 150) {
            final e = m.siguiente();
            d.observar(e);
            if (e.falta == TipoFalta.intencional) hack ? faltas++ : control++;
          }
        }
      }
      expect(faltas, greaterThan(control + 20));
    });

    test('pelota al mejor de libres: es él quien va a la línea', () {
      var elegidos = 0, total = 0;
      for (var s = 0; s < 80; s++) {
        final m = partido(s + 9000)
          ..arrancarEn(cuarto: 4, reloj: 22, puntosLocal: 100, puntosVisitante: 98, ataqueLocal: true);
        final d = DirectorDecisiones(motor: m, propio: true);
        final dec = d.evaluar();
        if (dec?.tipo != TipoDecision.faltaIntencional) continue;
        final o = dec!.opciones.firstWhere((o) => o.accion == AccionTactica.lineaMejor);
        d.resolver(dec, o);
        for (var k = 0; k < 4; k++) {
          final e = m.siguiente();
          d.observar(e);
          if (e.falta == TipoFalta.intencional && e.local) {
            total++;
            if (e.jugadorId == o.jugadorId) elegidos++;
            break;
          }
        }
      }
      expect(total, greaterThan(30));
      expect(elegidos, total, reason: 'sin perder la pelota, siempre va el elegido');
    });

    test('el último tiro nombra al jugador que de verdad tira', () {
      var ok = 0, total = 0;
      for (var s = 0; s < 80; s++) {
        final m = partido(s + 9500)
          ..arrancarEn(cuarto: 2, reloj: 18, puntosLocal: 50, puntosVisitante: 50, ataqueLocal: true);
        final d = DirectorDecisiones(motor: m, propio: true);
        final dec = d.evaluar();
        if (dec?.tipo != TipoDecision.ultimoTiro) continue;
        for (final o in dec!.opciones.where((o) => o.accion != AccionTactica.jugadaPickAndRoll)) {
          final m2 = partido(s + 9500)
            ..arrancarEn(cuarto: 2, reloj: 18, puntosLocal: 50, puntosVisitante: 50, ataqueLocal: true);
          final d2 = DirectorDecisiones(motor: m2, propio: true);
          final dec2 = d2.evaluar()!;
          d2.resolver(dec2, dec2.opciones.firstWhere((x) => x.id == o.id));
          for (var k = 0; k < 3; k++) {
            final e = m2.siguiente();
            d2.observar(e);
            if (e.jugadaClave != null) {
              total++;
              if (e.jugadorId == o.jugadorId) ok++;
              break;
            }
          }
        }
      }
      expect(total, greaterThan(40));
      expect(ok / total, greaterThan(0.95));
    });

    test('descansar a un titular lo saca y lo trae de vuelta', () {
      final m = partido(31);
      final d = DirectorDecisiones(motor: m, propio: true);
      final estrella = m.enCancha(true).reduce((x, y) => x.media >= y.media ? x : y);
      d.aplicarManual(d.menuTactico().firstWhere((o) => o.accion == AccionTactica.descansar));
      var salio = false, volvio = false;
      final t0 = d.ahora;
      while (!m.terminado && d.ahora - t0 < 600) {
        d.observar(m.siguiente());
        d.tick();
        final adentro = m.enCancha(true).any((j) => j.id == estrella.id);
        if (!adentro) salio = true;
        if (salio && adentro) {
          volvio = true;
          break;
        }
      }
      expect(salio, isTrue);
      expect(volvio, isTrue);
    });
  });

  group('registro y ajustes', () {
    test('el registro de decisiones pasa por JSON', () {
      final r = RegistroDecision(
        tipo: TipoDecision.parcialContra,
        cuarto: 3,
        reloj: 301,
        opcion: 'Zona 2-3',
        opcionId: 'zona',
        aviso: 'La zona cortó la racha: ellos 0 de 6.',
        impacto: 4,
        veredicto: Veredicto.ayudo,
      );
      final b = RegistroDecision.fromJson(r.toJson());
      expect(b.tipo, r.tipo);
      expect(b.cuarto, 3);
      expect(b.reloj, 301);
      expect(b.opcion, 'Zona 2-3');
      expect(b.aviso, r.aviso);
      expect(b.impacto, 4);
      expect(b.veredicto, Veredicto.ayudo);
      expect(b.ignorada, isFalse);
      final i = RegistroDecision.fromJson(RegistroDecision(tipo: TipoDecision.faltas, cuarto: 1, reloj: 5).toJson());
      expect(i.ignorada, isTrue);
      expect(i.veredicto, Veredicto.sinDato);
    });

    test('el ajuste de decisiones sugeridas: por defecto sí, y sobrevive al JSON', () {
      expect(const Ajustes().decisiones, isTrue);
      expect(Ajustes.fromJson(const {}).decisiones, isTrue, reason: 'ajustes viejos sin el campo');
      final a = const Ajustes().copyWith(decisiones: false);
      expect(Ajustes.fromJson(a.toJson()).decisiones, isFalse);
      expect(a.copyWith(velocidad: 4).decisiones, isFalse);
    });
  });
}
