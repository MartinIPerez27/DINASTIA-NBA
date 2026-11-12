import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/ajustes.dart';

/// Ajustes del jugador. Cada cambio se avisa con [onCambio] (la app lo guarda).
class AjustesPantalla extends StatefulWidget {
  const AjustesPantalla({super.key, required this.onCambio, required this.onTutorial});

  final ValueChanged<Ajustes> onCambio;
  final VoidCallback onTutorial;

  @override
  State<AjustesPantalla> createState() => _AjustesPantallaState();
}

class _AjustesPantallaState extends State<AjustesPantalla> {
  late Ajustes _a = ajustesApp.value;

  void _cambiar(Ajustes nuevo) {
    setState(() => _a = nuevo);
    widget.onCambio(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(texto, style: tema.textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                titulo('Partido en vivo'),
                ListTile(
                  title: const Text('Velocidad al empezar'),
                  subtitle: Text(
                    'Con la que arranca cada partido; después la podés cambiar.',
                    style: TextStyle(color: esquema.onSurfaceVariant),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('x1')),
                      ButtonSegment(value: 2, label: Text('x2')),
                      ButtonSegment(value: 4, label: Text('x4')),
                    ],
                    selected: {_a.velocidad},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => _cambiar(_a.copyWith(velocidad: s.first)),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Sonido'),
                  subtitle: const Text('Pique, red, chicharra y el público.'),
                  value: _a.sonido,
                  onChanged: (v) => _cambiar(_a.copyWith(sonido: v)),
                ),
                SwitchListTile(
                  title: const Text('Voz del relator'),
                  subtitle: const Text(
                    'El relator lee las jugadas con la voz del celular (sin internet; necesita la voz en español instalada).',
                  ),
                  value: _a.vozRelator,
                  onChanged: (v) => _cambiar(_a.copyWith(vozRelator: v)),
                ),
                SwitchListTile(
                  title: const Text('Efectos reducidos'),
                  subtitle: const Text('Sin zoom de cámara: la cancha queda fija de lado a lado.'),
                  value: _a.efectosReducidos,
                  onChanged: (v) => _cambiar(_a.copyWith(efectosReducidos: v)),
                ),
                titulo('General'),
                SwitchListTile(
                  title: const Text('Vibración'),
                  subtitle: const Text('Al anotar, al revelar cartas y en los botones.'),
                  value: _a.vibracion,
                  onChanged: (v) => _cambiar(_a.copyWith(vibracion: v)),
                ),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Ver el tutorial'),
                  onTap: widget.onTutorial,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
