import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/relato/contexto_relato.dart';

/// Una voz del sistema: nombre y región (como las devuelve `getVoices`).
typedef VozSistema = ({String name, String locale});

/// Voces elegidas para cada personaje y cómo diferenciarlos.
class AsignacionVoces {
  const AsignacionVoces({this.relator, this.comentarista});

  /// null: se usa la voz por defecto del sistema.
  final VozSistema? relator, comentarista;

  /// ¿Hay dos voces distintas? Si no, se diferencian solo por tono y velocidad.
  bool get distintas => relator != null && comentarista != null && relator!.name != comentarista!.name;
}

/// Perfil de prosodia de un personaje (tono 0.5-2, velocidad 0-1 de flutter_tts).
({double tono, double velocidad}) perfilDeVoz(Personaje p, {required bool distintas, int intensidad = 1}) {
  final (tono, velocidad) = switch ((p, distintas)) {
    (Personaje.relator, true) => (0.95, 0.47),
    (Personaje.comentarista, true) => (1.08, 0.53),
    (Personaje.relator, false) => (0.8, 0.45),
    (Personaje.comentarista, false) => (1.25, 0.56),
  };
  // Más emoción: un poco más agudo y más rápido.
  return (tono: tono + 0.03 * intensidad, velocidad: velocidad + 0.015 * intensidad);
}

/// Reparte las voces en español: el Comentarista prefiere la rioplatense/latina, el Relator otra distinta
/// (si hay). Con una sola voz las dos usan esa misma.
AsignacionVoces asignarVoces(List<dynamic> voces) {
  final es = <VozSistema>[];
  for (final v in voces) {
    if (v is! Map) continue;
    final nombre = '${v['name'] ?? ''}', region = '${v['locale'] ?? ''}'.replaceAll('_', '-');
    if (nombre.isEmpty || !region.toLowerCase().startsWith('es')) continue;
    es.add((name: nombre, locale: region));
  }
  if (es.isEmpty) return const AsignacionVoces();
  // Las que necesitan red van al final: tienen que funcionar sin internet.
  int sinRed(VozSistema v) => v.name.toLowerCase().contains('network') ? 1 : 0;
  int rank(VozSistema v, List<String> pref) {
    final i = pref.indexWhere((r) => v.locale.toLowerCase().startsWith(r.toLowerCase()));
    return sinRed(v) * 100 + (i < 0 ? pref.length : i);
  }

  VozSistema mejor(List<VozSistema> lista, List<String> pref) =>
      (List.of(lista)..sort((a, b) => rank(a, pref).compareTo(rank(b, pref)))).first;

  final comentarista = mejor(es, const ['es-AR', 'es-UY', 'es-419', 'es-US', 'es-MX']);
  final otras = es.where((v) => v.name != comentarista.name).toList();
  final relator = otras.isEmpty ? comentarista : mejor(otras, const ['es-US', 'es-419', 'es-MX', 'es-ES', 'es-CO']);
  return AsignacionVoces(relator: relator, comentarista: comentarista);
}

/// Cola con prioridad de las líneas por decir: no se acumulan relatos viejos.
class ColaVoz {
  final _pendientes = <LineaRelato>[];

  List<LineaRelato> get pendientes => List.unmodifiable(_pendientes);
  bool get vacia => _pendientes.isEmpty;

  /// Cuántas líneas esperan como máximo según la velocidad del partido (x1, x2, x4).
  static int maximo(int velocidad) => velocidad >= 4 ? 0 : (velocidad >= 2 ? 1 : 3);

  /// Agrega una línea. Devuelve false si se descarta (no hay lugar y no era más importante que lo que espera).
  /// A x4 solo entran las de intensidad 3 o más.
  bool agregar(LineaRelato l, {int velocidad = 1, bool hablando = false}) {
    if (velocidad >= 4 && l.intensidad < 3) return false;
    if (!hablando && _pendientes.isEmpty) {
      _pendientes.add(l);
      return true;
    }
    final tope = velocidad >= 4 ? 1 : maximo(velocidad);
    if (tope == 0) return false;
    while (_pendientes.length >= tope) {
      // Se saca la más vieja de las menos intensas, salvo que la nueva sea más floja que todas.
      var peor = 0;
      for (var i = 1; i < _pendientes.length; i++) {
        if (_pendientes[i].intensidad < _pendientes[peor].intensidad) peor = i;
      }
      if (_pendientes[peor].intensidad > l.intensidad) return false;
      _pendientes.removeAt(peor);
    }
    _pendientes.add(l);
    return true;
  }

  LineaRelato? siguiente() => _pendientes.isEmpty ? null : _pendientes.removeAt(0);

  void vaciar() => _pendientes.clear();
}

