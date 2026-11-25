import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/avatar_ilustrado.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  test('el retrato es determinístico: mismo id, mismos rasgos; el hash es estable entre sesiones', () {
    final a = PerfilAvatar.de('jordami01'), b = PerfilAvatar.de('jordami01');
    expect(
      (a.piel, a.pelo, a.estilo, a.anchoCabeza, a.altoCabeza, a.barba),
      (b.piel, b.pelo, b.estilo, b.anchoCabeza, b.altoCabeza, b.barba),
    );
    // Valor fijado a mano: si cambia, todos los retratos cambiarían de cara entre versiones.
    expect(PerfilAvatar.hash('jordami01'), 2647236377);
    expect(PerfilAvatar.hash('jordami01'), isNot(PerfilAvatar.hash('jordami02')));
  });

  test('el catálogo reparte tonos, peinados y colores de pelo sin concentrarse', () {
    final personas = {for (final j in catalogo) j.idBbref};
    final perfiles = [for (final p in personas) PerfilAvatar.de(p)];
    expect(perfiles.map((p) => p.piel).toSet().length, PerfilAvatar.pieles.length);
    expect(perfiles.map((p) => p.pelo).toSet().length, PerfilAvatar.pelos.length);
    expect(perfiles.map((p) => p.estilo).toSet().length, PeloEstilo.automaticos);
    for (final piel in PerfilAvatar.pieles) {
      final n = perfiles.where((p) => p.piel == piel).length;
      expect(n / perfiles.length, inInclusiveRange(0.08, 0.28), reason: 'tono $piel');
    }
    for (final e in PeloEstilo.values.take(PeloEstilo.automaticos)) {
      expect(perfiles.where((p) => p.estilo == e).length / perfiles.length, inInclusiveRange(0.07, 0.25), reason: '$e');
    }
    for (final p in perfiles) {
      expect(p.anchoCabeza, inInclusiveRange(0.92, 1.08));
      expect(p.altoCabeza, inInclusiveRange(0.95, 1.09));
    }
  });

  testWidgets('se dibuja en cualquier tamaño sin desbordes; las iniciales solo cuando entran', (t) async {
    final jugador = catalogo.firstWhere((j) => j.id == 'jordami01-CHI-90');
    final franquicia = franquiciaPorId('CHI');
    Future<void> montar(double ancho, double alto) => t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquicia),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: ancho,
              height: alto,
              child: AvatarIlustrado(jugador: jugador, franquicia: franquicia),
            ),
          ),
        ),
      ),
    );
    for (final (w, h) in [(24.0, 24.0), (40.0, 40.0), (56.0, 56.0), (120.0, 200.0), (300.0, 219.0)]) {
      await montar(w, h);
      expect(t.takeException(), isNull, reason: '$w×$h');
      expect(find.text(jugador.iniciales), w >= 44 ? findsOneWidget : findsNothing, reason: '$w×$h');
    }
  });

  testWidgets('JugadorAvatar sin red muestra el retrato ilustrado con las iniciales', (t) async {
    JugadorAvatar.usarRed = false;
    final jugador = catalogo.firstWhere((j) => j.id == 'jordami01-CHI-90');
    final franquicia = franquiciaPorId('CHI');
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquicia),
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: JugadorAvatar(jugador: jugador, franquicia: franquicia),
          ),
        ),
      ),
    );
    expect(find.byType(AvatarIlustrado), findsOneWidget);
    expect(find.text('MJ'), findsOneWidget);
    expect(find.bySemanticsLabel(jugador.nombre), findsOneWidget);
  });
}
