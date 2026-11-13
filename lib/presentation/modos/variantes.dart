import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/draft.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/plantel.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/version_catalogo.dart';
import '../../domain/variantes.dart';
import '../pantallas/draft_pantalla.dart';
import '../pantallas/playbook_pantalla.dart';
import '../widgets/carta_jugador.dart';
import '../widgets/elegir_modo.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Variantes de la temporada clásica: cambia cómo se arma el plantel o las reglas, no el formato.
bool esModoVariante(ModoJuego m) => const {
  ModoJuego.leyendaUnica,
  ModoJuego.extremo,
  ModoJuego.soloEntrenador,
  ModoJuego.espejo,
  ModoJuego.desafioDelDia,
}.contains(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarVariante(ModoJuego m, Franquicia enfocada, ContextoModos c) => switch (m) {
  ModoJuego.leyendaUnica => _leyendaUnica(enfocada, c),
  ModoJuego.extremo => _extremo(enfocada, c),
  ModoJuego.soloEntrenador => _soloEntrenador(enfocada, c),
  ModoJuego.espejo => _espejo(enfocada, c),
  ModoJuego.desafioDelDia => _desafioDelDia(c),
  _ => Future.value(),
};

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase.
Future<Widget?> pantallaVariante(Temporada t, ContextoModos c) async {
  final m = t.modoJuego;
  switch (t.fase) {
    case FaseTemporada.draft:
      if (m != ModoJuego.espejo && m != ModoJuego.desafioDelDia) return null;
      return _draft(t, c);
    case FaseTemporada.tacticas:
      final liga = await c.liga();
      if (m == ModoJuego.espejo && t.datosModo[Variantes.claveEspejado] != true) {
        final espejada = Variantes(liga.catalogo).espejar(t);
        return EspejoRevelado(
          tuyo: t.plantel,
          ia: espejada.plantel,
          onSeguir: () async {
            await c.guardar(espejada);
            await c.abrirTemporada(espejada, reemplazar: true);
          },
        );
      }
      return PlaybookPantalla(
        temporada: t,
        onConfirmar: (lista) async {
          final nueva = Variantes(liga.catalogo).iniciar(liga, lista);
          await c.guardar(nueva);
          await c.abrirTemporada(nueva, reemplazar: true);
        },
      );
    default:
      return null;
  }
}

/// Draft con agregados: el espejo anota lo que dejás pasar; el del día usa la semilla de la fecha.
Future<Widget> _draft(Temporada t, ContextoModos c) async {
  final liga = await c.liga();
  final draft = Draft(liga.catalogo);
  final espejo = t.modoJuego == ModoJuego.espejo;
  var ultima = t;
  var pasadas = Variantes.pasadas(t);
  return DraftPantalla(
    temporada: t,
    catalogo: liga.catalogo,
    azar: t.modoJuego == ModoJuego.desafioDelDia ? Variantes.azarDraftDelDia(t) : null,
    onCambio: (nueva) {
      if (espejo) {
        pasadas = Variantes.registrarPasadas(draft, ultima, nueva, pasadas);
        nueva = nueva.copyWith(datosModo: {...nueva.datosModo, Variantes.clavePasadas: pasadas});
      }
      ultima = nueva;
      c.guardar(nueva);
    },
    onCompleto: () => c.abrirTemporada(ultima, reemplazar: true),
  );
}

Future<void> _crear(ContextoModos c, Temporada t) async {
  await c.guardar(t);
  await c.abrirTemporada(t);
}

// ── Leyenda única ──

Future<void> _leyendaUnica(Franquicia enfocada, ContextoModos c) async {
  final liga = await c.liga();
  if (!c.context.mounted) return;
  final variantes = Variantes(liga.catalogo);
  final leyenda = await elegirLeyenda(c.context, variantes.leyendasParaElegir());
  if (leyenda == null || !c.context.mounted) return;
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null) return;
  await _crear(
    c,
    Temporada(
      id: ContextoModos.nuevoId(),
      franquiciaUsuarioId: enfocada.id,
      plantel: variantes.conLeyenda(leyenda, dificultad),
      dificultad: dificultad,
      rerollsRestantes: 0,
      modoJuego: ModoJuego.leyendaUnica,
      datosModo: {'leyenda': leyenda.id},
    ),
  );
}

