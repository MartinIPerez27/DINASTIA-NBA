import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/estilo_creado.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final carrera = CarreraJugador(Liga(catalogo, franquicias, azar: Random(2)));
  final arg = SeleccionCarrera.paises.indexWhere((p) => p.nombre == 'Argentina');

  EstadoCarrera estado({int pais = 0, int numero = 3, String raiz = 'sel1', int potencial = 90}) {
    final e = carrera.estadoCreado(
      raiz: raiz,
      creado: JugadorCreado(
        nombre: 'Leo Paz',
        posicion: Posicion.alero,
        rol: RolCancha.especialista3D,
        fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
        estilo: EstiloCreado(pais: pais),
      ),
      pick: 4,
      franquiciaId: 'CHI',
      potencial: potencial,
    );
    return e.copyWith(numero: numero);
  }

  test('el país viaja en el código del estilo y los códigos viejos siguen leyéndose', () {
    expect(EstiloCreado.deCodigo(EstiloCreado(pais: arg).codigo)!.pais, arg);
    expect(EstiloCreado.deCodigo('0.0.1.0.0.3')!.pais, 0);
  });

  test('hay torneo en la 3.ª, 7.ª y 11.ª temporada, alternando Mundial y Juegos', () {
    expect([for (var n = 1; n <= 12; n++) if (SeleccionCarrera.hayTorneo(n)) n], [3, 7, 11]);
    expect(SeleccionCarrera.nombreTorneo(3), 'Mundial');
    expect(SeleccionCarrera.nombreTorneo(7), 'Juegos Olímpicos');
    expect([SeleccionCarrera.faltan(1), SeleccionCarrera.faltan(3), SeleccionCarrera.faltan(4), SeleccionCarrera.faltan(7)], [2, 0, 3, 0]);
  });

  test('sin torneo ese año, o sin país (jugador real), no pasa nada', () {
    expect(SeleccionCarrera.jugar(estado(numero: 4), media: 90, ppg: 25), isNull);
    final real = carrera.estadoReal(raiz: 'real1', carta: catalogo.firstWhere((j) => j.media > 80), pick: 3);
    expect(SeleccionCarrera.paisDe(real), isNull);
  });

  test('convocatoria: el nivel manda (titular, suplente o afuera)', () {
    final eeuu = SeleccionCarrera.paises.first, otro = SeleccionCarrera.paises.last;
    final azar = Random(1);
    expect(SeleccionCarrera.rolEn(eeuu, 60, azar), 0);
    expect(SeleccionCarrera.rolEn(eeuu, 85, azar), 1);
    expect(SeleccionCarrera.rolEn(eeuu, 92, azar), 2);
    expect(SeleccionCarrera.rolEn(otro, 62, azar), 2);
  });

  test('un crack gana más medallas que un jugador flojo con el mismo país, y es determinista', () {
    int medallas(int media) {
      var m = 0;
      for (var i = 0; i < 120; i++) {
        final t = SeleccionCarrera.jugar(estado(pais: arg, raiz: 'k$i'), media: media, ppg: 25);
        if (t?.resultado case final r? when r.fans > 0) m++;
      }
      return m;
    }

    expect(medallas(92), greaterThan(medallas(60)));
    final a = SeleccionCarrera.jugar(estado(pais: arg), media: 85, ppg: 20)!;
    final b = SeleccionCarrera.jugar(estado(pais: arg), media: 85, ppg: 20)!;
    expect((a.resultado, a.pts), (b.resultado, b.pts));
  });

  test('aplicar suma convocatoria, medalla, fans y deja un hito', () {
    final e = estado(pais: arg);
    final t = TorneoJugado(
      nombre: 'Mundial',
      pais: SeleccionCarrera.paisDe(e)!,
      rol: 2,
      resultado: ResultadoTorneo.oro,
      pts: 18.4,
    );
    final n = SeleccionCarrera.aplicar(e, t, '2026-27');
    expect(SeleccionCarrera.convocatorias(n), 1);
    expect(n.uso['sn:oro'], 1);
    expect(SeleccionCarrera.medallas(n), 1);
    expect(n.fans, greaterThan(e.fans));
    expect(n.hitos.last, contains('medalla de oro'));
    final fuera = SeleccionCarrera.aplicar(
      e,
      TorneoJugado(nombre: 'Mundial', pais: t.pais, rol: 0, resultado: null, pts: 0),
      '2026-27',
    );
    expect(SeleccionCarrera.convocatorias(fuera), 0);
    expect(fuera.movimientos.last, contains('no te convocaron'));
  });
}
