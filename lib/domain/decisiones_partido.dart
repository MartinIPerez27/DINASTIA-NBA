import 'dart:math';

import 'efecto_en_vivo.dart';
import 'entities/jugador.dart';
import 'entities/posicion.dart';
import 'entities/tactica.dart';
import 'modificadores.dart';
import 'modos/carrera_jugador.dart' show Atributo, Atributos, EstadoCarrera, GradoInsignia, Habilidad, Insignia;
import 'motor.dart';
import 'premios.dart' show apellido;

/// Decisiones del entrenador durante el partido en vivo: cuándo se ofrecen, qué opciones hay, qué efecto
/// temporal tienen sobre el motor y cómo se explica después lo que pasó.
///
/// Es Dart puro: la pantalla (`presentation/partido/decisiones.dart`) solo dibuja lo que acá se decide.
/// Nada de esto toca el azar del motor: si el usuario ignora todo, el partido sale idéntico al de siempre.

/// Situaciones en las que el partido se frena para ofrecer una decisión corta.
enum TipoDecision {
  parcialContra('Parcial en contra'),
  cansancio('Cansancio'),
  faltas('Faltas'),
  rivalCaliente('Rival encendido'),
  tiradorEncendido('Tirador encendido'),
  remontada('Remontada'),
  ventajaGrande('Ventaja grande'),
  ultimoTiro('Último tiro del cuarto'),
  faltaIntencional('Falta intencional'),
  finalConVentaja('Final con ventaja'),
  entretiempo('Entretiempo'),
  ajusteManual('Ajuste táctico'),
  // Decisiones como jugador (Mi carrera): solo lo que hacés vos en la cancha.
  tuPlan('Tu plan'),
  tuMomento('Tu momento'),
  tuMarca('Tu marca'),
  tuEnergia('Tu energía'),
  tuClutch('Tu último tiro'),
  takeover('Takeover');

  const TipoDecision(this.titulo);
  final String titulo;

  /// Momentos que no cuentan para el tope del cuarto: pasan o no pasan en segundos.
  bool get critica => this == ultimoTiro || this == faltaIntencional || this == finalConVentaja || this == tuClutch;
}

/// Un ajuste del mismo grupo reemplaza al anterior (no se acumulan dos defensas).
enum CategoriaAjuste { defensa, ritmo, foco, quinteto, jugada, falta, linea, descanso, otro }

/// Todo lo que el entrenador puede pedir en vivo. Cada acción tiene su efecto y su costo en
/// `DirectorDecisiones._efecto` y su texto en `DirectorDecisiones._texto`.
enum AccionTactica {
  tiempoMuerto(CategoriaAjuste.otro),
  defensaIndividual(CategoriaAjuste.defensa),
  zona(CategoriaAjuste.defensa),
  presion(CategoriaAjuste.defensa),
  cajaYUno(CategoriaAjuste.defensa),
  ritmoAlto(CategoriaAjuste.ritmo),
  ritmoBajo(CategoriaAjuste.ritmo),
  focoAislamiento(CategoriaAjuste.foco),
  focoPickAndRoll(CategoriaAjuste.foco),
  circulaPelota(CategoriaAjuste.foco),
  hack(CategoriaAjuste.falta),
  quintetoChico(CategoriaAjuste.quinteto),
  quintetoGrande(CategoriaAjuste.quinteto),
  descansar(CategoriaAjuste.descanso),
  sentar(CategoriaAjuste.descanso),
  aguantar(CategoriaAjuste.descanso),
  jugadaAislamiento(CategoriaAjuste.jugada),
  jugadaTriple(CategoriaAjuste.jugada),
  jugadaPickAndRoll(CategoriaAjuste.jugada),
  lineaMejor(CategoriaAjuste.linea),
  lineaSentarPeor(CategoriaAjuste.linea),
  lineaTiempoMuerto(CategoriaAjuste.linea),
  defenderTriple(CategoriaAjuste.defensa),
  faltaTactica(CategoriaAjuste.falta),
  enfriar(CategoriaAjuste.ritmo),
  // Como jugador (Mi carrera).
  pedirPelota(CategoriaAjuste.foco),
  atacarAro(CategoriaAjuste.foco),
  tirarTriple(CategoriaAjuste.foco),
  buscarAbierto(CategoriaAjuste.foco),
  takeover(CategoriaAjuste.foco),
  cerrarMarca(CategoriaAjuste.defensa),
  apostarRobo(CategoriaAjuste.defensa),
  guardarEnergia(CategoriaAjuste.descanso),
  yoAislamiento(CategoriaAjuste.jugada),
  yoTriple(CategoriaAjuste.jugada),
  yoPasar(CategoriaAjuste.jugada);

  const AccionTactica(this.categoria);
  final CategoriaAjuste categoria;

  /// Se resuelve en una sola jugada (no tiene "duración").
  bool get unaJugada =>
      this == jugadaAislamiento ||
      this == jugadaTriple ||
      this == jugadaPickAndRoll ||
      this == lineaMejor ||
      this == lineaTiempoMuerto ||
      this == faltaTactica ||
      this == yoAislamiento ||
      this == yoTriple ||
      this == yoPasar;
}

/// Una opción de una decisión: qué hace, qué cuesta y, si hace falta, sobre quién.
class OpcionDecision {
  const OpcionDecision({
    required this.accion,
    required this.titulo,
    required this.efecto,
    required this.costo,
    this.jugadorId,
    this.recomendada = false,
    this.segundos = 180,
  });

  final AccionTactica accion;
  final String titulo, efecto, costo;
  final String? jugadorId;

  /// La que mejor encaja con lo que está pasando (se marca como "sugerida").
  final bool recomendada;

  /// Cuánto dura (segundos de juego); 0 si se resuelve en la jugada.
  final double segundos;

  String get id => jugadorId == null ? accion.name : '${accion.name}:$jugadorId';

  OpcionDecision conSegundos(double s) => OpcionDecision(
    accion: accion,
    titulo: titulo,
    efecto: efecto,
    costo: costo,
    jugadorId: jugadorId,
    recomendada: recomendada,
    segundos: s,
  );
}

/// Una decisión ofrecida: por qué, qué opciones y qué pasa si se la ignora (nada).
class DecisionPartido {
  const DecisionPartido({
    required this.id,
    required this.tipo,
    required this.situacion,
    required this.motivo,
    required this.opciones,
    required this.cuarto,
    required this.reloj,
    this.segundosEspera = 14,
  });

  final int id;
  final TipoDecision tipo;

  /// Marcador y momento ("Perdés 41-52 · Q3 8:12").
  final String situacion;

  /// Por qué se sugiere, con datos reales ("Ellos vienen 10-0 y tus tiros bajaron a 31 %").
  final String motivo;
  final List<OpcionDecision> opciones;
  final int cuarto;
  final double reloj;

  /// Si no tocás nada en este tiempo, se sigue igual.
  final int segundosEspera;
}

enum Veredicto { ayudo, neutro, empeoro, sinDato }

/// Lo que quedó de una decisión, para el pospartido.
class RegistroDecision {
  RegistroDecision({
    required this.tipo,
    required this.cuarto,
    required this.reloj,
    this.opcion,
    this.opcionId,
    this.aviso,
    this.impacto,
    this.veredicto = Veredicto.sinDato,
  });

  final TipoDecision tipo;
  final int cuarto;
  final double reloj;

  /// Título de la opción elegida (null: la ignoraste).
  String? opcion;
  String? opcionId;

  /// Lo que se contó al terminar el efecto.
  String? aviso;

  /// Efecto aproximado en el marcador (puntos), solo para los ajustes que duran un rato.
  int? impacto;
  Veredicto veredicto;

  bool get ignorada => opcion == null;

  Map<String, dynamic> toJson() => {
    't': tipo.name,
    'q': cuarto,
    'r': reloj.round(),
    if (opcion != null) 'o': opcion,
    if (opcionId != null) 'oi': opcionId,
    if (aviso != null) 'a': aviso,
    if (impacto != null) 'i': impacto,
    'v': veredicto.name,
  };

  factory RegistroDecision.fromJson(Map<String, dynamic> j) => RegistroDecision(
    tipo: TipoDecision.values.firstWhere((t) => t.name == j['t'], orElse: () => TipoDecision.ajusteManual),
    cuarto: j['q'] as int? ?? 1,
    reloj: (j['r'] as num? ?? 0).toDouble(),
    opcion: j['o'] as String?,
    opcionId: j['oi'] as String?,
    aviso: j['a'] as String?,
    impacto: j['i'] as int?,
    veredicto: Veredicto.values.firstWhere((v) => v.name == j['v'], orElse: () => Veredicto.sinDato),
  );
}

/// Un ajuste en marcha (para mostrar "Zona 2-3 · 2:10" y, al terminar, contar cómo salió).
class EfectoActivo {
  EfectoActivo._(
    this.opcion,
    this.categoria,
    this.propio,
    this.rival,
    this.desde,
    this.hasta,
    this._foto,
    this.registro,
  );

  final OpcionDecision opcion;
  final CategoriaAjuste categoria;
  final EfectoEnVivo propio, rival;
  final double desde, hasta;
  final _Foto _foto;
  final RegistroDecision registro;
  String? volverId, reemplazoId;
  bool cumplido = false;
  int extra = 0;

  double restante(double ahora) => max(0, hasta - ahora);
}

/// Fotografía acumulada del partido (propios contra rivales) para medir ventanas de tiempo.
class _Foto {
  _Foto(
    this.t,
    this.ptsP,
    this.ptsR,
    this.fgmR,
    this.fgaR,
    this.fgmP,
    this.fgaP,
    this.perP,
    this.perR,
    this.tlmR,
    this.tlaR,
  );

  final double t;
  final int ptsP, ptsR, fgmR, fgaR, fgmP, fgaP, perP, perR, tlmR, tlaR;
}

/// Una fila del informe de entretiempo.
class FilaJugador {
  const FilaJugador({
    required this.id,
    required this.nombre,
    required this.minutos,
    required this.pts,
    required this.reb,
    required this.ast,
    required this.tcI,
    required this.tcA,
    required this.t3I,
    required this.t3A,
    required this.faltas,
    required this.energia,
    required this.enCancha,
  });

  final String id, nombre;
  final int minutos, pts, reb, ast, tcI, tcA, t3I, t3A, faltas;
  final double energia;
  final bool enCancha;
}

/// Informe del entretiempo: números por jugador, qué falló, qué anduvo y qué se puede ajustar.
class InformeEntretiempo {
  const InformeEntretiempo({
    required this.propios,
    required this.rivales,
    required this.filas,
    required this.bien,
    required this.mal,
    required this.defensas,
    required this.ritmos,
    required this.quintetos,
    required this.focos,
    required this.descansos,
  });

  final int propios, rivales;
  final List<FilaJugador> filas;
  final List<String> bien, mal;
  final List<OpcionDecision> defensas, ritmos, quintetos, focos, descansos;
}

