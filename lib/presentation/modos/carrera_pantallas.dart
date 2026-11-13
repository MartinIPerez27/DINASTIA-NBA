import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/dinastia.dart';
import '../compartir/tarjeta_compartir.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/texto_led.dart';

/// Fin de temporada de un modo de carrera: resumen, retiros, cómo envejeció el plantel y el draft de
/// novatos (1 de 3 por puesto libre). Al arrancar, devuelve la temporada siguiente por [onArrancar].
class RecesoPantalla extends StatefulWidget {
  const RecesoPantalla({
    super.key,
    required this.temporada,
    required this.carrera,
    required this.nombreDe,
    required this.onArrancar,
  });

  final Temporada temporada;
  final CarreraDinastia carrera;
  final String Function(String id) nombreDe;
  final Future<void> Function(Temporada nueva) onArrancar;

  @override
  State<RecesoPantalla> createState() => _RecesoPantallaState();
}

class _RecesoPantallaState extends State<RecesoPantalla> {
  late final Receso _r = widget.carrera.receso(widget.temporada, widget.nombreDe);
  late final EstadoDinastia _estado = EstadoDinastia.de(widget.temporada);
  final _elegidos = <Posicion, Jugador>{};
  var _ocupado = false;

  bool get _listo => _r.vacantes.every(_elegidos.containsKey);

  Future<void> _arrancar() async {
    setState(() => _ocupado = true);
    final nueva = widget.carrera.siguiente(widget.temporada, _r, _elegidos);
    await widget.onArrancar(nueva);
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final p = _r.pasada;
    final reescribi = widget.temporada.modoJuego == ModoJuego.reescribi;
    TextStyle? seccion() => tema.textTheme.titleMedium?.copyWith(letterSpacing: 0.5);

    return Scaffold(
      appBar: AppBar(title: Text('Receso · temporada ${_estado.numero}')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: p.campeon ? esquema.primary : esquema.outlineVariant,
                  width: p.campeon ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FIN DE LA TEMPORADA ${p.numero}',
                          style: tema.textTheme.headlineSmall?.copyWith(color: p.campeon ? esquema.primary : null),
                        ),
                      ),
                      TextoLed('${p.victorias}-${p.derrotas}', tamano: 22, color: esquema.primary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final linea in narrar(p)) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(linea)),
                ],
              ),
            ),
            if (_r.epocaNueva != null && _r.epocaNueva != _estado.epoca) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: TextoLed(_r.epocaNueva!.codigo, tamano: 18, color: esquema.primary),
                  title: Text('¡Empiezan ${_r.epocaNueva!.etiqueta.toLowerCase()}!'),
                  subtitle: const Text('Los rivales juegan con sus planteles de la nueva década.'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('RETIROS', style: seccion()),
            const SizedBox(height: 4),
            if (_r.retiros.isEmpty)
              Text('Nadie cuelga las zapatillas este año.', style: TextStyle(color: esquema.onSurfaceVariant)),
            for (final x in _r.retiros)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.waving_hand_outlined, color: esquema.primary),
                title: Text(x.jugador.nombre),
                subtitle: Text(x.frase),
              ),
            const SizedBox(height: 16),
            Text('TU PLANTEL, UN AÑO DESPUÉS', style: seccion()),
            const SizedBox(height: 4),
            for (final pos in Posicion.values)
              if (_r.plantel.en(pos) case final j?)
                _FilaEnvejecida(posicion: pos, jugador: j, edad: _r.edades[j.id], cambio: _r.cambios[j.id]),
            for (final j in _r.suplentes)
              _FilaEnvejecida(posicion: null, jugador: j, edad: _r.edades[j.id], cambio: _r.cambios[j.id]),
            const SizedBox(height: 16),
            Text('DRAFT DE NOVATOS', style: seccion()),
            const SizedBox(height: 4),
            Text(
              _r.opciones.isEmpty
                  ? 'No hay lugar en el plantel ni en el banco largo: este año no hay draft.'
                  : _r.draftParaElBanco
                  ? 'No quedó ningún puesto libre: si querés, sumá un novato al banco largo.'
                  : 'Elegí 1 de 3 para cada puesto libre.${reescribi ? ' Son jugadores de la década siguiente: llegan unos puntos más abajo y crecen con los años.' : ''}',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            for (final e in _r.opciones.entries) ...[
              const SizedBox(height: 10),
              Text(
                _r.draftParaElBanco ? 'BANCO LARGO' : e.key.etiqueta.toUpperCase(),
                style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary),
              ),
              const SizedBox(height: 4),
              for (final j in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _ConTilde(
                      marcada: _elegidos[e.key]?.id == j.id,
                      child: CartaJugador(
                        jugador: j,
                        seleccionada: _elegidos[e.key]?.id == j.id,
                        onTap: () => setState(() {
                          if (_r.draftParaElBanco && _elegidos[e.key]?.id == j.id) {
                            _elegidos.remove(e.key);
                          } else {
                            _elegidos[e.key] = j;
                          }
                        }),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _listo && !_ocupado ? _arrancar : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.play_arrow),
              label: Text('ARRANCAR LA TEMPORADA ${_estado.numero + 1}'),
            ),
            if (!_listo)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Falta elegir: ${_r.vacantes.where((v) => !_elegidos.containsKey(v)).map((v) => v.etiqueta).join(', ')}.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carta del mini-draft con una tilde cuando está elegida.
class _ConTilde extends StatelessWidget {
  const _ConTilde({required this.marcada, required this.child});

  final bool marcada;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(width: 8),
        AnimatedOpacity(
          opacity: marcada ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Icon(Icons.check_circle, color: esquema.primary, size: 28),
        ),
      ],
    );
  }
}

