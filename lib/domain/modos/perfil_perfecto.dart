import 'dart:math';

import '../entities/jugador.dart';
import '../entities/perfil.dart';

/// Perfil perfecto: acertijos de lógica con jugadores de la NBA, inspirados en los puzzles de
/// deducción con pistas (cada nivel es una grilla nueva).
///
/// Cada nivel muestra N perfiles ocultos. Los identifica un dato visible (la franquicia: la
/// categoría ancla) y hay que deducir, con las pistas, el resto de sus datos (puesto, época, media,
/// arquetipo…). Cada valor de una categoría pertenece a un solo perfil. Los niveles salen del
/// catálogo con una semilla (nivel n → siempre el mismo) y un solucionador garantiza que cada uno
/// tenga UNA sola solución.

/// Una categoría de datos (columna de la grilla).
class CategoriaPP {
  const CategoriaPP({
    required this.id,
    required this.nombre,
    required this.claves,
    required this.etiquetas,
    this.ordinal = false,
  });

  final String id;
  final String nombre;

  /// Identificador de cada valor (para el escudo de la franquicia, etc.).
  final List<String> claves;

  /// Texto de cada valor. Si [ordinal], van de menor a mayor.
  final List<String> etiquetas;

  /// Si los valores tienen orden (época, media, tier): habilita pistas de "más que".
  final bool ordinal;

  int get n => etiquetas.length;

  /// "el base", "el de los Spurs", "el de media 91": cómo se nombra a un perfil por este valor.
  String sujeto(int v) {
    final e = etiquetas[v];
    return switch (id) {
      'franquicia' => 'el de los $e',
      'posicion' => 'el ${e.toLowerCase()}',
      'epoca' => 'el de los ${e.toLowerCase()}',
      'media' => 'el de media $e',
      'tier' => 'el de Tier $e',
      'universidad' => 'el que pasó por $e',
      _ => 'el $e',
    };
  }
}

enum TipoPista { igual, distinto, mayor, extremo, oEntre, conferencia }

/// Un valor concreto: categoría y valor dentro de ella.
class RefPP {
  const RefPP(this.cat, this.val);
  final int cat, val;
}

/// Una pista. Según el [tipo], las [refs] son:
/// - igual / distinto: [a, b]
/// - mayor: [a, b] y [cNum] (la categoría ordinal): a tiene un valor más alto que b en cNum
/// - extremo: [a] y [cNum]; [flag] true = el más alto, false = el más bajo
/// - oEntre: [a, b, c]: a es b o c (b y c de una misma categoría)
/// - conferencia: [a]; [flag] true = Este, false = Oeste
class PistaPP {
  const PistaPP(this.tipo, this.refs, {this.cNum = -1, this.flag = false});

  final TipoPista tipo;
  final List<RefPP> refs;
  final int cNum;
  final bool flag;

  /// Mayor categoría que hay que tener asignada para poder evaluarla.
  int get maxCat => [for (final r in refs) r.cat, cNum].reduce(max);
}

/// Un nivel generado.
class NivelPP {
  const NivelPP({
    required this.nivel,
    required this.categorias,
    required this.jugadores,
    required this.pistas,
    required this.solucion,
    required this.esteFila,
    required this.diario,
  });

  /// Número de nivel (o, en el diario, la fecha aaaammdd).
  final int nivel;
  final bool diario;

  /// Categoría 0 = ancla (franquicia): la fila i es el perfil de la franquicia i.
  final List<CategoriaPP> categorias;

  /// Carta real de cada fila (se revela al resolver).
  final List<Jugador> jugadores;

  /// Pistas, en el orden en que se van mostrando.
  final List<PistaPP> pistas;

  /// solucion[cat][valor] = fila (perfil) a la que pertenece.
  final List<List<int>> solucion;

  /// Si la franquicia de cada fila es del Este.
  final List<bool> esteFila;

  int get n => jugadores.length;
  int get incognitas => categorias.length - 1;

  /// Cantidad de casilleros a completar.
  int get casilleros => n * incognitas;

  /// Frase de una pista.
  String texto(PistaPP p) => TextosPP.de(this, p);
}

/// Textos de las pistas.
class TextosPP {
  const TextosPP._();

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _s(NivelPP n, RefPP r) => n.categorias[r.cat].sujeto(r.val);

