import 'dart:math';

import '../efecto_en_vivo.dart';
import '../entities/jugador.dart';
import '../modificadores.dart';
import 'carrera_jugador.dart';

// El mundo alrededor de tu jugador: la química que se arma con los compañeros a fuerza de jugar juntos y los rivales
// que te estudian (y se adaptan a lo que más hacés). Los dos entran al motor como ajustes del partido.

/// Qué tan bien se conocen tu jugador y un compañero.
enum NivelQuimica {
  ninguna('Recién se conocen'),
  bronce('Bronce'),
  plata('Plata'),
  oro('Oro');

  const NivelQuimica(this.etiqueta);
  final String etiqueta;

  static NivelQuimica deMinutos(int partidos) => partidos >= 150
      ? oro
      : partidos >= 60
      ? plata
      : partidos >= 20
      ? bronce
      : ninguna;
}

class QuimicaCarrera {
  const QuimicaCarrera._();

  static int partidosCon(EstadoCarrera e, Jugador j) => e.uso['qm:${j.id}'] ?? 0;

  static NivelQuimica nivelCon(EstadoCarrera e, Jugador j) => NivelQuimica.deMinutos(partidosCon(e, j));

  /// Suma de niveles (0 a 3 por compañero) de quienes están hoy en tu plantel.
  static int puntos(EstadoCarrera e) => e.companeros.fold(0, (a, j) => a + nivelCon(e, j).index);

  /// Lo que suma al equipo: más acierto en los tiros asistidos y algo de química general. Con tope.
  static ModificadoresEquipo mods(EstadoCarrera e) {
    final p = puntos(e);
    return ModificadoresEquipo(asistidoExtra: min(0.012, 0.002 * p), quimicaExtra: min(0.006, 0.001 * p));
  }

  /// Cuenta un partido más con cada compañero que jugó (ids de las cartas que sumaron minutos).
  static Map<String, int> alPartido(EstadoCarrera e, Iterable<String> jugaron) {
    final uso = {...e.uso};
    final ids = {for (final j in e.companeros) j.id};
    for (final id in jugaron) {
      if (ids.contains(id)) uso['qm:$id'] = (uso['qm:$id'] ?? 0) + 1;
    }
    return uso;
  }
}

/// Los rivales te estudian: cuanto más jugás, más se preparan contra lo que más hacés. Un juego balanceado casi no se
/// puede marcar; uno de solo triples (o de solo aro) sí.
class AdaptacionRival {
  const AdaptacionRival._();

  /// Partidos para que los rivales te conozcan del todo.
  static const partidosParaConocerte = 150;

  /// 0 (nadie te conoce) a 1 (todos te tienen estudiado).
  static double aprendizaje(EstadoCarrera e) => ((e.uso['c:pj'] ?? 0) / partidosParaConocerte).clamp(0.0, 1.0);

  /// Qué parte de tus puntos viene de triples (0 a 1; 0,3 es un perfil normal).
  static double parteDeTriples(EstadoCarrera e) {
    final pts = e.uso['c:pts'] ?? 0;
    return pts <= 0 ? 0.3 : ((3 * (e.uso['c:t3'] ?? 0)) / pts).clamp(0.0, 1.0);
  }

  /// Cuánto te cierran el triple y la pintura (0 a 1 cada uno).
  static (double, double) cierres(EstadoCarrera e) {
    final a = aprendizaje(e), s3 = parteDeTriples(e);
    final triple = a * ((s3 - 0.30) / 0.30).clamp(0.0, 1.0);
    final aro = a * ((0.20 - s3) / 0.20).clamp(0.0, 1.0);
    return (triple, aro);
  }

  /// El ajuste de la defensa rival (null si todavía no se prepararon contra vos).
  static EfectoEnVivo? efecto(EstadoCarrera e) {
    final (t, a) = cierres(e);
    if (t < 0.02 && a < 0.02) return null;
    return EfectoEnVivo(tripleRival: 1 - 0.07 * t, interiorRival: 1 - 0.06 * a);
  }

  /// El informe de scouting de los rivales sobre vos, en voseo.
  static List<String> informe(EstadoCarrera e) {
    final a = aprendizaje(e);
    final (t, aro) = cierres(e);
    final s3 = (parteDeTriples(e) * 100).round();
    if (a < 0.1) return ['Todavía casi no te conocen: es tu momento. Cuanto más juegues, más se van a preparar.'];
    final lineas = <String>[
      'Los rivales ya te estudiaron un ${(a * 100).round()} %. Tu juego: $s3 % de tus puntos son de triples.',
    ];
    if (t >= 0.05) lineas.add('Te cierran el triple: el acierto de tu equipo de tres baja un ${(7 * t).toStringAsFixed(1).replaceAll('.', ',')} %.');
    if (aro >= 0.05) lineas.add('Te cierran la pintura: el acierto de tu equipo adentro baja un ${(6 * aro).toStringAsFixed(1).replaceAll('.', ',')} %.');
    if (t < 0.05 && aro < 0.05) {
      lineas.add('Tu juego está equilibrado: no tienen una forma clara de marcarte.');
    } else {
      lineas.add('Para que se adapten menos: sumá variedad (más tiros de media distancia, pases, otras zonas).');
    }
    return lineas;
  }
}

