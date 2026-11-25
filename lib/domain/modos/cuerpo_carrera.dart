import 'dart:math';

import '../entities/temporada.dart';
import 'carrera_jugador.dart';
import 'vida_carrera.dart';

/// Parte del cuerpo que se lastima: cambia cuánto dura y qué tan seguido vuelve.
enum ParteCuerpo {
  tobillo('Tobillo', 0.30, 0.9),
  rodilla('Rodilla', 0.15, 1.5),
  isquiotibiales('Isquiotibiales', 0.15, 1.1),
  espalda('Espalda', 0.10, 1.4),
  muneca('Muñeca', 0.10, 0.8),
  hombro('Hombro', 0.10, 1.2),
  pie('Pie', 0.10, 1.0);

  const ParteCuerpo(this.etiqueta, this.peso, this.duracion);
  final String etiqueta;

  /// Qué tan común es (suma 1).
  final double peso;

  /// Multiplicador de los partidos de baja.
  final double duracion;
}

/// Cómo encarás la recuperación de una lesión.
enum Rehab {
  cuidadosa('Cuidadosa', 'Volvés más tarde (+25 % de partidos) pero sano: sin riesgo de recaída.'),
  normal('Normal', 'El plazo que dicen los médicos.'),
  acelerada('Acelerada', 'Volvés antes (−40 % de partidos), pero hay 30 % de chance de recaer.');

  const Rehab(this.etiqueta, this.descripcion);
  final String etiqueta;
  final String descripcion;
}

/// Carga de partidos, lesiones por parte del cuerpo y rehabilitación de tu jugador.
///
/// Se guarda en [EstadoCarrera.uso]: `cu:carga` (0-100), `cu:activa` (parte+1 de la lesión actual),
/// `cu:dias` (partidos de baja originales), `cu:rehab` (0 sin elegir, 1-3 la rehabilitación),
/// `cu:p<i>` (veces que se lastimó esa parte) y `cu:total`.
class CuerpoCarrera {
  CuerpoCarrera._();

  /// Carga a partir de la cual se nota el cansancio acumulado.
  static const cargaCansada = 40;

  static int carga(EstadoCarrera e) => (e.uso['cu:carga'] ?? 0).clamp(0, 100);

  static int total(EstadoCarrera e) => e.uso['cu:total'] ?? 0;

  static int veces(EstadoCarrera e, ParteCuerpo p) => e.uso['cu:p${p.index}'] ?? 0;

  /// Parte lastimada ahora, o null.
  static ParteCuerpo? activa(EstadoCarrera e) {
    final n = e.uso['cu:activa'] ?? 0;
    return n <= 0 || n > ParteCuerpo.values.length ? null : ParteCuerpo.values[n - 1];
  }

  static Rehab? rehabElegida(EstadoCarrera e) {
    final n = e.uso['cu:rehab'] ?? 0;
    return n <= 0 || n > Rehab.values.length ? null : Rehab.values[n - 1];
  }

  /// Partes que ya se lastimaron 3 veces o más: molestias crónicas.
  static List<ParteCuerpo> cronicas(EstadoCarrera e) => [
    for (final p in ParteCuerpo.values)
      if (veces(e, p) >= 3) p,
  ];

  /// Multiplicador de la chance de lesionarse en cada partido: rutina, durabilidad y personalidad,
  /// más el cansancio acumulado (hasta ×1,8) y el historial (+5 % por lesión, hasta ×1,3).
  static double factor(EstadoCarrera e) {
    final cansancio = carga(e) <= cargaCansada ? 1.0 : 1 + (carga(e) - cargaCansada) / 60 * 0.8;
    final historial = (1 + total(e) * 0.05).clamp(1.0, 1.3).toDouble();
    return VidaCarrera.factorLesion(e) * cansancio * historial * EconomiaCarrera.factorFisio(e);
  }

  /// Sube la carga con los minutos jugados y la baja con el descanso. Sin jugar, se recupera más.
  static int nuevaCarga(int actual, double segundos, {double extra = 0}) {
    final minutos = segundos / 60;
    final delta = (minutos <= 0 ? -12 : minutos / 6 - 5.5) - extra;
    return (actual + delta).round().clamp(0, 100);
  }

