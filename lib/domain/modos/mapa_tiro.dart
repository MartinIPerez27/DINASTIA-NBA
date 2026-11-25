import 'carrera_jugador.dart';

/// Una zona de tiro de tu carrera: cuánto tirás ahí y con qué acierto, contra el promedio de la liga.
class ZonaTiro {
  const ZonaTiro(this.nombre, this.hechos, this.intentos, this.ligaPct);
  final String nombre;
  final int hechos, intentos;

  /// Acierto típico de la liga en esa zona (0 a 1).
  final double ligaPct;

  double get pct => intentos == 0 ? 0 : hechos / intentos;

  /// Puntos por tiro (los triples valen 3).
  double get ppt => intentos == 0 ? 0 : (hechos * (nombre == 'Triple' ? 3 : 2)) / intentos;

  /// Diferencia con la liga en puntos porcentuales.
  double get contraLiga => (pct - ligaPct) * 100;

  String get veredicto {
    if (intentos < 30) return 'pocos tiros';
    if (contraLiga >= 4) return 'zona caliente';
    if (contraLiga <= -4) return 'zona fría';
    return 'en la media';
  }
}

/// Mapa de tiro de la carrera: pintura, media distancia y triples (las zonas se estiman por el tipo de tiro).
class MapaTiro {
  const MapaTiro(this.zonas);
  final List<ZonaTiro> zonas;

  factory MapaTiro.de(EstadoCarrera e) {
    int n(String k) => e.uso[k] ?? 0;
    final pinI = n('c:pinI'), pinA = n('c:pinA');
    final triI = n('c:t3'), triA = n('c:t3A');
    final medI = n('c:tcI') - pinI - triI, medA = n('c:tcA') - pinA - triA;
    return MapaTiro([
      ZonaTiro('Pintura', pinI, pinA, 0.64),
      ZonaTiro('Media distancia', medI < 0 ? 0 : medI, medA < 0 ? 0 : medA, 0.42),
      ZonaTiro('Triple', triI, triA, 0.36),
    ]);
  }

  int get intentos => zonas.fold(0, (a, z) => a + z.intentos);

  double participacion(ZonaTiro z) => intentos == 0 ? 0 : z.intentos / intentos;

  /// La zona más eficiente (por puntos por tiro) con volumen suficiente.
  ZonaTiro? get mejor {
    final con = zonas.where((z) => z.intentos >= 30).toList();
    if (con.isEmpty) return null;
    return con.reduce((a, b) => a.ppt >= b.ppt ? a : b);
  }

  String get consejo {
    final m = mejor;
    if (m == null) return 'Todavía hay pocos tiros para armar tu mapa.';
    final frio = zonas.where((z) => z.veredicto == 'zona fría').toList();
    return 'Tu zona más rentable es ${m.nombre.toLowerCase()} (${m.ppt.toStringAsFixed(2).replaceAll('.', ',')} puntos por tiro).'
        '${frio.isEmpty ? '' : ' Cuidado con ${frio.first.nombre.toLowerCase()}: rendís menos que la liga.'}';
  }
}
