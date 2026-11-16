import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/entities/jugador.dart';
import 'fuentes_foto.dart';
import 'indice_fotos.dart';
import 'limitador_hosts.dart';

/// Quita el fondo de una foto de archivo y devuelve el PNG (null si no se pudo).
typedef Recortador = Future<Uint8List?> Function(File original);

/// Descarga y guarda para siempre las fotos de jugadores en el dispositivo.
///
/// - Se trabaja por PERSONA (id de Basketball-Reference), no por carta: ~4.000 personas.
/// - Cada foto se baja una vez a `carpeta` (archivo propio, sin vencimiento ni tope de cantidad) y se
///   anota en el índice SQLite con fuente, licencia, autor y fecha.
/// - Los pedidos van de a uno con ritmo por host (ver [PeticionesFotos]); los 404 se recuerdan
///   (`EstadoFoto.sin`) entre sesiones; las fallas de red quedan `pendiente` y se reintentan luego.
/// - Se puede pausar y reanudar; si falla la red varias veces seguidas se pausa solo.
class GestorFotos extends ChangeNotifier {
  GestorFotos({
    required this.indice,
    required this.carpeta,
    required this.peticiones,
    this.recortador,
    ResolvedorFotos? resolvedor,
    DateTime Function()? ahora,
    this.fallasParaPausar = 4,
    this.reintentoDeSin = const Duration(days: 180),
  }) : resolvedor = resolvedor ?? ResolvedorFotos(peticiones),
       _ahora = ahora ?? DateTime.now;

  /// Gestor de la app (lo crea `main`); null en tests y capturas sin red.
  static GestorFotos? instancia;

  final IndiceFotos indice;
  final Directory carpeta;
  final PeticionesFotos peticiones;
  final ResolvedorFotos resolvedor;

  /// Quita el fondo de las fotos de archivo. Sin recortador (plataformas sin ML Kit) esas fotos se
  /// guardan igual pero no se muestran hasta poder recortarlas.
  final Recortador? recortador;
  final DateTime Function() _ahora;
  final int fallasParaPausar;
  final Duration reintentoDeSin;

  final _filas = <String, FotoIndexada>{};
  final _cola = Queue<PersonaFoto>();
  final _enCola = <String>{};
  final _aviso = <String, ChangeNotifier>{};
  bool _corriendo = false;
  bool _pausado = false;
  int _fallasSeguidas = 0;
  int _total = 0;
  int _hechas = 0;
  String? _mensaje;

  /// Carga el índice en memoria (miles de filas livianas): después las cartas leen sin esperar.
  Future<void> cargar() async {
    _filas
      ..clear()
      ..addEntries([for (final f in await indice.todas()) MapEntry(f.persona, f)]);
    notifyListeners();
  }

  // ---- Lectura (sincrónica, desde la memoria) ----

  FotoIndexada? de(String persona) => _filas[persona];

  /// Cantidad de personas por estado entre las [personas] dadas.
  ({int listas, int sin, int faltan}) conteo(Iterable<PersonaFoto> personas) {
    var listas = 0, sin = 0, faltan = 0;
    for (final p in personas) {
      switch (_filas[p.clave]?.estado) {
        case EstadoFoto.ok:
          listas++;
        case EstadoFoto.sin:
          sin++;
        case EstadoFoto.pendiente || null:
          faltan++;
      }
    }
    return (listas: listas, sin: sin, faltan: faltan);
  }

  /// Archivo para mostrar: el recortado (fotos de archivo) o el original (NBA), o null si no hay
  /// una foto lista y mostrable.
  File? archivoMostrable(String persona) {
    final f = _filas[persona];
    if (f == null || f.estado != EstadoFoto.ok) return null;
    final nombre = f.esNba ? f.ruta : f.rutaRecorte;
    return nombre == null ? null : File('${carpeta.path}/$nombre');
  }

  /// Avisa solo cuando cambia la foto de [persona] (las cartas no se redibujan por el progreso general).
  Listenable escuchar(String persona) => _aviso.putIfAbsent(persona, ChangeNotifier.new);

