import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Variantes de la temporada clásica: cambia cómo se arma el plantel o las reglas, no el formato.
bool esModoVariante(ModoJuego m) => const {
  ModoJuego.leyendaUnica,
  ModoJuego.extremo,
  ModoJuego.soloEntrenador,
  ModoJuego.espejo,
  ModoJuego.desafioDelDia,
}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarVariante(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaVariante(Temporada t, ContextoModos c) async => null;
