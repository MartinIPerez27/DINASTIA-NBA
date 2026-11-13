import 'entities/jugador.dart';

/// Etapa de la carrera que representa una carta, cuando el jugador tiene varias (una por década):
/// la de mayor media es su Prime; la más temprana, Novato; la última, Veterano.
enum VersionCarta {
  novato('NOVATO'),
  prime('PRIME'),
  veterano('VETERANO');

  const VersionCarta(this.etiqueta);
  final String etiqueta;
}

/// Versión de cada carta (solo para jugadores con más de una época).
Map<String, VersionCarta> calcularVersiones(Iterable<Jugador> catalogo) {
  final porPersona = <String, List<Jugador>>{};
  for (final j in catalogo) {
    (porPersona[j.nbaPlayerId > 0 ? '${j.nbaPlayerId}' : j.idBbref] ??= []).add(j);
  }
  final versiones = <String, VersionCarta>{};
  for (final cartas in porPersona.values) {
    final epocas = {for (final c in cartas) c.epoca};
    if (epocas.length < 2) continue;
    final prime = cartas.reduce(
      (a, b) => b.media > a.media || (b.media == a.media && b.epoca.index < a.epoca.index) ? b : a,
    );
    final primera = cartas.map((c) => c.epoca.index).reduce((a, b) => a < b ? a : b);
    final ultima = cartas.map((c) => c.epoca.index).reduce((a, b) => a > b ? a : b);
    for (final c in cartas) {
      if (c.epoca == prime.epoca) {
        versiones[c.id] = VersionCarta.prime;
      } else if (c.epoca.index == primera) {
        versiones[c.id] = VersionCarta.novato;
      } else if (c.epoca.index == ultima) {
        versiones[c.id] = VersionCarta.veterano;
      }
    }
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
