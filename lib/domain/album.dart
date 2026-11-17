import 'entities/jugador.dart';
import 'una_carta.dart';

/// Una persona del álbum: UNA tarjeta con todas sus versiones adentro. El perfil sigue guardando solo ids de
/// carta (`PerfilEntrenador.coleccion`); esto es una vista agrupada por persona, sin tocar el modelo guardado.
class JugadorAlbum {
  const JugadorAlbum({required this.personaId, required this.nombre, required this.tengo, required this.total});

  final String personaId;
  final String nombre;

  /// Versiones que tenés, de mayor a menor media (desempate: la más reciente).
  final List<Jugador> tengo;

  /// Todas las versiones que existen en el catálogo, de mayor a menor media.
  final List<Jugador> total;

  /// La que se muestra por defecto: la de mayor media que tenés.
  Jugador get principal => tengo.first;

  bool get tieneVarias => total.length > 1;

  /// Versiones que todavía no tenés.
  List<Jugador> get faltan => [
    for (final j in total)
      if (!tengo.any((x) => x.id == j.id)) j,
  ];
}

/// Los números del álbum: personas y versiones, por separado.
class ResumenAlbum {
  const ResumenAlbum({
    required this.personasTengo,
    required this.personasTotal,
    required this.versionesTengo,
    required this.versionesTotal,
  });

  final int personasTengo, personasTotal, versionesTengo, versionesTotal;

  /// "12 de 4.070 jugadores · 31 versiones".
  String get texto =>
      '${miles(personasTengo)} de ${miles(personasTotal)} ${personasTotal == 1 ? 'jugador' : 'jugadores'}'
      ' · ${miles(versionesTengo)} ${versionesTengo == 1 ? 'versión' : 'versiones'}';
}

/// Separador de miles con punto (es-AR): 4070 → "4.070".
String miles(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Cómo se cuenta el álbum, por persona y por franquicia. Se calcula una vez por catálogo y colección.
class AlbumPorJugador {
  AlbumPorJugador(Iterable<Jugador> catalogo, Set<String> coleccion) {
    final todas = <String, List<Jugador>>{};
    final propias = <String, List<Jugador>>{};
    for (final j in catalogo) {
      (todas[j.personaId] ??= []).add(j);
      if (coleccion.contains(j.id)) (propias[j.personaId] ??= []).add(j);
      _personasPorFranquicia.putIfAbsent(j.franquiciaId, () => {}).add(j.personaId);
      _versionesPorFranquicia[j.franquiciaId] = (_versionesPorFranquicia[j.franquiciaId] ?? 0) + 1;
      if (coleccion.contains(j.id)) {
        _tengoPersonasPorFranquicia.putIfAbsent(j.franquiciaId, () => {}).add(j.personaId);
        _tengoVersionesPorFranquicia[j.franquiciaId] = (_tengoVersionesPorFranquicia[j.franquiciaId] ?? 0) + 1;
      }
    }
    int orden(Jugador a, Jugador b) => a.id == b.id ? 0 : (esMejorVersion(a, b) ? -1 : 1);
    for (final e in propias.entries) {
      final total = todas[e.key]!..sort(orden);
      final tengo = e.value..sort(orden);
      personas.add(JugadorAlbum(personaId: e.key, nombre: tengo.first.nombre, tengo: tengo, total: total));
      versionesTengo += tengo.length;
    }
    personasTotal = todas.length;
    versionesTotal = todas.values.fold(0, (a, l) => a + l.length);
    personas.sort((a, b) {
      final m = b.principal.media.compareTo(a.principal.media);
      return m != 0 ? m : a.nombre.compareTo(b.nombre);
    });
  }

  /// Personas que tenés (al menos una versión), de mayor a menor media de su mejor versión.
  final List<JugadorAlbum> personas = [];
  int versionesTengo = 0;
  late final int personasTotal, versionesTotal;

  final _personasPorFranquicia = <String, Set<String>>{};
  final _versionesPorFranquicia = <String, int>{};
  final _tengoPersonasPorFranquicia = <String, Set<String>>{};
  final _tengoVersionesPorFranquicia = <String, int>{};

  ResumenAlbum get resumen => ResumenAlbum(
    personasTengo: personas.length,
    personasTotal: personasTotal,
    versionesTengo: versionesTengo,
    versionesTotal: versionesTotal,
  );

  /// Progreso de una franquicia: personas con una carta de ahí (tengo / total) y versiones (tengo / total).
  ResumenAlbum deFranquicia(String franquiciaId) => ResumenAlbum(
    personasTengo: _tengoPersonasPorFranquicia[franquiciaId]?.length ?? 0,
    personasTotal: _personasPorFranquicia[franquiciaId]?.length ?? 0,
    versionesTengo: _tengoVersionesPorFranquicia[franquiciaId] ?? 0,
    versionesTotal: _versionesPorFranquicia[franquiciaId] ?? 0,
  );

  /// Las personas que tienen una carta de [franquiciaId], mostrando solo sus versiones de esa franquicia
  /// (la principal es la de mayor media de ahí). Sin franquicia: todas, con todas sus versiones.
  List<JugadorAlbum> deLaFranquicia(String? franquiciaId) {
    if (franquiciaId == null) return personas;
    final r = <JugadorAlbum>[];
    for (final p in personas) {
      final suyas = [
        for (final j in p.tengo)
          if (j.franquiciaId == franquiciaId) j,
      ];
      if (suyas.isEmpty) continue;
      r.add(
        JugadorAlbum(
          personaId: p.personaId,
          nombre: p.nombre,
          tengo: suyas,
          total: [
            for (final j in p.total)
              if (j.franquiciaId == franquiciaId) j,
          ],
        ),
      );
    }
    return r..sort((a, b) {
      final m = b.principal.media.compareTo(a.principal.media);
      return m != 0 ? m : a.nombre.compareTo(b.nombre);
    });
  }
}
