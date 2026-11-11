import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/main.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contraste(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  test('el color LED de las 30 franquicias se lee sobre el tablero (≥ 4.5:1)', () {
    for (final f in franquicias) {
      final tema = temaFranquicia(f);
      expect(
        _contraste(tema.colorScheme.primary, tema.colorScheme.surfaceContainerLowest),
        greaterThanOrEqualTo(4.5),
        reason: f.nombreCompleto,
      );
      expect(
        _contraste(tema.colorScheme.primary, tema.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
        reason: 'texto del botón de ${f.nombreCompleto}',
      );
      expect(
        _contraste(tema.colorScheme.onSurfaceVariant, tema.colorScheme.surfaceContainerLowest),
        greaterThanOrEqualTo(4.5),
        reason: 'siglas apagadas de la cinta de ${f.nombreCompleto}',
      );
    }
  });

  testWidgets('elegir franquicia tiñe la app y abre el draft', (tester) async {
    await tester.pumpWidget(const DinastiaNbaApp());
    expect(find.text('BULLS'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Boston Celtics'));
    await tester.pumpAndSettle();
    expect(find.text('CELTICS'), findsOneWidget);
    final tema = Theme.of(tester.element(find.text('CELTICS')));
    expect(tema.colorScheme.primary, colorLed(franquiciaPorId('BOS')));

    await tester.tap(find.text('Oeste'));
    await tester.pumpAndSettle();
    expect(find.text('NUGGETS'), findsOneWidget, reason: 'cambiar de conferencia enfoca su primer equipo');

    await tester.tap(find.text('DIRIGIR A LOS NUGGETS'));
    await tester.pumpAndSettle();
    expect(find.text('Draft de los Nuggets'), findsOneWidget);
  });
}
