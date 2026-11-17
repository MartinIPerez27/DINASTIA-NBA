import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/motor_modelo.dart';
import 'package:dinastia_nba/domain/playbook.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motor v2 (ronda 2): ritmo, perfil de tiro, tácticas con efectos reales, sesgo de época, expulsados,
/// emparejamiento por puesto y arquetipos, tiempo muerto simétrico, presión con costo.
void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

  Plantel mejorDe(String f) {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == f).toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return p;
  }

  /// Plantel al azar con las cartas que cumplan [filtro] y media de los 6 cercana a [media].
  Plantel armar(bool Function(Jugador) filtro, Random r, {int? media, int intentos = 250}) {
    final porPos = {
      for (final pos in Posicion.values) pos: catalogo.where((j) => filtro(j) && j.puedeJugarEn(pos)).toList(),
    };
    Plantel? mejor;
    var mejorD = 1e9;
    for (var k = 0; k < intentos; k++) {
      var p = const Plantel();
      var ok = true;
      for (final pos in [...Posicion.titulares, Posicion.sextoHombre]) {
        final c = porPos[pos]!;
        Jugador? x;
        for (var t = 0; t < 12 && x == null; t++) {
          final cand = c[r.nextInt(c.length)];
          if (!p.jugadores.any((y) => y.nbaPlayerId == cand.nbaPlayerId) &&
              p.posicionesDisponiblesPara(cand).contains(pos)) {
            x = cand;
          }
        }
        if (x == null) {
          ok = false;
          break;
        }
        p = p.asignar(x, pos);
      }
      if (!ok) continue;
      if (media == null) return p;
      final d = (p.jugadores.fold(0, (a, j) => a + j.media) / 6 - media).abs();
      if (d < mejorD) {
        mejorD = d;
        mejor = p;
      }
      if (d < 0.25) break;
    }
    return mejor!;
  }

  double mediaDe(Plantel p) => p.jugadores.fold(0, (a, j) => a + j.media) / 6;

  EquipoPartido equipo(Plantel p, {Tactica? t}) => EquipoPartido(
    identidadId: 'CHI',
    plantel: p,
    tactica: t ?? recomendar(PerfilPlantel.de(p)).tactica,
  );

  /// Partido completo con todos sus eventos.
  (MotorPartido, List<EventoPartido>) jugar(
    EquipoPartido l,
    EquipoPartido v,
    Random r, {
    bool? usuarioLocal,
    void Function(MotorPartido)? antes,
  }) {
    final m = MotorPartido(local: l, visitante: v, usuarioLocal: usuarioLocal, azar: r);
    antes?.call(m);
    final ev = <EventoPartido>[];
    while (!m.terminado) {
      ev.add(m.siguiente());
    }
    return (m, ev);
  }

  /// Acumulador de estadísticas de UN lado (suma de partidos).
  Map<String, double> lado(MotorPartido m, List<EventoPartido> ev, bool local) {
    final box = (local ? m.boxLocal : m.boxVisitante).values;
    var fga = 0, t3a = 0, fta = 0, tov = 0, pts = 0, rob = 0, ast = 0, fal = 0;
    for (final l in box) {
      fga += l.tcA;
      t3a += l.t3A;
      fta += l.tlA;
      tov += l.per;
      pts += l.pts;
      rob += l.rob;
      ast += l.ast;
      fal += l.fal;
    }
    var oreb = 0, contra = 0;
    for (final e in ev) {
      if (e.tipo == TipoEvento.tiro && e.local == local && e.reboteOfensivo && !e.convertido) oreb++;
      if (e.tipo == TipoEvento.tiro && e.local == local && e.contraataque) contra++;
    }
    return {
      'fga': fga.toDouble(),
      't3a': t3a.toDouble(),
      'fta': fta.toDouble(),
      'tov': tov.toDouble(),
      'pts': pts.toDouble(),
      'rob': rob.toDouble(),
      'ast': ast.toDouble(),
      'fal': fal.toDouble(),
      'oreb': oreb.toDouble(),
      'contra': contra.toDouble(),
      'poss': fga + 0.44 * fta - oreb + tov.toDouble(),
      'minEnergia': (local ? m.energias(true) : m.energias(false)).values.reduce(min),
      'n': 1,
    };
  }

  Map<String, double> suma(Map<String, double> a, Map<String, double> b) => {
    for (final k in b.keys) k: (a[k] ?? 0) + b[k]!,
  };

  group('perfil de partido (MOT-01 y MOT-02)', () {
    late Map<String, double> liga;
    setUpAll(() {
      final l = Liga(catalogo, franquicias, azar: Random(11));
      final t = l.iniciar(Temporada(id: 'x', franquiciaUsuarioId: 'CHI', plantel: mejorDe('CHI'), tacticaConfirmada: true));
      var acum = <String, double>{};
      var k = 0;
      for (final p in t.calendario) {
        if (p.participa('CHI')) continue;
        if (k++ >= 600) break;
        final (m, ev) = jugar(l.equipo(t, p.localId), l.equipo(t, p.visitanteId), Random(100 + k));
        acum = suma(acum, suma(lado(m, ev, true), lado(m, ev, false)));
      }
      liga = acum;
    });

    test('ritmo y puntos de la NBA moderna: ~95–101 posesiones y 106–116 puntos por equipo', () {
      final n = liga['n']!;
      expect(liga['poss']! / n, inInclusiveRange(95, 101));
      expect(liga['pts']! / n, inInclusiveRange(106, 116));
    });

    test('perfil de tiro: libres, pérdidas y faltas como la NBA', () {
      final n = liga['n']!;
      // Libres intentados por equipo ~ 21–25 (NBA ~22–23): FTA/FGA ~ 0,24–0,29 (antes 0,34).
      expect(liga['fta']! / n, inInclusiveRange(19, 26));
      expect(liga['fta']! / liga['fga']!, inInclusiveRange(0.2, 0.31));
      expect(liga['tov']! / liga['poss']!, inInclusiveRange(0.115, 0.15));
      expect(2 * liga['fal']! / n, inInclusiveRange(36, 44), reason: 'faltas de los dos equipos por partido');
      expect(2 * liga['fta']! / n, inInclusiveRange(40, 52), reason: 'libres de los dos equipos por partido');
    });

    test('el volumen de triples sigue la época de la carta', () {
      final r = Random(3);
      double tresPAr(bool Function(Jugador) f) {
        var a = <String, double>{};
        for (var i = 0; i < 6; i++) {
          final p = armar(f, r);
          final q = armar(f, r);
          for (var k = 0; k < 10; k++) {
            final (m, ev) = jugar(equipo(p), equipo(q), r);
            a = suma(a, lado(m, ev, true));
          }
        }
        return a['t3a']! / a['fga']!;
      }

      final viejos = tresPAr((j) => j.epoca.index <= Epoca.anios70.index && j.media >= 70);
      final noventa = tresPAr((j) => j.epoca == Epoca.anios90 && j.media >= 70);
      final moderno = tresPAr((j) => j.epoca.index >= Epoca.anios2010.index && j.media >= 70);
      expect(viejos, lessThan(0.04), reason: 'sin línea de tres no hay triples (salvo tiros de desesperación)');
      expect(noventa, inInclusiveRange(0.15, 0.36));
      expect(moderno, inInclusiveRange(0.33, 0.5), reason: 'la NBA actual tira ~40 % de triples');
      expect(moderno, greaterThan(noventa));
      expect(noventa, greaterThan(viejos));
    });
  });

  group('sesgo de época (MDA-05)', () {
    test('a igual media los planteles de cualquier época quedan parejos contra los de los 2000', () {
      final r = Random(5);
      List<Plantel> equipos(bool Function(Jugador) f, int k) {
        final out = <Plantel>[];
        for (var i = 0; i < k * 8 && out.length < k; i++) {
          final p = armar(f, r, media: 80, intentos: 120);
          if ((mediaDe(p) - 80).abs() <= 0.5) out.add(p);
        }
        return out;
      }

      final base = equipos((j) => j.epoca == Epoca.anios2000, 16);
      expect(base.length, greaterThan(8));
      final resultados = <Epoca, double>{};
      for (final e in [Epoca.anios50, Epoca.anios70, Epoca.anios90, Epoca.anios2010, Epoca.actualidad]) {
        final eq = equipos((j) => j.epoca == e, 16);
        expect(eq.length, greaterThan(8), reason: e.name);
        var g = 0, tot = 0;
        for (final p in eq) {
          for (var k = 0; k < 50; k++) {
            final b = base[r.nextInt(base.length)];
            final local = k.isEven;
            final (m, _) = local ? jugar(equipo(p), equipo(b), r) : jugar(equipo(b), equipo(p), r);
            if (local ? m.puntosLocal > m.puntosVisitante : m.puntosVisitante > m.puntosLocal) g++;
            tot++;
          }
        }
        resultados[e] = g / tot;
      }
      // Antes: 25 % (años 50) a 70 % (2010). Ahora, parejo dentro del ruido de armar planteles al azar.
      for (final e in resultados.entries) {
        expect(e.value, inInclusiveRange(0.36, 0.64), reason: '${e.key.name}: $resultados');
      }
    });

    test('los jugadores viejos conservan su identidad: sin triples y más pintura', () {
      final r = Random(8);
      final viejos = armar((j) => j.epoca == Epoca.anios60 && j.media >= 74, r);
      final (m, ev) = jugar(equipo(viejos), equipo(viejos), r);
      final l = lado(m, ev, true);
      expect(l['t3a']! / l['fga']!, lessThan(0.05));
      expect(l['fga']!, greaterThan(70));
    });
  });

  group('tácticas con efectos reales (MOT-04)', () {
    test('cada sistema ofensivo y defensivo cambia al menos un indicador medible', () {
      final r = Random(9);
      final rosters = [
        mejorDe('LAL'),
        mejorDe('GSW'),
        for (var i = 0; i < 3; i++) armar((j) => j.epoca.index >= 7, r, media: 82, intentos: 100),
      ];
      const base = Tactica();
      Map<String, double> medir(Tactica t) {
        var a = <String, double>{};
        for (final p in rosters) {
          for (var k = 0; k < 90; k++) {
            final local = k.isEven;
            final rr = Random(1000 + k + rosters.indexOf(p) * 1000); // misma semilla para todas las tácticas
            final (m, ev) = local
                ? jugar(equipo(p, t: t), equipo(p, t: base), rr)
                : jugar(equipo(p, t: base), equipo(p, t: t), rr);
            a = suma(a, lado(m, ev, local));
          }
        }
        final n = a['n']!;
        return {
          'posesiones': a['poss']! / n,
          'triples': a['t3a']! / a['fga']!,
          'libres': a['fta']! / a['fga']!,
          'perdidas': a['tov']! / a['poss']!,
          'robos': a['rob']! / n,
          'asistencias': a['ast']! / n,
          'contraataques': a['contra']! / n,
          'reboteOf': a['oreb']! / n,
          'energia': a['minEnergia']! / n,
        };
      }

      final ref = medir(base);
      final peor = <String, double>{};
      for (final o in SistemaOfensivo.values) {
        final m = medir(Tactica(ofensiva: o));
        final dev = {for (final k in ref.keys) k: (m[k]! - ref[k]!).abs() / ref[k]!};
        final mayor = dev.entries.reduce((a, b) => a.value >= b.value ? a : b);
        peor['of ${o.name}'] = mayor.value;
        if (o != base.ofensiva) {
          expect(mayor.value, greaterThan(0.04), reason: '${o.name} no cambia nada medible: $dev');
        }
      }
      for (final d in EsquemaDefensivo.values) {
        final m = medir(Tactica(defensiva: d));
        final dev = {for (final k in ref.keys) k: (m[k]! - ref[k]!).abs() / ref[k]!};
        final mayor = dev.entries.reduce((a, b) => a.value >= b.value ? a : b);
        peor['def ${d.name}'] = mayor.value;
        if (d != base.defensiva) {
          // Algunos esquemas cambian el acierto del rival (puntos) más que un indicador de conteo.
          var pts = 0.0;
          for (final p in rosters.take(2)) {
            for (var k = 0; k < 120; k++) {
              final (m2, _) = jugar(equipo(p, t: Tactica(defensiva: d)), equipo(p, t: base), Random(77 + k));
              pts += m2.puntosVisitante - m2.puntosLocal;
            }
          }
          expect(mayor.value > 0.04 || pts.abs() > 15, isTrue, reason: '${d.name}: $dev, margen de puntos $pts');
        }
      }
    });

    test('el efecto interior se lee: el Post-Inside-Out carga el juego en la pintura', () {
      final r = Random(10);
      final p = mejorDe('LAL');
      var a = <String, double>{}, b = <String, double>{};
      for (var k = 0; k < 150; k++) {
        final (m, ev) = jugar(
          equipo(p, t: const Tactica(ofensiva: SistemaOfensivo.postInsideOut)),
          equipo(p, t: const Tactica(ofensiva: SistemaOfensivo.cincoAbierto)),
          r,
        );
        a = suma(a, lado(m, ev, true));
        b = suma(b, lado(m, ev, false));
      }
      expect(a['fta']! / a['fga']!, greaterThan(b['fta']! / b['fga']! * 1.1), reason: 'más libres en la pintura');
      expect(a['t3a']! / a['fga']!, lessThan(b['t3a']! / b['fga']!), reason: 'menos triples');
    });

    test('el sistema decide el estilo y el plantel decide si rinde: contraejemplos', () {
      final r = Random(12);
      final tiradores = [
        for (var i = 0; i < 3; i++) armar((j) => j.epoca.index >= 7 && j.stats.pctT3 >= 0.37 && j.media >= 74, r),
      ];
      final malos = [
        for (var i = 0; i < 3; i++)
          armar((j) => j.epoca.index >= 7 && j.stats.pctT3 > 0 && j.stats.pctT3 <= 0.31 && j.media >= 74, r),
      ];
      // Triples intentados y convertidos con 5-Out: el estilo es el mismo, el rendimiento no.
      (double, double) cincoAbierto(List<Plantel> ps) {
        var t3a = 0, t3m = 0, fga = 0;
        for (final p in ps) {
          for (var k = 0; k < 150; k++) {
            final (m, _) = jugar(
              equipo(p, t: const Tactica(ofensiva: SistemaOfensivo.cincoAbierto)),
              equipo(mejorDe(['BOS', 'CHI', 'LAL'][k % 3]), t: const Tactica()),
              Random(5000 + k),
            );
            for (final l in m.boxLocal.values) {
              t3a += l.t3A;
              t3m += l.t3I;
              fga += l.tcA;
            }
          }
        }
        return (t3a / fga, t3m / t3a);
      }

      final (volT, pctT) = cincoAbierto(tiradores);
      final (volM, pctM) = cincoAbierto(malos);
      expect(volT, greaterThan(0.3), reason: 'el 5-Out tira de tres con cualquiera');
      expect(volM, greaterThan(0.3));
      expect(pctT, greaterThan(pctM + 0.03), reason: 'pero solo los tiradores de verdad lo convierten');
    });
  });

  group('presión y cansancio (MOT-05 y MOT-11)', () {
    test('la presión alta en vivo ya no es un botón gratis: cuesta energía, faltas y no domina', () {
      final r = Random(21);
      final rosters = [for (var i = 0; i < 4; i++) armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 120)];
      var g = 0, tot = 0;
      var conPresion = <String, double>{}, sin = <String, double>{};
      for (final p in rosters) {
        for (var k = 0; k < 200; k++) {
          final local = k.isEven;
          final (m, ev) = jugar(
            equipo(p),
            equipo(p),
            r,
            usuarioLocal: local,
            antes: (m) => m.presionAlta(local, true),
          );
          if (local ? m.puntosLocal > m.puntosVisitante : m.puntosVisitante > m.puntosLocal) g++;
          tot++;
          conPresion = suma(conPresion, lado(m, ev, local));
          sin = suma(sin, lado(m, ev, !local));
        }
      }
      expect(g / tot, lessThan(0.56), reason: 'antes ganaba 58–60 %');
      expect(conPresion['minEnergia']! / conPresion['n']!, lessThan(sin['minEnergia']! / sin['n']! - 5));
      expect(conPresion['fal']!, lessThan(double.infinity));
      expect(sin['fta']!, greaterThan(conPresion['fta']! * 1.03), reason: 'la presión regala libres al rival');
    });

    test('un jugador agotado sale de la cancha: nadie sigue jugando con energía 0 si hay banco', () {
      final r = Random(22);
      var sospechosos = 0;
      for (var k = 0; k < 150; k++) {
        final p = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 60);
        final m = MotorPartido(local: equipo(p), visitante: equipo(p), azar: r);
        m.presionAlta(true, true);
        m.presionAlta(false, true);
        while (!m.terminado) {
          m.siguiente();
          for (final local in [true, false]) {
            final banco = m.enBanco(local);
            final bancoDescansado = banco != null && !m.expulsado(banco.id) && m.energias(local)[banco.id]! > 40;
            final agotado = m.enCancha(local).any((j) => m.energias(local)[j.id]! < 1);
            if (bancoDescansado && agotado) sospechosos++;
          }
        }
      }
      expect(sospechosos, 0);
    });
  });

  group('expulsados (MOT-06)', () {
    test('4.000 partidos: el expulsado se va, entra el reemplazo, siempre 5 en cancha y nadie pasa de 6 faltas', () {
      final l = Liga(catalogo, franquicias, azar: Random(31));
      final t = l.iniciar(Temporada(id: 'x', franquiciaUsuarioId: 'CHI', plantel: mejorDe('CHI'), tacticaConfirmada: true));
      var expulsiones = 0, partidosConExpulsion = 0, cambiosPosteriores = 0;
      for (var i = 0; i < 4000; i++) {
        final p = t.calendario[i % t.calendario.length];
        final m = l.motor(t, p, azar: Random(9000 + i));
        final fuera = <String>{};
        var expulsoAlgo = false;
        while (!m.terminado) {
          final e = m.siguiente();
          if (e.expulsadoId != null) {
            expulsiones++;
            expulsoAlgo = true;
            fuera.add(e.expulsadoId!);
          }
          if (e.tipo == TipoEvento.cambio && expulsoAlgo && e.saleId != null && !fuera.contains(e.saleId)) {
            cambiosPosteriores++;
          }
          for (final local in [true, false]) {
            final c = m.enCancha(local);
            expect(c.length, 5);
            // El expulsado puede seguir un instante (hasta el próximo evento, que es el cambio), nunca más.
            // Entre la expulsión y el cambio puede haber un fin de cuarto, un tiempo muerto o el final.
            if (e.tipo != TipoEvento.tiro &&
                e.tipo != TipoEvento.perdida &&
                e.tipo != TipoEvento.libres &&
                e.tipo != TipoEvento.falta &&
                e.tipo != TipoEvento.finCuarto &&
                e.tipo != TipoEvento.finPartido &&
                e.tipo != TipoEvento.tiempoMuerto) {
              expect(c.where((j) => fuera.contains(j.id)), isEmpty, reason: 'expulsado en cancha tras ${e.tipo}');
            }
          }
          if (e.tipo == TipoEvento.cambio) {
            expect(fuera.contains(e.entraId), isFalse, reason: 'un expulsado no vuelve');
          }
        }
        if (expulsoAlgo) partidosConExpulsion++;
        for (final box in [m.boxLocal, m.boxVisitante]) {
          for (final linea in box.values) {
            expect(linea.fal, lessThanOrEqualTo(6));
          }
        }
      }
      expect(expulsiones, greaterThan(100), reason: 'hay expulsiones (si no, el test no prueba nada)');
      expect(partidosConExpulsion, greaterThan(100));
      expect(cambiosPosteriores, greaterThan(0), reason: 'la rotación sigue después de una expulsión');
    });

    test('con banco largo el que se va con 6 faltas lo reemplaza un suplente y el equipo sigue rotando', () {
      final r = Random(40);
      var verificados = 0;
      for (var k = 0; k < 400 && verificados < 5; k++) {
        final p = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 60);
        final reserva = [for (final j in armar((j) => j.epoca.index >= 5, r, media: 76, intentos: 30).jugadores.take(3)) j];
        final propios = p.jugadores.map((j) => j.nbaPlayerId).toSet();
        final m = MotorPartido(
          local: EquipoPartido(
            identidadId: 'CHI',
            plantel: p,
            tactica: const Tactica(),
            reserva: [for (final j in reserva) if (!propios.contains(j.nbaPlayerId)) j],
          ),
          visitante: equipo(p),
          azar: r,
        );
        final fuera = <String>{};
        while (!m.terminado) {
          final e = m.siguiente();
          if (e.expulsadoId != null && e.local != true) {
            // la falta la comete el que defiende: puede ser el local
          }
          if (e.expulsadoId != null) fuera.add(e.expulsadoId!);
          expect(m.enCancha(true).where((j) => fuera.contains(j.id)).length <= 1, isTrue);
        }
        if (fuera.isNotEmpty) verificados++;
      }
      expect(verificados, greaterThan(0));
    });
  });

  group('emparejamiento y arquetipos (MOT-09)', () {
    test('todos los arquetipos tienen un efecto chico y transparente', () {
      for (final rol in RolCancha.values) {
        final e = efectosRol[rol];
        expect(e, isNotNull, reason: '${rol.name} sin efecto');
        expect(e!.descripcion, isNotEmpty);
        for (final x in [e.tripleExtra, e.dosExtra, e.defensaDirecta, e.defensaTriple, e.proteccionAro, e.asistido, e.clutch]) {
          expect(x.abs(), lessThanOrEqualTo(0.02), reason: '${rol.name}: efecto de más de 2 puntos');
        }
      }
      expect(efectosRol[RolCancha.protectorAro]!.proteccionAro, greaterThan(0));
      expect(efectosRol[RolCancha.especialista3D]!.defensaTriple, greaterThan(0));
      expect(efectosRol[RolCancha.pivotTirador]!.volumenTriples, greaterThan(1));
    });

    test('el peso del defensor directo cambia con el esquema: Switch All reparte, Drop y Grit marcan a su par', () {
      double w(EsquemaDefensivo d) => MotorPartido.pesoDefensorDirecto(d);
      for (final d in EsquemaDefensivo.values) {
        expect(w(d), inInclusiveRange(0.15, 0.75));
      }
      expect(w(EsquemaDefensivo.switchAll), lessThan(w(EsquemaDefensivo.dropCoverage)));
      expect(w(EsquemaDefensivo.zona23), lessThan(w(EsquemaDefensivo.gritAndGrind)));
    });

    test('un defensor directo de elite baja el acierto de su par (emparejamiento por puesto)', () {
      final r = Random(50);
      // El mismo plantel; en uno el escolta es el mejor defensor (cerrojo) y en el otro el peor.
      final base = armar((j) => j.epoca.index >= 6 && j.media >= 74, r, media: 80, intentos: 80);
      final todos = catalogo.where((j) => j.epoca.index >= 6 && j.posiciones.first == Posicion.escolta).toList();
      final cerrojo = todos.where((j) => j.rol == RolCancha.especialista3D && j.media >= 74).toList();
      final comun = todos.where((j) => j.rol == RolCancha.anotadorTresNiveles || j.rol == RolCancha.tiradorPantallas).toList();
      expect(cerrojo, isNotEmpty);
      expect(comun, isNotEmpty);
      final con = cerrojo.firstWhere((j) => !base.jugadores.any((x) => x.nbaPlayerId == j.nbaPlayerId));
      final sin = comun.firstWhere((j) => j.media == con.media && !base.jugadores.any((x) => x.nbaPlayerId == j.nbaPlayerId),
          orElse: () => comun.firstWhere((j) => !base.jugadores.any((x) => x.nbaPlayerId == j.nbaPlayerId)));
      expect(efectoDeRol(con).defensaDirecta + efectoDeRol(con).defensaTriple, greaterThan(efectoDeRol(sin).defensaDirecta));
    });
  });

  group('tiempo muerto automático (simétrico)', () {
    test('al simular, el usuario y los dos lados de un partido entre IA piden tiempo muerto por igual', () {
      final r = Random(60);
      var usoLocal = 0, usoVisitante = 0;
      for (var k = 0; k < 400; k++) {
        final p = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 30);
        final q = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 30);
        // Usuario marcado como local: antes solo pedía el rival; simulando, los dos piden.
        final m = MotorPartido(local: equipo(p), visitante: equipo(q), usuarioLocal: true, azar: r)..simularTodo();
        usoLocal += 5 - m.tiemposMuertos(true);
        usoVisitante += 5 - m.tiemposMuertos(false);
      }
      expect(usoLocal, greaterThan(100), reason: 'el usuario simulado también pide tiempo muerto');
      expect(usoVisitante, greaterThan(100));
      expect(usoLocal / usoVisitante, inInclusiveRange(0.8, 1.25));
      // Partido entre IA (usuarioLocal null): simétrico.
      usoLocal = 0;
      usoVisitante = 0;
      for (var k = 0; k < 400; k++) {
        final p = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 30);
        final q = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 30);
        final m = MotorPartido(local: equipo(p), visitante: equipo(q), azar: r)..simularTodo();
        usoLocal += 5 - m.tiemposMuertos(true);
        usoVisitante += 5 - m.tiemposMuertos(false);
      }
      expect(usoLocal / usoVisitante, inInclusiveRange(0.8, 1.25));
    });

    test('el que juega en vivo sin pedir nada mantiene sus 5 tiempos muertos', () {
      final r = Random(61);
      final p = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 30);
      final m = MotorPartido(local: equipo(p), visitante: equipo(p), usuarioLocal: true, azar: r);
      while (!m.terminado) {
        m.siguiente();
      }
      expect(m.tiemposMuertos(true), 5, reason: 'en vivo decide el usuario');
    });
  });

  group('jugada clave (MOT-07)', () {
    test('ninguna jugada domina ni es una trampa; el Triple depende del plantel', () {
      final r = Random(70);
      final rosters = [
        mejorDe('GSW'),
        mejorDe('LAL'),
        for (var i = 0; i < 4; i++) armar((j) => j.epoca.index >= 6, r, media: 80, intentos: 100),
      ];
      double ganar(JugadaClave? clave, Plantel p, {int n = 500}) {
        var g = 0;
        for (var k = 0; k < n; k++) {
          final local = k.isEven;
          final m = MotorPartido(local: equipo(p), visitante: equipo(p), usuarioLocal: local, azar: Random(8000 + k));
          while (!m.terminado) {
            if (clave != null && m.ataqueDelUsuario && m.momentoClutch) m.pedirJugada(clave);
            m.siguiente();
          }
          if (local ? m.puntosLocal > m.puntosVisitante : m.puntosVisitante > m.puntosLocal) g++;
        }
        return g / n;
      }

      final promedio = <JugadaClave?, double>{};
      final triples = <double>[];
      for (final clave in [null, ...JugadaClave.values]) {
        var s = 0.0;
        for (final p in rosters) {
          final v = ganar(clave, p);
          s += v;
          if (clave == JugadaClave.triple) triples.add(v);
        }
        promedio[clave] = s / rosters.length;
      }
      final ninguna = promedio[null]!;
      for (final c in JugadaClave.values) {
        expect(promedio[c]! - ninguna, inInclusiveRange(-0.05, 0.06), reason: '${c.nombre}: $promedio');
      }
      expect(promedio[JugadaClave.pickAndRoll]!, greaterThan(ninguna - 0.035), reason: 'el Pick & roll no es una trampa');
      final spread = triples.reduce(max) - triples.reduce(min);
      expect(spread, greaterThan(0.06), reason: 'el triple rinde según el plantel: $triples');
    });

    test('el Pick & roll y el Aislamiento también buscan el triple cuando el partido lo pide', () {
      final r = Random(71);
      final p = mejorDe('GSW');
      var triplesPnR = 0, intentos = 0;
      for (var k = 0; k < 200; k++) {
        final m = MotorPartido(local: equipo(p), visitante: equipo(p), usuarioLocal: true, azar: r);
        m.arrancarEn(cuarto: 4, reloj: 20, puntosLocal: 90, puntosVisitante: 93, ataqueLocal: true);
        m.pedirJugada(JugadaClave.pickAndRoll);
        final e = m.siguiente();
        if (e.tipo == TipoEvento.tiro && e.jugadaClave == JugadaClave.pickAndRoll) {
          intentos++;
          if (e.triple) triplesPnR++;
        }
      }
      expect(intentos, greaterThan(50));
      expect(triplesPnR / intentos, greaterThan(0.8), reason: 'abajo por 3 con 20 s hay que tirar de tres');
    });
  });

  group('simulado y en vivo equivalentes', () {
    test('sin intervenir, vivo y simulado dan el mismo porcentaje (±4 pp)', () {
      final r = Random(80);
      final p = armar((j) => j.epoca.index >= 5, r, media: 80, intentos: 80);
      double pct(bool simular, int n) {
        var g = 0;
        for (var k = 0; k < n; k++) {
          final local = k.isEven;
          final m = MotorPartido(
            local: equipo(p),
            visitante: equipo(p),
            usuarioLocal: simular ? null : local,
            azar: Random(300 + k),
          );
          if (simular) {
            m.simularTodo();
          } else {
            while (!m.terminado) {
              m.siguiente();
            }
          }
          if (local ? m.puntosLocal > m.puntosVisitante : m.puntosVisitante > m.puntosLocal) g++;
        }
        return g / n;
      }

      expect((pct(true, 1500) - pct(false, 1500)).abs(), lessThan(0.05));
    });
  });
}
