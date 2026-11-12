import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/entities/jugador.dart';

const rutaCatalogo = 'assets/database/nba_players.json';

Future<List<Jugador>>? _catalogo;

/// Catálogo de cartas empaquetado en la app (~11.000 cartas): se lee y decodifica una sola vez,
/// fuera del hilo de la interfaz, y queda en memoria para toda la sesión.
Future<List<Jugador>> cargarCatalogo() => _catalogo ??= () async {
  final raw = await rootBundle.loadString(rutaCatalogo);
  return compute(parsearCatalogo, raw);
}();

List<Jugador> parsearCatalogo(String json) =>
    List.unmodifiable([for (final j in jsonDecode(json) as List) Jugador.fromJson(j as Map<String, dynamic>)]);
