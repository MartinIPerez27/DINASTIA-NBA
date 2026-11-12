import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/tactica.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/playbook.dart';
import '../widgets/texto_led.dart';
import '../widgets/haptica.dart';

enum _Lado { ofensiva, defensiva }

/// Playbook (GDD §5): 10 sistemas ofensivos y 10 defensivos con su afinidad (1–99) al plantel,
/// y el asistente que recomienda la mejor pareja. [onConfirmar] recibe la temporada con la
/// táctica elegida y confirmada.
class PlaybookPantalla extends StatefulWidget {
  const PlaybookPantalla({super.key, required this.temporada, required this.onConfirmar});

  final Temporada temporada;
  final ValueChanged<Temporada> onConfirmar;

  @override
  State<PlaybookPantalla> createState() => _PlaybookPantallaState();
}

class _PlaybookPantallaState extends State<PlaybookPantalla> {
  late final _perfil = PerfilPlantel.de(widget.temporada.plantel);
  late final _recomendacion = recomendar(_perfil);
  late Tactica _tactica = widget.temporada.tacticaConfirmada ? widget.temporada.tactica : _recomendacion.tactica;
  _Lado _lado = _Lado.ofensiva;

  String _motivos(Map<Rasgo, int> rasgos) => [
    for (final (rasgo, figura) in _perfil.motivos(rasgos))
      if (figura != null) '${rasgo.etiqueta}: ${figura.nombre} (${PerfilPlantel.evidencia(rasgo, figura)})',
  ].join(' · ');

  void _elegir(Tactica t) {
    Haptica.seleccion();
    setState(() => _tactica = t);
  }

  @override
  Widget build(BuildContext context) {
    final franquicia = franquiciaPorId(widget.temporada.franquiciaUsuarioId);
    final rec = _recomendacion;

    final opciones = _lado == _Lado.ofensiva
        ? [
            for (final o in SistemaOfensivo.values)
              (
                nombre: o.nombre,
                descripcion: o.descripcion,
                afinidad: _perfil.afinidad(o.rasgos),
                motivos: _motivos(o.rasgos),
                elegida: _tactica.ofensiva == o,
                recomendada: rec.tactica.ofensiva == o,
                elegir: () => _elegir(_tactica.copyWith(ofensiva: o)),
              ),
          ]
        : [
            for (final d in EsquemaDefensivo.values)
              (
                nombre: d.nombre,
                descripcion: d.descripcion,
                afinidad: _perfil.afinidad(d.rasgos),
                motivos: _motivos(d.rasgos),
                elegida: _tactica.defensiva == d,
                recomendada: rec.tactica.defensiva == d,
                elegir: () => _elegir(_tactica.copyWith(defensiva: d)),
              ),
          ];
    opciones.sort((a, b) => b.afinidad.compareTo(a.afinidad));

    return Scaffold(
      appBar: AppBar(title: Text('Playbook de los ${franquicia.nombre}')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _PanelRecomendacion(
                recomendacion: rec,
                motivosOfensiva: _motivos(rec.tactica.ofensiva.rasgos),
                motivosDefensiva: _motivos(rec.tactica.defensiva.rasgos),
                enUso: _tactica == rec.tactica,
                onUsar: () => _elegir(rec.tactica),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<_Lado>(
                segments: const [
                  ButtonSegment(value: _Lado.ofensiva, label: Text('Ofensiva')),
                  ButtonSegment(value: _Lado.defensiva, label: Text('Defensiva')),
                ],
                selected: {_lado},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _lado = s.first),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                itemCount: opciones.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final o = opciones[i];
                  return _OpcionSistema(
                    nombre: o.nombre,
                    descripcion: o.descripcion,
                    afinidad: o.afinidad,
                    motivos: o.motivos,
                    elegida: o.elegida,
                    recomendada: o.recomendada,
                    onTap: o.elegir,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: () =>
                    widget.onConfirmar(widget.temporada.copyWith(tactica: _tactica, tacticaConfirmada: true)),
                child: const Text('CONFIRMAR TÁCTICAS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelRecomendacion extends StatelessWidget {
  const _PanelRecomendacion({
    required this.recomendacion,
    required this.motivosOfensiva,
    required this.motivosDefensiva,
    required this.enUso,
    required this.onUsar,
  });

  final Recomendacion recomendacion;
  final String motivosOfensiva;
  final String motivosDefensiva;
  final bool enUso;
  final VoidCallback onUsar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final t = recomendacion.tactica;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('LA RECOMENDACIÓN DEL ASISTENTE', style: tema.textTheme.headlineSmall?.copyWith(fontSize: 20)),
            const SizedBox(height: 10),
            _Linea(afinidad: recomendacion.afinidadOfensiva, nombre: t.ofensiva.nombre, motivos: motivosOfensiva),
            const SizedBox(height: 8),
            _Linea(afinidad: recomendacion.afinidadDefensiva, nombre: t.defensiva.nombre, motivos: motivosDefensiva),
            const SizedBox(height: 10),
            enUso
                ? Text(
                    'Estás usando esta combinación.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  )
                : FilledButton.tonal(
                    onPressed: onUsar,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    child: const Text('Usar la recomendación'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.afinidad, required this.nombre, required this.motivos});

  final int afinidad;
  final String nombre;
  final String motivos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      label: '$nombre, afinidad $afinidad. $motivos',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 48, child: TextoLed('$afinidad'.padLeft(2, '0'), tamano: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre.toUpperCase(), style: tema.textTheme.headlineSmall?.copyWith(fontSize: 18)),
                  Text(motivos, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionSistema extends StatelessWidget {
  const _OpcionSistema({
    required this.nombre,
    required this.descripcion,
    required this.afinidad,
    required this.motivos,
    required this.elegida,
    required this.recomendada,
    required this.onTap,
  });

  final String nombre;
  final String descripcion;
  final int afinidad;
  final String motivos;
  final bool elegida;
  final bool recomendada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Semantics(
      button: true,
      selected: elegida,
      label: '$nombre, afinidad $afinidad${recomendada ? ', recomendada' : ''}. $descripcion',
      child: ExcludeSemantics(
        child: Material(
          color: esquema.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: elegida ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
              width: elegida ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: TextoLed(
                      '$afinidad'.padLeft(2, '0'),
                      tamano: 26,
                      color: elegida ? esquema.primary : esquema.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                nombre.toUpperCase(),
                                style: tema.textTheme.headlineSmall?.copyWith(fontSize: 18),
                              ),
                            ),
                            if (recomendada) ...[
                              const SizedBox(width: 8),
                              Text(
                                'RECOMENDADA',
                                style: tema.textTheme.labelSmall?.copyWith(
                                  color: esquema.primary,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(descripcion, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                        if (elegida && motivos.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(motivos, style: tema.textTheme.bodySmall),
                        ],
                      ],
                    ),
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
