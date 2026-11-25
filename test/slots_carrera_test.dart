import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/copia.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(8));
  final carrera = CarreraJugador(liga);
  final creado = JugadorCreado(
    nombre: 'Ana Solé',
    posicion: Posicion.base,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
  );
  Temporada original() {
    final e = carrera.estadoCreado(raiz: '1700000000123456', creado: creado, pick: 4, franquiciaId: 'CHI');
    return carrera.nuevaCarrera(estado: e, dificultad: Dificultad.normal);
  }

  test('duplicar una carrera: mismo jugador, id y raíz nuevos, sigue siendo de verdad y no toca la original', () {
    final t = original();
    final d = partidaDuplicada(t, idNuevo: '1800000000999999');
    final a = EstadoCarrera.de(t)!, b = EstadoCarrera.de(d)!;
    expect(d.id, isNot(t.id));
    expect(b.raiz, '1800000000999999');
    expect(b.jugadorId, isNot(a.jugadorId));
    expect(b.nombre, a.nombre);
    expect(b.media, a.media);
    expect(d.importada, isFalse);
    expect(d.origenId, isNull);
    expect(a.raiz, '1700000000123456');
  });

  test('duplicar una partida de exhibición deja la copia también de exhibición', () {
    final imp = partidaImportada(original().toJson(), idNuevo: '1800000000111111');
    expect(imp.importada, isTrue);
    expect(partidaDuplicada(imp, idNuevo: '1800000000222222').importada, isTrue);
  });

  test('exportar e importar una carrera conserva al jugador y deja la importada de exhibición', () {
    final t = original();
    final json = jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>;
    final i = partidaImportada(json);
    expect(EstadoCarrera.de(i)!.nombre, 'Ana Solé');
    expect(i.importada, isTrue);
    expect(i.modoJuego, ModoJuego.carreraJugador);
  });
}
