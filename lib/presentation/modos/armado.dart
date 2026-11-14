import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/entities/plantel.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/modos/amigos.dart';
import '../../domain/modos/armado.dart';
import '../../domain/motor.dart';
import '../../domain/premios.dart' show apellido;
import '../../domain/quimica.dart';
import '../pantallas/partido_pantalla.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/disposicion.dart';
import '../widgets/elegir_modo.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Modos de armado: tope salarial, desafíos con el álbum, liga contra la IA y el minijuego de adivinar.
bool esModoArmado(ModoJuego m) =>
    const {ModoJuego.topeSalarial, ModoJuego.desafiosArmado, ModoJuego.ligaIA, ModoJuego.adivina}.contains(m);

/// Guarda el perfil (los modos sin partida: desafíos y adiviná).
void _guardarPerfil(ContextoModos c, PerfilEntrenador p) {
  perfilApp.value = p;
  c.db?.escribir('perfil', p.toJson()).ignore();
}

Conferencia? _conferencia(String franquiciaId) {
  try {
    return franquiciaPorId(franquiciaId).conferencia;
  } catch (_) {
    return null;
  }
}

String _nombreFranquicia(String id) => franquiciaPorId(id).nombreCompleto;

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarArmado(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  final liga = await c.liga();
  if (!c.context.mounted) return;
  final navegador = c.navegador.currentState!;
  switch (m) {
    case ModoJuego.desafiosArmado:
      navegador.push(
        MaterialPageRoute<void>(
          builder: (_) => DesafiosArmadoPantalla(catalogo: liga.catalogo, onPerfil: (p) => _guardarPerfil(c, p)),
        ),
      );
    case ModoJuego.adivina:
      final v = await showModalBottomSheet<VarianteAdivina>(
        context: c.context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => const _ElegirVariante(),
      );
      if (v == null || !c.context.mounted) return;
      navegador.push(
        MaterialPageRoute<void>(
          builder: (_) => AdivinaPantalla(catalogo: liga.catalogo, variante: v, onPerfil: (p) => _guardarPerfil(c, p)),
        ),
      );
    case ModoJuego.topeSalarial:
      final d = await elegirDificultad(c.context);
      if (d == null) return;
      final id = ContextoModos.nuevoId();
      final p = ModosArmado(liga.catalogo).nuevoTope(
        semilla: int.parse(id) % 1000000007,
        dificultad: d,
        franquiciaUsuario: enfocada.id,
        franquicias: [for (final f in franquicias) f.id],
        nombreDe: _nombreFranquicia,
      );
      final t = Temporada(id: id, franquiciaUsuarioId: enfocada.id, dificultad: d, modoJuego: m).conArmada(p);
      await c.guardar(t);
      await c.abrirTemporada(t);
    case ModoJuego.ligaIA:
      final id = ContextoModos.nuevoId();
      final modos = ModosArmado(liga.catalogo);
      final p = modos.avanzarIA(
        modos.nuevaLigaIA(
          semilla: int.parse(id) % 1000000007,
          franquiciaUsuario: enfocada.id,
          franquicias: [for (final f in franquicias) f.id],
          nombreDe: _nombreFranquicia,
        ),
      );
      final t = Temporada(id: id, franquiciaUsuarioId: enfocada.id, modoJuego: m).conArmada(p);
      await c.guardar(t);
      await c.abrirTemporada(t);
    default:
      return;
  }
}

/// Pantalla propia del modo para la partida [t] (tope salarial y liga contra la IA).
Future<Widget?> pantallaArmado(Temporada t, ContextoModos c) async {
  if (!esPartidaArmada(t.modoJuego)) return null;
  final liga = await c.liga();
  return ArmadoPantalla(temporada: t, liga: liga, onCambio: c.guardar);
}

BoxDecoration _panel(ColorScheme esquema, {Color? borde}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: borde ?? esquema.outlineVariant.withValues(alpha: 0.5)),
);

// ═══════════════════════════════ Tope salarial / Liga de 8 ═══════════════════════════════════

/// Tope salarial y Liga de 8 contra la IA: el armado (tablero o draft) y después la liga de 8.
class ArmadoPantalla extends StatefulWidget {
  const ArmadoPantalla({super.key, required this.temporada, required this.liga, required this.onCambio, this.azar});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;
  final Random? azar;

  @override
  State<ArmadoPantalla> createState() => _ArmadoPantallaState();
}

class _ArmadoPantallaState extends State<ArmadoPantalla> {
  late Temporada _t = widget.temporada;
  late final _modos = ModosArmado(widget.liga.catalogo, azar: widget.azar);
  var _ocupado = false;
  Posicion? _filtro;