  static String de(NivelPP n, PistaPP p) {
    final a = _s(n, p.refs.first);
    switch (p.tipo) {
      case TipoPista.igual:
        return '${_cap(a)} es ${_s(n, p.refs[1])}.';
      case TipoPista.distinto:
        return '${_cap(a)} no es ${_s(n, p.refs[1])}.';
      case TipoPista.mayor:
        final b = _s(n, p.refs[1]);
        return switch (n.categorias[p.cNum].id) {
          'media' => '${_cap(a)} tiene más media que $b.',
          'epoca' => '${_cap(a)} jugó después que $b.',
          _ => '${_cap(a)} tiene un tier más alto que $b.',
        };
      case TipoPista.extremo:
        final alto = p.flag;
        return switch (n.categorias[p.cNum].id) {
          'media' => 'El de ${alto ? 'mayor' : 'menor'} media es $a.',
          'epoca' => '${alto ? 'El que jugó más recientemente' : 'El más antiguo'} es $a.',
          _ => 'El de ${alto ? 'mayor' : 'menor'} tier es $a.',
        };
      case TipoPista.oEntre:
        return '${_cap(a)} es ${_s(n, p.refs[1])} o ${_s(n, p.refs[2])}.';
      case TipoPista.conferencia:
        return '${_cap(a)} juega en el ${p.flag ? 'Este' : 'Oeste'}.';
    }
  }
}

/// El solucionador: cuenta las soluciones (hasta [limite]) de un conjunto de pistas.
class SolucionadorPP {
  const SolucionadorPP._();

  static List<List<int>> _perms(int n) {
    final salida = <List<int>>[];
    void rec(List<int> actual, List<bool> usado) {
      if (actual.length == n) {
        salida.add(List.of(actual));
        return;
      }
      for (var i = 0; i < n; i++) {
        if (usado[i]) continue;
        usado[i] = true;
        actual.add(i);
        rec(actual, usado);
        actual.removeLast();
        usado[i] = false;
      }
    }

    rec([], List.filled(n, false));
    return salida;
  }

  static final _cachePerms = <int, List<List<int>>>{};

  /// Evalúa una pista con asignaciones parciales: null si todavía no se puede saber.
  static bool? _evaluar(PistaPP p, List<List<int>> fila, List<List<int>> val, List<bool> esteFila, int n) {
    int fi(RefPP r) => fila[r.cat][r.val];
    switch (p.tipo) {
      case TipoPista.igual:
        final a = fi(p.refs[0]), b = fi(p.refs[1]);
        return a < 0 || b < 0 ? null : a == b;
      case TipoPista.distinto:
        final a = fi(p.refs[0]), b = fi(p.refs[1]);
        return a < 0 || b < 0 ? null : a != b;
      case TipoPista.mayor:
        final a = fi(p.refs[0]), b = fi(p.refs[1]);
        if (a < 0 || b < 0) return null;
        final va = val[p.cNum][a], vb = val[p.cNum][b];
        return va < 0 || vb < 0 ? null : va > vb;
      case TipoPista.extremo:
        final a = fi(p.refs[0]);
        if (a < 0) return null;
        final va = val[p.cNum][a];
        return va < 0 ? null : va == (p.flag ? n - 1 : 0);
      case TipoPista.oEntre:
        final a = fi(p.refs[0]), b = fi(p.refs[1]), c = fi(p.refs[2]);
        return a < 0 || b < 0 || c < 0 ? null : (a == b || a == c);
      case TipoPista.conferencia:
        final a = fi(p.refs[0]);
        return a < 0 ? null : esteFila[a] == p.flag;
    }
  }

  /// Cantidad de soluciones (se corta al llegar a [limite]).
  static int contar({
    required int n,
    required int categorias,
    required List<PistaPP> pistas,
    required List<bool> esteFila,
    int limite = 2,
  }) {
    final perms = _cachePerms.putIfAbsent(n, () => _perms(n));
    final fila = [for (var c = 0; c < categorias; c++) List.filled(n, -1)];
    final val = [for (var c = 0; c < categorias; c++) List.filled(n, -1)];
    for (var v = 0; v < n; v++) {
      fila[0][v] = v;
      val[0][v] = v;
    }
    final porNivel = [for (var c = 0; c < categorias; c++) <PistaPP>[]];
    for (final p in pistas) {
      porNivel[p.maxCat].add(p);
    }
    for (final p in porNivel[0]) {
      if (_evaluar(p, fila, val, esteFila, n) == false) return 0;
    }
    var cuenta = 0;
    void dfs(int c) {
      if (c == categorias) {
        cuenta++;
        return;
      }
      for (final perm in perms) {
        for (var v = 0; v < n; v++) {
          fila[c][v] = perm[v];
          val[c][perm[v]] = v;
        }
        var ok = true;
        for (final p in porNivel[c]) {
          if (_evaluar(p, fila, val, esteFila, n) == false) {
            ok = false;
            break;
          }
        }
        if (ok) dfs(c + 1);
        if (cuenta >= limite) break;
      }
      for (var v = 0; v < n; v++) {
        fila[c][v] = -1;
        val[c][v] = -1;
      }
    }

    dfs(1);
    return cuenta;
  }

