import 'dart:math';

import '../entities/jugador.dart';
import '../entities/modo_juego.dart';
import '../entities/perfil.dart';
import '../entities/plantel.dart';
import '../entities/posicion.dart';
import '../entities/temporada.dart';
import '../liga.dart';
import '../motor.dart';
import '../playbook.dart';
import 'escalera.dart' show Cruce, ModosEscalera, RivalEscalera;

/// Un participante de los torneos por época: una clase de draft, una universidad o el campeón de
/// una década.
class EquipoEpoca {
  const EquipoEpoca({required this.clave, required this.nombre, required this.equipo});

  /// '1984', 'Duke', '' (sin universidad) o el nombre de la época ('anios90').
  final String clave;

  /// "Camada 1984", "Duke", "Directo a la NBA", "Boston Celtics (60’)".
  final String nombre;
  final RivalEscalera equipo;

  factory EquipoEpoca.fromJson(Map<String, dynamic> j) => EquipoEpoca(
    clave: j['clave'] as String,
    nombre: j['nombre'] as String,
    equipo: RivalEscalera.fromJson(j['equipo'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {'clave': clave, 'nombre': nombre, 'equipo': equipo.toJson()};
}

/// Estado de una partida de Guantelete de las décadas, Batalla de camadas o Torneo de universidades
/// (en [Temporada.datosModo]).
///
/// - Guantelete: [equipos] son los campeones de cada década, en orden; [etapa] es por cuál vas.
///   Arranca con un mini-draft de los años 40 y 50 ([ofertas], [elegidas]) y después de cada
///   victoria se recluta a uno del rival ([reclutando]).
/// - Camadas y universidades: [equipos] es el cuadro (ordenado por media) y [usuario] el tuyo;
///   [ganadores] y [marcadores] guardan cada ronda (con −1 / '' en tu llave mientras se juega).
class EstadoEpocas {
  const EstadoEpocas({
    this.equipos = const [],
    this.usuario = -1,
    this.propio,
    this.ganadores = const [],
    this.marcadores = const [],
    this.cruce,
    this.historial = const [],
    this.etapa = 0,
    this.reclutando = false,
    this.reclutas = const [],
    this.ofertas = const [],
    this.elegidas = const {},
  });

  static const clave = 'epocas';

  final List<EquipoEpoca> equipos;
  final int usuario;

  /// Tu equipo (en el guantelete cambia con cada recluta).
  final RivalEscalera? propio;
  final List<List<int>> ganadores;
  final List<List<String>> marcadores;

  /// Tu cruce en curso (o el último que jugaste).
  final Cruce? cruce;

  /// Tus cruces ya terminados, en orden.
  final List<Cruce> historial;
  final int etapa;
  final bool reclutando;

  /// Ids de carta que reclutaste en el guantelete.
  final List<String> reclutas;

  /// Mini-draft del guantelete: las cartas ofrecidas para el puesto que sigue y las ya elegidas.
  final List<String> ofertas;
  final Map<Posicion, String> elegidas;

  static EstadoEpocas de(Temporada t) => switch (t.datosModo[clave]) {
    final Map<String, dynamic> j => EstadoEpocas.fromJson(j),
    _ => const EstadoEpocas(),
  };

  Temporada en(Temporada t) => t.copyWith(datosModo: {...t.datosModo, clave: toJson()});

  bool get enDraft => propio == null;

  /// Puesto que se elige ahora en el mini-draft (null si ya terminó).
  Posicion? get puestoDraft => Posicion.values.where((p) => !elegidas.containsKey(p)).firstOrNull;

  bool get eliminado => historial.any((c) => !c.ganado);

  /// Ganaste todo: el guantelete entero o el cuadro.
  bool get campeon {
    if (eliminado || propio == null) return false;
    if (usuario < 0) return historial.length == ModosEpocas.decadas.length; // guantelete: las 8 décadas
    return ganadores.isNotEmpty && ganadores.last.length == 1 && ganadores.last.first == usuario;
  }

  bool get terminado => eliminado || campeon;

  /// Tu cruce si todavía se juega (y no estás eligiendo recluta).
  Cruce? get pendiente => cruce == null || cruce!.terminado || reclutando ? null : cruce;

  /// Campeón del cuadro (cuando terminó).
  int? get campeonCuadro =>
      ganadores.isNotEmpty && ganadores.last.length == 1 && ganadores.last.first >= 0 ? ganadores.last.first : null;

  List<(int, int)> get todosLosMarcadores => [
    for (final c in historial) ...c.marcadores,
    if (cruce case final c? when !c.terminado) ...c.marcadores,
  ];

  EstadoEpocas copyWith({
    List<EquipoEpoca>? equipos,
    int? usuario,
    RivalEscalera? propio,
    List<List<int>>? ganadores,
    List<List<String>>? marcadores,
    Cruce? cruce,
    bool sinCruce = false,
    List<Cruce>? historial,
    int? etapa,
    bool? reclutando,
    List<String>? reclutas,
    List<String>? ofertas,
    Map<Posicion, String>? elegidas,
  }) => EstadoEpocas(
    equipos: equipos ?? this.equipos,
    usuario: usuario ?? this.usuario,
    propio: propio ?? this.propio,
    ganadores: ganadores ?? this.ganadores,
    marcadores: marcadores ?? this.marcadores,
    cruce: sinCruce ? null : cruce ?? this.cruce,
    historial: historial ?? this.historial,
    etapa: etapa ?? this.etapa,
    reclutando: reclutando ?? this.reclutando,
    reclutas: reclutas ?? this.reclutas,
    ofertas: ofertas ?? this.ofertas,
    elegidas: elegidas ?? this.elegidas,
  );

  factory EstadoEpocas.fromJson(Map<String, dynamic> j) => EstadoEpocas(
    equipos: [for (final e in j['equipos'] as List? ?? const []) EquipoEpoca.fromJson(e as Map<String, dynamic>)],
    usuario: j['usuario'] as int? ?? -1,
    propio: j['propio'] == null ? null : RivalEscalera.fromJson(j['propio'] as Map<String, dynamic>),
    ganadores: [
      for (final r in j['ganadores'] as List? ?? const []) [for (final x in r as List) x as int],
    ],
    marcadores: [
      for (final r in j['marcadores'] as List? ?? const []) [for (final x in r as List) x as String],
    ],
    cruce: j['cruce'] == null ? null : Cruce.fromJson(j['cruce'] as Map<String, dynamic>),
    historial: [for (final c in j['historial'] as List? ?? const []) Cruce.fromJson(c as Map<String, dynamic>)],
    etapa: j['etapa'] as int? ?? 0,
    reclutando: j['reclutando'] as bool? ?? false,
    reclutas: [for (final x in j['reclutas'] as List? ?? const []) x as String],
    ofertas: [for (final x in j['ofertas'] as List? ?? const []) x as String],
    elegidas: {
      for (final e in (j['elegidas'] as Map<String, dynamic>? ?? const {}).entries)
        Posicion.values.byName(e.key): e.value as String,
    },
  );

  Map<String, dynamic> toJson() => {
    if (equipos.isNotEmpty) 'equipos': [for (final e in equipos) e.toJson()],
    'usuario': usuario,
    if (propio != null) 'propio': propio!.toJson(),
    if (ganadores.isNotEmpty) 'ganadores': ganadores,
    if (marcadores.isNotEmpty) 'marcadores': marcadores,
    if (cruce != null) 'cruce': cruce!.toJson(),
    if (historial.isNotEmpty) 'historial': [for (final c in historial) c.toJson()],
    'etapa': etapa,
    if (reclutando) 'reclutando': true,
    if (reclutas.isNotEmpty) 'reclutas': reclutas,
    if (ofertas.isNotEmpty) 'ofertas': ofertas,
    if (elegidas.isNotEmpty) 'elegidas': {for (final e in elegidas.entries) e.key.name: e.value},
  };
}

/// Reglas de los tres modos.
class ModosEpocas {
  ModosEpocas(this.liga, {Random? azar}) : _azar = azar ?? Random(), _escalera = ModosEscalera(liga, azar: azar);

  final Liga liga;
  final Random _azar;
  final ModosEscalera _escalera;

  static bool esModo(ModoJuego m) =>
      const {ModoJuego.guantelete, ModoJuego.camadas, ModoJuego.universidades}.contains(m);

  /// Clases de draft candidatas (se juegan las 8 más fuertes).
  static const clasesDraft = [1984, 1985, 1987, 1992, 1996, 1998, 2003, 2009, 2011, 2018];

  /// Universidades candidatas (como las escribe Basketball-Reference; se juegan las 15 más fuertes y
  /// los que llegaron sin pasar por una).
  static const universidadesCandidatas = [
    'Duke', 'North Carolina', 'Kentucky', 'UCLA', 'Kansas', 'Michigan State', 'Arizona', 'Syracuse', 'Georgetown', //
    'Indiana', 'Louisville', 'Villanova', 'Connecticut', 'Michigan', 'Notre Dame', 'Ohio State', 'Wake Forest', //
    'Texas', 'LSU', 'Georgia Tech', 'Houston', 'Memphis', 'Alabama', 'Gonzaga',
  ];

  static String nombreUniversidad(String? u) => u == null || u.isEmpty ? 'Directo a la NBA' : u;

  /// Décadas del guantelete, en orden (el mini-draft es de los 40 y 50).
  static const decadas = [
    Epoca.anios50,
    Epoca.anios60,
    Epoca.anios70,
    Epoca.anios80,
    Epoca.anios90,
    Epoca.anios2000,
    Epoca.anios2010,
    Epoca.actualidad,
  ];

  static const cartasPorOferta = 4;

  // ── Armado de equipos ──

  /// La mejor carta de cada persona del [pool] (su pico), de mayor a menor media.
  static List<Jugador> mejorCartaPorPersona(Iterable<Jugador> pool) {
    final mejor = <String, Jugador>{};
    for (final j in pool) {
      final persona = j.idBbref;
      if (mejor[persona] case final otra? when otra.media >= j.media) continue;
      mejor[persona] = j;
    }
    return mejor.values.toList()
      ..sort((a, b) => b.media != a.media ? b.media.compareTo(a.media) : a.id.compareTo(b.id));
  }

  RivalEscalera? _equipoDe(List<Jugador> pool, String etiqueta) {
    final p = _escalera.completar(const Plantel(), pool);
    if (p == null) return null;
    final estrella = p.jugadores.reduce((a, b) => b.media > a.media ? b : a);
    return RivalEscalera(
      identidadId: estrella.equipo,
      etiqueta: etiqueta,
      cartaIds: {for (final pos in Posicion.values) pos: p.en(pos)!.id},
      tactica: recomendar(PerfilPlantel.de(p)).tactica,
      media: ModosEscalera.mediaDe(p),
    );
  }

  /// Las 8 clases de draft más fuertes, ordenadas por media.
  List<EquipoEpoca> equiposCamadas() {
    final equipos = <EquipoEpoca>[];
    for (final anio in clasesDraft) {
      final pool = mejorCartaPorPersona(liga.catalogo.where((j) => j.draft?.$1 == anio));
      final r = _equipoDe(pool, 'Camada $anio');
      if (r != null) equipos.add(EquipoEpoca(clave: '$anio', nombre: 'Camada $anio', equipo: r));
    }
    equipos.sort((a, b) => b.equipo.media.compareTo(a.equipo.media));
    return equipos.take(8).toList();
  }

  /// Las 15 universidades más fuertes y los que llegaron sin universidad, ordenados por media.
  List<EquipoEpoca> equiposUniversidades() {
    final equipos = <EquipoEpoca>[];
    for (final u in universidadesCandidatas) {
      final pool = mejorCartaPorPersona(liga.catalogo.where((j) => j.universidad == u));
      final r = _equipoDe(pool, nombreUniversidad(u));
      if (r != null) equipos.add(EquipoEpoca(clave: u, nombre: nombreUniversidad(u), equipo: r));
    }
    equipos.sort((a, b) => b.equipo.media.compareTo(a.equipo.media));
    final elegidas = equipos.take(15).toList();
    // Solo cartas con dato de nacimiento: así no entran los pioneros sin registro de universidad.
    final sin = mejorCartaPorPersona(liga.catalogo.where((j) => j.universidad == null && j.nacimiento != null));
    if (_equipoDe(sin, nombreUniversidad(null)) case final r?) {
      elegidas.add(EquipoEpoca(clave: '', nombre: nombreUniversidad(null), equipo: r));
    }
    elegidas.sort((a, b) => b.equipo.media.compareTo(a.equipo.media));
    return elegidas;
  }

  Set<String> _personas(RivalEscalera r) => {for (final id in r.cartaIds.values) ?liga.jugador(id)?.idBbref};

  /// Campeón de una década: la franquicia con el mejor plantel de esa época (sin repetir personas
  /// que ya estén en tu equipo). Con [objetivo], ese mismo grupo arma su plantel con las cartas de
  /// media más cercana a ese valor (así el guantelete crece a la par de tu equipo).
  RivalEscalera campeonDeDecada(Epoca epoca, {Set<String> excluidos = const {}, double? objetivo}) {
    final grupos = <String, List<Jugador>>{};
    for (final j in liga.catalogo) {
      if (j.epoca != epoca || excluidos.contains(j.idBbref)) continue;
      (grupos[j.franquiciaId] ??= []).add(j);
    }
    RivalEscalera? mejor;
    List<Jugador>? pool;
    for (final f in grupos.keys.toList()..sort()) {
      final candidatos = mejorCartaPorPersona(grupos[f]!);
      final r = _equipoDe(candidatos, '(${epoca.corta})');
      if (r != null && (mejor == null || r.media > mejor.media)) {
        mejor = r;
        pool = candidatos;
      }
    }
    if (objetivo == null || objetivo >= mejor!.media) return mejor!;
    final p = _escalera.completar(const Plantel(), pool!, objetivo: objetivo.round());
    if (p == null) return mejor;
    return RivalEscalera(
      identidadId: mejor.identidadId,
      etiqueta: mejor.etiqueta,
      cartaIds: {for (final pos in Posicion.values) pos: p.en(pos)!.id},
      tactica: recomendar(PerfilPlantel.de(p)).tactica,
      media: ModosEscalera.mediaDe(p),
    );
  }

  /// Media objetivo del campeón de la etapa [etapa], según la de tu equipo: arranca un poco por
  /// debajo y termina un poco por encima.
  static double objetivoEtapa(double mediaPropia, int etapa) => mediaPropia + objetivosGuantelete[etapa];

  static var objetivosGuantelete = const [-2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5];

  // ── Arranque ──

  static int _semilla(String clave) {
    var h = 0x811c9dc5;
    for (final c in clave.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Cartas del mini-draft (años 40 y 50) para el puesto [p]: 4 al azar entre las 30 de más media
  /// que juegan ahí, sin personas ya elegidas. Fijas para esa partida y ese puesto.
  List<String> ofertaDraft(Temporada t, Posicion p, Map<Posicion, String> elegidas) {
    final tomadas = {for (final id in elegidas.values) ?liga.jugador(id)?.idBbref};
    final pool = mejorCartaPorPersona(
      liga.catalogo.where(
        (j) =>
            (j.epoca == Epoca.anios40 || j.epoca == Epoca.anios50) && j.puedeJugarEn(p) && !tomadas.contains(j.idBbref),
      ),
    );
    final top = pool.take(30).toList()..shuffle(Random(_semilla('${t.id}-${p.name}')));
    return [for (final j in top.take(cartasPorOferta)) j.id];
  }

  /// Partida nueva del guantelete (arranca en el mini-draft).
  Temporada nuevoGuantelete({required String id, required String franquiciaId, required Dificultad dificultad}) {
    final t = Temporada(
      id: id,
      franquiciaUsuarioId: franquiciaId,
      dificultad: dificultad,
      modoJuego: ModoJuego.guantelete,
    );
    return EstadoEpocas(ofertas: ofertaDraft(t, Posicion.values.first, const {})).en(t);
  }

  /// Elegís una carta del mini-draft. Con los 6 puestos, arranca el guantelete.
  Temporada elegirDraft(Temporada t, String cartaId) {
    final e = EstadoEpocas.de(t);
    final p = e.puestoDraft;
    if (p == null || !e.ofertas.contains(cartaId)) return t;
    final elegidas = {...e.elegidas, p: cartaId};
    final siguiente = Posicion.values.where((x) => !elegidas.containsKey(x)).firstOrNull;
    if (siguiente != null) {
      return e.copyWith(elegidas: elegidas, ofertas: ofertaDraft(t, siguiente, elegidas)).en(t);
    }
    final propio = _propioDe(elegidas, '(40-50)');
    final x = _conPlantel(t, propio);
    final rival = campeonDeDecada(
      decadas.first,
      excluidos: _personas(propio),
      objetivo: objetivoEtapa(propio.media, 0),
    );
    return EstadoEpocas(
      equipos: [EquipoEpoca(clave: decadas.first.name, nombre: decadas.first.etiqueta, equipo: rival)],
      propio: propio,
      elegidas: elegidas,
      cruce: _cruceGuantelete(0, rival),
    ).en(x);
  }

  RivalEscalera _propioDe(Map<Posicion, String> cartas, String etiqueta) {
    var p = const Plantel();
    for (final e in cartas.entries) {
      p = p.asignar(liga.jugador(e.value)!, e.key);
    }
    return RivalEscalera(
      identidadId: '',
      etiqueta: etiqueta,
      cartaIds: Map.of(cartas),
      tactica: recomendar(PerfilPlantel.de(p)).tactica,
      media: ModosEscalera.mediaDe(p),
    );
  }

  /// El plantel queda en la partida (para la ficha y la lista de partidas; no suma al álbum).
  Temporada _conPlantel(Temporada t, RivalEscalera propio) {
    var p = const Plantel();
    for (final e in propio.cartaIds.entries) {
      p = p.asignar(liga.jugador(e.value)!, e.key);
    }
    return t.copyWith(plantel: p, tactica: propio.tactica, tacticaConfirmada: true);
  }

  Cruce _cruceGuantelete(int etapa, RivalEscalera rival) => Cruce(
    rival: rival,
    titulo: 'Década ${etapa + 1} de ${decadas.length}: ${decadas[etapa].etiqueta}',
    aGanar: 2,
    usuarioAlto: false,
  );

  /// Partida nueva de camadas o universidades con tu equipo [elegido] (índice en [equipos]).
  Temporada nuevoCuadro({
    required String id,
    required ModoJuego modo,
    required List<EquipoEpoca> equipos,
    required int elegido,
    required Dificultad dificultad,
  }) {
    final propio = equipos[elegido].equipo;
    var t = Temporada(id: id, franquiciaUsuarioId: propio.identidadId, dificultad: dificultad, modoJuego: modo);
    t = _conPlantel(t, propio);
    return _avanzarCuadro(EstadoEpocas(equipos: equipos, usuario: elegido, propio: propio), t);
  }

  // ── Cuadro ──

  static List<int> ordenLlaves(int n) => switch (n) {
    16 => const [0, 15, 7, 8, 3, 12, 4, 11, 1, 14, 6, 9, 2, 13, 5, 10],
    8 => const [0, 7, 3, 4, 2, 5, 1, 6],
    4 => const [0, 3, 1, 2],
    _ => [for (var i = 0; i < n; i++) i],
  };

  static List<String> nombresRondas(int n) => switch (n) {
    16 => const ['Octavos de final', 'Cuartos de final', 'Semifinales', 'La final'],
    8 => const ['Cuartos de final', 'Semifinales', 'La final'],
    _ => const ['Semifinales', 'La final'],
  };

  /// Partido único en las primeras rondas; semifinales y final, al mejor de 3.
  static int aGanarEnRonda(int n, int ronda) => ronda >= nombresRondas(n).length - 2 ? 2 : 1;

  List<int> participantes(EstadoEpocas e, int ronda) =>
      ronda == 0 ? ordenLlaves(e.equipos.length) : e.ganadores[ronda - 1];

  /// Juega lo que no es tuyo y arma tu cruce de la ronda que sigue. Si quedaste afuera, simula el
  /// resto del cuadro hasta el campeón.
  Temporada _avanzarCuadro(EstadoEpocas e, Temporada t) {
    var esc = e;
    final rondas = nombresRondas(esc.equipos.length);
    for (var guarda = 0; guarda < 8; guarda++) {
      final r = esc.ganadores.length;
      // Ronda en curso: la última, si todavía tiene tu llave sin resolver.
      if (r > 0 && esc.ganadores.last.contains(-1)) {
        final c = esc.cruce;
        if (c == null || !c.terminado) break;
        final part = participantes(esc, r - 1);
        final k = esc.ganadores.last.indexOf(-1);
        final rival = part[2 * k] == esc.usuario ? part[2 * k + 1] : part[2 * k];
        final ronda0 = [...esc.ganadores.last];
        ronda0[k] = c.ganado ? esc.usuario : rival;
        final textos = [...esc.marcadores.last];
        textos[k] = _textoCruce(c, esc.usuario == part[2 * k]);
        final ganadores = [...esc.ganadores.take(r - 1), ronda0];
        final marcadores = [...esc.marcadores.take(r - 1), textos];
        esc = esc.copyWith(
          ganadores: ganadores,
          marcadores: marcadores,
          historial: [...esc.historial, c],
          sinCruce: true,
        );
        continue;
      }
      if (r > 0 && esc.ganadores.last.length == 1) break; // hay campeón
      if (r >= rondas.length) break;
      final part = participantes(esc, r);
      final ganadores = <int>[];
      final marcadores = <String>[];
      Cruce? cruce;
      for (var k = 0; k + 1 < part.length; k += 2) {
        final (a, b) = (part[k], part[k + 1]);
        final aGanar = aGanarEnRonda(esc.equipos.length, r);
        if (a == esc.usuario || b == esc.usuario) {
          final rival = a == esc.usuario ? b : a;
          ganadores.add(-1);
          marcadores.add('');
          cruce = Cruce(
            rival: esc.equipos[rival].equipo,
            titulo: rondas[r],
            aGanar: aGanar,
            usuarioAlto: esc.usuario < rival,
          );
        } else {
          final (ganaA, texto) = _simularLlave(esc.equipos[a].equipo, esc.equipos[b].equipo, aGanar: aGanar);
          ganadores.add(ganaA ? a : b);
          marcadores.add(texto);
        }
      }
      esc = esc.copyWith(
        ganadores: [...esc.ganadores, ganadores],
        marcadores: [...esc.marcadores, marcadores],
        cruce: cruce,
        sinCruce: cruce == null,
      );
      if (cruce != null) break;
    }
    return esc.en(t);
  }

  String _textoCruce(Cruce c, bool usuarioPrimero) {
    if (c.aGanar > 1) return usuarioPrimero ? '${c.propias}-${c.ajenas}' : '${c.ajenas}-${c.propias}';
    final (m, s) = c.marcadores.last;
    return usuarioPrimero ? '$m-$s' : '$s-$m';
  }

  (bool, String) _simularLlave(RivalEscalera a, RivalEscalera b, {required int aGanar}) {
    var va = 0, vb = 0;
    var ultimo = '';
    while (va < aGanar && vb < aGanar) {
      final aLocal = (va + vb).isEven;
      final m = MotorPartido(
        local: _escalera.equipoRival(aLocal ? a : b),
        visitante: _escalera.equipoRival(aLocal ? b : a),
        azar: _azar,
      )..simularTodo();
      final ganaLocal = m.puntosLocal > m.puntosVisitante;
      (ganaLocal == aLocal) ? va++ : vb++;
      final (pa, pb) = aLocal ? (m.puntosLocal, m.puntosVisitante) : (m.puntosVisitante, m.puntosLocal);
      ultimo = '$pa-$pb';
    }
    return (va > vb, aGanar > 1 ? '$va-$vb' : ultimo);
  }

  // ── Partidos ──

  /// Los rivales son planteles históricos fijos: la dificultad les ajusta la media. En el
  /// guantelete los primeros campeones llegan un poco más accesibles (rampa de −3 a 0).
  int _ajuste(Temporada t, EstadoEpocas e) {
    final base = ModosEscalera.ajusteDificultad(t.dificultad);
    if (t.modoJuego != ModoJuego.guantelete) return base;
    // El motor juega las épocas viejas más débiles que su media (sin triples, otro ritmo). Cada
    // década de distancia entre tu equipo (en promedio) y el rival le resta [porDecada] de media al
    // rival: con los reclutas tu equipo se moderniza y la ayuda se achica.
    final rival = decadas[e.etapa.clamp(0, decadas.length - 1)].index;
    final distancia = max(0.0, rival - eraPromedio(e.propio!));
    return base - (distancia * porDecada).round();
  }

  /// Media de ajuste por cada década de distancia (calibrado con simulaciones).
  static var porDecada = 3.0;

  /// Época promedio (índice de [Epoca]) de las cartas de un equipo.
  double eraPromedio(RivalEscalera r) {
    final js = [for (final id in r.cartaIds.values) ?liga.jugador(id)];
    return js.isEmpty ? 0 : js.fold(0, (a, j) => a + j.epoca.index) / js.length;
  }

  /// Motor del próximo partido de tu cruce.
  MotorPartido motor(Temporada t) {
    final e = EstadoEpocas.de(t);
    final c = e.pendiente ?? (throw StateError('No hay partido pendiente.'));
    final propio = _escalera.equipoRival(e.propio!);
    final rival = _escalera.equipoRival(c.rival, ajuste: _ajuste(t, e));
    final local = c.usuarioLocalProximo;
    return MotorPartido(
      local: local ? propio : rival,
      visitante: local ? rival : propio,
      usuarioLocal: local,
      azar: _azar,
    );
  }

  /// Registra un partido tuyo y avanza el modo.
  Temporada registrar(Temporada t, MotorPartido m) {
    final e = EstadoEpocas.de(t);
    final c = e.pendiente;
    if (c == null) return t;
    final local = m.usuarioLocal ?? true;
    final (mios, suyos) = local ? (m.puntosLocal, m.puntosVisitante) : (m.puntosVisitante, m.puntosLocal);
    final nuevo = c.conResultado(mios, suyos);
    final esc = e.copyWith(cruce: nuevo);
    if (!nuevo.terminado) return esc.en(t);
    if (t.modoJuego == ModoJuego.guantelete) return _cerrarEtapa(esc, t);
    return _avanzarCuadro(esc, t);
  }

  Temporada simularPartido(Temporada t) => registrar(t, motor(t)..simularTodo());

  /// Simula tu cruce entero.
  Temporada simularCruce(Temporada t) {
    var x = t;
    final inicio = EstadoEpocas.de(t).historial.length;
    for (var guarda = 0; guarda < 7; guarda++) {
      final e = EstadoEpocas.de(x);
      if (e.pendiente == null || e.historial.length > inicio) break;
      x = simularPartido(x);
    }
    return x;
  }

  Temporada _cerrarEtapa(EstadoEpocas e, Temporada t) {
    final c = e.cruce!;
    final historial = [...e.historial, c];
    if (!c.ganado || e.etapa == decadas.length - 1) {
      return e.copyWith(historial: historial, sinCruce: true).en(t);
    }
    return e.copyWith(historial: historial, reclutando: true).en(t);
  }

  /// Cartas del rival vencido que podés reclutar (no repetidas en tu equipo).
  List<Jugador> reclutables(Temporada t) {
    final e = EstadoEpocas.de(t);
    final c = e.cruce;
    if (!e.reclutando || c == null) return const [];
    final propias = _personas(e.propio!);
    return [
      for (final id in c.rival.cartaIds.values)
        if (liga.jugador(id) case final j? when !propias.contains(j.idBbref)) j,
    ]..sort((a, b) => b.media.compareTo(a.media));
  }

  /// Puestos donde puede entrar [recluta] (reemplazando a quien esté).
  static List<Posicion> puestosPara(Jugador recluta) => [
    for (final p in Posicion.values)
      if (recluta.puedeJugarEn(p)) p,
  ];

  /// Reclutás a [cartaId] en el puesto [p] (o null: seguís sin cambios) y arranca la década que sigue.
  Temporada reclutar(Temporada t, {String? cartaId, Posicion? p}) {
    final e = EstadoEpocas.de(t);
    if (!e.reclutando) return t;
    var propio = e.propio!;
    var reclutas = e.reclutas;
    if (cartaId != null && p != null && reclutables(t).any((j) => j.id == cartaId)) {
      final j = liga.jugador(cartaId)!;
      if (j.puedeJugarEn(p)) {
        propio = _propioDe({...propio.cartaIds, p: cartaId}, propio.etiqueta);
        reclutas = [...reclutas, cartaId];
      }
    }
    final etapa = e.etapa + 1;
    final rival = campeonDeDecada(
      decadas[etapa],
      excluidos: _personas(propio),
      objetivo: objetivoEtapa(propio.media, etapa),
    );
    return e
        .copyWith(
          propio: propio,
          reclutas: reclutas,
          reclutando: false,
          etapa: etapa,
          equipos: [
            ...e.equipos,
            EquipoEpoca(clave: decadas[etapa].name, nombre: decadas[etapa].etiqueta, equipo: rival),
          ],
          cruce: _cruceGuantelete(etapa, rival),
        )
        .en(_conPlantel(t, propio));
  }
}

// ── Metajuego ──

/// Partidos ganados y perdidos entre dos estados, y si se completó el modo en este cambio.
(int, int, bool) progresoEpocas(Temporada antes, Temporada despues) {
  if (!ModosEpocas.esModo(despues.modoJuego)) return (0, 0, false);
  final a = EstadoEpocas.de(antes), d = EstadoEpocas.de(despues);
  final previos = a.todosLosMarcadores.length;
  final nuevos = d.todosLosMarcadores.skip(previos).toList();
  return (nuevos.where((m) => m.$1 > m.$2).length, nuevos.where((m) => m.$1 <= m.$2).length, d.campeon && !a.campeon);
}

/// Logros por completar cada modo.
List<Logro> logrosDeEpocas(Temporada antes, Temporada despues) {
  final (_, _, completo) = progresoEpocas(antes, despues);
  if (!completo) return const [];
  return [
    switch (despues.modoJuego) {
      ModoJuego.guantelete => Logro.guantelete,
      ModoJuego.camadas => Logro.camadas,
      _ => Logro.universidades,
    },
  ];
}

/// XP y monedas por partido ganado y un premio grande por completar el modo.
PerfilEntrenador premiarEpocas(PerfilEntrenador p, Temporada antes, Temporada despues, double mult) {
  final (ganados, _, completo) = progresoEpocas(antes, despues);
  if (ganados == 0 && !completo) return p;
  final xp = (ganados * 40 * mult).round() + (completo ? (400 * mult).round() : 0);
  final monedas = ganados * 10 + (completo ? 150 : 0);
  return p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
}
