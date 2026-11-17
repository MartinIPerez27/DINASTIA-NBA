import 'dart:math';

import 'entities/entrenador.dart';
import 'entities/jugador.dart';
import 'entities/oferta.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/temporada.dart';
import 'entities/tirada.dart';
import 'tokens_draft.dart';
import 'una_carta.dart';
import 'version_catalogo.dart';

/// Reglas del draft 82-0 (GDD §4) sobre una [Temporada]. Cada operación devuelve una temporada
/// nueva, que se guarda enseguida: cerrar la app no regala una tirada.
///
/// - Estilo 82-0: franquicia y época definen el plantel que sale; se elige entre todas sus cartas.
/// - El carrete de rareza (sorteado con [pesosRareza]) garantiza al menos una carta de ese Tier.
/// - Los carretes solo frenan en combinaciones con al menos una carta que entre en un puesto libre.
/// - La primera tirada de cada elección es gratis; volver a tirar cuesta una ficha gratis (pocas)
///   o monedas (precio creciente) y permite retener hasta [maxRetenidos] carretes.
/// - Tokens (ver [ReglasTokens]): volver a tirar, mejor versión, doble, intercambio y comodín. Sus
///   reglas, precios y topes están en `tokens_draft.dart`; acá se aplican y se anotan en
///   [Temporada.tokens]. El que llama pasa las `monedas` disponibles y descuenta del perfil lo que
///   creció `tokens.gastadas`.
class Draft {
  Draft(
    this.catalogo, {
    Random? azar,
    this.azarPara,
    this.coleccion = const {},
    this.ventajas = VentajasTokens.ninguna,
  }) : _azar = azar ?? Random();

  /// Descuentos y usos gratis que da el nivel del entrenador en los tokens.
  final VentajasTokens ventajas;

  final List<Jugador> catalogo;
  final Random _azar;

  /// Azar propio de cada paso del draft (retos: el mismo draft para el mismo código). Recibe la
  /// temporada antes del paso y un número de paso: 1 tirar, 2 volver a tirar, 3 comodín (la parte
  /// que no elegís), 100+puesto repartir, 200+puesto volver a repartir, 300+puesto×10+sobre abrir
  /// un sobre. Mejor versión, doble e intercambio no usan azar: no mueven las tiradas del reto.
  final Random Function(Temporada t, int paso)? azarPara;

  /// Si el paso gasta (o viene de gastar) una ficha: volver a tirar, volver a repartir y los sobres.
  static const pasoComodin = 3;
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

  late final Map<String, Jugador> _porId = {...cartasLegado, for (final j in catalogo) j.id: j};

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

  /// Una carta por persona de lo que cumple la regla del draft y entra en un puesto libre, y por cada
  /// franquicia+época (ver `una_carta.dart`). Es la base de las tiradas: [candidatos] y [_combinaciones]
  /// salen de acá, así el Tier de la tirada siempre es el de una carta que de verdad se muestra.
  List<Jugador> _visibles(Temporada t) =>
      unaPorPersonaYGrupo(_disponibles(t), (j) => (j.franquiciaId, j.epoca));

  /// Cartas que salieron: el plantel de esa franquicia y época que todavía entra, **una sola carta por
  /// persona** (la de mayor media de ese tramo de franquicia+época; desempate, la más reciente).
  /// Primero las del Tier del carrete de rareza (garantizado), después por PPP.
  ///
  /// Con "Mejor versión" ([Temporada.tokens] `sustituidas`) la carta de esa persona se cambia por la
  /// elegida, que puede ser de otra franquicia o tramo.
  List<Jugador> candidatos(Temporada t) {
    final tirada = t.tirada;
    if (tirada == null) return const [];
    final sustitutas = <String, Jugador>{};
    for (final e in t.tokens.sustituidas.entries) {
      final antes = _porId[e.key], ahora = _porId[e.value];
      if (antes != null && ahora != null) sustitutas[antes.personaId] = ahora;
    }
    return [
      for (final j in unaPorPersona(
        catalogo.where((j) => tirada.incluye(j) && permitida(t, j) && t.plantel.posicionesDisponiblesPara(j).isNotEmpty),
      ))
        sustitutas[j.personaId] ?? j,
    ]..sort((a, b) {
      final garantizada = (b.tier == tirada.tier ? 1 : 0) - (a.tier == tirada.tier ? 1 : 0);
      if (garantizada != 0) return garantizada;
      final tier = b.tier.index - a.tier.index;
      if (tier != 0) return tier;
      final ppp = b.stats.ppp.compareTo(a.stats.ppp);
      return ppp != 0 ? ppp : a.id.compareTo(b.id);
    });
  }

