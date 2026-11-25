import 'dart:math';

import 'carrera_jugador.dart';
import 'vida_carrera.dart';

/// Tu equipo personal: cada uno tiene 3 niveles y cuesta dinero cada temporada.
enum Personal {
  entrenador('Entrenador personal', 'Cada nivel suma 1 punto de habilidad por temporada.', 3.0),
  fisio('Fisioterapeuta', 'Cada nivel reduce 10 % la chance de lesionarte.', 2.0),
  nutricionista('Nutricionista', 'Cada nivel recupera más carga de partidos (menos cansancio).', 1.5),
  agente('Agente', 'Cada nivel mejora 5 % tu sueldo, te trae ofertas extra de otros equipos y se queda con 3 % de comisión.', 0);

  const Personal(this.etiqueta, this.descripcion, this.costoPorNivel);
  final String etiqueta, descripcion;

  /// Millones por temporada y por nivel (el agente cobra comisión, no tarifa).
  final double costoPorNivel;
}

/// Cuánto cobra tu jugador y en qué lo gasta: sueldo, patrocinios, equipo personal y caja (millones de dólares).
/// Se guarda en [EstadoCarrera.uso]: `ec:caja` y `ec:total` en décimas de millón, `ec:n<i>` nivel de cada [Personal].
class EconomiaCarrera {
  EconomiaCarrera._();

  static const nivelMaximo = 3;

  static double caja(EstadoCarrera e) => (e.uso['ec:caja'] ?? 0) / 10;
  static double ganadoEnTotal(EstadoCarrera e) => (e.uso['ec:total'] ?? 0) / 10;
  static int nivel(EstadoCarrera e, Personal p) => (e.uso['ec:n${p.index}'] ?? 0).clamp(0, nivelMaximo);

  /// Sueldo anual antes de la comisión: escala de novato según el pick, después según tu media.
  static double sueldoBase(EstadoCarrera e) {
    final novato = e.numero <= CarreraJugador.contratoNovato(e.pick);
    if (novato) return max(1.5, 11 - e.pick * 0.28);
    return max(2.0, 4 + (e.media - 68) * 1.7);
  }

  static double sueldo(EstadoCarrera e) => sueldoBase(e) * (1 + 0.05 * nivel(e, Personal.agente));

  static double comision(EstadoCarrera e) => sueldo(e) * 0.03 * nivel(e, Personal.agente);

  /// Lo que entra por marcas: patrocinios y fama.
  static double patrocinios(EstadoCarrera e) => VidaCarrera.patrocinios(e).length * 1.2 + e.fans / 100 * 3;

  /// Costo anual del equipo personal (sin la comisión del agente).
  static double costoStaff(EstadoCarrera e) => [for (final p in Personal.values) p.costoPorNivel * nivel(e, p)].fold(0.0, (a, b) => a + b);

  /// Balance de una temporada.
  static double balanceAnual(EstadoCarrera e) => sueldo(e) - comision(e) + patrocinios(e) - costoStaff(e);

  static int puntosEntrenador(EstadoCarrera e) => nivel(e, Personal.entrenador);
  static double factorFisio(EstadoCarrera e) => 1 - 0.1 * nivel(e, Personal.fisio);
  static double cargaExtra(EstadoCarrera e) => 0.5 * nivel(e, Personal.nutricionista);
  static int ofertasExtra(EstadoCarrera e) => (nivel(e, Personal.agente) + 1) ~/ 2;

  /// Cuánto cuesta contratar o subir de nivel a [p] (un año por adelantado); null si ya está al máximo.
  static double? costoDeSubir(EstadoCarrera e, Personal p) {
    if (nivel(e, p) >= nivelMaximo) return null;
    return p == Personal.agente ? 2.0 * (nivel(e, p) + 1) : p.costoPorNivel;
  }

  static bool puedeSubir(EstadoCarrera e, Personal p) {
    final costo = costoDeSubir(e, p);
    return costo != null && caja(e) >= costo && !e.retirado;
  }

  static EstadoCarrera subir(EstadoCarrera e, Personal p) {
    if (!puedeSubir(e, p)) return e;
    final costo = costoDeSubir(e, p)!;
    return e.copyWith(uso: {...e.uso, 'ec:caja': (e.uso['ec:caja'] ?? 0) - (costo * 10).round(), 'ec:n${p.index}': nivel(e, p) + 1});
  }

  static EstadoCarrera bajar(EstadoCarrera e, Personal p) =>
      nivel(e, p) == 0 ? e : e.copyWith(uso: {...e.uso, 'ec:n${p.index}': nivel(e, p) - 1});

  /// Cierra el año: cobra sueldo y marcas, paga el equipo personal y suma los puntos del entrenador.
  /// Si no alcanza la caja, el personal más caro se va (baja un nivel cada vez).
  static EstadoCarrera alCerrar(EstadoCarrera e) {
    final ingreso = sueldo(e) - comision(e) + patrocinios(e);
    var ne = e;
    var caja10 = (e.uso['ec:caja'] ?? 0) + (ingreso * 10).round();
    final avisos = <String>[];
    while (caja10 < (costoStaff(ne) * 10).round()) {
      final p = Personal.values.where((x) => x != Personal.agente && nivel(ne, x) > 0).fold<Personal?>(null, (m, x) => m == null || x.costoPorNivel > m.costoPorNivel ? x : m);
      if (p == null) break;
      ne = bajar(ne, p);
      avisos.add('Sin plata para pagarlo, bajaste a tu ${p.etiqueta.toLowerCase()} un nivel.');
    }
    caja10 -= (costoStaff(ne) * 10).round();
    final total = (e.uso['ec:total'] ?? 0) + (ingreso * 10).round();
    final texto = '${e.etiquetaTemporada}: cobraste ${sueldo(e).toStringAsFixed(1).replaceAll('.', ',')} M de sueldo y ${patrocinios(e).toStringAsFixed(1).replaceAll('.', ',')} M de marcas.';
    return ne.copyWith(
      uso: {...ne.uso, 'ec:caja': caja10, 'ec:total': total},
      phBanco: ne.phBanco + puntosEntrenador(ne),
      movimientos: [...ne.movimientos, texto, ...avisos.map((a) => '${e.etiquetaTemporada}: $a')],
    );
  }
}
