import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/metajuego.dart';
import '../../domain/entities/perfil.dart';
import '../partido/cancha_partido.dart';

/// Cómo se ven los cosméticos elegidos en el vestuario (pase de temporada y nivel de entrenador).
/// Con lo de fábrica, todo queda exactamente como siempre.
abstract final class Vestuario {
  static Cosmetico _elegido(CategoriaCosmetico c, [PerfilEntrenador? p]) => (p ?? perfilApp.value).metajuego.elegido(c);

  static EstiloCancha cancha([PerfilEntrenador? p]) =>
      estiloDe(_elegido(CategoriaCosmetico.cancha, p), _elegido(CategoriaCosmetico.pelota, p));

  static EstiloCancha estiloDe(Cosmetico cancha, Cosmetico pelota) {
    final (superficie, madera, pintura) = switch (cancha) {
      Cosmetico.canchaSetentas => (SuperficieCancha.parquet, const Color(0xFF8A5A2E), 0.78),
      Cosmetico.canchaCuadros => (SuperficieCancha.cuadros, const Color(0xFFA9774A), 1.0),
      Cosmetico.canchaBarrio => (SuperficieCancha.cemento, const Color(0xFF7D8186), 0.7),
      _ => (SuperficieCancha.parquet, const Color(0xFFA2724A), 1.0),
    };
    final (colores, costura) = switch (pelota) {
      Cosmetico.pelotaAba => (const [Color(0xFFD7263D), Color(0xFFF4F4F4), Color(0xFF1B4D9B)], const Color(0xFF1A1A1A)),
      Cosmetico.pelotaDorada => (const [Color(0xFFE2B33C)], const Color(0xFF5A3E08)),
      _ => (const [Color(0xFFE8792B)], const Color(0xFF3A1A08)),
    };
    final defecto = cancha == Cosmetico.canchaModerna && pelota == Cosmetico.pelotaClasica;
    return EstiloCancha(
      id: defecto ? 'moderna' : cancha.name,
      superficie: superficie,
      madera: madera,
      opacidadPintura: pintura,
      pelota: colores,
      costura: costura,
    );
  }

  /// Color de los LED: null = el de la franquicia (lo de siempre).
  static Color? led([PerfilEntrenador? p]) => ledDe(_elegido(CategoriaCosmetico.led, p));

  static Color? ledDe(Cosmetico c) => switch (c) {
    Cosmetico.ledAmbar => const Color(0xFFFFA726),
    Cosmetico.ledVerde => const Color(0xFF39FF6A),
    Cosmetico.ledHielo => const Color(0xFF7FDBFF),
    Cosmetico.ledOro => const Color(0xFFFFD54F),
    _ => null,
  };

  /// Camiseta propia (relleno, número) según el uniforme elegido; null = la titular de siempre.
  static (Color, Color)? uniforme(Color primario, Color secundario, [PerfilEntrenador? p]) =>
      uniformeDe(_elegido(CategoriaCosmetico.uniforme, p), primario, secundario);

  static (Color, Color)? uniformeDe(Cosmetico c, Color primario, Color secundario) => switch (c) {
    Cosmetico.uniformeAlternativo => (secundario, primario),
    Cosmetico.uniformeClasico => (const Color(0xFFF1E6CC), primario),
    _ => null,
  };
}
