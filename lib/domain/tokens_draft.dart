import 'entities/modo_juego.dart';
import 'entities/perfil.dart';
import 'entities/temporada.dart';
import 'entities/tokens_temporada.dart';

export 'entities/tokens_temporada.dart';

/// Cómo se consiguen los tokens en una partida.
enum ModoTokens {
  /// Extremo: sin tokens ni fichas.
  ninguno,

  /// Modos con draft prestado (espejo, Dinastía…): solo las fichas gratis de volver a tirar.
  soloReroll,

  /// Retos y Desafío del día: un kit fijo y gratis, igual para todos (nada cuesta monedas).
  kit,

  /// Temporada 82-0: tokens de pago con monedas del juego.
  monedas,
}

/// Ventajas de nivel del entrenador que tocan los tokens (se leen del perfil al abrir el draft).
class VentajasTokens {
  const VentajasTokens({this.descuento = 0, this.versionGratis = false});

  factory VentajasTokens.de(PerfilEntrenador p) => VentajasTokens(
    descuento: p.tiene(Ventaja.descuentoTokens) ? 20 : 0,
    versionGratis: p.tiene(Ventaja.versionGratis),
  );

  static const ninguna = VentajasTokens();

  /// Porcentaje que se descuenta de todos los precios.
  final int descuento;

  /// Un uso de «Mejor versión» gratis por draft.
  final bool versionGratis;
}

/// Estado de un token para la bandeja.
enum EstadoToken {
  /// Se puede usar y no cuesta monedas.
  gratis,

  /// Se puede usar pagando.
  disponible,

  /// Hay usos, pero no alcanzan las monedas.
  caro,

  /// Ya se usó el máximo de este draft (o este modo no lo trae).
  agotado,

  /// Todavía no se puede usar (no hay tirada, plantel vacío…).
  bloqueado,
}

/// Reglas y precios de los tokens del draft.
///
/// **Economía** (monedas: 10 por victoria, 3 por derrota, 15/5 en playoffs, 50 por logro, hasta 250
/// por el campeonato → una temporada clásica rinde unas 600–1.000; un sobre común cuesta 150):
///
/// | Token           | Gratis                  | Precio (monedas)                    | Tope por draft |
/// |-----------------|-------------------------|-------------------------------------|----------------|
/// | Volver a tirar  | 1 (2 con nivel 3)       | 50 · 100 · 200 · 400                | 4 de pago      |
/// | Mejor versión   | 1 con nivel 20          | 150 · 300                           | 2              |
/// | Doble           | no                      | 200                                 | 1              |
/// | Intercambio     | no                      | 250 + 10 por punto de media ganado (máx. 400) | 1   |
/// | Comodín         | no                      | 120                                 | 1              |
///
/// Además hay un tope de [topeGastoPorDraft] monedas en tokens por draft. El nivel 10 descuenta 20 %.
/// En retos y en el Desafío del día no se cobra nada: el kit es fijo para todos.
class ReglasTokens {
  const ReglasTokens._();

  /// Fichas gratis de volver a tirar en retos y Desafío del día (igual para todos).
  static const rerollsKit = 2;

  /// Monedas máximas que se pueden gastar en tokens en un solo draft.
  static const topeGastoPorDraft = 800;

  static const _preciosReroll = [50, 100, 200, 400];
  static const _preciosVersion = [150, 300];
  static const preciosFijos = {
    TokenDraft.doble: [200],
    TokenDraft.comodin: [120],
  };

  /// Intercambio: precio base, monedas por punto de media que sube y tope.
  static const intercambioBase = 250, intercambioPorPunto = 10, intercambioMax = 400;

  static ModoTokens modoDe(Temporada t) => switch (t.modoJuego) {
    ModoJuego.extremo => ModoTokens.ninguno,
    ModoJuego.clasico => ModoTokens.monedas,
    ModoJuego.reto || ModoJuego.desafioDelDia => ModoTokens.kit,
    _ => ModoTokens.soloReroll,
  };

  /// Usos que trae el token en este draft sin contar las fichas gratis de volver a tirar
  /// (esas son `Temporada.rerollsRestantes`): kit o de pago.
  static int tope(Temporada t, TokenDraft k) => switch ((modoDe(t), k)) {
    (ModoTokens.monedas, TokenDraft.volverATirar) => _preciosReroll.length,
    (ModoTokens.monedas, TokenDraft.mejorVersion) => _preciosVersion.length,
    (ModoTokens.monedas, _) => 1,
    (ModoTokens.kit, TokenDraft.mejorVersion || TokenDraft.doble) => t.modoJuego == ModoJuego.desafioDelDia ? 1 : 0,
    _ => 0,
  };

  /// Usos del token sin costo en este draft, además de las fichas de volver a tirar.
  static int gratis(Temporada t, TokenDraft k, VentajasTokens v) => switch ((modoDe(t), k)) {
    (ModoTokens.kit, _) => tope(t, k),
    (ModoTokens.monedas, TokenDraft.mejorVersion) when v.versionGratis => 1,
    _ => 0,
  };

  /// Precio base del próximo uso de pago ([n] = pagos anteriores). Null si no hay más.
  static int? precioBase(TokenDraft k, int n) {
    final lista = switch (k) {
      TokenDraft.volverATirar => _preciosReroll,
      TokenDraft.mejorVersion => _preciosVersion,
      TokenDraft.intercambio => const [intercambioBase],
      _ => preciosFijos[k]!,
    };
    return n < lista.length ? lista[n] : null;
  }

  /// Aplica el descuento de nivel y redondea a múltiplos de 5.
  static int conDescuento(int precio, VentajasTokens v) =>
      v.descuento == 0 ? precio : (precio * (100 - v.descuento) / 100 / 5).round() * 5;

  /// Cuánto cuesta el intercambio según cuánto sube la media (la que baja o empata no suma).
  static int precioIntercambio(int mediaQueSale, int mediaQueEntra) =>
      (intercambioBase + intercambioPorPunto * (mediaQueEntra - mediaQueSale).clamp(0, 99)).clamp(
        intercambioBase,
        intercambioMax,
      );
}
