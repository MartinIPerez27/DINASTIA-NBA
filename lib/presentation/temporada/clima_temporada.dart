import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/all_star.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/historicos.dart';
import '../../domain/liga.dart';
import '../../domain/noticias.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

// Clima de temporada (GDD: metajuego): titulares de la semana, carrera al MVP, récords en juego y el
// fin de semana All-Star. Cada widget es independiente y se oculta solo si no tiene nada para mostrar.
// Van en la lista del hub de la temporada, debajo de la tarjeta del próximo partido.

/// Identidad visible de una franquicia en esta temporada (los rivales de época usan la suya).
Franquicia _identidad(Temporada t, String id) =>
    franquiciaPorId(id == t.franquiciaUsuarioId ? id : t.rivales[id]?.identidadId ?? id);

BoxDecoration _panel(ColorScheme esquema, {bool resaltado = false}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: resaltado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
    width: resaltado ? 1.5 : 1,
  ),
);

Widget _titulo(BuildContext context, String texto, {Widget? accion}) => Row(
  children: [
    Expanded(
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: [FontVariation.weight(800)],
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
    ),
    ?accion,
  ],
);

String _decimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Titulares de la semana: los 3 últimos y, al tocar "Ver todos", el archivo completo.
class TitularesSemana extends StatefulWidget {
  const TitularesSemana({super.key, required this.temporada, required this.liga});

  final Temporada temporada;
  final Liga liga;

  @override
  State<TitularesSemana> createState() => _TitularesSemanaState();
}