/// Lo que el partido necesita saber de tu jugador en Mi carrera: quién es y cómo es (atributos,
/// habilidades específicas e insignias). Con esto las decisiones "como jugador" rinden distinto según
/// el jugador que armaste.
class PerfilVivo {
  const PerfilVivo({
    required this.id,
    required this.nombre,
    required this.atributos,
    this.espec = const {},
    this.grados = const {},
    this.moral = 60,
  });

  factory PerfilVivo.de(EstadoCarrera e) => PerfilVivo(
    id: e.jugadorId,
    nombre: e.nombre,
    atributos: e.atributos,
    espec: e.espec,
    grados: e.grados,
    moral: e.moral,
  );

  final String id, nombre;
  final Atributos atributos;
  final Map<Habilidad, int> espec;
  final Map<Insignia, GradoInsignia> grados;
  final int moral;

  int a(Atributo x) => atributos[x];
  int h(Habilidad x) => Habilidad.valor(x, atributos, espec);
  int nivel(Insignia i) => grados[i]?.nivel ?? 0;

  /// Nivel ofensivo (tiro y finalización).
  double get ataque => (a(Atributo.tiro) + a(Atributo.finalizacion)) / 2;
}

/// El cerebro de las decisiones en vivo. Se crea con el motor y el lado del usuario; la pantalla le avisa
/// de cada jugada (`observar` + `tick`) y antes de la próxima pregunta si hay algo para decidir (`evaluar`).
class DirectorDecisiones {
  DirectorDecisiones({required this.motor, required this.propio, this.habilitado = true, this.yo}) {
    _tm = motor.tiemposMuertos(propio);
  }

  final MotorPartido motor;

  /// Lado del usuario (true: local).
  final bool propio;

  /// Las decisiones sugeridas (el ajuste del usuario). Los ajustes manuales siempre están.
  bool habilitado;

  /// Tu jugador en Mi carrera (null: decisiones de entrenador, como siempre). Con jugador, el partido solo te
  /// frena en tus momentos y las opciones son las de un jugador, no las del DT.
  final PerfilVivo? yo;
  bool get esJugador => yo != null;

  /// Jugadas decisivas que resolviste bien como jugador y veces que activaste el Takeover (van a Mi carrera).
  int clutchLogrados = 0, takeoversUsados = 0;

  /// Lo que se suma a los contadores de la carrera al terminar el partido.
  Map<String, int> get usoCarrera => {
    if (clutchLogrados > 0) 'clutch': clutchLogrados,
    if (takeoversUsados > 0) 'takeover': takeoversUsados,
  };

  // ── límites: nunca en cada posesión ──
  static const maxPorCuarto = 2, maxPorPartido = 6;
  static const cooldownNormal = 150.0, cooldownIgnorada = 240.0, cooldownCritica = 25.0, cooldownManual = 75.0;

  final registro = <RegistroDecision>[];
  final activos = <EfectoActivo>[];

  /// Jugada que se pide sola en cada posesión del final apretado (la elegida en el entretiempo).
  JugadaClave? jugadaPreferida;

  DecisionPartido? _actual;
  var _siguienteId = 1;
  var _total = 0, _ignoradasSeguidas = 0;
  final _porCuarto = <int, int>{};
  var _hastaT = 0.0, _ultimaT = -1e9, _ultimoManual = -1e9;
  var _cooldown = cooldownNormal;
  final _vistos = <String>{};
  var _entretiempoVisto = false;
  var _rachaRival = 0;
  late int _tm;
  final _tiros = <(bool, String, bool, bool)>[]; // (mío, tirador, triple, entró)
  final _linea = <(double, int, int)>[]; // (t, mis puntos, puntos rivales)

  // ── utilidades de lectura ──

  static double transcurrido(int cuarto, double reloj) =>
      cuarto <= 4 ? (cuarto - 1) * 720 + (720 - reloj) : 2880 + (cuarto - 5) * 300 + (300 - reloj);

  double get ahora => transcurrido(motor.cuarto, motor.reloj);
  DecisionPartido? get actual => _actual;
  int get decisionesOfrecidas => _total;
  int get rachaRival => _rachaRival;

  Map<String, LineaEstadistica> get _boxP => propio ? motor.boxLocal : motor.boxVisitante;
  Map<String, LineaEstadistica> get _boxR => propio ? motor.boxVisitante : motor.boxLocal;

  int get _ptsP => propio ? motor.puntosLocal : motor.puntosVisitante;
  int get _ptsR => propio ? motor.puntosVisitante : motor.puntosLocal;
  int get _dif => _ptsP - _ptsR;

  List<Jugador> get _cancha => motor.enCancha(propio);
  List<Jugador> get _canchaR => motor.enCancha(!propio);
  Jugador? get _banco => motor.enBanco(propio);

  int _media(Jugador j) => j.media + (motor.forma[j.id] ?? 0);
  double _energia(Jugador j) => motor.energias(propio)[j.id] ?? 100;
  LineaEstadistica _linea1(Jugador j) => _boxP[j.id] ?? LineaEstadistica();

  Jugador get _estrella => _cancha.reduce((a, b) => _media(a) >= _media(b) ? a : b);
  Jugador get _figuraRival => _canchaR.reduce((a, b) => a.stats.ppp >= b.stats.ppp ? a : b);

  Jugador get _mejorTirador => motor.tiradorDeJugada(propio, JugadaClave.triple);

  static bool _interior(Jugador j) => j.posiciones.contains(Posicion.pivot) || j.posiciones.contains(Posicion.alaPivot);

  (Jugador, Jugador?) get _duoPickAndRoll {
    final organizador = _cancha.reduce((a, b) => a.stats.app >= b.stats.app ? a : b);
    final grandes = _cancha.where(_interior).toList();
    final grande = grandes.isEmpty ? null : grandes.reduce((a, b) => a.stats.ppp >= b.stats.ppp ? a : b);
    return (organizador, grande);
  }

  String _n(Jugador j) => apellido(j);
  String _pct(num v) => '${(100 * v).round()} %';
  static String _tiempo(double r) => '${r ~/ 60}:${(r % 60).floor().toString().padLeft(2, '0')}';
  String get _momento => '${motor.cuarto > 4 ? 'OT' : 'Q${motor.cuarto}'} ${_tiempo(max(0, motor.reloj))}';
  String get _situacion {
    final d = _dif;
    final m = d == 0 ? 'Empatan $_ptsP-$_ptsR' : (d > 0 ? 'Ganás $_ptsP-$_ptsR' : 'Perdés $_ptsP-$_ptsR');
    return '$m · $_momento';
  }

  (int, int) _fg(bool mio, {int n = 10}) {
    var hechos = 0, total = 0;
    for (final t in _tiros.reversed) {
      if (t.$1 != mio) continue;
      total++;
      if (t.$4) hechos++;
      if (total >= n) break;
    }
    return (hechos, total);
  }

  (int, int) _tres(bool mio, {int n = 12}) {
    var hechos = 0, total = 0, vistos = 0;
    for (final t in _tiros.reversed) {
      if (t.$1 != mio) continue;
      vistos++;
      if (t.$3) {
        total++;
        if (t.$4) hechos++;
      }
      if (vistos >= n) break;
    }
    return (hechos, total);
  }

  _Foto _foto() {
    var fgmR = 0, fgaR = 0, fgmP = 0, fgaP = 0, perP = 0, perR = 0, tlmR = 0, tlaR = 0;
    for (final l in _boxP.values) {
      fgmP += l.tcI;
      fgaP += l.tcA;
      perP += l.per;
    }
    for (final l in _boxR.values) {
      fgmR += l.tcI;
      fgaR += l.tcA;
      perR += l.per;
      tlmR += l.tlI;
      tlaR += l.tlA;
    }
    return _Foto(ahora, _ptsP, _ptsR, fgmR, fgaR, fgmP, fgaP, perP, perR, tlmR, tlaR);
  }

  // ── observación de la jugada que acaba de pasar ──

  /// La pantalla llama esto con cada evento del motor (también al saltar jugadas).
  void observar(EventoPartido e) {
    final mio = e.local == propio;
    if (e.tipo == TipoEvento.tiro && e.jugadorId != null && !e.desdeLejos) {
      _tiros.add((mio, e.jugadorId!, e.triple, e.convertido));
      if (_tiros.length > 80) _tiros.removeAt(0);
    }
    if (e.puntos > 0) {
      if (mio) {
        _rachaRival = 0;
      } else {
        _rachaRival += e.puntos;
      }
    }
    // Un tiempo muerto (tuyo o del rival) corta la racha del otro.
    final tm = motor.tiemposMuertos(propio);
    if (tm < _tm) _rachaRival = 0;
    _tm = tm;
    _linea.add((ahora, _ptsP, _ptsR));
    // Efectos de una sola jugada: se cumplen cuando pasa lo que pedimos.
    for (final ef in activos) {
      switch (ef.opcion.accion) {
        case AccionTactica.yoAislamiento || AccionTactica.yoTriple || AccionTactica.yoPasar:
          if (e.jugadaClave != null && mio) {
            ef.cumplido = true;
            ef.extra = e.puntos;
            final bien = e.puntos > 0;
            if (bien) clutchLogrados++;
            ef.registro
              ..aviso = _avisoYo(ef, e)
              ..veredicto = bien ? Veredicto.ayudo : Veredicto.empeoro;
          }
        case AccionTactica.jugadaAislamiento || AccionTactica.jugadaTriple || AccionTactica.jugadaPickAndRoll:
          if (e.jugadaClave != null && mio) {
            ef.cumplido = true;
            ef.extra = e.puntos;
            ef.registro
              ..aviso = _avisoJugada(ef, e)
              ..veredicto = e.puntos > 0 ? Veredicto.ayudo : Veredicto.empeoro;
          }
        case AccionTactica.lineaMejor || AccionTactica.lineaTiempoMuerto:
          if (e.falta == TipoFalta.intencional && mio) {
            ef.cumplido = true;
            ef.extra = e.puntos;
            ef.registro
              ..aviso = 'Libres de ${_nombreDe(e.jugadorId)}: ${e.puntos} de 2.'
              ..veredicto = e.puntos >= 1 ? Veredicto.ayudo : Veredicto.empeoro;
          }
        case AccionTactica.faltaTactica:
          if (e.falta == TipoFalta.intencional && !mio) {
            ef.cumplido = true;
            ef.extra = e.puntos;
            ef.registro
              ..aviso = 'La falta mandó a ${_nombreDe(e.jugadorId)} a la línea: ${e.puntos} de 2.'
              ..veredicto = e.puntos <= 1 ? Veredicto.ayudo : Veredicto.empeoro;
          }
        case _:
      }
    }
  }

  String _nombreDe(String? id) {
    if (id == null) return 'el jugador';
    for (final j in [..._cancha, ..._canchaR, ?_banco, ...motor.reservas(propio), ...motor.reservas(!propio)]) {
      if (j.id == id) return _n(j);
    }
    return 'el jugador';
  }

