import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/historia.dart';
import '../../domain/motor.dart';
import '../pantallas/partido_pantalla.dart';
import '../pantallas/playbook_pantalla.dart';
import '../pantallas/playoffs_pantalla.dart';
import '../pantallas/temporada_pantalla.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Historia de la NBA: temporadas reales, historias alternativas y finales reales.
bool esModoHistoria(ModoJuego m) =>
    const {ModoJuego.temporadaReal, ModoJuego.queHubiera, ModoJuego.ultimoCuarto}.contains(m);

Future<Map<String, Set<int>>>? _huecos;

/// La lógica de historia con los años exactos de las cartas con huecos (se cargan una vez).
Future<HistoriaNba> historiaDe(ContextoModos c) async {
  final liga = await c.liga();
  final huecos = await (_huecos ??= rootBundle
      .loadString('assets/database/temporadas_huecos.json')
      .then((s) => HistoriaNba.leerHuecos(jsonDecode(s) as Map<String, dynamic>))
      .catchError((Object _) => <String, Set<int>>{}));
  return HistoriaNba(liga, huecos: huecos);
}

String _nombre(String identidadId) => franquiciaPorId(identidadId).nombreCompleto;

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarHistoria(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  final contexto = c.context;
  final historia = await historiaDe(c);
  if (!contexto.mounted) return;
  final Temporada t;
  switch (m) {
    case ModoJuego.temporadaReal:
      final anio = await _elegirAnio(contexto);
      if (anio == null || !contexto.mounted) return;
      final franquicia = await _elegirEquipo(contexto, historia, anio);
      if (franquicia == null) return;
      t = historia.nuevaTemporada(id: ContextoModos.nuevoId(), franquiciaId: franquicia, anio: anio);
    case ModoJuego.queHubiera:
      final q = await _elegirHistoria(contexto);
      if (q == null) return;
      t = historia.nuevaTemporada(id: ContextoModos.nuevoId(), franquiciaId: q.franquiciaId, anio: q.anio, historia: q);
    default:
      // Momentos clutch: una sola partida que guarda qué finales ya cambiaste.
      Temporada? guardada;
      try {
        guardada = await c.db?.cargarTemporada(HistoriaNba.idMomentos);
      } catch (_) {}
      t = guardada ?? HistoriaNba.partidaMomentos(enfocada.id);
  }
  await c.guardar(t);
  await c.abrirTemporada(t);
}

Future<int?> _elegirAnio(BuildContext context) => showModalBottomSheet<int>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) {
    final tema = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('TEMPORADA REAL', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Los 30 equipos con el plantel que tuvieron ese año. Elegís cualquiera y tratás de superar lo que '
            'pasó de verdad. Récords y campeones reales (Basketball-Reference).',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final anio in HistoriaNba.anios)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: SizedBox(width: 92, child: TextoLed(nombreTemporada(anio), tamano: 15)),
              title: Text(switch (campeonesReales[anio]) {
                final id? => 'Campeón: ${_nombre(registrosDe(anio, id))}',
                null => 'Campeón: todavía sin dato',
              }),
              trailing: switch (campeonesReales[anio]) {
                final id? => Escudo(franquiciaPorId(registrosDe(anio, id)), tamano: 28),
                null => null,
              },
              onTap: () => Navigator.of(context).pop(anio),
            ),
        ],
      ),
    );
  },
);

/// Identidad con la que jugó una franquicia ese año (SEA para OKC en 1996).
String registrosDe(int anio, String franquiciaId) => HistoriaNba.identidad(franquiciaId, anio);

Future<String?> _elegirEquipo(BuildContext context, HistoriaNba h, int anio) {
  final equipos =
      [
        for (final f in franquicias)
          if (h.plantelReal(f.id, anio) case final r?) (f.id, r),
      ]..sort(
        (a, b) =>
            (HistoriaNba.recordReal(b.$1, anio)?.$1 ?? -1).compareTo(HistoriaNba.recordReal(a.$1, anio)?.$1 ?? -1),
      );
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final tema = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('¿A QUIÉN DIRIGÍS EN ${nombreTemporada(anio)}?', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final (id, r) in equipos)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Escudo(franquiciaPorId(r.identidadId), tamano: 36),
                title: Row(
                  children: [
                    Flexible(child: Text(_nombre(r.identidadId), overflow: TextOverflow.ellipsis)),
                    if (campeonesReales[anio] == id) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.emoji_events, size: 18, color: tema.colorScheme.primary),
                    ],
                  ],
                ),
                subtitle: Text(
                  r.aproximado && HistoriaNba.recordReal(id, anio) == null
                      ? 'No existía todavía: juega con su plantel más cercano en el tiempo.'
                      : _figuras(r.plantel.jugadores),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: switch (HistoriaNba.recordReal(id, anio)) {
                  (final w, final l) => TextoLed('$w-$l', tamano: 18),
                  null => null,
                },
                onTap: () => Navigator.of(context).pop(id),
              ),
          ],
        ),
      );
    },
  );
}

