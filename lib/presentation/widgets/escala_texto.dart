import 'package:flutter/material.dart';

/// Tope de la escala de texto del sistema: por encima el tablero (y los LED) se desarman.
const topeEscalaTexto = 1.5;

/// Para `MaterialApp.builder`: respeta la preferencia de tamaño de letra hasta [topeEscalaTexto].
Widget conTopeEscalaTexto(BuildContext context, Widget? child) {
  final datos = MediaQuery.of(context);
  return MediaQuery(
    data: datos.copyWith(textScaler: datos.textScaler.clamp(maxScaleFactor: topeEscalaTexto)),
    child: child ?? const SizedBox.shrink(),
  );
}
