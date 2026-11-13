import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/presentation/pantallas/playoffs_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:dinastia_nba/presentation/widgets/texto_led.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(3));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  var t = liga.iniciar(Temporada(id: 't', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  while (liga.proximoDelUsuario(t) != null) {
    t = liga.simularProximo(t);
  }
  t = liga.simularOtrosHasta(t, 1 << 30);

  setUpAll(() => JugadorAvatar.usarRed = false);

  testWidgets('playoffs: arma el cuadro, simula la serie y abre el STATS 82 ordenable', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final guardadas = <Temporada>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: PlayoffsPantalla(temporada: t, liga: liga, onCambio: guardadas.add),
      ),
    );
    await tester.pump();
    expect(guardadas.single.series, hasLength(4), reason: 'el Play-In se arma y se guarda al entrar');
    expect(find.text('PLAY-IN'), findsOneWidget);
    Future<void> tocar(String texto) async {
      await tester.ensureVisible(find.text(texto));
      await tester.tap(find.text(texto));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    if (guardadas.single.serieDelUsuario != null) {
      await tocar('SIMULAR SERIE');
      expect(guardadas.last.series.length, greaterThan(4));
    } else if (liga.esperandoPlayIn(guardadas.single)) {
      await tocar('SIMULAR EL PLAY-IN');
      expect(guardadas.last.series.where((s) => s.ronda == RondaPlayoff.primeraRonda), hasLength(8));
      expect(find.text('1ª RONDA DE CONFERENCIA'), findsOneWidget);
    } else {
      await tocar('SIMULAR HASTA EL CAMPEÓN');
      expect(guardadas.last.campeonId, isNotNull);
    }

    await tester.tap(find.byTooltip('STATS 82'));
    await tester.pumpAndSettle();
    expect(find.text('Máximo Anotador'), findsOneWidget);
    // La tabla queda debajo de los premios: se baja hasta verla.
    await tester.scrollUntilVisible(find.byType(DataTable), 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    double primeraPpp() {
      final fila = find.byType(DataRow).evaluate();
      final tabla = tester.widget<DataTable>(find.byType(DataTable));
      expect(fila, isEmpty); // DataRow no es un widget: se lee de la tabla
      return double.parse((tabla.rows.first.cells[3].child as CeldaLed).texto);
    }

    final antes = primeraPpp();
    await tester.tap(find.text('PPP'));
    await tester.pump();
    final despues = primeraPpp();
    expect(despues, lessThanOrEqualTo(antes), reason: 'el segundo toque invierte el orden');
  });
}
