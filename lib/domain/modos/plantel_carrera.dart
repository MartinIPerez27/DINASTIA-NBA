import 'dart:math';

import '../entities/jugador.dart';
import 'carrera_jugador.dart';

// La plantilla de tu equipo año a año: edad de los compañeros, contratos, retiros, traspasos y novatos del draft.
//
// Los contratos de los compañeros se guardan en `EstadoCarrera.uso` (clave `ct:<id de carta>`: años que le quedan).

/// Qué pasó con los compañeros en un receso.
class RotacionPlantel {
  const RotacionPlantel(this.quedan, this.movimientos);

  /// Los que siguen en el plantel.
  final List<Jugador> quedan;

  /// Líneas para "Mi equipo" (quién se fue y por qué).
  final List<String> movimientos;
}

class PlantelCarrera {
  const PlantelCarrera._();

  /// Edad de [j] en el año [anio] (si la carta no trae año de nacimiento, se supone 27).
  static int edadEn(Jugador j, int anio) => anio - (j.nacimiento ?? anio - 27);

  static int contratoDe(EstadoCarrera e, Jugador j) => e.uso['ct:${j.id}'] ?? 2;

  /// Probabilidad de retirarse al terminar el año: 0 hasta los 34, y sube rápido.
  static double probabilidadRetiro(int edad) => edad < 35 ? 0 : min(0.95, 0.1 + (edad - 35) * 0.25);

  /// Qué pasa con cada compañero al cerrar la temporada: retiro, fin de contrato (renueva o se va) o traspaso.
  static RotacionPlantel rotar(
    EstadoCarrera e,
    Random azar, {
    required int anio,
    required String Function(String franquiciaId) nombreDe,
    required List<String> franquicias,
  }) {
    final quedan = <Jugador>[];
    final mov = <String>[];
    final etiqueta = e.etiquetaDe(e.numero + 1);
    for (final j in e.companeros) {
      final edad = edadEn(j, anio);
      if (azar.nextDouble() < probabilidadRetiro(edad)) {
        mov.add('$etiqueta: ${j.nombre} se retira a los $edad años.');
        continue;
      }
      final restan = contratoDe(e, j) - 1;
      if (restan <= 0) {
        if (azar.nextDouble() < 0.7) {
          quedan.add(j);
        } else {
          mov.add('$etiqueta: ${j.nombre} termina contrato y firma con otro equipo.');
        }
        continue;
      }
      if (azar.nextDouble() < 0.07) {
        final destino = franquicias[azar.nextInt(franquicias.length)];
        mov.add('$etiqueta: ${j.nombre} es traspasado a ${nombreDe(destino)}.');
        continue;
      }
      quedan.add(j);
    }
    return RotacionPlantel(quedan, mov);
  }

  /// Contratos del plantel después de la rotación: los que siguen bajan un año (o renuevan), los nuevos reciben uno.
  /// Devuelve los nuevos `uso` y las líneas de llegadas.
  static (Map<String, int>, List<String>) contratos(
    EstadoCarrera e,
    List<Jugador> anteriores,
    List<Jugador> nuevos,
    Random azar, {
    required int anio,
  }) {
    final uso = {
      for (final x in e.uso.entries)
        if (!x.key.startsWith('ct:')) x.key: x.value,
    };
    final antes = {for (final j in anteriores) j.id};
    final llegadas = <String>[];
    final etiqueta = e.etiquetaDe(e.numero + 1);
    for (final j in nuevos) {
      if (antes.contains(j.id)) {
        final restan = contratoDe(e, j) - 1;
        uso['ct:${j.id}'] = restan <= 0 ? 1 + azar.nextInt(3) : restan;
      } else {
        uso['ct:${j.id}'] = 1 + azar.nextInt(4);
        final novato = j.draft?.$1 == anio || edadEn(j, anio) <= 21;
        final como = novato ? 'novato del draft' : (azar.nextBool() ? 'por traspaso' : 'como agente libre');
        llegadas.add('$etiqueta: llega ${j.nombre} ($como).');
      }
    }
    return (uso, llegadas);
  }

  /// Contratos iniciales (1 a 4 años) para los compañeros que todavía no tienen.
  static Map<String, int> contratosIniciales(EstadoCarrera e, Random azar) => {
    ...e.uso,
    for (final j in e.companeros)
      if (!e.uso.containsKey('ct:${j.id}')) 'ct:${j.id}': 1 + azar.nextInt(4),
  };
}

/// Qué hacés en la fecha límite de traspasos (partido 49 de la temporada regular).
enum OpcionFechaLimite {
  quedarme('Quedarme', 'Pasás la fecha límite sin tocar nada.'),
  pedirTraspaso(
    'Pedir el traspaso',
    'Le decís al club que querés irte: en el receso se te ofrecen otros equipos, pero te cuesta con el vestuario y el DT.',
  ),
  extender('Extender el contrato', 'Un año más con el club: confianza del DT y fans, y tranquilidad para seguir.');

  const OpcionFechaLimite(this.etiqueta, this.descripcion);
  final String etiqueta, descripcion;
}
