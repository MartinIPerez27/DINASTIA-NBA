import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/copa.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/rival.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/motor.dart';
import '../pantallas/partido_pantalla.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Copa NBA de mitad de temporada en el hub: el cuadro (cuartos → semis → final), tu partido
/// pendiente (en vivo o simulado) y el campeón. Oculta hasta que arranca la Copa.
class TarjetaCopa extends StatefulWidget {
  const TarjetaCopa({
    super.key,
    required this.temporada,
    required this.liga,
    required this.onCambio,
    required this.franquiciaUsuario,
  });

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;
  final Franquicia franquiciaUsuario;

  @override
  State<TarjetaCopa> createState() => _TarjetaCopaState();
}

class _TarjetaCopaState extends State<TarjetaCopa> {
  var _ocupado = false;

  Temporada get _t => widget.temporada;
  CopaNba get _copa => CopaNba(widget.liga);

  Franquicia _identidad(String id) =>
      franquiciaPorId(id == _t.franquiciaUsuarioId ? id : _t.rivales[id]?.identidadId ?? id);

  /// "Detroit Pistons (90’)" o "Boston Celtics (Histórico)".
  String _nombre(String id) {
    final nombre = _identidad(id).nombreCompleto;
    final r = _t.rivales[id];
    if (r == null) return nombre;
    return '$nombre (${r.tipo == TipoRival.epoca ? r.epoca!.corta : 'Histórico'})';
  }

  Future<void> _vivo(SeriePlayoff s) async {
    final copa = _copa;
    final p = copa.partido(s);
    final antes = _t;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: copa.motor(antes, s),
          usuarioLocal: p.localId == antes.franquiciaUsuarioId,
          franquiciaUsuario: widget.franquiciaUsuario,
          identidadLocal: _identidad(p.localId),
          identidadVisitante: _identidad(p.visitanteId),
          onTerminado: (MotorPartido m) => widget.onCambio(copa.registrar(antes, s, m)),
        ),
      ),
    );
  }

  Future<void> _simular(SeriePlayoff s) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    final copa = _copa;
    final m = copa.motor(_t, s)..simularTodo();
    widget.onCambio(copa.registrar(_t, s, m));
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_t.copa.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final copa = _copa;
    final pendiente = copa.pendienteDelUsuario(_t);
    final campeon = copa.campeon(_t);
    final usuario = _t.franquiciaUsuarioId;
    final propio = campeon == usuario;
    final rondas = [
      for (final r in [RondaPlayoff.copaCuartos, RondaPlayoff.copaSemis, RondaPlayoff.copaFinal])
        [
          for (final s in _t.copa)
            if (s.ronda == r) s,
        ],
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pendiente != null || propio ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
            width: pendiente != null || propio ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.military_tech, color: esquema.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'COPA NBA',
                    style: TextStyle(
                      fontFamily: Fuentes.estadio,
                      fontVariations: [FontVariation.weight(800)],
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'No cuenta para el récord',
                  style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Cuadro: cuartos → semis → final.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, lista) in rondas.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            ['CUARTOS', 'SEMIS', 'FINAL'][i],
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: esquema.onSurfaceVariant,
                              letterSpacing: 1,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                for (final s in lista) _Cruce(serie: s, usuario: usuario, identidad: _identidad),
                                if (lista.isEmpty)
                                  for (var k = 0; k < (i == 1 ? 2 : 1); k++) const _Cruce.vacio(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (pendiente != null) ...[
              Text(
                '${pendiente.ronda.etiqueta.replaceFirst('Copa NBA: ', '').toUpperCase()} · '
                'vs ${_nombre(pendiente.altoId == usuario ? pendiente.bajoId : pendiente.altoId)}',
                style: tema.textTheme.titleSmall,
              ),
              Text(
                'Partido único: el que gana sigue. Si lo dejás pasar ${CopaNba.gracia} jornadas, se simula solo.',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _ocupado ? null : () => _vivo(pendiente),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('JUGAR EN VIVO'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _ocupado ? null : () => _simular(pendiente),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('SIMULAR'),
                    ),
                  ),
                ],
              ),
            ] else if (campeon != null)
              Row(
                children: [
                  Escudo(_identidad(campeon), tamano: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      propio
                          ? '¡Campeones de la Copa NBA! El primer trofeo de la temporada ya está en la vitrina.'
                          : 'Campeón: ${_nombre(campeon)}.',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: propio ? esquema.primary : esquema.onSurface,
                        fontWeight: propio ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                copa.usuarioEliminado(_t)
                    ? 'Quedaste afuera de la Copa. El torneo sigue sin vos.'
                    : copa.usuarioClasifico(_t)
                    ? 'Pasaste de ronda: esperá a tu próximo rival.'
                    : 'Tu equipo no estuvo entre los 4 mejores de su conferencia.',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un cruce del cuadro: dos escudos con siglas; el ganador resaltado, tu equipo con borde.
class _Cruce extends StatelessWidget {
  const _Cruce({
    required SeriePlayoff this.serie,
    required this.usuario,
    required Franquicia Function(String) this.identidad,
  });
  const _Cruce.vacio() : serie = null, usuario = '', identidad = null;

  final SeriePlayoff? serie;
  final String usuario;
  final Franquicia Function(String)? identidad;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final s = serie;
    final propia = s != null && (s.altoId == usuario || s.bajoId == usuario);
    Widget lado(String? id) {
      final gano = s != null && s.terminada && s.ganadorId == id;
      final perdio = s != null && s.terminada && s.ganadorId != id;
      return Opacity(
        opacity: perdio ? 0.4 : 1,
        child: Row(
          children: [
            if (id != null) Escudo(identidad!(id), tamano: 18) else const SizedBox(width: 18, height: 18),
            const SizedBox(width: 4),
            Expanded(
              child: id == null
                  ? Text('–', style: TextStyle(color: esquema.onSurfaceVariant))
                  : TextoLed(identidad!(id).id, tamano: 13, color: gano ? esquema.primary : esquema.onSurface),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: s == null
          ? 'Cruce por definirse'
          : '${identidad!(s.altoId).nombreCompleto} contra ${identidad!(s.bajoId).nombreCompleto}'
                '${s.terminada ? ', ganó ${identidad!(s.ganadorId!).nombreCompleto}' : ''}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: propia ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.4),
              width: propia ? 1.5 : 1,
            ),
          ),
          child: Column(children: [lado(s?.altoId), const SizedBox(height: 2), lado(s?.bajoId)]),
        ),
      ),
    );
  }
}
