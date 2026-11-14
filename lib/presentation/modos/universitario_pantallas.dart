import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../../domain/modos/universitario.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/disposicion.dart';
import '../widgets/texto_led.dart';

/// Escudo de una universidad ficticia: círculo con sus colores y la sigla en puntos LED.
class EscudoUniv extends StatelessWidget {
  const EscudoUniv(this.franquicia, {super.key, this.tamano = 40});

  final Franquicia franquicia;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final fondo = Color(franquicia.colorPrimario);
    final aro = Color(franquicia.colorSecundario);
    final texto = fondo.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    return Semantics(
      label: franquicia.nombreCompleto,
      image: true,
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          shape: BoxShape.circle,
          border: Border.all(color: aro, width: max(1.5, tamano * 0.07)),
        ),
        child: Padding(
          padding: EdgeInsets.all(tamano * 0.1),
          child: FittedBox(child: TextoLed(franquicia.id, tamano: 20, color: texto)),
        ),
      ),
    );
  }
}

/// La franquicia oficial cuyo color primario se parece más al de tu programa: sirve para el tema de
/// la app y para el "Seguir" de Inicio (la partida necesita una franquicia real asociada).
Franquicia franquiciaParecida(Programa p) {
  final objetivo = Color(p.franquicia.colorPrimario);
  double distancia(Color a, Color b) =>
      pow(a.r - b.r, 2).toDouble() + pow(a.g - b.g, 2).toDouble() + pow(a.b - b.b, 2).toDouble();
  final oficiales = [
    for (final f in franquicias)
      if (!f.historica) f,
  ];
  oficiales.sort(
    (a, b) => distancia(Color(a.colorPrimario), objetivo).compareTo(distancia(Color(b.colorPrimario), objetivo)),
  );
  return oficiales.first;
}

/// Estrellas de reclutamiento (1 a 5).
class Estrellas extends StatelessWidget {
  const Estrellas(this.n, {super.key, this.tamano = 14});

  final int n;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$n estrellas',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= n ? Icons.star : Icons.star_border,
                  size: tamano,
                  color: i <= n ? color : color.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Los cinco atributos de un estudiante en barras.
class BarrasAtributos extends StatelessWidget {
  const BarrasAtributos(this.atributos, {super.key, this.cambios});

  final Atributos atributos;

