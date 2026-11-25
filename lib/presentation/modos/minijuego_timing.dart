import 'package:flutter/material.dart';

import '../../domain/modos/carrera_jugador.dart';
import '../../domain/modos/medidor_tiro.dart';

/// Minijuego de timing reutilizable (entrenamientos y concursos): [intentos] veces se llena una barra y hay que
/// tocar en la zona verde. Al terminar, devuelve la [RondaTiming] con la calidad de cada intento.
class MinijuegoTimingPantalla extends StatefulWidget {
  const MinijuegoTimingPantalla({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.intentos,
    required this.ventana,
    this.segundos = 1.0,
  });

  final String titulo, descripcion;
  final int intentos;

  /// Ancho de la zona verde (0 a 1) y lo que tarda en llenarse la barra.
  final double ventana, segundos;

  @override
  State<MinijuegoTimingPantalla> createState() => _MinijuegoTimingState();
}

class _MinijuegoTimingState extends State<MinijuegoTimingPantalla> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.segundos * 1000).round()),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _soltar();
    });
  final _resultados = <CalidadTiro>[];
  CalidadTiro? _ultimo;
  var _esperando = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _soltar() {
    if (_esperando || _resultados.length >= widget.intentos) return;
    _c.stop();
    final calidad = MedidorTiro.evaluar(_c.value, widget.ventana);
    setState(() {
      _resultados.add(calidad);
      _ultimo = calidad;
      _esperando = true;
    });
    if (_resultados.length >= widget.intentos) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop(RondaTiming(List.of(_resultados)));
      });
    } else {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _esperando = false);
        _c.forward(from: 0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final v = widget.ventana;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.titulo), automaticallyImplyLeading: false),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _soltar,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.descripcion, textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Intento ${(_resultados.length + (_esperando ? 0 : 1)).clamp(1, widget.intentos)} de ${widget.intentos}',
                      textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final ancho = c.maxWidth;
                        return AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                top: 12,
                                bottom: 12,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: esquema.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: esquema.outlineVariant),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 12,
                                bottom: 12,
                                width: ancho * _c.value,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: esquema.primary.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: ancho * (MedidorTiro.centro - v / 2),
                                width: ancho * v,
                                top: 8,
                                bottom: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.4),
                                    border: Border.all(color: Colors.green, width: 2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 32,
                    child: Center(child: Text(_ultimo?.etiqueta ?? 'Tocá en la zona verde', style: tema.textTheme.titleLarge)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [for (final q in _resultados) q == CalidadTiro.perfecto ? '★' : (q == CalidadTiro.bueno ? '●' : '○')].join(' '),
                    textAlign: TextAlign.center,
                    style: tema.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
