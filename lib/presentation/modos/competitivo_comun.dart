import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/liga.dart';
import '../../domain/modos/competitivo.dart';
import '../../domain/modos/escalera.dart';
import '../../domain/modos/evoluciones.dart';
import '../../domain/motor.dart';
import '../../domain/premios.dart' show apellido;
import '../pantallas/partido_pantalla.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Piezas que comparten Divisiones, Conquista y el Creador de torneos.

BoxDecoration panelCompetitivo(ColorScheme esquema, {bool resaltado = false}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: resaltado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
    width: resaltado ? 1.5 : 1,
  ),
);

/// "Chicago Bulls 1995-96", "Detroit Pistons (90’)", "Boston Celtics (Histórico)".
String nombreDeRival(RivalEscalera r) => '${franquiciaPorId(r.identidadId).nombreCompleto} ${r.etiqueta}'.trim();

/// Juega un partido tuyo en vivo y avisa cuando termina.
Future<void> jugarEnVivo(
  BuildContext context, {
  required MotorPartido motor,
  required Franquicia propia,
  required Franquicia rival,
  required ValueChanged<MotorPartido> alTerminar,
}) {
  final local = motor.usuarioLocal ?? true;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PartidoPantalla(
        motor: motor,
        usuarioLocal: local,
        franquiciaUsuario: propia,
        identidadLocal: local ? propia : rival,
        identidadVisitante: local ? rival : propia,
        onTerminado: alTerminar,
      ),
    ),
  );
}

/// El rival que sigue: escudos, nombre, media y sus tres mejores, con los botones de jugar.
class TarjetaRival extends StatelessWidget {
  const TarjetaRival({
    super.key,
    required this.titulo,
    required this.rival,
    required this.propia,
    required this.liga,
    required this.local,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    this.extra,
    this.detalle,
  });

  final String titulo;
  final RivalEscalera rival;
  final Franquicia propia;
  final Liga liga;

  /// ¿Jugás de local?
  final bool local;
  final bool ocupado;
  final VoidCallback onVivo, onSimular;

  /// Botones de más debajo de los dos principales.
  final List<Widget>? extra;

  /// Una línea más (formato, serie…).
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final jugadores = [for (final id in rival.cartaIds.values) ?liga.jugador(id)]
      ..sort((a, b) => mediaDe(b).compareTo(mediaDe(a)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelCompetitivo(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo.toUpperCase(), style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Escudo(propia, tamano: 44),
              Expanded(
                child: Center(child: Text('VS', style: tema.textTheme.titleMedium)),
              ),
              Escudo(franquiciaPorId(rival.identidadId), tamano: 44),
            ],
          ),
          const SizedBox(height: 10),
          Text(nombreDeRival(rival), textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
          Text(
            '${local ? 'De local' : 'De visitante'} · media ${rival.media.toStringAsFixed(1)}'
            '${detalle == null ? '' : ' · $detalle'}',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.primary),
          ),
          const SizedBox(height: 4),
          Text(
            [for (final j in jugadores.take(3)) '${apellido(j)} ${mediaDe(j)}'].join(' · '),
            textAlign: TextAlign.center,
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
          OutlinedButton(
            onPressed: ocupado ? null : onSimular,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('SIMULAR'),
          ),
          ...?extra,
        ],
      ),
    );
  }
}

/// Tus seis cartas, una por línea: puesto, apellido y media en LED.
class ListaPlantel extends StatelessWidget {
  const ListaPlantel({super.key, required this.cartas, required this.liga, this.onCambiar, this.titulo = 'TU EQUIPO'});

  final Alineacion cartas;
  final Liga liga;
  final VoidCallback? onCambiar;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: panelCompetitivo(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(titulo, style: tema.textTheme.labelLarge?.copyWith(color: esquema.primary)),
              ),
              if (onCambiar != null)
                TextButton.icon(onPressed: onCambiar, icon: const Icon(Icons.swap_horiz), label: const Text('CAMBIAR')),
            ],
          ),
          for (final pos in Posicion.values) _Fila(pos: pos, jugador: _carta(pos)),
        ],
      ),
    );
  }

  Jugador? _carta(Posicion pos) {
    final id = cartas[pos];
    final j = id == null ? null : liga.jugador(id);
    return j == null ? null : aplicarEvolucion(perfilApp.value, j, usaAlbum: true);
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.pos, required this.jugador});

  final Posicion pos;
  final Jugador? jugador;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final j = jugador;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              pos.etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              j == null ? '—' : '${j.nombre} · ${j.tramoConEquipo}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodyMedium,
            ),
          ),
          if (j != null) TextoLed('${mediaDe(j)}', tamano: 16),
        ],
      ),
    );
  }
}
