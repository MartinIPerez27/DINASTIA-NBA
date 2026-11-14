import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(41));
  final carrera = CarreraJugador(liga);
  _liga = liga;

  JugadorCreado creado({
    Posicion pos = Posicion.escolta,
    RolCancha rol = RolCancha.tiradorPantallas,
    List<Atributo> fuertes = const [Atributo.tiro, Atributo.iq, Atributo.defensa],
    int altura = 195,
    int peso = 90,
  }) =>
      JugadorCreado(nombre: 'Martín Pérez', posicion: pos, rol: rol, fuertes: fuertes, alturaCm: altura, pesoKg: peso);

  String nombreDe(String id) => franquiciaPorId(id).nombreCompleto;

  group('jugador creado', () {
    test('validaciones del creador', () {
      expect(creado().error, isNull);
      expect(
        JugadorCreado(
          nombre: 'A',
          posicion: Posicion.base,
          rol: RolCancha.organizadorPuro,
          fuertes: const [Atributo.tiro, Atributo.iq, Atributo.defensa],
        ).error,
        contains('nombre'),
      );
      expect(creado(rol: RolCancha.goliatPintura).error, contains('arquetipo'));
      expect(creado(fuertes: const [Atributo.tiro, Atributo.tiro, Atributo.iq]).error, contains('tres'));
      expect(creado(altura: 250).error, contains('altura'));
      expect(creado(peso: 20).error, contains('peso'));
    });

    test('todos los arquetipos arrancan con media 66–72 y estadísticas creíbles', () {
      for (final pos in Posicion.titulares) {
        for (final rol in JugadorCreado.rolesDe(pos)) {
          final jc = creado(
            pos: pos,
            rol: rol,
            altura: JugadorCreado.alturaSugerida(pos),
            peso: 70 + (JugadorCreado.alturaSugerida(pos) - 180),
          );
          expect(jc.error, isNull, reason: rol.name);
          expect(jc.media, inInclusiveRange(66, 73), reason: '${rol.name} media ${jc.media}');
          final s = jc.estadisticas;
          expect(s.ppp, inInclusiveRange(6.5, 17), reason: rol.name);
          expect(s.pctTc, inInclusiveRange(0.38, 0.62), reason: rol.name);
          expect(s.pctT3, inInclusiveRange(0.0, 0.42), reason: rol.name);
          expect(s.iq, inInclusiveRange(40, 80), reason: rol.name);
        }
      }
    });

    test('los puntos fuertes y el físico cambian el perfil', () {
      final tirador = creado(
        fuertes: const [
          Atributo.tiro,
          Atributo.tiro == Atributo.iq ? Atributo.tiro : Atributo.finalizacion,
          Atributo.iq,
        ],
      );
      final defensor = creado(fuertes: const [Atributo.defensa, Atributo.fisico, Atributo.iq]);
      expect(tirador.atributos[Atributo.tiro], greaterThan(defensor.atributos[Atributo.tiro]));
      expect(defensor.atributos[Atributo.defensa], greaterThan(tirador.atributos[Atributo.defensa]));
      final alto = creado(altura: 215, peso: 120), bajo = creado(altura: 175, peso: 75);
      expect(alto.atributos[Atributo.fisico], greaterThan(bajo.atributos[Atributo.fisico]));
      expect(alto.atributos[Atributo.tiro], lessThan(bajo.atributos[Atributo.tiro]));
    });

    test('JSON de ida y vuelta y carta con id propio sin fotos de la red', () {
      final jc = creado();
      final copia = JugadorCreado.fromJson(jc.toJson());
      expect(copia.nombre, jc.nombre);
      expect(copia.fuertes, jc.fuertes);
      expect(copia.atributos.igualA(jc.atributos), isTrue);
      final carta = jc.comoCarta(id: 'mc-x', franquiciaId: 'CHI');
      expect(carta.nbaPlayerId, lessThan(0));
      expect(carta.urlsFoto, isEmpty);
      expect(Jugador.fromJson(carta.toJson()).nombre, 'Martín Pérez');
    });
  });

  group('progresión', () {
    test('costo por nivel y puntos que se gastan', () {
      expect(ModeloCarrera.costo(60), 1);
      expect(ModeloCarrera.costo(70), 2);
      expect(ModeloCarrera.costo(85), 3);
      var e = carrera.estadoCreado(raiz: 'p1', creado: creado(), pick: 12, franquiciaId: 'CHI');
      e = e.copyWith(phBanco: 4);
      final antes = e.atributos[Atributo.tiro];
      final despues = carrera.subir(e, Atributo.tiro);
      expect(despues.atributos[Atributo.tiro], antes + 1);
      expect(despues.phBanco, 4 - ModeloCarrera.costo(antes));
      expect(despues.phGastados, ModeloCarrera.costo(antes));
      // Sin puntos no sube.
      final sinPuntos = carrera.subir(e.copyWith(phBanco: 0), Atributo.tiro);
      expect(sinPuntos.atributos[Atributo.tiro], antes);
    });

    test('subir atributos mueve estadísticas y media, y nunca pasa de 99', () {
      var e = carrera.estadoCreado(raiz: 'p2', creado: creado(), pick: 8, franquiciaId: 'CHI').copyWith(phBanco: 400);
      final base = e.carta;
      for (var i = 0; i < 40; i++) {
        e = carrera.subir(e, Atributo.tiro);
      }
      expect(e.atributos[Atributo.tiro], 99);
      final ahora = e.carta;
      expect(ahora.stats.pctT3, greaterThan(base.stats.pctT3));
      expect(ahora.stats.pctTl, greaterThan(base.stats.pctTl));
      expect(ahora.stats.ppp, greaterThan(base.stats.ppp));
      expect(ahora.media, greaterThan(base.media));
      expect(ahora.media, lessThanOrEqualTo(99));
      expect(e.insigniasGanadas, contains(Insignia.francotirador));
      // Una insignia ganada suma sobre las estadísticas por atributo.
      final sinInsignia = e.copyWith(atributos: e.atributos.con(Atributo.tiro, 79));
      expect(ahora.stats.pctT3, greaterThan(sinInsignia.carta.stats.pctT3 + 0.015 * 0.9));
    });

    test('un jugador real arranca igual que su carta (sin doble cuenta)', () {
      final jordan = carrera.candidatosReales(texto: 'Michael Jordan').first;
      final e = carrera.estadoReal(raiz: 'r1', carta: jordan);
      expect(e.media, jordan.media);
      expect(e.carta.stats.ppp, jordan.stats.ppp);
      expect(e.carta.stats.pctT3, jordan.stats.pctT3);
      expect(e.carta.nbaPlayerId, jordan.nbaPlayerId);
      expect(e.carta.id, isNot(jordan.id), reason: 'la carta de la carrera tiene su propio id');
      expect(e.carta.idBbref, jordan.idBbref, reason: 'conserva el id de Basketball-Reference (foto y dúos)');
    });

    test('el desarrollo natural: crece joven, cae viejo', () {
      var jovenSuma = 0, viejoSuma = 0;
      for (var k = 0; k < 50; k++) {
        final joven = ModeloCarrera.desarrolloNatural(21, Random(k));
        final viejo = ModeloCarrera.desarrolloNatural(35, Random(k));
        jovenSuma += joven.values.fold(0, (a, b) => a + b);
        viejoSuma += viejo.values.fold(0, (a, b) => a + b);
      }
      expect(jovenSuma, greaterThan(0));
      expect(viejoSuma, lessThan(0));
    });

    test('puntos por partido: más rendimiento, más puntos, con tope', () {
      expect(CarreraJugador.phDeLinea(null), 0);
      final flojo = lineaDePrueba(pj: 60, pts: 300, reb: 150, ast: 60);
      final estrella = lineaDePrueba(pj: 80, pts: 2400, reb: 700, ast: 600);
      expect(CarreraJugador.phDeLinea(estrella), greaterThan(CarreraJugador.phDeLinea(flojo)));
      expect(CarreraJugador.phDeLinea(estrella), lessThanOrEqualTo(24));
    });
  });

  group('equipo y confianza', () {
    test('confianza inicial y papel según el draft', () {
      expect(CarreraJugador.confianzaInicial(1, 70), greaterThanOrEqualTo(80));
      expect(CarreraJugador.confianzaInicial(40, 66), lessThan(50));
      expect(CarreraJugador.rolPorConfianza(80), RolEquipo.titular);
      expect(CarreraJugador.rolPorConfianza(45), RolEquipo.sexto);
      expect(CarreraJugador.rolPorConfianza(10), RolEquipo.banco);
      expect(CarreraJugador.contratoNovato(10), 4);
      expect(CarreraJugador.contratoNovato(45), 2);
    });

    test('los compañeros cubren los cinco puestos y el plantel se arma en los tres roles', () {
      final e0 = carrera.estadoCreado(raiz: 'q1', creado: creado(), pick: 12, franquiciaId: 'DEN');
      final t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      final e = EstadoCarrera.de(t)!;
      expect(e.companeros, hasLength(CarreraJugador.maxCompaneros));
      for (final p in Posicion.titulares) {
        expect(e.companeros.any((j) => j.posiciones.first == p), isTrue, reason: p.etiqueta);
      }
      expect({for (final j in e.companeros) j.nbaPlayerId}.length, e.companeros.length);
      final yo = e.carta;
      for (final rol in RolEquipo.values) {
        final (plantel, suplentes, aplicado) = carrera.ubicar(yo, e.companeros, rol);
        expect(plantel.completo, isTrue, reason: rol.name);
        expect(aplicado, rol);
        expect(suplentes.length, lessThanOrEqualTo(Temporada.maxSuplentes));
        final enPlantel = plantel.jugadores.any((j) => j.id == yo.id);
        final enBanco = suplentes.any((j) => j.id == yo.id);
        expect(enPlantel, rol != RolEquipo.banco, reason: rol.name);
        expect(enBanco, rol == RolEquipo.banco, reason: rol.name);
        if (rol == RolEquipo.sexto) expect(plantel.sextoHombre!.id, yo.id);
        if (rol == RolEquipo.titular) expect(plantel.titulares.any((j) => j.id == yo.id), isTrue);
      }
    });

    test('la temporada de Mi carrera es completa, con tu jugador, y se guarda y se lee', () {
      final e0 = carrera.estadoCreado(raiz: 'q2', creado: creado(), pick: 4, franquiciaId: 'CHI');
      final t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.dificil);
      expect(t.modoJuego, ModoJuego.carreraJugador);
      expect(t.fase, FaseTemporada.temporadaRegular);
      expect(t.calendario, isNotEmpty);
      expect(t.dificultad, Dificultad.dificil);
      expect(t.plantel.jugadores.any((j) => j.id == 'mc-q2'), isTrue, reason: 'pick 4: arranca de titular');
      expect(liga.jugador('mc-q2'), isNotNull, reason: 'registrada en la liga para premios y All-Star');
      for (final r in t.rivales.values) {
        for (final id in r.cartaIds.values) {
          expect(liga.jugador(id)?.nbaPlayerId, isNot(e0.base.nbaPlayerId));
        }
      }
      final copia = Temporada.fromJson(t.toJson());
      final e = EstadoCarrera.de(copia)!;
      expect(e.nombre, 'Martín Pérez');
      expect(e.atributos.igualA(e0.atributos), isTrue);
      expect(e.companeros.map((j) => j.id), EstadoCarrera.de(t)!.companeros.map((j) => j.id));
      expect(copia.plantel.completo, isTrue);
    });

    test('la confianza se mueve con el rendimiento y cambia el papel; los puntos se acreditan', () {
      var e0 = carrera.estadoCreado(raiz: 'q3', creado: creado(), pick: 20, franquiciaId: 'DAL');
      var t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      for (var i = 0; i < 25; i++) {
        t = liga.simularProximo(t);
      }
      final antes = EstadoCarrera.de(t)!;
      t = carrera.alGuardar(t);
      final e = EstadoCarrera.de(t)!;
      final l = t.lineas[e.jugadorId];
      if (l != null) {
        expect(e.snapPj, l.pj);
        expect(e.phBanco, greaterThan(antes.phBanco), reason: 'jugó partidos: acredita puntos de habilidad');
        expect(e.phAcreditados, e.phBanco);
      }
      // Idempotente: guardar de nuevo sin partidos nuevos no cambia nada.
      final otra = EstadoCarrera.de(carrera.alGuardar(t))!;
      expect(otra.phBanco, e.phBanco);
      expect(otra.confianza, e.confianza);
      // Con confianza baja baja al banco; con alta, vuelve a ser titular.
      final bajo = carrera.sincronizar(t, e.copyWith(confianza: 10, rolEquipo: RolEquipo.banco));
      expect(bajo.plantel.jugadores.any((j) => j.id == e.jugadorId), isFalse);
      expect(bajo.suplentes.any((j) => j.id == e.jugadorId), isTrue);
      final alto = carrera.sincronizar(bajo, EstadoCarrera.de(bajo)!.copyWith(rolEquipo: RolEquipo.titular));
      expect(alto.plantel.jugadores.any((j) => j.id == e.jugadorId), isTrue);
    });
  });

  group('receso y siguiente temporada', () {
    test('tres temporadas seguidas: cierre, receso, contrato y mudanza, sin romper y con JSON', () {
      final e0 = carrera.estadoCreado(raiz: 'z1', creado: creado(), pick: 6, franquiciaId: 'MIA');
      var t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      for (var n = 1; n <= 3; n++) {
        t = liga.simularOtrosHasta(carrera.alGuardar(_jugarRegular(t)), 1 << 30);
        t = liga.simularRestoPlayoffs(t);
        t = carrera.alGuardar(t);
        final e = EstadoCarrera.de(t)!;
        expect(e.numero, n);
        final cierre = carrera.cerrar(t, e, nombreDe);
        // Determinístico: cerrar dos veces da lo mismo.
        final otra = carrera.cerrar(t, e, nombreDe);
        expect(otra.estado.atributos.igualA(cierre.estado.atributos), isTrue);
        expect(otra.phObjetivos, cierre.phObjetivos);
        final c = cierre.estado;
        expect(c.cerrada, isTrue);
        expect(c.historial, hasLength(n));
        expect(c.edad, e.edad + 1);
        expect(c.contrato, e.contrato - 1);
        expect(cierre.temporada.pj, greaterThan(0));
        expect(cierre.objetivos, hasLength(3));
        expect(c.phBanco, e.phBanco + cierre.phBase + cierre.phObjetivos + cierre.phPremios);
        // Prensa.
        final preguntas = carrera.preguntasDelReceso(c);
        expect(preguntas, hasLength(2));
        final tras = carrera.responderPrensa(c, preguntas.first.respuestas.first);
        expect(tras.prensaHecha, 1);
        // Ofertas: renovación + 3 equipos, con papel y años.
        final ofertas = carrera.ofertas(t, tras, traspaso: false);
        expect(ofertas, hasLength(4));
        expect(ofertas.first.renovacion, isTrue);
        expect({for (final o in ofertas) o.franquiciaId}.length, ofertas.length);
        expect(carrera.ofertas(t, tras, traspaso: true).any((o) => o.renovacion), isFalse);
        // Temporada 2: renueva; temporada 3: se muda a otro equipo.
        final oferta = n == 2 ? ofertas[1] : (n == 1 ? ofertas.first : null);
        t = carrera.siguiente(t, tras, oferta: oferta);
        final sig = EstadoCarrera.de(t)!;
        expect(t.id, '${e.raiz}-t${n + 1}');
        expect(sig.numero, n + 1);
        expect(sig.cerrada, isFalse);
        expect(sig.objetivos, hasLength(3));
        expect(sig.historial, hasLength(n));
        expect(t.fase, FaseTemporada.temporadaRegular);
        expect(t.plantel.completo, isTrue);
        if (n == 2) {
          expect(sig.franquiciaId, ofertas[1].franquiciaId);
          expect(t.franquiciaUsuarioId, ofertas[1].franquiciaId);
          expect(sig.relacion, 50);
        }
        final copia = Temporada.fromJson(t.toJson());
        expect(EstadoCarrera.de(copia)!.historial, hasLength(n));
      }
    });

    test('retiro, legado y línea de tiempo', () {
      var e = carrera.estadoCreado(raiz: 'z2', creado: creado(), pick: 3, franquiciaId: 'LAL');
      expect(CarreraJugador.puedeRetirarse(e), isFalse);
      e = e.copyWith(
        edad: 36,
        atributos: e.atributos.sumar({Atributo.fisico: -30, Atributo.finalizacion: -30, Atributo.tiro: -30}),
      );
      expect(CarreraJugador.puedeRetirarse(e), isTrue);
      expect(CarreraJugador.retiroForzoso(e), isTrue, reason: 'a los 36 con media baja ya no da más');
      const campeonYMvp = TemporadaJugador(
        numero: 1,
        etiqueta: '2026–27',
        franquiciaId: 'LAL',
        edad: 20,
        media: 90,
        pj: 80,
        pts: 30,
        reb: 8,
        ast: 7,
        victorias: 65,
        derrotas: 17,
        resultado: 'Campeón',
        campeon: true,
        allStar: true,
        premios: ['MVP', 'All-NBA 1.º equipo'],
      );
      final leyenda = LegadoCarrera('X', List.filled(6, campeonYMvp));
      expect(leyenda.anillos, 6);
      expect(leyenda.mvps, 6);
      expect(leyenda.salon, isTrue);
      expect(leyenda.veredicto, contains('Salón de la Fama'));
      expect(const LegadoCarrera('Y', [campeonYMvp]).salon, isFalse);
      final retirado = carrera.retirar(e.copyWith(historial: [campeonYMvp]));
      expect(retirado.retirado, isTrue);
      expect(retirado.hitos.last, contains('se retira'));
      expect(carrera.narrar(retirado).single, contains('¡Campeón!'));
      expect(EstadoCarrera.fromJson(retirado.toJson()).retirado, isTrue);
    });
  });

  group('jugador real', () {
    test('Jordan arranca en los Bulls con su draft real y una temporada completa', () {
      final jordan = carrera.candidatosReales(texto: 'Michael Jordan').first;
      final e0 = carrera.estadoReal(raiz: 'jr', carta: jordan);
      expect(e0.esReal, isTrue);
      expect(e0.franquiciaId, jordan.franquiciaId);
      expect(e0.pick, jordan.draft?.$2 ?? 3);
      final t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      final yo = t.plantel.jugadores.followedBy(t.suplentes).firstWhere((j) => j.id == e0.jugadorId);
      expect(yo.nbaPlayerId, jordan.nbaPlayerId, reason: 'conserva la foto real');
      expect(yo.media, jordan.media);
      expect(t.plantel.completo, isTrue);
      // Ninguna otra carta de Jordan juega en la liga de esta partida.
      for (final r in t.rivales.values) {
        for (final id in r.cartaIds.values) {
          expect(liga.jugador(id)?.nbaPlayerId, isNot(jordan.nbaPlayerId));
        }
      }
      expect(e0.companeros, isEmpty, reason: 'el estado de arranque todavía no armó el equipo');
      final armado = EstadoCarrera.de(t)!;
      expect(armado.companeros.every((j) => j.nbaPlayerId != jordan.nbaPlayerId), isTrue);
      expect(Temporada.fromJson(t.toJson()).plantel.completo, isTrue);
      expect(e0.hitos.first, contains('draft'));
    });

    test('sin draft (pick 55): arranca de banco con contrato corto', () {
      final e = carrera.estadoCreado(raiz: 'sd', creado: creado(), pick: 55, franquiciaId: 'SAS');
      expect(e.contrato, 2);
      expect(e.rolEquipo, RolEquipo.banco);
      expect(e.hitos.first, contains('no es elegido'));
      final t = carrera.nuevaCarrera(estado: e, dificultad: Dificultad.leyenda);
      expect(t.plantel.completo, isTrue);
      expect(t.suplentes.any((j) => j.id == 'mc-sd'), isTrue);
    });
  });

  group('en el juego', () {
    test('las mejoras se notan en el motor: más puntos y más acierto en los mismos partidos', () {
      final e0 = carrera.estadoCreado(raiz: 'm1', creado: creado(), pick: 3, franquiciaId: 'CHI');
      final t0 = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      var mejorado = EstadoCarrera.de(t0)!.copyWith(phBanco: 600);
      for (var i = 0; i < 40; i++) {
        for (final a in [Atributo.tiro, Atributo.finalizacion, Atributo.iq]) {
          mejorado = carrera.subir(mejorado, a);
        }
      }
      final t1 = carrera.sincronizar(t0, mejorado);
      expect(mejorado.media, greaterThan(e0.media + 8));
      double puntos(Temporada t) {
        var suma = 0;
        final propios = t.calendario.where((p) => p.participa(t.franquiciaUsuarioId)).take(30).toList();
        for (final p in propios) {
          final g = propios.indexOf(p);
          final m = liga.motor(t, p, azar: Random(900 + g))..simularTodo();
          final linea = {...m.boxLocal, ...m.boxVisitante}['mc-m1'];
          suma += linea?.pts ?? 0;
        }
        return suma / 30;
      }

      final antes = puntos(t0), despues = puntos(t1);
      expect(despues, greaterThan(antes + 2), reason: 'antes $antes, después $despues');
    });

    test('retirarse con una carrera de Salón da el logro, una sola vez', () {
      final progreso = Progreso(liga);
      final e0 = carrera.estadoCreado(raiz: 'hf', creado: creado(), pick: 2, franquiciaId: 'LAL');
      final t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      const leyenda = TemporadaJugador(
        numero: 1,
        etiqueta: '2026–27',
        franquiciaId: 'LAL',
        edad: 20,
        media: 95,
        pj: 80,
        pts: 30,
        reb: 8,
        ast: 7,
        victorias: 65,
        derrotas: 17,
        resultado: 'Campeón',
        campeon: true,
        allStar: true,
        premios: ['MVP', 'All-NBA 1.º equipo'],
      );
      final activo = EstadoCarrera.de(t)!.copyWith(historial: List.filled(6, leyenda), edad: 38);
      final antes = t.copyWith(datosModo: activo.aDatos());
      final despues = t.copyWith(datosModo: carrera.retirar(activo).aDatos());
      final (perfil, novedades) = progreso.aplicar(const PerfilEntrenador(), antes, despues);
      expect(perfil.logros.keys, contains(Logro.salonDeLaFama));
      expect(novedades.any((n) => n.titulo.contains('Salón de la Fama')), isTrue);
      final (otra, _) = progreso.aplicar(perfil, despues, despues);
      expect(otra.logros.length, perfil.logros.length);
    });

    test('el metajuego corre con Mi carrera: XP por partido, sin romper y sin premiar dos veces', () {
      final progreso = Progreso(liga);
      final e0 = carrera.estadoCreado(raiz: 'm2', creado: creado(), pick: 7, franquiciaId: 'DEN');
      final t0 = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
      var t = t0;
      for (var i = 0; i < 6; i++) {
        t = liga.simularProximo(t);
      }
      final (perfil, novedades) = progreso.aplicar(const PerfilEntrenador(), t0, t);
      expect(perfil.xp, greaterThan(0));
      expect(novedades, isNotEmpty);
      // Cambiar solo el estado de la carrera (gastar puntos, prensa…) no da nada.
      final tocada = carrera.sincronizar(t, EstadoCarrera.de(t)!.copyWith(phBanco: 5, moral: 80));
      final (igual, sinNovedades) = progreso.aplicar(perfil, t, tocada);
      expect(igual.xp, perfil.xp);
      expect(sinNovedades, isEmpty);
      // Otra temporada (otro id) nunca suma sobre la anterior.
      final (sinCambio, _) = progreso.aplicar(
        perfil,
        t,
        carrera.siguiente(t, EstadoCarrera.de(t)!.copyWith(cerrada: true)),
      );
      expect(sinCambio.xp, perfil.xp);
    });
  });

  group('combine y draft', () {
    test('el combine proyecta mejor a quien tiene mejor media y es determinístico', () {
      final bueno = creado(fuertes: const [Atributo.tiro, Atributo.finalizacion, Atributo.iq]);
      final r1 = carrera.combine(bueno, Random(5)), r2 = carrera.combine(bueno, Random(5));
      expect(r1.pick, r2.pick);
      expect(r1.pruebas, hasLength(5));
      expect(r1.pick, inInclusiveRange(1, 60));
      var suma = 0;
      for (var k = 0; k < 40; k++) {
        suma += carrera.combine(bueno, Random(k)).pick;
      }
      // Un jugador medio de ~69 cae en la zona de la primera ronda en promedio.
      expect(suma / 40, inInclusiveRange(5, 30));
      final flojo = JugadorCreado(
        nombre: 'Flojo',
        posicion: Posicion.pivot,
        rol: RolCancha.goliatPintura,
        fuertes: const [Atributo.fisico, Atributo.defensa, Atributo.finalizacion],
        alturaCm: 185,
        pesoKg: 70,
      );
      expect(carrera.combine(flojo, Random(1)).puntaje, lessThan(r1.puntaje + 30));
    });

    test('el orden del draft es un sorteo de las 30 franquicias', () {
      final orden = carrera.ordenDraft(7);
      expect(orden.toSet().length, 30);
      expect(carrera.ordenDraft(7), orden);
      expect(carrera.ordenDraft(8), isNot(orden));
    });

    test('jugadores reales para elegir: uno por persona, con búsqueda', () {
      final lista = carrera.candidatosReales(limite: 400);
      expect({for (final j in lista) j.nbaPlayerId}.length, lista.length);
      expect(carrera.candidatosReales(texto: 'jokic').any((j) => j.nombre.contains('Joki')), isTrue);
      expect(lista.first.media, greaterThanOrEqualTo(lista.last.media));
    });
  });
}

/// Una línea de temporada simple para probar los puntos de habilidad.
LineaEstadistica lineaDePrueba({required int pj, required int pts, required int reb, required int ast}) =>
    LineaEstadistica()
      ..pj = pj
      ..pts = pts
      ..reb = reb
      ..ast = ast;

/// Juega todos los partidos del usuario, guardando cada 20 como lo hace la pantalla.
Temporada _jugarRegular(Temporada t) {
  final carrera = CarreraJugador(_liga!);
  var n = 0;
  while (_liga!.proximoDelUsuario(t) != null) {
    t = _liga!.simularProximo(t);
    if (++n % 20 == 0) t = carrera.alGuardar(t);
  }
  return t;
}

Liga? _liga;
