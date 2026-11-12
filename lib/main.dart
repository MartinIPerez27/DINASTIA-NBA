import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/db_local.dart';
import 'data/franquicias.dart';
import 'domain/entities/franquicia.dart';
import 'domain/entities/temporada.dart';
import 'presentation/pantallas/draft_pantalla.dart';
import 'presentation/pantallas/inicio_pantalla.dart';
import 'presentation/pantallas/playbook_pantalla.dart';
import 'presentation/tema/tema_franquicia.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  for (final (familia, archivo) in [('Doto', 'OFL-Doto.txt'), ('Big Shoulders', 'OFL-BigShoulders.txt')]) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([familia], await rootBundle.loadString('assets/fonts/$archivo'));
    });
  }

  // Sin base de datos se puede jugar igual; solo no se guarda la temporada.
  DbLocal? db;
  Temporada? guardada;
  try {
    db = await DbLocal.abrir();
    guardada = await db.ultimaTemporada();
  } catch (e) {
    debugPrint('Base local no disponible: $e');
  }
  runApp(DinastiaNbaApp(db: db, guardada: guardada));
}

class DinastiaNbaApp extends StatefulWidget {
  const DinastiaNbaApp({super.key, this.db, this.guardada});

  final DbLocal? db;
  final Temporada? guardada;

  @override
  State<DinastiaNbaApp> createState() => _DinastiaNbaAppState();
}

class _DinastiaNbaAppState extends State<DinastiaNbaApp> {
  final _navegador = GlobalKey<NavigatorState>();
  late Franquicia _enfocada = franquiciaPorId(widget.guardada?.franquiciaUsuarioId ?? 'CHI');
  late Temporada? _guardada = widget.guardada;

  /// Abre la pantalla que corresponde a la fase de la temporada.
  void _abrirTemporada(Temporada t, {bool reemplazar = false}) {
    setState(() => _enfocada = franquiciaPorId(t.franquiciaUsuarioId));
    final pantalla = t.fase == FaseTemporada.draft
        ? DraftPantalla(
            temporada: t,
            onCambio: _guardarCambios,
            onCompleto: () => _abrirTemporada(_guardada!, reemplazar: true),
          )
        : PlaybookPantalla(temporada: t, onConfirmar: _confirmarTacticas);
    final ruta = MaterialPageRoute<void>(builder: (_) => pantalla);
    final navegador = _navegador.currentState!;
    reemplazar ? navegador.pushReplacement(ruta) : navegador.push(ruta);
  }

  // shortcut: hasta la Fase 5 no hay pantalla de temporada; al confirmar se vuelve al inicio.
  Future<void> _confirmarTacticas(Temporada t) async {
    await _guardarCambios(t);
    _navegador.currentState!.pop();
    ScaffoldMessenger.of(_navegador.currentContext!).showSnackBar(
      SnackBar(content: Text('Tácticas listas: ${t.tactica.ofensiva.nombre} + ${t.tactica.defensiva.nombre}.')),
    );
  }

  /// Cada paso del draft se guarda al instante (cerrar la app no regala tiradas).
  Future<void> _guardarCambios(Temporada t) async {
    setState(() => _guardada = t);
    try {
      await widget.db?.guardarTemporada(t);
    } catch (e) {
      ScaffoldMessenger.of(_navegador.currentContext!)
          .showSnackBar(const SnackBar(content: Text('No se pudo guardar el progreso.')));
    }
  }

  Future<void> _dirigir(Franquicia f) async {
    final t = Temporada(id: DateTime.now().millisecondsSinceEpoch.toString(), franquiciaUsuarioId: f.id);
    try {
      await widget.db?.guardarTemporada(t);
      setState(() => _guardada = t);
    } catch (e) {
      ScaffoldMessenger.of(_navegador.currentContext!)
          .showSnackBar(const SnackBar(content: Text('No se pudo guardar la temporada. Podés jugar igual.')));
    }
    _abrirTemporada(t);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dinastía NBA (82-0)',
    navigatorKey: _navegador,
    debugShowCheckedModeBanner: false,
    theme: temaFranquicia(_enfocada),
    themeAnimationDuration: const Duration(milliseconds: 250),
    themeAnimationCurve: Curves.easeOutCubic,
    home: InicioPantalla(
      franquicias: franquicias,
      enfocada: _enfocada,
      onEnfocar: (f) => setState(() => _enfocada = f),
      onDirigir: _dirigir,
      guardada: _guardada,
      onSeguir: _guardada == null ? null : () => _abrirTemporada(_guardada!),
    ),
  );
}