  List<Tirada> _combinaciones(Temporada t, Tirada? anterior, Set<Carrete> retenidos) => {
    for (final j in _visibles(t))
      if (anterior == null || retenidos.every((c) => c.coincide(j, anterior))) Tirada.de(j),
  }.toList();

  /// Tiradas que pueden salir con la regla vigente (por ejemplo, con Franquicia pura, solo las de tu equipo).
  /// La animación de los carretes gira solo entre estas.
  List<Tirada> tiradasPosibles(Temporada t) => _combinaciones(t, null, const {});

  bool puedeVolverATirar(Temporada t, Set<Carrete> retenidos) =>
      t.tirada != null &&
      !t.plantel.completo &&
      t.tokens.picksExtra == 0 &&
      precioDe(t, TokenDraft.volverATirar) != null &&
      retenidos.length <= maxRetenidos &&
      _combinaciones(t, t.tirada, retenidos).isNotEmpty;

  /// Tira los carretes. La primera tirada de cada elección es gratis; volver a tirar gasta una
  /// ficha gratis o, si no quedan, [monedas] del precio creciente (ver [ReglasTokens]).
  Temporada tirar(Temporada t, {Set<Carrete> retenidos = const {}, int monedas = 0}) {
    if (t.plantel.completo) throw StateError('El plantel ya está completo.');
    if (retenidos.length > maxRetenidos) throw ArgumentError('Se retienen como máximo $maxRetenidos carretes.');
    final anterior = t.tirada;
    if (anterior == null && retenidos.isNotEmpty) throw ArgumentError('Solo se retiene al volver a tirar.');
    if (anterior != null && t.tokens.picksExtra > 0) throw StateError('Con el Doble activo no se vuelve a tirar.');
    if (anterior != null) _verificarPago(t, TokenDraft.volverATirar, monedas);

    final combinaciones = _combinaciones(t, anterior, retenidos);
    if (combinaciones.isEmpty) throw StateError('No quedan cartas para esa combinación.');
    _sembrar(t, anterior == null ? 1 : 2);
    final base = anterior == null ? t : _pagar(t, TokenDraft.volverATirar, monedas);
    return _conTiradaNueva(base, _sortear(combinaciones));
  }

  Temporada _conTiradaNueva(Temporada t, Tirada? tirada) {
    final nueva = t.conTirada(tirada);
    return nueva.tokens.sustituidas.isEmpty && nueva.tokens.picksExtra == 0
        ? nueva
        : nueva.copyWith(tokens: nueva.tokens.sinTirada);
  }

  /// Puestos libres donde puede ir [j]. Con el Doble activo, solo los que dejan lugar al segundo.
  List<Posicion> puestosPara(Temporada t, Jugador j) {
    final libres = t.plantel.posicionesDisponiblesPara(j);
    if (t.tokens.picksExtra == 0) return libres;
    return [
      for (final p in libres)
        if (_quedanDespues(t, j, p).isNotEmpty) p,
    ];
  }

  List<Jugador> _quedanDespues(Temporada t, Jugador j, Posicion p) =>
      candidatos(t.copyWith(plantel: t.plantel.asignar(j, p)));

