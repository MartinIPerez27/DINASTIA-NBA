import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final creado = JugadorCreado(
    nombre: 'Lucía Gómez',
    posicion: Posicion.alero,
    rol: RolCancha.anotadorTresNiveles,
    fuertes: const [Atributo.tiro, Atributo.finalizacion, Atributo.iq],
  );

  test('cada premio tiene su valor y la temporada tiene tope', () {
    expect(PremiosCarrera.puntos('MVP'), 4);
    expect(PremiosCarrera.puntos('Jugador de la semana'), 0.25);
    expect(PremiosCarrera.puntos('Jugador de la semana ×4'), 1.0);
    expect(PremiosCarrera.puntos('Jugador del mes ×3'), 3.0);
    expect(PremiosCarrera.puntos('Novato del año'), greaterThan(PremiosCarrera.puntos('Quinteto de novatos 2.º equipo')));
    expect(PremiosCarrera.puntos('All-NBA 1.º equipo'), greaterThan(PremiosCarrera.puntos('All-NBA 3.º equipo')));
    expect(PremiosCarrera.puntos('Algo nuevo'), 1);
    expect(PremiosCarrera.puntosDe(['MVP', 'Defensor del Año', 'MVP de las Finales', 'Novato del año', 'Clutch Player']), 12);
  });

  /// Juega la temporada completa y devuelve el estado cerrado.
  (EstadoCarrera, CierreTemporada, Temporada) temporada(int potenciaAtributos, int semilla) {
    final liga = Liga(catalogo, franquicias, azar: Random(semilla));
    final carrera = CarreraJugador(liga);
    var e0 = carrera.estadoCreado(raiz: 'pr$semilla', creado: creado, pick: 3, franquiciaId: 'DAL', potencial: 99);
    e0 = e0.copyWith(
      atributos: Atributos.de(
        tiro: potenciaAtributos,
        finalizacion: potenciaAtributos,
        defensa: potenciaAtributos,
        fisico: potenciaAtributos,
        iq: potenciaAtributos,
      ),
    );
    var t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
    }
    t = liga.simularRestoPlayoffs(liga.simularOtrosHasta(carrera.alGuardar(t), 1 << 30));
    t = carrera.alGuardar(t);
    final e = EstadoCarrera.de(t)!;
    final c = carrera.cerrar(t, e, (id) => franquiciaPorId(id).nombreCompleto);
    return (e, c, t);
  }

  test('un crack gana premios en su primera temporada; uno de rotación casi ninguno', () {
    final (eAlto, cAlto, _) = temporada(97, 1);
    final (eBajo, cBajo, _) = temporada(45, 2);
    expect((eAlto.uso['sc:semana'] ?? 0) + (eAlto.uso['sc:mes'] ?? 0), greaterThan(0), reason: 'semana o mes');
    expect(cAlto.temporada.premios, isNotEmpty);
    expect(cAlto.temporada.premios.any((p) => p.startsWith('Novato') || p.startsWith('Quinteto de novatos')), isTrue);
    expect(cBajo.temporada.premios.where((p) => !p.startsWith('Novato del mes')), isEmpty);
    expect(cAlto.phPremios, greaterThan(cBajo.phPremios));
    expect((eBajo.uso['sc:semana'] ?? 0), 0);
  });

  test('el cierre no repite premios y es determinístico', () {
    final (_, c1, _) = temporada(92, 3);
    final (_, c2, _) = temporada(92, 3);
    expect(c1.temporada.premios, c2.temporada.premios);
    expect(c1.temporada.premios.toSet().length, c1.temporada.premios.length);
  });

  test('el jugador del mes cuenta para el objetivo y la semana se reinicia cada cuatro partidos', () {
    final liga = Liga(catalogo, franquicias, azar: Random(4));
    final carrera = CarreraJugador(liga);
    final (e, _, t) = temporada(97, 4);
    expect(carrera.marca(t, e).jugadorDelMes, e.uso['sc:mes'] ?? 0);
    expect(e.uso['sem:n'] ?? 0, lessThan(PremiosCarrera.partidosPorSemana));
  });
}