/// Tus números más finos de carrera (se llevan desde que existe el seguimiento por partido).
class AvanzadasCarrera {
  const AvanzadasCarrera({
    required this.pj,
    required this.ts,
    required this.efg,
    required this.pctTc,
    required this.pctT3,
    required this.pctTl,
    required this.astPorPerdida,
    required this.valoracion,
    required this.minutos,
    required this.puntosPor36,
  });

  final int pj;

  /// Acierto real (cuenta triples y libres), acierto efectivo de campo y porcentajes de tiro.
  final double ts, efg, pctTc, pctT3, pctTl;

  /// Asistencias por pérdida y valoración por partido (fórmula de Hollinger con los rebotes a 0,5).
  final double astPorPerdida, valoracion;
  final double minutos, puntosPor36;

  static AvanzadasCarrera? de(EstadoCarrera e) {
    final u = e.uso;
    final pj = u['c:pj'] ?? 0, tcA = u['c:tcA'] ?? 0;
    if (pj == 0 || tcA == 0) return null;
    double d(String k) => (u[k] ?? 0).toDouble();
    final pts = d('c:pts'), tcI = d('c:tcI'), t3 = d('c:t3'), t3A = d('c:t3A'), tlI = d('c:tlI'), tlA = d('c:tlA');
    final seg = d('c:seg');
    final valoracion =
        (pts + 0.4 * tcI - 0.7 * tcA - 0.4 * (tlA - tlI) + 0.5 * d('c:reb') + d('c:rob') + 0.7 * d('c:ast') + 0.7 * d('c:tap') - 0.4 * d('c:fal') - d('c:per')) /
        pj;
    return AvanzadasCarrera(
      pj: pj,
      ts: pts / (2 * (tcA + 0.44 * tlA)),
      efg: (tcI + 0.5 * t3) / tcA,
      pctTc: tcI / tcA,
      pctT3: t3A == 0 ? 0 : t3 / t3A,
      pctTl: tlA == 0 ? 0 : tlI / tlA,
      astPorPerdida: d('c:per') == 0 ? d('c:ast') : d('c:ast') / d('c:per'),
      valoracion: valoracion,
      minutos: seg / 60 / pj,
      puntosPor36: seg <= 0 ? 0 : pts / seg * 36 * 60,
    );
  }
}

/// Categorías de la bandeja de entrada.
enum CategoriaMensaje {
  premios('Premios'),
  objetivos('Objetivos'),
  plantel('Plantel'),
  mercado('Mercado'),
  general('Otros');

  const CategoriaMensaje(this.etiqueta);
  final String etiqueta;
}

class MensajeBandeja {
  const MensajeBandeja(this.texto, this.categoria, this.temporada);

  final String texto;
  final CategoriaMensaje categoria;

  /// Número de temporada de la carrera (0: el arranque).
  final int temporada;
}

/// La bandeja de entrada: todo lo que te pasó (premios, objetivos, plantel, mercado) en un solo lugar, de lo más
/// nuevo a lo más viejo. Se arma con la historia y los movimientos de tu carrera (no guarda nada propio).
class BandejaCarrera {
  const BandejaCarrera._();

  static CategoriaMensaje categoriaDe(String t) {
    final x = t.toLowerCase();
    if (x.contains('objetivo')) return CategoriaMensaje.objetivos;
    if (x.contains('jugador del mes') || x.contains('novato') || x.contains('mvp') || x.contains('all-') || x.contains('líder de la liga') || x.contains('campeón')) {
      return CategoriaMensaje.premios;
    }
    if (x.contains('rumor') || x.contains('fecha límite') && x.contains('traspaso') && !x.contains('es traspasado') || x.contains('firma ') || x.contains('renueva') || x.contains('pide el traspaso') || x.contains('extiende')) {
      return CategoriaMensaje.mercado;
    }
    if (x.contains('se retira') || x.contains('traspasado') || x.contains('llega ') || x.contains('termina contrato') || x.contains('nuevo equipo') || x.contains('se queda')) {
      return CategoriaMensaje.plantel;
    }
    return CategoriaMensaje.general;
  }

  static List<MensajeBandeja> mensajes(EstadoCarrera e) {
    int temporadaDe(String t) {
      for (var n = e.numero + 1; n >= 1; n--) {
        if (t.startsWith(e.etiquetaDe(n))) return n;
      }
      return 0;
    }

    final todos = <MensajeBandeja>[
      for (final t in {...e.hitos, ...e.movimientos}) MensajeBandeja(t, categoriaDe(t), temporadaDe(t)),
    ];
    // Estable: dentro de una temporada se conserva el orden en que pasó; después se da vuelta (lo nuevo arriba).
    final ordenados = [for (var i = 0; i < todos.length; i++) (i, todos[i])]
      ..sort((a, b) => a.$2.temporada != b.$2.temporada ? a.$2.temporada.compareTo(b.$2.temporada) : a.$1.compareTo(b.$1));
    return [for (final x in ordenados.reversed) x.$2];
  }

  static int sinLeer(EstadoCarrera e) => max(0, mensajes(e).length - (e.uso['bd:leidos'] ?? 0));

  static EstadoCarrera marcarLeidos(EstadoCarrera e) => e.copyWith(uso: {...e.uso, 'bd:leidos': mensajes(e).length});
}
