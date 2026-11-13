import 'package:flutter/material.dart';

import '../../data/db_local.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import 'amigos.dart';
import 'armado.dart';
import 'carrera.dart';
import 'epocas.dart';
import 'escalera.dart';
import 'historia.dart';
import 'reto.dart';
import 'variantes.dart';

/// Lo que la app le presta a cada modo: la liga, la base, el navegador y cómo guardar y abrir
/// una partida (guardar también aplica el metajuego: XP, monedas, logros…).
class ContextoModos {
  ContextoModos({
    required this.liga,
    required this.db,
    required this.navegador,
    required this.guardar,
    required this.abrirTemporada,
  });

  final Future<Liga> Function() liga;
  final DbLocal? db;
  final GlobalKey<NavigatorState> navegador;

  /// Guarda la partida y aplica el metajuego.
  final Future<void> Function(Temporada t) guardar;

  /// Abre la pantalla que corresponde (la del modo, si [pantallaDeModo] la da, o la fase clásica).
  final Future<void> Function(Temporada t, {bool reemplazar}) abrirTemporada;

  BuildContext get context => navegador.currentContext!;

  /// Id nuevo para una partida.
  static String nuevoId() => DateTime.now().millisecondsSinceEpoch.toString();
}

/// Arranca una partida nueva del modo [m] (el clásico lo arranca la app con su propio flujo).
Future<void> iniciarModo(ModoJuego m, Franquicia enfocada, ContextoModos c) => switch (m.grupo) {
  GrupoModo.principal => Future.value(),
  _ when esModoEscalera(m) => iniciarEscalera(m, enfocada, c),
  _ when esModoVariante(m) => iniciarVariante(m, enfocada, c),
  _ when esModoCarrera(m) => iniciarCarrera(m, enfocada, c),
  _ when m == ModoJuego.reto => iniciarReto(c),
  _ when esModoHistoria(m) => iniciarHistoria(m, enfocada, c),
  _ when esModoEpocas(m) => iniciarEpocas(m, enfocada, c),
  _ when esModoArmado(m) => iniciarArmado(m, enfocada, c),
  _ when esModoAmigos(m) => iniciarAmigos(m, enfocada, c),
  _ => Future.value(),
};

/// La pantalla propia del modo para esta partida, o null si sigue el flujo clásico
/// (draft → tácticas → temporada → playoffs) en la fase en que está.
Future<Widget?> pantallaDeModo(Temporada t, ContextoModos c) async {
  final m = t.modoJuego;
  if (esModoEscalera(m)) return pantallaEscalera(t, c);
  if (esModoVariante(m)) return pantallaVariante(t, c);
  if (esModoCarrera(m)) return pantallaCarrera(t, c);
  if (esModoAmigos(m)) return pantallaAmigos(t, c);
  if (esModoHistoria(m)) return pantallaHistoria(t, c);
  if (esModoEpocas(m)) return pantallaEpocas(t, c);
  if (esModoArmado(m)) return pantallaArmado(t, c);
  return null;
}

/// Menú de modos, agrupado. Devuelve el modo elegido.
class ModosPantalla extends StatelessWidget {
  const ModosPantalla({super.key, required this.onElegir});

  final ValueChanged<ModoJuego> onElegir;

  static IconData icono(ModoJuego m) => switch (m) {
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
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Modos de juego')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final g in GrupoModo.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(g.etiqueta.toUpperCase(), style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
            ),
            for (final m in ModoJuego.values.where((m) => m.grupo == g))
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(icono(m), color: tema.colorScheme.primary),
                  title: Text(m.nombre),
                  subtitle: Text(m.descripcion),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onElegir(m),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
