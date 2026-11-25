import 'package:flutter/services.dart' show rootBundle;

import '../domain/modos/records_carrera.dart';

/// Los récords históricos reales de la NBA (`tools/records_nba.py`).
Future<RecordsNba> cargarRecordsNba() async =>
    RecordsNba.fromJson(await rootBundle.loadString('assets/database/records_nba.json'));
