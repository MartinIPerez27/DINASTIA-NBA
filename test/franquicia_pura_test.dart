import 'dart:io';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  test('Franquicia pura: tiradas y candidatos son solo de tu franquicia', () {
    final d = Draft(catalogo);
    var t = const Temporada(id: 't', franquiciaUsuarioId: 'LAL', regla: ReglaDraft.franquiciaPura);
    expect(d.tiradasPosibles(t).map((x) => x.franquiciaId).toSet(), {'LAL'});
    t = d.tirar(t);
    expect(t.tirada!.franquiciaId, 'LAL');
    expect(d.candidatos(t).every((j) => j.franquiciaId == 'LAL'), isTrue);
  });
}
