import 'dart:math';

import 'draft.dart';
import 'entities/franquicia.dart';
import 'entities/jugador.dart';
import 'entities/modo_juego.dart';
import 'entities/oferta.dart';
import 'entities/perfil.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/rival.dart';
import 'entities/temporada.dart';
import 'liga.dart';
import 'playbook.dart';
import 'progreso.dart';

/// Reglas de las variantes de la temporada clásica (Leyenda única, Extremo, Solo entrenador,
/// Modo espejo y Desafío del día): cómo se arma el plantel, qué cambia en la liga y qué se gana.
class Variantes {
  Variantes(this.catalogo, {Random? azar}) : _azar = azar ?? Random();

  final List<Jugador> catalogo;
  final Random _azar;

  late final Map<String, Jugador> _porId = {for (final j in catalogo) j.id: j};

  /// Media a la que apuntan los planteles al azar: un poco arriba de los rivales de cada dificultad
  /// (como un draft típico), para que se pueda competir sin regalar nada.
  static int objetivo(Dificultad d) => switch (d) {
    Dificultad.normal => 84,
    Dificultad.dificil => 86,
    Dificultad.leyenda => 90,
  };

  // ── Armado al azar (Solo entrenador y el resto de Leyenda única) ──

  /// Completa los puestos vacíos al azar con cartas de media cercana a [objetivo] (±3; si no
  /// alcanza, se abre el margen). Primero los puestos con menos candidatos.
  Plantel completarAlAzar(Plantel inicial, int objetivo) {
    var plantel = inicial;
    final vacios = [
      for (final p in Posicion.titulares)
        if (!plantel.estaOcupada(p)) p,
    ]..sort((a, b) => _candidatos(plantel, a).length.compareTo(_candidatos(plantel, b).length));
    for (final p in [...vacios, if (!plantel.estaOcupada(Posicion.sextoHombre)) Posicion.sextoHombre]) {
      final todos = _candidatos(plantel, p);
      if (todos.isEmpty) throw StateError('No hay cartas para ${p.etiqueta}.');
      List<Jugador> cerca = const [];
      for (var margen = 3; cerca.isEmpty; margen += 2) {
        cerca = todos.where((j) => (j.media - objetivo).abs() <= margen).toList();
      }
      plantel = plantel.asignar(cerca[_azar.nextInt(cerca.length)], p);
    }
    return plantel;
  }

  List<Jugador> _candidatos(Plantel plantel, Posicion p) => [
    for (final j in catalogo)
      if (plantel.posicionesDisponiblesPara(j).contains(p)) j,
  ];

  /// Plantel completo al azar para Solo entrenador.
  Plantel alAzar(Dificultad d) => completarAlAzar(const Plantel(), objetivo(d));

  // ── Leyenda única ──

  /// Figuras para elegir: 2 GOAT (S+) y el resto leyendas (S), sin repetir persona.
  List<Jugador> leyendasParaElegir({int cantidad = 6}) {
    final vistos = <int>{};
    List<Jugador> de(Tier tier, int n) {
      final pool = catalogo.where((j) => j.tier == tier).toList()..shuffle(_azar);
      final elegidas = <Jugador>[];
      for (final j in pool) {
        if (elegidas.length == n) break;
        if (vistos.add(j.nbaPlayerId)) elegidas.add(j);
      }
      return elegidas;
    }

    return [...de(Tier.sPlus, 2), ...de(Tier.s, cantidad - 2)];
  }

  /// La figura en su mejor puesto titular y el resto al azar, un escalón abajo del objetivo (la
  /// leyenda ya suma por su cuenta).
  Plantel conLeyenda(Jugador leyenda, Dificultad d) {
    final puestos = const Plantel().posicionesDisponiblesPara(leyenda);
    final puesto = puestos.firstWhere((p) => p != Posicion.sextoHombre, orElse: () => puestos.first);
    return completarAlAzar(const Plantel().asignar(leyenda, puesto), objetivo(d) - 2);
  }

  // ── Modo espejo ──

  static const clavePasadas = 'pasadas';
  static const claveEspejado = 'espejado';
  static const claveTuyo = 'tuyo';
  static const claveRivalEspejo = 'rivalEspejo';

  /// Cartas que te ofrecieron y dejaste pasar (las que usa la IA para armar su plantel).
  static List<String> pasadas(Temporada t) => [...(t.datosModo[clavePasadas] as List? ?? const []).cast<String>()];

