import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/historias.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/bitacora.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:dinastia_nba/domain/rivalidades.dart';
import 'package:dinastia_nba/domain/scouting.dart';
import 'package:dinastia_nba/domain/tension.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/ficha_rival.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:dinastia_nba/presentation/widgets/titulares.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => JugadorAvatar.usarRed = false);
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  var p = const Plantel();
  for (final pos in Posicion.values) {
    p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final rivales = catalogo.where((j) => j.franquiciaId == 'LAL').toList()..sort((a, b) => b.media.compareTo(a.media));
  final rivalJs = rivales.take(6).toList();

  RivalEscalera rival() => RivalEscalera(
    identidadId: 'LAL',
    etiqueta: '(Histórico)',
    cartaIds: {for (final (i, j) in rivalJs.indexed) Posicion.values[i]: j.id},
    tactica: const Tactica(),
    media: 88,
  );

  Cruce unico(bool gana, int a, int b) => Cruce(
    rival: rival(),
    titulo: 'Escalón 1 de 10',
    marcadores: [(a, b)],
    propias: gana ? 1 : 0,
    ajenas: gana ? 0 : 1,
  );

  Widget app(Widget hijo, {Size tam = const Size(412, 1500)}) => MaterialApp(
    theme: temaFranquicia(franquiciaPorId('CHI')),
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [hijo]),
    ),
  );

  void pantalla(WidgetTester t, Size s) {
    t.view.physicalSize = s * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  group('dominio de scouting y bitácora', () {
    test('FichaScouting: figuras ordenadas, amenaza según la diferencia de media', () {
      final f = FichaScouting.de(rivalJs, propios: p.jugadores.toList());
      expect(f.figuras, hasLength(3));
      expect(f.figuras.first.media >= f.figuras.last.media, isTrue);
      expect(f.fuerte, isNot(f.debil));
      final debil = FichaScouting.de(js.reversed.take(6).toList(), propios: rivalJs);
      expect(debil.amenaza, Amenaza.baja);
      expect(FichaScouting.de(const []).figuras, isEmpty);
    });

    test('EventoCruce: determinista, a veces nulo, siempre con efecto visible', () {
      final f = rivalJs.first;
      final a = [for (var i = 0; i < 60; i++) EventoCruce.de('x', i, figura: f, rival: 'Lakers')];
      final b = [for (var i = 0; i < 60; i++) EventoCruce.de('x', i, figura: f, rival: 'Lakers')];
      expect([for (final e in a) e?.tipo], [for (final e in b) e?.tipo]);
      final con = a.whereType<EventoCruce>().toList();
      expect(con, isNotEmpty);
      expect(con.length, lessThan(40));
      expect({for (final e in con) e.tipo}.length, greaterThan(2));
      for (final e in con) {
        expect(e.efecto, isNotEmpty);
        expect(e.rivalMenos.abs() <= 2 && e.propioMas <= 1, isTrue);
      }
    });

    test('Bitácora: un renglón por cruce, hitos y cierre', () {
      final cruces = [for (var i = 0; i < 5; i++) unico(true, 100 + i, 90)];
      final e = Escalera(cruces: [...cruces, unico(false, 90, 91)]);
      final b = Bitacora.de(e, (r) => r.etiqueta);
      expect(b.where((x) => x.hito).length, 2);
      expect(b.last.victoria, isFalse);
      expect(b.last.detalle, contains('por poco'));
      final cierre = Bitacora.cierre(e, (r) => r.etiqueta, mejorRachaPrevia: 8);
      expect(cierre.any((l) => l.contains('Mejor noche')), isTrue);
      expect(cierre.any((l) => l.contains('Te faltaron')), isTrue);
      expect(Bitacora.nivelRacha(0), 'Calentando');
      expect(Bitacora.nivelRacha(20), 'Leyenda viva');
    });

    test('presionDeCruce: la racha en juego sube la tensión', () {
      final c = unico(true, 100, 90);
      Escalera conRacha(int n) => Escalera(
        cruces: [
          for (var i = 0; i < n; i++) c,
          Cruce(rival: rival(), titulo: 't'),
        ],
      );
      final p3 = Bitacora.presionDeCruce(ModoJuego.racha, conRacha(3), conRacha(3).cruces.last);
      final p10 = Bitacora.presionDeCruce(ModoJuego.racha, conRacha(10), conRacha(10).cruces.last, mejorRacha: 12);
      expect(p10.valor, greaterThan(p3.valor));
      expect(p10.detalle, contains('récord'));
      expect(p3.etiqueta, 'RACHA DE 3 EN JUEGO');
      final fin = Escalera(
        total: 10,
        cruces: [for (var i = 0; i < 10; i++) Cruce(rival: rival(), titulo: 't')],
      );
      expect(Bitacora.presionDeCruce(ModoJuego.caminoAlAnillo, fin, fin.cruces.last).etiqueta, 'ÚLTIMO ESCALÓN');
    });
  });

  for (final (nombre, tam) in [('teléfono', const Size(412, 1500)), ('tablet', const Size(1280, 1500))]) {
    group('widgets en $nombre', () {
      testWidgets('FichaRival jefe con rivalidad y evento, banner y bitácora sin desbordes', (t) async {
        pantalla(t, tam);
        final ficha = FichaScouting.de(rivalJs, propios: p.jugadores.toList());
        final relato = const RelatoRivalidad(
          nivel: NivelRivalidad.malaSangre,
          calor: 62,
          frase: 'Los Lakers te sacaron en 6 el año pasado. Hay cuenta pendiente.',
          fichas: ['1 eliminación', '2 series cerradas', '3 partidos picantes', 'Duelos: 4-9'],
        );
        final e = Escalera(
          cruces: [
            for (var i = 0; i < 6; i++) unico(i != 4, 110, 100 + i),
            Cruce(rival: rival(), titulo: 'x'),
          ],
        );
        await t.pumpWidget(
          app(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BannerTension(presion: presion(aGanar: 4, propias: 3, ajenas: 3, peso: 10)),
                const SizedBox(height: 8),
                BannerTension(presion: presion(aGanar: 4, propias: 2, ajenas: 0), compacto: true),
                const SizedBox(height: 8),
                FichaRival(
                  identidad: franquiciaPorId('LAL'),
                  nombre: 'Los Angeles Lakers (Histórico) con un nombre bastante largo para probar',
                  scouting: ficha,
                  tactica: const Tactica(),
                  jefe: true,
                  introJefe: 'La última puerta: el campeón que quiere cerrarte el camino al anillo.',
                  rivalidad: relato,
                  evento:
                      EventoCruce.de('x', 0, figura: rivalJs.first, rival: 'Lakers') ??
                      const EventoCruce(
                        tipo: TipoEventoCruce.hinchadaEncendida,
                        titulo: 'HINCHADA ENCENDIDA',
                        texto: 'La gente se hizo sentir.',
                        efecto: 'Tu plantel +1 de forma',
                        propioMas: 1,
                      ),
                  historial: 'Corrida: 5-1',
                ),
                const SizedBox(height: 8),
                BitacoraCorrida(entradas: Bitacora.de(e, (r) => r.etiqueta)),
              ],
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('RIVAL JEFE'), findsOneWidget);
        expect(find.text('PARTIDO 7'), findsOneWidget);
        expect(find.textContaining('RIVALIDAD · MALA SANGRE'), findsOneWidget);
        expect(find.text('BITÁCORA DE LA CORRIDA'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('historias: tarjeta principal, reacción, ver todas y tras el partido', (t) async {
        pantalla(t, tam);
        var tt = liga.iniciar(Temporada(id: 'w', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
        for (var i = 0; i < 25; i++) {
          tt = liga.simularProximo(tt);
        }
        final hist = Historias.generar(
          tt,
          liga,
          nombre: (id) => franquiciaPorId(id == 'CHI' ? id : tt.rivales[id]!.identidadId).nombre,
        );
        expect(hist, isNotEmpty);
        await t.pumpWidget(
          app(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrasElPartido(historias: hist.take(3).toList(), resumen: 'Ganaste 110-100. Quedás 12-1.'),
                const SizedBox(height: 8),
                for (final h in hist.take(4)) ...[
                  TarjetaHistoria(historia: h, principal: h == hist.first),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('TRAS EL PARTIDO'), findsOneWidget);
        expect(find.byType(TarjetaHistoria), findsNWidgets(hist.take(4).length));
        expect(t.takeException(), isNull);
      });
    });
  }
}
