import 'dart:math';

import 'package:flutter/painting.dart';

import 'coreografia.dart';

/// Cámara de transmisión: sigue el plano que pide la coreografía (`Coreografia.plano`) con un resorte
/// suave (más rápido al acercarse a lo importante que al abrirse), y se sacude con los impactos
/// (volcadas, tapones).
class CamaraTransmision {
  double x = 25, y = 47, zoom = 1;
  double _impacto = 0;
  double _tiempo = 0;
  double _tAnterior = 0;
  Coreografia? _coreo;

  /// Sacudida actual en píxeles lógicos.
  Offset get temblor => Offset(sin(_tiempo * 71), cos(_tiempo * 89)) * (_impacto * 3.5);

  /// Vuelve al plano general (inicio del partido, salto de cuartos).
  void reiniciar() {
    x = 25;
    y = 47;
    zoom = 1;
    _impacto = 0;
    _coreo = null;
  }

  /// Avanza [dt] segundos hacia el plano de la jugada en el instante [t] (0–1).
  void avanzar(Coreografia? coreo, double t, double dt, {bool reducido = false}) {
    _tiempo += dt;
    _impacto *= exp(-dt * 9);
    if (coreo == null) return;
    if (!identical(coreo, _coreo)) {
      _coreo = coreo;
      _tAnterior = t;
    }
    final plano = coreo.plano(t);
    final pide = reducido ? 1.0 : plano.zoom;
    x += (plano.x - x) * (1 - exp(-dt * 3));
    y += (plano.y - y) * (1 - exp(-dt * 3.5));
    zoom += (pide - zoom) * (1 - exp(-dt * (pide > zoom ? 3.2 : 1.8)));
    // Golpe de cámara en el impacto de lo vistoso.
    final clave = coreo.evento.volcada || coreo.evento.taponado ? coreo.momentoClimax : null;
    if (!reducido && clave != null && _tAnterior < clave && t >= clave) _impacto = 1;
    _tAnterior = t;
  }
}
