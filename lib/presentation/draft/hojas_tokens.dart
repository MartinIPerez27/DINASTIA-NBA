import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/tokens_draft.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Hoja de pago: título, detalle, contenido propio, el resumen de monedas y la confirmación.
class _HojaPago extends StatelessWidget {
  const _HojaPago({
    required this.titulo,
    required this.detalle,
    required this.precio,
    required this.monedas,
    required this.boton,
    required this.onConfirmar,
    this.contenido = const [],
    this.aviso,
  });

  final String titulo, detalle, boton;
  final int precio, monedas;
  final VoidCallback? onConfirmar;
  final List<Widget> contenido;
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final alcanza = monedas >= precio;
    Widget cifra(String rotulo, int valor, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(rotulo, style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TextoLed('$valor', tamano: 24, color: color),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo.toUpperCase(), style: tema.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(detalle, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
            if (contenido.isNotEmpty) ...[const SizedBox(height: 12), ...contenido],
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: esquema.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    cifra('TENÉS', monedas),
                    cifra('COSTO', precio, color: precio == 0 ? null : esquema.tertiary),
                    cifra('TE QUEDAN', alcanza ? monedas - precio : 0, color: alcanza ? null : esquema.error),
                  ],
                ),
              ),
            ),
            if (aviso != null) ...[
              const SizedBox(height: 8),
              Text(aviso!, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: alcanza ? onConfirmar : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(alcanza ? boton : 'TE FALTAN ${precio - monedas} MONEDAS'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('CANCELAR'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> _hoja<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: builder,
);

/// Confirmación simple del gasto (Doble, volver a tirar con monedas…).
Future<bool> confirmarGasto(
  BuildContext context, {
  required String titulo,
  required String detalle,
  required int precio,
  required int monedas,
  String? aviso,
}) async =>
    await _hoja<bool>(
      context,
      (c) => _HojaPago(
        titulo: titulo,
        detalle: detalle,
        precio: precio,
        monedas: monedas,
        aviso: aviso,
        boton: precio == 0 ? 'USAR' : 'PAGAR $precio MONEDAS',
        onConfirmar: () => Navigator.of(c).pop(true),
      ),
    ) ??
    false;

String _lineaCarta(Jugador j) => '${j.tramoConEquipo} · media ${j.media}';

/// Mejor versión: muestra la carta que salió, la mejor versión y por qué es la elegida.
Future<bool> confirmarMejorVersion(
  BuildContext context, {
  required Jugador actual,
  required Jugador mejor,
  required int versiones,
  bool reglaLimita = false,
  required int precio,
  required int monedas,
  String? aviso,
}) async {
  final tema = Theme.of(context);
  Widget lado(String rotulo, Jugador j, {bool destacada = false}) => Expanded(
    child: Column(
      children: [
        Text(
          rotulo,
          style: tema.textTheme.labelMedium?.copyWith(
            color: destacada ? tema.colorScheme.primary : tema.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 110,
          child: CartaVertical(jugador: j, seleccionada: destacada),
        ),
        const SizedBox(height: 6),
        Text(_lineaCarta(j), textAlign: TextAlign.center, style: tema.textTheme.bodySmall),
      ],
    ),
  );
  return await _hoja<bool>(
        context,
        (c) => _HojaPago(
          titulo: 'Mejor versión de ${actual.nombre}',
          detalle:
              reglaLimita
              ? 'Su mejor carta no entra con la regla de este draft: te damos la mejor que sí entra, de las '
                    '$versiones que tiene. ${mejor.equipo} ${mejor.tramo}, media ${mejor.media} (+${mejor.media - actual.media}).'
              : 'Es la carta de mayor media de las $versiones que tiene en el catálogo: '
                    '${mejor.equipo} ${mejor.tramo}, media ${mejor.media} (+${mejor.media - actual.media}).',
          precio: precio,
          monedas: monedas,
          aviso: aviso,
          boton: precio == 0 ? 'CAMBIAR GRATIS' : 'CAMBIAR POR $precio MONEDAS',
          onConfirmar: () => Navigator.of(c).pop(true),
          contenido: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lado('AHORA', actual),
                Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Icon(Icons.arrow_forward, color: tema.colorScheme.primary),
                ),
                lado('MEJOR VERSIÓN', mejor, destacada: true),
              ],
            ),
          ],
        ),
      ) ??
      false;
}

/// Intercambio: elegís qué carta tuya sale y cuál de la tirada entra en su puesto.
Future<(Posicion, Jugador)?> elegirIntercambio(
  BuildContext context, {
  required List<(Posicion, Jugador, List<Jugador>)> opciones,
  required int Function(Jugador sale, Jugador entra) precioDe,
  required int monedas,
  String? aviso,
}) => _hoja<(Posicion, Jugador)>(
  context,
  (_) => _HojaIntercambio(opciones: opciones, precioDe: precioDe, monedas: monedas, aviso: aviso),
);

class _HojaIntercambio extends StatefulWidget {
  const _HojaIntercambio({required this.opciones, required this.precioDe, required this.monedas, this.aviso});

  final List<(Posicion, Jugador, List<Jugador>)> opciones;
  final int Function(Jugador, Jugador) precioDe;
  final int monedas;
  final String? aviso;

