import 'dart:math';

import 'carrera_jugador.dart';
import 'medidor_tiro.dart';

/// Resultado de un minijuego de timing: una calidad por intento.
class RondaTiming {
  const RondaTiming(this.intentos);
  final List<CalidadTiro> intentos;

  int get perfectos => intentos.where((c) => c == CalidadTiro.perfecto).length;
  int get buenos => intentos.where((c) => c == CalidadTiro.bueno).length;

  /// Perfecto vale 2 y Bien 1.
  int get puntos => perfectos * 2 + buenos;
  int get maximo => intentos.length * 2;
}

/// Entrenamiento interactivo: una sesión por temporada en la que ejercitás un atributo con la barra de timing.
/// Se guarda `ent:hecho` (1 si ya la hiciste esta temporada).
class EntrenamientoInteractivo {
  EntrenamientoInteractivo._();

  static const intentos = 5;

  static bool yaHecho(EstadoCarrera e) => (e.uso['ent:hecho'] ?? 0) == 1;

  /// Ancho de la zona verde: crece con el atributo que entrenás.
  static double ventana(EstadoCarrera e, Atributo a) => (0.10 + (e.atributos[a] - 60) * 0.0015).clamp(0.08, 0.2).toDouble();

  /// Puntos de habilidad según cómo salió (de 0 a 10): 6 o más dan 1, 9 o más dan 2.
  static int premioPH(RondaTiming r) => r.puntos >= 9 ? 2 : (r.puntos >= 6 ? 1 : 0);

  static EstadoCarrera aplicar(EstadoCarrera e, Atributo a, RondaTiming r) {
    if (yaHecho(e) || e.retirado) return e;
    final ph = premioPH(r);
    final perfecta = r.puntos >= r.maximo; // 5 perfectos: sube el atributo
    final nuevo = perfecta && e.atributos[a] < ModeloCarrera.tope ? e.atributos.con(a, e.atributos[a] + 1) : e.atributos;
    return e.copyWith(
      atributos: nuevo,
      phBanco: e.phBanco + ph,
      uso: {...e.uso, 'ent:hecho': 1, 'ent:total': (e.uso['ent:total'] ?? 0) + 1, if (perfecta) 'ent:perfectas': (e.uso['ent:perfectas'] ?? 0) + 1},
      movimientos: [
        ...e.movimientos,
        '${e.etiquetaTemporada}: sesión de ${a.etiqueta.toLowerCase()}: ${r.puntos}/${r.maximo}'
            '${ph > 0 ? ', +$ph ${ph == 1 ? 'punto' : 'puntos'} de habilidad' : ''}${perfecta ? ' y +1 al atributo' : ''}.',
      ],
    );
  }

  /// Al cerrar la temporada se abre una sesión nueva.
  static Map<String, int> alCerrar(Map<String, int> uso) => {...uso}..remove('ent:hecho');
}

/// Los concursos del fin de semana de las estrellas (solo si te eligieron para el All-Star).
enum Concurso {
  triples('Concurso de triples', 10, 'Diez tiros de tres: soltá en la zona verde.'),
  volcadas('Concurso de volcadas', 5, 'Cinco volcadas: el jurado puntúa el timing.');

  const Concurso(this.etiqueta, this.intentos, this.descripcion);
  final String etiqueta, descripcion;
  final int intentos;
}

class ResultadoConcurso {
  const ResultadoConcurso({required this.concurso, required this.tuPuntaje, required this.rivales, required this.puesto});
  final Concurso concurso;
  final double tuPuntaje;
  final List<(String, double)> rivales;

  /// 1 = ganaste.
  final int puesto;
  bool get gano => puesto == 1;
}

class ConcursosAllStar {
  ConcursosAllStar._();

  static bool disponible(EstadoCarrera e, bool esAllStar, Concurso c) =>
      esAllStar && !e.retirado && (e.uso['as:${c.name}'] ?? 0) == 0;

  static bool jugado(EstadoCarrera e, Concurso c) => (e.uso['as:${c.name}'] ?? 0) > 0;

