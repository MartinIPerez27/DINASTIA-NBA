import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Bienvenida de la primera vez (se puede volver a ver desde Ajustes).
class TutorialPantalla extends StatefulWidget {
  const TutorialPantalla({super.key, required this.onTerminar});

  final VoidCallback onTerminar;

  @override
  State<TutorialPantalla> createState() => _TutorialPantallaState();
}

class _Pagina {
  const _Pagina(this.titulo, this.texto, this.ilustracion);

  final String titulo;
  final String texto;
  final Widget ilustracion;
}

class _TutorialPantallaState extends State<TutorialPantalla> {
  final _control = PageController();
  var _actual = 0;

  static const _paginas = [
    _Pagina(
      'ELEGÍ TU FRANQUICIA',
      'Recorré las 30 franquicias en el tablero. La app entera se tiñe con los colores de la que elijas.',
      _Escudos(),
    ),
    _Pagina(
      'ARMÁ TU PLANTEL',
      'Ruleta: tirá franquicia, época y rareza, y retené hasta 2 carretes. Cartas: abrí sobres y elegí. '
          'Tenés fichas (tokens) para volver a tirar: se ganan subiendo de nivel.',
      _Carretes(),
    ),
    _Pagina(
      'TÁCTICAS Y DIFICULTAD',
      'El playbook te recomienda un sistema ofensivo y uno defensivo para tu plantel. '
          'La dificultad define qué tan fuertes son los 29 rivales.',
      _Iconos([Icons.tune, Icons.equalizer]),
    ),
    _Pagina(
      'LA TEMPORADA',
      'Mirá cada partido en vivo o simulalo. En vivo podés pausar, pedir tiempo muerto, acelerar el ritmo '
          'y meter presión alta.',
      _Marcador(),
    ),
    _Pagina(
      'MUCHAS FORMAS DE JUGAR',
      'Tocá "Modos de juego" en el inicio: Carrera (Mi carrera, Dinastía), Desafíos, Historia y torneos, '
          'Con amigos y Minijuegos. "Seguir jugando" te lleva a tu última partida.',
      _Iconos([Icons.timeline, Icons.local_fire_department_outlined, Icons.groups_outlined]),
    ),
    _Pagina(
      'ÁLBUM Y TIENDA',
      'Tus cartas se guardan en el Álbum. Con las monedas que ganás comprás sobres en la Tienda: '
          'los dos están en el ícono de cartas del inicio.',
      _Iconos([Icons.style_outlined, Icons.toll, Icons.inventory_2_outlined]),
    ),
    _Pagina(
      'TU CARRERA',
      'Cada partido te da experiencia y monedas. Subí de nivel, desbloqueá ventajas, conseguí logros '
          'y llená tu vitrina de trofeos.',
      _Iconos([Icons.emoji_events_outlined, Icons.military_tech_outlined, Icons.workspace_premium_outlined]),
    ),
  ];

  bool get _ultima => _actual == _paginas.length - 1;

  void _siguiente() {
    if (_ultima) {
      widget.onTerminar();
      return;
    }
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    if (sinAnimaciones) {
      _control.jumpToPage(_actual + 1);
    } else {
      _control.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: TextButton(onPressed: widget.onTerminar, child: const Text('Saltar')),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _control,
                    onPageChanged: (i) => setState(() => _actual = i),
                    children: [
                      for (final p in _paginas)
                        // Con poca altura o letra grande la página se desplaza en vez de desbordarse.
                        LayoutBuilder(
                          builder: (context, c) => SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: c.maxHeight),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 160,
                                    child: FittedBox(fit: BoxFit.scaleDown, child: p.ilustracion),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(p.titulo, textAlign: TextAlign.center, style: tema.textTheme.headlineMedium),
                                  const SizedBox(height: 12),
                                  Text(
                                    p.texto,
                                    textAlign: TextAlign.center,
                                    style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Página ${_actual + 1} de ${_paginas.length}',
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _paginas.length; i++)
                          Container(
                            width: i == _actual ? 18 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _actual ? esquema.primary : esquema.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: FilledButton(
                    onPressed: _siguiente,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(_ultima ? 'EMPEZAR' : 'SIGUIENTE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Escudos extends StatelessWidget {
  const _Escudos();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final id in ['BOS', 'CHI', 'LAL'])
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Escudo(franquiciaPorId(id), tamano: 72)),
    ],
  );
}

class _Carretes extends StatelessWidget {
  const _Carretes();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final v in ['CHI', '90s', 'S+'])
          Container(
            width: 84,
            height: 84,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: esquema.outlineVariant),
            ),
            child: TextoLed(v, tamano: 26),
          ),
      ],
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Escudo(franquiciaPorId('CHI'), tamano: 40),
          const SizedBox(width: 12),
          const TextoLed('104', tamano: 34),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextoLed('Q4', tamano: 12, color: esquema.onSurfaceVariant),
              const TextoLed('0:24', tamano: 18),
            ],
          ),
          const SizedBox(width: 10),
          TextoLed('101', tamano: 34, color: esquema.onSurface),
          const SizedBox(width: 12),
          Escudo(franquiciaPorId('UTA'), tamano: 40),
        ],
      ),
    );
  }
}

class _Iconos extends StatelessWidget {
  const _Iconos(this.iconos);

  final List<IconData> iconos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, icono) in iconos.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(icono, size: i == 1 ? 76 : 56, color: i == 1 ? esquema.primary : esquema.onSurfaceVariant),
          ),
      ],
    );
  }
}
