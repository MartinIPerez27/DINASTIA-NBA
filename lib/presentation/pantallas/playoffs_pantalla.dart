import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/rival.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/motor.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'partido_pantalla.dart';
import 'playbook_pantalla.dart';
import 'stats82_pantalla.dart';

/// Playoffs (GDD §7): cuadro de 16 con series al mejor de 7 hasta Las Finales y el anillo.
/// Tu serie se juega partido a partido (en vivo o simulado) y el resto del cuadro avanza a la par.
class PlayoffsPantalla extends StatefulWidget {
  const PlayoffsPantalla({super.key, required this.temporada, required this.liga, required this.onCambio});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  @override
  State<PlayoffsPantalla> createState() => _PlayoffsPantallaState();
}

class _PlayoffsPantallaState extends State<PlayoffsPantalla> {
  late Temporada _t = widget.liga.iniciarPlayoffs(widget.temporada);
  var _ocupado = false;
  String? _resumen;

  Liga get _liga => widget.liga;

  @override
  void initState() {
    super.initState();
    if (_t.series.length != widget.temporada.series.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCambio(_t));
    }
  }

  void _guardar(Temporada t) {
    setState(() => _t = t);
    widget.onCambio(t);
  }

  Franquicia _identidad(String id) => franquiciaPorId(id == _t.franquiciaUsuarioId ? id : _t.rivales[id]!.identidadId);

  String _nombre(String id) {
    final nombre = _identidad(id).nombreCompleto;
    final r = _t.rivales[id];
    if (r == null) return nombre;
    return '$nombre (${r.tipo == TipoRival.epoca ? r.epoca!.corta : 'Histórico'})';
  }

  String _marcador(SeriePlayoff s) {
    final propio = s.altoId == _t.franquiciaUsuarioId;
    return propio ? '${s.victoriasAlto}-${s.victoriasBajo}' : '${s.victoriasBajo}-${s.victoriasAlto}';
  }

  /// Después de jugar o simular: cómo quedó tu serie (sin mirar resultados de antemano).
  String _resumenSerie(SeriePlayoff antes) {
    final ahora = _t.series.firstWhere(
      (s) => s.ronda == antes.ronda && s.altoId == antes.altoId && s.bajoId == antes.bajoId,
    );
    if (ahora.terminada) {
      return ahora.ganadorId == _t.franquiciaUsuarioId
          ? '¡Ganaste la serie ${_marcador(ahora)}!'
          : 'Perdiste la serie ${_marcador(ahora)}.';
    }
    final jugados = ahora.victoriasAlto + ahora.victoriasBajo;
    final antesPropias = antes.altoId == _t.franquiciaUsuarioId ? antes.victoriasAlto : antes.victoriasBajo;
    final ahoraPropias = ahora.altoId == _t.franquiciaUsuarioId ? ahora.victoriasAlto : ahora.victoriasBajo;
    final gano = ahoraPropias > antesPropias;
    return jugados - (antes.victoriasAlto + antes.victoriasBajo) == 1
        ? '${gano ? 'Ganaste' : 'Perdiste'} el Juego $jugados. Serie ${_marcador(ahora)}.'
        : 'Serie ${_marcador(ahora)}.';
  }

  Future<void> _vivo(SeriePlayoff s) async {
    setState(() => _resumen = null);
    final p = _liga.partidoDeSerie(s);
    final antes = _t;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: _liga.motor(antes, p),
          usuarioLocal: p.localId == _t.franquiciaUsuarioId,
          franquiciaUsuario: franquiciaPorId(_t.franquiciaUsuarioId),
          identidadLocal: _identidad(p.localId),
          identidadVisitante: _identidad(p.visitanteId),
          onTerminado: (MotorPartido m) => _guardar(_liga.registrarPlayoff(antes, s, m)),
        ),
      ),
    );
    if (mounted) setState(() => _resumen = _resumenSerie(s));
  }

  Future<void> _simular(Temporada Function(Temporada) paso, SeriePlayoff? serie) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    final t = paso(_t);
    if (!mounted) return;
    _guardar(t);
    setState(() {
      _ocupado = false;
      final campeon = t.campeonId;
      _resumen = serie != null
          ? _resumenSerie(serie)
          : campeon == null
          ? null
          : 'Campeón: ${_nombre(campeon)}.';
    });
  }

  void _abrirPlaybook() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (c) => PlaybookPantalla(
        temporada: _t,
        onConfirmar: (t) {
          _guardar(t);
          Navigator.of(c).pop();
        },
      ),
    ),
  );

  void _abrirStats() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Stats82Pantalla(temporada: _t, liga: _liga),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final serie = _t.serieDelUsuario;
    final campeon = _t.campeonId;
    final rondas = [
      for (final r in RondaPlayoff.values)
        if (_t.series.any((s) => s.ronda == r)) r,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playoffs'),
        actions: [
          IconButton(onPressed: _abrirStats, icon: const Icon(Icons.leaderboard_outlined), tooltip: 'STATS 82'),
          if (serie != null) IconButton(onPressed: _abrirPlaybook, icon: const Icon(Icons.tune), tooltip: 'Tácticas'),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (campeon != null)
              _Campeon(
                campeon: _identidad(campeon),
                nombre: _nombre(campeon),
                propio: campeon == _t.franquiciaUsuarioId,
                finales: _t.series.last,
                onStats: _abrirStats,
                onInicio: () => Navigator.of(context).popUntil((r) => r.isFirst),
              )
            else if (_liga.esperandoPlayIn(_t))
              _Afuera(
                titulo: 'ENTRASTE DIRECTO',
                texto:
                    'Terminaste entre los 6 primeros: esperás en la 1.ª ronda mientras los puestos 7.º a 10.º '
                    'se juegan el Play-In.',
                boton: 'SIMULAR EL PLAY-IN',
                ocupado: _ocupado,
                onSimular: () => _simular(_liga.simularPlayIn, null),
              )
            else if (serie != null)
              _SerieActual(
                serie: serie,
                usuarioId: _t.franquiciaUsuarioId,
                propia: _identidad(_t.franquiciaUsuarioId),
                rival: _identidad(serie.altoId == _t.franquiciaUsuarioId ? serie.bajoId : serie.altoId),
                nombreRival: _nombre(serie.altoId == _t.franquiciaUsuarioId ? serie.bajoId : serie.altoId),
                local: _liga.partidoDeSerie(serie).localId == _t.franquiciaUsuarioId,
                ocupado: _ocupado,
                onVivo: () => _vivo(serie),
                onSimular: () => _simular(_liga.simularPartidoPlayoff, serie),
                onSimularSerie: () => _simular(_liga.simularSerieUsuario, serie),
              )
            else
              _Afuera(
                texto: switch (_t.eliminacion) {
                  final s? =>
                    'Quedaste afuera en ${s.ronda.etiqueta.toLowerCase().replaceFirst('las ', '')} '
                        '(${_marcador(s)} vs ${_nombre(s.altoId == _t.franquiciaUsuarioId ? s.bajoId : s.altoId)}).',
                  null => 'Tu equipo no entró entre los 10 mejores de su conferencia (ni al Play-In).',
                },
                ocupado: _ocupado,
                onSimular: () => _simular(_liga.simularRestoPlayoffs, null),
              ),
            if (_resumen case final r?) ...[
              const SizedBox(height: 10),
              Text(r, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            for (final ronda in rondas.reversed) ...[
              Text(ronda.etiqueta.toUpperCase(), style: tema.textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final conf in ronda == RondaPlayoff.finalesNba ? [null] : Conferencia.values) ...[
                if (conf != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      conf == Conferencia.este ? 'Este' : 'Oeste',
                      style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ),
                for (final s in _t.series.where(
                  (s) => s.ronda == ronda && (conf == null || franquiciaPorId(s.altoId).conferencia == conf),
                ))
                  _FilaSerie(
                    serie: s,
                    alto: _identidad(s.altoId),
                    bajo: _identidad(s.bajoId),
                    propia: s.altoId == _t.franquiciaUsuarioId || s.bajoId == _t.franquiciaUsuarioId,
                  ),
              ],
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

BoxDecoration _panel(ColorScheme esquema, {bool resaltado = false}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: resaltado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
    width: resaltado ? 2 : 1,
  ),
);

class _SerieActual extends StatelessWidget {
  const _SerieActual({
    required this.serie,
    required this.usuarioId,
    required this.propia,
    required this.rival,
    required this.nombreRival,
    required this.local,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    required this.onSimularSerie,
  });

  final SeriePlayoff serie;
  final String usuarioId;
  final Franquicia propia, rival;
  final String nombreRival;
  final bool local, ocupado;
  final VoidCallback onVivo, onSimular, onSimularSerie;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final altoEsUsuario = serie.altoId == usuarioId;
    final mias = altoEsUsuario ? serie.victoriasAlto : serie.victoriasBajo;
    final suyas = altoEsUsuario ? serie.victoriasBajo : serie.victoriasAlto;
    final juego = serie.victoriasAlto + serie.victoriasBajo + 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(serie.ronda.etiqueta, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
          const SizedBox(height: 10),
          Semantics(
            label: 'Serie $mias a $suyas contra $nombreRival',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Escudo(propia, tamano: 52),
                  Expanded(
                    child: Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: TextoLed('$mias-$suyas', tamano: 48)),
                    ),
                  ),
                  Escudo(rival, tamano: 52),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('vs $nombreRival', style: tema.textTheme.titleMedium),
          Text(
            serie.ronda.esPlayIn
                ? 'Partido único · ${local ? 'de local' : 'de visitante'} · el que gana sigue'
                : 'Juego $juego · ${local ? 'de local' : 'de visitante'} · gana el primero en llegar a 4',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: ocupado ? null : onVivo,
            icon: const Icon(Icons.play_arrow),
            label: const Text('JUGAR EN VIVO'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: ocupado ? null : onSimular,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('SIMULAR'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: ocupado ? null : onSimularSerie,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('SIMULAR SERIE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Afuera extends StatelessWidget {
  const _Afuera({
    required this.texto,
    required this.ocupado,
    required this.onSimular,
    this.titulo = 'FIN DEL CAMINO',
    this.boton = 'SIMULAR HASTA EL CAMPEÓN',
  });

  final String texto, titulo, boton;
  final bool ocupado;
  final VoidCallback onSimular;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(tema.colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(texto, style: tema.textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: ocupado ? null : onSimular,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(boton),
          ),
        ],
      ),
    );
  }
}

class _Campeon extends StatelessWidget {
  const _Campeon({
    required this.campeon,
    required this.nombre,
    required this.propio,
    required this.finales,
    required this.onStats,
    required this.onInicio,
  });

  final Franquicia campeon;
  final String nombre;
  final bool propio;
  final SeriePlayoff finales;
  final VoidCallback onStats, onInicio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ganadas = finales.ganadorId == finales.altoId ? finales.victoriasAlto : finales.victoriasBajo;
    final perdidas = finales.ganadorId == finales.altoId ? finales.victoriasBajo : finales.victoriasAlto;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panel(esquema, resaltado: propio),
      child: Column(
        children: [
          Escudo(campeon, tamano: 96),
          const SizedBox(height: 12),
          Text(
            propio ? '¡CAMPEONES DE LA NBA!' : 'CAMPEÓN DE LA NBA',
            textAlign: TextAlign.center,
            style: tema.textTheme.displayLarge?.copyWith(fontSize: 34, color: propio ? esquema.primary : null),
          ),
          const SizedBox(height: 4),
          Text(nombre, textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            propio
                ? 'El anillo y el Trofeo Larry O’Brien son tuyos ($ganadas-$perdidas en Las Finales).'
                : 'Ganó Las Finales $ganadas-$perdidas.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onStats,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('VER STATS 82 Y PREMIOS'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onInicio,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('VOLVER AL INICIO'),
          ),
        ],
      ),
    );
  }
}

class _FilaSerie extends StatelessWidget {
  const _FilaSerie({required this.serie, required this.alto, required this.bajo, required this.propia});

  final SeriePlayoff serie;
  final Franquicia alto, bajo;
  final bool propia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    Widget lado(Franquicia f, int victorias, bool gano, {required bool derecha}) {
      final apagado = serie.terminada && !gano;
      final color = apagado ? esquema.onSurfaceVariant.withValues(alpha: 0.55) : esquema.onSurface;
      return Expanded(
        child: Row(
          textDirection: derecha ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Opacity(opacity: apagado ? 0.5 : 1, child: Escudo(f, tamano: 28)),
            const SizedBox(width: 8),
            Text(
              f.id,
              style: TextStyle(
                fontFamily: Fuentes.estadio,
                fontVariations: const [FontVariation.weight(800)],
                fontSize: 18,
                color: color,
              ),
            ),
            const Spacer(),
            TextoLed('$victorias', tamano: 22, color: gano ? esquema.primary : color),
          ],
        ),
      );
    }

    return Semantics(
      label:
          '${alto.nombreCompleto} ${serie.victoriasAlto}, ${bajo.nombreCompleto} ${serie.victoriasBajo}'
          '${serie.terminada ? ', terminada' : ''}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: propia ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.4),
              width: propia ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              lado(alto, serie.victoriasAlto, serie.ganadorId == serie.altoId, derecha: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('–', style: TextStyle(color: esquema.onSurfaceVariant)),
              ),
              lado(bajo, serie.victoriasBajo, serie.ganadorId == serie.bajoId, derecha: true),
            ],
          ),
        ),
      ),
    );
  }
}
