import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../pantallas/playoffs_pantalla.dart';
import '../pantallas/temporada_pantalla.dart';
import '../widgets/elegir_modo.dart';
import 'carrera_jugador_pantallas.dart';
import 'creador_jugador.dart';
import 'modos.dart';

/// Mi carrera: un jugador, real o creado, del draft al Salón de la Fama.
Future<void> iniciarCarreraJugador(ContextoModos c) async {
  final liga = await c.liga();
  if (!c.context.mounted) return;
  final carrera = CarreraJugador(liga);
  final tipo = await showModalBottomSheet<bool>(
    context: c.context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final tema = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('MI CARRERA', style: tema.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Un solo jugador, toda una carrera: sumás puntos de habilidad, ganás la confianza del DT, hablás con '
                'la prensa, negociás contratos y buscás el Salón de la Fama. El equipo lo maneja la IA.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.history_edu),
                title: const Text('UN JUGADOR REAL'),
                subtitle: const Text('Arrancás en su año de novato, con su equipo y su elección real del draft.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(true),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('CREAR UN JUGADOR'),
                subtitle: const Text('Tu nombre, puesto, físico y arquetipo. Combine, draft y a ganarte un lugar.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (tipo == null || !c.context.mounted) return;
  final id = ContextoModos.nuevoId();
  final semilla = int.parse(id) & 0x7fffffff;
  final nav = c.navegador.currentState!;
  if (tipo) {
    final carta = await nav.push(
      MaterialPageRoute<Jugador>(builder: (_) => ElegirJugadorRealPantalla(carrera: carrera)),
    );
    if (carta == null || !c.context.mounted) return;
    final dificultad = await elegirDificultad(c.context);
    if (dificultad == null || !c.context.mounted) return;
    final estado = carrera.estadoReal(raiz: id, carta: carta);
    final franquicia = await nav.push(
      MaterialPageRoute<String>(
        builder: (_) => NocheDraftPantalla(
          nombre: carta.nombre,
          pick: estado.pick,
          franquiciaId: estado.franquiciaId,
          anio: estado.anioBase,
          real: true,
        ),
      ),
    );
    if (franquicia == null) return;
    final t = carrera.nuevaCarrera(estado: estado, dificultad: dificultad);
    await c.guardar(t);
    await c.abrirTemporada(t);
    return;
  }
  final creado = await nav.push(
    MaterialPageRoute<JugadorCreado>(
      builder: (_) => const CreadorJugadorPantalla(titulo: 'Creá tu jugador', textoBoton: 'IR AL COMBINE'),
    ),
  );
  if (creado == null || !c.context.mounted) return;
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null || !c.context.mounted) return;
  final combine = carrera.combine(creado, Random(semilla));
  final listo = await nav.push(
    MaterialPageRoute<bool>(
      builder: (_) => CombinePantalla(creado: creado, resultado: combine),
    ),
  );
  if (listo != true) return;
  final orden = carrera.ordenDraft(semilla);
  final propio = orden[(combine.pick - 1) % orden.length];
  final opciones = [for (final f in (List.of(orden)..shuffle(Random(semilla + 1))).take(3)) f];
  final franquicia = await nav.push(
    MaterialPageRoute<String>(
      builder: (_) => NocheDraftPantalla(
        nombre: creado.nombre,
        pick: combine.pick,
        franquiciaId: propio,
        anio: 2026,
        opciones: opciones,
      ),
    ),
  );
  if (franquicia == null) return;
  final estado = carrera.estadoCreado(raiz: id, creado: creado, pick: combine.pick, franquiciaId: franquicia);
  final t = carrera.nuevaCarrera(estado: estado, dificultad: dificultad);
  await c.guardar(t);
  await c.abrirTemporada(t);
}

String _nombreDe(String id) => franquiciaPorId(id).nombreCompleto;

/// Pantalla de la partida de Mi carrera según dónde esté: temporada, playoffs, receso o retiro.
Future<Widget?> pantallaCarreraJugador(Temporada t, ContextoModos c) async {
  final estado = EstadoCarrera.de(t);
  if (estado == null) return null;
  final liga = await c.liga();
  final carrera = CarreraJugador(liga);
  liga.registrarCarta(estado.carta);
  // La última versión de la temporada que vio esta pantalla.
  var actual = t;
  void guardar(Temporada x) {
    actual = x;
    c.guardar(x);
  }

  if (estado.retirado) {
    return LegadoCarreraPantalla(
      estado: estado,
      carrera: carrera,
      alInicio: () => c.navegador.currentState?.popUntil((r) => r.isFirst),
    );
  }
  if (estado.cerrada) return _receso(t, estado, null, carrera, c, apilado: false);

  List<Widget> acciones() => [
    Builder(
      builder: (context) => IconButton(
        onPressed: () {
          final e = EstadoCarrera.de(actual) ?? estado;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LegadoCarreraPantalla(estado: e, carrera: carrera),
            ),
          );
        },
        icon: const Icon(Icons.timeline),
        tooltip: 'Historia de tu carrera',
      ),
    ),
  ];

  switch (t.fase) {
    case FaseTemporada.draft || FaseTemporada.tacticas:
      return null;
    case FaseTemporada.temporadaRegular:
      return TemporadaPantalla(
        temporada: t,
        liga: liga,
        onCambio: guardar,
        onPlayoffs: () => c.abrirTemporada(actual, reemplazar: true),
        acciones: acciones(),
        modoJugador: true,
        ajustar: carrera.alGuardar,
        cabeceraBuilder: (context, temp, cambiar) {
          final e = EstadoCarrera.de(temp);
          if (e == null) return const SizedBox.shrink();
          return TarjetaMiJugador(
            estado: e,
            marca: carrera.marca(temp, e),
            onAbrir: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MiJugadorPantalla(temporada: temp, carrera: carrera, onCambiar: cambiar),
              ),
            ),
          );
        },
      );
    case FaseTemporada.playoffs || FaseTemporada.finalizada:
      return PlayoffsPantalla(
        temporada: t,
        liga: liga,
        onCambio: guardar,
        acciones: acciones(),
        onSiguienteTemporada: (x) async {
          final e = EstadoCarrera.de(x) ?? estado;
          final cierre = carrera.cerrar(x, e, _nombreDe);
          final cerrada = x.copyWith(datosModo: cierre.estado.aDatos());
          actual = cerrada;
          await c.guardar(cerrada);
          await c.navegador.currentState?.push(
            MaterialPageRoute<void>(builder: (_) => _receso(cerrada, cierre.estado, cierre, carrera, c, apilado: true)),
          );
        },
      );
  }
}

