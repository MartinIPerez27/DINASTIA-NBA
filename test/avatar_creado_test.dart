import 'dart:convert';

import 'package:dinastia_nba/domain/entities/avatar_creado.dart';
import 'package:dinastia_nba/domain/entities/estilo_creado.dart';
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
    const a = AvatarCreado(
      piel: 4, pelo: 7, estilo: 15, barba: 4, ancho: 8, alto: 0,
      ojos: 3, cejas: 4, nariz: 2, boca: 2, orejas: 2, tatuaje: 3, gafas: 2, cinta: true, cuerpo: 4,
    );
    final b = AvatarCreado.deCodigo(a.codigo)!;
    expect((b.piel, b.pelo, b.estilo, b.barba, b.ancho, b.alto), (4, 7, 15, 4, 8, 0));
    expect((b.ojos, b.cejas, b.nariz, b.boca, b.orejas, b.tatuaje, b.gafas, b.cinta, b.cuerpo), (3, 4, 2, 2, 2, 3, 2, true, 4));
    expect(b.codigo, a.codigo);
    expect(AvatarCreado.deCodigo(null), isNull);
    final raro = AvatarCreado.deCodigo('99.-3.x')!;
    expect(raro.piel, AvatarCreado.pieles - 1);
    expect(raro.pelo, 0);
    expect(raro.estilo, const AvatarCreado().estilo);
  });

  test('el avatar viaja con el jugador creado, la carta y el guardado', () {
    const a = AvatarCreado(piel: 5, pelo: 6, estilo: 3, barba: 1, gafas: 1);
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
    final p = PerfilAvatar.creado(const AvatarCreado(piel: 0, pelo: 6, estilo: 5, barba: 3, ancho: 0, alto: 7, ojos: 2));
    expect(p.piel, PerfilAvatar.pieles[0]);
    expect(p.pelo, PerfilAvatar.pelosCreador[6]);
    expect(p.estilo, PeloEstilo.largo);
    expect(p.barba, isFalse, reason: 'el pelo largo no lleva barba');
    expect(p.conRostro, isTrue);
    expect(p.ojos, 2);
    expect(p.anchoCabeza, closeTo(0.92, 1e-9));
    expect(p.altoCabeza, closeTo(1.09, 1e-9));
  });

  test('un código viejo (solo seis rasgos) carga con el rostro por defecto, y el retrato automático no cambia', () {
    final v = AvatarCreado.deCodigo('3.2.4.1.5.2')!;
    expect((v.piel, v.pelo, v.estilo, v.barba), (3, 2, 4, 1));
    const d = AvatarCreado();
    expect((v.ojos, v.cejas, v.nariz, v.boca, v.gafas, v.cuerpo), (d.ojos, d.cejas, d.nariz, d.boca, d.gafas, d.cuerpo));
    // El retrato automático solo usa los siete peinados de siempre y sigue siendo una silueta.
    for (var i = 0; i < 300; i++) {
      final p = PerfilAvatar.de('jugador-$i');
      expect(p.estilo.index, lessThan(PeloEstilo.automaticos));
      expect(p.conRostro, isFalse);
    }
  });

  test('hay 20 peinados, 7 barbas y los rasgos nuevos tienen nombre', () {
    expect(AvatarCreado.nombresEstilo.length, AvatarCreado.estilos);
    expect(PeloEstilo.values.length, AvatarCreado.estilos);
    expect(AvatarCreado.nombresBarba.length, AvatarCreado.barbas);
    expect(AvatarCreado.nombresOjos.length, AvatarCreado.ojosN);
    expect(AvatarCreado.nombresCuerpo.length, AvatarCreado.cuerpos);
  });

  test('el estilo de juego viaja con el jugador y la envergadura y el origen mueven al jugador', () {
    final base = creado();
    final largo = JugadorCreado(
      nombre: 'Lucía Gómez',
      posicion: Posicion.alero,
      rol: RolCancha.especialista3D,
      fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
      estilo: const EstiloCreado(envergadura: 12, mano: 1, origen: OrigenJugador.internacional, formaDeTiro: 3, festejo: 4),
    );
    final r = JugadorCreado.fromJson(jsonDecode(jsonEncode(largo.toJson())) as Map<String, dynamic>);
    expect((r.estilo!.envergadura, r.estilo!.mano, r.estilo!.origen, r.estilo!.formaDeTiro, r.estilo!.festejo), (12, 1, OrigenJugador.internacional, 3, 4));
    expect(largo.estadisticas.tapP, greaterThan(base.estadisticas.tapP));
    expect(largo.estadisticas.rpp, greaterThan(base.estadisticas.rpp));
    expect(largo.atributos[Atributo.tiro], base.atributos[Atributo.tiro] + 2, reason: 'internacional: mejor tiro');
    expect(largo.atributos[Atributo.fisico], base.atributos[Atributo.fisico] - 1);
    final corto = JugadorCreado(
      nombre: 'Lucía Gómez',
      posicion: Posicion.alero,
      rol: RolCancha.especialista3D,
      fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
      estilo: const EstiloCreado(envergadura: -8),
    );
    expect(corto.estadisticas.tapP, lessThan(base.estadisticas.tapP));
    expect(EstiloCreado.deCodigo('99.9.9.9.9')!.envergadura, EstiloCreado.envergaduraMax, reason: 'tolera basura');
    expect(base.estilo, isNull, reason: 'los jugadores viejos no cambian');
  });
}
