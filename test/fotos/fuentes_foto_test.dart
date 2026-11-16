import 'package:dinastia_nba/core/fotos/fuentes_foto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayudas_fotos.dart';

const _thumb = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Shaq_2001.jpg/960px-Shaq_2001.jpg';
const _original = 'https://upload.wikimedia.org/wikipedia/commons/a/ab/Shaq_2001.jpg';

Map<String, dynamic> _meta(String licencia, {String autor = '<a href="x">Keith Allison</a>', bool noLibre = false}) => {
  'query': {
    'pages': [
      {
        'imageinfo': [
          {
            'descriptionurl': 'https://commons.wikimedia.org/wiki/File:Shaq_2001.jpg',
            'extmetadata': {
              'LicenseShortName': {'value': licencia},
              'Artist': {'value': autor},
              'NonFree': {'value': noLibre ? 'true' : 'false'},
            },
          },
        ],
      },
    ],
  },
};

Map<String, dynamic> _resumen({String descripcion = 'American basketball player', String? imagen = _thumb}) => {
  'type': 'standard',
  'description': descripcion,
  'thumbnail': ?(imagen == null ? null : {'source': imagen, 'width': 320}),
  'originalimage': ?(imagen == null ? null : {'source': _original, 'width': 3000}),
};

const _shaq = PersonaFoto(
  clave: 'onealsh01',
  nombre: "Shaquille O'Neal",
  nbaPlayerId: 406,
  usaNba: true,
  nacimiento: 1972,
);

Future<List<Candidata>> _todas(ResolvedorFotos r, PersonaFoto p) => r.candidatas(p).toList();

