import 'dart:convert';

import 'entities/jugador.dart';

/// Versión del catálogo de cartas cargado: un hash FNV-1a de 32 bits del JSON tal cual viene en la
/// app. Cambia sola cuando se regenera el catálogo (medias, roles, cartas nuevas), así los códigos
/// de reto y el Desafío del día saben si se armaron con las mismas cartas. 0 = desconocida (pruebas).
int versionCatalogo = 0;

/// Versión de la REGLA de tiradas. Se mezcla en [versionDe] para que un código de reto o el Desafío del día
/// armado con una regla distinta se detecte como "otro catálogo" en vez de dar una tirada distinta sin aviso.
/// 2 = una sola carta por persona por tirada (la lista de candidatos y el sorteo dejaron de contar las
/// versiones repetidas de una misma persona); 1 = antes. Subirla si vuelve a cambiar cómo se arman las tiradas.
const reglaDeTirada = 2;

int versionDe(String json) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(json)) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h ^ reglaDeTirada;
}

/// Cartas `legado` del catálogo (las del catálogo anterior que no se pueden recalcular). No salen en los
/// sorteos, pero una partida o un álbum viejo que las guardó las sigue encontrando por id.
Map<String, Jugador> cartasLegado = const {};
