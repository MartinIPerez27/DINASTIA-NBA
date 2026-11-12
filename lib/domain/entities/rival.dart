import 'jugador.dart';
import 'posicion.dart';
import 'tactica.dart';

/// Cómo arma su plantel un rival en esta temporada.
enum TipoRival {
  historico('Histórico', 'Lo mejor de toda su historia'),
  epoca('Época', 'Su plantel real de una década');

  const TipoRival(this.nombre, this.descripcion);
  final String nombre;
  final String descripcion;
}

/// Plantel y táctica de una franquicia rival para la temporada.
class Rival {
  const Rival({
    required this.franquiciaId,
    required this.tipo,
    required this.identidadId,
    required this.cartaIds,
    required this.tactica,
    this.epoca,
  });

  final String franquiciaId;
  final TipoRival tipo;
  final Epoca? epoca;

  /// Con qué identidad juega (p. ej. 'SEA' si son los Thunder de los 90).
  final String identidadId;
  final Map<Posicion, String> cartaIds;
  final Tactica tactica;

  factory Rival.fromJson(Map<String, dynamic> j) => Rival(
    franquiciaId: j['franquicia'] as String,
    tipo: TipoRival.values.byName(j['tipo'] as String),
    epoca: j['epoca'] == null ? null : Epoca.values.byName(j['epoca'] as String),
    identidadId: j['identidad'] as String,
    cartaIds: {
      for (final e in (j['cartas'] as Map<String, dynamic>).entries) Posicion.values.byName(e.key): e.value as String,
    },
    tactica: Tactica.fromJson(j['tactica'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'franquicia': franquiciaId,
    'tipo': tipo.name,
    if (epoca != null) 'epoca': epoca!.name,
    'identidad': identidadId,
    'cartas': {for (final e in cartaIds.entries) e.key.name: e.value},
    'tactica': tactica.toJson(),
  };
}
