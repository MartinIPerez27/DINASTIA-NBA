import 'package:flutter/material.dart';

import '../../domain/entities/posicion.dart';
import '../../domain/entities/rol_cancha.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../widgets/disposicion.dart';
import '../widgets/texto_led.dart';

/// Creador de jugadores (reutilizable: Mi carrera, modo universitario…). Devuelve el
/// [JugadorCreado] con `Navigator.pop`, o null si se vuelve atrás.
class CreadorJugadorPantalla extends StatefulWidget {
  const CreadorJugadorPantalla({
    super.key,
    this.titulo = 'Creá tu jugador',
    this.textoBoton = 'CONTINUAR',
    this.nombreInicial = '',
    this.nacimiento,
    this.posicionInicial = Posicion.escolta,
  });

  final String titulo, textoBoton, nombreInicial;

  /// Año de nacimiento que se le pone al jugador (opcional).
  final int? nacimiento;
  final Posicion posicionInicial;

  @override
  State<CreadorJugadorPantalla> createState() => _CreadorJugadorPantallaState();
}

class _CreadorJugadorPantallaState extends State<CreadorJugadorPantalla> {
  late final _nombre = TextEditingController(text: widget.nombreInicial);
  late Posicion _posicion = widget.posicionInicial;
  late RolCancha _rol = JugadorCreado.rolesDe(_posicion).first;
  late double _altura = JugadorCreado.alturaSugerida(_posicion).toDouble();
  var _peso = 92.0;
  final _fuertes = <Atributo>[Atributo.tiro, Atributo.iq, Atributo.defensa];

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  JugadorCreado get _jugador => JugadorCreado(
    nombre: _nombre.text,
    posicion: _posicion,
    rol: _rol,
    fuertes: List.of(_fuertes),
    alturaCm: _altura.round(),
    pesoKg: _peso.round(),
    nacimiento: widget.nacimiento,
  );

  void _elegirPosicion(Posicion p) => setState(() {
    _posicion = p;
    _rol = JugadorCreado.rolesDe(p).first;
    _altura = JugadorCreado.alturaSugerida(p).toDouble();
    _peso = (70 + (_altura - 180) * 1.0).clamp(70, 150);
  });

  void _alternarFuerte(Atributo a) => setState(() {
    if (_fuertes.contains(a)) {
      _fuertes.remove(a);
    } else if (_fuertes.length < 3) {
      _fuertes.add(a);
    }
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final jugador = _jugador;
    final error = jugador.error;
    final formulario = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'Nombre y apellido', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text('PUESTO', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in Posicion.titulares)
              ChoiceChip(label: Text(p.etiqueta), selected: p == _posicion, onSelected: (_) => _elegirPosicion(p)),
          ],
        ),
        const SizedBox(height: 16),
        Text('ARQUETIPO', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in JugadorCreado.rolesDe(_posicion))
              ChoiceChip(label: Text(r.etiqueta), selected: r == _rol, onSelected: (_) => setState(() => _rol = r)),
          ],
        ),
        const SizedBox(height: 16),
        _Deslizador(
          etiqueta: 'ALTURA',
          valor: '${_altura.round()} cm',
          slider: Slider(
            value: _altura,
            min: JugadorCreado.alturaMin.toDouble(),
            max: JugadorCreado.alturaMax.toDouble(),
            divisions: JugadorCreado.alturaMax - JugadorCreado.alturaMin,
            onChanged: (v) => setState(() => _altura = v),
          ),
        ),
        _Deslizador(
          etiqueta: 'PESO',
          valor: '${_peso.round()} kg',
          slider: Slider(
            value: _peso,
            min: JugadorCreado.pesoMin.toDouble(),
            max: JugadorCreado.pesoMax.toDouble(),
            divisions: JugadorCreado.pesoMax - JugadorCreado.pesoMin,
            onChanged: (v) => setState(() => _peso = v),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('TRES PUNTOS FUERTES', style: tema.textTheme.labelLarge),
            const Spacer(),
            Text('${_fuertes.length}/3', style: tema.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in Atributo.values)
              FilterChip(
                label: Text(a.etiqueta),
                selected: _fuertes.contains(a),
                onSelected: (_) => _alternarFuerte(a),
                tooltip: a.descripcion,
              ),
          ],
        ),
      ],
    );
    final vista = _VistaPrevia(jugador: jugador, error: error);
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(flex: 6, child: formulario),
                  Expanded(
                    flex: 5,
                    child: Padding(padding: const EdgeInsets.fromLTRB(0, 8, 24, 24), child: _conBoton(vista, error)),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(child: formulario),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _conBoton(vista, error, compacto: true),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _conBoton(Widget vista, String? error, {bool compacto = false}) => Column(
    mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (compacto) vista else Expanded(child: SingleChildScrollView(child: vista)),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: error == null ? () => Navigator.of(context).pop(_jugador) : null,
        child: Text(widget.textoBoton),
      ),
    ],
  );
}

class _Deslizador extends StatelessWidget {
  const _Deslizador({required this.etiqueta, required this.valor, required this.slider});

  final String etiqueta, valor;
  final Slider slider;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        SizedBox(width: 72, child: Text(etiqueta, style: tema.textTheme.labelLarge)),
        Expanded(child: slider),
        SizedBox(
          width: 70,
          child: Text(valor, textAlign: TextAlign.end, style: tema.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// Cómo arranca el jugador: media, estadísticas y atributos, en vivo mientras lo armás.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({required this.jugador, required this.error});

  final JugadorCreado jugador;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ok = error == null;
    final a = jugador.atributos;
    final s = jugador.estadisticas;
    String n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    return Container(
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
              TextoLed('${jugador.media}', tamano: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jugador.nombre.trim().isEmpty ? 'Tu jugador' : jugador.nombre.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium,
                    ),
                    Text(
                      '${jugador.posicion.etiqueta} · ${jugador.rol.etiqueta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Dato('PPP', n(s.ppp)),
              _Dato('RPP', n(s.rpp)),
              _Dato('APP', n(s.app)),
              _Dato('%T3', '${(s.pctT3 * 100).round()}'),
              _Dato('IQ', '${s.iq}'),
            ],
          ),
          const SizedBox(height: 8),
          for (final x in Atributo.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 108, child: Text(x.etiqueta, style: tema.textTheme.bodySmall)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: a[x] / 99, minHeight: 6),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('${a[x]}', textAlign: TextAlign.end, style: tema.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          if (!ok) ...[
            const SizedBox(height: 8),
            Text(error!, style: tema.textTheme.bodySmall?.copyWith(color: esquema.error)),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

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