class _TitularesSemanaState extends State<TitularesSemana> {
  var _todos = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.temporada;
    final lista = titulares(t, widget.liga, nombre: (id) => _identidad(t, id).nombre);
    if (lista.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final visibles = _todos ? lista : lista.take(3).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: _panel(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.only(right: 8), child: _titulo(context, 'Titulares')),
          const SizedBox(height: 6),
          for (final n in visibles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 40, child: TextoLed('J${n.jornada}', tamano: 13, color: esquema.onSurfaceVariant)),
                  if (n.franquiciaId case final f?) ...[Escudo(_identidad(t, f), tamano: 20), const SizedBox(width: 8)],
                  Expanded(
                    child: Text(
                      n.texto,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: n.destacado ? esquema.onSurface : esquema.onSurfaceVariant,
                        fontWeight: n.destacado ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (lista.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _todos = !_todos),
                child: Text(_todos ? 'VER MENOS' : 'VER TODOS (${lista.length})'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Los 5 primeros de la carrera al MVP, con su línea y el valor que los ordena.
class CarreraMvp extends StatelessWidget {
  const CarreraMvp({super.key, required this.temporada, required this.liga});

  final Temporada temporada;
  final Liga liga;

  @override
  Widget build(BuildContext context) {
    final t = temporada;
    final carrera = carreraMvp(t, liga);
    if (carrera.isEmpty || t.registroUsuario.jugados < 5) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final terminada = t.calendario.every((p) => p.jugado);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: _panel(esquema),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(context, terminada ? 'Votación del MVP' : 'Carrera al MVP'),
          const SizedBox(height: 8),
          for (final (i, g) in carrera.indexed)
            Semantics(
              label: '${i + 1}. ${g.jugador.nombre}, ${_decimal(g.por(g.linea.pts))} puntos por partido',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: TextoLed(
                          '${i + 1}',
                          tamano: 16,
                          color: i == 0 ? esquema.primary : esquema.onSurfaceVariant,
                        ),
                      ),
                      Escudo(_identidad(t, g.franquiciaId), tamano: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.jugador.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.bodyMedium?.copyWith(
                                fontWeight: g.franquiciaId == t.franquiciaUsuarioId ? FontWeight.w700 : null,
                                color: g.franquiciaId == t.franquiciaUsuarioId ? esquema.primary : null,
                              ),
                            ),
                            Text(
                              '${_decimal(g.por(g.linea.pts))} PPP · ${_decimal(g.por(g.linea.reb))} RPP · '
                              '${_decimal(g.por(g.linea.ast))} APP',
                              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextoLed(_decimal(g.valor), tamano: 16),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Récords históricos que tu equipo o tus jugadores están persiguiendo (o ya batieron).
class RecordsEnJuego extends StatelessWidget {
  const RecordsEnJuego({super.key, required this.temporada, required this.liga});

  final Temporada temporada;
  final Liga liga;

  @override
  Widget build(BuildContext context) {
    final batidos = recordsBatidos(temporada, liga);
    final lista = batidos.isNotEmpty ? batidos : recordsEnJuego(temporada, liga);
    if (lista.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: _panel(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(context, batidos.isNotEmpty ? 'Récords batidos' : 'Récords en juego'),
          const SizedBox(height: 8),
          for (final r in lista)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(r.batido ? Icons.emoji_events : Icons.history_edu, color: esquema.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.texto, style: tema.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fin de semana All-Star: resultado, MVP y tus convocados; los planteles en una hoja aparte.
class TarjetaAllStar extends StatelessWidget {
  const TarjetaAllStar({super.key, required this.temporada, required this.liga});

  final Temporada temporada;
  final Liga liga;

  @override
  Widget build(BuildContext context) {
    final t = temporada;
    final allStar = allStarDe(t, liga);
    if (allStar == null) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final mios = allStar.de(t.franquiciaUsuarioId);
    final ganoEste = allStar.puntosEste > allStar.puntosOeste;
    Widget lado(String nombre, int puntos, bool gano) => Column(
      children: [
        Text(
          nombre,
          style: TextStyle(
            fontFamily: Fuentes.estadio,
            fontVariations: const [FontVariation.weight(800)],
            fontSize: 18,
            color: gano ? esquema.onSurface : esquema.onSurfaceVariant,
          ),
        ),
        TextoLed('$puntos', tamano: 34, color: gano ? esquema.primary : esquema.onSurfaceVariant),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: _panel(esquema, resaltado: mios.isNotEmpty),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(context, 'Fin de semana All-Star'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [lado('ESTE', allStar.puntosEste, ganoEste), lado('OESTE', allStar.puntosOeste, !ganoEste)],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'MVP: ',
                  style: TextStyle(color: esquema.onSurfaceVariant),
                ),
                TextSpan(
                  text: allStar.mvp.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' · ${allStar.lineaMvp.pts} PTS, ${allStar.lineaMvp.reb} REB, ${allStar.lineaMvp.ast} AST',
                  style: TextStyle(color: esquema.onSurfaceVariant),
                ),
              ],
            ),
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            mios.isEmpty
                ? 'Ningún jugador tuyo fue convocado.'
                : 'Tus convocados: ${mios.map((j) => j.nombre).join(', ')}.',
            style: tema.textTheme.bodySmall?.copyWith(color: mios.isEmpty ? esquema.onSurfaceVariant : esquema.primary),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (_) => _PlantelesAllStar(temporada: t, allStar: allStar),
              ),
              child: const Text('VER PLANTELES'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantelesAllStar extends StatelessWidget {
  const _PlantelesAllStar({required this.temporada, required this.allStar});

  final Temporada temporada;
  final AllStar allStar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    Widget columna(String titulo, List<Jugador> jugadores) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final (i, j) in jugadores.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Escudo(_identidad(temporada, allStar.equipos[j.id]!), tamano: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      j.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: allStar.equipos[j.id] == temporada.franquiciaUsuarioId ? esquema.primary : null,
                        fontWeight: i < 6 ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PLANTELES ALL-STAR', style: tema.textTheme.headlineSmall),
          Text(
            'En negrita, los que jugaron de titulares y sexto.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [columna('Este', allStar.este), const SizedBox(width: 16), columna('Oeste', allStar.oeste)],
          ),
        ],
      ),
    );
  }
}
