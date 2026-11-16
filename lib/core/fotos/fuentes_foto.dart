import '../foto_wikipedia.dart' show fotoGrande;
import '../nba_cdn.dart';
import 'limitador_hosts.dart';

/// Una persona a la que hay que conseguirle foto. Se indexa por [clave] (id de Basketball-Reference,
/// el prefijo del id de carta), así que varias cartas del mismo jugador comparten una foto.
class PersonaFoto {
  const PersonaFoto({
    required this.clave,
    required this.nombre,
    this.nbaPlayerId = 0,
    this.usaNba = false,
    this.nacimiento,
  });

  final String clave;
  final String nombre;
  final int nbaPlayerId;

  /// El catálogo marca su foto de la NBA (`fotos` contiene 'n') y hay id de la NBA.
  final bool usaNba;
  final int? nacimiento;
}

/// Una foto posible y de dónde sale. [fuente]: `nba`, `wikipedia` o `commons`.
class Candidata {
  const Candidata({required this.url, required this.fuente, this.licencia, this.autor, this.paginaUrl});

  final String url;
  final String fuente;
  final String? licencia;
  final String? autor;

  /// Página del archivo (Commons/Wikipedia) para la atribución.
  final String? paginaUrl;
}

/// Datos de licencia de un archivo de Wikimedia (`extmetadata` de la API).
class MetadatosArchivo {
  const MetadatosArchivo({required this.licencia, required this.autor, required this.libre, this.paginaUrl});

  final String licencia;
  final String autor;
  final bool libre;
  final String? paginaUrl;
}

/// Licencias que se aceptan: Creative Commons, dominio público y equivalentes libres. Nada de
/// "fair use" ni archivos marcados `NonFree`.
bool esLicenciaLibre(String? licencia, {bool noLibre = false}) {
  if (noLibre || licencia == null || licencia.trim().isEmpty) return false;
  final l = licencia.toLowerCase();
  if (l.contains('fair use') || l.contains('non-free') || l.contains('nonfree') || l.contains('all rights reserved')) {
    return false;
  }
  return RegExp(r'(^|[^a-z])cc[ -]?(by|0|zero)|public domain|^pd([- ]|$)|gfdl|free art|attribution').hasMatch(l);
}

/// Texto plano de un campo HTML de la API (autor, descripción): sin etiquetas ni entidades comunes.
String textoPlano(String? html) {
  if (html == null) return '';
  return html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _acentos = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ñ': 'n', 'ç': 'c', 'ć': 'c', 'č': 'c', 'š': 's', 'ž': 'z',
  'ğ': 'g', 'ı': 'i', 'ł': 'l', 'ń': 'n', 'ś': 's', 'ź': 'z', 'ż': 'z', 'đ': 'd', 'ā': 'a', 'ē': 'e', 'ū': 'u',
};

/// Palabras de un nombre en minúsculas y sin acentos ni puntuación ("Shaquille O'Neal" → shaquille,
/// o, neal). Los sufijos (Jr., Sr., II…) se ignoran.
List<String> palabrasDeNombre(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(_acentos[c] ?? c);
  }
  return b
      .toString()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((p) => p.isNotEmpty && !const {'jr', 'sr', 'ii', 'iii', 'iv'}.contains(p))
      .toList();
}

/// El texto [objetivo] nombra a la persona: todas las palabras de [nombre] (de 2 letras o más)
/// aparecen en él.
bool nombraA(String nombre, String objetivo) {
  final clave = palabrasDeNombre(nombre).where((p) => p.length > 1).toList();
  if (clave.isEmpty) return false;
  final texto = palabrasDeNombre(objetivo).toSet();
  return clave.every(texto.contains);
}

/// Archivo de Wikimedia detrás de una URL de `upload.wikimedia.org`: proyecto (`commons`, `en`) y
/// nombre del archivo, o null si no es una URL de ese tipo.
({String proyecto, String archivo})? archivoWikimedia(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'upload.wikimedia.org') return null;
  final s = uri.pathSegments;
  if (s.length < 5 || s[0] != 'wikipedia') return null;
  final i = s[2] == 'thumb' ? 3 : 2;
  if (s.length < i + 3) return null;
  return (proyecto: s[1], archivo: Uri.decodeComponent(s[i + 2]));
}