  String _avisoJugada(EfectoActivo ef, EventoPartido e) {
    final quien = _nombreDe(e.jugadorId);
    final que = switch (ef.opcion.accion) {
      AccionTactica.jugadaAislamiento => 'Aislamiento con $quien',
      AccionTactica.jugadaTriple => 'Triple buscado a $quien',
      _ => 'Pick & roll',
    };
    return e.puntos > 0 ? '$que: ¡entró! +${e.puntos}.' : '$que: no entró, la pelota no tuvo premio.';
  }

  String _avisoYo(EfectoActivo ef, EventoPartido e) {
    final que = switch (ef.opcion.accion) {
      AccionTactica.yoAislamiento => 'Pediste la pelota',
      AccionTactica.yoTriple => 'Fuiste por el triple',
      _ => 'Buscaste al compañero',
    };
    final quien = _nombreDe(e.jugadorId);
    return e.puntos > 0
        ? '$que: ¡salió! $quien anotó +${e.puntos}. Cuenta para tu insignia Clutch.'
        : '$que: no entró, esta vez no hubo premio.';
  }

  /// Vence los ajustes que ya cumplieron su tiempo y devuelve los avisos para mostrar.
  List<String> tick() {
    final avisos = <String>[];
    final t = ahora;
    for (final ef in List.of(activos)) {
      if (motor.terminado || t >= ef.hasta || ef.cumplido) {
        final a = _cerrar(ef);
        if (a != null) avisos.add(a);
      }
    }
    return avisos;
  }

  // ── límites ──

  bool _permite({required bool critica}) {
    if (!habilitado || motor.terminado || _actual != null) return false;
    if (_total >= (critica ? maxPorPartido + 2 : maxPorPartido)) return false;
    if ((_porCuarto[motor.cuarto] ?? 0) >= (critica ? maxPorCuarto + 1 : maxPorCuarto)) return false;
    return critica ? ahora - _ultimaT >= cooldownCritica : ahora >= _hastaT;
  }

  /// ¿Hay algo para decidir ahora? Llamar antes de cada posesión. Si devuelve algo, el partido se frena.
  DecisionPartido? evaluar() {
    if (!habilitado || motor.terminado || _actual != null) return null;
    if (esJugador) return _evaluarJugador();
    if (_permite(critica: true)) {
      final d = _faltaIntencional() ?? _finalConVentaja() ?? _ultimoTiro();
      if (d != null) return _presentar(d);
    }
    if (_permite(critica: false)) {
      final d =
          _parcialContra() ??
          _cansancio() ??
          _faltas() ??
          _rivalCaliente() ??
          _tiradorEncendido() ??
          _remontada() ??
          _ventajaGrande();
      if (d != null) return _presentar(d);
    }
    return null;
  }

  DecisionPartido _presentar(DecisionPartido d) {
    _actual = d;
    _total++;
    _porCuarto[d.cuarto] = (_porCuarto[d.cuarto] ?? 0) + 1;
    _hastaT = ahora + _cooldown;
    _ultimaT = ahora;
    registro.add(RegistroDecision(tipo: d.tipo, cuarto: d.cuarto, reloj: d.reloj));
    return d;
  }

  /// Aplica la opción elegida (o ignora la decisión si [opcion] es null).
  void resolver(DecisionPartido d, OpcionDecision? opcion) {
    if (_actual?.id != d.id) return;
    _actual = null;
    final reg = registro.lastWhere((r) => r.tipo == d.tipo && r.opcion == null, orElse: () => registro.last);
    if (opcion == null) {
      _ignoradasSeguidas++;
      _cooldown = _ignoradasSeguidas >= 2 ? 330 : cooldownIgnorada;
      _hastaT = ahora + _cooldown;
      return;
    }
    _ignoradasSeguidas = 0;
    _cooldown = cooldownNormal;
    _hastaT = ahora + _cooldown;
    _activar(opcion, reg);
  }

  /// Política por defecto del cuerpo técnico (la de la simulación): si el rival viene con 10 puntos sin
  /// respuesta, tiempo muerto. Es lo que hace la máquina con su propio equipo.
  void politicaAutomatica() {
    if (motor.terminado) return;
    if (_rachaRival >= 10 && motor.pedirTiempoMuerto(propio)) {
      _rachaRival = 0;
      _tm = motor.tiemposMuertos(propio);
    }
  }

  // ── ajustes manuales (el botón AJUSTES) ──

  /// Segundos de juego que faltan para poder pedir otro ajuste (0: ya se puede).
  int get segundosParaAjustar => max(0, (cooldownManual - (ahora - _ultimoManual)).ceil());

  bool aplicarManual(OpcionDecision o) {
    if (motor.terminado || segundosParaAjustar > 0) return false;
    _ultimoManual = ahora;
    final reg = RegistroDecision(tipo: TipoDecision.ajusteManual, cuarto: motor.cuarto, reloj: motor.reloj);
    registro.add(reg);
    _activar(o, reg);
    return true;
  }

  /// Todo lo que se puede pedir ahora, agrupado por categoría (para el menú de ajustes).
  List<OpcionDecision> menuTactico() {
    if (esJugador) return _menuJugador();
    final star = _estrella;
    final (org, grande) = _duoPickAndRoll;
    final lista = <OpcionDecision?>[
      _op(AccionTactica.defensaIndividual),
      _op(AccionTactica.zona),
      _op(AccionTactica.presion),
      _op(AccionTactica.cajaYUno, rival: _figuraRival),
      _op(AccionTactica.ritmoAlto),
      _op(AccionTactica.ritmoBajo),
      _op(AccionTactica.focoAislamiento, j: star),
      _op(AccionTactica.focoPickAndRoll, j: star),
      _op(AccionTactica.circulaPelota),
      _op(AccionTactica.hack, rival: _peorLibres),
      _op(AccionTactica.quintetoChico),
      _op(AccionTactica.quintetoGrande),
      _op(AccionTactica.descansar, j: star),
      _op(AccionTactica.jugadaAislamiento, j: star),
      _op(AccionTactica.jugadaTriple, j: _mejorTirador),
      _op(AccionTactica.jugadaPickAndRoll, j: org, j2: grande),
    ];
    return [for (final o in lista) ?o];
  }

  Jugador? get _peorLibres {
    if (_canchaR.isEmpty) return null;
    return _canchaR.reduce((a, b) => a.stats.pctTl <= b.stats.pctTl ? a : b);
  }

  // ── los textos y los efectos de cada acción ──

  EsquemaDefensivo get _defensaActual => motor.efecto(propio)?.defensa ?? motor.equipo(propio).tactica.defensiva;
  SistemaOfensivo get _ataqueActual => motor.efecto(propio)?.ataque ?? motor.equipo(propio).tactica.ofensiva;

