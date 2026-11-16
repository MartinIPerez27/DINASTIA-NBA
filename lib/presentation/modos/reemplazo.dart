import 'package:flutter/material.dart';

import '../../domain/entities/temporada.dart';
import 'modos.dart';

/// Pasa de la temporada [vieja] a la [nueva] (receso de Dinastía y de Mi carrera) sin riesgo de
/// quedarse sin ninguna: primero se guarda la nueva y se comprueba que quedó en la base; recién
/// después se borra la vieja. Devuelve la temporada nueva ya guardada, o null si falló (la vieja
/// sigue ahí). Si la vieja era una partida importada (de exhibición), la nueva también lo es.
Future<Temporada?> reemplazarTemporada(ContextoModos c, Temporada vieja, Temporada nueva) async {
  if (vieja.importada && !nueva.importada) nueva = nueva.copyWith(importada: true, origenId: vieja.origenId);
  await c.guardar(nueva);
  final db = c.db;
  if (db != null) {
    try {
      if (await db.cargarTemporada(nueva.id) == null) return _fallo(c);
    } catch (_) {
      return _fallo(c);
    }
    try {
      // La temporada terminada ya está en la historia (el perfil la cerró): la nueva la reemplaza.
      if (vieja.id != nueva.id) await db.borrarTemporada(vieja.id);
    } catch (_) {} // si no se pudo borrar, sobra una partida vieja; no se pierde nada
  }
  return nueva;
}

Temporada? _fallo(ContextoModos c) {
  final contexto = c.navegador.currentContext;
  if (contexto != null) {
    ScaffoldMessenger.maybeOf(contexto)
      ?..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la temporada nueva. Se conserva la anterior: probá de nuevo.'),
        ),
      );
  }
  return null;
}