bool _esRaster(String url) {
  final u = url.toLowerCase().split('?').first;
  return u.endsWith('.jpg') ||
      u.endsWith('.jpeg') ||
      u.endsWith('.png') ||
      u.endsWith('.webp') ||
      RegExp(r'\.(jpe?g|png|webp)/\d+px-').hasMatch(u);
}

/// Resuelve, por orden y de forma perezosa (un pedido a la vez, solo si hace falta), las fotos
/// posibles de una persona:
///  1. CDN de la NBA (si el catálogo la marca con foto `n`).
///  2. Wikipedia REST `page/summary` (foto principal del artículo).
///  3. API de Wikipedia `pageimages` (buscando el artículo; resuelve desambiguaciones).
///  4. Wikimedia Commons (búsqueda por nombre y "basketball").
/// Toda foto de Wikimedia se acepta solo si su licencia es libre; se guarda autor y licencia.
class ResolvedorFotos {
  ResolvedorFotos(this.http);

  final PeticionesFotos http;

  Stream<Candidata> candidatas(PersonaFoto p) async* {
    final vistas = <String>{};
    if (p.usaNba && p.nbaPlayerId > 0) {
      yield Candidata(
        url: NbaCdn.headshot(p.nbaPlayerId),
        fuente: 'nba',
        licencia: 'Imagen oficial de la NBA',
        autor: 'NBA Media Ventures',
      );
    }
    for (final titulo in ['${p.nombre} (basketball)', p.nombre]) {
      final c = await _resumen(p, titulo, vistas);
      if (c != null) yield c;
    }
    for (final c in await _pageimages(p, vistas)) {
      yield c;
    }
    for (final c in await _commons(p, vistas)) {
      yield c;
    }
  }

  Future<dynamic> _json(Uri url) async {
    final r = await http.pedir(url);
    if (!r.ok) return null;
    try {
      return r.json;
    } on FormatException {
      return null;
    }
  }