  /// Arma la opción de [a] con los datos del partido, o null si no tiene sentido ofrecerla ahora.
  OpcionDecision? _op(AccionTactica a, {Jugador? j, Jugador? j2, Jugador? rival, bool recomendada = false}) {
    final nj = j == null ? '' : _n(j);
    OpcionDecision o(String titulo, String efecto, String costo, {double s = 180, String? id}) => OpcionDecision(
      accion: a,
      titulo: titulo,
      efecto: efecto,
      costo: costo,
      jugadorId: id ?? j?.id,
      recomendada: recomendada,
      segundos: a.unaJugada ? 0 : s,
    );
    switch (a) {
      case AccionTactica.tiempoMuerto:
        final q = motor.tiemposMuertos(propio);
        if (q <= 0) return null;
        return o(
          'Tiempo muerto',
          'Todos recuperan 10 de energía y se corta la racha rival.',
          'Gastás uno de tus tiempos muertos (te quedan ${q - 1}).',
        );
      case AccionTactica.defensaIndividual:
        if (_defensaActual == EsquemaDefensivo.switchAll) return null;
        return o(
          'Defensa individual',
          'Cada uno con su hombre y cambios en los bloqueos: su triple baja 5 %.',
          'Cede un poco cerca del aro (sus dobles suben 2 %).',
        );
      case AccionTactica.zona:
        if (_defensaActual == EsquemaDefensivo.zona23) return null;
        return o(
          'Zona 2-3',
          'Cierra la pintura: sus dobles bajan 7 %.',
          'Regala el triple: sus tiros de tres suben 10 %.',
        );
      case AccionTactica.presion:
        if (_defensaActual == EsquemaDefensivo.presionTodaCancha) return null;
        return o(
          'Presión en toda la cancha',
          'Más robos (+40 %): lo que fuerces sale en contraataque.',
          'Tus titulares se cansan 50 % más rápido y la salida queda abierta.',
          s: 150,
        );
      case AccionTactica.cajaYUno:
        if (_defensaActual == EsquemaDefensivo.cajaYUno) return null;
        return o(
          rival == null ? 'Marcar a su figura' : 'Marcar a ${_n(rival)}',
          'Doble marca a su figura: su protagonismo baja 25 % y cerrás la pintura (−3 %).',
          'Los otros cuatro quedan sueltos afuera (+5 % de triple).',
        );
      case AccionTactica.ritmoAlto:
        return o(
          'Subir el ritmo',
          'Más posesiones y más contraataques.',
          'Te cansás 12 % más y hay más margen de error.',
        );
      case AccionTactica.ritmoBajo:
        return o(
          'Bajar el ritmo',
          'Menos posesiones y gastás un 12 % menos de energía.',
          'Con menos posesiones cuesta más descontar o apurar un parcial.',
        );
      case AccionTactica.enfriar:
        return o(
          'Enfriar el partido',
          'Menos posesiones y más reloj gastado: el rival tiene menos chances.',
          'Si se acercan, queda menos tiempo para reaccionar.',
          s: 240,
        );
      case AccionTactica.focoAislamiento:
        if (j == null) return null;
        return o(
          'Aislar a $nj',
          'La pelota a $nj: el doble de tiros para él.',
          'Fuerza más (−0,8 % de acierto) y los otros se enfrían.',
        );
      case AccionTactica.focoPickAndRoll:
        if (j == null) return null;
        return o(
          'Pick & roll con $nj',
          'Más tiros para $nj, con bloqueo y asistencia (+1 % de acierto).',
          'Menos pelota para tus otros tiradores.',
        );
      case AccionTactica.circulaPelota:
        if (_ataqueActual == SistemaOfensivo.motionOffense) return null;
        return o(
          'Que circule la pelota',
          'Motion: más asistencias y menos pérdidas.',
          'Dejás de lado el sistema que armaste para esta plantilla.',
        );
      case AccionTactica.hack:
        if (rival == null || rival.stats.pctTl > 0.66) return null;
        return o(
          'Hack a ${_n(rival)}',
          'Falta a ${_n(rival)} (${_pct(rival.stats.pctTl)} en libres): lo mandás a la línea.',
          'Si embocá, regalás puntos; llenás el bonus y se acelera el partido.',
          s: 150,
          id: rival.id,
        );
      case AccionTactica.quintetoChico:
        return o(
          'Quinteto chico',
          'Cinco abiertos: más triples (+45 %) y +1 % de acierto de tres.',
          'Pierdés rebote (ellos +8 %) y pintura (sus dobles +1 %).',
        );
      case AccionTactica.quintetoGrande:
        return o(
          'Quinteto grande',
          'Más rebote ofensivo (+12 %) y la pintura cerrada.',
          'Menos espacio (−2 % de triple) y el ritmo baja.',
        );
      case AccionTactica.descansar:
        if (j == null || _banco == null) return null;
        return o(
          'Descansar a $nj',
          '$nj se sienta y vuelve en unos 4 minutos con aire.',
          'Entra ${_n(_banco!)} (menos calidad) mientras tanto.',
          s: 240,
        );
      case AccionTactica.sentar:
        if (j == null || _banco == null) return null;
        return o('Sentar a $nj ya', 'Sale $nj y entra ${_n(_banco!)}.', 'Perdés su aporte en ese tramo.', s: 180);
      case AccionTactica.aguantar:
        if (j == null) return null;
        final f = _linea1(j).fal;
        return o(
          'Dejar a $nj',
          '$nj sigue en cancha con $f faltas (3 minutos sin sentar a nadie por faltas).',
          'Si comete otra falta, puede irse por seis.',
        );
      case AccionTactica.jugadaAislamiento:
        if (j == null) return null;
        return o(
          'Aislamiento con $nj',
          'La pelota a $nj, uno contra uno en la próxima.',
          'Todo depende de uno: si el rival lo carga, no hay plan B.',
        );
      case AccionTactica.jugadaTriple:
        if (j == null) return null;
        return o(
          'Triple de $nj',
          '$nj (${_pct(j.stats.pctT3)} de tres) busca el triple.',
          'Más lejos, menos acierto: vale 3 si entra, nada si no.',
        );
      case AccionTactica.jugadaPickAndRoll:
        if (j == null) return null;
        return o(
          'Pick & roll ${j2 == null ? 'de ${_n(j)}' : '${_n(j)} y ${_n(j2)}'}',
          'Bloqueo y doble cerca del aro, con asistencia.',
          'Si el rival cierra la pintura, queda poco.',
        );
      case AccionTactica.lineaMejor:
        if (j == null) return null;
        return o(
          'Pelota a $nj',
          '$nj (${_pct(j.stats.pctTl)} en libres) va a la línea si hacen falta.',
          'Riesgo de robo en el saque (7 %).',
        );
      case AccionTactica.lineaSentarPeor:
        if (j == null || _banco == null) return null;
        return o(
          'Sentar a $nj y que entre ${_n(_banco!)}',
          '${_n(_banco!)} tira ${_pct(_banco!.stats.pctTl)} en libres: el rival ya no tiene a quién faltarle.',
          'Cambiás defensa y ataque justo en el final.',
          s: 120,
        );
      case AccionTactica.lineaTiempoMuerto:
        final q = motor.tiemposMuertos(propio);
        if (j == null || q <= 0) return null;
        return o(
          'Tiempo muerto y salida armada',
          'Pelota a $nj (${_pct(j.stats.pctTl)} en libres) sin riesgo de robo.',
          'Gastás un tiempo muerto (te quedan ${q - 1}).',
        );
      case AccionTactica.defenderTriple:
        return o(
          'Defender el triple',
          'Salís a los tiradores: su triple baja 10 %.',
          'Cedés el aro: sus dobles suben 6 %.',
          s: 60,
        );
      case AccionTactica.faltaTactica:
        return o(
          'Hacer falta antes del tiro',
          'Cortás la jugada y los mandás a la línea (2 libres).',
          'Si meten los dos siguen en juego y pueden tener el último tiro.',
        );
      case AccionTactica.pedirPelota ||
          AccionTactica.atacarAro ||
          AccionTactica.tirarTriple ||
          AccionTactica.buscarAbierto ||
          AccionTactica.takeover ||
          AccionTactica.cerrarMarca ||
          AccionTactica.apostarRobo ||
          AccionTactica.guardarEnergia ||
          AccionTactica.yoAislamiento ||
          AccionTactica.yoTriple ||
          AccionTactica.yoPasar:
        return _opYo(a, recomendada: recomendada, rival: rival);
    }
  }

  /// Efecto (propio, del rival) de cada acción. Los números van con los textos de [_op].
  (EfectoEnVivo, EfectoEnVivo?) _efecto(OpcionDecision o) {
    const neutro = EfectoEnVivo();
    return switch (o.accion) {
      AccionTactica.defensaIndividual => (const EfectoEnVivo(defensa: EsquemaDefensivo.switchAll), null),
      AccionTactica.zona => (
        const EfectoEnVivo(defensa: EsquemaDefensivo.zona23, tripleRival: 1.04, interiorRival: 1.03),
        null,
      ),
      AccionTactica.presion => (
        const EfectoEnVivo(
          defensa: EsquemaDefensivo.presionTodaCancha,
          fatigaFactor: 1.15,
          tripleRival: 1.03,
          mods: ModificadoresEquipo(interiorRival: -0.015),
        ),
        null,
      ),
      AccionTactica.cajaYUno => (
        const EfectoEnVivo(defensa: EsquemaDefensivo.cajaYUno, tripleRival: 1.03, interiorRival: 0.97),
        null,
      ),
      AccionTactica.ritmoAlto => (const EfectoEnVivo(ritmo: 1, fatigaFactor: 1.12), null),
      AccionTactica.ritmoBajo => (const EfectoEnVivo(ritmo: -1, fatigaFactor: 0.88), null),
      AccionTactica.enfriar => (const EfectoEnVivo(ritmo: -1, fatigaFactor: 0.9), null),
      AccionTactica.focoAislamiento => (EfectoEnVivo(foco: o.jugadorId, focoPeso: 2, focoExtra: -0.008), null),
      AccionTactica.focoPickAndRoll => (
        EfectoEnVivo(
          foco: o.jugadorId,
          focoPeso: 1.5,
          focoExtra: -0.006,
          mods: const ModificadoresEquipo(asistidoExtra: 0.012, interiorExtra: 0.008),
        ),
        null,
      ),
      AccionTactica.circulaPelota => (
        const EfectoEnVivo(ataque: SistemaOfensivo.motionOffense, mods: ModificadoresEquipo(asistidoExtra: 0.01)),
        null,
      ),
      AccionTactica.hack => (const EfectoEnVivo(faltar: 0.55), null),
      AccionTactica.quintetoChico => (
        const EfectoEnVivo(
          ataque: SistemaOfensivo.cincoAbierto,
          mods: ModificadoresEquipo(interiorRival: -0.012, tripleExtra: 0.012),
        ),
        const EfectoEnVivo(mods: ModificadoresEquipo(reboteOfensivoFactor: 1.08)),
      ),
      AccionTactica.quintetoGrande => (
        const EfectoEnVivo(
          ataque: SistemaOfensivo.postInsideOut,
          ritmo: -0.5,
          mods: ModificadoresEquipo(reboteOfensivoFactor: 1.12, interiorRival: 0.015, tripleExtra: -0.02),
        ),
        null,
      ),
      AccionTactica.aguantar => (const EfectoEnVivo(aguantar: true), null),
      AccionTactica.lineaMejor => (EfectoEnVivo(linea: o.jugadorId, lineaRiesgo: 0.07), null),
      AccionTactica.lineaTiempoMuerto => (EfectoEnVivo(linea: o.jugadorId, lineaRiesgo: 0), null),
      AccionTactica.defenderTriple => (const EfectoEnVivo(tripleRival: 0.9, interiorRival: 1.06), null),
      AccionTactica.faltaTactica => (const EfectoEnVivo(faltar: 1), null),
      AccionTactica.pedirPelota ||
      AccionTactica.atacarAro ||
      AccionTactica.tirarTriple ||
      AccionTactica.buscarAbierto ||
      AccionTactica.takeover ||
      AccionTactica.cerrarMarca ||
      AccionTactica.apostarRobo ||
      AccionTactica.guardarEnergia ||
      AccionTactica.yoAislamiento ||
      AccionTactica.yoTriple ||
      AccionTactica.yoPasar => (_efectoYo(o.accion), null),
      _ => (neutro, null),
    };
  }

  // ── activar y cerrar ajustes ──

  void _activar(OpcionDecision o, RegistroDecision reg) {
    reg
      ..opcion = o.titulo
      ..opcionId = o.id;
    final t = ahora;
    String? volverId, reemplazoId;
    switch (o.accion) {
      case AccionTactica.tiempoMuerto || AccionTactica.lineaTiempoMuerto:
        if (motor.pedirTiempoMuerto(propio)) {
          _rachaRival = 0;
          _tm = motor.tiemposMuertos(propio);
        }
      case AccionTactica.descansar:
        volverId = o.jugadorId;
        reemplazoId = _banco?.id;
        motor.cambiar(propio, o.jugadorId!);
      case AccionTactica.sentar || AccionTactica.lineaSentarPeor:
        motor.cambiar(propio, o.jugadorId!);
      case AccionTactica.jugadaAislamiento:
        motor.pedirJugada(JugadaClave.aislamiento);
      case AccionTactica.jugadaTriple:
        motor.pedirJugada(JugadaClave.triple);
      case AccionTactica.jugadaPickAndRoll:
        motor.pedirJugada(JugadaClave.pickAndRoll);
      case AccionTactica.yoAislamiento:
        motor.pedirJugada(JugadaClave.aislamiento, tiradorId: yo?.id);
      case AccionTactica.yoTriple:
        motor.pedirJugada(JugadaClave.triple, tiradorId: yo?.id);
      case AccionTactica.yoPasar:
        motor.pedirJugada(JugadaClave.pickAndRoll, evitarId: yo?.id);
      case AccionTactica.takeover:
        takeoversUsados++;
        _takeoverCuarto.add(motor.cuarto);
      case _:
    }
    final cat = o.accion.categoria;
    if (cat != CategoriaAjuste.otro) {
      for (final previo in List.of(activos)) {
        if (previo.categoria == cat) _cerrar(previo, reemplazado: true);
      }
    }
    final (p, r) = _efecto(o);
    // Las jugadas y la salida armada se resuelven solas: si no llegan, vencen al minuto.
    final dur = o.accion.unaJugada ? 90.0 : o.segundos;
    final ef = EfectoActivo._(o, cat, p, r ?? const EfectoEnVivo(), t, t + dur, _foto(), reg)
      ..volverId = volverId
      ..reemplazoId = reemplazoId;
    activos.add(ef);
    _reaplicar();
  }

  void _reaplicar() {
    var p = const EfectoEnVivo(), r = const EfectoEnVivo();
    for (final ef in activos) {
      p = p.mas(ef.propio);
      r = r.mas(ef.rival);
    }
    motor.aplicarEfecto(propio, p.esNeutro ? null : p);
    motor.aplicarEfecto(!propio, r.esNeutro ? null : r);
  }