  Temporada elegir(Temporada t, Jugador j, Posicion p) {
    if (!candidatos(t).contains(j)) throw ReglaPlantelException('${j.nombre} no salió en esta tirada.');
    final plantel = t.plantel.asignar(j, p);
    final base = t.copyWith(plantel: plantel);
    if (t.tokens.picksExtra > 0) {
      if (candidatos(base).isEmpty) {
        throw const ReglaPlantelException('Ese puesto no le deja lugar al segundo jugador del Doble.');
      }
      return base.copyWith(tokens: t.tokens.copyWith(picksExtra: t.tokens.picksExtra - 1));
    }
    return _conTiradaNueva(base, null);
  }

  // ── Tokens ──

  /// Los tokens que trae este modo de draft (la bandeja solo muestra estos).
  static bool trae(Temporada t, TokenDraft k) {
    final modo = ReglasTokens.modoDe(t);
    if (modo == ModoTokens.ninguno) return false;
    if (k == TokenDraft.volverATirar) return true;
    if (ReglasTokens.tope(t, k) == 0) return false;
    // En el modo cartas no hay tirada que doblar ni cartas elegidas con otra tirada que cambiar.
    return t.modo != ModoDraft.cartas || k == TokenDraft.mejorVersion || k == TokenDraft.comodin;
  }

  /// Usos que le quedan al token en este draft (gratis y de pago), sin mirar las monedas.
  int usosRestantes(Temporada t, TokenDraft k) {
    if (ReglasTokens.modoDe(t) == ModoTokens.ninguno) return 0;
    if (k == TokenDraft.volverATirar) {
      final deMonedas = ReglasTokens.modoDe(t) == ModoTokens.monedas ? ReglasTokens.tope(t, k) : 0;
      return t.rerollsRestantes + max(0, deMonedas - t.tokens.pagosDe(k));
    }
    return max(0, ReglasTokens.tope(t, k) - t.tokens.usosDe(k));
  }

  /// Precio en monedas del próximo uso: 0 si es gratis, null si ya no se puede (sin usos, el modo no
  /// cobra o se llegó al tope de gasto del draft). El intercambio depende de las cartas ([sale] y
  /// [entra]); sin ellas es el precio base.
  int? precioDe(Temporada t, TokenDraft k, {Jugador? sale, Jugador? entra}) {
    if (usosRestantes(t, k) <= 0) return null;
    if (k == TokenDraft.volverATirar && t.rerollsRestantes > 0) return 0;
    if (k != TokenDraft.volverATirar && t.tokens.usosDe(k) < ReglasTokens.gratis(t, k, ventajas)) return 0;
    if (ReglasTokens.modoDe(t) != ModoTokens.monedas) return null;
    final bruto = k == TokenDraft.intercambio && sale != null && entra != null
        ? ReglasTokens.precioIntercambio(sale.media, entra.media)
        : ReglasTokens.precioBase(k, t.tokens.pagosDe(k));
    if (bruto == null) return null;
    final precio = ReglasTokens.conDescuento(bruto, ventajas);
    return t.tokens.gastadas + precio > ReglasTokens.topeGastoPorDraft ? null : precio;
  }

  /// Estado del token para la bandeja, con las [monedas] que tiene el jugador.
  EstadoToken estadoDe(Temporada t, TokenDraft k, {required int monedas}) {
    final precio = precioDe(t, k);
    if (precio == null) return EstadoToken.agotado;
    if (!_aplicable(t, k)) return EstadoToken.bloqueado;
    if (precio == 0) return EstadoToken.gratis;
    return monedas >= precio ? EstadoToken.disponible : EstadoToken.caro;
  }

