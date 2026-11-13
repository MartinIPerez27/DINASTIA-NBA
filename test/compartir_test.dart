import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/reto.dart';
import 'package:dinastia_nba/presentation/compartir/tarjeta_compartir.dart';
import 'package:dinastia_nba/presentation/modos/reto.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(3));
  JugadorAvatar.usarRed = false;

  /// Arma el plantel eligiendo siempre la mejor carta que sale (ruleta) o la primera del primer
  /// sobre (cartas): con el mismo código, dos personas que eligen igual tienen que llegar a lo mismo.
  Temporada draftear(Temporada t) {
    final draft = Draft(catalogo, azarPara: Reto.azarPara(t));
    while (!t.plantel.completo) {
      if (t.modo == ModoDraft.ruleta) {
        t = draft.tirar(t);
        final opciones = draft.candidatos(t)..sort((a, b) => b.media.compareTo(a.media));
        final j = opciones.firstWhere((j) => t.plantel.posicionesDisponiblesPara(j).isNotEmpty);
        t = draft.elegir(t, j, t.plantel.posicionesDisponiblesPara(j).first);
      } else {
        final p = Posicion.values.firstWhere((p) => draft.puedeRepartir(t, p));
        t = draft.abrirSobre(draft.repartir(t, p), 0);
        t = draft.fichar(t, draft.cartasDeOferta(t).first);
      }
    }
    return t.copyWith(tacticaConfirmada: true);
  }

  group('código de reto', () {
    test('ida y vuelta con todos los campos', () {
      final azar = Random(7);
      for (var i = 0; i < 300; i++) {
        final regla = ReglaDraft.values[azar.nextInt(ReglaDraft.values.length)];
        final c = CodigoReto(
          semilla: azar.nextInt(CodigoReto.maxSemilla),
          franquiciaId: Draft.franquiciasRivales[azar.nextInt(30)],
          modo: ModoDraft.values[azar.nextInt(2)],
          regla: regla,
          epoca: regla == ReglaDraft.unaDecada ? Epoca.values[azar.nextInt(Epoca.values.length)] : null,
          dificultad: Dificultad.values[azar.nextInt(3)],
          victorias: azar.nextBool() ? azar.nextInt(83) : null,
          campeon: azar.nextBool(),
        );
        final texto = c.codificar();
        expect(texto, matches(RegExp(r'^82-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$')));
        final leido = CodigoReto.leer(texto)!;
        expect(
          (leido.semilla, leido.franquiciaId, leido.modo, leido.regla, leido.epoca, leido.dificultad),
          (c.semilla, c.franquiciaId, c.modo, c.regla, c.epoca, c.dificultad),
        );
        expect((leido.victorias, leido.campeon), (c.victorias, c.campeon));
      }
    });

    test('tolera minúsculas, espacios y O/I/L; rechaza cualquier carácter mal tipeado', () {
      const c = CodigoReto(
        semilla: 123456,
        franquiciaId: 'CHI',
        modo: ModoDraft.ruleta,
        regla: ReglaDraft.libre,
        dificultad: Dificultad.normal,
        victorias: 64,
      );
      final texto = c.codificar();
      expect(CodigoReto.leer(texto.toLowerCase().replaceAll('-', ' ')), c);
      expect(CodigoReto.leer(texto.replaceAll('0', 'O').replaceAll('1', 'I')), c);
      const alfabeto = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final cuerpo = texto.substring(3);
      for (var i = 0; i < cuerpo.length; i++) {
        if (cuerpo[i] == '-') continue;
        for (final ch in alfabeto.split('')) {
          if (ch == cuerpo[i]) continue;
          final mal = '82-${cuerpo.substring(0, i)}$ch${cuerpo.substring(i + 1)}';
          expect(CodigoReto.leer(mal), isNull, reason: mal);
        }
      }
      expect(CodigoReto.leer('82-1234'), isNull);
      expect(CodigoReto.leer(''), isNull);
    });

    test('se puede retar desde una partida clásica con semilla, no desde "Mi colección" ni las viejas', () {
      final t = Temporada(
        id: 'x',
        franquiciaUsuarioId: 'BOS',
        datosModo: Reto.datosNuevos(3, azar: Random(1)),
      );
      final c = Reto.codigoDe(t)!;
      expect((c.franquiciaId, c.victorias), ('BOS', null));
      expect(Reto.codigoDe(const Temporada(id: 'vieja', franquiciaUsuarioId: 'BOS')), isNull);
      final coleccion = Temporada(
        id: 'c',
        franquiciaUsuarioId: 'BOS',
        regla: ReglaDraft.coleccion,
        datosModo: Reto.datosNuevos(3),
      );
      expect(Reto.codigoDe(coleccion), isNull);
      final aceptada = Reto.aceptar(c, id: 'y', fichasExtra: 1);
      expect(aceptada.modoJuego, ModoJuego.reto);
      expect(aceptada.rerollsRestantes, 4);
      expect(Reto.aceptadoEn(Temporada.fromJson(aceptada.toJson()))!.semilla, c.semilla);
    });
  });

  group('mismo código, mismo draft', () {
    for (final modo in ModoDraft.values) {
      test('${modo.nombre}: mismas cartas, mismo plantel y mismos rivales y calendario', () {
        final creador = Temporada(
          id: 'creador',
          franquiciaUsuarioId: 'LAL',
          modo: modo,
          rerollsRestantes: 5,
          datosModo: Reto.datosNuevos(5, azar: Random(99)),
        );
        final codigo = Reto.codigoDe(creador)!;
        // El amigo tiene otra cantidad de fichas: las tiradas no dependen de eso.
        final amigo = Reto.aceptar(CodigoReto.leer(codigo.codificar())!, id: 'amigo');
        expect(amigo.rerollsRestantes, isNot(creador.rerollsRestantes));

        if (modo == ModoDraft.ruleta) {
          final d1 = Draft(catalogo, azarPara: Reto.azarPara(creador));
          final d2 = Draft(catalogo, azarPara: Reto.azarPara(amigo));
          expect(d1.tirar(creador).tirada!.toJson(), d2.tirar(amigo).tirada!.toJson());
          expect(d1.candidatos(d1.tirar(creador)).map((j) => j.id), d2.candidatos(d2.tirar(amigo)).map((j) => j.id));
        }

        final a = draftear(creador), b = draftear(amigo);
        expect([for (final j in a.plantel.jugadores) j.id], [for (final j in b.plantel.jugadores) j.id]);
        expect(a.entrenadorId, b.entrenadorId);
        expect(
          Draft(catalogo).opcionesEntrenador(a).map((e) => e.id),
          Draft(catalogo).opcionesEntrenador(b).map((e) => e.id),
        );

        final la = Reto.ligaPara(liga, a).iniciar(a), lb = Reto.ligaPara(liga, b).iniciar(b);
        expect(
          {for (final e in la.rivales.entries) e.key: e.value.cartaIds.values.toList()},
          {for (final e in lb.rivales.entries) e.key: e.value.cartaIds.values.toList()},
        );
        expect(la.calendario.map((p) => p.id).take(40), lb.calendario.map((p) => p.id).take(40));

        // Otra semilla, otro draft.
        final otro = Reto.aceptar(
          CodigoReto(
            semilla: codigo.semilla + 1,
            franquiciaId: 'LAL',
            modo: modo,
            regla: ReglaDraft.libre,
            dificultad: Dificultad.normal,
          ),
          id: 'otro',
        );
        expect([
          for (final j in draftear(otro).plantel.jugadores) j.id,
        ], isNot([for (final j in a.plantel.jugadores) j.id]));
      });
    }

    test('sin semilla el draft sigue al azar como siempre', () {
      expect(Reto.azarPara(const Temporada(id: 'v', franquiciaUsuarioId: 'BOS')), isNull);
      expect(Reto.ligaPara(liga, const Temporada(id: 'v', franquiciaUsuarioId: 'BOS')), same(liga));
    });

    test('al final se comparan los récords', () {
      final codigo = const CodigoReto(
        semilla: 4242,
        franquiciaId: 'CHI',
        modo: ModoDraft.ruleta,
        regla: ReglaDraft.libre,
        dificultad: Dificultad.normal,
        victorias: 1,
      );
      var t = draftear(Reto.aceptar(codigo, id: 'r'));
      t = Reto.ligaPara(liga, t).iniciar(t);
      expect(Reto.comparar(t).$3, isNull, reason: 'temporada en curso');
      while (liga.proximoDelUsuario(t) != null) {
        t = liga.simularProximo(t);
      }
      t = liga.simularOtrosHasta(t, 1 << 30);
      final (tuya, amigo, veredicto) = Reto.comparar(t);
      expect(amigo, '1-81');
      expect(tuya, '${t.registroUsuario.victorias}-${t.registroUsuario.derrotas}');
      expect(veredicto, ResultadoReto.ganaste);
    });
  });

  group('pantallas', () {
    Temporada conPlantel({ModoJuego modo = ModoJuego.clasico}) {
      final base = Temporada(
        id: 'p',
        franquiciaUsuarioId: 'CHI',
        modoJuego: modo,
        datosModo: Reto.datosNuevos(3, azar: Random(2)),
      );
      return draftear(base);
    }

    testWidgets('la tarjeta se dibuja con plantel, récord y código', (tester) async {
      tester.view.physicalSize = const Size(400, 700) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final t = Reto.ligaPara(liga, conPlantel()).iniciar(conPlantel());
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: TarjetaCompartir(temporada: t, liga: liga),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('0-0'), findsOneWidget);
      expect(find.text(Reto.codigoDe(t)!.codificar()), findsOneWidget);
      final primero = t.plantel.jugadores.first;
      // Nombre y tramo ("Michael Jordan  CHI 1985–93"): cada carta dice qué etapa es.
      expect(find.textContaining(primero.nombre, findRichText: true), findsOneWidget);
      expect(find.textContaining(primero.tramoConEquipo, findRichText: true), findsWidgets);
      expect(find.text('DINASTÍA NBA (82-0)'), findsOneWidget);
    });

    testWidgets('la tarjeta de un modo de escalera muestra su marcador', (tester) async {
      tester.view.physicalSize = const Size(400, 700) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: TarjetaCompartir(temporada: conPlantel(modo: ModoJuego.racha)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('RACHA'), findsOneWidget);
    });

    testWidgets('la vista previa captura la imagen a 1080×1920', (tester) async {
      final t = conPlantel();
      await tester.pumpWidget(MaterialApp(home: CompartirPantalla(temporada: t)));
      await tester.pump();
      final clave = (tester.widget(
        find.ancestor(of: find.byType(TarjetaCompartir), matching: find.byType(RepaintBoundary)).first,
      ) as RepaintBoundary).key;
      expect(find.text('RETAR A UN AMIGO'), findsOneWidget);
      final png = await tester.runAsync(() => capturarPng(clave! as GlobalKey));
      expect(png, isNotNull);
      // Ancho y alto del PNG (cabecera IHDR).
      final b = png!;
      final ancho = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
      final alto = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
      expect((ancho, alto), (1080, 1920));
    });

    testWidgets('ingresar un código: valida, muestra el reto y lo acepta', (tester) async {
      const c = CodigoReto(
        semilla: 77,
        franquiciaId: 'BOS',
        modo: ModoDraft.cartas,
        regla: ReglaDraft.libre,
        dificultad: Dificultad.dificil,
        victorias: 64,
      );
      CodigoReto? aceptado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: IngresarCodigoReto(onAceptar: (x) => aceptado = x)),
        ),
      );
      await tester.enterText(find.byType(TextField), '82-ZZZZ-ZZZZ-ZZZZ');
      await tester.pump();
      expect(find.textContaining('no es válido'), findsOneWidget);
      expect(find.text('ACEPTAR EL RETO'), findsNothing);
      await tester.enterText(find.byType(TextField), c.codificar().toLowerCase());
      await tester.pump();
      expect(find.text('Reto de un amigo: Celtics'), findsOneWidget);
      expect(find.text('Superá su 64-18.'), findsOneWidget);
      await tester.tap(find.text('ACEPTAR EL RETO'));
      expect(aceptado, c);
    });
  });
}
