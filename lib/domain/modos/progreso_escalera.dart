import '../entities/modo_juego.dart';
import '../entities/perfil.dart';
import '../entities/temporada.dart';
import '../progreso.dart';
import 'escalera.dart';

/// Metajuego de los modos de escalera: XP y monedas por partido, la mejor racha al Salón y un
/// trofeo al completar el modo. No toca anillos ni récords de temporada.
PerfilEntrenador premiarEscalera(
  PerfilEntrenador perfil,
  ProgresoEscalera pe,
  Temporada t,
  double multiplicador,
  List<Novedad> novedades,
) {
  var p = perfil;
  if (pe.ganados + pe.perdidos > 0) {
    final xp = ((pe.ganados * 30 + pe.perdidos * 10) * multiplicador).round();
    final monedas = pe.ganados * 10 + pe.perdidos * 3;
    novedades.add(Novedad('+$xp XP · +$monedas monedas'));
    p = p.copyWith(xp: p.xp + xp, monedas: p.monedas + monedas);
  }
  if (pe.racha > p.mejorRacha) p = p.copyWith(mejorRacha: pe.racha);
  if (pe.completada) {
    final (tipo, xp, monedas) = switch (t.modoJuego) {
      ModoJuego.caminoAlAnillo => (TipoTrofeo.caminoAlAnillo, 400, 150),
      ModoJuego.mejoresEquipos => (TipoTrofeo.mejoresEquipos, 500, 200),
      ModoJuego.mundial => (TipoTrofeo.mundial, 500, 200),
      _ => (TipoTrofeo.escenario, 200, 80),
    };
    final detalle = escenarioPorId(Escalera.de(t).escenarioId)?.titulo;
    p = p.copyWith(
      xp: p.xp + (xp * multiplicador).round(),
      monedas: p.monedas + monedas,
      trofeos: [
        ...p.trofeos,
        Trofeo(
          tipo: tipo,
          temporadaId: t.id,
          franquiciaId: t.franquiciaUsuarioId,
          detalle: t.modoJuego == ModoJuego.escenario ? detalle : null,
          fecha: DateTime.now().millisecondsSinceEpoch,
        ),
      ],
    );
    novedades.add(Novedad('Trofeo: ${tipo.nombre}', detalle: detalle, destacada: true));
  }
  return p;
}

/// Logros que deja este cambio en una escalera.
List<Logro> logrosDeEscalera(ProgresoEscalera pe, Temporada t) => [
  if (pe.ganados > 0) Logro.primeraVictoria,
  if (pe.racha >= 15) Logro.rachaInfinita,
  if (pe.completada)
    switch (t.modoJuego) {
      ModoJuego.caminoAlAnillo => Logro.caminoAlAnillo,
      ModoJuego.mejoresEquipos => Logro.mejoresDeLaHistoria,
      ModoJuego.mundial => Logro.mundial,
      _ => Logro.escenario,
    },
];

/// En los escenarios, Leyenda única y Solo entrenador el plantel te lo dan (no lo fichaste): no
/// entra al álbum.
bool sumaAlAlbum(Temporada t) =>
    !const {ModoJuego.escenario, ModoJuego.leyendaUnica, ModoJuego.soloEntrenador}.contains(t.modoJuego);