/// Hoja con las figuras para elegir. Devuelve la elegida (null si se cierra).
Future<Jugador?> elegirLeyenda(BuildContext context, List<Jugador> opciones) => showModalBottomSheet<Jugador>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => SelectorLeyenda(opciones: opciones, onElegir: (j) => Navigator.of(context).pop(j)),
);

class SelectorLeyenda extends StatelessWidget {
  const SelectorLeyenda({super.key, required this.opciones, required this.onElegir});

  final List<Jugador> opciones;
  final ValueChanged<Jugador> onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ELEGÍ TU LEYENDA', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Es la única que elegís: los otros cinco puestos salen al azar.',
            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [for (final j in opciones) CartaJugador(jugador: j, onTap: () => onElegir(j))],
          ),
        ],
      ),
    );
  }
}

// ── Extremo ──

Future<void> _extremo(Franquicia enfocada, ContextoModos c) async {
  // Una sola partida Extremo a la vez.
  final enCurso = [
    for (final t in await c.db?.temporadas() ?? const <Temporada>[])
      if (t.modoJuego == ModoJuego.extremo && t.fase != FaseTemporada.finalizada && !Variantes.extremoPerdido(t)) t,
  ];
  if (!c.context.mounted) return;
  if (enCurso.isNotEmpty) {
    final seguir = await showDialog<bool>(
      context: c.context,
      builder: (context) => AlertDialog(
        title: const Text('Ya tenés una partida Extremo'),
        content: const Text('En Extremo hay una sola partida a la vez: terminala (o perdela) para empezar otra.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('SEGUIRLA')),
        ],
      ),
    );
    if (seguir == true) await c.abrirTemporada(enCurso.first);
    return;
  }
  final ok = await introVariante(
    c.context,
    modo: ModoJuego.extremo,
    puntos: const [
      'Sin fichas para volver a tirar: lo que sale, sale.',
      'Dificultad Difícil fija (en Leyenda, con estas lesiones, no se puede jugar).',
      'Lesiones el doble de frecuentes y un 50 % más largas.',
      'Una sola partida a la vez: si quedás afuera de los playoffs o te eliminan, está perdida.',
      'Si salís campeón: +1000 XP, +400 monedas y el logro Sobreviviente.',
    ],
    boton: 'ACEPTO EL RIESGO',
  );
  if (!ok || !c.context.mounted) return;
  final modo = await elegirModoDraft(c.context);
  if (modo == null) return;
  await _crear(
    c,
    Temporada(
      id: ContextoModos.nuevoId(),
      franquiciaUsuarioId: enfocada.id,
      modo: modo,
      dificultad: Dificultad.dificil,
      rerollsRestantes: 0,
      modoJuego: ModoJuego.extremo,
    ),
  );
}

// ── Solo entrenador ──

Future<void> _soloEntrenador(Franquicia enfocada, ContextoModos c) async {
  final ok = await introVariante(
    c.context,
    modo: ModoJuego.soloEntrenador,
    puntos: const [
      'No hay draft: el plantel te toca al azar, a la altura de la dificultad.',
      'Vos elegís las tácticas, manejás la rotación y pedís la jugada clave en vivo.',
      'Si salís campeón, ganás el logro Pizarrón.',
    ],
    boton: 'VER MI PLANTEL',
  );
  if (!ok || !c.context.mounted) return;
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null) return;
  final liga = await c.liga();
  await _crear(
    c,
    Temporada(
      id: ContextoModos.nuevoId(),
      franquiciaUsuarioId: enfocada.id,
      plantel: Variantes(liga.catalogo).alAzar(dificultad),
      dificultad: dificultad,
      rerollsRestantes: 0,
      modoJuego: ModoJuego.soloEntrenador,
    ),
  );
}

