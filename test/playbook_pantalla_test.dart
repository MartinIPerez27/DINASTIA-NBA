import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/playbook.dart';
import 'package:dinastia_nba/presentation/pantallas/playbook_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/draft/entrenadores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Temporada temporadaConPlantel() {
  final c = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final j = {for (final x in c) x.nombre: x};
  final plantel = const Plantel()
      .asignar(j['Magic Johnson']!, Posicion.base)
      .asignar(j['Michael Jordan']!, Posicion.escolta)
      .asignar(j['Larry Bird']!, Posicion.alero)
      .asignar(j['Tim Duncan']!, Posicion.alaPivot)
      .asignar(j["Shaquille O'Neal"]!, Posicion.pivot)
      .asignar(j['Manu Ginóbili']!, Posicion.sextoHombre);
  return Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: plantel);
}

void main() {
  testWidgets('arranca con la recomendación, se puede cambiar y confirmar', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final t = temporadaConPlantel();
    final rec = recomendar(PerfilPlantel.de(t.plantel));
    Temporada? confirmada;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PlaybookPantalla(temporada: t, onConfirmar: (x) => confirmada = x),
      ),
    );
    expect(find.text('Estás usando esta combinación.'), findsOneWidget);
    expect(find.text('QUÍMICA'), findsOneWidget);

    // Entrenador (7.º puesto): se elige desde el playbook y viaja con la confirmación.
    expect(find.text('SIN ENTRENADOR'), findsOneWidget);
    await tester.tap(find.text('SIN ENTRENADOR'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CartaEntrenador).first);
    await tester.pumpAndSettle();
    expect(find.text('SIN ENTRENADOR'), findsNothing);

    await tester.tap(find.text('Defensiva'));
    await tester.pumpAndSettle();
    final otra = EsquemaDefensivo.values.firstWhere((d) => d != rec.tactica.defensiva);
    await tester.scrollUntilVisible(find.text(otra.nombre.toUpperCase()), 200);
    await tester.tap(find.text(otra.nombre.toUpperCase()));
    await tester.pump();
    expect(find.text('Usar la recomendación'), findsOneWidget);

    await tester.tap(find.text('CONFIRMAR TÁCTICAS'));
    expect(confirmada!.tacticaConfirmada, isTrue);
    expect(confirmada!.tactica, Tactica(ofensiva: rec.tactica.ofensiva, defensiva: otra));
    expect(confirmada!.entrenadorId, isNotNull);
  });
}
