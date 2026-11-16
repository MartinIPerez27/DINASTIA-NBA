import 'package:flutter/material.dart';

import '../../data/db_local.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import 'amigos.dart';
import 'armado.dart';
import 'carrera_jugador.dart';
import 'competitivo.dart';
import 'carrera.dart';
import 'epocas.dart';
import 'escalera.dart';
import 'fantasy.dart';
import 'historia.dart';
import 'menu_modos.dart';
import 'perfil_perfecto.dart';
import 'universitario.dart';
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
  _ when m == ModoJuego.carreraJugador => iniciarCarreraJugador(c),
  _ when m == ModoJuego.universitario => iniciarUniversitario(c),
  _ when esModoCompetitivo(m) => iniciarCompetitivo(m, enfocada, c),
  _ when m == ModoJuego.fantasy => iniciarFantasy(c),
  _ when m == ModoJuego.perfilPerfecto => iniciarPerfilPerfecto(c),
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
  if (m == ModoJuego.carreraJugador) return pantallaCarreraJugador(t, c);
  if (m == ModoJuego.universitario) return pantallaUniversitario(t, c);
  if (esModoCompetitivo(m)) return pantallaCompetitivo(t, c);
  if (m == ModoJuego.fantasy) return pantallaFantasy(t, c);
  return null;
}

/// Menú de modos: primer nivel con "Seguir jugando" y las categorías, cada una con su submenú
/// (ver `menu_modos.dart`). Devuelve el modo elegido en [onElegir].
class ModosPantalla extends StatelessWidget {
  const ModosPantalla({super.key, required this.onElegir, this.guardada, this.onSeguir});

  final ValueChanged<ModoJuego> onElegir;

  /// Última partida guardada y cómo seguirla (si hay, es la primera tarjeta).
  final Temporada? guardada;
  final VoidCallback? onSeguir;

  static IconData icono(ModoJuego m) => iconoModo(m);

  @override
  Widget build(BuildContext context) => MenuModos(onElegir: onElegir, guardada: guardada, onSeguir: onSeguir);
}