void main() {
  test('con foto de la NBA va primera; después Wikipedia con autor y licencia', () async {
    final cliente = ClienteFalso((u) {
      if (u.path.contains('rest_v1/page/summary')) return jsonOk(_resumen());
      if (u.queryParameters['prop'] == 'imageinfo') return jsonOk(_meta('CC BY-SA 2.0'));
      return jsonOk({
        'query': {'pages': []},
      });
    });
    final cs = await _todas(ResolvedorFotos(peticionesDe(cliente)), _shaq);
    expect(cs.first.fuente, 'nba');
    expect(cs.first.url, 'https://cdn.nba.com/headshots/nba/latest/1040x760/406.png');
    final wiki = cs[1];
    expect(wiki.fuente, 'wikipedia');
    expect(wiki.url, _thumb);
    expect(wiki.licencia, 'CC BY-SA 2.0');
    expect(wiki.autor, 'Keith Allison'); // sin etiquetas HTML
    expect(wiki.paginaUrl, contains('commons.wikimedia.org/wiki/File:'));
  });

  test('sin foto de la NBA (fotos b+w) no se toca el CDN ni Basketball-Reference', () async {
    final cliente = ClienteFalso((u) => estado(404));
    const p = PersonaFoto(clave: 'x01', nombre: 'Algun Jugador');
    await _todas(ResolvedorFotos(peticionesDe(cliente)), p);
    expect(cliente.pedidos.map((u) => u.host).toSet(), {'en.wikipedia.org', 'commons.wikimedia.org'});
    expect(cliente.pedidos.any((u) => u.host.contains('basketball-reference')), isFalse);
  });

  test('rechaza fotos con licencia no libre y descripciones que no son de básquet', () async {
    final cliente = ClienteFalso((u) {
      if (u.path.contains('rest_v1/page/summary')) {
        return u.path.contains('basketball') ? jsonOk(_resumen(descripcion: 'American actor')) : jsonOk(_resumen());
      }
      if (u.queryParameters['prop'] == 'imageinfo') return jsonOk(_meta('Fair use', noLibre: true));
      return jsonOk({
        'query': {'pages': []},
      });
    });
    final cs = await _todas(ResolvedorFotos(peticionesDe(cliente)), const PersonaFoto(clave: 'x01', nombre: 'Foo Bar'));
    expect(cs, isEmpty);
  });

  test('pageimages: encuentra el artículo desambiguado y filtra por año de nacimiento', () async {
    final cliente = ClienteFalso((u) {
      if (u.path.contains('rest_v1/page/summary')) return estado(404);
      if (u.queryParameters['generator'] == 'search' && u.host == 'en.wikipedia.org') {
        return jsonOk({
          'query': {
            'pages': [
              {
                'title': 'Larry Johnson (basketball, born 1979)',
                'description': 'American basketball player',
                'thumbnail': {'source': _thumb, 'width': 960},
              },
              {
                'title': 'Larry Johnson (basketball, born 1969)',
                'description': 'American basketball player',
                'thumbnail': {
                  'source': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/LJ.jpg/960px-LJ.jpg',
                  'width': 960,
                },
              },
              {
                'title': 'Larry Bird',
                'description': 'American basketball player',
                'thumbnail': {'source': _thumb},
              },
            ],
          },
        });
      }
      if (u.queryParameters['prop'] == 'imageinfo') return jsonOk(_meta('CC BY 2.0'));
      return jsonOk({
        'query': {'pages': []},
      });
    });
    const p = PersonaFoto(clave: 'johnsla02', nombre: 'Larry Johnson', nacimiento: 1969);
    final cs = await _todas(ResolvedorFotos(peticionesDe(cliente)), p);
    expect(cs.length, 1);
    expect(cs.single.url, contains('LJ.jpg'));
    expect(cs.single.licencia, 'CC BY 2.0');
  });

  test('Commons: acepta solo libres con el nombre, retratos primero y guarda atribución', () async {
    Map<String, dynamic> pagina(String titulo, int w, int h, String licencia, {String mime = 'image/jpeg'}) => {
      'title': titulo,
      'imageinfo': [
        {
          'url': 'https://upload.wikimedia.org/wikipedia/commons/a/ab/${titulo.substring(5)}',
          'thumburl': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/${titulo.substring(5)}/960px-x.jpg',
          'width': w,
          'height': h,
          'mime': mime,
          'descriptionurl': 'https://commons.wikimedia.org/wiki/$titulo',
          'extmetadata': {
            'LicenseShortName': {'value': licencia},
            'Artist': {'value': 'Autor <b>Uno</b>'},
          },
        },
      ],
    };
    final cliente = ClienteFalso((u) {
      if (u.host == 'commons.wikimedia.org' && u.queryParameters['generator'] == 'search') {
        return jsonOk({
          'query': {
            'pages': [
              pagina('File:Paisaje_Dennis_Rodman.jpg', 4000, 1000, 'CC BY 2.0'),
              pagina('File:Dennis_Rodman_retrato.jpg', 800, 1200, 'CC BY-SA 3.0'),
              pagina('File:Dennis_Rodman_fair.jpg', 800, 1200, 'Fair use'),
              pagina('File:Michael_Jordan.jpg', 800, 1200, 'CC BY 2.0'),
              pagina('File:Dennis_Rodman_chico.jpg', 100, 100, 'CC BY 2.0'),
              pagina('File:Dennis_Rodman.svg', 800, 1200, 'CC BY 2.0', mime: 'image/svg+xml'),
            ],
          },
        });
      }
      return estado(404);
    });
    final cs = await _todas(
      ResolvedorFotos(peticionesDe(cliente)),
      const PersonaFoto(clave: 'rodmade01', nombre: 'Dennis Rodman'),
    );
    expect(cs.map((c) => c.fuente), everyElement('commons'));
    expect(cs.first.url, contains('Dennis_Rodman_retrato.jpg')); // retrato antes que el apaisado
    expect(cs.first.licencia, 'CC BY-SA 3.0');
    expect(cs.first.autor, 'Autor Uno');
    expect(cs.any((c) => c.url.contains('Jordan') || c.url.contains('fair') || c.url.contains('chico')), isFalse);
    expect(cs.length, 2);
  });

  test('un fallo de red a mitad de la búsqueda se propaga como FotoTransitoria', () async {
    final cliente = ClienteFalso((_) => estado(503));
    await expectLater(
      _todas(ResolvedorFotos(peticionesDe(cliente, reintentos: 1)), const PersonaFoto(clave: 'x', nombre: 'Foo Bar')),
      throwsA(isA<Exception>()),
    );
  });

  group('utilidades', () {
    test('licencias libres vs no libres', () {
      for (final l in ['CC BY 4.0', 'CC BY-SA 2.0', 'CC0', 'Public domain', 'PD-US', 'Attribution']) {
        expect(esLicenciaLibre(l), isTrue, reason: l);
      }
      for (final l in ['Fair use', 'All rights reserved', '', 'Copyrighted']) {
        expect(esLicenciaLibre(l), isFalse, reason: l);
      }
      expect(esLicenciaLibre('CC BY 2.0', noLibre: true), isFalse);
      expect(esLicenciaLibre(null), isFalse);
    });

    test('nombres con acentos y puntuación', () {
      expect(nombraA("Shaquille O'Neal", 'File:Shaquille O Neal 2001.jpg'), isTrue);
      expect(nombraA('Nenê', 'Nene Hilario'), isTrue);
      expect(nombraA('Dennis Rodman', 'Dennis Johnson'), isFalse);
      expect(nombraA('Gary Payton Jr.', 'Gary Payton II (basketball)'), isTrue);
    });

    test('archivo de Wikimedia desde la URL (miniatura y original)', () {
      expect(archivoWikimedia(_thumb), (proyecto: 'commons', archivo: 'Shaq_2001.jpg'));
      expect(archivoWikimedia(_original), (proyecto: 'commons', archivo: 'Shaq_2001.jpg'));
      expect(
        archivoWikimedia('https://upload.wikimedia.org/wikipedia/en/thumb/1/12/Foo%20Bar.jpg/220px-Foo%20Bar.jpg'),
        (proyecto: 'en', archivo: 'Foo Bar.jpg'),
      );
      expect(archivoWikimedia('https://example.com/a.jpg'), isNull);
    });
  });
}
