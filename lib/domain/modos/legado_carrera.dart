import 'dart:math';

import '../entities/estilo_creado.dart';
import '../entities/jugador.dart';
import 'carrera_jugador.dart';

/// Tu carta de carrera: al retirarte, tu jugador queda como carta de tu álbum (sirve en los demás modos).
class CartaCarrera {
  CartaCarrera._();

  static String idDe(String raiz) => 'cc-$raiz';

  /// Carta de tu jugador retirado: la media es la de su mejor temporada y el nivel sale de su legado.
  static Jugador deRetiro(EstadoCarrera e) {
    final c = e.carta;
    final pico = max(e.media, e.legado.mejorMedia);
    final salon = e.legado.puntosSalon;
    final tier = salon >= 24 || pico >= 95
        ? Tier.sPlus
        : salon >= 14 || pico >= 90
        ? Tier.s
        : pico >= 80
        ? Tier.a
        : Tier.b;
    final h = e.raiz.codeUnits.fold(17, (a, x) => (a * 31 + x) & 0x7fffffff);
    return Jugador(
      id: idDe(e.raiz),
      nbaPlayerId: 9000000 + h % 900000,
      nombre: c.nombre,
      franquiciaId: c.franquiciaId,
      epoca: c.epoca,
      tier: tier,
      posiciones: c.posiciones,
      rol: c.rol,
      dorsal: c.dorsal,
      stats: c.stats,
      media: pico,
      equipo: c.franquiciaId,
      fotos: c.fotos,
      temporadas: (e.anioBase + 1, e.anioCierre),
      draft: c.draft,
      universidad: c.universidad,
      nacimiento: c.nacimiento,
      avatar: c.avatar,
    );
  }
}

/// Carrera generacional: tu hijo o hija empieza donde terminaste vos.
class HerederoCarrera {
  const HerederoCarrera({required this.creado, required this.pick, required this.potencial, required this.franquiciaId, required this.anio, required this.fans});

  final JugadorCreado creado;
  final int pick, potencial, fans;
  final String franquiciaId;

  /// Año del draft del heredero.
  final int anio;

  static const nombres = ['Tomás', 'Mateo', 'Lucas', 'Santi', 'Bruno', 'Thiago', 'Valentina', 'Camila', 'Lola', 'Emma', 'Julieta', 'Mía'];

  /// Apellido para el heredero: la última palabra del nombre del padre/madre.
  static String apellido(String nombre) => nombre.trim().split(RegExp(r'\s+')).last;

  /// Se puede heredar solo con una carrera terminada de al menos 5 temporadas.
  static bool puede(EstadoCarrera e) => e.retirado && e.historial.length >= 5;

  /// El heredero: mismo apellido y país, mismo puesto, los puntos fuertes cambian en uno y el techo sale de la leyenda familiar.
  static HerederoCarrera de(EstadoCarrera padre) {
    final azar = Random(padre.raiz.codeUnits.fold(7, (a, x) => (a * 31 + x) & 0x7fffffff) ^ 0x5ca1ab1e);
    final base = padre.creado;
    final pos = base?.posicion ?? padre.posicion;
    final rol = base?.rol ?? padre.base.rol;
    final fuertes = [...(base?.fuertes ?? [Atributo.tiro, Atributo.defensa, Atributo.iq])];
    if (azar.nextBool()) {
      final nuevo = Atributo.values.where((a) => !fuertes.contains(a)).toList();
      fuertes[azar.nextInt(3)] = nuevo[azar.nextInt(nuevo.length)];
    }
    final salon = padre.legado.puntosSalon;
    final potencial = (padre.potencial - 3 + min(5, salon ~/ 5)).clamp(82, 96).toInt();
    final estilo = (base?.estilo ?? const EstiloCreado()).copyWith(mano: azar.nextInt(3));
    return HerederoCarrera(
      creado: JugadorCreado(
        nombre: '${nombres[azar.nextInt(nombres.length)]} ${apellido(padre.nombre)}',
        posicion: pos,
        rol: rol,
        fuertes: fuertes,
        alturaCm: base?.alturaCm ?? 198,
        pesoKg: base?.pesoKg ?? 95,
        avatar: base?.avatar,
        anioDraft: padre.anioCierre + 4,
        dorsal: base?.dorsal ?? 0,
        estilo: estilo,
      ),
      pick: salon >= 14 ? 3 : 12,
      potencial: potencial,
      franquiciaId: padre.franquiciaId,
      anio: padre.anioCierre + 4,
      fans: padre.fans ~/ 4,
    );
  }

  /// Arma el estado de la nueva carrera: la fama de la familia da fans y un hito de arranque.
  EstadoCarrera estado(CarreraJugador carrera, String raiz, String padreNombre) {
    final e = carrera.estadoCreado(
      raiz: raiz,
      creado: creado,
      pick: pick,
      franquiciaId: franquiciaId,
      anioInicial: anio,
      potencial: potencial,
    );
    return e.copyWith(
      fans: (e.fans + fans).clamp(0, 98),
      hitos: [...e.hitos, '$anio: ${creado.nombre} sigue los pasos de $padreNombre.'],
    );
  }
}