  /// Fotos con autor y licencia que hay que atribuir (Wikipedia y Commons), por nombre.
  List<FotoIndexada> atribuciones() => [
    for (final f in _filas.values)
      if (f.estado == EstadoFoto.ok && (f.fuente == 'wikipedia' || f.fuente == 'commons')) f,
  ]..sort((a, b) => (a.nombre ?? '').compareTo(b.nombre ?? ''));

  bool get activo => _corriendo && !_pausado;
  bool get pausado => _pausado;
  bool get trabajando => _corriendo || _cola.isNotEmpty;
  int get enCola => _cola.length;
  int get totalLote => _total;
  int get hechasLote => _hechas;
  String? get mensaje => _mensaje;

  // ---- Cola ----

  /// Pide la foto de [p] ya (al frente de la cola) si todavía no se resolvió. Lo usa la carta que se
  /// está viendo.
  void solicitar(PersonaFoto p) {
    final f = _filas[p.clave];
    if (f != null && (f.estado == EstadoFoto.ok || f.estado == EstadoFoto.sin)) return;
    if (_enCola.contains(p.clave)) return;
    _enCola.add(p.clave);
    _cola.addFirst(p);
    if (!_pausado) _arrancar();
  }

  /// Encola a todas las personas sin foto resuelta (y las "sin foto" de hace mucho) y arranca.
  /// Las de la NBA van primero: son rápidas y no tienen límite de ritmo estricto.
  void descargarTodas(Iterable<PersonaFoto> personas) {
    final pendientes = <PersonaFoto>[];
    for (final p in personas) {
      final f = _filas[p.clave];
      final vieja = f != null && f.estado == EstadoFoto.sin && _ahora().difference(f.fecha) > reintentoDeSin;
      if (f == null || f.estado == EstadoFoto.pendiente || vieja) pendientes.add(p);
    }
    pendientes.sort((a, b) => (b.usaNba ? 1 : 0).compareTo(a.usaNba ? 1 : 0));
    for (final p in pendientes) {
      if (_enCola.add(p.clave)) _cola.addLast(p);
    }
    _total = _hechas + _cola.length;
    _pausado = false;
    _mensaje = null;
    _fallasSeguidas = 0;
    notifyListeners();
    _arrancar();
  }

  /// Vuelve a buscar las que quedaron "sin foto" (por ejemplo, tras subir una a Wikimedia).
  Future<void> reintentarSinFoto(Iterable<PersonaFoto> personas) async {
    for (final p in personas) {
      if (_filas[p.clave]?.estado == EstadoFoto.sin) {
        await indice.borrar(p.clave);
        _filas.remove(p.clave);
      }
    }
    descargarTodas(personas);
  }

  void pausar() {
    _pausado = true;
    notifyListeners();
  }

  void reanudar() {
    _pausado = false;
    _mensaje = null;
    _fallasSeguidas = 0;
    notifyListeners();
    _arrancar();
  }

