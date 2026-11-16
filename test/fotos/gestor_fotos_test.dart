import 'dart:io';
import 'dart:typed_data';

import 'package:dinastia_nba/core/fotos/fuentes_foto.dart';
import 'package:dinastia_nba/core/fotos/gestor_fotos.dart';
import 'package:dinastia_nba/core/fotos/http_fotos.dart';
import 'package:dinastia_nba/core/fotos/indice_fotos.dart';
import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/db_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ayudas_fotos.dart';

const _nba = PersonaFoto(clave: 'onealsh01', nombre: "Shaquille O'Neal", nbaPlayerId: 406, usaNba: true);
const _wiki = PersonaFoto(clave: 'ewingpa01', nombre: 'Patrick Ewing');
const _nadie = PersonaFoto(clave: 'zzz01', nombre: 'Nadie Conocido');

const _imagenWiki = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Ewing.jpg/960px-Ewing.jpg';

/// Wikipedia/Commons simulados: Ewing existe (CC BY-SA), cualquier otro no.
RespuestaHttp _servidor(Uri u) {
  if (u.host == 'cdn.nba.com') return u.path.endsWith('/406.png') ? pngFalso() : estado(403);
  if (u.host == 'upload.wikimedia.org') return pngFalso();
  if (u.path.contains('rest_v1/page/summary')) {
    return u.path.contains('Patrick_Ewing')
        ? jsonOk({
            'type': 'standard',
            'description': 'Jamaican-American basketball player',
            'thumbnail': {'source': _imagenWiki, 'width': 320},
            'originalimage': {
              'source': _imagenWiki.replaceAll('thumb/', '').replaceAll('/960px-Ewing.jpg', ''),
              'width': 5000,
            },
          })
        : estado(404);
  }
  if (u.queryParameters['prop'] == 'imageinfo' && u.queryParameters.containsKey('titles')) {
    return jsonOk({
      'query': {
        'pages': [
          {
            'imageinfo': [
              {
                'descriptionurl': 'https://commons.wikimedia.org/wiki/File:Ewing.jpg',
                'extmetadata': {
                  'LicenseShortName': {'value': 'CC BY-SA 2.0'},
                  'Artist': {'value': 'Keith Allison'},
                },
              },
            ],
          },
        ],
      },
    });
  }
  return jsonOk({
    'query': {'pages': []},
  });
}