  String? _cerrar(EfectoActivo ef, {bool reemplazado = false}) {
    activos.remove(ef);
    _reaplicar();
    final a = ef.opcion.accion;
    if (a == AccionTactica.descansar && ef.volverId != null && ef.reemplazoId != null && !motor.terminado) {
      if (motor.enBanco(propio)?.id == ef.volverId && _cancha.any((j) => j.id == ef.reemplazoId)) {
        motor.cambiar(propio, ef.reemplazoId!);
      }
    }
    if (a.unaJugada) {
      // La jugada que no llegó a pasar no cuenta como decisión mala ni buena.
      if (!ef.cumplido) ef.registro.aviso ??= 'No llegó a jugarse antes de que cambie el partido.';
      return ef.cumplido ? ef.registro.aviso : null;
    }
    final aviso = _resumen(ef, reemplazado: reemplazado);
    ef.registro.aviso = aviso;
    return aviso;
  }

  /// Cuenta cómo salió un ajuste: números del rato que duró y una valoración aproximada.
  String _resumen(EfectoActivo ef, {required bool reemplazado}) {
    final ini = ef._foto, fin = _foto();
    final dur = max(20.0, fin.t - ini.t);
    final min = (dur / 60).toStringAsFixed(dur >= 90 ? 0 : 1).replaceAll('.', ',');
    final mis = fin.ptsP - ini.ptsP, ellos = fin.ptsR - ini.ptsR;
    final margen = mis - ellos;
    // Lo que venía pasando en un rato igual de largo justo antes (para no atribuir al ajuste lo de siempre).
    final previo = _margenEn(ini.t) - _margenEn(ini.t - dur);
    final impacto = (margen - 0.5 * previo).round();
    final v = dur < 45
        ? Veredicto.sinDato
        : impacto >= 3
        ? Veredicto.ayudo
        : (impacto <= -3 ? Veredicto.empeoro : Veredicto.neutro);
    ef.registro
      ..impacto = dur < 45 ? null : impacto
      ..veredicto = v;
    final rFga = fin.fgaR - ini.fgaR, rFgm = fin.fgmR - ini.fgmR;
    final d = '$mis-$ellos en $min min';
    final signo = impacto > 0 ? '+$impacto' : '$impacto';
    final cierre = switch (v) {
      Veredicto.ayudo => ' Ayudó (≈ $signo).',
      Veredicto.empeoro => ' No salió: ≈ $signo.',
      Veredicto.neutro => ' No cambió mucho.',
      Veredicto.sinDato => '',
    };
    final nom = ef.opcion.titulo;
    return switch (ef.opcion.accion) {
      AccionTactica.zona ||
      AccionTactica.defensaIndividual ||
      AccionTactica.presion ||
      AccionTactica.cajaYUno ||
      AccionTactica.defenderTriple =>
        v == Veredicto.ayudo && rFgm * 2 <= rFga
            ? '$nom cortó la racha: ellos $rFgm de $rFga ($d).'
            : '$nom: ellos $rFgm de $rFga ($d).$cierre',
      AccionTactica.tiempoMuerto => 'Después del tiempo muerto: $d.$cierre',
      AccionTactica.ritmoAlto ||
      AccionTactica.ritmoBajo ||
      AccionTactica.enfriar => 'Con el ritmo cambiado: $d.$cierre',
      AccionTactica.focoAislamiento ||
      AccionTactica.focoPickAndRoll ||
      AccionTactica.pedirPelota ||
      AccionTactica.atacarAro ||
      AccionTactica.tirarTriple ||
      AccionTactica.buscarAbierto ||
      AccionTactica.takeover => _avisoYoFoco(ef, d, cierre),
      AccionTactica.cerrarMarca || AccionTactica.apostarRobo => '$nom: ellos $rFgm de $rFga, $d.$cierre',
      AccionTactica.guardarEnergia => 'Cuidándote: $d.$cierre',
      AccionTactica.hack => () {
        final att = fin.tlaR - ini.tlaR, hechos = fin.tlmR - ini.tlmR;
        return att == 0 ? 'El hack no llegó a usarse ($d).' : 'El hack: ellos $hechos de $att en libres ($d).$cierre';
      }(),
      AccionTactica.descansar => 'Con el titular en el banco: $d.$cierre',
      AccionTactica.sentar || AccionTactica.lineaSentarPeor => 'Sin el titular en cancha: $d.$cierre',
      _ => '$nom: $d.$cierre',
    };
  }

  String _avisoFoco(EfectoActivo ef, String d, String cierre) {
    final id = ef.opcion.jugadorId;
    final l = id == null ? null : _boxP[id];
    return l == null
        ? '${ef.opcion.titulo}: $d.$cierre'
        : 'Con ${_nombreDe(id)} como foco: ${l.pts} pts en total ($d).$cierre';
  }

  int _margenEn(double t) {
    var p = 0, r = 0;
    for (final e in _linea) {
      if (e.$1 > t) break;
      p = e.$2;
      r = e.$3;
    }
    return p - r;
  }

  // ───────────── Decisiones como jugador (Mi carrera) ─────────────

  /// Tu jugador si está en la cancha (null si está en el banco o expulsado).
  Jugador? get _yoJ {
    final id = yo?.id;
    if (id == null) return null;
    for (final j in _cancha) {
      if (j.id == id) return j;
    }
    return null;
  }

  final _takeoverCuarto = <int>{};

  /// Carga del Takeover (0 a 100): sube con tus aciertos y baja con los fallos recientes.
  double get takeoverCarga {
    final id = yo?.id;
    if (id == null) return 0;
    final mios = [
      for (final t in _tiros.reversed)
        if (t.$1 && t.$2 == id) t,
    ].take(10).toList();
    var c = 0.0;
    for (final t in mios) {
      c += t.$4 ? (t.$3 ? 30 : 20) : -8;
    }
    return c.clamp(0, 100).toDouble();
  }

  /// Los últimos [n] tiros de tu jugador (true: entró).
  List<bool> _misUltimos(int n) {
    final id = yo?.id;
    return [
      for (final t in _tiros.reversed)
        if (t.$1 && t.$2 == id) t.$4,
    ].take(n).toList();
  }

  double _k(num valor, double por, {double base = 75}) => (valor - base) * por;

  /// Cuánto cambia el acierto de tu jugador (en puntos porcentuales) con cada acción: sale de lo que sabe hacer.
  double _extraFoco(AccionTactica a) {
    final y = yo!;
    switch (a) {
      case AccionTactica.pedirPelota:
        return _k(y.ataque, 0.0007) - 0.012;
      case AccionTactica.atacarAro:
        return _k(y.a(Atributo.finalizacion), 0.0008) +
            _k((y.h(Habilidad.bandeja) + y.h(Habilidad.volcada)) / 2, 0.0004) -
            0.006;
      case AccionTactica.tirarTriple:
        return _k(y.h(Habilidad.triple), 0.0009) - 0.01;
      case AccionTactica.takeover:
        return 0.02 + _k(y.ataque, 0.0005, base: 80).clamp(-0.01, 0.02);
      case AccionTactica.yoAislamiento:
        return _k(y.a(Atributo.iq), 0.0004) +
            0.008 * y.nivel(Insignia.clutch) +
            0.004 * y.nivel(Insignia.sangreFria) -
            0.01;
      case AccionTactica.yoTriple:
        return _k(y.h(Habilidad.triple), 0.0008) +
            0.008 * y.nivel(Insignia.clutch) +
            0.004 * y.nivel(Insignia.sangreFria) -
            0.014;
      default:
        return 0;
    }
  }

  EfectoEnVivo _efectoYo(AccionTactica a) {
    final y = yo!;
    double lim(double v, double lo, double hi) => v.clamp(lo, hi).toDouble();
    switch (a) {
      case AccionTactica.pedirPelota:
        return EfectoEnVivo(foco: y.id, focoPeso: 1.9, focoExtra: _extraFoco(a));
      case AccionTactica.atacarAro:
        return EfectoEnVivo(foco: y.id, focoPeso: 1.5, focoExtra: _extraFoco(a));
      case AccionTactica.tirarTriple:
        return EfectoEnVivo(
          foco: y.id,
          focoPeso: 1.6,
          focoExtra: _extraFoco(a),
          mods: const ModificadoresEquipo(tripleExtra: 0.004),
        );
      case AccionTactica.buscarAbierto:
        final pase = (y.h(Habilidad.pase) + y.h(Habilidad.vision)) / 2;
        return EfectoEnVivo(
          foco: y.id,
          focoPeso: 0.5,
          mods: ModificadoresEquipo(asistidoExtra: lim(0.008 + _k(pase, 0.0006), 0.004, 0.03)),
        );
      case AccionTactica.takeover:
        return EfectoEnVivo(
          foco: y.id,
          focoPeso: 2.4,
          focoExtra: _extraFoco(a),
          fatigaFactor: 1.15,
          mods: const ModificadoresEquipo(tripleExtra: 0.006, clutchExtra: 0.01),
        );
      case AccionTactica.cerrarMarca:
        return EfectoEnVivo(
          tripleRival: 1 - lim(_k(y.h(Habilidad.defPerimetral), 0.0025, base: 70), 0.0, 0.08) - 0.01,
          interiorRival: 1 - lim(_k(y.h(Habilidad.defInterior), 0.002, base: 70), 0.0, 0.05),
          fatigaFactor: 1.08,
        );
      case AccionTactica.apostarRobo:
        return EfectoEnVivo(
          robosFactor: 1 + lim(_k(y.h(Habilidad.robo), 0.008, base: 60), 0.05, 0.4),
          interiorRival: lim(1.05 - _k(y.h(Habilidad.robo), 0.001, base: 70), 1.01, 1.08),
        );
      case AccionTactica.guardarEnergia:
        return EfectoEnVivo(
          foco: y.id,
          focoPeso: 0.85,
          fatigaFactor: lim(0.78 - _k(y.h(Habilidad.resistencia), 0.001, base: 70), 0.6, 0.9),
        );
      case AccionTactica.yoAislamiento:
      case AccionTactica.yoTriple:
        return EfectoEnVivo(foco: y.id, focoPeso: 1, focoExtra: _extraFoco(a));
      default:
        return const EfectoEnVivo();
    }
  }

  String _signo(double v) => '${v >= 0 ? '+' : '−'}${(v.abs() * 100).toStringAsFixed(1).replaceAll('.', ',')} %';

