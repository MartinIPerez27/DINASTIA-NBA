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
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE temporadas (
            id TEXT PRIMARY KEY,
            datos TEXT NOT NULL,
            actualizada INTEGER NOT NULL
          )''');
        await db.execute(_tablaClaves);
      },
      // v2: perfil del entrenador y ajustes (documentos JSON por clave).
      onUpgrade: (db, viejo, _) async {
        if (viejo < 2) await db.execute(_tablaClaves);
      },
    );
    return DbLocal._(db);
  }

  static const _tablaClaves = 'CREATE TABLE claves (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)';

  Future<Map<String, dynamic>?> leer(String clave) async {
    final filas = await _db.query('claves', where: 'clave = ?', whereArgs: [clave]);
    return filas.isEmpty ? null : jsonDecode(filas.first['valor'] as String) as Map<String, dynamic>;
  }

  Future<void> escribir(String clave, Map<String, dynamic> valor) =>
      _db.insert('claves', {'clave': clave, 'valor': jsonEncode(valor)}, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Todas las partidas guardadas, la más reciente primero.
  Future<List<Temporada>> temporadas() async {
    final filas = await _db.query('temporadas', orderBy: 'actualizada DESC');
    return [for (final f in filas) ?_intentar(f)];
  }

  Temporada? _intentar(Map<String, Object?> fila) {
    try {
      return _decodificar(fila);
    } catch (_) {
      return null; // una partida dañada no tira abajo la lista
    }
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
