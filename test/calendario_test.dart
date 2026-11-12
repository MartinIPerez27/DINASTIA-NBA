import 'dart:math';

import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/calendario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final calendario = generarCalendario(franquicias, Random(82));

  test('1230 partidos: 82 por equipo, 41 de local', () {
    expect(calendario, hasLength(1230));
    for (final f in franquicias) {
      final suyos = calendario.where((p) => p.participa(f.id));
      expect(suyos, hasLength(82), reason: f.id);
      expect(suyos.where((p) => p.localId == f.id), hasLength(41), reason: f.id);
    }
  });

  test('cruces según la fórmula oficial (división 4, conferencia 3 o 4, otra conferencia 2)', () {
    for (final f in franquicias) {
      final veces = <String, int>{};
      for (final p in calendario.where((p) => p.participa(f.id))) {
        final rival = p.localId == f.id ? p.visitanteId : p.localId;
        veces[rival] = (veces[rival] ?? 0) + 1;
      }
      for (final r in franquicias.where((r) => r != f)) {
        final esperado = r.division == f.division
            ? [4]
            : r.conferencia == f.conferencia
            ? [3, 4]
            : [2];
        expect(esperado, contains(veces[r.id]), reason: '${f.id} vs ${r.id}');
      }
      expect(veces.values.where((v) => v == 3), hasLength(4), reason: '${f.id}: 4 rivales de 3 partidos');
    }
  });

  test('cada equipo juega como mucho una vez por jornada', () {
    final porJornada = <int, List<String>>{};
    for (final p in calendario) {
      (porJornada[p.jornada] ??= []).addAll([p.localId, p.visitanteId]);
    }
    for (final equipos in porJornada.values) {
      expect(equipos.toSet().length, equipos.length);
    }
  });
}