  PartidaArmada get _p => PartidaArmada.de(_t)!;

  void _guardar(PartidaArmada p) {
    final t = _t.conArmada(p);
    setState(() => _t = t);
    widget.onCambio(t);
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(texto)));

  // ─── Tope ───

  void _tocarTope(Jugador j, Posicion columna) {
    final e = _p.tope!;
    final comprado = e.compra.entries.where((x) => x.value == j.id).firstOrNull;
    if (comprado != null) {
      _guardar(_p.copyWith(tope: _modos.vender(e, comprado.key)));
      return;
    }
    // Puesto: el de su columna si está libre; si no, otro titular libre que juegue; si no, el sexto.
    final candidatos = [
      columna,
      for (final p in Posicion.titulares)
        if (p != columna) p,
      Posicion.sextoHombre,
    ];
    String? motivo;
    for (final pos in candidatos) {
      final m = _modos.motivoNoCompra(e, j, pos);
      if (m == null) {
        _guardar(_p.copyWith(tope: _modos.comprar(e, j, pos)));
        return;
      }
      motivo ??= m;
      if (m.startsWith('No te alcanza')) break;
    }
    _aviso(motivo ?? 'No entra en ningún puesto libre.');
  }

  // ─── Draft ───

  void _elegirDraft(Jugador j) {
    final p = _p;
    if (p.draft!.eligeAhora != PartidaArmada.usuario) return;
    if (p.equipos[0].plantel.posicionesDisponiblesPara(j).isEmpty) {
      _aviso('${j.nombre} no entra en ningún puesto libre.');
      return;
    }
    _guardar(_modos.elegir(p, j, _modos.puestoPara(p, 0, j)));
  }

  // ─── Liga ───

  Future<void> _vivo() async {
    var p = _modos.simularAjenos(_p);
    if (!identical(p, _p)) _guardar(p);
    final x = _modos.proximoDelUsuario(p);
    if (x == null) return;
    final local = x.local == PartidaArmada.usuario;
    final motor = _modos.motor(p, x, usuarioLocal: local);
    final propia = franquiciaPorId(p.equipos[0].franquiciaId);
    final rival = franquiciaPorId(p.equipos[local ? x.visitante : x.local].franquiciaId);
    final antes = p;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: motor,
          usuarioLocal: local,
          franquiciaUsuario: propia,
          identidadLocal: local ? propia : rival,
          identidadVisitante: local ? rival : propia,
          onTerminado: (MotorPartido m) => _guardar(_modos.simularAjenos(_modos.registrar(antes, m))),
        ),
      ),
    );
  }

  Future<void> _simular(PartidaArmada Function(PartidaArmada) paso) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    _guardar(paso(_p));
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final titulo = _t.modoJuego.nombre;
    final Widget cuerpo = switch (p.fase) {
      FaseArmada.armado when p.tope != null => _TableroTope(
        estado: p.tope!,
        modos: _modos,
        onTocar: _tocarTope,
        onConfirmar: p.tope!.completo ? () => _guardar(_modos.confirmarTope(p)) : null,
      ),
      FaseArmada.armado => _DraftIA(
        partida: p,
        modos: _modos,
        filtro: _filtro,
        onFiltro: (f) => setState(() => _filtro = f),
        onElegir: _elegirDraft,
      ),
      _ => _VistaLiga(
        partida: p,
        modos: _modos,
        ocupado: _ocupado,
        onVivo: _vivo,
        onSimular: () => _simular(_modos.simularProximoDelUsuario),
        onSimularFase: () => _simular(_modos.simularFase),
        onSimularTodo: () => _simular(_modos.simularTodo),
        onSalir: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(top: false, child: cuerpo),
    );
  }
}

/// Celda chica de una carta: media LED, iniciales y apellido.
class _CartaChica extends StatelessWidget {
  const _CartaChica({required this.jugador, this.marcada = false, this.apagada = false});

