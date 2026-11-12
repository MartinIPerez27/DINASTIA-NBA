import 'dart:math';

import 'entities/jugador.dart';
import 'entities/oferta.dart';
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
  static const cartasPorReparto = 5;

  late final Map<String, Jugador> _porId = {for (final j in catalogo) j.id: j};

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

  // ── Modo cartas: tocar un puesto, se reparten 5 cartas y se ficha una ──

  List<Jugador> cartasDeOferta(Temporada t) => [for (final id in t.oferta?.cartaIds ?? const <String>[]) ?_porId[id]];

  bool puedeRepartir(Temporada t, Posicion p) =>
      t.oferta == null && !t.plantel.estaOcupada(p) && _elegibles(t.plantel, p).isNotEmpty;

  Temporada repartir(Temporada t, Posicion p) {
    if (t.oferta != null) throw StateError('Primero fichá una de las cartas repartidas.');
    if (t.plantel.estaOcupada(p)) throw ReglaPlantelException('${p.etiqueta} ya está ocupado.');
    return t.conOferta(Oferta(posicion: p, cartaIds: _repartir(t.plantel, p)));
  }

  /// Cuesta una ficha de Reroll; evita repetir las cartas de la oferta anterior si hay suficientes.
  Temporada volverARepartir(Temporada t) {
    final oferta = t.oferta;
    if (oferta == null) throw StateError('No hay cartas repartidas.');
    if (t.rerollsRestantes == 0) throw StateError('No quedan fichas de Reroll.');
    final nuevas = _repartir(t.plantel, oferta.posicion, evitar: oferta.cartaIds.toSet());
    return t.usarReroll().conOferta(Oferta(posicion: oferta.posicion, cartaIds: nuevas));
  }

  Temporada fichar(Temporada t, Jugador j) {
    final oferta = t.oferta;
    if (oferta == null || !oferta.cartaIds.contains(j.id)) {
      throw ReglaPlantelException('${j.nombre} no está entre las cartas repartidas.');
    }
    return t.copyWith(plantel: t.plantel.asignar(j, oferta.posicion)).conOferta(null);
  }

  List<Jugador> _elegibles(Plantel p, Posicion pos) => [
    for (final j in catalogo)
      if (p.posicionesDisponiblesPara(j).contains(pos)) j,
  ];

  /// Cada carta: primero se sortea la rareza (6/3/1), después una carta de esa rareza.
  /// Nunca dos cartas de la misma persona.
  List<String> _repartir(Plantel p, Posicion pos, {Set<String> evitar = const {}}) {
    var pool = _elegibles(p, pos);
    final nuevas = pool.where((j) => !evitar.contains(j.id)).toList();
    if (nuevas.length >= cartasPorReparto) pool = nuevas;
    final elegidas = <Jugador>[];
    while (elegidas.length < cartasPorReparto && pool.isNotEmpty) {
      final rareza = _sortearRareza({for (final j in pool) j.tier});
      final deEsaRareza = pool.where((j) => j.tier == rareza).toList();
      final carta = deEsaRareza[_azar.nextInt(deEsaRareza.length)];
      elegidas.add(carta);
      pool = pool.where((j) => j.nbaPlayerId != carta.nbaPlayerId).toList();
    }
    return [for (final j in elegidas) j.id];
  }

  Tier _sortearRareza(Set<Tier> disponibles) {
    final rarezas = Tier.values.where(disponibles.contains).toList();
    var dado = _azar.nextInt(rarezas.fold(0, (s, t) => s + pesosRareza[t]!));
    return rarezas.firstWhere((t) => (dado -= pesosRareza[t]!) < 0);
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
