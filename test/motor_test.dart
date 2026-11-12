import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  Plantel armar(bool Function(Jugador) filtro, Random r) {
    var p = const Plantel();
    final pool = catalogo.where(filtro).toList()..shuffle(r);
    for (final pos in Posicion.values) {
      p = p.asignar(pool.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return p;
  }

  MotorPartido jugar(bool Function(Jugador) a, bool Function(Jugador) b, Random r) => MotorPartido(
    local: EquipoPartido(identidadId: 'CHI', plantel: armar(a, r), tactica: const Tactica()),
    visitante: EquipoPartido(identidadId: 'BOS', plantel: armar(b, r), tactica: const Tactica()),
    azar: r,
  )..simularTodo();

  bool tier(Jugador j, Tier t) => j.tier == t;

  test('tanteos realistas y el box score suma exactamente el marcador', () {
    final r = Random(1);
    var total = 0;
    for (var i = 0; i < 60; i++) {
      final m = jugar((j) => tier(j, Tier.a), (j) => tier(j, Tier.a), r);
      total += m.puntosLocal + m.puntosVisitante;
      expect(m.puntosLocal == m.puntosVisitante, isFalse, reason: 'no hay empates');
      expect(m.boxLocal.values.fold(0, (a, l) => a + l.pts), m.puntosLocal);
      expect(m.boxVisitante.values.fold(0, (a, l) => a + l.pts), m.puntosVisitante);
      expect(m.parcialesLocal.fold(0, (a, b) => a + b), m.puntosLocal);
    }
    expect(total / 120, inInclusiveRange(92, 122), reason: 'promedio de puntos por equipo');
  });

  test('el plantel más fuerte gana casi siempre', () {
    final r = Random(2);
    var gana = 0;
    for (var i = 0; i < 80; i++) {
      final m = jugar((j) => tier(j, Tier.sPlus), (j) => tier(j, Tier.b), r);
      if (m.puntosLocal > m.puntosVisitante) gana++;
    }
    expect(gana, greaterThan(72));
  });

  test('tiempo muerto: recupera estamina y tiene límite', () {
    final r = Random(3);
    final m = MotorPartido(
      local: EquipoPartido(identidadId: 'CHI', plantel: armar((j) => tier(j, Tier.a), r), tactica: const Tactica()),
      visitante: EquipoPartido(identidadId: 'BOS', plantel: armar((j) => tier(j, Tier.a), r), tactica: const Tactica()),
      usuarioLocal: true,
      azar: r,
    );
    for (var i = 0; i < 60; i++) {
      m.siguiente();
    }
    final antes = m.energias(true).values.reduce(min);
    expect(m.pedirTiempoMuerto(true), isTrue);
    expect(m.siguiente().tipo, TipoEvento.tiempoMuerto);
    expect(m.energias(true).values.reduce(min), greaterThan(antes));
    for (var i = 0; i < 4; i++) {
      m.pedirTiempoMuerto(true);
    }
    expect(m.pedirTiempoMuerto(true), isFalse, reason: 'solo 5 por partido');
  });

  test('el Sexto Hombre entra durante el partido', () {
    final r = Random(4);
    final m = MotorPartido(
      local: EquipoPartido(identidadId: 'CHI', plantel: armar((j) => tier(j, Tier.a), r), tactica: const Tactica()),
      visitante: EquipoPartido(identidadId: 'BOS', plantel: armar((j) => tier(j, Tier.a), r), tactica: const Tactica()),
      azar: r,
    );
    final eventos = <EventoPartido>[];
    while (!m.terminado) {
      eventos.add(m.siguiente());
    }
    expect(eventos.where((e) => e.tipo == TipoEvento.cambio), isNotEmpty);
    expect(eventos.first.marcadorLocal + eventos.first.marcadorVisitante, lessThanOrEqualTo(3), reason: 'arranca 0-0');
    expect(eventos.last.tipo, TipoEvento.finPartido);
  });
}
