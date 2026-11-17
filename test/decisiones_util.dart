import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/domain/decisiones_partido.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/tactica.dart';
import 'package:dinastia_nba/domain/motor.dart';

/// Ayudas comunes de las pruebas de decisiones en vivo.
final List<Jugador> catalogoDecisiones = parsearCatalogo(File(rutaCatalogo).readAsStringSync());

Plantel armarPlantel(bool Function(Jugador) filtro, int semilla, {int top = 40}) {
  final r = Random(semilla);
  var p = const Plantel();
  final pool = catalogoDecisiones.where(filtro).toList()..sort((a, b) => b.media.compareTo(a.media));
  final candidatos = pool.take(max(top, 12)).toList()..shuffle(r);
  for (final pos in Posicion.values) {
    final j = candidatos.firstWhere(
      (j) => p.posicionesDisponiblesPara(j).contains(pos) && !p.jugadores.any((x) => x.id == j.id),
      orElse: () => pool.firstWhere(
        (j) => p.posicionesDisponiblesPara(j).contains(pos) && !p.jugadores.any((x) => x.id == j.id),
        orElse: () => (catalogoDecisiones.toList()..sort((a, b) => b.media.compareTo(a.media))).firstWhere(
          (j) => p.posicionesDisponiblesPara(j).contains(pos) && !p.jugadores.any((x) => x.id == j.id),
        ),
      ),
    );
    p = p.asignar(j, pos);
  }
  return p;
}

EquipoPartido equipoDe(Plantel p, {String id = 'CHI', Tactica t = const Tactica()}) =>
    EquipoPartido(identidadId: id, plantel: p, tactica: t);

typedef Elegir = OpcionDecision? Function(DecisionPartido d);

/// Juega un partido en vivo con el director; [elegir] responde a cada decisión (null = ignorar).
DirectorDecisiones jugarConDirector(
  MotorPartido m,
  DirectorDecisiones d, {
  Elegir? elegir,
  bool automatica = false,
  void Function(EventoPartido e)? alEvento,
}) {
  while (!m.terminado) {
    final inf = d.evaluarEntretiempo();
    if (inf != null) d.aplicarEntretiempo(const []);
    final dec = d.evaluar();
    if (dec != null) d.resolver(dec, elegir?.call(dec));
    if (automatica) d.politicaAutomatica();
    final e = m.siguiente();
    d.observar(e);
    d.tick();
    alEvento?.call(e);
  }
  d.tick();
  return d;
}
