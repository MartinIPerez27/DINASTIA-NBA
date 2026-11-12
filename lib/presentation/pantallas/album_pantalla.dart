import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/tienda.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/carta_vertical.dart';
import '../widgets/escudo.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';

/// Álbum de colección (cartas tuyas, por franquicia) y tienda de sobres con monedas del juego.
class AlbumPantalla extends StatefulWidget {
  const AlbumPantalla({super.key, required this.catalogo, required this.onPerfil, this.tienda});

  final List<Jugador> catalogo;

  /// Guarda el perfil después de abrir un sobre.
  final ValueChanged<PerfilEntrenador> onPerfil;

  /// Para pruebas (azar fijo).
  final Tienda? tienda;

  @override
  State<AlbumPantalla> createState() => _AlbumPantallaState();
}

class _AlbumPantallaState extends State<AlbumPantalla> {
  late final _tienda = widget.tienda ?? Tienda(widget.catalogo);
  String? _franquicia;

  Future<void> _comprar(SobreTienda s) async {
    final (perfil, apertura) = _tienda.abrir(perfilApp.value, s);
    widget.onPerfil(perfil);
    Haptica.media();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AperturaDialogo(sobre: s, apertura: apertura),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Álbum'),
        actions: [
          ValueListenableBuilder(
            valueListenable: perfilApp,
            builder: (context, p, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(Icons.toll, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  TextoLed('${p.monedas}', tamano: 18),
                ],
              ),
            ),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Mis cartas'),
            Tab(text: 'Tienda'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: perfilApp,
          builder: (context, perfil, _) =>
              TabBarView(children: [_coleccion(context, perfil), _tiendaVista(context, perfil)]),
        ),
      ),
    ),
  );

  Widget _coleccion(BuildContext context, PerfilEntrenador perfil) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final porFranquicia = <String, (int, int)>{};
    for (final j in widget.catalogo) {
      final (tengo, total) = porFranquicia[j.franquiciaId] ?? (0, 0);
      porFranquicia[j.franquiciaId] = (tengo + (perfil.coleccion.contains(j.id) ? 1 : 0), total + 1);
    }
    final mias =
        widget.catalogo
            .where((j) => perfil.coleccion.contains(j.id) && (_franquicia == null || j.franquiciaId == _franquicia))
            .toList()
          ..sort((a, b) => b.media.compareTo(a.media));
    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = max(3, (ancho / 130).floor());
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                TextoLed('${perfil.coleccion.length}', tamano: 36),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'de ${widget.catalogo.length} cartas. Fichar en un draft o abrir sobres suma cartas; '
                    'con la regla "Mi colección" jugás solo con ellas.',
                    style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in franquicias)
                  () {
                    final (tengo, total) = porFranquicia[f.id] ?? (0, 0);
                    final elegida = _franquicia == f.id;
                    return Semantics(
                      button: true,
                      selected: elegida,
                      label: '${f.nombreCompleto}: $tengo de $total',
                      child: ExcludeSemantics(
                        child: InkWell(
                          onTap: () => setState(() => _franquicia = elegida ? null : f.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 64,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: elegida ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              children: [
                                Escudo(f, tamano: 30),
                                const SizedBox(height: 4),
                                Text('$tengo/$total', style: tema.textTheme.labelSmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ),
        if (mias.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _franquicia == null
                      ? 'Todavía no tenés cartas. Armá un draft o abrí un sobre en la Tienda.'
                      : 'No tenés cartas de esta franquicia todavía.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnas,
                childAspectRatio: 0.64,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: mias.length,
              itemBuilder: (_, i) => CartaVertical(jugador: mias[i]),
            ),
          ),
      ],
    );
  }

  Widget _tiendaVista(BuildContext context, PerfilEntrenador perfil) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Las monedas se ganan jugando (partidos, logros y temporadas). Las cartas repetidas valen '
          '${Tienda.monedasPorRepetida} monedas.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final s in SobreTienda.values) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: s == SobreTienda.leyenda ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                _SobreDibujo(sobre: s),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nombre.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: Fuentes.estadio,
                          fontVariations: [FontVariation.weight(800)],
                          fontSize: 20,
                        ),
                      ),
                      Text(s.descripcion, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _tienda.alcanza(perfil, s) ? () => _comprar(s) : null,
                        icon: const Icon(Icons.toll, size: 18),
                        label: Text('${s.precio}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Sobre cerrado dibujado: rectángulo con su franja y la cantidad de cartas en LED.
class _SobreDibujo extends StatelessWidget {
  const _SobreDibujo({required this.sobre});

  final SobreTienda sobre;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final acento = switch (sobre) {
      SobreTienda.comun => esquema.outline,
      SobreTienda.premium => esquema.secondary,
      SobreTienda.leyenda => esquema.primary,
    };
    return Container(
      width: 64,
      height: 88,
      decoration: BoxDecoration(
        color: esquema.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: acento, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(height: 6, color: acento),
          const SizedBox(height: 10),
          TextoLed('×${sobre.cartas}', tamano: 18, color: acento),
        ],
      ),
    );
  }
}

/// Apertura: las cartas aparecen de a una (o todas juntas sin animaciones).
class _AperturaDialogo extends StatefulWidget {
  const _AperturaDialogo({required this.sobre, required this.apertura});

  final SobreTienda sobre;
  final Apertura apertura;

  @override
  State<_AperturaDialogo> createState() => _AperturaDialogoState();
}

class _AperturaDialogoState extends State<_AperturaDialogo> {
  var _vistas = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _siguiente());
  }

  Future<void> _siguiente() async {
    final instantaneo = MediaQuery.disableAnimationsOf(context);
    while (mounted && _vistas < widget.apertura.cartas.length) {
      if (!instantaneo) await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _vistas++);
      if (widget.apertura.cartas[_vistas - 1].tier == Tier.sPlus) Haptica.fuerte();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final a = widget.apertura;
    return AlertDialog(
      title: Text(widget.sobre.nombre),
      content: SizedBox(
        width: 520,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, c) in a.cartas.indexed)
              SizedBox(
                width: 112,
                child: AnimatedOpacity(
                  opacity: i < _vistas ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    children: [
                      AspectRatio(aspectRatio: 0.64, child: CartaVertical(jugador: c)),
                      const SizedBox(height: 4),
                      Text(
                        a.repetidas.contains(c.id) ? 'REPETIDA · +${Tienda.monedasPorRepetida}' : 'NUEVA',
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: a.repetidas.contains(c.id)
                              ? tema.colorScheme.onSurfaceVariant
                              : tema.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _vistas >= a.cartas.length ? () => Navigator.of(context).pop() : null,
          child: const Text('LISTO'),
        ),
      ],
    );
  }
}
