import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/fotos/indice_fotos.dart';
import '../domain/entities/perfil.dart';
import '../domain/entities/temporada.dart';

/// Partidas guardadas en SQLite local. Cada temporada se guarda como un documento JSON:
/// se lee y escribe entera, así que no hace falta normalizar tablas.
class DbLocal {
  DbLocal._(this._db);

  /// Para pruebas: una base ya abierta (en memoria) con las tablas de [crearTablas].
  DbLocal.conBase(Database db) : _db = db;

  final Database _db;

  /// La base abierta, para módulos con tablas propias (índice de fotos).
  Database get baseDatos => _db;

  /// Solo para pruebas: la base cruda (insertar filas dañadas a propósito).
  @visibleForTesting
  Database get baseCruda => _db;

  /// Mientras sea true, el perfil NO se escribe: se llega acá cuando el perfil guardado existe pero no
  /// se pudo leer. Escribir uno vacío encima lo perdería para siempre; el usuario decide qué hacer
  /// (ver [empezarPerfilNuevo]).
  bool perfilProtegido = false;

  static const claveCopiaPerfil = 'perfil.bak';

  /// Crea las tablas de una base nueva.
  static Future<void> crearTablas(Database db, int _) async {
    await db.execute('''
      CREATE TABLE temporadas (
        id TEXT PRIMARY KEY,
        datos TEXT NOT NULL,
        actualizada INTEGER NOT NULL
      )''');
    await db.execute(_tablaClaves);
  }

