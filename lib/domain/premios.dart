import 'dart:math';

import 'entities/jugador.dart';
import 'entities/posicion.dart';
import 'entities/temporada.dart';
import 'liga.dart';
import 'motor.dart';

/// Un premio individual: quién, de qué franquicia, el valor que lo definió y su línea del año.
/// Apellido para mostrar en espacios chicos (sin "Jr.", "III" y compañía).
String apellido(Jugador j) {
  final partes = j.nombre.split(' ').where((p) => !{'Jr.', 'Jr', 'Sr.', 'II', 'III', 'IV'}.contains(p)).toList();
  return partes.isEmpty ? j.nombre : partes.last;
}

class Galardon {
  const Galardon(this.jugador, this.franquiciaId, this.valor, this.linea);

  final Jugador jugador;
  final String franquiciaId;
  final double valor;
  final LineaEstadistica linea;

  String get jugadorId => jugador.id;
  double por(int total) => linea.pj == 0 ? 0 : total / linea.pj;
}

/// Puesto en los quintetos All-NBA: 2 bases/escoltas, 2 aleros/ala-pívots, 1 pívot.
enum GrupoPuesto {
  exterior('Exterior'),
  alero('Alero'),
  pivot('Pívot');

  const GrupoPuesto(this.etiqueta);
  final String etiqueta;

  static GrupoPuesto de(Jugador j) => switch (j.posiciones.first) {
    Posicion.base || Posicion.escolta => exterior,
    Posicion.alero || Posicion.alaPivot => alero,
    _ => pivot,
  };

  static const cupo = {GrupoPuesto.exterior: 2, GrupoPuesto.alero: 2, GrupoPuesto.pivot: 1};
}

/// Todos los premios de la temporada regular (GDD §8.2 + metajuego).
class PremiosTemporada {
  const PremiosTemporada({
    required this.mvp,
    required this.anotador,
    required this.defensor,
    required this.sextoHombre,
    required this.masMejorado,
    required this.allNba,
    required this.definitivos,
  });

  final Galardon? mvp, anotador, defensor, sextoHombre, masMejorado;

  /// 1.º, 2.º y 3.º quinteto All-NBA (5 jugadores cada uno, 2-2-1 por puesto).
  final List<List<Galardon>> allNba;

  /// La temporada regular terminó (si no, son "la carrera").
  final bool definitivos;

  static const vacios = PremiosTemporada(
    mvp: null,
    anotador: null,
    defensor: null,
    sextoHombre: null,
    masMejorado: null,
    allNba: [],
    definitivos: false,
  );

  /// Premios que se llevó una franquicia: (nombre del premio, galardón).
  List<(String, Galardon)> de(String franquiciaId) => [
    for (final (nombre, g) in [
      ('MVP', mvp),
      ('Máximo Anotador', anotador),
      ('Defensor del Año', defensor),
      ('Sexto Hombre del Año', sextoHombre),
      ('Jugador Más Mejorado', masMejorado),
    ])
      if (g != null && g.franquiciaId == franquiciaId) (nombre, g),
  ];
}

/// Valor para el MVP: eficiencia por partido ponderada por el récord del equipo (igual que
/// [Liga.premios], así el MVP de acá y el de la vitrina son el mismo).
double valorMvp(LineaEstadistica l, double porcentajeEquipo) {
  if (l.pj == 0) return 0;
  final eficiencia = (l.pts + l.reb + l.ast + l.rob + l.tap - (l.tcA - l.tcI) - (l.tlA - l.tlI) - l.per) / l.pj;
  return eficiencia * (0.6 + 0.8 * porcentajeEquipo);
}

/// Candidatos a premios: los que jugaron al menos la mitad de los partidos del que más jugó.
List<Galardon> candidatos(Temporada t, Liga liga, {double Function(LineaEstadistica, double)? valor}) {
  final equipos = liga.equipos(t);
  final maxPj = t.lineas.values.fold(0, (a, l) => max(a, l.pj));
  if (maxPj == 0) return const [];
  final pct = <String, double>{};
  return [
    for (final e in t.lineas.entries)
      if (equipos[e.key] case final f? when e.value.pj * 2 >= maxPj)
        if (liga.jugador(e.key) case final j?)
          Galardon(j, f, (valor ?? valorMvp)(e.value, pct[f] ??= t.registroDe(f).porcentaje), e.value),
  ]..sort((a, b) => b.valor.compareTo(a.valor));
}

PremiosTemporada calcularPremios(Temporada t, Liga liga) {
  final base = candidatos(t, liga);
  if (base.isEmpty) return PremiosTemporada.vacios;
  Galardon? mejor(double Function(Galardon) valor, {bool Function(Galardon)? filtro}) {
    Galardon? elegido;
    var max = double.negativeInfinity;
    for (final g in base) {
      if (filtro != null && !filtro(g)) continue;
      final v = valor(g);
      if (v > max) {
        max = v;
        elegido = Galardon(g.jugador, g.franquiciaId, v, g.linea);
      }
    }
    return elegido;
  }

  final pct = {for (final g in base) g.franquiciaId: t.registroDe(g.franquiciaId).porcentaje};
  final sextos = {
    ?t.plantel.en(Posicion.sextoHombre)?.id,
    for (final r in t.rivales.values) ?r.cartaIds[Posicion.sextoHombre],
  };

  // Quintetos All-NBA: por valor de MVP, respetando 2-2-1 y sin repetir a nadie.
  final usados = <String>{};
  final quintetos = <List<Galardon>>[];
  for (var k = 0; k < 3; k++) {
    final quinteto = <Galardon>[];
    for (final grupo in GrupoPuesto.values) {
      final cupo = GrupoPuesto.cupo[grupo]!;
      final elegidos = base
          .where((g) => !usados.contains(g.jugadorId) && GrupoPuesto.de(g.jugador) == grupo)
          .take(cupo);
      for (final g in elegidos) {
        quinteto.add(g);
        usados.add(g.jugadorId);
      }
    }
    if (quinteto.length == 5) quintetos.add(quinteto);
  }

  return PremiosTemporada(
    mvp: base.first,
    anotador: mejor((g) => g.por(g.linea.pts)),
    defensor: mejor(
      (g) =>
          (g.por(g.linea.rob) * 2 + g.por(g.linea.tap) * 2 + g.por(g.linea.reb) * 0.12) *
          (0.8 + 0.4 * pct[g.franquiciaId]!),
    ),
    sextoHombre: mejor((g) => g.valor, filtro: (g) => sextos.contains(g.jugadorId)),
    masMejorado: mejor((g) {
      final s = g.jugador.stats;
      return (g.por(g.linea.pts) - s.ppp) + 0.5 * (g.por(g.linea.reb) - s.rpp) + 0.5 * (g.por(g.linea.ast) - s.app);
    }, filtro: (g) => g.por(g.linea.pts) > g.jugador.stats.ppp),
    allNba: quintetos,
    definitivos: t.calendario.isNotEmpty && t.calendario.every((p) => p.jugado),
  );
}
