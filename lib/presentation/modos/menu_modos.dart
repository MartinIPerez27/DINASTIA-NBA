import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Un bloque de modos dentro de una categoría, con título opcional.
class SeccionModos {
  const SeccionModos(this.modos, {this.titulo});

  final String? titulo;
  final List<ModoJuego> modos;
}

/// Una tarjeta grande del primer nivel del menú. Abre un submenú con sus [secciones], o, si es
/// [directa], arranca [ModoJuego.clasico] sin pasos de más.
class CategoriaModos {
  const CategoriaModos({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    this.secciones = const [],
    this.directa,
  });

  final String id, titulo, descripcion;
  final IconData icono;
  final List<SeccionModos> secciones;

  /// Si no es null, tocar la tarjeta arranca este modo directamente.
  final ModoJuego? directa;

  Iterable<ModoJuego> get modos => directa != null ? [directa!] : secciones.expand((s) => s.modos);
}

/// El menú, de arriba abajo (sin contar "Seguir jugando", que aparece primero si hay una partida).
/// Cada uno de los 34 modos está en una sola categoría; el orden es el de importancia para jugar.
const categoriasModos = <CategoriaModos>[
  CategoriaModos(
    id: 'temporada',
    titulo: 'Temporada 82-0',
    descripcion: 'Armá tu plantel y buscá la temporada perfecta.',
    icono: Icons.emoji_events_outlined,
    directa: ModoJuego.clasico,
  ),
  CategoriaModos(
    id: 'carrera',
    titulo: 'Carrera',
    descripcion: 'Tu jugador, tu franquicia, tu historia: temporadas encadenadas.',
    icono: Icons.timeline,
    secciones: [
      SeccionModos([
        ModoJuego.carreraJugador,
        ModoJuego.dinastia,
        ModoJuego.figuraFranquicia,
        ModoJuego.universitario,
        ModoJuego.reescribi,
        ModoJuego.soloEntrenador,
      ]),
    ],
  ),
  CategoriaModos(
    id: 'desafios',
    titulo: 'Desafíos',
    descripcion: 'Retos con reglas propias: una sola vida, presupuesto, ligas a medida.',
    icono: Icons.local_fire_department_outlined,
    secciones: [
      SeccionModos(titulo: 'Retos con riesgo', [
        ModoJuego.caminoAlAnillo,
        ModoJuego.racha,
        ModoJuego.extremo,
        ModoJuego.leyendaUnica,
        ModoJuego.espejo,
        ModoJuego.desafioDelDia,
      ]),
      SeccionModos(titulo: 'Armado y presupuesto', [ModoJuego.topeSalarial, ModoJuego.desafiosArmado]),
      SeccionModos(titulo: 'Ligas y competencia', [
        ModoJuego.ligaIA,
        ModoJuego.divisiones,
        ModoJuego.conquista,
        ModoJuego.creadorTorneos,
        ModoJuego.fantasy,
      ]),
    ],
  ),
  CategoriaModos(
    id: 'historia',
    titulo: 'Historia y torneos',
    descripcion: 'Revivís la NBA real y enfrentás a los mejores de cada época.',
    icono: Icons.history_edu,
    secciones: [
      SeccionModos(titulo: 'Revivir la historia', [
        ModoJuego.temporadaReal,
        ModoJuego.queHubiera,
        ModoJuego.ultimoCuarto,
        ModoJuego.escenario,
      ]),
      SeccionModos(titulo: 'Torneos históricos', [
        ModoJuego.guantelete,
        ModoJuego.camadas,
        ModoJuego.universidades,
        ModoJuego.mejoresEquipos,
        ModoJuego.mundial,
      ]),
    ],
  ),
  CategoriaModos(
    id: 'amigos',
    titulo: 'Con amigos',
    descripcion: 'Drafts y duelos en el mismo dispositivo, o por código.',
    icono: Icons.groups_outlined,
    secciones: [
      SeccionModos([ModoJuego.draftEnGrupo, ModoJuego.duelo, ModoJuego.reto]),
    ],
  ),
  CategoriaModos(
    id: 'minijuegos',
    titulo: 'Minijuegos',
    descripcion: 'Acertijos rápidos de básquet, sin temporada de por medio.',
    icono: Icons.psychology_alt_outlined,
    secciones: [
      SeccionModos([ModoJuego.perfilPerfecto, ModoJuego.adivina]),
    ],
  ),
];

