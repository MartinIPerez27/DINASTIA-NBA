import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dinastia_nba/core/fotos/http_fotos.dart';
import 'package:dinastia_nba/core/fotos/limitador_hosts.dart';

/// Cliente HTTP simulado: sin red real. [responder] decide la respuesta por URL.
class ClienteFalso implements ClienteHttp {
  ClienteFalso(this.responder);

  final FutureOr<RespuestaHttp> Function(Uri url) responder;
  final pedidos = <Uri>[];

  @override
  Future<RespuestaHttp> get(Uri url, {Map<String, String> cabeceras = const {}, Duration? espera}) async {
    pedidos.add(url);
    return responder(url);
  }

  int pedidosA(String host) => pedidos.where((u) => u.host == host).length;
}

RespuestaHttp jsonOk(Object cuerpo) => RespuestaHttp(200, Uint8List.fromList(utf8.encode(jsonEncode(cuerpo))));

RespuestaHttp estado(int codigo, [Map<String, String> cabeceras = const {}]) =>
    RespuestaHttp(codigo, Uint8List(0), cabeceras);

/// Bytes con firma de PNG y tamaño suficiente para pasar por imagen.
RespuestaHttp pngFalso([int tam = 1200]) {
  final b = Uint8List(tam);
  b.setRange(0, 8, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return RespuestaHttp(200, b);
}

/// Peticiones sin esperas reales: el limitador usa un reloj falso que avanza al "dormir".
class RelojFalso {
  DateTime ahora = DateTime(2026, 1, 1);
  final dormidas = <Duration>[];

  Future<void> dormir(Duration d) async {
    dormidas.add(d);
    ahora = ahora.add(d);
  }
}

PeticionesFotos peticionesDe(
  ClienteFalso cliente, {
  RelojFalso? reloj,
  Duration intervalo = Duration.zero,
  int reintentos = 2,
}) {
  final r = reloj ?? RelojFalso();
  return PeticionesFotos(
    cliente: cliente,
    limitador: LimitadorHosts(intervaloPorDefecto: intervalo, ahora: () => r.ahora, dormir: r.dormir),
    reintentos: reintentos,
    baseBackoff: const Duration(seconds: 5),
  );
}

Directory carpetaTemporal() => Directory.systemTemp.createTempSync('fotos_test_');
