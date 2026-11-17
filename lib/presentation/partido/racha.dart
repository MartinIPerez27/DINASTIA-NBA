import '../../domain/motor.dart';

/// Lleva la cuenta de rachas del partido para el marcador y la cancha: quién está "en llamas" (3 tiros
/// de campo seguidos metidos) y el parcial del momento (puntos seguidos de un equipo sin respuesta).
class RachaTiradores {
  final _seguidos = <String, int>{};
  bool? _localRacha;
  int _puntosRacha = 0;

  /// Anota una jugada del motor (en orden).
  void registrar(EventoPartido e) {
    if (e.tipo == TipoEvento.tiro && e.jugadorId != null) {
      final id = e.jugadorId!;
      _seguidos[id] = e.convertido ? (_seguidos[id] ?? 0) + 1 : 0;
    }
    if (e.puntos > 0) {
      if (_localRacha == e.local) {
        _puntosRacha += e.puntos;
      } else {
        _localRacha = e.local;
        _puntosRacha = e.puntos;
      }
    }
  }

  /// Aciertos seguidos de [id].
  int seguidos(String id) => _seguidos[id] ?? 0;

  bool enLlamas(String id) => seguidos(id) >= 3;

  /// El jugador más encendido: (id, aciertos seguidos) o null.
  (String, int)? get masEncendido {
    (String, int)? mejor;
    for (final e in _seguidos.entries) {
      if (e.value >= 3 && (mejor == null || e.value > mejor.$2)) mejor = (e.key, e.value);
    }
    return mejor;
  }

  /// Parcial en curso: (¿es del local?, puntos) si pasa de 6 puntos seguidos; si no, null.
  (bool, int)? get parcial => _localRacha != null && _puntosRacha >= 7 ? (_localRacha!, _puntosRacha) : null;
}
