import 'dart:math';

import 'draft.dart';
import 'entities/jugador.dart';
import 'entities/modo_juego.dart';
import 'entities/oferta.dart';
import 'entities/temporada.dart';
import 'liga.dart';

/// Lo que viaja en un código de reto: con qué semilla y reglas se arma el draft, y (si ya lo
/// jugó) qué hizo el que reta.
class CodigoReto {
  const CodigoReto({
    required this.semilla,
    required this.franquiciaId,
    required this.modo,
    required this.regla,
    this.epoca,
    required this.dificultad,
    this.victorias,
    this.campeon = false,
    this.version,
  });

  /// Semilla del draft, del calendario y de los rivales (20 bits en los códigos nuevos, 28 en los
  /// anteriores al versionado del catálogo).
  final int semilla;

  /// Los 8 bits bajos de la versión del catálogo con que se armó el reto (null en códigos viejos).
  final int? version;
  final String franquiciaId;
  final ModoDraft modo;
  final ReglaDraft regla;
  final Epoca? epoca;
  final Dificultad dificultad;

  /// Victorias en la temporada regular del que reta (null: todavía no la terminó).
  final int? victorias;

  /// El que reta salió campeón.
  final bool campeon;

  static const maxSemilla = 1 << 28;

  /// Semillas de las partidas nuevas: entran en el código junto con la versión del catálogo.
  static const maxSemillaNueva = 1 << 20;

  /// Si el reto se armó con estas mismas cartas: null si el código es viejo (sin versión) o no se
  /// conoce la versión actual.
  bool? mismoCatalogo(int versionActual) =>
      version == null || versionActual == 0 ? null : version == versionActual & 0xff;

  /// "64-18" o null.
  String? get marca => victorias == null ? null : '$victorias-${Temporada.partidosTemporadaRegular - victorias!}';

  // ── Codificación: 52 bits de datos + 8 de control (CRC-8) = 60 bits = 12 caracteres base32 ──
  //
  // Formato 2 (con versión): 1 · semilla 20 · versión del catálogo 8 · franquicia 5 · modo 1 ·
  //   regla 3 · época 4 (0 = ninguna) · dificultad 2 · victorias 7 (127 = sin marca) · campeón 1.
  // Formato 1 (anterior): 0 · semilla 28 · el resto igual. Los dos se leen; el 2 se escribe cuando
  // la partida tiene versión y una semilla de 20 bits. Control (CRC-8) siempre al final.

  static const _alfabeto = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford: sin I, L, O, U

  String codificar() {
    final f = Draft.franquiciasRivales.indexOf(franquiciaId);
    if (f < 0) throw ArgumentError('Franquicia sin código: $franquiciaId');
    if (semilla < 0 || semilla >= maxSemilla) throw RangeError.range(semilla, 0, maxSemilla - 1, 'semilla');
    final conVersion = version != null && semilla < maxSemillaNueva;
    var datos = conVersion ? (1 << 20 | semilla) << 8 | (version! & 0xff) : semilla;
    datos = datos << 5 | f;
    datos = datos << 1 | modo.index;
    datos = datos << 3 | regla.index;
    datos = datos << 4 | (epoca == null ? 0 : epoca!.index + 1);
    datos = datos << 2 | dificultad.index;
    datos = datos << 7 | (victorias ?? 127).clamp(0, 127);
    datos = datos << 1 | (campeon ? 1 : 0);
    final completo = datos << 8 | _crc8(datos);
    final letras = StringBuffer();
    for (var i = 11; i >= 0; i--) {
      letras.write(_alfabeto[(completo >> (i * 5)) & 31]);
    }
    final s = letras.toString();
    return '82-${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8)}';
  }

