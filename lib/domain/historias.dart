import 'dart:math';

import 'entities/partido.dart';
import 'entities/temporada.dart';
import 'historicos.dart';
import 'liga.dart';
import 'motor.dart';
import 'noticias.dart' show carreraMvp;
import 'premios.dart';
import 'tension.dart';

// Motor de historias entre partidos: convierte el estado real de la temporada (calendario, líneas,
// lesiones, series, premios) en noticias con drama y reacciones (DT, vestuario, prensa, afición).
// Dominio puro y determinista: la misma temporada da las mismas historias. Lo consumen la pantalla
// de noticias (`presentation/widgets/titulares.dart`) y, indirectamente, el relator (ver
// `contexto_narrativo.dart`). Solo usa datos que existen en `Temporada`.

enum TipoHistoria {
  inicio('Arranque'),
  invicto('Invictos'),
  caidaInvicto('Cayó el invicto'),
  racha('Racha'),
  finRacha('Racha cortada'),
  crisis('Crisis'),
  respiro('Respiro'),
  lesion('Lesión'),
  rival('Rival'),
  hito('Hito'),
  record('Récord'),
  mvp('Carrera al MVP'),
  duelo('Duelo de estrellas'),
  mejorado('Más Mejorado'),
  bisagra('Partido bisagra'),
  serie('Playoffs'),
  resumen('Balance');

  const TipoHistoria(this.etiqueta);
  final String etiqueta;
}

/// Qué dicen los de alrededor: el DT, el vestuario, la prensa o la afición.
class Reaccion {
  const Reaccion(this.voz, this.cita);

  /// 'DT', 'Vestuario', 'Prensa' o 'Afición'.
  final String voz;
  final String cita;
}

class Historia {
  const Historia({
    required this.tipo,
    required this.jornada,
    required this.titulo,
    required this.texto,
    this.franquiciaId,
    this.jugadorId,
    this.destacado = false,
    this.reaccion,
  });

  final TipoHistoria tipo;

  /// Jornada a la que se refiere (0 si es de antes de jugar).
  final int jornada;
  final String titulo;
  final String texto;
  final String? franquiciaId;
  final String? jugadorId;

  /// Tiene que ver con tu equipo o tus jugadores.
  final bool destacado;
  final Reaccion? reaccion;

  /// Clave estable para comparar dos estados de la misma temporada (qué historias son nuevas).
  String get clave => '${tipo.name}|$jornada|$titulo';
}

class Historias {
  Historias._();

  /// Tope de historias que devuelve [generar].
  static const limite = 40;