/// Voz del relato: lee las líneas en voz alta con las voces de texto a voz del celular (el motor de Android,
/// sin internet una vez instaladas las voces en español). Gratis y sin cuentas. Cada personaje usa una voz
/// distinta si el teléfono tiene más de una en español; si no, se diferencian por tono y velocidad.
///
/// ```dart
/// final voz = VozRelator();
/// await voz.iniciar();
/// voz.hablar(linea, velocidad: 2);   // encola (con prioridad por intensidad)
/// voz.callar();                       // corta y vacía la cola (pausa, saltar)
/// await voz.liberar();                // en dispose()
/// ```
/// Nada de esto lanza excepciones: si no hay voz disponible, el partido sigue en silencio.
/// En pruebas de widgets poné `VozRelator.habilitado = false` (no hay plugin).
class VozRelator {
  /// Interruptor global (pruebas sin plugin): en false todo es un no-op.
  static bool habilitado = true;

  /// Idiomas en orden de preferencia: rioplatense primero.
  static const _idiomas = ['es-AR', 'es-US', 'es-419', 'es-ES', 'es'];

  FlutterTts? _tts;
  var _hablando = false;
  var _listo = false;
  var _asignacion = const AsignacionVoces();
  LineaRelato? _actual;
  final _cola = ColaVoz();

  /// Voces elegidas (para mostrar o depurar).
  AsignacionVoces get asignacion => _asignacion;

  Future<void> iniciar() async {
    if (!habilitado || _listo) return;
    _listo = true;
    await _seguro(() async {
      final tts = FlutterTts();
      _tts = tts;
      await tts.awaitSpeakCompletion(false);
      for (final idioma in _idiomas) {
        if (await tts.isLanguageAvailable(idioma) == true) {
          await tts.setLanguage(idioma);
          break;
        }
      }
      try {
        _asignacion = asignarVoces(await tts.getVoices as List<dynamic>? ?? const []);
      } catch (e) {
        debugPrint('Sin lista de voces: $e');
      }
      tts
        ..setStartHandler(() => _hablando = true)
        ..setCompletionHandler(_alTerminar)
        ..setCancelHandler(() => _hablando = false)
        ..setErrorHandler((_) => _alTerminar());
    });
  }

  void _alTerminar() {
    _hablando = false;
    _actual = null;
    _decirSiguiente();
  }

  /// Encola una línea del relato. A velocidad alta se saltan las viejas y las flojas; una línea muy
  /// intensa corta lo que se está diciendo si era más tranquilo.
  void hablar(LineaRelato l, {int velocidad = 1}) {
    final tts = _tts;
    if (!habilitado || tts == null || l.texto.trim().isEmpty) return;
    final interrumpe = _hablando && (_actual?.intensidad ?? 0) + 2 <= l.intensidad;
    if (interrumpe) {
      _cola.vaciar();
      _hablando = false;
      _seguro(() async => tts.stop());
    }
    if (_cola.agregar(l, velocidad: velocidad, hablando: _hablando) && !_hablando) _decirSiguiente();
  }

  void _decirSiguiente() {
    final tts = _tts;
    final l = _cola.siguiente();
    if (!habilitado || tts == null || l == null) return;
    _hablando = true;
    _actual = l;
    _seguro(() async {
      final p = perfilDeVoz(l.personaje, distintas: _asignacion.distintas, intensidad: l.intensidad);
      final voz = l.personaje == Personaje.relator ? _asignacion.relator : _asignacion.comentarista;
      if (voz != null) await tts.setVoice({'name': voz.name, 'locale': voz.locale});
      await tts.setPitch(p.tono);
      await tts.setSpeechRate(p.velocidad);
      await tts.speak(l.texto);
    });
  }

  /// Compatibilidad: dice un texto suelto con la voz del Relator.
  void decir(String frase, {bool prioridad = false}) =>
      hablar(LineaRelato(Personaje.relator, frase, prioridad ? 4 : 1, Situacion.doble), velocidad: 1);

  /// Corta lo que se está diciendo y vacía la cola (pausa o salto de partido).
  void callar() {
    final tts = _tts;
    _cola.vaciar();
    _actual = null;
    if (!habilitado || tts == null) return;
    _hablando = false;
    _seguro(() async => tts.stop());
  }

  Future<void> liberar() async {
    if (!habilitado) return;
    final tts = _tts;
    _tts = null;
    _listo = false;
    _hablando = false;
    _cola.vaciar();
    if (tts != null) await _seguro(() async => tts.stop());
  }

  /// Corre una operación de voz sin dejar escapar errores (plugin ausente, sin voz instalada…).
  Future<void> _seguro(Future<void> Function() accion) async {
    if (!habilitado) return;
    try {
      await accion();
    } catch (e) {
      debugPrint('Voz del relato no disponible: $e');
      _hablando = false;
    }
  }
}