  /// ¿Tiene sentido usar el token en este momento del draft?
  bool _aplicable(Temporada t, TokenDraft k) {
    if (t.plantel.completo || !trae(t, k)) return false;
    if (t.modo == ModoDraft.cartas) {
      final o = t.oferta;
      return switch (k) {
        TokenDraft.volverATirar || TokenDraft.mejorVersion => o != null && !o.sinAbrir,
        TokenDraft.comodin => o != null && o.sinAbrir,
        _ => false,
      };
    }
    if (t.tokens.picksExtra > 0) return false;
    final hayTirada = t.tirada != null;
    return switch (k) {
      TokenDraft.volverATirar => hayTirada,
      TokenDraft.mejorVersion => hayTirada && candidatos(t).any((j) => mejorVersionDe(t, j) != null),
      TokenDraft.doble => hayTirada && _dobleViable(t),
      TokenDraft.intercambio => hayTirada && t.plantel.jugadores.isNotEmpty && opcionesIntercambio(t).isNotEmpty,
      TokenDraft.comodin => true,
    };
  }

  void _verificarPago(Temporada t, TokenDraft k, int monedas, {Jugador? sale, Jugador? entra}) {
    final precio = precioDe(t, k, sale: sale, entra: entra);
    if (precio == null) {
      throw StateError(k == TokenDraft.volverATirar ? 'No quedan fichas de Reroll.' : '${k.nombre}: no quedan usos.');
    }
    if (precio > monedas) throw StateError('No alcanzan las monedas para ${k.nombre.toLowerCase()}.');
  }

  /// Anota el uso del token (y la ficha gratis de volver a tirar, si era gratis).
  Temporada _pagar(Temporada t, TokenDraft k, int monedas, {Jugador? sale, Jugador? entra}) {
    _verificarPago(t, k, monedas, sale: sale, entra: entra);
    final precio = precioDe(t, k, sale: sale, entra: entra)!;
    if (k == TokenDraft.volverATirar && precio == 0) return t.usarReroll();
    return t.copyWith(tokens: t.tokens.conUso(k, precio: precio));
  }

  /// Todas las cartas de la misma persona, de la de más media a la de menos.
  List<Jugador> versionesDe(Jugador j) =>
      [for (final c in catalogo) if (c.personaId == j.personaId) c]..sort((a, b) => a.id == b.id ? 0 : (esMejorVersion(a, b) ? -1 : 1));

  /// La mejor versión disponible de la persona de [j]: la de mayor media de TODO el catálogo (cualquier
  /// franquicia o tramo) que **cumple la regla del draft vigente** (Una sola década, Franquicia pura,
  /// Underdog, Mi colección…) y entra en un puesto libre. Si la mejor del catálogo viola la regla, se usa
  /// la mejor que sí cumple. Null si [j] ya es esa o no hay una de más media. Como es la misma persona,
  /// nunca duplica a nadie en la tirada.
  Jugador? mejorVersionDe(Temporada t, Jugador j) {
    final pool = t.modo == ModoDraft.cartas
        ? (t.oferta == null ? const <Jugador>[] : _elegibles(t, t.oferta!.posicion))
        : _disponibles(t).toList();
    Jugador? mejor;
    for (final c in pool) {
      if (c.personaId != j.personaId || c.id == j.id) continue;
      if (mejor == null || esMejorVersion(c, mejor)) mejor = c;
    }
    return mejor != null && mejor.media > j.media ? mejor : null;
  }

  /// Mejor versión: cambia [j] (una de las cartas que salieron) por su mejor versión. En la ruleta
  /// la carta cambiada queda en la grilla de esta tirada; en el modo cartas reemplaza a [j] en las
  /// cinco reveladas.
  Temporada mejorVersion(Temporada t, Jugador j, {int monedas = 0}) {
    final mejor = mejorVersionDe(t, j);
    if (mejor == null) throw StateError('${j.nombre} no tiene una versión mejor disponible.');
    final oferta = t.oferta;
    if (t.modo == ModoDraft.cartas) {
      if (oferta == null || !oferta.cartaIds.contains(j.id)) {
        throw ReglaPlantelException('${j.nombre} no está entre las cartas repartidas.');
      }
    } else if (!candidatos(t).contains(j) || t.tokens.sustituidas.containsValue(j.id)) {
      throw ReglaPlantelException('${j.nombre} no salió en esta tirada.');
    }
    final pagada = _pagar(t, TokenDraft.mejorVersion, monedas);
    if (t.modo == ModoDraft.cartas) {
      return pagada.conOferta(
        Oferta(
          posicion: oferta!.posicion,
          cartaIds: [for (final id in oferta.cartaIds) id == j.id ? mejor.id : id],
          sorpresaId: oferta.sorpresaId == j.id ? mejor.id : oferta.sorpresaId,
          robadas: oferta.robadas,
          ciega: oferta.ciega,
        ),
      );
    }
    return pagada.copyWith(
      tokens: pagada.tokens.copyWith(sustituidas: {...pagada.tokens.sustituidas, j.id: mejor.id}),
    );
  }

