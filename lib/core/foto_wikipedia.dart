import 'dart:convert';

import 'cache_imagenes.dart';

final _resueltas = <String, Future<String?>>{};

/// URL de la foto principal del artículo de Wikipedia de un jugador, o null si no hay.
/// Se busca desde el celular (Wikipedia limita a los servidores en la nube) y la respuesta queda
/// en el caché de disco, así que después funciona sin internet.
Future<String?> fotoWikipedia(String nombre) => _resueltas.putIfAbsent(nombre, () async {
  for (final titulo in ['$nombre (basketball)', nombre]) {
    try {
      final url =
          'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(titulo.replaceAll(' ', '_'))}';
      final archivo = await cacheHeadshots.getSingleFile(
        url,
        headers: {'User-Agent': 'DinastiaNBA/0.1 (app personal)'},
      );
      final datos = jsonDecode(await archivo.readAsString()) as Map<String, dynamic>;
      final descripcion = (datos['description'] as String? ?? '').toLowerCase();
      final imagen = fotoGrande(
        datos['thumbnail'] as Map<String, dynamic>?,
        datos['originalimage'] as Map<String, dynamic>?,
      );
      if (datos['type'] == 'standard' && descripcion.contains('basketball') && imagen != null) return imagen;
    } catch (_) {
      // Sin artículo, sin red o sin foto: se prueba el siguiente título.
    }
  }
  return null;
});

/// Ancho pedido a Wikimedia: alcanza para las cartas grandes de la tablet (≈ 200 px lógicos a
/// densidad 2) y es uno de sus tamaños estándar de miniatura.
const anchoFotoWikipedia = 960;

/// La foto en buena resolución: la miniatura de 320 px de la API se ve blanda en pantallas grandes.
/// Si el original es chico se usa tal cual; si no, la miniatura de [anchoFotoWikipedia] px.
String? fotoGrande(Map<String, dynamic>? miniatura, Map<String, dynamic>? original) {
  final chica = miniatura?['source'] as String?;
  final fuente = original?['source'] as String?;
  final ancho = original?['width'] as int?;
  if (fuente != null && ancho != null && ancho <= anchoFotoWikipedia) return fuente;
  if (chica == null) return fuente;
  final grande = chica.replaceFirst(RegExp(r'/\d+px-'), '/${anchoFotoWikipedia}px-');
  return grande;
}
