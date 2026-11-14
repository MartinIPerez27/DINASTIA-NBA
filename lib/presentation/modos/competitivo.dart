import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/draft.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/metajuego.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/misiones.dart';
import '../../domain/modos/competitivo.dart';
import '../widgets/disposicion.dart';
import '../widgets/elegir_modo.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'competitivo_comun.dart';
import 'elegir_alineacion.dart';
import 'modos.dart';
import 'torneos.dart';

/// Divisiones, Conquista y Creador de torneos: se juegan con cartas de tu álbum.
bool esModoCompetitivo(ModoJuego m) => esPartidaCompetitiva(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarCompetitivo(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  final liga = await c.liga();
  if (!c.context.mounted) return;
  switch (m) {
    case ModoJuego.divisiones || ModoJuego.conquista:
      await _iniciarConAlbum(m, enfocada, c, liga);
    case ModoJuego.creadorTorneos:
      await iniciarCreadorDeTorneos(enfocada, c, liga);
    default:
      return;
  }
}

Future<void> _iniciarConAlbum(ModoJuego m, Franquicia enfocada, ContextoModos c, Liga liga) async {
  final album = perfilApp.value.coleccion;
  if (!Draft.coleccionAlcanza(liga.catalogo, album)) {
    ScaffoldMessenger.of(c.context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tu álbum todavía no alcanza para armar los 6 puestos: fichá en un draft o abrí sobres.'),
        ),
      );
    return;
  }
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null || !c.context.mounted) return;
  final cartas = await Navigator.of(c.context).push<Map<Posicion, String>>(
    MaterialPageRoute(
      builder: (_) => ElegirAlineacionPantalla(
        pool: [
          for (final j in liga.catalogo)
            if (album.contains(j.id)) j,
        ],
        titulo: m == ModoJuego.divisiones ? 'Tu equipo de Divisiones' : 'Tu equipo de Conquista',
        ayuda: 'Solo con cartas de tu álbum. Podés cambiarlo cuando quieras.',
      ),
    ),
  );
  if (cartas == null) return;
  final modos = ModosCompetitivo(liga, perfil: () => perfilApp.value);
  final id = ContextoModos.nuevoId();
  final t = m == ModoJuego.divisiones
      ? modos.nuevaDivisiones(id: id, franquiciaId: enfocada.id, dificultad: dificultad, cartas: cartas)
      : modos.nuevaConquista(id: id, franquiciaId: enfocada.id, dificultad: dificultad, cartas: cartas);
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// Pantalla propia del modo para la partida [t] (null si la partida no tiene su estado).
Future<Widget?> pantallaCompetitivo(Temporada t, ContextoModos c) async {
  final liga = await c.liga();
  Future<void> repetir(Temporada nueva) async {
    await c.guardar(nueva);
    await c.abrirTemporada(nueva, reemplazar: true);
  }

  return switch (t.modoJuego) {
    ModoJuego.divisiones when EstadoDivisiones.de(t) != null => DivisionesPantalla(
      temporada: t,
      liga: liga,
      onCambio: c.guardar,
    ),
    ModoJuego.conquista when EstadoConquista.de(t) != null => ConquistaPantalla(
      temporada: t,
      liga: liga,
      onCambio: c.guardar,
    ),
    ModoJuego.creadorTorneos when Torneo.de(t) != null => TorneoPantalla(
      temporada: t,
      liga: liga,
      onCambio: c.guardar,
      onRepetir: repetir,
    ),
    _ => null,
  };
}

// ═════════════════════════════════════════ Divisiones ═══════════════════════════════════════════

class DivisionesPantalla extends StatefulWidget {
  const DivisionesPantalla({super.key, required this.temporada, required this.liga, required this.onCambio, this.azar});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  /// Azar fijo para pruebas.
  final Random? azar;

  @override
  State<DivisionesPantalla> createState() => _DivisionesPantallaState();
}

class _DivisionesPantallaState extends State<DivisionesPantalla> {
  late Temporada _t = widget.temporada;
  late final _modos = ModosCompetitivo(widget.liga, azar: widget.azar, perfil: () => perfilApp.value);
  var _ocupado = false;

