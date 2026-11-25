import 'package:flutter/material.dart';

import '../../domain/modos/medidor_tiro.dart';
import '../../domain/motor.dart';

/// La barra de tiro: se llena sola (o mientras mantenés apretado) y hay que soltar en la zona verde. Si se llena del
/// todo, sale tarde. Sirve para tu tiro y, con otro texto, para tu defensa (tapón).
class HojaMedidor extends StatefulWidget {
  const HojaMedidor({
    super.key,
    required this.momento,
    required this.ventana,
    required this.segundos,
    required this.mantener,
    required this.alSoltar,
  });

  final MomentoPendiente momento;

  /// Ancho de la zona verde (0 a 1) y lo que tarda en llenarse.
  final double ventana, segundos;

  /// Mantener apretado mientras se llena y soltar (en vez de tocar).
  final bool mantener;

  final void Function(CalidadTiro calidad, double punto) alSoltar;

  @override
  State<HojaMedidor> createState() => _HojaMedidorState();
}

class _HojaMedidorState extends State<HojaMedidor> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.segundos * 1000).round()),
  )..addStatusListener(_alTerminar);
  var _hecho = false;
  var _empezo = false;

  @override
  void initState() {
    super.initState();
    if (!widget.mantener) _empezar();
  }

  void _empezar() {
    if (_empezo) return;
    _empezo = true;
    _c.forward(from: 0);
  }

  void _alTerminar(AnimationStatus s) {
    if (s == AnimationStatus.completed) _soltar();
  }

  void _soltar() {
    if (_hecho || !_empezo) return;
    _hecho = true;
    _c.stop();
    final punto = _c.value;
    widget.alSoltar(MedidorTiro.evaluar(punto, widget.ventana), punto);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final defensa = widget.momento.tipo == TipoMomento.defensa;
    final titulo = defensa
        ? 'DEFENDÉ A ${widget.momento.nombre.toUpperCase()}'
        : (widget.momento.triple ? '¡TIRÁ DE TRES!' : '¡TIRÁ!');
    final ayuda = defensa
        ? 'Soltá en la zona verde para taparle el tiro.'
        : (widget.mantener ? 'Mantené apretado y soltá en la zona verde.' : 'Tocá en la zona verde.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: esquema.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  ayuda,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final ancho = c.maxWidth;
                      final v = widget.ventana;
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
                            // Llenado.
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
                            // Zona verde y centro perfecto.
                            Positioned(
                              left: ancho * (MedidorTiro.centro - v / 2),
                              width: ancho * v,
                              top: 8,
                              bottom: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2EB872).withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF2EB872), width: 2),
                                ),
                              ),
                            ),
                            Positioned(
                              left: ancho * (MedidorTiro.centro - v * 0.2),
                              width: ancho * v * 0.4,
                              top: 8,
                              bottom: 8,
                              child: const DecoratedBox(decoration: BoxDecoration(color: Color(0xFFB8F5D2))),
                            ),
                            // Marcador.
                            Positioned(
                              left: ancho * _c.value - 2,
                              width: 4,
                              top: 0,
                              bottom: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: esquema.onSurface, borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                widget.mantener
                    ? Listener(
                        onPointerDown: (_) => _empezar(),
                        onPointerUp: (_) => _soltar(),
                        child: FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                          child: const Text('MANTENÉ Y SOLTÁ'),
                        ),
                      )
                    : FilledButton(
                        onPressed: _soltar,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                        child: Text(defensa ? 'TAPAR' : 'SOLTAR'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
