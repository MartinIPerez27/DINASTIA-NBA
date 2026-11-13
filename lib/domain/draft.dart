import 'dart:math';

import 'entities/entrenador.dart';
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
  Draft(this.catalogo, {Random? azar, this.azarPara, this.coleccion = const {}}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final Random _azar;

  /// Azar propio de cada paso del draft (retos: el mismo draft para el mismo código). Recibe la
  /// temporada antes del paso y un número de paso: 1 tirar, 2 volver a tirar, 100+puesto repartir,
  /// 200+puesto volver a repartir, 300+puesto×10+sobre abrir un sobre.
  final Random Function(Temporada t, int paso)? azarPara;

  /// Si el paso gasta (o viene de gastar) una ficha: volver a tirar, volver a repartir y los sobres.
  static bool pasoConFicha(int paso) => paso == 2 || paso >= 200;

  late Random _paso = _azar;

  void _sembrar(Temporada t, int paso) {
    if (azarPara case final f?) _paso = f(t, paso);
  }

  /// Cartas del álbum del jugador (para la regla "Mi colección").
  final Set<String> coleccion;

  static const pesosRareza = {Tier.b: 10, Tier.a: 6, Tier.s: 3, Tier.sPlus: 1};
  static const maxRetenidos = 2;
  static const cartasPorReparto = 5;

  /// Pesos de rareza de la carta sorpresa: es la que puede traer el "walkout".
  static const pesosSorpresa = {Tier.b: 2, Tier.a: 4, Tier.s: 5, Tier.sPlus: 3};

  late final Map<String, Jugador> _porId = {for (final j in catalogo) j.id: j};

  /// Identidad más frecuente de cada franquicia en cada época (Thunder + 90s → 'SEA').
  late final Map<(String, Epoca), String> _identidadPorGrupo = () {
    final conteo = <(String, Epoca), Map<String, int>>{};
    for (final j in catalogo) {
      final c = conteo.putIfAbsent((j.franquiciaId, j.epoca), () => {});
      c[j.equipo] = (c[j.equipo] ?? 0) + 1;
    }
    return {for (final e in conteo.entries) e.key: e.value.entries.reduce((a, b) => b.value > a.value ? b : a).key};
  }();

  /// Id de la identidad con la que se muestra una tirada.
  String identidadDeTirada(Tirada t) => _identidadPorGrupo[(t.franquiciaId, t.epoca)] ?? t.franquiciaId;

  /// La regla del draft deja pasar esta carta.
  bool permitida(Temporada t, Jugador j) => switch (t.regla) {
    ReglaDraft.unaDecada => j.epoca == t.epocaRegla,
    ReglaDraft.franquiciaPura => j.franquiciaId == t.franquiciaUsuarioId,
    ReglaDraft.underdog => j.tier == Tier.a || j.tier == Tier.b,
    ReglaDraft.coleccion => coleccion.contains(j.id),
    _ => true,
  };

  /// Con la regla "Mi colección": ¿alcanzan tus cartas para llenar los 6 puestos?
  static bool coleccionAlcanza(Iterable<Jugador> catalogo, Set<String> coleccion) {
    var plantel = const Plantel();
    final propias = catalogo.where((j) => coleccion.contains(j.id)).toList()
      ..sort((a, b) => a.posiciones.length.compareTo(b.posiciones.length));
    for (final p in Posicion.values) {
      final candidata = propias.where((j) => plantel.posicionesDisponiblesPara(j).contains(p)).firstOrNull;
      if (candidata == null) return false;
      plantel = plantel.asignar(candidata, p);
    }
    return true;
  }

  Iterable<Jugador> _disponibles(Temporada t) =>
      catalogo.where((j) => permitida(t, j) && t.plantel.posicionesDisponiblesPara(j).isNotEmpty);

  /// Cartas que salieron: todo el plantel de esa franquicia y época que todavía entra.
  /// Primero las del Tier del carrete de rareza (garantizado), después por PPP.
  List<Jugador> candidatos(Temporada t) {
    final tirada = t.tirada;
    if (tirada == null) return const [];
    return [
      for (final j in _disponibles(t))
        if (tirada.incluye(j)) j,
    ]..sort((a, b) {
      final garantizada = (b.tier == tirada.tier ? 1 : 0) - (a.tier == tirada.tier ? 1 : 0);
      if (garantizada != 0) return garantizada;
      final tier = b.tier.index - a.tier.index;
      return tier != 0 ? tier : b.stats.ppp.compareTo(a.stats.ppp);
    });
  }

  List<Tirada> _combinaciones(Temporada t, Tirada? anterior, Set<Carrete> retenidos) => {
    for (final j in _disponibles(t))
      if (anterior == null || retenidos.every((c) => c.coincide(j, anterior))) Tirada.de(j),
  }.toList();

  bool puedeVolverATirar(Temporada t, Set<Carrete> retenidos) =>
      t.tirada != null &&
      !t.plantel.completo &&
      t.rerollsRestantes > 0 &&
      retenidos.length <= maxRetenidos &&
      _combinaciones(t, t.tirada, retenidos).isNotEmpty;

  Temporada tirar(Temporada t, {Set<Carrete> retenidos = const {}}) {
    if (t.plantel.completo) throw StateError('El plantel ya está completo.');
    if (retenidos.length > maxRetenidos) throw ArgumentError('Se retienen como máximo $maxRetenidos carretes.');
    final anterior = t.tirada;
    if (anterior == null && retenidos.isNotEmpty) throw ArgumentError('Solo se retiene al volver a tirar.');
    if (anterior != null && t.rerollsRestantes == 0) throw StateError('No quedan fichas de Reroll.');

    final combinaciones = _combinaciones(t, anterior, retenidos);
    if (combinaciones.isEmpty) throw StateError('No quedan cartas para esa combinación.');
    _sembrar(t, anterior == null ? 1 : 2);
    final base = anterior == null ? t : t.usarReroll();
    return base.conTirada(_sortear(combinaciones));
  }

  Temporada elegir(Temporada t, Jugador j, Posicion p) {
    if (!candidatos(t).contains(j)) throw ReglaPlantelException('${j.nombre} no salió en esta tirada.');
    return t.copyWith(plantel: t.plantel.asignar(j, p)).conTirada(null);
  }

  // ── Modo cartas: tocar un puesto, elegir 1 de 3 sobres, abrirlo y fichar una carta ──

  List<Jugador> cartasDeOferta(Temporada t) => [for (final id in t.oferta?.cartaIds ?? const <String>[]) ?_porId[id]];

  Jugador? jugador(String id) => _porId[id];

  bool puedeRepartir(Temporada t, Posicion p) =>
      t.oferta == null && !t.plantel.estaOcupada(p) && _elegibles(t, p).isNotEmpty;

  /// Pone 3 sobres cerrados sobre la mesa para ese puesto.
  Temporada repartir(Temporada t, Posicion p) {
    if (t.oferta != null) throw StateError('Primero fichá una de las cartas repartidas.');
    if (t.plantel.estaOcupada(p)) throw ReglaPlantelException('${p.etiqueta} ya está ocupado.');
    _sembrar(t, 100 + p.index);
    return t.conOferta(Oferta(posicion: p, sobres: _sobres(t, p)));
  }

  /// Abre el sobre elegido: sus cartas (una boca abajo, la sorpresa). En el draft en serpiente,
  /// en las rondas impares dos rivales eligen antes que vos y se llevan las mejores.
  Temporada abrirSobre(Temporada t, int indice) {
    final oferta = t.oferta;
    if (oferta == null || !oferta.sinAbrir) throw StateError('No hay sobres para abrir.');
    final sobre = oferta.sobres[indice];
    _sembrar(t, 300 + oferta.posicion.index * 10 + indice);
    var pool = _elegibles(t, oferta.posicion).where(sobre.incluye).toList();
    if (pool.length < cartasPorReparto) pool = _elegibles(t, oferta.posicion);
    final serpiente = t.regla == ReglaDraft.serpiente && t.plantel.jugadores.length.isOdd;
    final cantidad = cartasPorReparto + (serpiente ? 2 : 0);
    final cartas = _repartirDe(pool, cantidad - 1, misterioso: sobre.tipo == TipoSobre.misterioso);
    // La sorpresa: una carta más, con más chances de ser grande.
    final resto = pool.where((j) => !cartas.any((c) => c.nbaPlayerId == j.nbaPlayerId)).toList();
    final sorpresa = resto.isEmpty ? null : _sortearCon(resto, pesosSorpresa);
    final todas = [...cartas, ?sorpresa]..shuffle(_paso);
    var robos = t.robos;
    final robadas = <(String, String)>[];
    if (serpiente) {
      final rivales = [
        for (final f in franquiciasRivales)
          if (f != t.franquiciaUsuarioId) f,
      ];
      final mejores = [...todas]..sort((a, b) => b.media.compareTo(a.media));
      for (final j in mejores.take(2)) {
        final rival = rivales[_paso.nextInt(rivales.length)];
        robadas.add((j.id, rival));
        todas.remove(j);
        robos = {
          ...robos,
          rival: [...?robos[rival], j.id],
        };
      }
    }
    final nueva = Oferta(
      posicion: oferta.posicion,
      cartaIds: [for (final j in todas) j.id],
      sorpresaId: todas.contains(sorpresa) ? sorpresa?.id : null,
      robadas: robadas,
      ciega: t.regla == ReglaDraft.aCiegas,
    );
    return t.copyWith(robos: robos).conOferta(nueva);
  }

  /// Franquicias que pueden "robar" en el draft en serpiente (las 30 actuales).
  static const franquiciasRivales = [
    'ATL', 'BOS', 'BKN', 'CHA', 'CHI', 'CLE', 'DAL', 'DEN', 'DET', 'GSW', 'HOU', 'IND', 'LAC', 'LAL', 'MEM', //
    'MIA', 'MIL', 'MIN', 'NOP', 'NYK', 'OKC', 'ORL', 'PHI', 'PHX', 'POR', 'SAC', 'SAS', 'TOR', 'UTA', 'WAS',
  ];

  /// Cuesta una ficha de Reroll: vuelve a poner 3 sobres nuevos.
  Temporada volverARepartir(Temporada t) {
    final oferta = t.oferta;
    if (oferta == null) throw StateError('No hay cartas repartidas.');
    if (t.rerollsRestantes == 0) throw StateError('No quedan fichas de Reroll.');
    _sembrar(t, 200 + oferta.posicion.index);
    return t.usarReroll().conOferta(Oferta(posicion: oferta.posicion, sobres: _sobres(t, oferta.posicion)));
  }

  Temporada fichar(Temporada t, Jugador j) {
    final oferta = t.oferta;
    if (oferta == null || !oferta.cartaIds.contains(j.id)) {
      throw ReglaPlantelException('${j.nombre} no está entre las cartas repartidas.');
    }
    return t.copyWith(plantel: t.plantel.asignar(j, oferta.posicion)).conOferta(null);
  }

  List<Jugador> _elegibles(Temporada t, Posicion pos) => [
    for (final j in catalogo)
      if (permitida(t, j) && t.plantel.posicionesDisponiblesPara(j).contains(pos)) j,
  ];

  /// 3 sobres distintos con al menos 5 cartas cada uno: de una época, de una franquicia y misterioso.
  List<Sobre> _sobres(Temporada t, Posicion pos) {
    final pool = _elegibles(t, pos);
    List<T> conCartas<T>(Iterable<T> claves, bool Function(Jugador, T) incluye) {
      final ok = [
        for (final c in claves)
          if (pool.where((j) => incluye(j, c)).length >= cartasPorReparto) c,
      ]..shuffle(_paso);
      return ok;
    }

    final epocas = conCartas({for (final j in pool) j.epoca}, (j, e) => j.epoca == e);
    final franquicias = conCartas({for (final j in pool) j.franquiciaId}, (j, f) => j.franquiciaId == f);
    final sobres = <Sobre>[
      if (epocas.isNotEmpty) Sobre(TipoSobre.epoca, epoca: epocas.first),
      if (franquicias.isNotEmpty) Sobre(TipoSobre.franquicia, franquiciaId: franquicias.first),
    ];
    // Si alguna clase no alcanza (p. ej. franquicia pura), se completa con otra de la que sí hay.
    for (final e in epocas.skip(1)) {
      if (sobres.length >= 2) break;
      sobres.add(Sobre(TipoSobre.epoca, epoca: e));
    }
    for (final f in franquicias.skip(1)) {
      if (sobres.length >= 2) break;
      sobres.add(Sobre(TipoSobre.franquicia, franquiciaId: f));
    }
    sobres.add(const Sobre(TipoSobre.misterioso));
    return sobres;
  }

  /// Reparte [cantidad] cartas del pool: primero se sortea la rareza (pesos de 82-0), después una
  /// carta de esa rareza. Nunca dos cartas de la misma persona.
  List<Jugador> _repartirDe(List<Jugador> todas, int cantidad, {bool misterioso = false}) {
    var pool = todas;
    final elegidas = <Jugador>[];
    while (elegidas.length < cantidad && pool.isNotEmpty) {
      // El sobre misterioso trae más chances de cartas grandes.
      final carta = _sortearCon(
        pool,
        misterioso ? const {Tier.b: 8, Tier.a: 6, Tier.s: 4, Tier.sPlus: 2} : pesosRareza,
      );
      elegidas.add(carta);
      pool = pool.where((j) => j.nbaPlayerId != carta.nbaPlayerId).toList();
    }
    return elegidas;
  }

  Jugador _sortearCon(List<Jugador> pool, Map<Tier, int> pesos) {
    final rarezas = Tier.values.where((t) => pool.any((j) => j.tier == t)).toList();
    var dado = _paso.nextInt(rarezas.fold(0, (s, t) => s + pesos[t]!));
    final rareza = rarezas.firstWhere((t) => (dado -= pesos[t]!) < 0);
    final deEsaRareza = pool.where((j) => j.tier == rareza).toList();
    return deEsaRareza[_paso.nextInt(deEsaRareza.length)];
  }

  // ── Carta de entrenador (7.º puesto) ──

  /// 3 entrenadores para elegir (estables para cada temporada): si alguno dirigió tu franquicia,
  /// aparece seguro.
  List<Entrenador> opcionesEntrenador(Temporada t) {
    // Con semilla (retos, desafío del día) los mismos 3 para todos los que juegan ese draft.
    final azar = Random(t.datosModo['semilla'] as int? ?? t.id.hashCode);
    final propios = Entrenador.todos.where((e) => e.franquicias.contains(t.franquiciaUsuarioId)).toList()
      ..shuffle(azar);
    final otros = Entrenador.todos.where((e) => !propios.contains(e)).toList()..shuffle(azar);
    return [...propios.take(1), ...otros].take(3).toList();
  }

  Temporada elegirEntrenador(Temporada t, Entrenador e) => t.copyWith(entrenadorId: e.id);

  Tirada _sortear(List<Tirada> combinaciones) {
    final rarezas = [
      for (final t in Tier.values)
        if (combinaciones.any((c) => c.tier == t)) t,
    ];
    var dado = _paso.nextInt(rarezas.fold(0, (s, t) => s + pesosRareza[t]!));
    final rareza = rarezas.firstWhere((t) => (dado -= pesosRareza[t]!) < 0);
    final opciones = combinaciones.where((c) => c.tier == rareza).toList();
    return opciones[_paso.nextInt(opciones.length)];
  }
}
