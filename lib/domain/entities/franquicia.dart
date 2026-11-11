import '../../core/nba_cdn.dart';

enum Conferencia {
  este('Conferencia Este'),
  oeste('Conferencia Oeste');

  const Conferencia(this.etiqueta);
  final String etiqueta;
}

/// Las divisiones definen el calendario oficial de 82 partidos (4 vs. rivales de división).
enum Division {
  atlantico('Atlántico', Conferencia.este),
  central('Central', Conferencia.este),
  sureste('Sureste', Conferencia.este),
  noroeste('Noroeste', Conferencia.oeste),
  pacifico('Pacífico', Conferencia.oeste),
  suroeste('Suroeste', Conferencia.oeste);

  const Division(this.etiqueta, this.conferencia);
  final String etiqueta;
  final Conferencia conferencia;
}

/// Franquicia base (GDD §2). Los colores van como ARGB (0xAARRGGBB) para que el dominio
/// no dependa de Flutter; la capa de presentación los convierte con `Color(valor)`.
class Franquicia {
  const Franquicia({
    required this.id,
    required this.nbaTeamId,
    required this.ciudad,
    required this.nombre,
    required this.division,
    required this.colorPrimario,
    required this.colorSecundario,
  });

  /// Abreviatura oficial, p. ej. 'CHI'.
  final String id;
  final int nbaTeamId;
  final String ciudad;
  final String nombre;
  final Division division;
  final int colorPrimario;
  final int colorSecundario;

  Conferencia get conferencia => division.conferencia;
  String get nombreCompleto => '$ciudad $nombre';
  String get logoUrl => NbaCdn.logo(nbaTeamId);

  @override
  bool operator ==(Object other) => other is Franquicia && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
