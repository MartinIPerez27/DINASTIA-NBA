import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/perfil.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Tu carrera de entrenador: nivel y ventajas, vitrina de trofeos, logros, Salón de la Fama
/// (temporadas terminadas) y la carrera de cada carta con vos.
class PerfilPantalla extends StatelessWidget {
  const PerfilPantalla({super.key, required this.jugador});

  /// Para nombrar las cartas de la carrera (null si la carta ya no existe).
  final Jugador? Function(String cartaId) jugador;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Tu carrera'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Resumen'),
            Tab(text: 'Vitrina'),
            Tab(text: 'Logros'),
            Tab(text: 'Salón de la Fama'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: perfilApp,
          builder: (context, perfil, _) => TabBarView(
            children: [
              _Resumen(perfil: perfil),
              _Vitrina(perfil: perfil),
              _Logros(perfil: perfil),
              _Salon(perfil: perfil, jugador: jugador),
            ],
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _panel(ColorScheme esquema, {bool resaltado = false}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: resaltado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
    width: resaltado ? 1.5 : 1,
  ),
);

String _fecha(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}/${d.month}/${d.year}';
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.perfil});

  final PerfilEntrenador perfil;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final falta = PerfilEntrenador.xpParaNivel(perfil.nivel + 1) - perfil.xp;
    Widget dato(String valor, String sigla) => Expanded(
      child: Column(
        children: [
          FittedBox(child: TextoLed(valor, tamano: 30)),
          Text(sigla, style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panel(esquema),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('NIVEL', style: tema.textTheme.headlineSmall),
                  const SizedBox(width: 10),
                  TextoLed('${perfil.nivel}', tamano: 52),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: perfil.avanceNivel, minHeight: 6),
              ),
              const SizedBox(height: 6),
              Text(
                '${perfil.xp} XP · faltan $falta para el nivel ${perfil.nivel + 1}',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  dato('${perfil.monedas}', 'MONEDAS'),
                  dato('${perfil.puntaje}', 'PUNTAJE'),
                  dato('${perfil.logros.length}/${Logro.values.length}', 'LOGROS'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Ventajas del entrenador', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final v in Ventaja.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              perfil.tiene(v) ? Icons.check_circle : Icons.lock_outline,
              color: perfil.tiene(v) ? esquema.primary : esquema.onSurfaceVariant,
            ),
            title: Text(v.descripcion),
            subtitle: Text(perfil.tiene(v) ? 'Activa' : 'Se desbloquea en el nivel ${v.nivel}'),
          ),
        const SizedBox(height: 8),
        Text(
          'El puntaje sube cuando le ganás a planteles fuertes y baja cuando perdés con débiles. '
          'Arranca en 1000.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Vitrina extends StatelessWidget {
  const _Vitrina({required this.perfil});

  final PerfilEntrenador perfil;

  static IconData _icono(TipoTrofeo t) => switch (t) {
    TipoTrofeo.anillo => Icons.radio_button_checked,
    TipoTrofeo.larryOBrien => Icons.emoji_events,
    TipoTrofeo.presidente => Icons.workspace_premium,
    TipoTrofeo.mvp => Icons.star,
    TipoTrofeo.anotador => Icons.sports_basketball,
    TipoTrofeo.perfecta => Icons.all_inclusive,
    TipoTrofeo.dpoy => Icons.shield,
    TipoTrofeo.sextoHombre => Icons.event_seat,
    TipoTrofeo.mip => Icons.trending_up,
    TipoTrofeo.allNba => Icons.groups,
    TipoTrofeo.allStar => Icons.auto_awesome,
    TipoTrofeo.record => Icons.history_edu,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    if (perfil.trofeos.isEmpty) {
      return _Vacio(
        icono: Icons.emoji_events_outlined,
        texto: 'Tu vitrina está vacía. Los anillos, el Trofeo Presidente y los premios de tus jugadores van a aparecer acá.',
      );
    }
    final porTipo = <TipoTrofeo, List<Trofeo>>{};
    for (final t in perfil.trofeos) {
      (porTipo[t.tipo] ??= []).add(t);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tipo in TipoTrofeo.values)
              if (porTipo[tipo] case final lista?)
                Container(
                  width: 160,
                  padding: const EdgeInsets.all(14),
                  decoration: _panel(esquema, resaltado: tipo == TipoTrofeo.anillo || tipo == TipoTrofeo.perfecta),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_icono(tipo), color: esquema.primary, size: 28),
                          const Spacer(),
                          TextoLed('×${lista.length}', tamano: 22),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(tipo.nombre, style: tema.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: [for (final t in lista.take(8)) Escudo(franquiciaPorId(t.franquiciaId), tamano: 20)],
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _Logros extends StatelessWidget {
  const _Logros({required this.perfil});

  final PerfilEntrenador perfil;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final orden = [...Logro.values]
      ..sort((a, b) => (perfil.logros.containsKey(a) ? 0 : 1).compareTo(perfil.logros.containsKey(b) ? 0 : 1));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orden.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final l = orden[i];
        final fecha = perfil.logros[l];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: _panel(esquema, resaltado: fecha != null),
          child: Row(
            children: [
              Icon(
                fecha != null ? Icons.verified : Icons.lock_outline,
                color: fecha != null ? esquema.primary : esquema.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.nombre,
                      style: TextStyle(
                        fontFamily: Fuentes.estadio,
                        fontVariations: const [FontVariation.weight(800)],
                        fontSize: 18,
                        color: fecha != null ? esquema.onSurface : esquema.onSurfaceVariant,
                      ),
                    ),
                    Text(l.descripcion, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                  ],
                ),
              ),
              if (fecha != null) Text(_fecha(fecha), style: tema.textTheme.labelSmall),
            ],
          ),
        );
      },
    );
  }
}

class _Salon extends StatelessWidget {
  const _Salon({required this.perfil, required this.jugador});

  final PerfilEntrenador perfil;
  final Jugador? Function(String) jugador;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    if (perfil.historial.isEmpty) {
      return _Vacio(
        icono: Icons.history_edu_outlined,
        texto:
            'Cuando termines una temporada (con los playoffs), queda acá: récord, hasta dónde llegaste y tus figuras.',
      );
    }
    final carrera = perfil.carrera.entries.toList()..sort((a, b) => b.value.$2.pj.compareTo(a.value.$2.pj));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final h in perfil.historial) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _panel(esquema, resaltado: h.campeon),
            child: Row(
              children: [
                Escudo(franquiciaPorId(h.franquiciaId), tamano: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.resultado.toUpperCase(),
                        style: TextStyle(
                          fontFamily: Fuentes.estadio,
                          fontVariations: const [FontVariation.weight(800)],
                          fontSize: 18,
                          color: h.campeon ? esquema.primary : esquema.onSurface,
                        ),
                      ),
                      Text(
                        '${h.dificultad} · ${h.figuras.join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextoLed('${h.victorias}-${h.derrotas}', tamano: 20),
                    Text(_fecha(h.fecha), style: tema.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (carrera.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Tus cartas de confianza', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final e in carrera.take(10))
            if (jugador(e.key) case final j?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(j.nombre),
                subtitle: Text('${e.value.$1} temporada${e.value.$1 == 1 ? '' : 's'} · ${j.epoca.etiqueta}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (sigla, v) in [
                      ('PJ', '${e.value.$2.pj}'),
                      ('PPP', e.value.$2.pj == 0 ? '–' : (e.value.$2.pts / e.value.$2.pj).toStringAsFixed(1)),
                    ]) ...[
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextoLed(v, tamano: 16),
                          Text(sigla, style: tema.textTheme.labelSmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
