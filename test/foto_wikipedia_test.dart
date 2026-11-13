import 'package:dinastia_nba/core/foto_wikipedia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mini = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Jordan_1990.jpg/320px-Jordan_1990.jpg';
  const original = 'https://upload.wikimedia.org/wikipedia/commons/a/ab/Jordan_1990.jpg';

  test('pide la miniatura grande cuando el original es enorme', () {
    expect(
      fotoGrande({'source': mini}, {'source': original, 'width': 3000}),
      'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Jordan_1990.jpg/960px-Jordan_1990.jpg',
    );
  });

  test('usa el original si es chico, y aguanta datos faltantes', () {
    expect(fotoGrande({'source': mini}, {'source': original, 'width': 700}), original);
    expect(fotoGrande(null, {'source': original}), original);
    expect(fotoGrande(null, null), isNull);
  });
}