/// El receso de una temporada terminada [t] (el cierre es null al retomar uno empezado).
///
/// Con [apilado] el receso se abrió encima de los playoffs: al seguir, hay que cerrarlo antes de
/// reemplazar esa pantalla. Si se retomó desde el inicio, la reemplaza directamente.
Widget _receso(
  Temporada t,
  EstadoCarrera estado,
  CierreTemporada? cierre,
  CarreraJugador carrera,
  ContextoModos c, {
  required bool apilado,
}) {
  var actual = t;
  return Builder(
    builder: (contexto) => RecesoJugadorPantalla(
      temporada: t,
      estado: estado,
      carrera: carrera,
      cierre: cierre,
      onEstado: (e) {
        actual = actual.copyWith(datosModo: e.aDatos());
        c.guardar(actual);
      },
      onRetirar: (e) async {
        final retirado = carrera.retirar(e);
        actual = actual.copyWith(datosModo: retirado.aDatos());
        await c.guardar(actual);
        if (apilado && contexto.mounted) Navigator.of(contexto).pop();
        await c.abrirTemporada(actual, reemplazar: true);
      },
      onSeguir: (e, oferta) async {
        final nueva = carrera.siguiente(actual.copyWith(datosModo: e.aDatos()), e, oferta: oferta);
        // La temporada terminada queda en la historia de tu carrera: se reemplaza por la nueva.
        try {
          await c.db?.borrarTemporada(t.id);
        } catch (_) {}
        await c.guardar(nueva);
        if (apilado && contexto.mounted) Navigator.of(contexto).pop();
        await c.abrirTemporada(nueva, reemplazar: true);
      },
    ),
  );
}
