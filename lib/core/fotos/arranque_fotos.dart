import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/db_local.dart';
import '../recorte_fotos.dart';
import 'gestor_fotos.dart';
import 'http_fotos.dart';
import 'indice_fotos.dart';
import 'limitador_hosts.dart';

/// Crea el gestor de fotos de la app (índice en la base local, archivos en la carpeta de soporte).
/// Si algo falla, la app sigue sin gestor: las cartas muestran el avatar ilustrado.
Future<void> iniciarGestorFotos(DbLocal db) async {
  try {
    final carpeta = Directory('${(await getApplicationSupportDirectory()).path}/fotos_v1');
    final gestor = GestorFotos(
      indice: IndiceFotos(db.baseDatos),
      carpeta: carpeta,
      peticiones: PeticionesFotos(cliente: ClienteHttpIo()),
      recortador: recortarFotoDeArchivo,
    );
    await gestor.cargar();
    GestorFotos.instancia = gestor;
  } catch (e) {
    debugPrint('Gestor de fotos no disponible: $e');
  }
}
