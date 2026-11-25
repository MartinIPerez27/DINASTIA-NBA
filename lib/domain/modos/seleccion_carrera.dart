import 'dart:math';

import 'carrera_jugador.dart';

/// Un país con su selección de básquet (fuerza de 0 a 100, parecida a una media de carta).
class Pais {
  const Pais(this.nombre, this.fuerza);
  final String nombre;
  final int fuerza;
}

/// Resultado de un torneo con tu selección.
enum ResultadoTorneo {
  oro('Medalla de oro', 3),
  plata('Medalla de plata', 2),
  bronce('Medalla de bronce', 1),
  cuarto('4.º puesto', 0),
  cuartos('Cuartos de final', 0),
  grupos('Primera fase', 0);

  const ResultadoTorneo(this.etiqueta, this.fans);
  final String etiqueta;

  /// Fans que suma al volver.
  final int fans;
}

/// Lo que pasó en un torneo con tu selección.
class TorneoJugado {
  const TorneoJugado({required this.nombre, required this.pais, required this.rol, required this.resultado, required this.pts});
  final String nombre;
  final Pais pais;

  /// 0 no convocado, 1 suplente, 2 titular.
  final int rol;
  final ResultadoTorneo? resultado;
  final double pts;
}

/// Selección nacional: Mundial y Juegos Olímpicos cada 4 temporadas (3.ª, 7.ª, 11.ª…).
/// Se simulan con tu nivel (no se juegan en vivo). Se guarda en [EstadoCarrera.uso]:
/// `sn:conv` convocatorias, `sn:oro`/`sn:plata`/`sn:bronce`, `sn:pts100` puntos por partido del último torneo.
class SeleccionCarrera {
  SeleccionCarrera._();

  static const paises = <Pais>[
    Pais('Estados Unidos', 95),
    Pais('España', 86),
    Pais('Serbia', 86),
    Pais('Francia', 85),
    Pais('Canadá', 84),
    Pais('Alemania', 83),
    Pais('Argentina', 82),
    Pais('Eslovenia', 80),
    Pais('Australia', 80),
    Pais('Grecia', 79),
    Pais('Lituania', 78),
    Pais('Italia', 77),
    Pais('Brasil', 75),
    Pais('Nigeria', 72),
    Pais('Puerto Rico', 70),
    Pais('Japón', 68),
    Pais('Otro país', 64),
  ];

  /// Cada cuántas temporadas hay torneo, y en cuál es el primero.
  static const cadaTemporadas = 4, primera = 3;

  static bool hayTorneo(int numero) => numero >= primera && (numero - primera) % cadaTemporadas == 0;

  static String nombreTorneo(int numero) => ((numero - primera) ~/ cadaTemporadas).isEven ? 'Mundial' : 'Juegos Olímpicos';

  /// Temporadas que faltan para el próximo torneo (0 = es este año).
  static int faltan(int numero) {
    if (numero <= primera) return primera - numero;
    return (cadaTemporadas - (numero - primera) % cadaTemporadas) % cadaTemporadas;
  }

  /// País elegido (solo los jugadores creados lo tienen).
  static Pais? paisDe(EstadoCarrera e) {
    final i = e.creado?.estilo?.pais;
    return i == null ? null : paises[i.clamp(0, paises.length - 1)];
  }

  static int convocatorias(EstadoCarrera e) => e.uso['sn:conv'] ?? 0;
  static int medallas(EstadoCarrera e) => (e.uso['sn:oro'] ?? 0) + (e.uso['sn:plata'] ?? 0) + (e.uso['sn:bronce'] ?? 0);

  /// Convocatoria: 2 titular, 1 suplente, 0 afuera (a veces lo definen los técnicos al azar si estás cerca).
  static int rolEn(Pais p, int media, Random azar) {
    final umbral = p.fuerza - 14;
    if (media >= p.fuerza - 4) return 2;
    if (media >= umbral) return 1;
    return media >= umbral - 6 && azar.nextBool() ? 1 : 0;
  }

  /// Juega el torneo del año [numero] con tu nivel [media] y tus puntos de la temporada [ppg].
  static TorneoJugado? jugar(EstadoCarrera e, {required int media, required double ppg}) {
    final pais = paisDe(e);
    if (pais == null || !hayTorneo(e.numero)) return null;
    final azar = Random(_hash('${e.raiz}-torneo-${e.numero}'));
    final rol = rolEn(pais, media, azar);
    final nombre = nombreTorneo(e.numero);
    if (rol == 0) return TorneoJugado(nombre: nombre, pais: pais, rol: 0, resultado: null, pts: 0);
    final aporte = ((media - (pais.fuerza - 8)) * (rol == 2 ? 0.3 : 0.15)).clamp(-2.0, 8.0);
    final propia = pais.fuerza + aporte;
    final rivales = [for (final p in paises) if (p != pais && p.nombre != 'Otro país') p.fuerza.toDouble()]..sort((a, b) => b.compareTo(a));
    bool gana(double rival) => azar.nextDouble() < 1 / (1 + exp(-(propia - rival) / 5));
    double rival(int desde, int hasta) => rivales[desde + azar.nextInt(hasta - desde + 1)];
    var victorias = 0;
    for (var i = 0; i < 3; i++) {
      if (gana(rival(4, rivales.length - 1))) victorias++;
    }
    final pts = ppg * (rol == 2 ? 0.8 : 0.5) * (0.85 + azar.nextDouble() * 0.3);
    ResultadoTorneo r;
    if (victorias < 2) {
      r = ResultadoTorneo.grupos;
    } else if (!gana(rival(2, 7))) {
      r = ResultadoTorneo.cuartos;
    } else if (!gana(rival(1, 4))) {
      r = gana(rival(3, 8)) ? ResultadoTorneo.bronce : ResultadoTorneo.cuarto;
    } else {
      r = gana(rival(0, 2)) ? ResultadoTorneo.oro : ResultadoTorneo.plata;
    }
    return TorneoJugado(nombre: nombre, pais: pais, rol: rol, resultado: r, pts: pts);
  }

  /// Suma el torneo al estado (contadores, hito y fans). [e] es el estado ya cerrado de la temporada.
  static EstadoCarrera aplicar(EstadoCarrera e, TorneoJugado t, String etiqueta) {
    final r = t.resultado;
    if (r == null) {
      return e.copyWith(movimientos: [...e.movimientos, '$etiqueta: no te convocaron al ${t.nombre} con ${t.pais.nombre}.']);
    }
    final texto = '$etiqueta: ${t.nombre} con ${t.pais.nombre} (${t.rol == 2 ? 'titular' : 'suplente'}): '
        '${r.etiqueta.toLowerCase()}, ${t.pts.toStringAsFixed(1).replaceAll('.', ',')} pts por partido.';
    return e.copyWith(
      uso: {
        ...e.uso,
        'sn:conv': convocatorias(e) + 1,
        if (r == ResultadoTorneo.oro) 'sn:oro': (e.uso['sn:oro'] ?? 0) + 1,
        if (r == ResultadoTorneo.plata) 'sn:plata': (e.uso['sn:plata'] ?? 0) + 1,
        if (r == ResultadoTorneo.bronce) 'sn:bronce': (e.uso['sn:bronce'] ?? 0) + 1,
        'sn:pts100': (t.pts * 100).round(),
      },
      fans: (e.fans + r.fans + 1).clamp(0, 98),
      confianza: (e.confianza + 1).clamp(0, 98),
      hitos: [...e.hitos, texto],
      movimientos: [...e.movimientos, texto],
    );
  }

  static int _hash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);
}
