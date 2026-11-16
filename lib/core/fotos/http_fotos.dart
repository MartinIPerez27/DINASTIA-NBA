import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Identificación propia ante Wikimedia, la NBA y quien sirva una foto: nombre de la app y URL del
/// repositorio (sin datos personales). Las políticas de Wikimedia piden un User-Agent descriptivo.
const agenteUsuarioFotos = 'DinastiaNBA/1.0 (+https://github.com/MartinIPerez27/dinatia-nba)';

/// Respuesta mínima de un GET: lo único que necesita el gestor de fotos.
class RespuestaHttp {
  const RespuestaHttp(this.estado, this.cuerpo, [this.cabeceras = const {}]);

  final int estado;
  final Uint8List cuerpo;

  /// Nombres de cabecera en minúsculas.
  final Map<String, String> cabeceras;

  bool get ok => estado >= 200 && estado < 300;

  String get texto => utf8.decode(cuerpo, allowMalformed: true);

  dynamic get json => jsonDecode(texto);
}

/// Cliente HTTP inyectable: en la app es [ClienteHttpIo]; en los tests, uno simulado (sin red real).
abstract class ClienteHttp {
  Future<RespuestaHttp> get(Uri url, {Map<String, String> cabeceras, Duration espera});
}

/// Implementación sobre `dart:io` (sin dependencias nuevas), con tiempo máximo por pedido.
class ClienteHttpIo implements ClienteHttp {
  ClienteHttpIo() : _http = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  final HttpClient _http;

  @override
  Future<RespuestaHttp> get(
    Uri url, {
    Map<String, String> cabeceras = const {},
    Duration espera = const Duration(seconds: 25),
  }) async {
    Future<RespuestaHttp> pedir() async {
      final pedido = await _http.getUrl(url);
      pedido.headers.set(HttpHeaders.userAgentHeader, agenteUsuarioFotos);
      cabeceras.forEach(pedido.headers.set);
      final respuesta = await pedido.close();
      final partes = <int>[];
      await for (final trozo in respuesta) {
        partes.addAll(trozo);
        if (partes.length > _maximoBytes) throw const HttpException('Respuesta demasiado grande');
      }
      final cabs = <String, String>{};
      respuesta.headers.forEach((k, v) => cabs[k.toLowerCase()] = v.join(', '));
      return RespuestaHttp(respuesta.statusCode, Uint8List.fromList(partes), cabs);
    }

    return pedir().timeout(espera);
  }

  static const _maximoBytes = 20 * 1024 * 1024;
}
