import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/metajuego.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/misiones.dart';
import '../widgets/texto_led.dart';
import 'vestuario_pantalla.dart';

/// Misiones del día y de la semana, y el pase de temporada offline (premios estéticos).
class MisionesPantalla extends StatefulWidget {
  const MisionesPantalla({super.key, required this.franquicia, required this.onPerfil, this.ahora});

  /// Para la vista previa del vestuario.
  final Franquicia franquicia;

  /// Guarda el perfil (cobrar una misión o un nivel del pase).
  final ValueChanged<PerfilEntrenador> onPerfil;

  /// Reloj (para las capturas y los tests); por defecto, el del sistema.
  final DateTime Function()? ahora;

  @override
  State<MisionesPantalla> createState() => _MisionesPantallaState();
}

class _MisionesPantallaState extends State<MisionesPantalla> {
  @override
  void initState() {
    super.initState();
    // Al entrar: las misiones de hoy y de esta semana (y el pase del trimestre).
    final p = perfilApp.value;
    final meta = Misiones.alDia(p.metajuego, widget.ahora?.call() ?? DateTime.now());
    if (!identical(meta, p.metajuego)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPerfil(p.copyWith(metajuego: meta)));
    }
  }

  void _cobrar(PerfilEntrenador? nuevo, String mensaje) {
    if (nuevo == null) return;
    widget.onPerfil(nuevo);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misiones y pase'),
        actions: [
          IconButton(
            tooltip: 'Vestuario',
            icon: const Icon(Icons.checkroom_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VestuarioPantalla(franquicia: widget.franquicia, onPerfil: widget.onPerfil),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: perfilApp,
        builder: (context, perfil, _) {
          final m = perfil.metajuego;
          final diarias = m.misiones.where((x) => !x.semanal).toList();
          final semanales = m.misiones.where((x) => x.semanal).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Pase(
                perfil: perfil,
                onReclamar: (n) {
                  final c = PaseTemporada.cosmetico(n);
                  final yaLoTenia = c != null && perfil.metajuego.cosmeticos.contains(c);
                  _cobrar(
                    PaseTemporada.reclamar(perfil, n),
                    c != null && !yaLoTenia
                        ? 'Nuevo en el vestuario: ${c.nombre}'
                        : '+${PaseTemporada.monedas(n)} monedas',
                  );
                },
              ),
              const SizedBox(height: 20),
              _Titulo('HOY', 'Se renuevan a la medianoche'),
              for (final x in diarias) _TarjetaMision(mision: x, onReclamar: () => _reclamar(perfil, x)),
              const SizedBox(height: 16),
              _Titulo('ESTA SEMANA', 'Se renuevan el lunes'),
              for (final x in semanales) _TarjetaMision(mision: x, onReclamar: () => _reclamar(perfil, x)),
              const SizedBox(height: 12),
              Text(
                'Las misiones avanzan solas con lo que jugás. El pase cambia cada trimestre: lo que ganaste queda en tu vestuario.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }

  void _reclamar(PerfilEntrenador perfil, Mision x) {
    final (xp, monedas, puntos) = x.premio;
    _cobrar(Misiones.reclamar(perfil, x.id), '+$xp XP · +$monedas monedas · +$puntos del pase');
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, this.nota);

  final String texto, nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(texto, style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nota,
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMision extends StatelessWidget {
  const _TarjetaMision({required this.mision, required this.onReclamar});

  final Mision mision;
  final VoidCallback onReclamar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final (xp, monedas, puntos) = mision.premio;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mision.texto,
                    style: tema.textTheme.titleSmall?.copyWith(
                      decoration: mision.reclamada ? TextDecoration.lineThrough : null,
                      color: mision.reclamada ? esquema.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(value: mision.progreso / mision.objetivo, minHeight: 5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextoLed('${mision.progreso}/${mision.objetivo}', tamano: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+$xp XP · +$monedas monedas · +$puntos del pase',
                    style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (mision.reclamada)
              Icon(Icons.check_circle, color: esquema.primary, semanticLabel: 'Cobrada')
            else
              FilledButton(
                onPressed: mision.cumplida ? onReclamar : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('COBRAR'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nivel del pase, barra al próximo y la tira de premios.
class _Pase extends StatelessWidget {
  const _Pase({required this.perfil, required this.onReclamar});

  final PerfilEntrenador perfil;
  final ValueChanged<int> onReclamar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final m = perfil.metajuego;
    final nivel = PaseTemporada.nivel(m.puntosPase);
    final completo = nivel >= PaseTemporada.niveles;
    final enNivel = m.puntosPase - nivel * PaseTemporada.puntosPorNivel;
    final pendientes = PaseTemporada.pendientes(perfil).toSet();
    final enfoque = pendientes.isEmpty ? nivel + 1 : pendientes.reduce(min);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.primary.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PASE DE TEMPORADA', style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
                      Text(
                        m.pase.isEmpty ? 'Sin conexión, sin pagar nada' : 'Temporada ${m.pase}',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextoLed('$nivel', tamano: 34),
                Text('/${PaseTemporada.niveles}', style: tema.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: completo ? 1 : enNivel / PaseTemporada.puntosPorNivel,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              completo
                  ? '¡Pase completo!'
                  : '$enNivel/${PaseTemporada.puntosPorNivel} para el nivel ${nivel + 1} · '
                        '${PaseTemporada.puntosVictoria} por victoria, ${PaseTemporada.puntosDerrota} por derrota',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 118,
              child: ListView.separated(
                // Arranca mostrando el primer premio por cobrar (o el próximo a ganar).
                key: ValueKey(m.nivelesReclamados.length),
                controller: ScrollController(initialScrollOffset: max(0, (enfoque - 2) * 94.0)),
                scrollDirection: Axis.horizontal,
                itemCount: PaseTemporada.niveles,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final n = i + 1;
                  return _PremioPase(
                    nivel: n,
                    alcanzado: n <= nivel,
                    cobrado: m.nivelesReclamados.contains(n),
                    onCobrar: pendientes.contains(n) ? () => onReclamar(n) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremioPase extends StatelessWidget {
  const _PremioPase({required this.nivel, required this.alcanzado, required this.cobrado, this.onCobrar});

  final int nivel;
  final bool alcanzado, cobrado;
  final VoidCallback? onCobrar;

  static IconData icono(CategoriaCosmetico c) => switch (c) {
    CategoriaCosmetico.cancha => Icons.grid_on,
    CategoriaCosmetico.pelota => Icons.sports_basketball,
    CategoriaCosmetico.uniforme => Icons.checkroom,
    CategoriaCosmetico.led => Icons.blur_on,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final c = PaseTemporada.cosmetico(nivel);
    final color = alcanzado ? esquema.primary : esquema.outlineVariant;
    return Semantics(
      label: 'Nivel $nivel del pase: ${c?.nombre ?? '${PaseTemporada.monedas(nivel)} monedas'}',
      child: InkWell(
        onTap: onCobrar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 86,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: c != null ? 1.6 : 1),
            color: c != null && alcanzado ? esquema.primary.withValues(alpha: 0.12) : null,
          ),
          child: Column(
            children: [
              TextoLed('$nivel', tamano: 16, color: color),
              const SizedBox(height: 4),
              Icon(c == null ? Icons.toll : icono(c.categoria), size: 22, color: color),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  c?.nombre ?? '${PaseTemporada.monedas(nivel)}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.labelSmall,
                ),
              ),
              SizedBox(
                height: 24,
                child: cobrado
                    ? Icon(Icons.check, size: 18, color: esquema.primary)
                    : onCobrar != null
                    ? TextButton(
                        onPressed: onCobrar,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('COBRAR'),
                      )
                    : Icon(Icons.lock_outline, size: 16, color: esquema.outlineVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