// ── Modo espejo ──

Future<void> _espejo(Franquicia enfocada, ContextoModos c) async {
  final ok = await introVariante(
    c.context,
    modo: ModoJuego.espejo,
    puntos: const [
      'Draftás como siempre, pero la IA anota cada carta que dejás pasar.',
      'Con esas cartas arma su plantel… y es el que vas a dirigir vos.',
      'Tu plantel del draft juega la temporada como un rival de tu conferencia.',
    ],
    boton: 'A DRAFTEAR',
  );
  if (!ok || !c.context.mounted) return;
  final modo = await elegirModoDraft(c.context);
  if (modo == null || !c.context.mounted) return;
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null) return;
  await _crear(
    c,
    Temporada(
      id: ContextoModos.nuevoId(),
      franquiciaUsuarioId: enfocada.id,
      modo: modo,
      dificultad: dificultad,
      rerollsRestantes: Temporada.rerollsPorTemporada + perfilApp.value.fichasExtra,
      modoJuego: ModoJuego.espejo,
    ),
  );
}

/// El cambio de planteles del Modo espejo: el tuyo pasa a ser rival y vos dirigís el de la IA.
class EspejoRevelado extends StatelessWidget {
  const EspejoRevelado({super.key, required this.tuyo, required this.ia, required this.onSeguir});

  final Plantel tuyo, ia;
  final VoidCallback onSeguir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Modo espejo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('¡CAMBIO DE PLANTELES!', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'La IA armó su equipo con las cartas que dejaste pasar. Ese es el que vas a dirigir. '
            'El que draftaste vos va a jugar la temporada en tu contra, en tu conferencia.',
            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _PlantelEspejo(titulo: 'LO DIRIGÍS VOS', subtitulo: 'Plantel de la IA', plantel: ia, destacado: true),
          const SizedBox(height: 12),
          Center(child: Icon(Icons.swap_vert, color: tema.colorScheme.primary, size: 32)),
          const SizedBox(height: 12),
          _PlantelEspejo(titulo: 'TU RIVAL', subtitulo: 'Tu plantel del draft', plantel: tuyo),
          const SizedBox(height: 20),
          FilledButton(onPressed: onSeguir, child: const Text('ELEGIR TÁCTICAS')),
        ],
      ),
    );
  }
}

class _PlantelEspejo extends StatelessWidget {
  const _PlantelEspejo({required this.titulo, required this.subtitulo, required this.plantel, this.destacado = false});

