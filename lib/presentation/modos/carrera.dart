import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Modos de carrera: varias temporadas seguidas con el mismo club.
bool esModoCarrera(ModoJuego m) => const {ModoJuego.dinastia, ModoJuego.reescribi}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarCarrera(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaCarrera(Temporada t, ContextoModos c) async => null;
