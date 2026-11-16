import 'dart:async';
import 'dart:math';

import 'http_fotos.dart';

/// Falla pasajera (sin red, tiempo agotado, 429, 5xx): no es un "no hay foto", se reintenta luego.
class FotoTransitoria implements Exception {
  const FotoTransitoria(this.motivo);

  final String motivo;

  @override
  String toString() => 'FotoTransitoria($motivo)';
}

/// Ritmo por host: reserva turnos para que dos pedidos al mismo host queden separados por al menos
/// su intervalo (3 s por defecto, como el `Crawl-delay` de los sitios que lo piden). Los hosts son
/// independientes entre sí. Reloj y espera inyectables para probarlo sin esperar de verdad.
class LimitadorHosts {
  LimitadorHosts({
    this.intervaloPorDefecto = const Duration(seconds: 3),
    this._intervalos = const {},
    DateTime Function()? ahora,
    Future<void> Function(Duration)? dormir,
  }) : _ahora = ahora ?? DateTime.now,
       _dormir = dormir ?? Future<void>.delayed;

  final Duration intervaloPorDefecto;
  final Map<String, Duration> _intervalos;
  final DateTime Function() _ahora;
  final Future<void> Function(Duration) _dormir;
  final _proximo = <String, DateTime>{};

  Duration intervaloDe(String host) => _intervalos[host] ?? intervaloPorDefecto;

  /// Espera hasta que le toque a [host] y deja reservado el turno siguiente.
  Future<void> esperarTurno(String host) async {
    final ahora = _ahora();
    final previsto = _proximo[host];
    final turno = previsto != null && previsto.isAfter(ahora) ? previsto : ahora;
    _proximo[host] = turno.add(intervaloDe(host));
    final falta = turno.difference(ahora);
    if (falta > Duration.zero) await _dormir(falta);
  }

  /// Retira a [host] durante [duracion] (backoff ante 429/5xx).
  void penalizar(String host, Duration duracion) {
    final hasta = _ahora().add(duracion);
    final actual = _proximo[host];
    if (actual == null || hasta.isAfter(actual)) _proximo[host] = hasta;
  }
}

/// GET con ritmo por host, tiempo máximo, reintentos y backoff exponencial (respeta `Retry-After`).
/// Devuelve cualquier respuesta que no sea 429/5xx (el 404 es una respuesta válida: "no existe").
/// Si se agotan los reintentos lanza [FotoTransitoria].
class PeticionesFotos {
  PeticionesFotos({
    required this.cliente,
    LimitadorHosts? limitador,
    this.reintentos = 3,
    this.espera = const Duration(seconds: 25),
    this.baseBackoff = const Duration(seconds: 5),
    this.tope = const Duration(minutes: 2),
  }) : limitador = limitador ?? LimitadorHosts(intervalos: intervalosPorHost);

  final ClienteHttp cliente;
  final LimitadorHosts limitador;
  final int reintentos;
  final Duration espera;
  final Duration baseBackoff;
  final Duration tope;

  /// El CDN de la NBA sirve archivos estáticos (no es una API con límites): se pide más seguido para
  /// que las cartas de la mano se llenen rápido. Todo lo demás va a 3 s por host.
  static const intervalosPorHost = {'cdn.nba.com': Duration(milliseconds: 400)};

  Future<RespuestaHttp> pedir(Uri url, {Map<String, String> cabeceras = const {}}) async {
    String motivo = 'sin respuesta';
    for (var intento = 0; intento <= reintentos; intento++) {
      await limitador.esperarTurno(url.host);
      final retroceso = _retroceso(intento);
      try {
        final r = await cliente.get(url, cabeceras: cabeceras, espera: espera);
        if (r.estado != 429 && r.estado < 500) return r;
        motivo = 'HTTP ${r.estado}';
        limitador.penalizar(url.host, _segundosIndicados(r) ?? retroceso);
      } on FotoTransitoria {
        rethrow;
      } catch (e) {
        // SocketException, TimeoutException, HttpException, TLS…: se espera y se reintenta.
        motivo = e.runtimeType.toString();
        limitador.penalizar(url.host, retroceso);
      }
    }
    throw FotoTransitoria('${url.host}: $motivo');
  }

  Duration _retroceso(int intento) {
    final ms = baseBackoff.inMilliseconds * pow(2, intento).toInt();
    return Duration(milliseconds: min(ms, tope.inMilliseconds));
  }

  Duration? _segundosIndicados(RespuestaHttp r) {
    final s = int.tryParse(r.cabeceras['retry-after'] ?? '');
    if (s == null || s < 0) return null;
    return Duration(seconds: min(s, tope.inSeconds));
  }
}
