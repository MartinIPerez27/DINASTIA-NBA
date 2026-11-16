import 'dart:io';

import 'package:dinastia_nba/core/fotos/limitador_hosts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas_fotos.dart';

void main() {
  test('dos pedidos al mismo host quedan separados por 3 s; hosts distintos no se esperan', () async {
    final reloj = RelojFalso();
    final lim = LimitadorHosts(ahora: () => reloj.ahora, dormir: reloj.dormir);
    await lim.esperarTurno('en.wikipedia.org'); // el primero sale ya
    expect(reloj.dormidas, isEmpty);
    await lim.esperarTurno('en.wikipedia.org');
    expect(reloj.dormidas.single, const Duration(seconds: 3));
    await lim.esperarTurno('upload.wikimedia.org'); // otro host: sin espera
    expect(reloj.dormidas.length, 1);
    await lim.esperarTurno('en.wikipedia.org');
    expect(reloj.dormidas.last, const Duration(seconds: 3));
  });

  test('turnos reservados a la vez no se pisan', () async {
    final reloj = RelojFalso();
    final lim = LimitadorHosts(ahora: () => reloj.ahora, dormir: reloj.dormir);
    final inicio = reloj.ahora;
    await Future.wait([for (var i = 0; i < 4; i++) lim.esperarTurno('h')]);
    // Las reservas son 0, 3, 6 y 9 s desde el inicio: el último sale a los 9 s, no antes.
    expect(reloj.ahora.difference(inicio), const Duration(seconds: 9));
  });

  test('el CDN de la NBA tiene su propio intervalo, el resto 3 s', () {
    final p = peticionesDe(ClienteFalso((_) => estado(404)));
    expect(PeticionesFotos.intervalosPorHost['cdn.nba.com'], lessThan(const Duration(seconds: 3)));
    expect(
      LimitadorHosts(intervalos: PeticionesFotos.intervalosPorHost).intervaloDe('en.wikipedia.org'),
      const Duration(seconds: 3),
    );
    expect(p.limitador.intervaloDe('x'), Duration.zero);
  });

  test('429 y 5xx: reintenta con backoff exponencial y devuelve la respuesta buena', () async {
    final reloj = RelojFalso();
    var n = 0;
    final cliente = ClienteFalso((_) => ++n == 1 ? estado(429) : (n == 2 ? estado(503) : jsonOk({'ok': true})));
    final r = await peticionesDe(cliente, reloj: reloj).pedir(Uri.parse('https://en.wikipedia.org/x'));
    expect(r.ok, isTrue);
    expect(cliente.pedidos.length, 3);
    // Backoff: 5 s tras el primer fallo (intento 0), 10 s tras el segundo.
    expect(reloj.dormidas.map((d) => d.inSeconds), [5, 10]);
  });

  test('respeta Retry-After (con tope) en el 429', () async {
    final reloj = RelojFalso();
    var n = 0;
    final cliente = ClienteFalso((_) => ++n == 1 ? estado(429, {'retry-after': '42'}) : jsonOk({}));
    await peticionesDe(cliente, reloj: reloj).pedir(Uri.parse('https://en.wikipedia.org/x'));
    expect(reloj.dormidas.single.inSeconds, 42);
    n = 0;
    final cliente2 = ClienteFalso((_) => ++n == 1 ? estado(429, {'retry-after': '99999'}) : jsonOk({}));
    final reloj2 = RelojFalso();
    await peticionesDe(cliente2, reloj: reloj2).pedir(Uri.parse('https://en.wikipedia.org/x'));
    expect(reloj2.dormidas.single, lessThanOrEqualTo(const Duration(minutes: 2)));
  });

  test('si se agotan los reintentos lanza FotoTransitoria (no es "sin foto")', () async {
    final cliente = ClienteFalso((_) => estado(500));
    await expectLater(
      peticionesDe(cliente, reintentos: 2).pedir(Uri.parse('https://en.wikipedia.org/x')),
      throwsA(isA<FotoTransitoria>()),
    );
    expect(cliente.pedidos.length, 3);
  });

  test('errores de red y tiempos agotados también se reintentan', () async {
    var n = 0;
    final cliente = ClienteFalso((_) {
      if (++n < 3) throw const SocketException('sin red');
      return jsonOk({'a': 1});
    });
    final r = await peticionesDe(cliente).pedir(Uri.parse('https://en.wikipedia.org/x'));
    expect(r.ok, isTrue);
    final caido = ClienteFalso((_) => throw const SocketException('sin red'));
    await expectLater(peticionesDe(caido).pedir(Uri.parse('https://x.org/')), throwsA(isA<FotoTransitoria>()));
  });

  test('el 404 es una respuesta válida: se devuelve sin reintentar', () async {
    final cliente = ClienteFalso((_) => estado(404));
    final r = await peticionesDe(cliente).pedir(Uri.parse('https://en.wikipedia.org/x'));
    expect(r.estado, 404);
    expect(cliente.pedidos.length, 1);
  });
}
