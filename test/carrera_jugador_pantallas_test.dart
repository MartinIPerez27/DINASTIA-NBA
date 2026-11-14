import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/presentation/modos/carrera_jugador_pantallas.dart';
import 'package:dinastia_nba/presentation/modos/creador_jugador.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(43));
  final carrera = CarreraJugador(liga);
  final creado = JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
    alturaCm: 200,
    pesoKg: 95,
  );

  void telefono(WidgetTester t) {
    t.view.physicalSize = const Size(412, 900) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    JugadorAvatar.usarRed = false;
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  testWidgets('el creador valida, muestra la vista previa y devuelve el jugador', (t) async {
    telefono(t);
    t.view.physicalSize = const Size(412, 2200) * 2.5;
    JugadorCreado? salida;
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  salida = await Navigator.of(context).push<JugadorCreado>(
                    MaterialPageRoute(builder: (_) => const CreadorJugadorPantalla(textoBoton: 'LISTO')),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    // Sin nombre no deja continuar.
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'LISTO')).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'Lucía Gómez');
    await t.pump();
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'LISTO')).onPressed, isNotNull);
    // Cambiar de puesto cambia los arquetipos.
    await t.tap(find.text('PÍVOT'));
    await t.pump();
    expect(find.text('Goliat de Pintura'), findsWidgets);
    // Tres fuertes: al sacar uno no deja continuar.
    await t.tap(find.widgetWithText(FilterChip, 'Tiro exterior'));
    await t.pump();
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'LISTO')).onPressed, isNull);
    await t.tap(find.widgetWithText(FilterChip, 'Tiro exterior'));
    await t.pump();
    await t.ensureVisible(find.widgetWithText(FilledButton, 'LISTO'));
    await t.tap(find.widgetWithText(FilledButton, 'LISTO'));
    await t.pumpAndSettle();
    expect(salida?.nombre, 'Lucía Gómez');
    expect(salida?.posicion, Posicion.pivot);
    expect(salida?.fuertes, hasLength(3));
  });

  testWidgets('Mi jugador: gastar un punto sube el atributo y avisa', (t) async {
    telefono(t);
    t.view.physicalSize = const Size(412, 2600) * 2.5;
    final e0 = carrera.estadoCreado(raiz: 'w1', creado: creado, pick: 9, franquiciaId: 'CHI').copyWith(phBanco: 6);
    final temporada = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
    Temporada? ultima;
    await t.pumpWidget(app(MiJugadorPantalla(temporada: temporada, carrera: carrera, onCambiar: (x) => ultima = x)));
    expect(find.text('Mi jugador'), findsOneWidget);
    expect(find.text('Lucía Gómez'), findsOneWidget);
    final antes = EstadoCarrera.de(temporada)!;
    final boton = find.text('+1 · ${ModeloCarrera.costo(antes.atributos[Atributo.tiro])}').first;
    await t.ensureVisible(boton);
    await t.tap(boton);
    await t.pump();
    final despues = EstadoCarrera.de(ultima!)!;
    expect(despues.atributos[Atributo.tiro], antes.atributos[Atributo.tiro] + 1);
    expect(despues.phBanco, lessThan(6));
    expect(ultima!.plantel.completo, isTrue);
  });

  testWidgets('el receso recorre los pasos y llega a arrancar la temporada siguiente', (t) async {
    telefono(t);
    final e0 = carrera.estadoCreado(raiz: 'w2', creado: creado, pick: 5, franquiciaId: 'CHI');
    var temporada = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
    temporada = liga.simularRestoPlayoffs(liga.simularOtrosHasta(_jugar(liga, temporada), 1 << 30));
    final e = EstadoCarrera.de(temporada)!;
    final cierre = carrera.cerrar(temporada, e, (id) => franquiciaPorId(id).nombreCompleto);
    EstadoCarrera? guardado;
    EstadoCarrera? alSeguir;
    await t.pumpWidget(
      app(
        RecesoJugadorPantalla(
          temporada: temporada,
          estado: cierre.estado,
          carrera: carrera,
          cierre: cierre,
          onEstado: (x) => guardado = x,
          onSeguir: (x, o) => alSeguir = x,
          onRetirar: (_) {},
        ),
      ),
    );
    expect(find.textContaining('FIN DE LA TEMPORADA 1'), findsOneWidget);
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    expect(find.text('ENTRENAMIENTO'), findsOneWidget);
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    // Prensa: no deja seguir hasta responder las dos preguntas.
    expect(find.text('CONFERENCIA DE PRENSA'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'CONTINUAR')).onPressed, isNull);
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byType(OutlinedButton).first);
      await t.pumpAndSettle();
    }
    expect(guardado?.prensaHecha, 2);
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    expect(find.text('TU CONTRATO'), findsOneWidget);
    await t.tap(find.text('ARRANCAR LA TEMPORADA 2'));
    await t.pumpAndSettle();
    expect(alSeguir?.prensaHecha, 2);
  });

  testWidgets('legado: totales, veredicto y línea de tiempo', (t) async {
    telefono(t);
    var e = carrera.estadoCreado(raiz: 'w3', creado: creado, pick: 5, franquiciaId: 'CHI');
    e = e.copyWith(
      historial: [
        const TemporadaJugador(
          numero: 1,
          etiqueta: '2026–27',
          franquiciaId: 'CHI',
          edad: 20,
          media: 72,
          pj: 70,
          pts: 14.2,
          reb: 4.1,
          ast: 2.3,
          victorias: 44,
          derrotas: 38,
          resultado: '1.ª ronda',
        ),
      ],
    );
    await t.pumpWidget(app(LegadoCarreraPantalla(estado: e, carrera: carrera)));
    expect(find.text('LÍNEA DE TIEMPO'), findsOneWidget);
    expect(find.textContaining('Temporada 1 (2026–27)'), findsOneWidget);
  });
}

Temporada _jugar(Liga liga, Temporada t) {
  while (liga.proximoDelUsuario(t) != null) {
    t = liga.simularProximo(t);
  }
  return t;
}
