import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/historias.dart';
import '../../domain/liga.dart';
import '../tema/tema_franquicia.dart';
import 'escudo.dart';

// Tarjetas de historias entre partidos (ver `domain/historias.dart`): titulares con drama y reacciones.
// Estilo "El Marcador": paneles mates, títulos de estadio, sin sombras.

IconData iconoDeHistoria(TipoHistoria tipo) => switch (tipo) {
  TipoHistoria.inicio => Icons.flag_outlined,
  TipoHistoria.invicto => Icons.verified_outlined,
  TipoHistoria.caidaInvicto => Icons.heart_broken_outlined,
  TipoHistoria.racha => Icons.local_fire_department_outlined,
  TipoHistoria.finRacha => Icons.content_cut,
  TipoHistoria.crisis => Icons.warning_amber_rounded,
  TipoHistoria.respiro => Icons.air,
  TipoHistoria.lesion => Icons.healing_outlined,
  TipoHistoria.rival => Icons.visibility_outlined,
  TipoHistoria.hito => Icons.military_tech_outlined,
  TipoHistoria.record => Icons.history_edu,
  TipoHistoria.mvp => Icons.emoji_events_outlined,
  TipoHistoria.duelo => Icons.compare_arrows,
  TipoHistoria.mejorado => Icons.trending_up,
  TipoHistoria.bisagra => Icons.sports_basketball_outlined,
  TipoHistoria.serie => Icons.stadium_outlined,
  TipoHistoria.resumen => Icons.bar_chart,
};

/// Qué historias son malas noticias (para teñirlas con el color de alerta).
bool esMalaNoticia(TipoHistoria t) =>
    t == TipoHistoria.caidaInvicto ||
    t == TipoHistoria.finRacha ||
    t == TipoHistoria.crisis ||
    t == TipoHistoria.lesion;

Franquicia _identidad(Temporada t, String id) =>
    franquiciaPorId(id == t.franquiciaUsuarioId ? id : t.rivales[id]?.identidadId ?? id);

/// Una historia: etiqueta, titular, texto y, si la hay, la reacción (DT, vestuario, prensa, afición).
class TarjetaHistoria extends StatelessWidget {
  const TarjetaHistoria({super.key, required this.historia, this.escudo, this.principal = false});

  final Historia historia;

  /// Escudo de la franquicia protagonista (si la hay).
  final Franquicia? escudo;

  /// La historia grande de la lista (borde resaltado y titular más grande).
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final mala = esMalaNoticia(historia.tipo);
    final acento = mala ? esquema.error : esquema.primary;
    return Semantics(
      container: true,
      label: '${historia.tipo.etiqueta}. ${historia.titulo}. ${historia.texto}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: principal || historia.destacado
                  ? acento.withValues(alpha: principal ? 1 : 0.55)
                  : esquema.outlineVariant.withValues(alpha: 0.5),
              width: principal ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: acento.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(iconoDeHistoria(historia.tipo), size: 20, color: acento),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      historia.tipo.etiqueta.toUpperCase() +
                          (historia.jornada > 0 && historia.jornada < 1000 ? ' · J${historia.jornada}' : ''),
                      style: tema.textTheme.labelSmall?.copyWith(color: acento, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      historia.titulo,
                      style: TextStyle(
                        fontFamily: Fuentes.estadio,
                        fontVariations: const [FontVariation.weight(800)],
                        fontSize: principal ? 24 : 19,
                        height: 1.05,
                        letterSpacing: 0.3,
                        color: esquema.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(historia.texto, style: tema.textTheme.bodyMedium),
                    if (historia.reaccion case final r?) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: acento.withValues(alpha: 0.6), width: 2)),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${r.voz.toUpperCase()}  ',
                                style: tema.textTheme.labelSmall?.copyWith(
                                  color: esquema.onSurfaceVariant,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: '«${r.cita}»',
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: esquema.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (escudo != null) ...[const SizedBox(width: 8), Escudo(escudo!, tamano: 28)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de noticias: las historias de tu temporada (la principal grande y el resto en tarjetas).
class HistoriasTemporada extends StatefulWidget {
  const HistoriasTemporada({super.key, required this.temporada, required this.liga, this.compacta = 4});

  final Temporada temporada;
  final Liga liga;

  /// Cuántas historias se ven antes de tocar "Ver todas".
  final int compacta;

  @override
  State<HistoriasTemporada> createState() => _HistoriasTemporadaState();
}

class _HistoriasTemporadaState extends State<HistoriasTemporada> {
  var _todas = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.temporada;
    final lista = Historias.generar(
      t,
      widget.liga,
      nombre: (id) => _identidad(t, id).nombre,
      mejorRachaHistorica: perfilApp.value.mejorRacha,
    );
    final visibles = _todas ? lista : lista.take(widget.compacta).toList();
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'LA HISTORIA DE TU TEMPORADA',
            style: TextStyle(
              fontFamily: Fuentes.estadio,
              fontVariations: const [FontVariation.weight(800)],
              fontSize: 20,
              letterSpacing: 0.5,
              color: esquema.onSurface,
            ),
          ),
        ),
        for (final (i, h) in visibles.indexed) ...[
          TarjetaHistoria(
            historia: h,
            principal: i == 0,
            escudo: h.franquiciaId == null ? null : _identidad(t, h.franquiciaId!),
          ),
          const SizedBox(height: 8),
        ],
        if (lista.length > widget.compacta)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _todas = !_todas),
              child: Text(_todas ? 'VER MENOS' : 'VER TODAS (${lista.length})'),
            ),
          ),
      ],
    );
  }
}

/// "Tras el partido": lo que cambió con tu último partido o jornada (hitos de la noche, rachas, lesiones…).
class TrasElPartido extends StatelessWidget {
  const TrasElPartido({super.key, required this.historias, this.resumen});

  final List<Historia> historias;

  /// Frase de tu último partido ("Ganaste 112-104… Quedás 12-1.").
  final String? resumen;

  @override
  Widget build(BuildContext context) {
    if (historias.isEmpty && resumen == null) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final visibles = historias.take(3).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TRAS EL PARTIDO',
            style: TextStyle(
              fontFamily: Fuentes.estadio,
              fontVariations: const [FontVariation.weight(800)],
              fontSize: 20,
              letterSpacing: 0.5,
              color: esquema.onSurface,
            ),
          ),
          if (resumen != null) ...[const SizedBox(height: 4), Text(resumen!, style: tema.textTheme.bodyMedium)],
          for (final h in visibles) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconoDeHistoria(h.tipo), size: 20, color: esMalaNoticia(h.tipo) ? esquema.error : esquema.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.titulo, style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(h.texto, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                      if (h.reaccion case final r?)
                        Text(
                          '${r.voz}: «${r.cita}»',
                          style: tema.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
