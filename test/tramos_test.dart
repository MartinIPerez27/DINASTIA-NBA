import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rival.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/reto.dart';
import 'package:dinastia_nba/domain/version_catalogo.dart';
import 'package:dinastia_nba/domain/versiones.dart';
import 'package:dinastia_nba/presentation/modos/reto.dart';
import 'package:dinastia_nba/presentation/widgets/carta_vertical.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = File(rutaCatalogo).readAsStringSync();
  final catalogo = parsearCatalogo(raw);
  final base = catalogo.firstWhere((j) => j.tier == Tier.sPlus);

  Jugador con((int, int)? temporadas) => Jugador.fromJson({
    ...base.toJson()..remove('temporadas'),
    if (temporadas != null) 'temporadas': [temporadas.$1, temporadas.$2],
  });

  group('tramo de cada carta', () {
    test('formato: mismo siglo, otro siglo, una sola temporada y sin datos', () {
      expect(con((2020, 2023)).tramo, '2020–23');
      expect(con((1985, 1998)).tramo, '1985–98');
      expect(con((1999, 2004)).tramo, '1999–2004');
      expect(con((2025, 2025)).tramo, '2025');
      expect(con(null).tramo, base.epoca.etiqueta);
      expect(con((2020, 2023)).tramoCorto, '20-23');
      expect(con((1998, 2004)).tramoCorto, '98-04');
      expect(con((2024, 2024)).tramoCorto, '2024');
      expect(con(null).tramoCorto, base.epoca.codigo);
      expect(con((2024, 2025)).tramoConEquipo, '${base.equipo} 2024–25');
    });

    test('JSON con y sin temporadas; la copia con otra media las conserva', () {
      final j = con((2020, 2023));
      final ida = Jugador.fromJson(j.toJson());
      expect(ida.temporadas, (2020, 2023));
      expect(j.conMedia(70).temporadas, (2020, 2023));
      expect(j.conMedia(70).media, 70);
      final viejo = Jugador.fromJson({...base.toJson()}..remove('temporadas'));
      expect(viejo.temporadas, isNull);
      expect(viejo.toJson().containsKey('temporadas'), isFalse);
    });

    test('los años 2020 se llaman así (ya no "HOY")', () {
      expect(Epoca.actualidad.etiqueta, 'Años 2020');
      expect(Epoca.actualidad.codigo, '20s');
      expect(Epoca.actualidad.corta, '20’');
      expect(Epoca.actualidad.name, 'actualidad', reason: 'el JSON sigue igual');
    });
  });

  test('NOVATO / PRIME / VETERANO están sin pasar por el draft', () {
    versionesCatalogo = const {};
    Liga(catalogo, franquicias);
    expect(CartaVertical.versiones, isNotEmpty);
    expect(CartaVertical.versiones, calcularVersiones(catalogo));
  });

  group('versión del catálogo', () {
    test('hash estable de 32 bits y distinto si cambia una sola carta', () {
      final v = versionDe(raw);
      expect(v, versionDe(raw));
      expect(v, inInclusiveRange(1, 0xffffffff));
      expect(versionDe(raw.replaceFirst('"media":', '"media": ')), isNot(v));
    });

    test('código de reto con versión: ida y vuelta, y aviso si cambian las cartas', () {
      final c = CodigoReto(
        semilla: 777777,
        franquiciaId: 'CHI',
        modo: ModoDraft.cartas,
        regla: ReglaDraft.libre,
        dificultad: Dificultad.dificil,
        victorias: 64,
        version: 0xAB,
      );
      final leido = CodigoReto.leer(c.codificar())!;
      expect(leido.version, 0xAB);
      expect(leido.semilla, 777777);
      expect(leido.victorias, 64);
      expect(leido.mismoCatalogo(0x1234AB), isTrue);
      expect(avisoCatalogo(leido, versionActual: 0x1234AB), isNull);
      expect(leido.mismoCatalogo(0x1234AC), isFalse);
      expect(avisoCatalogo(leido, versionActual: 0x1234AC), contains('otra versión de las cartas'));
    });

    test('los códigos viejos (sin versión) se siguen leyendo, con un aviso', () {
      const viejo = CodigoReto(
        semilla: (1 << 28) - 5,
        franquiciaId: 'BOS',
        modo: ModoDraft.ruleta,
        regla: ReglaDraft.libre,
        dificultad: Dificultad.normal,
      );
      final leido = CodigoReto.leer(viejo.codificar())!;
      expect(leido.version, isNull);
      expect(leido.semilla, (1 << 28) - 5);
      expect(avisoCatalogo(leido, versionActual: 123), contains('versión anterior'));
      // Una semilla grande con versión no entra en el formato nuevo: se escribe en el viejo.
      final grande = CodigoReto(
        semilla: (1 << 28) - 5,
        franquiciaId: 'BOS',
        modo: ModoDraft.ruleta,
        regla: ReglaDraft.libre,
        dificultad: Dificultad.normal,
        version: 9,
      );
      expect(CodigoReto.leer(grande.codificar())!.version, isNull);
    });

    test('las partidas nuevas tienen semillas de 20 bits y su código lleva la versión', () {
      final datos = Reto.datosNuevos(3, azar: Random(1));
      expect(datos[Reto.claveSemilla] as int, lessThan(CodigoReto.maxSemillaNueva));
      final t = Temporada(id: 'v', franquiciaUsuarioId: 'CHI', datosModo: datos, versionCatalogo: 0xCAFE01);
      expect(Reto.codigoDe(t)!.version, 0x01);
      final copia = Temporada.fromJson(t.copyWith().toJson());
      expect(copia.versionCatalogo, 0xCAFE01);
    });
  });

  test('una partida vieja con una carta que ya no existe no se rompe', () {
    final liga = Liga(catalogo, franquicias, azar: Random(4));
    var p = const Plantel();
    final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    final t = liga.iniciar(Temporada(id: 'vieja', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
    final (id, r) = t.rivales.entries.map((e) => (e.key, e.value)).first;
    final rota = Rival(
      franquiciaId: r.franquiciaId,
      tipo: r.tipo,
      identidadId: r.identidadId,
      epoca: r.epoca,
      tactica: r.tactica,
      cartaIds: {...r.cartaIds, Posicion.pivot: 'noexiste01-${r.franquiciaId}-90'},
    );
    final vieja = Temporada.fromJson(t.copyWith(rivales: {...t.rivales, id: rota}).toJson());
    final plantel = liga.plantelDe(vieja.rivales[id]!);
    expect(plantel.completo, isTrue);
    expect(plantel.en(Posicion.pivot)!.puedeJugarEn(Posicion.pivot), isTrue);
    expect(plantel.en(Posicion.pivot)!.franquiciaId, r.franquiciaId, reason: 'reemplazo de la misma franquicia');
    // Y se puede jugar.
    final x = liga.simularProximo(vieja);
    expect(x.registroUsuario.jugados, 1);
    expect(Draft.franquiciasRivales, isNotEmpty);
  });
}
