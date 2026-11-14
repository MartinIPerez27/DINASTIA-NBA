import 'dart:math';

import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/modos/universitario.dart';
import 'package:dinastia_nba/presentation/modos/modos.dart';
import 'package:dinastia_nba/presentation/modos/universitario.dart';
import 'package:dinastia_nba/presentation/modos/universitario_pantallas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JugadorCreado creado(String nombre, Posicion pos) => JugadorCreado(
  nombre: nombre,
  posicion: pos,
  rol: JugadorCreado.rolesDe(pos).first,
  fuertes: const [Atributo.tiro, Atributo.iq, Atributo.defensa],
);

void main() {
  const sim = Universitario();
  const programa = Programa(nombre: 'Lago Azul', mote: 'Cóndores', color1: 1, color2: 3);
  EstadoUniv nueva([int semilla = 7]) => sim.nueva(
    semilla: semilla,
    programa: programa,
    creados: [
      creado('Ana Pérez', Posicion.base),
      creado('Beto Ruiz', Posicion.pivot),
      creado('Cris Gómez', Posicion.alero),
    ],
  );

  test('los nombres ficticios son determinísticos con la misma semilla', () {
    final a = [for (var i = 0; i < 5; i++) NombresFicticios.persona(Random(i))];
    final b = [for (var i = 0; i < 5; i++) NombresFicticios.persona(Random(i))];
    expect(a, b);
    expect(a.toSet().length, greaterThan(2));
  });

  test('programa: sigla, errores y colores', () {
    expect(programa.sigla, 'LAX');
    expect(programa.sigla.length, 3);
    expect(const Programa(nombre: 'ab', mote: 'xxx', color1: 0, color2: 1).error, isNotNull);
    expect(const Programa(nombre: 'Norte Uni', mote: 'Osos', color1: 2, color2: 2).error, isNotNull);
    expect(programa.error, isNull);
    // Nunca repite la sigla de una universidad de la IA.
    final e = nueva();
    final siglas = {for (var i = 0; i < 32; i++) e.franquicia(i).id};
    expect(siglas.length, 32);
  });

  test('plantel: 10 jugadores, los creados primero y todos los puestos cubiertos', () {
    final e = nueva();
    expect(e.plantel.length, EstadoUniv.plantelBase);
    expect(e.plantel.where((x) => x.creado).length, 3);
    for (final p in Posicion.titulares) {
      expect(e.plantel.any((x) => x.posicion == p), isTrue, reason: p.etiqueta);
    }
    expect(
      () => sim.nueva(semilla: 1, programa: programa, creados: [creado('Solo Uno', Posicion.base)]),
      throwsArgumentError,
    );
  });

  test('las universidades de la IA se regeneran iguales y con nivel según su prestigio', () {
    final a = EstadoUniv.plantelIA(7, 1, 5, 50), b = EstadoUniv.plantelIA(7, 1, 5, 50);
    expect([for (final x in a) x.nombre], [for (final x in b) x.nombre]);
    expect(
      EstadoUniv.fuerzaDe(EstadoUniv.plantelIA(7, 1, 5, 90)),
      greaterThan(EstadoUniv.fuerzaDe(EstadoUniv.plantelIA(7, 1, 5, 15))),
    );
    expect(a.length, 10);
  });

  test('calendario: 30 jornadas, 16 partidos, todos juegan una vez por jornada y 14 son de conferencia', () {
    final e = nueva();
    final cal = e.calendario();
    expect(cal.length, 30);
    final conf = e.conferenciaDe;
    expect([for (var c = 0; c < 4; c++) conf.where((x) => x == c).length], [8, 8, 8, 8]);
    for (final j in cal) {
      expect(j.length, 16);
      expect(
        {
          for (final (l, v) in j) ...[l, v],
        }.length,
        32,
      );
    }
    for (var t = 0; t < 32; t++) {
      final suyos = [for (final j in cal) j.firstWhere((g) => g.$1 == t || g.$2 == t)];
      expect(suyos.length, 30);
      final deConf = suyos.where((g) => conf[g.$1] == conf[g.$2]).length;
      expect(deConf, 14, reason: 'equipo $t');
      // Conferencia: dos veces cada rival; fuera: sin repetir rival.
      final rivales = [for (final g in suyos) g.$1 == t ? g.$2 : g.$1];
      for (final r in rivales.where((r) => conf[r] == conf[t])) {
        expect(rivales.where((x) => x == r).length, 2);
      }
      for (final r in rivales.where((r) => conf[r] != conf[t])) {
        expect(rivales.where((x) => x == r).length, 1, reason: 'equipo $t rival $r');
      }
    }
    // Determinístico.
    expect(nueva().calendario().toString(), cal.toString());
  });

  test('temporada entera: puntajes razonables, tabla coherente y torneo de 16 con campeón', () {
    var e = nueva();
    e = sim.simularJornadas(e, 30);
    expect(e.fase, FaseUniv.torneo);
    expect(e.jornada, 30);
    final regs = e.registros();
    expect(regs.every((r) => r.jugados == 30), isTrue);
    expect(regs.fold(0, (a, r) => a + r.v), 480);
    expect(regs.fold(0, (a, r) => a + r.d), 480);
    for (var i = 0; i < 960; i += 2) {
      expect(e.resultados[i], inInclusiveRange(55, 190));
      expect(e.resultados[i], isNot(e.resultados[i + 1]));
    }
    // Los de la liga se separan por nivel: el mejor récord gana bastante más que el peor.
    final orden = [...regs]..sort(EstadoUniv.comparar);
    expect(orden.first.v, greaterThan(orden.last.v + 8));
    expect(e.plantel.every((p) => p.pj >= 0), isTrue);
    expect(e.plantel.fold(0, (a, p) => a + p.pj), greaterThan(150), reason: 'tus jugadores acumulan líneas del motor');
    final clas = e.clasificados();
    expect(clas.length, 16);
    expect(clas.toSet().length, 16);
    final conf = e.conferenciaDe;
    for (var c = 0; c < 4; c++) {
      expect(clas.any((i) => conf[i] == c), isTrue);
    }
    e = sim.simularTorneo(e);
    expect(e.fase, FaseUniv.premios);
    expect(e.torneo.length, 4);
    expect([for (final r in e.torneo) r.length], [8, 4, 2, 1]);
    expect(e.campeon, isNotNull);
    expect(clas, contains(e.campeon));
    expect(['Campeón', 'Final', 'Semifinal', 'Cuartos', 'Octavos', 'Sin torneo'], contains(e.resultadoTorneoUsuario));
  });

  test('ranking: 32 equipos distintos; premios: novato es de primer año y los equipos no repiten gente', () {
    final e = sim.simularJornadas(nueva(), 30);
    expect(e.ranking().toSet().length, 32);
    final p = e.premios();
    expect(p.novato?.anio, 1);
    expect(p.primerEquipo.length, 5);
    expect(p.segundoEquipo.length, 5);
    final ids = {...p.primerEquipo.map((x) => x.id), ...p.segundoEquipo.map((x) => x.id)};
    expect(ids.length, 10);
    expect(p.primerEquipo.every((x) => x.valor <= p.mejor.valor + 1e-9), isTrue);
    // Determinístico.
    expect(e.premios().mejor.nombre, p.mejor.nombre);
  });

  test('jornada con motor: mi partido en vivo se registra tal cual', () {
    var e = nueva();
    final (juego, _) = e.partidoUsuario(0)!;
    final m = sim.motor(e, juego)..simularTodo();
    e = sim.simularJornada(e, motorUsuario: m);
    final (_, idx) = nueva().partidoUsuario(0)!;
    expect(e.resultado(0, idx), (m.puntosLocal, m.puntosVisitante));
    expect(e.jornada, 1);
  });

  test('receso: progresión, reclutas con precio, draft con tus declarados y siguiente temporada', () {
    var e = sim.simularTorneo(sim.simularJornadas(nueva(), 30));
    e = sim.cerrarTemporada(e);
    expect(e.fase, FaseUniv.receso);
    expect(e.historial.length, 1);
    expect(e.historial.single.numero, 1);
    expect(e.prestigio, inInclusiveRange(0, 100));
    final seniors = e.plantel.where((x) => x.anio >= 4).length;
    final (quedan, seVan, cambios) = e.pasarDeAnio({});
    expect(seVan.length, seniors);
    expect(quedan.length + seVan.length, e.plantel.length);
    expect(quedan.every((x) => x.anio >= 2), isTrue);
    for (final q in quedan) {
      final antes = e.plantel.firstWhere((x) => x.id == q.id);
      expect(q.media, greaterThanOrEqualTo(antes.media - 3));
      expect(cambios[q.id], isNotNull);
    }
    // Los de primer año crecen en promedio más que los de tercero.
    final jovenes = quedan.where((x) => x.anio == 2).toList();
    final grandes = quedan.where((x) => x.anio == 4).toList();
    if (jovenes.isNotEmpty && grandes.isNotEmpty) {
      double crec(List l) =>
          l.fold(0.0, (a, x) => a + (x.media - e.plantel.firstWhere((y) => y.id == x.id).media)) / l.length;
      expect(crec(jovenes), greaterThanOrEqualTo(crec(grandes) - 1));
    }
    final rec = e.reclutas();
    expect(rec.length, 8);
    expect(rec.every((r) => r.precio == Recluta.precios[r.estudiante.estrellas]), isTrue);
    expect(rec.every((r) => r.estudiante.anio == 1), isTrue);
    expect(e.reclutas().map((r) => r.estudiante.nombre).toList(), rec.map((r) => r.estudiante.nombre).toList());
    expect(e.puntosReclutamiento(), greaterThan(8));
    final tabla = e.tablaDraft(seVan);
    expect(tabla.primeraRonda.length, 30);
    expect(tabla.primeraRonda.map((p) => p.pick).toList(), List.generate(30, (i) => i + 1));
    final sig = sim.cerrarReceso(e, declarados: {}, firmados: rec.take(3).toList());
    expect(sig.temporada, 2);
    expect(sig.fase, FaseUniv.regular);
    expect(sig.jornada, 0);
    expect(sig.plantel.length, inInclusiveRange(EstadoUniv.plantelMin, EstadoUniv.plantelMax));
    expect(sig.plantel.where((x) => x.anio == 1).length, greaterThanOrEqualTo(3));
    expect(sig.plantel.map((x) => x.id).toSet().length, sig.plantel.length);
    expect(sig.egresados.length, seVan.length);
    expect(sig.historial.single.picks.length, seVan.length);
    expect(sig.torneo, isEmpty);
    // Una segunda temporada se puede jugar.
    final dos = sim.simularJornadas(sig, 30);
    expect(dos.fase, FaseUniv.torneo);
  });

  test('egresado creado se lleva a Mi carrera con sus tres mejores atributos', () {
    final e = nueva();
    final x = e.plantel.first;
    final g = Egresado(
      nombre: x.nombre,
      posicion: x.posicion,
      rol: x.rol,
      atributos: x.atributos,
      alturaCm: x.alturaCm,
      pesoKg: x.pesoKg,
      temporada: 1,
      anios: 4,
      media: x.media,
      pick: 12,
      creado: true,
    );
    final c = g.comoCreado;
    expect(c.error, isNull);
    expect(c.fuertes.toSet().length, 3);
    expect(g.destino, 'Pick 12');
    expect(Egresado.fromJson(g.toJson()).comoCreado.nombre, g.nombre);
  });

  test('JSON de ida y vuelta de toda la partida, y en datosModo de la Temporada', () {
    var e = sim.simularTorneo(sim.simularJornadas(nueva(), 30));
    e = sim.cerrarTemporada(e);
    final t = Temporada(
      id: 'u1',
      franquiciaUsuarioId: 'CHI',
      modoJuego: ModoJuego.universitario,
      datosModo: e.aDatos(),
    );
    final copia = Temporada.fromJson(t.toJson());
    final r = EstadoUniv.de(copia)!;
    expect(r.toJson().toString(), e.toJson().toString());
    expect(r.plantel.length, e.plantel.length);
    expect(r.fase, FaseUniv.receso);
    expect(r.torneo.length, 4);
    expect(EstadoUniv.de(const Temporada(id: 'x', franquiciaUsuarioId: 'CHI')), isNull);
  });

  test('metajuego: XP por victorias y logro por el título; sin tocar el álbum', () {
    final e0 = nueva();
    final antes = Temporada(
      id: 'u1',
      franquiciaUsuarioId: 'CHI',
      modoJuego: ModoJuego.universitario,
      datosModo: e0.aDatos(),
    );
    final e1 = sim.simularJornadas(e0, 6);
    final despues = antes.copyWith(datosModo: e1.aDatos());
    final (p, nov) = premiarUniversitario(PerfilEntrenador(), antes, despues);
    final v = e1.registros()[0].v;
    expect(p.xp, v * 15);
    expect(p.coleccion, isEmpty);
    if (v == 0) expect(nov, isEmpty);
    // Un título nuevo da el logro.
    var campeona = e1;
    for (var s = 0; s < 40; s++) {
      var x = sim.simularTorneo(sim.simularJornadas(nueva(300 + s), 30));
      if (x.campeon == 0) {
        campeona = x;
        break;
      }
    }
    if (campeona.campeon == 0) {
      final a = Temporada(
        id: 'u2',
        franquiciaUsuarioId: 'CHI',
        modoJuego: ModoJuego.universitario,
        datosModo: campeona.aDatos(),
      );
      final cerrada = a.copyWith(datosModo: sim.cerrarTemporada(campeona).aDatos());
      final (q, n) = premiarUniversitario(PerfilEntrenador(), a, cerrada);
      expect(q.logros, contains(Logro.campeonNacional));
      expect(n.any((x) => x.destacada), isTrue);
    }
  });

  // --- Pantallas ---
  Temporada tem(EstadoUniv e) =>
      Temporada(id: 'u', franquiciaUsuarioId: 'DAL', modoJuego: ModoJuego.universitario, datosModo: e.aDatos());
  ContextoModos contexto(List<Temporada> guardadas) => ContextoModos(
    liga: () async => throw UnimplementedError(),
    db: null,
    navegador: GlobalKey<NavigatorState>(),
    guardar: (t) async => guardadas.add(t),
    abrirTemporada: (t, {reemplazar = false}) async {},
  );
  void telefono(WidgetTester t) {
    t.view.physicalSize = const Size(412, 1000) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  testWidgets('pantalla: simular una jornada actualiza el récord y guarda; las pestañas cambian', (t) async {
    telefono(t);
    final guardadas = <Temporada>[];
    await t.pumpWidget(
      MaterialApp(
        home: UniversitarioPantalla(temporada: tem(nueva()), contexto: contexto(guardadas)),
      ),
    );
    expect(find.text('JORNADA 1 DE 30'), findsOneWidget);
    await t.tap(find.text('PARTIDO'));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('JORNADA 2 DE 30'), findsOneWidget);
    expect(guardadas, isNotEmpty);
    expect(EstadoUniv.de(guardadas.last)!.jornada, 1);
    await t.tap(find.text('Top 25'));
    await t.pump();
    expect(find.textContaining('TOP 25'), findsOneWidget);
    await t.tap(find.text('Plantel'));
    await t.pump();
    expect(find.text('Ana Pérez'), findsOneWidget);
  });

  testWidgets('pantalla: temporada completa → torneo → premios → receso → temporada siguiente', (t) async {
    telefono(t);
    final guardadas = <Temporada>[];
    final fin = sim.simularJornadas(nueva(), 30);
    await t.pumpWidget(
      MaterialApp(
        home: UniversitarioPantalla(temporada: tem(fin), contexto: contexto(guardadas)),
      ),
    );
    expect(find.textContaining('TORNEO NACIONAL'), findsOneWidget);
    await t.ensureVisible(find.text('SIMULAR TORNEO'));
    await t.tap(find.text('SIMULAR TORNEO'));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('FIN DE LA TEMPORADA 1'), findsOneWidget);
    await t.ensureVisible(find.text('SEGUIR AL RECESO'));
    await t.tap(find.text('SEGUIR AL RECESO'));
    await t.pump();
    expect(find.text('ABRIR EL RECESO', skipOffstage: false), findsOneWidget);
    expect(EstadoUniv.de(guardadas.last)!.fase, FaseUniv.receso);
  });

  testWidgets('receso: declarar a un jugador, fichar reclutas y arrancar la temporada siguiente', (t) async {
    telefono(t);
    final receso = sim.cerrarTemporada(sim.simularTorneo(sim.simularJornadas(nueva(), 30)));
    Set<String>? declarados;
    List<Recluta>? firmados;
    await t.pumpWidget(
      MaterialApp(
        home: RecesoUnivPantalla(
          estado: receso,
          onTerminar: (d, f) {
            declarados = d;
            firmados = f;
          },
        ),
      ),
    );
    expect(find.text('EL DRAFT'), findsOneWidget);
    await t.tap(find.text('Reclutas'));
    await t.pumpAndSettle();
    final fichar = find.textContaining('FICHAR ·');
    expect(fichar, findsWidgets);
    await t.tap(fichar.last);
    await t.pump();
    expect(find.text('FIRMADO ✓'), findsOneWidget);
    await t.tap(find.text('ARRANCAR LA TEMPORADA 2'));
    expect(firmados!.length, 1);
    expect(declarados, isEmpty);
  });

  testWidgets('programa: sin nombre no deja seguir; con nombre y mote devuelve el Programa', (t) async {
    telefono(t);
    Programa? resultado;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await Navigator.of(c)
                    .push(MaterialPageRoute<Programa>(builder: (_) => const ProgramaConfigPantalla()));
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    final boton = find.widgetWithText(FilledButton, 'SEGUIR: CREAR TUS JUGADORES');
    expect(t.widget<FilledButton>(boton).onPressed, isNull);
    await t.enterText(find.byType(TextField).first, 'Lago Azul');
    await t.enterText(find.byType(TextField).last, 'Cóndores');
    await t.pump();
    expect(t.widget<FilledButton>(boton).onPressed, isNotNull);
    await t.tap(boton);
    await t.pumpAndSettle();
    expect(resultado?.nombre, 'Lago Azul');
    expect(resultado?.mote, 'Cóndores');
  });

  test('un programa con vida: hay últimos años desde la primera temporada y el draft los lleva', () {
    var e = nueva();
    final seniors = e.plantel.where((x) => x.anio >= 4).length;
    expect(seniors, greaterThanOrEqualTo(2));
    e = sim.cerrarTemporada(sim.simularTorneo(sim.simularJornadas(e, 30)));
    final sig = sim.cerrarReceso(e, declarados: {}, firmados: const []);
    expect(sig.egresados.length, seniors);
    expect(sig.egresados.every((g) => g.anios == 4), isTrue);
    expect(sig.historial.single.picks.length, seniors);
  });
}
