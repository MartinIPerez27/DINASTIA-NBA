import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Lado corto desde el que un dispositivo se considera tablet (dp).
const ladoCortoTablet = 600.0;

/// Orientaciones permitidas según el lado corto de la pantalla en dp: el teléfono queda en vertical
/// (el diseño de teléfono es vertical) y la tablet gira libre (ahí hay diseño apaisado).
List<DeviceOrientation> orientacionesPara(double ladoCortoDp) => ladoCortoDp >= ladoCortoTablet
    ? DeviceOrientation.values
    : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

/// Se llama en el arranque: bloquea la vertical en teléfonos y deja girar las tablets.
Future<void> aplicarOrientacion([ui.FlutterView? vista]) {
  vista ??= ui.PlatformDispatcher.instance.views.firstOrNull;
  final corto = vista == null ? 0.0 : vista.physicalSize.shortestSide / vista.devicePixelRatio;
  // Si todavía no hay vista (no debería pasar), se asume teléfono.
  return SystemChrome.setPreferredOrientations(orientacionesPara(corto));
}