  OpcionDecision? _opYo(AccionTactica a, {bool recomendada = false, Jugador? rival}) {
    final y = yo;
    final yoJ = _yoJ;
    if (y == null || yoJ == null) return null;
    OpcionDecision o(String titulo, String efecto, String costo, {double s = 180}) => OpcionDecision(
      accion: a,
      titulo: titulo,
      efecto: efecto,
      costo: costo,
      jugadorId: y.id,
      recomendada: recomendada,
      segundos: a.unaJugada ? 0 : s,
    );
    switch (a) {
      case AccionTactica.pedirPelota:
        return o(
          'Pedir la pelota',
          'El doble de tiros para vos. Con tu nivel ofensivo (${y.ataque.round()}) el acierto cambia ${_signo(_extraFoco(a))}.',
          'Los demás se enfrían y, si no estás fino, forzás tiros.',
        );
      case AccionTactica.atacarAro:
        return o(
          'Atacar el aro',
          'Más tiros cerca del aro (×1,5). Tu finalización (${y.a(Atributo.finalizacion)}) mueve el acierto ${_signo(_extraFoco(a))}.',
          'Si te cierran la pintura, perdés rebote y energía.',
        );
      case AccionTactica.tirarTriple:
        return o(
          'Tirar de tres',
          'Más triples tuyos (×1,6). Tu triple (${y.h(Habilidad.triple)}) mueve el acierto ${_signo(_extraFoco(a))}.',
          'Tiro largo: sin buen triple, el costo se nota.',
        );
      case AccionTactica.buscarAbierto:
        return o(
          'Buscar al compañero',
          'Vos tirás menos y el equipo mete más asistido (tu pase y visión: ${((y.h(Habilidad.pase) + y.h(Habilidad.vision)) / 2).round()}).',
          'Tus puntos bajan; es lo que el equipo necesita si no estás fino.',
        );
      case AccionTactica.takeover:
        return o(
          'TAKEOVER',
          'Te hacés cargo: ×2,4 de tiros y mejor puntería (${_signo(_extraFoco(a))}) por 2 minutos y medio.',
          'Te cansás 15 % más rápido.',
          s: 150,
        );
      case AccionTactica.cerrarMarca:
        return o(
          'Cerrar a tu marca',
          'Tu defensa (perimetral ${y.h(Habilidad.defPerimetral)}, interior ${y.h(Habilidad.defInterior)}) baja el acierto rival.',
          'Te cansás 8 % más rápido y arriesgás faltas.',
        );
      case AccionTactica.apostarRobo:
        return o(
          'Apostar al robo',
          'Más robos (tu robo: ${y.h(Habilidad.robo)}). Lo que robes sale en contraataque.',
          'Si fallás la apuesta, regalás el aro (sus dobles suben).',
        );
      case AccionTactica.guardarEnergia:
        return o(
          'Cuidar la energía',
          'Gastás menos (tu resistencia: ${y.h(Habilidad.resistencia)}) y jugás con más aire más adelante.',
          'Tirás un poco menos ahora.',
        );
      case AccionTactica.yoAislamiento:
        return o(
          'Pedir la última',
          'Uno contra uno: tirás vos. Tu IQ y tus insignias de clutch mueven el acierto ${_signo(_extraFoco(a))}.',
          'Todo depende de vos: si te cargan, no hay plan B.',
        );
      case AccionTactica.yoTriple:
        return o(
          'Ir por el triple',
          'Tirás de tres vos (${y.h(Habilidad.triple)} de triple): acierto ${_signo(_extraFoco(a))}.',
          'Vale 3 si entra, nada si no.',
        );
      case AccionTactica.yoPasar:
        return o(
          'Pasar al abierto',
          'Atraés la marca y buscás al compañero libre (pase ${y.h(Habilidad.pase)}, visión ${y.h(Habilidad.vision)}).',
          'No sumás puntos propios, pero el tiro sale más limpio.',
        );
      default:
        return null;
    }
  }

  /// Lo que se puede pedir ahora como jugador (menú de AJUSTES).
  List<OpcionDecision> _menuJugador() {
    final lista = <OpcionDecision?>[
      if (takeoverCarga >= 70 && !_takeoverCuarto.contains(motor.cuarto)) _opYo(AccionTactica.takeover),
      _opYo(AccionTactica.pedirPelota),
      _opYo(AccionTactica.atacarAro),
      _opYo(AccionTactica.tirarTriple),
      _opYo(AccionTactica.buscarAbierto),
      _opYo(AccionTactica.cerrarMarca),
      _opYo(AccionTactica.apostarRobo),
      _opYo(AccionTactica.guardarEnergia),
      if (_yoJ != null && _banco != null) _op(AccionTactica.descansar, j: _yoJ),
    ];
    return [for (final o in lista) ?o];
  }

  String _avisoYoFoco(EfectoActivo ef, String d, String cierre) {
    if (yo == null) return _avisoFoco(ef, d, cierre);
    final id = yo?.id;
    final l = id == null ? null : _boxP[id];
    if (l == null) return '${ef.opcion.titulo}: $d.$cierre';
    return '${ef.opcion.titulo}: vos hiciste ${l.pts} pts, ${l.reb} reb y ${l.ast} ast en total ($d).$cierre';
  }

  /// El partido se frena solo en tus momentos: plan, jugadas decisivas, rachas, marca, energía y Takeover.
  DecisionPartido? _evaluarJugador() {
    final yoJ = _yoJ;
    if (yoJ == null || motor.terminado) return null;
    if (_permite(critica: true)) {
      final d = _tuClutch();
      if (d != null) return _presentar(d);
    }
    if (_permite(critica: false)) {
      final d = _tuPlan() ?? _tuTakeover() ?? _tuCaliente() ?? _tuFrio() ?? _tuMarca() ?? _tuEnergia();
      if (d != null) return _presentar(d);
    }
    return null;
  }

  /// Plan de juego al arrancar el partido y la segunda parte.
  DecisionPartido? _tuPlan() {
    final y = yo!;
    final primera = motor.cuarto == 1 && ahora < 60;
    final segunda = motor.cuarto == 3 && motor.reloj > 690;
    if (!primera && !segunda) return null;
    if (_visto(primera ? 'plan:1' : 'plan:2')) return null;
    final ataca = y.ataque >= 72 ? AccionTactica.pedirPelota : AccionTactica.buscarAbierto;
    return _decision(
      TipoDecision.tuPlan,
      primera
          ? 'Arranca el partido: ¿cómo querés jugarlo hoy?'
          : 'Segunda parte. Hasta acá: ${_linea1(_yoJ!).pts} pts, ${_linea1(_yoJ!).reb} reb, ${_linea1(_yoJ!).ast} ast. ¿Qué cambiás?',
      [
        _opYo(AccionTactica.pedirPelota, recomendada: ataca == AccionTactica.pedirPelota),
        _opYo(AccionTactica.buscarAbierto, recomendada: ataca == AccionTactica.buscarAbierto),
        _opYo(AccionTactica.cerrarMarca),
        _opYo(AccionTactica.guardarEnergia),
      ],
    );
  }

  /// Estás encendido: aprovechalo.
  DecisionPartido? _tuCaliente() {
    final ult = _misUltimos(5);
    if (ult.length < 5 || ult.where((x) => x).length < 4) return null;
    if (motor.efecto(propio)?.foco != null) return null;
    if (_visto('caliente:${motor.cuarto}')) return null;
    return _decision(
      TipoDecision.tuMomento,
      'Metiste ${ult.where((x) => x).length} de tus últimos 5 tiros. Estás encendido.',
      [
        _opYo(AccionTactica.pedirPelota, recomendada: true),
        _opYo(AccionTactica.tirarTriple),
        _opYo(AccionTactica.atacarAro),
      ],
    );
  }

  /// Estás frío: cambiá la forma de ayudar.
  DecisionPartido? _tuFrio() {
    final ult = _misUltimos(6);
    if (ult.length < 5 || ult.where((x) => x).length > 1) return null;
    if (_visto('frio:${motor.cuarto <= 2 ? 0 : 1}')) return null;
    return _decision(
      TipoDecision.tuMomento,
      'Tus últimos tiros no entran (${ult.where((x) => x).length} de ${ult.length}). Hay que cambiar algo.',
      [
        _opYo(AccionTactica.buscarAbierto, recomendada: true),
        _opYo(AccionTactica.atacarAro),
        _opYo(AccionTactica.cerrarMarca),
        _opYo(AccionTactica.guardarEnergia),
      ],
    );
  }

  /// La figura rival te la está haciendo difícil.
  DecisionPartido? _tuMarca() {
    final rivales = [..._canchaR]..sort((a, b) => (_box(b.id)?.pts ?? 0).compareTo(_box(a.id)?.pts ?? 0));
    if (rivales.isEmpty) return null;
    final f = rivales.first;
    final pts = _box(f.id)?.pts ?? 0;
    if (pts < 14 || _visto('marca:${f.id}:${pts ~/ 8}')) return null;
    return _decision(TipoDecision.tuMarca, '${_n(f)} ya lleva $pts puntos. Te toca hacerle la vida difícil.', [
      _opYo(AccionTactica.cerrarMarca, recomendada: true),
      _opYo(AccionTactica.apostarRobo),
      _opYo(AccionTactica.guardarEnergia),
    ]);
  }

  /// Estás sin aire.
  DecisionPartido? _tuEnergia() {
    final j = _yoJ;
    if (j == null || _energia(j) > 48 || _visto('energia:${motor.cuarto}')) return null;
    return _decision(TipoDecision.tuEnergia, 'Te quedó ${_energia(j).round()} % de energía y todavía falta partido.', [
      _opYo(AccionTactica.guardarEnergia, recomendada: true),
      if (_banco != null) _op(AccionTactica.descansar, j: j),
      _opYo(AccionTactica.cerrarMarca),
    ]);
  }

  /// Barra llena: podés hacerte cargo del partido.
  DecisionPartido? _tuTakeover() {
    if (takeoverCarga < 70 || _takeoverCuarto.contains(motor.cuarto)) return null;
    if (_visto('takeover:${motor.cuarto}')) return null;
    return _decision(
      TipoDecision.takeover,
      'Tu racha llenó la barra de Takeover (${takeoverCarga.round()} %). ¿Te hacés cargo?',
      [_opYo(AccionTactica.takeover, recomendada: true), _opYo(AccionTactica.pedirPelota)],
    );
  }

  /// Final apretado con la pelota en tu equipo: elegís qué hacés con ella.
  DecisionPartido? _tuClutch() {
    if (motor.cuarto < 4 || motor.reloj > 150 || !motor.ataqueDelUsuario || _dif.abs() > 5) return null;
    if (_visto('clutch:${motor.cuarto}:${(motor.reloj / 40).floor()}')) return null;
    final y = yo!;
    final abajo3 = _dif == -3 || (_dif < -3 && motor.reloj < 40);
    final tiro = y.h(Habilidad.triple) >= y.a(Atributo.iq) ? AccionTactica.yoTriple : AccionTactica.yoAislamiento;
    return _decision(
      TipoDecision.tuClutch,
      '${_situacion.split(' · ').first}: la pelota es de tu equipo en el final. ${abajo3 ? 'Hace falta un triple.' : 'Decidís vos.'}',
      [
        _opYo(abajo3 ? AccionTactica.yoTriple : tiro, recomendada: true),
        _opYo(
          abajo3
              ? AccionTactica.yoAislamiento
              : (tiro == AccionTactica.yoTriple ? AccionTactica.yoAislamiento : AccionTactica.yoTriple),
        ),
        _opYo(AccionTactica.yoPasar),
      ],
      espera: 10,
    );
  }

