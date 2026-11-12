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
      final imagen = (datos['thumbnail'] as Map<String, dynamic>?)?['source'] as String?;
      if (datos['type'] == 'standard' && descripcion.contains('basketball') && imagen != null) return imagen;
    } catch (_) {
      // Sin artículo, sin red o sin foto: se prueba el siguiente título.
    }
  }
  return null;
});
