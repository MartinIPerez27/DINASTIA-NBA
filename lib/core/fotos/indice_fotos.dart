import 'package:sqflite/sqflite.dart';

/// Estado de la foto de una persona en el índice local.
enum EstadoFoto {
  /// Descargada y guardada en el dispositivo.
  ok,

  /// Se buscó en todas las fuentes y no hay (se recuerda entre sesiones; se reintenta mucho después).
  sin,

  /// Falta intentar (o falló por red y hay que reintentar).
  pendiente,
}

/// Fila del índice: persona → archivo, fuente, licencia, autor, fecha y estado.
class FotoIndexada {
  const FotoIndexada({
    required this.persona,
    required this.estado,
    required this.fecha,
    this.nombre,
    this.ruta,
    this.rutaRecorte,
    this.fuente,
    this.licencia,
    this.autor,
    this.urlOrigen,
    this.urlPagina,
    this.intentos = 0,
  });

  final String persona;
  final EstadoFoto estado;
  final DateTime fecha;
  final String? nombre;

  /// Nombres de archivo dentro de la carpeta de fotos (no rutas absolutas: la carpeta de la app
  /// puede cambiar al actualizarla).
  final String? ruta;
  final String? rutaRecorte;
  final String? fuente;
  final String? licencia;
  final String? autor;
  final String? urlOrigen;
  final String? urlPagina;
  final int intentos;

  /// Fotos de la NBA: ya vienen sin fondo. Las demás necesitan recorte para mostrarse.
  bool get esNba => fuente == 'nba';

  Map<String, Object?> toMap() => {
    'persona': persona,
    'estado': estado.name,
    'ruta': ruta,
    'ruta_recorte': rutaRecorte,
    'fuente': fuente,
    'licencia': licencia,
    'autor': autor,
    'url_origen': urlOrigen,
    'url_pagina': urlPagina,
    'fecha': fecha.millisecondsSinceEpoch,
    'intentos': intentos,
    'nombre': nombre,
  };

  factory FotoIndexada.fromMap(Map<String, Object?> m) => FotoIndexada(
    persona: m['persona'] as String,
    estado: EstadoFoto.values.firstWhere((e) => e.name == m['estado'], orElse: () => EstadoFoto.pendiente),
    fecha: DateTime.fromMillisecondsSinceEpoch(m['fecha'] as int? ?? 0),
    nombre: m['nombre'] as String?,
    ruta: m['ruta'] as String?,
    rutaRecorte: m['ruta_recorte'] as String?,
    fuente: m['fuente'] as String?,
    licencia: m['licencia'] as String?,
    autor: m['autor'] as String?,
    urlOrigen: m['url_origen'] as String?,
    urlPagina: m['url_pagina'] as String?,
    intentos: m['intentos'] as int? ?? 0,
  );

  FotoIndexada copyWith({EstadoFoto? estado, String? rutaRecorte, int? intentos, DateTime? fecha}) => FotoIndexada(
    persona: persona,
    estado: estado ?? this.estado,
    fecha: fecha ?? this.fecha,
    nombre: nombre,
    ruta: ruta,
    rutaRecorte: rutaRecorte ?? this.rutaRecorte,
    fuente: fuente,
    licencia: licencia,
    autor: autor,
    urlOrigen: urlOrigen,
    urlPagina: urlPagina,
    intentos: intentos ?? this.intentos,
  );
}

/// Índice SQLite de fotos por persona. La tabla se crea con `IF NOT EXISTS` al abrir la base (ver
/// `DbLocal.abrir`), así que una base vieja se migra sola sin tocar `version` ni las demás tablas.
class IndiceFotos {
  IndiceFotos(this._db);

  final Database _db;

  static const tabla = 'fotos_jugador';

  static Future<void> crearTabla(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS $tabla (
      persona TEXT PRIMARY KEY,
      estado TEXT NOT NULL,
      ruta TEXT,
      ruta_recorte TEXT,
      fuente TEXT,
      licencia TEXT,
      autor TEXT,
      url_origen TEXT,
      url_pagina TEXT,
      fecha INTEGER NOT NULL,
      intentos INTEGER NOT NULL DEFAULT 0,
      nombre TEXT
    )''');

  Future<FotoIndexada?> obtener(String persona) async {
    final f = await _db.query(tabla, where: 'persona = ?', whereArgs: [persona]);
    return f.isEmpty ? null : FotoIndexada.fromMap(f.first);
  }

  Future<void> guardar(FotoIndexada foto) =>
      _db.insert(tabla, foto.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<FotoIndexada>> todas() async => [for (final f in await _db.query(tabla)) FotoIndexada.fromMap(f)];

  Future<void> borrar(String persona) => _db.delete(tabla, where: 'persona = ?', whereArgs: [persona]);

  /// Cuántas filas hay por estado.
  Future<Map<EstadoFoto, int>> conteo() async {
    final f = await _db.rawQuery('SELECT estado, COUNT(*) AS n FROM $tabla GROUP BY estado');
    return {
      for (final e in EstadoFoto.values) e: 0,
      for (final r in f) EstadoFoto.values.firstWhere((e) => e.name == r['estado']): r['n'] as int,
    };
  }
}
