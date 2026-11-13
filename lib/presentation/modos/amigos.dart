import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Modos para jugar con amigos pasándose el dispositivo.
bool esModoAmigos(ModoJuego m) => const {ModoJuego.draftEnGrupo, ModoJuego.duelo}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarAmigos(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaAmigos(Temporada t, ContextoModos c) async => null;