  bool _dobleViable(Temporada t) {
    final c = candidatos(t);
    for (final a in c) {
      for (final b in c) {
        if (a.personaId == b.personaId) continue;
        for (final pa in t.plantel.posicionesDisponiblesPara(a)) {
          if (t.plantel.posicionesDisponiblesPara(b).any((pb) => pb != pa)) return true;
        }
      }
    }
    return false;
  }

  /// Doble: con la misma tirada elegís dos jugadores (cada uno en su puesto). Se paga al activarlo.
  Temporada doble(Temporada t, {int monedas = 0}) {
    if (t.tirada == null || !_aplicable(t, TokenDraft.doble)) {
      throw StateError('El Doble pide una tirada con dos cartas que entren en dos puestos libres.');
    }
    final pagada = _pagar(t, TokenDraft.doble, monedas);
    return pagada.copyWith(tokens: pagada.tokens.copyWith(picksExtra: 1));
  }

  /// Para el intercambio: (puesto, carta que sale, cartas de esta tirada que podrían entrar ahí).
  List<(Posicion, Jugador, List<Jugador>)> opcionesIntercambio(Temporada t) {
    final tirada = t.tirada;
    if (tirada == null) return const [];
    return [
      for (final p in Posicion.values)
        if (t.plantel.en(p) case final sale?)
          if (unaPorPersona([
            for (final c in catalogo)
              if (tirada.incluye(c) && c.personaId != sale.personaId && _puedeEntrarEn(t, c, p)) c,
          ])..sort((a, b) => b.media.compareTo(a.media))
              case final entran when entran.isNotEmpty)
            (p, sale, entran),
    ];
  }

  bool _puedeEntrarEn(Temporada t, Jugador c, Posicion p) =>
      permitida(t, c) && c.puedeJugarEn(p) && !t.plantel.quitar(p).contiene(c);

  /// Intercambio: la carta del puesto [p] se pierde y entra [entra], de esta tirada. Cuesta el
  /// precio base más 10 monedas por cada punto de media que ganás (tope 400). Gasta la tirada:
  /// para el próximo puesto libre volvés a tirar gratis.
  Temporada intercambiar(Temporada t, Jugador entra, Posicion p, {int monedas = 0}) {
    final tirada = t.tirada;
    final sale = t.plantel.en(p);
    if (tirada == null || sale == null || t.tokens.picksExtra > 0 || !tirada.incluye(entra)) {
      throw const ReglaPlantelException('El intercambio pide una carta de esta tirada y un puesto ya ocupado.');
    }
    // Solo entra la carta que la tirada muestra para esa persona (una por persona) y nunca otra versión de
    // quien sale.
    final muestra = opcionesIntercambio(t).any((o) => o.$1 == p && o.$3.any((c) => c.id == entra.id));
    if (!muestra || !_puedeEntrarEn(t, entra, p) || entra.id == sale.id) {
      throw ReglaPlantelException('${entra.nombre} no puede reemplazar a ${sale.nombre} como ${p.etiqueta}.');
    }
    final pagada = _pagar(t, TokenDraft.intercambio, monedas, sale: sale, entra: entra);
    final plantel = pagada.plantel.quitar(p).asignar(entra, p);
    return _conTiradaNueva(pagada.copyWith(plantel: plantel), null);
  }