  @override
  State<_HojaIntercambio> createState() => _HojaIntercambioState();
}

class _HojaIntercambioState extends State<_HojaIntercambio> {
  late int _sale = 0;
  Jugador? _entra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final (puesto, sale, entran) = widget.opciones[_sale];
    final entra = entran.contains(_entra) ? _entra : null;
    return _HojaPago(
      titulo: 'Intercambio',
      detalle:
          'Elegí la carta que sale (se pierde para este draft) y la de esta tirada que entra en su puesto. '
          'Gastás la tirada.',
      precio: entra == null ? ReglasTokens.intercambioBase : widget.precioDe(sale, entra),
      monedas: widget.monedas,
      aviso: widget.aviso ?? 'Precio base más 10 monedas por cada punto de media que ganás (máximo 400).',
      boton: 'CAMBIAR A ${sale.nombre.split(' ').last.toUpperCase()}',
      onConfirmar: entra == null ? null : () => Navigator.of(context).pop((puesto, entra)),
      contenido: [
        Text('SALE', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, o) in widget.opciones.indexed)
              ChoiceChip(
                label: Text('${o.$1.etiqueta} · ${o.$2.nombre.split(' ').last} ${o.$2.media}'),
                selected: i == _sale,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _sale = i;
                  _entra = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('ENTRA DE ESTA TIRADA', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
        const SizedBox(height: 6),
        SizedBox(
          height: 166,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entran.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final j = entran[i];
              final delta = j.media - sale.media;
              return Semantics(
                button: true,
                selected: j == entra,
                label: '${j.nombre}, media ${j.media}, ${delta >= 0 ? 'sube' : 'baja'} ${delta.abs()}',
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: () => setState(() => _entra = j),
                    child: SizedBox(
                      width: 100,
                      child: Column(
                        children: [
                          Expanded(
                            child: CartaVertical(jugador: j, seleccionada: j == entra),
                          ),
                          Text(
                            j.tramoConEquipo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelSmall,
                          ),
                          Text(
                            delta == 0 ? '=' : (delta > 0 ? '+$delta' : '$delta'),
                            style: tema.textTheme.labelMedium?.copyWith(
                              color: delta > 0 ? esquema.primary : esquema.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Comodín: se elige una franquicia **o** una época. Devuelve (franquiciaId, época).
Future<(String?, Epoca?)?> elegirComodin(
  BuildContext context, {
  required Set<String> franquicias,
  required Set<Epoca> epocas,
  required int precio,
  required int monedas,
  String? aviso,
}) => _hoja<(String?, Epoca?)>(
  context,
  (_) => _HojaComodin(franquicias: franquicias, epocas: epocas, precio: precio, monedas: monedas, aviso: aviso),
);

class _HojaComodin extends StatefulWidget {
  const _HojaComodin({
    required this.franquicias,
    required this.epocas,
    required this.precio,
    required this.monedas,
    this.aviso,
  });

  final Set<String> franquicias;
  final Set<Epoca> epocas;
  final int precio, monedas;
  final String? aviso;

  @override
  State<_HojaComodin> createState() => _HojaComodinState();
}

class _HojaComodinState extends State<_HojaComodin> {
  bool _porFranquicia = true;
  String? _franquicia;
  Epoca? _epoca;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ids = widget.franquicias.toList()
      ..sort((a, b) => franquiciaPorId(a).nombre.compareTo(franquiciaPorId(b).nombre));
    final epocas = widget.epocas.toList()..sort((a, b) => a.index.compareTo(b.index));
    final elegido = _porFranquicia ? _franquicia != null : _epoca != null;
    final nombre = _porFranquicia
        ? (_franquicia == null ? '' : franquiciaPorId(_franquicia!).nombre.toUpperCase())
        : (_epoca?.etiqueta.toUpperCase() ?? '');
    return _HojaPago(
      titulo: 'Comodín',
      detalle: 'Fijás la franquicia o la época de la próxima tirada; lo demás sale al azar.',
      precio: widget.precio,
      monedas: widget.monedas,
      aviso: widget.aviso,
      boton: elegido ? 'FIJAR $nombre' : 'ELEGÍ UNA OPCIÓN',
      onConfirmar: elegido
          ? () => Navigator.of(context).pop(_porFranquicia ? (_franquicia, null as Epoca?) : (null as String?, _epoca))
          : null,
      contenido: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('FRANQUICIA')),
            ButtonSegment(value: false, label: Text('ÉPOCA')),
          ],
          selected: {_porFranquicia},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _porFranquicia = s.first),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _porFranquicia
                  ? [
                      for (final id in ids)
                        ChoiceChip(
                          avatar: Escudo(franquiciaPorId(id), tamano: 18),
                          label: Text(id),
                          selected: _franquicia == id,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _franquicia = id),
                          tooltip: franquiciaPorId(id).nombre,
                        ),
                    ]
                  : [
                      for (final e in epocas)
                        ChoiceChip(
                          label: Text(e.etiqueta),
                          selected: _epoca == e,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _epoca = e),
                        ),
                    ],
            ),
          ),
        ),
        if (!_porFranquicia && epocas.isEmpty) Text('No hay épocas disponibles.', style: tema.textTheme.bodySmall),
      ],
    );
  }
}
