import 'dart:math';

import 'package:dinastia_nba/domain/decisiones_partido.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'decisiones_util.dart';

/// Decisiones como jugador (Mi carrera): solo tus momentos, y de verdad cambian el partido.
void main() {
  MotorPartido partido(int semilla) {
    final a = armarPlantel((j) => j.media >= 80, 100 + semilla % 7);
    final b = armarPlantel((j) => j.media >= 80, 200 + semilla % 5);
    return MotorPartido(
      local: EquipoPartido(identidadId: 'CHI', plantel: a, tactica: const Tactica()),
      visitante: equipoDe(b, id: 'BOS'),
      usuarioLocal: true,
      azar: Random(semilla),
    );
  }

  PerfilVivo perfil(String id, {int tiro = 80, int fin = 80, int iq = 80, int triple = 0, int pase = 0}) {
    final a = Atributos.de(tiro: tiro, finalizacion: fin, defensa: 70, fisico: 70, iq: iq);
    return PerfilVivo(
      id: id,
      nombre: 'Yo',
      atributos: a,
      espec: {if (triple > 0) Habilidad.triple: triple, if (pase > 0) Habilidad.pase: pase},
    );
  }

  (MotorPartido, DirectorDecisiones) escena(
    int cuarto,
    double reloj,
    int p,
    int r, {
    bool ataca = true,
    PerfilVivo? yo,
  }) {
    final m = partido(5)
      ..arrancarEn(cuarto: cuarto, reloj: reloj, puntosLocal: p, puntosVisitante: r, ataqueLocal: ataca, energia: 80);
    final id = m.enCancha(true).first.id;
    return (m, DirectorDecisiones(motor: m, propio: true, yo: yo ?? perfil(id)));
  }

  test('el final apretado te pregunta a vos qué hacés con la pelota', () {
    final (_, d) = escena(4, 100, 90, 88);
    final dec = d.evaluar();
    expect(dec?.tipo, TipoDecision.tuClutch);
    final acciones = dec!.opciones.map((o) => o.accion).toSet();
    expect(acciones, containsAll([AccionTactica.yoPasar]));
    expect(acciones.any((a) => a == AccionTactica.yoTriple || a == AccionTactica.yoAislamiento), isTrue);
  });

  test('como jugador no aparecen las decisiones de entrenador ni el informe del entretiempo', () {
    final (_, d) = escena(3, 400, 80, 55);
    final dec = d.evaluar();
    expect(dec == null || dec.tipo.name.startsWith('tu') || dec.tipo == TipoDecision.takeover, isTrue);
    final (_, d2) = escena(3, 719.5, 50, 50);
    expect(d2.evaluarEntretiempo(), isNull);
    expect(
      d2.menuTactico().every(
        (o) => const {
          AccionTactica.pedirPelota,
          AccionTactica.atacarAro,
          AccionTactica.tirarTriple,
          AccionTactica.buscarAbierto,
          AccionTactica.cerrarMarca,
          AccionTactica.apostarRobo,
          AccionTactica.guardarEnergia,
          AccionTactica.descansar,
          AccionTactica.takeover,
        }.contains(o.accion),
      ),
      isTrue,
    );
  });

  test('el plan de juego del primer cuarto es de jugador y siempre ofrece opciones', () {
    final m = partido(9);
    final d = DirectorDecisiones(motor: m, propio: true, yo: perfil(m.enCancha(true).first.id));
    final dec = d.evaluar();
    expect(dec?.tipo, TipoDecision.tuPlan);
    expect(dec!.opciones.length, greaterThanOrEqualTo(3));
    expect(dec.opciones.where((o) => o.recomendada), isNotEmpty);
  });

  test('pedir la pelota mueve el foco del motor hacia tu jugador, y rinde según tu nivel ofensivo', () {
    final m = partido(3);
    final id = m.enCancha(true).first.id;
    OpcionDecision pedir(PerfilVivo p) {
      final d = DirectorDecisiones(motor: m, propio: true, yo: p);
      final o = d.menuTactico().firstWhere((o) => o.accion == AccionTactica.pedirPelota);
      d.aplicarManual(o);
      return o;
    }

    pedir(perfil(id, tiro: 60, fin: 60));
    final flojo = m.efecto(true)!;
    expect(flojo.foco, id);
    expect(flojo.focoPeso, greaterThan(1.5));
    final m2 = partido(3);
    final d2 = DirectorDecisiones(motor: m2, propio: true, yo: perfil(id, tiro: 96, fin: 96));
    d2.aplicarManual(d2.menuTactico().firstWhere((o) => o.accion == AccionTactica.pedirPelota));
    expect(m2.efecto(true)!.focoExtra, greaterThan(flojo.focoExtra), reason: 'el crack acierta más con la pelota');
  });

  test('las habilidades nuevas y los rasgos mentales mueven las decisiones', () {
    final m = partido(3);
    final id = m.enCancha(true).first.id;
    final a = Atributos.de(tiro: 80, finalizacion: 80, defensa: 75, fisico: 75, iq: 80);
    double extra(Map<Habilidad, int> espec, AccionTactica acc) {
      final mm = partido(3);
      final d = DirectorDecisiones(motor: mm, propio: true, yo: PerfilVivo(id: id, nombre: 'Yo', atributos: a, espec: espec));
      d.aplicarManual(d.menuTactico().firstWhere((o) => o.accion == acc));
      return mm.efecto(true)!.focoExtra;
    }

    expect(
      extra({Habilidad.tiroDeEsquina: 20, Habilidad.tiroEnMovimiento: 20}, AccionTactica.tirarTriple),
      greaterThan(extra(const {}, AccionTactica.tirarTriple)),
    );
    expect(
      extra({Habilidad.finalizacionContacto: 20, Habilidad.flotadora: 20}, AccionTactica.atacarAro),
      greaterThan(extra(const {}, AccionTactica.atacarAro)),
    );
    expect(
      extra({Habilidad.creacionDeTiro: 20, Habilidad.consistencia: 20}, AccionTactica.pedirPelota),
      greaterThan(extra(const {}, AccionTactica.pedirPelota)),
    );
    // El rasgo Clutch cuenta en la última jugada.
    final base = partido(11)
      ..arrancarEn(cuarto: 4, reloj: 60, puntosLocal: 90, puntosVisitante: 90, ataqueLocal: true, energia: 90);
    String textoDe(Map<Habilidad, int> espec) {
      final d = DirectorDecisiones(motor: base, propio: true, yo: PerfilVivo(id: base.enCancha(true).first.id, nombre: 'Yo', atributos: a, espec: espec));
      return d.evaluar()!.opciones.firstWhere((o) => o.accion == AccionTactica.yoAislamiento || o.accion == AccionTactica.yoTriple).efecto;
    }

    expect(textoDe({Habilidad.clutch: 20}), isNot(textoDe(const {})));
  });

  test('tomar el último tiro lo tira tu jugador; pasar, no', () {
    for (final pasar in [false, true]) {
      var total = 0, cumplen = 0;
      for (var seed = 0; seed < 60; seed++) {
        final m = partido(seed + 40)
          ..arrancarEn(cuarto: 4, reloj: 60, puntosLocal: 90, puntosVisitante: 90, ataqueLocal: true, energia: 90);
        final id = m.enCancha(true).first.id;
        final d = DirectorDecisiones(motor: m, propio: true, yo: perfil(id));
        final dec = d.evaluar();
        if (dec == null) continue;
        d.resolver(
          dec,
          dec.opciones.firstWhere((o) => pasar ? o.accion == AccionTactica.yoPasar : o.accion != AccionTactica.yoPasar),
        );
        for (var k = 0; k < 4; k++) {
          final e = m.siguiente();
          if (e.jugadaClave != null) {
            total++;
            if ((e.jugadorId == id) != pasar) cumplen++;
            break;
          }
        }
      }
      expect(total, greaterThan(25));
      expect(cumplen / total, greaterThan(0.95), reason: pasar ? 'pasar: otro tira' : 'pedir la última: tira él');
    }
  });

  test('tu racha carga el Takeover y se puede activar una vez por cuarto', () {
    final m = partido(7)
      ..arrancarEn(cuarto: 2, reloj: 400, puntosLocal: 40, puntosVisitante: 40, ataqueLocal: true, energia: 90);
    final id = m.enCancha(true).first.id;
    final d = DirectorDecisiones(motor: m, propio: true, yo: perfil(id));
    expect(d.takeoverCarga, 0);
    for (var i = 0; i < 4; i++) {
      d.observar(
        EventoPartido(
          tipo: TipoEvento.tiro,
          local: true,
          cuarto: 2,
          reloj: 400.0 - i * 10,
          marcadorLocal: 40,
          marcadorVisitante: 40,
          texto: '',
          jugadorId: id,
          convertido: true,
          puntos: 2,
        ),
      );
    }
    expect(d.takeoverCarga, greaterThanOrEqualTo(70));
    final o = d.menuTactico().firstWhere((o) => o.accion == AccionTactica.takeover);
    d.aplicarManual(o);
    expect(d.takeoversUsados, 1);
    expect(m.efecto(true)!.focoPeso, greaterThan(2));
    expect(d.menuTactico().any((o) => o.accion == AccionTactica.takeover), isFalse);
  });

  test('de verdad cambia el partido: pedir la pelota da más tiros a tu jugador que no hacer nada', () {
    var con = 0.0, sin = 0.0;
    const n = 40;
    for (var s = 0; s < n; s++) {
      for (final pide in [true, false]) {
        final m = partido(s);
        final id = m.enCancha(true).first.id;
        final d = DirectorDecisiones(motor: m, propio: true, yo: perfil(id), habilitado: false);
        if (pide) d.aplicarManual(d.menuTactico().firstWhere((o) => o.accion == AccionTactica.pedirPelota));
        m.simularTodo();
        final tiros = (m.boxLocal[id]?.tcA ?? 0).toDouble();
        if (pide) {
          con += tiros;
        } else {
          sin += tiros;
        }
      }
    }
    expect(con / n, greaterThan(sin / n + 1.5), reason: 'con la pelota tira bastante más: $con vs $sin');
  });

  test('un partido completo: pocas decisiones, todas de jugador, y los contadores de carrera suben solo si salen', () {
    for (var s = 0; s < 8; s++) {
      final m = partido(s);
      final id = m.enCancha(true).first.id;
      final d = DirectorDecisiones(motor: m, propio: true, yo: perfil(id));
      final vistos = <TipoDecision>[];
      jugarConDirector(
        m,
        d,
        elegir: (dec) {
          vistos.add(dec.tipo);
          return dec.opciones.firstWhere((o) => o.recomendada, orElse: () => dec.opciones.first);
        },
      );
      expect(vistos.length, lessThanOrEqualTo(DirectorDecisiones.maxPorPartido + 2));
      for (final t in vistos) {
        expect(
          const {
            TipoDecision.tuPlan,
            TipoDecision.tuMomento,
            TipoDecision.tuMarca,
            TipoDecision.tuEnergia,
            TipoDecision.tuClutch,
            TipoDecision.takeover,
          }.contains(t),
          isTrue,
          reason: t.name,
        );
      }
      expect(d.usoCarrera.values.every((v) => v > 0), isTrue);
    }
  });
}