  /// Franquicias y épocas que hoy podrían salir (para elegir con el Comodín).
  Set<String> franquiciasPosibles(Temporada t) {
    if (t.modo == ModoDraft.cartas) {
      final personas = _personasPor(_elegiblesOferta(t), (j) => j.franquiciaId);
      return {for (final e in personas.entries) if (e.value.length >= cartasPorReparto) e.key};
    }
    return {for (final j in _disponibles(t)) j.franquiciaId};
  }

  Set<Epoca> epocasPosibles(Temporada t) {
    if (t.modo == ModoDraft.cartas) {
      final personas = _personasPor(_elegiblesOferta(t), (j) => j.epoca);
      return {for (final e in personas.entries) if (e.value.length >= cartasPorReparto) e.key};
    }
    return {for (final j in _disponibles(t)) j.epoca};
  }

  List<Jugador> _elegiblesOferta(Temporada t) => t.oferta == null ? const [] : _elegibles(t, t.oferta!.posicion);

  /// Comodín: fijás la franquicia **o** la época de la próxima tirada; el otro carrete y la rareza
  /// se sortean (paso [pasoComodin]). Reemplaza a la tirada en curso, si hay.
  Temporada comodin(Temporada t, {String? franquiciaId, Epoca? epoca, int monedas = 0}) {
    if ((franquiciaId == null) == (epoca == null)) {
      throw ArgumentError('El Comodín fija la franquicia o la época, una sola.');
    }
    if (!_aplicable(t, TokenDraft.comodin)) throw StateError('No se puede usar el Comodín ahora.');
    final combinaciones = {
      for (final j in _visibles(t))
        if ((franquiciaId == null || j.franquiciaId == franquiciaId) && (epoca == null || j.epoca == epoca))
          Tirada.de(j),
    }.toList();
    if (combinaciones.isEmpty) throw StateError('No quedan cartas para esa elección.');
    final pagada = _pagar(t, TokenDraft.comodin, monedas);
    _sembrar(t, pasoComodin);
    return _conTiradaNueva(pagada, _sortear(combinaciones));
  }