  /// Si entre [antes] y [despues] fichaste una carta, suma a [pasadas] las que salieron con ella y
  /// no elegiste (los candidatos de la tirada o las cartas del sobre).
  static List<String> registrarPasadas(Draft draft, Temporada antes, Temporada despues, List<String> pasadas) {
    if (despues.plantel.jugadores.length <= antes.plantel.jugadores.length) return pasadas;
    final propias = {for (final j in despues.plantel.jugadores) j.id};
    final ofrecidas = antes.tirada != null ? draft.candidatos(antes) : draft.cartasDeOferta(antes);
    final nuevas = [
      for (final j in ofrecidas)
        if (!propias.contains(j.id) && !pasadas.contains(j.id)) j.id,
    ];
    return [...pasadas, ...nuevas];
  }

  /// Plantel que arma la IA con lo que dejaste pasar: por puesto, la mejor carta que entra (sin
  /// repetir a nadie de tu plantel). Si algún puesto no se llena, se completa al nivel del resto.
  Plantel plantelEspejo(List<String> pasadas, Plantel tuyo) {
    final pool = [
      for (final id in pasadas)
        if (_porId[id] case final j? when !tuyo.contiene(j)) j,
    ]..sort((a, b) => b.media.compareTo(a.media));
    var plantel = const Plantel();
    final puestos = [...Posicion.titulares]
      ..sort(
        (a, b) => pool.where((j) => j.puedeJugarEn(a)).length.compareTo(pool.where((j) => j.puedeJugarEn(b)).length),
      );
    for (final p in [...puestos, Posicion.sextoHombre]) {
      final j = pool.where((j) => plantel.posicionesDisponiblesPara(j).contains(p)).firstOrNull;
      if (j != null) plantel = plantel.asignar(j, p);
    }
    if (plantel.completo) return plantel;
    final js = plantel.jugadores.isEmpty ? tuyo.jugadores : plantel.jugadores;
    final media = js.fold(0, (a, j) => a + j.media) ~/ js.length;
    // Que no aparezca nadie de tu plantel en el de la IA.
    final sinTuyos = Variantes(catalogo.where((j) => !tuyo.contiene(j)).toList(), azar: _azar);
    return sinTuyos.completarAlAzar(plantel, media);
  }

  /// Cambia de plantel: jugás con el de la IA y el tuyo queda guardado para ser un rival.
  Temporada espejar(Temporada t) {
    if (t.datosModo[claveEspejado] == true) return t;
    final ia = plantelEspejo(pasadas(t), t.plantel);
    return t.copyWith(
      plantel: ia,
      datosModo: {
        ...t.datosModo,
        claveEspejado: true,
        claveTuyo: {for (final p in Posicion.values) p.name: t.plantel.en(p)!.id},
      },
    );
  }

  /// Tu plantel del draft (guardado al espejar).
  Plantel? plantelTuyo(Temporada t) {
    final ids = t.datosModo[claveTuyo] as Map<String, dynamic>?;
    if (ids == null) return null;
    var p = const Plantel();
    for (final e in ids.entries) {
      final puesto = Posicion.values.byName(e.key);
      p = p.asignar(cartaOReemplazo(_porId, catalogo, e.value as String, puesto, p), puesto);
    }
    return p;
  }

  // ── Desafío del día ──

