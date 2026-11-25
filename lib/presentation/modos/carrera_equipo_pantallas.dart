import 'package:flutter/material.dart';

import '../../data/draft_2026.dart';
import '../../data/franquicias.dart';
import '../../data/records_nba.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../widgets/disposicion.dart';
import '../widgets/texto_led.dart';

/// "Mi equipo": tus compañeros (edad, media, contrato) y cómo fue cambiando el plantel año a año.
class MiEquipoPantalla extends StatelessWidget {
  const MiEquipoPantalla({super.key, required this.estado});

  final EstadoCarrera estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final anio = estado.anioCierre;
    final quien = franquiciaPorId(estado.franquiciaId).nombreCompleto;
    final plantel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(quien.toUpperCase(), style: tema.textTheme.titleMedium),
        Text(
          '${estado.etiquetaTemporada} · ${estado.companeros.length + 1} jugadores con vos',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final j in [...estado.companeros]..sort((a, b) => b.media.compareTo(a.media)))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 44, child: TextoLed('${j.media}', tamano: 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(j.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodyMedium),
                      Text(
                        '${j.posiciones.first.etiqueta} · ${PlantelCarrera.edadEn(j, anio)} años · química: ${QuimicaCarrera.nivelCon(estado, j).etiqueta}',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${PlantelCarrera.contratoDe(estado, j)} ${PlantelCarrera.contratoDe(estado, j) == 1 ? 'año' : 'años'}',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
    final movimientos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MOVIMIENTOS DEL PLANTEL', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        if (estado.movimientos.isEmpty)
          Text(
            'Todavía no hubo cambios. Cada receso se van los que terminan contrato o se retiran, y llegan caras nuevas.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        for (final m in estado.movimientos.reversed)
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(m, style: tema.textTheme.bodySmall)),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mi equipo')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 8, 24), children: [plantel])),
                  Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(8, 8, 16, 24), children: [movimientos])),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [plantel, const SizedBox(height: 16), movimientos],
              ),
      ),
    );
  }
}

/// "Mi generación": los mejores elegidos de tu draft y qué hacen este año contra vos.
class GeneracionPantalla extends StatefulWidget {
  const GeneracionPantalla({super.key, required this.estado, required this.catalogo, this.clase2026});

  final EstadoCarrera estado;
  final List<Jugador> catalogo;

  /// La clase real de 2026 (si no se pasa, se carga del asset cuando hace falta).
  final List<CompaneroGeneracion>? clase2026;

  @override
  State<GeneracionPantalla> createState() => _GeneracionPantallaState();
}

class _GeneracionPantallaState extends State<GeneracionPantalla> {
  late final Future<List<CompaneroGeneracion>?> _real = widget.clase2026 != null
      ? Future.value(widget.clase2026)
      : (widget.estado.anioBase == 2026 ? cargarClase2026() : Future.value(null));

  EstadoCarrera get estado => widget.estado;

  static String _n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CompaneroGeneracion>?>(
    future: _real,
    builder: (context, snap) => snap.connectionState != ConnectionState.done
        ? Scaffold(appBar: AppBar(title: Text('Clase del draft ${estado.anioBase}')), body: const Center(child: CircularProgressIndicator()))
        : _vista(context, snap.data),
  );

