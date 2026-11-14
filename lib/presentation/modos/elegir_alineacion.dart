import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/modos/competitivo.dart';
import '../../domain/modos/evoluciones.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/disposicion.dart';
import '../widgets/texto_led.dart';

/// Pantalla para armar tu equipo con las cartas de [pool] (tu álbum, y en Conquista también las de
/// los territorios que ganaste). Devuelve la alineación (puesto → id de carta) al confirmar.
class ElegirAlineacionPantalla extends StatefulWidget {
  const ElegirAlineacionPantalla({
    super.key,
    required this.pool,
    this.inicial = const {},
    this.titulo = 'Armá tu equipo',
    this.ayuda,
  });

  final List<Jugador> pool;
  final Alineacion inicial;
  final String titulo;

  /// Una línea de explicación arriba de la lista.
  final String? ayuda;

  @override
  State<ElegirAlineacionPantalla> createState() => _ElegirAlineacionPantallaState();
}

class _ElegirAlineacionPantallaState extends State<ElegirAlineacionPantalla> {
  /// Las cartas con la media que les dieron sus evoluciones (valen en los modos del álbum).
  late final List<Jugador> _pool = aplicarEvoluciones(perfilApp.value, widget.pool, usaAlbum: true);
  late final Map<String, Jugador> _porId = {for (final j in _pool) j.id: j};
  late Map<Posicion, Jugador> _elegidas = {
    for (final e in widget.inicial.entries)
      if (_porId[e.value] != null) e.key: _porId[e.value]!,
  };
  late Posicion _puesto = _primerVacio ?? Posicion.base;
  var _busqueda = '';

  Posicion? get _primerVacio {
    for (final p in Posicion.values) {
      if (!_elegidas.containsKey(p)) return p;
    }
    return null;
  }

  bool get _completa => _elegidas.length == Posicion.values.length;

  List<Jugador> get _candidatas {
    final texto = _busqueda.trim().toLowerCase();
    final personas = {
      for (final e in _elegidas.entries)
        if (e.key != _puesto) e.value.nbaPlayerId,
    };
    return [
      for (final j in _pool)
        if (j.puedeJugarEn(_puesto) &&
            !personas.contains(j.nbaPlayerId) &&
            (texto.isEmpty || j.nombre.toLowerCase().contains(texto)))
          j,
    ]..sort((a, b) => mediaDe(b).compareTo(mediaDe(a)));
  }

  void _elegir(Jugador j) {
    setState(() {
      _elegidas = {..._elegidas, _puesto: j};
      _puesto = _primerVacio ?? _puesto;
    });
  }

  void _automatico() {
    final fijas = {for (final e in _elegidas.entries) e.key: e.value};
    final a = mejorAlineacion(_pool, fijas: fijas) ?? mejorAlineacion(_pool);
    if (a == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Con estas cartas no alcanza para los 6 puestos.')));
      return;
    }
    setState(() {
      _elegidas = {for (final e in a.entries) e.key: _porId[e.value]!};
      _puesto = Posicion.base;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final candidatas = _candidatas;

    final puestos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.ayuda != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.ayuda!, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
          ),
        for (final pos in Posicion.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: pos == _puesto ? esquema.primary.withValues(alpha: 0.12) : esquema.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: pos == _puesto ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _puesto = pos),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 96, child: Text(pos.etiqueta, style: tema.textTheme.labelMedium)),
                      Expanded(
                        child: Text(
                          _elegidas[pos]?.nombre ?? 'Elegí una carta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: _elegidas[pos] == null ? esquema.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                      if (_elegidas[pos] case final j?) ...[
                        TextoLed('${mediaDe(j)}', tamano: 16),
                        IconButton(
                          tooltip: 'Sacar a ${j.nombre}',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _elegidas = {..._elegidas}..remove(pos);
                            _puesto = pos;
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final botones = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _automatico,
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('COMPLETAR CON LAS MEJORES'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _completa
              ? () =>
                    Navigator.of(context).pop(<Posicion, String>{for (final e in _elegidas.entries) e.key: e.value.id})
              : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(_completa ? 'CONFIRMAR EQUIPO' : 'FALTAN ${Posicion.values.length - _elegidas.length} PUESTOS'),
        ),
      ],
    );

    final lista = Column(
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar para ${_puesto.etiqueta.toLowerCase()}…',
            isDense: true,
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: candidatas.isEmpty
              ? Center(
                  child: Text(
                    'No hay cartas para ese puesto.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  itemCount: candidatas.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CartaJugador(
                        jugador: candidatas[i],
                        seleccionada: _elegidas[_puesto]?.id == candidatas[i].id,
                        onTap: () => _elegir(candidatas[i]),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 420,
                      child: SingleChildScrollView(
                        child: Column(children: [puestos, const SizedBox(height: 8), botones]),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: lista),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  children: [
                    puestos,
                    const SizedBox(height: 4),
                    botones,
                    const Divider(),
                    Expanded(child: lista),
                  ],
                ),
              ),
      ),
    );
  }
}
