import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/motor.dart';
import 'package:dinastia_nba/domain/relato/relato.dart';
import 'package:dinastia_nba/domain/relator.dart' show Relator;
import 'package:flutter_test/flutter_test.dart';

/// Partido simulado con su relato: (evento, líneas, ¿clutch?, ¿final apretado?).
typedef Registro = ({EventoPartido e, List<LineaRelato> lineas, bool clutch, bool apretado});

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(3));
  var p = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    p = p.asignar(chi.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final t = liga.iniciar(Temporada(id: 'rel', franquiciaUsuarioId: 'CHI', plantel: p, tacticaConfirmada: true));
  final jugadores = {for (final j in catalogo) j.id: j};
  final ctx = ContextoRelato(
    jugadores: jugadores,
    nombreLocal: 'Bulls',
    nombreVisitante: 'Lakers',
    ciudadLocal: 'Chicago',
    ciudadVisitante: 'Los Ángeles',
    usuarioLocal: true,
    playoffs: true,
    ronda: 'Semifinales del Este',
    juegoSerie: 4,
    victoriasLocalSerie: 3,
    victoriasVisitanteSerie: 2,
    ritmoAlto: true,
    energiaDe: (id) => id.length % 5 == 0 ? 30 : 90,
    victorias: 50,
    derrotas: 20,
    rachaVictorias: 5,
    historialVictorias: 2,
    historialDerrotas: 1,
    ultimoResultado: '104-99 a favor',
    rivalidad: 'el clásico del Medio Oeste',
    recordEnJuego: 'a 12 puntos del máximo de la temporada',
    historia: 'vienen de ganar cinco seguidos',
  );

  final partidos = <List<Registro>>[];
  final aperturas = <List<LineaRelato>>[];
  setUpAll(() {
    for (var i = 0; i < 30; i++) {
      final m = liga.motor(t, t.calendario[i], azar: Random(700 + i));
      final r = Relato(azar: Random(i));
      aperturas.add(r.apertura(ctx));
      final reg = <Registro>[];
      while (!m.terminado) {
        final e = m.siguiente();
        reg.add((
          e: e,
          lineas: r.linea(e, ctx),
          clutch: e.cuarto >= 4 && e.reloj <= 300 && (e.marcadorLocal - e.marcadorVisitante).abs() <= 6,
          apretado:
              e.cuarto >= 4 &&
              e.tipo != TipoEvento.finCuarto &&
              e.reloj <= 150 &&
              (e.marcadorLocal - e.marcadorVisitante).abs() <= 5,
        ));
      }
      partidos.add(reg);
    }
  });

  Iterable<Registro> todos() => partidos.expand((x) => x);
  Iterable<LineaRelato> lineas() => todos().expand((r) => r.lineas);

  test('catálogo: todas las situaciones, ambos personajes, varias variantes y ninguna vacía', () {
    for (final s in Situacion.values) {
      final f = catalogoRelato[s];
      expect(f, isNotNull, reason: '$s sin frases');
      for (final per in Personaje.values) {
        final l = f!.de(per);
        expect(l.length, greaterThanOrEqualTo(3), reason: '$s/$per');
        expect(l.where((x) => x.replaceAll(RegExp(r'^[~^]'), '').trim().isEmpty), isEmpty);
        expect(l.where((x) => !x.startsWith('~') && !x.startsWith('^')).length, greaterThanOrEqualTo(3));
        expect(l.toSet().length, l.length, reason: 'repetidas en $s/$per');
      }
    }
  });

  test('marcadores del catálogo conocidos (ninguna llave sin completar)', () {
    final conocidos = {
      ...'q a d p r e s x g eq rv reloj cq lib nlib libtxt res falta_n motivo gan perd pg pp mejor parcial cambios'
          .split(' '),
      ...'nloc nvis ciudad marc dif lider usuario rival serie ronda juego vic der racha hv hd ultimo riv rec hist'
          .split(' '),
      ...'rach n dm linea pts ceq crv cloc cvis cusuario ganando'.split(' '),
    };
    final re = RegExp(r'\{(\w+)\}');
    for (final (s, per, t) in Relato.plantillas) {
      for (final m in re.allMatches(t)) {
        expect(conocidos, contains(m[1]), reason: '$s/$per: $t');
      }
    }
  });

  test('partidos simulados: ninguna línea vacía ni con restos de plantilla', () {
    expect(lineas().length, greaterThan(1000));
    for (final l in lineas()) {
      expect(l.texto.trim(), isNotEmpty);
      expect(l.texto, isNot(contains('{')));
      expect(l.texto, isNot(contains('  ')));
      expect(l.texto, isNot(contains(' .')));
      expect(l.intensidad, inInclusiveRange(0, 4));
    }
  });

  test('cobertura: las situaciones de jugada aparecen en partidos simulados', () {
    final vistas = {...lineas().map((l) => l.situacion), ...aperturas.expand((a) => a).map((l) => l.situacion)};
    final faltan = Situacion.values.where((s) => !vistas.contains(s)).toList();
    // Solo pueden faltar las que dependen de datos que no hay en el partido y las muy raras.
    const aceptables = {
      Situacion.ritmoAlto,
      Situacion.ritmoBajo,
      Situacion.retoma,
      Situacion.record,
      Situacion.rivalidad,
      Situacion.prorroga,
      Situacion.localia,
      Situacion.playoffs,
      Situacion.historiaTemporada,
      Situacion.chicharraLejana,
      Situacion.interferencia,
      Situacion.cambioExpulsion,
      Situacion.expulsion,
      Situacion.fatiga,
      Situacion.tripleDoble,
      Situacion.tiempoMuertoParcial,
      Situacion.tramite,
    };
    expect(faltan.where((s) => !aceptables.contains(s)), isEmpty, reason: 'faltan: $faltan');
  });

  test('cobertura sintética: cada situación de jugada sale de la jugada correcta', () {
    EventoPartido ev(
      TipoEvento tipo, {
      bool convertido = false,
      bool triple = false,
      bool volcada = false,
      bool alley = false,
      bool tap = false,
      bool rebOf = false,
      bool lejos = false,
      bool chich = false,
      bool interf = false,
      int libres = 0,
      int puntos = 0,
      TipoPerdida? perdida,
      TipoFalta? falta,
      String? defensor,
      String? asist,
      int cuarto = 2,
    }) => EventoPartido(
      tipo: tipo,
      local: true,
      cuarto: cuarto,
      reloj: 400,
      marcadorLocal: 50,
      marcadorVisitante: 40,
      texto: '',
      jugadorId: 'a',
      defensorId: defensor,
      reboteId: rebOf ? 'b' : null,
      entraId: tipo == TipoEvento.cambio ? 'b' : null,
      saleId: tipo == TipoEvento.cambio ? 'd' : null,
      asistenteId: asist,
      convertido: convertido,
      triple: triple,
      volcada: volcada,
      alleyOop: alley,
      taponado: tap,
      reboteOfensivo: rebOf,
      desdeLejos: lejos,
      chicharra: chich,
      interferencia: interf,
      libres: libres,
      puntos: puntos,
      perdida: perdida,
      falta: falta,
    );
    final casos = <Situacion, EventoPartido>{
      Situacion.doble: ev(TipoEvento.tiro, convertido: true, puntos: 2),
      Situacion.dobleAsistido: ev(TipoEvento.tiro, convertido: true, asist: 'b'),
      Situacion.triple: ev(TipoEvento.tiro, convertido: true, triple: true),
      Situacion.volcada: ev(TipoEvento.tiro, convertido: true, volcada: true),
      Situacion.alleyOop: ev(TipoEvento.tiro, convertido: true, volcada: true, alley: true, asist: 'b'),
      Situacion.canastaYFalta: ev(TipoEvento.tiro, convertido: true, libres: 1, puntos: 3),
      Situacion.chicharraLejana: ev(TipoEvento.tiro, convertido: true, lejos: true),
      Situacion.chicharra: ev(TipoEvento.tiro, convertido: true, chich: true),
      Situacion.interferencia: ev(TipoEvento.tiro, convertido: true, interf: true, defensor: 'd'),
      Situacion.tapon: ev(TipoEvento.tiro, tap: true, defensor: 'd'),
      Situacion.taponRecuperado: ev(TipoEvento.tiro, tap: true, rebOf: true, defensor: 'd'),
      Situacion.reboteOfensivo: ev(TipoEvento.tiro, rebOf: true),
      Situacion.ladrillo: ev(TipoEvento.tiro),
      Situacion.tiroDesesperado: ev(TipoEvento.tiro, lejos: true),
      Situacion.libresPerfectos: ev(TipoEvento.libres, libres: 2, puntos: 2),
      Situacion.libresParciales: ev(TipoEvento.libres, libres: 2, puntos: 1),
      Situacion.libresFallados: ev(TipoEvento.libres, libres: 2),
      Situacion.robo: ev(TipoEvento.perdida, perdida: TipoPerdida.robo, defensor: 'd'),
      Situacion.perdidaAfuera: ev(TipoEvento.perdida, perdida: TipoPerdida.afuera),
      Situacion.perdida24: ev(TipoEvento.perdida, perdida: TipoPerdida.veinticuatro),
      Situacion.perdida3s: ev(TipoEvento.perdida, perdida: TipoPerdida.tresSegundos),
      Situacion.campoAtras: ev(TipoEvento.perdida, perdida: TipoPerdida.campoAtras),
      Situacion.pasos: ev(TipoEvento.perdida, perdida: TipoPerdida.pasos),
      Situacion.dobles: ev(TipoEvento.perdida, perdida: TipoPerdida.dobles),
      Situacion.carga: ev(TipoEvento.perdida, perdida: TipoPerdida.carga),
      Situacion.faltaPersonal: ev(TipoEvento.falta, falta: TipoFalta.personal, defensor: 'd'),
      Situacion.bonus: ev(TipoEvento.falta, falta: TipoFalta.bonus, defensor: 'd', libres: 2),
      Situacion.tecnica: ev(TipoEvento.falta, falta: TipoFalta.tecnica, defensor: 'd', libres: 1),
      Situacion.flagrante: ev(TipoEvento.falta, falta: TipoFalta.flagrante, defensor: 'd', libres: 2),
      Situacion.intencional: ev(TipoEvento.falta, falta: TipoFalta.intencional, defensor: 'd', libres: 2),
      Situacion.salto: ev(TipoEvento.salto, defensor: 'd'),
      Situacion.cambio: ev(TipoEvento.cambio),
      Situacion.tiempoMuerto: ev(TipoEvento.tiempoMuerto),
      Situacion.finCuarto: ev(TipoEvento.finCuarto, cuarto: 2),
      Situacion.entretiempo: ev(TipoEvento.finCuarto, cuarto: 3),
      Situacion.prorroga: ev(TipoEvento.finCuarto, cuarto: 5),
      Situacion.finPartido: ev(TipoEvento.finPartido, cuarto: 4),
    };
    for (final MapEntry(key: s, value: e) in casos.entries) {
      expect(Relato.situacionDe(e), s, reason: '$s');
    }
    // finCuarto del 1.º cuarto y del 3.º son finCuarto; el 2.º es el descanso.
    expect(Relato.situacionDe(ev(TipoEvento.finCuarto, cuarto: 2)), Situacion.finCuarto);
    expect(Relato.situacionDe(ev(TipoEvento.finCuarto, cuarto: 3)), Situacion.entretiempo);
    // Triple de cierre y libres decisivos solo con final apretado.
    final tri = ev(TipoEvento.tiro, convertido: true, triple: true);
    expect(Relato.situacionDe(tri, finalApretado: true), Situacion.tripleCierre);
    expect(Relato.situacionDe(tri), Situacion.triple);
    final lib = ev(TipoEvento.libres, libres: 2, puntos: 2);
    expect(Relato.situacionDe(lib, finalApretado: true), Situacion.lineaDeSuspiros);
    // Las líneas reales de cada una salen completas, con cualquier jugador.
    for (final MapEntry(key: s, value: e) in casos.entries) {
      final r = Relato(azar: Random(1));
      final c = ContextoRelato(
        jugadores: {
          for (final k in ['a', 'b', 'd']) k: chi.first,
        },
        nombreLocal: 'Bulls',
        nombreVisitante: 'Lakers',
      );
      final ls = r.linea(e, c, siempre: true);
      expect(ls.where((l) => l.situacion == s || l.situacion == Situacion.aro), isNotEmpty, reason: '$s');
      for (final l in ls) {
        expect(l.texto, isNot(contains('{')), reason: '$s: ${l.texto}');
      }
    }
  });

  test('cada situación solo se dispara cuando corresponde', () {
    for (final r in todos()) {
      final e = r.e;
      for (final l in r.lineas) {
        switch (l.situacion) {
          case Situacion.tripleCierre:
            expect(r.apretado && e.triple && e.convertido, isTrue, reason: l.texto);
          case Situacion.lineaDeSuspiros:
            expect(r.apretado && e.tipo == TipoEvento.libres, isTrue, reason: l.texto);
          case Situacion.libresPerfectos || Situacion.libresParciales || Situacion.libresFallados:
            expect(e.tipo == TipoEvento.libres && !r.apretado, isTrue, reason: l.texto);
          case Situacion.volcada:
            expect(e.volcada && !e.alleyOop, isTrue);
          case Situacion.alleyOop:
            expect(e.alleyOop, isTrue);
          case Situacion.tapon:
            expect(e.taponado && !e.reboteOfensivo, isTrue);
          case Situacion.taponRecuperado:
            expect(e.taponado && e.reboteOfensivo, isTrue);
          case Situacion.robo:
            expect(e.tipo == TipoEvento.perdida && e.defensorId != null, isTrue);
          case Situacion.perdida24:
            expect(e.perdida, TipoPerdida.veinticuatro);
          case Situacion.bonus:
            expect(e.falta, TipoFalta.bonus);
          case Situacion.tecnica:
            expect(e.falta, TipoFalta.tecnica);
          case Situacion.flagrante:
            expect(e.falta, TipoFalta.flagrante);
          case Situacion.intencional:
            expect(e.falta, TipoFalta.intencional);
          case Situacion.chicharra:
            expect(e.chicharra && e.convertido, isTrue);
          case Situacion.chicharraLejana:
            expect(e.desdeLejos && e.convertido, isTrue);
          case Situacion.tiroDesesperado:
            expect(e.desdeLejos && !e.convertido, isTrue);
          case Situacion.canastaYFalta:
            expect(e.tipo == TipoEvento.tiro && e.convertido && e.libres > 0, isTrue);
          case Situacion.ladrillo || Situacion.aro:
            expect(e.tipo == TipoEvento.tiro && !e.convertido, isTrue);
          case Situacion.triple:
            expect(e.triple && e.convertido && !r.apretado, isTrue);
          case Situacion.finPartido:
            expect(e.tipo, TipoEvento.finPartido);
          case Situacion.finCuarto || Situacion.entretiempo || Situacion.prorroga:
            expect(e.tipo, TipoEvento.finCuarto);
          case Situacion.tiempoMuerto || Situacion.tiempoMuertoParcial:
            expect(e.tipo, TipoEvento.tiempoMuerto);
          case Situacion.clutch:
            expect(r.clutch, isTrue);
          case Situacion.cambio || Situacion.cambioFaltas || Situacion.cambioExpulsion:
            expect(e.tipo, TipoEvento.cambio);
          default:
        }
      }
    }
  });

  test('el diálogo no habla en cada jugada: proporción de líneas y silencios', () {
    final eventos = todos().length;
    final n = lineas().length;
    final porJugada = n / eventos;
    expect(porJugada, inInclusiveRange(0.45, 1.3), reason: '$porJugada');
    final silencios = todos().where((r) => r.lineas.isEmpty).length / eventos;
    expect(silencios, inInclusiveRange(0.2, 0.6), reason: '$silencios');
    final relator = lineas().where((l) => l.personaje == Personaje.relator).length;
    final comentarista = n - relator;
    expect(relator, greaterThan(comentarista), reason: 'el Relator canta más de lo que el Comentarista comenta');
    expect(comentarista / n, inInclusiveRange(0.15, 0.45));
    expect(todos().every((r) => r.lineas.length <= 4), isTrue);
  });

  test('el Comentarista abre; el cierre de cuarto y de partido lo dicen los dos', () {
    for (final a in aperturas) {
      expect(a.first.personaje, Personaje.comentarista);
      expect(a.any((l) => l.personaje == Personaje.relator), isTrue);
      expect(a.length, inInclusiveRange(3, 6));
    }
    for (final r in todos().where((r) => r.e.tipo == TipoEvento.finCuarto || r.e.tipo == TipoEvento.finPartido)) {
      expect(r.lineas.map((l) => l.personaje).toSet(), {
        Personaje.relator,
        Personaje.comentarista,
      }, reason: '${r.e.tipo}');
    }
  });

  test('variedad: no se repite la misma frase seguida ni en una ventana corta', () {
    for (final g in partidos) {
      for (final per in Personaje.values) {
        final ult = <String>[];
        for (final l in g.expand((r) => r.lineas).where((l) => l.personaje == per)) {
          // La misma frase exacta no reaparece en las 4 anteriores del mismo personaje.
          expect(ult.reversed.take(4), isNot(contains(l.texto)), reason: l.texto);
          ult.add(l.texto);
        }
      }
    }
    // Una misma situación, 40 veces: las variantes rotan.
    final r = Relato(azar: Random(5));
    final e = EventoPartido(
      tipo: TipoEvento.tiro,
      local: true,
      cuarto: 2,
      reloj: 300,
      marcadorLocal: 20,
      marcadorVisitante: 18,
      texto: '',
      jugadorId: chi.first.id,
      convertido: true,
      triple: true,
      puntos: 3,
    );
    final textos = [
      for (var i = 0; i < 60; i++)
        ...r
            .linea(e, ContextoRelato(jugadores: jugadores), siempre: true)
            .where((l) => l.personaje == Personaje.relator)
            .map((l) => l.texto),
    ];
    for (var i = 3; i < textos.length; i++) {
      expect(textos.sublist(i - 3, i), isNot(contains(textos[i])));
    }
    expect(textos.toSet().length, greaterThanOrEqualTo(4));
  });

  test('la intensidad sube en el clutch, el final apretado y los playoffs', () {
    double prom(Iterable<LineaRelato> ls) => ls.map((l) => l.intensidad).reduce((a, b) => a + b) / ls.length;
    final clutch = prom(todos().where((r) => r.clutch).expand((r) => r.lineas));
    final resto = prom(todos().where((r) => !r.clutch).expand((r) => r.lineas));
    expect(clutch, greaterThan(resto + 0.8), reason: '$clutch vs $resto');
    final apretado = prom(todos().where((r) => r.apretado).expand((r) => r.lineas));
    expect(apretado, greaterThan(clutch));
    // Mismas jugadas con y sin playoffs.
    double total(bool playoffs) {
      var suma = 0, n = 0;
      for (var i = 0; i < 3; i++) {
        final m = liga.motor(t, t.calendario[i], azar: Random(900 + i));
        final r = Relato(azar: Random(i));
        final c = ContextoRelato(jugadores: jugadores, nombreLocal: 'A', nombreVisitante: 'B', playoffs: playoffs);
        while (!m.terminado) {
          for (final l in r.linea(m.siguiente(), c, siempre: true)) {
            suma += l.intensidad;
            n++;
          }
        }
      }
      return suma / n;
    }

    expect(total(true), greaterThan(total(false)));
    // En trámite (diferencia grande en el 3.º) es más mesurado que en el cierre parejo.
    final tramite = todos().where((r) => (r.e.marcadorLocal - r.e.marcadorVisitante).abs() >= 20 && r.e.cuarto >= 3);
    if (tramite.expand((r) => r.lineas).isNotEmpty) {
      expect(prom(tramite.expand((r) => r.lineas)), lessThan(clutch));
    }
  });

  test('contexto: parciales, remontadas, rachas y récords aparecen con su condición', () {
    final ls = lineas().toList();
    expect(ls.where((l) => l.situacion == Situacion.parcialAFavor), isNotEmpty);
    expect(ls.where((l) => l.situacion == Situacion.rachaTirador), isNotEmpty);
    expect(ls.where((l) => l.situacion == Situacion.dobleDoble), isNotEmpty);
    expect(ls.where((l) => l.situacion == Situacion.jugadorDominante), isNotEmpty);
    expect(ls.where((l) => l.situacion == Situacion.clutch), isNotEmpty);
    // Un parcial a favor siempre dice una racha de 8 o más.
    for (final l in ls.where((l) => l.situacion == Situacion.parcialAFavor && l.personaje == Personaje.relator)) {
      final m = RegExp(r'(\d+)(-0| puntos)').firstMatch(l.texto);
      if (m != null) expect(int.parse(m[1]!), greaterThanOrEqualTo(8), reason: l.texto);
    }
    // Las remontadas citan un déficit de 10 o más.
    for (final l in ls.where((l) => l.situacion == Situacion.remontada && l.personaje == Personaje.relator)) {
      final m = RegExp(r'(\d+) (puntos )?(en contra|abajo)').firstMatch(l.texto);
      if (m != null) expect(int.parse(m[1]!), greaterThanOrEqualTo(10), reason: l.texto);
    }
    // Aperturas con los datos de contexto (serie, historial).
    final aperturasTexto = aperturas.expand((a) => a).map((l) => l.texto).join(' ');
    expect(aperturasTexto, contains('Chicago'));
    expect(aperturasTexto, anyOf(contains('serie'), contains('Semifinales'), contains('eliminación')));
  });

  test('los datos de contexto opcionales se cuentan cuando existen', () {
    ContextoRelato con(Map<String, Object> campos) => ContextoRelato(
      jugadores: jugadores,
      nombreLocal: 'Bulls',
      nombreVisitante: 'Lakers',
      ciudadLocal: 'Chicago',
      usuarioLocal: true,
      rivalidad: campos['riv'] as String?,
      victorias: campos['v'] as int?,
      derrotas: campos['d'] as int?,
      historialVictorias: campos['hv'] as int?,
      historialDerrotas: campos['hd'] as int?,
      recordEnJuego: campos['rec'] as String?,
      historia: campos['his'] as String?,
    );
    final casos = {
      Situacion.rivalidad: con({'riv': 'el clásico del Medio Oeste'}),
      Situacion.record: con({'v': 50, 'd': 20}),
      Situacion.historial: con({'hv': 2, 'hd': 1}),
      Situacion.localia: con({}),
      Situacion.recordEnJuego: con({'rec': 'a 3 triples del récord'}),
      Situacion.historiaTemporada: con({'his': 'vienen de perder tres seguidos'}),
    };
    for (final MapEntry(key: s, value: c) in casos.entries) {
      final l = Relato(azar: Random(1)).apertura(c);
      expect(l.map((x) => x.situacion), contains(s), reason: '$s');
    }
  });

  test('sin contexto de playoffs no se habla de series ni de eliminación', () {
    final r = Relato(azar: Random(2));
    final c = ContextoRelato(
      jugadores: jugadores,
      nombreLocal: 'Bulls',
      nombreVisitante: 'Lakers',
      ciudadLocal: 'Chicago',
    );
    final m = liga.motor(t, t.calendario[0], azar: Random(1));
    final dichas = [...r.apertura(c)];
    while (!m.terminado) {
      dichas.addAll(r.linea(m.siguiente(), c));
    }
    expect(
      dichas.where((l) => {Situacion.serie, Situacion.eliminacion, Situacion.playoffs}.contains(l.situacion)),
      isEmpty,
    );
  });

  test('observar y retomar: saltar el partido no rompe el relato', () {
    final r = Relato(azar: Random(3));
    final m = liga.motor(t, t.calendario[1], azar: Random(4));
    for (var i = 0; i < 300 && !m.terminado; i++) {
      r.observar(m.siguiente(), ctx);
    }
    final l = r.retoma(ctx);
    expect(l.map((x) => x.personaje).toSet(), {Personaje.relator, Personaje.comentarista});
    for (final x in l) {
      expect(x.texto, isNot(contains('{')));
    }
  });

  test('compatibilidad: Relator.frase devuelve siempre una frase', () {
    final relator = Relator(azar: Random(1));
    final m = liga.motor(t, t.calendario[2], azar: Random(9));
    while (!m.terminado) {
      expect(relator.frase(m.siguiente(), jugadores).trim(), isNotEmpty);
    }
  });

  test('sin nombres de personas reales en ningún texto del relato', () {
    // Nombres de narradores reales (lista de guarda: nunca deben aparecer en la UI ni en las frases).
    const prohibidos = [
      'Tirico',
      'Gus Johnson',
      'Marv Albert',
      'Mike Breen',
      'Doris Burke',
      'Kevin Harlan',
      'Jorge Sedano',
      'Sedano',
      'Garrafa',
      'Sánchez',
      'Hugo Sigman',
      'Dani Rouco',
      'Daniel Rouco',
      'Ernesto Mosquera',
      'Mosquera',
      'Fabián Pérez',
      'Pablo Ladaga',
      'Ladaga',
      'Quique Wolff',
      'Hernán Pereyra',
      'Marcelo Palacios',
      'Palacios',
      'Fernando Palomo',
      'Palomo',
      'Sebastián Vignolo',
      'Vignolo',
      'Walter Nelson',
      'Mauro Viale',
      'Jaime Rouco',
      'Macri',
      'Cristóbal',
      'Sergio Goycochea',
      'Nelson Vivas',
      'Bruce Buffer',
    ];
    final textos = [
      for (final (_, _, t) in Relato.plantillas) t,
      ...lineas().map((l) => l.texto),
      ...aperturas.expand((a) => a).map((l) => l.texto),
      ...Personaje.values.map((p) => p.nombre),
    ];
    for (final x in textos) {
      for (final n in prohibidos) {
        expect(x.toLowerCase(), isNot(contains(n.toLowerCase())), reason: x);
      }
    }
    // Y ninguna plantilla nombra a un jugador de la liga (los nombres vienen de la carta).
    final apellidos = {
      for (final j in catalogo)
        if (j.nombre.split(' ').last.length >= 5) j.nombre.split(' ').last,
    };
    for (final (s, per, tp) in Relato.plantillas) {
      final palabras = tp.replaceAll(RegExp(r'[{}~^¡!¿?.,:;]'), ' ').split(RegExp(r'\s+'));
      for (final w in palabras.where((w) => w.isNotEmpty && w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase())) {
        expect(apellidos.contains(w) && !_comunes.contains(w), isFalse, reason: '$s/$per: $tp ($w)');
      }
    }
  });
}

/// Palabras capitalizadas que son del idioma aunque coincidan con un apellido.
const _comunes = <String>{'Final', 'Estuvo', 'Cuarto', 'Dale', 'Regalaron'};
