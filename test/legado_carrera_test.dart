import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/estilo_creado.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga([...catalogo], franquicias, azar: Random(9));
  final carrera = CarreraJugador(liga);

  TemporadaJugador anio(int n, {bool campeon = false, bool allStar = true, int media = 88}) => TemporadaJugador(
    numero: n,
    etiqueta: '20${26 + n}',
    franquiciaId: 'CHI',
    edad: 20 + n,
    media: media,
    pj: 75,
    pts: 26,
    reb: 7,
    ast: 6,
    victorias: 52,
    derrotas: 30,
    resultado: '',
    campeon: campeon,
    allStar: allStar,
    premios: n.isEven ? const ['MVP'] : const [],
  );

  EstadoCarrera retirado({int anios = 12}) {
    final e = carrera.estadoCreado(
      raiz: 'lg1',
      creado: JugadorCreado(
        nombre: 'Marcos Ibáñez',
        posicion: Posicion.alero,
        rol: RolCancha.especialista3D,
        fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
        estilo: const EstiloCreado(pais: 6),
      ),
      pick: 3,
      franquiciaId: 'CHI',
    );
    return e.copyWith(historial: [for (var n = 1; n <= anios; n++) anio(n, campeon: n % 3 == 0)], retirado: true, edad: 34);
  }

  test('la carta de carrera lleva tu pico, un nivel según tu legado y sobrevive al JSON', () {
    final e = retirado();
    final c = CartaCarrera.deRetiro(e);
    expect(c.id, 'cc-lg1');
    expect(c.nombre, 'Marcos Ibáñez');
    expect(c.media, greaterThanOrEqualTo(88));
    expect(c.tier, anyOf(Tier.s, Tier.sPlus), reason: 'carrera de Salón');
    expect(c.nbaPlayerId, greaterThan(9000000));
    final vuelta = Jugador.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(vuelta.id, c.id);
    expect(vuelta.media, c.media);
    final flojo = CartaCarrera.deRetiro(e.copyWith(historial: [anio(1, allStar: false, media: 70)]));
    expect(flojo.tier.index, lessThan(c.tier.index));
  });

  test('el perfil guarda las cartas de carrera y las devuelve', () {
    final c = CartaCarrera.deRetiro(retirado());
    final p = const PerfilEntrenador().copyWith(cartasCarrera: [c.toJson()], coleccion: {c.id});
    final de = PerfilEntrenador.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(de.cartasCarrera, hasLength(1));
    expect(de.coleccion, contains(c.id));
    expect(const PerfilEntrenador().toJson().containsKey('cartasCarrera'), isFalse);
  });

  test('la liga suma la carta una sola vez y la encuentra por id', () {
    final c = CartaCarrera.deRetiro(retirado());
    final antes = liga.catalogo.length;
    expect(liga.agregarCartaPropia(c), isTrue);
    expect(liga.agregarCartaPropia(c), isFalse);
    expect(liga.catalogo.length, antes + 1);
  });

  group('carrera generacional', () {
    test('solo se hereda con una carrera retirada de 5 temporadas o más', () {
      expect(HerederoCarrera.puede(retirado()), isTrue);
      expect(HerederoCarrera.puede(retirado(anios: 3)), isFalse);
      expect(HerederoCarrera.puede(retirado().copyWith(retirado: false)), isFalse);
    });

    test('el heredero lleva el apellido y el país, y arranca con la fama de la familia', () {
      final padre = retirado().copyWith(fans: 80);
      final h = HerederoCarrera.de(padre);
      expect(h.creado.nombre, endsWith('Ibáñez'));
      expect(h.creado.nombre, isNot('Marcos Ibáñez'));
      expect(h.creado.estilo!.pais, 6);
      expect(h.creado.posicion, padre.posicion);
      expect(h.anio, padre.anioCierre + 4);
      expect(h.pick, 3, reason: 'hijo de una leyenda: pick alto');
      expect(h.potencial, inInclusiveRange(82, 96));
      final e = h.estado(carrera, 'hijo1', padre.nombre);
      expect(e.fans, greaterThan(HerederoCarrera.de(padre.copyWith(fans: 0)).estado(carrera, 'hijo2', padre.nombre).fans));
      expect(e.hitos.last, contains('sigue los pasos de Marcos Ibáñez'));
      final t = carrera.nuevaCarrera(estado: e, dificultad: Dificultad.normal);
      expect(EstadoCarrera.de(t)!.nombre, h.creado.nombre);
      // Determinista.
      expect(HerederoCarrera.de(padre).creado.nombre, h.creado.nombre);
    });
  });
}