  /// Hash estable (FNV-1a), no depende de la corrida.
  static int _h(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  static T _uno<T>(List<T> opciones, String clave) => opciones[_h(clave) % opciones.length];

  static String _dec(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Racha del usuario (o de [franquiciaId]) con signo: positiva = victorias seguidas, negativa = derrotas.
  static int rachaDe(Temporada t, String franquiciaId) {
    final jugados = t.calendario.where((p) => p.jugado && p.participa(franquiciaId)).toList()
      ..sort((a, b) => a.jornada.compareTo(b.jornada));
    if (jugados.isEmpty) return 0;
    final gano = jugados.last.ganadorId == franquiciaId;
    var n = 0;
    for (final p in jugados.reversed) {
      if ((p.ganadorId == franquiciaId) != gano) break;
      n++;
    }
    return gano ? n : -n;
  }

  static (int, int) _record(Temporada t, String f, {int hastaJornada = 1 << 30}) {
    var v = 0, d = 0;
    for (final p in t.calendario) {
      if (!p.jugado || p.jornada > hastaJornada || !p.participa(f)) continue;
      p.ganadorId == f ? v++ : d++;
    }
    return (v, d);
  }

  /// Todas las historias de la temporada hasta hoy, de la más nueva a la más vieja (nunca vacío).
  /// [nombre] da el nombre visible de cada franquicia ("Knicks"); [mejorRachaHistorica] es la mejor racha
  /// de tu perfil (para marcar récords personales).
  static List<Historia> generar(
    Temporada t,
    Liga liga, {
    required String Function(String franquiciaId) nombre,
    int mejorRachaHistorica = 0,
  }) {
    final u = t.franquiciaUsuarioId;
    final propio = nombre(u);
    final lista = <Historia>[];
    void add(Historia h) => lista.add(h);
    String k(String s) => '${t.id}|$s';
    Reaccion? reaccion(String clave, List<Reaccion> opciones) => _uno(opciones, k(clave));

    final propios = t.calendario.where((p) => p.jugado && p.participa(u)).toList()
      ..sort((a, b) => a.jornada.compareTo(b.jornada));
    final ultimaJornada = propios.isEmpty ? 0 : propios.last.jornada;

    // ── Recorrido por tus partidos: invictos, rachas, crisis, respiros. ──
    var v = 0, d = 0, rachaG = 0, rachaP = 0;
    for (final p in propios) {
      final gane = p.ganadorId == u;
      final rivalId = p.localId == u ? p.visitanteId : p.localId;
      final rival = nombre(rivalId);
      final j = p.jornada;
      if (gane) {
        if (rachaP >= 3) {
          add(
            Historia(
              tipo: TipoHistoria.respiro,
              jornada: j,
              titulo: 'RESPIRO',
              texto: 'Los $propio cortaron una racha de $rachaP derrotas ganándole a los $rival.',
              franquiciaId: u,
              destacado: true,
              reaccion: reaccion('respiro$j', const [
                Reaccion('DT', 'Esto no se arregla en un día, pero hoy volvimos a ser nosotros.'),
                Reaccion('Vestuario', 'Se sintió el alivio: hablamos claro y se vio en la cancha.'),
              ]),
            ),
          );
        }
        v++;
        rachaG++;
        rachaP = 0;
        final invicto = d == 0;
        if (invicto && const {5, 10, 15, 20, 30, 40, 50, 60, 70}.contains(v)) {
          add(
            Historia(
              tipo: TipoHistoria.invicto,
              jornada: j,
              titulo: 'INVICTOS: $v-0',
              texto: switch (v) {
                >= 50 => '$v-0. Ya no es una ilusión: el 82-0 está a la vista y todos quieren ser quienes lo frenen.',
                >= 20 => '$v-0. Los $propio siguen sin perder y el país ya habla del 82-0.',
                _ => '$v-0 para arrancar: los $propio todavía no conocen la derrota.',
              },
              franquiciaId: u,
              destacado: true,
              reaccion: v >= 10
                  ? reaccion('inv$v', const [
                      Reaccion('Prensa', '¿Hasta dónde llegan? Nadie les encuentra la vuelta.'),
                      Reaccion('Afición', 'Las entradas vuelan: todos quieren ver caer o seguir el invicto.'),
                    ])
                  : null,
            ),
          );
        } else if (const {5, 8, 10, 15, 20, 25, 30, 33, 34, 40}.contains(rachaG) && !(invicto && v >= 5)) {
          final recordNba = RecordNba.racha.marca.toInt();
          add(
            Historia(
              tipo: TipoHistoria.racha,
              jornada: j,
              titulo: rachaG == recordNba
                  ? 'IGUALARON EL RÉCORD: $rachaG SEGUIDOS'
                  : rachaG > recordNba
                  ? 'RÉCORD HISTÓRICO: $rachaG SEGUIDOS'
                  : 'RACHA DE $rachaG',
              texto: rachaG >= recordNba
                  ? 'Los $propio llegaron a $rachaG victorias al hilo: la marca de los Lakers del 71-72 ya es historia.'
                  : _uno(<String>[
                      'Los $propio ya suman $rachaG triunfos seguidos ($v-$d).',
                      'Van $rachaG al hilo y el vestuario está encendido.',
                      '¿Quién frena a los $propio? $rachaG victorias seguidas.',
                    ], k('rg$j')),
              franquiciaId: u,
              destacado: true,
              reaccion: rachaG >= 8
                  ? reaccion('rg$rachaG', const [
                      Reaccion('DT', 'No miramos la tabla. Mañana es otro partido y hay que ganarlo igual.'),
                      Reaccion('Vestuario', 'Hay una química rara: nadie quiere ser el que corte esto.'),
                      Reaccion('Afición', 'El estadio ruge: la gente cree que este año se puede.'),
                    ])
                  : null,
            ),
          );
        }
      } else {
        if (d == 0 && v >= 3) {
          add(
            Historia(
              tipo: TipoHistoria.caidaInvicto,
              jornada: j,
              titulo: 'SE ACABÓ EL INVICTO',
              texto:
                  'Los $rival frenaron a los $propio después de $v victorias seguidas: el 82-0 quedó en el recuerdo.',
              franquiciaId: rivalId,
              destacado: true,
              reaccion: reaccion('caida$j', const [
                Reaccion('DT', 'Duele, pero el objetivo sigue siendo ganar el anillo.'),
                Reaccion('Prensa', 'Se terminó el sueño perfecto. Ahora empieza la verdadera temporada.'),
                Reaccion('Afición', 'Aplausos igual: lo que hicieron hasta acá fue espectacular.'),
              ]),
            ),
          );
        } else if (rachaG >= 5) {
          add(
            Historia(
              tipo: TipoHistoria.finRacha,
              jornada: j,
              titulo: 'SE CORTÓ LA RACHA DE $rachaG',
              texto: 'Los $rival le pusieron fin a las $rachaG victorias seguidas de los $propio.',
              franquiciaId: rivalId,
              destacado: true,
              reaccion: reaccion('fin$j', const [
                Reaccion('DT', 'Las rachas se terminan. Lo importante es cómo respondemos.'),
                Reaccion('Vestuario', 'Se nos escapó, pero estamos tranquilos: el equipo está sano.'),
              ]),
            ),
          );
        }
        d++;
        rachaP++;
        rachaG = 0;
        if (const {3, 5, 7, 10}.contains(rachaP)) {
          add(
            Historia(
              tipo: TipoHistoria.crisis,
              jornada: j,
              titulo: rachaP >= 7 ? 'CRISIS PROFUNDA' : 'ALARMAS ENCENDIDAS',
              texto: _uno(<String>[
                'Los $propio acumulan $rachaP derrotas al hilo ($v-$d) y el ambiente se pone espeso.',
                'Van $rachaP caídas seguidas: en el club ya hablan de "reunión de urgencia".',
              ], k('cr$j')),
              franquiciaId: u,
              destacado: true,
              reaccion: reaccion('cr$rachaP', const [
                Reaccion('Prensa', 'Se discute todo: la rotación, las tácticas y hasta el entrenador.'),
                Reaccion('Afición', 'Hay silbidos en la tribuna. La paciencia se acaba.'),
                Reaccion('Vestuario', 'Faltan respuestas y sobran excusas: hay que sacudirse ya.'),
              ]),
            ),
          );
        }
      }
    }

    // ── Lesiones: figuras tuyas y la del próximo rival. ──
    final equipos = liga.equipos(t);
    final proximo = liga.proximoDelUsuario(t);
    final proximoRival = proximo == null ? null : (proximo.localId == u ? proximo.visitanteId : proximo.localId);
    final jornadaActual = max(1, ultimaJornada);
    final mediasPropias = [
      for (final j in [...t.plantel.jugadores, ...t.suplentes]) j.media,
    ]..sort((a, b) => b.compareTo(a));
    final umbralFigura = mediasPropias.length >= 3 ? mediasPropias[2] : 0;
    for (final e in t.lesiones.entries) {
      final jug = liga.jugador(e.key);
      final fid = equipos[e.key];
      if (jug == null || fid == null) continue;
      final partidos = e.value;
      final mio = fid == u;
      final esFigura = jug.media >= 80 || (mio && jug.media >= umbralFigura);
      if (!esFigura && !(mio && partidos >= 8)) continue;
      if (!mio && fid != proximoRival) continue;
      final gravedad = partidos >= 11
          ? 'lesión grave: se pierde al menos $partidos partidos'
          : partidos >= 4
          ? 'estará $partidos partidos afuera'
          : 'es duda: ${partidos == 1 ? 'un partido' : '$partidos partidos'} de baja';
      if (mio) {
        add(
          Historia(
            tipo: TipoHistoria.lesion,
            jornada: jornadaActual,
            titulo: partidos >= 11 ? 'GOLPE DURÍSIMO: ${apellido(jug)}' : 'BAJA: ${apellido(jug)}',
            texto:
                '${jug.nombre} $gravedad. '
                '${partidos >= 11 ? 'Es un golpe para las aspiraciones de los $propio.' : 'Los $propio tendrán que rearmarse sin él.'}',
            franquiciaId: u,
            jugadorId: jug.id,
            destacado: true,
            reaccion: reaccion('les${jug.id}', [
              Reaccion('DT', 'Es una pérdida enorme, pero acá todos tienen que dar un paso al frente.'),
              const Reaccion('Vestuario', 'Vamos a jugar por él. No nos vamos a caer.'),
              const Reaccion('Afición', 'Le mandamos fuerza: lo necesitamos de vuelta cuanto antes.'),
            ]),
          ),
        );
      } else {
        add(
          Historia(
            tipo: TipoHistoria.rival,
            jornada: jornadaActual,
            titulo: 'RIVAL GOLPEADO',
            texto:
                '${jug.nombre}, figura de los ${nombre(fid)}, $gravedad. Es tu próximo rival: cambia el panorama del cruce.',
            franquiciaId: fid,
            jugadorId: jug.id,
            destacado: true,
          ),
        );
      }
    }

    // ── Hitos de la liga y de tus jugadores (con los promedios de hoy). ──
    final cand = candidatos(t, liga);
    final maxPj = t.lineas.values.fold(0, (a, l) => max(a, l.pj));
    if (maxPj >= 10 && cand.isNotEmpty) {
      final goleo = [...cand]..sort((a, b) => b.por(b.linea.pts).compareTo(a.por(a.linea.pts)));
      final l = goleo.first;
      add(
        Historia(
          tipo: TipoHistoria.hito,
          jornada: jornadaActual,
          titulo: 'MÁXIMO ANOTADOR: ${apellido(l.jugador)}',
          texto: '${l.jugador.nombre} lidera la liga con ${_dec(l.por(l.linea.pts))} puntos por partido.',
          franquiciaId: l.franquiciaId,
          jugadorId: l.jugadorId,
          destacado: l.franquiciaId == u,
        ),
      );
      for (final g in cand.where((g) => g.franquiciaId == u && g.linea.pj >= 10)) {
        final pts = g.por(g.linea.pts), reb = g.por(g.linea.reb), ast = g.por(g.linea.ast);
        if (pts >= 10 && reb >= 10 && ast >= 7) {
          add(
            Historia(
              tipo: TipoHistoria.hito,
              jornada: jornadaActual,
              titulo: 'CAMINO AL TRIPLE-DOBLE DE PROMEDIO',
              texto: '${g.jugador.nombre} promedia ${_dec(pts)}-${_dec(reb)}-${_dec(ast)}: números de otra galaxia.',
              franquiciaId: u,
              jugadorId: g.jugadorId,
              destacado: true,
            ),
          );
        } else if (pts >= 10 && reb >= 10) {
          add(
            Historia(
              tipo: TipoHistoria.hito,
              jornada: jornadaActual,
              titulo: 'DOBLE-DOBLE DE PROMEDIO',
              texto: '${g.jugador.nombre} promedia ${_dec(pts)} puntos y ${_dec(reb)} rebotes: manda en la pintura.',
              franquiciaId: u,
              jugadorId: g.jugadorId,
              destacado: true,
            ),
          );
        }
      }
      // Carrera al MVP: duelo de estrellas si están cerca, líder si no.
      final carrera = carreraMvp(t, liga);
      if (carrera.length >= 2 && t.registroUsuario.jugados >= 5) {
        final a = carrera[0], b = carrera[1];
        final cerca = (a.valor - b.valor).abs() <= a.valor * 0.06;
        if (cerca) {
          add(
            Historia(
              tipo: TipoHistoria.duelo,
              jornada: jornadaActual,
              titulo: 'DUELO POR EL MVP',
              texto:
                  '${a.jugador.nombre} (${nombre(a.franquiciaId)}) y ${b.jugador.nombre} (${nombre(b.franquiciaId)}) '
                  'se pelean el MVP: ${_dec(a.valor)} contra ${_dec(b.valor)}. Un mal partido y se da vuelta.',
              franquiciaId: a.franquiciaId == u
                  ? a.franquiciaId
                  : b.franquiciaId == u
                  ? b.franquiciaId
                  : a.franquiciaId,
              jugadorId: a.jugadorId,
              destacado: a.franquiciaId == u || b.franquiciaId == u,
            ),
          );
        } else {
          add(
            Historia(
              tipo: TipoHistoria.mvp,
              jornada: jornadaActual,
              titulo: 'PUNTERO DEL MVP',
              texto:
                  '${a.jugador.nombre} se despega en la carrera al MVP con ${_dec(a.por(a.linea.pts))} puntos por partido.',
              franquiciaId: a.franquiciaId,
              jugadorId: a.jugadorId,
              destacado: a.franquiciaId == u,
            ),
          );
        }
      }
      final mejorado = calcularPremios(t, liga).masMejorado;
      if (mejorado != null && t.registroUsuario.jugados >= 10) {
        final s = mejorado.jugador.stats;
        final dif = mejorado.por(mejorado.linea.pts) - s.ppp;
        add(
          Historia(
            tipo: TipoHistoria.mejorado,
            jornada: jornadaActual,
            titulo: 'CARRERA AL MÁS MEJORADO',
            texto: '${mejorado.jugador.nombre} anota ${_dec(dif)} puntos más por partido de lo que se esperaba de él.',
            franquiciaId: mejorado.franquiciaId,
            jugadorId: mejorado.jugadorId,
            destacado: mejorado.franquiciaId == u,
          ),
        );
      }
    }

    // ── Récords (históricos y personales). ──
    for (final r in recordsEnJuego(t, liga)) {
      add(
        Historia(
          tipo: TipoHistoria.record,
          jornada: jornadaActual,
          titulo: 'RÉCORD EN JUEGO',
          texto: r.texto,
          franquiciaId: u,
          destacado: true,
        ),
      );
    }
    final enCurso = max(0, rachaDe(t, u));
    if (mejorRachaHistorica >= 3 && enCurso > mejorRachaHistorica) {
      add(
        Historia(
          tipo: TipoHistoria.record,
          jornada: jornadaActual,
          titulo: 'RÉCORD PERSONAL',
          texto: 'Tu racha de $enCurso victorias ya superó tu mejor marca ($mejorRachaHistorica). ¡Seguí así!',
          franquiciaId: u,
          destacado: true,
        ),
      );
    }

    // ── Rivales en llamas (variedad: una noticia que cambia el cruce). ──
    for (final f in {
      for (final p in t.calendario) ...[p.localId, p.visitanteId],
    }) {
      if (f == u) continue;
      final r = rachaDe(t, f);
      if (r >= 8) {
        add(
          Historia(
            tipo: TipoHistoria.rival,
            jornada: jornadaActual,
            titulo: 'EN LLAMAS: ${nombre(f).toUpperCase()}',
            texto:
                'Los ${nombre(f)} llevan $r victorias seguidas.${f == proximoRival ? ' Y son tu próximo rival.' : ''}',
            franquiciaId: f,
            destacado: f == proximoRival,
          ),
        );
      }
    }

    // ── Partido bisagra (el próximo). ──
    if (proximo != null && proximoRival != null && t.registroUsuario.jugados >= 10) {
      final (pv, pd) = _record(t, proximoRival);
      final ru = t.registroUsuario;
      final conf = {for (final f in liga.franquicias) f.id: f.conferencia};
      final misma = conf[u] != null && conf[u] == conf[proximoRival];
      final parejos = (pv - ru.victorias).abs() <= 2 && pv / max(1, pv + pd) >= 0.5 && ru.porcentaje >= 0.5;
      if (misma && parejos) {
        add(
          Historia(
            tipo: TipoHistoria.bisagra,
            jornada: proximo.jornada,
            titulo: 'PARTIDO BISAGRA',
            texto:
                'Los ${nombre(proximoRival)} ($pv-$pd) pelean tu lugar en la conferencia: el cruce de hoy puede definir quién se queda con la localía.',
            franquiciaId: proximoRival,
            destacado: true,
          ),
        );
      } else if (pv / max(1, pv + pd) >= 0.7 && ru.porcentaje >= 0.7) {
        add(
          Historia(
            tipo: TipoHistoria.bisagra,
            jornada: proximo.jornada,
            titulo: 'CHOQUE DE PUNTEROS',
            texto:
                '${nombre(u)} (${ru.victorias}-${ru.derrotas}) contra ${nombre(proximoRival)} ($pv-$pd): se miden dos candidatos.',
            franquiciaId: proximoRival,
            destacado: true,
          ),
        );
      }
    }

    // ── Playoffs: tu serie actual o el cierre. ──
    final serie = t.serieDelUsuario;
    if (serie != null && !serie.terminada) {
      final p = presionDeSerie(serie, u);
      if (p != null) {
        final rivalId = serie.altoId == u ? serie.bajoId : serie.altoId;
        add(
          Historia(
            tipo: TipoHistoria.serie,
            jornada: 1000,
            titulo: '${p.etiqueta} · ${serie.ronda.etiqueta.toUpperCase()}',
            texto: 'Contra los ${nombre(rivalId)}: ${p.detalle}',
            franquiciaId: rivalId,
            destacado: true,
          ),
        );
      }
    } else if (t.campeonId == u) {
      add(
        const Historia(
          tipo: TipoHistoria.serie,
          jornada: 1000,
          titulo: 'CAMPEONES',
          texto: 'La temporada terminó con el anillo en casa.',
          destacado: true,
        ),
      );
    } else if (t.eliminacion != null) {
      add(
        Historia(
          tipo: TipoHistoria.serie,
          jornada: 1000,
          titulo: 'ELIMINADOS',
          texto: 'La temporada de los $propio terminó en ${t.eliminacion!.ronda.etiqueta}.',
          franquiciaId: u,
          destacado: true,
        ),
      );
    }

    // ── Balance (siempre hay algo para leer) y arranque. ──
    if (propios.isEmpty) {
      add(
        Historia(
          tipo: TipoHistoria.inicio,
          jornada: 0,
          titulo: 'ARRANCA LA TEMPORADA',
          texto: 'Los $propio salen a buscar el 82-0. Todavía no hay historias: las escribís vos, partido a partido.',
          franquiciaId: u,
          destacado: true,
        ),
      );
    } else {
      final r = t.registroUsuario;
      add(
        Historia(
          tipo: TipoHistoria.resumen,
          jornada: ultimaJornada,
          titulo: 'BALANCE: ${r.victorias}-${r.derrotas}',
          texto: r.derrotas == 0
              ? 'Los $propio siguen invictos tras ${r.jugados} partidos.'
              : 'Los $propio llevan ${r.victorias} victorias y ${r.derrotas} derrotas (${(r.porcentaje * 100).round()} %).',
          franquiciaId: u,
          destacado: true,
        ),
      );
    }

    // Más nuevas primero; con la misma jornada, primero lo importante. Sin repetir seguido el mismo cuento.
    lista.sort((a, b) {
      final c = b.jornada.compareTo(a.jornada);
      if (c != 0) return c;
      return (b.destacado ? 1 : 0).compareTo(a.destacado ? 1 : 0);
    });
    final salida = <Historia>[];
    for (final h in lista) {
      if (salida.isNotEmpty && salida.last.titulo == h.titulo && salida.last.franquiciaId == h.franquiciaId) continue;
      if (salida.any((x) => x.clave == h.clave)) continue;
      salida.add(h);
      if (salida.length >= limite) break;
    }
    return salida;
  }

  /// Historias nuevas entre dos estados de la misma temporada (lo que pasó con el último partido o jornada).
  static List<Historia> nuevas(
    Temporada antes,
    Temporada despues,
    Liga liga, {
    required String Function(String franquiciaId) nombre,
    int mejorRachaHistorica = 0,
  }) {
    final vistas = {
      for (final h in generar(antes, liga, nombre: nombre, mejorRachaHistorica: mejorRachaHistorica)) h.clave,
    };
    return [
      for (final h in generar(despues, liga, nombre: nombre, mejorRachaHistorica: mejorRachaHistorica))
        if (!vistas.contains(h.clave) && h.tipo != TipoHistoria.resumen) h,
    ];
  }

  /// Hitos de una noche individual (40 puntos, triple-doble…) a partir de la línea del partido de cada
  /// jugador. Sirve con la diferencia de líneas de dos estados de la temporada (ver [hitosEntre]) o con
  /// el box score de un partido en vivo. [nombreDe] da el nombre visible del jugador.
  static List<Historia> hitosDeNoche(
    Map<String, LineaEstadistica> noche, {
    required String? Function(String jugadorId) nombreDe,
    required String? Function(String jugadorId) franquiciaDe,
    required String usuarioId,
    int jornada = 0,
  }) {
    final r = <Historia>[];
    for (final e in noche.entries) {
      final l = e.value;
      final nombre = nombreDe(e.key);
      if (nombre == null) continue;
      final f = franquiciaDe(e.key);
      void hito(String titulo, String texto) => r.add(
        Historia(
          tipo: TipoHistoria.hito,
          jornada: jornada,
          titulo: titulo,
          texto: texto,
          franquiciaId: f,
          jugadorId: e.key,
          destacado: f == usuarioId,
        ),
      );
      final dobles = [l.pts, l.reb, l.ast, l.rob, l.tap].where((x) => x >= 10).length;
      if (l.pts >= 50) {
        hito('NOCHE HISTÓRICA: ${l.pts}', '$nombre anotó ${l.pts} puntos: una de esas noches que se cuentan por años.');
      } else if (l.pts >= 40) {
        hito('${l.pts} PUNTOS', '$nombre explotó con ${l.pts} puntos y se llevó el partido puesto.');
      }
      if (dobles >= 3) {
        hito('TRIPLE-DOBLE', '$nombre cerró con triple-doble: ${l.pts} pts, ${l.reb} reb y ${l.ast} ast.');
      }
      if (l.tap >= 7) hito('MURALLA: ${l.tap} TAPONES', '$nombre puso ${l.tap} tapones: nadie entró a la pintura.');
      if (l.rob >= 6) hito('LADRÓN DE BALONES', '$nombre robó ${l.rob} pelotas: la defensa fue una locura.');
      if (l.t3I >= 8) hito('LLUVIA DE TRIPLES', '$nombre metió ${l.t3I} triples: desde cualquier lado le entraba.');
    }
    return r;
  }

  /// Diferencia de líneas entre dos estados: lo que sumó cada jugador, para los que jugaron justo un partido
  /// (cuando se simula de a uno) — así sale la "línea del partido" sin guardar logs por partido.
  static Map<String, LineaEstadistica> lineasDelUltimo(Temporada antes, Temporada despues) {
    final r = <String, LineaEstadistica>{};
    for (final e in despues.lineas.entries) {
      final a = antes.lineas[e.key];
      final pjAntes = a?.pj ?? 0;
      if (e.value.pj - pjAntes != 1) continue;
      final l = LineaEstadistica()
        ..pj = 1
        ..pts = e.value.pts - (a?.pts ?? 0)
        ..reb = e.value.reb - (a?.reb ?? 0)
        ..ast = e.value.ast - (a?.ast ?? 0)
        ..rob = e.value.rob - (a?.rob ?? 0)
        ..tap = e.value.tap - (a?.tap ?? 0)
        ..per = e.value.per - (a?.per ?? 0)
        ..t3I = e.value.t3I - (a?.t3I ?? 0)
        ..t3A = e.value.t3A - (a?.t3A ?? 0);
      r[e.key] = l;
    }
    return r;
  }

  /// Hitos de la noche entre dos estados de temporada (solo de los jugadores de tu partido).
  static List<Historia> hitosEntre(
    Temporada antes,
    Temporada despues,
    Liga liga, {
    required String Function(String franquiciaId) nombre,
  }) {
    final equipos = liga.equipos(despues);
    final u = despues.franquiciaUsuarioId;
    final jugado = despues.calendario.where((p) => p.jugado && p.participa(u)).toList()
      ..sort((a, b) => a.jornada.compareTo(b.jornada));
    final jornada = jugado.isEmpty ? 0 : jugado.last.jornada;
    final participantes = jugado.isEmpty ? <String>{} : {jugado.last.localId, jugado.last.visitanteId};
    final noche = {
      for (final e in lineasDelUltimo(antes, despues).entries)
        if (participantes.contains(equipos[e.key])) e.key: e.value,
    };
    return hitosDeNoche(
      noche,
      nombreDe: (id) => liga.jugador(id)?.nombre,
      franquiciaDe: (id) => equipos[id],
      usuarioId: u,
      jornada: jornada,
    );
  }

  /// Resumen en una frase de tu último partido (para la tarjeta "tras el partido").
  static String? ultimoPartido(Temporada t, {required String Function(String franquiciaId) nombre}) {
    final u = t.franquiciaUsuarioId;
    final jugados = t.calendario.where((p) => p.jugado && p.participa(u)).toList()
      ..sort((a, b) => a.jornada.compareTo(b.jornada));
    if (jugados.isEmpty) return null;
    final Partido p = jugados.last;
    final gane = p.ganadorId == u;
    final rivalId = p.localId == u ? p.visitanteId : p.localId;
    final (mios, suyos) = p.localId == u ? (p.puntosLocal, p.puntosVisitante) : (p.puntosVisitante, p.puntosLocal);
    final racha = rachaDe(t, u);
    final r = t.registroUsuario;
    final cola = racha >= 2
        ? ' Ya son $racha seguidas.'
        : racha <= -2
        ? ' Ya son ${-racha} caídas seguidas.'
        : '';
    return '${gane ? 'Ganaste' : 'Perdiste'} $mios-$suyos ${p.localId == u ? 'contra' : 'visitando a'} los ${nombre(rivalId)}. '
        'Quedás ${r.victorias}-${r.derrotas}.$cola';
  }
}
