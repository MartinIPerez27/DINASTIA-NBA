import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/jugador_avatar.dart';
import '../widgets/texto_led.dart';

String _n1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

Franquicia _franq(String id) => franquiciaPorId(id);

/// Barra con nombre, valor y color (confianza, ánimo, fans, relación…).
class BarraNivel extends StatelessWidget {
  const BarraNivel({super.key, required this.etiqueta, required this.valor, this.maximo = 100, this.pie});

  final String etiqueta;
  final int valor;
  final int maximo;
  final String? pie;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final f = (valor / maximo).clamp(0.0, 1.0);
    final color = f >= 0.6 ? const Color(0xFF46C46E) : (f >= 0.35 ? const Color(0xFFF5B83D) : const Color(0xFFE5484D));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(etiqueta, style: tema.textTheme.bodySmall)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: f,
                minHeight: 7,
                color: color,
                backgroundColor: tema.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(pie ?? '$valor', textAlign: TextAlign.end, style: tema.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

String _etiquetaConfianza(int c) => c >= 80
    ? 'Intocable'
    : c >= 60
    ? 'Titular'
    : c >= 35
    ? 'A prueba'
    : 'En duda';

/// Marco común de un panel de la carrera.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.destacado = false});

  final Widget child;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: destacado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.6),
          width: destacado ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// Atributos con botones para subirlos, y las insignias. Se usa en el receso y en la pantalla de tu jugador.
class PanelAtributos extends StatelessWidget {
  const PanelAtributos({super.key, required this.estado, required this.carrera, required this.onSubir});

  final EstadoCarrera estado;
  final CarreraJugador carrera;
  final ValueChanged<Atributo> onSubir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('PUNTOS DE HABILIDAD', style: tema.textTheme.labelLarge),
            const Spacer(),
            TextoLed('${estado.phBanco}', tamano: 26),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Los ganás jugando bien, cumpliendo los objetivos y con los premios. Cuanto más alto el atributo, más '
          'cuesta subirlo.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final a in Atributo.values)
          _FilaAtributo(
            atributo: a,
            valor: estado.atributos[a],
            cambio: estado.atributos[a] - estado.atributosBase[a],
            costo: ModeloCarrera.costo(estado.atributos[a]),
            puede: carrera.puedeSubir(estado, a),
            onSubir: () => onSubir(a),
          ),
        const SizedBox(height: 12),
        Text('INSIGNIAS', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in Insignia.values)
              Tooltip(
                message: i.descripcion,
                child: Chip(
                  avatar: Icon(
                    i.la(estado.atributos) ? Icons.verified : Icons.lock_outline,
                    size: 16,
                    color: i.la(estado.atributos) ? esquema.primary : esquema.onSurfaceVariant,
                  ),
                  label: Text(i.etiqueta),
                  side: BorderSide(color: i.la(estado.atributos) ? esquema.primary : esquema.outlineVariant),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tocá una insignia para ver qué pide. Las ganadas suman a tus estadísticas.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _FilaAtributo extends StatelessWidget {
  const _FilaAtributo({
    required this.atributo,
    required this.valor,
    required this.cambio,
    required this.costo,
    required this.puede,
    required this.onSubir,
  });

  final Atributo atributo;
  final int valor, cambio, costo;
  final bool puede;
  final VoidCallback onSubir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(atributo.etiqueta, style: tema.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: valor / 99, minHeight: 6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 36, child: TextoLed('$valor', tamano: 20)),
          SizedBox(
            width: 34,
            child: Text(
              cambio == 0 ? '' : (cambio > 0 ? '+$cambio' : '$cambio'),
              style: tema.textTheme.labelSmall?.copyWith(color: cambio >= 0 ? esquema.primary : esquema.error),
            ),
          ),
          FilledButton.tonal(
            onPressed: puede ? onSubir : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(valor >= 99 ? 'MÁX.' : '+1 · $costo'),
          ),
        ],
      ),
    );
  }
}

/// La línea de estadísticas de la carta de tu jugador (lo que usa el motor del partido).
class LineaCarta extends StatelessWidget {
  const LineaCarta({super.key, required this.carta});