  Widget _vista(BuildContext context, List<CompaneroGeneracion>? real) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final clase = GeneracionCarrera.clase(widget.catalogo, estado, clase2026: real);
    final anio = estado.anioCierre;
    final yo = estado.historial.isEmpty ? null : estado.historial.last;
    final filas = [
      for (final c in clase) (c, GeneracionCarrera.lineaEn(c, anio, anioDraft: estado.anioBase)),
    ];
    final rival = clase.isEmpty ? null : clase.first;
    return Scaffold(
      appBar: AppBar(title: Text('Clase del draft ${estado.anioBase}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              clase.any((c) => c.ficticio)
                  ? 'Esta clase se inventa para tu carrera: sus carreras evolucionan sola, año a año.'
                  : (clase.any((c) => c.proyectado)
                        ? 'Los elegidos reales del draft ${estado.anioBase}. Todavía no tienen carrera: sus números son una proyección.'
                        : 'Los primeros elegidos de tu draft, con sus números reales de cada época.'),
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            if (rival != null) ...[
              const SizedBox(height: 8),
              Text('TU RIVAL DE GENERACIÓN: ${rival.nombre.toUpperCase()} (pick ${rival.pick})', style: tema.textTheme.labelLarge),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 40, child: Text('PICK')),
                const Expanded(child: Text('JUGADOR')),
                SizedBox(width: 120, child: Text('PTS · REB · AST', textAlign: TextAlign.end, style: tema.textTheme.labelSmall)),
              ],
            ),
            const Divider(),
            if (yo != null)
              _fila(
                tema,
                esquema,
                'TÚ',
                '${estado.nombre} (pick ${estado.pick})',
                '${_n(yo.pts)} · ${_n(yo.reb)} · ${_n(yo.ast)}',
                destacado: true,
              ),
            for (final (c, l) in filas)
              _fila(
                tema,
                esquema,
                '${c.pick}',
                c.equipo == null ? c.nombre : '${c.nombre} (${c.equipo})',
                l == null
                    ? 'todavía no juega'
                    : (l.retirado ? 'retirado' : '${_n(l.pts)} · ${_n(l.reb)} · ${_n(l.ast)}'),
              ),
            const SizedBox(height: 8),
            Text(
              'Los números de los demás son los del año de tu última temporada cerrada (${estado.etiquetaTemporada}).',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(ThemeData tema, ColorScheme esquema, String pick, String nombre, String linea, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(pick, style: tema.textTheme.bodyMedium?.copyWith(color: destacado ? esquema.primary : null))),
          Expanded(
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodyMedium?.copyWith(color: destacado ? esquema.primary : null),
            ),
          ),
          SizedBox(width: 120, child: Text(linea, textAlign: TextAlign.end, style: tema.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// La decisión de la fecha límite de traspasos.
Future<void> mostrarFechaLimite(BuildContext context, ValueChanged<OpcionFechaLimite> alElegir, {String? rumor}) {
  return showDialog<void>(
    context: context,
    builder: (d) => SimpleDialog(
      title: const Text('Fecha límite de traspasos'),
      children: [
        if (rumor != null)
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(rumor)),
        for (final o in OpcionFechaLimite.values)
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(d).pop();
              alElegir(o);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.etiqueta, style: Theme.of(d).textTheme.titleSmall),
                Text(o.descripcion, style: Theme.of(d).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    ),
  );
}

/// "Camino a los récords": tu jugador contra los récords históricos reales de la NBA (carrera, temporada y partido).
class RecordsPantalla extends StatefulWidget {
  const RecordsPantalla({super.key, required this.estado, this.records});

  final EstadoCarrera estado;

  /// Los datos ya cargados (si no se pasan, se leen del asset).
  final RecordsNba? records;

  @override
  State<RecordsPantalla> createState() => _RecordsPantallaState();
}

class _RecordsPantallaState extends State<RecordsPantalla> {
  late final Future<RecordsNba> _datos = widget.records != null ? Future.value(widget.records) : cargarRecordsNba();

  static String _n(double v, {bool entero = true}) {
    final base = entero ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
    // Separador de miles con punto: 43.672.
    if (!entero) return base;
    final b = StringBuffer();
    for (var i = 0; i < base.length; i++) {
      if (i > 0 && (base.length - i) % 3 == 0) b.write('.');
      b.write(base[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RecordsNba>(
    future: _datos,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return Scaffold(
          appBar: AppBar(title: const Text('Camino a los récords')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snap.hasError || snap.data == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Camino a los récords')),
          body: const Center(child: Text('No se pudieron leer los récords.')),
        );
      }
      return _vista(context, snap.data!);
    },
  );

  Widget _vista(BuildContext context, RecordsNba r) {
    final e = widget.estado;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Camino a los récords'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [Tab(text: 'CARRERA'), Tab(text: 'TEMPORADA'), Tab(text: 'PARTIDO'), Tab(text: 'HITOS'), Tab(text: 'HONOR')],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _lista(context, RecordsCarrera.carrera(r, e), r, ritmo: true, novedades: RecordsCarrera.novedades(r, e)),
              _lista(context, RecordsCarrera.temporada(r, e), r, decimales: true),
              _lista(context, RecordsCarrera.partido(r, e), r),
              _hitos(context, e),
              _honor(context, r, e),
            ],
          ),
        ),
      ),
    );
  }

  Widget _honor(BuildContext context, RecordsNba r, EstadoCarrera e) {
    final tema = Theme.of(context);
    final c = CuadroDeHonor.evaluar(r, e);
    final filas = c.puestos.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('CUADRO DE HONOR', style: tema.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(c.nivel, style: tema.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Top 10: ${c.top10} · Top 25: ${c.top25} · En alguna lista: ${c.top50}', style: tema.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (filas.isEmpty)
          Text('Todavía no entrás en ninguna lista de totales de la historia de la NBA.', style: tema.textTheme.bodyMedium)
        else
          for (final f in filas) ListTile(dense: true, title: Text(f.key), trailing: Text('Puesto ${f.value}.º')),
        const SizedBox(height: 8),
        Text('Salón de la Fama: ${e.legado.salon ? 'ya tenés el pase' : '${14 - e.legado.puntosSalon} puntos para entrar'} (${e.legado.puntosSalon} puntos).', style: tema.textTheme.bodyMedium),
      ],
    );
  }

  Widget _lista(
    BuildContext context,
    List<CaminoRecord> caminos,
    RecordsNba r, {
    bool ritmo = false,
    bool decimales = false,
    List<String> novedades = const [],
  }) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Datos reales de la NBA (${r.fuente}), al ${r.fecha}. Los jugadores en actividad pueden seguir sumando.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        if (novedades.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('YA SUPERASTE A…', style: tema.textTheme.labelLarge),
          for (final n in novedades) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(n, style: tema.textTheme.bodySmall)),
        ],
        const SizedBox(height: 8),
        for (final c in caminos) _tarjeta(context, c, ritmo: ritmo, decimales: decimales),
      ],
    );
  }

  Widget _tarjeta(BuildContext context, CaminoRecord c, {required bool ritmo, required bool decimales}) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    String v(double x) => _n(x, entero: !decimales);
    final rec = c.lista.record;
    final top = c.lista.filas.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.lista.etiqueta.toUpperCase(), style: tema.textTheme.labelLarge)),
                TextoLed(v(c.tuValor), tamano: 22),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              c.puesto == null
                  ? (c.tuValor <= 0 ? 'Todavía sin marca.' : 'Todavía fuera del top ${c.lista.filas.length} histórico.')
                  : (c.puesto == 1 ? '¡Sos el récord histórico!' : 'Ocuparías el puesto n.º ${c.puesto} de la historia.'),
              style: tema.textTheme.bodyMedium?.copyWith(color: c.puesto != null ? esquema.primary : null),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: c.progreso, minHeight: 6),
            const SizedBox(height: 4),
            Text(
              'Récord: ${rec.nombre} · ${v(rec.valor)}${rec.detalle.isEmpty ? '' : ' (${rec.detalle})'}',
              style: tema.textTheme.bodySmall,
            ),
            if (c.siguiente != null)
              Text(
                'Próximo: ${c.siguiente!.nombre} (${v(c.siguiente!.valor)}) · te faltan ${v(c.faltan)}'
                '${ritmo && c.temporadasParaSuperar != null ? ' · a tu ritmo, ~${c.temporadasParaSuperar!.ceil()} temporadas' : ''}',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            const SizedBox(height: 6),
            for (final f in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${f.nombre}${f.activo ? ' ●' : ''}${f.detalle.isEmpty ? '' : ' · ${f.detalle}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: f.valor <= c.tuValor ? esquema.primary : null,
                          decoration: f.valor <= c.tuValor ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Text(v(f.valor), style: tema.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hitos(BuildContext context, EstadoCarrera e) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Tus marcas partido a partido. La NBA no publica un ranking de partidos de 40 o 50 puntos que podamos usar, '
          'así que acá solo ves tu cuenta (y tu mejor partido, en la solapa PARTIDO).',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (final (t, n) in RecordsCarrera.hitos(e))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(t, style: tema.textTheme.bodyMedium)),
                TextoLed('$n', tamano: 22),
              ],
            ),
          ),
      ],
    );
  }
}

