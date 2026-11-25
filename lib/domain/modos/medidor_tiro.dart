import '../decisiones_partido.dart' show PerfilVivo;
import '../motor.dart' show ModoMedidor, MomentoPendiente, TipoMomento;
import 'carrera_jugador.dart';

// La barra de tiro: una barra que se llena y hay que soltar (o tocar) en la zona verde. Cuánto mide la zona
// depende de lo que sabe tu jugador; cuándo soltás decide el acierto de ese tiro (o lo bien que defendés al rival).

/// Cómo salió el timing.
enum CalidadTiro {
  perfecto('¡PERFECTO!'),
  bueno('Bien'),
  temprano('Temprano'),
  tarde('Tarde');

  const CalidadTiro(this.etiqueta);
  final String etiqueta;
}

/// Cómo querés jugar el control del partido (se guarda en la carrera).
class AjustesMedidor {
  const AjustesMedidor({this.modo = ModoMedidor.importantes, this.zona = 1, this.mantener = false, this.extras = const {}});

  final ModoMedidor modo;

  /// Tamaño de la zona verde: 0 chica (más desafío), 1 normal, 2 grande (más fácil).
  final int zona;

  /// Soltar el dedo (mantener apretado mientras se llena) en vez de tocar.
  final bool mantener;

  /// Momentos extra que también querés jugar con la barra (libres, rebote, robo y pase). El tiro y tu defensa directa van siempre.
  final Set<TipoMomento> extras;

  static const posiblesExtras = [TipoMomento.libres, TipoMomento.rebote, TipoMomento.robo, TipoMomento.pase];

  /// Los momentos que frenan el partido con estos ajustes.
  Set<TipoMomento> get momentos => {TipoMomento.tiro, TipoMomento.defensa, ...extras};

  static const nombresZona = ['Chica', 'Normal', 'Grande'];
  static const factorZona = [0.8, 1.0, 1.35];

  AjustesMedidor copyWith({ModoMedidor? modo, int? zona, bool? mantener, Set<TipoMomento>? extras}) =>
      AjustesMedidor(modo: modo ?? this.modo, zona: zona ?? this.zona, mantener: mantener ?? this.mantener, extras: extras ?? this.extras);

  static AjustesMedidor de(EstadoCarrera e) => AjustesMedidor(
    modo: ModoMedidor.values[(e.uso['cfg:modo'] ?? 0).clamp(0, ModoMedidor.values.length - 1)],
    zona: (e.uso['cfg:zona'] ?? 1).clamp(0, 2),
    mantener: (e.uso['cfg:mantener'] ?? 0) == 1,
    extras: {
      for (final t in posiblesExtras)
        if ((e.uso['cfg:x:${t.name}'] ?? 0) == 1) t,
    },
  );

  /// Las marcas con que se guarda en `EstadoCarrera.uso`.
  Map<String, int> get aUso => {
    'cfg:modo': modo.index,
    'cfg:zona': zona,
    'cfg:mantener': mantener ? 1 : 0,
    for (final t in posiblesExtras) 'cfg:x:${t.name}': extras.contains(t) ? 1 : 0,
  };
}

class MedidorTiro {
  const MedidorTiro._();

  /// Dónde está el centro de la zona verde (0 = barra vacía, 1 = llena).
  static const centro = 0.82;

  /// Cuánto dura llenarse la barra.
  static double segundos(PerfilVivo y) => switch (y.formaDeTiro) {
    1 => 0.85, // Rápido
    4 => 1.15, // Muñeca suelta
    _ => 1.0,
  };

