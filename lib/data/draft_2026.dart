import 'package:flutter/services.dart' show rootBundle;

import '../domain/modos/generacion_carrera.dart';

/// Los elegidos reales del draft 2026 (60 picks), con su puesto y equipo.
Future<List<CompaneroGeneracion>> cargarClase2026() async =>
    GeneracionCarrera.deJson2026(await rootBundle.loadString('assets/database/draft_2026.json'));