String _figuras(Iterable<Jugador> js) =>
    (js.toList()..sort((a, b) => b.media.compareTo(a.media))).take(3).map((j) => j.nombre).join(' · ');

Future<QueHubiera?> _elegirHistoria(BuildContext context) => showModalBottomSheet<QueHubiera>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) {
    final tema = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('¿QUÉ HUBIERA PASADO SI…?', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'La temporada real, con la historia cambiada. El resto de la liga juega con sus planteles de ese año. '
            'Objetivo: el anillo.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final q in historiasAlternativas)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: Escudo(franquiciaPorId(registrosDe(q.anio, q.franquiciaId)), tamano: 36),
                title: Text(q.titulo),
                subtitle: Text(
                  '${nombreTemporada(q.anio)} · ${q.relato}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(q),
              ),
            ),
        ],
      ),
    );
  },
);

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaHistoria(Temporada t, ContextoModos c) async {
  final historia = await historiaDe(c);
  if (t.modoJuego == ModoJuego.ultimoCuarto) {
    return MomentosClutchPantalla(temporada: t, historia: historia, onCambio: c.guardar);
  }
  var actual = t;
  void guardar(Temporada x) {
    actual = x;
    c.guardar(x);
  }

  List<Widget> acciones() => [
    Builder(
      builder: (context) => IconButton(
        onPressed: () => mostrarObjetivo(context, actual),
        icon: const Icon(Icons.flag_outlined),
        tooltip: 'Lo que pasó de verdad',
      ),
    ),
  ];
  switch (t.fase) {
    case FaseTemporada.draft:
      return null;
    case FaseTemporada.tacticas:
      return PlaybookPantalla(
        temporada: t,
        onConfirmar: (x) async {
          final lista = historia.iniciarLiga(x);
          await c.guardar(lista);
          await c.abrirTemporada(lista, reemplazar: true);
        },
      );
    case FaseTemporada.temporadaRegular:
      return TemporadaPantalla(
        temporada: t,
        liga: historia.liga,
        onCambio: guardar,
        onPlayoffs: () => c.abrirTemporada(actual, reemplazar: true),
        acciones: acciones(),
      );
    case FaseTemporada.playoffs || FaseTemporada.finalizada:
      return PlayoffsPantalla(temporada: t, liga: historia.liga, onCambio: guardar, acciones: acciones());
  }
}

/// Lo que pasó de verdad esa temporada y cómo vas vos.
Future<void> mostrarObjetivo(BuildContext context, Temporada t) {
  final anio = HistoriaNba.anioDe(t);
  final propia = t.franquiciaUsuarioId;
  final q = HistoriaNba.historiaDe(t);
  final real = HistoriaNba.resultadoReal(propia, anio);
  final campeon = campeonesReales[anio];
  final r = t.registroUsuario;
  final terminada = t.fase == FaseTemporada.finalizada;
  final veredicto = !terminada
      ? null
      : t.campeonId == propia
      ? '¡Campeones! Le ganaste a la historia.'
      : q == null && (HistoriaNba.recordReal(propia, anio)?.$1 ?? 99) < r.victorias
      ? 'Sin anillo, pero con más victorias que las reales.'
      : 'No pudo ser: la historia quedó como estaba.';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final tema = Theme.of(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q?.titulo.toUpperCase() ?? 'TEMPORADA REAL ${nombreTemporada(anio)}',
              style: tema.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (q != null) ...[Text(q.relato), const SizedBox(height: 8)],
            Text('Lo que pasó de verdad', style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.primary)),
            Text(
              [
                if (real != null) '${_nombre(registrosDe(anio, propia))}: $real',
                if (campeon != null) 'Campeón: ${_nombre(registrosDe(anio, campeon))}',
              ].join(' · '),
            ),
            const SizedBox(height: 12),
            Text(
              q == null ? 'Tu objetivo: superar ese récord o ganar el anillo.' : 'Tu objetivo: el anillo.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('VOS', style: tema.textTheme.labelLarge),
                const SizedBox(width: 12),
                TextoLed('${r.victorias}-${r.derrotas}', tamano: 26),
              ],
            ),
            if (veredicto != null) ...[const SizedBox(height: 8), Text(veredicto, style: tema.textTheme.titleMedium)],
            const SizedBox(height: 8),
            Text(
              'Récords y campeones reales de Basketball-Reference. Los planteles salen de las cartas de cada tramo '
              '(franquicia y década) que jugaron ese año.',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    },
  );
}

