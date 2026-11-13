import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/amigos.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/presentation/modos/amigos.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/carta_jugador.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final amigos = Amigos(catalogo, azar: Random(3));

  /// Cada uno ficha la primera carta del turno en su primer puesto libre.
  PartidaAmigos draftCompleto(PartidaAmigos p) {
    while (p.fase == FaseAmigos.draft) {
      final yo = p.participantes[p.eligeAhora];
      final j = amigos.candidatos(p).first;
      p = amigos.elegir(amigos.verTurno(p), j, yo.plantel.posicionesDisponiblesPara(j).first);
    }
    return p;
  }

  PartidaAmigos conTacticas(PartidaAmigos p) {
    for (int? i = p.pendienteDeTactica; i != null; i = p.pendienteDeTactica) {
      p = amigos.confirmarTactica(p, i, amigos.recomendada(p, i));
    }
    return p;
  }

  test('draft por turnos en serpiente, sin personas repetidas y con cartas fijas por semilla', () {
    final personas = [('Martín', 'CHI'), ('Lucía', 'BOS'), ('Nico', 'LAL'), ('Sofi', 'MIA')];
    var p = amigos.nueva(duelo: false, personas: personas, semilla: 42);
    expect(p.candidatos, hasLength(PartidaAmigos.cartasPorTurno));
    expect(amigos.nueva(duelo: false, personas: personas, semilla: 42).candidatos, p.candidatos);
    // Serpiente: 0 1 2 3 3 2 1 0 0 1…
    expect([for (var k = 0; k < 9; k++) p.quienElige(k)], [0, 1, 2, 3, 3, 2, 1, 0, 0]);

    // Pedir otras cartas: una vez por persona.
    final otras = amigos.otrasCartas(p);
    expect(otras.candidatos, isNot(p.candidatos));
    expect(otras.participantes[0].sorteos, 0);
    expect(() => amigos.otrasCartas(otras), throwsStateError);

    p = draftCompleto(p);
    expect(p.fase, FaseAmigos.tacticas);
    expect(p.participantes.every((x) => x.plantel.completo), isTrue);
    final ids = [
      for (final x in p.participantes)
        for (final j in x.plantel.jugadores) j.nbaPlayerId,
    ];
    expect(ids.toSet(), hasLength(ids.length), reason: 'nadie repetido entre los planteles');
    expect(() => amigos.nueva(duelo: false, personas: [('A', 'CHI'), ('B', 'CHI')]), throwsArgumentError);
    expect(() => amigos.nueva(duelo: true, personas: personas), throwsArgumentError);
  });

  test('liga ida y vuelta, tabla y final al mejor de 3 entre los dos primeros', () {
    var p = conTacticas(
      draftCompleto(amigos.nueva(duelo: false, personas: [('A', 'CHI'), ('B', 'BOS'), ('C', 'LAL')], semilla: 7)),
    );
    expect(p.fase, FaseAmigos.liga);
    expect(p.liga, hasLength(3 * 2));
    for (var a = 0; a < 3; a++) {
      for (var b = 0; b < 3; b++) {
        if (a != b) expect(p.liga.where((x) => x.local == a && x.visitante == b), hasLength(1));
      }
    }
    p = amigos.simularFase(p);
    expect(p.fase, FaseAmigos.serie);
    final tabla = p.tabla();
    expect(tabla.fold(0, (s, f) => s + f.victorias), 6);
    for (var i = 0; i + 1 < tabla.length; i++) {
      expect(tabla[i].victorias, greaterThanOrEqualTo(tabla[i + 1].victorias));
    }
    expect((p.serie!.alto, p.serie!.bajo), (tabla[0].indice, tabla[1].indice));
    expect(p.serie!.victoriasParaGanar, 2);
    p = amigos.simularFase(p);
    expect(p.fase, FaseAmigos.terminada);
    expect({tabla[0].indice, tabla[1].indice}, contains(p.campeon));
  });

  test('duelo: al mejor de 7 con localía 2-2-1-1-1', () {
    var p = conTacticas(draftCompleto(amigos.nueva(duelo: true, personas: [('A', 'NYK'), ('B', 'DET')], semilla: 9)));
    expect(p.fase, FaseAmigos.serie);
    expect(p.liga, isEmpty);
    final s = p.serie!;
    final locales = <int>[];
    while (p.fase == FaseAmigos.serie) {
      locales.add(p.serie!.localProximo);
      p = amigos.simularProximo(p);
    }
    final esperado = [s.alto, s.alto, s.bajo, s.bajo, s.alto, s.bajo, s.alto];
    expect(locales, esperado.take(locales.length));
    expect(p.serie!.victoriasDe(p.campeon!), 4);
    expect(locales.length, inInclusiveRange(4, 7));
  });

  test('se guarda y se retoma (JSON) y no da premios de carrera, solo XP al terminar', () {
    var p = amigos.nueva(duelo: true, personas: [('A', 'NYK'), ('B', 'DET')], semilla: 1);
    p = amigos.verTurno(p);
    final t0 = Temporada(id: 'x', franquiciaUsuarioId: 'NYK', modoJuego: ModoJuego.duelo, datosModo: p.toJson());
    final copia = PartidaAmigos.de(Temporada.fromJson(t0.toJson()))!;
    expect(copia.candidatos, p.candidatos);
    expect(copia.turnoVisto, isTrue);
    expect(Temporada.fromJson(t0.toJson()).modoJuego, ModoJuego.duelo);

    p = conTacticas(draftCompleto(p));
    p = amigos.simularFase(p);
    final media = amigos.simularProximo(
      conTacticas(draftCompleto(amigos.nueva(duelo: true, personas: [('A', 'NYK'), ('B', 'DET')], semilla: 1))),
    );
    final t1 = t0.conAmigos(media), t2 = t0.conAmigos(p);
    final vuelta = PartidaAmigos.de(Temporada.fromJson(t2.toJson()))!;
    expect(vuelta.fase, FaseAmigos.terminada);
    expect(vuelta.campeon, p.campeon);
    expect(vuelta.serie!.juegos.length, p.serie!.juegos.length);
    for (final (i, x) in vuelta.participantes.indexed) {
      expect(
        [for (final pos in Posicion.values) x.plantel.en(pos)!.id],
        [for (final pos in Posicion.values) p.participantes[i].plantel.en(pos)!.id],
      );
    }

    final progreso = Progreso(Liga(catalogo, franquicias));
    const perfil = PerfilEntrenador();
    final (enCurso, n1) = progreso.aplicar(perfil, t0, t1);
    expect(enCurso.xp, 0);
    expect(n1, isEmpty);
    final (fin, n2) = progreso.aplicar(perfil, t1, t2);
    expect(fin.xp, Progreso.xpPartidaAmigos);
    expect(fin.trofeos, isEmpty);
    expect(fin.logros, isEmpty);
    expect(fin.coleccion, isEmpty, reason: 'las cartas de los amigos no van a tu álbum');
    expect(n2, hasLength(1));
    expect(progreso.aplicar(perfil, t2, t2).$1.xp, 0, reason: 'una sola vez');
  });

  testWidgets('pantalla: pasar el dispositivo, fichar y pasa el turno', (t) async {
    JugadorAvatar.usarRed = false;
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final p = amigos.nueva(duelo: false, personas: [('Martín', 'CHI'), ('Lucía', 'BOS')], semilla: 5);
    final guardadas = <Temporada>[];
    await t.pumpWidget(
      MaterialApp(
        theme: temaFranquicia(franquiciaPorId('CHI')),
        home: AmigosPantalla(
          temporada: Temporada(
            id: 'g',
            franquiciaUsuarioId: 'CHI',
            modoJuego: ModoJuego.draftEnGrupo,
            datosModo: p.toJson(),
          ),
          catalogo: catalogo,
          onGuardar: (x) async => guardadas.add(x),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Pasale el dispositivo.'), findsOneWidget);
    await t.tap(find.text('SOY MARTÍN, ESTOY LISTO'));
    await t.pump();
    expect(find.byType(CartaJugador), findsNWidgets(PartidaAmigos.cartasPorTurno));
    await t.tap(find.byType(CartaJugador).first);
    await t.pump();
    final fichar = find.textContaining('FICHAR A');
    await t.ensureVisible(fichar);
    await t.tap(fichar);
    await t.pump();
    expect(find.text('SOY LUCÍA, ESTOY LISTO'), findsOneWidget);
    final ultima = PartidaAmigos.de(guardadas.last)!;
    expect(ultima.turno, 1);
    expect(ultima.participantes[0].plantel.jugadores, hasLength(1));
  });

  testWidgets('configuración: cuántos son, nombres y franquicias distintas', (t) async {
    t.view.physicalSize = const Size(412, 915) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    List<(String, String)>? resultado;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => resultado = await Navigator.of(c).push(
              MaterialPageRoute(builder: (_) => ConfigAmigosPantalla(duelo: false, enfocada: franquiciaPorId('CHI'))),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('3'));
    await t.pump();
    await t.enterText(find.byType(TextField).first, 'Martín');
    await t.tap(find.text('EMPEZAR EL DRAFT'));
    await t.pumpAndSettle();
    expect(resultado, hasLength(3));
    expect(resultado!.first, ('Martín', 'CHI'));
    expect(resultado![1].$1, 'Jugador 2');
    expect(resultado!.map((x) => x.$2).toSet(), hasLength(3));
  });
}