  /// ¿La asignación dada cumple todas las pistas? (para pruebas)
  static bool cumple(NivelPP nivel, List<List<int>> fila) {
    final n = nivel.n;
    final val = [
      for (final f in fila)
        () {
          final v = List.filled(n, -1);
          for (var i = 0; i < n; i++) {
            v[f[i]] = i;
          }
          return v;
        }(),
    ];
    return nivel.pistas.every((p) => _evaluar(p, fila, val, nivel.esteFila, n) ?? true);
  }
}

/// Qué lleva cada nivel.
class EspecNivel {
  const EspecNivel(this.n, this.m, this.categorias, this.tipos, this.fama);

  /// Perfiles y categorías incógnita.
  final int n, m;

  /// Categorías posibles (además de la franquicia), en orden de preferencia.
  final List<String> categorias;
  final Set<TipoPista> tipos;

  /// Media mínima de las cartas (más alta = jugadores más conocidos).
  final int fama;
}

int _hash(Object a, [Object b = '', Object c = '']) {
  var h = 0x811c9dc5;
  for (final u in '$a|$b|$c'.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Generador de niveles a partir del catálogo.
class PerfilPerfecto {
  PerfilPerfecto(this.catalogo, {required this.nombres, required this.este}) {
    _pool = [
      for (final j in catalogo)
        if (nombres.containsKey(j.franquiciaId) && j.posiciones.isNotEmpty) j,
    ];
  }

  final List<Jugador> catalogo;

  /// Franquicias válidas: id → nombre corto ("Spurs").
  final Map<String, String> nombres;

  /// id → si es de la conferencia Este.
  final Map<String, bool> este;
  late final List<Jugador> _pool;

  static const niveles = 120;

  static EspecNivel espec(int nivel) {
    const nominales = ['posicion', 'epoca', 'media', 'rol', 'tier', 'universidad'];
    if (nivel <= 10) {
      return EspecNivel(
        3,
        1,
        const ['posicion', 'epoca'],
        const {TipoPista.igual, TipoPista.distinto, TipoPista.extremo},
        86,
      );
    }
    if (nivel <= 30) {
      return EspecNivel(
        3,
        2,
        const ['posicion', 'epoca', 'media'],
        const {TipoPista.igual, TipoPista.distinto, TipoPista.extremo, TipoPista.mayor},
        85,
      );
    }
    if (nivel <= 55) {
      return EspecNivel(
        4,
        2,
        const ['posicion', 'epoca', 'media', 'rol'],
        const {TipoPista.distinto, TipoPista.extremo, TipoPista.mayor, TipoPista.oEntre, TipoPista.igual},
        83,
      );
    }
    if (nivel <= 80) {
      return EspecNivel(4, 3, nominales, const {
        TipoPista.distinto,
        TipoPista.extremo,
        TipoPista.mayor,
        TipoPista.oEntre,
        TipoPista.conferencia,
        TipoPista.igual,
      }, 80);
    }
    if (nivel <= 105) {
      return EspecNivel(5, 3, nominales, const {
        TipoPista.distinto,
        TipoPista.extremo,
        TipoPista.mayor,
        TipoPista.oEntre,
        TipoPista.conferencia,
      }, 78);
    }
    return EspecNivel(5, 4, nominales, const {
      TipoPista.distinto,
      TipoPista.mayor,
      TipoPista.oEntre,
      TipoPista.conferencia,
      TipoPista.extremo,
    }, 76);
  }

  /// Nivel de la campaña (1 a [niveles]; más allá se sigue con la dificultad máxima).
  NivelPP generar(int nivel) => _generar(espec(nivel), Random(_hash('pp', nivel)), nivel, false);

  /// El acertijo del día (aaaammdd): 4 perfiles y 3 categorías, igual para todos ese día.
  NivelPP diario(int fecha) => _generar(
    const EspecNivel(
      4,
      3,
      ['posicion', 'epoca', 'media', 'rol', 'tier'],
      {TipoPista.distinto, TipoPista.extremo, TipoPista.mayor, TipoPista.oEntre, TipoPista.conferencia},
      82,
    ),
    Random(_hash('pp-diario', fecha)),
    fecha,
    true,
  );

  CategoriaPP? _categoria(String id, List<Jugador> js) {
    String nombreCat() => switch (id) {
      'posicion' => 'Puesto',
      'epoca' => 'Época',
      'media' => 'Media',
      'tier' => 'Tier',
      'rol' => 'Arquetipo',
      'universidad' => 'Universidad',
      _ => id,
    };
    // clave (para repetir o no) y etiqueta de cada carta; el orden numérico para las ordinales.
    (String, String, int)? dato(Jugador j) => switch (id) {
      'posicion' => (j.posiciones.first.name, j.posiciones.first.etiqueta, j.posiciones.first.index),
      'epoca' => (j.epoca.name, j.epoca.etiqueta, j.epoca.index),
      'media' => ('${j.media}', '${j.media}', j.media),
      'tier' => (j.tier.name, j.tier.codigo, j.tier.index),
      'rol' => (j.rol.name, j.rol.etiqueta, j.rol.index),
      'universidad' => j.universidad == null ? null : (j.universidad!, j.universidad!, 0),
      _ => null,
    };
    final datos = <(String, String, int)>[];
    for (final j in js) {
      final d = dato(j);
      if (d == null || datos.any((x) => x.$1 == d.$1)) return null;
      datos.add(d);
    }
    final ordinal = const {'epoca', 'media', 'tier'}.contains(id);
    final orden = [...datos]..sort((a, b) => ordinal ? a.$3.compareTo(b.$3) : a.$2.compareTo(b.$2));
    return CategoriaPP(
      id: id,
      nombre: nombreCat(),
      claves: [for (final d in orden) d.$1],
      etiquetas: [for (final d in orden) d.$2],
      ordinal: ordinal,
    );
  }

  /// Valor de la carta [j] en la categoría [c].
  int _valorDe(CategoriaPP c, Jugador j) {
    final clave = switch (c.id) {
      'franquicia' => j.franquiciaId,
      'posicion' => j.posiciones.first.name,
      'epoca' => j.epoca.name,
      'media' => '${j.media}',
      'tier' => j.tier.name,
      'rol' => j.rol.name,
      _ => j.universidad ?? '',
    };
    return c.claves.indexOf(clave);
  }

  NivelPP _generar(EspecNivel e, Random r, int numero, bool diario) {
    final candidatas = [
      for (final j in _pool)
        if (j.media >= e.fama) j,
    ];
    for (var intento = 0; intento < 600; intento++) {
      final elegidas = <Jugador>[];
      final franquicias = <String>{}, personas = <int>{};
      var falla = false;
      for (var i = 0; i < e.n && !falla; i++) {
        Jugador? ok;
        for (var k = 0; k < 80 && ok == null; k++) {
          final j = candidatas[r.nextInt(candidatas.length)];
          if (franquicias.contains(j.franquiciaId) || personas.contains(j.nbaPlayerId)) continue;
          ok = j;
        }
        if (ok == null) {
          falla = true;
          break;
        }
        elegidas.add(ok);
        franquicias.add(ok.franquiciaId);
        personas.add(ok.nbaPlayerId);
      }
      if (falla) continue;
      // La franquicia ancla, en orden aleatorio.
      elegidas.shuffle(r);
      final ancla = CategoriaPP(
        id: 'franquicia',
        nombre: 'Franquicia',
        claves: [for (final j in elegidas) j.franquiciaId],
        etiquetas: [for (final j in elegidas) nombres[j.franquiciaId]!],
      );
      // Categorías incógnita: las primeras de la lista (en orden mezclado) donde todos difieren.
      final orden = [...e.categorias]..shuffle(r);
      final cats = <CategoriaPP>[ancla];
      for (final id in orden) {
        if (cats.length > e.m) break;
        final c = _categoria(id, elegidas);
        if (c != null) cats.add(c);
      }
      if (cats.length <= e.m) continue;
      // Las ordinales dan juego a las pistas de "más que": exigimos una si el nivel las usa.
      if ((e.tipos.contains(TipoPista.mayor) || e.tipos.contains(TipoPista.extremo)) && !cats.any((c) => c.ordinal)) {
        continue;
      }
      // Solución: valor → fila (fila = índice de la franquicia ancla).
      final solucion = List.generate(cats.length, (_) => List<int>.filled(e.n, -1));
      for (var f = 0; f < e.n; f++) {
        for (var ci = 0; ci < cats.length; ci++) {
          solucion[ci][_valorDe(cats[ci], elegidas[f])] = f;
        }
      }
      final esteFila = [for (final j in elegidas) este[j.franquiciaId] ?? false];
      final pistas = _pistas(e, cats, solucion, esteFila, r);
      if (pistas != null) {
        return NivelPP(
          nivel: numero,
          categorias: cats,
          jugadores: elegidas,
          pistas: pistas,
          solucion: solucion,
          esteFila: esteFila,
          diario: diario,
        );
      }
    }
    throw StateError('No se pudo generar el nivel $numero');
  }

  /// Todas las pistas verdaderas posibles según el nivel.
  List<PistaPP> _candidatas(EspecNivel e, List<CategoriaPP> cats, List<List<int>> sol, List<bool> esteFila, Random r) {
    final n = e.n;
    final salida = <(double, PistaPP)>[];
    final todos = [
      for (var c = 0; c < cats.length; c++)
        for (var v = 0; v < n; v++) RefPP(c, v),
    ];
    int fila(RefPP x) => sol[x.cat][x.val];
    int valEn(int cNum, int row) => sol[cNum].indexOf(row);
    // Probabilidad relativa de salir primero: las "igual" revelan demasiado, se usan poco.
    double peso(TipoPista t) => switch (t) {
      TipoPista.igual => 0.12,
      TipoPista.distinto => 1.0,
      TipoPista.mayor => 1.3,
      TipoPista.extremo => 1.0,
      TipoPista.oEntre => 1.1,
      TipoPista.conferencia => 0.8,
    };
    void agregar(PistaPP p) => salida.add((pow(r.nextDouble(), 1 / peso(p.tipo)).toDouble(), p));
    for (final a in todos) {
      for (final b in todos) {
        if (a.cat >= b.cat) continue;
        if (fila(a) == fila(b)) {
          if (e.tipos.contains(TipoPista.igual)) agregar(PistaPP(TipoPista.igual, [a, b]));
        } else if (e.tipos.contains(TipoPista.distinto)) {
          agregar(PistaPP(TipoPista.distinto, [a, b]));
        }
      }
    }
    for (var cn = 1; cn < cats.length; cn++) {
      if (!cats[cn].ordinal) continue;
      for (final a in todos) {
        if (a.cat == cn) continue;
        if (e.tipos.contains(TipoPista.extremo)) {
          final v = valEn(cn, fila(a));
          if (v == n - 1) agregar(PistaPP(TipoPista.extremo, [a], cNum: cn, flag: true));
          if (v == 0) agregar(PistaPP(TipoPista.extremo, [a], cNum: cn, flag: false));
        }
        if (!e.tipos.contains(TipoPista.mayor)) continue;
        for (final b in todos) {
          if (b.cat == cn || fila(a) == fila(b) || a.cat == b.cat) continue;
          if (valEn(cn, fila(a)) > valEn(cn, fila(b))) agregar(PistaPP(TipoPista.mayor, [a, b], cNum: cn));
        }
      }
    }
    if (e.tipos.contains(TipoPista.oEntre)) {
      for (final a in todos) {
        for (var c2 = 1; c2 < cats.length; c2++) {
          if (c2 == a.cat) continue;
          final verdadero = valEn(c2, fila(a));
          for (var v = 0; v < n; v++) {
            if (v == verdadero) continue;
            final dos = r.nextBool() ? [RefPP(c2, verdadero), RefPP(c2, v)] : [RefPP(c2, v), RefPP(c2, verdadero)];
            agregar(PistaPP(TipoPista.oEntre, [a, ...dos]));
          }
        }
      }
    }
    if (e.tipos.contains(TipoPista.conferencia)) {
      for (final a in todos) {
        if (a.cat == 0) continue;
        agregar(PistaPP(TipoPista.conferencia, [a], flag: esteFila[fila(a)]));
      }
    }
    salida.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final x in salida) x.$2];
  }

  /// Elige pistas hasta que haya una sola solución y después saca las que sobran.
  List<PistaPP>? _pistas(EspecNivel e, List<CategoriaPP> cats, List<List<int>> sol, List<bool> esteFila, Random r) {
    final candidatas = _candidatas(e, cats, sol, esteFila, r);
    int soluciones(List<PistaPP> ps) =>
        SolucionadorPP.contar(n: e.n, categorias: cats.length, pistas: ps, esteFila: esteFila);
    final elegidas = <PistaPP>[];
    var unica = false;
    for (final c in candidatas) {
      elegidas.add(c);
      // Antes de tener varias pistas no vale la pena revisar (siempre habrá muchas soluciones).
      if (elegidas.length < cats.length * 2) continue;
      if (soluciones(elegidas) == 1) {
        unica = true;
        break;
      }
      if (elegidas.length > 44) return null;
    }
    if (!unica) return null;
    // Sacar las que sobran (en orden aleatorio, con un tope para que generar no tarde).
    final orden = [...elegidas]..shuffle(r);
    final reloj = Stopwatch()..start();
    for (final p in orden) {
      if (elegidas.length <= 3 || reloj.elapsedMilliseconds > 600) break;
      final sin = [...elegidas]..remove(p);
      if (soluciones(sin) == 1) elegidas.remove(p);
    }
    // Más fáciles primero: las que nombran más cosas distintas van después.
    elegidas.sort((a, b) => a.maxCat.compareTo(b.maxCat));
    return elegidas;
  }
}

