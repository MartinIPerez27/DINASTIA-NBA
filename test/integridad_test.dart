import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/arranque.dart';
import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/copia.dart';
import 'package:dinastia_nba/data/db_local.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/coleccion.dart';
import 'package:dinastia_nba/domain/entities/enum_tolerante.dart';
import 'package:dinastia_nba/domain/entities/metajuego.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/misiones.dart';
import 'package:dinastia_nba/domain/modos/competitivo.dart';
import 'package:dinastia_nba/domain/modos/evoluciones.dart';
import 'package:dinastia_nba/domain/modos/progreso_escalera.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:dinastia_nba/domain/variantes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(21));
  var plantel = const Plantel();
  final chi = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
  for (final pos in Posicion.values) {
    plantel = plantel.asignar(chi.firstWhere((j) => plantel.posicionesDisponiblesPara(j).contains(pos)), pos);
  }
  final inicio = liga.iniciar(
    Temporada(id: 't1', franquiciaUsuarioId: 'CHI', plantel: plantel, tacticaConfirmada: true),
  );
  Temporada jugar(Temporada t, int n) {
    for (var i = 0; i < n; i++) {
      t = liga.simularProximo(t);
    }
    return t;
  }

  Future<DbLocal> abrirDb() async {
    final db = await databaseFactoryFfi.openDatabase(
      sq.inMemoryDatabasePath,
      options: sq.OpenDatabaseOptions(version: 2, onCreate: DbLocal.crearTablas),
    );
    // La base en memoria es compartida entre aperturas: se parte siempre de cero.
    await db.delete('temporadas');
    await db.delete('claves');
    return DbLocal.conBase(db);
  }

  Future<void> crudo(DbLocal db, String id, String datos, int ms) async {
    await db.baseCruda.insert('temporadas', {'id': id, 'datos': datos, 'actualizada': ms});
  }

  group('META-01 arranque', () {
    test('una partida dañada no impide cargar el perfil; avisa y sigue con la anterior', () async {
      final db = await abrirDb();
      await db.guardarTemporada(inicio);
      await crudo(db, 'rota', '{no es json', DateTime.now().millisecondsSinceEpoch + 100000);
      await db.escribir('perfil', const PerfilEntrenador(xp: 500, monedas: 70).toJson());
      final r = await cargarArranque(db);
      expect(r.guardada?.id, 't1');
      expect(r.perfil?.xp, 500);
      expect(r.perfilIlegible, isFalse);
      expect(r.avisos, isNotEmpty);
    });

    test('perfil ilegible: se protege, se guarda .bak y no se pisa con uno vacío', () async {
      final db = await abrirDb();
      await db.escribir('perfil', const PerfilEntrenador(xp: 900).toJson());
      // Se daña el perfil guardado.
      await db.baseCruda.insert('claves', {
        'clave': 'perfil',
        'valor': '{"xp": "no soy un número"}',
      }, conflictAlgorithm: sq.ConflictAlgorithm.replace);
      final r = await cargarArranque(db);
      expect(r.perfilIlegible, isTrue);
      expect(r.perfil, isNull);
      expect(db.perfilProtegido, isTrue);
      expect(await db.leerCrudo(DbLocal.claveCopiaPerfil), contains('no soy un número'));
      // Guardar un perfil vacío NO lo pisa mientras esté protegido.
      await db.escribir('perfil', const PerfilEntrenador().toJson());
      await db.guardarTemporadaYPerfil(inicio, const PerfilEntrenador());
      expect(await db.leerCrudo('perfil'), contains('no soy un número'));
      // Si el usuario decide empezar de nuevo, recién ahí se escribe.
      await db.empezarPerfilNuevo(const PerfilEntrenador());
      expect((await db.leer('perfil'))!['xp'], 0);
    });
  });

  group('CAR-04 receso', () {
    test('reemplazar guarda la nueva y borra la vieja en una transacción; si falla, queda la vieja', () async {
      final db = await abrirDb();
      await db.guardarTemporada(inicio);
      final nueva = Temporada(id: 'n1', franquiciaUsuarioId: 'CHI');
      await db.reemplazarTemporada('t1', nueva);
      expect(await db.cargarTemporada('t1'), isNull);
      expect(await db.cargarTemporada('n1'), isNotNull);
      // Falla simulada: id de la nueva repetido como NULL no existe, así que forzamos un error de la base.
      await db.guardarTemporada(inicio);
      final rota = Temporada(id: 'x', franquiciaUsuarioId: 'CHI', datosModo: {'a': double.nan});
      await expectLater(db.reemplazarTemporada('t1', rota), throwsA(anything));
      expect(await db.cargarTemporada('t1'), isNotNull, reason: 'la vieja no se borra si falla guardar la nueva');
    });
  });

  group('META-03 / META-02 importación', () {
    final dinastia = inicio.copyWith(datosModo: {'raiz': '1731500000000', 'numero': 1});
    Map<String, dynamic> jsonDe(Temporada t, String id) => {...t.toJson(), 'id': id};

    test('una Dinastía importada recibe raíz e id nuevos y queda de exhibición', () {
      final json = jsonDe(dinastia, '1731500000000-t3');
      final importada = partidaImportada(json);
      expect(importada.importada, isTrue);
      expect(importada.origenId, '1731500000000-t3');
      expect(importada.id, isNot(json['id']));
      expect(importada.id, endsWith('-t3'));
      expect(importada.datosModo['raiz'], isNot('1731500000000'));
      // Round trip del JSON.
      expect(Temporada.fromJson(importada.toJson()).importada, isTrue);
    });

    test('las partidas importadas no dan premios ni marcas', () {
      final importada = partidaImportada(inicio.toJson());
      final t = jugar(importada, 10);
      final (perfil, novedades) = Progreso(liga).aplicar(const PerfilEntrenador(), importada, t);
      expect(perfil.xp, 0);
      expect(perfil.monedas, 0);
      expect(perfil.logros, isEmpty);
      expect(novedades, isEmpty);
      // La misma jugada en una partida propia sí paga.
      final propia = Progreso(liga).aplicar(const PerfilEntrenador(), inicio, jugar(inicio, 10)).$1;
      expect(propia.xp, greaterThan(0));
    });

    test('Desafío del día: una copia con otro id no mueve la marca', () {
      final dia = Temporada.fromJson({
        ...inicio.toJson(),
        'modoJuego': 'desafioDelDia',
        'datosModo': {'semilla': 20261113},
      });
      final t = jugar(dia, 10);
      final (marca, _) = Progreso(liga).aplicar(const PerfilEntrenador(), dia, t);
      expect(marca.desafiosDelDia['20261113'], isNull, reason: 'el id no es dia-20261113');
    });
  });

  group('copia completa', () {
    test('exportar es atómico, escribe de a una partida y avisa de las dañadas; importar valida', () async {
      final carpeta = await Directory.systemTemp.createTemp('copia');
      final destino = File('${carpeta.path}/c.json');
      final informe = await escribirCopia(
        destino,
        perfil: const PerfilEntrenador(xp: 10).toJson(),
        ajustes: const {},
        partidasJson: [
          jsonEncode(inicio.toJson()),
          '{roto',
          jsonEncode({'id': 'futuro', 'modoJuego': 'modoDelFuturo'}),
        ],
      );
      expect(informe.partidas, 2);
      expect(informe.omitidas, 1);
      expect(informe.ilegibles, 1);
      expect(informe.advertencia, isNotNull);
      expect(File('${destino.path}.tmp').existsSync(), isFalse);
      final leida = leerCopia(jsonDecode(destino.readAsStringSync()) as Map<String, dynamic>);
      expect(leida.partidas.map((t) => t.id), ['t1']);
      expect(leida.descartadas, 1);
      expect(leida.perfil.xp, 10);
      expect(() => leerCopia({'perfil': 3, 'ajustes': {}, 'temporadas': []}), throwsFormatException);
      expect(() => leerCopia({'perfil': {}, 'ajustes': {}, 'temporadas': 'x'}), throwsFormatException);
      await carpeta.delete(recursive: true);
    });

    test('restaurar la copia propia conserva ids, no duplica y es atómico', () async {
      final db = await abrirDb();
      await db.guardarTemporada(inicio);
      final copia = leerCopia({
        'perfil': const PerfilEntrenador(xp: 77).toJson(),
        'ajustes': <String, dynamic>{},
        'temporadas': [inicio.toJson()],
      });
      await db.restaurarCopia(perfil: copia.perfil, ajustes: copia.ajustes, partidas: copia.partidas);
      await db.restaurarCopia(perfil: copia.perfil, ajustes: copia.ajustes, partidas: copia.partidas);
      final todas = await db.temporadas();
      expect(todas, hasLength(1));
      expect(todas.single.id, 't1');
      expect(todas.single.importada, isFalse);
      expect((await db.leer('perfil'))!['xp'], 77);
    });
  });

  group('META-04 JSON del futuro', () {
    test('valores desconocidos no tumban la carga', () {
      final j = inicio.toJson()
        ..['dificultad'] = 'imposible'
        ..['regla'] = 'reglaNueva'
        ..['modo'] = 'holograma';
      final t = Temporada.fromJson(j);
      expect(t.dificultad, Dificultad.leyenda);
      expect(t.regla, ReglaDraft.libre);
      expect(t.modo, ModoDraft.ruleta);
    });

    test('un modo de juego desconocido no se carga como clásico', () {
      final j = inicio.toJson()..['modoJuego'] = 'modoDelFuturo';
      expect(() => Temporada.fromJson(j), throwsFormatException);
    });

    test('perfil: trofeos, misiones y logros desconocidos se descartan', () {
      final p = PerfilEntrenador.fromJson({
        'xp': 100,
        'logros': {'logroDelFuturo': 1, 'campeon': 5},
        'trofeos': [
          {'tipo': 'trofeoDelFuturo', 'temporada': 'a', 'franquicia': 'CHI', 'fecha': 1},
          {'tipo': 'anillo', 'temporada': 'a', 'franquicia': 'CHI', 'fecha': 1},
        ],
        'metajuego': {
          'misiones': [
            {'id': 'd-1', 'tipo': 'tipoNuevo', 'obj': 3},
            {'id': 'd-2', 'tipo': 'triples', 'obj': 3},
          ],
        },
      });
      expect(p.trofeos.map((t) => t.tipo), [TipoTrofeo.anillo]);
      expect(p.metajuego.misiones.map((m) => m.id), ['d-2']);
      expect(p.logros.keys, [Logro.campeon]);
    });

    test('porNombre tolera todo', () {
      expect(Posicion.values.porNombre('nope'), isNull);
      expect(Posicion.values.porNombre(null), isNull);
      expect(Posicion.values.porNombreO('nope'), Posicion.values.first);
    });
  });

  group('META-05 capa común', () {
    // Divisiones: 10 victorias propias, sin calendario de temporada.
    final div0 = const EstadoDivisiones().en(
      Temporada(id: 'd1', franquiciaUsuarioId: 'CHI', modoJuego: ModoJuego.divisiones),
    );
    final div1 = const EstadoDivisiones(victorias: 10, derrotas: 2).en(div0);
    final hoy = DateTime(2026, 11, 13);

    test('misiones y pase avanzan en un modo con partidos propios', () {
      final (p, _) = Progreso(liga, reloj: () => hoy).aplicar(const PerfilEntrenador(), div0, div1);
      expect(p.metajuego.puntosPase, 10 * 10 + 2 * 3);
      final ganar = p.metajuego.misiones.where((m) => m.tipo == TipoMision.ganarPartidos);
      for (final m in ganar) {
        expect(m.progreso, min(m.objetivo, 10));
      }
      expect(p.xp, greaterThan(0), reason: 'la capa del modo sigue pagando');
    });

    test('las evoluciones avanzan con partidos de un modo del álbum', () {
      final carta = plantel.jugadores.first.id;
      final base = PerfilEvoluciones.de(const PerfilEntrenador())
          .empezar(carta, 'partidos')
          .guardarEn(const PerfilEntrenador());
      final conCarta = div1.copyWith(plantel: plantel);
      final div0b = div0.copyWith(plantel: plantel);
      final (p, _) = Progreso(liga, reloj: () => hoy).aplicar(base, div0b, conCarta);
      expect(PerfilEvoluciones.de(p).cartas[carta]?.progreso, greaterThan(0));
    });

    test('no hay doble conteo en el modo clásico', () {
      final t = jugar(inicio, 6);
      final v = t.registroUsuario.victorias;
      final (p, _) = Progreso(liga, reloj: () => hoy).aplicar(const PerfilEntrenador(), inicio, t);
      expect(
        p.metajuego.misiones.where((m) => m.tipo == TipoMision.ganarPartidos).map((m) => m.progreso),
        everyElement(min(3, v)),
      );
    });

    test('lo anotado fuera de la temporada se aplica y no queda en una cola en memoria', () {
      final p = Misiones.anotarEn(const PerfilEntrenador(), TipoMision.jugarEnVivo, 1, hoy);
      expect(p.metajuego.misiones.where((m) => m.tipo == TipoMision.jugarEnVivo).every((m) => m.progreso == 1), isTrue);
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      expect(PerfilEntrenador.fromJson(json).metajuego.misiones, isNotEmpty);
    });
  });

  group('META-08 misiones', () {
    test('una misión cumplida y sin cobrar sobrevive a medianoche', () {
      final ayer = DateTime(2026, 11, 13);
      var m = Misiones.alDia(const Metajuego(), ayer);
      final diaria = m.misiones.firstWhere((x) => !x.semanal);
      m = m.copyWith(misiones: [for (final x in m.misiones) x.id == diaria.id ? x.conProgreso(x.objetivo) : x]);
      final manana = Misiones.alDia(m, DateTime(2026, 11, 14));
      final sigue = manana.misiones.firstWhere((x) => x.id == diaria.id);
      expect(sigue.cumplida && !sigue.reclamada, isTrue);
    });

    test('atrasar el reloj no regenera las misiones ya cobradas', () {
      var m = Misiones.alDia(const Metajuego(), DateTime(2026, 11, 13));
      final diaria = m.misiones.firstWhere((x) => !x.semanal);
      var perfil = PerfilEntrenador(
        metajuego: m.copyWith(
          misiones: [for (final x in m.misiones) x.id == diaria.id ? x.conProgreso(x.objetivo) : x],
        ),
      );
      perfil = Misiones.reclamar(perfil, diaria.id)!;
      perfil = perfil.copyWith(metajuego: Misiones.alDia(perfil.metajuego, DateTime(2026, 11, 14)));
      // Se atrasa el reloj al día 13.
      final atras = Misiones.alDia(perfil.metajuego, DateTime(2026, 11, 13));
      expect(atras.ultimaFecha, 20261114);
      expect(atras.misiones.where((x) => x.id == diaria.id), isEmpty, reason: 'la de ayer no vuelve a empezar');
      expect(atras.misiones.where((x) => x.id.startsWith('d-20261114')), isNotEmpty);
    });
  });

  group('MDA', () {
    test('MDA-07: lo superado en Momentos clutch queda en el perfil y no se paga dos veces', () {
      final a = Temporada(
        id: 'c1',
        franquiciaUsuarioId: 'CHI',
        modoJuego: ModoJuego.ultimoCuarto,
        datosModo: const {'superados': <String>[]},
      );
      final b = a.copyWith(
        datosModo: {
          'superados': ['m1'],
        },
      );
      final (p1, _) = Progreso(liga).aplicar(const PerfilEntrenador(), a, b);
      expect(p1.xp, greaterThan(0));
      expect(p1.momentosClutch, contains('m1'));
      // Se borra la partida y se vuelve a empezar: superar el mismo momento no paga.
      final c = Temporada(
        id: 'c2',
        franquiciaUsuarioId: 'CHI',
        modoJuego: ModoJuego.ultimoCuarto,
        datosModo: const {'superados': <String>[]},
      );
      final d = c.copyWith(
        datosModo: {
          'superados': ['m1'],
        },
      );
      final (p2, _) = Progreso(liga).aplicar(p1, c, d);
      expect(p2.xp, p1.xp);
    });

    test('MDA-03: historia y espejo no suman al álbum', () {
      for (final m in [ModoJuego.temporadaReal, ModoJuego.queHubiera, ModoJuego.espejo]) {
        expect(
          sumaAlAlbum(Temporada(id: 'x', franquiciaUsuarioId: 'CHI', modoJuego: m)),
          isFalse,
          reason: m.name,
        );
      }
      expect(sumaAlAlbum(Temporada(id: 'x', franquiciaUsuarioId: 'CHI')), isTrue);
    });

    test('MDA-02: el azar del Desafío del día depende del paso, no de cuántas veces abriste la pantalla', () {
      final t = Temporada(
        id: 'dia-1',
        franquiciaUsuarioId: 'CHI',
        modoJuego: ModoJuego.desafioDelDia,
        datosModo: const {'semilla': 20261113},
      );
      expect(Variantes.azarPorPasoDelDia(t, 1).nextInt(1 << 30), Variantes.azarPorPasoDelDia(t, 1).nextInt(1 << 30));
      final gastada = t.copyWith(rerollsRestantes: t.rerollsRestantes - 1);
      expect(
        Variantes.azarPorPasoDelDia(gastada, 2).nextInt(1 << 30),
        isNot(Variantes.azarPorPasoDelDia(t, 2).nextInt(1 << 30)),
      );
    });

    test('MDA-09: "Mi colección" valida por puesto con asignación completa', () {
      // Tres cartas que solo juegan de base no cubren los 6 puestos.
      final bases = catalogo
          .where((j) => j.posiciones.length == 1 && j.posiciones.first == Posicion.values.first)
          .take(6);
      final faltan = puestosSinCobertura(catalogo, {for (final j in bases) j.id});
      expect(faltan, isNotEmpty);
      expect(coleccionLlenaPuestos(catalogo, {for (final j in catalogo) j.id}), isTrue);
    });
  });
}
