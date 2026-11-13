import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/motor.dart';
import '../partido/cancha_partido.dart';
import '../../domain/relator.dart';
import '../partido/coreografia.dart';
import '../partido/repeticion.dart';
import '../partido/voz_relator.dart';
import 'pospartido_pantalla.dart';
import '../partido/sonido_partido.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/indicador_forma.dart';
import '../widgets/texto_led.dart';
import '../widgets/haptica.dart';
import '../../domain/premios.dart' show apellido;
import '../../domain/entities/metajuego.dart' show TipoMision;
import '../../domain/misiones.dart';
import '../tema/vestuario.dart';

enum _Panel { jugadores, tiros, partido, relato }

/// Tiro de campo de tu equipo para el mapa: (x, distancia a la línea de fondo) en pies, y si entró.
typedef _Tiro = (Offset, bool);

/// Partido en vivo 2D estilo transmisión (GDD §6): cámara que sigue la jugada, posesiones continuas
/// (subida, pases, tiro con estela, rebote), marcador de TV con reloj corriendo desde 0-0, pausa,
/// intervenciones del entrenador y estadísticas en vivo de tu equipo. Al terminar (o si el usuario
/// sale, que simula lo que falta) llama a [onTerminado] con el motor completo.
class PartidoPantalla extends StatefulWidget {
  const PartidoPantalla({
    super.key,
    required this.motor,
    required this.usuarioLocal,
    required this.franquiciaUsuario,
    required this.identidadLocal,
    required this.identidadVisitante,
    required this.onTerminado,
  });

  final MotorPartido motor;
  final bool usuarioLocal;
  final Franquicia franquiciaUsuario;
  final Franquicia identidadLocal;
  final Franquicia identidadVisitante;
  final ValueChanged<MotorPartido> onTerminado;

  @override
  State<PartidoPantalla> createState() => _PartidoPantallaState();
}

