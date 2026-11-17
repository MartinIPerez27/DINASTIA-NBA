import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/catalogo_jugadores.dart';
import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/draft.dart';
import '../../domain/entities/entrenador.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/oferta.dart';
import '../../domain/entities/plantel.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/entities/tirada.dart';
import '../../domain/reto.dart';
import '../../domain/tokens_draft.dart';
import '../../domain/quimica.dart';
import '../../domain/versiones.dart';
import '../draft/bandeja_tokens.dart';
import '../draft/cancha.dart';
import '../draft/hojas_tokens.dart';
import '../draft/entrenadores.dart';
import '../draft/quimica_panel.dart';
import '../draft/revelado_cartas.dart';
import '../draft/sobres.dart';
import '../draft/tragamonedas_panel.dart';
import '../widgets/disposicion.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/ficha_jugador.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';
import '../../domain/entities/franquicia.dart';

/// Draft 82-0 (GDD §4). Modo ruleta: tirar los carretes, elegir una de las cartas que salieron y
/// tocar su puesto. Modo cartas: tocar un puesto, se revelan 5 cartas y se ficha una.
/// Cada cambio se informa con [onCambio] para guardarlo al instante.
class DraftPantalla extends StatefulWidget {
  const DraftPantalla({
    super.key,
    required this.temporada,
    required this.onCambio,
    this.onCompleto,
    this.catalogo,
    this.azar,
    this.azarPara,
    this.onPerfil,
  });

  final Temporada temporada;
  final ValueChanged<Temporada> onCambio;

  /// Con el plantel completo, el botón principal pasa a las tácticas.
  final VoidCallback? onCompleto;

  /// Solo para tests; en la app se carga el catálogo empaquetado.
  final List<Jugador>? catalogo;
  final Random? azar;

  /// Azar de cada paso del draft (retos: el mismo draft para el mismo código). Ver [Draft.azarPara].
  final Random Function(Temporada t, int paso)? azarPara;

  /// Se llama con el perfil nuevo cuando un token gasta monedas (para guardarlo al instante).
  final ValueChanged<PerfilEntrenador>? onPerfil;

  @override
  State<DraftPantalla> createState() => _DraftPantallaState();
}

class _DraftPantallaState extends State<DraftPantalla> {
  late Temporada _t = widget.temporada;
  Draft? _draft;
  Object? _errorCatalogo;
  int _vuelta = 0;
  bool _girando = false;
  Set<Carrete> _retenidos = {};
  Jugador? _elegida;
  Posicion? _ubicada;
  Timer? _finGiro;

  /// Ruleta: filtro de la grilla por puesto (null = todas).
  Posicion? _filtro;
  final _clavesPuestos = {for (final p in Posicion.values) p: GlobalKey()};

  /// Mientras una carta vuela a la cancha, se muestra el plantel de antes (el puesto sigue vacío).
  Plantel? _plantelAntes;

  bool get _modoCartas => _t.modo == ModoDraft.cartas;

  @override
  void initState() {
    super.initState();
    final catalogo = widget.catalogo;
    if (catalogo != null) {
      _draft = _crearDraft(catalogo);
    } else {
      cargarCatalogo().then(
        (c) => mounted ? setState(() => _draft = _crearDraft(c)) : null,
        onError: (Object e) => mounted ? setState(() => _errorCatalogo = e) : null,
      );
    }
  }

  Draft _crearDraft(List<Jugador> catalogo) {
    registrarVersiones(catalogo);
    return Draft(
      catalogo,
      azar: widget.azar,
      azarPara: widget.azarPara,
      coleccion: perfilApp.value.coleccion,
      ventajas: VentajasTokens.de(perfilApp.value),
    );
  }

  /// Química del plantel: líneas en la cancha entre los puestos vinculados.
  List<(Posicion, Posicion, bool)> _lineasQuimica(Plantel plantel) {
    final puestoDe = {for (final p in Posicion.values) ?plantel.en(p)?.id: p};
    return [
      for (final v in Quimica.de(plantel.jugadores).vinculos)
        if (puestoDe[v.a] case final a?)
          if (puestoDe[v.b] case final b?) (a, b, v.tipo == TipoVinculo.duo),
    ];
  }