/// Etiquetas cortas de duración o tensión de cada modo (para elegir de un vistazo).
List<String> etiquetasModo(ModoJuego m) => switch (m) {
  ModoJuego.clasico => const ['LARGO'],
  ModoJuego.carreraJugador => const ['MUY LARGO'],
  ModoJuego.dinastia => const ['MUY LARGO'],
  ModoJuego.figuraFranquicia => const ['LARGO'],
  ModoJuego.universitario => const ['LARGO'],
  ModoJuego.reescribi => const ['LARGO'],
  ModoJuego.soloEntrenador => const ['LARGO'],
  ModoJuego.caminoAlAnillo => const ['CORTO', 'UNA VIDA'],
  ModoJuego.racha => const ['CORTO', 'SIN FIN'],
  ModoJuego.extremo => const ['SIN RED'],
  ModoJuego.leyendaUnica => const ['LARGO'],
  ModoJuego.espejo => const ['LARGO'],
  ModoJuego.desafioDelDia => const ['DIARIO', 'CORTO'],
  ModoJuego.topeSalarial => const ['CORTO', 'ACERTIJO'],
  ModoJuego.desafiosArmado => const ['CORTO', 'ACERTIJO'],
  ModoJuego.ligaIA => const ['LARGO'],
  ModoJuego.divisiones => const ['LARGO'],
  ModoJuego.conquista => const ['LARGO'],
  ModoJuego.creadorTorneos => const ['MEDIO'],
  ModoJuego.fantasy => const ['MEDIO'],
  ModoJuego.temporadaReal => const ['LARGO'],
  ModoJuego.queHubiera => const ['CORTO'],
  ModoJuego.ultimoCuarto => const ['MUY CORTO'],
  ModoJuego.escenario => const ['CORTO'],
  ModoJuego.guantelete => const ['MEDIO'],
  ModoJuego.camadas => const ['MEDIO'],
  ModoJuego.universidades => const ['MEDIO'],
  ModoJuego.mejoresEquipos => const ['MEDIO'],
  ModoJuego.mundial => const ['MEDIO'],
  ModoJuego.draftEnGrupo => const ['MISMO DISPOSITIVO', 'MEDIO'],
  ModoJuego.duelo => const ['MISMO DISPOSITIVO', 'CORTO'],
  ModoJuego.reto => const ['POR CÓDIGO', 'CORTO'],
  ModoJuego.perfilPerfecto => const ['ACERTIJO', 'CORTO'],
  ModoJuego.adivina => const ['CORTO'],
};

/// Dónde quedó una partida guardada, en palabras y, si ya hay calendario, con su récord.
({String estado, String? record}) resumenPartida(Temporada t) {
  final estado = switch (t.fase) {
    FaseTemporada.draft => 'Armando el plantel',
    FaseTemporada.tacticas => 'Falta elegir las tácticas',
    FaseTemporada.temporadaRegular => 'Temporada regular',
    FaseTemporada.playoffs => 'Playoffs',
    FaseTemporada.finalizada => 'Temporada terminada',
  };
  if (t.calendario.isEmpty) return (estado: estado, record: null);
  final r = t.registroUsuario;
  return (estado: estado, record: '${r.victorias}-${r.derrotas}');
}

/// Primer nivel del menú: "Seguir jugando" (si hay partida) y las categorías. En el teléfono, una
/// columna de tarjetas grandes y cada una abre su submenú; en tablet apaisada, dos paneles
/// (categorías a la izquierda, sus modos a la derecha).
class MenuModos extends StatefulWidget {
  const MenuModos({super.key, required this.onElegir, this.guardada, this.onSeguir});

  final ValueChanged<ModoJuego> onElegir;
  final Temporada? guardada;
  final VoidCallback? onSeguir;

  @override
  State<MenuModos> createState() => _MenuModosState();
}

class _MenuModosState extends State<MenuModos> {
  CategoriaModos _abierta = categoriasModos[1];