class _PartidoPantallaState extends State<PartidoPantalla> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _c = AnimationController(vsync: this)
    ..addListener(_alAvanzar)
    ..addStatusListener(_alTerminarJugada);
  Coreografia? _coreo;
  var _velocidad = ajustesApp.value.velocidad;
  var _pausado = false;
  var _acelerar = false, _presion = false;
  var _panel = _Panel.jugadores;
  var _marcador = (0, 0);
  var _cuarto = 1;
  var _relojDesde = 720.0, _relojHasta = 720.0;
  var _anotado = false;
  final _relato = <String>[];
  final _posiciones = <String, Offset>{};
  var _balonFin = const Offset(25, 47);
  String? _poseedorFin;
  var _atacaLocal = true;
  var _segundaOportunidad = false;
  var _camara = 47.0;
  Duration? _ultimoCuadro;
  Map<String, LineaEstadistica> _box = {};
  bool _final = false, _registrado = false;

  // Transmisión: zoom y paneo, sonido, carteles.
  final _sonido = SonidoPartido();
  var _silencio = !ajustesApp.value.sonido;
  var _zoom = 1.0, _camaraX = Cancha94.ancho / 2, _tiempo = 0.0;
  var _ultimoPique = -1;
  var _sonoAro = false, _sonoSilbato = false;
  ui.Image? _escudo;

  // Marcador ampliado (foto al final de cada jugada, sin adelantar nada).
  var _faltas = (0, 0), _tiemposMuertos = (5, 5);
  var _clutch = false;
  var _inicio24 = 24.0, _ultimo24 = 24.0;

  // Paneles: mapa de tiros, probabilidad de ganar y parciales.
  final _tiros = <_Tiro>[];
  late final double _ventaja; // puntos de ventaja esperada antes del salto (calidad + localía)
  final _probabilidad = <(double, double)>[];
  var _parciales = (<int>[0], <int>[0]);

  // Relator, jugada clave y lo mejor del partido.
  final _relator = Relator();
  final _voz = VozRelator();
  late final Map<String, Jugador> _jugadores = {
    for (final local in [true, false])
      for (final j in [..._m.enCancha(local), ?_m.enBanco(local), ..._m.reservas(local)]) j.id: j,
  };
  final _destacadas = <Destacada>[];
  var _eligiendoJugada = false, _noPreguntar = false;
  late final Equipaciones _equipaciones = () {
    final (rival, textoRival, ribeteRival) = _coloresRival(
      widget.usuarioLocal ? widget.identidadVisitante : widget.identidadLocal,
    );
    final propio = _camiseta.$1;
    return Equipaciones(
      propio: propio,
      textoPropio: _contraste(propio),
      ribetePropio: _ribete(propio, _camiseta.$2),
      rival: rival,
      textoRival: textoRival,
      ribeteRival: _ribete(rival, ribeteRival),
    );
  }();

  MotorPartido get _m => widget.motor;

  /// Tu camiseta (relleno, ribete): la titular o la elegida en el vestuario.
  late final (Color, Color) _camiseta = () {
    final (primario, secundario) = (
      Color(widget.franquiciaUsuario.colorPrimario),
      Color(widget.franquiciaUsuario.colorSecundario),
    );
    return Vestuario.uniforme(primario, secundario) ?? (primario, secundario);
  }();

  /// Piso, pelota y LED del vestuario (con lo de fábrica, la cancha de siempre).
  late final EstiloCancha _estilo = Vestuario.cancha();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _box = _copiaBox();
    double media(bool local) {
      final js = [..._m.enCancha(local), ?_m.enBanco(local)];
      return js.fold(0.0, (a, j) => a + j.media) / js.length;
    }

    _ventaja = (media(widget.usuarioLocal) - media(!widget.usuarioLocal)) * 1.3 + (widget.usuarioLocal ? 2 : -2);
    _probabilidad.add((0, _probabilidadGanar(0, 0)));
    final perfil = perfilApp.value;
    _m.ventajasUsuario(
      tiemposExtra: perfil.tiene(Ventaja.tiempoMuertoExtra) ? 1 : 0,
      descansoLargo: perfil.tiene(Ventaja.descansoLargo),
    );
    _tiemposMuertos = (_m.tiemposMuertos(true), _m.tiemposMuertos(false));
    _sonido.iniciar().then((_) => _sonido.silencio = _silencio);
    if (ajustesApp.value.vozRelator) _voz.iniciar();
    imagenEscudo(widget.franquiciaUsuario).then((imagen) {
      if (mounted) setState(() => _escudo = imagen);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _proxima());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    _sonido.liberar();
    _voz.liberar();
    super.dispose();
  }

  /// Segundos de juego transcurridos (incluidas las prórrogas).
  double _transcurrido(int cuarto, double reloj) =>
      cuarto <= 4 ? (cuarto - 1) * 720 + (720 - reloj) : 2880 + (cuarto - 5) * 300 + (300 - reloj);

  /// Probabilidad de que gane tu equipo: diferencia actual + ventaja esperada en lo que queda,
  /// con la incertidumbre de un partido de NBA (~12,5 puntos en 48 minutos).
  double _probabilidadGanar(int diferencia, double transcurrido) {
    final queda = transcurrido < 2880 ? (2880 - transcurrido) : max(0.0, 300 - (transcurrido - 2880) % 300);
    final fraccion = queda / 2880;
    final sigma = max(0.6, 12.5 * sqrt(fraccion));
    final z = (diferencia + _ventaja * fraccion) / sigma;
    return 0.5 * (1 + _erf(z / sqrt2));
  }

  static double _erf(double x) {
    // Abramowitz-Stegun 7.1.26.
    final t = 1 / (1 + 0.3275911 * x.abs());
    final y =
        1 -
        (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
    return x >= 0 ? y : -y;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed && !_pausado && !_final) _alternarPausa();
  }

  Map<String, LineaEstadistica> _copiaBox() => {
    for (final e in (widget.usuarioLocal ? _m.boxLocal : _m.boxVisitante).entries)
      e.key: LineaEstadistica()..sumar(e.value),
  };

  bool _haciaArriba(bool local) => local == (_cuarto <= 2);

  /// En el final apretado, antes de cada posesión tuya, el partido se frena para que elijas la jugada.
  bool get _hayQuePreguntar => !_noPreguntar && !_final && _m.momentoClutch && _m.ataqueDelUsuario;

  void _elegirJugada(JugadaClave? jugada, {bool noPreguntarMas = false}) {
    if (jugada != null) _m.pedirJugada(jugada);
    setState(() {
      _eligiendoJugada = false;
      _noPreguntar = noPreguntarMas;
    });
    if (!_pausado) _proxima(preguntar: false);
  }

  void _proxima({bool preguntar = true}) {
    if (!mounted || _m.terminado) return;
    if (preguntar && _hayQuePreguntar) {
      setState(() => _eligiendoJugada = true);
      Haptica.media();
      return;
    }
    final e = _m.siguiente();
    final ataca = switch (e.tipo) {
      TipoEvento.tiro || TipoEvento.libres || TipoEvento.perdida || TipoEvento.cambio => e.local,
      _ => widget.usuarioLocal,
    };
    if (e.cuarto != _cuarto) _relojDesde = e.cuarto > 4 ? 300 : 720;
    _cuarto = e.tipo == TipoEvento.finCuarto ? e.cuarto - 1 : e.cuarto;
    _relojHasta = e.tipo == TipoEvento.finCuarto ? 0 : e.reloj;
    final saliente = e.tipo == TipoEvento.cambio ? _jugadores[e.saleId] : null;
    _atacaLocal = ataca;
    final posesion = e.tipo == TipoEvento.tiro || e.tipo == TipoEvento.perdida || e.tipo == TipoEvento.libres;
    if (posesion) _inicio24 = _segundaOportunidad ? 14 : 24;
    switch (e.tipo) {
      case TipoEvento.finCuarto || TipoEvento.finPartido:
        _sonido.chicharra();
      case TipoEvento.tiempoMuerto || TipoEvento.cambio:
        _sonido.silbato();
      case _:
    }
    // El público local alienta "DE-FEN-SA" cuando ataca el visitante en los momentos calientes.
    if (posesion && !e.local && (_m.momentoClutch || Random().nextDouble() < 0.05)) _sonido.canto();
    _ultimoPique = -1;
    _sonoAro = false;
    _sonoSilbato = false;
    _coreo = Coreografia(
      evento: e,
      atacantes: List.of(_m.enCancha(ataca)),
      defensores: List.of(_m.enCancha(!ataca)),
      haciaArriba: _haciaArriba(ataca),
      desde: Map.of(_posiciones),
      balonDesde: _balonFin,
      poseedorDesde: _poseedorFin,
      segundaOportunidad: _segundaOportunidad,
      saliente: saliente,
    );
    _anotado = false;
    final reducido = MediaQuery.disableAnimationsOf(context);
    _c.duration = Duration(milliseconds: reducido ? 300 : (_coreo!.duracion * 1000 / _velocidad).round());
    _c.forward(from: 0);
  }

  void _alAvanzar() {
    final coreo = _coreo;
    if (coreo == null) return;
    // Marcador y "+N" en el momento en que entra la pelota.
    final e = coreo.evento;
    final t = _c.value;
    if (!_anotado && e.puntos > 0 && t >= coreo.momentoCanasta) {
      _anotado = true;
      setState(() => _marcador = (e.marcadorLocal, e.marcadorVisitante));
      if (e.local == widget.usuarioLocal) Haptica.ligera();
      e.volcada ? _sonido.golpe() : _sonido.red();
      // El público de local estalla con las jugadas grandes de su equipo y abuchea las del visitante.
      final grande = e.triple || e.volcada || e.texto.contains('Sangre fría') || e.contraataque;
      if (grande && e.local) _sonido.ovacion();
      if (grande && !e.local && Random().nextBool()) _sonido.abucheo();
    }
    final golpe = coreo.momentoAro, silbato = coreo.momentoSilbato;
    if (!_sonoAro && golpe != null && t >= golpe) {
      _sonoAro = true;
      _sonido.aro();
    }
    if (!_sonoSilbato && silbato != null && t >= silbato) {
      _sonoSilbato = true;
      _sonido.silbato();
    }
    final pique = coreo.pique(t);
    if (pique >= 0 && pique != _ultimoPique) _sonido.pique();
    _ultimoPique = pique;
    // Cámara: sigue al balón con suavidad (resorte crítico).
    final ahora = _c.lastElapsedDuration ?? Duration.zero;
    final dt = _ultimoCuadro == null ? 0.016 : max(0, (ahora - _ultimoCuadro!).inMicroseconds) / 1e6;
    _ultimoCuadro = ahora;
    _tiempo += dt;
    final objetivo = coreo.foco(t);
    _camara += (objetivo - _camara) * (1 - exp(-dt * 3.5));
    // Zoom de transmisión: se acerca en el ataque armado y se abre en las transiciones.
    final reducido = MediaQuery.disableAnimationsOf(context) || ajustesApp.value.efectosReducidos;
    final zoom = reducido ? 1.0 : coreo.zoom(t);
    _zoom += (zoom - _zoom) * (1 - exp(-dt * 1.8));
    _camaraX +=
        (Cancha94.ancho / 2 + (coreo.balon(t).$1.dx - Cancha94.ancho / 2) * 0.7 - _camaraX) * (1 - exp(-dt * 3));
  }

  void _alTerminarJugada(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _ultimoCuadro = null;
    final coreo = _coreo!;
    final e = coreo.evento;
    for (final (id, pos, _, _) in _fichas(coreo, 1)) {
      _posiciones[id] = pos;
    }
    final (balon, _, poseedor) = coreo.balon(1);
    _balonFin = balon;
    _poseedorFin = poseedor;
    _segundaOportunidad = e.tipo == TipoEvento.tiro && e.reboteOfensivo;
    if (coreo.puntoTiro case final punto? when e.local == widget.usuarioLocal) {
      final arriba = coreo.haciaArriba;
      _tiros.add((
        Offset(arriba ? punto.dx : Cancha94.ancho - punto.dx, arriba ? punto.dy : Cancha94.largo - punto.dy),
        e.convertido,
      ));
    }
    final propio = widget.usuarioLocal;
    final diferencia = propio ? e.marcadorLocal - e.marcadorVisitante : e.marcadorVisitante - e.marcadorLocal;
    final transcurrido = _transcurrido(_cuarto, _relojHasta);
    _probabilidad.add((
      transcurrido,
      e.tipo == TipoEvento.finPartido ? (diferencia > 0 ? 1.0 : 0.0) : _probabilidadGanar(diferencia, transcurrido),
    ));
    if (e.tipo == TipoEvento.tiro || e.tipo == TipoEvento.perdida || e.tipo == TipoEvento.libres) {
      _ultimo24 = max(0, _inicio24 - (_relojDesde - _relojHasta));
    }
    setState(() {
      _marcador = (e.marcadorLocal, e.marcadorVisitante);
      _faltas = (_m.faltas(true), _m.faltas(false));
      _tiemposMuertos = (_m.tiemposMuertos(true), _m.tiemposMuertos(false));
      _clutch = _m.momentoClutch && !_m.terminado;
      _parciales = (List.of(_m.parcialesLocal), List.of(_m.parcialesVisitante));
      _relojDesde = _relojHasta;
      final frase = _relator.frase(e, _jugadores);
      _relato.insert(0, frase);
      if (_relato.length > 40) _relato.removeLast();
      if (ajustesApp.value.vozRelator && !_silencio) {
        _voz.decir(frase, prioridad: e.volcada || e.triple || e.taponado || e.tipo == TipoEvento.finPartido);
      }
      // Lo mejor del partido, para el resumen.
      final valor = Destacada.valor(e, clutch: _m.momentoClutch);
      if (valor >= 3) {
        _destacadas.add(
          Destacada(
            coreo: coreo,
            frase: frase,
            puntaje: valor,
            atacaLocal: _atacaLocal,
            cuarto: _cuarto,
            reloj: _relojHasta,
          ),
        );
        _destacadas.sort((a, b) => b.puntaje.compareTo(a.puntaje));
        if (_destacadas.length > 3) _destacadas.removeLast();
      }
      _box = _copiaBox();
    });
    if (e.tipo == TipoEvento.finPartido) {
      _terminar();
    } else if (!_pausado) {
      _proxima();
    }
  }

  /// Saltar a lo importante: juega al instante (sin dibujar) hasta el último cuarto o hasta el
  /// próximo final apretado, y sigue en vivo desde ahí.
  void _saltar({required bool hastaClutch}) {
    if (_final || _m.terminado) return;
    _c.stop();
    var ultimo = _coreo?.evento;
    bool llegamos() => hastaClutch ? _m.momentoClutch : _m.cuarto >= 4;
    var guardas = 0;
    while (!_m.terminado && !llegamos() && guardas++ < 2000) {
      final e = _m.siguiente();
      ultimo = e;
      if (e.tipo != TipoEvento.finCuarto) _cuarto = e.cuarto;
      _relato.insert(0, _relator.frase(e, _jugadores));
      final propio = widget.usuarioLocal;
      final dif = propio ? e.marcadorLocal - e.marcadorVisitante : e.marcadorVisitante - e.marcadorLocal;
      final transcurrido = _transcurrido(e.cuarto, e.reloj);
      _probabilidad.add((transcurrido, _m.terminado ? (dif > 0 ? 1.0 : 0.0) : _probabilidadGanar(dif, transcurrido)));
    }
    if (_relato.length > 40) _relato.removeRange(40, _relato.length);
    // La jugada en vivo arranca de cero: todos a su lugar y la pelota en el medio.
    _posiciones.clear();
    _balonFin = const Offset(25, 47);
    _poseedorFin = null;
    _segundaOportunidad = false;
    _coreo = null;
    setState(() {
      if (ultimo case final e?) _marcador = (e.marcadorLocal, e.marcadorVisitante);
      _cuarto = _m.cuarto;
      _relojDesde = _relojHasta = _m.reloj;
      _faltas = (_m.faltas(true), _m.faltas(false));
      _tiemposMuertos = (_m.tiemposMuertos(true), _m.tiemposMuertos(false));
      _clutch = _m.momentoClutch && !_m.terminado;
      _parciales = (List.of(_m.parcialesLocal), List.of(_m.parcialesVisitante));
      _box = _copiaBox();
    });
    if (_m.terminado) {
      _terminar();
    } else if (!_pausado) {
      _proxima();
    }
  }

  /// Orden cronológico de las jugadas destacadas.
  double _orden(Destacada d) => _transcurrido(d.cuarto, d.reloj);

  void _alternarPausa() {
    setState(() => _pausado = !_pausado);
    _pausado ? _sonido.pausar() : _sonido.reanudar();
    if (_pausado) _voz.callar();
    if (_pausado) {
      _c.stop();
    } else if (_c.isCompleted || _coreo == null) {
      _proxima();
    } else {
      _ultimoCuadro = null;
      _c.forward();
    }
  }

  void _cambiarVelocidad(int v) {
    final avance = _c.value;
    setState(() => _velocidad = v);
    final coreo = _coreo;
    if (coreo == null || MediaQuery.disableAnimationsOf(context)) return;
    _c.duration = Duration(milliseconds: (coreo.duracion * 1000 / v).round());
    if (_c.isAnimating) _c.forward(from: avance);
  }

  void _terminar() {
    if (_registrado) return;
    _registrado = true;
    Misiones.anotar(TipoMision.jugarEnVivo);
    widget.onTerminado(_m);
    setState(() => _final = true);
    _sonido.chicharra();
    Haptica.fuerte();
  }

  Future<void> _salir() async {
    if (_final) {
      Navigator.of(context).pop();
      return;
    }
    final estabaPausado = _pausado;
    if (!estabaPausado) _alternarPausa();
    final salir = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir del partido?'),
        content: const Text('Lo que falta se simula al instante, con el resultado que salga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir mirando')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simular y salir')),
        ],
      ),
    );
    if (!mounted) return;
    if (salir != true) {
      if (!estabaPausado) _alternarPausa();
      return;
    }
    _c.stop();
    _m.simularTodo();
    _terminar();
    if (mounted) Navigator.of(context).pop();
  }

  /// Las 10 fichas (y el que sale en un cambio) en el instante t: (id, posición, local, opacidad).
  List<(String, Offset, bool, double)> _fichas(Coreografia coreo, double t) => [
    for (final j in coreo.atacantes) (j.id, coreo.posicion(j.id, t), _atacaLocal, 1.0),
    for (final j in coreo.defensores) (j.id, coreo.posicion(j.id, t), !_atacaLocal, 1.0),
    if (coreo.salienteEn(t) case (final p, final opacidad)) (coreo.saliente!.id, p, coreo.evento.local, opacidad),
  ];

  Color _contraste(Color c) => c.computeLuminance() > 0.4 ? Colors.black : Colors.white;

  /// Camiseta del rival: (color, número, ribete), que no se confunda con la tuya.
  (Color, Color, Color) _coloresRival(Franquicia rival) {
    final propio = _camiseta.$1;
    double distancia(Color a, Color b) => (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
    var color = Color(rival.colorPrimario);
    var ribete = Color(rival.colorSecundario);
    if (distancia(color, propio) < 0.35) (color, ribete) = (Color(rival.colorSecundario), Color(rival.colorPrimario));
    if (distancia(color, propio) < 0.35) color = propio.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    return (color, _contraste(color), ribete);
  }

  /// Ribete que se vea sobre la camiseta (si es casi igual al color de fondo, va blanco o negro).
  Color _ribete(Color fondo, Color ribete) {
    final diferencia = (fondo.computeLuminance() - ribete.computeLuminance()).abs();
    return diferencia < 0.08 ? _contraste(fondo) : ribete;
  }

  /// Texto de los carteles LED de los costados según el momento.
  String _cartel(Coreografia? coreo, double t) {
    final nombre = widget.franquiciaUsuario.nombre.toUpperCase();
    if (coreo == null) return '$nombre · DINASTÍA 82-0';
    final e = coreo.evento;
    if (e.puntos > 0 && e.triple && t >= coreo.momentoCanasta) return '¡TRIPLE!';
    if (_clutch) return 'CLUTCH';
    if (e.tipo == TipoEvento.tiro || e.tipo == TipoEvento.perdida || e.tipo == TipoEvento.libres) {
      if (e.local != widget.usuarioLocal) return 'DE-FEN-SA';
    }
    return '$nombre · DINASTÍA 82-0';
  }

  String _apellido(Jugador j) => apellido(j).toUpperCase();

  /// Teléfono: cancha arriba, controles y panel abajo. Tablet apaisada: cancha a la izquierda (a
  /// toda la altura) y controles + panel a la derecha, sin scroll.
  Widget _disponer({required Widget cancha, required Widget controles, required Widget panel}) {
    if (!esTabletApaisada(context)) {
      return Column(
        children: [
          Expanded(child: cancha),
          controles,
          SizedBox(height: 236, child: panel),
        ],
      );
    }
    // La cancha escala por el ancho: angosta para que entre casi toda a lo alto (como en el
    // teléfono). A la derecha, el panel elegido y, abajo, el partido (o el relato) siempre a la vista.
    final abajo = _panel == _Panel.partido
        ? _RelatoCompleto(lineas: _relato)
        : _PanelPartido(
            probabilidad: _probabilidad,
            parciales: _parciales,
            local: widget.identidadLocal,
            visitante: widget.identidadVisitante,
            usuarioLocal: widget.usuarioLocal,
          );
    return LayoutBuilder(
      builder: (context, c) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: min(c.maxWidth * 0.5, c.maxHeight * 0.64), child: cancha),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 8),
                controles,
                const SizedBox(height: 4),
                Expanded(flex: 5, child: panel),
                const Divider(height: 1),
                Expanded(flex: 4, child: abajo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final usuarioLocal = widget.usuarioLocal;
    final (colorRival, textoRival, ribeteRival) = _coloresRival(
      usuarioLocal ? widget.identidadVisitante : widget.identidadLocal,
    );
    final colorPropio = _camiseta.$1;
    final ribetePropio = _ribete(colorPropio, _camiseta.$2);
    final ribeteDelRival = _ribete(colorRival, ribeteRival);
    final energias = {..._m.energias(true), ..._m.energias(false)};
    final todos = {
      for (final local in [true, false]) ...{
        for (final j in [..._m.enCancha(local), ?_m.enBanco(local), ..._m.reservas(local)]) j.id: j,
      },
    };
    final banner = switch (_coreo?.evento.tipo) {
      TipoEvento.tiempoMuerto => 'TIEMPO MUERTO',
      TipoEvento.finCuarto => _coreo!.evento.texto.toUpperCase(),
      TipoEvento.cambio => 'CAMBIO · ENTRA ${_apellido(todos[_coreo!.evento.entraId]!)}',
      _ => null,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: esquema.surfaceContainerLowest,
        body: SafeArea(
          child: Stack(
            children: [
              _disponer(
                cancha: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: _final ? null : _alternarPausa,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) {
                          final coreo = _coreo;
                          if (coreo == null) {
                            return CustomPaint(
                              painter: CanchaPartidoPainter(
                                franquicia: widget.franquiciaUsuario,
                                fichas: const [],
                                balon: const Offset(25, 47),
                                camaraY: _camara,
                                colorLed: Vestuario.led() ?? esquema.primary,
                                estilo: _estilo,
                                escudo: _escudo,
                                cartel: _cartel(null, 0),
                              ),
                            );
                          }
                          final t = _c.value;
                          final (balon, altura, poseedor) = coreo.balon(t);
                          final e = coreo.evento;
                          EfectoAro? efectoAro;
                          if (e.puntos > 0 && e.tipo == TipoEvento.tiro && t >= coreo.momentoCanasta) {
                            efectoAro = EfectoAro(
                              arriba: coreo.haciaArriba,
                              progreso: ((t - coreo.momentoCanasta) * coreo.duracion / 0.9).clamp(0, 1),
                              adentro: true,
                              fuerte: e.volcada,
                            );
                          } else if (coreo.momentoAro case final m? when t >= m) {
                            efectoAro = EfectoAro(
                              arriba: coreo.haciaArriba,
                              progreso: ((t - m) * coreo.duracion / 0.7).clamp(0, 1),
                              adentro: false,
                            );
                          }
                          final estela = [
                            if (coreo.enTiro(t))
                              for (var k = 1; k <= 7; k++) coreo.balon(max(0, t - k * 0.012)).$1,
                          ];
                          return CustomPaint(
                            painter: CanchaPartidoPainter(
                              franquicia: widget.franquiciaUsuario,
                              colorLed: Vestuario.led() ?? esquema.primary,
                              estilo: _estilo,
                              camaraY: _camara,
                              camaraX: _camaraX,
                              zoom: _zoom,
                              escudo: _escudo,
                              cartel: _cartel(coreo, t),
                              tiempo: _tiempo,
                              efectoAro: efectoAro,
                              margenArriba: 78,
                              margenAbajo: 50,
                              balon: balon,
                              alturaBalon: altura,
                              estela: estela,
                              tanto: e.puntos > 0 && t >= coreo.momentoCanasta
                                  ? Tanto(
                                      '+${e.puntos}',
                                      coreo.aro,
                                      ((t - coreo.momentoCanasta) / (1 - coreo.momentoCanasta + 0.0001)).clamp(0, 1),
                                    )
                                  : null,
                              fichas: [
                                for (final (id, p, local, opacidad) in _fichas(coreo, t))
                                  Ficha(
                                    posicion: p,
                                    relleno: local == usuarioLocal ? colorPropio : colorRival,
                                    texto: local == usuarioLocal ? _contraste(colorPropio) : textoRival,
                                    ribete: local == usuarioLocal ? ribetePropio : ribeteDelRival,
                                    energia: (energias[id] ?? 100) / 100,
                                    etiqueta: todos[id]!.dorsal > 0 ? '${todos[id]!.dorsal}' : todos[id]!.iniciales,
                                    conBalon: poseedor == id,
                                    nombre: poseedor == id ? _apellido(todos[id]!) : null,
                                    opacidad: opacidad,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) {
                          final reloj = _relojDesde + (_relojHasta - _relojDesde) * _c.value;
                          final tipo = _coreo?.evento.tipo;
                          final posesion =
                              tipo == TipoEvento.tiro || tipo == TipoEvento.perdida || tipo == TipoEvento.libres;
                          return _MarcadorTV(
                            local: widget.identidadLocal,
                            visitante: widget.identidadVisitante,
                            puntos: _marcador,
                            cuarto: _cuarto,
                            reloj: reloj,
                            posesion: posesion ? max(0, _inicio24 - (_relojDesde - reloj)) : _ultimo24,
                            faltas: _faltas,
                            tiemposMuertos: _tiemposMuertos,
                            clutch: _clutch,
                            onSalir: _salir,
                          );
                        },
                      ),
                    ),
                    if (banner != null) Center(child: _Banner(texto: banner)),
                    if (_eligiendoJugada && !_final)
                      Positioned.fill(
                        child: _SelectorJugada(
                          marcador: _marcador,
                          usuarioLocal: usuarioLocal,
                          reloj: _relojDesde,
                          onElegir: _elegirJugada,
                        ),
                      ),
                    if (_relato.isNotEmpty)
                      Positioned(left: 12, right: 12, bottom: 10, child: _Zocalo(texto: _relato.first)),
                    if (_pausado && !_final)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _alternarPausa,
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _Banner(texto: 'PAUSA'),
                                  const SizedBox(height: 8),
                                  Text('Tocá para seguir', style: TextStyle(color: esquema.onSurface)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                controles: _Controles(
                  pausado: _pausado,
                  onPausa: _final ? null : _alternarPausa,
                  silencio: _silencio,
                  onSaltar: _final || _m.terminado ? null : (hastaClutch) => _saltar(hastaClutch: hastaClutch),
                  puedeSaltarCuarto: _cuarto < 4,
                  onSilencio: () {
                    setState(() => _silencio = !_silencio);
                    _sonido.silencio = _silencio;
                  },
                  velocidad: _velocidad,
                  onVelocidad: _cambiarVelocidad,
                  tiemposMuertos: _m.tiemposMuertos(usuarioLocal),
                  onTiempoMuerto: _final
                      ? null
                      : () {
                          if (_m.pedirTiempoMuerto(usuarioLocal)) Haptica.media();
                          setState(() {});
                        },
                  acelerar: _acelerar,
                  onAcelerar: (v) {
                    _m.acelerarRitmo(usuarioLocal, v);
                    setState(() => _acelerar = v);
                  },
                  presion: _presion,
                  onPresion: (v) {
                    _m.presionAlta(usuarioLocal, v);
                    setState(() => _presion = v);
                  },
                ),
                panel: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SegmentedButton<_Panel>(
                        segments: const [
                          ButtonSegment(value: _Panel.jugadores, label: Text('Equipo')),
                          ButtonSegment(value: _Panel.tiros, label: Text('Tiros')),
                          ButtonSegment(value: _Panel.partido, label: Text('Partido')),
                          ButtonSegment(value: _Panel.relato, label: Text('Relato')),
                        ],
                        selected: {_panel},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() => _panel = s.first),
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      ),
                    ),
                    Expanded(
                      child: switch (_panel) {
                        _Panel.jugadores => _EstadisticasVivo(
                          jugadores: [
                            ..._m.enCancha(usuarioLocal),
                            ?_m.enBanco(usuarioLocal),
                            ..._m.reservas(usuarioLocal),
                          ],
                          enCancha: {for (final j in _m.enCancha(usuarioLocal)) j.id},
                          box: _box,
                          energia: _m.energias(usuarioLocal),
                          forma: _m.forma,
                          rotacionAuto: _m.esRotacionAutomatica(usuarioLocal),
                          onRotacion: _final ? null : (v) => setState(() => _m.rotacionAutomatica(usuarioLocal, v)),
                          minutosBanco: _m.nivelMinutosBanco(usuarioLocal),
                          onMinutos: (v) => setState(() => _m.minutosDelBanco(usuarioLocal, v)),
                          onSentar: _final
                              ? null
                              : (id) {
                                  if (_m.cambiar(usuarioLocal, id)) Haptica.ligera();
                                  setState(() {});
                                },
                          pendiente: _m.cambioPendiente(usuarioLocal),
                          expulsados: {
                            for (final j in _jugadores.values)
                              if (_m.expulsado(j.id)) j.id,
                          },
                        ),
                        _Panel.tiros => _MapaTiros(tiros: _tiros, box: _box),
                        _Panel.partido => _PanelPartido(
                          probabilidad: _probabilidad,
                          parciales: _parciales,
                          local: widget.identidadLocal,
                          visitante: widget.identidadVisitante,
                          usuarioLocal: usuarioLocal,
                        ),
                        _Panel.relato => _RelatoCompleto(lineas: _relato),
                      },
                    ),
                  ],
                ),
              ),
              if (_final)
                Positioned.fill(
                  child: _Final(
                    marcador: _marcador,
                    usuarioLocal: usuarioLocal,
                    local: widget.identidadLocal,
                    visitante: widget.identidadVisitante,
                    onContinuar: () => Navigator.of(context).pop(),
                    onResumen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PospartidoPantalla(
                          motor: _m,
                          usuarioLocal: widget.usuarioLocal,
                          identidadLocal: widget.identidadLocal,
                          identidadVisitante: widget.identidadVisitante,
                          franquiciaUsuario: widget.franquiciaUsuario,
                          jugadores: _jugadores,
                          destacadas: List.of(_destacadas)..sort((a, b) => _orden(a).compareTo(_orden(b))),
                          equipaciones: _equipaciones,
                          escudo: _escudo,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marcador estilo transmisión, sobre la cancha.
class _MarcadorTV extends StatelessWidget {
  const _MarcadorTV({
    required this.local,
    required this.visitante,
    required this.puntos,
    required this.cuarto,
    required this.reloj,
    required this.posesion,
    required this.faltas,
    required this.tiemposMuertos,
    required this.clutch,
    required this.onSalir,
  });

  final Franquicia local, visitante;
  final (int, int) puntos;
  final int cuarto;
  final double reloj;

  /// Reloj de posesión (24 segundos).
  final double posesion;
  final (int, int) faltas, tiemposMuertos;
  final bool clutch;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final r = max(0.0, reloj);
    final minutos = r ~/ 60, segundos = (r % 60).floor();
    final periodo = cuarto > 4 ? 'OT${cuarto > 5 ? cuarto - 4 : ''}' : 'Q$cuarto';
    Widget equipo(Franquicia f, int pts, bool derecha) {
      final color = Color(f.colorPrimario);
      return Expanded(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withValues(alpha: 0.55), esquema.surfaceContainerLowest),
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(derecha ? 0 : 10),
              right: Radius.circular(derecha ? 10 : 0),
            ),
          ),
          child: Row(
            textDirection: derecha ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Escudo(f, tamano: 28),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  f.id,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontFamily: Fuentes.estadio,
                    fontVariations: [FontVariation.weight(800)],
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TextoLed('$pts', tamano: 28, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Debajo de cada equipo: tiempos muertos que le quedan (puntitos) y faltas del cuarto.
    Widget detalle(int tm, int f, bool derecha) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          textDirection: derecha ? TextDirection.rtl : TextDirection.ltr,
          children: [
            for (var k = 0; k < 5; k++)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: k < tm ? Colors.white : Colors.white.withValues(alpha: 0.18),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: derecha ? Alignment.centerLeft : Alignment.centerRight,
                child: Text(
                  f >= 5 ? 'BONUS' : 'FALTAS $f',
                  style: TextStyle(
                    fontFamily: Fuentes.estadio,
                    fontVariations: const [FontVariation.weight(700)],
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: f >= 5 ? const Color(0xFFFFB020) : Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final p24 = posesion.ceil().clamp(0, 24);
    return Semantics(
      label:
          '${local.nombre} ${puntos.$1}, ${visitante.nombre} ${puntos.$2}, $periodo, $minutos minutos $segundos segundos'
          '${clutch ? ', momento clutch' : ''}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Material(
                  color: esquema.surfaceContainerLowest.withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  child: IconButton(onPressed: onSalir, icon: const Icon(Icons.close), tooltip: 'Salir del partido'),
                ),
                const SizedBox(width: 6),
                equipo(local, puntos.$1, false),
                Container(
                  height: 44,
                  width: 74,
                  color: esquema.surfaceContainerLowest,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: FittedBox(
                    child: Column(
                      children: [
                        TextoLed(periodo, tamano: 12, color: esquema.onSurfaceVariant),
                        TextoLed('$minutos:${'$segundos'.padLeft(2, '0')}', tamano: 19),
                      ],
                    ),
                  ),
                ),
                equipo(visitante, puntos.$2, true),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 54),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: esquema.surfaceContainerLowest.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        detalle(tiemposMuertos.$1, faltas.$1, false),
                        SizedBox(
                          width: 74,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextoLed('$p24', tamano: 14, color: p24 <= 5 ? esquema.error : const Color(0xFFFFB020)),
                                if (clutch) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    'CLUTCH',
                                    style: TextStyle(
                                      fontFamily: Fuentes.estadio,
                                      fontVariations: const [FontVariation.weight(800)],
                                      fontSize: 11,
                                      color: esquema.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        detalle(tiemposMuertos.$2, faltas.$2, true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Jugada clave en el final apretado: aislamiento, pick & roll o triple (o que juegue el equipo).
class _SelectorJugada extends StatefulWidget {
  const _SelectorJugada({
    required this.marcador,
    required this.usuarioLocal,
    required this.reloj,
    required this.onElegir,
  });

  final (int, int) marcador;
  final bool usuarioLocal;
  final double reloj;
  final void Function(JugadaClave?, {bool noPreguntarMas}) onElegir;

  @override
  State<_SelectorJugada> createState() => _SelectorJugadaState();
}

class _SelectorJugadaState extends State<_SelectorJugada> {
  var _noPreguntar = false;

  static IconData _icono(JugadaClave j) => switch (j) {
    JugadaClave.aislamiento => Icons.person,
    JugadaClave.pickAndRoll => Icons.swap_calls,
    JugadaClave.triple => Icons.filter_3,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final propios = widget.usuarioLocal ? widget.marcador.$1 : widget.marcador.$2;
    final rivales = widget.usuarioLocal ? widget.marcador.$2 : widget.marcador.$1;
    final dif = propios - rivales;
    final r = max(0.0, widget.reloj);
    final situacion = dif == 0 ? 'EMPATADOS' : (dif > 0 ? 'ARRIBA POR $dif' : 'ABAJO POR ${-dif}');
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: esquema.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: esquema.primary, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('JUGADA CLAVE', style: tema.textTheme.headlineSmall),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextoLed('${r ~/ 60}:${(r % 60).floor().toString().padLeft(2, '0')}', tamano: 20),
                    ],
                  ),
                  Text(situacion, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
                  const SizedBox(height: 12),
                  for (final j in JugadaClave.values) ...[
                    OutlinedButton(
                      onPressed: () => widget.onElegir(j, noPreguntarMas: _noPreguntar),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Row(
                        children: [
                          Icon(_icono(j)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(j.nombre.toUpperCase()),
                                Text(
                                  j.descripcion,
                                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton(
                    onPressed: () => widget.onElegir(null, noPreguntarMas: _noPreguntar),
                    child: const Text('QUE JUEGUE EL EQUIPO'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _noPreguntar,
                    onChanged: (v) => setState(() => _noPreguntar = v ?? false),
                    title: const Text('No preguntar más en este partido'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zócalo inferior con la última jugada, como en la tele.
class _Zocalo extends StatelessWidget {
  const _Zocalo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(texto),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerLowest.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: esquema.primary, width: 1)),
        ),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: esquema.onSurface, fontSize: 13),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: esquema.primary, width: 1.5),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: const [FontVariation.weight(800)],
          fontSize: 22,
          letterSpacing: 1.5,
          color: esquema.onSurface,
        ),
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.pausado,
    required this.onPausa,
    required this.silencio,
    required this.onSilencio,
    this.onSaltar,
    this.puedeSaltarCuarto = true,
    required this.velocidad,
    required this.onVelocidad,
    required this.tiemposMuertos,
    required this.onTiempoMuerto,
    required this.acelerar,
    required this.onAcelerar,
    required this.presion,
    required this.onPresion,
  });

  final bool pausado;
  final VoidCallback? onPausa;
  final bool silencio;
  final VoidCallback onSilencio;

  /// Saltar a lo importante (true: hasta el próximo final apretado; false: hasta el 4.º cuarto).
  final ValueChanged<bool>? onSaltar;
  final bool puedeSaltarCuarto;
  final int velocidad;
  final ValueChanged<int> onVelocidad;
  final int tiemposMuertos;
  final VoidCallback? onTiempoMuerto;
  final bool acelerar, presion;
  final ValueChanged<bool> onAcelerar, onPresion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
    child: Column(
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: onPausa,
              icon: Icon(pausado ? Icons.play_arrow : Icons.pause),
              tooltip: pausado ? 'Seguir' : 'Pausa',
            ),
            const SizedBox(width: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('x1')),
                ButtonSegment(value: 2, label: Text('x2')),
                ButtonSegment(value: 4, label: Text('x4')),
              ],
              selected: {velocidad},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onVelocidad(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: tiemposMuertos > 0 ? onTiempoMuerto : null,
                child: FittedBox(child: Text('TIEMPO MUERTO · $tiemposMuertos')),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(label: const Text('Acelerar ritmo'), selected: acelerar, onSelected: onAcelerar),
                  FilterChip(label: const Text('Presión alta'), selected: presion, onSelected: onPresion),
                ],
              ),
            ),
            if (onSaltar != null)
              PopupMenuButton<bool>(
                tooltip: 'Saltar a lo importante',
                icon: const Icon(Icons.fast_forward),
                onSelected: onSaltar,
                itemBuilder: (_) => [
                  if (puedeSaltarCuarto) const PopupMenuItem(value: false, child: Text('Saltar al último cuarto')),
                  const PopupMenuItem(value: true, child: Text('Saltar al próximo final apretado')),
                ],
              ),
            IconButton(
              onPressed: onSilencio,
              icon: Icon(silencio ? Icons.volume_off : Icons.volume_up),
              tooltip: silencio ? 'Activar sonido' : 'Silenciar',
            ),
          ],
        ),
      ],
    ),
  );
}

/// Box score en vivo de tu equipo (se actualiza al terminar cada jugada, sin adelantar resultados).
class _EstadisticasVivo extends StatelessWidget {
  const _EstadisticasVivo({
    required this.jugadores,
    required this.enCancha,
    required this.box,
    required this.energia,
    this.forma = const {},
    this.rotacionAuto = true,
    this.onRotacion,
    this.minutosBanco = 0,
    this.onMinutos,
    this.onSentar,
    this.pendiente,
    this.expulsados = const {},
  });

  final List<Jugador> jugadores;
  final Set<String> enCancha;
  final Map<String, LineaEstadistica> box;
  final Map<String, double> energia;
  final Map<String, int> forma;

  /// Cambios a mano: rotación automática, minutos del Sexto Hombre y "sentar" a un titular.
  final bool rotacionAuto;
  final ValueChanged<bool>? onRotacion;
  final int minutosBanco;
  final ValueChanged<int>? onMinutos;
  final ValueChanged<String>? onSentar;
  final String? pendiente;
  final Set<String> expulsados;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final cabecera = tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant, letterSpacing: 0.5);
    Widget celda(String texto, {TextStyle? estilo, double ancho = 34}) => SizedBox(
      width: ancho,
      child: Text(texto, textAlign: TextAlign.end, style: estilo),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      children: [
        if (onRotacion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Switch(value: rotacionAuto, onChanged: onRotacion),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rotacionAuto
                            ? 'Rotación automática · tocá un titular para sentarlo'
                            : 'Cambios a mano: tocá un titular',
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (rotacionAuto)
                  Row(
                    children: [
                      Expanded(child: Text('Minutos del 6.º hombre', style: tema.textTheme.bodySmall)),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: -1, label: Text('Pocos')),
                          ButtonSegment(value: 0, label: Text('Normal')),
                          ButtonSegment(value: 1, label: Text('Muchos')),
                        ],
                        selected: {minutosBanco},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => onMinutos?.call(v.first),
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(child: Text('JUGADOR', style: cabecera)),
            for (final c in ['MIN', 'PTS', 'REB', 'AST']) celda(c, estilo: cabecera),
            celda('TC', estilo: cabecera, ancho: 46),
            celda('F', estilo: cabecera, ancho: 24),
          ],
        ),
        for (final j in jugadores)
          () {
            final l = box[j.id] ?? LineaEstadistica();
            final juega = enCancha.contains(j.id);
            final valores = TextStyle(
              fontFamily: Fuentes.led,
              fontVariations: const [FontVariation.weight(800)],
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: 15,
              color: juega ? esquema.onSurface : esquema.onSurfaceVariant,
            );
            final puedeSentar = juega && onSentar != null && !expulsados.contains(j.id) && pendiente == null;
            return Semantics(
              button: puedeSentar,
              hint: puedeSentar ? 'Tocá para sentarlo y que entre el Sexto Hombre' : null,
              label:
                  '${j.nombre}${juega ? '' : ', en el banco'}${pendiente == j.id ? ', sale en la próxima jugada' : ''}: '
                  '${l.pts} puntos, ${l.reb} rebotes, ${l.ast} asistencias, ${l.fal} faltas',
              child: InkWell(
                onTap: puedeSentar ? () => onSentar!(j.id) : null,
                borderRadius: BorderRadius.circular(6),
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: juega ? esquema.primary : esquema.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      j.nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tema.textTheme.bodySmall?.copyWith(
                                        color: juega ? esquema.onSurface : esquema.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  IndicadorForma(forma[j.id] ?? 0),
                                  if (pendiente == j.id)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        'SALE',
                                        style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              FractionallySizedBox(
                                widthFactor: 0.7,
                                alignment: Alignment.centerLeft,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: (energia[j.id] ?? 100) / 100,
                                    minHeight: 3,
                                    color: (energia[j.id] ?? 100) < 60 ? esquema.error : esquema.primary,
                                    backgroundColor: esquema.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        celda('${(l.seg / 60).floor()}', estilo: valores),
                        celda('${l.pts}', estilo: valores.copyWith(color: juega ? esquema.primary : null)),
                        celda('${l.reb}', estilo: valores),
                        celda('${l.ast}', estilo: valores),
                        celda('${l.tcI}/${l.tcA}', estilo: valores, ancho: 46),
                        celda(
                          expulsados.contains(j.id) ? 'EXP' : '${l.fal}',
                          estilo: valores.copyWith(color: l.fal >= 5 ? esquema.error : null),
                          ancho: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// Mapa de tiros de tu equipo: media cancha con el aro arriba; lleno = adentro, cruz = errado.
class _MapaTiros extends StatelessWidget {
  const _MapaTiros({required this.tiros, required this.box});

  final List<_Tiro> tiros;
  final Map<String, LineaEstadistica> box;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final total = box.values.fold(LineaEstadistica(), (a, l) => a..sumar(l));
    String pct(int i, int a) => a == 0 ? '–' : '${(100 * i / a).round()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              label: 'Mapa de tiros: ${tiros.where((t) => t.$2).length} adentro de ${tiros.length}',
              child: AspectRatio(
                aspectRatio: 50 / 32,
                child: CustomPaint(
                  painter: _MapaTirosPainter(
                    tiros: tiros,
                    adentro: esquema.primary,
                    errado: esquema.onSurfaceVariant,
                    lineas: esquema.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (sigla, i, a) in [
                ('TC', total.tcI, total.tcA),
                ('T3', total.t3I, total.t3A),
                ('TL', total.tlI, total.tlA),
              ]) ...[
                TextoLed('$i/$a', tamano: 18, color: esquema.onSurface),
                Text(
                  '$sigla · ${pct(i, a)}',
                  style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MapaTirosPainter extends CustomPainter {
  _MapaTirosPainter({required this.tiros, required this.adentro, required this.errado, required this.lineas});

  final List<_Tiro> tiros;
  final Color adentro, errado, lineas;

  @override
  void paint(Canvas canvas, Size size) {
    final pie = size.width / 50;
    Offset p(double x, double y) => Offset(x * pie, y * pie);
    final linea = Paint()
      ..color = lineas
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, linea);
    canvas.drawRect(Rect.fromPoints(p(17, 0), p(33, 19)), linea);
    canvas.drawCircle(p(25, 19), 6 * pie, linea);
    canvas.drawCircle(p(25, 5.25), 0.75 * pie, linea..color = const Color(0xFFF26A1B));
    linea.color = lineas;
    final ang = asin(8.95 / 23.75);
    canvas.drawLine(p(3, 0), p(3, 14.2), linea);
    canvas.drawLine(p(47, 0), p(47, 14.2), linea);
    canvas.drawArc(Rect.fromCircle(center: p(25, 5.25), radius: 23.75 * pie), ang, pi - 2 * ang, false, linea);
    final r = max(2.5, pie * 0.9);
    for (final (punto, entro) in tiros) {
      final c = p(punto.dx, min(punto.dy, 31));
      if (entro) {
        canvas.drawCircle(c, r, Paint()..color = adentro);
      } else {
        final cruz = Paint()
          ..color = errado
          ..strokeWidth = 1.4;
        canvas.drawLine(c - Offset(r, r), c + Offset(r, r), cruz);
        canvas.drawLine(c + Offset(-r, r), c + Offset(r, -r), cruz);
      }
    }
  }

  @override
  bool shouldRepaint(_MapaTirosPainter viejo) => viejo.tiros.length != tiros.length;
}

/// Probabilidad de ganar a lo largo del partido y los parciales por cuarto.
class _PanelPartido extends StatelessWidget {
  const _PanelPartido({
    required this.probabilidad,
    required this.parciales,
    required this.local,
    required this.visitante,
    required this.usuarioLocal,
  });

  final List<(double, double)> probabilidad;
  final (List<int>, List<int>) parciales;
  final Franquicia local, visitante;
  final bool usuarioLocal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final actual = probabilidad.last.$2;
    final numeros = TextStyle(
      fontFamily: Fuentes.led,
      fontVariations: const [FontVariation.weight(800)],
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 14,
      color: esquema.onSurface,
    );
    final periodos = max(4, parciales.$1.length);
    String et(int i) => i < 4 ? '${i + 1}' : 'OT${i > 4 ? i - 3 : ''}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        Row(
          children: [
            Text('Probabilidad de ganar', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
            const Spacer(),
            TextoLed('${(100 * actual).round()}%', tamano: 18),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Probabilidad de ganar: ${(100 * actual).round()} por ciento',
          child: SizedBox(
            height: 70,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ProbabilidadPainter(puntos: probabilidad, linea: esquema.primary, guia: esquema.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {0: FlexColumnWidth(2)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox(),
                for (var i = 0; i < periodos; i++)
                  Text(et(i), textAlign: TextAlign.end, style: tema.textTheme.labelSmall),
                Text('T', textAlign: TextAlign.end, style: tema.textTheme.labelSmall),
              ],
            ),
            for (final (f, ps) in [(local, parciales.$1), (visitante, parciales.$2)])
              TableRow(
                children: [
                  Row(
                    children: [
                      Escudo(f, tamano: 18),
                      const SizedBox(width: 6),
                      Text(f.id, style: tema.textTheme.bodySmall),
                    ],
                  ),
                  for (var i = 0; i < periodos; i++)
                    Text(i < ps.length ? '${ps[i]}' : '–', textAlign: TextAlign.end, style: numeros),
                  Text('${ps.fold(0, (a, b) => a + b)}', textAlign: TextAlign.end, style: numeros),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ProbabilidadPainter extends CustomPainter {
  _ProbabilidadPainter({required this.puntos, required this.linea, required this.guia});

  final List<(double, double)> puntos;
  final Color linea, guia;

  @override
  void paint(Canvas canvas, Size size) {
    final fin = max(2880.0, puntos.last.$1);
    Offset p(double x, double y) => Offset(x / fin * size.width, (1 - y) * size.height);
    final g = Paint()
      ..color = guia
      ..strokeWidth = 1;
    canvas.drawLine(p(0, 0.5), p(fin, 0.5), g);
    for (var q = 1; q < 4; q++) {
      canvas.drawLine(p(q * 720, 0), p(q * 720, 1), g..color = guia.withValues(alpha: 0.4));
    }
    final camino = Path()..moveTo(p(puntos.first.$1, puntos.first.$2).dx, p(0, puntos.first.$2).dy);
    for (final (x, y) in puntos.skip(1)) {
      final punto = p(x, y);
      camino.lineTo(punto.dx, punto.dy);
    }
    canvas.drawPath(
      camino,
      Paint()
        ..color = linea
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(p(puntos.last.$1, puntos.last.$2), 3, Paint()..color = linea);
  }

  @override
  bool shouldRepaint(_ProbabilidadPainter viejo) => viejo.puntos.length != puntos.length;
}

class _RelatoCompleto extends StatelessWidget {
  const _RelatoCompleto({required this.lineas});

  final List<String> lineas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      itemCount: lineas.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          lineas[i],
          style: tema.textTheme.bodySmall?.copyWith(
            color: i == 0 ? tema.colorScheme.onSurface : tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({
    required this.marcador,
    required this.usuarioLocal,
    required this.local,
    required this.visitante,
    required this.onContinuar,
    this.onResumen,
  });

  final (int, int) marcador;
  final bool usuarioLocal;
  final Franquicia local, visitante;
  final VoidCallback onContinuar;
  final VoidCallback? onResumen;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gano = usuarioLocal ? marcador.$1 > marcador.$2 : marcador.$2 > marcador.$1;
    return ColoredBox(
      color: tema.colorScheme.surfaceContainerLowest.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('FINAL', style: tema.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Escudo(local, tamano: 48),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextoLed('${marcador.$1}-${marcador.$2}', tamano: 52),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Escudo(visitante, tamano: 48),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                gano ? '¡VICTORIA!' : 'DERROTA',
                style: tema.textTheme.displayLarge?.copyWith(
                  fontSize: 44,
                  color: gano ? tema.colorScheme.primary : null,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onContinuar, child: const Text('CONTINUAR')),
              if (onResumen != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onResumen,
                  icon: const Icon(Icons.slow_motion_video),
                  label: const Text('RESUMEN Y REPETICIONES'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
