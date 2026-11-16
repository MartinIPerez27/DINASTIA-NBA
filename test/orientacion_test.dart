import 'package:dinastia_nba/core/orientacion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el teléfono queda en vertical y la tablet gira libre', () {
    for (final lado in [320.0, 360.0, 412.0, 430.0, 599.0]) {
      expect(orientacionesPara(lado), [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown], reason: '$lado');
    }
    for (final lado in [600.0, 800.0, 1200.0]) {
      expect(orientacionesPara(lado), DeviceOrientation.values, reason: '$lado');
    }
  });
}
