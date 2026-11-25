import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(4));
  final carrera = CarreraJugador(liga);
  EstadoCarrera nuevo({int pick = 5}) => carrera.estadoCreado(
    raiz: 'ec$pick',
    creado: JugadorCreado(
      nombre: 'Iván Mora',
      posicion: Posicion.pivot,
      rol: RolCancha.especialista3D,
      fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
    ),
    pick: pick,
    franquiciaId: 'CHI',
  );
  EstadoCarrera conCaja(EstadoCarrera e, double m) => e.copyWith(uso: {...e.uso, 'ec:caja': (m * 10).round()});

  test('el sueldo de novato baja con el pick y después depende de tu media', () {
    expect(EconomiaCarrera.sueldoBase(nuevo(pick: 1)), greaterThan(EconomiaCarrera.sueldoBase(nuevo(pick: 25))));
    final vet = nuevo().copyWith(numero: 8);
    final crack = vet.copyWith(atributos: vet.atributos.sumar({for (final a in Atributo.values) a: 20}));
    expect(EconomiaCarrera.sueldoBase(crack), greaterThan(EconomiaCarrera.sueldoBase(vet)));
  });

  test('contratar cuesta plata, no se puede sin caja y llega a nivel 3 como máximo', () {
    var e = nuevo();
    expect(EconomiaCarrera.puedeSubir(e, Personal.entrenador), isFalse);
    e = conCaja(e, 100);
    for (var i = 0; i < 5; i++) {
      e = EconomiaCarrera.subir(e, Personal.entrenador);
    }
    expect(EconomiaCarrera.nivel(e, Personal.entrenador), 3);
    expect(EconomiaCarrera.caja(e), closeTo(100 - 9, 0.001));
    expect(EconomiaCarrera.nivel(EconomiaCarrera.bajar(e, Personal.entrenador), Personal.entrenador), 2);
  });

  test('el agente mejora el sueldo y trae ofertas extra; cobra comisión', () {
    var e = conCaja(nuevo(), 100);
    final sin = EconomiaCarrera.sueldo(e);
    e = EconomiaCarrera.subir(EconomiaCarrera.subir(e, Personal.agente), Personal.agente);
    expect(EconomiaCarrera.sueldo(e), greaterThan(sin));
    expect(EconomiaCarrera.comision(e), greaterThan(0));
    expect(EconomiaCarrera.ofertasExtra(e), 1);
    final t = carrera.nuevaCarrera(estado: e, dificultad: Dificultad.normal);
    final base = carrera.ofertas(t, EstadoCarrera.de(t)!.copyWith(uso: {}), traspaso: true).length;
    expect(carrera.ofertas(t, EstadoCarrera.de(t)!, traspaso: true).length, base + 1);
  });

  test('al cerrar cobrás sueldo y marcas, pagás el equipo y el entrenador suma puntos', () {
    var e = conCaja(nuevo(), 20);
    e = EconomiaCarrera.subir(e, Personal.entrenador);
    final antes = EconomiaCarrera.caja(e);
    final c = EconomiaCarrera.alCerrar(e);
    expect(EconomiaCarrera.caja(c), closeTo(antes + EconomiaCarrera.balanceAnual(e), 0.15));
    expect(c.phBanco, e.phBanco + 1);
    expect(EconomiaCarrera.ganadoEnTotal(c), greaterThan(0));
  });

  test('sin plata para pagar, el personal más caro se va', () {
    var e = conCaja(nuevo(), 20);
    e = EconomiaCarrera.subir(e, Personal.entrenador);
    e = e.copyWith(uso: {...e.uso, 'ec:n${Personal.fisio.index}': 3, 'ec:n${Personal.entrenador.index}': 3, 'ec:caja': 0});
    final bajo = nuevo(pick: 60).copyWith(uso: e.uso);
    final c = EconomiaCarrera.alCerrar(bajo);
    expect(EconomiaCarrera.nivel(c, Personal.entrenador) + EconomiaCarrera.nivel(c, Personal.fisio), lessThan(6));
    expect(EconomiaCarrera.caja(c), greaterThanOrEqualTo(0));
  });

  test('fisio y nutricionista bajan el riesgo y el cansancio', () {
    var e = conCaja(nuevo(), 100);
    final base = CuerpoCarrera.factor(e);
    for (var i = 0; i < 3; i++) {
      e = EconomiaCarrera.subir(e, Personal.fisio);
    }
    expect(CuerpoCarrera.factor(e), lessThan(base));
    expect(CuerpoCarrera.nuevaCarga(50, 36 * 60, extra: 1.5), lessThan(CuerpoCarrera.nuevaCarga(50, 36 * 60)));
  });

  group('ofertas con tope salarial y cláusulas', () {
    test('cada oferta trae sueldo y cláusula, y nunca pasa el espacio salarial del equipo', () {
      var e = nuevo(pick: 2).copyWith(numero: 6);
      e = e.copyWith(atributos: e.atributos.sumar({for (final a in Atributo.values) a: 20}));
      final t = carrera.nuevaCarrera(estado: e, dificultad: Dificultad.normal);
      final ofertas = carrera.ofertas(t, EstadoCarrera.de(t)!, traspaso: true);
      expect(ofertas, isNotEmpty);
      for (final o in ofertas) {
        expect(o.salario, greaterThan(0));
        expect(o.salario, lessThanOrEqualTo(CarreraJugador.espacioSalarial(o.nivelEquipo) + 0.05));
      }
      expect(CarreraJugador.espacioSalarial(70), greaterThan(CarreraJugador.espacioSalarial(86)));
    });

    test('un crack choca con el tope de los equipos armados', () {
      expect(CarreraJugador.espacioSalarial(86), lessThan(30));
      expect(CarreraJugador.espacioSalarial(60), 70);
    });

    test('firmar guarda el sueldo y la cláusula, y el bono por título paga si salís campeón', () {
      final e0 = nuevo();
      final t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      final e = EstadoCarrera.de(t)!;
      final oferta = OfertaContrato(
        franquiciaId: 'CHI',
        rol: RolOferta.titular,
        anios: 3,
        nivelEquipo: 78,
        renovacion: true,
        salario: 21.5,
        clausula: ClausulaContrato.bonoTitulo,
      );
      final sig = carrera.siguiente(t, e.copyWith(cerrada: true), oferta: oferta);
      final ne = EstadoCarrera.de(sig)!;
      expect(ne.uso['ec:sal'], 215);
      expect(EconomiaCarrera.clausula(ne), ClausulaContrato.bonoTitulo);
      expect(EconomiaCarrera.sueldoBase(ne.copyWith(numero: 9)), 21.5);
      final campeon = ne.copyWith(historial: [
        TemporadaJugador(numero: 1, etiqueta: 'x', franquiciaId: 'CHI', edad: 22, media: 80, pj: 70, pts: 20, reb: 5, ast: 5, victorias: 60, derrotas: 22, resultado: '', campeon: true, allStar: false),
      ]);
      expect(EconomiaCarrera.bono(campeon), 4.0);
      expect(EconomiaCarrera.bono(ne), 0.0);
    });
  });
}