  final Jugador jugador;
  final bool marcada, apagada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final f = identidadDe(jugador);
    return Opacity(
      opacity: apagada ? 0.4 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
        decoration: BoxDecoration(
          color: marcada ? esquema.primary.withValues(alpha: 0.18) : esquema.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: marcada ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
            width: marcada ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Escudo(f, tamano: 14),
                const Spacer(),
                Text(jugador.tier.codigo, style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary)),
              ],
            ),
            FittedBox(child: TextoLed('${jugador.media}', tamano: 18)),
            FittedBox(
              child: Text(
                apellido(jugador).toUpperCase(),
                maxLines: 1,
                style: tema.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FittedBox(
              child: Text(
                '${jugador.posiciones.map((x) => x.abreviatura).join('/')} · ${jugador.tramoCorto}',
                maxLines: 1,
                style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Posicion {
  String get abreviatura => switch (this) {
    Posicion.base => 'B',
    Posicion.escolta => 'E',
    Posicion.alero => 'A',
    Posicion.alaPivot => 'AP',
    Posicion.pivot => 'P',
    Posicion.sextoHombre => '6',
  };
}

/// Tu plantel (los 6 puestos), con la química.
class _Plantel extends StatelessWidget {
  const _Plantel({required this.plantel});

  final Plantel plantel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final q = Quimica.de(plantel.jugadores);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('TU PLANTEL', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1))),
              Text('QUÍMICA ', style: tema.textTheme.labelSmall),
              TextoLed('${q.puntaje}', tamano: 16),
            ],
          ),
          const SizedBox(height: 6),
          for (final pos in Posicion.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      pos.etiqueta.toUpperCase(),
                      style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      plantel.en(pos)?.nombre ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium,
                    ),
                  ),
                  if (plantel.en(pos) case final j?) TextoLed('${j.media}', tamano: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────── Tope ────────────────────────────────────────────────

class _TableroTope extends StatelessWidget {
  const _TableroTope({required this.estado, required this.modos, required this.onTocar, required this.onConfirmar});

  final EstadoTope estado;
  final ModosArmado modos;
  final void Function(Jugador, Posicion) onTocar;
  final VoidCallback? onConfirmar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final restante = modos.restante(estado);
    final js = [for (final id in estado.tablero) modos.jugador(id)!];
    final comprados = estado.compra.values.toSet();
    final faltan = Posicion.values.length - estado.compra.length;

    final encabezado = Container(
      padding: const EdgeInsets.all(14),
      decoration: _panel(esquema),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOPE SALARIAL', style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(
                  faltan == 0
                      ? 'Plantel completo. Confirmalo y arranca la liga de 8.'
                      : 'Comprá 5 titulares y el Sexto Hombre. Te faltan $faltan.',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            children: [
              TextoLed('\$$restante', tamano: 34),
              Text('DE \$${estado.presupuesto}', style: tema.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );

    final grilla = Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 30),
            for (final pos in Posicion.titulares)
              Expanded(
                child: Center(
                  child: Text(
                    pos.etiqueta.toUpperCase(),
                    style: tema.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var fila = 0; fila < 5; fila++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 30, child: TextoLed('\$${EstadoTope.filas[fila]}', tamano: 14)),
                for (var col = 0; col < 5; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        key: ValueKey('tope-${js[fila * 5 + col].id}'),
                        onTap: () => onTocar(js[fila * 5 + col], Posicion.titulares[col]),
                        child: _CartaChica(
                          jugador: js[fila * 5 + col],
                          marcada: comprados.contains(js[fila * 5 + col].id),
                          apagada:
                              !comprados.contains(js[fila * 5 + col].id) &&
                              (faltan == 0 || precioTope(js[fila * 5 + col]) + faltan - 1 > restante),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Text(
          'Tocá una carta para comprarla (va a su columna o a un puesto libre); tocala de nuevo para venderla.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );

    final plantel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Plantel(plantel: modos.plantelTope(estado)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onConfirmar,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('CONFIRMAR Y JUGAR LA LIGA'),
        ),
        const SizedBox(height: 8),
        Text(
          'Los otros 7 equipos armaron con el mismo presupuesto. Liga a dos ruedas (14 partidos) y '
          'semifinales y final al mejor de 3.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );

    if (esTabletApaisada(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: ListView(children: [encabezado, const SizedBox(height: 12), grilla])),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: ListView(children: [plantel])),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [encabezado, const SizedBox(height: 12), grilla, const SizedBox(height: 12), plantel],
    );
  }
}

// ──────────────────────────────────────── Draft IA ───────────────────────────────────────────

class _DraftIA extends StatelessWidget {
  const _DraftIA({
    required this.partida,
    required this.modos,
    required this.filtro,
    required this.onFiltro,
    required this.onElegir,
  });

  final PartidaArmada partida;
  final ModosArmado modos;
  final Posicion? filtro;
  final ValueChanged<Posicion?> onFiltro;
  final ValueChanged<Jugador> onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final d = partida.draft!;
    final propio = partida.equipos[0].plantel;
    final pozo = modos.cartasDelPozo(partida)..sort((a, b) => b.media.compareTo(a.media));
    final visibles = [
      for (final j in pozo)
        if ((filtro == null || j.puedeJugarEn(filtro!)) && propio.posicionesDisponiblesPara(j).isNotEmpty) j,
    ];
    final encabezado = Container(
      padding: const EdgeInsets.all(14),
      decoration: _panel(esquema, borde: esquema.primary),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TE TOCA ELEGIR', style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
                Text(
                  'Ronda ${d.ronda} de 6 · elección ${d.turno + 1} de ${EstadoDraftIA.totalElecciones}. '
                  'Las cartas grises no entran en tus puestos libres.',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextoLed('${d.ronda}/6', tamano: 26),
        ],
      ),
    );
    final relato = d.ultimas.isEmpty
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.all(12),
            decoration: _panel(esquema),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ÚLTIMAS ELECCIONES', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
                const SizedBox(height: 4),
                for (final (e, id) in d.ultimas.reversed.take(7))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Escudo(franquiciaPorId(partida.equipos[e].franquiciaId), tamano: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${e == 0 ? 'Vos' : partida.equipos[e].estilo?.nombre ?? partida.equipos[e].nombre}: '
                            '${modos.jugador(id)?.nombre ?? id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
    final rivales = Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LOS 7 MÁNAGERS', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          for (final e in partida.equipos.skip(1))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Escudo(franquiciaPorId(e.franquiciaId), tamano: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.estilo?.nombre ?? e.nombre, style: tema.textTheme.bodyMedium),
                        Text(
                          e.estilo?.descripcion ?? '',
                          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextoLed('${e.plantel.jugadores.length}/6', tamano: 14),
                ],
              ),
            ),
        ],
      ),
    );
    final filtros = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(label: const Text('Todas'), selected: filtro == null, onSelected: (_) => onFiltro(null)),
        for (final pos in Posicion.titulares)
          ChoiceChip(label: Text(pos.etiqueta), selected: filtro == pos, onSelected: (_) => onFiltro(pos)),
      ],
    );
    Widget grilla(int columnas) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (_, i) => GestureDetector(
        key: ValueKey('pozo-${visibles[i].id}'),
        onTap: () => onElegir(visibles[i]),
        child: CartaVertical(jugador: visibles[i]),
      ),
    );

    if (esTabletApaisada(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 380,
              child: ListView(
                children: [
                  encabezado,
                  const SizedBox(height: 12),
                  _Plantel(plantel: propio),
                  const SizedBox(height: 12),
                  relato,
                  const SizedBox(height: 12),
                  rivales,
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: ListView(children: [filtros, const SizedBox(height: 10), grilla(5)])),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        encabezado,
        const SizedBox(height: 12),
        _Plantel(plantel: propio),
        const SizedBox(height: 12),
        relato,
        const SizedBox(height: 12),
        filtros,
        const SizedBox(height: 10),
        grilla(3),
        const SizedBox(height: 12),
        rivales,
      ],
    );
  }
}

