import 'dart:math';

import '../entities/rol_cancha.dart';
import 'carrera_jugador.dart';

// La vida fuera de la cancha en Mi carrera: la rutina de entrenamiento, los eventos con decisiones, la marca
// personal (patrocinios) y el legado (camisetas retiradas, récords, Salón de la Fama y qué pasa después).
//
// Todo lo que se guarda va en `EstadoCarrera.uso` (marcas con prefijo), así las partidas viejas siguen cargando.

// ---------- Rutina de entrenamiento ----------

/// En qué trabajás durante el receso: sale gratis un punto más en ese atributo al cerrar la próxima temporada.
enum Rutina {
  tiro(Atributo.tiro, 'Taller de tiro', 'Horas de tiro en soledad: +1 en Tiro exterior al cerrar la temporada.'),
  finalizacion(Atributo.finalizacion, 'Trabajo de aro', 'Bandejas, contacto y pies: +1 en Finalización.'),
  defensa(Atributo.defensa, 'Video y defensa', 'Estudiás rivales y trabajás los pies: +1 en Defensa.'),
  fisico(Atributo.fisico, 'Gimnasio', 'Pesas y velocidad: +1 en Físico (y algo de cansancio).'),
  iq(Atributo.iq, 'Pizarra y film', 'Horas de video y charlas con el DT: +1 en IQ y pase.'),
  recuperacion(null, 'Recuperación', 'Fisio, descanso y alimentación: casi no te lesionás y subís el ánimo.');

  const Rutina(this.atributo, this.etiqueta, this.descripcion);
  final Atributo? atributo;
  final String etiqueta, descripcion;
}

// ---------- Eventos con decisión ----------

/// Una respuesta posible a un evento y lo que provoca.
class OpcionEvento {
  const OpcionEvento(
    this.texto,
    this.resultado, {
    this.confianza = 0,
    this.moral = 0,
    this.fans = 0,
    this.relacion = 0,
    this.ph = 0,
  });

  final String texto, resultado;
  final int confianza, moral, fans, relacion, ph;
}

/// Algo que te pasa entre temporadas y pide que elijas.
class EventoCarrera {
  const EventoCarrera(this.id, this.titulo, this.texto, this.opciones, {this.condicion});

  final String id, titulo, texto;
  final List<OpcionEvento> opciones;

  /// Cuándo puede ocurrir (null: siempre).
  final bool Function(EstadoCarrera e)? condicion;
}

// ---------- Marca personal ----------

/// Contratos con marcas: se desbloquean con lo que lográs y cada uno suma fans cada año.
enum Patrocinio {
  zapatillasLocales('Zapatillas locales', 'Una marca del barrio te elige como cara.', 45),
  bancoDeLaCiudad('Banco de la ciudad', 'Tu equipo te pone en la publicidad: jugás 150 partidos.', 0),
  bebidaEnergetica('Bebida energética', 'Un All-Star vende: pasás por el Juego de las Estrellas.', 0),
  videojuego('Tapa del videojuego', 'Dos premios individuales y tu cara en la portada.', 0),
  marcaGlobal('Marca global', 'Con título y la afición de tu lado, las grandes llaman.', 70);

  const Patrocinio(this.etiqueta, this.descripcion, this.fansMinimos);
  final String etiqueta, descripcion;
  final int fansMinimos;

  bool la(ContextoInsignia c) => switch (this) {
    Patrocinio.zapatillasLocales => c.fans >= fansMinimos,
    Patrocinio.bancoDeLaCiudad => c.pj >= 150,
    Patrocinio.bebidaEnergetica => c.allStar >= 1,
    Patrocinio.videojuego => c.premios >= 2,
    Patrocinio.marcaGlobal => c.fans >= fansMinimos && c.titulos >= 1,
  };
}

/// Una camiseta retirada: el equipo que la retira y las temporadas que jugaste ahí.
class CamisetaRetirada {
  const CamisetaRetirada(this.franquiciaId, this.temporadas);

  final String franquiciaId;
  final int temporadas;
}

/// Lo que mejor hiciste en una sola temporada.
class RecordPersonal {
  const RecordPersonal(this.etiqueta, this.valor, this.temporada);

  final String etiqueta, temporada;
  final double valor;
}

/// Servicios de la vida de carrera. Todo es determinístico (semilla de la carrera) y sin pantalla.
class VidaCarrera {
  const VidaCarrera._();

  // ---- arquetipo ----