  Future<void> _elegirEntrenador() async {
    final draft = _draft;
    if (draft == null) return;
    final e = await elegirEntrenador(context, draft.opcionesEntrenador(_t), actual: Entrenador.porId(_t.entrenadorId));
    if (e != null && mounted) setState(() => _guardar(draft.elegirEntrenador(_t, e)));
  }

  void _abrirSobre(int i) {
    Haptica.fuerte();
    setState(() => _guardar(_draft!.abrirSobre(_t, i)));
  }

  @override
  void dispose() {
    _finGiro?.cancel();
    super.dispose();
  }

  void _guardar(Temporada nueva) {
    _t = nueva;
    widget.onCambio(nueva);
  }

  int get _monedas => perfilApp.value.monedas;

  /// Guarda la temporada y, si el paso gastó monedas en tokens, las descuenta del perfil (primero
  /// el perfil: cerrar la app justo en el medio nunca regala un token).
  void _aplicar(Temporada nueva) {
    final gasto = nueva.tokens.gastadas - _t.tokens.gastadas;
    if (gasto > 0) {
      final p = perfilApp.value;
      final nuevo = p.copyWith(monedas: max(0, p.monedas - gasto));
      perfilApp.value = nuevo;
      widget.onPerfil?.call(nuevo);
    }
    _guardar(nueva);
  }

