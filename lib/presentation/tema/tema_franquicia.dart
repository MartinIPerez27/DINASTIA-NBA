import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';

/// Tipografías del mundo "El Marcador": puntos LED para números y siglas, condensada de estadio
/// para nombres. El cuerpo queda en Roboto (sistema) por legibilidad.
abstract final class Fuentes {
  static const led = 'Doto';
  static const estadio = 'BigShouldersDisplay';
}

/// Panel mate del tablero, casi negro. Se juega de noche o en interiores: tema oscuro.
const _panel = Color(0xFF0F1012);

double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Aclara [color] lo justo para leerse sobre el panel (≥ 4.5:1). Devuelve cuánto se aclaró.
(Color, double) _legible(Color color) {
  final inicio = HSLColor.fromColor(color);
  var hsl = inicio;
  while (_contraste(hsl.toColor(), _panel) < 4.5 && hsl.lightness < 0.95) {
    hsl = hsl.withLightness((hsl.lightness + 0.02).clamp(0, 1));
  }
  return (hsl.toColor(), hsl.lightness - inicio.lightness);
}

/// Color de los LED encendidos. Manda el color principal del equipo (verde Celtics, azul Knicks),
/// aclarado si hace falta; si es negro/gris o habría que aclararlo tanto que pierde identidad
/// (púrpura Lakers, azul Warriors), se usa el secundario (oro, blanco, plata).
Color colorLed(Franquicia f) {
  final principal = Color(f.colorPrimario);
  final (ledPrincipal, aclarado) = _legible(principal);
  if (HSLColor.fromColor(principal).saturation > 0.25 && aclarado <= 0.2) return ledPrincipal;
  final (ledSecundario, _) = _legible(Color(f.colorSecundario));
  return _contraste(ledSecundario, _panel) >= 4.5 ? ledSecundario : ledPrincipal;
}

/// Tema Material 3 teñido por la franquicia: el panel toma un 6% del color principal.
ThemeData temaFranquicia(Franquicia f) {
  final led = colorLed(f);
  final sobreLed = _contraste(led, Colors.black) >= _contraste(led, Colors.white) ? Colors.black : Colors.white;
  final superficie = Color.alphaBlend(Color(f.colorPrimario).withValues(alpha: 0.06), _panel);
  final esquema = ColorScheme.fromSeed(
    seedColor: led,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(primary: led, onPrimary: sobreLed, surface: superficie, surfaceContainerLowest: _panel);

  final base = ThemeData(colorScheme: esquema, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: superficie,
    textTheme: base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontFamily: Fuentes.estadio,
        fontVariations: const [FontVariation.weight(800)],
        height: 0.9,
        letterSpacing: 0,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: Fuentes.estadio,
        fontVariations: const [FontVariation.weight(600)],
        letterSpacing: 0.5,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: [FontVariation.weight(700)],
          fontSize: 20,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}
