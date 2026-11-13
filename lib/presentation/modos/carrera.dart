import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/draft.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart' show Epoca;
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/modos/dinastia.dart';
import '../pantallas/playbook_pantalla.dart';
import '../pantallas/playoffs_pantalla.dart';
import '../pantallas/temporada_pantalla.dart';
import '../widgets/elegir_modo.dart';
import '../widgets/texto_led.dart';
import 'carrera_pantallas.dart';
import 'modos.dart';

/// Modos de carrera: varias temporadas seguidas con el mismo club.
bool esModoCarrera(ModoJuego m) => const {ModoJuego.dinastia, ModoJuego.reescribi}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarCarrera(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  final contexto = c.context;
  final id = ContextoModos.nuevoId();
  final rerolls = Temporada.rerollsPorTemporada + perfilApp.value.fichasExtra;
  final Temporada t;
  if (m == ModoJuego.dinastia) {
    final modo = await elegirModoDraft(contexto);
    if (modo == null || !contexto.mounted) return;
    final regla = await elegirRegla(
      contexto,
      modo: modo,
      coleccionAlcanza: c.liga().then((l) => Draft.coleccionAlcanza(l.catalogo, perfilApp.value.coleccion)),
    );
    if (regla == null || !contexto.mounted) return;
    final dificultad = await elegirDificultad(contexto);
    if (dificultad == null) return;
    t = Temporada(
      id: id,
      franquiciaUsuarioId: enfocada.id,
      modo: modo,
      dificultad: dificultad,
      regla: regla.$1,
      epocaRegla: regla.$2,
      rerollsRestantes: rerolls,
      modoJuego: ModoJuego.dinastia,
      datosModo: CarreraDinastia.datosIniciales(id),
    );
  } else {
    final carrera = CarreraDinastia(await c.liga());
    if (!contexto.mounted) return;
    final epoca = await elegirDecada(contexto, enfocada, carrera);
    if (epoca == null || !contexto.mounted) return;
    final dificultad = await elegirDificultad(contexto);
    if (dificultad == null) return;
    t = carrera.reescribir(id: id, franquiciaId: enfocada.id, epoca: epoca, dificultad: dificultad, rerolls: rerolls);
  }
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// Reescribí la historia: ¿en qué década arrancás? Muestra las figuras de cada plantel.
Future<Epoca?> elegirDecada(BuildContext context, Franquicia f, CarreraDinastia carrera) {
  final epocas = carrera.epocasPosibles(f.id);
  return showModalBottomSheet<Epoca>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final tema = Theme.of(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿EN QUÉ DÉCADA ARRANCÁS?', style: tema.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Arrancás con el plantel real de los ${f.nombre} de esa década. Cada '
              '${EstadoDinastia.temporadasPorDecada} temporadas pasás a la siguiente, y en el draft de novatos '
              'aparecen los jugadores de la década que viene (el catálogo va por décadas, no por año de draft).',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (epocas.isEmpty) const Text('Esta franquicia no tiene cartas para armar un plantel completo.'),
            for (final e in epocas)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: SizedBox(width: 56, child: Center(child: TextoLed(e.codigo, tamano: 18))),
                title: Text(e.etiqueta),
                subtitle: Text(
                  (carrera.plantelDeEpoca(f.id, e)!.jugadores.toList()..sort((a, b) => b.media.compareTo(a.media)))
                      .take(3)
                      .map((j) => j.nombre)
                      .join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(e),
              ),
          ],
        ),
      );
    },
  );
}

/// Nombre completo de una franquicia o identidad histórica.
String nombreFranquicia(String id) => franquiciaPorId(id).nombreCompleto;

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaCarrera(Temporada t, ContextoModos c) async {
  final liga = await c.liga();
  final carrera = CarreraDinastia(liga);
  // La última versión de la temporada que vio esta pantalla (para abrir los playoffs o el receso).
  var actual = t;
  void guardar(Temporada x) {
    actual = x;
    c.guardar(x);
  }

  List<Widget> acciones() => [
    Builder(
      builder: (context) => IconButton(
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => HistoriaDinastiaPantalla(temporada: actual))),
        icon: const Icon(Icons.timeline),
        tooltip: 'Historia de la dinastía',
      ),
    ),
  ];

  switch (t.fase) {
    case FaseTemporada.draft:
      return null;
    case FaseTemporada.tacticas:
      return PlaybookPantalla(
        temporada: t,
        onConfirmar: (x) async {
          var lista = x.calendario.isEmpty ? liga.iniciar(x) : x;
          lista = carrera.rivalesDeEpoca(lista);
          await c.guardar(lista);
          await c.abrirTemporada(lista, reemplazar: true);
        },
      );
    case FaseTemporada.temporadaRegular:
      return TemporadaPantalla(
        temporada: t,
        liga: liga,
        onCambio: guardar,
        onPlayoffs: () => c.abrirTemporada(actual, reemplazar: true),
        acciones: acciones(),
      );
    case FaseTemporada.playoffs || FaseTemporada.finalizada:
      return PlayoffsPantalla(
        temporada: t,
        liga: liga,
        onCambio: guardar,
        acciones: acciones(),
        onSiguienteTemporada: (x) => _abrirReceso(x, liga, c),
      );
  }
}

Future<void> _abrirReceso(Temporada t, Liga liga, ContextoModos c) async {
  await c.navegador.currentState?.push(
    MaterialPageRoute<void>(
      builder: (contexto) => RecesoPantalla(
        temporada: t,
        carrera: CarreraDinastia(liga),
        nombreDe: nombreFranquicia,
        onArrancar: (nueva) async {
          // La temporada terminada queda en la historia de la dinastía: se reemplaza por la nueva.
          try {
            await c.db?.borrarTemporada(t.id);
          } catch (_) {}
          await c.guardar(nueva);
          if (contexto.mounted) Navigator.of(contexto).pop();
          await c.abrirTemporada(nueva, reemplazar: true);
        },
      ),
    ),
  );
}