  @override
  void didUpdateWidget(DivisionesPantalla vieja) {
    super.didUpdateWidget(vieja);
    if (!identical(vieja.temporada, widget.temporada)) _t = widget.temporada;
  }

  EstadoDivisiones get _e => EstadoDivisiones.de(_t)!;
  Franquicia get _propia => franquiciaPorId(_t.franquiciaUsuarioId);

  void _guardar(Temporada t) {
    final ganados = EstadoDivisiones.de(t)!.victorias - _e.victorias;
    if (ganados > 0) Misiones.anotar(TipoMision.ganarDesafio, ganados);
    setState(() => _t = t);
    widget.onCambio(t);
  }

  Future<void> _vivo() async {
    final antes = _t;
    final e = _e;
    await jugarEnVivo(
      context,
      motor: _modos.motorDivisiones(antes),
      propia: _propia,
      rival: franquiciaPorId(e.pendiente!.identidadId),
      alTerminar: (m) => _guardar(_modos.registrarDivisiones(antes, m)),
    );
  }

  Future<void> _simular(Temporada Function(Temporada) f) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    _guardar(f(_t));
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _cambiarEquipo() async {
    final album = perfilApp.value.coleccion;
    final cartas = await Navigator.of(context).push<Map<Posicion, String>>(
      MaterialPageRoute(
        builder: (_) => ElegirAlineacionPantalla(
          pool: [
            for (final j in widget.liga.catalogo)
              if (album.contains(j.id)) j,
          ],
          inicial: _e.cartas,
          titulo: 'Tu equipo de Divisiones',
        ),
      ),
    );
    if (cartas != null) _guardar(_modos.cambiarCartasDivisiones(_t, cartas));
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final pendiente = e.pendiente;

    final encabezado = _EncabezadoDivision(estado: e, dificultad: _t.dificultad);
    final accion = pendiente != null
        ? TarjetaRival(
            titulo: 'Partido ${e.marcadores.length + 1} de ${EstadoDivisiones.partidosPorTemporada}',
            rival: pendiente,
            propia: _propia,
            liga: widget.liga,
            local: e.localProximo,
            ocupado: _ocupado,
            onVivo: _vivo,
            onSimular: () => _simular(_modos.simularDivisiones),
            extra: [
              TextButton(
                onPressed: _ocupado ? null : () => _simular(_modos.simularTemporadaDivisiones),
                child: const Text('SIMULAR TODA LA TEMPORADA'),
              ),
            ],
          )
        : _CierreDivision(estado: e, ocupado: _ocupado, onCerrar: () => _simular(_modos.cerrarTemporadaDivisiones));
    final equipo = ListaPlantel(cartas: e.cartas, liga: widget.liga, onCambiar: _cambiarEquipo);
    final resultados = _Resultados(estado: e, liga: widget.liga);

    return Scaffold(
      appBar: AppBar(title: const Text('Divisiones')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          encabezado,
                          const SizedBox(height: 12),
                          accion,
                          const SizedBox(height: 12),
                          resultados,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(width: 440, child: ListView(children: [equipo])),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  encabezado,
                  const SizedBox(height: 12),
                  accion,
                  const SizedBox(height: 12),
                  equipo,
                  const SizedBox(height: 12),
                  resultados,
                ],
              ),
      ),
      backgroundColor: esquema.surface,
    );
  }
}

class _EncabezadoDivision extends StatelessWidget {
  const _EncabezadoDivision({required this.estado, required this.dificultad});

