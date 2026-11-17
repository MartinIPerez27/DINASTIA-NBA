import '../entities/modo_juego.dart';
import '../tension.dart';
import 'escalera.dart';

/// Una línea del cuaderno de bitácora de una corrida de escalera (se calcula de los cruces: no se guarda).
class EntradaBitacora {
  const EntradaBitacora({required this.titulo, required this.detalle, this.victoria = true, this.hito = false});

  final String titulo, detalle;
  final bool victoria;

  /// Es un hito que se celebra (3, 5, 10… seguidos), no un cruce.
  final bool hito;
}

class Bitacora {
  Bitacora._();

  /// Racha de cruces ganados que se celebran.
  static const hitos = {3, 5, 8, 10, 15, 20, 25, 30};

  /// Recorrido de la corrida en orden cronológico: un renglón por cruce terminado y un hito cada tanto.
  /// [nombre] da el nombre visible del rival ("Bulls 95-96").
  static List<EntradaBitacora> de(Escalera e, String Function(RivalEscalera) nombre) {
    final r = <EntradaBitacora>[];
    var ganados = 0;
    for (final c in e.cruces) {
      if (!c.terminado || c.marcadores.isEmpty) continue;
      final rival = nombre(c.rival);
      final margenes = [for (final (a, b) in c.marcadores) a - b];
      if (c.ganado) {
        ganados++;
        final mejor = margenes.isEmpty ? 0 : margenes.reduce((a, b) => a > b ? a : b);
        final apretado = margenes.isNotEmpty && margenes.last.abs() <= 3;
        r.add(
          EntradaBitacora(
            titulo: c.esSerie
                ? 'Serie ganada ${c.propias}-${c.ajenas}'
                : 'Victoria ${c.marcadores.last.$1}-${c.marcadores.last.$2}',
            detalle:
                '${c.titulo} · $rival${apretado
                    ? ' · por un suspiro'
                    : mejor >= 20
                    ? ' · paliza de +$mejor'
                    : ''}',
          ),
        );
        if (hitos.contains(ganados)) {
          r.add(EntradaBitacora(titulo: '¡$ganados seguidos!', detalle: 'Hito de la corrida', hito: true));
        }
      } else {
        final dolor = margenes.isEmpty ? 0 : margenes.last;
        r.add(
          EntradaBitacora(
            titulo: c.esSerie
                ? 'Serie perdida ${c.propias}-${c.ajenas}'
                : 'Derrota ${c.marcadores.last.$1}-${c.marcadores.last.$2}',
            detalle: '${c.titulo} · $rival${dolor.abs() <= 3 ? ' · se te escapó por poco' : ''}',
            victoria: false,
          ),
        );
      }
    }
    return r;
  }

  /// Frases de cierre de la corrida: lo mejor, lo más doloroso y si hay récord personal.
  /// [mejorRachaPrevia] es el récord que tenías antes de esta corrida (0 si no aplica).
  static List<String> cierre(Escalera e, String Function(RivalEscalera) nombre, {int mejorRachaPrevia = 0}) {
    final r = <String>[];
    (int, Cruce)? mejor, peor;
    for (final c in e.cruces) {
      for (final (a, b) in c.marcadores) {
        final m = a - b;
        if (mejor == null || m > mejor.$1) mejor = (m, c);
        if (peor == null || m < peor.$1) peor = (m, c);
      }
    }
    if (mejor != null && mejor.$1 > 0) {
      r.add('Mejor noche: +${mejor.$1} contra ${nombre(mejor.$2.rival)}.');
    }
    if (peor != null && peor.$1 < 0) {
      r.add('La que duele: ${peor.$1} contra ${nombre(peor.$2.rival)}.');
    }
    if (mejorRachaPrevia > 0 && e.racha > mejorRachaPrevia) {
      r.add('¡Récord personal! Superaste tu mejor marca de $mejorRachaPrevia.');
    } else if (mejorRachaPrevia > 0 && e.racha > 0 && e.racha < mejorRachaPrevia) {
      r.add('Te faltaron ${mejorRachaPrevia - e.racha + 1} para superar tu récord de $mejorRachaPrevia.');
    }
    return r;
  }

  /// Etiqueta de la racha según su largo.
  static String nivelRacha(int n) => n < 3
      ? 'Calentando'
      : n < 5
      ? 'Tomando ritmo'
      : n < 8
      ? 'En llamas'
      : n < 12
      ? 'Imparable'
      : 'Leyenda viva';

  /// Presión del cruce pendiente [c] en un modo de escalera. En las series vale la de `presion`; en los partidos
  /// únicos de un modo de una sola vida se arma con lo que se juega: la racha (y tu récord), el escalón o la ronda.
  static PresionPartido presionDeCruce(ModoJuego modo, Escalera e, Cruce c, {int mejorRacha = 0}) {
    final indice = e.cruces.length; // cruce actual (1-based en pantalla)
    if (c.esSerie) {
      final peso = e.total != null && indice >= e.total! ? 10 : (indice * 6 / (e.total ?? 10)).round();
      return presion(aGanar: c.aGanar, propias: c.propias, ajenas: c.ajenas, peso: peso);
    }
    PresionPartido hacer(String etiqueta, String detalle, int valor) {
      final v = valor.clamp(0, 100);
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
        decisivo: true,
        eliminacion: true,
        matchPoint: true,
        juego: 1,
      );
    }

    if (modo == ModoJuego.racha) {
      final r = e.racha;
      final record = r >= mejorRacha && mejorRacha > 0
          ? 'Ganás y seguís haciendo historia: ya superaste tu récord de $mejorRacha.'
          : mejorRacha > r
          ? 'Si perdés, se corta la racha de $r. Tu récord es $mejorRacha: te faltan ${mejorRacha - r + 1}.'
          : 'Si perdés, se corta la racha de $r.';
      return hacer(
        r == 0 ? 'PRIMER RIVAL' : 'RACHA DE $r EN JUEGO',
        r == 0 ? 'Una vida: el primer partido ya cuenta.' : record,
        35 + r * 7,
      );
    }
    final total = e.total ?? 10;
    final final_ = e.total != null && indice >= e.total!;
    return hacer(
      final_ ? 'ÚLTIMO ESCALÓN' : 'ESCALÓN $indice DE $total',
      final_
          ? 'Todo o nada: un partido para quedarte con la corrida.'
          : 'Una sola vida: si perdés, se termina la corrida. Llevás $indice ${indice == 1 ? 'cruce' : 'cruces'}.',
      45 + (indice * 50 / total).round(),
    );
  }
}
