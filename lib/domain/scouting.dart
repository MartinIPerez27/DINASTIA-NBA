import 'entities/jugador.dart';

// Scouting de rivales para los modos (ficha del rival) y eventos aleatorios con peso. Dominio puro.

/// Qué tan peligroso es el rival comparado con tu plantel.
enum Amenaza {
  baja('Baja'),
  media('Media'),
  alta('Alta'),
  extrema('Extrema');

  const Amenaza(this.etiqueta);
  final String etiqueta;
}

/// Lectura rápida de un plantel rival: figuras, fortaleza, punto débil y amenaza.
class FichaScouting {
  const FichaScouting({
    required this.figuras,
    required this.fuerte,
    required this.debil,
    required this.media,
    required this.amenaza,
    required this.diferencia,
  });

  /// Las tres mejores cartas del rival, de mayor a menor media.
  final List<Jugador> figuras;

  /// "Triples", "Rebote", "Creación", "Defensa" o "Anotación".
  final String fuerte, debil;
  final double media;
  final Amenaza amenaza;

  /// Media del rival menos la tuya (positivo: es más fuerte).
  final double diferencia;

  /// "Más fuerte que vos por 3,1" / "Parejo" / "Más débil por 2,0".
  String get comparacion {
    String n(double v) => v.abs().toStringAsFixed(1).replaceAll('.', ',');
    if (diferencia.abs() < 0.5) return 'Parejo con tu plantel';
    return diferencia > 0 ? 'Más fuerte que vos por ${n(diferencia)}' : 'Más débil que vos por ${n(diferencia)}';
  }

  static double _mediaDe(List<Jugador> js) => js.isEmpty ? 0 : js.fold<double>(0, (a, j) => a + j.media) / js.length;

  /// Ficha del rival [plantel] frente a tus [propios].
  static FichaScouting de(List<Jugador> plantel, {List<Jugador> propios = const []}) {
    final ordenados = [...plantel]..sort((a, b) => b.media.compareTo(a.media));
    double suma(double Function(Jugador) f) => plantel.fold<double>(0, (a, j) => a + f(j));
    final n = plantel.isEmpty ? 1 : plantel.length / 6;
    // Cada categoría contra una referencia típica de un plantel de 6 cartas.
    final categorias = <String, double>{
      'Triples': plantel.isEmpty ? 0 : suma((j) => j.stats.pctT3) / plantel.length / 0.36,
      'Rebote': suma((j) => j.stats.rpp) / n / 33,
      'Creación': suma((j) => j.stats.app) / n / 20,
      'Defensa': suma((j) => j.stats.robP + j.stats.tapP) / n / 8,
      'Anotación': suma((j) => j.stats.ppp) / n / 105,
    };
    final orden = categorias.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final media = _mediaDe(plantel);
    final dif = propios.isEmpty ? 0.0 : media - _mediaDe(propios);
    return FichaScouting(
      figuras: ordenados.take(3).toList(),
      fuerte: orden.isEmpty ? 'Anotación' : orden.first.key,
      debil: orden.isEmpty ? 'Rebote' : orden.last.key,
      media: media,
      diferencia: dif,
      amenaza: dif >= 4
          ? Amenaza.extrema
          : dif >= 1.5
          ? Amenaza.alta
          : dif >= -1.5
          ? Amenaza.media
          : Amenaza.baja,
    );
  }
}

enum TipoEventoCruce { figuraLesionada, rivalEnRacha, rivalCansado, hinchadaEncendida }

/// Un hecho aleatorio (pero determinista por partida y cruce) que cambia levemente el cruce y SIEMPRE se
/// muestra en pantalla con su efecto: la corrida se siente distinta sin esconder números.
class EventoCruce {
  const EventoCruce({
    required this.tipo,
    required this.titulo,
    required this.texto,
    required this.efecto,
    this.rivalMenos = 0,
    this.propioMas = 0,
    this.rivalCansado = false,
  });

  final TipoEventoCruce tipo;
  final String titulo, texto;

  /// Lo que se ve en pantalla: "Rival −2 de forma".
  final String efecto;

  /// Puntos de forma que se le restan al rival (negativo: se le suman).
  final int rivalMenos;

  /// Puntos de forma que se te suman.
  final int propioMas;
  final bool rivalCansado;

  /// Probabilidad de que haya un evento en un cruce.
  static const probabilidad = 0.4;

  static int _h(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// El evento del cruce [indice] de la partida [partidaId] contra un rival con [figura] como mejor carta
  /// y llamado [rival] ("Bulls 95-96"); null si ese cruce no tiene.
  static EventoCruce? de(String partidaId, int indice, {required Jugador? figura, required String rival}) {
    final h = _h('$partidaId|evento|$indice');
    if ((h % 1000) / 1000 >= probabilidad) return null;
    final dado = (h ~/ 1000) % 100;
    final nombre = figura?.nombre;
    if (dado < 40 && nombre != null) {
      return EventoCruce(
        tipo: TipoEventoCruce.figuraLesionada,
        titulo: 'BAJA EN EL RIVAL',
        texto: '$nombre llega tocado: los $rival sufren la ausencia de su figura.',
        efecto: 'Rival −2 de forma',
        rivalMenos: 2,
      );
    }
    if (dado < 70) {
      return EventoCruce(
        tipo: TipoEventoCruce.rivalEnRacha,
        titulo: 'RIVAL ENCENDIDO',
        texto: 'Los $rival llegan en racha y con la confianza por las nubes.',
        efecto: 'Rival +1 de forma',
        rivalMenos: -1,
      );
    }
    if (dado < 85) {
      return EventoCruce(
        tipo: TipoEventoCruce.rivalCansado,
        titulo: 'RIVAL CANSADO',
        texto: 'Los $rival vienen de un viaje largo y llegan con las piernas pesadas.',
        efecto: 'Rival arranca cansado',
        rivalCansado: true,
      );
    }
    return const EventoCruce(
      tipo: TipoEventoCruce.hinchadaEncendida,
      titulo: 'HINCHADA ENCENDIDA',
      texto: 'La gente se hizo sentir: noche de pasión en las tribunas.',
      efecto: 'Tu plantel +1 de forma',
      propioMas: 1,
    );
  }
}
