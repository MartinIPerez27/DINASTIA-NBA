import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/modos/perfil_perfecto.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/haptica.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Abre el menú de Perfil perfecto (no necesita una partida guardada).
Future<void> iniciarPerfilPerfecto(ContextoModos c) async {
  final liga = await c.liga();
  final generador = generadorPP(liga.catalogo);
  c.navegador.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => PerfilPerfectoMenu(
        generador: generador,
        onPerfil: (p) {
          perfilApp.value = p;
          c.db?.escribir('perfil', p.toJson()).ignore();
        },
      ),
    ),
  );
}

/// El generador de niveles con las 30 franquicias actuales.
PerfilPerfecto generadorPP(List<Jugador> catalogo) => PerfilPerfecto(
  catalogo,
  nombres: {
    for (final f in franquicias)
      if (!f.historica) f.id: f.nombre,
  },
  este: {
    for (final f in franquicias)
      if (!f.historica) f.id: f.conferencia == Conferencia.este,
  },
);

/// Fecha de hoy como aaaammdd.
int fechaHoy([DateTime? ahora]) {
  final d = ahora ?? DateTime.now();
  return d.year * 10000 + d.month * 100 + d.day;
}

// ───────────────────────────────────────────── Menú ─────────────────────────────────────────────

class PerfilPerfectoMenu extends StatelessWidget {
  const PerfilPerfectoMenu({super.key, required this.generador, required this.onPerfil, this.fecha});

  final PerfilPerfecto generador;
  final ValueChanged<PerfilEntrenador> onPerfil;

  /// Para pruebas.
  final int? fecha;

  Future<void> _abrir(BuildContext context, int nivel, {bool diario = false}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PerfilPerfectoNivel(generador: generador, nivel: nivel, diario: diario, onPerfil: onPerfil),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil perfecto')),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: perfilApp,
          builder: (context, perfil, _) {
            final hoy = fecha ?? fechaHoy();
            final libre = ProgresoPP.desbloqueado(perfil);
            final estrellasHoy = ProgresoPP.estrellasDiario(perfil, hoy);
            return AnchoMaximo(
              ancho: 900,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'Deducí quién es cada perfil. Te mostramos la franquicia; con las pistas descubrís el resto de sus datos. '
                    'Cada valor es de un solo jugador. Tenés ${ProgresoPP.vidas} vidas y ${ProgresoPP.pistasPorNivel} ayudas por nivel.',
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextoLed('${ProgresoPP.resueltos(perfil)}', tamano: 28),
                      Text(' / ${PerfilPerfecto.niveles} niveles', style: tema.textTheme.bodyMedium),
                      const Spacer(),
                      const Icon(Icons.star, size: 18),
                      const SizedBox(width: 4),
                      TextoLed('${ProgresoPP.estrellasTotales(perfil)}', tamano: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: esquema.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: esquema.primary),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.today, color: esquema.primary),
                      title: const Text('ACERTIJO DEL DÍA'),
                      subtitle: Text(
                        estrellasHoy > 0
                            ? 'Resuelto hoy ($estrellasHoy de 3 estrellas). Mañana, otro.'
                            : 'Igual para todos hoy: 4 perfiles, 3 categorías. Da más monedas.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(context, hoy, diario: true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('NIVELES', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 76,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: PerfilPerfecto.niveles,
                    itemBuilder: (context, i) {
                      final nivel = i + 1;
                      final estrellas = ProgresoPP.estrellas(perfil, nivel);
                      final abierto = nivel <= libre;
                      return Material(
                        color: esquema.surfaceContainerLowest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: nivel == libre ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
                            width: nivel == libre ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: abierto ? () => _abrir(context, nivel) : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              abierto
                                  ? TextoLed('$nivel', tamano: 20)
                                  : Icon(Icons.lock_outline, color: esquema.outline, size: 20),
                              const SizedBox(height: 4),
                              if (estrellas == 0)
                                Text('···', style: tema.textTheme.labelSmall)
                              else
                                _Estrellas(estrellas, tamano: 11),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────── Nivel ─────────────────────────────────────────────

/// Los niveles generados quedan en memoria (generar los grandes tarda un poco).
final _cacheNiveles = <String, NivelPP>{};

class PerfilPerfectoNivel extends StatefulWidget {
  const PerfilPerfectoNivel({
    super.key,
    required this.generador,
    required this.nivel,
    required this.onPerfil,
    this.diario = false,
  });

  final PerfilPerfecto generador;
  final int nivel;
  final bool diario;
  final ValueChanged<PerfilEntrenador> onPerfil;

  @override
  State<PerfilPerfectoNivel> createState() => _NivelState();
}

class _NivelState extends State<PerfilPerfectoNivel> {
  NivelPP? _nivel;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final clave = '${widget.diario ? 'd' : 'n'}${widget.nivel}';
    var n = _cacheNiveles[clave];
    if (n == null) {
      // Un frame para mostrar el "Armando el acertijo…" antes de calcular.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      n = widget.diario ? widget.generador.diario(widget.nivel) : widget.generador.generar(widget.nivel);
      _cacheNiveles[clave] = n;
    }
    if (mounted) setState(() => _nivel = n);
  }

  @override
  Widget build(BuildContext context) {
    final n = _nivel;
    if (n == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.diario ? 'Acertijo del día' : 'Nivel ${widget.nivel}')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Armando el acertijo…')],
          ),
        ),
      );
    }
    return _Juego(
      nivel: n,
      onPerfil: widget.onPerfil,
      onSiguiente: widget.diario || widget.nivel >= PerfilPerfecto.niveles
          ? null
          : () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => PerfilPerfectoNivel(
                  generador: widget.generador,
                  nivel: widget.nivel + 1,
                  onPerfil: widget.onPerfil,
                ),
              ),
            ),
    );
  }
}

