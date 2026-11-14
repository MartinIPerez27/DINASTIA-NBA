import 'package:flutter/material.dart';

import '../../domain/entities/temporada.dart';
import 'modos.dart';

Future<void> iniciarUniversitario(ContextoModos c) async {
  ScaffoldMessenger.of(c.context)
    ..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text('Muy pronto.')));
}

Future<Widget?> pantallaUniversitario(Temporada t, ContextoModos c) async => null;
