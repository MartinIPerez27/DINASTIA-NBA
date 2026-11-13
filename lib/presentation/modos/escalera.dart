import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Modos de escalera: una sucesión de cruces (partido único o serie) contra rivales armados a medida.
bool esModoEscalera(ModoJuego m) => const {
  ModoJuego.racha,
  ModoJuego.caminoAlAnillo,
  ModoJuego.mejoresEquipos,
  ModoJuego.mundial,
  ModoJuego.escenario,
}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarEscalera(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaEscalera(Temporada t, ContextoModos c) async => null;
