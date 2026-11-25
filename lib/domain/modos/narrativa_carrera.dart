import 'dart:math';

import '../entities/jugador.dart';
import 'carrera_jugador.dart';

/// Tu rival de la época y tu mentor, y el duelo de números entre temporadas.
class RivalidadCarrera {
  RivalidadCarrera._();

  /// Cada cuántas temporadas aparece un rival nuevo.
  static const cadaTemporadas = 3;

  static double _valor(double pts, double reb, double ast) => pts + 0.7 * reb + 0.7 * ast;

  /// El rival de la época de tu jugador: otra franquicia, tu mismo puesto y un nivel un poco por encima.
  /// Sale de la carta del catálogo y cambia cada [cadaTemporadas] temporadas (determinista).
  static Jugador? rival(EstadoCarrera e, List<Jugador> catalogo) {
    final bloque = (e.numero - 1) ~/ cadaTemporadas;
    final azar = Random(_hash('${e.raiz}-rival-$bloque'));
    final candidatos = [
      for (final j in catalogo)
        if (j.epoca == e.epoca &&
            j.nbaPlayerId > 0 &&
            j.franquiciaId != e.franquiciaId &&
            j.posiciones.first == e.posicion &&
            j.nbaPlayerId != e.base.nbaPlayerId)
          j,
    ]..sort((a, b) => ((a.media - (e.media + 3)).abs()).compareTo((b.media - (e.media + 3)).abs()));
    if (candidatos.isEmpty) return null;
    return candidatos[azar.nextInt(min(4, candidatos.length))];
  }

  static int ganados(EstadoCarrera e) => e.uso['rv:g'] ?? 0;
  static int perdidos(EstadoCarrera e) => e.uso['rv:p'] ?? 0;

  /// Tu mentor: el compañero de mayor nivel, si el vestuario te quiere (relación de 60 o más).
  static Jugador? mentor(EstadoCarrera e) {
    if (e.companeros.isEmpty) return null;
    final mejor = e.companeros.reduce((a, b) => a.media >= b.media ? a : b);
    return mejor;
  }

  static bool mentorActivo(EstadoCarrera e) => mentor(e) != null && e.relacion >= 60;

  /// Cierra el año: duelo contra el rival (puntos, rebotes y asistencias contra los de su carta) y clase de tu mentor.
  static EstadoCarrera alCerrar(EstadoCarrera e, TemporadaJugador t, List<Jugador> catalogo) {
    var ne = e;
    final r = rival(e, catalogo);
    if (r != null && t.pj >= 20) {
      final mio = _valor(t.pts, t.reb, t.ast);
      final suyo = _valor(r.stats.ppp, r.stats.rpp, r.stats.app);
      final gane = mio >= suyo;
      final texto = '${e.etiquetaTemporada}: duelo con ${r.nombre}: '
          '${gane ? 'le ganaste' : 'te ganó'} la temporada (${t.pts.toStringAsFixed(1).replaceAll('.', ',')} pts contra ${r.stats.ppp.toStringAsFixed(1).replaceAll('.', ',')}).';
      ne = ne.copyWith(
        uso: {...ne.uso, gane ? 'rv:g' : 'rv:p': (gane ? ganados(ne) : perdidos(ne)) + 1},
        movimientos: [...ne.movimientos, texto],
        hitos: gane && e.uso['rv:g'] == null ? [...ne.hitos, texto] : null,
        confianza: (ne.confianza + (gane ? 1 : -1)).clamp(0, 98),
      );
    }
    final m = mentor(e);
    if (m != null && mentorActivo(e)) {
      ne = ne.copyWith(
        phBanco: ne.phBanco + 1,
        movimientos: [...ne.movimientos, '${e.etiquetaTemporada}: ${m.nombre} te ayudó con consejos: +1 punto de habilidad.'],
      );
    }
    return ne;
  }

  static int _hash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);
}

/// Opciones para publicar en redes una vez por temporada.
enum PostRedes {
  highlight('Subir tu mejor jugada', 'Seguidores y fans suben, sin costo.'),
  polemica('Tirar una polémica', 'Muchos más seguidores, pero baja la relación con el vestuario.'),
  agradecer('Agradecer a los fans', 'Menos seguidores pero fans que te quieren y más confianza.');

  const PostRedes(this.etiqueta, this.descripcion);
  final String etiqueta, descripcion;
}

/// Redes sociales: seguidores (en miles) que crecen con tu fama y suman marcas.
/// `rs:seg` seguidores en miles, `rs:post` marca de que ya publicaste esta temporada.
class RedesCarrera {
  RedesCarrera._();

  static int seguidores(EstadoCarrera e) => e.uso['rs:seg'] ?? 0;
  static bool yaPublico(EstadoCarrera e) => (e.uso['rs:post'] ?? 0) == 1;

  /// Plata extra por marcas según los seguidores (millones por temporada).
  static double ingresos(EstadoCarrera e) => seguidores(e) / 800;

