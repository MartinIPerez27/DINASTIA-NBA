import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contraste(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  test('el LED de las 30 franquicias se lee (≥ 4,5:1) sobre fondo, tarjetas, paneles y diálogos', () {
    expect(franquicias, hasLength(30));
    for (final f in franquicias) {
      final e = temaFranquicia(f).colorScheme;
      final nombres = ['surface', 'tarjeta (Low)', 'Container', 'diálogo (High)', 'Highest'];
      final sup = superficiesDeLed(e);
      for (var i = 0; i < sup.length; i++) {
        expect(
          _contraste(e.primary, sup[i]),
          greaterThanOrEqualTo(contrasteLedMinimo),
          reason: '${f.nombreCompleto} sobre ${nombres[i]}',
        );
      }
      expect(_contraste(e.primary, e.surfaceContainerLowest), greaterThanOrEqualTo(contrasteLedMinimo));
      expect(_contraste(e.primary, e.onPrimary), greaterThanOrEqualTo(contrasteLedMinimo), reason: 'texto del botón');
      expect(colorLed(f), e.primary);
    }
  });
}
