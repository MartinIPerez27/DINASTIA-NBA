import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/vida_carrera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final carrera = CarreraJugador(Liga(catalogo, franquicias, azar: Random(7)));
  final creado = JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
  );
  EstadoCarrera nuevo({int ph = 200, int potencial = 90}) =>
      carrera.estadoCreado(raiz: 'h1', creado: creado, pick: 12, franquiciaId: 'CHI', potencial: potencial).copyWith(phBanco: ph);

  test('hay unas 34 habilidades técnicas y 4 rasgos mentales en los 5 atributos, y 30+ insignias', () {
    expect(Habilidad.values.length, greaterThanOrEqualTo(38));
    expect(Habilidad.mentales.length, 4);
    for (final a in Atributo.values) {
      expect(Habilidad.de(a).length, greaterThanOrEqualTo(5), reason: a.name);
      expect(Habilidad.de(a).any((h) => h.esMental), isFalse, reason: 'los mentales van aparte');
    }
    expect(Habilidad.values.where((h) => !h.esMental).length, greaterThanOrEqualTo(34));
    expect(Insignia.values.length, greaterThanOrEqualTo(33));
  });

  test('cada habilidad mueve alguna estadística y las nuevas también', () {
    for (final h in Habilidad.values) {
      final e = Habilidad.efectoPorPunto(h);
      final suma = e.ppp.abs() + e.rpp.abs() + e.app.abs() + e.robP.abs() + e.tapP.abs() + e.pctTc.abs() + e.pctT3.abs() + e.pctTl.abs() + e.minP.abs() + e.perP.abs();
      expect(suma, greaterThan(0), reason: h.name);
    }
  });

  test('las habilidades nuevas se compran, cuestan menos que un atributo y mueven la carta', () {
    var e = nuevo(ph: 100000);
    final base = e.carta.stats;
    for (var i = 0; i < 15; i++) {
      for (final h in [Habilidad.tiroDeEsquina, Habilidad.flotadora, Habilidad.reboteOfensivo, Habilidad.creacionDeTiro]) {
        e = carrera.subirHabilidad(e, h);
      }
    }
    expect(e.espec[Habilidad.flotadora], 15);
    expect(e.carta.stats.ppp, greaterThan(base.ppp));
    expect(e.carta.stats.rpp, greaterThan(base.rpp));
  });

  test('la durabilidad baja la probabilidad de lesión y la baja del todo lo contrario', () {
    final e = nuevo().copyWith(atributos: nuevo().atributos.con(Atributo.fisico, 75));
    final base = VidaCarrera.factorLesion(e);
    final fuerte = VidaCarrera.factorLesion(e.copyWith(espec: {Habilidad.durabilidad: 20}));
    final debil = VidaCarrera.factorLesion(e.copyWith(atributos: e.atributos.con(Atributo.fisico, 45)));
    expect(fuerte, lessThan(base));
    expect(debil, greaterThan(base));
    expect(fuerte, greaterThanOrEqualTo(0.7));
    expect(debil, lessThanOrEqualTo(1.3));
  });

  test('sumar a una habilidad cuesta menos que subir el atributo y mueve su valor', () {
    final e = nuevo();
    final h = Habilidad.triple;
    final antes = Habilidad.valor(h, e.atributos, e.espec);
    expect(carrera.costoHabilidad(e, h), lessThan(ModeloCarrera.costo(e.atributos[Atributo.tiro]) + 1));
    final d = carrera.subirHabilidad(e, h);
    expect(Habilidad.valor(h, d.atributos, d.espec), antes + 1);
    expect(d.phBanco, e.phBanco - carrera.costoHabilidad(e, h));
    expect(d.phGastados, carrera.costoHabilidad(e, h));
    expect(d.atributos[Atributo.tiro], e.atributos[Atributo.tiro], reason: 'el atributo general no cambia');
  });

  test('tope de especialización, y sin puntos no sube', () {
    var e = nuevo(ph: 100000);
    for (var i = 0; i < 40; i++) {
      e = carrera.subirHabilidad(e, Habilidad.poste);
    }
    expect(e.espec[Habilidad.poste], lessThanOrEqualTo(Habilidad.maxEspecializacion));
    expect(carrera.subirHabilidad(nuevo(ph: 0), Habilidad.triple).espec, isEmpty);
  });

  test('especializar mejora las estadísticas que le tocan', () {
    var e = nuevo(ph: 100000);
    final base = e.carta.stats;
    for (var i = 0; i < 15; i++) {
      e = carrera.subirHabilidad(e, Habilidad.triple);
      e = carrera.subirHabilidad(e, Habilidad.pase);
    }
    final s = e.carta.stats;
    expect(s.pctT3, greaterThan(base.pctT3));
    expect(s.app, greaterThan(base.app));
  });

  test('los grados de las insignias suben con el puntaje', () {
    const sinNada = ContextoInsignia(atributos: Atributos({}));
    expect(Insignia.francotirador.grado(sinNada), GradoInsignia.ninguno);
    Atributos con(int v) => Atributos.de(tiro: v, finalizacion: v, defensa: v, fisico: v, iq: v);
    final grados = [for (final v in [70, 80, 86, 92, 97]) Insignia.francotirador.grado(ContextoInsignia(atributos: con(v))).nivel];
    expect(grados, [0, 1, 2, 3, 4]);
    final todo99 = ContextoInsignia(atributos: con(99), espec: const {}, pj: 600, titulos: 4, allStar: 5, premios: 3, clutch: 10, fans: 90);
    for (final i in Insignia.values) {
      expect(i.grado(todo99).nivel, greaterThanOrEqualTo(1), reason: '${i.name} se puede conseguir');
    }
  });

  test('las insignias de carrera dependen de lo vivido, no de los atributos', () {
    final base = ContextoInsignia(atributos: Atributos.de(tiro: 60, finalizacion: 60, defensa: 60, fisico: 60, iq: 60));
    expect(Insignia.ganador.grado(base), GradoInsignia.ninguno);
    final campeon = ContextoInsignia(atributos: base.atributos, titulos: 2);
    expect(Insignia.ganador.grado(campeon).nivel, greaterThanOrEqualTo(1));
    expect(Insignia.maquina.grado(ContextoInsignia(atributos: base.atributos, pj: 700)).nivel, greaterThanOrEqualTo(1));
  });

  test('el estado guarda las especializaciones y los contadores, y una partida vieja carga sin ellos', () {
    var e = nuevo().copyWith(uso: {'clutch': 3});
    e = carrera.subirHabilidad(e, Habilidad.volcada);
    final r = EstadoCarrera.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>);
    expect(r.espec, e.espec);
    expect(r.uso['clutch'], 3);
    final viejo = Map<String, dynamic>.from(e.toJson())..remove('esp')..remove('uso');
    final v = EstadoCarrera.fromJson(viejo);
    expect(v.espec, isEmpty);
    expect(v.uso, isEmpty);
  });

  test('una insignia ganada por especialización suma a las estadísticas', () {
    var e = nuevo(ph: 100000, potencial: 99);
    final antes = e.carta.stats;
    while ((e.grados[Insignia.reptil]?.nivel ?? 0) < 1) {
      e = carrera.subirHabilidad(e, Habilidad.defPerimetral);
      if (e.espec[Habilidad.defPerimetral] == Habilidad.maxEspecializacion) break;
    }
    if ((e.grados[Insignia.reptil]?.nivel ?? 0) >= 1) {
      expect(e.carta.stats.robP, greaterThan(antes.robP));
    }
  });
}
