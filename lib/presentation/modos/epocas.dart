import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Torneos por época, clase de draft y universidad.
bool esModoEpocas(ModoJuego m) => const {ModoJuego.guantelete, ModoJuego.camadas, ModoJuego.universidades}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarEpocas(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaEpocas(Temporada t, ContextoModos c) async => null;
