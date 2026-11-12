import 'dart:math';

import 'entities/jugador.dart';
import 'entities/plantel.dart';
import 'entities/posicion.dart';
import 'entities/rol_cancha.dart';
import 'entities/tactica.dart';

/// Escala lineal a 0–1 entre [desde] y [hasta].
double _norma(double v, double desde, double hasta) => ((v - desde) / (hasta - desde)).clamp(0.0, 1.0);

/// Rasgos del plantel (0–1) y el jugador que más aporta a cada uno.
class PerfilPlantel {
  PerfilPlantel._(this.valores, this.figuras);

  final Map<Rasgo, double> valores;
  final Map<Rasgo, Jugador> figuras;

  static const _pesoSexto = 0.6;
  static const _interiores = {Posicion.alaPivot, Posicion.pivot};
  static const _exteriores = {Posicion.base, Posicion.escolta, Posicion.alero};
  static const _rolesTransicion = {
    RolCancha.penetradorAtletico,
    RolCancha.aleroCortador,
    RolCancha.controladorTotal,
    RolCancha.inyeccionEnergia,
  };
  static const _rolesDefensivos = {
    RolCancha.baseDefensivo,
    RolCancha.cerrojoDefensivo,
    RolCancha.especialista3D,
    RolCancha.inyeccionEnergia,
  };

  /// Aporte individual de [j] a cada rasgo (0–1).
  static double aporte(Rasgo r, Jugador j) {
    final s = j.stats;
    final interior = _interiores.contains(j.posiciones.first);
    return switch (r) {
      Rasgo.triple => _norma(s.pctT3, 0.28, 0.42),
      Rasgo.creacion => _norma(s.app, 1, 9),
      Rasgo.poste => interior ? 0.6 * _norma(s.ppp, 10, 28) + 0.4 * _norma(s.pctTc, 0.45, 0.58) : 0,
      Rasgo.transicion => 0.6 * _norma(s.robP, 0.5, 2.2) + (_rolesTransicion.contains(j.rol) ? 0.4 : 0),
      // Un anotador de poste no es un jugador de aclarados: los interiores aportan la mitad.
      Rasgo.aislamiento => _norma(s.ppp, 18, 31) * (interior ? 0.5 : 1),
      Rasgo.iq => _norma(s.iq.toDouble(), 60, 99),
      Rasgo.defensaExterior =>
        _exteriores.contains(j.posiciones.first)
            ? 0.7 * _norma(s.robP, 0.6, 2.2) + (_rolesDefensivos.contains(j.rol) ? 0.3 : 0)
            : 0,
      Rasgo.proteccionAro => interior ? _norma(s.tapP, 0.5, 3.0) : 0,
      Rasgo.rebote => _norma(s.rpp, 3, 12),
      Rasgo.versatilidad => _norma(j.posiciones.length.toDouble(), 1, 3),
      Rasgo.fisico => _norma(s.minP, 28, 40),
    };
  }

  /// Evidencia legible del rasgo para un jugador, p. ej. "42.6 %T3".
  static String evidencia(Rasgo r, Jugador j) {
    final s = j.stats;
    final valor = switch (r) {
      Rasgo.triple => (s.pctT3 * 100).toStringAsFixed(1),
      Rasgo.creacion => s.app.toStringAsFixed(1),
      Rasgo.poste || Rasgo.aislamiento => s.ppp.toStringAsFixed(1),
      Rasgo.transicion || Rasgo.defensaExterior => s.robP.toStringAsFixed(1),
      Rasgo.iq => '${s.iq}',
      Rasgo.proteccionAro => s.tapP.toStringAsFixed(1),
      Rasgo.rebote => s.rpp.toStringAsFixed(1),
      Rasgo.versatilidad => '${j.posiciones.length}',
      Rasgo.fisico => s.minP.toStringAsFixed(1),
    };
    return '$valor ${r.sigla}';
  }

  factory PerfilPlantel.de(Plantel plantel) {
    final pesos = {for (final p in Posicion.values) ?plantel.en(p): p == Posicion.sextoHombre ? _pesoSexto : 1.0};
    final valores = <Rasgo, double>{};
    final figuras = <Rasgo, Jugador>{};
    for (final r in Rasgo.values) {
      if (pesos.isEmpty) {
        valores[r] = 0;
        continue;
      }
      final aportes = {for (final j in pesos.keys) j: aporte(r, j)};
      figuras[r] = aportes.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      final media =
          aportes.entries.fold(0.0, (s, e) => s + e.value * pesos[e.key]!) / pesos.values.fold(0.0, (s, p) => s + p);
      final mejor = aportes.values.reduce(max);
      // Rasgos que dependen de una figura (estrella, protector del aro) pesan por el mejor;
      // los colectivos, por el promedio.
      valores[r] = switch (r) {
        Rasgo.aislamiento || Rasgo.proteccionAro || Rasgo.poste => mejor,
        Rasgo.creacion => 0.5 * media + 0.5 * mejor,
        _ => media,
      };
    }
    return PerfilPlantel._(valores, figuras);
  }

  int afinidad(Map<Rasgo, int> rasgos) {
    final total = rasgos.values.fold(0, (s, w) => s + w);
    final puntos = rasgos.entries.fold(0.0, (s, e) => s + e.value * valores[e.key]!);
    return (100 * puntos / total).round().clamp(1, 99);
  }

  /// Los [n] rasgos que más empujan al sistema, con su figura.
  List<(Rasgo, Jugador?)> motivos(Map<Rasgo, int> rasgos, {int n = 2}) {
    final orden = rasgos.entries.toList()
      ..sort((a, b) => (b.value * valores[b.key]!).compareTo(a.value * valores[a.key]!));
    return [for (final e in orden.take(n)) (e.key, figuras[e.key])];
  }
}

class Recomendacion {
  const Recomendacion(this.tactica, this.afinidadOfensiva, this.afinidadDefensiva);

  final Tactica tactica;
  final int afinidadOfensiva;
  final int afinidadDefensiva;
}

/// Asistente de recomendación dual (GDD §11, Fase 4): la mejor pareja ofensiva + defensiva.
/// Penaliza ritmos opuestos (correr en ataque y frenar el partido en defensa no conviven).
Recomendacion recomendar(PerfilPlantel perfil) {
  const castigoRitmo = 8.0;
  Recomendacion? mejor;
  double mejorPuntaje = double.negativeInfinity;
  for (final o in SistemaOfensivo.values) {
    final ao = perfil.afinidad(o.rasgos);
    for (final d in EsquemaDefensivo.values) {
      final ad = perfil.afinidad(d.rasgos);
      final puntaje = ao + ad - castigoRitmo * (o.ritmo - d.ritmo).abs();
      if (puntaje > mejorPuntaje) {
        mejorPuntaje = puntaje;
        mejor = Recomendacion(Tactica(ofensiva: o, defensiva: d), ao, ad);
      }
    }
  }
  return mejor!;
}
