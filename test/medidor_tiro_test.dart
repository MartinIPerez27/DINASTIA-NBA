import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/decisiones_partido.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/medidor_tiro.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/presentation/partido/medidor_tiro.dart';
import 'package:dinastia_nba/presentation/pantallas/partido_pantalla.dart';
import 'package:dinastia_nba/presentation/partido/sonido_partido.dart';
import 'package:dinastia_nba/presentation/partido/voz_relator.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PerfilVivo perfil(String id, {int habilidad = 80, int zona = 1, bool mantener = false, int forma = 0, ModoMedidor modo = ModoMedidor.todos}) {
  return PerfilVivo(
    id: id,
    nombre: 'Yo',
    atributos: Atributos.de(tiro: habilidad, finalizacion: habilidad, defensa: habilidad, fisico: habilidad, iq: habilidad),
    ajustes: AjustesMedidor(modo: modo, zona: zona, mantener: mantener),
    formaDeTiro: forma,
  );
}

MomentoPendiente momento({bool triple = false, double p = 0.5, TipoMomento tipo = TipoMomento.tiro}) => MomentoPendiente(
  tipo: tipo,
  jugadorId: 'x',
  probabilidad: p,
  triple: triple,
  clutch: false,
  nombre: 'Rival',
);

void main() {
  group('el modelo de la barra', () {
    test('mejor habilidad, zona verde más grande; tiro difícil, más chica; la opción de zona y la forma de tirar cuentan', () {
      final flojo = MedidorTiro.ventana(perfil('a', habilidad: 60), momento());
      final crack = MedidorTiro.ventana(perfil('a', habilidad: 95), momento());
      expect(crack, greaterThan(flojo));
      expect(MedidorTiro.ventana(perfil('a'), momento(p: 0.25)), lessThan(MedidorTiro.ventana(perfil('a'), momento(p: 0.65))));
      expect(MedidorTiro.ventana(perfil('a', zona: 2), momento()), greaterThan(MedidorTiro.ventana(perfil('a', zona: 0), momento())));
      expect(MedidorTiro.ventana(perfil('a', forma: 2), momento(triple: true)), greaterThan(MedidorTiro.ventana(perfil('a'), momento(triple: true))));
      expect(MedidorTiro.segundos(perfil('a', forma: 1)), lessThan(MedidorTiro.segundos(perfil('a'))));
      for (final h in [25, 60, 99]) {
        final v = MedidorTiro.ventana(perfil('a', habilidad: h), momento());
        expect(v, inInclusiveRange(0.05, 0.3));
      }
    });

    test('perfecto en el centro, bien cerca, temprano o tarde afuera; y el efecto crece con la calidad', () {
      const v = 0.2;
      expect(MedidorTiro.evaluar(MedidorTiro.centro, v), CalidadTiro.perfecto);
      expect(MedidorTiro.evaluar(MedidorTiro.centro + 0.07, v), CalidadTiro.bueno);
      expect(MedidorTiro.evaluar(MedidorTiro.centro - 0.07, v), CalidadTiro.bueno);
      expect(MedidorTiro.evaluar(0.3, v), CalidadTiro.temprano);
      expect(MedidorTiro.evaluar(1.0, v), CalidadTiro.tarde);
      final d = [for (final q in CalidadTiro.values) MedidorTiro.deltaTiro(q)];
      expect(d[0], greaterThan(d[1]));
      expect(d[1], greaterThan(0));
      expect(d[2], lessThan(0));
      expect(d[3], lessThan(d[2]));
      final (dp, tp) = MedidorTiro.efectoDefensa(CalidadTiro.perfecto);
      final (dt, tt) = MedidorTiro.efectoDefensa(CalidadTiro.tarde);
      expect(dp, lessThan(0));
      expect(dt, greaterThan(0));
      expect(tp, greaterThan(tt));
    });

    test('los ajustes se guardan en la carrera y vuelven igual; sin guardar, "solo importantes"', () {
      final liga = Liga(parsearCatalogo(File(rutaCatalogo).readAsStringSync()), franquicias, azar: Random(1));
      final c = CarreraJugador(liga);
      final e = c.estadoReal(raiz: 'm1', carta: liga.catalogo.firstWhere((j) => j.nbaPlayerId > 0));
      expect(AjustesMedidor.de(e).modo, ModoMedidor.importantes);
      const a = AjustesMedidor(modo: ModoMedidor.todos, zona: 2, mantener: true);
      final r = AjustesMedidor.de(e.copyWith(uso: {...e.uso, ...a.aUso}));
      expect((r.modo, r.zona, r.mantener), (ModoMedidor.todos, 2, true));
      expect(PerfilVivo.de(e).ajustes.modo, ModoMedidor.importantes);
    });
  });

  group('la barra en pantalla', () {
    setUpAll(() {
      SonidoPartido.habilitado = false;
      VozRelator.habilitado = false;
      JugadorAvatar.usarRed = false;
    });

    testWidgets('tocar en la zona verde da "perfecto"; dejar que se llene sale tarde', (t) async {
      CalidadTiro? salida;
      Future<void> montar({bool mantener = false}) => t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HojaMedidor(
              key: UniqueKey(),
              momento: momento(triple: true),
              ventana: 0.2,
              segundos: 1,
              mantener: mantener,
              alSoltar: (q, _) => salida = q,
            ),
          ),
        ),
      );
      await montar();
      expect(find.text('¡TIRÁ DE TRES!'), findsOneWidget);
      // La barra llega al centro de la zona verde a los 0,82 s.
      await t.pump(const Duration(milliseconds: 820));
      await t.tap(find.text('SOLTAR'));
      await t.pump();
      expect(salida, CalidadTiro.perfecto);
      salida = null;
      await montar();
      await t.pump(const Duration(milliseconds: 1200));
      expect(salida, CalidadTiro.tarde, reason: 'si se llena del todo, sale tarde');
      salida = null;
      await montar();
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text('SOLTAR'));
      await t.pump();
      expect(salida, CalidadTiro.temprano);
    });

    testWidgets('en modo "mantener y soltar" no arranca hasta que apretás, y soltar resuelve', (t) async {
      CalidadTiro? salida;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HojaMedidor(
              momento: momento(tipo: TipoMomento.defensa),
              ventana: 0.2,
              segundos: 1,
              mantener: true,
              alSoltar: (q, _) => salida = q,
            ),
          ),
        ),
      );
      expect(find.textContaining('DEFENDÉ'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 2000));
      expect(salida, isNull, reason: 'sin apretar no pasa nada');
      final g = await t.startGesture(t.getCenter(find.text('MANTENÉ Y SOLTÁ')));
      await t.pump(); // el primer cuadro arranca la barra
      await t.pump(const Duration(milliseconds: 820));
      await g.up();
      await t.pump();
      expect(salida, CalidadTiro.perfecto);
    });

    testWidgets('en Mi carrera el partido se frena en tu tiro, el timing lo resuelve y no hay controles de entrenador', (t) async {
      t.view.physicalSize = const Size(412, 900) * 2.5;
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
      final liga = Liga(catalogo, franquicias, azar: Random(2));
      var p = const Plantel();
      final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
      for (final pos in Posicion.values) {
        p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
      }
      final temporada = liga.iniciar(Temporada(id: 'mm', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
      final partido = liga.proximoDelUsuario(temporada)!;
      final usuarioLocal = partido.localId == 'CHI';
      final m = liga.motor(temporada, partido, azar: Random(5));
      final yo = m.enCancha(usuarioLocal).first.id;
      Map<String, int>? uso;
      await t.pumpWidget(
        MaterialApp(
          theme: temaFranquicia(franquiciaPorId('CHI')),
          home: PartidoPantalla(
            motor: m,
            usuarioLocal: usuarioLocal,
            franquiciaUsuario: franquiciaPorId('CHI'),
            identidadLocal: franquiciaPorId(usuarioLocal ? 'CHI' : temporada.rivales[partido.localId]!.identidadId),
            identidadVisitante: franquiciaPorId(usuarioLocal ? temporada.rivales[partido.visitanteId]!.identidadId : 'CHI'),
            jugadorCarrera: perfil(yo),
            alUsarCarrera: (u) => uso = u,
            onTerminado: (_) {},
          ),
        ),
      );
      // Sin controles de entrenador.
      expect(find.textContaining('TIEMPO MUERTO'), findsNothing);
      expect(find.text('Acelerar ritmo'), findsNothing);
      expect(find.text('Presión alta'), findsNothing);
      expect(find.text('Mis decisiones'), findsOneWidget);
      for (var i = 0; i < 120 && find.byType(HojaMedidor).evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(HojaMedidor), findsOneWidget, reason: 'el partido se frenó en un tiro tuyo o de tu marca');
      expect(m.momentoPendiente, isNotNull);
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.byType(FilledButton).last);
      await t.pump();
      expect(find.byType(HojaMedidor), findsNothing);
      expect(m.momentoPendiente, isNull);
      // Se cierra la pantalla (simula lo que falta) sin dejar nada pendiente.
      await t.tap(find.byTooltip('Pausa'));
      await t.pump();
      expect(uso, isNull);
    });
  });
}
