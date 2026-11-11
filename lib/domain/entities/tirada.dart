import 'jugador.dart';

/// Los 3 carretes del tragamonedas (GDD §4.2).
enum Carrete {
  franquicia('Franquicia'),
  epoca('Época'),
  rareza('Rareza');

  const Carrete(this.etiqueta);
  final String etiqueta;

  bool coincide(Jugador j, Tirada t) => switch (this) {
    Carrete.franquicia => j.franquiciaId == t.franquiciaId,
    Carrete.epoca => j.epoca == t.epoca,
    Carrete.rareza => j.tier == t.tier,
  };
}

/// Resultado de los 3 carretes: dónde frenó cada uno.
class Tirada {
  const Tirada({required this.franquiciaId, required this.epoca, required this.tier});

  Tirada.de(Jugador j) : this(franquiciaId: j.franquiciaId, epoca: j.epoca, tier: j.tier);

  final String franquiciaId;
  final Epoca epoca;
  final Tier tier;

  bool admite(Jugador j) => Carrete.values.every((c) => c.coincide(j, this));

  factory Tirada.fromJson(Map<String, dynamic> j) => Tirada(
    franquiciaId: j['franquicia'] as String,
    epoca: Epoca.values.byName(j['epoca'] as String),
    tier: Tier.values.byName(j['tier'] as String),
  );

  Map<String, dynamic> toJson() => {'franquicia': franquiciaId, 'epoca': epoca.name, 'tier': tier.name};

  @override
  bool operator ==(Object other) =>
      other is Tirada && other.franquiciaId == franquiciaId && other.epoca == epoca && other.tier == tier;

  @override
  int get hashCode => Object.hash(franquiciaId, epoca, tier);
}