  /// Habilidad que pesa en cada concurso.
  static double habilidad(EstadoCarrera e, Concurso c) => c == Concurso.triples
      ? (Habilidad.valor(Habilidad.triple, e.atributos, e.espec) + Habilidad.valor(Habilidad.tiroEnMovimiento, e.atributos, e.espec)) / 2
      : (Habilidad.valor(Habilidad.volcada, e.atributos, e.espec) + Habilidad.valor(Habilidad.velocidad, e.atributos, e.espec)) / 2;

  /// Ancho de la zona verde del minijuego.
  static double ventana(EstadoCarrera e, Concurso c) => (0.08 + (habilidad(e, c) - 60) * 0.0028).clamp(0.07, 0.2).toDouble();

  /// Puntaje: en triples, tiros convertidos (perfecto y bien entran; el perfecto vale dos, como el carrito de dinero);
  /// en volcadas, puntaje del jurado (de 5 a 10 por salto).
  static double puntaje(Concurso c, RondaTiming r) => c == Concurso.triples
      ? r.puntos.toDouble()
      : r.intentos.fold(0.0, (a, q) => a + (q == CalidadTiro.perfecto ? 10 : q == CalidadTiro.bueno ? 8 : 5));

  static const _nombresRivales = ['Davis', 'Kerr', 'Mitchell', 'Booker', 'Haliburton', 'Edwards', 'Curry', 'Lillard', 'Gordon', 'Jackson', 'Zion', 'Morant'];

  /// Cuatro rivales con puntaje determinista (parecidos entre sí; el que gana, gana por poco).
  static List<(String, double)> rivales(EstadoCarrera e, Concurso c) {
    final azar = Random(e.raiz.codeUnits.fold(11, (a, x) => (a * 31 + x) & 0x7fffffff) + e.numero * 7 + c.index);
    final nombres = [..._nombresRivales]..shuffle(azar);
    final base = c == Concurso.triples ? 11.0 : 40.0;
    final dispersion = c == Concurso.triples ? 4.0 : 6.0;
    return [for (var i = 0; i < 4; i++) (nombres[i], double.parse((base + azar.nextDouble() * dispersion * 2 - dispersion + (c == Concurso.triples ? 1.0 : 2.0)).toStringAsFixed(1)))];
  }

  static ResultadoConcurso resolver(EstadoCarrera e, Concurso c, RondaTiming r) {
    final propio = puntaje(c, r);
    final riv = rivales(e, c);
    final puesto = 1 + riv.where((x) => x.$2 >= propio).length;
    return ResultadoConcurso(concurso: c, tuPuntaje: propio, rivales: riv, puesto: puesto);
  }

  static EstadoCarrera aplicar(EstadoCarrera e, ResultadoConcurso r) {
    if ((e.uso['as:${r.concurso.name}'] ?? 0) > 0) return e;
    final texto = '${e.etiquetaTemporada}: ${r.concurso.etiqueta}: ${r.gano ? '¡campeón!' : '${r.puesto}.º puesto'} '
        '(${r.tuPuntaje.toStringAsFixed(0)} puntos).';
    return e.copyWith(
      fans: (e.fans + (r.gano ? 4 : 1)).clamp(0, 98),
      uso: {
        ...e.uso,
        'as:${r.concurso.name}': r.puesto,
        if (r.gano) 'as:ganados': (e.uso['as:ganados'] ?? 0) + 1,
      },
      hitos: r.gano ? [...e.hitos, texto] : null,
      movimientos: [...e.movimientos, texto],
    );
  }

  /// Premios de concurso ganados esta temporada (para el resumen del año).
  static List<String> premios(EstadoCarrera e) => [
    for (final c in Concurso.values)
      if ((e.uso['as:${c.name}'] ?? 0) == 1) 'Campeón del ${c.etiqueta.toLowerCase()}',
  ];

  static Map<String, int> alCerrar(Map<String, int> uso) => {
    for (final x in uso.entries)
      if (x.key != 'as:triples' && x.key != 'as:volcadas') x.key: x.value,
  };
}