class _Juego extends StatefulWidget {
  const _Juego({required this.nivel, required this.onPerfil, this.onSiguiente});

  final NivelPP nivel;
  final ValueChanged<PerfilEntrenador> onPerfil;
  final VoidCallback? onSiguiente;

  @override
  State<_Juego> createState() => _JuegoState();
}

class _JuegoState extends State<_Juego> {
  /// asig[cat][fila] = valor elegido (o -1).
  late List<List<int>> _asig = _vacia();
  final _fijas = <(int, int)>{}; // casilleros revelados por ayuda: (cat, fila)
  var _vidas = ProgresoPP.vidas;
  var _ayudas = 0;
  var _errores = 0;
  late var _pistas = min(3, widget.nivel.pistas.length);
  var _resuelto = false;
  String? _recompensa;
  int _estrellas = 0;
  String? _mensaje;

  NivelPP get _n => widget.nivel;

  List<List<int>> _vacia() => [for (var c = 0; c < _n.categorias.length; c++) List.filled(_n.n, -1)];

  /// Valor correcto de la fila [f] en la categoría [c].
  int _correcto(int c, int f) => _n.solucion[c].indexOf(f);

  void _poner(int c, int f, int v) {
    if (_resuelto || _fijas.contains((c, f))) return;
    setState(() {
      // Si ese valor estaba en otra fila, se mueve.
      for (var r = 0; r < _n.n; r++) {
        if (_asig[c][r] == v && !_fijas.contains((c, r))) _asig[c][r] = -1;
      }
      _asig[c][f] = v;
      _mensaje = null;
    });
  }

  bool get _completa {
    for (var c = 1; c < _n.categorias.length; c++) {
      if (_asig[c].any((v) => v < 0)) return false;
    }
    return true;
  }

  Future<void> _verificar() async {
    var bien = 0;
    for (var c = 1; c < _n.categorias.length; c++) {
      for (var f = 0; f < _n.n; f++) {
        if (_asig[c][f] == _correcto(c, f)) bien++;
      }
    }
    if (bien == _n.casilleros) {
      Haptica.media();
      final estrellas = ProgresoPP.calcularEstrellas(errores: _errores, pistas: _ayudas);
      final fecha = _n.diario ? _n.nivel : _n.nivel;
      final (perfil, texto) = ProgresoPP.registrar(
        perfilApp.value,
        clave: fecha,
        estrellas: estrellas,
        diario: _n.diario,
      );
      widget.onPerfil(perfil);
      setState(() {
        _resuelto = true;
        _estrellas = estrellas;
        _recompensa = texto;
      });
      return;
    }
    Haptica.fuerte();
    setState(() {
      _vidas--;
      _errores++;
      _mensaje = _vidas > 0
          ? 'Acertaste $bien de ${_n.casilleros} casilleros. Te quedan $_vidas vida${_vidas == 1 ? '' : 's'}.'
          : 'Te quedaste sin vidas. Probá de nuevo.';
    });
  }

