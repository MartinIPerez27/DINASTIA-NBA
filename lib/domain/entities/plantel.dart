import 'jugador.dart';
import 'posicion.dart';

class ReglaPlantelException implements Exception {
  const ReglaPlantelException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Quinteto + Sexto Hombre. Inmutable: [asignar] devuelve un plantel nuevo.
///
/// Regla inquebrantable (GDD §3.3): una posición ocupada queda bloqueada y nunca
/// acepta un segundo jugador. Tampoco se repite la misma persona con otra carta.
class Plantel {
  const Plantel() : _puestos = const {};
  const Plantel._(this._puestos);

  final Map<Posicion, Jugador> _puestos;

  Jugador? en(Posicion p) => _puestos[p];
  bool estaOcupada(Posicion p) => _puestos.containsKey(p);
  bool get completo => _puestos.length == Posicion.values.length;
  Iterable<Jugador> get jugadores => _puestos.values;

  List<Jugador> get titulares => [for (final p in Posicion.titulares) ?_puestos[p]];

  Jugador? get sextoHombre => _puestos[Posicion.sextoHombre];

  bool contiene(Jugador j) => _puestos.values.any((x) => x.nbaPlayerId == j.nbaPlayerId);

  /// Puestos vacíos donde [j] puede entrar. Vacío si ya está en el plantel.
  List<Posicion> posicionesDisponiblesPara(Jugador j) => contiene(j)
      ? const []
      : [
          for (final p in Posicion.values)
            if (!estaOcupada(p) && j.puedeJugarEn(p)) p,
        ];

  Plantel asignar(Jugador j, Posicion p) {
    if (estaOcupada(p)) {
      throw ReglaPlantelException('${p.etiqueta} ya está ocupado por ${_puestos[p]!.nombre}.');
    }
    if (contiene(j)) throw ReglaPlantelException('${j.nombre} ya forma parte del plantel.');
    if (!j.puedeJugarEn(p)) {
      throw ReglaPlantelException('${j.nombre} no es elegible como ${p.etiqueta}.');
    }
    return Plantel._(Map.unmodifiable({..._puestos, p: j}));
  }

  factory Plantel.fromJson(Map<String, dynamic> j) {
    var plantel = const Plantel();
    j.forEach((pos, jugador) {
      plantel = plantel.asignar(Jugador.fromJson(jugador as Map<String, dynamic>), Posicion.values.byName(pos));
    });
    return plantel;
  }

  Map<String, dynamic> toJson() => {for (final e in _puestos.entries) e.key.name: e.value.toJson()};
}
