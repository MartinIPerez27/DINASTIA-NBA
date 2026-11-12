import 'dart:math';

import 'entities/entrenador.dart';
import 'entities/jugador.dart';

enum TipoVinculo {
  franquicia('Misma franquicia', 1),
  epoca('Misma época', 1),
  companeros('Compañeros de época', 3),
  duo('Dúo legendario', 6),
  entrenador('Los dirigió', 2);

  const TipoVinculo(this.nombre, this.puntos);
  final String nombre;
  final int puntos;
}

/// Un lazo entre dos cartas (o entre una carta y el entrenador).
class Vinculo {
  const Vinculo(this.tipo, this.a, this.b, {this.nombreDuo});

  final TipoVinculo tipo;
  final String a; // id de carta
  final String b; // id de carta, o id de entrenador
  final String? nombreDuo;
}

/// Química estilo Ultimate Team (GDD: metajuego): misma franquicia, misma época, compañeros reales
/// y dúos legendarios. Va de 0 a 100 y en el motor vale hasta ±1 punto de acierto.
class Quimica {
  Quimica._(this.puntaje, this.vinculos);

  final int puntaje;
  final List<Vinculo> vinculos;

  /// Puntos que llevan al 100 (un plantel de compañeros de la misma época llega solo).
  static const _tope = 36;

  /// Dúos legendarios por id de Basketball-Reference (prefijo del id de carta).
  static const duos = <(String, String, String)>[
    ('jordami01', 'pippesc01', 'Jordan y Pippen'),
    ('jordami01', 'rodmade01', 'Jordan y Rodman'),
    ('onealsh01', 'bryanko01', 'Shaq y Kobe'),
    ('stockjo01', 'malonka01', 'Stockton y Malone'),
    ('johnsma02', 'abdulka01', 'Magic y Kareem'),
    ('johnsma02', 'worthja01', 'Magic y Worthy'),
    ('birdla01', 'mchalke01', 'Bird y McHale'),
    ('birdla01', 'parisro01', 'Bird y Parish'),
    ('curryst01', 'thompkl01', 'Splash Brothers'),
    ('curryst01', 'greendr01', 'Curry y Green'),
    ('thompkl01', 'duranke01', 'Thompson y Durant'),
    ('jamesle01', 'wadedw01', 'LeBron y Wade'),
    ('jamesle01', 'irvinky01', 'LeBron e Irving'),
    ('jamesle01', 'davisan02', 'LeBron y Davis'),
    ('duncati01', 'parketo01', 'Duncan y Parker'),
    ('duncati01', 'ginobma01', 'Duncan y Ginóbili'),
    ('parketo01', 'ginobma01', 'Parker y Ginóbili'),
    ('duncati01', 'robinda01', 'Las Torres Gemelas'),
    ('duncati01', 'leonaka01', 'Duncan y Leonard'),
    ('russebi01', 'cousybo01', 'Russell y Cousy'),
    ('westje01', 'bayloel01', 'West y Baylor'),
    ('chambwi01', 'westje01', 'Wilt y West'),
    ('nashst01', 'stoudam01', 'Nash y Amar’e'),
    ('paulch01', 'griffbl01', 'Lob City'),
    ('duranke01', 'westbru01', 'Durant y Westbrook'),
    ('hardeja01', 'duranke01', 'Harden y Durant'),
    ('garneke01', 'piercpa01', 'Garnett y Pierce'),
    ('allenra02', 'garneke01', 'Allen y Garnett'),
    ('thomais01', 'dumarjo01', 'Isiah y Dumars'),
    ('fraziwa01', 'reedwi01', 'Clyde y Reed'),
    ('olajuha01', 'drexlcl01', 'Hakeem y Drexler'),
    ('paytoga01', 'kempsh01', 'Payton y Kemp'),
    ('ervinju01', 'malonmo01', 'Dr. J y Moses'),
    ('hardaan01', 'onealsh01', 'Penny y Shaq'),
    ('nowitdi01', 'terryja01', 'Dirk y Terry'),
    ('bryanko01', 'gasolpa01', 'Kobe y Pau'),
    ('jokicni01', 'murraja01', 'Jokić y Murray'),
    ('antetgi01', 'middlkh01', 'Giannis y Middleton'),
    ('tatumja01', 'brownja02', 'Tatum y Brown'),
    ('mullich01', 'hardati01', 'Run TMC: Mullin y Hardaway'),
    ('richmmi01', 'mullich01', 'Run TMC: Richmond y Mullin'),
    ('millere01', 'smitsri01', 'Miller y Smits'),
    ('ewingpa01', 'oaklech01', 'Ewing y Oakley'),
    ('iversal01', 'mutomdi01', 'Iverson y Mutombo'),
  ];

  static final _indiceDuos = {
    for (final (a, b, nombre) in duos) ...{'$a|$b': nombre, '$b|$a': nombre},
  };

  static String? nombreDuo(Jugador a, Jugador b) => _indiceDuos['${a.idBbref}|${b.idBbref}'];

  static Quimica de(Iterable<Jugador> jugadores, {Entrenador? entrenador}) {
    final js = jugadores.toList();
    final vinculos = <Vinculo>[];
    for (var i = 0; i < js.length; i++) {
      for (var k = i + 1; k < js.length; k++) {
        final a = js[i], b = js[k];
        if (nombreDuo(a, b) case final nombre?) {
          vinculos.add(Vinculo(TipoVinculo.duo, a.id, b.id, nombreDuo: nombre));
        } else if (a.equipo == b.equipo && a.epoca == b.epoca) {
          vinculos.add(Vinculo(TipoVinculo.companeros, a.id, b.id));
        } else if (a.franquiciaId == b.franquiciaId) {
          vinculos.add(Vinculo(TipoVinculo.franquicia, a.id, b.id));
        } else if (a.epoca == b.epoca) {
          vinculos.add(Vinculo(TipoVinculo.epoca, a.id, b.id));
        }
      }
    }
    if (entrenador != null) {
      for (final j in js) {
        if (entrenador.franquicias.contains(j.franquiciaId) || entrenador.franquicias.contains(j.equipo)) {
          vinculos.add(Vinculo(TipoVinculo.entrenador, j.id, entrenador.id));
        }
      }
    }
    final puntos = vinculos.fold(0, (s, v) => s + v.tipo.puntos);
    return Quimica._(min(100, (puntos * 100 / _tope).round()), vinculos);
  }

  /// Efecto en el tiro: de −1 punto (química 0) a +1 punto (química 100).
  double get efectoTiro => (puntaje - 50) / 5000;
}
