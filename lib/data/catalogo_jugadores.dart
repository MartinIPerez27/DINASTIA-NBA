import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/entities/jugador.dart';
import '../domain/version_catalogo.dart';
import '../domain/versiones.dart';

const rutaCatalogo = 'assets/database/nba_players.json';

Future<List<Jugador>>? _catalogo;

/// Catálogo de cartas empaquetado en la app (~13.000 cartas, una por tramo de temporadas): se lee y decodifica una sola vez,
/// fuera del hilo de la interfaz, y queda en memoria para toda la sesión.
Future<List<Jugador>> cargarCatalogo() => _catalogo ??= () async {
  final raw = await rootBundle.loadString(rutaCatalogo);
  versionCatalogo = versionDe(raw);
  final (catalogo, legado) = await compute(parsearCatalogoCompleto, raw);
  cartasLegado = legado;
  registrarVersiones(catalogo);
  return catalogo;
}();

/// Cartas de los sorteos (sin las `legado`).
List<Jugador> parsearCatalogo(String json) => parsearCatalogoCompleto(json).$1;

/// (cartas activas, cartas legado por id). Las legado son las que se conservan solo para que las
/// partidas guardadas con ids viejos sigan cargando.
(List<Jugador>, Map<String, Jugador>) parsearCatalogoCompleto(String json) {
  final activas = <Jugador>[];
  final legado = <String, Jugador>{};
  for (final j in jsonDecode(json) as List) {
    final carta = Jugador.fromJson(j as Map<String, dynamic>);
    if (carta.legado) {
      legado[carta.id] = carta;
    } else {
      activas.add(carta);
    }
  }
  return (List.unmodifiable(activas), Map.unmodifiable(legado));
}