  static Future<DbLocal> abrir() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'dinastia_nba.db'),
      version: 2,
      onCreate: crearTablas,
      // v2: perfil del entrenador y ajustes (documentos JSON por clave).
      onUpgrade: (db, viejo, _) async {
        if (viejo < 2) await db.execute(_tablaClaves);
      },
    );
    // Índice de fotos de jugadores (aditivo, IF NOT EXISTS: migra cualquier base vieja sin tocar `version`).
    await IndiceFotos.crearTabla(db);
    return DbLocal._(db);
  }

  static const _tablaClaves = 'CREATE TABLE claves (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)';

  Future<Map<String, dynamic>?> leer(String clave) async {
    final filas = await _db.query('claves', where: 'clave = ?', whereArgs: [clave]);
    return filas.isEmpty ? null : jsonDecode(filas.first['valor'] as String) as Map<String, dynamic>;
  }

  /// El texto guardado tal cual (sin interpretarlo), o null si no hay nada.
  Future<String?> leerCrudo(String clave) async {
    final filas = await _db.query('claves', where: 'clave = ?', whereArgs: [clave]);
    return filas.isEmpty ? null : filas.first['valor'] as String;
  }

  Future<void> escribir(String clave, Map<String, dynamic> valor) async {
    if (clave == 'perfil' && perfilProtegido) return; // ver [perfilProtegido]
    await _db.insert('claves', {
      'clave': clave,
      'valor': jsonEncode(valor),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Guarda una copia del perfil ilegible (texto crudo) y lo deja protegido contra escrituras.
  Future<void> protegerPerfilIlegible(String crudo) async {
    perfilProtegido = true;
    try {
      await _db.insert('claves', {
        'clave': claveCopiaPerfil,
        'valor': crudo,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  /// El usuario decidió empezar con un perfil nuevo: se levanta la protección y se escribe [perfil].
  Future<void> empezarPerfilNuevo(PerfilEntrenador perfil) async {
    perfilProtegido = false;
    await escribir('perfil', perfil.toJson());
  }

  /// Todas las partidas legibles, la más reciente primero.
  Future<List<Temporada>> temporadas() async => (await temporadasConDanadas()).$1;

  /// Las partidas legibles y cuántas filas no se pudieron leer (dañadas o de una versión futura).
  Future<(List<Temporada>, int)> temporadasConDanadas() async {
    final filas = await _db.query('temporadas', orderBy: 'actualizada DESC');
    final ok = <Temporada>[];
    var danadas = 0;
    for (final f in filas) {
      final t = _intentar(f);
      t == null ? danadas++ : ok.add(t);
    }
    return (ok, danadas);
  }

  /// Las filas tal cual están guardadas (id, texto JSON), la más reciente primero.
  Future<List<(String, String)>> temporadasCrudas() async {
    final filas = await _db.query('temporadas', columns: ['id', 'datos'], orderBy: 'actualizada DESC');
    return [for (final f in filas) (f['id'] as String, f['datos'] as String)];
  }

  Temporada? _intentar(Map<String, Object?> fila) {
    try {
      return _decodificar(fila);
    } catch (_) {
      return null; // una partida dañada no tira abajo la lista
    }
  }

  Future<void> guardarTemporada(Temporada t) =>
      _db.insert('temporadas', _fila(t), conflictAlgorithm: ConflictAlgorithm.replace);

  static Map<String, Object?> _fila(Temporada t) => {
    'id': t.id,
    'datos': jsonEncode(t.toJson()),
    'actualizada': DateTime.now().millisecondsSinceEpoch,
  };

  /// Guarda la partida y el perfil en una sola transacción: o se escriben las dos o ninguna.
  Future<void> guardarTemporadaYPerfil(Temporada t, PerfilEntrenador? perfil) => _db.transaction((txn) async {
    await txn.insert('temporadas', _fila(t), conflictAlgorithm: ConflictAlgorithm.replace);
    if (perfil != null && !perfilProtegido) {
      await txn.insert('claves', {
        'clave': 'perfil',
        'valor': jsonEncode(perfil.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  });

  /// Guarda la [nueva] y recién después borra la [vieja], en una transacción: si algo falla, la
  /// vieja sigue ahí.
  Future<void> reemplazarTemporada(String viejaId, Temporada nueva) => _db.transaction((txn) async {
    await txn.insert('temporadas', _fila(nueva), conflictAlgorithm: ConflictAlgorithm.replace);
    if (viejaId != nueva.id) await txn.delete('temporadas', where: 'id = ?', whereArgs: [viejaId]);
  });

  /// Restaura una copia completa de forma atómica: perfil, ajustes y partidas, o nada. Las partidas
  /// con el mismo id se reemplazan (no se duplican).
  Future<void> restaurarCopia({
    required PerfilEntrenador perfil,
    required Map<String, dynamic> ajustes,
    required List<Temporada> partidas,
  }) => _db.transaction((txn) async {
    await txn.insert('claves', {
      'clave': 'perfil',
      'valor': jsonEncode(perfil.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.insert('claves', {
      'clave': 'ajustes',
      'valor': jsonEncode(ajustes),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final t in partidas) {
      await txn.insert('temporadas', _fila(t), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    perfilProtegido = false; // recién acá, con todo escrito
  });

  Future<Temporada?> cargarTemporada(String id) async {
    final filas = await _db.query('temporadas', where: 'id = ?', whereArgs: [id]);
    return filas.isEmpty ? null : _decodificar(filas.first);
  }

  /// Para el botón "Continuar" de la pantalla de inicio. Si la última está dañada, sigue con la
  /// anterior (una partida rota no deja sin arrancar a las demás).
  Future<Temporada?> ultimaTemporada() async => (await ultimaTemporadaLegible()).$1;

  /// La partida legible más reciente y cuántas más nuevas estaban dañadas.
  Future<(Temporada?, int)> ultimaTemporadaLegible() async {
    // Lo normal: la más reciente se lee bien y no hace falta traer las demás.
    final primera = await _db.query('temporadas', orderBy: 'actualizada DESC', limit: 1);
    if (primera.isEmpty) return (null, 0);
    if (_intentar(primera.first) case final t?) return (t, 0);
    final filas = await _db.query('temporadas', orderBy: 'actualizada DESC');
    var danadas = 0;
    for (final f in filas) {
      final t = _intentar(f);
      if (t != null) return (t, danadas);
      danadas++;
    }
    return (null, danadas);
  }

  Future<void> borrarTemporada(String id) => _db.delete('temporadas', where: 'id = ?', whereArgs: [id]);

  Temporada _decodificar(Map<String, Object?> fila) =>
      Temporada.fromJson(jsonDecode(fila['datos'] as String) as Map<String, dynamic>);
}