  LineaEstadistica? _box(String id) => _boxR[id] ?? _boxP[id];

  // ── los disparadores ──

  bool _visto(String clave) => !_vistos.add(clave);

  DecisionPartido _decision(TipoDecision tipo, String motivo, List<OpcionDecision?> opciones, {int espera = 14}) {
    final lista = [for (final o in opciones) ?o].take(4).toList();
    return DecisionPartido(
      id: _siguienteId++,
      tipo: tipo,
      situacion: _situacion,
      motivo: motivo,
      opciones: lista,
      cuarto: motor.cuarto,
      reloj: motor.reloj,
      segundosEspera: espera,
    );
  }

  /// Parcial en contra: 8 puntos seguidos del rival o más.
  DecisionPartido? _parcialContra() {
    if (_rachaRival < 8 || motor.reloj < 20) return null;
    if (_visto('parcial:${motor.cuarto}:${_rachaRival >= 10 ? 10 : 8}')) return null;
    final (m, n) = _fg(true, n: 8);
    final (rm, rn) = _fg(false, n: 8);
    final propios = n >= 4 ? 'tus últimos $n tiros: $m de $n (${_pct(m / n)})' : 'tu ataque no encuentra el aro';
    final ellos = rn >= 4 ? ', ellos $rm de $rn' : '';
    final tienenFigura = _boxR.values.fold(0, (a, l) => max(a, l.pts)) >= max(10, _ptsR * 0.4);
    final defensa = _defensaSugerida(tienenFigura);
    final cansado = _cancha
        .where((j) => _energia(j) < 62)
        .fold<Jugador?>(null, (a, j) => a == null || _energia(j) < _energia(a) ? j : a);
    return _decision(TipoDecision.parcialContra, 'Ellos vienen $_rachaRival-0; $propios$ellos.', [
      _op(AccionTactica.tiempoMuerto, recomendada: _rachaRival >= 10),
      defensa,
      _op(AccionTactica.focoAislamiento, j: _estrella),
      cansado == null ? _op(AccionTactica.ritmoBajo) : _op(AccionTactica.descansar, j: cansado),
    ]);
  }

  OpcionDecision? _defensaSugerida(bool tienenFigura) {
    if (tienenFigura && _defensaActual != EsquemaDefensivo.cajaYUno) {
      return _op(AccionTactica.cajaYUno, rival: _figuraRival, recomendada: true);
    }
    final (hechos, total) = _tres(false);
    final desdeAfuera = total >= 4 && hechos / total >= 0.4;
    final tirosTres = _tiros.where((t) => !t.$1).toList().reversed.take(12).where((t) => t.$3).length;
    final afuera = desdeAfuera || tirosTres >= 5;
    return afuera
        ? _op(AccionTactica.defensaIndividual, recomendada: true) ?? _op(AccionTactica.zona)
        : _op(AccionTactica.zona, recomendada: true) ?? _op(AccionTactica.defensaIndividual);
  }

  /// Un titular con muy poca energía.
  DecisionPartido? _cansancio() {
    if (motor.reloj < 25) return null;
    final cansados = _cancha.where((j) => _energia(j) < (_media(j) >= _media(_estrella) - 3 ? 52 : 44)).toList()
      ..sort((a, b) => _energia(a).compareTo(_energia(b)));
    if (cansados.isEmpty) return null;
    final j = cansados.first;
    if (_visto('cansancio:${j.id}:${motor.cuarto}')) return null;
    final minutos = (_linea1(j).seg / 60).floor();
    final b = _banco;
    final bancoEnergia = b == null ? 0.0 : _energia(b);
    return _decision(
      TipoDecision.cansancio,
      '${_n(j)} lleva $minutos min y le queda ${_energia(j).round()} % de energía'
      '${b == null ? '' : '; ${_n(b)} está al ${bancoEnergia.round()} %'}: se le notan las piernas en el tiro.',
      [
        _op(AccionTactica.descansar, j: j, recomendada: b != null && bancoEnergia > _energia(j) + 15),
        _op(AccionTactica.tiempoMuerto),
        _op(AccionTactica.ritmoBajo),
      ],
    );
  }

  int _umbralFaltas() => motor.cuarto <= 3 ? 4 : 5;

  /// Un jugador importante con muchas faltas para el cuarto en el que estamos.
  DecisionPartido? _faltas() {
    if (motor.reloj < 25) return null;
    final cargados = _cancha.where((j) => _linea1(j).fal >= _umbralFaltas()).toList()
      ..sort((a, b) => _media(b).compareTo(_media(a)));
    if (cargados.isEmpty) return null;
    final j = cargados.first;
    if (_visto('faltas:${j.id}:${motor.cuarto}')) return null;
    final f = _linea1(j).fal;
    final c = motor.cuarto > 4 ? 'la prórroga' : 'el ${motor.cuarto}.º cuarto';
    return _decision(
      TipoDecision.faltas,
      '${_n(j)} ya tiene $f faltas en $c: con la sexta se va, y sin él el equipo cambia.',
      [
        _op(AccionTactica.sentar, j: j, recomendada: motor.cuarto <= 3),
        _op(AccionTactica.aguantar, j: j, recomendada: motor.cuarto >= 4),
        _op(AccionTactica.zona),
      ],
    );
  }

  /// El rival está acertando casi todo.
  DecisionPartido? _rivalCaliente() {
    if (_rachaRival >= 8 || motor.reloj < 30) return null;
    final (rm, rn) = _fg(false, n: 10);
    final (r3m, r3n) = _tres(false, n: 14);
    final caliente = (rn >= 10 && rm >= 8) || (r3n >= 5 && r3m >= 4 && r3m / r3n >= 0.8);
    if (!caliente) return null;
    if (_visto('rival:${motor.cuarto <= 2 ? 0 : 1}')) return null;
    final (m, n) = _fg(true, n: 8);
    final motivo = r3n >= 4 && r3m / r3n >= 0.75
        ? 'Ellos meten $r3m de $r3n triples seguidos'
        : 'Ellos vienen $rm de $rn en sus últimos tiros';
    final figura = _boxR.values.fold(0, (a, l) => max(a, l.pts)) >= max(10, _ptsR * 0.4);
    return _decision(TipoDecision.rivalCaliente, '$motivo${n >= 4 ? ' y vos $m de $n' : ''}: les está saliendo todo.', [
      _defensaSugerida(figura),
      _op(AccionTactica.presion),
      _op(AccionTactica.cajaYUno, rival: _figuraRival),
      _op(AccionTactica.ritmoBajo),
    ]);
  }

  /// Un jugador tuyo viene muy encendido.
  DecisionPartido? _tiradorEncendido() {
    if (motor.reloj < 40 || motor.efecto(propio)?.foco != null) return null;
    for (final j in _cancha) {
      final mios = [
        for (final t in _tiros.reversed)
          if (t.$1 && t.$2 == j.id) t.$4,
      ].take(6).toList();
      if (mios.length < 6 || mios.where((x) => x).length < 5) continue;
      if (_visto('encendido:${motor.cuarto <= 2 ? 0 : 1}')) continue;
      final l = _linea1(j);
      return _decision(
        TipoDecision.tiradorEncendido,
        '${_n(j)} metió 5 de sus últimos 6 tiros (${l.pts} puntos en total).',
        [
          _op(AccionTactica.focoAislamiento, j: j),
          _op(AccionTactica.focoPickAndRoll, j: j),
          _op(AccionTactica.circulaPelota),
        ],
      );
    }
    return null;
  }

  /// Muy abajo en el marcador con tiempo para dar vuelta.
  DecisionPartido? _remontada() {
    if (motor.cuarto < 3 || _dif > -14) return null;
    if (motor.cuarto == 4 && motor.reloj < 240) return null;
    if (motor.cuarto > 4 || _visto('remontada:${motor.cuarto}')) return null;
    final peor = _peorLibres;
    return _decision(
      TipoDecision.remontada,
      'Perdés por ${-_dif} y quedan ${motor.cuarto == 3 ? 'el último cuarto y ' : ''}${_tiempo(motor.reloj)}: hay que arriesgar.',
      [
        _op(AccionTactica.presion),
        _op(AccionTactica.quintetoChico),
        _op(AccionTactica.ritmoAlto),
        _op(AccionTactica.hack, rival: peor),
      ],
    );
  }

  /// Muy arriba: ¿se cuida a los titulares o se sigue a fondo?
  DecisionPartido? _ventajaGrande() {
    if (motor.cuarto < 3 || motor.cuarto > 4 || _dif < 18) return null;
    if (_visto('ventaja:${motor.cuarto}')) return null;
    final star = _estrella;
    return _decision(
      TipoDecision.ventajaGrande,
      'Ganás por $_dif con $_momento: el partido está liquidado y ${_n(star)} lleva ${(_linea1(star).seg / 60).floor()} min.',
      [
        _op(AccionTactica.descansar, j: star, recomendada: true),
        _op(AccionTactica.enfriar),
        _op(AccionTactica.quintetoGrande),
      ],
    );
  }

  /// La próxima posesión es tuya y el cuarto se termina (1.º a 3.º).
  DecisionPartido? _ultimoTiro() {
    if (motor.cuarto > 3 || !motor.ataqueDelUsuario || motor.reloj > 22 || motor.reloj < 7) return null;
    if (motor.cuarto != 2 && _dif.abs() > 6) return null;
    if (_visto('ultimo:${motor.cuarto}')) return null;
    final star = motor.tiradorDeJugada(propio, JugadaClave.aislamiento), tirador = _mejorTirador;
    final (org, grande) = _duoPickAndRoll;
    final quedan = motor.reloj.ceil();
    return _decision(
      TipoDecision.ultimoTiro,
      'Quedan $quedan segundos del ${motor.cuarto}.º cuarto y la tenés vos: una buena jugada vale un tiro limpio, no un apuro.',
      [
        _op(AccionTactica.jugadaAislamiento, j: star, recomendada: true),
        _op(AccionTactica.jugadaTriple, j: tirador),
        _op(AccionTactica.jugadaPickAndRoll, j: org, j2: grande),
      ],
      espera: 10,
    );
  }