  /// Comodín en el modo cartas: cambia el sobre de franquicia (o el de época) por el que elegís.
  Temporada comodinSobre(Temporada t, {String? franquiciaId, Epoca? epoca, int monedas = 0}) {
    if ((franquiciaId == null) == (epoca == null)) {
      throw ArgumentError('El Comodín fija la franquicia o la época, una sola.');
    }
    final oferta = t.oferta;
    if (oferta == null || !oferta.sinAbrir || !_aplicable(t, TokenDraft.comodin)) {
      throw StateError('El Comodín se usa con los sobres cerrados sobre la mesa.');
    }
    final sobre = franquiciaId != null ? Sobre(TipoSobre.franquicia, franquiciaId: franquiciaId) : Sobre(TipoSobre.epoca, epoca: epoca);
    if (_personasDistintas(_elegibles(t, oferta.posicion).where(sobre.incluye)) < cartasPorReparto) {
      throw StateError('Ese sobre no tiene cartas suficientes para este puesto.');
    }
    final pagada = _pagar(t, TokenDraft.comodin, monedas);
    final i = oferta.sobres.indexWhere((s) => s.tipo == sobre.tipo);
    final sobres = [...oferta.sobres];
    i < 0 ? sobres.insert(0, sobre) : sobres[i] = sobre;
    return pagada.conOferta(Oferta(posicion: oferta.posicion, sobres: sobres.take(3).toList()));
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
    // Filtro del sobre (época, franquicia, regla, puesto libre) y después UNA carta por persona: la de
    // mayor media de lo que pasó el filtro. Un sobre no repite persona ni con otra versión.
    var pool = unaPorPersona(_elegibles(t, oferta.posicion).where(sobre.incluye));
    if (pool.length < cartasPorReparto) pool = unaPorPersona(_elegibles(t, oferta.posicion));
    final serpiente = t.regla == ReglaDraft.serpiente && t.plantel.jugadores.length.isOdd;
    final cantidad = cartasPorReparto + (serpiente ? 2 : 0);
    final cartas = _repartirDe(pool, cantidad - 1, misterioso: sobre.tipo == TipoSobre.misterioso);
    // La sorpresa: una carta más, con más chances de ser grande.
    final sacadas = {for (final c in cartas) c.personaId};
    final resto = pool.where((j) => !sacadas.contains(j.personaId)).toList();
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

  /// Cuesta una ficha gratis o monedas (como volver a tirar): vuelve a poner 3 sobres nuevos.
  Temporada volverARepartir(Temporada t, {int monedas = 0}) {
    final oferta = t.oferta;
    if (oferta == null) throw StateError('No hay cartas repartidas.');
    _verificarPago(t, TokenDraft.volverATirar, monedas);
    _sembrar(t, 200 + oferta.posicion.index);
    return _pagar(
      t,
      TokenDraft.volverATirar,
      monedas,
    ).conOferta(Oferta(posicion: oferta.posicion, sobres: _sobres(t, oferta.posicion)));
  }

  Temporada fichar(Temporada t, Jugador j) {
    final oferta = t.oferta;
    if (oferta == null || !oferta.cartaIds.contains(j.id)) {
      throw ReglaPlantelException('${j.nombre} no está entre las cartas repartidas.');
    }
    return t.copyWith(plantel: t.plantel.asignar(j, oferta.posicion)).conOferta(null);
  }

  /// Cartas que cumplen la regla y entran en [pos] (todas las versiones: agrupar por persona es cosa del
  /// que reparte, después de filtrar). En el draft en serpiente las personas que ya se llevó un rival
  /// no vuelven a salir.
  List<Jugador> _elegibles(Temporada t, Posicion pos) {
    final robadas = t.robos.isEmpty
        ? const <String>{}
        : {for (final ids in t.robos.values) for (final id in ids) ?_porId[id]?.personaId};
    return [
      for (final j in catalogo)
        if (permitida(t, j) && !robadas.contains(j.personaId) && t.plantel.posicionesDisponiblesPara(j).contains(pos))
          j,
    ];
  }

  /// Personas distintas de [cartas] por clave (franquicia, época…): lo que cuenta para que un sobre tenga
  /// al menos [cartasPorReparto] cartas.
  Map<K, Set<String>> _personasPor<K>(Iterable<Jugador> cartas, K Function(Jugador) clave) {
    final m = <K, Set<String>>{};
    for (final j in cartas) {
      (m[clave(j)] ??= {}).add(j.personaId);
    }
    return m;
  }

  int _personasDistintas(Iterable<Jugador> cartas) => {for (final j in cartas) j.personaId}.length;

  /// 3 sobres distintos con al menos 5 cartas cada uno: de una época, de una franquicia y misterioso.
  List<Sobre> _sobres(Temporada t, Posicion pos) {
    final pool = _elegibles(t, pos);
    // Un sobre cuenta PERSONAS (no cartas): tiene que poder traer 5 jugadores distintos.
    List<T> conCartas<T>(Map<T, Set<String>> personas) {
      final ok = [
        for (final e in personas.entries)
          if (e.value.length >= cartasPorReparto) e.key,
      ]..shuffle(_paso);
      return ok;
    }

    final epocas = conCartas(_personasPor(pool, (j) => j.epoca));
    final franquicias = conCartas(_personasPor(pool, (j) => j.franquiciaId));
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

  /// Reparte [cantidad] cartas del pool (que ya trae una sola carta por persona): primero se sortea la
  /// rareza (pesos de 82-0), después una carta de esa rareza. Nunca dos cartas de la misma persona.
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
      pool = pool.where((j) => j.personaId != carta.personaId).toList();
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