  final EstadoDivisiones estado;
  final Dificultad dificultad;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = estado;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelCompetitivo(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DIVISIÓN', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
                    Text(
                      'Temporada ${e.temporada} · ${dificultad.nombre}',
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextoLed('${e.division}', tamano: 52),
            ],
          ),
          const SizedBox(height: 12),
          // La escalera de las diez divisiones: la tuya, encendida.
          Row(
            children: [
              for (var d = EstadoDivisiones.ultimaDivision; d >= 1; d--)
                Expanded(
                  child: Container(
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: d == e.division ? esquema.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: d == e.division ? esquema.primary : esquema.outlineVariant),
                    ),
                    child: FittedBox(
                      child: Text(
                        '$d',
                        style: tema.textTheme.labelMedium?.copyWith(
                          color: d == e.division ? esquema.onPrimary : esquema.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextoLed('${e.puntos}', tamano: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'puntos · ascendés con ${EstadoDivisiones.umbralAscenso}, descendés con '
                  '${EstadoDivisiones.umbralDescenso} o menos',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Un casillero por partido: ganado (lleno), perdido (vacío) o por jugar (punteado).
          Row(
            children: [
              for (var i = 0; i < EstadoDivisiones.partidosPorTemporada; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i < e.marcadores.length
                          ? (e.marcadores[i].$1 > e.marcadores[i].$2
                                ? esquema.primary
                                : esquema.onSurfaceVariant.withValues(alpha: 0.7))
                          : esquema.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CierreDivision extends StatelessWidget {
  const _CierreDivision({required this.estado, required this.ocupado, required this.onCerrar});

  final EstadoDivisiones estado;
  final bool ocupado;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = estado;
    final (nueva, mov) = EstadoDivisiones.cierre(e.division, e.puntos);
    final texto = e.tituloDeLaElite
        ? '¡Campeón de la élite! Seguís en la División 1.'
        : switch (mov) {
            MovimientoDivision.asciende => 'Subís a la División $nueva.',
            MovimientoDivision.desciende => 'Bajás a la División $nueva.',
            MovimientoDivision.mantiene => 'Te quedás en la División ${e.division}.',
          };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelCompetitivo(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('FIN DE LA TEMPORADA', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
          const SizedBox(height: 8),
          Center(child: TextoLed('${e.ganadosTemporada}-${e.marcadores.length - e.ganadosTemporada}', tamano: 44)),
          const SizedBox(height: 4),
          Center(child: Text('${e.puntos} puntos', style: tema.textTheme.bodyMedium)),
          const SizedBox(height: 8),
          Center(
            child: Text(mov.etiqueta, style: tema.textTheme.headlineSmall?.copyWith(color: esquema.primary)),
          ),
          const SizedBox(height: 4),
          Text(texto, textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: ocupado ? null : onCerrar,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('SIGUIENTE TEMPORADA'),
          ),
        ],
      ),
    );
  }
}

class _Resultados extends StatelessWidget {
  const _Resultados({required this.estado, required this.liga});

  final EstadoDivisiones estado;
  final Liga liga;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = estado;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: panelCompetitivo(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ESTA TEMPORADA', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
          const SizedBox(height: 6),
          if (e.marcadores.isEmpty)
            Text('Todavía no jugaste.', style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
          for (final (i, m) in e.marcadores.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Escudo(franquiciaPorId(e.rivales[i].identidadId), tamano: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nombreDeRival(e.rivales[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${m.$1 > m.$2 ? 'G' : 'P'} ${m.$1}-${m.$2}',
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: m.$1 > m.$2 ? esquema.primary : esquema.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '+${EstadoDivisiones.puntosPartido(m.$1, m.$2)}',
                      textAlign: TextAlign.end,
                      style: tema.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (e.historial.isNotEmpty) ...[
            const Divider(height: 24),
            Text('TEMPORADAS ANTERIORES', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
            const SizedBox(height: 6),
            for (final (i, h) in e.historial.indexed.toList().reversed.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Temporada ${i + 1} · División ${h.division}', style: tema.textTheme.bodySmall),
                    ),
                    Text('${h.puntos} pts · ${h.movimiento.etiqueta}', style: tema.textTheme.labelMedium),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════ Conquista ════════════════════════════════════════════

class ConquistaPantalla extends StatefulWidget {
  const ConquistaPantalla({super.key, required this.temporada, required this.liga, required this.onCambio, this.azar});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;
  final Random? azar;

  @override
  State<ConquistaPantalla> createState() => _ConquistaPantallaState();
}

class _ConquistaPantallaState extends State<ConquistaPantalla> {
  late Temporada _t = widget.temporada;
  late final _modos = ModosCompetitivo(widget.liga, azar: widget.azar, perfil: () => perfilApp.value);
  var _ocupado = false;

  @override
  void didUpdateWidget(ConquistaPantalla vieja) {
    super.didUpdateWidget(vieja);
    if (!identical(vieja.temporada, widget.temporada)) _t = widget.temporada;
  }

  EstadoConquista get _e => EstadoConquista.de(_t)!;
  Franquicia get _propia => franquiciaPorId(_t.franquiciaUsuarioId);

  void _guardar(Temporada t) {
    final ganados = EstadoConquista.de(t)!.victorias - _e.victorias;
    if (ganados > 0) Misiones.anotar(TipoMision.ganarDesafio, ganados);
    setState(() => _t = t);
    widget.onCambio(t);
  }

  void _tocar(String id) {
    final e = _e;
    if (e.terminada || e.objetivo != null || !e.atacables.contains(id)) return;
    _guardar(_modos.atacar(_t, id));
  }

  Future<void> _vivo() async {
    final antes = _t;
    final e = _e;
    await jugarEnVivo(
      context,
      motor: _modos.motorConquista(antes),
      propia: _propia,
      rival: franquiciaPorId(e.rival!.identidadId),
      alTerminar: (m) => _guardar(_modos.registrarConquista(antes, m)),
    );
  }

  Future<void> _simular() async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    _guardar(_modos.simularConquista(_t));
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _cambiarEquipo() async {
    final e = _e;
    final pool = _modos.cartasDisponiblesConquista(e, perfilApp.value.coleccion);
    final cartas = await Navigator.of(context).push<Map<Posicion, String>>(
      MaterialPageRoute(
        builder: (_) => ElegirAlineacionPantalla(
          pool: pool,
          inicial: e.cartas,
          titulo: 'Tu equipo de Conquista',
          ayuda: 'Tu álbum y las cartas de los ${e.conquistados.length} territorios que ganaste.',
        ),
      ),
    );
    if (cartas != null) _guardar(_modos.cambiarCartasConquista(_t, cartas));
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final mapa = _Mapa(estado: e, onTocar: _tocar);
    final panel = _PanelConquista(
      estado: e,
      liga: widget.liga,
      propia: _propia,
      ocupado: _ocupado,
      onVivo: _vivo,
      onSimular: _simular,
      onCancelar: () => _guardar(_modos.cancelarAtaque(_t)),
      onCambiarEquipo: _cambiarEquipo,
      onSalir: () => Navigator.of(context).popUntil((r) => r.isFirst),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Conquista')),
      backgroundColor: esquema.surface,
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Center(child: SingleChildScrollView(child: mapa)),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(width: 440, child: ListView(children: [panel])),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                children: [mapa, const SizedBox(height: 12), panel],
              ),
      ),
    );
  }
}

/// El tablero: las 30 franquicias en su lugar; tuyas (encendidas), atacables (con borde) y lejanas.
class _Mapa extends StatelessWidget {
  const _Mapa({required this.estado, required this.onTocar});

  final EstadoConquista estado;
  final ValueChanged<String> onTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final celda = min((c.maxWidth - 8) / columnasMapa, 76.0);
        final ataque = estado.objetivo;
        final tablero = Container(
          width: celda * columnasMapa + 8,
          height: celda * filasMapa + 8,
          padding: const EdgeInsets.all(4),
          decoration: panelCompetitivo(esquema),
          child: Stack(
            children: [
              for (final e in mapaConquista.entries)
                Positioned(
                  left: e.value.$1 * celda,
                  top: e.value.$2 * celda,
                  width: celda,
                  height: celda,
                  child: _Territorio(
                    franquicia: franquiciaPorId(e.key),
                    propio: estado.propios.contains(e.key),
                    atacable: estado.atacables.contains(e.key) && estado.objetivo == null && !estado.terminada,
                    enBatalla: ataque == e.key,
                    onTap: () => onTocar(e.key),
                  ),
                ),
            ],
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: tablero),
            const SizedBox(height: 8),
            const _Leyenda(),
          ],
        );
      },
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    Widget item(Color relleno, Color borde, double ancho, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: relleno,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borde, width: ancho),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        item(esquema.primary.withValues(alpha: 0.28), esquema.primary, 1, 'Tuyos'),
        item(Colors.transparent, esquema.primary, 2, 'Para atacar'),
        item(Colors.transparent, esquema.outlineVariant, 1, 'Lejanos'),
      ],
    );
  }
}

class _Territorio extends StatelessWidget {
  const _Territorio({
    required this.franquicia,
    required this.propio,
    required this.atacable,
    required this.enBatalla,
    required this.onTap,
  });

  final Franquicia franquicia;
  final bool propio, atacable, enBatalla;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final estado = propio ? 'tuyo' : (enBatalla ? 'en batalla' : (atacable ? 'atacable' : 'lejano'));
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: atacable,
        label: '${franquicia.nombreCompleto}, $estado',
        child: ExcludeSemantics(
          child: Tooltip(
            message: franquicia.nombreCompleto,
            child: Material(
              color: propio
                  ? esquema.primary.withValues(alpha: 0.28)
                  : enBatalla
                  ? esquema.error.withValues(alpha: 0.25)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: propio
                      ? esquema.primary
                      : enBatalla
                      ? esquema.error
                      : atacable
                      ? esquema.primary
                      : esquema.outlineVariant.withValues(alpha: 0.4),
                  width: atacable || enBatalla ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: atacable ? onTap : null,
                child: LayoutBuilder(
                  builder: (context, c) => Opacity(
                    opacity: propio || atacable || enBatalla ? 1 : 0.35,
                    child: Center(child: Escudo(franquicia, tamano: c.maxWidth * 0.68)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelConquista extends StatelessWidget {
  const _PanelConquista({
    required this.estado,
    required this.liga,
    required this.propia,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onCancelar,
    required this.onCambiarEquipo,
    required this.onSalir,
  });

  final EstadoConquista estado;
  final Liga liga;
  final Franquicia propia;
  final bool ocupado;
  final VoidCallback onVivo, onSimular, onCancelar, onCambiarEquipo, onSalir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = estado;
    final ventajas = e.ventajas(liga.franquicias);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: panelCompetitivo(esquema),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TERRITORIOS', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
                    TextoLed('${e.conquistados.length}/${mapaConquista.length}', tamano: 30),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('VIDAS', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < EstadoConquista.vidas; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Icon(
                            Icons.favorite,
                            size: 16,
                            color: i < e.vidasRestantes
                                ? esquema.primary
                                : esquema.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (e.completo)
          _Fin(titulo: '¡Dueño del mapa!', texto: 'Conquistaste las 30 franquicias.', onSalir: onSalir)
        else if (e.sinVidas)
          _Fin(
            titulo: 'Se acabó la campaña',
            texto: 'Perdiste ${e.derrotas} batallas. Conquistaste ${e.conquistados.length} de 30.',
            onSalir: onSalir,
          )
        else if (e.rival != null && e.objetivo != null)
          TarjetaRival(
            titulo: 'Batalla por ${franquiciaPorId(e.objetivo!).nombreCompleto}',
            rival: e.rival!,
            propia: propia,
            liga: liga,
            local: e.localProximo,
            ocupado: ocupado,
            onVivo: onVivo,
            onSimular: onSimular,
            extra: [TextButton(onPressed: ocupado ? null : onCancelar, child: const Text('ELEGIR OTRO TERRITORIO'))],
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: panelCompetitivo(esquema, resaltado: true),
            child: Text(
              'Tocá un territorio resaltado para atacarlo. Si ganás, es tuyo y sumás sus cartas.',
              style: tema.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 12),
        ListaPlantel(cartas: e.cartas, liga: liga, onCambiar: e.terminada ? null : onCambiarEquipo),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: panelCompetitivo(esquema),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('VENTAJAS DEL TERRITORIO', style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
              const SizedBox(height: 6),
              if (ventajas.isEmpty)
                Text(
                  'Dominá 3 de las 5 franquicias de una división de la NBA para ganar ventajas.',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              for (final (v, nivel) in ventajas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${v.nombre} (${v.division.etiqueta}) · nivel $nivel: ${v.descripcion}',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fin extends StatelessWidget {
  const _Fin({required this.titulo, required this.texto, required this.onSalir});

  final String titulo, texto;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelCompetitivo(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: tema.textTheme.headlineSmall?.copyWith(color: esquema.primary),
          ),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onSalir,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('VOLVER AL INICIO'),
          ),
        ],
      ),
    );
  }
}