/// Progreso del jugador: estrellas por nivel y por día, guardado en `PerfilEntrenador.perfilPerfecto`.
class ProgresoPP {
  const ProgresoPP._();

  static const vidas = 3;
  static const pistasPorNivel = 2;

  static Map<String, int> _mapa(PerfilEntrenador p, String clave) =>
      ((p.perfilPerfecto[clave] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as int));

  static int estrellas(PerfilEntrenador p, int nivel) => _mapa(p, 'n')['$nivel'] ?? 0;
  static int resueltos(PerfilEntrenador p) => _mapa(p, 'n').length;
  static int estrellasTotales(PerfilEntrenador p) => _mapa(p, 'n').values.fold(0, (a, b) => a + b);

  /// Hasta qué nivel se puede jugar (el siguiente al último resuelto en orden).
  static int desbloqueado(PerfilEntrenador p) {
    final m = _mapa(p, 'n');
    var n = 1;
    while (m.containsKey('$n')) {
      n++;
    }
    return n;
  }

  static int estrellasDiario(PerfilEntrenador p, int fecha) => _mapa(p, 'd')['$fecha'] ?? 0;

  /// Estrellas según los errores y las pistas usadas: 3 sin ninguno; 2 con uno solo; 1 si no.
  static int calcularEstrellas({required int errores, required int pistas}) {
    final malos = errores + pistas;
    return malos == 0 ? 3 : (malos == 1 ? 2 : 1);
  }