  /// Actualiza tu estado de salud tras cada partido de tu equipo ([seg]: lo que jugaste).
  /// Detecta si te lesionaste (aparece en [Temporada.lesiones]) y le pone parte y duración,
  /// o si ya te recuperaste (y entonces cierra la rehabilitación, con su posible recaída).
  static (Temporada, EstadoCarrera) alPartido(Temporada t, EstadoCarrera e, double seg, int numeroPartido) {
    var uso = {...e.uso, 'cu:carga': nuevaCarga(carga(e), seg, extra: EconomiaCarrera.cargaExtra(e))};
    var ne = e.copyWith(uso: uso);
    var tt = t;
    final baja = t.lesiones[e.jugadorId];
    final hay = activa(e) != null;
    if (baja != null && !hay) {
      // Lesión nueva: parte y gravedad.
      final azar = Random(_hash('${e.raiz}-cuerpo-${e.numero}-$numeroPartido'));
      var r = azar.nextDouble();
      var parte = ParteCuerpo.values.last;
      for (final p in ParteCuerpo.values) {
        // Las partes lastimadas antes se repiten más.
        final peso = p.peso * (1 + veces(e, p) * 0.35);
        r -= peso / _sumaPesos(e);
        if (r <= 0) {
          parte = p;
          break;
        }
      }
      final repetida = (1 + veces(e, parte) * 0.15).clamp(1.0, 1.5).toDouble();
      final dias = max(1, (baja * parte.duracion * repetida).round());
      tt = t.copyWith(lesiones: {...t.lesiones, e.jugadorId: dias});
      uso = {
        ...ne.uso,
        'cu:activa': parte.index + 1,
        'cu:dias': dias,
        'cu:rehab': 0,
        'cu:p${parte.index}': veces(e, parte) + 1,
        'cu:total': total(e) + 1,
      };
      final grave = dias >= 11;
      final texto = '${ne.etiquetaTemporada}: lesión de ${parte.etiqueta.toLowerCase()}, $dias partidos de baja.';
      ne = ne.copyWith(uso: uso, movimientos: [...ne.movimientos, texto], hitos: grave ? [...ne.hitos, texto] : null);
    } else if (baja == null && hay) {
      // Ya volvió: ¿recayó por apurarse?
      final parte = activa(e)!;
      final azar = Random(_hash('${e.raiz}-recaida-${e.numero}-$numeroPartido'));
      final recae = rehabElegida(e) == Rehab.acelerada && azar.nextDouble() < 0.3;
      uso = {...ne.uso}
        ..remove('cu:activa')
        ..remove('cu:dias')
        ..['cu:rehab'] = 0;
      if (recae) {
        final dias = 2 + azar.nextInt(5);
        tt = t.copyWith(lesiones: {...t.lesiones, e.jugadorId: dias});
        uso['cu:activa'] = parte.index + 1;
        uso['cu:dias'] = dias;
        uso['cu:rehab'] = Rehab.normal.index + 1;
        uso['cu:p${parte.index}'] = veces(e, parte) + 1;
        ne = ne.copyWith(
          uso: uso,
          movimientos: [
            ...ne.movimientos,
            '${ne.etiquetaTemporada}: recaíste de la ${parte.etiqueta.toLowerCase()} por volver apurado.',
          ],
        );
      } else {
        ne = ne.copyWith(uso: uso);
      }
    } else {
      ne = ne.copyWith(uso: uso);
    }
    return (tt, ne);
  }

  static double _sumaPesos(EstadoCarrera e) =>
      ParteCuerpo.values.fold(0.0, (a, p) => a + p.peso * (1 + veces(e, p) * 0.35));

  /// Elige cómo recuperarte: cambia los partidos de baja que te quedan.
  static (Temporada, EstadoCarrera) elegirRehab(Temporada t, EstadoCarrera e, Rehab r) {
    final quedan = t.lesiones[e.jugadorId];
    if (quedan == null || activa(e) == null || rehabElegida(e) != null) return (t, e);
    final factor = switch (r) {
      Rehab.cuidadosa => 1.25,
      Rehab.normal => 1.0,
      Rehab.acelerada => 0.6,
    };
    final nuevo = max(1, (quedan * factor).round());
    return (
      t.copyWith(lesiones: {...t.lesiones, e.jugadorId: nuevo}),
      e.copyWith(uso: {...e.uso, 'cu:rehab': r.index + 1}),
    );
  }

  /// Un partido de descanso por decisión propia: no jugás (queda como baja de 1 partido) y la carga baja a la mitad.
  static bool puedeDescansar(Temporada t, EstadoCarrera e) =>
      !e.retirado && !t.lesiones.containsKey(e.jugadorId) && carga(e) >= cargaCansada;

  static (Temporada, EstadoCarrera) descansar(Temporada t, EstadoCarrera e) {
    if (!puedeDescansar(t, e)) return (t, e);
    return (
      t.copyWith(lesiones: {...t.lesiones, e.jugadorId: 1}),
      e.copyWith(uso: {...e.uso, 'cu:carga': carga(e) ~/ 2, 'cu:desc': (e.uso['cu:desc'] ?? 0) + 1}),
    );
  }

  static int _hash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);
}
