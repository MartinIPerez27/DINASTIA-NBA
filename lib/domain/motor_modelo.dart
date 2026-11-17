import 'entities/jugador.dart';
import 'entities/rol_cancha.dart';

/// Tablas del motor v2 (ronda 2): normalización por época y efectos pasivos por arquetipo.
///
/// POR QUÉ EXISTE: las estadísticas de cada carta son las crudas de su época (en los 60 se tiraba
/// 41 % y casi nadie perdía menos de 2,7 pelotas cada 36 minutos; hoy se tira 47 % y se pierden 1,9).
/// La `media` de la carta ya está ajustada por época, así que el motor NO puede usar el valor crudo
/// como si fuera comparable entre épocas: usa cuánto se aparta la carta del promedio de SU época
/// (más la media, que es lo que decide). Así, a igual media, un plantel de los 60 y uno de los 2000
/// quedan parejos, y lo que distingue a cada época es su ESTILO (volumen de triples, pintura, rebote).
class EraStats {
  const EraStats({
    required this.tc,
    required this.t3,
    required this.tl,
    required this.per36,
    required this.per36Pend,
    required this.rob36,
    required this.rob36Pend,
    required this.rpp,
    required this.rppPend,
    required this.volumenT3,
  });

  /// Promedios del catálogo de las cartas de media ≥ 70 de la época (los titulares reales):
  /// %TC, %T3 (de quienes tiran de tres) y %TL.
  final double tc, t3, tl;

  /// Pérdidas y robos cada 36 minutos y rebotes por partido que se esperan de una carta de media 80 de
  /// la época, y cuánto sube cada uno por punto de media (regresión sobre el catálogo). Importa porque
  /// las estrellas de hoy pierden MÁS pelotas que el promedio de su época (mucho uso) y las de los 60
  /// no: comparar contra el promedio plano de la época castigaba a los planteles modernos.
  final double per36, per36Pend, rob36, rob36Pend, rpp, rppPend;

  /// Cuánto se tira de tres en la época respecto de la NBA actual (1 = hoy). Las cartas anteriores a
  /// 1980 no tienen %T3 (la línea no existía) y no tiran de tres.
  final double volumenT3;

  double per36Esp(int media) => per36 + per36Pend * (media - 80);
  double rob36Esp(int media) => rob36 + rob36Pend * (media - 80);
  double rppEsp(int media) => rpp + rppPend * (media - 80);
}

/// Una entrada por época. Los promedios salen de `assets/database/nba_players.json`; el volumen de
/// triples sigue la historia: 80s tímidos, 90s y 2000 de a poco, 2010 y 2020 como la NBA moderna.
const estadisticasEpoca = <Epoca, EraStats>{
  Epoca.anios40: EraStats(tc: .336, t3: .30, tl: .699, per36: 2.784, per36Pend: -.0005, rob36: 1.149, rob36Pend: -.0153, rpp: 9.29, rppPend: .381, volumenT3: 0),
  Epoca.anios50: EraStats(tc: .366, t3: .30, tl: .724, per36: 2.800, per36Pend: .0017, rob36: 1.313, rob36Pend: -.009, rpp: 6.90, rppPend: .364, volumenT3: 0),
  Epoca.anios60: EraStats(tc: .430, t3: .30, tl: .717, per36: 2.769, per36Pend: .0086, rob36: 1.328, rob36Pend: .0013, rpp: 7.34, rppPend: .420, volumenT3: 0),
  Epoca.anios70: EraStats(tc: .462, t3: .30, tl: .743, per36: 2.812, per36Pend: .0143, rob36: 1.367, rob36Pend: .0141, rpp: 5.86, rppPend: .298, volumenT3: 0),
  Epoca.anios80: EraStats(tc: .478, t3: .262, tl: .753, per36: 2.624, per36Pend: .0239, rob36: 1.381, rob36Pend: .0228, rpp: 4.83, rppPend: .233, volumenT3: .5),
  Epoca.anios90: EraStats(tc: .459, t3: .311, tl: .741, per36: 2.272, per36Pend: .0252, rob36: 1.327, rob36Pend: .0222, rpp: 4.78, rppPend: .215, volumenT3: .72),
  Epoca.anios2000: EraStats(tc: .447, t3: .334, tl: .750, per36: 2.079, per36Pend: .0229, rob36: 1.191, rob36Pend: .0150, rpp: 4.86, rppPend: .218, volumenT3: .86),
  Epoca.anios2010: EraStats(tc: .456, t3: .339, tl: .751, per36: 2.072, per36Pend: .0396, rob36: 1.177, rob36Pend: .0200, rpp: 4.79, rppPend: .232, volumenT3: 1),
  Epoca.actualidad: EraStats(tc: .472, t3: .351, tl: .766, per36: 2.023, per36Pend: .0464, rob36: 1.201, rob36Pend: .0147, rpp: 4.82, rppPend: .241, volumenT3: 1.06),
};