  final Jugador carta;

  @override
  Widget build(BuildContext context) {
    final s = carta.stats;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _Celda('PPP', _n1(s.ppp)),
        _Celda('RPP', _n1(s.rpp)),
        _Celda('APP', _n1(s.app)),
        _Celda('ROB', _n1(s.robP)),
        _Celda('TAP', _n1(s.tapP)),
        _Celda('%T3', '${(s.pctT3 * 100).round()}'),
        _Celda('%TC', '${(s.pctTc * 100).round()}'),
        _Celda('IQ', '${s.iq}'),
      ],
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda(this.etiqueta, this.valor);

  final String etiqueta, valor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextoLed(valor, tamano: 18),
      Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

/// Tarjeta de tu jugador en la temporada: papel, confianza, puntos de habilidad y objetivos.
class TarjetaMiJugador extends StatelessWidget {
  const TarjetaMiJugador({super.key, required this.estado, required this.marca, required this.onAbrir});

  final EstadoCarrera estado;
  final MarcaTemporada marca;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final carta = estado.carta;
    return _Panel(
      destacado: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Escudo(_franq(estado.franquiciaId), tamano: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estado.nombre.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 0.5),
                    ),
                    Text(
                      '${estado.etiquetaTemporada} · ${estado.edad} años · ${estado.rolEquipo.etiqueta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextoLed('${carta.media}', tamano: 30),
            ],
          ),
          const SizedBox(height: 8),
          BarraNivel(etiqueta: 'Confianza DT', valor: estado.confianza, pie: _etiquetaConfianza(estado.confianza)),
          BarraNivel(etiqueta: 'Ánimo', valor: estado.moral),
          const SizedBox(height: 6),
          Text(
            marca.pj == 0
                ? 'Todavía no jugaste.'
                : '${_n1(marca.ppg)} pts · ${_n1(marca.rpg)} reb · ${_n1(marca.apg)} ast en ${marca.pj} partidos',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          for (final o in estado.objetivos)
            Builder(
              builder: (context) {
                final (v, ok) = o.avance(marca);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Icon(
                        ok ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: ok ? esquema.primary : esquema.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          o.texto,
                          style: tema.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (o.tipo != TipoObjetivo.playoffs && o.tipo != TipoObjetivo.allStar)
                        Text(
                          o.tipo == TipoObjetivo.victorias || o.tipo == TipoObjetivo.partidos ? '${v.round()}' : _n1(v),
                          style: tema.textTheme.bodySmall,
                        ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAbrir,
            icon: const Icon(Icons.trending_up),
            label: Text(estado.phBanco > 0 ? 'MEJORAR · ${estado.phBanco} PUNTOS' : 'MI JUGADOR'),
          ),
        ],
      ),
    );
  }
}

/// Tu jugador a fondo, durante la temporada: gastá los puntos, mirá tu ánimo y tus objetivos.
class MiJugadorPantalla extends StatefulWidget {
  const MiJugadorPantalla({super.key, required this.temporada, required this.carrera, required this.onCambiar});

  final Temporada temporada;
  final CarreraJugador carrera;

  /// Devuelve la temporada ya con los cambios (para guardarla y refrescar el inicio).
  final ValueChanged<Temporada> onCambiar;

  @override
  State<MiJugadorPantalla> createState() => _MiJugadorPantallaState();
}

class _MiJugadorPantallaState extends State<MiJugadorPantalla> {
  late Temporada _t = widget.temporada;

  EstadoCarrera get _e => EstadoCarrera.de(_t)!;

