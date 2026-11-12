import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Voz del relator: lee las frases en voz alta con la voz de texto a voz que trae el celular
/// (el motor de Android, sin internet una vez instalada la voz en español). Gratis y sin cuentas.
///
/// Uso:
/// ```dart
/// final voz = VozRelator();
/// await voz.iniciar();
/// voz.decir('¡Adentro, señores!');                 // si ya está hablando, se descarta
/// voz.decir('¡Ganaron el partido!', prioridad: true); // corta lo anterior y se dice sí o sí
/// voz.callar();
/// await voz.liberar();                              // en dispose()
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
      await tts.setSpeechRate(0.5);
      await tts.setPitch(1.0);
      tts
        ..setStartHandler(() => _hablando = true)
        ..setCompletionHandler(() => _hablando = false)
        ..setCancelHandler(() => _hablando = false)
        ..setErrorHandler((_) => _hablando = false);
    });
  }

  /// Dice la frase. Si ya está hablando, una frase común se descarta (no se encolan relatos
  /// viejos); una con [prioridad] corta lo anterior.
  void decir(String frase, {bool prioridad = false}) {
    final tts = _tts;
    if (!habilitado || tts == null || frase.trim().isEmpty) return;
    if (_hablando && !prioridad) return;
    _hablando = true;
    _seguro(() async {
      if (prioridad) await tts.stop();
      await tts.speak(frase);
    });
  }

  void callar() {
    final tts = _tts;
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
    if (tts != null) await _seguro(() async => tts.stop());
  }

  /// Corre una operación de voz sin dejar escapar errores (plugin ausente, sin voz instalada…).
  Future<void> _seguro(Future<void> Function() accion) async {
    if (!habilitado) return;
    try {
      await accion();
    } catch (e) {
      debugPrint('Voz del relator no disponible: $e');
      _hablando = false;
    }
  }
}