// ─────────────────────────────────────────── Liga ────────────────────────────────────────────

class _VistaLiga extends StatelessWidget {
  const _VistaLiga({
    required this.partida,
    required this.modos,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onSimularFase,
    required this.onSimularTodo,
    required this.onSalir,
  });

  final PartidaArmada partida;
  final ModosArmado modos;
  final bool ocupado;
  final VoidCallback onVivo, onSimular, onSimularFase, onSimularTodo, onSalir;

  String _fase(FaseArmada f) => switch (f) {
    FaseArmada.liga => 'Liga',
    FaseArmada.semis => 'Semifinales',
    FaseArmada.finalLiga => 'La final',
    FaseArmada.terminada => 'Terminada',
    FaseArmada.armado => 'Armado',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final p = partida;
    final (v, d) = p.recordUsuario;
    final proximo = modos.proximoDelUsuario(p);
    final terminada = p.fase == FaseArmada.terminada;

    final encabezado = Container(
      padding: const EdgeInsets.all(14),
      decoration: _panel(esquema),
      child: Row(
        children: [
          Escudo(franquiciaPorId(p.equipos[0].franquiciaId), tamano: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fase(p.fase).toUpperCase(), style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
                Text(p.equipos[0].nombre, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
              ],
            ),
          ),
          TextoLed('$v-$d', tamano: 32),
        ],
      ),
    );

