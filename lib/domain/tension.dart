import 'entities/temporada.dart';

// Presión de los partidos clave (playoffs, series de escalera, torneos): qué tan decisivo es el
// próximo partido, con una etiqueta lista para banners y un número 0–100 para el indicador de tensión.
// Dominio puro: lo leen las pantallas de playoffs y de modos y, vía `ContextoNarrativo`, el relator.

/// Cuánta presión hay (para colorear y para el medidor de 5 segmentos).
enum NivelTension {
  normal('Partido normal'),
  importante('Partido importante'),
  alta('Presión alta'),
  critica('Todo o nada'),
  maxima('Máxima tensión');

  const NivelTension(this.etiqueta);
  final String etiqueta;

  /// Segmentos encendidos del medidor (1 a 5).
  int get segmentos => index + 1;
}

class PresionPartido {
  const PresionPartido({
    required this.etiqueta,
    required this.detalle,
    required this.nivel,
    required this.valor,
    this.decisivo = false,
    this.eliminacion = false,
    this.matchPoint = false,
    this.propias = 0,
    this.ajenas = 0,
    this.juego = 1,
  });

  /// Titular del banner: "PARTIDO 7", "ELIMINACIÓN", "MATCH POINT", "VENTAJA 3-1"…
  final String etiqueta;

  /// Una frase en voseo con lo que está en juego.
  final String detalle;
  final NivelTension nivel;

  /// 0–100.
  final int valor;

  /// Define la serie (el que gana pasa, el que pierde se va).
  final bool decisivo;

  /// Si perdés, te vas (para vos).
  final bool eliminacion;

  /// Si ganás, cerrás la serie.
  final bool matchPoint;
  final int propias, ajenas, juego;

  /// Marcador de la serie desde tu lado ("3-2").
  String get marcador => '$propias-$ajenas';
}

/// Calcula la presión de la serie (o partido único) que sigue. [aGanar]: victorias para ganar (1 = partido
/// único). [peso] suma tensión por la importancia de la ronda (0 a 10): Finales de la NBA, última etapa de un modo.
PresionPartido presion({required int aGanar, required int propias, required int ajenas, int peso = 0}) {
  final juego = propias + ajenas + 1;
  PresionPartido hacer(
    String etiqueta,
    String detalle,
    int valor, {
    bool decisivo = false,
    bool elim = false,
    bool mp = false,
  }) {
    final v = (valor + peso).clamp(0, 100);
    final nivel = v >= 95
        ? NivelTension.maxima
        : v >= 80
        ? NivelTension.critica
        : v >= 60
        ? NivelTension.alta
        : v >= 35
        ? NivelTension.importante
        : NivelTension.normal;
    return PresionPartido(
      etiqueta: etiqueta,
      detalle: detalle,
      nivel: nivel,
      valor: v,
      decisivo: decisivo,
      eliminacion: elim,
      matchPoint: mp,
      propias: propias,
      ajenas: ajenas,
      juego: juego,
    );
  }

  if (aGanar <= 1) {
    return hacer(
      'ELIMINACIÓN DIRECTA',
      'Un solo partido: el que pierde se va a su casa.',
      82,
      decisivo: true,
      elim: true,
      mp: true,
    );
  }
  final falta = aGanar - 1;
  if (propias == falta && ajenas == falta) {
    return hacer(
      'PARTIDO $juego',
      'Define la serie. El que gana sigue, el que pierde se va.',
      98,
      decisivo: true,
      elim: true,
      mp: true,
    );
  }
  if (ajenas == falta) {
    return hacer(
      'ELIMINACIÓN',
      propias == 0
          ? 'Estás a un partido de irte. No hay margen.'
          : 'Quedás $propias-$ajenas abajo: si perdés hoy, se terminó.',
      90,
      elim: true,
    );
  }
  if (propias == falta) {
    return hacer('MATCH POINT', 'Ganás hoy y cerrás la serie. Que no se te escape.', 78, mp: true);
  }
  if (propias - ajenas >= 2) {
    return hacer('VENTAJA $propias-$ajenas', 'Vas arriba en la serie: ahora a liquidarla.', 52);
  }
  if (ajenas - propias >= 2) {
    return hacer('ABAJO $propias-$ajenas', 'Venís perdiendo la serie: hay que remontar ya.', 66);
  }
  if (propias == ajenas && juego > 1) {
    return hacer('SERIE IGUALADA $propias-$ajenas', 'Está todo parejo: el próximo partido inclina la serie.', 55);
  }
  return hacer('JUEGO $juego', 'Arranca la serie: el primero en llegar a $aGanar pasa.', 40);
}

/// Presión de una serie de playoffs desde el lado de [usuarioId]. Null si la serie no lo incluye.
PresionPartido? presionDeSerie(SeriePlayoff s, String usuarioId) {
  if (s.altoId != usuarioId && s.bajoId != usuarioId) return null;
  if (s.terminada) return null;
  final alto = s.altoId == usuarioId;
  final peso = switch (s.ronda) {
    RondaPlayoff.finalesNba => 10,
    RondaPlayoff.finalConferencia => 6,
    RondaPlayoff.semifinalConferencia => 3,
    RondaPlayoff.playIn || RondaPlayoff.playInFinal => 0,
    _ => 0,
  };
  return presion(
    aGanar: s.victoriasParaGanar,
    propias: alto ? s.victoriasAlto : s.victoriasBajo,
    ajenas: alto ? s.victoriasBajo : s.victoriasAlto,
    peso: peso,
  );
}

/// Qué cambió en tu serie entre [antes] y [despues] (la misma serie): "Quedás 3-2 abajo."
/// Null si no hay cambio que contar.
String? consecuenciaDeSerie(SeriePlayoff antes, SeriePlayoff despues, String usuarioId) {
  final alto = despues.altoId == usuarioId;
  final p = alto ? despues.victoriasAlto : despues.victoriasBajo;
  final a = alto ? despues.victoriasBajo : despues.victoriasAlto;
  final pa = alto ? antes.victoriasAlto : antes.victoriasBajo;
  final aa = alto ? antes.victoriasBajo : antes.victoriasAlto;
  if (p == pa && a == aa) return null;
  final gane = p > pa;
  final falta = despues.victoriasParaGanar;
  if (despues.terminada) {
    if (despues.ganadorId == usuarioId) {
      return despues.ronda.esPlayIn
          ? 'Ganaste el partido: seguís en carrera.'
          : despues.ronda == RondaPlayoff.finalesNba
          ? '¡Campeón! Cerraste la serie $p-$a.'
          : 'Cerraste la serie $p-$a: pasás de ronda.';
    }
    return despues.ronda.esPlayIn
        ? 'Perdiste y quedaste afuera del Play-In.'
        : 'Se terminó: perdiste la serie $a-$p y quedás eliminado.';
  }
  final marcador = switch (p.compareTo(a)) {
    1 => 'arriba $p-$a',
    -1 => 'abajo $p-$a',
    _ => 'igualados $p-$a',
  };
  final base = gane ? 'Ganaste: quedás' : 'Perdiste: quedás';
  final extra = a == falta - 1 && p == falta - 1
      ? ' Partido ${p + a + 1} para definir.'
      : a == falta - 1
      ? ' Un partido más y se termina.'
      : p == falta - 1
      ? ' Estás a una victoria de cerrarla.'
      : '';
  return '$base $marcador.$extra';
}
