import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/entities/jugador.dart';

const rutaCatalogo = 'assets/database/nba_players.json';

/// Catálogo de cartas empaquetado en la app (solo lectura, ~600 cartas caben en memoria).
Future<List<Jugador>> cargarCatalogo([AssetBundle? bundle]) async {
  final raw = await (bundle ?? rootBundle).loadString(rutaCatalogo);
  return parsearCatalogo(raw);
}

List<Jugador> parsearCatalogo(String json) =>
    List.unmodifiable([for (final j in jsonDecode(json) as List) Jugador.fromJson(j as Map<String, dynamic>)]);
