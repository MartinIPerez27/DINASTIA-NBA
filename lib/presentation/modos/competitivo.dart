import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Divisiones, creador de torneos y conquista.
bool esModoCompetitivo(ModoJuego m) =>
    const {ModoJuego.divisiones, ModoJuego.creadorTorneos, ModoJuego.conquista}.contains(m);

Future<void> iniciarCompetitivo(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('${m.nombre}: muy pronto.')));
}

Future<Widget?> pantallaCompetitivo(Temporada t, ContextoModos c) async => null;