  /// Lee un código (sin importar mayúsculas, guiones o espacios; O→0, I/L→1). Null si no es válido.
  static CodigoReto? leer(String texto) {
    var limpio = texto.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '');
    if (limpio.startsWith('82') && limpio.length == 14) limpio = limpio.substring(2);
    if (limpio.length != 12) return null;
    var completo = 0;
    for (final ch in limpio.split('')) {
      final normal = switch (ch) {
        'O' => '0',
        'I' || 'L' => '1',
        _ => ch,
      };
      final v = _alfabeto.indexOf(normal);
      if (v < 0) return null;
      completo = completo << 5 | v;
    }
    var datos = completo >> 8;
    if (_crc8(datos) != completo & 0xff) return null;
    int tomar(int bits) {
      final v = datos & ((1 << bits) - 1);
      datos >>= bits;
      return v;
    }

    final campeon = tomar(1) == 1;
    final victorias = tomar(7);
    final dificultad = tomar(2);
    final epoca = tomar(4);
    final regla = tomar(3);
    final modo = tomar(1);
    final f = tomar(5);
    // Lo que queda: la semilla (formato 1) o 1 · semilla 20 · versión 8 (formato 2).
    final int semilla;
    int? version;
    if (datos >> 28 == 0) {
      semilla = datos;
    } else if (datos >> 28 == 1) {
      version = datos & 0xff;
      semilla = (datos >> 8) & (maxSemillaNueva - 1);
    } else {
      return null;
    }
    if (dificultad >= Dificultad.values.length ||
        regla >= ReglaDraft.values.length ||
        epoca > Epoca.values.length ||
        f >= Draft.franquiciasRivales.length ||
        (victorias != 127 && victorias > Temporada.partidosTemporadaRegular)) {
      return null;
    }
    return CodigoReto(
      semilla: semilla,
      franquiciaId: Draft.franquiciasRivales[f],
      modo: ModoDraft.values[modo],
      regla: ReglaDraft.values[regla],
      epoca: epoca == 0 ? null : Epoca.values[epoca - 1],
      dificultad: Dificultad.values[dificultad],
      victorias: victorias == 127 ? null : victorias,
      campeon: campeon,
      version: version,
    );
  }

  /// CRC-8 (polinomio 0x07) sobre los 7 bytes de los datos: detecta cualquier carácter mal tipeado.
  static int _crc8(int datos) {
    var crc = 0;
    for (var i = 6; i >= 0; i--) {
      crc ^= (datos >> (i * 8)) & 0xff;
      for (var b = 0; b < 8; b++) {
        crc = (crc & 0x80) != 0 ? ((crc << 1) ^ 0x07) & 0xff : (crc << 1) & 0xff;
      }
    }
    return crc;
  }

  @override
  bool operator ==(Object other) => other is CodigoReto && other.codificar() == codificar();

  @override
  int get hashCode => codificar().hashCode;
}

/// Retos entre amigos: la semilla de cada partida clásica, el azar del draft que sale de ella y
/// cómo se arma la partida de quien acepta un reto.
class Reto {
  Reto._();

  static const claveSemilla = 'semilla';
  static const claveFichas = 'fichas';
  static const claveReto = 'reto';

  /// Datos de una partida clásica nueva: semilla al azar y las fichas con que arranca (para que
  /// las tiradas no dependan de cuántas fichas extra tiene cada uno).
  static Map<String, dynamic> datosNuevos(int fichas, {Random? azar}) => {
    claveSemilla: (azar ?? Random()).nextInt(CodigoReto.maxSemillaNueva),
    claveFichas: fichas,
  };

  static int? semillaDe(Temporada t) =>
      t.modoJuego == ModoJuego.clasico || t.modoJuego == ModoJuego.reto ? t.datosModo[claveSemilla] as int? : null;

  /// Azar del draft para cada paso, que sale de la semilla, de cuántos jugadores fichaste y (al
  /// volver a tirar o repartir) de cuántas fichas usaste. Así la primera tirada de cada puesto es
  /// la misma para todos los que juegan el mismo código. Null para partidas sin semilla.
  static Random Function(Temporada t, int paso)? azarPara(Temporada t) {
    final semilla = semillaDe(t);
    if (semilla == null) return null;
    return (x, paso) {
      final fichas = x.datosModo[claveFichas] as int? ?? x.rerollsRestantes;
      final usadas = Draft.pasoConFicha(paso) ? fichas - x.rerollsRestantes : 0;
      var h = semilla;
      for (final v in [x.plantel.jugadores.length, paso, usadas]) {
        h = (h * 1000003 + v * 7919 + 0x9e37) & 0x7fffffff;
      }
      return Random(h);
    };
  }

