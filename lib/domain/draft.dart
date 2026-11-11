import 'dart:math';

import 'entities/jugador.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/temporada.dart';
import 'entities/tirada.dart';

/// Reglas del draft 82-0 (GDD §4) sobre una [Temporada]. Cada operación devuelve una temporada
/// nueva, que se guarda enseguida: cerrar la app no regala una tirada.
///
/// - Estilo 82-0: franquicia y época definen el plantel que sale; se elige entre todas sus cartas.
/// - El carrete de rareza (sorteado con [pesosRareza]) garantiza al menos una carta de ese Tier.
/// - Los carretes solo frenan en combinaciones con al menos una carta que entre en un puesto libre.
/// - La primera tirada de cada elección es gratis; volver a tirar cuesta una ficha de Reroll y
///   permite retener hasta [maxRetenidos] carretes.
class Draft {
  Draft(this.catalogo, {Random? azar}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final Random _azar;

  static const pesosRareza = {Tier.a: 6, Tier.s: 3, Tier.sPlus: 1};
  static const maxRetenidos = 2;

  Iterable<Jugador> _disponibles(Plantel p) => catalogo.where((j) => p.posicionesDisponiblesPara(j).isNotEmpty);

  /// Cartas que salieron: todo el plantel de esa franquicia y época que todavía entra.
  /// Primero las del Tier del carrete de rareza (garantizado), después por PPP.
  List<Jugador> candidatos(Temporada t) {
    final tirada = t.tirada;
    if (tirada == null) return const [];
    return [
      for (final j in _disponibles(t.plantel))
        if (tirada.incluye(j)) j,
    ]..sort((a, b) {
      final garantizada = (b.tier == tirada.tier ? 1 : 0) - (a.tier == tirada.tier ? 1 : 0);
      if (garantizada != 0) return garantizada;
      final tier = b.tier.index - a.tier.index;
      return tier != 0 ? tier : b.stats.ppp.compareTo(a.stats.ppp);
    });
  }

  List<Tirada> _combinaciones(Plantel p, Tirada? anterior, Set<Carrete> retenidos) => {
    for (final j in _disponibles(p))
      if (anterior == null || retenidos.every((c) => c.coincide(j, anterior))) Tirada.de(j),
  }.toList();

  bool puedeVolverATirar(Temporada t, Set<Carrete> retenidos) =>
      t.tirada != null &&
      !t.plantel.completo &&
      t.rerollsRestantes > 0 &&
      retenidos.length <= maxRetenidos &&
      _combinaciones(t.plantel, t.tirada, retenidos).isNotEmpty;

  Temporada tirar(Temporada t, {Set<Carrete> retenidos = const {}}) {
    if (t.plantel.completo) throw StateError('El plantel ya está completo.');
    if (retenidos.length > maxRetenidos) throw ArgumentError('Se retienen como máximo $maxRetenidos carretes.');
    final anterior = t.tirada;
    if (anterior == null && retenidos.isNotEmpty) throw ArgumentError('Solo se retiene al volver a tirar.');
    if (anterior != null && t.rerollsRestantes == 0) throw StateError('No quedan fichas de Reroll.');

    final combinaciones = _combinaciones(t.plantel, anterior, retenidos);
    if (combinaciones.isEmpty) throw StateError('No quedan cartas para esa combinación.');
    final base = anterior == null ? t : t.usarReroll();
    return base.conTirada(_sortear(combinaciones));
  }

  Temporada elegir(Temporada t, Jugador j, Posicion p) {
    if (!candidatos(t).contains(j)) throw ReglaPlantelException('${j.nombre} no salió en esta tirada.');
    return t.copyWith(plantel: t.plantel.asignar(j, p)).conTirada(null);
  }

  Tirada _sortear(List<Tirada> combinaciones) {
    final rarezas = [
      for (final t in Tier.values)
        if (combinaciones.any((c) => c.tier == t)) t,
    ];
    var dado = _azar.nextInt(rarezas.fold(0, (s, t) => s + pesosRareza[t]!));
    final rareza = rarezas.firstWhere((t) => (dado -= pesosRareza[t]!) < 0);
    final opciones = combinaciones.where((c) => c.tier == rareza).toList();
    return opciones[_azar.nextInt(opciones.length)];
  }
}
