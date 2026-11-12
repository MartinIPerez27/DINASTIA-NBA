import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/rival.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/mercado.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/escudo.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';

/// Mercado de pases: elegís a quién das, a qué equipo y a quién pedís; el rival contesta en el
/// momento (regla fija) y, si dice que sí, confirmás el pase.
class MercadoPantalla extends StatefulWidget {
  const MercadoPantalla({super.key, required this.temporada, required this.liga, required this.onCambio});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  @override
  State<MercadoPantalla> createState() => _MercadoPantallaState();
}

class _MercadoPantallaState extends State<MercadoPantalla> {
  late Temporada _t = widget.temporada;
  late final _mercado = Mercado(widget.liga);
  Jugador? _mio;
  String? _rival;
  Jugador? _suyo;
  Respuesta? _respuesta;
  String? _hecho;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Franquicia _identidad(String id) => franquiciaPorId(_t.rivales[id]!.identidadId);

  String _nombre(String id) {
    final r = _t.rivales[id]!;
    return '${_identidad(id).nombreCompleto} (${r.tipo == TipoRival.epoca ? r.epoca!.corta : 'Histórico'})';
  }

  Jugador? _carta(String id) {
    for (final j in _t.plantel.jugadores) {
      if (j.id == id) return j;
    }
    return widget.liga.jugador(id);
  }

  void _proponer() {
    final mio = _mio, rival = _rival, suyo = _suyo;
    if (mio == null || rival == null || suyo == null) return;
    setState(() => _respuesta = _mercado.evaluar(_t, mio, rival, suyo));
    _respuesta!.acepta ? Haptica.media() : Haptica.ligera();
  }

