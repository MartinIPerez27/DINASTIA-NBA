import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(21));
  final progreso = Progreso(liga);
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final inicio = liga.iniciar(Temporada(id: 't1', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));

  test('nivel: 0, 150, 450, 900 XP', () {
    expect(const PerfilEntrenador().nivel, 1);
    expect(const PerfilEntrenador(xp: 149).nivel, 1);
    expect(const PerfilEntrenador(xp: 150).nivel, 2);
    expect(const PerfilEntrenador(xp: 900).nivel, 4);
    expect(const PerfilEntrenador(xp: 450).fichasExtra, 1);
  });

  test('partidos jugados dan XP, monedas, puntaje y el primer logro', () {
    var t = inicio;
    for (var i = 0; i < 10; i++) {
      t = liga.simularProximo(t);
    }
    final (perfil, novedades) = progreso.aplicar(const PerfilEntrenador(), inicio, t);
    expect(perfil.xp, greaterThan(0));
    expect(perfil.monedas, greaterThan(0));
    expect(perfil.puntaje, isNot(1000));
    expect(perfil.logros.keys, contains(Logro.primeraVictoria));
    expect(novedades.map((n) => n.titulo), contains(startsWith('+')));
    // Otra temporada (otro id) no cuenta como continuación.
    expect(progreso.aplicar(perfil, inicio, Temporada(id: 'otra', franquiciaUsuarioId: 'CHI')).$2, isEmpty);
  });

  test('cerrar la temporada llena el Salón, la vitrina y la carrera, una sola vez', () {
    var t = inicio;
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
    }
    final regular = liga.simularOtrosHasta(t, 1 << 30);
    final fin = liga.simularRestoPlayoffs(regular);
    var (perfil, _) = progreso.aplicar(const PerfilEntrenador(), inicio, regular);
    final (cerrado, novedades) = progreso.aplicar(perfil, regular, fin);
    perfil = cerrado;
    expect(perfil.temporadasCerradas, contains('t1'));
    expect(perfil.historial, hasLength(1));
    expect(perfil.historial.first.victorias, regular.registroUsuario.victorias);
    expect(perfil.carrera.keys.toSet(), {for (final j in fin.plantel.jugadores) j.id});
    expect(novedades.any((n) => n.titulo.startsWith('Temporada cerrada')), isTrue);
    if (fin.campeonId == 'CHI') {
      expect(perfil.trofeos.map((t) => t.tipo), containsAll([TipoTrofeo.anillo, TipoTrofeo.larryOBrien]));
    }
    // Volver a guardar la misma temporada terminada no premia de nuevo.
    final (otraVez, nada) = progreso.aplicar(perfil, fin, fin);
    expect(otraVez.historial, hasLength(1));
    expect(nada, isEmpty);
    // Y el perfil sobrevive a guardarse y leerse.
    final copia = PerfilEntrenador.fromJson(perfil.toJson());
    expect(
      (copia.xp, copia.monedas, copia.puntaje, copia.historial.length, copia.carrera.length),
      (perfil.xp, perfil.monedas, perfil.puntaje, perfil.historial.length, perfil.carrera.length),
    );
    expect(copia.logros.keys.toSet(), perfil.logros.keys.toSet());
  });
}