  void _reiniciar() => setState(() {
    _asig = _vacia();
    _fijas.clear();
    _vidas = ProgresoPP.vidas;
    _ayudas = 0;
    _errores = 0;
    _pistas = min(3, _n.pistas.length);
    _mensaje = null;
  });

  /// Ayuda: revela un casillero que todavía no está bien.
  void _ayuda() {
    if (_ayudas >= ProgresoPP.pistasPorNivel || _resuelto || _vidas == 0) return;
    final malos = <(int, int)>[
      for (var c = 1; c < _n.categorias.length; c++)
        for (var f = 0; f < _n.n; f++)
          if (_asig[c][f] != _correcto(c, f)) (c, f),
    ];
    if (malos.isEmpty) return;
    final (c, f) = malos[Random(_n.nivel * 31 + _ayudas * 7 + malos.length).nextInt(malos.length)];
    final v = _correcto(c, f);
    setState(() {
      for (var r = 0; r < _n.n; r++) {
        if (_asig[c][r] == v) _asig[c][r] = -1;
      }
      _asig[c][f] = v;
      _fijas.add((c, f));
      _ayudas++;
      _mensaje = null;
    });
  }

  Future<void> _elegir(int c, int f) async {
    if (_resuelto || _vidas == 0 || _fijas.contains((c, f))) return;
    final cat = _n.categorias[c];
    final v = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ElegirValor(categoria: cat, asignados: _asig[c], fila: f, letras: _letras),
    );
    if (v != null) _poner(c, f, v);
  }

  static const _letras = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tablero = _Tablero(nivel: _n, asig: _asig, fijas: _fijas, resuelto: _resuelto, onElegir: _elegir);
    final panel = _Panel(
      nivel: _n,
      pistas: _pistas,
      vidas: _vidas,
      ayudasUsadas: _ayudas,
      mensaje: _mensaje,
      resuelto: _resuelto,
      estrellas: _estrellas,
      recompensa: _recompensa,
      completa: _completa,
      onMasPistas: () => setState(() => _pistas = min(_n.pistas.length, _pistas + 1)),
      onVerificar: _verificar,
      onAyuda: _ayuda,
      onReiniciar: _reiniciar,
      onSiguiente: widget.onSiguiente,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_n.diario ? 'Acertijo del día' : 'Nivel ${_n.nivel}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                for (var i = 0; i < ProgresoPP.vidas; i++)
                  Icon(i < _vidas ? Icons.favorite : Icons.favorite_border, size: 20, color: esquema.primary),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? DosPaneles(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                flexIzquierda: 6,
                flexDerecha: 5,
                izquierda: tablero,
                derecha: panel,
              )
            : Column(
                children: [
                  Expanded(flex: 5, child: tablero),
                  Expanded(flex: 5, child: panel),
                ],
              ),
      ),
    );
  }
}

// ───────────────────────────────────────── Tablero ─────────────────────────────────────────

class _Tablero extends StatelessWidget {
  const _Tablero({
    required this.nivel,
    required this.asig,
    required this.fijas,
    required this.resuelto,
    required this.onElegir,
  });

