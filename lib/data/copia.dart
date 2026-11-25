import 'dart:convert';
import 'dart:io';

import '../domain/entities/ajustes.dart';
import '../domain/entities/perfil.dart';
import '../domain/entities/temporada.dart';

/// Exportar e importar partidas y copias completas.
///
/// - Una **partida importada** queda "de exhibición" ([Temporada.importada]): se puede jugar, pero no
///   da premios, marcas ni logros (así importar la misma partida varias veces no infla el perfil).
/// - Una **copia completa** propia conserva los ids y se deduplica por id: restaurarla dos veces no
///   duplica partidas ni cobra otra vez.

/// Lo que se pudo armar al exportar una copia completa.
class InformeExportacion {
  const InformeExportacion({required this.partidas, required this.omitidas, required this.ilegibles});

  /// Partidas escritas en la copia.
  final int partidas;

  /// Partidas que NO entraron porque su texto no era JSON válido.
  final int omitidas;

  /// Partidas que entraron tal cual pero esta versión no sabe abrir (dañadas o de una versión futura).
  final int ilegibles;

  /// Texto para mostrarle al usuario si hubo algo raro (null si salió todo bien).
  String? get advertencia {
    if (omitidas == 0 && ilegibles == 0) return null;
    return [
      if (omitidas > 0) '$omitidas partidas dañadas no entraron en la copia.',
      if (ilegibles > 0)
        '$ilegibles partidas entraron en la copia pero esta versión no las puede abrir '
            '(dañadas o de una versión futura).',
    ].join(' ');
  }
}

/// Escribe la copia completa en [destino] de forma atómica (se arma en un archivo temporal y recién
/// al final se renombra) y sin armar todo en memoria: cada partida se escribe a medida que llega.
/// [partidasJson] son los textos JSON de las partidas tal cual están guardados.
Future<InformeExportacion> escribirCopia(
  File destino, {
  required Map<String, dynamic> perfil,
  required Map<String, dynamic> ajustes,
  required Iterable<String> partidasJson,
}) async {
  final temporal = File('${destino.path}.tmp');
  final sink = temporal.openWrite();
  var escritas = 0, omitidas = 0, ilegibles = 0;
  try {
    sink.write(
      '{"tipo":"copia","version":1,"perfil":${jsonEncode(perfil)},"ajustes":${jsonEncode(ajustes)},"temporadas":[',
    );
    for (final texto in partidasJson) {
      final Object? decodificado;
      try {
        decodificado = jsonDecode(texto);
      } catch (_) {
        omitidas++;
        continue;
      }
      if (decodificado is! Map<String, dynamic>) {
        omitidas++;
        continue;
      }
      try {
        Temporada.fromJson(decodificado);
      } catch (_) {
        ilegibles++; // se conserva tal cual: puede ser de una versión más nueva
      }
      if (escritas > 0) sink.write(',');
      sink.write(texto);
      escritas++;
    }
    sink.write(']}');
    await sink.flush();
    await sink.close();
    await temporal.rename(destino.path);
  } catch (_) {
    try {
      await sink.close();
    } catch (_) {}
    try {
      if (await temporal.exists()) await temporal.delete();
    } catch (_) {}
    rethrow;
  }
  return InformeExportacion(partidas: escritas, omitidas: omitidas, ilegibles: ilegibles);
}

/// Una copia completa ya validada.
class CopiaLeida {
  const CopiaLeida({required this.perfil, required this.ajustes, required this.partidas, required this.descartadas});

  final PerfilEntrenador perfil;
  final Map<String, dynamic> ajustes;
  final List<Temporada> partidas;

  /// Partidas de la copia que no se pudieron leer (no son un objeto, o están dañadas).
  final int descartadas;
}

/// Valida una copia completa: perfil y ajustes tienen que ser objetos legibles (si no, se rechaza
/// toda la copia con un [FormatException]); cada partida se valida por separado y las dañadas se
/// cuentan en [CopiaLeida.descartadas] sin frenar a las demás.
CopiaLeida leerCopia(Map<String, dynamic> datos) {
  final perfilJson = datos['perfil'], ajustesJson = datos['ajustes'], temporadasJson = datos['temporadas'];
  if (perfilJson is! Map<String, dynamic>) throw const FormatException('La copia no tiene un perfil válido.');
  if (ajustesJson is! Map<String, dynamic>) throw const FormatException('La copia no tiene ajustes válidos.');
  if (temporadasJson is! List) throw const FormatException('La copia no tiene la lista de partidas.');
  final perfil = PerfilEntrenador.fromJson(perfilJson);
  final ajustes = Ajustes.fromJson(ajustesJson).toJson();
  final partidas = <Temporada>[];
  var descartadas = 0;
  final vistas = <String>{};
  for (final t in temporadasJson) {
    try {
      if (t is! Map<String, dynamic>) throw const FormatException('Partida que no es un objeto.');
      final partida = Temporada.fromJson(t);
      if (vistas.add(partida.id)) partidas.add(partida); // mismo id dos veces: queda una sola
    } catch (_) {
      descartadas++;
    }
  }
  return CopiaLeida(perfil: perfil, ajustes: ajustes, partidas: partidas, descartadas: descartadas);
}

/// Una partida suelta importada: id nuevo (y raíz nueva si es una Dinastía o Mi carrera, para que no
/// pise a la original: las temporadas siguientes son `<raíz>-tN`), marcada como de exhibición.
Temporada partidaImportada(Map<String, dynamic> json, {String? idNuevo}) {
  final nuevo = idNuevo ?? '${DateTime.now().microsecondsSinceEpoch}';
  final viejo = json['id'] as String;
  final datos = json['datosModo'];
  final raiz = datos is Map ? datos['raiz'] : null;
  Map<String, dynamic> copia;
  if (raiz is String && raiz.length >= 6) {
    // La raíz aparece en el id, en el estado del modo y en los ids de las cartas creadas: se cambia en
    // todos lados a la vez (es un número largo, no se confunde con otro texto).
    copia = jsonDecode(jsonEncode(json).replaceAll(raiz, nuevo)) as Map<String, dynamic>;
    if (copia['id'] == viejo) copia['id'] = nuevo;
  } else {
    copia = Map<String, dynamic>.of(json)..['id'] = nuevo;
  }
  return Temporada.fromJson(copia).copyWith(importada: true, origenId: json['origenId'] as String? ?? viejo);
}

/// Un punto de guardado: copia de la partida con id (y raíz) nuevos que sigue siendo "de verdad"
/// (da premios y marcas), para probar otro camino sin perder el actual. Si la original era de
/// exhibición, la copia también.
Temporada partidaDuplicada(Temporada t, {String? idNuevo}) {
  final copia = partidaImportada(t.toJson(), idNuevo: idNuevo);
  if (t.importada) return copia;
  final json = copia.toJson()
    ..remove('importada')
    ..remove('origenId');
  return Temporada.fromJson(json);
}
