import 'domain/coleccion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/fotos/arranque_fotos.dart';
import 'core/orientacion.dart';
import 'data/arranque.dart';
import 'data/catalogo_jugadores.dart';
import 'data/db_local.dart';
import 'data/estado_app.dart';
import 'data/franquicias.dart';
import 'domain/version_catalogo.dart';
import 'domain/entities/ajustes.dart';
import 'domain/entities/franquicia.dart';
import 'domain/entities/metajuego.dart';
import 'domain/entities/modo_juego.dart';
import 'domain/entities/perfil.dart';
import 'domain/entities/temporada.dart';
import 'domain/liga.dart';
import 'domain/misiones.dart';
import 'domain/partido_en_curso.dart';
import 'domain/modos/evoluciones.dart';
import 'domain/progreso.dart';
import 'domain/reto.dart';
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
import 'presentation/widgets/carga.dart';
import 'presentation/widgets/escala_texto.dart';
import 'presentation/widgets/elegir_modo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await aplicarOrientacion();
  for (final (familia, archivo) in [('Doto', 'OFL-Doto.txt'), ('Big Shoulders', 'OFL-BigShoulders.txt')]) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([familia], await rootBundle.loadString('assets/fonts/$archivo'));
    });
  }

  // Sin base de datos se puede jugar igual; solo no se guarda la temporada.
  DbLocal? db;
  ResultadoArranque? arranque;
  try {
    db = await DbLocal.abrir();
    // Cada lectura va por separado: una partida o un perfil dañados no tumban al resto.
    arranque = await cargarArranque(db);
    await iniciarGestorFotos(db);
    if (arranque.ajustes case final a?) ajustesApp.value = a;
    if (arranque.perfil case final p?) perfilApp.value = p;
  } catch (e) {
    debugPrint('Base local no disponible: $e');
  }
  runApp(
    DinastiaNbaApp(
      db: db,
      guardada: arranque?.guardada,
      avisosArranque: arranque?.avisos ?? const [],
      perfilIlegible: arranque?.perfilIlegible ?? false,
    ),
  );
}

class DinastiaNbaApp extends StatefulWidget {
  const DinastiaNbaApp({
    super.key,
    this.db,
    this.guardada,
    this.avisosArranque = const [],
    this.perfilIlegible = false,
  });

  final DbLocal? db;
  final Temporada? guardada;

  /// Avisos de la carga inicial (partidas dañadas, perfil ilegible…).
  final List<String> avisosArranque;

  /// El perfil guardado no se pudo leer: hay que preguntarle al usuario qué hacer.
  final bool perfilIlegible;

  @override
  State<DinastiaNbaApp> createState() => _DinastiaNbaAppState();
}

class _DinastiaNbaAppState extends State<DinastiaNbaApp> {
  final _navegador = GlobalKey<NavigatorState>();
  late Franquicia _enfocada = franquiciaPorId(widget.guardada?.franquiciaUsuarioId ?? 'CHI');
  late Temporada? _guardada = widget.guardada;
  Liga? _liga;

