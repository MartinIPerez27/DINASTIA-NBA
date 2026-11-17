import 'package:dinastia_nba/domain/entities/ajustes.dart';
import 'package:dinastia_nba/domain/relato/relato.dart';
import 'package:dinastia_nba/presentation/partido/panel_relato.dart';
import 'package:dinastia_nba/presentation/partido/voz_relator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LineaRelato l(int i, [Personaje p = Personaje.relator]) => LineaRelato(p, 'línea $i', i, Situacion.doble);

void main() {
  group('voces', () {
    test('reparte dos voces en español distintas, el Comentarista rioplatense', () {
      final a = asignarVoces([
        {'name': 'en-us-x-tpf-local', 'locale': 'en-US'},
        {'name': 'es-us-x-sfb-local', 'locale': 'es-US'},
        {'name': 'es-ar-x-abc-local', 'locale': 'es_AR'},
        {'name': 'es-es-x-eed-network', 'locale': 'es-ES'},
      ]);
      expect(a.distintas, isTrue);
      expect(a.comentarista!.locale, 'es-AR');
      expect(a.relator!.name, 'es-us-x-sfb-local');
      expect(a.relator!.name, isNot(a.comentarista!.name));
    });

    test('las voces que piden internet quedan al final', () {
      final a = asignarVoces([
        {'name': 'es-es-x-network', 'locale': 'es-ES'},
        {'name': 'es-mx-x-local', 'locale': 'es-MX'},
      ]);
      expect(a.relator!.name, 'es-es-x-network');
      expect(a.comentarista!.name, 'es-mx-x-local');
    });

    test('con una sola voz, las dos la comparten y se diferencian por tono y velocidad', () {
      final a = asignarVoces([
        {'name': 'es-us-x-sfb-local', 'locale': 'es-US'},
      ]);
      expect(a.distintas, isFalse);
      final r = perfilDeVoz(Personaje.relator, distintas: false);
      final c = perfilDeVoz(Personaje.comentarista, distintas: false);
      expect(c.tono - r.tono, greaterThan(0.3));
      expect(c.velocidad, greaterThan(r.velocidad));
    });

    test('sin voces en español, o con datos raros, no explota', () {
      expect(asignarVoces([]).relator, isNull);
      expect(
        asignarVoces([
          {'name': 'x', 'locale': 'fr-FR'},
          'raro',
          null,
        ]).comentarista,
        isNull,
      );
    });

    test('con dos voces los perfiles también son distintos y la emoción acelera y agudiza', () {
      final r = perfilDeVoz(Personaje.relator, distintas: true);
      final c = perfilDeVoz(Personaje.comentarista, distintas: true);
      expect(c.tono, greaterThan(r.tono));
      final fuerte = perfilDeVoz(Personaje.relator, distintas: true, intensidad: 4);
      expect(fuerte.velocidad, greaterThan(r.velocidad));
      expect(fuerte.tono, greaterThan(r.tono));
    });
  });

  group('cola de voz', () {
    test('a x1 espera hasta 3 líneas; a x2 solo la última; a x4 solo las intensas', () {
      final x1 = ColaVoz();
      for (var i = 0; i < 6; i++) {
        x1.agregar(l(1), velocidad: 1, hablando: true);
      }
      expect(x1.pendientes.length, 3);
      final x2 = ColaVoz();
      for (var i = 0; i < 6; i++) {
        x2.agregar(l(1), velocidad: 2, hablando: true);
      }
      expect(x2.pendientes.length, 1);
      final x4 = ColaVoz();
      expect(x4.agregar(l(2), velocidad: 4, hablando: true), isFalse);
      expect(x4.agregar(l(3), velocidad: 4, hablando: true), isTrue);
      expect(x4.agregar(l(4), velocidad: 4, hablando: true), isTrue);
      expect(x4.pendientes.length, 1);
      expect(x4.pendientes.single.intensidad, 4);
    });

    test('la más intensa desplaza a la vieja floja, y una floja no desplaza a una intensa', () {
      final c = ColaVoz()
        ..agregar(l(1), hablando: true)
        ..agregar(l(2), hablando: true)
        ..agregar(l(3), hablando: true);
      expect(c.agregar(l(4), hablando: true), isTrue);
      expect(c.pendientes.map((x) => x.intensidad), [2, 3, 4]);
      expect(c.agregar(l(0), hablando: true), isFalse);
      expect(c.pendientes.length, 3);
    });

    test('se vacía al callar y entrega en orden', () {
      final c = ColaVoz()
        ..agregar(l(1), hablando: true)
        ..agregar(l(2), hablando: true);
      expect(c.siguiente()!.intensidad, 1);
      c.vaciar();
      expect(c.siguiente(), isNull);
    });
  });

  test('ajustes: modo del relato se guarda y las partidas viejas arrancan en relato completo', () {
    const a = Ajustes(modoRelato: ModoRelato.soloRelator, vozRelator: true);
    final b = Ajustes.fromJson(a.toJson());
    expect(b.modoRelato, ModoRelato.soloRelator);
    expect(b.vozRelator, isTrue);
    expect(Ajustes.fromJson(const {}).modoRelato, ModoRelato.completo);
    expect(Ajustes.fromJson(const {'modoRelato': 99}).modoRelato, ModoRelato.completo);
    expect(a.copyWith(modoRelato: ModoRelato.soloTexto).modoRelato, ModoRelato.soloTexto);
  });

  testWidgets('el panel muestra el nombre de cada personaje y no desborda en pantalla angosta', (t) async {
    t.view.physicalSize = const Size(320, 500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanelRelato(
            lineas: [
              LineaRelato(
                Personaje.comentarista,
                'Qué barbaridad, mirá cómo la colgó ese muchacho, ni la vieron pasar.',
                3,
                Situacion.volcada,
              ),
              LineaRelato(
                Personaje.relator,
                'Volcada contundente con el reloj de posesión en 9 segundos. 98-96.',
                3,
                Situacion.volcada,
              ),
              LineaRelato(Personaje.relator, 'Doble de media distancia.', 1, Situacion.doble),
            ],
          ),
        ),
      ),
    );
    expect(find.text('RELATOR'), findsNWidgets(2));
    expect(find.text('COMENTARISTA'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNWidgets(2));
    expect(find.byIcon(Icons.record_voice_over), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
