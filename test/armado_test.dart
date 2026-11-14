import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/estado_app.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/franquicia.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/armado.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/presentation/modos/armado.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final ids = [for (final f in franquicias) f.id];
  String nombre(String id) => franquiciaPorId(id).nombreCompleto;
  Conferencia? conf(String id) {
    try {
      return franquiciaPorId(id).conferencia;
    } catch (_) {
      return null;
    }
  }

  setUpAll(() => JugadorAvatar.usarRed = false);

  group('Tope salarial', () {
    final modos = ModosArmado(catalogo, azar: Random(1));

    test('el tablero siempre permite un plantel válido dentro del presupuesto', () {
      for (var semilla = 0; semilla < 25; semilla++) {
        final t = modos.tablero(semilla);
        expect(t, hasLength(25));
        final js = [for (final id in t) modos.jugador(id)!];
        expect(js.map((j) => j.nbaPlayerId).toSet(), hasLength(25), reason: 'sin personas repetidas');
        for (var k = 0; k < 25; k++) {
          expect(precioTope(js[k]), EstadoTope.filas[k ~/ 5], reason: 'fila de precio');
          expect(js[k].puedeJugarEn(Posicion.titulares[k % 5]), isTrue, reason: 'columna de puesto');
        }
        for (final d in Dificultad.values) {
          final p = modos.mejorPlantelTope(t, presupuestoTope(d));
          expect(p, isNotNull);
          expect(p!.completo, isTrue);
          expect(p.jugadores.fold(0, (a, j) => a + precioTope(j)), lessThanOrEqualTo(presupuestoTope(d)));
        }
      }
    });

    test('comprar respeta presupuesto, puestos y deja \$1 por puesto que falta', () {
      final p = modos.nuevoTope(
        semilla: 7,
        dificultad: Dificultad.leyenda,
        franquiciaUsuario: 'CHI',
        franquicias: ids,
        nombreDe: nombre,
      );
      expect(p.equipos, hasLength(8));
      final personas = <int>{};
      for (final e in p.equipos.skip(1)) {
        expect(e.plantel.completo, isTrue);
        expect(e.plantel.jugadores.fold(0, (a, j) => a + precioTope(j)), lessThanOrEqualTo(13));
        for (final j in e.plantel.jugadores) {
          expect(personas.add(j.nbaPlayerId), isTrue, reason: 'nadie en dos equipos');
        }
      }
      var e = p.tope!;
      expect(e.presupuesto, 13);
      final js = [for (final id in e.tablero) modos.jugador(id)!];
      // Una carta de $5 de base: quedan $8 para 5 puestos.
      e = modos.comprar(e, js[0], Posicion.base);
      expect(modos.restante(e), 8);
      // Otra de $4 dejaría $4 para 4 puestos: entra justo. Una de $5 no.
      expect(modos.motivoNoCompra(e, js[1], Posicion.escolta), contains('No te alcanza'));
      expect(modos.motivoNoCompra(e, js[5], Posicion.base), contains('ocupado'));
      e = modos.comprar(e, js[6], Posicion.escolta);
      for (var col = 2; col < 5; col++) {
        e = modos.comprar(e, js[20 + col], Posicion.titulares[col]);
      }
      e = modos.comprar(e, js[20], Posicion.sextoHombre);
      expect(e.completo, isTrue);
      expect(modos.restante(e), greaterThanOrEqualTo(0));
      final lista = modos.confirmarTope(p.copyWith(tope: e));
      expect(lista.fase, FaseArmada.liga);
      expect(lista.partidos, hasLength(56));
      final copia = PartidaArmada.fromJson(lista.toJson());
      expect(copia.toJson(), lista.toJson());
    });
  });

  group('Liga de 8 contra la IA', () {
    final modos = ModosArmado(catalogo, azar: Random(2));

    test('los estilos eligen distinto', () {
      final pool = [for (final id in modos.pozo(5)) modos.jugador(id)!];
      final mejores = {
        for (final e in EstiloGM.values)
          e:
              (pool.toList()..sort(
                    (a, b) => valorParaEstilo(e, b, const Plantel()).compareTo(valorParaEstilo(e, a, const Plantel())),
                  ))
                  .take(5)
                  .map((j) => j.id)
                  .toSet(),
      };
      expect(mejores.values.map((s) => s.join()).toSet().length, greaterThanOrEqualTo(5));
      final joven = mejores[EstiloGM.joven]!.map((id) => modos.jugador(id)!.epoca.index);
      final viejo = mejores[EstiloGM.nostalgico]!.map((id) => modos.jugador(id)!.epoca.index);
      expect(joven.reduce((a, b) => a + b), greaterThan(viejo.reduce((a, b) => a + b)));
    });

    test('draft en serpiente sin repetidos, liga de 14 por equipo, playoffs y campeón', () {
      var p = modos.nuevaLigaIA(semilla: 11, franquiciaUsuario: 'BOS', franquicias: ids, nombreDe: nombre);
      expect(p.draft!.pozo, hasLength(72));
      p = modos.avanzarIA(p);
      while (!p.draft!.terminado) {
        expect(p.draft!.eligeAhora, PartidaArmada.usuario);
        final j = modos.elegibles(p, 0).first;
        p = modos.elegir(p, j, modos.puestoPara(p, 0, j));
        final copia = PartidaArmada.fromJson(p.toJson());
        expect(copia.draft!.turno, p.draft!.turno);
      }
      final personas = <int>{};
      for (final e in p.equipos) {
        expect(e.plantel.completo, isTrue, reason: e.nombre);
        for (final j in e.plantel.jugadores) {
          expect(personas.add(j.nbaPlayerId), isTrue, reason: '${j.nombre} en dos equipos');
        }
      }
      expect(p.fase, FaseArmada.liga);
      for (var i = 0; i < 8; i++) {
        expect(p.partidos.where((x) => x.local == i || x.visitante == i), hasLength(14));
      }
      p = modos.simularProximoDelUsuario(p);
      expect(p.recordUsuario.$1 + p.recordUsuario.$2, 1);
      p = modos.simularTodo(p);
      expect(p.fase, FaseArmada.terminada);
      expect(p.semis, hasLength(2));
      final t = p.tabla();
      expect({p.semis[0].alto, p.semis[0].bajo}, {t[0].indice, t[3].indice});
      expect(p.campeon, isNotNull);
    });

    test('premio: XP por partido y logro al salir campeón (una sola vez)', () {
      var p = modos.nuevaLigaIA(semilla: 3, franquiciaUsuario: 'LAL', franquicias: ids, nombreDe: nombre);
      p = modos.avanzarIA(p);
      while (!p.draft!.terminado) {
        final j = modos.elegibles(p, 0).reduce((a, b) => a.media >= b.media ? a : b);
        p = modos.elegir(p, j, modos.puestoPara(p, 0, j));
      }
      final t0 = Temporada(id: 'ia', franquiciaUsuarioId: 'LAL', modoJuego: ModoJuego.ligaIA).conArmada(p);
      final fin = modos.simularTodo(p);
      final t1 = t0.conArmada(fin);
      final (perfil, novedades) = premiarArmado(const PerfilEntrenador(), t0, t1);
      expect(perfil.xp, greaterThan(0));
      expect(novedades, isNotEmpty);
      if (fin.campeon == PartidaArmada.usuario) expect(perfil.logros.containsKey(Logro.ligaIA), isTrue);
      final (otra, _) = premiarArmado(perfil, t1, t1);
      expect(otra.xp, perfil.xp, reason: 'sin cambios no hay premio');
      // Por Progreso: tampoco toca récords de temporada.
      final liga = Liga(catalogo, franquicias);
      final (viaProgreso, _) = Progreso(liga).aplicar(const PerfilEntrenador(), t0, t1);
      expect(viaProgreso.xp, perfil.xp);
      expect(viaProgreso.historial, isEmpty);
    });
  });

  group('Desafíos de armado', () {
    Jugador de(String f, Epoca e) => catalogo.firstWhere((j) => j.franquiciaId == f && j.epoca == e);

    test('las condiciones se evalúan bien', () {
      final chi90 = catalogo.where((j) => j.equipo == 'CHI' && j.epoca == Epoca.anios90).take(6).toList();
      expect(const UnaSolaDecada().cumple(chi90, conf), isTrue);
      expect(const MismaFranquicia(6).cumple(chi90, conf), isTrue);
      expect(const DeConferencia(Conferencia.este, 6, exacto: true).cumple(chi90, conf), isTrue);
      expect(const DeConferencia(Conferencia.oeste, 1).cumple(chi90, conf), isFalse);
      final mezcla = [de('BOS', Epoca.anios80), de('LAL', Epoca.anios2000), de('MIA', Epoca.anios2010)];
      expect(const DecadasDistintas(3).cumple(mezcla, conf), isTrue);
      expect(const DecadasDistintas(2, maximo: 2).cumple(mezcla, conf), isFalse);
      expect(const QuimicaMinima(60).cumple(chi90, conf), isTrue);
      expect(const TierMaximo(Tier.a, 0).cumple(chi90, conf), chi90.every((j) => j.tier == Tier.b));
    });

    test('resolver suma monedas una vez, desbloquea el siguiente y respeta el álbum', () {
      var p = const PerfilEntrenador();
      expect(p.desafioDesbloqueado(0), isTrue);
      expect(p.desafioDesbloqueado(1), isFalse);
      p = p.conDesafioResuelto(desafiosArmado[0]);
      expect(p.monedas, desafiosArmado[0].monedas);
      expect(p.desafioDesbloqueado(1), isTrue);
      expect(p.conDesafioResuelto(desafiosArmado[0]).monedas, p.monedas, reason: 'no se cobra dos veces');
      expect(PerfilEntrenador.fromJson(p.toJson()).desafiosResueltos, {'d01'});
      final pocas = catalogo.take(5).toList();
      expect(albumAlcanza(desafiosArmado[0], pocas), isFalse);
      final chi = catalogo.where((j) => j.franquiciaId == 'CHI').take(80).toList();
      expect(albumAlcanza(desafiosArmado.last, chi), isTrue);
      expect(desafiosArmado, hasLength(20));
      expect(desafiosArmado.map((d) => d.id).toSet(), hasLength(20));
    });
  });

  group('Adiviná la carta', () {
    final a = Adivina(catalogo, azar: Random(9));

    test('¿Quién es?: 4 opciones creíbles (mismo puesto y época) y la respuesta entre ellas', () {
      for (var k = 0; k < 40; k++) {
        final q = a.pregunta(VarianteAdivina.quien);
        expect(q.opciones, hasLength(4));
        expect(q.opciones[q.correcta], q.objetivo);
        expect(q.opciones.map((j) => j.nbaPlayerId).toSet(), hasLength(4));
        for (final o in q.opciones) {
          expect(o.posiciones.first, q.objetivo.posiciones.first);
          expect(o.epoca, q.objetivo.epoca);
        }
      }
    });

    test('Más o menos: la correcta es la de más media; récord y logro', () {
      for (var k = 0; k < 40; k++) {
        final q = a.pregunta(VarianteAdivina.masMenos);
        expect(q.opciones, hasLength(2));
        expect(q.opciones[q.correcta].media, greaterThan(q.opciones[1 - q.correcta].media));
      }
      var p = const PerfilEntrenador().conSesionAdivina(VarianteAdivina.masMenos, 7, 10);
      expect(p.mejorAdivina(VarianteAdivina.masMenos), 7);
      p = p.conSesionAdivina(VarianteAdivina.masMenos, 4, 10);
      expect(p.mejorAdivina(VarianteAdivina.masMenos), 7, reason: 'se queda el mejor');
      p = p.conSesionAdivina(VarianteAdivina.quien, 10, 10);
      expect(p.logros.containsKey(Logro.adivina), isTrue);
      expect(PerfilEntrenador.fromJson(p.toJson()).mejorAdivina(VarianteAdivina.quien), 10);
    });
  });

  group('pantallas', () {
    Widget app(Widget home) => MaterialApp(theme: temaFranquicia(franquiciaPorId('CHI')), home: home);
    final liga = Liga(catalogo, franquicias);

    testWidgets('tope salarial: comprar del tablero baja la plata', (t) async {
      t.view.physicalSize = const Size(412, 1000) * 2.5;
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      final modos = ModosArmado(catalogo, azar: Random(1));
      final p = modos.nuevoTope(
        semilla: 4,
        dificultad: Dificultad.normal,
        franquiciaUsuario: 'CHI',
        franquicias: ids,
        nombreDe: nombre,
      );
      Temporada? guardada;
      await t.pumpWidget(
        app(
          ArmadoPantalla(
            temporada: Temporada(id: 'ts', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.topeSalarial).conArmada(p),
            liga: liga,
            onCambio: (x) => guardada = x,
          ),
        ),
      );
      await t.pump();
      expect(find.text('\$15'), findsWidgets);
      final barato = modos.jugador(p.tope!.tablero[20])!;
      await t.tap(find.byKey(ValueKey('tope-${barato.id}')));
      await t.pump();
      expect(guardada, isNotNull);
      expect(PartidaArmada.de(guardada!)!.tope!.compra, isNotEmpty);
    });

    testWidgets('adiviná: responder suma y avanza', (t) async {
      t.view.physicalSize = const Size(412, 900) * 2.5;
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      PerfilEntrenador? perfil;
      await t.pumpWidget(
        app(
          AdivinaPantalla(
            catalogo: catalogo,
            variante: VarianteAdivina.masMenos,
            azar: Random(3),
            onPerfil: (p) => perfil = p,
          ),
        ),
      );
      await t.pump();
      expect(find.textContaining('1 / 10'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('opcion-0')));
      await t.pump();
      expect(find.text('SIGUIENTE'), findsOneWidget);
      await t.tap(find.text('SIGUIENTE'));
      await t.pump();
      expect(find.textContaining('2 / 10'), findsOneWidget);
      expect(perfil, isNull, reason: 'el perfil se guarda al terminar la sesión');
      perfilApp.value = const PerfilEntrenador();
    });
  });
}
