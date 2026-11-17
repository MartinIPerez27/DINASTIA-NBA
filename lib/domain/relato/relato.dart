import 'dart:collection';
import 'dart:math';

import '../entities/jugador.dart';
import '../motor.dart';
import '../premios.dart' show apellido;
import 'catalogo.dart';
import 'contexto_relato.dart';

export 'catalogo.dart';
export 'contexto_relato.dart';

/// Estadística acumulada de un jugador en el partido (la lleva el propio relato).
class _Stat {
  int pts = 0, reb = 0, ast = 0, rob = 0, tap = 0, faltas = 0, triplesSeguidos = 0;
  bool dominante = false, alto = false, muyAlto = false, dd = false, td = false;

  int get dobles => [pts, reb, ast, rob, tap].where((x) => x >= 10).length;

  /// "28 puntos, 9 rebotes y 6 asistencias".
  String get linea {
    final partes = [
      if (pts > 0) '$pts punto${pts == 1 ? '' : 's'}',
      if (reb > 0) '$reb rebote${reb == 1 ? '' : 's'}',
      if (ast > 0) '$ast asistencia${ast == 1 ? '' : 's'}',
      if (rob >= 3) '$rob robos',
      if (tap >= 3) '$tap tapones',
    ];
    if (partes.length <= 1) return partes.join();
    return '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';
  }
}

/// Transmisión con dos voces: el [Relator][Personaje.relator] canta y da el dato; el
/// [Comentarista][Personaje.comentarista] reacciona y pone el color. No hablan en cada jugada: hay
/// silencios, ráfagas en los momentos clave y el Comentarista retoma cuando el trámite está parejo.
///
/// ```dart
/// final relato = Relato();
/// for (final l in relato.apertura(ctx)) ...      // al arrancar
/// for (final l in relato.linea(evento, ctx)) ... // por cada jugada (0 a 4 líneas)
/// relato.observar(evento, ctx);                  // jugadas que se saltan sin relatarlas
/// ```
class Relato {
  Relato({Random? azar, this.memoria = 30}) : _azar = azar ?? Random();

  final Random _azar;

  /// Cuántas frases recientes se evitan mientras haya alternativas.
  final int memoria;

  static final _marcador = RegExp(r'\{(\w+)\}');
  static const _opcionales = {'racha'};

  // Memoria de frases
  final _recientes = Queue<String>();
  final _ultimoUso = <String, int>{};
  var _usos = 0;

  // Estado del partido
  var _pl = 0, _pv = 0;
  var _inicioCuartoL = 0, _inicioCuartoV = 0;
  var _runL = 0, _runV = 0;
  var _maxDeficitL = 0, _maxDeficitV = 0;
  var _cambiosDeMando = 0;
  var _clutchAntes = false;
  var _clutchDisparos = 0;
  var _eventos = 0;
  var _desdeComentarista = 0;
  var _desdeTramite = 999, _desdePicado = 999;
  var _calor = 0.0;
  var _desdeUltimoDato = 0;
  var _tramiteDicho = false, _eliminacionDicha = false;
  EventoPartido? _ultimo;
  final _stats = <String, _Stat>{};
  final _expulsados = <String>{};
  final _extrasUsados = <Situacion>{};
  final _fatigaDicha = <String, int>{};

  /// Estado del cierre del marcador, útil para tests.
  int get eventosVistos => _eventos;

  // ───────────────────────── API pública ─────────────────────────

  /// La situación principal de una jugada (sin contexto). [finalApretado]: últimos 2:30 del cuarto
  /// final con 5 puntos o menos de diferencia.
  static Situacion situacionDe(EventoPartido e, {bool finalApretado = false}) {
    switch (e.tipo) {
      case TipoEvento.tiro:
        if (e.convertido) {
          if (e.desdeLejos) return Situacion.chicharraLejana;
          if (e.interferencia) return Situacion.interferencia;
          if (e.chicharra) return Situacion.chicharra;
          if (e.alleyOop) return Situacion.alleyOop;
          if (e.volcada) return Situacion.volcada;
          if (e.triple && finalApretado) return Situacion.tripleCierre;
          if (e.libres > 0) return Situacion.canastaYFalta;
          if (e.triple) return Situacion.triple;
          if (e.contraataque) return Situacion.contraataque;
          if (e.asistenteId != null) return Situacion.dobleAsistido;
          return Situacion.doble;
        }
        if (e.desdeLejos) return Situacion.tiroDesesperado;
        if (e.taponado) return e.reboteOfensivo ? Situacion.taponRecuperado : Situacion.tapon;
        if (e.reboteOfensivo) return Situacion.reboteOfensivo;
        return Situacion.ladrillo;
      case TipoEvento.libres:
        if (finalApretado) return Situacion.lineaDeSuspiros;
        final intentos = e.libres == 0 ? (e.triple ? 3 : 2) : e.libres;
        if (e.puntos >= intentos) return Situacion.libresPerfectos;
        return e.puntos == 0 ? Situacion.libresFallados : Situacion.libresParciales;
      case TipoEvento.perdida:
        if (e.defensorId != null) return Situacion.robo;
        return switch (e.perdida) {
          TipoPerdida.carga => Situacion.carga,
          TipoPerdida.veinticuatro => Situacion.perdida24,
          TipoPerdida.tresSegundos => Situacion.perdida3s,
          TipoPerdida.campoAtras => Situacion.campoAtras,
          TipoPerdida.pasos => Situacion.pasos,
          TipoPerdida.dobles => Situacion.dobles,
          _ => Situacion.perdidaAfuera,
        };
      case TipoEvento.falta:
        return switch (e.falta) {
          TipoFalta.tecnica => Situacion.tecnica,
          TipoFalta.flagrante => Situacion.flagrante,
          TipoFalta.intencional => Situacion.intencional,
          TipoFalta.bonus => Situacion.bonus,
          _ => Situacion.faltaPersonal,
        };
      case TipoEvento.salto:
        return Situacion.salto;
      case TipoEvento.cambio:
        return Situacion.cambio;
      case TipoEvento.tiempoMuerto:
        return Situacion.tiempoMuerto;
      case TipoEvento.finCuarto:
        if (e.cuarto >= 5) return Situacion.prorroga;
        return e.cuarto - 1 == 2 ? Situacion.entretiempo : Situacion.finCuarto;
      case TipoEvento.finPartido:
        return Situacion.finPartido;
    }
  }

