import 'entities/jugador.dart';

/// Etapa de la carrera que representa una carta, cuando el jugador tiene varias (una por tramo de
/// temporadas): la de mayor media es su Prime; la más temprana, Novato; la última, Veterano.
enum VersionCarta {
  novato('NOVATO'),
  prime('PRIME'),
  veterano('VETERANO');

  const VersionCarta(this.etiqueta);
  final String etiqueta;
}

/// Primer año de cierre del tramo (sin datos de temporadas, el comienzo de su década).
int _inicio(Jugador j) => j.temporadas?.$1 ?? 1940 + j.epoca.index * 10;

/// Versión de cada carta (solo para jugadores con más de un tramo). Desde el catálogo v3 una década puede
/// tener varias cartas de la misma persona (Curry 2010–12, 2013–14, 2015–16…): la versión se decide por
/// carta, no por década.
Map<String, VersionCarta> calcularVersiones(Iterable<Jugador> catalogo) {
  final porPersona = <String, List<Jugador>>{};
  for (final j in catalogo) {
    (porPersona[j.nbaPlayerId > 0 ? '${j.nbaPlayerId}' : j.idBbref] ??= []).add(j);
  }
  final versiones = <String, VersionCarta>{};
  for (final cartas in porPersona.values) {
    if (cartas.length < 2) continue;
    // Orden estable: por inicio del tramo y, si empatan (traspaso a mitad de temporada), por id.
    final orden = [...cartas]
      ..sort((a, b) {
        final c = _inicio(a).compareTo(_inicio(b));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final prime = orden.reduce((a, b) => b.media > a.media ? b : a);
    versiones[prime.id] = VersionCarta.prime;
    if (orden.first != prime) versiones[orden.first.id] = VersionCarta.novato;
    if (orden.last != prime && orden.last != orden.first) versiones[orden.last.id] = VersionCarta.veterano;
  }
  return versiones;
}

/// Versiones del catálogo cargado: se calculan una sola vez, al cargar el catálogo o al crear la Liga,
/// para que NOVATO / PRIME / VETERANO se vean en cualquier pantalla (álbum, temporada, mercado…).
Map<String, VersionCarta> versionesCatalogo = const {};

/// Calcula [versionesCatalogo] si todavía no se calculó para este catálogo.
void registrarVersiones(List<Jugador> catalogo) {
  if (identical(catalogo, _catalogoRegistrado)) return;
  _catalogoRegistrado = catalogo;
  versionesCatalogo = calcularVersiones(catalogo);
}

List<Jugador>? _catalogoRegistrado;
