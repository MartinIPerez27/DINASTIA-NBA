import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/franquicia.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/modos/perfil_perfecto.dart';
import 'package:dinastia_nba/presentation/modos/perfil_perfecto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final pp = PerfilPerfecto(
    catalogo,
    nombres: {
      for (final f in franquicias)
        if (!f.historica) f.id: f.nombre,
    },
    este: {
      for (final f in franquicias)
        if (!f.historica) f.id: f.conferencia == Conferencia.este,
    },
  );

  void validar(NivelPP n, {String? motivo}) {
    final r = motivo ?? 'nivel ${n.nivel}';
    // 1) La verdad cumple todas las pistas y es la ÚNICA solución.
    expect(SolucionadorPP.cumple(n, n.solucion), isTrue, reason: r);
    expect(
      SolucionadorPP.contar(n: n.n, categorias: n.categorias.length, pistas: n.pistas, esteFila: n.esteFila),
      1,
      reason: '$r: solución única',
    );
    // 2) Cada categoría tiene N valores distintos, uno por perfil; las ordinales van de menor a mayor.
    for (final c in n.categorias) {
      expect(c.n, n.n, reason: r);
      expect(c.etiquetas.toSet().length, c.n, reason: '$r ${c.id}: valores distintos');
    }
    for (final c in n.categorias.where((c) => c.id == 'media')) {
      final medias = [for (final e in c.etiquetas) int.parse(e)];
      expect(medias, [...medias]..sort());
    }
    for (final c in n.categorias.where((c) => c.id == 'epoca')) {
      final idx = [for (final e in c.claves) catalogo.firstWhere((j) => j.epoca.name == e).epoca.index];
      expect(idx, [...idx]..sort());
    }
    // 3) La solución coincide con las cartas reales.
    for (var f = 0; f < n.n; f++) {
      final j = n.jugadores[f];
      expect(n.categorias[0].claves[f], j.franquiciaId);
      for (var c = 1; c < n.categorias.length; c++) {
        final v = n.solucion[c].indexOf(f);
        final cat = n.categorias[c];
        final esperado = switch (cat.id) {
          'posicion' => j.posiciones.first.etiqueta,
          'epoca' => j.epoca.etiqueta,
          'media' => '${j.media}',
          'tier' => j.tier.codigo,
          'rol' => j.rol.etiqueta,
          _ => j.universidad,
        };
        expect(cat.etiquetas[v], esperado, reason: '$r ${j.nombre} ${cat.id}');
      }
    }
    // 4) Hay pistas, todas con texto, y ninguna sobra de más.
    expect(n.pistas, isNotEmpty);
    for (final p in n.pistas) {
      expect(n.texto(p).trim().length, greaterThan(8));
      expect(n.texto(p), endsWith('.'));
    }
    expect(n.pistas.length, lessThanOrEqualTo(45), reason: r);
  }

  test('niveles de toda la dificultad: solución única, datos reales y pistas redactadas', () {
    // Una muestra que cubre todos los tramos de dificultad (incluido el máximo).
    for (final nivel in [1, 2, 5, 10, 11, 20, 30, 31, 42, 55, 56, 70, 80, 81, 95, 105, 106, 112, 120, 150]) {
      validar(pp.generar(nivel));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('el acertijo del día: igual para todos ese día, distinto otro día, y de solución única', () {
    final a = pp.diario(20261113), b = pp.diario(20261113), c = pp.diario(20261114);
    validar(a, motivo: 'diario');
    expect(a.jugadores.map((j) => j.id).toList(), b.jugadores.map((j) => j.id).toList());
    expect([for (final p in a.pistas) a.texto(p)], [for (final p in b.pistas) b.texto(p)]);
    expect(c.jugadores.map((j) => j.id).toList(), isNot(a.jugadores.map((j) => j.id).toList()));
    expect(a.diario, isTrue);
    expect((a.n, a.incognitas), (4, 3));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('la generación es determinista y los niveles son distintos entre sí', () {
    final a = pp.generar(37), b = pp.generar(37);
    expect(a.jugadores.map((j) => j.id).toList(), b.jugadores.map((j) => j.id).toList());
    expect([for (final p in a.pistas) a.texto(p)], [for (final p in b.pistas) b.texto(p)]);
    final distintos = {for (var n = 1; n <= 12; n++) pp.generar(n).jugadores.map((j) => j.id).join(',')};
    expect(distintos.length, 12);
  });

  test('la dificultad sube: más perfiles y más categorías con el nivel', () {
    var previo = (0, 0);
    for (final nivel in [1, 11, 31, 56, 81, 106]) {
      final e = PerfilPerfecto.espec(nivel);
      expect(e.n * 10 + e.m >= previo.$1 * 10 + previo.$2, isTrue);
      previo = (e.n, e.m);
    }
    expect((PerfilPerfecto.espec(1).n, PerfilPerfecto.espec(1).m), (3, 1));
    expect((PerfilPerfecto.espec(120).n, PerfilPerfecto.espec(120).m), (5, 4));
    expect(PerfilPerfecto.espec(1).tipos, isNot(contains(TipoPista.oEntre)));
    expect(PerfilPerfecto.espec(100).tipos, contains(TipoPista.oEntre));
  });

  test('el solucionador distingue: sin pistas hay varias soluciones y una pista falsa deja ninguna', () {
    final n = pp.generar(31);
    expect(SolucionadorPP.contar(n: n.n, categorias: n.categorias.length, pistas: const [], esteFila: n.esteFila), 2);
    // Una pista que la solución real incumple: "el de la franquicia 0 es el de la franquicia 1" (distintos perfiles)
    final falsa = PistaPP(TipoPista.igual, [const RefPP(0, 0), const RefPP(0, 1)]);
    expect(SolucionadorPP.contar(n: n.n, categorias: n.categorias.length, pistas: [falsa], esteFila: n.esteFila), 0);
    // Quitar una pista de las necesarias suele dejar de ser única: al menos una no se puede sacar
    final sinUna = [
      for (var i = 0; i < n.pistas.length; i++)
        SolucionadorPP.contar(
          n: n.n,
          categorias: n.categorias.length,
          pistas: [
            for (var k = 0; k < n.pistas.length; k++)
              if (k != i) n.pistas[k],
          ],
          esteFila: n.esteFila,
        ),
    ];
    expect(sinUna.any((c) => c > 1), isTrue);
  });

  test('estrellas, recompensas (solo la primera vez), desbloqueo y logros', () {
    expect(ProgresoPP.calcularEstrellas(errores: 0, pistas: 0), 3);
    expect(ProgresoPP.calcularEstrellas(errores: 1, pistas: 0), 2);
    expect(ProgresoPP.calcularEstrellas(errores: 0, pistas: 1), 2);
    expect(ProgresoPP.calcularEstrellas(errores: 2, pistas: 1), 1);
    var p = const PerfilEntrenador();
    expect(ProgresoPP.desbloqueado(p), 1);
    final (p1, texto) = ProgresoPP.registrar(p, clave: 1, estrellas: 2);
    expect(texto, isNotNull);
    expect(p1.xp, greaterThan(0));
    expect(p1.monedas, greaterThan(0));
    expect(ProgresoPP.estrellas(p1, 1), 2);
    expect(ProgresoPP.desbloqueado(p1), 2);
    // Repetirlo mejor sube las estrellas pero no vuelve a pagar
    final (p2, texto2) = ProgresoPP.registrar(p1, clave: 1, estrellas: 3);
    expect(texto2, isNull);
    expect(ProgresoPP.estrellas(p2, 1), 3);
    expect((p2.xp, p2.monedas), (p1.xp, p1.monedas));
    // Peor resultado no baja las estrellas
    expect(ProgresoPP.estrellas(ProgresoPP.registrar(p2, clave: 1, estrellas: 1).$1, 1), 3);
    // Diario: aparte, y paga más
    final (pd, _) = ProgresoPP.registrar(p, clave: 20261113, estrellas: 3, diario: true);
    expect(ProgresoPP.estrellasDiario(pd, 20261113), 3);
    expect(ProgresoPP.resueltos(pd), 0);
    expect(pd.xp, greaterThan(p1.xp));
    // Logros a los 25 y 100 niveles
    p = const PerfilEntrenador();
    for (var n = 1; n <= 100; n++) {
      p = ProgresoPP.registrar(p, clave: n, estrellas: 1).$1;
      if (n == 24) expect(p.logros.containsKey(Logro.detective), isFalse);
      if (n == 25) expect(p.logros.containsKey(Logro.detective), isTrue);
      if (n == 99) expect(p.logros.containsKey(Logro.maestroDetective), isFalse);
    }
    expect(p.logros.containsKey(Logro.maestroDetective), isTrue);
    expect(ProgresoPP.resueltos(p), 100);
    expect(ProgresoPP.desbloqueado(p), 101);
    // JSON ida y vuelta
    final copia = PerfilEntrenador.fromJson(p.toJson());
    expect(ProgresoPP.resueltos(copia), 100);
  });

  Future<void> bombear(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('pantalla: el menú muestra los niveles y se resuelve el nivel 1 tocando la solución', (t) async {
    t.view.physicalSize = const Size(412, 900) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    perfilApp.value = const PerfilEntrenador();
    addTearDown(() => perfilApp.value = const PerfilEntrenador());
    PerfilEntrenador? guardado;
    await t.pumpWidget(
      MaterialApp(
        home: PerfilPerfectoMenu(generador: pp, fecha: 20261113, onPerfil: (p) => guardado = p),
      ),
    );
    expect(find.text('ACERTIJO DEL DÍA'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    await t.tap(find.text('1').first);
    await bombear(t);
    expect(find.text('Nivel 1'), findsOneWidget);
    expect(find.textContaining('PISTAS'), findsOneWidget);
    // VERIFICAR está apagado hasta completar todos los casilleros
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'VERIFICAR')).onPressed, isNull);

    final n = pp.generar(1);
    // Los casilleros se recorren fila por fila, categoría por categoría.
    for (var f = 0; f < n.n; f++) {
      for (var c = 1; c < n.categorias.length; c++) {
        await t.tap(find.text('?').first);
        await t.pumpAndSettle();
        final v = n.solucion[c].indexOf(f);
        await t.tap(find.descendant(of: find.byType(ListTile), matching: find.text(n.categorias[c].etiquetas[v])));
        await t.pumpAndSettle();
      }
    }
    expect(find.text('?'), findsNothing);
    await t.tap(find.widgetWithText(FilledButton, 'VERIFICAR'));
    await t.pumpAndSettle();
    expect(find.textContaining('RESUELTO'), findsOneWidget);
    expect(guardado, isNotNull);
    expect(ProgresoPP.estrellas(guardado!, 1), 3);
    expect(find.text('SIGUIENTE NIVEL'), findsOneWidget);
    // Las cartas reales se muestran al resolver
    expect(find.text(n.jugadores.first.nombre), findsOneWidget);
  });

  testWidgets('pantalla: un error cuesta una vida y tres errores piden volver a intentar', (t) async {
    t.view.physicalSize = const Size(412, 900) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    perfilApp.value = const PerfilEntrenador();
    await t.pumpWidget(
      MaterialApp(
        home: PerfilPerfectoNivel(generador: pp, nivel: 1, onPerfil: (_) {}),
      ),
    );
    await bombear(t);
    final n = pp.generar(1);
    // Llenamos con una asignación equivocada: cada valor desplazado una fila.
    Future<void> llenarMal() async {
      for (var f = 0; f < n.n; f++) {
        for (var c = 1; c < n.categorias.length; c++) {
          if (find.text('?').evaluate().isEmpty) break;
          await t.tap(find.text('?').first);
          await t.pumpAndSettle();
          final v = (n.solucion[c].indexOf(f) + 1) % n.n;
          await t.tap(find.descendant(of: find.byType(ListTile), matching: find.text(n.categorias[c].etiquetas[v])));
          await t.pumpAndSettle();
        }
      }
    }

    await llenarMal();
    await t.tap(find.widgetWithText(FilledButton, 'VERIFICAR'));
    await t.pumpAndSettle();
    expect(find.textContaining('Te quedan 2 vidas'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNWidgets(2));
    await t.tap(find.widgetWithText(FilledButton, 'VERIFICAR'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'VERIFICAR'));
    await t.pumpAndSettle();
    expect(find.text('VOLVER A INTENTAR'), findsOneWidget);
    await t.tap(find.text('VOLVER A INTENTAR'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.text('?'), findsWidgets);
  });
}