  void _tocar(CategoriaModos c) {
    if (c.directa case final m?) {
      widget.onElegir(m);
    } else if (esTabletApaisada(context)) {
      setState(() => _abierta = c);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubmenuModos(categoria: c, onElegir: widget.onElegir),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablet = esTabletApaisada(context);
    final lista = _ListaCategorias(
      guardada: widget.guardada,
      onSeguir: widget.onSeguir,
      onTocar: _tocar,
      seleccionada: tablet ? _abierta : null,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('¿A qué jugamos?')),
      body: tablet
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DosPaneles(
                flexIzquierda: 4,
                flexDerecha: 7,
                izquierda: lista,
                derecha: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: ListaModos(categoria: _abierta, onElegir: widget.onElegir, columnas: 2),
                ),
              ),
            )
          : lista,
    );
  }
}

class _ListaCategorias extends StatelessWidget {
  const _ListaCategorias({required this.guardada, required this.onSeguir, required this.onTocar, this.seleccionada});

  final Temporada? guardada;
  final VoidCallback? onSeguir;
  final ValueChanged<CategoriaModos> onTocar;
  final CategoriaModos? seleccionada;

  @override
  Widget build(BuildContext context) {
    final g = guardada;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (g != null && onSeguir != null) ...[
          _TarjetaSeguir(temporada: g, onTap: onSeguir!),
          const SizedBox(height: 12),
        ],
        for (final c in categoriasModos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TarjetaCategoria(categoria: c, onTap: () => onTocar(c), seleccionada: c == seleccionada),
          ),
      ],
    );
  }
}

/// Base común de las tarjetas: panel con borde, sin sombras. Con [encendida], el borde va en LED.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, required this.onTap, this.encendida = false, this.semantica});

  final Widget child;
  final VoidCallback onTap;
  final bool encendida;
  final String? semantica;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semantica,
      child: Material(
        color: esquema.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: encendida ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.6),
            width: encendida ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class _TarjetaSeguir extends StatelessWidget {
  const _TarjetaSeguir({required this.temporada, required this.onTap});

  final Temporada temporada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final f = franquiciaPorId(temporada.franquiciaUsuarioId);
    final resumen = resumenPartida(temporada);
    final nombre = temporada.modoJuego == ModoJuego.clasico ? 'Temporada 82-0' : temporada.modoJuego.nombre;
    return _Tarjeta(
      onTap: onTap,
      encendida: true,
      semantica:
          'Seguir jugando: $nombre, ${f.nombre}, ${resumen.estado}${resumen.record == null ? '' : ', ${resumen.record}'}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Escudo(f, tamano: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SEGUIR JUGANDO', style: tema.textTheme.headlineSmall?.copyWith(color: esquema.primary)),
                      const SizedBox(height: 2),
                      Text(
                        '$nombre · ${f.nombre}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.titleSmall,
                      ),
                      Text(
                        resumen.estado,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (resumen.record case final r?) ...[TextoLed(r, tamano: 28), const SizedBox(width: 8)],
                Icon(Icons.play_circle_outline, size: 32, color: esquema.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaCategoria extends StatelessWidget {
  const _TarjetaCategoria({required this.categoria, required this.onTap, required this.seleccionada});

  final CategoriaModos categoria;
  final VoidCallback onTap;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final cuantos = categoria.modos.length;
    return _Tarjeta(
      onTap: onTap,
      encendida: seleccionada,
      semantica: '${categoria.titulo}. ${categoria.descripcion}${categoria.directa == null ? ' $cuantos modos' : ''}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 84),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(categoria.icono, size: 34, color: esquema.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(categoria.titulo.toUpperCase(), style: tema.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        categoria.descripcion,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (categoria.directa == null) ...[TextoLed('$cuantos', tamano: 22), const SizedBox(width: 2)],
                Icon(Icons.chevron_right, color: esquema.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segundo nivel (teléfono): los modos de una categoría, con sus secciones.
class SubmenuModos extends StatelessWidget {
  const SubmenuModos({super.key, required this.categoria, required this.onElegir});

  final CategoriaModos categoria;
  final ValueChanged<ModoJuego> onElegir;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(categoria.titulo)),
    body: ListaModos(categoria: categoria, onElegir: onElegir),
  );
}

/// Los modos de una categoría: tarjetas con descripción y etiquetas, en una o dos columnas.
class ListaModos extends StatelessWidget {
  const ListaModos({super.key, required this.categoria, required this.onElegir, this.columnas = 1});

  final CategoriaModos categoria;
  final ValueChanged<ModoJuego> onElegir;
  final int columnas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      key: ValueKey(categoria.id),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final s in categoria.secciones) ...[
          if (s.titulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                s.titulo!.toUpperCase(),
                style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1, color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
          if (columnas == 1)
            for (final m in s.modos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TarjetaModo(modo: m, onTap: () => onElegir(m)),
              )
          else
            LayoutBuilder(
              builder: (context, c) {
                final ancho = (c.maxWidth - 10 * (columnas - 1)) / columnas;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final m in s.modos)
                      SizedBox(
                        width: ancho,
                        child: TarjetaModo(modo: m, onTap: () => onElegir(m), compacta: true),
                      ),
                  ],
                );
              },
            ),
        ],
      ],
    );
  }
}