  static EstadoCarrera publicar(EstadoCarrera e, PostRedes p) {
    if (yaPublico(e) || e.retirado) return e;
    final extra = switch (p) {
      PostRedes.highlight => 12,
      PostRedes.polemica => 30,
      PostRedes.agradecer => 6,
    };
    return e.copyWith(
      uso: {...e.uso, 'rs:seg': seguidores(e) + extra + e.fans ~/ 10, 'rs:post': 1},
      fans: (e.fans + (p == PostRedes.agradecer ? 2 : (p == PostRedes.highlight ? 1 : 0))).clamp(0, 98),
      relacion: e.relacion - (p == PostRedes.polemica ? 3 : 0),
      confianza: (e.confianza + (p == PostRedes.agradecer ? 1 : 0)).clamp(0, 98),
      movimientos: [...e.movimientos, '${e.etiquetaTemporada}: publicaste en redes (${p.etiqueta.toLowerCase()}).'],
    );
  }

  /// Cierra el año: los seguidores crecen con tu fama y tus resultados; vuelve a abrirse la publicación.
  static EstadoCarrera alCerrar(EstadoCarrera e, TemporadaJugador t) {
    final crecimiento = (e.fans * 0.6 + t.pts * 1.5 + (t.campeon ? 40 : 0) + (t.allStar ? 15 : 0)).round();
    return e.copyWith(uso: {...e.uso, 'rs:seg': seguidores(e) + crecimiento}..remove('rs:post'));
  }
}

/// El relator que se acuerda de tu historia: frases armadas con lo que hiciste.
class RelatorCarrera {
  RelatorCarrera._();

  static String _n(num v, [int d = 1]) => v.toStringAsFixed(d).replaceAll('.', ',');

  static List<String> memorias(EstadoCarrera e, {Jugador? rival}) {
    final f = <String>[];
    int n(String k) => e.uso[k] ?? 0;
    final puntos = RecordsCarrera.totalCarrera(e, 'puntos').round();
    if (puntos > 0) {
      final proximo = (puntos ~/ 1000 + 1) * 1000;
      f.add('Lleva $puntos puntos en su carrera: ${proximo - puntos} para llegar a $proximo.');
    }
    if (n('c:p40') > 0) {
      f.add('Ya tiene ${n('c:p40')} ${n('c:p40') == 1 ? 'partido' : 'partidos'} de 40 puntos o más, y su récord es de ${n('m:pts')}.');
    } else if (n('m:pts') >= 30) {
      f.add('Su techo anotador: ${n('m:pts')} puntos en una noche.');
    }
    if (n('c:td') > 0) f.add('Suma ${n('c:td')} triples dobles en su historia.');
    if (e.historial.isNotEmpty) {
      final u = e.historial.last;
      if (u.campeon) {
        f.add('Todavía se acuerda del anillo de ${u.etiqueta}.');
      } else if (u.premios.isNotEmpty) {
        f.add('El año pasado se llevó: ${u.premios.first}.');
      }
    }
    final cronicas = CuerpoCarrera.cronicas(e);
    if (cronicas.isNotEmpty) f.add('Cuidado con su ${cronicas.first.etiqueta.toLowerCase()}, que ya lo frenó varias veces.');
    if (rival != null && (RivalidadCarrera.ganados(e) + RivalidadCarrera.perdidos(e)) > 0) {
      f.add('Su duelo con ${rival.nombre} va ${RivalidadCarrera.ganados(e)} a ${RivalidadCarrera.perdidos(e)} en las temporadas.');
    }
    if (SeleccionCarrera.medallas(e) > 0) f.add('Con la selección ya ganó ${SeleccionCarrera.medallas(e)} ${SeleccionCarrera.medallas(e) == 1 ? 'medalla' : 'medallas'}.');
    if (e.historial.length >= 3) {
      final mejor = e.historial.reduce((a, b) => a.pts >= b.pts ? a : b);
      f.add('Su mejor año anotador fue ${mejor.etiqueta}, con ${_n(mejor.pts)} por partido.');
    }
    return f;
  }

  /// Una frase para la previa del partido (la que cuenta el relator antes del salto inicial).
  static String? previa(EstadoCarrera e, {Jugador? rival}) {
    final m = memorias(e, rival: rival);
    if (m.isEmpty) return null;
    return m[(e.uso['c:pj'] ?? 0) % m.length];
  }
}

/// Dónde entrarías en el cuadro de honor de la NBA según tus totales de carrera.
class CuadroDeHonor {
  const CuadroDeHonor({required this.nivel, required this.puestos, required this.top10, required this.top25, required this.top50});

  final String nivel;

  /// Puesto histórico que ocuparías en cada lista de totales (solo las que entrás).
  final Map<String, int> puestos;
  final int top10, top25, top50;

  static CuadroDeHonor evaluar(RecordsNba r, EstadoCarrera e) {
    final caminos = RecordsCarrera.carrera(r, e);
    final puestos = {
      for (final c in caminos)
        if (c.puesto != null) c.lista.etiqueta: c.puesto!,
    };
    final top10 = puestos.values.where((p) => p <= 10).length;
    final top25 = puestos.values.where((p) => p <= 25).length;
    final top50 = puestos.values.length;
    final nivel = top10 >= 3
        ? 'Inmortal: en el top 10 histórico de varias marcas'
        : top10 >= 1 || top25 >= 3
        ? 'Leyenda: entre los mejores de la historia'
        : top25 >= 1 || top50 >= 3
        ? 'Salón de la Fama: tu nombre figura en la historia'
        : top50 >= 1
        ? 'Notable: ya figurás en una lista histórica'
        : 'Todavía fuera del cuadro de honor';
    return CuadroDeHonor(nivel: nivel, puestos: puestos, top10: top10, top25: top25, top50: top50);
  }
}