  /// Ancho de la zona verde (fracción de la barra): crece con tu habilidad y con lo abierto que está el tiro, y se
  /// ajusta con tu forma de tirar y con la opción de tamaño.
  static double ventana(PerfilVivo y, MomentoPendiente m) {
    final double habilidad;
    if (m.tipo == TipoMomento.libres) {
      habilidad = y.prom([Habilidad.tiroLibre, Habilidad.tiroLibre, Habilidad.triple]);
    } else if (m.tipo == TipoMomento.rebote) {
      habilidad = y.prom([Habilidad.rebote, Habilidad.reboteOfensivo, Habilidad.fuerza]);
    } else if (m.tipo == TipoMomento.robo) {
      habilidad = y.prom([Habilidad.robo, Habilidad.velocidadLateral, Habilidad.defPerimetral]);
    } else if (m.tipo == TipoMomento.pase) {
      habilidad = y.prom([Habilidad.pase, Habilidad.manejo, Habilidad.vision]);
    } else if (m.tipo == TipoMomento.defensa) {
      habilidad = y.prom([Habilidad.defPerimetral, Habilidad.velocidadLateral, Habilidad.robo, Habilidad.tapon]);
    } else if (m.triple) {
      habilidad = y.prom([Habilidad.triple, Habilidad.tiroEnMovimiento, Habilidad.tiroDeEsquina]);
    } else {
      habilidad = y.prom([Habilidad.mediaDistancia, Habilidad.bandeja, Habilidad.tiroCercano, Habilidad.finalizacionContacto]);
    }
    var base = 0.09 + (habilidad - 60) * 0.0028;
    // Un tiro difícil (acierto bajo) achica la zona; uno limpio la agranda (los momentos extra no dependen de eso).
    if (m.tipo == TipoMomento.tiro || m.tipo == TipoMomento.defensa) {
      base *= (0.6 + 0.8 * m.probabilidad).clamp(0.5, 1.3);
    }
    if (m.tipo == TipoMomento.tiro) {
      base *= switch (y.formaDeTiro) {
        2 => m.triple ? 1.1 : 1.0, // Alto y liviano
        3 => 0.95, // Salto hacia atrás
        4 => 1.05, // Muñeca suelta
        _ => 1.0,
      };
    }
    return (base * AjustesMedidor.factorZona[y.ajustes.zona]).clamp(0.05, 0.3);
  }

  /// La calidad de soltar en [punto] (0 a 1) con una zona verde de ancho [ventana].
  static CalidadTiro evaluar(double punto, double ventana) {
    final d = punto - centro;
    if (d.abs() <= ventana * 0.2) return CalidadTiro.perfecto;
    if (d.abs() <= ventana * 0.5) return CalidadTiro.bueno;
    return d < 0 ? CalidadTiro.temprano : CalidadTiro.tarde;
  }

  /// Lo que suma (o resta) a la chance de acierto de tu tiro.
  static double deltaTiro(CalidadTiro q) => switch (q) {
    CalidadTiro.perfecto => 0.15,
    CalidadTiro.bueno => 0.05,
    CalidadTiro.temprano => -0.09,
    CalidadTiro.tarde => -0.12,
  };

  /// Lo que suma tu timing en los momentos extra, a favor de tu equipo (siempre positivo si saliste bien).
  static double efectoExtra(TipoMomento t, CalidadTiro q) => switch (t) {
    TipoMomento.libres => switch (q) {
      CalidadTiro.perfecto => 0.08,
      CalidadTiro.bueno => 0.03,
      CalidadTiro.temprano => -0.05,
      CalidadTiro.tarde => -0.08,
    },
    TipoMomento.rebote => switch (q) {
      CalidadTiro.perfecto => 0.12,
      CalidadTiro.bueno => 0.04,
      CalidadTiro.temprano => -0.04,
      CalidadTiro.tarde => -0.08,
    },
    TipoMomento.robo => switch (q) {
      CalidadTiro.perfecto => 0.12,
      CalidadTiro.bueno => 0.04,
      CalidadTiro.temprano => 0.0,
      CalidadTiro.tarde => -0.03,
    },
    TipoMomento.pase => switch (q) {
      CalidadTiro.perfecto => 0.06,
      CalidadTiro.bueno => 0.02,
      CalidadTiro.temprano => -0.02,
      CalidadTiro.tarde => -0.04,
    },
    _ => 0.0,
  };

  /// Defendiendo: lo que cambia el acierto del rival y la chance de tapón.
  static (double, double) efectoDefensa(CalidadTiro q) => switch (q) {
    CalidadTiro.perfecto => (-0.14, 0.10),
    CalidadTiro.bueno => (-0.05, 0.03),
    CalidadTiro.temprano => (0.03, 0.0),
    CalidadTiro.tarde => (0.06, 0.0),
  };
}
