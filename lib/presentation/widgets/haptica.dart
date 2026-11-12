import 'package:flutter/services.dart';

import '../../data/estado_app.dart';

/// Vibración que respeta el ajuste "Vibración".
abstract final class Haptica {
  static bool get _activa => ajustesApp.value.vibracion;

  static void seleccion() {
    if (_activa) HapticFeedback.selectionClick();
  }

  static void ligera() {
    if (_activa) HapticFeedback.lightImpact();
  }

  static void media() {
    if (_activa) HapticFeedback.mediumImpact();
  }

  static void fuerte() {
    if (_activa) HapticFeedback.heavyImpact();
  }
}
