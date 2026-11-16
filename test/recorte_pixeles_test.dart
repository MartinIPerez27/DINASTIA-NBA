import 'dart:typed_data';

import 'package:dinastia_nba/core/recorte_fotos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recortarPixeles pone la máscara como alfa y recorta a la silueta (parte pura, apta para Isolate)', () {
    const w = 40, h = 60, mw = 20, mh = 30;
    final rgba = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 200);
    // Persona en el centro de la máscara (columnas 6..13, filas 5..24).
    final conf = [
      for (var y = 0; y < mh; y++)
        for (var x = 0; x < mw; x++) (x >= 6 && x <= 13 && y >= 5 && y <= 24) ? 1.0 : 0.0,
    ];
    final r = recortarPixeles(rgba, w, h, conf, mw, mh)!;
    expect(r.ancho, lessThan(w));
    expect(r.alto, lessThan(h));
    expect(r.rgba.length, r.ancho * r.alto * 4);
    // El centro es opaco; la esquina del recorte, casi transparente.
    final centro = ((r.alto ~/ 2) * r.ancho + r.ancho ~/ 2) * 4 + 3;
    expect(r.rgba[centro], 255);
    expect(r.rgba[3], lessThan(40));
  });

  test('sin persona clara (menos del 4 %) devuelve null', () {
    final rgba = Uint8List(40 * 60 * 4);
    final conf = List<double>.filled(20 * 30, 0);
    expect(recortarPixeles(rgba, 40, 60, conf, 20, 30), isNull);
    conf[5 * 20 + 5] = 1; // un pixel suelto de la máscara
    expect(recortarPixeles(Uint8List(40 * 60 * 4), 40, 60, conf, 20, 30), isNull);
  });

  test('recortarConMascara (con Isolate) da un PNG', () async {
    const w = 40, h = 60;
    final rgba = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 180);
    final conf = List<double>.filled(20 * 30, 1);
    final png = await recortarConMascara(rgba, w, h, conf, 20, 30);
    expect(png, isNotNull);
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