  /// Espera a que termine la cola actual (para tests y para esperar un lote).
  Future<void> terminar() async {
    while (_corriendo) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  void _arrancar() {
    if (_corriendo || _pausado || _cola.isEmpty) return;
    _corriendo = true;
    notifyListeners();
    unawaited(_bucle());
  }

  Future<void> _bucle() async {
    try {
      while (_cola.isNotEmpty && !_pausado) {
        final p = _cola.removeFirst();
        _enCola.remove(p.clave);
        final transitoria = await _resolver(p);
        _hechas++;
        if (transitoria) {
          _fallasSeguidas++;
          if (_fallasSeguidas >= fallasParaPausar) {
            _pausado = true;
            _mensaje = 'Sin conexión o el servidor no responde. Pausado: reanudá cuando vuelva.';
          }
        } else {
          _fallasSeguidas = 0;
        }
        notifyListeners();
      }
    } finally {
      _corriendo = false;
      if (_cola.isEmpty) {
        _total = 0;
        _hechas = 0;
      }
      notifyListeners();
    }
  }

  /// Devuelve true si falló por un motivo pasajero (red, 429, 5xx).
  Future<bool> _resolver(PersonaFoto p) async {
    final previo = _filas[p.clave];
    if (previo?.estado == EstadoFoto.ok && archivoMostrable(p.clave)?.existsSync() == true) return false;
    final intentos = (previo?.intentos ?? 0) + 1;
    try {
      await carpeta.create(recursive: true);
      await for (final c in resolvedor.candidatas(p)) {
        final fila = await _guardarCandidata(p, c, intentos);
        if (fila != null) {
          await _anotar(fila);
          return false;
        }
      }
      await _anotar(
        FotoIndexada(persona: p.clave, nombre: p.nombre, estado: EstadoFoto.sin, fecha: _ahora(), intentos: intentos),
      );
      return false;
    } on FotoTransitoria catch (e) {
      debugPrint('Foto de ${p.nombre} pendiente: $e');
      await _anotar(
        FotoIndexada(
          persona: p.clave,
          nombre: p.nombre,
          estado: EstadoFoto.pendiente,
          fecha: _ahora(),
          intentos: intentos,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Foto de ${p.nombre}: error inesperado $e');
      await _anotar(
        FotoIndexada(
          persona: p.clave,
          nombre: p.nombre,
          estado: EstadoFoto.pendiente,
          fecha: _ahora(),
          intentos: intentos,
        ),
      );
      return false;
    }
  }

  /// Baja la candidata y la guarda; null si no sirve (404, no es imagen, sin persona recortable).
  Future<FotoIndexada?> _guardarCandidata(PersonaFoto p, Candidata c, int intentos) async {
    final r = await peticiones.pedir(Uri.parse(c.url));
    if (!r.ok) return null;
    final ext = _extension(r.cuerpo);
    if (ext == null || r.cuerpo.length < 800) return null;
    final nombre = '${p.clave}.$ext';
    final archivo = File('${carpeta.path}/$nombre');
    await archivo.writeAsBytes(r.cuerpo, flush: true);

    String? recorte;
    if (c.fuente != 'nba' && recortador != null) {
      final png = await recortador!(archivo);
      if (png == null) {
        // Sin persona clara en la foto: se descarta y se prueba la siguiente fuente.
        await archivo.delete();
        return null;
      }
      recorte = '${p.clave}_r.png';
      await File('${carpeta.path}/$recorte').writeAsBytes(png, flush: true);
    }
    return FotoIndexada(
      persona: p.clave,
      nombre: p.nombre,
      estado: EstadoFoto.ok,
      ruta: nombre,
      rutaRecorte: recorte,
      fuente: c.fuente,
      licencia: c.licencia,
      autor: c.autor,
      urlOrigen: c.url,
      urlPagina: c.paginaUrl,
      fecha: _ahora(),
      intentos: intentos,
    );
  }

  Future<void> _anotar(FotoIndexada f) async {
    await indice.guardar(f);
    _filas[f.persona] = f;
    _aviso[f.persona]?.notifyListeners();
  }

  /// Extensión según los primeros bytes (png, jpg, webp); null si no es una imagen.
  static String? _extension(Uint8List b) {
    if (b.length < 12) return null;
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'png';
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'jpg';
    if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45) return 'webp';
    return null;
  }

  /// Personas a partir de las cartas del catálogo: una por id de Basketball-Reference, con foto
  /// de la NBA si alguna de sus cartas la tiene. Las cartas sin fuentes de foto (jugadores creados)
  /// no cuentan.
  static List<PersonaFoto> personasDe(Iterable<Jugador> cartas) {
    final por = <String, PersonaFoto>{};
    for (final j in cartas) {
      if (j.fotos.isEmpty) continue;
      final usaNba = j.fotos.contains('n') && j.nbaPlayerId > 0;
      final antes = por[j.idBbref];
      por[j.idBbref] = PersonaFoto(
        clave: j.idBbref,
        nombre: antes?.nombre ?? j.nombre,
        nbaPlayerId: usaNba ? j.nbaPlayerId : (antes?.nbaPlayerId ?? 0),
        usaNba: usaNba || (antes?.usaNba ?? false),
        nacimiento: antes?.nacimiento ?? j.nacimiento,
      );
    }
    return por.values.toList();
  }

  /// Persona de una carta (null si no tiene fuentes de foto).
  static PersonaFoto? personaDe(Jugador j) => j.fotos.isEmpty ? null : personasDe([j]).first;
}