class _FilaEnvejecida extends StatelessWidget {
  const _FilaEnvejecida({required this.posicion, required this.jugador, required this.edad, required this.cambio});

  final Posicion? posicion;
  final Jugador jugador;
  final int? edad;
  final int? cambio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final c = cambio ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(jugador.nombre),
      subtitle: Text('${posicion?.etiqueta.toUpperCase() ?? 'SUPLENTE'}${edad == null ? '' : ' · $edad años'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c != 0) ...[
            Icon(
              c > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: c > 0 ? Colors.greenAccent.shade400 : esquema.error,
            ),
            Text(
              '${c > 0 ? '+' : ''}$c',
              style: tema.textTheme.labelLarge?.copyWith(color: c > 0 ? Colors.greenAccent.shade400 : esquema.error),
            ),
          ],
          const SizedBox(width: 10),
          TextoLed('${jugador.media}', tamano: 18, color: esquema.primary),
        ],
      ),
    );
  }
}

/// Línea de tiempo narrada de la dinastía: una tarjeta por temporada, de la primera a la actual.
class HistoriaDinastiaPantalla extends StatelessWidget {
  const HistoriaDinastiaPantalla({super.key, required this.temporada});

  final Temporada temporada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final estado = EstadoDinastia.de(temporada);
    final franquicia = franquiciaPorId(temporada.franquiciaUsuarioId);
    final r = temporada.registroUsuario;
    final enCurso = switch (temporada.fase) {
      FaseTemporada.draft || FaseTemporada.tacticas => 'Por empezar: armando el plantel y las tácticas.',
      FaseTemporada.temporadaRegular => 'En juego: ${r.victorias}-${r.derrotas}.',
      FaseTemporada.playoffs => 'En los playoffs, después de un ${r.victorias}-${r.derrotas}.',
      FaseTemporada.finalizada => 'Terminada: ${r.victorias}-${r.derrotas}. Falta el receso.',
    };
    final titulos = estado.titulos + (temporada.campeonId == temporada.franquiciaUsuarioId ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia de la dinastía'),
        actions: [BotonCompartir(temporada: temporada)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            temporada.modoJuego == ModoJuego.reescribi
                ? 'Los ${franquicia.nombre}, reescribiendo la historia'
                : 'La dinastía de los ${franquicia.nombre}',
            style: tema.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${estado.numero} ${estado.numero == 1 ? 'temporada' : 'temporadas'} · '
                '$titulos ${titulos == 1 ? 'anillo' : 'anillos'}',
                style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
              ),
              for (var i = 0; i < titulos; i++) Icon(Icons.emoji_events, size: 18, color: esquema.primary),
            ],
          ),
          const SizedBox(height: 16),
          for (final p in estado.historial)
            _Hito(
              numero: p.numero,
              titulo: 'TEMPORADA ${p.numero}',
              epoca: p.epoca,
              lineas: narrar(p),
              campeon: p.campeon,
              ultimo: false,
            ),
          _Hito(
            numero: estado.numero,
            titulo: 'TEMPORADA ${estado.numero}',
            epoca: estado.epoca,
            lineas: [enCurso],
            campeon: temporada.campeonId == temporada.franquiciaUsuarioId,
            ultimo: true,
            actual: true,
          ),
          if (estado.historial.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Todo empieza acá. Cada temporada que termines se va a contar en esta línea de tiempo.',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hito extends StatelessWidget {
  const _Hito({
    required this.numero,
    required this.titulo,
    required this.epoca,
    required this.lineas,
    required this.campeon,
    required this.ultimo,
    this.actual = false,
  });

  final int numero;
  final String titulo;
  final Epoca? epoca;
  final List<String> lineas;
  final bool campeon, ultimo, actual;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: campeon ? esquema.primary : esquema.surfaceContainerHigh,
                    border: Border.all(color: actual ? esquema.primary : esquema.outlineVariant, width: 2),
                  ),
                  child: campeon
                      ? Icon(Icons.emoji_events, size: 18, color: esquema.onPrimary)
                      : Text('$numero', style: tema.textTheme.labelLarge),
                ),
                if (!ultimo) Expanded(child: Container(width: 2, color: esquema.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titulo,
                          style: tema.textTheme.titleMedium?.copyWith(color: campeon ? esquema.primary : null),
                        ),
                      ),
                      if (epoca != null) ...[
                        const SizedBox(width: 8),
                        TextoLed(epoca!.codigo, tamano: 14, color: esquema.primary),
                      ],
                      if (actual) ...[
                        const SizedBox(width: 8),
                        Text('EN CURSO', style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final l in lineas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(l, style: tema.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
