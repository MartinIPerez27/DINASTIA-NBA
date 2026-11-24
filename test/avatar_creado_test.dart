import 'dart:convert';

import 'package:dinastia_nba/domain/entities/avatar_creado.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/presentation/widgets/avatar_ilustrado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JugadorCreado creado({AvatarCreado? avatar}) => JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
    avatar: avatar,
  );

  test('el código del avatar ida y vuelta, y tolera basura', () {
    const a = AvatarCreado(piel: 4, pelo: 7, estilo: 5, barba: true, ancho: 8, alto: 0);
    final b = AvatarCreado.deCodigo(a.codigo)!;
    expect((b.piel, b.pelo, b.estilo, b.barba, b.ancho, b.alto), (4, 7, 5, true, 8, 0));
    expect(AvatarCreado.deCodigo(null), isNull);
    final raro = AvatarCreado.deCodigo('99.-3.x')!;
    expect(raro.piel, AvatarCreado.pieles - 1);
    expect(raro.pelo, 0);
    expect(raro.estilo, const AvatarCreado().estilo);
  });

  test('el avatar viaja con el jugador creado, la carta y el guardado', () {
    const a = AvatarCreado(piel: 5, pelo: 6, estilo: 3, barba: true);
    final c = JugadorCreado.fromJson(jsonDecode(jsonEncode(creado(avatar: a).toJson())) as Map<String, dynamic>);
    expect(c.avatar!.codigo, a.codigo);
    final carta = c.comoCarta(id: 'mc-x', franquiciaId: 'CHI');
    expect(carta.avatar, a.codigo);
    expect(Jugador.fromJson(jsonDecode(jsonEncode(carta.toJson())) as Map<String, dynamic>).avatar, a.codigo);
    expect(carta.conMedia(80).avatar, a.codigo);
  });

  test('las partidas viejas (sin avatar) siguen igual', () {
    final c = JugadorCreado.fromJson(creado().toJson());
    expect(c.avatar, isNull);
    expect(c.comoCarta(id: 'mc-x', franquiciaId: 'CHI').avatar, isNull);
  });

  test('el retrato usa los rasgos elegidos', () {
    final p = PerfilAvatar.creado(const AvatarCreado(piel: 0, pelo: 6, estilo: 5, barba: true, ancho: 0, alto: 7));
    expect(p.piel, PerfilAvatar.pieles[0]);
    expect(p.pelo, PerfilAvatar.pelosCreador[6]);
    expect(p.estilo, PeloEstilo.largo);
    expect(p.barba, isFalse, reason: 'el pelo largo no lleva barba');
    expect(p.anchoCabeza, closeTo(0.92, 1e-9));
    expect(p.altoCabeza, closeTo(1.09, 1e-9));
  });
}
