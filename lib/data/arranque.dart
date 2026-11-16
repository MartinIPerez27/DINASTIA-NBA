import 'dart:convert';

import '../domain/entities/ajustes.dart';
import '../domain/entities/perfil.dart';
import '../domain/entities/temporada.dart';
import 'db_local.dart';

/// Lo que se pudo leer al arrancar, y lo que salió mal.
class ResultadoArranque {
  ResultadoArranque();

  Temporada? guardada;

  /// Null si no había perfil guardado o no se pudo leer (ver [perfilIlegible]).
  PerfilEntrenador? perfil;
  Ajustes? ajustes;

  /// El perfil existe pero no se pudo leer: la base queda protegida (no se escribe el perfil) y se
  /// guardó una copia en `perfil.bak` hasta que el usuario decida.
  var perfilIlegible = false;

  /// Avisos para mostrarle al usuario (partidas dañadas, ajustes ilegibles…).
  final avisos = <String>[];
}

/// Lee partida, ajustes y perfil de la base, cada uno por su lado: que uno falle no impide cargar
/// los otros, y JAMÁS se deja que un perfil que no se pudo leer sea pisado por uno vacío.
Future<ResultadoArranque> cargarArranque(DbLocal db) async {
  final r = ResultadoArranque();
  try {
    final (t, danadas) = await db.ultimaTemporadaLegible();
    r.guardada = t;
    if (danadas > 0) {
      r.avisos.add(
        danadas == 1
            ? 'Una partida guardada está dañada y no se pudo abrir. Las demás siguen ahí.'
            : '$danadas partidas guardadas están dañadas y no se pudieron abrir. Las demás siguen ahí.',
      );
    }
  } catch (_) {
    r.avisos.add('No se pudieron leer las partidas guardadas.');
  }
  try {
    if (await db.leer('ajustes') case final j?) r.ajustes = Ajustes.fromJson(j);
  } catch (_) {
    r.avisos.add('No se pudieron leer tus ajustes: se usan los de fábrica.');
  }
  String? crudo;
  try {
    crudo = await db.leerCrudo('perfil');
    if (crudo != null) r.perfil = PerfilEntrenador.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
  } catch (_) {
    r.perfil = null;
    r.perfilIlegible = true;
    if (crudo != null) await db.protegerPerfilIlegible(crudo);
    r.avisos.add('No se pudo leer tu perfil. No se guarda nada de tu progreso hasta que decidas qué hacer.');
  }
  return r;
}