    final Widget accion;
    if (terminada) {
      final campeon = p.campeon!;
      final propio = campeon == PartidaArmada.usuario;
      accion = Container(
        padding: const EdgeInsets.all(16),
        decoration: _panel(esquema, borde: propio ? esquema.primary : null),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: propio ? esquema.primary : esquema.onSurfaceVariant),
            const SizedBox(height: 6),
            Escudo(franquiciaPorId(p.equipos[campeon].franquiciaId), tamano: 56),
            const SizedBox(height: 6),
            Text(
              propio ? '¡CAMPEONES!' : 'Campeón: ${p.equipos[campeon].estilo?.nombre ?? p.equipos[campeon].nombre}',
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSalir, child: const Text('VOLVER AL INICIO')),
          ],
        ),
      );
    } else if (proximo != null) {
      final local = proximo.local == PartidaArmada.usuario;
      final rival = p.equipos[local ? proximo.visitante : proximo.local];
      accion = Container(
        padding: const EdgeInsets.all(14),
        decoration: _panel(esquema, borde: esquema.primary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Escudo(franquiciaPorId(rival.franquiciaId), tamano: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${local ? 'vs' : '@'} ${rival.nombre}',
                        style: tema.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (rival.estilo != null)
                        Text(rival.estilo!.nombre, style: tema.textTheme.bodySmall?.copyWith(color: esquema.primary)),
                      Text(
                        rival.plantel.jugadores.map(apellido).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ocupado ? null : onVivo,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('JUGAR EN VIVO'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: ocupado ? null : onSimular, child: const Text('SIMULAR')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: ocupado ? null : onSimularFase,
                    child: FittedBox(child: Text(p.fase == FaseArmada.liga ? 'SIMULAR LA LIGA' : 'SIMULAR LA SERIE')),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      accion = Container(
        padding: const EdgeInsets.all(14),
        decoration: _panel(esquema),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quedaste afuera de los playoffs.', style: tema.textTheme.titleMedium),
            const SizedBox(height: 10),
            FilledButton(onPressed: ocupado ? null : onSimularTodo, child: const Text('VER CÓMO TERMINA')),
          ],
        ),
      );
    }

    final tabla = _Tabla(partida: p);
    final cuadro = p.semis.isEmpty ? const SizedBox.shrink() : _Cuadro(partida: p);
    if (esTabletApaisada(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 420,
              child: ListView(
                children: [
                  encabezado,
                  const SizedBox(height: 12),
                  accion,
                  const SizedBox(height: 12),
                  _Plantel(plantel: p.equipos[0].plantel),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: ListView(children: [cuadro, const SizedBox(height: 12), tabla])),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        encabezado,
        const SizedBox(height: 12),
        accion,
        const SizedBox(height: 12),
        cuadro,
        const SizedBox(height: 12),
        tabla,
        const SizedBox(height: 12),
        _Plantel(plantel: p.equipos[0].plantel),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.partida});

  final PartidaArmada partida;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final filas = partida.tabla();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POSICIONES', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 6),
          for (var k = 0; k < filas.length; k++) ...[
            if (k == 4) Divider(height: 10, color: esquema.primary.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text('${k + 1}', style: tema.textTheme.labelMedium)),
                  Escudo(franquiciaPorId(partida.equipos[filas[k].indice].franquiciaId), tamano: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filas[k].indice == 0
                          ? 'Vos'
                          : partida.equipos[filas[k].indice].estilo?.nombre ?? partida.equipos[filas[k].indice].nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        fontWeight: filas[k].indice == 0 ? FontWeight.w800 : null,
                        color: filas[k].indice == 0 ? esquema.primary : null,
                      ),
                    ),
                  ),
                  TextoLed('${filas[k].victorias}-${filas[k].derrotas}', tamano: 16),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${filas[k].diferencia >= 0 ? '+' : ''}${filas[k].diferencia}',
                      textAlign: TextAlign.end,
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Los 4 primeros van a las semifinales (1.º vs 4.º, 2.º vs 3.º), al mejor de 3.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Cuadro extends StatelessWidget {
  const _Cuadro({required this.partida});

  final PartidaArmada partida;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    Widget serie(String titulo, SerieAmigos s) {
      Widget lado(int i) => Row(
        children: [
          Escudo(franquiciaPorId(partida.equipos[i].franquiciaId), tamano: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              i == 0 ? 'Vos' : partida.equipos[i].estilo?.nombre ?? partida.equipos[i].nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodySmall?.copyWith(
                fontWeight: s.ganador == i ? FontWeight.w800 : null,
                color: s.terminada && s.ganador != i ? esquema.onSurfaceVariant : null,
              ),
            ),
          ),
          TextoLed('${s.victoriasDe(i)}', tamano: 16),
        ],
      );
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: _panel(esquema, borde: s.alto == 0 || s.bajo == 0 ? esquema.primary : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary)),
            const SizedBox(height: 4),
            lado(s.alto),
            lado(s.bajo),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PLAYOFFS', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: serie('SEMIFINAL 1', partida.semis[0])),
            const SizedBox(width: 8),
            Expanded(child: serie('SEMIFINAL 2', partida.semis[1])),
          ],
        ),
        if (partida.finalSerie case final f?) ...[const SizedBox(height: 8), serie('LA FINAL', f)],
      ],
    );
  }
}