/// Referencia moderna (2020s) con la que se comparan todas las épocas.
const _modernaRpp = 4.82, _modernaRppPend = .241;
double reboteNormalizado(Jugador j) {
  final e = eraDe(j);
  final esperado = e.rppEsp(j.media).clamp(1.0, 20.0);
  final moderno = (_modernaRpp + _modernaRppPend * (j.media - 80)).clamp(1.0, 20.0);
  return j.stats.rpp * (moderno / esperado);
}

EraStats eraDe(Jugador j) => estadisticasEpoca[j.epoca]!;

/// Efecto pasivo de un arquetipo ([RolCancha]) en el motor. Chicos y transparentes (±1–2 puntos
/// porcentuales o ±10–20 % de una frecuencia); 0 / 1 = sin efecto. Se aplican solo mientras el
/// jugador está en cancha. La UI puede mostrarlos con [descripcion].
class EfectoRol {
  const EfectoRol({
    this.tripleExtra = 0,
    this.dosExtra = 0,
    this.defensaDirecta = 0,
    this.defensaTriple = 0,
    this.proteccionAro = 0,
    this.asistido = 0,
    this.volumenTriples = 1,
    this.faltasRecibidas = 1,
    this.reboteOfensivo = 1,
    this.fatiga = 1,
    this.contraataque = 1,
    this.clutch = 0,
    this.descripcion = '',
  });

  /// + al acierto del propio jugador en triples / dobles.
  final double tripleExtra, dosExtra;

  /// Como defensor DIRECTO: − al acierto de su par (en general / en triples).
  final double defensaDirecta, defensaTriple;

  /// En cancha: − al acierto en dobles del rival (protector del aro).
  final double proteccionAro;

  /// + al acierto de los compañeros en los tiros que él asiste (el organizador).
  final double asistido;

  /// Multiplicadores de frecuencias del propio jugador.
  final double volumenTriples, faltasRecibidas, reboteOfensivo, fatiga;

  /// Multiplica la chance de contraataque del equipo mientras él está en cancha.
  final double contraataque;

  /// + al acierto en el clutch (puntos porcentuales).
  final double clutch;

  final String descripcion;
}

