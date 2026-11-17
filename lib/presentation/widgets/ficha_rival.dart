import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/tactica.dart';
import '../../domain/modos/bitacora.dart';
import '../../domain/rivalidades.dart';
import '../../domain/scouting.dart';
import '../../domain/tension.dart';
import '../tema/tema_franquicia.dart';
import 'escudo.dart';
import 'texto_led.dart';

// Widgets compartidos de tensión para temporada, playoffs y modos: ficha de scouting del rival,
// banner de presión, chip de rivalidad y cuaderno de bitácora. Estilo "El Marcador" (sin sombras).

String _dec(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

TextStyle _estadio(BuildContext context, double tamano, {Color? color}) => TextStyle(
  fontFamily: Fuentes.estadio,
  fontVariations: const [FontVariation.weight(800)],
  fontSize: tamano,
  height: 1.05,
  letterSpacing: 0.4,
  color: color ?? Theme.of(context).colorScheme.onSurface,
);

/// Color de alerta según la tensión.
Color _colorTension(ColorScheme e, NivelTension n) => switch (n) {
  NivelTension.normal => e.onSurfaceVariant,
  NivelTension.importante => e.primary,
  _ => e.error,
};

/// Medidor de 5 segmentos de la tensión de un partido.
class MedidorTension extends StatelessWidget {
  const MedidorTension({super.key, required this.nivel, this.alto = 8});

  final NivelTension nivel;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = _colorTension(esquema, nivel);
    return Semantics(
      label: 'Tensión: ${nivel.etiqueta}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Container(
                width: 18,
                height: alto,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: i < nivel.segmentos ? color : esquema.outlineVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Banner de presión: "PARTIDO 7", "ELIMINACIÓN", "MATCH POINT", "VENTAJA 3-1" con lo que está en juego.
class BannerTension extends StatelessWidget {
  const BannerTension({super.key, required this.presion, this.compacto = false});

  final PresionPartido presion;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final color = _colorTension(esquema, presion.nivel);
    final fuerte = presion.nivel.index >= NivelTension.alta.index;
    return Semantics(
      container: true,
      label: '${presion.etiqueta}. ${presion.detalle}. ${presion.nivel.etiqueta}.',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: compacto ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: fuerte ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: fuerte ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(presion.etiqueta, style: _estadio(context, compacto ? 18 : 22, color: color)),
                    if (!compacto) ...[
                      const SizedBox(height: 2),
                      Text(presion.detalle, style: tema.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MedidorTension(nivel: presion.nivel),
                  const SizedBox(height: 4),
                  Text(
                    presion.nivel.etiqueta.toUpperCase(),
                    style: tema.textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "RIVALIDAD · MALA SANGRE": la frase en voseo y las fichas (series cerradas, picantes, duelos).
class ChipRivalidad extends StatelessWidget {
  const ChipRivalidad({super.key, required this.relato});

  final RelatoRivalidad relato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final caliente = relato.nivel.index >= NivelRivalidad.malaSangre.index;
    final color = caliente ? esquema.error : esquema.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIVALIDAD · ${relato.nivel.etiqueta.toUpperCase()}',
                  style: tema.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                Text(relato.frase, style: tema.textTheme.bodySmall),
                if (relato.fichas.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    relato.fichas.join(' · '),
                    style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Evento aleatorio del cruce con su efecto visible.
class CintaEvento extends StatelessWidget {
  const CintaEvento({super.key, required this.evento});

  final EventoCruce evento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final favorable = evento.rivalMenos > 0 || evento.propioMas > 0 || evento.rivalCansado;
    final color = favorable ? esquema.primary : esquema.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(favorable ? Icons.trending_up : Icons.trending_down, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${evento.titulo} · ${evento.efecto.toUpperCase()}',
                  style: tema.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                Text(evento.texto, style: tema.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ficha de scouting del rival: figuras clave, estilo, fortaleza y punto débil, amenaza, historial,
/// rivalidad y evento. Con [jefe] la ficha se presenta como "rival jefe" con una introducción.
class FichaRival extends StatelessWidget {
  const FichaRival({
    super.key,
    required this.identidad,
    required this.nombre,
    required this.scouting,
    this.tactica,
    this.historial,
    this.rivalidad,
    this.evento,
    this.jefe = false,
    this.introJefe,
    this.notas = const [],
  });

  final Franquicia identidad;

  /// "Chicago Bulls 1995-96".
  final String nombre;
  final FichaScouting scouting;
  final Tactica? tactica;

  /// "Serie de la temporada: 1-0" o "Primer cruce".
  final String? historial;
  final RelatoRivalidad? rivalidad;
  final EventoCruce? evento;
  final bool jefe;

  /// Frase de presentación del rival jefe ("El mejor equipo de la historia…").
  final String? introJefe;
  final List<String> notas;

  Color _colorAmenaza(ColorScheme e) => switch (scouting.amenaza) {
    Amenaza.baja => e.onSurfaceVariant,
    Amenaza.media => e.primary,
    _ => e.error,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final amenaza = _colorAmenaza(esquema);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: jefe ? esquema.error : esquema.outlineVariant.withValues(alpha: 0.5),
          width: jefe ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (jefe) ...[
            Text(
              'RIVAL JEFE',
              style: tema.textTheme.labelMedium?.copyWith(
                color: esquema.error,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (introJefe != null) ...[
              const SizedBox(height: 2),
              Text(introJefe!, style: tema.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Escudo(identidad, tamano: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FICHA DEL RIVAL',
                      style: tema.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: esquema.onSurfaceVariant),
                    ),
                    Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: _estadio(context, 20)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextoLed(_dec(scouting.media), tamano: 26),
                  Text(
                    'AMENAZA ${scouting.amenaza.etiqueta.toUpperCase()}',
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: amenaza,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(scouting.comparacion, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 10),
          for (final j in scouting.figuras) _FilaFigura(jugador: j),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Ficha(Icons.bolt, 'Fuerte: ${scouting.fuerte}', esquema.primary),
              _Ficha(Icons.report_gmailerrorred_outlined, 'Débil: ${scouting.debil}', esquema.onSurfaceVariant),
              if (tactica != null)
                _Ficha(
                  Icons.draw_outlined,
                  '${tactica!.ofensiva.nombre} · ${tactica!.defensiva.nombre}',
                  esquema.onSurfaceVariant,
                ),
              if (historial != null) _Ficha(Icons.history, historial!, esquema.onSurfaceVariant),
            ],
          ),
          if (rivalidad != null && rivalidad!.visible) ...[
            const SizedBox(height: 10),
            ChipRivalidad(relato: rivalidad!),
          ],
          if (evento != null) ...[const SizedBox(height: 8), CintaEvento(evento: evento!)],
          for (final n in notas) ...[
            const SizedBox(height: 6),
            Text(n, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha(this.icono, this.texto, this.color);

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(texto, style: tema.textTheme.labelSmall, softWrap: true)),
        ],
      ),
    );
  }
}

class _FilaFigura extends StatelessWidget {
  const _FilaFigura({required this.jugador});

  final Jugador jugador;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final s = jugador.stats;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 34, child: TextoLed('${jugador.media}', tamano: 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jugador.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_dec(s.ppp)} PPP · ${_dec(s.rpp)} RPP · ${_dec(s.app)} APP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuaderno de bitácora de la corrida: cada cruce y los hitos que se celebran, lo más nuevo arriba.
class BitacoraCorrida extends StatefulWidget {
  const BitacoraCorrida({super.key, required this.entradas, this.visibles = 4});

  final List<EntradaBitacora> entradas;
  final int visibles;

  @override
  State<BitacoraCorrida> createState() => _BitacoraCorridaState();
}

class _BitacoraCorridaState extends State<BitacoraCorrida> {
  var _todo = false;

  @override
  Widget build(BuildContext context) {
    if (widget.entradas.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final lista = widget.entradas.reversed.toList();
    final mostradas = _todo ? lista : lista.take(widget.visibles).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text('BITÁCORA DE LA CORRIDA', style: _estadio(context, 20)),
          ),
          const SizedBox(height: 6),
          for (final e in mostradas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    e.hito
                        ? Icons.celebration_outlined
                        : e.victoria
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 18,
                    color: e.hito || e.victoria ? esquema.primary : esquema.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.titulo,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            fontWeight: e.hito ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        Text(e.detalle, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (lista.length > widget.visibles)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _todo = !_todo),
                child: Text(_todo ? 'VER MENOS' : 'VER TODA (${lista.length})'),
              ),
            ),
        ],
      ),
    );
  }
}