  void _subir(Atributo a) {
    final e = widget.carrera.subir(_e, a);
    setState(() => _t = widget.carrera.sincronizar(_t, e));
    widget.onCambiar(_t);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = _e;
    final carta = e.carta;
    final marca = widget.carrera.marca(_t, e);
    final izquierda = <Widget>[
      _Panel(
        destacado: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 62,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: JugadorAvatar(jugador: carta, franquicia: _franq(e.franquiciaId)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleLarge),
                      Text(
                        '${e.posicion.etiqueta} · ${carta.rol.etiqueta}',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                      Text(
                        '${e.edad} años · contrato: ${e.contrato} ${e.contrato == 1 ? 'temporada' : 'temporadas'}',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextoLed('${carta.media}', tamano: 36),
              ],
            ),
            const SizedBox(height: 10),
            LineaCarta(carta: carta),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TU LUGAR EN EL EQUIPO', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            BarraNivel(etiqueta: 'Confianza DT', valor: e.confianza, pie: _etiquetaConfianza(e.confianza)),
            BarraNivel(etiqueta: 'Ánimo', valor: e.moral),
            BarraNivel(etiqueta: 'Fans', valor: e.fans),
            BarraNivel(etiqueta: 'Vestuario', valor: e.relacion),
            const SizedBox(height: 4),
            Text(
              'Jugás de ${e.rolEquipo.etiqueta.toLowerCase()}. Rendir sube la confianza; con confianza alta pasás a '
              'titular, con poca vas al banco. El vestuario y el ánimo mueven tus estadísticas.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OBJETIVOS DEL DT', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final o in e.objetivos)
              Builder(
                builder: (context) {
                  final (v, ok) = o.avance(marca);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(ok ? Icons.check_circle : Icons.flag_outlined, color: ok ? esquema.primary : null),
                    title: Text(o.texto),
                    trailing: o.tipo == TipoObjetivo.playoffs || o.tipo == TipoObjetivo.allStar
                        ? null
                        : Text(
                            o.tipo == TipoObjetivo.victorias || o.tipo == TipoObjetivo.partidos
                                ? '${v.round()}/${o.meta.round()}'
                                : '${_n1(v)}/${_n1(o.meta)}',
                          ),
                  );
                },
              ),
            Text(
              'Cada objetivo cumplido da 3 puntos de habilidad y confianza al final de la temporada.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ];
    final derecha = <Widget>[
      _Panel(
        child: PanelAtributos(estado: e, carrera: widget.carrera, onSubir: _subir),
      ),
    ];
    const relleno = EdgeInsets.fromLTRB(16, 8, 16, 24);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi jugador')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ListView(padding: relleno, children: izquierda),
                  ),
                  Expanded(
                    flex: 5,
                    child: ListView(padding: relleno, children: derecha),
                  ),
                ],
              )
            : ListView(padding: relleno, children: [...izquierda, const SizedBox(height: 12), ...derecha]),
      ),
    );
  }
}

// ===========================================================================================
// Receso
// ===========================================================================================

enum _Paso { resumen, entrenar, prensa, contrato, retiro }

/// Entre temporada y temporada: el resumen, entrenar, la prensa, el contrato y, a veces, el retiro.
/// Cada paso se guarda, así que podés cerrar la app y seguir donde quedaste.
class RecesoJugadorPantalla extends StatefulWidget {
  const RecesoJugadorPantalla({
    super.key,
    required this.temporada,
    required this.estado,
    required this.carrera,
    required this.cierre,
    required this.onEstado,
    required this.onSeguir,
    required this.onRetirar,
  });

  /// La temporada terminada (con los playoffs).
  final Temporada temporada;
  final EstadoCarrera estado;
  final CarreraJugador carrera;

  /// Lo que pasó al cerrar (null al retomar un receso ya empezado).
  final CierreTemporada? cierre;

  /// Se llama con cada cambio del estado, para guardarlo.
  final ValueChanged<EstadoCarrera> onEstado;

  /// Arranca la temporada siguiente (con la oferta elegida, si hubo).
  final void Function(EstadoCarrera estado, OfertaContrato? oferta) onSeguir;

  /// Te retirás: se cierra la carrera.
  final ValueChanged<EstadoCarrera> onRetirar;

  @override
  State<RecesoJugadorPantalla> createState() => _RecesoJugadorPantallaState();
}

