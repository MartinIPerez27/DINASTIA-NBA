import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sonido del partido en vivo: público de fondo y efectos (sintetizados por `tools/sonidos.py`,
/// sin licencias, en `assets/sonidos/`).
///
/// Uso:
/// ```dart
/// final sonido = SonidoPartido();
/// await sonido.iniciar();          // precarga y arranca el público en bucle (bajito)
/// sonido.pique();                  // dribbling (limitado a uno cada 120 ms)
/// sonido.red();                    // canasta limpia
/// sonido.aro();                    // la pelota pega en el aro
/// sonido.chicharra();              // fin de cuarto / partido
/// sonido.silbato();                // falta, infracción, tiempo muerto
/// sonido.ovacion();                // jugada grande (triple, tapón, clutch)
/// sonido.abucheo();                // el público local abuchea al visitante
/// sonido.canto();                  // "DE-FEN-SA" (como mucho uno cada 8 s)
/// sonido.golpe();                  // volcada: aro y tablero
/// sonido.aplauso();                // aplauso (tiempo muerto, cambio, cierre de cuarto)
/// sonido.atmosfera(excitacion: .4, tension: 1); // murmullo que sube y suspenso del final apretado
/// sonido.tiroLibre(true);          // silencio del público mientras se tira un libre
/// sonido.pausar(); sonido.reanudar();
/// sonido.silencio = true;          // botón de silencio
/// await sonido.liberar();          // en dispose()
/// ```
/// Nada de esto lanza excepciones: si el audio falla, el partido sigue en silencio.
/// En pruebas de widgets poné `SonidoPartido.habilitado = false` (no hay plugin de audio).
class SonidoPartido {
  /// Interruptor global (pruebas sin plugin de audio): en false todo es un no-op.
  static bool habilitado = true;

  static const _volumenPublico = 0.35;

  final _pools = <String, AudioPool>{};
  AudioPlayer? _publico;
  AudioPlayer? _suspenso;
  var _excitacion = 0.0, _tension = 0.0, _silencioLibre = false;
  var _silencio = false;
  var _pausado = false;
  var _listo = false;
  DateTime _ultimoPique = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _ultimoCanto = DateTime.fromMillisecondsSinceEpoch(0);

  bool get silencio => _silencio;

  set silencio(bool valor) {
    _silencio = valor;
    _seguro(() async {
      if (valor) {
        await _publico?.pause();
      } else if (!_pausado) {
        await _publico?.resume();
      }
    });
  }

  Future<void> iniciar() async {
    if (!habilitado || _listo) return;
    _listo = true;
    await _seguro(() async {
      // Que el partido no corte la música que el usuario tenga sonando.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      for (final (nombre, maximo) in [
        ('pique', 3),
        ('red', 2),
        ('aro', 2),
        ('chicharra', 1),
        ('silbato', 2),
        ('ovacion', 1),
        ('abucheo', 1),
        ('defensa', 1),
        ('golpe', 2),
        ('aplauso', 1),
      ]) {
        _pools[nombre] = await AudioPool.create(source: AssetSource('sonidos/$nombre.ogg'), maxPlayers: maximo);
      }
      final publico = AudioPlayer();
      _publico = publico;
      await publico.setReleaseMode(ReleaseMode.loop);
      await publico.setVolume(_volumenPublico);
      await publico.setSource(AssetSource('sonidos/publico.ogg'));
      if (!_silencio && !_pausado) await publico.resume();
      final suspenso = AudioPlayer();
      _suspenso = suspenso;
      await suspenso.setReleaseMode(ReleaseMode.loop);
      await suspenso.setVolume(0);
      await suspenso.setSource(AssetSource('sonidos/tension.ogg'));
    });
  }

  /// Murmullo que sube con la tensión y la excitación (0–1) y capa de suspenso en el final apretado.
  void atmosfera({double excitacion = 0, double tension = 0}) {
    _excitacion = excitacion.clamp(0.0, 1.0);
    _tension = tension.clamp(0.0, 1.0);
    _aplicarVolumen();
  }

  /// En un tiro libre el público se calla (el murmullo baja casi a cero) hasta que cae la pelota.
  void tiroLibre(bool activo) {
    _silencioLibre = activo;
    _aplicarVolumen();
  }

  void aplauso() => _efecto('aplauso', 0.8);

  void _aplicarVolumen() {
    if (!habilitado || !_listo) return;
    final murmullo = _silencioLibre ? 0.06 : _volumenPublico * (0.7 + 0.8 * _excitacion + 0.3 * _tension);
    _seguro(() async {
      await _publico?.setVolume(murmullo.clamp(0.0, 1.0));
      final suspenso = _suspenso;
      if (suspenso == null) return;
      final v = _silencio || _pausado ? 0.0 : _tension * (_silencioLibre ? 0.5 : 0.35);
      await suspenso.setVolume(v);
      if (v > 0 && suspenso.state != PlayerState.playing) {
        await suspenso.resume();
      } else if (v == 0 && suspenso.state == PlayerState.playing) {
        await suspenso.pause();
      }
    });
  }

  void pique() {
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoPique) < const Duration(milliseconds: 120)) return;
    _ultimoPique = ahora;
    _efecto('pique', 0.55);
  }

  void red() => _efecto('red', 0.9);

  void aro() => _efecto('aro', 0.8);

  void chicharra() => _efecto('chicharra', 0.8);

  void silbato() => _efecto('silbato', 0.7);

  void ovacion() => _efecto('ovacion', 0.9);

  void abucheo() => _efecto('abucheo', 0.75);

  /// Canto "DE-FEN-SA" de la tribuna: como mucho uno cada 8 segundos (si no, satura).
  void canto() {
    if (!habilitado || _silencio || _pausado) return;
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoCanto) < const Duration(seconds: 8)) return;
    _ultimoCanto = ahora;
    _efecto('defensa', 0.7);
  }

  void golpe() => _efecto('golpe', 0.95);

  void pausar() {
    _pausado = true;
    _seguro(() async {
      await _publico?.pause();
      await _suspenso?.pause();
    });
  }

  void reanudar() {
    _pausado = false;
    if (!_silencio) _seguro(() async => _publico?.resume());
    _aplicarVolumen();
  }

  Future<void> liberar() async {
    if (!habilitado) return;
    await _seguro(() async {
      await _publico?.dispose();
      await _suspenso?.dispose();
      for (final p in _pools.values) {
        await p.dispose();
      }
    });
    _publico = null;
    _suspenso = null;
    _pools.clear();
    _listo = false;
  }

  void _efecto(String nombre, double volumen) {
    if (!habilitado || _silencio || _pausado) return;
    final pool = _pools[nombre];
    if (pool == null) return;
    _seguro(() => pool.start(volume: volumen));
  }

  /// Corre una operación de audio sin dejar escapar errores (plugin ausente, archivo, etc.).
  Future<void> _seguro(Future<void> Function() accion) async {
    if (!habilitado) return;
    try {
      await accion();
    } catch (e) {
      debugPrint('Audio no disponible: $e');
    }
  }
}
