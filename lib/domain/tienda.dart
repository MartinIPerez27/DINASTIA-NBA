import 'dart:math';

import 'entities/jugador.dart';
import 'entities/perfil.dart';

/// Sobres de la tienda (se pagan con monedas del juego, nunca con dinero real). Las cartas van a
/// tu álbum; las repetidas se convierten en monedas.
enum SobreTienda {
  comun('Sobre común', 'Cinco cartas de cualquier rareza.', 150, 5, {Tier.b: 10, Tier.a: 6, Tier.s: 3, Tier.sPlus: 1}),
  premium('Sobre premium', 'Cinco cartas sin Tier B: más figuras.', 450, 5, {Tier.a: 6, Tier.s: 4, Tier.sPlus: 1}),
  leyenda('Sobre de leyenda', 'Tres cartas S o S+.', 1200, 3, {Tier.s: 3, Tier.sPlus: 1});

  const SobreTienda(this.nombre, this.descripcion, this.precio, this.cartas, this.pesos);
  final String nombre;
  final String descripcion;
  final int precio;
  final int cartas;
  final Map<Tier, int> pesos;
}

/// Lo que salió de un sobre: las cartas (en orden de aparición) y cuáles eran repetidas.
class Apertura {
  const Apertura(this.cartas, this.repetidas, this.reembolso);

  final List<Jugador> cartas;
  final Set<String> repetidas;
  final int reembolso;
}

class Tienda {
  Tienda(this.catalogo, {Random? azar}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final Random _azar;

  static const monedasPorRepetida = 20;

  bool alcanza(PerfilEntrenador p, SobreTienda s) => p.monedas >= s.precio;

  (PerfilEntrenador, Apertura) abrir(PerfilEntrenador p, SobreTienda s) {
    if (!alcanza(p, s)) throw StateError('No alcanzan las monedas.');
    final cartas = <Jugador>[];
    final personas = <int>{};
    while (cartas.length < s.cartas) {
      final rarezas = s.pesos.keys.toList();
      var dado = _azar.nextInt(s.pesos.values.fold(0, (a, b) => a + b));
      final tier = rarezas.firstWhere((t) => (dado -= s.pesos[t]!) < 0);
      final pool = catalogo.where((j) => j.tier == tier && !personas.contains(j.nbaPlayerId)).toList();
      if (pool.isEmpty) continue;
      final carta = pool[_azar.nextInt(pool.length)];
      cartas.add(carta);
      if (carta.nbaPlayerId > 0) personas.add(carta.nbaPlayerId);
    }
    final repetidas = {
      for (final c in cartas)
        if (p.coleccion.contains(c.id)) c.id,
    };
    final reembolso = repetidas.length * monedasPorRepetida;
    final perfil = p.copyWith(
      monedas: p.monedas - s.precio + reembolso,
      coleccion: {...p.coleccion, for (final c in cartas) c.id},
    );
    return (perfil, Apertura(cartas, repetidas, reembolso));
  }
}
