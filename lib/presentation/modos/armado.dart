import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Modos de armado: tope salarial, desafíos con el álbum, liga contra la IA y el minijuego de adivinar.
bool esModoArmado(ModoJuego m) =>
    const {ModoJuego.topeSalarial, ModoJuego.desafiosArmado, ModoJuego.ligaIA, ModoJuego.adivina}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarArmado(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaArmado(Temporada t, ContextoModos c) async => null;