  /// Apertura de la transmisión: abre el Comentarista, el Relator da los datos y se arranca.
  List<LineaRelato> apertura(ContextoRelato ctx) {
    final v = _base(ctx);
    final i = ctx.playoffs ? 3 : 1;
    final lineas = <LineaRelato>[];
    void di(Personaje p, Situacion s) {
      if (_decir(p, s, v, i) case final l?) lineas.add(l);
    }

    di(Personaje.comentarista, Situacion.apertura);
    final datos = [
      if (ctx.noHayManana) Situacion.eliminacion,
      if (ctx.playoffs) Situacion.serie,
      Situacion.historial,
      Situacion.rivalidad,
      Situacion.record,
      Situacion.localia,
    ];
    for (final s in datos) {
      final antes = lineas.length;
      di(Personaje.relator, s);
      if (lineas.length > antes) {
        _extrasUsados.add(s);
        break;
      }
    }
    for (final s in [Situacion.recordEnJuego, Situacion.historiaTemporada]) {
      // El gancho lo dice el Relator y el Comentarista lo comenta.
      if (_decir(Personaje.relator, s, v, i) case final r?) {
        lineas.add(r);
        if (_decir(Personaje.comentarista, s, v, i) case final c?) lineas.add(c);
        _extrasUsados.add(s);
        break;
      }
    }
    di(Personaje.comentarista, Situacion.arranque);
    _desdeComentarista = 0;
    return lineas;
  }

  /// Línea(s) para una jugada: de 0 a 4. Actualiza el estado del relato. Con [siempre], el Relator
  /// canta la jugada aunque el ritmo natural lo dejara en silencio.
  List<LineaRelato> linea(EventoPartido e, ContextoRelato ctx, {bool siempre = false}) =>
      _procesar(e, ctx, hablar: true, siempre: siempre);

  /// Registra una jugada sin relatarla (cuando se salta el partido).
  void observar(EventoPartido e, ContextoRelato ctx) => _procesar(e, ctx, hablar: false, siempre: false);

  /// Al volver a mirar después de saltar: ambos ubican al público.
  List<LineaRelato> retoma(ContextoRelato ctx) {
    final e = _ultimo;
    if (e == null) return const [];
    final v = _jugada(e, _base(ctx), ctx);
    final i = _clutchAhora(e) ? 3 : 1;
    _desdeComentarista = 0;
    return [
      ?_decir(Personaje.relator, Situacion.retoma, v, i),
      ?_decir(Personaje.comentarista, Situacion.retoma, v, i),
    ];
  }

  // ───────────────────────── Motor ─────────────────────────

  bool _finalApretado(EventoPartido e) =>
      e.cuarto >= 4 &&
      e.tipo != TipoEvento.finCuarto &&
      e.reloj <= 150 &&
      (e.marcadorLocal - e.marcadorVisitante).abs() <= 5;

  bool _clutchAhora(EventoPartido e) =>
      e.cuarto >= 4 && e.reloj <= 300 && (e.marcadorLocal - e.marcadorVisitante).abs() <= 6;

  _Stat _s(String id) => _stats.putIfAbsent(id, _Stat.new);

  static String _nombreCuarto(int c) => switch (c) {
    1 => 'primer cuarto',
    2 => 'segundo cuarto',
    3 => 'tercer cuarto',
    4 => 'último cuarto',
    _ => 'tiempo suplementario',
  };