  /// Habilidades que van con tu arquetipo: subirlas sale un 30 % más barato (los jugadores se especializan).
  static Set<Habilidad> afines(RolCancha r) => switch (r) {
    RolCancha.organizadorPuro => {Habilidad.pase, Habilidad.vision, Habilidad.manejo},
    RolCancha.anotadorExterior => {Habilidad.triple, Habilidad.mediaDistancia, Habilidad.manejo},
    RolCancha.penetradorAtletico => {Habilidad.velocidad, Habilidad.bandeja, Habilidad.salto},
    RolCancha.baseDefensivo => {Habilidad.defPerimetral, Habilidad.robo, Habilidad.resistencia},
    RolCancha.superestrellaAclarados => {Habilidad.mediaDistancia, Habilidad.manejo, Habilidad.triple},
    RolCancha.tiradorPantallas => {Habilidad.triple, Habilidad.tiroLibre, Habilidad.mediaDistancia},
    RolCancha.escoltaGenerador => {Habilidad.manejo, Habilidad.pase, Habilidad.triple},
    RolCancha.especialista3D => {Habilidad.triple, Habilidad.defPerimetral, Habilidad.robo},
    RolCancha.controladorTotal => {Habilidad.vision, Habilidad.pase, Habilidad.manejo},
    RolCancha.anotadorTresNiveles => {Habilidad.triple, Habilidad.mediaDistancia, Habilidad.bandeja},
    RolCancha.cerrojoDefensivo => {Habilidad.defPerimetral, Habilidad.robo, Habilidad.fuerza},
    RolCancha.aleroCortador => {Habilidad.volcada, Habilidad.velocidad, Habilidad.salto},
    RolCancha.maestroPoste => {Habilidad.poste, Habilidad.fuerza, Habilidad.mediaDistancia},
    RolCancha.alaPivotTirador => {Habilidad.triple, Habilidad.tiroLibre, Habilidad.rebote},
    RolCancha.fuerzaBruta => {Habilidad.rebote, Habilidad.fuerza, Habilidad.defInterior},
    RolCancha.distribuidorInterior => {Habilidad.pase, Habilidad.vision, Habilidad.poste},
    RolCancha.goliatPintura => {Habilidad.volcada, Habilidad.fuerza, Habilidad.rebote},
    RolCancha.juegoDePies => {Habilidad.poste, Habilidad.bandeja, Habilidad.tiroLibre},
    RolCancha.protectorAro => {Habilidad.tapon, Habilidad.defInterior, Habilidad.rebote},
    RolCancha.pivotOrganizador => {Habilidad.pase, Habilidad.vision, Habilidad.poste},
    RolCancha.pivotTirador => {Habilidad.triple, Habilidad.tiroLibre, Habilidad.defInterior},
    RolCancha.microondas => {Habilidad.triple, Habilidad.mediaDistancia, Habilidad.velocidad},
    RolCancha.directorSegundaUnidad => {Habilidad.pase, Habilidad.manejo, Habilidad.vision},
    RolCancha.inyeccionEnergia => {Habilidad.resistencia, Habilidad.robo, Habilidad.defPerimetral},
  };

  // ---- rutina ----

  static Rutina? rutinaDe(EstadoCarrera e) {
    final n = e.uso['rutina'] ?? 0;
    return n <= 0 || n > Rutina.values.length ? null : Rutina.values[n - 1];
  }

  static EstadoCarrera elegirRutina(EstadoCarrera e, Rutina r) =>
      e.copyWith(uso: {...e.uso, 'rutina': r.index + 1});

  /// Cambio extra en los atributos al cerrar la temporada por la rutina elegida.
  static Map<Atributo, int> efectoRutina(EstadoCarrera e) {
    final r = rutinaDe(e);
    final a = r?.atributo;
    return a == null ? const {} : {a: 1};
  }

  /// Probabilidad de lesión grave multiplicada por la rutina (Recuperación casi la elimina).
  static double factorLesion(EstadoCarrera e) => rutinaDe(e) == Rutina.recuperacion ? 0.35 : 1.0;

  // ---- eventos ----