/// Un modo: ícono, nombre, una línea de descripción y etiquetas de duración o tensión.
class TarjetaModo extends StatelessWidget {
  const TarjetaModo({super.key, required this.modo, required this.onTap, this.compacta = false});

  final ModoJuego modo;
  final VoidCallback onTap;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final etiquetas = etiquetasModo(modo);
    return _Tarjeta(
      onTap: onTap,
      semantica: '${modo.nombre}. ${modo.descripcion} ${etiquetas.join(', ')}',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compacta ? 120 : 76),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconoModo(modo), size: 28, color: esquema.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(modo.nombre, style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        modo.descripcion,
                        maxLines: compacta ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 4, children: [for (final e in etiquetas) _Etiqueta(e)]),
                    ],
                  ),
                ),
                if (!compacta) Icon(Icons.chevron_right, color: esquema.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          texto,
          style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.6),
        ),
      ),
    );
  }
}

IconData iconoModo(ModoJuego m) => switch (m) {
  ModoJuego.clasico => Icons.emoji_events_outlined,
  ModoJuego.dinastia => Icons.account_tree_outlined,
  ModoJuego.reescribi => Icons.history_edu,
  ModoJuego.soloEntrenador => Icons.assignment_ind_outlined,
  ModoJuego.desafioDelDia => Icons.today,
  ModoJuego.escenario => Icons.theaters_outlined,
  ModoJuego.caminoAlAnillo => Icons.stairs_outlined,
  ModoJuego.extremo => Icons.local_fire_department_outlined,
  ModoJuego.leyendaUnica => Icons.star_outline,
  ModoJuego.espejo => Icons.flip,
  ModoJuego.racha => Icons.all_inclusive,
  ModoJuego.mejoresEquipos => Icons.military_tech_outlined,
  ModoJuego.mundial => Icons.public,
  ModoJuego.draftEnGrupo => Icons.groups_outlined,
  ModoJuego.duelo => Icons.sports_kabaddi,
  ModoJuego.reto => Icons.qr_code_2,
  ModoJuego.temporadaReal => Icons.event_note,
  ModoJuego.queHubiera => Icons.alt_route,
  ModoJuego.ultimoCuarto => Icons.timer_outlined,
  ModoJuego.guantelete => Icons.hourglass_bottom,
  ModoJuego.camadas => Icons.school_outlined,
  ModoJuego.universidades => Icons.account_balance_outlined,
  ModoJuego.topeSalarial => Icons.attach_money,
  ModoJuego.desafiosArmado => Icons.extension_outlined,
  ModoJuego.ligaIA => Icons.smart_toy_outlined,
  ModoJuego.figuraFranquicia => Icons.person_pin_outlined,
  ModoJuego.adivina => Icons.quiz_outlined,
  ModoJuego.carreraJugador => Icons.sports_basketball,
  ModoJuego.universitario => Icons.school,
  ModoJuego.divisiones => Icons.leaderboard_outlined,
  ModoJuego.creadorTorneos => Icons.account_tree,
  ModoJuego.conquista => Icons.map_outlined,
  ModoJuego.fantasy => Icons.groups_2_outlined,
  ModoJuego.perfilPerfecto => Icons.psychology_alt_outlined,
};
