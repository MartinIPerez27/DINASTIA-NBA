import 'dart:math';

import '../entities/posicion.dart';
import 'carrera_jugador.dart';

/// Una temporada de las etapas previas (secundario o universidad).
class TemporadaPrevia {
  const TemporadaPrevia({
    required this.etapa,
    required this.anio,
    required this.edad,
    required this.media,
    required this.pts,
    required this.reb,
    required this.ast,
    required this.hitos,
  });

  /// 'Secundario' o 'Universidad'.
  final String etapa;
  final int anio, edad, media;
  final double pts, reb, ast;
  final List<String> hitos;
}

/// El camino antes del draft: lo que jugó, cuánto mejoró, y con qué pick y atributos llega a la NBA.
class CaminoPrevio {
  const CaminoPrevio({required this.temporadas, required this.creado, required this.pick, required this.ranking});

  final List<TemporadaPrevia> temporadas;

  /// El jugador listo para el draft: atributos, edad y pick fijados por lo que hizo.
  final JugadorCreado creado;
  final int pick;

  /// Puesto en el ranking de reclutas al salir del secundario (1 = el mejor del país).
  final int ranking;

  List<String> get hitos => [
    for (final t in temporadas)
      for (final h in t.hitos) '${t.anio}: $h',
  ];
}

/// Simula las etapas previas de un jugador creado: 3 años de secundario y, si querés, de 1 a 3 de universidad.
/// Determinista por jugador y semilla.
class EtapasPrevias {
  EtapasPrevias._();

  static const aniosSecundario = 3;
  static const maxUniversidad = 3;

  /// Edad con la que se entra al secundario y año en que se sale (el draft cae un año después).
  static const _edadInicio = 15;

  static double _estadisticaBase(int media, double techo) => (media - 40) * techo;

  /// [aniosUniversidad]: 0 salta directo desde el secundario (solo si el ranking lo permite), 1 a 3 los que juegues.
  static CaminoPrevio simular(JugadorCreado jc, int semilla, {required int aniosUniversidad}) {
    final azar = Random(semilla ^ jc.nombre.codeUnits.fold(5, (a, x) => (a * 31 + x) & 0x7fffffff));
    // Cada año de universidad pule tus puntos fuertes y tu lectura de juego (+1 a cada uno); el secundario ya está en el nivel que creaste.
    var atributos = jc.atributos;
    for (var i = 0; i < aniosUniversidad; i++) {
      atributos = atributos.sumar({for (final f in jc.fuertes) f: 1}..[Atributo.iq] = 1);
    }
    final listo = JugadorCreado(
      nombre: jc.nombre,
      posicion: jc.posicion,
      rol: jc.rol,
      fuertes: jc.fuertes,
      alturaCm: jc.alturaCm,
      pesoKg: jc.pesoKg,
      atributosFijos: atributos,
    );
    final mediaFinal = listo.media;
    final temporadas = <TemporadaPrevia>[];
    final posicion = jc.posicion;
    final anioDraft = jc.anioDraft ?? 2026;
    final totalAnios = aniosSecundario + aniosUniversidad;
    final anioInicio = anioDraft - totalAnios;
    // El jugador "recién creado" es el que llega al draft: hacia atrás se le restan los avances de cada año.
    // Por eso las etapas parten de un nivel más bajo y suben hasta lo que elegiste.
    final subidaTotal = 3.0 * aniosUniversidad + 4.0 * aniosSecundario; // puntos de media ganados en el camino
    var media = max(35, mediaFinal - subidaTotal.round());
    var ranking = 0;
    for (var i = 0; i < totalAnios; i++) {
      final secundario = i < aniosSecundario;
      final crecimiento = secundario ? 4.0 : 3.0;
      media = min(mediaFinal, media + (crecimiento + (azar.nextDouble() - 0.5) * 2).round());
      final anio = anioInicio + i;
      final edad = _edadInicio + i;
      final nivel = secundario ? 0.62 : 0.55; // universitario: la competencia es más dura
      final pts = (_estadisticaBase(media, nivel) * (posicion == Posicion.pivot ? 0.75 : 1.0) / 2.4 + 8 + azar.nextDouble() * 3).clamp(8.0, 38.0);
      final reb = (media - 38) / 6 * (posicion == Posicion.pivot || posicion == Posicion.alaPivot ? 1.5 : 0.9) + azar.nextDouble();
      final ast = (media - 38) / 9 * (posicion == Posicion.base ? 1.7 : 0.8) + azar.nextDouble() * 0.8;
      final hitos = <String>[];
      if (secundario) {
        if (i == aniosSecundario - 1) {
          ranking = (110 - (media - 40) * 2.4 + (azar.nextDouble() - 0.5) * 18).round().clamp(1, 150);
          hitos.add('terminás el secundario como el n.º $ranking del ranking de reclutas.');
          if (ranking <= 24) hitos.add('te eligen para el McDonald\'s All-American.');
        } else if (pts >= 28) {
          hitos.add('promediás ${pts.toStringAsFixed(1).replaceAll('.', ',')} puntos: mejor jugador de tu estado.');
        }
      } else {
        final ronda = azar.nextDouble() + (media - 65) * 0.01;
        if (ronda > 1.05) {
          hitos.add('llegás a la Final Four del torneo universitario.');
        } else if (ronda > 0.75) {
          hitos.add('tu equipo llega al Sweet 16 de la March Madness.');
        } else if (ronda > 0.45) {
          hitos.add('caen en la primera ronda del torneo.');
        }
        if (pts >= 20) hitos.add('Jugador del año de tu conferencia.');
        if (pts >= 24 && media >= 78) hitos.add('Consensus All-American.');
        if (i == totalAnios - 1) hitos.add('te declarás elegible para el draft de la NBA.');
      }
      temporadas.add(
        TemporadaPrevia(
          etapa: secundario ? 'Secundario' : 'Universidad',
          anio: anio,
          edad: edad,
          media: media,
          pts: double.parse(pts.toStringAsFixed(1)),
          reb: double.parse(reb.toStringAsFixed(1)),
          ast: double.parse(ast.toStringAsFixed(1)),
          hitos: hitos,
        ),
      );
    }
    // El pick sale de la media con la que llegás y del ranking: los mejores reclutas caen más alto aunque no mejoren tanto.
    final puntaje = 0.75 * mediaFinal + 0.25 * (100 - ranking * 0.45);
    final pick = (18 - (puntaje - 67) * 1.6 + (azar.nextDouble() - 0.5) * 8).round().clamp(1, 60);
    return CaminoPrevio(
      temporadas: temporadas,
      ranking: ranking,
      pick: pick,
      creado: JugadorCreado(
        nombre: jc.nombre,
        posicion: jc.posicion,
        rol: jc.rol,
        fuertes: jc.fuertes,
        alturaCm: jc.alturaCm,
        pesoKg: jc.pesoKg,
        nacimiento: jc.nacimiento,
        atributosFijos: atributos,
        pickFijo: pick,
        edadInicial: _edadInicio + totalAnios,
        avatar: jc.avatar,
        anioDraft: anioDraft,
        dorsal: jc.dorsal,
        estilo: jc.estilo,
      ),
    );
  }
}
