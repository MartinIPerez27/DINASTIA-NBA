import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/metajuego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/misiones.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(5));
  final hoy = DateTime(2026, 11, 13); // viernes

  Temporada nueva() {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return liga.iniciar(Temporada(id: 'm', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  }

  group('misiones', () {
    test('3 diarias y 3 semanales, siempre las mismas para la misma fecha', () {
      final a = Misiones.generar(hoy), b = Misiones.generar(DateTime(2026, 11, 13, 23, 59));
      expect(a.where((m) => !m.semanal), hasLength(3));
      expect(a.where((m) => m.semanal), hasLength(3));
      expect([for (final m in a) (m.id, m.tipo, m.objetivo)], [for (final m in b) (m.id, m.tipo, m.objetivo)]);
      expect(a.where((m) => !m.semanal).map((m) => m.tipo).toSet(), hasLength(3), reason: 'sin repetidas');
      // Otro día de la misma semana: cambian las diarias, no las semanales.
      final lunes = Misiones.generar(DateTime(2026, 11, 9));
      expect(lunes.where((m) => m.semanal).map((m) => m.id), a.where((m) => m.semanal).map((m) => m.id));
      expect(lunes.where((m) => !m.semanal).map((m) => m.id), isNot(a.where((m) => !m.semanal).map((m) => m.id)));
    });

    test('alDia conserva el avance y cambia el pase con el trimestre', () {
      var m = Misiones.alDia(const Metajuego(), hoy);
      expect(m.pase, '2026-T4');
      m = Misiones.avanzar(m, {for (final x in m.misiones) x.tipo: 1});
      m = m.copyWith(puntosPase: 500, nivelesReclamados: {1});
      final mismo = Misiones.alDia(m, hoy.add(const Duration(hours: 2)));
      expect(identical(mismo, m), isTrue);
      final otroTrimestre = Misiones.alDia(m, DateTime(2027, 1, 2));
      expect(otroTrimestre.pase, '2027-T1');
      expect(otroTrimestre.puntosPase, 0);
      expect(otroTrimestre.nivelesReclamados, isEmpty);
    });

    test('avanzan con lo que pasa en la temporada y se cobran una sola vez', () {
      final t0 = nueva();
      var t = t0;
      for (var i = 0; i < 6; i++) {
        t = liga.simularProximo(t);
      }
      final d = Misiones.diferencias(t0, t);
      final v = t.registroUsuario.victorias;
      expect(d[TipoMision.ganarPartidos] ?? 0, v);
      expect(d[TipoMision.triples], greaterThan(0));
      expect(d[TipoMision.rebotes], greaterThan(30));
      // Por Progreso: misiones del día y puntos del pase por jugar; lo anotado en vivo también cuenta.
      Misiones.anotar(TipoMision.jugarEnVivo);
      final (p, _) = Progreso(liga, reloj: () => hoy).aplicar(const PerfilEntrenador(), t0, t);
      final r = t.registroUsuario;
      expect(p.metajuego.puntosPase, r.victorias * 10 + r.derrotas * 3);
      expect(p.metajuego.misiones, hasLength(6));
      for (final m in p.metajuego.misiones) {
        final esperado = switch (m.tipo) {
          TipoMision.jugarEnVivo => 1,
          TipoMision.ganarPartidos => v,
          _ => null,
        };
        if (esperado != null) expect(m.progreso, min(m.objetivo, esperado), reason: m.tipo.name);
      }
      expect(Misiones.cobrarPendientes(), isEmpty, reason: 'lo anotado se cobró');

      final cumplida = Metajuego(
        misiones: [const Mision(id: 'd-x-0', tipo: TipoMision.ganarPartidos, objetivo: 3, semanal: false, progreso: 3)],
      );
      final perfil = PerfilEntrenador(metajuego: cumplida);
      final cobrado = Misiones.reclamar(perfil, 'd-x-0')!;
      expect((cobrado.xp, cobrado.monedas, cobrado.metajuego.puntosPase), (80, 40, 100));
      expect(Misiones.reclamar(cobrado, 'd-x-0'), isNull);
      expect(Misiones.hayParaReclamar(perfil), isTrue);
      expect(Misiones.hayParaReclamar(cobrado), isFalse);
    });
  });

  group('pase y cosméticos', () {
    test('niveles del pase: cosmético o monedas, cada uno una vez', () {
      expect(PaseTemporada.nivel(0), 0);
      expect(PaseTemporada.nivel(450), 2);
      expect(PaseTemporada.nivel(1 << 20), PaseTemporada.niveles);
      final p = const PerfilEntrenador(metajuego: Metajuego(puntosPase: 450));
      expect(PaseTemporada.pendientes(p), [1, 2]);
      final con1 = PaseTemporada.reclamar(p, 1)!;
      expect(con1.monedas, PaseTemporada.monedas(1));
      final con2 = PaseTemporada.reclamar(con1, 2)!;
      expect(con2.metajuego.cosmeticos, {Cosmetico.uniformeAlternativo});
      expect(PaseTemporada.reclamar(con2, 2), isNull);
      expect(PaseTemporada.reclamar(con2, 3), isNull, reason: 'todavía no llegó');
      // Todos los cosméticos que no son de fábrica se ganan por algún lado.
      for (final c in Cosmetico.values.where((c) => !c.deFabrica)) {
        expect(c.nivelPase != null || c.nivelEntrenador != null, isTrue);
        if (c.nivelPase != null) expect(PaseTemporada.cosmetico(c.nivelPase!), c);
      }
    });

    test('por nivel de entrenador, elegir y guardar', () {
      const nuevo = PerfilEntrenador();
      expect(PaseTemporada.disponible(nuevo, Cosmetico.ledAmbar), isFalse);
      expect(identical(PaseTemporada.elegir(nuevo, Cosmetico.ledAmbar), nuevo), isTrue);
      final nivel4 = PerfilEntrenador(xp: PerfilEntrenador.xpParaNivel(4));
      expect(nivel4.nivel, 4);
      final elegido = PaseTemporada.elegir(nivel4, Cosmetico.ledAmbar);
      expect(elegido.metajuego.elegido(CategoriaCosmetico.led), Cosmetico.ledAmbar);
      expect(elegido.metajuego.elegido(CategoriaCosmetico.cancha), Cosmetico.canchaModerna, reason: 'de fábrica');

      final completo = elegido.copyWith(
        metajuego: elegido.metajuego.copyWith(
          cosmeticos: {Cosmetico.pelotaAba, Cosmetico.canchaSetentas},
          elegidos: {...elegido.metajuego.elegidos, CategoriaCosmetico.pelota: Cosmetico.pelotaAba},
          misiones: Misiones.generar(hoy),
          pase: '2026-T4',
          puntosPase: 777,
          nivelesReclamados: {1, 2, 3},
          rivalidades: {'BOS': const Rivalidad(franquiciaId: 'BOS', eliminaciones: 1, ronda: 'finalesNba')},
        ),
      );
      final copia = PerfilEntrenador.fromJson(completo.toJson()).metajuego;
      expect(copia.cosmeticos, completo.metajuego.cosmeticos);
      expect(copia.elegidos, completo.metajuego.elegidos);
      expect(copia.misiones.map((m) => m.id), completo.metajuego.misiones.map((m) => m.id));
      expect((copia.pase, copia.puntosPase), ('2026-T4', 777));
      expect(copia.nivelesReclamados, {1, 2, 3});
      expect(copia.rivalidades['BOS']!.ronda, 'finalesNba');
      // Un perfil de antes del metajuego carga igual.
      final viejo = PerfilEntrenador.fromJson({'xp': 10, 'monedas': 5});
      expect(viejo.metajuego.misiones, isEmpty);
      expect(viejo.metajuego.elegido(CategoriaCosmetico.pelota), Cosmetico.pelotaClasica);
    });
  });

  group('revancha', () {
    SeriePlayoff serie(String alto, String bajo, int va, int vb) => SeriePlayoff(
      ronda: RondaPlayoff.finalConferencia,
      altoId: alto,
      bajoId: bajo,
      victoriasAlto: va,
      victoriasBajo: vb,
    );

    test('te eliminan, queda la cuenta pendiente y la cobrás en otra temporada', () {
      final antes = Temporada(id: 'a', franquiciaUsuarioId: 'CHI', series: [serie('CHI', 'DET', 2, 3)]);
      final despues = Temporada(id: 'a', franquiciaUsuarioId: 'CHI', series: [serie('CHI', 'DET', 2, 4)]);
      final (m, cumplidas) = Rivalidades.registrar(const Metajuego(), antes, despues, numero: 3);
      expect(cumplidas, isEmpty);
      final r = m.rivalidades['DET']!;
      expect((r.eliminaciones, r.derrotas, r.temporadaNumero), (1, 1, 3));
      final perfil = PerfilEntrenador(metajuego: m);
      expect(Rivalidades.contexto(perfil, despues, 'DET'), isNull, reason: 'en la misma partida no');
      final otra = Temporada(id: 'b', franquiciaUsuarioId: 'CHI');
      expect(
        Rivalidades.contexto(perfil, otra, 'DET'),
        'Te eliminaron en las Finales de Conferencia de tu temporada 3',
      );
      expect(Rivalidades.contexto(perfil, otra, 'BOS'), isNull);

      // En la partida 'b' le ganás la serie: revancha, logro y bonus.
      final b0 = Temporada(id: 'b', franquiciaUsuarioId: 'CHI', series: [serie('DET', 'CHI', 1, 3)]);
      final b1 = Temporada(id: 'b', franquiciaUsuarioId: 'CHI', series: [serie('DET', 'CHI', 1, 4)]);
      final (p, novedades) = Progreso(liga, reloj: () => hoy).aplicar(perfil, b0, b1);
      expect(p.logros.containsKey(Logro.revancha), isTrue);
      expect(p.metajuego.rivalidades['DET']!.revanchas, 1);
      expect(novedades.any((n) => n.titulo == '¡Revancha cumplida!'), isTrue);
      expect(Rivalidades.contexto(p, otra, 'DET'), isNull, reason: 'cuenta saldada');
    });

    test('muchas derrotas también arman rivalidad', () {
      const r = Rivalidad(franquiciaId: 'BOS', derrotas: 6);
      final perfil = PerfilEntrenador(metajuego: Metajuego(rivalidades: {'BOS': r}));
      expect(
        Rivalidades.contexto(perfil, Temporada(id: 'x', franquiciaUsuarioId: 'CHI'), 'BOS'),
        'Te ganaron 6 partidos en tu carrera',
      );
    });
  });
}