  /// Una sola liga para toda la app (el catálogo se carga una vez).
  Future<Liga> _ligaLista() async =>
      _liga ??= Liga(await cargarCatalogo(), franquicias)..nivelEvolucion = (id) => nivelEvo(perfilApp.value, id);

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
        guardada: _guardada,
        onSeguir: _guardada == null
            ? null
            : () {
                Navigator.of(c).popUntil((r) => r.isFirst);
                _abrirTemporada(_guardada!);
              },
        onElegir: (m) {
          Navigator.of(c).popUntil((r) => r.isFirst);
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
  void dispose() {
    Misiones.alAnotar = null;
    PartidoEnCurso.alEmpezar = null;
    PartidoEnCurso.alTerminar = null;
    super.dispose();
  }

  /// Avance de misiones que no queda en la temporada (partido en vivo, partido de un desafío): se
  /// aplica al perfil y se guarda en el acto, sin cola en memoria. Las partidas importadas (de
  /// exhibición) no suman.
  /// Marca en la base que hay un partido en vivo abierto de la partida actual (y la borra al terminar).
  void _marcarPartido(bool abierto) {
    final id = _guardada?.id;
    if (id == null) return;
    widget.db?.escribir('partido_en_curso', abierto ? {'temporada': id} : const {}).ignore();
  }

  /// Si se cerró la app a mitad de un partido de esta partida, se simula ahora: no se puede repetir.
  Future<Temporada> _resolverPartidoAbandonado(Temporada t) async {
    try {
      final marca = await widget.db?.leer('partido_en_curso');
      if (marca == null || marca['temporada'] != t.id) return t;
      await widget.db?.escribir('partido_en_curso', const {});
      if (!t.modoJuego.usaTemporada || t.importada) return t;
      final liga = await _ligaLista();
      Temporada? nueva;
      if (t.fase == FaseTemporada.temporadaRegular) {
        nueva = liga.simularProximo(t);
      } else if (t.fase == FaseTemporada.playoffs && t.serieDelUsuario != null) {
        nueva = liga.simularPartidoPlayoff(t);
      }
      if (nueva == null) return t;
      setState(() => _guardada = t); // el "antes" del metajuego es esta partida
      await _guardarCambios(nueva);
      _avisoGuardado('Cerraste la app en medio de un partido: se simuló y quedó registrado.');
      return nueva;
    } catch (_) {
      return t;
    }
  }

  void _anotarMision(TipoMision tipo, int cantidad) {
    if (_guardada?.importada ?? false) return;
    _guardarPerfil(Misiones.anotarEn(perfilApp.value, tipo, cantidad, DateTime.now()));
  }

  @override
  void initState() {
    super.initState();
    Misiones.alAnotar = _anotarMision;
    PartidoEnCurso.alEmpezar = () => _marcarPartido(true);
    PartidoEnCurso.alTerminar = () => _marcarPartido(false);
    if (!ajustesApp.value.tutorialVisto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirTutorial());
    }
    if (widget.perfilIlegible || widget.avisosArranque.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _avisarArranque());
    }
  }

  /// Cuenta qué salió mal al arrancar; si el perfil no se pudo leer, deja elegir qué hacer.
  Future<void> _avisarArranque() async {
    final contexto = _navegador.currentContext;
    if (contexto == null || !contexto.mounted) return;
    final texto = widget.avisosArranque.join('\n\n');
    if (!widget.perfilIlegible) {
      ScaffoldMessenger.maybeOf(contexto)
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 8)));
      return;
    }
    final nuevo = await showDialog<bool>(
      context: contexto,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('No se pudo leer tu perfil'),
        content: Text(
          '$texto\n\nGuardamos una copia de lo que había (perfil.bak). Si empezás con un perfil nuevo, '
          'el progreso de esta copia no se va a ver. Si elegís seguir sin guardar, jugás normal pero '
          'no se guarda tu progreso en esta sesión.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('SEGUIR SIN GUARDAR')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('EMPEZAR PERFIL NUEVO')),
        ],
      ),
    );
    if (nuevo == true) {
      perfilApp.value = const PerfilEntrenador();
      await widget.db?.empezarPerfilNuevo(perfilApp.value);
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

  /// Espera [f] mostrando "Cargando…" si el catálogo todavía no está listo y tarda.
  Future<T> _conCarga<T>(Future<T> f) =>
      _liga != null || _navegador.currentState == null ? f : conCarga(_navegador.currentState!, f);

  Future<void> _abrirPerfil() async {
    final liga = await _conCarga(_ligaLista());
    _navegador.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => PerfilPantalla(jugador: liga.jugador, onVestuario: _abrirVestuario),
      ),
    );
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
    _escribirPerfil(p);
  }

  /// Perfil cambiado en memoria que todavía no llegó a la base (falló un guardado).
  var _perfilSinGuardar = false;

  /// Escribe el perfil y, si falla, avisa (antes el error se ignoraba en silencio).
  Future<void> _escribirPerfil(PerfilEntrenador p) async {
    try {
      await widget.db?.escribir('perfil', p.toJson());
      _perfilSinGuardar = false;
    } catch (e) {
      _perfilSinGuardar = true;
      _avisoGuardado('No se pudo guardar tu perfil. Se reintenta con el próximo guardado.');
    }
  }

  void _avisoGuardado(String texto) {
    final contexto = _navegador.currentContext;
    if (contexto == null) return;
    ScaffoldMessenger.maybeOf(contexto)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _abrirMisiones() => _navegador.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => MisionesPantalla(franquicia: _enfocada, onPerfil: _guardarPerfil),
    ),
  );

  void _abrirVestuario() => _navegador.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => VestuarioPantalla(franquicia: _enfocada, onPerfil: _guardarPerfil),
    ),
  );

  Future<void> _abrirAlbum() async {
    final liga = await _conCarga(_ligaLista());
    _navegador.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumPantalla(
          catalogo: liga.catalogo,
          onPerfil: _guardarPerfil,
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
    t = await _resolverPartidoAbandonado(t);
    setState(() {
      _enfocada = franquiciaPorId(t.franquiciaUsuarioId);
      _guardada = t;
    });
    final Widget pantalla;
    // Si el catálogo todavía se está leyendo, un indicador evita que parezca que no pasó nada.
    final propia = await _conCarga(pantallaDeModo(t, _modos));
    if (propia != null) {
      pantalla = propia;
    } else {
      pantalla = await _conCarga(_pantallaClasica(t));
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
          azarPara: Reto.azarPara(t),
          onCambio: _guardarCambios,
          onPerfil: (p) => widget.db?.escribir('perfil', p.toJson()).ignore(),
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
    final lista = t.calendario.isEmpty && t.modoJuego.usaTemporada ? Reto.ligaPara(liga, t).iniciar(t) : t;
    await _guardarCambios(lista);
    await _abrirTemporada(lista, reemplazar: true);
  }

  /// Último estado de cada partida sobre el que ya se aplicó el metajuego. Si todavía no cargó la liga,
  /// el "antes" no puede ser el estado en memoria: se perdería el premio de ese paso (META-12).
  Temporada? _baseProgreso;

  /// Cada paso del draft se guarda al instante (cerrar la app no regala tiradas).
  Future<void> _guardarCambios(Temporada t) async {
    final antes = _guardada;
    final base = _baseProgreso != null && _baseProgreso!.id == t.id ? _baseProgreso : antes;
    // Versión del catálogo: una partida nueva se sella con la de ahora; las pantallas que no la
    // conocen heredan la que ya tenía guardada (las partidas anteriores al versionado quedan sin).
    if (t.versionCatalogo == null) {
      final misma = antes != null && antes.id == t.id;
      if (misma && antes.versionCatalogo != null) {
        t = t.copyWith(versionCatalogo: antes.versionCatalogo);
      } else if (!misma || (t.calendario.isEmpty && !t.tacticaConfirmada)) {
        // Partida nueva, o todavía en el draft (las cartas que salgan son las de este catálogo).
        if (_liga != null && versionCatalogo != 0) t = t.copyWith(versionCatalogo: versionCatalogo);
      }
    }
    setState(() => _guardada = t);
    // Metajuego: XP, monedas, puntaje, logros, trofeos e historial por lo que acaba de pasar.
    Liga? liga = _liga;
    if (liga == null) {
      try {
        liga = await _ligaLista();
      } catch (_) {}
    }
    if (liga != null) {
      final (perfil, novedades) = Progreso(liga).aplicar(perfilApp.value, base, t);
      if (!identical(perfil, perfilApp.value)) {
        perfilApp.value = perfil;
        _perfilSinGuardar = true;
      }
      _baseProgreso = t;
      if (_navegador.currentState?.overlay case final overlay?) Avisos.mostrar(overlay, novedades);
    } else {
      _baseProgreso = base; // sin liga no se aplicó nada: el próximo guardado cobra la diferencia
    }
    try {
      // Partida y perfil en una sola transacción: o se guardan las dos o ninguna.
      await widget.db?.guardarTemporadaYPerfil(t, _perfilSinGuardar ? perfilApp.value : null);
      _perfilSinGuardar = false;
    } catch (e) {
      _avisoGuardado('No se pudo guardar el progreso.');
    }
  }

  Future<void> _dirigir(Franquicia f) async {
    final modo = await elegirModoDraft(_navegador.currentContext!);
    if (modo == null) return;
    final regla = await elegirRegla(
      _navegador.currentContext!,
      modo: modo,
      coleccionAlcanza: _ligaLista().then((l) => coleccionLlenaPuestos(l.catalogo, perfilApp.value.coleccion)),
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
      // Semilla del draft y de la liga: con ella se puede retar a un amigo a jugar el mismo draft.
      datosModo: Reto.datosNuevos(Temporada.rerollsPorTemporada + perfilApp.value.fichasExtra),
      versionCatalogo: versionCatalogo == 0 ? null : versionCatalogo,
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
    builder: conTopeEscalaTexto,
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
