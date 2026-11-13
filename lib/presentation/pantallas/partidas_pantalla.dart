import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db_local.dart';
import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/ajustes.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/modos/amigos.dart';
import '../../domain/modos/dinastia.dart';
import '../../domain/variantes.dart';
import '../../domain/entities/temporada.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';

/// Partidas guardadas: continuar, exportar, borrar, importar y copia completa (perfil + ajustes +
/// todas las partidas) para pasar el juego a otro dispositivo.
class PartidasPantalla extends StatefulWidget {
  const PartidasPantalla({super.key, required this.db, required this.onContinuar, this.cargar});

  final DbLocal? db;
  final ValueChanged<Temporada> onContinuar;

  /// Para pruebas: de dónde salen las partidas (por defecto, `db.temporadas()`).
  final Future<List<Temporada>> Function()? cargar;

  @override
  State<PartidasPantalla> createState() => _PartidasPantallaState();
}

enum _Accion { exportar, borrar }

class _PartidasPantallaState extends State<PartidasPantalla> {
  List<Temporada>? _partidas;

  /// Resultado de la última importación o exportación (en la pantalla, no como aviso flotante).
  String? _aviso;
  var _avisoError = false;

  bool get _sinGuardado => widget.db == null && widget.cargar == null;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    final cargar = widget.cargar ?? widget.db?.temporadas;
    if (cargar == null) return;
    final partidas = await cargar();
    if (mounted) setState(() => _partidas = partidas);
  }

  void _avisar(String texto, {bool error = false}) => setState(() {
    _aviso = texto;
    _avisoError = error;
  });

  // ------------------------------------------------------------------ exportar

  static String _fechaArchivo(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${dos(d.month)}${dos(d.day)}-${dos(d.hour)}${dos(d.minute)}';
  }

  Future<void> _compartir(String nombre, Map<String, dynamic> datos) async {
    final carpeta = await getTemporaryDirectory();
    final archivo = File('${carpeta.path}/$nombre');
    await archivo.writeAsString(jsonEncode(datos), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(archivo.path, mimeType: 'application/json')],
        subject: nombre,
      ),
    );
  }

  Future<void> _exportar(Temporada t) async {
    try {
      await _compartir('dinastia-${t.franquiciaUsuarioId}-${_fechaArchivo(DateTime.now())}.json', {
        'tipo': 'partida',
        'version': 1,
        'temporada': t.toJson(),
      });
    } catch (e) {
      _avisar('No se pudo exportar la partida.', error: true);
    }
  }

  Future<void> _exportarCopia() async {
    try {
      final partidas = _partidas ?? await widget.db?.temporadas() ?? const <Temporada>[];
      await _compartir('dinastia-copia-${_fechaArchivo(DateTime.now())}.json', {
        'tipo': 'copia',
        'version': 1,
        'perfil': perfilApp.value.toJson(),
        'ajustes': ajustesApp.value.toJson(),
        'temporadas': [for (final t in partidas) t.toJson()],
      });
    } catch (e) {
      _avisar('No se pudo exportar la copia completa.', error: true);
    }
  }

  // ------------------------------------------------------------------ importar

  Future<void> _importar() async {
    final db = widget.db;
    if (db == null) return;
    final PlatformFile? elegido;
    try {
      elegido = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['json']);
    } catch (e) {
      _avisar('No se pudo abrir el selector de archivos.', error: true);
      return;
    }
    if (elegido == null) return;
    final Map<String, dynamic> datos;
    try {
      datos = jsonDecode(await elegido.xFile.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      _avisar('Ese archivo no es una partida de Dinastía NBA.', error: true);
      return;
    }
    try {
      switch (datos['tipo']) {
        case 'partida':
          await _guardarImportada(db, datos['temporada'] as Map<String, dynamic>);
          _avisar('Partida importada.');
        case 'copia':
          if (!mounted) return;
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('¿Importar la copia completa?'),
              content: const Text('Reemplaza tu perfil y tus ajustes, y suma las partidas de la copia.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('IMPORTAR')),
              ],
            ),
          );
          if (ok != true) return;
          final perfil = PerfilEntrenador.fromJson(datos['perfil'] as Map<String, dynamic>);
          final ajustes = Ajustes.fromJson(datos['ajustes'] as Map<String, dynamic>);
          final temporadas = [for (final t in datos['temporadas'] as List) t as Map<String, dynamic>];
          await db.escribir('perfil', perfil.toJson());
          await db.escribir('ajustes', ajustes.toJson());
          perfilApp.value = perfil;
          ajustesApp.value = ajustes;
          for (final t in temporadas) {
            await _guardarImportada(db, t);
          }
          _avisar('Copia importada: perfil y ${temporadas.length} partidas.');
        default:
          _avisar('Ese archivo no es una partida de Dinastía NBA.', error: true);
          return;
      }
    } catch (e) {
      _avisar('El archivo está dañado o es de otra versión.', error: true);
      return;
    }
    await _recargar();
  }

  /// Guarda una partida importada; si ya existe una con el mismo id, le da uno nuevo.
  Future<void> _guardarImportada(DbLocal db, Map<String, dynamic> json) async {
    final datos = Map<String, dynamic>.of(json);
    final existe = await db.cargarTemporada(datos['id'] as String) != null;
    if (existe) datos['id'] = '${DateTime.now().microsecondsSinceEpoch}';
    await db.guardarTemporada(Temporada.fromJson(datos));
  }

  // ------------------------------------------------------------------ borrar

  Future<void> _borrar(Temporada t) async {
    final f = franquiciaPorId(t.franquiciaUsuarioId);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar la partida?'),
        content: Text('La temporada de los ${f.nombre} se borra para siempre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('BORRAR')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.db?.borrarTemporada(t.id);
    await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final partidas = _partidas;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partidas'),
        actions: [
          if (widget.db != null) ...[
            IconButton(onPressed: _importar, icon: const Icon(Icons.file_open_outlined), tooltip: 'Importar'),
            PopupMenuButton<void>(
              tooltip: 'Más opciones',
              itemBuilder: (_) => [PopupMenuItem(onTap: _exportarCopia, child: const Text('Exportar copia completa'))],
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _sinGuardado
                ? _Vacio(
                    texto:
                        'En este dispositivo no se pueden guardar partidas. Podés jugar igual, pero no se guarda nada.',
                  )
                : partidas == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (_aviso case final aviso?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            aviso,
                            style: tema.textTheme.bodyMedium?.copyWith(
                              color: _avisoError ? esquema.error : esquema.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (partidas.isEmpty)
                        const _Vacio(
                          texto: 'Todavía no tenés partidas guardadas. Elegí una franquicia y dirigila para empezar.',
                        ),
                      for (final t in partidas) ...[
                        _FilaPartida(
                          temporada: t,
                          onTap: () => widget.onContinuar(t),
                          onAccion: widget.db == null
                              ? null
                              : (a) => switch (a) {
                                  _Accion.exportar => _exportar(t),
                                  _Accion.borrar => _borrar(t),
                                },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _FilaPartida extends StatelessWidget {
  const _FilaPartida({required this.temporada, required this.onTap, required this.onAccion});

  final Temporada temporada;
  final VoidCallback onTap;
  final ValueChanged<_Accion>? onAccion;

  static String _fase(Temporada t) {
    if (PartidaAmigos.de(t) case final a?) {
      return switch (a.fase) {
        FaseAmigos.draft => 'Draft por turnos',
        FaseAmigos.tacticas => 'Tácticas',
        FaseAmigos.liga => 'Liga',
        FaseAmigos.serie => 'Serie',
        FaseAmigos.terminada => 'Terminada',
      };
    }
    if (t.modoJuego == ModoJuego.extremo && Variantes.extremoPerdido(t)) return 'Perdida';
    final fase = _faseClasica(t);
    if (t.modoJuego == ModoJuego.dinastia || t.modoJuego == ModoJuego.reescribi) {
      return 'Temporada ${EstadoDinastia.de(t).numero} · $fase';
    }
    return fase;
  }

  static String _faseClasica(Temporada t) => switch (t.fase) {
    FaseTemporada.draft => 'Draft',
    FaseTemporada.tacticas => 'Tácticas',
    FaseTemporada.temporadaRegular => 'Temporada regular',
    FaseTemporada.playoffs => 'Playoffs',
    FaseTemporada.finalizada => 'Terminada',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final t = temporada;
    final f = franquiciaPorId(t.franquiciaUsuarioId);
    final r = t.registroUsuario;
    final campeon = t.campeonId;
    final detalle = [
      if (t.modoJuego != ModoJuego.clasico) t.modoJuego.nombre.toUpperCase(),
      _fase(t),
      if (campeon != null)
        campeon == t.franquiciaUsuarioId ? '¡Campeón!' : 'Campeón: ${franquiciaPorId(campeon).nombre}',
      t.dificultad.nombre,
      t.modo.nombre,
    ].join(' · ');
    return Semantics(
      button: true,
      label: '${f.nombreCompleto}. ${r.victorias} victorias, ${r.derrotas} derrotas. $detalle',
      child: Material(
        color: esquema.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: campeon == t.franquiciaUsuarioId ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Escudo(f, tamano: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.nombreCompleto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detalle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextoLed('${r.victorias}-${r.derrotas}', tamano: 22),
                  if (onAccion case final accion?)
                    PopupMenuButton<_Accion>(
                      tooltip: 'Opciones de la partida',
                      onSelected: accion,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: _Accion.exportar, child: Text('Exportar')),
                        PopupMenuItem(value: _Accion.borrar, child: Text('Borrar')),
                      ],
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