/// La bandeja de entrada de tu carrera: todo lo que te pasó, por categoría, de lo más nuevo a lo más viejo.
class BandejaPantalla extends StatefulWidget {
  const BandejaPantalla({super.key, required this.estado, this.alAbrir});

  final EstadoCarrera estado;

  /// Se llama al abrirla (para marcar todo como leído).
  final VoidCallback? alAbrir;

  @override
  State<BandejaPantalla> createState() => _BandejaPantallaState();
}

class _BandejaPantallaState extends State<BandejaPantalla> {
  CategoriaMensaje? _filtro;
  late final int _sinLeer = BandejaCarrera.sinLeer(widget.estado);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.alAbrir?.call());
  }

  static IconData _icono(CategoriaMensaje c) => switch (c) {
    CategoriaMensaje.premios => Icons.emoji_events_outlined,
    CategoriaMensaje.objetivos => Icons.flag_outlined,
    CategoriaMensaje.plantel => Icons.groups_outlined,
    CategoriaMensaje.mercado => Icons.swap_horiz,
    CategoriaMensaje.general => Icons.chat_bubble_outline,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final todos = BandejaCarrera.mensajes(widget.estado);
    final lista = [
      for (final m in todos)
        if (_filtro == null || m.categoria == _filtro) m,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de entrada')),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  ChoiceChip(label: Text('Todos (${todos.length})'), selected: _filtro == null, onSelected: (_) => setState(() => _filtro = null)),
                  for (final c in CategoriaMensaje.values) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(c.etiqueta),
                      selected: _filtro == c,
                      onSelected: (_) => setState(() => _filtro = _filtro == c ? null : c),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const Center(child: Text('Todavía no hay novedades.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: lista.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = lista[i];
                        final nuevo = todos.indexOf(m) < _sinLeer;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(_icono(m.categoria), color: nuevo ? esquema.primary : esquema.onSurfaceVariant),
                          title: Text(m.texto, style: tema.textTheme.bodyMedium?.copyWith(fontWeight: nuevo ? FontWeight.w700 : null)),
                          subtitle: Text(m.categoria.etiqueta, style: tema.textTheme.labelSmall),
                          trailing: nuevo ? Icon(Icons.fiber_manual_record, size: 10, color: esquema.primary) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
