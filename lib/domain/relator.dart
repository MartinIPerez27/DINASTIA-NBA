import 'dart:math';

import 'entities/jugador.dart';
import 'motor.dart';
import 'relato/relato.dart';

export 'relato/relato.dart';

/// Compatibilidad: una sola frase por jugada (el Relator y, si habló, el Comentarista, juntos).
/// La transmisión de dos voces vive en [Relato].
class Relator {
  Relator({Random? azar}) : _relato = Relato(azar: azar);

  final Relato _relato;

  String frase(EventoPartido e, Map<String, Jugador> jugadores) {
    final lineas = _relato.linea(e, ContextoRelato(jugadores: jugadores), siempre: true);
    final texto = lineas.map((l) => l.texto).join(' ').trim();
    return texto.isEmpty ? e.texto : texto;
  }
}
