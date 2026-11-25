import 'dart:convert';
import 'dart:math';

import '../entities/jugador.dart';
import 'carrera_jugador.dart';

// Tu generación: los mejores elegidos del draft de tu año, con quienes competís toda la carrera. Hasta 2025 salen
// del catálogo con sus números reales; el draft 2026 (ya jugado) usa los elegidos reales y proyecta sus números
// (su año de novato pesa con las estadísticas reales de la temporada en curso, a medida que juegan). Si un año no tuviera datos, se arma una clase ficticia que evoluciona sola.

/// Un integrante de tu clase del draft.
class CompaneroGeneracion {
  const CompaneroGeneracion({
    required this.nombre,
    required this.pick,
    required this.cartas,
    this.ficticio = false,
    this.semilla = 0,
    this.equipo,
    this.posicion,
    this.real,
  });

  final String nombre;
  final int pick;

  /// Las cartas reales de su carrera (vacío si es ficticio).
  final List<Jugador> cartas;
  /// Nombre inventado (si es false con [cartas] vacías, es un elegido real cuyos números se proyectan).
  final bool ficticio;
  final int semilla;

  /// Equipo y puesto con que fue elegido (solo la clase 2026 los trae).
  final String? equipo, posicion;

  /// Estadísticas reales de su temporada de novato hasta hoy (partidos, puntos, rebotes y asistencias por partido), si ya debutó.
  final ({int g, double pts, double reb, double ast})? real;

  /// Sus números salen de un modelo y no de cartas reales.
  bool get proyectado => cartas.isEmpty;
}

/// Lo que hizo un compañero de generación en un año.
class LineaGeneracion {
  const LineaGeneracion(this.pts, this.reb, this.ast, this.media, {this.retirado = false});

  final double pts, reb, ast;
  final int media;
  final bool retirado;
}

class GeneracionCarrera {
  const GeneracionCarrera._();

  static const tamano = 8;

  static const _nombres = ['Mateo', 'Julián', 'Tomás', 'Bruno', 'Lucas', 'Gael', 'Thiago', 'Nahuel', 'Dante', 'Iván'];
  static const _apellidos = ['Ferrari', 'Duarte', 'Salas', 'Brandt', 'Okafor', 'Lindqvist', 'Moreau', 'Castaño', 'Vidal', 'Kovač'];

  /// Los elegidos reales del draft 2026 a partir de `assets/database/draft_2026.json` (pick, nombre, pos, equipo).
  static List<CompaneroGeneracion> deJson2026(String json) {
    final lista = jsonDecode(json) as List;
    return [
      for (final x in lista.cast<Map<String, dynamic>>())
        CompaneroGeneracion(
          nombre: x['nombre'] as String,
          pick: x['pick'] as int,
          cartas: const [],
          semilla: ((x['nombre'] as String).hashCode ^ (x['pick'] as int) * 7919) & 0xfffff,
          equipo: x['equipo'] as String?,
          posicion: x['pos'] as String?,
          real: switch (x['real']) {
            final Map<String, dynamic> r => (
              g: (r['g'] as num).toInt(),
              pts: (r['pts'] as num).toDouble(),
              reb: (r['reb'] as num).toDouble(),
              ast: (r['ast'] as num).toDouble(),
            ),
            _ => null,
          },
        ),
    ]..sort((a, b) => a.pick.compareTo(b.pick));
  }

  /// Los primeros [tamano] elegidos de tu draft (sin vos), por número de elección. [clase2026] son los reales de 2026.
  static List<CompaneroGeneracion> clase(List<Jugador> catalogo, EstadoCarrera e, {List<CompaneroGeneracion>? clase2026}) {
    final anio = e.anioBase;
    if (anio == 2026 && clase2026 != null && clase2026.length >= tamano) return clase2026.take(tamano).toList();
    final porPersona = <int, List<Jugador>>{};
    for (final j in catalogo) {
      if (j.nbaPlayerId > 0 && j.draft?.$1 == anio && j.nbaPlayerId != e.base.nbaPlayerId) {
        porPersona.putIfAbsent(j.nbaPlayerId, () => []).add(j);
      }
    }
    final reales = [
      for (final cartas in porPersona.values)
        CompaneroGeneracion(
          nombre: cartas.first.nombre,
          pick: cartas.first.draft!.$2,
          cartas: [...cartas]..sort((a, b) => (a.temporadas?.$1 ?? 0).compareTo(b.temporadas?.$1 ?? 0)),
        ),
    ]..sort((a, b) => a.pick.compareTo(b.pick));
    if (reales.length >= tamano) return reales.take(tamano).toList();
    // Año sin datos reales: clase ficticia, igual cada vez que se abre (semilla de la carrera).
    final azar = Random(e.raiz.hashCode ^ anio);
    final nombres = [..._nombres]..shuffle(azar);
    final apellidos = [..._apellidos]..shuffle(azar);
    return [
      ...reales,
      for (var i = reales.length; i < tamano; i++)
        CompaneroGeneracion(
          nombre: '${nombres[i]} ${apellidos[i]}',
          pick: i + 1,
          cartas: const [],
          ficticio: true,
          semilla: azar.nextInt(1 << 20),
        ),
    ];
  }

  /// Su línea en el año [anio] (la carta real que cubre ese año, o la modelada si es ficticio). Null si todavía no jugaba.
  static LineaGeneracion? lineaEn(CompaneroGeneracion c, int anio, {required int anioDraft}) {
    if (anio <= anioDraft) return null;
    if (c.proyectado) {
      final k = anio - anioDraft;
      final azar = Random(c.semilla ^ k);
      final techo = 24 - c.pick * 0.9 + (c.semilla % 5);
      final curva = k <= 6 ? 0.55 + 0.45 * (k / 6) : max(0.4, 1 - (k - 9) * 0.06);
      if (k > 15) return const LineaGeneracion(0, 0, 0, 0, retirado: true);
      final pts = max(3.0, techo * curva + (azar.nextDouble() - 0.5) * 3);
      final modelo = LineaGeneracion(pts, max(1.0, pts * 0.28), max(0.8, pts * 0.2), (62 + pts * 1.2).round().clamp(55, 97));
      // El año de novato ya se está jugando: pesan sus números reales según los partidos que lleva (30 o más: solo los reales).
      final r = c.real;
      if (k == 1 && r != null && r.g >= 3) {
        final w = (r.g / 30).clamp(0.0, 1.0);
        double mezcla(double real, double proy) => real * w + proy * (1 - w);
        final p = mezcla(r.pts, modelo.pts);
        return LineaGeneracion(p, mezcla(r.reb, modelo.reb), mezcla(r.ast, modelo.ast), (62 + p * 1.2).round().clamp(55, 97));
      }
      return modelo;
    }
    Jugador? mejor;
    var dist = 999;
    for (final j in c.cartas) {
      final (a, b) = j.temporadas ?? (anioDraft + 1, anioDraft + 6);
      final d = anio < a ? a - anio : (anio > b ? anio - b : 0);
      if (d < dist) {
        dist = d;
        mejor = j;
      }
    }
    if (mejor == null || dist > 4) return const LineaGeneracion(0, 0, 0, 0, retirado: true);
    return LineaGeneracion(mejor.stats.ppp, mejor.stats.rpp, mejor.stats.app, mejor.media);
  }
}