// ═════════════════════════════════════ Desafíos de armado ════════════════════════════════════

/// Lista de los 20 desafíos de armado con tu álbum.
class DesafiosArmadoPantalla extends StatefulWidget {
  const DesafiosArmadoPantalla({super.key, required this.catalogo, required this.onPerfil});

  final List<Jugador> catalogo;
  final ValueChanged<PerfilEntrenador> onPerfil;

  @override
  State<DesafiosArmadoPantalla> createState() => _DesafiosArmadoPantallaState();
}

class _DesafiosArmadoPantallaState extends State<DesafiosArmadoPantalla> {
  PerfilEntrenador get _perfil => perfilApp.value;

  List<Jugador> get _album => [
    for (final j in widget.catalogo)
      if (_perfil.coleccion.contains(j.id)) j,
  ];

  Future<void> _abrir(DesafioArmado d) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DesafioPantalla(
          desafio: d,
          album: _album,
          onResuelto: () {
            final p = _perfil.conDesafioResuelto(d);
            widget.onPerfil(p);
            perfilApp.value = p;
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final resueltos = _perfil.desafiosResueltos;
    final album = _album;
    return Scaffold(
      appBar: AppBar(title: const Text('Desafíos de armado')),
      body: AnchoMaximo(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _panel(esquema),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Armá quintetos con las cartas de tu álbum que cumplan cada condición. Las cartas no se gastan.',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      TextoLed('${resueltos.length}/${desafiosArmado.length}', tamano: 24),
                      Text('RESUELTOS', style: tema.textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < desafiosArmado.length; i++)
              Builder(
                builder: (context) {
                  final d = desafiosArmado[i];
                  final hecho = resueltos.contains(d.id);
                  final desbloqueado = _perfil.desafioDesbloqueado(i);
                  final alcanza = albumAlcanza(d, album);
                  final abierto = desbloqueado && alcanza;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      key: ValueKey('desafio-${d.id}'),
                      enabled: abierto || hecho,
                      leading: Icon(
                        hecho ? Icons.check_circle : (abierto ? Icons.extension_outlined : Icons.lock_outline),
                        color: hecho ? esquema.primary : null,
                      ),
                      title: Text('${i + 1}. ${d.titulo}'),
                      subtitle: Text(
                        !desbloqueado
                            ? 'Resolvé el anterior para desbloquearlo.'
                            : !alcanza
                            ? 'Tu álbum no alcanza (${album.length}/${d.albumMinimo} cartas): conseguí más cartas en la tienda.'
                            : d.condiciones.map((c) => c.texto).join(' · '),
                      ),
                      trailing: hecho ? const Text('LISTO') : TextoLed('+${d.monedas}', tamano: 14),
                      onTap: abierto || hecho ? () => _abrir(d) : null,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Un desafío: 6 puestos para llenar con cartas del álbum y las condiciones en vivo.
class DesafioPantalla extends StatefulWidget {
  const DesafioPantalla({super.key, required this.desafio, required this.album, required this.onResuelto});

  final DesafioArmado desafio;
  final List<Jugador> album;
  final VoidCallback onResuelto;

  @override
  State<DesafioPantalla> createState() => _DesafioPantallaState();
}

class _DesafioPantallaState extends State<DesafioPantalla> {
  var _plantel = const Plantel();
  Posicion? _filtro;
  var _busqueda = '';
  var _cobrado = false;

  void _tocar(Jugador j) {
    final puesto = _plantel.jugadores.contains(j) ? Posicion.values.firstWhere((p) => _plantel.en(p) == j) : null;
    if (puesto != null) {
      setState(() => _plantel = _plantel.quitar(puesto));
      return;
    }
    final libres = _plantel.posicionesDisponiblesPara(j);
    if (libres.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('${j.nombre} no entra en ningún puesto libre.')));
      return;
    }
    final pos = _filtro != null && libres.contains(_filtro) ? _filtro! : libres.first;
    setState(() => _plantel = _plantel.asignar(j, pos));
    if (!_cobrado && widget.desafio.resuelto(_plantel, _conferencia)) {
      _cobrado = true;
      widget.onResuelto();
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¡Desafío resuelto!'),
          content: Text('+${widget.desafio.monedas} monedas, XP y puntos del pase.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('GENIAL'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final js = _plantel.jugadores.toList();
    final estado = widget.desafio.estado(js, _conferencia);
    final visibles = [
      for (final j in widget.album)
        if ((_filtro == null || j.puedeJugarEn(_filtro!)) &&
            (_busqueda.isEmpty || j.nombre.toLowerCase().contains(_busqueda.toLowerCase())))
          j,
    ]..sort((a, b) => b.media.compareTo(a.media));

    final condiciones = Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(esquema, borde: esquema.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.desafio.titulo.toUpperCase(), style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _plantel.completo ? Icons.check : Icons.close,
                size: 18,
                color: _plantel.completo ? esquema.primary : esquema.error,
              ),
              const SizedBox(width: 6),
              Text('Plantel completo (${js.length}/6)', style: tema.textTheme.bodyMedium),
            ],
          ),
          for (final (c, ok) in estado)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(ok ? Icons.check : Icons.close, size: 18, color: ok ? esquema.primary : esquema.error),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.texto, style: tema.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
    final buscador = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar en tu álbum',
            isDense: true,
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _filtro == null,
              onSelected: (_) => setState(() => _filtro = null),
            ),
            for (final pos in Posicion.values)
              ChoiceChip(
                label: Text(pos.etiqueta),
                selected: _filtro == pos,
                onSelected: (_) => setState(() => _filtro = pos),
              ),
          ],
        ),
      ],
    );
    final elegidos = js.toSet();
    Widget grilla(int columnas) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (_, i) => GestureDetector(
        key: ValueKey('album-${visibles[i].id}'),
        onTap: () => _tocar(visibles[i]),
        child: _CartaChica(jugador: visibles[i], marcada: elegidos.contains(visibles[i])),
      ),
    );

