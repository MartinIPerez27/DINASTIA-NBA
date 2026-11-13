import 'package:flutter/material.dart';

/// Ancho desde el que una pantalla apaisada se arma en dos paneles (tablet en horizontal).
const anchoTablet = 900.0;

/// Tablet en horizontal (p. ej. 11" 2K apaisada): ancho ≥ [anchoTablet] y más ancha que alta.
/// En el teléfono (vertical) todo queda como siempre.
bool esTabletApaisada(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.width >= anchoTablet && s.width > s.height;
}

/// Dos paneles lado a lado en tablet apaisada; en el teléfono, [angosto] (o los dos apilados).
class DosPaneles extends StatelessWidget {
  const DosPaneles({
    super.key,
    required this.izquierda,
    required this.derecha,
    this.angosto,
    this.flexIzquierda = 5,
    this.flexDerecha = 6,
    this.separacion = 16,
    this.padding = EdgeInsets.zero,
  });

  final Widget izquierda;
  final Widget derecha;

  /// Lo que se muestra en el teléfono. Si es null, los dos paneles apilados en una columna.
  final Widget? angosto;
  final int flexIzquierda, flexDerecha;
  final double separacion;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (!esTabletApaisada(context)) {
      return angosto ??
          Column(
            children: [
              Expanded(child: izquierda),
              Expanded(child: derecha),
            ],
          );
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: flexIzquierda, child: izquierda),
          SizedBox(width: separacion),
          Expanded(flex: flexDerecha, child: derecha),
        ],
      ),
    );
  }
}

/// Tablet apaisada: centra el contenido con un ancho máximo, para que una lista no quede estirada.
/// En el teléfono devuelve [child] tal cual.
class AnchoMaximo extends StatelessWidget {
  const AnchoMaximo({super.key, required this.child, this.ancho = 760});

  final Widget child;
  final double ancho;

  @override
  Widget build(BuildContext context) => !esTabletApaisada(context)
      ? child
      : Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ancho),
            child: child,
          ),
        );
}
