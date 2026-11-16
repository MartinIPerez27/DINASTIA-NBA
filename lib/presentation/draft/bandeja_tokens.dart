import 'package:flutter/material.dart';

import '../../domain/tokens_draft.dart';
import '../widgets/texto_led.dart';

/// Ícono y rótulo corto de cada token en la bandeja.
IconData iconoToken(TokenDraft k) => switch (k) {
  TokenDraft.volverATirar => Icons.replay,
  TokenDraft.mejorVersion => Icons.trending_up,
  TokenDraft.doble => Icons.filter_2_outlined,
  TokenDraft.intercambio => Icons.swap_horiz,
  TokenDraft.comodin => Icons.auto_awesome,
};

String rotuloCorto(TokenDraft k) => switch (k) {
  TokenDraft.volverATirar => 'OTRA VEZ',
  TokenDraft.mejorVersion => 'VERSIÓN',
  TokenDraft.doble => 'DOBLE',
  TokenDraft.intercambio => 'CAMBIO',
  TokenDraft.comodin => 'COMODÍN',
};

/// Monedas del jugador: moneda + cifra en LED. Va en la barra del draft y en las hojas de pago.
class Monedero extends StatelessWidget {
  const Monedero(this.monedas, {super.key, this.tamano = 20});

  final int monedas;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      label: '$monedas monedas',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_outlined, size: tamano, color: esquema.onSurfaceVariant),
            const SizedBox(width: 4),
            TextoLed('$monedas', tamano: tamano),
          ],
        ),
      ),
    );
  }
}

/// La bandeja de tokens del draft ("El Marcador"): una ficha por token con su estado: **gratis**
/// (borde y rótulo encendidos), **disponible** (con su precio), **caro** (el precio en rojo: no
/// alcanzan las monedas), **bloqueado** (todavía no se puede) y **agotado**. Tocar una ficha la
/// usa; si no se puede, la pantalla explica por qué.
class BandejaTokens extends StatelessWidget {
  const BandejaTokens({
    super.key,
    required this.tokens,
    required this.estado,
    required this.precio,
    required this.usosRestantes,
    required this.onUsar,
  });

  final List<TokenDraft> tokens;
  final EstadoToken Function(TokenDraft) estado;

  /// Precio del próximo uso (0 = gratis, null = agotado).
  final int? Function(TokenDraft) precio;
  final int Function(TokenDraft) usosRestantes;
  final ValueChanged<TokenDraft> onUsar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (i, k) in tokens.indexed) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _FichaToken(
                  token: k,
                  estado: estado(k),
                  precio: precio(k),
                  restantes: usosRestantes(k),
                  onTap: () => onUsar(k),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FichaToken extends StatelessWidget {
  const _FichaToken({
    required this.token,
    required this.estado,
    required this.precio,
    required this.restantes,
    required this.onTap,
  });

  final TokenDraft token;
  final EstadoToken estado;
  final int? precio;
  final int restantes;
  final VoidCallback onTap;

  static String descripcionEstado(EstadoToken e, int? precio) => switch (e) {
    EstadoToken.gratis => 'gratis',
    EstadoToken.disponible => 'cuesta $precio monedas',
    EstadoToken.caro => 'cuesta $precio monedas y no te alcanzan',
    EstadoToken.bloqueado => 'todavía no se puede usar',
    EstadoToken.agotado => 'agotado',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final activo = estado == EstadoToken.gratis || estado == EstadoToken.disponible;
    final apagado = estado == EstadoToken.agotado || estado == EstadoToken.bloqueado;
    final colorBorde = switch (estado) {
      EstadoToken.gratis || EstadoToken.disponible => esquema.primary,
      EstadoToken.caro => esquema.error.withValues(alpha: 0.7),
      _ => esquema.outlineVariant.withValues(alpha: 0.5),
    };
    final colorTexto = apagado ? esquema.onSurfaceVariant.withValues(alpha: 0.6) : esquema.onSurface;
    final multi = restantes > 1 && estado != EstadoToken.gratis ? ' ×$restantes' : '';

    final Widget pie = switch (estado) {
      EstadoToken.agotado => Text(
        'AGOTADO',
        maxLines: 1,
        style: tema.textTheme.labelSmall?.copyWith(
          color: colorTexto,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          decoration: TextDecoration.lineThrough,
          fontSize: 10,
        ),
      ),
      EstadoToken.gratis => Text(
        restantes > 1 ? 'GRATIS ×$restantes' : 'GRATIS',
        maxLines: 1,
        style: tema.textTheme.labelSmall?.copyWith(
          color: esquema.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontSize: 10,
        ),
      ),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextoLed(
            '${precio ?? '—'}',
            tamano: 14,
            color: estado == EstadoToken.caro ? esquema.error : (apagado ? colorTexto : null),
          ),
          if (multi.isNotEmpty)
            Text(multi, style: tema.textTheme.labelSmall?.copyWith(color: colorTexto, fontSize: 10)),
        ],
      ),
    };

    return Semantics(
      button: true,
      enabled: activo,
      label: '${token.nombre}, ${descripcionEstado(estado, precio)}',
      child: ExcludeSemantics(
        child: Material(
          color: activo ? esquema.primary.withValues(alpha: 0.10) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colorBorde, width: activo ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconoToken(token), size: 16, color: activo ? esquema.primary : colorTexto),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rotuloCorto(token),
                        maxLines: 1,
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: colorTexto,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(fit: BoxFit.scaleDown, child: pie),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
