import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/vida_carrera.dart';
import 'package:dinastia_nba/presentation/modos/carrera_equipo_pantallas.dart';
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
    t.view.physicalSize = const Size(412, 6000) * 2.5;
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
    // Rutina de entrenamiento: se elige y queda guardada.
    await t.ensureVisible(find.text('Taller de tiro'));
    await t.tap(find.text('Taller de tiro'));
    await t.pumpAndSettle();
    expect(VidaCarrera.rutinaDe(guardado!), Rutina.tiro);
    await t.ensureVisible(find.text('CONTINUAR'));
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    // Evento fuera de la cancha: no deja seguir hasta elegir una respuesta.
    expect(find.text('FUERA DE LA CANCHA'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'CONTINUAR')).onPressed, isNull);
    await t.tap(find.byType(FilledButton).first);
    await t.pumpAndSettle();
    expect((guardado!.uso['evento'] ?? 0), greaterThan(0));
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

  testWidgets('el desglose muestra de dónde salió cada punto y las notas de partido', (t) async {
    telefono(t);
    final e = carrera
        .estadoCreado(raiz: 'w9', creado: creado, pick: 5, franquiciaId: 'CHI')
        .copyWith(uso: {'dg:rend': 1250, 'dg:nota': 840, 'dg:obj': 400, 'gr:A+': 3, 'gr:B': 12});
    await t.pumpWidget(app(Scaffold(body: PanelDesglose(estado: e))));
    expect(find.text('PUNTOS DE ESTA TEMPORADA'), findsOneWidget);
    expect(find.text('Rendimiento'), findsOneWidget);
    expect(find.text('12,5'), findsOneWidget);
    expect(find.text('Objetivos'), findsOneWidget);
    expect(find.text('Premios'), findsNothing, reason: 'sin puntos de premios todavía');
    expect(find.text('A+ ×3'), findsOneWidget);
    expect(find.text('B ×12'), findsOneWidget);
    expect(find.text('24,9'), findsOneWidget, reason: 'el total suma las fuentes');
  });

  testWidgets('elegir objetivos: de 4 a 6 de los 8 ofrecidos, con su nivel y puntos', (t) async {
    telefono(t);
    t.view.physicalSize = const Size(412, 2200) * 2.5;
    final base = carrera.estadoCreado(raiz: 'w10', creado: creado, pick: 5, franquiciaId: 'CHI');
    final ofrecidos = ObjetivosCarrera.ofrecer(base, Random(2));
    final e = base.copyWith(ofrecidos: ofrecidos, objetivos: ObjetivosCarrera.porDefecto(ofrecidos));
    EstadoCarrera? salida;
    await t.pumpWidget(app(ElegirObjetivosPantalla(estado: e, onConfirmar: (x) => salida = x)));
    expect(find.text('Objetivos de la temporada'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(8));
    expect(find.textContaining('Elegiste 4'), findsOneWidget);
    // Sumar dos más y confirmar.
    final sinElegir = [
      for (var i = 0; i < 8; i++)
        if (!e.objetivos.contains(ofrecidos[i])) i,
    ];
    for (final i in sinElegir.take(2)) {
      await t.tap(find.byType(CheckboxListTile).at(i));
      await t.pump();
    }
    expect(find.textContaining('Elegiste 6'), findsOneWidget);
    await t.tap(find.text('CONFIRMAR OBJETIVOS'));
    await t.pumpAndSettle();
    expect(salida?.objetivos.length, 6);
  });

  testWidgets('el panel de objetivos largos muestra el mini-objetivo del mes y la carrera', (t) async {
    telefono(t);
    final e = carrera
        .estadoCreado(raiz: 'w11', creado: creado, pick: 5, franquiciaId: 'CHI')
        .copyWith(uso: {'mo:tipo': MiniObjetivo.puntos.index, 'mo:meta': 220, 'mes:n': 6, 'mes:pts': 150, 'c:td': 4});
    await t.pumpWidget(app(Scaffold(body: SingleChildScrollView(child: PanelObjetivosLargos(estado: e)))));
    expect(find.textContaining('MINI-OBJETIVO DEL MES'), findsOneWidget);
    expect(find.textContaining('22,0 puntos'), findsOneWidget);
    expect(find.text('OBJETIVOS DE CARRERA'), findsOneWidget);
    expect(find.text('0/${ObjetivoCarrera.values.length}'), findsOneWidget);
  });

  testWidgets('Mi equipo muestra el plantel con edad y contrato, y los movimientos', (t) async {
    telefono(t);
    final base = carrera.estadoCreado(raiz: 'w12', creado: creado, pick: 5, franquiciaId: 'CHI');
    final t0 = carrera.nuevaCarrera(estado: base, dificultad: Dificultad.normal);
    final e = EstadoCarrera.de(t0)!.copyWith(movimientos: ['2027–28: Fulano se retira a los 37 años.']);
    await t.pumpWidget(app(MiEquipoPantalla(estado: e)));
    expect(find.text('Mi equipo'), findsOneWidget);
    expect(find.textContaining('años'), findsWidgets);
    expect(find.text('MOVIMIENTOS DEL PLANTEL'), findsOneWidget);
    expect(find.textContaining('Fulano se retira'), findsOneWidget);
  });

  testWidgets('Mi generación lista la clase del draft con vos y tu rival', (t) async {
    telefono(t);
    final e = carrera.estadoCreado(raiz: 'w13', creado: creado, pick: 5, franquiciaId: 'CHI');
    final real = GeneracionCarrera.deJson2026(File('assets/database/draft_2026.json').readAsStringSync());
    await t.pumpWidget(app(GeneracionPantalla(estado: e, catalogo: liga.catalogo, clase2026: real)));
    await t.pumpAndSettle();
    expect(find.text('Clase del draft ${e.anioBase}'), findsOneWidget);
    expect(find.textContaining('TU RIVAL DE GENERACIÓN: AJ DYBANTSA'), findsOneWidget);
    expect(find.textContaining('Washington Wizards'), findsOneWidget);
  });

  testWidgets('la fecha límite de traspasos ofrece las tres opciones', (t) async {
    telefono(t);
    OpcionFechaLimite? elegida;
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => mostrarFechaLimite(context, (o) => elegida = o, rumor: 'Rumor: varios equipos preguntan por vos.'),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('Fecha límite de traspasos'), findsOneWidget);
    expect(find.textContaining('Rumor'), findsOneWidget);
    for (final o in OpcionFechaLimite.values) {
      expect(find.text(o.etiqueta), findsOneWidget);
    }
    await t.tap(find.text('Pedir el traspaso'));
    await t.pumpAndSettle();
    expect(elegida, OpcionFechaLimite.pedirTraspaso);
  });

  testWidgets('el creador de Mi carrera pide año, edad y número y los devuelve', (t) async {
    telefono(t);
    t.view.physicalSize = const Size(412, 3600) * 2.5;
    JugadorCreado? salida;
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  salida = await Navigator.of(context).push<JugadorCreado>(
                    MaterialPageRoute(builder: (_) => const CreadorJugadorPantalla(textoBoton: 'LISTO', conArranque: true)),
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
    expect(find.text('TU ARRANQUE'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Lucía Gómez');
    await t.pump();
    await t.ensureVisible(find.text('1995'));
    await t.tap(find.text('1995'));
    await t.pump();
    await t.ensureVisible(find.widgetWithText(FilledButton, 'LISTO'));
    await t.tap(find.widgetWithText(FilledButton, 'LISTO'));
    await t.pumpAndSettle();
    expect(salida?.anioDraft, 1995);
    expect(salida?.edadInicial, 20);
    expect(salida?.nacimiento, 1975);
  });

  testWidgets('la bandeja filtra por categoría y marca todo como leído al abrirla', (t) async {
    telefono(t);
    var leidos = 0;
    final base = carrera.estadoCreado(raiz: 'w14', creado: creado, pick: 5, franquiciaId: 'CHI');
    final et = base.etiquetaDe(1);
    final e = base.copyWith(
      hitos: ['$et: Jugador del mes.', '$et: mini-objetivo del mes cumplido — algo.'],
      movimientos: ['$et: Zutano se retira a los 36 años.'],
    );
    await t.pumpWidget(app(BandejaPantalla(estado: e, alAbrir: () => leidos++)));
    await t.pumpAndSettle();
    expect(find.text('Bandeja de entrada'), findsOneWidget);
    expect(find.textContaining('Todos (3)'), findsOneWidget);
    expect(leidos, 1);
    await t.tap(find.widgetWithText(ChoiceChip, 'Premios'));
    await t.pumpAndSettle();
    expect(find.textContaining('Jugador del mes'), findsOneWidget);
    expect(find.textContaining('se retira'), findsNothing);
  });

  testWidgets('los paneles de scouting, química, personalidad y avanzadas se ven', (t) async {
    telefono(t);
    t.view.physicalSize = const Size(412, 2400) * 2.5;
    final base = carrera.estadoCreado(raiz: 'w15', creado: creado, pick: 5, franquiciaId: 'CHI');
    final e = EstadoCarrera.de(carrera.nuevaCarrera(estado: base, dificultad: Dificultad.normal))!.copyWith(
      uso: {'c:pj': 150, 'c:pts': 3000, 'c:t3': 700, 'c:tcI': 1100, 'c:tcA': 2300, 'c:t3A': 1800, 'c:tlI': 400, 'c:tlA': 500, 'c:ast': 400, 'c:per': 300, 'c:seg': 150 * 30 * 60},
    );
    await t.pumpWidget(app(Scaffold(body: SingleChildScrollView(child: Column(children: [PanelMundo(estado: e), PanelAvanzadas(estado: e)])))));
    expect(find.textContaining('TU PERSONALIDAD'), findsOneWidget);
    expect(find.text('QUÍMICA DEL EQUIPO'), findsOneWidget);
    expect(find.text('SCOUTING DE LOS RIVALES'), findsOneWidget);
    expect(find.textContaining('Te cierran el triple'), findsOneWidget);
    expect(find.text('ESTADÍSTICAS AVANZADAS'), findsOneWidget);
    expect(find.text('TS %'), findsOneWidget);
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