  /// Registra un nivel resuelto. Premia solo la primera vez que se resuelve (y las estrellas
  /// nuevas no dan monedas de nuevo). Devuelve el perfil y un texto para mostrar (o null).
  static (PerfilEntrenador, String?) registrar(
    PerfilEntrenador p, {
    required int clave,
    required int estrellas,
    bool diario = false,
  }) {
    final campo = diario ? 'd' : 'n';
    final mapa = _mapa(p, campo);
    final previas = mapa['$clave'] ?? 0;
    final nuevo = {...mapa, '$clave': max(previas, estrellas)};
    final todo = {...p.perfilPerfecto, campo: nuevo};
    var perfil = p.copyWith(perfilPerfecto: todo);
    String? texto;
    if (previas == 0) {
      final monedas = (diario ? 12 : 4) + 2 * estrellas;
      final xp = (diario ? 40 : 10) + 4 * estrellas;
      perfil = perfil.copyWith(xp: perfil.xp + xp, monedas: perfil.monedas + monedas);
      texto = '+$xp XP · +$monedas monedas';
    }
    final hechos = _mapa(perfil, 'n').length;
    final logros = {...perfil.logros};
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (hechos >= 25 && !logros.containsKey(Logro.detective)) logros[Logro.detective] = ahora;
    if (hechos >= 100 && !logros.containsKey(Logro.maestroDetective)) logros[Logro.maestroDetective] = ahora;
    if (logros.length != perfil.logros.length) perfil = perfil.copyWith(logros: logros);
    return (perfil, texto);
  }
}