  final String titulo, subtitulo;
  final Plantel plantel;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final js = plantel.jugadores.toList();
    final media = js.isEmpty ? 0 : js.fold(0, (a, j) => a + j.media) / js.length;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: destacado ? esquema.primary : esquema.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: tema.textTheme.titleMedium),
                      Text(subtitulo, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                    ],
                  ),
                ),
                TextoLed(media.toStringAsFixed(1), tamano: 22),
              ],
            ),
            const SizedBox(height: 6),
            for (final p in Posicion.values)
              if (plantel.en(p) case final j?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(
                          p.etiqueta.toUpperCase(),
                          style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ),
                      Expanded(child: Text(j.nombre, overflow: TextOverflow.ellipsis)),
                      Text(j.tier.codigo, style: tema.textTheme.labelMedium?.copyWith(color: esquema.primary)),
                      const SizedBox(width: 10),
                      TextoLed('${j.media}', tamano: 16),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ── Desafío del día ──

Future<void> _desafioDelDia(ContextoModos c) async {
  final hoy = DateTime.now();
  final semilla = Variantes.semilla(hoy);
  final id = Variantes.idDelDia(hoy);
  final existente = await c.db?.cargarTemporada(id);
  if (!c.context.mounted) return;
  if (existente != null) {
    await c.abrirTemporada(existente);
    return;
  }
  final perfil = perfilApp.value;
  if (perfil.desafiosDelDia['$semilla'] case final v?) {
    ScaffoldMessenger.of(c.context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Ya jugaste el desafío de hoy ($v victorias). Volvé mañana.')));
    return;
  }
  final liga = await c.liga();
  if (!c.context.mounted) return;
  final franquicia = Variantes.franquiciaDelDia(hoy, liga.franquicias);
  final modo = Variantes.modoDelDia(hoy);
  final ok = await introVariante(
    c.context,
    modo: ModoJuego.desafioDelDia,
    puntos: [
      'Hoy dirigís a los ${franquicia.nombreCompleto}, con draft de ${modo.nombre}.',
      'Mismas tiradas, mismos sobres y mismos rivales para todos los que lo jueguen hoy.',
      'Dificultad Normal y 3 fichas para volver a tirar. Un solo intento por día.',
      'Tu puntaje son las victorias de la temporada regular.',
    ],
    extra: DesafioDelDiaEncabezado(fecha: hoy, desafios: perfil.desafiosDelDia),
    boton: 'JUGAR EL DESAFÍO DE HOY',
  );
  if (!ok) return;
  final nuevo = perfil.copyWith(desafiosDelDia: {...perfil.desafiosDelDia, '$semilla': 0});
  perfilApp.value = nuevo;
  c.db?.escribir('perfil', nuevo.toJson()).ignore();
  await _crear(
    c,
    Temporada(
      id: id,
      franquiciaUsuarioId: franquicia.id,
      modo: modo,
      modoJuego: ModoJuego.desafioDelDia,
      datosModo: {'semilla': semilla},
      // Sellada desde el arranque: las tiradas del día se siembran con fecha + versión de las cartas.
      versionCatalogo: versionCatalogo == 0 ? null : versionCatalogo,
    ),
  );
}

/// Fecha del desafío y tu mejor marca.
class DesafioDelDiaEncabezado extends StatelessWidget {
  const DesafioDelDiaEncabezado({super.key, required this.fecha, required this.desafios});

  final DateTime fecha;
  final Map<String, int> desafios;

  static String _fecha(int aaaammdd) => '${aaaammdd % 100}/${aaaammdd ~/ 100 % 100}/${aaaammdd ~/ 10000}';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mejor = desafios.entries.isEmpty ? null : desafios.entries.reduce((a, b) => b.value > a.value ? b : a);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DESAFÍO DEL', style: tema.textTheme.labelMedium),
              TextoLed(_fecha(Variantes.semilla(fecha)), tamano: 24),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('TU MEJOR MARCA', style: tema.textTheme.labelMedium),
            if (mejor == null)
              Text('Todavía ninguna', style: tema.textTheme.bodyMedium)
            else ...[
              TextoLed('${mejor.value} V', tamano: 24),
              Text(_fecha(int.parse(mejor.key)), style: tema.textTheme.bodySmall),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Hoja de presentación ──

/// Explica las reglas de la variante antes de empezar. Devuelve true si se confirma.
Future<bool> introVariante(
  BuildContext context, {
  required ModoJuego modo,
  required List<String> puntos,
  required String boton,
  Widget? extra,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => IntroVariante(
        modo: modo,
        puntos: puntos,
        boton: boton,
        extra: extra,
        onConfirmar: () => Navigator.of(context).pop(true),
      ),
    ) ??
    false;

class IntroVariante extends StatelessWidget {
  const IntroVariante({
    super.key,
    required this.modo,
    required this.puntos,
    required this.boton,
    required this.onConfirmar,
    this.extra,
  });

  final ModoJuego modo;
  final List<String> puntos;
  final String boton;
  final VoidCallback onConfirmar;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(ModosPantalla.icono(modo), color: esquema.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(modo.nombre.toUpperCase(), style: tema.textTheme.headlineSmall)),
            ],
          ),
          const SizedBox(height: 12),
          if (extra != null) ...[extra!, const SizedBox(height: 14)],
          for (final p in puntos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(Icons.chevron_right, size: 18, color: esquema.primary),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p, style: tema.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onConfirmar, child: Text(boton)),
        ],
      ),
    );
  }
}
