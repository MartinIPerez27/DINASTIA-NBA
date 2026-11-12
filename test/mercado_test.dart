import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/mercado.dart';
import 'package:dinastia_nba/presentation/pantallas/mercado_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(31));
  final mercado = Mercado(liga);
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final t = liga.iniciar(Temporada(id: 'm', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  final leyenda = liga.iniciar(
    Temporada(id: 'l', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true, dificultad: Dificultad.leyenda),
  );
  setUpAll(() => JugadorAvatar.usarRed = false);

  /// Un pase posible: tu carta de un puesto por la del mismo puesto de un rival.
  (Jugador, String, Jugador) mismoPuesto(Posicion pos, bool Function(Jugador suyo) filtro, {Temporada? en}) {
    final t2 = en ?? t;
    final mio = t2.plantel.en(pos)!;
    for (final rivalId in t2.rivales.keys) {
      for (final (pp, suyo) in mercado.pedibles(t2, rivalId)) {
        if (pp == pos && suyo.puedeJugarEn(pos) && mio.puedeJugarEn(pp) && filtro(suyo)) return (mio, rivalId, suyo);
      }
    }
    throw StateError('sin candidato');
  }

  test('fecha límite al 60 %, 3 pases, y se cierra al pasar la jornada', () {
    final ultima = t.calendario.map((x) => x.jornada).reduce(max);
    expect(mercado.jornadaLimite(t), (ultima * 0.6).round());
    expect(mercado.abierto(t), isTrue);
    expect(mercado.pasesRestantes(t), 3);
    var x = t;
    while (liga.proximoDelUsuario(x)!.jornada <= mercado.jornadaLimite(t)) {
      x = liga.simularProximo(x);
    }
    expect(mercado.abierto(x), isFalse);
    expect(mercado.motivoCierre(x), contains('fecha límite'));
    final tres = t.copyWith(
      pases: [for (var i = 0; i < 3; i++) const Pase(jornada: 1, franquiciaId: 'BOS', dioId: 'a', recibioId: 'b')],
    );
    expect(mercado.abierto(tres), isFalse);
  });

  test('si no puede jugar en ese puesto, o está lesionado, no hay pase', () {
    final mio = t.plantel.en(Posicion.pivot)!;
    for (final rivalId in t.rivales.keys) {
      final base = mercado.pedibles(t, rivalId).firstWhere((e) => e.$1 == Posicion.base).$2;
      if (!mio.puedeJugarEn(Posicion.base)) {
        final r = mercado.evaluar(t, mio, rivalId, base);
        expect(r.acepta, isFalse);
        expect(r.motivo, contains('no juega de BASE'));
        break;
      }
    }
    final (m, rival, suyo) = mismoPuesto(Posicion.base, (s) => s.tier == Tier.b);
    final lesionado = t.copyWith(lesiones: {m.id: 4});
    expect(mercado.evaluar(lesionado, m, rival, suyo).motivo, contains('enfermería'));
  });

  test('valor = media + forma; un S+ es intocable salvo que lo pagues bien', () {
    late Jugador mio, suyo;
    late String rival;
    for (final pos in Posicion.titulares) {
      try {
        (mio, rival, suyo) = mismoPuesto(pos, (s) => s.tier == Tier.sPlus, en: leyenda);
        break;
      } on StateError {
        continue;
      }
    }
    final margen = mercado.margen(leyenda, rival, suyo);
    expect(margen, 4);
    final corto = leyenda.copyWith(forma: {mio.id: suyo.media + margen - 1 - mio.media});
    final r = mercado.evaluar(corto, mio, rival, suyo);
    expect(r.acepta, isFalse);
    expect(r.motivo, contains('intocable'));
    final justo = leyenda.copyWith(forma: {mio.id: suyo.media + margen - mio.media});
    expect(mercado.evaluar(justo, mio, rival, suyo).acepta, isTrue);
  });

  test('ejecutar: las cartas cambian de plantel, queda el pase y se guarda', () {
    final (mio, rival, suyo) = mismoPuesto(Posicion.base, (s) => s.tier == Tier.b);
    final respuesta = mercado.evaluar(t, mio, rival, suyo);
    expect(respuesta.acepta, isTrue, reason: respuesta.motivo);
    final nueva = mercado.ejecutar(t, mio, rival, suyo);
    expect(nueva.plantel.en(Posicion.base)!.id, suyo.id);
    expect(liga.plantelDe(nueva.rivales[rival]!).en(Posicion.base)!.id, mio.id);
    expect(nueva.rivales[rival]!.tipo, t.rivales[rival]!.tipo);
    expect(nueva.pases.single.dioId, mio.id);
    expect(nueva.pases.single.recibioId, suyo.id);
    expect(nueva.pases.single.jornada, liga.proximoDelUsuario(t)!.jornada);
    final copia = Temporada.fromJson(nueva.toJson());
    expect(copia.pases.single.franquiciaId, rival);
    expect(copia.plantel.en(Posicion.base)!.id, suyo.id);
    expect(() => mercado.ejecutar(nueva, suyo, rival, mio), throwsStateError, reason: 'ahora lo rechazan');
  });

  testWidgets('pantalla: elegir, proponer y confirmar un pase', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2.5;
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final (mio, rival, suyo) = mismoPuesto(Posicion.base, (s) => s.tier == Tier.b);
    final guardadas = <Temporada>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: MercadoPantalla(temporada: t, liga: liga, onCambio: guardadas.add),
      ),
    );
    expect(find.text('MERCADO ABIERTO'), findsOneWidget);
    Future<void> tocar(Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump();
    }

    await tocar(find.byKey(ValueKey('mia-${mio.id}')));
    expect(find.text('2. ¿A qué equipo?'), findsOneWidget);
    await tocar(find.byKey(ValueKey('rival-$rival')));
    await tocar(find.byKey(ValueKey('suya-${suyo.id}')));
    final proponer = find.textContaining('PROPONER');
    await tester.scrollUntilVisible(proponer, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(proponer);
    await tester.pump();
    expect(find.textContaining('Trato hecho'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CONFIRMAR PASE'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('CONFIRMAR PASE'));
    await tester.pump();
    expect(guardadas.single.pases, hasLength(1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pump();
    expect(find.textContaining('se va a los'), findsOneWidget, reason: 'el aviso queda arriba, con el encabezado');
  });
}