/// Todos los arquetipos, con su efecto. Sin entrada = neutro (no hay ninguno sin entrada hoy).
const efectosRol = <RolCancha, EfectoRol>{
  RolCancha.organizadorPuro: EfectoRol(asistido: .012, descripcion: 'Organizador: sus pases valen +1,2 pt de acierto.'),
  RolCancha.anotadorExterior: EfectoRol(tripleExtra: .008, volumenTriples: 1.1, descripcion: 'Anotador exterior: +0,8 pt en triples.'),
  RolCancha.penetradorAtletico: EfectoRol(faltasRecibidas: 1.15, contraataque: 1.08, descripcion: 'Penetrador: sufre más faltas y corre la cancha.'),
  RolCancha.baseDefensivo: EfectoRol(defensaDirecta: .014, descripcion: 'Perro de presa: su par acierta 1,4 pt menos.'),
  RolCancha.superestrellaAclarados: EfectoRol(clutch: .012, dosExtra: .006, descripcion: 'Aclarados: +1,2 pt en el clutch.'),
  RolCancha.tiradorPantallas: EfectoRol(tripleExtra: .012, volumenTriples: 1.12, descripcion: 'Tirador: +1,2 pt en triples.'),
  RolCancha.escoltaGenerador: EfectoRol(asistido: .006, tripleExtra: .004, descripcion: 'Generador: crea y tira.'),
  RolCancha.especialista3D: EfectoRol(defensaDirecta: .008, defensaTriple: .01, tripleExtra: .005, descripcion: '3&D: cierra el triple de su par.'),
  RolCancha.controladorTotal: EfectoRol(asistido: .008, contraataque: 1.05, descripcion: 'Point forward: reparte y lanza el contraataque.'),
  RolCancha.anotadorTresNiveles: EfectoRol(tripleExtra: .004, dosExtra: .004, clutch: .006, descripcion: 'Tres niveles: anota desde todos lados.'),
  RolCancha.cerrojoDefensivo: EfectoRol(defensaDirecta: .014, defensaTriple: .004, descripcion: 'Cerrojo: su par acierta 1,4 pt menos.'),
  RolCancha.aleroCortador: EfectoRol(dosExtra: .008, contraataque: 1.1, faltasRecibidas: 1.08, descripcion: 'Cortador: bandejas fáciles y transición.'),
  RolCancha.maestroPoste: EfectoRol(dosExtra: .012, faltasRecibidas: 1.1, volumenTriples: .6, descripcion: 'Poste: +1,2 pt cerca del aro y más libres.'),
  RolCancha.alaPivotTirador: EfectoRol(tripleExtra: .01, volumenTriples: 1.5, descripcion: 'Stretch four: abre la cancha.'),
  RolCancha.fuerzaBruta: EfectoRol(reboteOfensivo: 1.2, dosExtra: .004, volumenTriples: .6, descripcion: 'Fuerza bruta: más rebotes ofensivos.'),
  RolCancha.distribuidorInterior: EfectoRol(asistido: .008, descripcion: 'Distribuidor interior: pases desde el poste.'),
  RolCancha.goliatPintura: EfectoRol(dosExtra: .008, proteccionAro: .008, volumenTriples: .5, descripcion: 'Goliat: domina la pintura.'),
  RolCancha.juegoDePies: EfectoRol(dosExtra: .012, volumenTriples: .6, descripcion: 'Juego de pies: +1,2 pt cerca del aro.'),
  RolCancha.protectorAro: EfectoRol(proteccionAro: .016, reboteOfensivo: 1.05, volumenTriples: .5, descripcion: 'Protector del aro: el rival acierta 1,6 pt menos de dobles.'),
  RolCancha.pivotOrganizador: EfectoRol(asistido: .008, dosExtra: .004, descripcion: 'Point center: el juego pasa por él.'),
  RolCancha.pivotTirador: EfectoRol(tripleExtra: .01, volumenTriples: 2.2, descripcion: 'Stretch five: abre la cancha.'),
  RolCancha.microondas: EfectoRol(tripleExtra: .006, dosExtra: .006, fatiga: 1.1, descripcion: 'Microondas: anota rápido desde el banco.'),
  RolCancha.directorSegundaUnidad: EfectoRol(asistido: .008, descripcion: 'Director de segunda unidad: ordena al banco.'),
  RolCancha.inyeccionEnergia: EfectoRol(defensaDirecta: .008, fatiga: .88, contraataque: 1.06, descripcion: 'Inyección de energía: aguanta y corre.'),
};

EfectoRol efectoDeRol(Jugador j) => efectosRol[j.rol] ?? const EfectoRol();