  void _confirmar() {
    final nueva = _mercado.ejecutar(_t, _mio!, _rival!, _suyo!);
    widget.onCambio(nueva);
    Haptica.fuerte();
    setState(() {
      _hecho = '${_mio!.nombre} se va a los ${_identidad(_rival!).nombre}; llega ${_suyo!.nombre}.';
      _t = nueva;
      _mio = _suyo = _respuesta = null;
      _rival = null;
    });
    // El aviso del pase queda arriba, junto a la fecha límite.
    if (_scroll.hasClients) {
      MediaQuery.disableAnimationsOf(context)
          ? _scroll.jumpTo(0)
          : _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final abierto = _mercado.abierto(_t);
    final rivales = _t.rivales.keys.toList()..sort((a, b) => _identidad(a).nombre.compareTo(_identidad(b).nombre));
    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Text(texto, style: tema.textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mercado de pases')),
      body: SafeArea(
        top: false,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Encabezado(
              limite: _mercado.jornadaLimite(_t),
              restantes: _mercado.pasesRestantes(_t),
              abierto: abierto,
              motivo: _mercado.motivoCierre(_t),
            ),
            if (_hecho case final h?) ...[const SizedBox(height: 12), _Aviso(texto: h, positivo: true)],
            if (abierto) ...[
              titulo('1. ¿A quién das?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in Posicion.values)
                    if (_t.plantel.en(p) case final j?)
                      _ConPuesto(
                        puesto: p,
                        lesionado: (_t.lesiones[j.id] ?? 0) > 0,
                        child: CartaJugador(
                          key: ValueKey('mia-${j.id}'),
                          jugador: j,
                          seleccionada: _mio?.id == j.id,
                          onTap: () => setState(() {
                            _mio = j;
                            _respuesta = null;
                          }),
                        ),
                      ),
                ],
              ),
              if (_mio != null) ...[
                titulo('2. ¿A qué equipo?'),
                GridView.count(
                  crossAxisCount: (MediaQuery.sizeOf(context).width / 92).floor().clamp(3, 8),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.95,
                  children: [
                    for (final id in rivales)
                      Semantics(
                        button: true,
                        selected: _rival == id,
                        label: _nombre(id),
                        child: InkWell(
                          key: ValueKey('rival-$id'),
                          onTap: () => setState(() {
                            _rival = id;
                            _suyo = null;
                            _respuesta = null;
                          }),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _rival == id ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.4),
                                width: _rival == id ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Escudo(_identidad(id), tamano: 36),
                                const SizedBox(height: 4),
                                Text(
                                  _t.rivales[id]!.tipo == TipoRival.epoca ? _t.rivales[id]!.epoca!.corta : 'Hist.',
                                  style: tema.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (_rival case final rival?) ...[
                titulo('3. ¿A quién pedís de los ${_nombre(rival)}?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (p, j) in _mercado.pedibles(_t, rival))
                      _ConPuesto(
                        puesto: p,
                        lesionado: (_t.lesiones[j.id] ?? 0) > 0,
                        child: CartaJugador(
                          key: ValueKey('suya-${j.id}'),
                          jugador: j,
                          seleccionada: _suyo?.id == j.id,
                          onTap: () => setState(() {
                            _suyo = j;
                            _respuesta = null;
                          }),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _suyo == null ? null : _proponer,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(
                    _suyo == null
                        ? 'ELEGÍ A QUIÉN PEDÍS'
                        : 'PROPONER ${_mio!.nombre} POR ${_suyo!.nombre}'.toUpperCase(),
                  ),
                ),
              ],
              if (_respuesta case final r?) ...[
                const SizedBox(height: 12),
                _Aviso(texto: r.motivo, positivo: r.acepta),
                const SizedBox(height: 8),
                if (r.acepta)
                  FilledButton.icon(
                    onPressed: _confirmar,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('CONFIRMAR PASE'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  )
                else if (r.contraoferta case final c?)
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _mio = c;
                      _respuesta = _mercado.evaluar(_t, c, _rival!, _suyo!);
                    }),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text('Por ${c.nombre} sí aceptarían: ofrecelo'),
                  ),
              ],
            ],
            if (_t.pases.isNotEmpty) ...[
              titulo('Pases de esta temporada'),
              for (final p in _t.pases)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Escudo(
                    franquiciaPorId(_t.rivales[p.franquiciaId]?.identidadId ?? p.franquiciaId),
                    tamano: 32,
                  ),
                  title: Text('${_carta(p.dioId)?.nombre ?? '–'} ⇄ ${_carta(p.recibioId)?.nombre ?? '–'}'),
                  subtitle: Text('Jornada ${p.jornada} · con los ${franquiciaPorId(p.franquiciaId).nombre}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.limite, required this.restantes, required this.abierto, this.motivo});

  final int limite, restantes;
  final bool abierto;
  final String? motivo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: abierto ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(abierto ? 'MERCADO ABIERTO' : 'MERCADO CERRADO', style: tema.textTheme.headlineSmall),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextoLed('J$limite', tamano: 24),
                  Text('FECHA LÍMITE', style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            abierto
                ? 'Cierra en la jornada $limite · quedan $restantes pase${restantes == 1 ? '' : 's'}. '
                      'Tu jugador ocupa el puesto del que pedís, y al revés.'
                : motivo ?? '',
            style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Carta con su puesto arriba (y aviso de lesión).
class _ConPuesto extends StatelessWidget {
  const _ConPuesto({required this.puesto, required this.child, this.lesionado = false});

  final Posicion puesto;
  final Widget child;
  final bool lesionado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          lesionado ? '${puesto.etiqueta} · LESIONADO' : puesto.etiqueta,
          style: tema.textTheme.labelSmall?.copyWith(
            color: lesionado ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Opacity(opacity: lesionado ? 0.5 : 1, child: child),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.positivo});

  final String texto;
  final bool positivo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: positivo ? esquema.primary : esquema.error),
        ),
        child: Row(
          children: [
            Icon(positivo ? Icons.handshake_outlined : Icons.block, color: positivo ? esquema.primary : esquema.error),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }
}
