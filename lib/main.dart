import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/catalogo_jugadores.dart';
import 'data/db_local.dart';
import 'data/estado_app.dart';
import 'data/franquicias.dart';
import 'domain/draft.dart';
import 'domain/entities/ajustes.dart';
import 'domain/entities/franquicia.dart';
import 'domain/entities/modo_juego.dart';
import 'domain/entities/perfil.dart';
import 'domain/entities/temporada.dart';
import 'domain/liga.dart';
import 'domain/progreso.dart';
import 'presentation/modos/modos.dart';
import 'presentation/pantallas/ajustes_pantalla.dart';
import 'presentation/pantallas/album_pantalla.dart';
import 'presentation/pantallas/draft_pantalla.dart';
import 'presentation/pantallas/inicio_pantalla.dart';
import 'presentation/pantallas/misiones_pantalla.dart';
import 'presentation/pantallas/vestuario_pantalla.dart';
import 'presentation/pantallas/partidas_pantalla.dart';
import 'presentation/pantallas/perfil_pantalla.dart';
import 'presentation/pantallas/playbook_pantalla.dart';
import 'presentation/pantallas/playoffs_pantalla.dart';
import 'presentation/pantallas/temporada_pantalla.dart';
import 'presentation/pantallas/tutorial_pantalla.dart';
import 'presentation/tema/tema_franquicia.dart';
import 'presentation/widgets/aviso.dart';
import 'presentation/widgets/elegir_modo.dart';

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
    if (await db.leer('ajustes') case final j?) ajustesApp.value = Ajustes.fromJson(j);
    if (await db.leer('perfil') case final j?) perfilApp.value = PerfilEntrenador.fromJson(j);
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
  Liga? _liga;

  /// Una sola liga para toda la app (el catálogo se carga una vez).
  Future<Liga> _ligaLista() async => _liga ??= Liga(await cargarCatalogo(), franquicias);

  late final _modos = ContextoModos(
    liga: _ligaLista,
    db: widget.db,
    navegador: _navegador,
    guardar: _guardarCambios,
    abrirTemporada: _abrirTemporada,
  );

  void _abrirModos() => _navegador.currentState?.push(
    MaterialPageRoute<void>(
      builder: (c) => ModosPantalla(
        onElegir: (m) {
          Navigator.of(c).pop();
          if (m == ModoJuego.clasico) {
            _dirigir(_enfocada);
          } else {
            iniciarModo(m, _enfocada, _modos);
          }
        },
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    if (!ajustesApp.value.tutorialVisto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirTutorial());
    }
  }

  void _abrirTutorial() => _navegador.currentState?.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (c) => TutorialPantalla(
        onTerminar: () {
          _guardarAjustes(ajustesApp.value.copyWith(tutorialVisto: true));
          Navigator.of(c).pop();
        },
      ),
    ),
  );

  void _guardarAjustes(Ajustes a) {
    ajustesApp.value = a;
    widget.db?.escribir('ajustes', a.toJson()).ignore();
  }

  Future<void> _abrirPerfil() async {
    final liga = await _ligaLista();
    _navegador.currentState?.push(MaterialPageRoute<void>(builder: (_) => PerfilPantalla(jugador: liga.jugador, onVestuario: _abrirVestuario)));
  }

  Future<void> _abrirPartidas() async {
    Temporada? elegida;
    await _navegador.currentState?.push(
      MaterialPageRoute<void>(
        builder: (c) => PartidasPantalla(
          db: widget.db,
          onContinuar: (t) {
            elegida = t;
            Navigator.of(c).pop();
          },
        ),
      ),
    );
    if (elegida case final t?) {
      _abrirTemporada(t);
    } else {
      // Pudo haber importado o borrado partidas: el "Seguir" de inicio refleja lo que quedó.
      final ultima = await widget.db?.ultimaTemporada();
      if (mounted) setState(() => _guardada = ultima);
    }
  }

  void _guardarPerfil(PerfilEntrenador p) {
    perfilApp.value = p;
    widget.db?.escribir('perfil', p.toJson()).ignore();
  }

  void _abrirMisiones() => _navegador.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => MisionesPantalla(franquicia: _enfocada, onPerfil: _guardarPerfil)),
  );

  void _abrirVestuario() => _navegador.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => VestuarioPantalla(franquicia: _enfocada, onPerfil: _guardarPerfil)),
  );

  Future<void> _abrirAlbum() async {
    final liga = await _ligaLista();
    _navegador.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumPantalla(
          catalogo: liga.catalogo,
          onPerfil: (p) {
            perfilApp.value = p;
            widget.db?.escribir('perfil', p.toJson()).ignore();
          },
        ),
      ),
    );
  }

  void _abrirAjustes() => _navegador.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => AjustesPantalla(onCambio: _guardarAjustes, onTutorial: _abrirTutorial),
    ),
  );

  /// Abre la pantalla que corresponde a la fase de la temporada.
  Future<void> _abrirTemporada(Temporada t, {bool reemplazar = false}) async {
    setState(() {
      _enfocada = franquiciaPorId(t.franquiciaUsuarioId);
      _guardada = t;
    });
    final Widget pantalla;
    final propia = await pantallaDeModo(t, _modos);
    if (propia != null) {
      pantalla = propia;
    } else {
      pantalla = await _pantallaClasica(t);
    }
    final ruta = MaterialPageRoute<void>(builder: (_) => pantalla);
    final navegador = _navegador.currentState!;
    reemplazar ? navegador.pushReplacement(ruta) : navegador.push(ruta);
  }

  /// Draft → tácticas → temporada → playoffs, según la fase de la partida.
  Future<Widget> _pantallaClasica(Temporada t) async {
    final Widget pantalla;
    switch (t.fase) {
      case FaseTemporada.draft:
        pantalla = DraftPantalla(
          temporada: t,
          onCambio: _guardarCambios,
          onCompleto: () => _abrirTemporada(_guardada!, reemplazar: true),
        );
      case FaseTemporada.tacticas:
        pantalla = PlaybookPantalla(temporada: t, onConfirmar: _confirmarTacticas);
      case FaseTemporada.temporadaRegular:
        final liga = await _ligaLista();
        pantalla = TemporadaPantalla(
          temporada: t,
          liga: liga,
          onCambio: _guardarCambios,
          onPlayoffs: () => _abrirTemporada(_guardada!, reemplazar: true),
        );
      case FaseTemporada.playoffs || FaseTemporada.finalizada:
        final liga = await _ligaLista();
        pantalla = PlayoffsPantalla(temporada: t, liga: liga, onCambio: _guardarCambios);
    }
    return pantalla;
  }

  /// Con las tácticas confirmadas se arma la temporada (calendario y rivales) y se abre.
  Future<void> _confirmarTacticas(Temporada t) async {
    final liga = await _ligaLista();
    final lista = t.calendario.isEmpty && t.modoJuego.usaTemporada ? liga.iniciar(t) : t;
    await _guardarCambios(lista);
    await _abrirTemporada(lista, reemplazar: true);
  }

  /// Cada paso del draft se guarda al instante (cerrar la app no regala tiradas).
  Future<void> _guardarCambios(Temporada t) async {
    final antes = _guardada;
    setState(() => _guardada = t);
    // Metajuego: XP, monedas, puntaje, logros, trofeos e historial por lo que acaba de pasar.
    if (_liga case final liga?) {
      final (perfil, novedades) = Progreso(liga).aplicar(perfilApp.value, antes, t);
      if (!identical(perfil, perfilApp.value)) {
        perfilApp.value = perfil;
        widget.db?.escribir('perfil', perfil.toJson()).ignore();
      }
      if (_navegador.currentState?.overlay case final overlay?) Avisos.mostrar(overlay, novedades);
    }
    try {
      await widget.db?.guardarTemporada(t);
    } catch (e) {
      ScaffoldMessenger.of(_navegador.currentContext!)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('No se pudo guardar el progreso.')));
    }
  }

  Future<void> _dirigir(Franquicia f) async {
    final modo = await elegirModoDraft(_navegador.currentContext!);
    if (modo == null) return;
    final regla = await elegirRegla(
      _navegador.currentContext!,
      modo: modo,
      coleccionAlcanza: _ligaLista().then((l) => Draft.coleccionAlcanza(l.catalogo, perfilApp.value.coleccion)),
    );
    if (regla == null) return;
    final dificultad = await elegirDificultad(_navegador.currentContext!);
    if (dificultad == null) return;
    final t = Temporada(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      franquiciaUsuarioId: f.id,
      modo: modo,
      dificultad: dificultad,
      regla: regla.$1,
      epocaRegla: regla.$2,
      rerollsRestantes: Temporada.rerollsPorTemporada + perfilApp.value.fichasExtra,
    );
    try {
      await widget.db?.guardarTemporada(t);
      setState(() => _guardada = t);
    } catch (e) {
      ScaffoldMessenger.of(_navegador.currentContext!)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('No se pudo guardar la temporada. Podés jugar igual.')));
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
      onPerfil: _abrirPerfil,
      onPartidas: _abrirPartidas,
      onAlbum: _abrirAlbum,
      onAjustes: _abrirAjustes,
      onModos: _abrirModos,
      onMisiones: _abrirMisiones,
    ),
  );
}
