import 'dart:convert';

/// Versión del catálogo de cartas cargado: un hash FNV-1a de 32 bits del JSON tal cual viene en la
/// app. Cambia sola cuando se regenera el catálogo (medias, roles, cartas nuevas), así los códigos
/// de reto y el Desafío del día saben si se armaron con las mismas cartas. 0 = desconocida (pruebas).
int versionCatalogo = 0;

int versionDe(String json) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(json)) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}