  /// Vas ganando por poco, el rival está obligado a hacerte falta y la pelota es tuya.
  DecisionPartido? _faltaIntencional() {
    if (motor.cuarto < 4 || !motor.ataqueDelUsuario || motor.reloj > 35 || motor.reloj < 3) return null;
    final d = _dif;
    final habra = (d >= 1 && d <= 2 && motor.reloj <= 24) || (d >= 3 && d <= min(8, 3 + motor.reloj / 5));
    if (!habra) return null;
    if (_visto('falta:${motor.cuarto}:${motor.reloj ~/ 12}')) return null;
    final peor = _cancha.reduce((a, b) => a.stats.pctTl <= b.stats.pctTl ? a : b);
    final mejor = _cancha.reduce((a, b) => a.stats.pctTl >= b.stats.pctTl ? a : b);
    final b = _banco;
    final mejoraBanco = b != null && b.stats.pctTl > peor.stats.pctTl + 0.08 && _linea1(b).fal < 5;
    return _decision(
      TipoDecision.faltaIntencional,
      'Ganás por $d y quedan ${motor.reloj.ceil()} segundos: te van a hacer falta, y el rival elige a quién: '
      'hoy sería ${_n(peor)} (${_pct(peor.stats.pctTl)} en libres).',
      [
        _op(AccionTactica.lineaMejor, j: mejor, recomendada: mejor.stats.pctTl - peor.stats.pctTl >= 0.12),
        mejoraBanco ? _op(AccionTactica.lineaSentarPeor, j: peor) : null,
        _op(AccionTactica.lineaTiempoMuerto, j: mejor),
      ],
      espera: 10,
    );
  }

  /// Final apretado con ventaja y el rival con la pelota.
  DecisionPartido? _finalConVentaja() {
    if (motor.cuarto < 4 || motor.ataqueDelUsuario || motor.reloj > 45 || motor.reloj < 8) return null;
    final d = _dif;
    if (d < 1 || d > 5) return null;
    if (_visto('final:${motor.cuarto}')) return null;
    final (r3m, r3n) = _tres(false, n: 10);
    final sobreLaHora = motor.reloj <= 20 && d <= 3;
    return _decision(
      TipoDecision.finalConVentaja,
      'Ganás por $d y quedan ${motor.reloj.ceil()} segundos.'
      '${r3n >= 3 ? ' Ellos vienen $r3m de $r3n de tres.' : ''}'
      '${d == 3 ? ' Un triple los empata.' : ''}',
      [
        _op(AccionTactica.defenderTriple, recomendada: d >= 2 && d <= 3 && !sobreLaHora),
        sobreLaHora ? _op(AccionTactica.faltaTactica, recomendada: d == 3 && motor.reloj <= 12) : null,
        _op(AccionTactica.presion),
        _op(AccionTactica.tiempoMuerto),
      ],
      espera: 10,
    );
  }

  // ── entretiempo ──

  /// Devuelve el informe del entretiempo una sola vez, cuando termina el 2.º cuarto.
  InformeEntretiempo? evaluarEntretiempo() {
    if (esJugador) return null;
    if (!habilitado || _entretiempoVisto || motor.terminado) return null;
    if (motor.cuarto != 3 || motor.reloj < 719) return null;
    _entretiempoVisto = true;
    registro.add(RegistroDecision(tipo: TipoDecision.entretiempo, cuarto: 3, reloj: 720));
    return informeEntretiempo();
  }

  InformeEntretiempo informeEntretiempo() {
    final filas = <FilaJugador>[];
    final cancha = {for (final j in _cancha) j.id};
    final todos = [..._cancha, ?_banco, ...motor.reservas(propio)];
    for (final j in todos) {
      final l = _linea1(j);
      if (l.seg <= 0 && !cancha.contains(j.id)) continue;
      filas.add(
        FilaJugador(
          id: j.id,
          nombre: _n(j),
          minutos: (l.seg / 60).round(),
          pts: l.pts,
          reb: l.reb,
          ast: l.ast,
          tcI: l.tcI,
          tcA: l.tcA,
          t3I: l.t3I,
          t3A: l.t3A,
          faltas: l.fal,
          energia: _energia(j),
          enCancha: cancha.contains(j.id),
        ),
      );
    }
    filas.sort((a, b) => b.pts.compareTo(a.pts));
    final f = _foto();
    final bien = <String>[], mal = <String>[];
    int sum(Map<String, LineaEstadistica> m, int Function(LineaEstadistica) g) => m.values.fold(0, (a, l) => a + g(l));
    final t3P = sum(_boxP, (l) => l.t3I), t3aP = sum(_boxP, (l) => l.t3A);
    final t3R = sum(_boxR, (l) => l.t3I), t3aR = sum(_boxR, (l) => l.t3A);
    final rebP = sum(_boxP, (l) => l.reb), rebR = sum(_boxR, (l) => l.reb);
    final tlP = sum(_boxP, (l) => l.tlI), tlaP = sum(_boxP, (l) => l.tlA);
    if (f.fgaP >= 10) {
      final p = f.fgmP / f.fgaP;
      (p >= 0.5 ? bien : (p <= 0.4 ? mal : null))?.add('Tiros de campo: ${f.fgmP} de ${f.fgaP} (${_pct(p)}).');
    }
    if (t3aP >= 6) {
      final p = t3P / t3aP;
      (p >= 0.4 ? bien : (p <= 0.28 ? mal : null))?.add('Triples: $t3P de $t3aP (${_pct(p)}).');
    }
    if (t3aR >= 6 && t3R / t3aR >= 0.42) mal.add('Les dejás tirar de tres: $t3R de $t3aR (${_pct(t3R / t3aR)}).');
    if (t3aR >= 6 && t3R / t3aR <= 0.28) bien.add('Les cerrás el triple: $t3R de $t3aR.');
    if (f.fgaR >= 10 && f.fgmR / f.fgaR <= 0.4) {
      bien.add('Defensa: ellos ${f.fgmR} de ${f.fgaR} (${_pct(f.fgmR / f.fgaR)}).');
    }
    if (f.fgaR >= 10 && f.fgmR / f.fgaR >= 0.52) {
      mal.add('Defensa: ellos ${f.fgmR} de ${f.fgaR} (${_pct(f.fgmR / f.fgaR)}).');
    }
    if (f.perP >= f.perR + 3) mal.add('Pérdidas: ${f.perP} contra ${f.perR} del rival.');
    if (f.perR >= f.perP + 3) bien.add('Pérdidas: forzaste ${f.perR} y perdiste ${f.perP}.');
    if (rebP >= rebR + 5) bien.add('Rebotes: $rebP contra $rebR.');
    if (rebR >= rebP + 5) mal.add('Rebotes: $rebP contra $rebR.');
    if (tlaP >= 6 && tlP / tlaP <= 0.6) mal.add('Libres: $tlP de $tlaP.');
    final figura = _boxR.entries.fold<MapEntry<String, LineaEstadistica>?>(
      null,
      (a, e) => a == null || e.value.pts > a.value.pts ? e : a,
    );
    if (figura != null && figura.value.pts >= 14) mal.add('${_nombreDe(figura.key)} ya les hizo ${figura.value.pts}.');
    final top = filas.isEmpty ? null : filas.first;
    if (top != null && top.pts >= 14) bien.add('${top.nombre} lleva ${top.pts} puntos.');
    final cargados = [
      for (final x in filas)
        if (x.faltas >= 3) '${x.nombre} (${x.faltas})',
    ];
    if (cargados.isNotEmpty) mal.add('Cargados de faltas: ${cargados.join(', ')}.');
    final cansados = [
      for (final x in filas)
        if (x.enCancha && x.energia < 62) '${x.nombre} ${x.energia.round()} %',
    ];
    if (cansados.isNotEmpty) mal.add('Cansados: ${cansados.join(', ')}.');
    if (bien.isEmpty) bien.add('Marcador parejo: nada se rompió.');
    if (mal.isEmpty) mal.add('Nada grave para corregir.');

    final star = _estrella;
    final (org, grande) = _duoPickAndRoll;
    OpcionDecision? q(OpcionDecision? o) => o?.conSegundos(720);
    final defensas = [
      for (final a in [
        AccionTactica.defensaIndividual,
        AccionTactica.zona,
        AccionTactica.presion,
        AccionTactica.cajaYUno,
      ])
        q(_op(a, rival: _figuraRival, recomendada: _recomendadaMedio(a, t3aR, t3R))),
    ];
    return InformeEntretiempo(
      propios: _ptsP,
      rivales: _ptsR,
      filas: filas,
      bien: bien.take(4).toList(),
      mal: mal.take(4).toList(),
      defensas: [for (final o in defensas) ?o],
      ritmos: [
        for (final o in [q(_op(AccionTactica.ritmoAlto)), q(_op(AccionTactica.ritmoBajo))]) ?o,
      ],
      quintetos: [
        for (final o in [q(_op(AccionTactica.quintetoChico)), q(_op(AccionTactica.quintetoGrande))]) ?o,
      ],
      focos: [
        for (final o in [
          q(_op(AccionTactica.focoAislamiento, j: star)),
          q(_op(AccionTactica.focoPickAndRoll, j: org)),
          if (grande != null) q(_op(AccionTactica.focoPickAndRoll, j: grande)),
        ])
          ?o,
      ],
      descansos: [
        for (final j in _cancha.where((j) => _energia(j) < 70 || _linea1(j).fal >= 3))
          ?q(_op(AccionTactica.descansar, j: j)),
      ],
    );
  }

  bool _recomendadaMedio(AccionTactica a, int t3aR, int t3R) {
    final desdeAfuera = t3aR >= 6 && t3R / t3aR >= 0.4;
    return switch (a) {
      AccionTactica.defensaIndividual => desdeAfuera,
      AccionTactica.zona => !desdeAfuera && t3aR >= 6 && t3R / t3aR <= 0.34,
      _ => false,
    };
  }

  /// Aplica los ajustes elegidos en el entretiempo (duran el 3.er cuarto) y la jugada preferida del final.
  void aplicarEntretiempo(List<OpcionDecision> elegidas, {JugadaClave? preferida}) {
    jugadaPreferida = preferida;
    for (final o in elegidas) {
      final reg = RegistroDecision(tipo: TipoDecision.entretiempo, cuarto: 3, reloj: 720);
      registro.add(reg);
      _activar(o.conSegundos(720), reg);
    }
    _hastaT = max(_hastaT, ahora + 60);
  }

  /// Si el usuario dejó una jugada preferida, la pide para esta posesión (devuelve true si lo hizo).
  bool aplicarPreferida() {
    final p = jugadaPreferida;
    if (p == null || !motor.ataqueDelUsuario) return false;
    motor.pedirJugada(p);
    return true;
  }

  // ── pospartido ──

  /// Líneas para el resumen del pospartido: cada decisión tomada y cómo salió (sin precisión falsa).
  List<String> resumen() {
    final lineas = <String>[];
    for (final r in registro) {
      if (r.ignorada) continue;
      final cuando = '${r.cuarto > 4 ? 'OT' : 'Q${r.cuarto}'} ${_tiempo(max(0, r.reloj))}';
      lineas.add('$cuando · ${r.tipo.titulo}: ${r.opcion}${r.aviso == null ? '' : ' → ${r.aviso}'}');
    }
    return lineas;
  }

  /// Suma aproximada de lo que valieron los ajustes que duran un rato (puntos de diferencia).
  int get impactoTotal => registro.fold(0, (a, r) => a + (r.impacto ?? 0));

  int get tomadas => registro.where((r) => !r.ignorada).length;
}
