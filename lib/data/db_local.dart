import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/entities/temporada.dart';

/// Partidas guardadas en SQLite local. Cada temporada se guarda como un documento JSON:
/// se lee y escribe entera, así que no hace falta normalizar tablas.
class DbLocal {
  DbLocal._(this._db);

  final Database _db;

  static Future<DbLocal> abrir() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'dinastia_nba.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE temporadas (
          id TEXT PRIMARY KEY,
          datos TEXT NOT NULL,
          actualizada INTEGER NOT NULL
        )'''),
    );
    return DbLocal._(db);
  }

  Future<void> guardarTemporada(Temporada t) => _db.insert('temporadas', {
    'id': t.id,
    'datos': jsonEncode(t.toJson()),
    'actualizada': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Temporada?> cargarTemporada(String id) async {
    final filas = await _db.query('temporadas', where: 'id = ?', whereArgs: [id]);
    return filas.isEmpty ? null : _decodificar(filas.first);
  }

  /// Para el botón "Continuar" de la pantalla de inicio.
  Future<Temporada?> ultimaTemporada() async {
    final filas = await _db.query('temporadas', orderBy: 'actualizada DESC', limit: 1);
    return filas.isEmpty ? null : _decodificar(filas.first);
  }

  Future<void> borrarTemporada(String id) => _db.delete('temporadas', where: 'id = ?', whereArgs: [id]);

  Temporada _decodificar(Map<String, Object?> fila) =>
      Temporada.fromJson(jsonDecode(fila['datos'] as String) as Map<String, dynamic>);
}