  /// Cambio de cada atributo (para mostrar ▲ ▼ en el receso).
  final Map<Atributo, int>? cambios;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      children: [
        for (final a in Atributo.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(a.etiqueta, style: tema.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: atributos[a] / 99, minHeight: 6),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${atributos[a]}${cambios == null || cambios![a] == 0 ? '' : ' ${cambios![a]! > 0 ? '+' : ''}${cambios![a]}'}',
                    textAlign: TextAlign.end,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: cambios == null || cambios![a] == 0
                          ? null
                          : (cambios![a]! > 0 ? tema.colorScheme.primary : tema.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Un estudiante en una fila: nombre, puesto, año, estrellas, media LED y su línea de la temporada.
class FilaEstudiante extends StatelessWidget {
  const FilaEstudiante(this.e, {super.key, this.onTap, this.trailing, this.subtitulo, this.destacado = false});

  final Estudiante e;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitulo;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final linea = e.pj > 0
        ? '${(e.pts / e.pj).toStringAsFixed(1)} pts · ${(e.reb / e.pj).toStringAsFixed(1)} reb · ${(e.ast / e.pj).toStringAsFixed(1)} ast'
        : null;
    return Material(
      color: tema.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: destacado ? tema.colorScheme.primary : tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              TextoLed('${e.media}', tamano: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.titleSmall,
                          ),
                        ),
                        if (e.creado) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.edit, size: 13, color: tema.colorScheme.primary),
                        ],
                      ],
                    ),
                    Text(
                      '${e.posicion.etiqueta} · ${e.etiquetaAnio}${subtitulo == null ? '' : ' · $subtitulo'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                    if (linea != null)
                      Text(linea, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodySmall),
                    Estrellas(e.estrellas, tamano: 11),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────── Configuración del programa ───────────────────────────────────────────

/// Nombre, mote y colores de tu programa, con el escudo en vivo. Devuelve el [Programa].
class ProgramaConfigPantalla extends StatefulWidget {
  const ProgramaConfigPantalla({super.key});

  @override
  State<ProgramaConfigPantalla> createState() => _ProgramaConfigPantallaState();
}

class _ProgramaConfigPantallaState extends State<ProgramaConfigPantalla> {
  final _nombre = TextEditingController();
  final _mote = TextEditingController();
  var _c1 = 1, _c2 = 3;

  @override
  void dispose() {
    _nombre.dispose();
    _mote.dispose();
    super.dispose();
  }

  Programa get _programa => Programa(nombre: _nombre.text, mote: _mote.text, color1: _c1, color2: _c2);

  @override
  Widget build(BuildContext context) {
    final programa = _programa;
    final tema = temaFranquicia(programa.franquicia); // el Theme de abajo todavía no está en este contexto
    final error = programa.error;
    final formulario = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Armá tu programa universitario: nombre, mote y colores. Después creás a tus primeros jugadores y '
          'competís contra 31 universidades ficticias.',
          style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'Nombre de la universidad', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _mote,
          textCapitalization: TextCapitalization.words,
          maxLength: 18,
          decoration: const InputDecoration(labelText: 'Mote del equipo (los…)', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _SelectorColor(titulo: 'COLOR PRINCIPAL', seleccionado: _c1, onCambio: (i) => setState(() => _c1 = i)),
        const SizedBox(height: 12),
        _SelectorColor(titulo: 'COLOR SECUNDARIO', seleccionado: _c2, onCambio: (i) => setState(() => _c2 = i)),
      ],
    );
    final vista = Padding(
      padding: EdgeInsets.all(esTabletApaisada(context) ? 16 : 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EscudoUniv(programa.franquicia, tamano: esTabletApaisada(context) ? 132 : 64),
          SizedBox(height: esTabletApaisada(context) ? 12 : 6),
          Text(
            programa.nombre.trim().isEmpty ? 'TU UNIVERSIDAD' : programa.nombre.trim().toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.headlineSmall,
          ),
          Text(
            programa.mote.trim().isEmpty ? 'los…' : programa.mote.trim(),
            style: tema.textTheme.titleMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
            ),
          ],
        ],
      ),
    );
    final boton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: FilledButton(
        onPressed: error == null ? () => Navigator.of(context).pop(programa) : null,
        child: const Text('SEGUIR: CREAR TUS JUGADORES'),
      ),
    );
    return Theme(
      data: temaFranquicia(programa.franquicia),
      child: Scaffold(
        appBar: AppBar(title: const Text('Tu programa')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: esTabletApaisada(context)
                    ? Row(
                        children: [
                          Expanded(flex: 6, child: formulario),
                          Expanded(flex: 5, child: vista),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(height: 190, child: vista),
                          Expanded(child: formulario),
                        ],
                      ),
              ),
              boton,
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorColor extends StatelessWidget {
  const _SelectorColor({required this.titulo, required this.seleccionado, required this.onCambio});

  final String titulo;
  final int seleccionado;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < PaletaUniv.colores.length; i++)
              Semantics(
                button: true,
                selected: i == seleccionado,
                label: PaletaUniv.colores[i].$1,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onCambio(i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(PaletaUniv.colores[i].$2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == seleccionado ? tema.colorScheme.primary : tema.colorScheme.outlineVariant,
                        width: i == seleccionado ? 3 : 1,
                      ),
                    ),
                    child: i == seleccionado
                        ? Icon(
                            Icons.check,
                            size: 20,
                            color: Color(PaletaUniv.colores[i].$2).computeLuminance() > 0.4
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────── Receso ───────────────────────────────────────────

/// El receso: el draft de tus jugadores, cómo crecen los que siguen y a quién reclutás.
/// Al terminar devuelve (declarados, firmados) por [onTerminar].
class RecesoUnivPantalla extends StatefulWidget {
  const RecesoUnivPantalla({super.key, required this.estado, required this.onTerminar});

  final EstadoUniv estado;
  final void Function(Set<String> declarados, List<Recluta> firmados) onTerminar;

  @override
  State<RecesoUnivPantalla> createState() => _RecesoUnivPantallaState();
}

class _RecesoUnivPantallaState extends State<RecesoUnivPantalla> {
  final _declarados = <String>{};
  final _firmados = <Recluta>[];
  late final _reclutas = widget.estado.reclutas();
  late final _puntos = widget.estado.puntosReclutamiento();
  var _verDraft = false;

  EstadoUniv get _e => widget.estado;

  int get _gastados => _firmados.fold(0, (a, r) => a + r.precio);

  /// Las 30 franquicias de la NBA, en un orden de elección fijo para este año.
  List<Franquicia> get _ordenDraft {
    final f = [
      for (final x in franquicias)
        if (!x.historica) x,
    ]..shuffle(Random(hashUniv('${_e.semilla}|dt|${_e.temporada}')));
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final tema = temaFranquicia(_e.programa.franquicia);
    final (quedan, seVan, cambios) = _e.pasarDeAnio(_declarados);
    final tabla = _e.tablaDraft(seVan);
    final orden = _ordenDraft;
    final cupo = EstadoUniv.plantelMax - quedan.length;
    final restantes = _puntos - _gastados;

    final izquierda = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('EL DRAFT', style: tema.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Los de último año se van solos. Los de segundo y tercero con buena media pueden declararse: '
          'si los elegen, sumás prestigio; si no, pierden un año.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final e in _e.plantel.where((x) => x.anio >= 4 || EstadoUniv.puedeDeclarar(x)))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FilaEstudiante(
              e,
              destacado: seVan.any((s) => s.id == e.id),
              subtitulo: seVan.any((s) => s.id == e.id)
                  ? (tabla.pickDe(e.id) == null ? 'proyección: sin draft' : 'proyección: pick ${tabla.pickDe(e.id)}')
                  : 'se queda',
              trailing: e.anio >= 4
                  ? const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.school, size: 20))
                  : Switch(
                      value: _declarados.contains(e.id),
                      onChanged: (v) => setState(() => v ? _declarados.add(e.id) : _declarados.remove(e.id)),
                    ),
            ),
          ),
        if (_e.plantel.every((x) => x.anio < 4 && !EstadoUniv.puedeDeclarar(x)))
          const Padding(padding: EdgeInsets.all(8), child: Text('Nadie se va este año.')),
        TextButton.icon(
          onPressed: () => setState(() => _verDraft = !_verDraft),
          icon: Icon(_verDraft ? Icons.expand_less : Icons.expand_more),
          label: Text(_verDraft ? 'OCULTAR EL DRAFT' : 'VER EL DRAFT (PRIMERA RONDA)'),
        ),
        if (_verDraft)
          for (final p in tabla.primeraRonda)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: p.esTuyo
                    ? tema.colorScheme.primary.withValues(alpha: 0.16)
                    : tema.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.esTuyo ? tema.colorScheme.primary : Colors.transparent),
              ),
              child: Row(
                children: [
                  SizedBox(width: 34, child: Text('${p.pick}', style: tema.textTheme.titleSmall)),
                  Expanded(
                    child: Text(
                      '${p.nombre} · ${p.posicion.etiqueta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p.esTuyo ? tema.textTheme.titleSmall : tema.textTheme.bodySmall,
                    ),
                  ),
                  Text(orden[(p.pick - 1) % orden.length].id, style: tema.textTheme.labelSmall),
                ],
              ),
            ),
        const SizedBox(height: 16),
        Text('CÓMO CRECEN LOS QUE SIGUEN', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final q in quedan)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _Crecimiento(antes: _e.plantel.firstWhere((x) => x.id == q.id), despues: q, cambios: cambios[q.id]!),
          ),
      ],
    );

    final derecha = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'RECLUTAMIENTO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.titleMedium,
              ),
            ),
            Text('PUNTOS ', style: tema.textTheme.labelMedium),
            TextoLed('$restantes', tamano: 28),
            Text(' / $_puntos', style: tema.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Plantel del año que viene: ${quedan.length + _firmados.length}/${EstadoUniv.plantelMax} '
          '(mínimo ${EstadoUniv.plantelMin}; si falta gente entran estudiantes sin beca). Tu prestigio '
          '(${_e.prestigio}) mejora a los reclutas que te llegan.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final r in _reclutas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TarjetaRecluta(
              recluta: r,
              firmado: _firmados.contains(r),
              puedeFirmar: r.precio <= restantes && _firmados.length < cupo,
              onAlternar: () => setState(() => _firmados.contains(r) ? _firmados.remove(r) : _firmados.add(r)),
            ),
          ),
      ],
    );

    return Theme(
      data: temaFranquicia(_e.programa.franquicia),
      child: Scaffold(
        appBar: AppBar(title: Text('Receso · temporada ${_e.temporada}')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: esTabletApaisada(context)
                    ? Row(
                        children: [
                          Expanded(child: izquierda),
                          Expanded(child: derecha),
                        ],
                      )
                    : DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: 'Draft y crecimiento'),
                                Tab(text: 'Reclutas'),
                              ],
                            ),
                            Expanded(child: TabBarView(children: [izquierda, derecha])),
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: FilledButton(
                  onPressed: () => widget.onTerminar(_declarados, _firmados),
                  child: Text('ARRANCAR LA TEMPORADA ${_e.temporada + 1}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Crecimiento extends StatelessWidget {
  const _Crecimiento({required this.antes, required this.despues, required this.cambios});

  final Estudiante antes, despues;
  final Map<Atributo, int> cambios;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final dif = despues.media - antes.media;
    return Material(
      color: tema.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tema.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(despues.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
        subtitle: Text(
          '${despues.posicion.etiqueta} · pasa a ${despues.etiquetaAnio.toLowerCase()}',
          style: tema.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${antes.media} ', style: tema.textTheme.bodySmall),
            Icon(Icons.arrow_forward, size: 12, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            TextoLed('${despues.media}', tamano: 22),
            const SizedBox(width: 6),
            Text(
              dif == 0 ? '=' : (dif > 0 ? '+$dif' : '$dif'),
              style: tema.textTheme.labelMedium?.copyWith(
                color: dif >= 0 ? tema.colorScheme.primary : tema.colorScheme.error,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        children: [BarrasAtributos(despues.atributos, cambios: cambios)],
      ),
    );
  }
}

class _TarjetaRecluta extends StatelessWidget {
  const _TarjetaRecluta({
    required this.recluta,
    required this.firmado,
    required this.puedeFirmar,
    required this.onAlternar,
  });

  final Recluta recluta;
  final bool firmado, puedeFirmar;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final e = recluta.estudiante;
    return Material(
      color: tema.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: firmado ? tema.colorScheme.primary : tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextoLed('${e.media}', tamano: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                      Text(
                        '${e.posicion.etiqueta} · ${e.rol.etiqueta}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall,
                      ),
                      Estrellas(e.estrellas),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: firmado || puedeFirmar ? onAlternar : null,
                  child: Text(firmado ? 'FIRMADO ✓' : 'FICHAR · ${recluta.precio}'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            BarrasAtributos(e.atributos),
          ],
        ),
      ),
    );
  }
}