  static final catalogo = <EventoCarrera>[
    EventoCarrera(
      'rumor',
      'Rumores de traspaso',
      'Los diarios dicen que tu equipo te ofrece al mejor postor. En el vestuario todos te miran.',
      const [
        OpcionEvento('Desmentirlo en público', 'La gente te cree y el DT valora tu palabra.', confianza: 3, fans: 2),
        OpcionEvento('No decir nada', 'El ruido sigue, pero entrenás tranquilo.', moral: -2, ph: 1),
        OpcionEvento('Hablar con el gerente', 'Te aseguran que cuentan con vos.', confianza: 4, relacion: -2),
      ],
      condicion: (e) => e.contrato <= 2,
    ),
    EventoCarrera(
      'novato',
      'Un novato te pide consejos',
      'Un chico recién llegado te sigue a todos lados y quiere aprender de vos.',
      const [
        OpcionEvento('Ser su mentor', 'Se hace tu sombra y el vestuario te lo reconoce.', relacion: 6, moral: 2),
        OpcionEvento('Darle un par de tips', 'Cumplís sin ponerte en el centro.', relacion: 2),
        OpcionEvento('Concentrarte en lo tuyo', 'Ganás horas de entrenamiento.', ph: 2, relacion: -3),
      ],
      condicion: (e) => e.edad >= 25,
    ),
    EventoCarrera(
      'zapatillas',
      'Oferta de zapatillas',
      'Una marca grande quiere hacerte una línea propia, con una condición: exclusividad total.',
      const [
        OpcionEvento('Firmar la exclusividad', 'Sos cara de la marca: los fans te adoran.', fans: 8, relacion: -3),
        OpcionEvento('Rechazar y seguir libre', 'Te respetan por no venderte.', moral: 3, relacion: 3),
      ],
      condicion: (e) => e.fans >= 55,
    ),
    EventoCarrera(
      'bajon',
      'Un bajón de ánimo',
      'Venís de varias semanas sin disfrutar. Ni la pelota se siente igual.',
      const [
        OpcionEvento('Hablar con un psicólogo', 'Ordenás la cabeza y volvés a sonreír.', moral: 10),
        OpcionEvento('Entrenar el doble', 'Ganás nivel, pero te desgastás.', ph: 3, moral: -4),
        OpcionEvento('Tomarte unos días', 'El cuerpo agradece. El DT, menos.', moral: 5, confianza: -2),
      ],
      condicion: (e) => e.moral < 50,
    ),
    EventoCarrera(
      'dt',
      'Cruce con el DT',
      'Discutís con el entrenador por tus minutos y el tono sube delante de todos.',
      const [
        OpcionEvento('Pedir disculpas', 'Se recompone la relación; el equipo respira.', confianza: 5, relacion: 2, moral: -2),
        OpcionEvento('Mantener tu postura', 'Los compañeros te respaldan, el DT no.', relacion: 5, confianza: -6),
      ],
      condicion: (e) => e.confianza < 62,
    ),
    EventoCarrera(
      'campus',
      'Campus de verano',
      'Un ex jugador legendario te invita a entrenar un mes con su grupo.',
      const [
        OpcionEvento('Ir al campus', 'Volvés con ideas nuevas y las piernas cansadas.', ph: 3, moral: -3),
        OpcionEvento('Vacaciones de verdad', 'Cargás pilas para la temporada.', moral: 6),
      ],
    ),
    EventoCarrera(
      'cena',
      'Cena de equipo',
      'Se acerca el cierre del año y el grupo quiere juntarse. Alguien tiene que organizar.',
      const [
        OpcionEvento('Invitar vos a todos', 'Una noche para el recuerdo: el grupo está más unido.', relacion: 7, moral: 3),
        OpcionEvento('Que cada uno ponga lo suyo', 'Sale bien y sin vueltas.', relacion: 2),
      ],
    ),
    EventoCarrera(
      'fundacion',
      'Tu fundación',
      'Un amigo te propone armar una escuelita de básquet en tu barrio de origen.',
      const [
        OpcionEvento('Ponerle tu nombre y tu tiempo', 'La ciudad se enamora de tu historia.', fans: 7, moral: 3, ph: -1),
        OpcionEvento('Ayudar sin hacer ruido', 'Hacés el bien y te cuidás del foco.', moral: 4, fans: 2),
      ],
      condicion: (e) => e.fans >= 35,
    ),
    EventoCarrera(
      'polemica',
      'Declaración polémica',
      'Una frase tuya en una nota se volvió viral y no cayó bien en todos lados.',
      const [
        OpcionEvento('Defender lo que dijiste', 'Los tuyos te aplauden y los rivales también.', fans: 3, relacion: -3, confianza: -2),
        OpcionEvento('Pedir disculpas', 'Se apaga el fuego rápido.', fans: -2, confianza: 3),
        OpcionEvento('Dejar que el juego hable', 'Cambiás la conversación con una gran noche.', moral: 2, ph: 1),
      ],
      condicion: (e) => e.fans >= 40,
    ),
    EventoCarrera(
      'nutricion',
      'El cuerpo te avisa',
      'Notás que tardás más en recuperarte después de cada partido.',
      const [
        OpcionEvento('Armar un plan de nutrición', 'Pagás un especialista y se nota en la cancha.', ph: 2, moral: 2),
        OpcionEvento('Seguir como siempre', 'No hay cambios... por ahora.', moral: -1),
      ],
      condicion: (e) => e.edad >= 28,
    ),
  ];

  /// El evento de la temporada (null si ya lo resolviste o ninguno aplica). Determinístico por carrera.
  static EventoCarrera? eventoPara(EstadoCarrera e) {
    if ((e.uso['evento'] ?? 0) >= e.numero) return null;
    final azar = Random(_hash('${e.raiz}-evento-${e.numero}'));
    final posibles = [
      for (final ev in catalogo)
        if ((e.uso['e:${ev.id}'] ?? 0) < 1 && (ev.condicion?.call(e) ?? true)) ev,
    ];
    final lista = posibles.isEmpty ? catalogo : posibles;
    return lista[azar.nextInt(lista.length)];
  }