  static String _formatoReloj(double segundos) {
    final s = max(0, segundos.round());
    return s < 60 ? '$s segundos' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Marcadores comunes a todas las situaciones.
  Map<String, String> _base(ContextoRelato ctx) {
    final nl = ctx.nombreLocal ?? 'el local', nv = ctx.nombreVisitante ?? 'el visitante';
    final dif = _pl - _pv;
    final racha = ctx.rachaVictorias;
    return {
      'nloc': nl,
      'nvis': nv,
      'cloc': ctx.ciudadLocal ?? nl,
      'cvis': ctx.ciudadVisitante ?? nv,
      'cusuario':
          (ctx.usuarioLocal == null ? '' : (ctx.usuarioLocal! ? ctx.ciudadLocal : ctx.ciudadVisitante)) ??
          ctx.nombreUsuario ??
          '',
      'ganando': dif >= 0 ? (ctx.ciudadLocal ?? nl) : (ctx.ciudadVisitante ?? nv),
      'ciudad': ctx.ciudadLocal ?? '',
      'marc': dif >= 0 ? '$_pl-$_pv' : '$_pv-$_pl',
      'dif': '${dif.abs()}',
      'lider': dif == 0
          ? 'Empatados a $_pl'
          : '${dif > 0 ? (ctx.ciudadLocal ?? nl) : (ctx.ciudadVisitante ?? nv)} arriba por ${dif.abs()}',
      'usuario': ctx.nombreUsuario ?? '',
      'rival': ctx.nombreRival ?? '',
      'serie': ctx.textoSerie ?? '',
      'ronda': ctx.ronda ?? '',
      'juego': ctx.juegoSerie == null ? '' : 'juego ${ctx.juegoSerie}',
      'vic': ctx.victorias?.toString() ?? '',
      'der': ctx.derrotas?.toString() ?? '',
      'racha': racha != null && racha >= 3
          ? ', con $racha victorias seguidas'
          : racha != null && racha <= -3
          ? ', con ${-racha} derrotas seguidas'
          : '',
      if ((ctx.historialVictorias ?? 0) + (ctx.historialDerrotas ?? 0) > 0) ...{
        'hv': '${ctx.historialVictorias ?? 0}',
        'hd': '${ctx.historialDerrotas ?? 0}',
      },
      'ultimo': ctx.ultimoResultado ?? '',
      'riv': ctx.rivalidad ?? '',
      'rec': ctx.recordEnJuego ?? '',
      'hist': ctx.historia ?? '',
    };
  }

  /// Marcadores que dependen de la jugada.
  Map<String, String> _jugada(EventoPartido e, Map<String, String> v, ContextoRelato ctx) {
    String ap(String? id) => id == null || ctx.jugadores[id] == null ? '' : apellido(ctx.jugadores[id]!);
    final nl = v['nloc']!, nv = v['nvis']!;
    final ataca = e.local ? nl : nv, defiende = e.local ? nv : nl;
    final q = ap(e.jugadorId);
    final intentos = e.libres == 0 ? (e.triple ? 3 : 2) : e.libres;
    final base = e.triple ? 3 : 2;
    final libtxt = e.libres == 0
        ? ''
        : e.libres == 1
        ? (e.puntos >= 1 ? 'Adentro el libre.' : 'Falla el libre.')
        : e.puntos == 0
        ? '¡Falla los ${e.libres}!'
        : 'Mete ${e.puntos} de ${e.libres}.';
    final cuarto = e.tipo == TipoEvento.finCuarto ? e.cuarto - 1 : e.cuarto;
    final ganaLocal = e.marcadorLocal > e.marcadorVisitante;
    final top = _stats.entries.where((x) => x.value.pts > 0).fold<MapEntry<String, _Stat>?>(null, (a, b) {
      return a == null || b.value.pts > a.value.pts ? b : a;
    });
    final faltasDef = e.defensorId == null ? 0 : _s(e.defensorId!).faltas;
    final jug = {
      ...v,
      'q': q,
      'a': ap(e.asistenteId),
      'd': ap(e.defensorId),
      'p': ap(e.participanteId),
      'r': ap(e.reboteId),
      'e': ap(e.entraId),
      's': ap(e.saleId),
      'x': ap(e.expulsadoId),
      'g': e.convertido ? q : ap(e.defensorId),
      'eq': ataca,
      'rv': defiende,
      'ceq': e.local ? v['cloc']! : v['cvis']!,
      'crv': e.local ? v['cvis']! : v['cloc']!,
      'reloj': _formatoReloj(e.reloj),
      'cq': _nombreCuarto(cuarto),
      'lib': e.libres == 0 && e.tipo != TipoEvento.libres ? '' : '${e.puntos} de $intentos',
      'nlib': 'los $intentos',
      'libtxt': libtxt,
      'res': e.puntos > base ? 'convierte el libre adicional' : 'falla el libre adicional',
      'falta_n': switch (faltasDef) {
        1 => 'primera',
        2 => 'segunda',
        3 => 'tercera',
        4 => 'cuarta',
        5 => 'quinta',
        6 => 'sexta',
        _ => '',
      },
      'motivo': e.falta == TipoFalta.tecnica ? 'su segunda técnica' : 'su sexta falta personal',
      'gan': ganaLocal ? v['cloc']! : v['cvis']!,
      'perd': ganaLocal ? v['cvis']! : v['cloc']!,
      'pg': '${max(e.marcadorLocal, e.marcadorVisitante)}',
      'pp': '${min(e.marcadorLocal, e.marcadorVisitante)}',
      'mejor': top == null || ctx.jugadores[top.key] == null
          ? ''
          : 'El máximo anotador fue ${ap(top.key)}, con ${top.value.pts} puntos.',
      'parcial': '${v['cloc']} ${_pl - _inicioCuartoL}, ${v['cvis']} ${_pv - _inicioCuartoV}',
      'cambios': '$_cambiosDeMando',
    };
    return jug;
  }

  /// Datos base de probabilidad: (intensidad base, prob. del Relator, prob. del Comentarista).
  static (int, double, double) _perfil(Situacion s) => switch (s) {
    Situacion.doble => (1, .6, .10),
    Situacion.dobleAsistido => (1, .7, .18),
    Situacion.contraataque => (2, .85, .30),
    Situacion.canastaYFalta => (2, .95, .60),
    Situacion.triple => (2, .9, .35),
    Situacion.tripleCierre => (3, 1, .95),
    Situacion.volcada => (2, 1, .70),
    Situacion.alleyOop => (3, 1, .85),
    Situacion.tapon => (2, 1, .55),
    Situacion.taponRecuperado => (2, .9, .40),
    Situacion.reboteOfensivo => (1, .45, .20),
    Situacion.ladrillo => (0, .30, .12),
    Situacion.aro => (0, .35, .15),
    Situacion.tiroDesesperado => (1, .9, .40),
    Situacion.chicharraLejana => (4, 1, 1),
    Situacion.chicharra => (3, 1, .80),
    Situacion.interferencia => (1, 1, .50),
    Situacion.libresPerfectos => (1, .5, .08),
    Situacion.libresParciales => (1, .55, .15),
    Situacion.libresFallados => (1, .7, .35),
    Situacion.lineaDeSuspiros => (2, 1, .45),
    Situacion.robo => (2, .95, .40),
    Situacion.perdidaAfuera => (1, .6, .30),
    Situacion.perdida24 => (1, .9, .35),
    Situacion.perdida3s => (1, .85, .30),
    Situacion.campoAtras => (1, .85, .30),
    Situacion.pasos => (1, .8, .30),
    Situacion.dobles => (1, .85, .30),
    Situacion.carga => (1, .85, .40),
    Situacion.faltaPersonal => (0, .30, .06),
    Situacion.bonus => (1, .7, .25),
    Situacion.tecnica => (2, 1, .75),
    Situacion.flagrante => (3, 1, .80),
    Situacion.intencional => (2, .9, .35),
    Situacion.salto => (1, .9, .20),
    Situacion.cambio => (0, .30, .05),
    Situacion.cambioFaltas => (0, .5, .15),
    Situacion.cambioExpulsion => (1, 1, .50),
    Situacion.tiempoMuerto => (1, .9, .45),
    Situacion.tiempoMuertoParcial => (2, 1, .70),
    Situacion.finCuarto => (1, 1, 1),
    Situacion.entretiempo => (1, 1, 1),
    Situacion.prorroga => (3, 1, 1),
    Situacion.finPartido => (2, 1, 1),
    _ => (1, .5, .2),
  };

  List<LineaRelato> _procesar(EventoPartido e, ContextoRelato ctx, {required bool hablar, required bool siempre}) {
    _eventos++;
    _desdeComentarista++;
    _desdeTramite++;
    _desdePicado++;
    _desdeUltimoDato++;
    _calor = max(0, _calor - 0.12);

    // ── Marcador, rachas y vuelcos ──
    final difAntes = _pl - _pv;
    final dl = max(0, e.marcadorLocal - _pl), dv = max(0, e.marcadorVisitante - _pv);
    final runAntesL = _runL, runAntesV = _runV;
    _pl = e.marcadorLocal;
    _pv = e.marcadorVisitante;
    final dif = _pl - _pv;
    if (dl > 0) {
      _runL += dl;
      _runV = 0;
    }
    if (dv > 0) {
      _runV += dv;
      _runL = 0;
    }
    int umbralCruzado(int antes, int ahora) {
      for (final u in const [20, 16, 12, 8]) {
        if (antes < u && ahora >= u) return u;
      }
      return 0;
    }

    final cruceL = dl > 0 ? umbralCruzado(runAntesL, _runL) : 0;
    final cruceV = dv > 0 ? umbralCruzado(runAntesV, _runV) : 0;
    _maxDeficitL = max(_maxDeficitL, -dif);
    _maxDeficitV = max(_maxDeficitV, dif);
    final cambioMando = difAntes != 0 && dif != 0 && difAntes.sign != dif.sign;
    String? remontada;
    int deficit = 0;
    if (cambioMando) {
      _cambiosDeMando++;
      final localPasa = dif > 0;
      deficit = localPasa ? _maxDeficitL : _maxDeficitV;
      if (deficit >= 10) {
        remontada = localPasa ? 'local' : 'visitante';
        if (localPasa) {
          _maxDeficitL = 0;
        } else {
          _maxDeficitV = 0;
        }
      }
    }

    // ── Estadísticas ──
    final tocados = <String>{};
    void toca(String? id) {
      if (id != null) tocados.add(id);
    }

    switch (e.tipo) {
      case TipoEvento.tiro:
        if (e.jugadorId != null) {
          final st = _s(e.jugadorId!);
          if (e.convertido) st.pts += e.puntos;
          if (e.triple) st.triplesSeguidos = e.convertido ? st.triplesSeguidos + 1 : 0;
          toca(e.jugadorId);
        }
        if (e.convertido && e.asistenteId != null) {
          _s(e.asistenteId!).ast++;
          toca(e.asistenteId);
        }
        if (!e.convertido && e.reboteId != null) {
          _s(e.reboteId!).reb++;
          toca(e.reboteId);
        }
        if (e.taponado && e.defensorId != null) {
          _s(e.defensorId!).tap++;
          toca(e.defensorId);
        }
      case TipoEvento.libres:
        if (e.jugadorId != null) {
          _s(e.jugadorId!).pts += e.puntos;
          toca(e.jugadorId);
        }
      case TipoEvento.falta:
        if (e.jugadorId != null) {
          _s(e.jugadorId!).pts += e.puntos;
          toca(e.jugadorId);
        }
        if (e.defensorId != null && e.falta != TipoFalta.tecnica) _s(e.defensorId!).faltas++;
        _calor += switch (e.falta) {
          TipoFalta.tecnica || TipoFalta.flagrante => 3,
          TipoFalta.intencional => 0.5,
          _ => 1,
        };
      case TipoEvento.perdida:
        if (e.defensorId != null) {
          _s(e.defensorId!).rob++;
          toca(e.defensorId);
        } else if (e.perdida == TipoPerdida.carga) {
          if (e.jugadorId != null) _s(e.jugadorId!).faltas++;
          _calor += 1;
        }
      default:
    }

    // ── Cierres de cuarto: el parcial se mide antes de reiniciar ──
    final situacionBase = situacionDe(e, finalApretado: _finalApretado(e));
    final v0 = hablar ? _base(ctx) : const <String, String>{};
    final v = hablar ? _jugada(e, v0, ctx) : const <String, String>{};
    if (e.tipo == TipoEvento.finCuarto) {
      _inicioCuartoL = _pl;
      _inicioCuartoV = _pv;
      _runL = 0;
      _runV = 0;
    }
    _ultimo = e;

    // ── Hitos de jugadores ──
    final hitos = <(Personaje, Situacion, double, String)>[];
    for (final id in tocados) {
      final st = _s(id);
      if (!st.dominante && st.pts >= 24) {
        st.dominante = true;
        hitos.add((Personaje.comentarista, Situacion.jugadorDominante, .8, id));
      }
      if (!st.alto && st.pts >= 32) {
        st.alto = true;
        hitos.add((Personaje.relator, Situacion.anotadorAlto, .9, id));
      }
      if (!st.td && st.dobles >= 3) {
        st.td = true;
        st.dd = true;
        hitos.add((Personaje.relator, Situacion.tripleDoble, 1, id));
      } else if (!st.dd && st.dobles >= 2) {
        st.dd = true;
        hitos.add((Personaje.relator, Situacion.dobleDoble, .9, id));
      }
    }
    final racha = e.tipo == TipoEvento.tiro && e.triple && e.convertido && e.jugadorId != null
        ? _s(e.jugadorId!).triplesSeguidos
        : 0;

    // ── Intensidad ──
    final finalApretado = _finalApretado(e);
    final clutch = _clutchAhora(e);
    final perfil = _perfil(situacionBase);
    var intensidad = perfil.$1;
    if (e.cuarto >= 4) intensidad += 1;
    if (clutch) intensidad += 1;
    if (finalApretado) intensidad += 1;
    if (ctx.playoffs && perfil.$1 >= 1) intensidad += 1;
    if (ctx.noHayManana && clutch) intensidad += 1;
    if (e.cuarto >= 3 && dif.abs() <= 4 && _cambiosDeMando >= 3) intensidad += 1;
    final tramite = dif.abs() >= 20 && e.cuarto >= 3;
    if (tramite) intensidad -= 2;
    intensidad = intensidad.clamp(0, 4);

    final clutchNuevo = clutch && !_clutchAntes && e.tipo != TipoEvento.finPartido;
    _clutchAntes = clutch;

    if (!hablar) {
      if (clutchNuevo) _clutchDisparos++;
      if (tramite) _tramiteDicho = true;
      return const [];
    }

    // ── Qué dice cada uno ──
    var sit = situacionBase;
    if (sit == Situacion.ladrillo && _azar.nextDouble() < (e.triple ? .25 : .4)) sit = Situacion.aro;
    if (sit == Situacion.cambio) {
      if (e.saleId != null && _expulsados.contains(e.saleId)) {
        sit = Situacion.cambioExpulsion;
      } else if (e.texto.contains('cargado de faltas')) {
        sit = Situacion.cambioFaltas;
      }
    }
    var intensidadLinea = intensidad;
    String? rachaTexto;
    if (sit == Situacion.tiempoMuerto) {
      // El motor pide el minuto cuando alguien corre 8 o más: quien llama es el que sufre.
      final sufre = runAntesL >= 8 ? 'visitante' : (runAntesV >= 8 ? 'local' : null);
      if (sufre != null) {
        sit = Situacion.tiempoMuertoParcial;
        final run = sufre == 'visitante' ? runAntesL : runAntesV;
        rachaTexto = '$run-0';
        final l = sufre == 'local';
        v['eq'] = l ? v['nloc']! : v['nvis']!;
        v['rv'] = l ? v['nvis']! : v['nloc']!;
        v['ceq'] = l ? v['cloc']! : v['cvis']!;
        v['crv'] = l ? v['cvis']! : v['cloc']!;
        _runL = 0;
        _runV = 0;
      }
    }
    if (rachaTexto != null) v['rach'] = rachaTexto;
    if (e.expulsadoId != null) _expulsados.add(e.expulsadoId!);

    // Probabilidades
    final pR = siempre ? 1.0 : min(1.0, perfil.$2 + 0.04 * intensidad + (clutch ? 0.1 : 0));
    var pC =
        perfil.$3 *
        (_desdeComentarista < 2 ? .5 : (_desdeComentarista >= 6 ? 1.4 : 1.0)) *
        (1 + .15 * intensidad) *
        (tramite ? .6 : 1);
    if (perfil.$3 >= 1) pC = 1;
    pC = min(pC, perfil.$3 >= 1 ? 1 : .92);
    final habloR = _azar.nextDouble() < pR;
    final habloC = _azar.nextDouble() < pC;

    final lineas = <LineaRelato>[];
    LineaRelato? lineaR, lineaC;
    final extrasR = <LineaRelato>[], extrasC = <LineaRelato>[];

    if (habloR) {
      var l = _decir(Personaje.relator, sit, v, intensidadLinea);
      if (l != null &&
          intensidad >= 3 &&
          e.puntos > 0 &&
          e.tipo == TipoEvento.tiro &&
          !l.texto.contains('-') &&
          _azar.nextDouble() < .4) {
        l = LineaRelato(l.personaje, '${l.texto} ${v['marc']}.', l.intensidad, l.situacion);
      }
      lineaR = l;
    }
    // Sin plantilla que se pueda completar (p. ej. un jugador que no está en el contexto): el texto del motor.
    if (habloR && lineaR == null && e.texto.trim().isNotEmpty) {
      lineaR = LineaRelato(Personaje.relator, e.texto.trim(), intensidadLinea, sit);
    }
    if (habloC) lineaC = _decir(Personaje.comentarista, sit, v, intensidadLinea);

    // Contexto: lo que se agrega encima de la jugada
    void extra(Personaje p, Situacion s, double prob, {Map<String, String>? mas, bool forzar = false}) {
      if (!forzar && _azar.nextDouble() >= prob) return;
      final l = _decir(p, s, {...v, ...?mas}, intensidadLinea);
      if (l == null) return;
      (p == Personaje.relator ? extrasR : extrasC).add(l);
    }

    Map<String, String> nombre(String? id) => {
      'q': id == null || ctx.jugadores[id] == null ? '' : apellido(ctx.jugadores[id]!),
      if (id != null) 'linea': _s(id).linea,
      if (id != null) 'pts': '${_s(id).pts}',
    };

    final suma = cruceL > 0 || cruceV > 0;
    if (suma && e.tipo != TipoEvento.finCuarto) {
      final localCorre = cruceL > 0;
      final n = localCorre ? _runL : _runV;
      final mas = {
        'rach': '$n-0',
        'n': '$n',
        'eq': localCorre ? v['nloc']! : v['nvis']!,
        'rv': localCorre ? v['nvis']! : v['nloc']!,
        'ceq': localCorre ? v['cloc']! : v['cvis']!,
        'crv': localCorre ? v['cvis']! : v['cloc']!,
      };
      extra(Personaje.relator, Situacion.parcialAFavor, .95, mas: mas);
      extra(
        Personaje.comentarista,
        cruceL >= 12 || cruceV >= 12 ? Situacion.parcialAFavor : Situacion.parcialEnContra,
        .6,
        mas: mas,
      );
    }
    if (remontada != null) {
      final local = remontada == 'local';
      final mas = {
        'eq': local ? v['nloc']! : v['nvis']!,
        'rv': local ? v['nvis']! : v['nloc']!,
        'ceq': local ? v['cloc']! : v['cvis']!,
        'crv': local ? v['cvis']! : v['cloc']!,
        'dm': '$deficit',
      };
      extra(Personaje.relator, Situacion.remontada, 1, mas: mas, forzar: true);
      extra(Personaje.comentarista, Situacion.remontada, .85, mas: mas);
    }
    if (racha >= 3) {
      final mas = {...nombre(e.jugadorId), 'n': '$racha'};
      extra(Personaje.relator, Situacion.rachaTirador, racha == 3 ? .7 : 1, mas: mas);
      extra(Personaje.comentarista, Situacion.rachaTirador, .8, mas: mas);
    }
    for (final (p, s, prob, id) in hitos) {
      extra(p, s, prob, mas: nombre(id));
      if (s == Situacion.tripleDoble || s == Situacion.dobleDoble) {
        extra(Personaje.comentarista, s, s == Situacion.tripleDoble ? 1 : .5, mas: nombre(id));
      } else if (s == Situacion.jugadorDominante) {
        extra(Personaje.relator, s, .6, mas: nombre(id));
      }
    }
    if (clutchNuevo && _clutchDisparos < 2) {
      _clutchDisparos++;
      extra(Personaje.relator, Situacion.clutch, .9);
      if (ctx.noHayManana && !_eliminacionDicha) {
        _eliminacionDicha = true;
        extra(Personaje.comentarista, Situacion.eliminacion, .8);
      } else {
        extra(Personaje.comentarista, Situacion.clutch, .5);
      }
    }
    if (_calor >= 6 && _desdePicado > 40) {
      _desdePicado = 0;
      _calor = 2;
      extra(Personaje.comentarista, Situacion.partidoPicado, 1, forzar: true);
      extra(Personaje.relator, Situacion.partidoPicado, .5);
    }
    if (tramite && !_tramiteDicho) {
      _tramiteDicho = true;
      _desdeTramite = 0;
      extra(Personaje.relator, Situacion.tramite, 1, forzar: true);
      extra(Personaje.comentarista, Situacion.tramite, .8);
    }
    if (e.jugadorId != null &&
        (sit == Situacion.ladrillo || sit == Situacion.aro || e.tipo == TipoEvento.perdida) &&
        (ctx.energiaDe?.call(e.jugadorId!) ?? 100) < 45 &&
        _eventos - (_fatigaDicha[e.jugadorId!] ?? -99) > 25) {
      _fatigaDicha[e.jugadorId!] = _eventos;
      extra(Personaje.comentarista, Situacion.fatiga, .8);
      extra(Personaje.relator, Situacion.fatiga, .4);
    }
    if (e.cuarto == 4 && e.tipo == TipoEvento.finCuarto && ctx.playoffs && ctx.noHayManana && !_eliminacionDicha) {
      _eliminacionDicha = true;
      extra(Personaje.comentarista, Situacion.eliminacion, 1, forzar: true);
    }
    if (e.expulsadoId != null) {
      extra(Personaje.relator, Situacion.expulsion, 1, mas: {'x': nombre(e.expulsadoId)['q']!}, forzar: true);
      extra(Personaje.comentarista, Situacion.expulsion, .9, mas: {'x': nombre(e.expulsadoId)['q']!});
    }
    // Ráfaga en el cierre: el Relator agrega el dato de la situación.
    if (finalApretado &&
        intensidad >= 3 &&
        lineaR != null &&
        e.tipo != TipoEvento.finPartido &&
        _azar.nextDouble() < .3) {
      extra(Personaje.relator, Situacion.finalApretado, 1, forzar: true);
    }
    // Partido parejo: cambios de mando seguidos.
    if (cambioMando && e.cuarto >= 3 && _cambiosDeMando >= 4 && _azar.nextDouble() < .3) {
      extra(Personaje.comentarista, Situacion.partidoParejo, 1, forzar: true);
    }

    // ── Armado del diálogo: Relator canta, dato del Relator, el Comentarista cierra ──
    if (lineaR != null) lineas.add(lineaR);
    lineas.addAll(extrasR);
    final reaccion = extrasC.isNotEmpty ? extrasC.first : lineaC;
    if (reaccion != null) lineas.add(reaccion);
    if (extrasC.length > 1 && lineas.length < 4) lineas.add(extrasC[1]);
    final tope = e.tipo == TipoEvento.finPartido || e.tipo == TipoEvento.finCuarto || e.expulsadoId != null ? 4 : 3;
    while (lineas.length > tope) {
      // Se sacan primero las líneas de contexto del Relator para no perder la jugada.
      final i = lineas.lastIndexWhere((l) => l.personaje == Personaje.relator && l != lineaR);
      lineas.removeAt(i >= 0 ? i : lineas.length - 1);
    }

    // ── Retoma: nadie dijo nada y el Comentarista lleva rato callado ──
    if (lineas.isEmpty && _desdeComentarista >= 8 && perfil.$2 < .7 && e.tipo != TipoEvento.finPartido) {
      lineas.addAll(_retomaCharla(e, ctx, v, dif, intensidad));
    }
    if (lineas.any((l) => l.personaje == Personaje.comentarista)) _desdeComentarista = 0;
    return lineas;
  }

  /// El Comentarista retoma: trámite, partido parejo o un dato de contexto (una vez por partido).
  List<LineaRelato> _retomaCharla(EventoPartido e, ContextoRelato ctx, Map<String, String> v, int dif, int intensidad) {
    if (_azar.nextDouble() > .55) return const [];
    if (dif.abs() >= 18 && e.cuarto >= 2 && _desdeTramite > 30) {
      _desdeTramite = 0;
      return [?_decir(Personaje.comentarista, Situacion.tramite, v, intensidad)];
    }
    if (dif.abs() <= 6 && e.cuarto >= 2 && _desdeUltimoDato > 18) {
      _desdeUltimoDato = 0;
      return [
        ?_decir(Personaje.comentarista, Situacion.partidoParejo, v, intensidad),
        if (_azar.nextDouble() < .35) ?_decir(Personaje.relator, Situacion.partidoParejo, v, intensidad),
      ];
    }
    final pool = [
      if (ctx.noHayManana) Situacion.eliminacion,
      if (ctx.playoffs) ...[Situacion.serie, Situacion.playoffs],
      Situacion.historial,
      Situacion.rivalidad,
      Situacion.record,
      Situacion.recordEnJuego,
      Situacion.historiaTemporada,
      if (ctx.ritmoAlto == true) Situacion.ritmoAlto,
      if (ctx.ritmoAlto == false) Situacion.ritmoBajo,
      Situacion.localia,
    ].where((s) => !_extrasUsados.contains(s));
    for (final s in pool) {
      final r = _decir(Personaje.relator, s, v, intensidad);
      if (r == null) continue;
      _extrasUsados.add(s);
      _desdeUltimoDato = 0;
      return [r, ?_decir(Personaje.comentarista, s, v, intensidad)];
    }
    return const [];
  }

  // ───────────────────────── Elegir frase ─────────────────────────

  /// Dice algo de [s] como [p] con la intensidad dada (null si ninguna plantilla se puede completar).
  LineaRelato? _decir(Personaje p, Situacion s, Map<String, String> v, int intensidad) {
    final lista = catalogoRelato[s]?.de(p);
    if (lista == null) return null;
    final candidatas = <(String, String)>[]; // (clave, texto)
    for (final (i, crudo) in lista.indexed) {
      final suave = crudo.startsWith('~'), fuerte = crudo.startsWith('^');
      if ((suave && intensidad > 1) || (fuerte && intensidad < 3)) continue;
      final texto = _render(suave || fuerte ? crudo.substring(1) : crudo, v);
      if (texto != null) candidatas.add(('${p.index}|${s.index}|$i', texto));
    }
    if (candidatas.isEmpty) return null;
    final nuevas = candidatas.where((c) => !_recientes.contains(c.$1)).toList();
    final (clave, texto) = nuevas.isNotEmpty
        ? nuevas[_azar.nextInt(nuevas.length)]
        : (candidatas.toList()..sort((a, b) => (_ultimoUso[a.$1] ?? -1).compareTo(_ultimoUso[b.$1] ?? -1))).first;
    _recientes.addLast(clave);
    while (_recientes.length > memoria) {
      _recientes.removeFirst();
    }
    _ultimoUso[clave] = _usos++;
    return LineaRelato(p, texto, intensidad, s);
  }

  /// Completa los marcadores; null si falta alguno (salvo los opcionales).
  static String? _render(String plantilla, Map<String, String> v) {
    var completa = true;
    final texto = plantilla.replaceAllMapped(_marcador, (m) {
      final valor = v[m[1]];
      if (valor == null || (valor.isEmpty && !_opcionales.contains(m[1]))) {
        completa = false;
        return '';
      }
      return valor;
    });
    if (!completa) return null;
    return texto.replaceAll(RegExp(r' {2,}'), ' ').replaceAll(' .', '.').replaceAll(' ,', ',').trim();
  }

  /// Todas las plantillas del catálogo, para tests y revisión.
  static Iterable<(Situacion, Personaje, String)> get plantillas sync* {
    for (final MapEntry(key: s, value: f) in catalogoRelato.entries) {
      for (final p in Personaje.values) {
        for (final t in f.de(p)) {
          yield (s, p, t);
        }
      }
    }
  }

  /// Los jugadores que usa el relato (por si alguna pantalla quiere mostrarlos).
  static Map<String, Jugador> indexar(Iterable<Jugador> js) => {for (final j in js) j.id: j};
}
