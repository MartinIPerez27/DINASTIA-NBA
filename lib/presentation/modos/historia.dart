import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Historia de la NBA: temporadas reales, historias alternativas y finales reales.
bool esModoHistoria(ModoJuego m) =>
    const {ModoJuego.temporadaReal, ModoJuego.queHubiera, ModoJuego.ultimoCuarto}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarHistoria(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaHistoria(Temporada t, ContextoModos c) async => null;
