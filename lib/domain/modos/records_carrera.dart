import 'dart:convert';
import 'dart:math';

import 'carrera_jugador.dart';

// Los récords históricos reales de la NBA contra los que compite tu jugador: totales de carrera, promedios de una
// temporada y marcas de un partido. Los datos salen de `assets/database/records_nba.json` (lo genera
// `tools/records_nba.py` desde Basketball-Reference y Wikipedia; trae la fecha en que se bajó).

/// Un renglón de una lista de récords.
class FilaRecord {
  const FilaRecord({required this.nombre, required this.valor, this.activo = false, this.detalle = ''});

  final String nombre;
  final double valor;

  /// Sigue jugando (su marca puede crecer).
  final bool activo;

  /// Temporada (promedios) o fecha del partido.
  final String detalle;
}

class ListaRecords {
  const ListaRecords(this.clave, this.etiqueta, this.filas);

  final String clave, etiqueta;
  final List<FilaRecord> filas;

  FilaRecord get record => filas.first;
}

class RecordsNba {
  const RecordsNba({required this.fecha, required this.fuente, required this.carrera, required this.temporada, required this.partido});

  final String fecha, fuente;
  final Map<String, ListaRecords> carrera, temporada, partido;

  factory RecordsNba.fromJson(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    Map<String, ListaRecords> seccion(String k) => {
      for (final e in (j[k] as Map<String, dynamic>).entries)
        e.key: ListaRecords(
          e.key,
          (e.value as Map<String, dynamic>)['etiqueta'] as String,
          [
            for (final f in ((e.value as Map<String, dynamic>)['filas'] as List).cast<Map<String, dynamic>>())
              FilaRecord(
                nombre: f['nombre'] as String,
                valor: (f['valor'] as num).toDouble(),
                activo: f['activo'] as bool? ?? false,
                detalle: (f['temporada'] ?? f['fecha'] ?? '') as String,
              ),
          ],
        ),
    };
    return RecordsNba(
      fecha: j['fecha'] as String? ?? '',
      fuente: j['fuente'] as String? ?? '',
      carrera: seccion('carrera'),
      temporada: seccion('temporada'),
      partido: seccion('partido'),
    );
  }
}

/// Cómo vas contra una lista de récords.
class CaminoRecord {
  const CaminoRecord({
    required this.lista,
    required this.tuValor,
    required this.puesto,
    required this.siguiente,
    required this.superados,
    required this.progreso,
    this.ritmo,
    this.temporadasParaSuperar,
  });

  final ListaRecords lista;
  final double tuValor;

  /// Puesto histórico que ocuparías (1 = el récord); null si no entrás en la lista.
  final int? puesto;

  /// El próximo jugador por encima tuyo (null si ya sos el récord).
  final FilaRecord? siguiente;

  /// A quiénes de la lista ya superaste.
  final List<FilaRecord> superados;

  /// Tu valor sobre el del récord (0 a 1).
  final double progreso;

  /// Lo que sumás por temporada y cuántas más hacen falta para pasar a [siguiente] a ese ritmo (solo totales de carrera).
  final double? ritmo;
  final double? temporadasParaSuperar;

  double get faltan => siguiente == null ? 0 : siguiente!.valor - tuValor;
}

/// Cálculos de récords de tu jugador (todo sale de `EstadoCarrera`; los contadores `c:`, `m:` y `b:` los llena el partido).
class RecordsCarrera {
  const RecordsCarrera._();

  /// Contadores de carrera que se llevan partido a partido.
  static const contadores = {
    'puntos': 'c:pts',
    'rebotes': 'c:reb',
    'asistencias': 'c:ast',
    'robos': 'c:rob',
    'tapones': 'c:tap',
    'triples': 'c:t3',
    'triplesDobles': 'c:td',
  };

  static const mejorPartido = {
    'puntos': 'm:pts',
    'rebotes': 'm:reb',
    'asistencias': 'm:ast',
    'robos': 'm:rob',
    'tapones': 'm:tap',
    'triples': 'm:t3',
  };

  static double totalCarrera(EstadoCarrera e, String clave) {
    final c = (e.uso[contadores[clave]] ?? 0).toDouble();
    final l = e.legado;
    // Las partidas anteriores al seguimiento por partido tienen totales en el historial: vale el mayor.
    return switch (clave) {
      'puntos' => max(c, l.puntos.toDouble()),
      'rebotes' => max(c, l.rebotes.toDouble()),
      'asistencias' => max(c, l.asistencias.toDouble()),
      _ => c,
    };
  }