    final Widget cuerpo;
    if (esTabletApaisada(context)) {
      cuerpo = Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 380,
              child: ListView(
                children: [
                  condiciones,
                  const SizedBox(height: 12),
                  _Plantel(plantel: _plantel),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: ListView(children: [buscador, const SizedBox(height: 10), grilla(7)])),
          ],
        ),
      );
    } else {
      cuerpo = ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          condiciones,
          const SizedBox(height: 10),
          _Plantel(plantel: _plantel),
          const SizedBox(height: 10),
          buscador,
          const SizedBox(height: 10),
          grilla(4),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Desafío de armado')),
      body: cuerpo,
    );
  }
}

// ═══════════════════════════════════════ Adiviná la carta ════════════════════════════════════

class _ElegirVariante extends StatelessWidget {
  const _ElegirVariante();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final perfil = perfilApp.value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ADIVINÁ LA CARTA', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 8),
          for (final v in VarianteAdivina.values)
            ListTile(
              title: Text(v.nombre),
              subtitle: Text('${v.descripcion} Tu récord: ${perfil.mejorAdivina(v)}/${Adivina.rondas}.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(v),
            ),
        ],
      ),
    );
  }
}

/// El minijuego: 10 preguntas, puntaje y racha. Al terminar guarda el récord y los premios.
class AdivinaPantalla extends StatefulWidget {
  const AdivinaPantalla({super.key, required this.catalogo, required this.variante, required this.onPerfil, this.azar});

  final List<Jugador> catalogo;
  final VarianteAdivina variante;
  final ValueChanged<PerfilEntrenador> onPerfil;
  final Random? azar;

  @override
  State<AdivinaPantalla> createState() => _AdivinaPantallaState();
}

class _AdivinaPantallaState extends State<AdivinaPantalla> {
  late final _adivina = Adivina(widget.catalogo, azar: widget.azar);
  late PreguntaAdivina _q = _adivina.pregunta(widget.variante);
  var _ronda = 1, _aciertos = 0, _racha = 0, _mejorRacha = 0;
  int? _respuesta;
  var _terminada = false;

  void _responder(int i) {
    if (_respuesta != null) return;
    final ok = i == _q.correcta;
    setState(() {
      _respuesta = i;
      if (ok) {
        _aciertos++;
        _racha++;
        _mejorRacha = max(_mejorRacha, _racha);
      } else {
        _racha = 0;
      }
    });
  }