  /// La liga con que se arman el calendario y los rivales: con semilla, los mismos para el código.
  static Liga ligaPara(Liga liga, Temporada t) {
    final semilla = semillaDe(t);
    return semilla == null ? liga : Liga(liga.catalogo, liga.franquicias, azar: Random(semilla));
  }

  /// "Mi colección" depende del álbum de cada uno: no se puede retar con esa regla.
  static bool sePuedeRetar(Temporada t) => semillaDe(t) != null && t.regla != ReglaDraft.coleccion;

  /// El código para retar a un amigo con esta partida (con tu marca, si ya terminaste la temporada
  /// regular). Null si la partida no tiene semilla (anteriores a los retos) o es de "Mi colección".
  static CodigoReto? codigoDe(Temporada t) {
    if (!sePuedeRetar(t)) return null;
    final terminada = t.calendario.isNotEmpty && t.calendario.every((p) => p.jugado);
    return CodigoReto(
      semilla: semillaDe(t)!,
      franquiciaId: t.franquiciaUsuarioId,
      modo: t.modo,
      regla: t.regla,
      epoca: t.epocaRegla,
      dificultad: t.dificultad,
      victorias: terminada ? t.registroUsuario.victorias : null,
      campeon: t.campeonId == t.franquiciaUsuarioId,
      version: t.versionCatalogo == null ? null : t.versionCatalogo! & 0xff,
    );
  }

  /// La partida de quien acepta el reto.
  static Temporada aceptar(CodigoReto c, {required String id, int fichasExtra = 0}) {
    final fichas = Temporada.rerollsPorTemporada + fichasExtra;
    return Temporada(
      id: id,
      franquiciaUsuarioId: c.franquiciaId,
      modo: c.modo,
      regla: c.regla,
      epocaRegla: c.epoca,
      dificultad: c.dificultad,
      rerollsRestantes: fichas,
      modoJuego: ModoJuego.reto,
      datosModo: {claveSemilla: c.semilla, claveFichas: fichas, claveReto: c.codificar()},
    );
  }

  /// El reto que aceptaste en esta partida (null si no es un reto).
  static CodigoReto? aceptadoEn(Temporada t) {
    final s = t.datosModo[claveReto] as String?;
    return s == null ? null : CodigoReto.leer(s);
  }

  /// Cómo va el reto: (tu marca, la de tu amigo, veredicto). El veredicto es null mientras no se
  /// pueda decidir (sin la marca del amigo o con tu temporada regular en curso).
  static (String, String?, ResultadoReto?) comparar(Temporada t) {
    final c = aceptadoEn(t);
    final r = t.registroUsuario;
    final tuya = '${r.victorias}-${r.derrotas}';
    if (c == null || c.victorias == null) return (tuya, c?.marca, null);
    final terminada = t.calendario.isNotEmpty && t.calendario.every((p) => p.jugado);
    if (!terminada) return (tuya, c.marca, null);
    final v = r.victorias, a = c.victorias!;
    final campeon = t.campeonId == t.franquiciaUsuarioId;
    if (v != a) return (tuya, c.marca, v > a ? ResultadoReto.ganaste : ResultadoReto.perdiste);
    // Igual récord: desempata el anillo (cuando ya se sabe si lo ganaste).
    if (t.fase != FaseTemporada.finalizada && t.eliminacion == null) return (tuya, c.marca, null);
    if (campeon == c.campeon) return (tuya, c.marca, ResultadoReto.empate);
    return (tuya, c.marca, campeon ? ResultadoReto.ganaste : ResultadoReto.perdiste);
  }
}

enum ResultadoReto {
  ganaste('¡Ganaste el reto!'),
  empate('Empate: mismo récord.'),
  perdiste('Perdiste el reto.');

  const ResultadoReto(this.texto);
  final String texto;
}