void main() {
  sqfliteFfiInit();
  late sq.Database db;
  late Directory carpeta;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(sq.inMemoryDatabasePath);
    await IndiceFotos.crearTabla(db);
    carpeta = carpetaTemporal();
  });
  tearDown(() async {
    await db.close();
    if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
  });

  GestorFotos nuevo(ClienteFalso c, {Recortador? recortador, int fallas = 4}) => GestorFotos(
    indice: IndiceFotos(db),
    carpeta: carpeta,
    peticiones: peticionesDe(c, reintentos: 0),
    recortador: recortador,
    fallasParaPausar: fallas,
  );

  test('baja la foto de la NBA y la de Wikipedia, guarda archivos e índice con licencia y autor', () async {
    final c = ClienteFalso(_servidor);
    final g = nuevo(c, recortador: (f) async => Uint8List.fromList([1, 2, 3]));
    g.descargarTodas([_wiki, _nba]);
    await g.terminar();

    final n = g.de('onealsh01')!;
    expect(n.estado, EstadoFoto.ok);
    expect(n.fuente, 'nba');
    expect(File('${carpeta.path}/${n.ruta}').existsSync(), isTrue);
    expect(g.archivoMostrable('onealsh01')!.path, endsWith('onealsh01.png')); // NBA: la original

    final w = g.de('ewingpa01')!;
    expect(w.fuente, 'wikipedia');
    expect(w.licencia, 'CC BY-SA 2.0');
    expect(w.autor, 'Keith Allison');
    expect(w.urlPagina, contains('File:Ewing.jpg'));
    expect(g.archivoMostrable('ewingpa01')!.path, endsWith('ewingpa01_r.png')); // archivo: el recorte
    expect(g.conteo([_nba, _wiki, _nadie]), (listas: 2, sin: 0, faltan: 1));
    expect(g.atribuciones().single.persona, 'ewingpa01');
  });

  test('las de la NBA se piden primero', () async {
    final c = ClienteFalso(_servidor);
    final g = nuevo(c);
    g.descargarTodas([_wiki, _nba]);
    await g.terminar();
    expect(c.pedidos.first.host, 'cdn.nba.com');
  });

  test('persiste todo: otra sesión lee el índice y no vuelve a pedir nada (sin vencimiento)', () async {
    final g1 = nuevo(ClienteFalso(_servidor), recortador: (f) async => Uint8List.fromList([1, 2, 3]));
    g1.descargarTodas([_nba, _wiki, _nadie]);
    await g1.terminar();
    expect(g1.de('zzz01')!.estado, EstadoFoto.sin);

    final c2 = ClienteFalso((_) => throw StateError('no debería haber red'));
    final g2 = nuevo(c2); // sesión nueva, mismo índice y carpeta
    await g2.cargar();
    expect(g2.conteo([_nba, _wiki, _nadie]), (listas: 2, sin: 1, faltan: 0));
    g2.descargarTodas([_nba, _wiki, _nadie]);
    g2.solicitar(_nadie);
    await g2.terminar();
    expect(c2.pedidos, isEmpty); // ni las listas ni los 404 recordados
    expect(g2.archivoMostrable('ewingpa01')!.existsSync(), isTrue);
  });

  test('el 404 se recuerda; "buscar de nuevo" lo reintenta y una "sin foto" vieja se reintenta sola', () async {
    var ahora = DateTime(2026, 1, 1);
    final c = ClienteFalso(_servidor);
    final g = GestorFotos(
      indice: IndiceFotos(db),
      carpeta: carpeta,
      peticiones: peticionesDe(c, reintentos: 0),
      ahora: () => ahora,
    );
    g.descargarTodas([_nadie]);
    await g.terminar();
    final antes = c.pedidos.length;
    g.descargarTodas([_nadie]);
    await g.terminar();
    expect(c.pedidos.length, antes); // memoria del 404

    ahora = ahora.add(const Duration(days: 200)); // pasaron más de 180 días
    g.descargarTodas([_nadie]);
    await g.terminar();
    expect(c.pedidos.length, greaterThan(antes));

    final antes2 = c.pedidos.length;
    await g.reintentarSinFoto([_nadie]);
    await g.terminar();
    expect(c.pedidos.length, greaterThan(antes2));
  });

  test('falla de red: queda pendiente (no "sin foto") y se pausa sola tras varias fallas seguidas', () async {
    final c = ClienteFalso((_) => estado(503));
    final g = nuevo(c, fallas: 2);
    final gente = [for (var i = 0; i < 5; i++) PersonaFoto(clave: 'p$i', nombre: 'Persona Numero$i')];
    g.descargarTodas(gente);
    await g.terminar();
    expect(g.pausado, isTrue);
    expect(g.mensaje, contains('Sin conexión'));
    expect(g.conteo(gente).sin, 0);
    expect(g.de('p0')!.estado, EstadoFoto.pendiente);
    expect(g.de('p4'), isNull); // no llegó a procesarse: quedó en cola
    expect(g.enCola, 3);

    // Vuelve la red: reanudar completa lo que falta.
    final bien = ClienteFalso(_servidor);
    final g2 = GestorFotos(indice: IndiceFotos(db), carpeta: carpeta, peticiones: peticionesDe(bien, reintentos: 0));
    await g2.cargar();
    g2.descargarTodas(gente);
    await g2.terminar();
    expect(g2.conteo(gente).sin, 5);
  });

  test('pausar y reanudar: no se procesa nada en pausa', () async {
    final c = ClienteFalso(_servidor);
    final g = nuevo(c);
    g.pausar();
    g.descargarTodas([_nba]); // descargarTodas reanuda explícitamente
    g.pausar();
    await g.terminar();
    g.reanudar();
    await g.terminar();
    expect(g.de('onealsh01')!.estado, EstadoFoto.ok);
  });

  test('si el recorte no encuentra a nadie, descarta esa foto y prueba la siguiente fuente', () async {
    var llamadas = 0;
    final c = ClienteFalso((u) {
      if (u.path.contains('rest_v1/page/summary') && u.path.contains('Patrick_Ewing')) return _servidor(u);
      if (u.queryParameters['generator'] == 'search' && u.host == 'commons.wikimedia.org') {
        return jsonOk({
          'query': {
            'pages': [
              {
                'title': 'File:Patrick_Ewing_2.jpg',
                'imageinfo': [
                  {
                    'url': 'https://upload.wikimedia.org/wikipedia/commons/c/cd/Patrick_Ewing_2.jpg',
                    'width': 900,
                    'height': 1200,
                    'mime': 'image/jpeg',
                    'descriptionurl': 'https://commons.wikimedia.org/wiki/File:Patrick_Ewing_2.jpg',
                    'extmetadata': {
                      'LicenseShortName': {'value': 'CC BY 3.0'},
                      'Artist': {'value': 'Otro Autor'},
                    },
                  },
                ],
              },
            ],
          },
        });
      }
      return _servidor(u);
    });
    final g = nuevo(c, recortador: (f) async => ++llamadas == 1 ? null : Uint8List.fromList([9]));
    g.descargarTodas([_wiki]);
    await g.terminar();
    final f = g.de('ewingpa01')!;
    expect(f.fuente, 'commons');
    expect(f.autor, 'Otro Autor');
    expect(llamadas, 2);
    expect(carpeta.listSync().whereType<File>().length, 2); // original + recorte; la descartada se borró
  });

  test('personasDe: una por id de Basketball-Reference, con foto NBA si alguna carta la tiene', () async {
    // Se construye con el catálogo real (no toca red).
    final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
    final personas = GestorFotos.personasDe(catalogo);
    expect(personas.length, catalogo.map((j) => j.idBbref).toSet().length);
    expect(personas.where((p) => p.usaNba).length, greaterThan(1000));
    expect(personas.every((p) => p.clave.isNotEmpty && p.nombre.isNotEmpty), isTrue);
  });

  group('SQLite: tabla e índice', () {
    test('guardar, leer y contar por estado', () async {
      final i = IndiceFotos(db);
      final t = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      await i.guardar(
        FotoIndexada(
          persona: 'a',
          estado: EstadoFoto.ok,
          fecha: t,
          ruta: 'a.jpg',
          fuente: 'commons',
          licencia: 'CC BY 4.0',
          autor: 'Ana',
        ),
      );
      await i.guardar(FotoIndexada(persona: 'b', estado: EstadoFoto.sin, fecha: t));
      await i.guardar(FotoIndexada(persona: 'c', estado: EstadoFoto.pendiente, fecha: t));
      final a = (await i.obtener('a'))!;
      expect(
        (a.estado, a.ruta, a.fuente, a.licencia, a.autor, a.fecha),
        (EstadoFoto.ok, 'a.jpg', 'commons', 'CC BY 4.0', 'Ana', t),
      );
      expect(await i.conteo(), {EstadoFoto.ok: 1, EstadoFoto.sin: 1, EstadoFoto.pendiente: 1});
      await i.guardar(FotoIndexada(persona: 'c', estado: EstadoFoto.ok, fecha: t)); // reemplaza
      expect((await i.todas()).length, 3);
      expect((await i.conteo())[EstadoFoto.ok], 2);
    });

    test('migración: una base v2 existente gana la tabla al abrirla y conserva sus datos', () async {
      final carpetaDb = Directory.systemTemp.createTempSync('db_fotos_');
      addTearDown(() => carpetaDb.deleteSync(recursive: true));
      await databaseFactoryFfi.setDatabasesPath(carpetaDb.path);
      final ruta = '${carpetaDb.path}/dinastia_nba.db';
      // Base "vieja": versión 2, sin tabla de fotos, con una clave guardada.
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: sq.OpenDatabaseOptions(version: 2, onCreate: DbLocal.crearTablas),
      );
      await vieja.insert('claves', {'clave': 'ajustes', 'valor': '{"sonido":false}'});
      expect(await vieja.rawQuery("SELECT name FROM sqlite_master WHERE name = '${IndiceFotos.tabla}'"), isEmpty);
      await vieja.close();

      sq.databaseFactory = databaseFactoryFfi;
      final nueva = await DbLocal.abrir();
      expect((await nueva.leer('ajustes'))!['sonido'], false); // datos intactos
      final indice = IndiceFotos(nueva.baseDatos);
      expect(await indice.todas(), isEmpty);
      await indice.guardar(FotoIndexada(persona: 'x', estado: EstadoFoto.sin, fecha: DateTime.now()));
      await nueva.baseDatos.close();

      // Reabrir otra vez no rompe ni pierde nada (IF NOT EXISTS).
      final otra = await DbLocal.abrir();
      expect((await IndiceFotos(otra.baseDatos).todas()).single.persona, 'x');
      await otra.baseDatos.close();
    });
  });
}