  /// Aplica la respuesta [i] al evento [ev]. Suma al ánimo, los fans, la relación, la confianza y los puntos.
  static EstadoCarrera resolver(EstadoCarrera e, EventoCarrera ev, int i) {
    final o = ev.opciones[i.clamp(0, ev.opciones.length - 1)];
    return e.copyWith(
      confianza: e.confianza + o.confianza,
      moral: e.moral + o.moral,
      fans: e.fans + o.fans,
      relacion: e.relacion + o.relacion,
      phBanco: max(0, e.phBanco + o.ph),
      uso: {...e.uso, 'evento': e.numero, 'e:${ev.id}': 1},
      hitos: [...e.hitos, '${e.etiquetaTemporada}: ${ev.titulo} — ${o.texto.toLowerCase()}.'],
    );
  }

  // ---- marca personal ----

  static List<Patrocinio> patrocinios(EstadoCarrera e) {
    final c = e.contexto;
    return [
      for (final p in Patrocinio.values)
        if (p.la(c)) p,
    ];
  }

  /// Marca personal de 0 a 100: la fama (fans), los títulos y los contratos.
  static int marca(EstadoCarrera e) {
    final c = e.contexto;
    return (e.fans * 0.55 + c.allStar * 4 + c.titulos * 6 + patrocinios(e).length * 5).round().clamp(0, 100);
  }

  /// Fans que suman los patrocinios cada año (poco: la fama también se gana jugando).
  static int fansPorPatrocinios(EstadoCarrera e) => min(3, patrocinios(e).length);

  // ---- legado ----

  /// Camisetas retiradas: equipos donde jugaste 6 años o más y dejaste huella.
  static List<CamisetaRetirada> camisetas(LegadoCarrera l) {
    final porEquipo = <String, List<TemporadaJugador>>{};
    for (final t in l.temporadas) {
      porEquipo.putIfAbsent(t.franquiciaId, () => []).add(t);
    }
    return [
      for (final en in porEquipo.entries)
        if (en.value.length >= 6 &&
            (en.value.any((t) => t.campeon) || en.value.where((t) => t.allStar).length >= 2 || l.salon))
          CamisetaRetirada(en.key, en.value.length),
    ];
  }

  /// Tu mejor temporada en puntos, rebotes y asistencias.
  static List<RecordPersonal> records(LegadoCarrera l) {
    if (l.temporadas.isEmpty) return const [];
    TemporadaJugador mejor(double Function(TemporadaJugador) f) => l.temporadas.reduce((a, b) => f(a) >= f(b) ? a : b);
    final p = mejor((t) => t.pts), r = mejor((t) => t.reb), a = mejor((t) => t.ast);
    return [
      RecordPersonal('Puntos por partido', p.pts, p.etiqueta),
      RecordPersonal('Rebotes por partido', r.reb, r.etiqueta),
      RecordPersonal('Asistencias por partido', a.ast, a.etiqueta),
    ];
  }

  /// Qué pasa después de colgar las zapatillas: el Salón de la Fama y, si te lo ganaste, el banco.
  static List<String> epilogo(EstadoCarrera e) {
    final l = e.legado;
    final lineas = <String>[];
    final ultimo = e.anioBase + e.numero;
    if (l.puntosSalon >= 24) {
      lineas.add('${ultimo + 5}: entrás al Salón de la Fama en la primera votación, con la sala de pie.');
    } else if (l.salon) {
      lineas.add('${ultimo + 6}: el Salón de la Fama te abre sus puertas.');
    } else if (l.puntosSalon >= 7) {
      lineas.add('Año tras año, tu nombre suena en la votación del Salón. Un día de estos llega.');
    }
    for (final c in camisetas(l)) {
      lineas.add('${c.franquiciaId} retira tu camiseta tras ${c.temporadas} temporadas con el club.');
    }
    final iq = e.atributos[Atributo.iq];
    final azar = Random(_hash('${e.raiz}-retiro'));
    if (iq >= 80 && l.anillos >= 1 && azar.nextDouble() < 0.7) {
      lineas.add('Te quedás en la NBA: asistente técnico, y a los ${3 + azar.nextInt(3)} años, entrenador principal.');
    } else if (iq >= 70 && azar.nextDouble() < 0.5) {
      lineas.add('Te vas a los medios: comentarista de la liga que te vio crecer.');
    } else if (lineas.isEmpty) {
      lineas.add('Volvés a tu barrio a dirigir la escuelita donde empezó todo.');
    }
    return lineas;
  }

  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }
}
