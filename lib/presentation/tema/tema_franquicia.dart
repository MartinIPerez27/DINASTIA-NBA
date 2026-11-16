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

/// Contraste mínimo (WCAG AA para texto) de los LED contra cualquier superficie donde se pinten.
const contrasteLedMinimo = 4.5;

/// Las superficies donde el color LED se pinta de verdad: el fondo de pantalla, las tarjetas
/// (`surfaceContainerLow`), los paneles medios y los diálogos y menús (`surfaceContainerHigh`).
/// El tablero (`surfaceContainerLowest`) es la más oscura y siempre queda cubierta.
List<Color> superficiesDeLed(ColorScheme e) => [
  e.surface,
  e.surfaceContainerLow,
  e.surfaceContainer,
  e.surfaceContainerHigh,
  e.surfaceContainerHighest,
];

/// Color de los LED según la regla del panel (≥ 4.5:1 contra el tablero). Manda el color principal
/// del equipo (verde Celtics, azul Knicks), aclarado si hace falta; si es negro/gris o habría que
/// aclararlo tanto que pierde identidad (púrpura Lakers, azul Warriors), se usa el secundario.
Color _ledSobrePanel(Franquicia f) {
  final principal = Color(f.colorPrimario);
  final (ledPrincipal, aclarado) = _legible(principal);
  if (HSLColor.fromColor(principal).saturation > 0.25 && aclarado <= 0.2) return ledPrincipal;
  final (ledSecundario, _) = _legible(Color(f.colorSecundario));
  return _contraste(ledSecundario, _panel) >= 4.5 ? ledSecundario : ledPrincipal;
}

ColorScheme _esquema(Franquicia f, Color led) {
  final sobreLed = _contraste(led, Colors.black) >= _contraste(led, Colors.white) ? Colors.black : Colors.white;
  final superficie = Color.alphaBlend(Color(f.colorPrimario).withValues(alpha: 0.06), _panel);
  return ColorScheme.fromSeed(
    seedColor: led,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(primary: led, onPrimary: sobreLed, surface: superficie, surfaceContainerLowest: _panel);
}

final _ledCacheado = <String, Color>{};

/// Color de los LED encendidos de la franquicia: se lee (≥ 4.5:1) sobre el tablero y también sobre
/// cada superficie donde se pinta ([superficiesDeLed]: tarjetas, diálogos, menús). Si la superficie
/// más clara lo exige, se aclara de a 2% de luminosidad HSL hasta llegar.
Color colorLed(Franquicia f) => _ledCacheado.putIfAbsent('${f.id}:${f.colorPrimario}:${f.colorSecundario}', () {
  var hsl = HSLColor.fromColor(_ledSobrePanel(f));
  while (hsl.lightness < 0.97) {
    final e = _esquema(f, hsl.toColor());
    if (superficiesDeLed(e).every((s) => _contraste(hsl.toColor(), s) >= contrasteLedMinimo)) break;
    hsl = hsl.withLightness((hsl.lightness + 0.02).clamp(0, 1));
  }
  return hsl.toColor();
});

/// Tema Material 3 teñido por la franquicia: el panel toma un 6% del color principal.
ThemeData temaFranquicia(Franquicia f) {
  final esquema = _esquema(f, colorLed(f));
  final superficie = esquema.surface;

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