  /// 20261113 para el 13/11/2026.
  static int semilla(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static String idDelDia(DateTime d) => 'dia-${semilla(d)}';

  /// La franquicia del día (la misma para todos).
  static Franquicia franquiciaDelDia(DateTime d, List<Franquicia> franquicias) {
    final actuales = [...franquicias]..sort((a, b) => a.id.compareTo(b.id));
    return actuales[Random(semilla(d)).nextInt(actuales.length)];
  }

  /// Días pares de la semilla, ruleta; impares, cartas.
  static ModoDraft modoDelDia(DateTime d) => semilla(d).isEven ? ModoDraft.ruleta : ModoDraft.cartas;

  /// Semilla del azar de la partida: la fecha y, en el Desafío del día, la versión del catálogo con
  /// que se creó. Así el día es el mismo para todos los que tienen las mismas cartas, y una
  /// actualización a mitad del día no mezcla tiradas de dos catálogos (la partida sigue con su
  /// versión sellada; una partida nueva del día siguiente toma la nueva). Sin versión (partidas
  /// viejas), solo la fecha, como antes.
  static int? semillaDeAzar(Temporada t) {
    final base = t.datosModo['semilla'] as int?;
    if (base == null || t.modoJuego != ModoJuego.desafioDelDia || t.versionCatalogo == null) return base;
    return base ^ (t.versionCatalogo! & 0xffff);
  }

  /// Azar del draft del día, estable para cada elección (abrir y cerrar la app no cambia lo que sale).
  static Random azarDraftDelDia(Temporada t) =>
      Random((semillaDeAzar(t) ?? 0) * 31 + t.plantel.jugadores.length * 7919 + t.rerollsRestantes);

  // ── Extremo ──

  /// En Extremo no hay segunda vuelta: si quedás afuera (o no clasificás), la partida está perdida.
  static bool extremoPerdido(Temporada t) {
    if (t.modoJuego != ModoJuego.extremo) return false;
    if (t.eliminacion != null) return true;
    final u = t.franquiciaUsuarioId;
    final sinLugar = t.series.isNotEmpty && !t.series.any((s) => s.altoId == u || s.bajoId == u);
    return sinLugar || (t.fase == FaseTemporada.finalizada && t.campeonId != u);
  }

  // ── Inicio de la temporada (después de las tácticas) ──

  /// Calendario y rivales. Desafío del día: con la semilla del día (los mismos rivales para todos).
  /// Espejo: tu plantel del draft reemplaza a un rival de tu conferencia.
  Temporada iniciar(Liga liga, Temporada t) {
    if (t.calendario.isNotEmpty) return t;
    final tuyo = plantelTuyo(t);
    final excluidos = {for (final j in tuyo?.jugadores ?? const <Jugador>[]) j.nbaPlayerId};
    final semilla = semillaDeAzar(t);
    final motor = semilla == null ? liga : Liga(liga.catalogo, liga.franquicias, azar: Random(semilla));
    var nueva = motor.iniciar(t, excluidos: excluidos);
    if (t.modoJuego == ModoJuego.espejo && tuyo != null) {
      final conferencia = franquiciaPorIdEn(liga.franquicias, t.franquiciaUsuarioId).conferencia;
      final opciones = [
        for (final f in liga.franquicias)
          if (f.id != t.franquiciaUsuarioId && f.conferencia == conferencia) f.id,
      ]..sort();
      final elegido = opciones[_azar.nextInt(opciones.length)];
      nueva = nueva.copyWith(
        rivales: {
          ...nueva.rivales,
          elegido: Rival(
            franquiciaId: elegido,
            tipo: TipoRival.historico,
            identidadId: elegido,
            cartaIds: {for (final p in Posicion.values) p: tuyo.en(p)!.id},
            tactica: recomendar(PerfilPlantel.de(tuyo)).tactica,
          ),
        },
        datosModo: {...nueva.datosModo, claveRivalEspejo: elegido},
      );
    }
    return nueva;
  }

  static Franquicia franquiciaPorIdEn(List<Franquicia> fs, String id) => fs.firstWhere((f) => f.id == id);
}

// ── Metajuego de las variantes ──

/// Logros de las variantes que [despues] acaba de ganar.
List<Logro> logrosDeVariante(Temporada antes, Temporada despues) {
  final u = despues.franquiciaUsuarioId;
  final campeon = despues.campeonId == u && antes.campeonId != u;
  return [
    if (campeon)
      ?switch (despues.modoJuego) {
        ModoJuego.extremo => Logro.campeonExtremo,
        ModoJuego.soloEntrenador => Logro.campeonSoloEntrenador,
        ModoJuego.leyendaUnica => Logro.campeonLeyendaUnica,
        ModoJuego.espejo => Logro.campeonEspejo,
        _ => null,
      },
    if (despues.modoJuego == ModoJuego.desafioDelDia && despues.registroUsuario.victorias >= 50) Logro.desafioCumplido,
  ];
}

/// Premios propios: el puntaje del Desafío del día y el bonus por ganar en Extremo.
PerfilEntrenador premiarVariante(PerfilEntrenador p, Temporada antes, Temporada despues, List<Novedad> novedades) {
  if (despues.modoJuego == ModoJuego.desafioDelDia) {
    final fecha = despues.datosModo['semilla'] as int?;
    final v = despues.registroUsuario.victorias;
    if (fecha != null && v > (p.desafiosDelDia['$fecha'] ?? -1)) {
      p = p.copyWith(desafiosDelDia: {...p.desafiosDelDia, '$fecha': v});
    }
  }
  final u = despues.franquiciaUsuarioId;
  if (despues.modoJuego == ModoJuego.extremo && despues.campeonId == u && antes.campeonId != u) {
    novedades.add(const Novedad('Bonus Extremo', detalle: '+1000 XP · +400 monedas', destacada: true));
    p = p.copyWith(xp: p.xp + 1000, monedas: p.monedas + 400);
  }
  return p;
}