  final NivelPP nivel;
  final List<List<int>> asig;
  final Set<(int, int)> fijas;
  final bool resuelto;
  final void Function(int cat, int fila) onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        for (var f = 0; f < nivel.n; f++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: resuelto ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Column(
                    children: [
                      Escudo(franquiciaPorId(nivel.categorias[0].claves[f]), tamano: 34),
                      const SizedBox(height: 2),
                      Text(
                        nivel.categorias[0].etiquetas[f],
                        style: tema.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: resuelto
                      ? _Revelada(carta: nivel.jugadores[f])
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var c = 1; c < nivel.categorias.length; c++)
                              _Casillero(
                                categoria: nivel.categorias[c],
                                valor: asig[c][f],
                                fijo: fijas.contains((c, f)),
                                onTap: () => onElegir(c, f),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Casillero extends StatelessWidget {
  const _Casillero({required this.categoria, required this.valor, required this.fijo, required this.onTap});

  final CategoriaPP categoria;
  final int valor;
  final bool fijo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final lleno = valor >= 0;
    return Material(
      color: lleno ? esquema.primary.withValues(alpha: 0.14) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: lleno ? esquema.primary : esquema.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 84, minHeight: 44, maxWidth: 170),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoria.nombre.toUpperCase(),
                      style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant, fontSize: 9),
                    ),
                    if (fijo) Icon(Icons.lock, size: 10, color: esquema.onSurfaceVariant),
                  ],
                ),
                Text(
                  lleno ? categoria.etiquetas[valor] : '?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Revelada extends StatelessWidget {
  const _Revelada({required this.carta});
  final Jugador carta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        TextoLed('${carta.media}', tamano: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(carta.nombre, style: tema.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${carta.tramoConEquipo} · ${carta.rol.etiqueta}',
                style: tema.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ElegirValor extends StatelessWidget {
  const _ElegirValor({required this.categoria, required this.asignados, required this.fila, required this.letras});

  final CategoriaPP categoria;
  final List<int> asignados;
  final int fila;
  final List<String> letras;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(categoria.nombre.toUpperCase(), style: tema.textTheme.titleLarge),
          if (categoria.ordinal)
            Text('De menor a mayor.', style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (var v = 0; v < categoria.n; v++)
            Builder(
              builder: (context) {
                final en = asignados.indexOf(v);
                final enOtro = en >= 0 && en != fila;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(categoria.etiquetas[v]),
                  subtitle: enOtro ? Text('Lo tiene el perfil de la fila ${en + 1} (se mueve acá)') : null,
                  trailing: en == fila ? Icon(Icons.check, color: esquema.primary) : null,
                  onTap: () => Navigator.pop(context, v),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────── Panel ───────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.nivel,
    required this.pistas,
    required this.vidas,
    required this.ayudasUsadas,
    required this.mensaje,
    required this.resuelto,
    required this.estrellas,
    required this.recompensa,
    required this.completa,
    required this.onMasPistas,
    required this.onVerificar,
    required this.onAyuda,
    required this.onReiniciar,
    required this.onSiguiente,
  });

  final NivelPP nivel;
  final int pistas, vidas, ayudasUsadas, estrellas;
  final String? mensaje, recompensa;
  final bool resuelto, completa;
  final VoidCallback onMasPistas, onVerificar, onAyuda, onReiniciar;
  final VoidCallback? onSiguiente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final sinVidas = vidas == 0;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: [
              if (resuelto)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: esquema.primary, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('¡RESUELTO!', style: tema.textTheme.titleLarge),
                          const SizedBox(width: 10),
                          _Estrellas(estrellas, tamano: 22),
                        ],
                      ),
                      if (recompensa != null) Text(recompensa!, style: tema.textTheme.bodyMedium),
                      Text(
                        'Mirá quiénes eran los perfiles.',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              Text('PISTAS ($pistas/${nivel.pistas.length})', style: tema.textTheme.labelLarge),
              const SizedBox(height: 4),
              for (var i = 0; i < pistas; i++)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: esquema.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == pistas - 1 && !resuelto
                          ? esquema.primary
                          : esquema.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 24, child: Text('${i + 1}', style: tema.textTheme.labelLarge)),
                      Expanded(child: Text(nivel.texto(nivel.pistas[i]))),
                    ],
                  ),
                ),
              if (mensaje != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(mensaje!, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.error)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            children: [
              if (resuelto)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('MENÚ')),
                    ),
                    if (onSiguiente != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton(onPressed: onSiguiente, child: const Text('SIGUIENTE NIVEL')),
                      ),
                    ],
                  ],
                )
              else if (sinVidas)
                FilledButton(onPressed: onReiniciar, child: const Text('VOLVER A INTENTAR'))
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: pistas < nivel.pistas.length ? onMasPistas : null,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                        child: const FittedBox(fit: BoxFit.scaleDown, child: Text('OTRA PISTA')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ayudasUsadas < ProgresoPP.pistasPorNivel ? onAyuda : null,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('AYUDA ${ProgresoPP.pistasPorNivel - ayudasUsadas}'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(onPressed: completa ? onVerificar : null, child: const Text('VERIFICAR')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Estrellas como íconos (el carácter ★ no está en todas las tipografías).
class _Estrellas extends StatelessWidget {
  const _Estrellas(this.n, {this.tamano = 12});

  final int n;
  final double tamano;
  static const total = 3;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Icon(i < n ? Icons.star : Icons.star_border, size: tamano, color: i < n ? c : c.withValues(alpha: 0.35)),
      ],
    );
  }
}