  Future<Candidata?> _resumen(PersonaFoto p, String titulo, Set<String> vistas) async {
    final url = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(titulo.replaceAll(' ', '_'))}',
    );
    final datos = await _json(url);
    if (datos is! Map<String, dynamic>) return null;
    final descripcion = (datos['description'] as String? ?? '').toLowerCase();
    if (datos['type'] != 'standard' || !descripcion.contains('basketball')) return null;
    final imagen = fotoGrande(
      datos['thumbnail'] as Map<String, dynamic>?,
      datos['originalimage'] as Map<String, dynamic>?,
    );
    if (imagen == null || !_esRaster(imagen) || !vistas.add(imagen)) return null;
    return _conLicencia(imagen, 'wikipedia');
  }

  Future<List<Candidata>> _pageimages(PersonaFoto p, Set<String> vistas) async {
    final url = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': '${p.nombre} basketball',
      'gsrnamespace': '0',
      'gsrlimit': '4',
      'prop': 'pageimages|description',
      'piprop': 'original|thumbnail',
      'pithumbsize': '$anchoPedido',
      'format': 'json',
      'formatversion': '2',
    });
    final datos = await _json(url);
    final paginas = _paginas(datos);
    final salida = <Candidata>[];
    for (final pg in paginas.whereType<Map<String, dynamic>>()) {
      final titulo = pg['title'] as String? ?? '';
      final descripcion = (pg['description'] as String? ?? '').toLowerCase();
      if (!descripcion.contains('basketball') || !nombraA(p.nombre, titulo)) continue;
      if (!_nacimientoCoincide(p.nacimiento, titulo)) continue;
      final imagen = fotoGrande(pg['thumbnail'] as Map<String, dynamic>?, pg['original'] as Map<String, dynamic>?);
      if (imagen == null || !_esRaster(imagen) || !vistas.add(imagen)) continue;
      final c = await _conLicencia(imagen, 'wikipedia');
      if (c != null) salida.add(c);
    }
    return salida;
  }

  Future<List<Candidata>> _commons(PersonaFoto p, Set<String> vistas) async {
    final url = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': '"${p.nombre}" basketball filetype:bitmap',
      'gsrnamespace': '6',
      'gsrlimit': '8',
      'prop': 'imageinfo',
      'iiprop': 'url|size|mime|extmetadata',
      'iiurlwidth': '$anchoPedido',
      'format': 'json',
      'formatversion': '2',
    });
    final datos = await _json(url);
    final paginas = _paginas(datos);
    final buenas = <({double puntaje, Candidata c})>[];
    for (final pg in paginas.whereType<Map<String, dynamic>>()) {
      final info = ((pg['imageinfo'] as List?)?.firstOrNull) as Map<String, dynamic>?;
      if (info == null) continue;
      final mime = info['mime'] as String? ?? '';
      if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) continue;
      final ancho = (info['width'] as num?)?.toInt() ?? 0, alto = (info['height'] as num?)?.toInt() ?? 0;
      if (ancho < 300 || alto < 300) continue;
      final meta = _extmetadata(info['extmetadata'], info['descriptionurl'] as String?);
      if (meta == null || !meta.libre) continue;
      final texto =
          '${pg['title']} ${_valor(info['extmetadata'], 'ObjectName')} '
          '${textoPlano(_valor(info['extmetadata'], 'ImageDescription'))}';
      if (!nombraA(p.nombre, texto)) continue;
      final imagen = ancho > anchoPedido
          ? (info['thumburl'] as String? ?? info['url'] as String?)
          : info['url'] as String?;
      if (imagen == null || !vistas.add(imagen)) continue;
      // Retratos (más altos que anchos) primero, y a igual forma las más grandes.
      final puntaje = (alto >= ancho * 0.9 ? 1e9 : 0) + ancho * alto.toDouble();
      buenas.add((
        puntaje: puntaje,
        c: Candidata(
          url: imagen,
          fuente: 'commons',
          licencia: meta.licencia,
          autor: meta.autor,
          paginaUrl: meta.paginaUrl,
        ),
      ));
    }
    buenas.sort((a, b) => b.puntaje.compareTo(a.puntaje));
    return [for (final b in buenas.take(3)) b.c];
  }

  /// Pide la licencia del archivo y devuelve la candidata solo si es libre.
  Future<Candidata?> _conLicencia(String imagen, String fuente) async {
    final a = archivoWikimedia(imagen);
    if (a == null) return null;
    final host = a.proyecto == 'commons' ? 'commons.wikimedia.org' : 'en.wikipedia.org';
    final url = Uri.https(host, '/w/api.php', {
      'action': 'query',
      'titles': 'File:${a.archivo}',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'format': 'json',
      'formatversion': '2',
    });
    final datos = await _json(url);
    final paginas = _paginas(datos);
    final info = paginas
        .whereType<Map>()
        .map((pg) => (pg['imageinfo'] as List?)?.firstOrNull)
        .whereType<Map>()
        .firstOrNull;
    if (info == null) return null;
    final meta = _extmetadata(info['extmetadata'], info['descriptionurl'] as String?);
    if (meta == null || !meta.libre) return null;
    return Candidata(
      url: imagen,
      fuente: fuente,
      licencia: meta.licencia,
      autor: meta.autor,
      paginaUrl: meta.paginaUrl,
    );
  }

  static List<dynamic> _paginas(dynamic datos) {
    if (datos is! Map) return const [];
    final query = datos['query'];
    final paginas = query is Map ? query['pages'] : null;
    return paginas is List ? paginas : const [];
  }

  static String _valor(Object? ext, String campo) =>
      (ext is Map && ext[campo] is Map ? (ext[campo] as Map)['value'] : null)?.toString() ?? '';

  static MetadatosArchivo? _extmetadata(Object? ext, String? pagina) {
    if (ext is! Map) return null;
    final licencia = _valor(ext, 'LicenseShortName');
    final autor = textoPlano(_valor(ext, 'Artist'));
    final noLibre = _valor(ext, 'NonFree').toLowerCase() == 'true';
    return MetadatosArchivo(
      licencia: licencia,
      autor: autor.isEmpty ? 'Autor sin datos en Commons' : autor,
      libre: esLicenciaLibre(licencia, noLibre: noLibre),
      paginaUrl: pagina,
    );
  }

  /// "Larry Johnson (basketball, born 1969)": si el título trae el año y el catálogo también, deben coincidir.
  static bool _nacimientoCoincide(int? nacimiento, String titulo) {
    final m = RegExp(r'born (\d{4})').firstMatch(titulo);
    if (m == null || nacimiento == null) return true;
    return int.parse(m.group(1)!) == nacimiento;
  }

  /// Ancho de miniatura pedido (alcanza para las cartas grandes de la tablet).
  static const anchoPedido = 960;
}
