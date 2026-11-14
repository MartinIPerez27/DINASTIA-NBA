import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/franquicia.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/competitivo.dart';
import 'package:dinastia_nba/domain/modos/escalera.dart';
import 'package:flutter_test/flutter_test.dart';

EquipoTorneo _equipo(int i, {bool usuario = false}) => EquipoTorneo(
  nombre: 'E$i',
  rival: RivalEscalera(identidadId: 'CHI', etiqueta: '', cartaIds: const {}, tactica: const Tactica(), media: 90.0 - i),
  usuario: usuario,
);

/// El de menor índice (mejor sembrado) siempre gana.
(int, int) _simulaSeed(int a, int b, bool aLocal) => a < b ? (100, 90) : (90, 100);

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(7));
  // Un "álbum" generoso: todas las cartas de los Bulls y los Celtics.
  final album = {
    for (final j in catalogo)
      if (j.franquiciaId == 'CHI' || j.franquiciaId == 'BOS') j.id,
  };
  final cartas = mejorAlineacion([
    for (final j in catalogo)
      if (album.contains(j.id)) j,
  ])!;

  group('Divisiones', () {
    test('ascenso, descenso y permanencia', () {
      expect(EstadoDivisiones.cierre(5, 21), (4, MovimientoDivision.asciende));
      expect(EstadoDivisiones.cierre(5, 40), (4, MovimientoDivision.asciende));
      expect(EstadoDivisiones.cierre(5, 20), (5, MovimientoDivision.mantiene));
      expect(EstadoDivisiones.cierre(5, 10), (5, MovimientoDivision.mantiene));
      expect(EstadoDivisiones.cierre(5, 9), (6, MovimientoDivision.desciende));
      expect(EstadoDivisiones.cierre(10, 0), (10, MovimientoDivision.mantiene), reason: 'abajo de todo no se baja');
      expect(EstadoDivisiones.cierre(1, 30), (1, MovimientoDivision.mantiene), reason: 'arriba de todo no se sube');
    });

    test('puntos: 3 por victoria, 4 por paliza, 0 por derrota', () {
      expect(EstadoDivisiones.puntosPartido(100, 90), 3);
      expect(EstadoDivisiones.puntosPartido(115, 100), 4);
      expect(EstadoDivisiones.puntosPartido(90, 100), 0);
    });

    test('los rivales son más duros cuanto más arriba, y más con la dificultad', () {
      for (var d = 10; d > 1; d--) {
        expect(
          EstadoDivisiones.objetivo(d - 1, Dificultad.normal),
          greaterThan(EstadoDivisiones.objetivo(d, Dificultad.normal)),
        );
      }
      expect(
        EstadoDivisiones.objetivo(5, Dificultad.leyenda),
        greaterThan(EstadoDivisiones.objetivo(5, Dificultad.normal)),
      );
    });

    test('una temporada: 10 partidos, se cierra, y arranca la siguiente con rivales nuevos; JSON ida y vuelta', () {
      final m = ModosCompetitivo(liga, azar: Random(3));
      var t = m.nuevaDivisiones(id: 'd', franquiciaId: 'CHI', dificultad: Dificultad.normal, cartas: cartas);
      var e = EstadoDivisiones.de(t)!;
      expect(e.division, 10);
      expect(e.rivales, hasLength(10));
      expect(e.pendiente, isNotNull);
      t = m.simularTemporadaDivisiones(t);
      e = EstadoDivisiones.de(t)!;
      expect(e.marcadores, hasLength(10));
      expect(e.pendiente, isNull);
      expect(e.victorias + e.derrotas, 10);
      final copia = EstadoDivisiones.fromJson(e.toJson());
      expect(copia.marcadores, e.marcadores);
      expect(copia.rivales.first.cartaIds, e.rivales.first.cartaIds);
      final (division, _) = EstadoDivisiones.cierre(10, e.puntos);
      t = m.cerrarTemporadaDivisiones(t);
      e = EstadoDivisiones.de(t)!;
      expect(e.division, division);
      expect(e.temporada, 2);
      expect(e.marcadores, isEmpty);
      expect(e.rivales, hasLength(10));
      expect(e.historial, hasLength(1));
    });

    test('cerrar antes de tiempo no hace nada', () {
      final m = ModosCompetitivo(liga, azar: Random(3));
      final t = m.nuevaDivisiones(id: 'd', franquiciaId: 'CHI', dificultad: Dificultad.normal, cartas: cartas);
      expect(identical(m.cerrarTemporadaDivisiones(t), t), isTrue);
    });
  });

  group('Conquista', () {
    test('el tablero tiene las 30 franquicias, una vez cada una, y es un solo mapa conectado', () {
      final ids = franquicias.where((f) => !f.historica).map((f) => f.id).toSet();
      expect(mapaConquista.keys.toSet(), ids);
      expect(mapaConquista.values.toSet(), hasLength(30), reason: 'ninguna casilla repetida');
      for (final (c, f) in mapaConquista.values) {
        expect(c, inInclusiveRange(0, columnasMapa - 1));
        expect(f, inInclusiveRange(0, filasMapa - 1));
      }
      final visto = <String>{'CHI'};
      final cola = ['CHI'];
      while (cola.isNotEmpty) {
        for (final v in vecinosConquista(cola.removeLast())) {
          if (visto.add(v)) cola.add(v);
        }
      }
      expect(visto, ids, reason: 'desde cualquier territorio se llega a todos');
    });

    test('la adyacencia es simétrica y la conferencia coincide con los datos', () {
      for (final id in mapaConquista.keys) {
        for (final v in vecinosConquista(id)) {
          expect(vecinosConquista(v), contains(id));
        }
        expect(conferenciaDeConquista(id), franquiciaPorId(id).conferencia, reason: id);
      }
    });

    test('solo se ataca a los vecinos; ganar conquista, perder cuesta una vida', () {
      final m = ModosCompetitivo(liga, azar: Random(5));
      var t = m.nuevaConquista(id: 'c', franquiciaId: 'CHI', dificultad: Dificultad.normal, cartas: cartas);
      var e = EstadoConquista.de(t)!;
      expect(e.conquistados, ['CHI']);
      expect(e.atacables, vecinosConquista('CHI').toSet());
      final lejos = mapaConquista.keys.firstWhere((id) => id != 'CHI' && !e.atacables.contains(id));
      expect(identical(m.atacar(t, lejos), t), isTrue, reason: 'un territorio que no es vecino no se ataca');
      final objetivo = e.atacables.first;
      t = m.atacar(t, objetivo);
      e = EstadoConquista.de(t)!;
      expect(e.objetivo, objetivo);
      expect(e.rival, isNotNull);
      t = m.cancelarAtaque(t);
      expect(EstadoConquista.de(t)!.objetivo, isNull);
      // Se juega hasta conquistar o quedarse sin vidas: cada batalla suma o resta algo.
      for (var i = 0; i < 12 && !EstadoConquista.de(t)!.terminada; i++) {
        final ahora = EstadoConquista.de(t)!;
        t = m.atacar(t, ahora.atacables.first);
        t = m.simularConquista(t);
        final despues = EstadoConquista.de(t)!;
        expect(despues.batallas, ahora.batallas + 1);
        expect(
          despues.conquistados.length + despues.derrotas,
          ahora.conquistados.length + ahora.derrotas + 1,
          reason: 'cada batalla es una conquista o una derrota',
        );
      }
      final copia = EstadoConquista.fromJson(EstadoConquista.de(t)!.toJson());
      expect(copia.conquistados, EstadoConquista.de(t)!.conquistados);
    });

    test('condición de victoria (los 30) y de derrota (sin vidas)', () {
      final todos = EstadoConquista(inicio: 'CHI', conquistados: mapaConquista.keys.toList());
      expect(todos.completo, isTrue);
      expect(todos.terminada, isTrue);
      expect(todos.atacables, isEmpty);
      expect(todos.conferenciaCompleta(Conferencia.este, franquicias), isTrue);
      expect(
        const EstadoConquista(inicio: 'CHI', conquistados: ['CHI'], derrotas: EstadoConquista.vidas).terminada,
        isTrue,
      );
      expect(const EstadoConquista(inicio: 'CHI', conquistados: ['CHI'], derrotas: 3).terminada, isFalse);
    });

    test('dominar una división da ventajas: 3 de 5 → +1, las 5 → +2', () {
      final pacifico = [
        for (final f in franquicias)
          if (f.division == Division.pacifico) f.id,
      ];
      var e = EstadoConquista(inicio: 'LAL', conquistados: pacifico.take(2).toList());
      expect(e.bonusPorPuesto(franquicias), isEmpty);
      e = EstadoConquista(inicio: 'LAL', conquistados: pacifico.take(3).toList());
      expect(e.bonusPorPuesto(franquicias)[Posicion.base], 1);
      expect(e.bonusPorPuesto(franquicias)[Posicion.escolta], 1);
      e = EstadoConquista(inicio: 'LAL', conquistados: pacifico);
      expect(e.bonusPorPuesto(franquicias)[Posicion.base], 2);
      expect(e.bonusPorPuesto(franquicias)[Posicion.pivot], isNull);
    });

    test('las cartas de los territorios conquistados se suman a tu álbum', () {
      final m = ModosCompetitivo(liga);
      final e = const EstadoConquista(inicio: 'CHI', conquistados: ['CHI', 'MIA']);
      final pool = m.cartasDisponiblesConquista(e, {catalogo.firstWhere((j) => j.franquiciaId == 'LAL').id});
      expect(pool.where((j) => j.franquiciaId == 'MIA'), isNotEmpty);
      expect(pool.where((j) => j.franquiciaId == 'CHI'), isNotEmpty);
      expect(pool.where((j) => j.franquiciaId == 'LAL'), hasLength(1));
      expect(pool.where((j) => j.franquiciaId == 'BOS'), isEmpty);
    });
  });

  group('Creador de torneos', () {
    test('validación de tamaños por formato', () {
      expect(Torneo.validar(FormatoTorneo.eliminacion, 3), isNotNull);
      expect(Torneo.validar(FormatoTorneo.eliminacion, 32), isNull);
      expect(Torneo.validar(FormatoTorneo.eliminacion, 33), isNotNull);
      expect(Torneo.validar(FormatoTorneo.liga, 16), isNull);
      expect(Torneo.validar(FormatoTorneo.liga, 17), isNotNull);
      expect(Torneo.validar(FormatoTorneo.grupos, 5), isNotNull);
      expect(Torneo.validar(FormatoTorneo.grupos, 6), isNull);
    });

    test('todos contra todos: cada par juega una vez, con cantidad par o impar de equipos', () {
      for (final n in [4, 5, 6, 7, 9, 12]) {
        final fechas = Torneo.todosContraTodos([for (var i = 0; i < n; i++) i]);
        final pares = [for (final f in fechas) ...f];
        expect(pares, hasLength(n * (n - 1) ~/ 2), reason: 'n=$n');
        expect({for (final (a, b) in pares) '${min(a, b)}-${max(a, b)}'}, hasLength(pares.length), reason: 'n=$n');
        for (final f in fechas) {
          final jugando = [
            for (final (a, b) in f) ...[a, b],
          ];
          expect(jugando.toSet(), hasLength(jugando.length), reason: 'nadie juega dos veces en una fecha');
        }
      }
    });

    test('orden de siembra del cuadro', () {
      expect(Torneo.ordenSiembra(8), [0, 7, 3, 4, 1, 6, 2, 5]);
      expect(Torneo.ordenSiembra(4), [0, 3, 1, 2]);
    });

    test(
      'eliminación con cualquier cantidad de equipos: gana el mejor sembrado y hay tantos pasantes como corresponde',
      () {
        for (var n = 4; n <= 32; n++) {
          for (final aGanar in [1, 2, 4]) {
            var t = Torneo.crear(
              nombre: 'T',
              formato: FormatoTorneo.eliminacion,
              equipos: [for (var i = 0; i < n; i++) _equipo(i)],
              aGanar: aGanar,
            );
            var vueltas = 0;
            while (!t.terminado && vueltas++ < 10) {
              t = t.jugarRonda(_simulaSeed);
            }
            expect(t.terminado, isTrue, reason: 'n=$n');
            expect(t.campeon, 0, reason: 'n=$n aGanar=$aGanar');
            final partidos = t.llaves.where((l) => !l.bye).length;
            expect(partidos, n - 1, reason: 'en eliminación se juegan n-1 cruces (n=$n)');
            final primera = t.llaves.where((l) => l.ronda == 0);
            final tam = [
              for (var p = 4; ; p *= 2)
                if (p >= n) p,
            ].first;
            expect(primera.length, tam ~/ 2 * (n == tam ? 1 : 1) + (tam == 2 ? 0 : 0), reason: 'n=$n');
            expect(primera.where((l) => l.bye).length, tam - n, reason: 'los lugares que sobran son pases directos');
          }
        }
      },
    );

    test('al mejor de 3, 5 y 7 hacen falta 2, 3 y 4 victorias y la localía se reparte', () {
      for (final (aGanar, locales) in [
        (2, [true, false, true]),
        (3, [true, true, false, false, true]),
        (4, [true, true, false, false, true, false, true]),
      ]) {
        var l = Llave(fase: 'F', ronda: 0, a: 0, b: 1, aGanar: aGanar, ko: true);
        for (var i = 0; i < locales.length; i++) {
          expect(l.aLocalProximo, locales[i], reason: 'bo${aGanar * 2 - 1} juego ${i + 1}');
          l = l.conJuego(i.isEven ? 100 : 90, i.isEven ? 90 : 100);
        }
      }
      var l = Llave(fase: 'F', ronda: 0, a: 0, b: 1, aGanar: 2, ko: true);
      expect(l.terminada, isFalse);
      l = l.conJuego(100, 90).conJuego(100, 90);
      expect(l.terminada, isTrue);
      expect(l.ganador, 0);
    });

    test('liga: se juegan n(n-1)/2 partidos y la tabla suma bien', () {
      for (final n in [4, 5, 8, 11, 16]) {
        var t = Torneo.crear(
          nombre: 'L',
          formato: FormatoTorneo.liga,
          equipos: [for (var i = 0; i < n; i++) _equipo(i)],
        );
        while (!t.terminado) {
          t = t.jugarRonda(_simulaSeed);
        }
        expect(t.llaves, hasLength(n * (n - 1) ~/ 2));
        expect(t.campeon, 0);
        final tabla = t.tabla(null);
        expect(tabla, hasLength(n));
        expect(tabla.first.victorias, n - 1);
        expect(tabla.last.derrotas, n - 1);
        expect(tabla.fold(0, (a, f) => a + f.victorias), tabla.fold(0, (a, f) => a + f.derrotas));
        expect(tabla.fold(0, (a, f) => a + f.diferencia), 0);
      }
    });

    test('grupos + eliminación: grupos parejos, pasan 2 por grupo y gana el mejor sembrado', () {
      for (final n in [6, 7, 8, 10, 12, 16, 20, 32]) {
        var t = Torneo.crear(
          nombre: 'G',
          formato: FormatoTorneo.grupos,
          equipos: [for (var i = 0; i < n; i++) _equipo(i)],
        );
        final tamanios = t.grupos.map((g) => g.length).toList();
        expect(tamanios.reduce(min), greaterThanOrEqualTo(3), reason: 'n=$n');
        expect(tamanios.reduce(max) - tamanios.reduce(min), lessThanOrEqualTo(1), reason: 'n=$n');
        expect(t.grupos.expand((g) => g).toSet(), hasLength(n));
        var v = 0;
        while (!t.terminado && v++ < 40) {
          t = t.jugarRonda(_simulaSeed);
        }
        expect(t.terminado, isTrue, reason: 'n=$n');
        expect(t.campeon, 0, reason: 'n=$n');
        final ko = t.llaves
            .where((l) => l.ko && !l.bye)
            .map((l) => l.a)
            .followedBy(t.llaves.where((l) => l.ko && !l.bye).map((l) => l.b))
            .toSet();
        expect(
          ko.length,
          greaterThanOrEqualTo(t.grupos.length),
          reason: 'n=$n: llegan 2 por grupo (algunos con pase directo)',
        );
      }
    });

    test('tu partido: avanza hasta tu turno, se anota el resultado y se sigue', () {
      var t = Torneo.crear(
        nombre: 'U',
        formato: FormatoTorneo.eliminacion,
        equipos: [for (var i = 0; i < 8; i++) _equipo(i, usuario: i == 3)],
      );
      expect(t.usuario, 3);
      expect(t.pendienteUsuario, isNotNull);
      t = t.avanzar(_simulaSeed);
      expect(t.pendienteUsuario, isNotNull, reason: 'espera tu partido');
      // Los demás cruces de tu ronda ya se jugaron.
      final r = t.rondaActual!;
      expect(t.llaves.where((l) => l.ronda == r && !l.involucra(3)).every((l) => l.terminada), isTrue);
      t = t.registrarUsuario(100, 90).avanzar(_simulaSeed);
      expect(t.recordUsuario, (1, 0));
      t = t.registrarUsuario(80, 90).avanzar(_simulaSeed);
      // Eliminado en la ronda siguiente: el resto se simula solo hasta el final.
      expect(t.pendienteUsuario, isNull);
      expect(t.terminado, isTrue);
      expect(t.campeon, 0);
      expect(t.recordUsuario, (1, 1));
    });

    test('espectador: nada avanza hasta que se pide, y se puede simular todo', () {
      var t = Torneo.crear(
        nombre: 'E',
        formato: FormatoTorneo.eliminacion,
        equipos: [for (var i = 0; i < 6; i++) _equipo(i)],
      );
      expect(t.conUsuario, isFalse);
      expect(identical(t.avanzar(_simulaSeed), t), isTrue);
      expect(t.avanzar(_simulaSeed, incluirUsuario: true).terminado, isTrue);
    });

    test('hay un solo equipo tuyo y los parámetros inválidos no arman nada', () {
      expect(
        () => Torneo.crear(
          nombre: 'x',
          formato: FormatoTorneo.liga,
          equipos: [for (var i = 0; i < 4; i++) _equipo(i, usuario: i < 2)],
        ),
        throwsArgumentError,
      );
      expect(() => Torneo.crear(nombre: 'x', formato: FormatoTorneo.liga, equipos: [_equipo(0)]), throwsArgumentError);
    });

    test('JSON ida y vuelta, también a mitad del torneo', () {
      var t = Torneo.crear(
        nombre: 'J',
        formato: FormatoTorneo.grupos,
        equipos: [for (var i = 0; i < 9; i++) _equipo(i, usuario: i == 4)],
        aGanar: 2,
      );
      t = t.avanzar(_simulaSeed);
      final copia = Torneo.fromJson(t.toJson());
      expect(copia.toJson(), t.toJson());
      expect(copia.pendienteUsuario?.fase, t.pendienteUsuario?.fase);
      expect(copia.usuario, t.usuario);
    });

    test('con equipos reales: se arma, se simula entero y sale un campeón', () {
      final m = ModosCompetitivo(liga, azar: Random(11));
      final usados = <int>{};
      final equipos = <EquipoTorneo>[];
      for (final id in ['CHI', 'BOS', 'LAL', 'GSW']) {
        final r = m.esc.rivalTodosLosTiempos(id, usados)!;
        usados.addAll([for (final c in r.cartaIds.values) m.jugador(c)!.nbaPlayerId]);
        equipos.add(EquipoTorneo(nombre: id, rival: r));
      }
      final propio = m.rivalDeAlineacion(cartas, 'CHI', '(mi equipo)');
      final torneo = Torneo.crear(
        nombre: 'Real',
        formato: FormatoTorneo.eliminacion,
        equipos: [
          ...equipos,
          EquipoTorneo(nombre: 'Mi equipo', rival: propio, usuario: true),
        ],
      );
      var t = m.nuevoTorneo(id: 'tt', franquiciaId: 'CHI', torneo: torneo);
      expect(Torneo.de(t)!.pendienteUsuario, isNotNull);
      t = m.simularTorneo(t);
      t = m.simularRestoTorneo(t);
      final fin = Torneo.de(t)!;
      expect(fin.terminado, isTrue);
      expect(fin.campeon, isNotNull);
      expect(faseCompetitiva(t), startsWith('Campeón'));
    });
  });

  group('Alineaciones y recompensas', () {
    test('mejorAlineacion cubre los 6 puestos o devuelve null', () {
      expect(cartas, hasLength(6));
      expect(mejorAlineacion(const <Jugador>[]), isNull);
      final soloPivots = [
        for (final j in catalogo)
          if (j.posiciones.length == 1 && j.posiciones.first == Posicion.pivot) j,
      ].take(20);
      expect(mejorAlineacion(soloPivots), isNull);
    });

    test('ascender da XP, monedas y, a la División 1, logro y trofeo', () {
      final m = ModosCompetitivo(liga, azar: Random(2));
      final antes = m.nuevaDivisiones(id: 'p', franquiciaId: 'CHI', dificultad: Dificultad.normal, cartas: cartas);
      final e = EstadoDivisiones.de(antes)!;
      final despues = e.copyWith(division: 1, llegoA1: true, victorias: 8, derrotas: 2).en(antes);
      final (perfil, novedades) = premiarCompetitivo(const PerfilEntrenador(), antes, despues);
      expect(perfil.xp, greaterThan(0));
      expect(perfil.monedas, greaterThan(0));
      expect(perfil.logros.containsKey(Logro.divisionUno), isTrue);
      expect(perfil.trofeos.single.tipo, TipoTrofeo.divisiones);
      expect(novedades.any((n) => n.titulo.contains('Ascenso')), isTrue);
      // Ya con el logro, no se repite.
      final (otra, _) = premiarCompetitivo(perfil, antes, despues);
      expect(otra.trofeos, hasLength(2), reason: 'el trofeo se da por cada vez que se llega; el logro, una sola');
    });

    test('conquistar todo el mapa da el logro y el trofeo; ganar un torneo propio también', () {
      final m = ModosCompetitivo(liga);
      final antes = m.nuevaConquista(id: 'c', franquiciaId: 'CHI', dificultad: Dificultad.normal, cartas: cartas);
      final d = EstadoConquista.de(antes)!.copyWith(conquistados: mapaConquista.keys.toList(), victorias: 29);
      final (perfil, _) = premiarCompetitivo(const PerfilEntrenador(), antes, d.en(antes));
      expect(perfil.logros.containsKey(Logro.conquistaTotal), isTrue);
      expect(perfil.trofeos.single.tipo, TipoTrofeo.conquista);

      final torneo = Torneo.crear(
        nombre: 'Copa',
        formato: FormatoTorneo.liga,
        equipos: [for (var i = 0; i < 4; i++) _equipo(i, usuario: i == 0)],
      );
      final tAntes = torneo.en(Temporada(id: 'x', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.creadorTorneos));
      var fin = torneo;
      while (!fin.terminado) {
        fin = fin.jugarRonda(_simulaSeed);
      }
      final (p2, nov) = premiarCompetitivo(const PerfilEntrenador(), tAntes, fin.en(tAntes));
      expect(p2.logros.containsKey(Logro.campeonTorneo), isTrue);
      expect(nov.any((n) => n.titulo.contains('Campeón')), isTrue);
    });

    test('un modo que no es de estos no recibe premios acá', () {
      final t = Temporada(id: 'z', franquiciaUsuarioId: 'CHI');
      expect(premiarCompetitivo(const PerfilEntrenador(), t, t).$2, isEmpty);
      expect(esPartidaCompetitiva(ModoJuego.racha), isFalse);
      expect(esPartidaCompetitiva(ModoJuego.conquista), isTrue);
    });
  });
}