class _RecesoJugadorPantallaState extends State<RecesoJugadorPantalla> {
  late EstadoCarrera _e = widget.estado;
  late _Paso _paso = widget.cierre == null ? _Paso.entrenar : _Paso.resumen;
  OfertaContrato? _oferta;
  late var _pidioTraspaso = widget.estado.pidioTraspaso;
  RespuestaPrensa? _respondida;

  void _cambiar(EstadoCarrera e) {
    setState(() => _e = e);
    widget.onEstado(e);
  }

  bool get _vencido => _e.contrato <= 0;
  bool get _hayContrato => _vencido || _pidioTraspaso;
  bool get _hayRetiro => CarreraJugador.puedeRetirarse(_e);

  List<_Paso> get _pasos => [
    if (widget.cierre != null) _Paso.resumen,
    _Paso.entrenar,
    _Paso.prensa,
    _Paso.contrato,
    if (_hayRetiro) _Paso.retiro,
  ];

  void _siguiente() {
    final pasos = _pasos;
    final i = pasos.indexOf(_paso);
    if (i < pasos.length - 1) {
      setState(() => _paso = pasos[i + 1]);
    } else {
      widget.onSeguir(_e, _oferta);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pasos = _pasos;
    final indice = pasos.indexOf(_paso);
    final ultimo = indice == pasos.length - 1;
    final bloqueado = switch (_paso) {
      _Paso.prensa => _e.prensaHecha < 2,
      _Paso.contrato => _hayContrato && _oferta == null,
      _ => false,
    };
    final forzoso = CarreraJugador.retiroForzoso(_e);
    return Scaffold(
      appBar: AppBar(title: Text('Receso · ${_e.etiquetaDe(_e.numero + 1)}')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  for (var i = 0; i < pasos.length; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= indice ? tema.colorScheme.primary : tema.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < pasos.length - 1) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
            Expanded(
              child: AnchoMaximo(
                ancho: 900,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: switch (_paso) {
                    _Paso.resumen => _pasoResumen(context),
                    _Paso.entrenar => _pasoEntrenar(context),
                    _Paso.prensa => _pasoPrensa(context),
                    _Paso.contrato => _pasoContrato(context),
                    _Paso.retiro => _pasoRetiro(context, forzoso),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _paso == _Paso.retiro && forzoso
                  ? const SizedBox.shrink()
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: bloqueado ? null : _siguiente,
                        child: Text(ultimo ? 'ARRANCAR LA TEMPORADA ${_e.numero + 1}' : 'CONTINUAR'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Resumen ----------

  Widget _pasoResumen(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final c = widget.cierre!;
    final s = c.temporada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FIN DE LA TEMPORADA ${s.numero}', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _Panel(
          destacado: s.campeon,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Escudo(_franq(s.franquiciaId), tamano: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.campeon ? '¡CAMPEÓN!' : s.resultado.toUpperCase(),
                      style: tema.textTheme.titleLarge?.copyWith(color: s.campeon ? esquema.primary : null),
                    ),
                  ),
                  TextoLed('${s.victorias}-${s.derrotas}', tamano: 26),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${_n1(s.pts)} pts · ${_n1(s.reb)} reb · ${_n1(s.ast)} ast en ${s.pj} partidos',
                style: tema.textTheme.titleMedium,
              ),
              if (s.allStar || s.premios.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (s.allStar) const Chip(label: Text('All-Star'), visualDensity: VisualDensity.compact),
                    for (final p in s.premios) Chip(label: Text(p), visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OBJETIVOS DEL DT', style: tema.textTheme.labelLarge),
              for (final (o, ok) in c.objetivos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    ok ? Icons.check_circle : Icons.cancel_outlined,
                    color: ok ? esquema.primary : esquema.error,
                  ),
                  title: Text(o.texto),
                  trailing: Text(ok ? '+3' : '—'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PUNTOS DE HABILIDAD GANADOS', style: tema.textTheme.labelLarge),
              const SizedBox(height: 4),
              _Linea('Por tu juego', '+${c.phBase}'),
              _Linea('Objetivos', '+${c.phObjetivos}'),
              _Linea('Premios y título', '+${c.phPremios}'),
              const Divider(),
              _Linea('Total disponible', '${c.estado.phBanco}', fuerte: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TU CUERPO Y TU CABEZA, A LOS ${c.estado.edad}', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final a in Atributo.values)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        (c.desarrollo[a] ?? 0) > 0
                            ? Icons.arrow_upward
                            : ((c.desarrollo[a] ?? 0) < 0 ? Icons.arrow_downward : Icons.remove),
                        size: 14,
                      ),
                      label: Text('${a.etiqueta} ${(c.desarrollo[a] ?? 0) > 0 ? '+' : ''}${c.desarrollo[a] ?? 0}'),
                    ),
                ],
              ),
              for (final i in c.insigniasNuevas) ...[
                const SizedBox(height: 8),
                Text(
                  '¡Insignia desbloqueada: ${i.etiqueta}! ${i.descripcion}',
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Entrenar ----------

  Widget _pasoEntrenar(BuildContext context) {
    final tema = Theme.of(context);
    final carta = _e.carta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ENTRENAMIENTO', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Gastá tus puntos en el receso. Podés guardar algunos para después.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _Panel(
          child: Row(
            children: [
              TextoLed('${carta.media}', tamano: 34),
              const SizedBox(width: 12),
              Expanded(child: LineaCarta(carta: carta)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: PanelAtributos(
            estado: _e,
            carrera: widget.carrera,
            onSubir: (a) => _cambiar(widget.carrera.subir(_e, a)),
          ),
        ),
      ],
    );
  }

  // ---------- Prensa ----------

  Widget _pasoPrensa(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final preguntas = widget.carrera.preguntasDelReceso(_e);
    final hecha = _e.prensaHecha;
    if (hecha >= preguntas.length) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONFERENCIA DE PRENSA', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (_respondida case final r?) _Reaccion(r),
          const SizedBox(height: 8),
          _Panel(
            child: Column(
              children: [
                BarraNivel(etiqueta: 'Confianza DT', valor: _e.confianza, pie: _etiquetaConfianza(_e.confianza)),
                BarraNivel(etiqueta: 'Ánimo', valor: _e.moral),
                BarraNivel(etiqueta: 'Fans', valor: _e.fans),
                BarraNivel(etiqueta: 'Vestuario', valor: _e.relacion),
              ],
            ),
          ),
        ],
      );
    }
    final idx = hecha.clamp(0, preguntas.length - 1);
    final pregunta = preguntas[idx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONFERENCIA DE PRENSA', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Pregunta ${idx + 1} de ${preguntas.length}',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (_respondida case final r? when hecha > 0) _Reaccion(r),
        _Panel(
          destacado: true,
          child: Row(
            children: [
              const Icon(Icons.mic_none),
              const SizedBox(width: 10),
              Expanded(child: Text(pregunta.texto, style: tema.textTheme.titleMedium)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final r in pregunta.respuestas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () {
                _respondida = r;
                _cambiar(widget.carrera.responderPrensa(_e, r));
              },
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(r.texto, textAlign: TextAlign.start),
            ),
          ),
      ],
    );
  }

  // ---------- Contrato ----------

  Widget _pasoContrato(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final mostrarOfertas = _hayContrato;
    final ofertas = mostrarOfertas
        ? widget.carrera.ofertas(widget.temporada, _e, traspaso: _pidioTraspaso && !_vencido)
        : const <OfertaContrato>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_vencido ? 'AGENCIA LIBRE' : 'TU CONTRATO', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (!mostrarOfertas) ...[
          _Panel(
            child: Row(
              children: [
                Escudo(_franq(_e.franquiciaId), tamano: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seguís en ${_franq(_e.franquiciaId).nombreCompleto}: te quedan ${_e.contrato} '
                    '${_e.contrato == 1 ? 'temporada' : 'temporadas'} de contrato.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_e.numero >= 2)
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _pidioTraspaso = true);
                _cambiar(
                  _e.copyWith(
                    pidioTraspaso: true,
                    moral: _e.moral - 8,
                    confianza: _e.confianza - 5,
                    hitos: [..._e.hitos, '${_e.etiquetaTemporada}: ${_e.nombre} pide el traspaso.'],
                  ),
                );
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('PEDIR EL TRASPASO'),
            ),
          if (_e.numero >= 2)
            Text(
              'Te cuesta ánimo y confianza, pero te llegan ofertas de otros equipos.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
        ] else ...[
          Text(
            _vencido
                ? 'Se te terminó el contrato. Elegí dónde seguís: el papel que te ofrecen decide tu confianza inicial.'
                : 'Pediste el traspaso. Elegí un destino.',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          for (final o in ofertas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TarjetaOferta(
                oferta: o,
                elegida: _oferta == o || (_oferta?.franquiciaId == o.franquiciaId),
                onTap: () => setState(() => _oferta = o),
              ),
            ),
          if (!_vencido)
            TextButton(
              onPressed: () {
                setState(() {
                  _pidioTraspaso = false;
                  _oferta = null;
                });
                _cambiar(_e.copyWith(pidioTraspaso: false));
              },
              child: const Text('Mejor me quedo'),
            ),
        ],
      ],
    );
  }

  // ---------- Retiro ----------

  Widget _pasoRetiro(BuildContext context, bool forzoso) {
    final tema = Theme.of(context);
    final legado = _e.legado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(forzoso ? 'EL CUERPO DIJO BASTA' : '¿SEGUÍS O TE RETIRÁS?', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_e.nombre}, ${_e.edad} años · media ${_e.media}', style: tema.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                '${legado.anillos} anillos · ${legado.allStars} All-Star · ${legado.puntos} puntos de carrera',
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(legado.veredicto, style: tema.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => widget.onRetirar(_e),
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('ME RETIRO'),
        ),
        if (!forzoso) ...[
          const SizedBox(height: 8),
          Text(
            'Si seguís, arrancás la temporada ${_e.numero + 1}. A estas edades el físico cae cada año.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.texto, this.valor, {this.fuerte = false});

  final String texto, valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = fuerte ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _Reaccion extends StatelessWidget {
  const _Reaccion(this.r);

  final RespuestaPrensa r;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget efecto(String etiqueta, int v) => v == 0
        ? const SizedBox.shrink()
        : Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(v > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
            label: Text('$etiqueta ${v > 0 ? '+' : ''}$v'),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${r.texto}"', style: tema.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text(r.reaccion, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            Wrap(
              spacing: 6,
              children: [
                efecto('Confianza', r.confianza),
                efecto('Ánimo', r.moral),
                efecto('Fans', r.fans),
                efecto('Vestuario', r.relacion),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaOferta extends StatelessWidget {
  const _TarjetaOferta({required this.oferta, required this.elegida, required this.onTap});

  final OfertaContrato oferta;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final f = _franq(oferta.franquiciaId);
    return Material(
      color: elegida ? esquema.primary.withValues(alpha: 0.12) : esquema.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: elegida ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.6),
          width: elegida ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Escudo(f, tamano: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oferta.renovacion ? 'Renovar con ${f.nombre}' : f.nombreCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium,
                    ),
                    Text(
                      '${oferta.rol.etiqueta} · ${oferta.anios} ${oferta.anios == 1 ? 'año' : 'años'}',
                      style: tema.textTheme.bodyMedium,
                    ),
                    Text(
                      oferta.rival == null
                          ? 'Plantel de media ${oferta.nivelEquipo}'
                          : 'Competís con ${oferta.rival!.$1} (${oferta.rival!.$2}) · plantel de media ${oferta.nivelEquipo}',
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(elegida ? Icons.check_circle : Icons.circle_outlined, color: elegida ? esquema.primary : null),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================================
// Legado
// ===========================================================================================

/// La carrera completa: totales, anillos, premios, veredicto del Salón y la línea de tiempo.
class LegadoCarreraPantalla extends StatelessWidget {
  const LegadoCarreraPantalla({super.key, required this.estado, required this.carrera, this.alInicio});

  final EstadoCarrera estado;
  final CarreraJugador carrera;

  /// Al terminar la carrera (retirado): volver al inicio.
  final VoidCallback? alInicio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final l = estado.legado;
    final lineas = carrera.narrar(estado);
    final totales = _Panel(
      destacado: l.salon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(estado.nombre.toUpperCase(), style: tema.textTheme.headlineSmall)),
              TextoLed('${l.mejorMedia}', tamano: 30),
            ],
          ),
          Text(
            estado.retirado ? 'Retirado a los ${estado.edad} años' : '${estado.edad} años · temporada ${estado.numero}',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Celda('PARTIDOS', '${l.partidos}'),
              _Celda('PUNTOS', '${l.puntos}'),
              _Celda('REBOTES', '${l.rebotes}'),
              _Celda('ASIST.', '${l.asistencias}'),
              _Celda('ANILLOS', '${l.anillos}'),
              _Celda('ALL-STAR', '${l.allStars}'),
              _Celda('MVP', '${l.mvps}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(l.salon ? Icons.emoji_events : Icons.history_edu, color: l.salon ? esquema.primary : null),
              const SizedBox(width: 8),
              Expanded(child: Text(l.veredicto, style: tema.textTheme.titleMedium)),
            ],
          ),
        ],
      ),
    );
    final historia = _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LÍNEA DE TIEMPO', style: tema.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final h in estado.hitos.take(1)) _Hito(h),
          for (final s in lineas) _Hito(s, principal: true),
          for (final h
              in estado.hitos
                  .skip(1)
                  .where((x) => x.contains('retira') || x.contains('firma') || x.contains('traspaso')))
            _Hito(h),
          if (lineas.isEmpty && estado.hitos.length <= 1) const Text('Todavía no jugaste ninguna temporada.'),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Historia de tu carrera')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 8, 24), children: [totales]),
                  ),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(8, 8, 16, 24), children: [historia]),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  totales,
                  const SizedBox(height: 12),
                  historia,
                  if (alInicio != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(onPressed: alInicio, child: const Text('VOLVER AL INICIO')),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Hito extends StatelessWidget {
  const _Hito(this.texto, {this.principal = false});

  final String texto;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: principal ? 9 : 6, color: tema.colorScheme.primary),
          ),
          Expanded(child: Text(texto, style: principal ? tema.textTheme.bodyMedium : tema.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// ===========================================================================================
// Elegir jugador real, combine y noche del draft
// ===========================================================================================

/// Elegí el jugador real con el que arrancás la carrera (su carta más temprana).
class ElegirJugadorRealPantalla extends StatefulWidget {
  const ElegirJugadorRealPantalla({super.key, required this.carrera});

  final CarreraJugador carrera;

  @override
  State<ElegirJugadorRealPantalla> createState() => _ElegirJugadorRealPantallaState();
}

class _ElegirJugadorRealPantallaState extends State<ElegirJugadorRealPantalla> {
  var _texto = '';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lista = widget.carrera.candidatosReales(texto: _texto, limite: 80);
    return Scaffold(
      appBar: AppBar(title: const Text('Elegí tu jugador')),
      body: SafeArea(
        child: AnchoMaximo(
          ancho: 760,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscá por nombre (Jordan, Jokić, Kobe…)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _texto = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Arrancás en su año de novato, con su equipo y su elección real del draft. Después, la carrera la '
                  'escribís vos.',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: lista.isEmpty
                    ? const Center(child: Text('No hay jugadores con ese nombre.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                        itemCount: lista.length,
                        itemBuilder: (context, i) {
                          final j = lista[i];
                          return ListTile(
                            leading: SizedBox(width: 48, child: Center(child: TextoLed('${j.media}', tamano: 22))),
                            title: Text(j.nombre),
                            subtitle: Text(
                              '${j.posiciones.first.etiqueta} · ${j.rol.etiqueta} · ${j.tramoConEquipo}'
                              '${j.draft == null ? '' : ' · draft ${j.draft!.$1}, n.º ${j.draft!.$2}'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).pop(j),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El combine de la carrera de un jugador creado: las pruebas aparecen de a una.
class CombinePantalla extends StatefulWidget {
  const CombinePantalla({super.key, required this.creado, required this.resultado});

  final JugadorCreado creado;
  final ResultadoCombine resultado;

  @override
  State<CombinePantalla> createState() => _CombinePantallaState();
}

class _CombinePantallaState extends State<CombinePantalla> {
  var _vistas = 0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final r = widget.resultado;
    final termino = _vistas >= r.pruebas.length;
    return Scaffold(
      appBar: AppBar(title: const Text('El combine')),
      body: SafeArea(
        child: AnchoMaximo(
          ancho: 700,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Los scouts te miran de arriba abajo, ${widget.creado.nombre.split(' ').first}. Tocá cada prueba para ver cómo te va.',
                  style: tema.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < r.pruebas.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: i < _vistas
                              ? _Panel(
                                  child: Row(
                                    children: [
                                      TextoLed('${r.pruebas[i].nota}', tamano: 30),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.pruebas[i].nombre, style: tema.textTheme.titleMedium),
                                            Text(r.pruebas[i].comentario, style: tema.textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: i == _vistas ? () => setState(() => _vistas++) : null,
                                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                                  child: Text(
                                    i == _vistas ? 'HACER: ${r.pruebas[i].nombre.toUpperCase()}' : r.pruebas[i].nombre,
                                  ),
                                ),
                        ),
                      if (termino)
                        _Panel(
                          destacado: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PROYECCIÓN DE LOS SCOUTS', style: tema.textTheme.labelLarge),
                              const SizedBox(height: 4),
                              Text(
                                r.sinDraft
                                    ? 'Nadie te proyecta en el draft. Tendrás que ganarte un lugar firmando como agente libre.'
                                    : 'Te proyectan en la ${r.ronda == 1 ? 'primera' : 'segunda'} ronda, alrededor del puesto ${r.pick}.',
                                style: tema.textTheme.titleMedium?.copyWith(color: esquema.primary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: termino ? () => Navigator.of(context).pop(true) : null,
                  child: const Text('IR A LA NOCHE DEL DRAFT'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La noche del draft: te eligen (o no) y firmás con tu equipo. Devuelve el id de la franquicia.
class NocheDraftPantalla extends StatelessWidget {
  const NocheDraftPantalla({
    super.key,
    required this.nombre,
    required this.pick,
    required this.franquiciaId,
    this.anio,
    this.opciones = const [],
    this.real = false,
  });

  final String nombre;
  final int pick;
  final String franquiciaId;
  final int? anio;

  /// Sin draft: tres equipos que te ofrecen un contrato.
  final List<String> opciones;
  final bool real;

  bool get sinDraft => pick > 50;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(anio == null ? 'Noche del draft' : 'Draft $anio')),
      body: SafeArea(
        child: AnchoMaximo(
          ancho: 640,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                if (sinDraft) ...[
                  Text('SE ACABÓ EL DRAFT', style: tema.textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Nadie dijo tu nombre, pero tres equipos te llaman con un contrato de dos años. Elegí uno.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final id in opciones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(id),
                        icon: Escudo(_franq(id), tamano: 28),
                        label: Text(_franq(id).nombreCompleto),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      ),
                    ),
                ] else ...[
                  Center(child: TextoLed('N.º $pick', tamano: 44)),
                  const SizedBox(height: 16),
                  Center(child: Escudo(_franq(franquiciaId), tamano: 96)),
                  const SizedBox(height: 16),
                  Text(
                    real
                        ? '${_franq(franquiciaId).nombreCompleto} elige a $nombre'
                        : 'Con el puesto $pick, ${_franq(franquiciaId).nombreCompleto} elige a $nombre',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pick <= 14
                        ? 'Una elección de lotería: el equipo cuenta con vos desde el primer día.'
                        : pick <= 30
                        ? 'Primera ronda: tendrás que ganarte los minutos.'
                        : 'Segunda ronda: contrato corto y mucho por demostrar.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                if (!sinDraft)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(franquiciaId),
                    child: Text('FIRMAR CON ${_franq(franquiciaId).nombre.toUpperCase()}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