  /// Tu mejor promedio por partido en una temporada completa.
  static double mejorTemporada(EstadoCarrera e, String clave) => switch (clave) {
    'puntos' => e.historial.fold(0.0, (a, h) => max(a, h.pts)),
    'rebotes' => e.historial.fold(0.0, (a, h) => max(a, h.reb)),
    'asistencias' => e.historial.fold(0.0, (a, h) => max(a, h.ast)),
    'robos' => (e.uso['b:rob100'] ?? 0) / 100,
    'tapones' => (e.uso['b:tap100'] ?? 0) / 100,
    _ => 0,
  };

  static double marcaPartido(EstadoCarrera e, String clave) => (e.uso[mejorPartido[clave]] ?? 0).toDouble();

  /// Temporadas jugadas contando la actual por lo que lleva (para el ritmo).
  static double temporadasJugadas(EstadoCarrera e) {
    final actual = ((e.uso['sc:pj'] ?? 0) / 82).clamp(0.0, 1.0);
    return e.historial.length + actual;
  }

  static CaminoRecord camino(ListaRecords lista, double tuValor, {double? ritmoPorTemporada}) {
    final mayores = lista.filas.where((f) => f.valor > tuValor).toList();
    final superados = lista.filas.where((f) => f.valor <= tuValor && tuValor > 0).toList();
    final puesto = tuValor <= 0
        ? null
        : (mayores.length < lista.filas.length ? mayores.length + 1 : null);
    final siguiente = mayores.isEmpty ? null : mayores.reduce((a, b) => a.valor <= b.valor ? a : b);
    final record = lista.record.valor;
    double? paraSuperar;
    if (ritmoPorTemporada != null && ritmoPorTemporada > 0 && siguiente != null) {
      paraSuperar = (siguiente.valor - tuValor) / ritmoPorTemporada;
    }
    return CaminoRecord(
      lista: lista,
      tuValor: tuValor,
      puesto: puesto,
      siguiente: siguiente,
      superados: superados,
      progreso: record <= 0 ? 0 : (tuValor / record).clamp(0.0, 1.0),
      ritmo: ritmoPorTemporada,
      temporadasParaSuperar: paraSuperar,
    );
  }

  static List<CaminoRecord> carrera(RecordsNba r, EstadoCarrera e) {
    final t = max(0.2, temporadasJugadas(e));
    return [
      for (final l in r.carrera.values)
        camino(l, totalCarrera(e, l.clave), ritmoPorTemporada: totalCarrera(e, l.clave) / t),
    ];
  }

  static List<CaminoRecord> temporada(RecordsNba r, EstadoCarrera e) => [
    for (final l in r.temporada.values) camino(l, mejorTemporada(e, l.clave)),
  ];

  static List<CaminoRecord> partido(RecordsNba r, EstadoCarrera e) => [
    for (final l in r.partido.values) camino(l, marcaPartido(e, l.clave)),
  ];

  /// Tus marcas de partido que no son récords de la liga pero cuentan para tu historia.
  static List<(String, int)> hitos(EstadoCarrera e) => [
    ('Partidos de 30 puntos o más', e.uso['c:p30'] ?? 0),
    ('Partidos de 40 puntos o más', e.uso['c:p40'] ?? 0),
    ('Partidos de 50 puntos o más', e.uso['c:p50'] ?? 0),
    ('Dobles-dobles', e.uso['c:dd'] ?? 0),
    ('Triples-dobles', e.uso['c:td'] ?? 0),
  ];

  /// "Pasaste a Shaq en puntos": los de cada lista de carrera que ya superaste, por lista.
  static List<String> novedades(RecordsNba r, EstadoCarrera e) {
    final lineas = <String>[];
    for (final c in carrera(r, e)) {
      if (c.superados.isEmpty) continue;
      final nombres = c.superados.take(3).map((f) => f.nombre).join(', ');
      lineas.add('${c.lista.etiqueta}: ya superaste a $nombres${c.superados.length > 3 ? ' y ${c.superados.length - 3} más' : ''}.');
    }
    return lineas;
  }
}
