import 'package:flutter/foundation.dart';

import '../domain/entities/ajustes.dart';
import '../domain/entities/perfil.dart';

// shortcut: estado global de la app (ajustes y perfil) como notificadores. Son dos valores chicos
// que leen muchas pantallas; si crece, pasar a un InheritedWidget o inyección de dependencias.

/// Preferencias del jugador (velocidad, sonido, vibración…).
final ajustesApp = ValueNotifier<Ajustes>(const Ajustes());

/// Perfil del entrenador (nivel, monedas, logros…).
final perfilApp = ValueNotifier<PerfilEntrenador>(const PerfilEntrenador());
