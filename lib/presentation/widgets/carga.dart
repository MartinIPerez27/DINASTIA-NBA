import 'dart:async';

import 'package:flutter/material.dart';

/// Espera [trabajo] y, si tarda más de [demora], muestra un indicador de carga encima de la
/// pantalla hasta que termina (así no parece que el toque no hizo nada). Si es rápido, no parpadea.
Future<T> conCarga<T>(
  NavigatorState navegador,
  Future<T> trabajo, {
  String texto = 'Cargando…',
  Duration demora = const Duration(milliseconds: 250),
}) async {
  ModalRoute<void>? ruta;
  final reloj = Timer(demora, () {
    if (!navegador.mounted) return;
    ruta = DialogRoute<void>(
      context: navegador.context,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: _Cargando(texto)),
    );
    navegador.push(ruta!);
  });
  try {
    return await trabajo;
  } finally {
    reloj.cancel();
    if (ruta case final r? when r.isActive && navegador.mounted) navegador.removeRoute(r);
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        label: texto,
        child: Material(
          color: tema.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 16),
                Text(texto, style: tema.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