  void _avisar(String texto) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(texto)));

  /// Una acción del dominio que puede rechazar el paso (sin monedas, sin usos…).
  Temporada? _probar(Temporada Function() accion) {
    try {
      return accion();
    } on Object catch (e) {
      _avisar('$e');
      return null;
    }
  }

  /// Aviso de la hoja de pago: pagar tokens saca la partida de los retos por código.
  String? get _avisoReto =>
      Reto.sePuedeRetar(_t) ? 'Ojo: si pagás tokens con monedas, esta partida ya no se podrá retar con código.' : null;

  void _tirar() {
    final nueva = _probar(() => _draft!.tirar(_t, retenidos: _retenidos, monedas: _monedas));
    if (nueva != null) _girarCon(nueva);
  }

  /// Volver a tirar: gratis o con monedas (pide confirmar el gasto).
  Future<void> _volverATirar() async {
    final precio = _draft!.precioDe(_t, TokenDraft.volverATirar) ?? 0;
    if (precio > 0 &&
        !await confirmarGasto(
          context,
          titulo: TokenDraft.volverATirar.nombre,
          detalle: TokenDraft.volverATirar.descripcion,
          precio: precio,
          monedas: _monedas,
          aviso: _avisoReto,
        )) {
      return;
    }
    if (mounted) _tirar();
  }

  void _girarCon(Temporada nueva) {
    final animar = !MediaQuery.disableAnimationsOf(context);
    Haptica.ligera();
    setState(() {
      _aplicar(nueva);
      _vuelta++;
      _girando = animar;
      _elegida = null;
      _ubicada = null;
      _filtro = null;
      if (!animar) _retenidos = {};
    });
    if (animar) {
      _finGiro?.cancel();
      _finGiro = Timer(
        TragamonedasPanel.duracionGiro + const Duration(milliseconds: 150),
        () => setState(() {
          _girando = false;
          _retenidos = {};
        }),
      );
    }
  }

  void _retener(Carrete c) => setState(() {
    if (!_retenidos.remove(c) && _retenidos.length < Draft.maxRetenidos) _retenidos.add(c);
  });

  void _tocarPuesto(Posicion p) {
    if (_modoCartas) {
      if (_t.oferta != null || _plantelAntes != null || !_draft!.puedeRepartir(_t, p)) return;
      Haptica.ligera();
      setState(() {
        _guardar(_draft!.repartir(_t, p));
        _ubicada = null;
      });
      return;
    }
    final elegida = _elegida;
    if (elegida == null) {
      // Sin carta elegida, tocar un puesto libre filtra la grilla por ese puesto.
      if (_t.tirada != null && !_t.plantel.estaOcupada(p)) setState(() => _filtro = _filtro == p ? null : p);
      return;
    }
    if (!_draft!.puestosPara(_t, elegida).contains(p)) return;
    Haptica.fuerte();
    setState(() {
      _guardar(_draft!.elegir(_t, elegida, p));
      _elegida = null;
      _filtro = null;
      _ubicada = p;
    });
  }

  Future<void> _volverARepartir() async {
    final precio = _draft!.precioDe(_t, TokenDraft.volverATirar) ?? 0;
    if (precio > 0 &&
        !await confirmarGasto(
          context,
          titulo: 'Volver a repartir',
          detalle: 'Se reparten tres sobres nuevos para este puesto.',
          precio: precio,
          monedas: _monedas,
          aviso: _avisoReto,
        )) {
      return;
    }
    if (!mounted) return;
    final nueva = _probar(() => _draft!.volverARepartir(_t, monedas: _monedas));
    if (nueva != null) setState(() => _aplicar(nueva));
  }

  // ── Tokens ──

  bool get _hayBandeja => const {ModoTokens.monedas, ModoTokens.kit}.contains(ReglasTokens.modoDe(_t));

  Future<void> _usar(TokenDraft k, {Jugador? deLasCartas}) async {
    final d = _draft;
    if (d == null || _girando) return;
    final estado = d.estadoDe(_t, k, monedas: _monedas);
    final precio = d.precioDe(_t, k);
    if (estado != EstadoToken.gratis && estado != EstadoToken.disponible) {
      _avisar(_motivo(k, estado, precio));
      return;
    }
    switch (k) {
      case TokenDraft.volverATirar:
        if (_modoCartas) return _volverARepartir();
        if (!d.puedeVolverATirar(_t, _retenidos)) {
          return _avisar('No quedan cartas con esos carretes retenidos.');
        }
        return _volverATirar();
      case TokenDraft.mejorVersion:
        return _mejorVersion(_modoCartas ? deLasCartas : _elegida);
      case TokenDraft.doble:
        if (precio! > 0 &&
            !await confirmarGasto(
              context,
              titulo: k.nombre,
              detalle: '${k.descripcion} Se paga al activarlo y no se puede volver a tirar mientras esté activo.',
              precio: precio,
              monedas: _monedas,
              aviso: _avisoReto,
            )) {
          return;
        }
        if (!mounted) return;
        final nueva = _probar(() => d.doble(_t, monedas: _monedas));
        if (nueva != null) setState(() => _aplicar(nueva));
      case TokenDraft.intercambio:
        return _intercambio();
      case TokenDraft.comodin:
        return _comodin();
    }
  }

  Future<void> _mejorVersion(Jugador? j) async {
    final d = _draft!;
    if (j == null) return _avisar('Tocá primero la carta que querés cambiar por su mejor versión.');
    final mejor = d.mejorVersionDe(_t, j);
    if (mejor == null) return _avisar('${j.nombre} ya está en su mejor versión disponible.');
    final ok = await confirmarMejorVersion(
      context,
      actual: j,
      mejor: mejor,
      versiones: d.versionesDe(j).length,
      // Si la mejor del catálogo no cumple la regla del draft, se avisa que esta es la mejor que sí cumple.
      reglaLimita: d.versionesDe(j).first.id != mejor.id && _t.regla != ReglaDraft.libre,
      precio: d.precioDe(_t, TokenDraft.mejorVersion) ?? 0,
      monedas: _monedas,
      aviso: _avisoReto,
    );
    if (!ok || !mounted) return;
    final nueva = _probar(() => d.mejorVersion(_t, j, monedas: _monedas));
    if (nueva != null) {
      setState(() {
        _aplicar(nueva);
        _elegida = null;
      });
    }
  }

  Future<void> _intercambio() async {
    final d = _draft!;
    final elegido = await elegirIntercambio(
      context,
      opciones: d.opcionesIntercambio(_t),
      precioDe: (sale, entra) => d.precioDe(_t, TokenDraft.intercambio, sale: sale, entra: entra) ?? 0,
      monedas: _monedas,
      aviso: _avisoReto,
    );
    if (elegido == null || !mounted) return;
    final (puesto, entra) = elegido;
    final nueva = _probar(() => d.intercambiar(_t, entra, puesto, monedas: _monedas));
    if (nueva != null) {
      Haptica.fuerte();
      setState(() {
        _aplicar(nueva);
        _elegida = null;
        _filtro = null;
        _ubicada = puesto;
      });
    }
  }

  Future<void> _comodin() async {
    final d = _draft!;
    final elegido = await elegirComodin(
      context,
      franquicias: d.franquiciasPosibles(_t),
      epocas: d.epocasPosibles(_t),
      precio: d.precioDe(_t, TokenDraft.comodin) ?? 0,
      monedas: _monedas,
      aviso: _avisoReto,
    );
    if (elegido == null || !mounted) return;
    final (franquiciaId, epoca) = elegido;
    if (_modoCartas) {
      final nueva = _probar(() => d.comodinSobre(_t, franquiciaId: franquiciaId, epoca: epoca, monedas: _monedas));
      if (nueva != null) setState(() => _aplicar(nueva));
      return;
    }
    final nueva = _probar(() => d.comodin(_t, franquiciaId: franquiciaId, epoca: epoca, monedas: _monedas));
    if (nueva != null) {
      _retenidos = {};
      _girarCon(nueva);
    }
  }

  /// Por qué el token no se puede usar ahora.
  String _motivo(TokenDraft k, EstadoToken e, int? precio) => switch (e) {
    EstadoToken.agotado =>
      '${k.nombre}: ya no te quedan usos en este draft${ReglasTokens.modoDe(_t) == ModoTokens.monedas ? ' (o llegaste al tope de ${ReglasTokens.topeGastoPorDraft} monedas en tokens)' : ''}.',
    EstadoToken.caro => 'Te faltan ${(precio ?? 0) - _monedas} monedas para ${k.nombre.toLowerCase()}.',
    _ => switch (k) {
      TokenDraft.volverATirar => _modoCartas ? 'Abrí un sobre primero.' : 'Tirá los carretes primero.',
      TokenDraft.mejorVersion => 'Ninguna carta de esta tirada tiene una versión mejor disponible.',
      TokenDraft.doble => 'El Doble pide una tirada con dos cartas que entren en dos puestos libres.',
      TokenDraft.intercambio => 'Necesitás una carta ya elegida y otra de esta tirada que juegue su mismo puesto.',
      TokenDraft.comodin =>
        _modoCartas ? 'El Comodín se usa con los sobres cerrados.' : 'Ahora no se puede usar el Comodín.',
    },
  };

  Widget? _bandeja(Draft d, {Jugador? elegidaDeLasCartas}) {
    if (!_hayBandeja) return null;
    return BandejaTokens(
      tokens: [
        for (final k in TokenDraft.values)
          if (Draft.trae(_t, k)) k,
      ],
      estado: (k) => d.estadoDe(_t, k, monedas: _monedas),
      precio: (k) => d.precioDe(_t, k),
      usosRestantes: (k) => d.usosRestantes(_t, k),
      onUsar: (k) => _usar(k, deLasCartas: elegidaDeLasCartas),
    );
  }

  String _textoVolver(Draft d, String verbo) {
    final precio = d.precioDe(_t, TokenDraft.volverATirar);
    if (precio == null) {
      return ReglasTokens.modoDe(_t) == ModoTokens.monedas ? 'SIN MÁS TIRADAS' : 'SIN FICHAS DE REROLL';
    }
    return precio == 0 ? '$verbo · GRATIS' : '$verbo · $precio MONEDAS';
  }

  bool _puedeVolver(Draft d) => (d.precioDe(_t, TokenDraft.volverATirar) ?? 1 << 30) <= _monedas;

  /// Se guarda al instante; la carta vuela desde la escena del reparto hasta su puesto.
  void _fichar(Jugador carta, Rect origen) {
    final posicion = _t.oferta!.posicion;
    final antes = _t.plantel;
    final caja = _clavesPuestos[posicion]!.currentContext?.findRenderObject() as RenderBox?;
    setState(() => _guardar(_draft!.fichar(_t, carta)));
    if (MediaQuery.disableAnimationsOf(context) || caja == null) {
      Haptica.fuerte();
      setState(() => _ubicada = posicion);
      return;
    }
    setState(() => _plantelAntes = antes);
    late final OverlayEntry vuelo;
    vuelo = OverlayEntry(
      builder: (_) => _CartaEnVuelo(
        jugador: carta,
        origen: origen,
        destino: caja.localToGlobal(Offset.zero) & caja.size,
        onFin: () {
          vuelo.remove();
          Haptica.fuerte();
          if (mounted) {
            setState(() {
              _plantelAntes = null;
              _ubicada = posicion;
            });
          }
        },
      ),
    );
    Overlay.of(context).insert(vuelo);
  }

  /// Teléfono: cancha arriba, tragamonedas y cartas abajo; los sobres tapan toda la pantalla.
  /// Tablet apaisada: la cancha a la izquierda y el draft (carretes, cartas o sobres) a la derecha.
  Widget _disponer({
    required Draft draft,
    required Widget cancha,
    Widget? tragamonedas,
    Widget? bandeja,
    Widget? overlay,
  }) {
    final grande = !_modoCartas && _t.tirada != null && !_t.plantel.completo;
    if (!esTabletApaisada(context)) {
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: bandeja == null ? 4 : 3,
                  child: Center(child: cancha),
                ),
                const SizedBox(height: 12),
                if (tragamonedas != null) ...[tragamonedas, const SizedBox(height: 8)],
                if (bandeja != null) ...[bandeja, const SizedBox(height: 8)],
                if (grande) Expanded(flex: 5, child: _zonaInferior(draft)) else _zonaInferior(draft),
              ],
            ),
          ),
          if (overlay != null) Positioned.fill(child: overlay),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: Center(child: cancha)),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: grande ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    if (tragamonedas != null) ...[tragamonedas, const SizedBox(height: 8)],
                    if (bandeja != null) ...[bandeja, const SizedBox(height: 8)],
                    if (grande) Expanded(child: _zonaInferior(draft)) else _zonaInferior(draft),
                  ],
                ),
                if (overlay != null) Positioned.fill(child: overlay),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final franquicia = franquiciaPorId(_t.franquiciaUsuarioId);
    final draft = _draft;
    final elegida = _elegida;

    return ValueListenableBuilder<PerfilEntrenador>(
      valueListenable: perfilApp,
      builder: (context, perfil, _) => _construir(context, franquicia, draft, elegida),
    );
  }

  Widget _construir(BuildContext context, Franquicia franquicia, Draft? draft, Jugador? elegida) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Draft de los ${franquicia.nombre}'),
        actions: [
          if (ReglasTokens.modoDe(_t) == ModoTokens.monedas) Monedero(_monedas) else _Fichas(_t.rerollsRestantes),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch ((draft, _errorCatalogo)) {
          (_, final Object e) => Center(child: Text('No se pudo cargar el catálogo: $e')),
          (null, _) => const Center(child: CircularProgressIndicator()),
          (final Draft draft, _) => _disponer(
            draft: draft,
            cancha: Cancha(
              franquicia: franquicia,
              plantel: _plantelAntes ?? _t.plantel,
              resaltadas: _modoCartas
                  ? (_t.oferta == null && _plantelAntes == null
                        ? {
                            for (final p in Posicion.values)
                              if (!_t.plantel.estaOcupada(p)) p,
                          }
                        : const {})
                  : elegida == null
                  ? const {}
                  : draft.puestosPara(_t, elegida).toSet(),
              onTocar: _tocarPuesto,
              recienUbicada: _ubicada,
              clavesPuestos: _clavesPuestos,
              vinculos: _lineasQuimica(_plantelAntes ?? _t.plantel),
            ),
            tragamonedas: !_t.plantel.completo && !_modoCartas
                ? TragamonedasPanel(
                    identidad: draft.identidadDeTirada,
                    tirada: _t.tirada,
                    vuelta: _vuelta,
                    retenidos: _retenidos,
                    puedeRetener:
                        !_girando &&
                        _t.tirada != null &&
                        draft.puedeVolverATirar(_t, const {}) &&
                        _retenidos.length < Draft.maxRetenidos,
                    onRetener: _retener,
                  )
                : null,
            bandeja: !_t.plantel.completo && !_modoCartas ? _bandeja(draft) : null,
            overlay: switch (_t.oferta) {
              final oferta? when _modoCartas =>
                oferta.sinAbrir
                    ? ElegirSobre(
                        key: ValueKey('sobres-${oferta.sobres.map((s) => s.toJson()).join()}'),
                        posicion: oferta.posicion,
                        sobres: oferta.sobres,
                        onAbrir: _abrirSobre,
                        bandeja: _hayBandeja && Draft.trae(_t, TokenDraft.comodin) ? _bandeja(draft) : null,
                        aviso: _t.regla == ReglaDraft.serpiente
                            ? (_t.plantel.jugadores.length.isOdd
                                  ? 'Draft en serpiente: en esta ronda los rivales eligen antes que vos.'
                                  : 'Draft en serpiente: en esta ronda elegís primero.')
                            : null,
                      )
                    : ReveladoCartas(
                        key: ValueKey('cartas-${oferta.cartaIds.join()}'),
                        posicion: oferta.posicion,
                        cartas: draft.cartasDeOferta(_t),
                        textoVolver: _textoVolver(draft, 'VOLVER A REPARTIR'),
                        puedeVolver: _puedeVolver(draft),
                        bandeja: _hayBandeja ? (elegida) => _bandeja(draft, elegidaDeLasCartas: elegida)! : null,
                        onFichar: _fichar,
                        onVolverARepartir: _volverARepartir,
                        sorpresaId: oferta.sorpresaId,
                        ciega: oferta.ciega,
                        robadas: [
                          for (final (id, f) in oferta.robadas)
                            if (draft.jugador(id) case final j?) (j, franquiciaPorId(f)),
                        ],
                      ),
              _ => null,
            },
          ),
        },
      ),
    );
  }

  Widget _zonaInferior(Draft draft) {
    final tema = Theme.of(context);
    final ayuda = tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant);

    final entrenador = Entrenador.porId(_t.entrenadorId);
    final quimica = _t.plantel.jugadores.length >= 2
        ? PanelQuimica(jugadores: _t.plantel.jugadores.toList(), entrenador: entrenador)
        : null;

    if (_t.plantel.completo) {
      // 7.º puesto: la carta de entrenador, antes de pasar a las tácticas.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?quimica,
          const SizedBox(height: 10),
          ChipEntrenador(entrenador: entrenador, onTap: _elegirEntrenador),
          const SizedBox(height: 12),
          if (entrenador == null) ...[
            FilledButton(onPressed: _elegirEntrenador, child: const Text('ELEGIR ENTRENADOR')),
            TextButton(
              onPressed: widget.onCompleto,
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('SEGUIR SIN ENTRENADOR'),
            ),
          ] else
            FilledButton(onPressed: widget.onCompleto, child: const Text('ELEGIR TÁCTICAS')),
        ],
      );
    }

    if (_modoCartas) {
      final regla = _t.regla == ReglaDraft.libre ? '' : '${_t.regla.nombre}. ';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?quimica,
          SizedBox(
            height: 64,
            child: Center(
              child: Text(
                _t.oferta == null ? '${regla}Tocá un puesto marcado en la cancha y elegí un sobre.' : '',
                style: ayuda,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    if (_t.tirada == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: CartaJugador.alto,
            child: Center(
              child: Text(
                'Tirá los carretes: salen estrellas de una franquicia, una época y una rareza.',
                style: ayuda,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _tirar, child: const Text('TIRAR')),
        ],
      );
    }

    final candidatos = _girando ? const <Jugador>[] : draft.candidatos(_t);
    final puedeVolver = !_girando && draft.puedeVolverATirar(_t, _retenidos);
    final String texto;
    if (_girando) {
      texto = ' ';
    } else if (_t.tokens.picksExtra > 0) {
      texto = 'DOBLE ACTIVO: elegí dos jugadores de esta tirada, cada uno en su puesto.';
    } else if (_retenidos.isNotEmpty && !puedeVolver && draft.precioDe(_t, TokenDraft.volverATirar) != null) {
      texto = 'No quedan cartas con esos carretes retenidos.';
    } else if (_elegida != null) {
      texto = 'Tocá un puesto marcado en la cancha.';
    } else {
      texto = 'Elegí una carta y tocá su puesto en la cancha.';
    }

    // Grilla de cartas verticales ordenada por media, con filtro por puesto libre.
    final libres = [
      for (final p in Posicion.values)
        if (!_t.plantel.estaOcupada(p)) p,
    ];
    final filtro = _filtro;
    final visibles = [
      for (final j in candidatos)
        if (filtro == null || _t.plantel.posicionesDisponiblesPara(j).contains(filtro)) j,
    ]..sort((a, b) => b.media.compareTo(a.media));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En teléfonos bajos, la bandeja de tokens le gana el lugar al medidor de química.
        if (quimica != null && !_girando && !(_hayBandeja && MediaQuery.sizeOf(context).height < 760)) ...[
          quimica,
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in [null, ...libres]) ...[
                ChoiceChip(
                  label: Text(
                    '${p?.etiqueta ?? 'TODAS'} · ${p == null ? candidatos.length : candidatos.where((j) => _t.plantel.posicionesDisponiblesPara(j).contains(p)).length}',
                  ),
                  selected: filtro == p,
                  onSelected: _girando ? null : (_) => setState(() => _filtro = p),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _girando
              ? const SizedBox.shrink()
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: esTabletApaisada(context) ? 4 : 3,
                    childAspectRatio: proporcionCarta,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (_, i) {
                    final j = visibles[i];
                    return Semantics(
                      button: true,
                      selected: j == _elegida,
                      label: '${j.nombre}, media ${j.media}, ${j.tier.etiqueta}, ${j.rol.etiqueta}',
                      onLongPressHint: 'ver ficha completa',
                      child: ExcludeSemantics(
                        child: GestureDetector(
                          onTap: () {
                            Haptica.seleccion();
                            setState(() => _elegida = j == _elegida ? null : j);
                          },
                          onLongPress: () => mostrarFichaJugador(context, j),
                          child: AnimatedOpacity(
                            opacity: _elegida == null || _elegida == j ? 1 : 0.55,
                            duration: const Duration(milliseconds: 150),
                            child: CartaVertical(jugador: j, seleccionada: j == _elegida),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (visibles.isEmpty && !_girando)
          Text('Ninguna carta de esta tirada juega de ${filtro?.etiqueta}.', style: tema.textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(texto, style: ayuda, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: puedeVolver && _puedeVolver(draft) ? _volverATirar : null,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(_textoVolver(draft, 'VOLVER A TIRAR')),
        ),
      ],
    );
  }
}

/// Fichas gratis de volver a tirar que quedan (modos sin tokens de pago).
class _Fichas extends StatelessWidget {
  const _Fichas(this.restantes);

  final int restantes;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Fichas para volver a tirar: $restantes',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.replay, size: 18, color: restantes > 0 ? esquema.primary : esquema.onSurfaceVariant),
            const SizedBox(width: 4),
            TextoLed('$restantes', tamano: 20, color: restantes > 0 ? null : esquema.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// La carta elegida vuela desde el reparto hasta su puesto en la cancha.
class _CartaEnVuelo extends StatefulWidget {
  const _CartaEnVuelo({required this.jugador, required this.origen, required this.destino, required this.onFin});

  final Jugador jugador;
  final Rect origen;
  final Rect destino;
  final VoidCallback onFin;

  @override
  State<_CartaEnVuelo> createState() => _CartaEnVueloState();
}

class _CartaEnVueloState extends State<_CartaEnVuelo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFin();
    })
    ..forward();
  late final _curva = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curva,
    builder: (context, _) {
      final rect = Rect.lerp(widget.origen, widget.destino, _curva.value)!;
      return Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: FittedBox(
            child: SizedBox(
              width: widget.origen.width,
              child: CartaVertical(jugador: widget.jugador, seleccionada: true),
            ),
          ),
        ),
      );
    },
  );
}