/// Finales reales para jugar en vivo desde el marcador de entonces.
class MomentosClutchPantalla extends StatefulWidget {
  const MomentosClutchPantalla({super.key, required this.temporada, required this.historia, required this.onCambio});

  final Temporada temporada;
  final HistoriaNba historia;
  final ValueChanged<Temporada> onCambio;

  @override
  State<MomentosClutchPantalla> createState() => _MomentosClutchPantallaState();
}

class _MomentosClutchPantallaState extends State<MomentosClutchPantalla> {
  late Temporada _t = widget.temporada;

  Future<void> _jugar(MomentoClutch m) async {
    final ir = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(m.titulo),
        content: Text(
          '${m.partido}${m.basadoEn ? ' (basado en el partido real)' : ''}.\n\n${m.relato}\n\n'
          'Jugás con ${_nombre(registrosDe(m.anio, m.usuarioId))}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('A LA CANCHA')),
        ],
      ),
    );
    if (ir != true || !mounted) return;
    final motor = widget.historia.motor(m);
    MotorPartido? final_;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: motor,
          usuarioLocal: m.usuarioLocal,
          franquiciaUsuario: franquiciaPorId(m.usuarioId),
          identidadLocal: franquiciaPorId(registrosDe(m.anio, m.localId)),
          identidadVisitante: franquiciaPorId(registrosDe(m.anio, m.visitanteId)),
          onTerminado: (x) => final_ = x,
        ),
      ),
    );
    final terminado = final_;
    if (terminado == null || !mounted) return;
    final gano = HistoriaNba.gano(m, terminado);
    if (gano && !HistoriaNba.superados(_t).contains(m.id)) {
      setState(() => _t = HistoriaNba.conSuperado(_t, m.id));
      widget.onCambio(_t);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(gano ? '¡LO HICISTE!' : 'NO PUDO SER'),
        content: Text(
          '${_nombre(registrosDe(m.anio, m.localId))} ${terminado.puntosLocal} · '
          '${terminado.puntosVisitante} ${_nombre(registrosDe(m.anio, m.visitanteId))}\n\n'
          '${gano ? 'Ese final ya es tuyo.' : 'Podés volver a intentarlo cuando quieras.'}',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('SEGUIR'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hechos = HistoriaNba.superados(_t);
    final tablet = esTabletApaisada(context);
    final tarjetas = [
      for (final m in momentosClutch) _TarjetaMomento(m: m, superado: hechos.contains(m.id), onTap: () => _jugar(m)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Momentos clutch')),
      body: AnchoMaximo(
        ancho: 1100,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Finales reales, con el marcador y el reloj de entonces. Ganalos para cambiar la historia.',
                    style: tema.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    TextoLed('${hechos.length}/${momentosClutch.length}', tamano: 26),
                    Text('${hechos.length} de ${momentosClutch.length}', style: tema.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tablet)
              Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tarjetas) SizedBox(width: 520, child: t)])
            else
              ...tarjetas,
          ],
        ),
      ),
    );
  }
}

class _TarjetaMomento extends StatelessWidget {
  const _TarjetaMomento({required this.m, required this.superado, required this.onTap});

  final MomentoClutch m;
  final bool superado;
  final VoidCallback onTap;

  String get _reloj {
    final s = m.reloj;
    if (s < 60) return s == s.roundToDouble() ? '0:${s.round().toString().padLeft(2, '0')}' : s.toStringAsFixed(1);
    return '${s ~/ 60}:${(s % 60).round().toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final local = franquiciaPorId(registrosDe(m.anio, m.localId));
    final visitante = franquiciaPorId(registrosDe(m.anio, m.visitanteId));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: superado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(m.titulo.toUpperCase(), style: tema.textTheme.titleMedium)),
                  if (superado) Icon(Icons.check_circle, color: esquema.primary),
                ],
              ),
              Text(
                m.partido + (m.basadoEn ? ' · basado en el partido real' : ''),
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Escudo(visitante, tamano: 30),
                  const SizedBox(width: 8),
                  TextoLed('${m.puntosVisitante}', tamano: 24),
                  Expanded(
                    child: Column(
                      children: [
                        TextoLed(_reloj, tamano: 18),
                        Text(m.cuarto > 4 ? 'PRÓRROGA' : '4.º CUARTO', style: tema.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  TextoLed('${m.puntosLocal}', tamano: 24),
                  const SizedBox(width: 8),
                  Escudo(local, tamano: 30),
                ],
              ),
              const SizedBox(height: 8),
              Text(m.relato, style: tema.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'Jugás con ${franquiciaPorId(registrosDe(m.anio, m.usuarioId)).nombreCompleto}',
                style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