  void _siguiente() {
    if (_ronda >= Adivina.rondas) {
      final p = perfilApp.value.conSesionAdivina(widget.variante, _aciertos, Adivina.rondas);
      widget.onPerfil(p);
      setState(() => _terminada = true);
      return;
    }
    setState(() {
      _ronda++;
      _respuesta = null;
      _q = _adivina.pregunta(widget.variante);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final marcador = Container(
      padding: const EdgeInsets.all(12),
      decoration: _panel(esquema),
      child: Row(
        children: [
          Expanded(child: Text('Pregunta $_ronda / ${Adivina.rondas}', style: tema.textTheme.titleMedium)),
          Column(
            children: [
              TextoLed('$_aciertos', tamano: 26),
              Text('ACIERTOS', style: tema.textTheme.labelSmall),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              TextoLed('$_racha', tamano: 26),
              Text('RACHA', style: tema.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );

    if (_terminada) {
      final perfecto = _aciertos == Adivina.rondas;
      return Scaffold(
        appBar: AppBar(title: Text(widget.variante.nombre)),
        body: AnchoMaximo(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _panel(esquema, borde: esquema.primary),
                child: Column(
                  children: [
                    TextoLed('$_aciertos/${Adivina.rondas}', tamano: 56),
                    const SizedBox(height: 8),
                    Text(
                      perfecto ? '¡Perfecto! Sos una enciclopedia.' : 'Mejor racha: $_mejorRacha seguidas.',
                      style: tema.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${_aciertos * 10} XP · +${_aciertos * 5} monedas',
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('LISTO')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final contestada = _respuesta != null;
    Color? colorOpcion(int i) {
      if (!contestada) return null;
      if (i == _q.correcta) return esquema.primary;
      if (i == _respuesta) return esquema.error;
      return null;
    }

    final Widget pregunta;
    if (widget.variante == VarianteAdivina.quien) {
      final s = _q.objetivo.stats;
      final pos = _q.objetivo.posiciones.first.etiqueta.toUpperCase();
      pregunta = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _panel(esquema),
            child: Column(
              children: [
                Text('¿QUIÉN ES?', style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                  '$pos · ${_q.objetivo.tramo}',
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final (v, e) in [
                      (s.ppp.toStringAsFixed(1), 'PPP'),
                      (s.rpp.toStringAsFixed(1), 'RPP'),
                      (s.app.toStringAsFixed(1), 'APP'),
                      ((s.pctTc * 100).toStringAsFixed(0), '%TC'),
                    ])
                      Column(
                        children: [
                          TextoLed(v, tamano: 24),
                          Text(e, style: tema.textTheme.labelSmall),
                        ],
                      ),
                  ],
                ),
                if (contestada) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${_q.objetivo.nombre} · ${_q.objetivo.tramoConEquipo} · media ${_q.objetivo.media}',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _q.opciones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: ValueKey('opcion-$i'),
                onPressed: () => _responder(i),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: colorOpcion(i) ?? esquema.outline, width: colorOpcion(i) == null ? 1 : 2),
                ),
                child: Row(
                  children: [
                    Escudo(identidadDe(_q.opciones[i]), tamano: 24),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_q.opciones[i].nombre, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(_q.opciones[i].equipo, style: tema.textTheme.labelSmall),
                    if (contestada && (i == _q.correcta || i == _respuesta)) ...[
                      const SizedBox(width: 8),
                      Icon(i == _q.correcta ? Icons.check_circle : Icons.cancel, size: 20),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    } else {
      Widget opcion(int i) {
        final j = _q.opciones[i];
        final borde = colorOpcion(i);
        return Expanded(
          child: GestureDetector(
            key: ValueKey('opcion-$i'),
            onTap: () => _responder(i),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _panel(esquema, borde: borde),
              child: Column(
                children: [
                  Escudo(identidadDe(j), tamano: 40),
                  const SizedBox(height: 6),
                  Text(j.nombre, textAlign: TextAlign.center, maxLines: 2, style: tema.textTheme.titleSmall),
                  Text(
                    '${j.posiciones.first.etiqueta} · ${j.tramoConEquipo}',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  contestada ? TextoLed('${j.media}', tamano: 32) : TextoLed('??', tamano: 32),
                  if (contestada && (i == _q.correcta || i == _respuesta))
                    Icon(i == _q.correcta ? Icons.check_circle : Icons.cancel, size: 22),
                ],
              ),
            ),
          ),
        );
      }

      pregunta = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿CUÁL TIENE MÁS MEDIA?',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [opcion(0), const SizedBox(width: 10), opcion(1)],
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.variante.nombre)),
      body: AnchoMaximo(
        ancho: 640,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            marcador,
            const SizedBox(height: 12),
            pregunta,
            const SizedBox(height: 12),
            if (contestada)
              FilledButton(
                onPressed: _siguiente,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(_ronda >= Adivina.rondas ? 'VER RESULTADO' : 'SIGUIENTE'),
              ),
          ],
        ),
      ),
    );
  }
}
