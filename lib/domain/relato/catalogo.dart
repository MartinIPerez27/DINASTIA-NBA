import 'contexto_relato.dart';

/// Las frases de una situación para cada personaje.
///
/// Las plantillas usan marcadores entre llaves ({q} jugador, {a} asistente, {d} defensor, {eq} equipo
/// que ataca, {rv} el otro, {marc} marcador, {reloj}…) y un prefijo opcional de tono:
///   `~` solo con intensidad baja (≤ 1, trámite)   ·   `^` solo con intensidad alta (≥ 3).
/// Una plantilla cuyos marcadores no se pueden completar se descarta sola.
class FrasesSituacion {
  const FrasesSituacion({required this.relator, required this.comentarista});

  final List<String> relator, comentarista;

  List<String> de(Personaje p) => p == Personaje.relator ? relator : comentarista;
}

/// Catálogo completo. El Relator usa español neutro y técnico; el Comentarista, voseo rioplatense.
/// Todo es original: variaciones de expresiones comunes del básquet.
const catalogoRelato = <Situacion, FrasesSituacion>{
  // ───────────────────────────── Tiros ─────────────────────────────
  Situacion.doble: FrasesSituacion(
    relator: [
      'Doble de {q}.',
      '{q} la deja suave: dos puntos.',
      'Canasta de {q} desde la media distancia.',
      '{q} encuentra espacio y anota. {marc}.',
      'Penetración de {q} y definición por encima del aro: dos más.',
      '~Dos para {q}.',
      '^{q} anota y el partido sigue sin dueño: {marc}.',
    ],
    comentarista: [
      'Qué tranquilidad tiene {q} para definir.',
      'Ese lo hace dormido, mirá.',
      'Prolijo, muy prolijo {q}.',
      'Fijate qué fácil se lo dejaron a {q}.',
      'Entró, así de simple: {q} solo no perdona.',
      'Despacito y adentro, ese {q}.',
    ],
  ),
  Situacion.dobleAsistido: FrasesSituacion(
    relator: [
      'Pase de {a} y {q} define: dos puntos.',
      'Buena circulación de pelota: {a} encuentra a {q} libre y no falla.',
      'Asistencia de {a}, canasta de {q}.',
      'Corte de {q} hacia el aro, pase de {a} y doble sin oposición.',
      '^{a} lee la defensa, filtra el pase y {q} no falla. {marc}.',
    ],
    comentarista: [
      'Mirá cómo se entienden {a} y {q}.',
      'Eso es básquet de pizarrón.',
      'Pase de lujo de {a}: se lo dejó servido a {q}.',
      'Qué lindo se mueve este equipo, da gusto.',
      'Con esa pelota, {q} solo tenía que no equivocarse.',
    ],
  ),
  Situacion.contraataque: FrasesSituacion(
    relator: [
      'Contragolpe de {eq}: {q} corre la cancha y anota.',
      'Transición veloz, {q} termina la jugada. {marc}.',
      'Salida rápida tras el rebote y {q} define sin marca.',
      '{q} recibe en carrera y no desperdicia la superioridad numérica.',
      'Robo, carrera y canasta: así se castiga una transición mal cubierta.',
    ],
    comentarista: [
      '¡Pasaron como una moto, mirá!',
      'Se quedaron mirando, nadie bajó a tiempo.',
      'Con tanto espacio, {q} es un peligro.',
      'Corrieron todos juntos y a la defensa le faltó pulmón.',
      'Eso fue un relámpago de {eq}, ni se vio.',
    ],
  ),
  Situacion.canastaYFalta: FrasesSituacion(
    relator: [
      'Canasta y falta: {q} anota y {res}.',
      '{q} convierte con contacto: {res}.',
      'Jugada de tres puntos en marcha: {q} anota y {res}.',
      'Anota {q} y le cobran la falta al defensor: {res}.',
      '^{q} se lleva la canasta por delante y {res}.',
    ],
    comentarista: [
      '¡Cantó basket y encima libre!',
      'Le pegaron y le entró igual, no hay con qué darle.',
      'Se la llevó puesta y la metió, qué carácter.',
      'Anotó y encima lo pararon: doble castigo para {rv}.',
      'Eso es meter y cobrar, dos veces por el precio de una.',
    ],
  ),
  Situacion.triple: FrasesSituacion(
    relator: [
      'Triple de {q}.',
      '{q} lo intenta desde el perímetro: ¡adentro!',
      'Desde más allá del arco, {q} no falla. {marc}.',
      'Lanzamiento de tres puntos de {q}, y la pelota ni toca el aro.',
      'Pase de {a}, recepción y tiro de {q}: triple.',
      '~Tres puntos para {q}.',
      '^¡Triple de {q}! La defensa llegó tarde otra vez.',
    ],
    comentarista: [
      '¡Qué disparo tiene {q}!',
      'Esa la tiró con los ojos cerrados.',
      'Mirá la confianza: ni miró el aro.',
      'Cuando {q} agarra la pelota así, hay que ir a sacársela.',
      'Esa es de las que se cantan solas.',
      'Sonó la red y se calló la defensa.',
    ],
  ),
  Situacion.tripleCierre: FrasesSituacion(
    relator: [
      '¡Triple de {q} en el cierre! {marc}, quedan {reloj}.',
      '¡{q} se juega la posesión decisiva y la manda adentro! Tres puntos, {marc}.',
      'En el momento de máxima tensión, {q} lanza de tres y convierte.',
      'Con {reloj} en el reloj, {q} anota de tres. {marc}.',
      '^Canasta decisiva de {q} desde el perímetro: el partido cambia de dueño.',
    ],
    comentarista: [
      '¡Eso es de jugador grande, {q}!',
      '¡No me lo puedo creer! ¡Con la presión encima!',
      '¡Sangre fría total, {q}!',
      '¡Qué manera de elegir el momento para sacar esa!',
      '¡Se vino la cancha abajo, se vino!',
      '¡Triple de los que se cuentan durante años!',
    ],
  ),
  Situacion.volcada: FrasesSituacion(
    relator: [
      'Volcada de {q}.',
      '{q} sube y la cuelga con fuerza.',
      'Ataque al aro de {q}: volcada contundente.',
      '{q} se eleva por encima de la defensa y la clava. {marc}.',
      '^¡Machaque de {q}! Eso se siente en toda la cancha.',
    ],
    comentarista: [
      '¡Mirá cómo la colgó {q}!',
      '¡Se vino el aro abajo!',
      '¡Qué barbaridad, ni la vieron pasar!',
      'Eso no se marca: eso se mira.',
      'Con esa furia, hay que pedirle permiso para subir.',
      'Se les paró un edificio adelante.',
    ],
  ),
  Situacion.alleyOop: FrasesSituacion(
    relator: [
      '¡Alley-oop! Pase de {a} y {q} la finaliza en el aire.',
      'Lob de {a}, {q} la atrapa arriba y la clava.',
      'Conexión aérea entre {a} y {q}: dos puntos.',
      'Pase al aro de {a}; {q} anticipó la jugada y la baja con las dos manos.',
      '^¡Alley-oop espectacular! {a} la tira alta y {q} la termina de un golpe.',
    ],
    comentarista: [
      '¡Qué sociedad, por favor!',
      '¡La tiró al cielo y alguien la bajó!',
      '¡Eso estaba ensayado desde chiquitos!',
      'Mirá la confianza: {a} la tira sin fijarse si llega, y llega.',
      'Estas jugadas te hacen sonreír aunque seas el rival.',
    ],
  ),
  Situacion.tapon: FrasesSituacion(
    relator: [
      'Tapón de {d} sobre {q}.',
      '{d} llega desde la ayuda y bloquea el tiro de {q}.',
      'Bloqueo contundente de {d} en la pintura.',
      'Gran defensa de {d}: protegió el aro.',
      '^¡Tapón de {d}! {q} no tenía por dónde.',
    ],
    comentarista: [
      '¡No pasa nadie! ¡Cerrado el negocio!',
      '¡Le puso la mano en la cara, {d}!',
      'Eso es decir que acá no, con todas las letras.',
      'Mandó la pelota a otro barrio.',
      '¡Qué rechazo, {d}!',
      '{q} se fue al aro con la mejor intención y se encontró un portón.',
    ],
  ),
  Situacion.taponRecuperado: FrasesSituacion(
    relator: [
      'Tapón de {d}, pero {r} se queda con el rebote: nueva posesión para {eq}.',
      'Bloqueo de {d} sobre {q}; la pelota queda viva y la recupera {r}.',
      '{d} tapa, {r} recupera: se reinicia el ataque con 14 segundos.',
      'El tiro de {q} es bloqueado, aun así {ceq} conserva la pelota con {r}.',
    ],
    comentarista: [
      'Lo taparon y igual la tienen, mirá vos.',
      'Qué terquedad, esa pelota no se les quiere ir.',
      'Casi se la comen y se salvaron con {r}.',
      '{d} hizo lo suyo y {r} lo arruinó: así es esto.',
    ],
  ),
  Situacion.reboteOfensivo: FrasesSituacion(
    relator: [
      'Rebote ofensivo de {r}: segunda oportunidad para {eq}.',
      '{q} falla, pero {r} gana la posición y captura.',
      'Segunda chance: {r} pelea bajo el aro.',
      'Reinicia la posesión con 14 segundos {eq}, rebote de {r}.',
      '~Rebote ofensivo de {r}.',
    ],
    comentarista: [
      '¡Qué ganas, {r}!',
      'No se la dieron ni de regalo, la fue a buscar.',
      'Esa pelota tenía su nombre escrito, {r}.',
      'Alguien tiene que avisarle a {rv} que se cierra el rebote.',
      'Cabeza dura: no se rinden nunca.',
    ],
  ),
  Situacion.ladrillo: FrasesSituacion(
    relator: [
      'Falla {q}. Rebote de {r}.',
      '{q} no encuentra el aro; controla {r}.',
      'Tiro de {q} sin fortuna, la toma {r}.',
      'Fuera el intento de {q}. Captura {r}.',
      '~Falla {q}.',
      'Tiro forzado de {q} bajo presión: sin éxito.',
    ],
    comentarista: [
      'Ese tiro casi llega a la tribuna.',
      'Un ladrillo, che.',
      'Uy, qué mal lo vio {q}.',
      'Eso no lo tira nadie en el potrero, y menos acá.',
      'Le erró por bastante, no hay otra forma de decirlo.',
      'Se le escapó la mano, pasa.',
    ],
  ),
  Situacion.aro: FrasesSituacion(
    relator: [
      'El tiro de {q} pega en el aro y sale: rebote de {r}.',
      'Pega en el fondo del aro y no quiere entrar; {r} controla.',
      'Roza el aro el tiro de {q}, pero afuera.',
      'Tiro largo de {q}, golpea el hierro y rebota lejos.',
    ],
    comentarista: [
      '¡Qué golpe le dio al hierro! Hizo vibrar todo.',
      'Se quedó pensando si entraba y decidió que no.',
      'Casi, casi... pero no.',
      'Esa estaba adentro y se arrepintió.',
      'Pegó tan fuerte que todavía debe estar temblando el tablero.',
    ],
  ),
  Situacion.tiroDesesperado: FrasesSituacion(
    relator: [
      'Se agota el cuarto: {q} lanza desde su mitad de cancha y no llega.',
      'Tiro desesperado de {q} con la bocina: sin puntería.',
      '{q} intenta desde muy lejos sobre el tiempo: afuera.',
      'Lanzamiento de larga distancia de {q} con el reloj en cero: no hay premio.',
    ],
    comentarista: [
      'Valía la pena intentarlo, che.',
      'Eso no llegaba ni con un cohete.',
      'Tiró y rezó. Nadie escuchó.',
      'Qué ganas de tirar, pero no.',
    ],
  ),
  Situacion.chicharraLejana: FrasesSituacion(
    relator: [
      '¡Sobre la chicharra, desde su propia mitad, canasta de {q}!',
      '{q} lanza desde su campo con el tiempo agotado y... ¡entra!',
      '¡Tiro de otro planeta de {q} con la bocina! {marc}.',
      '¡Increíble! {q} convierte desde más allá de la mitad de la cancha.',
    ],
    comentarista: [
      '¡NO LO PUEDO CREER!',
      '¡Eso es de otro planeta!',
      '¡Tiró desde la otra punta del país y entró!',
      '¡Me tiembla el pulso! ¡Qué locura!',
    ],
  ),
  Situacion.chicharra: FrasesSituacion(
    relator: [
      'Sobre la chicharra, {q} anota y se cierra el {cq}.',
      '¡Con el reloj en cero entra el tiro de {q}!',
      'Canasta de {q} en el último segundo: {marc}.',
      'La bocina suena mientras la pelota viaja: ¡es válida!',
    ],
    comentarista: [
      '¡Justo justo, por un pelo!',
      'Eso fue sobre la hora, de casualidad no se suspende.',
      '¡Uy, qué nervios!',
      'Cuando suena la chicharra y la pelota igual entra, hay un poco de magia.',
    ],
  ),
  Situacion.interferencia: FrasesSituacion(
    relator: [
      'Interferencia de {d}: tocó la pelota en su descenso. La canasta de {q} vale.',
      'Goaltending de {d}; se concede el tiro de {q}.',
      'Infracción de {d} al tocar la pelota sobre el aro: puntos para {q}.',
      'El árbitro sanciona la interferencia de {d}: la canasta es de {eq}.',
    ],
    comentarista: [
      'Se le fue la mano a {d}, no podía tocarla.',
      'Fue un tapón con ganas pero tarde.',
      '¡Qué desesperación, {d}! Le regaló el doble.',
      'Quiso hacerse el héroe y quedó de villano.',
    ],
  ),

  // ───────────────────────────── Libres ─────────────────────────────
  Situacion.libresPerfectos: FrasesSituacion(
    relator: [
      '{q} convierte {lib}.',
      'Sin fallas desde la línea: {q}, {lib}.',
      'Libres de {q}: {lib}. Marcador {marc}.',
      '{q}, impecable desde la línea de libres: {lib}.',
    ],
    comentarista: [
      'Tranquilo desde la línea, un reloj {q}.',
      'Eso es automático.',
      'Qué sangre fría, no le tiembla nada.',
      'Tiros libres con la mano en el bolsillo.',
    ],
  ),
  Situacion.libresParciales: FrasesSituacion(
    relator: [
      '{q} convierte {lib} desde la línea.',
      'Falta sobre {q}: mete {lib}.',
      'Resultado parcial en la línea: {lib}, queda {marc}.',
      '{q} deja puntos en la línea de libres: {lib}.',
    ],
    comentarista: [
      'Algo es algo.',
      'Podría haber sido mejor, podría haber sido peor.',
      'Regalaron un punto ahí, che.',
      'Ese libre se le quedó corto.',
    ],
  ),
  Situacion.libresFallados: FrasesSituacion(
    relator: [
      '{q} no convierte ningún libre ({lib}).',
      'Se escapan todos los libres de {q}: {lib}.',
      'Pierde la oportunidad desde la línea: {lib}.',
      'Sin puntería desde los 4,60: {q} falla {nlib}.',
    ],
    comentarista: [
      'Dos ladrillos, y los dos de manual.',
      'Se le quemaron las manos.',
      'Eso se llama regalar puntos.',
      'Uy, qué mal que le fue en la línea.',
    ],
  ),
  Situacion.lineaDeSuspiros: FrasesSituacion(
    relator: [
      'Libres decisivos para {q}: {lib}. Marcador {marc}.',
      'Con {reloj} por jugarse, {q} va a la línea: {lib}.',
      'Desde la línea en el cierre: {q} convierte {lib}, {marc}.',
      '^Tiros libres de máxima presión: {q}, {lib}. {marc}.',
    ],
    comentarista: [
      'Se me hizo un nudo en el estómago.',
      'Los libres del final pesan el doble.',
      'Sudor frío: a la línea con todo el estadio en silencio.',
      'Qué presión, no me lo imagino.',
      'Acá se ve de qué está hecho cada uno.',
    ],
  ),

  // ───────────────────────────── Pérdidas ─────────────────────────────
  Situacion.robo: FrasesSituacion(
    relator: [
      'Robo de {d} a {q}.',
      '{d} corta la línea de pase y se queda con la pelota.',
      'Pérdida de {q}, interceptada por {d}.',
      'Gran lectura defensiva de {d}: recupera la pelota.',
      '^Robo de {d} y sale en transición.',
    ],
    comentarista: [
      '¡Se la afanó {d}, mirá!',
      'Eso es robar sin que se note.',
      'Estaba distraído {q} y {d} no perdona.',
      '¡Qué manos tiene {d}!',
      'Le sacó la pelota como quien le saca un caramelo a un nene.',
    ],
  ),
  Situacion.perdidaAfuera: FrasesSituacion(
    relator: [
      'Pelota afuera: pérdida de {q}.',
      '{q} se pasa del límite: posesión para {rv}.',
      'Error de {q}, el pase termina fuera de la cancha.',
      'Pérdida no forzada de {q}.',
    ],
    comentarista: [
      'Eso fue directo a la tribuna.',
      'Se confundió {q}, la pelota se fue con otro.',
      'Un pase así no tiene explicación.',
      'Tan mal tirado que ni los hinchas la quisieron.',
    ],
  ),
  Situacion.perdida24: FrasesSituacion(
    relator: [
      'Violación de 24 segundos: {ceq} no logra tirar a tiempo.',
      'Se agota el reloj de posesión: pierde la pelota {ceq}.',
      'Sin tiro dentro de los 24 segundos: la pelota pasa a {rv}.',
      'Demasiado tiempo manejando el balón: infracción de posesión.',
      'La bocina de 24 suena antes de que la pelota llegue al aro.',
    ],
    comentarista: [
      'Se amasó tanto la pelota que se enfrió.',
      'Se quedaron sin ideas, y sin reloj.',
      'Mucha vuelta y ningún tiro, qué desperdicio.',
      'Dale, tirá, che, que se acaba el tiempo.',
    ],
  ),
  Situacion.perdida3s: FrasesSituacion(
    relator: [
      'Tres segundos en la pintura: {q} permanece demasiado tiempo en la zona.',
      'Violación de 3 segundos para {q}.',
      'Infracción de {q}: más de tres segundos en el área restringida.',
      'Se silba tres segundos: pelota para {rv}.',
    ],
    comentarista: [
      'Se instaló {q} en la pintura como en su casa.',
      'Está viviendo ahí adentro, {q}.',
      'Dale, un pasito afuera, que no te cuesta nada.',
      'Pidió permiso para quedarse, pero no se lo dieron.',
    ],
  ),
  Situacion.campoAtras: FrasesSituacion(
    relator: [
      'Campo atrás de {q}: devolvió la pelota a su zona.',
      'Violación de campo atrás: {q} retrocede con el balón.',
      '{q} cruza la mitad de cancha y regresa a su campo: infracción.',
      'Se sanciona campo atrás a {eq}.',
    ],
    comentarista: [
      'Eso es un error de principiante.',
      'Pasó la mitad, se arrepintió y lo pagó.',
      'Se confundió de lado, che.',
      'Volvió {q}, y las reglas dicen que no se vuelve.',
    ],
  ),
  Situacion.pasos: FrasesSituacion(
    relator: [
      'Pasos de {q}: el árbitro señala la infracción.',
      'Caminata: {q} da demasiados pasos con la pelota.',
      'Infracción de {q} por pasos.',
      '{q} camina con la pelota y pierde la posesión.',
    ],
    comentarista: [
      'Caminó {q}, y se nota hasta desde la tribuna.',
      'Eso fue un paseo por la cancha.',
      'Dos pasitos de más.',
      'Qué ganas de pasear tenía {q}.',
    ],
  ),
  Situacion.dobles: FrasesSituacion(
    relator: [
      'Doble dribbling de {q}: pelota para {rv}.',
      '{q} vuelve a picar la pelota después de agarrarla: dobles.',
      'Infracción de dobles para {q}.',
      'Dobles: {q} reanuda el dribbling y se acaba la jugada.',
    ],
    comentarista: [
      'Picó, paró, picó de nuevo... ¿por qué, {q}?',
      'Eso se aprende en las inferiores.',
      'Doble toque: error de manual.',
      'Se enredó solo.',
    ],
  ),
  Situacion.carga: FrasesSituacion(
    relator: [
      'Falta en ataque de {q}: {p} se mantuvo firme y recibió el contacto.',
      'Carga de {q} sobre {p}: pérdida para {eq}.',
      '{p} planta los pies y consigue la falta en ataque.',
      'Falta ofensiva de {q}: pelota para {rv}.',
    ],
    comentarista: [
      '¡Se quedó parado, {p}, como una pared!',
      'Le pasó por arriba y encima se quiere quejar.',
      'Eso es sacrificio, {p}: se ofrece a que lo choquen.',
      'El golpe se escuchó hasta en los vestuarios.',
    ],
  ),

  // ───────────────────────────── Faltas ─────────────────────────────
  Situacion.faltaPersonal: FrasesSituacion(
    relator: [
      'Falta personal de {d} sobre {q}.',
      'Silbato: falta de {d}. Saque lateral.',
      'Contacto de {d}: falta, la posesión sigue.',
      'Se señala la {falta_n} falta de {d}.',
      '~Falta de {d}.',
    ],
    comentarista: [
      'Eso es poco para pitarlo, pero bueno.',
      'Le tocó apenas.',
      'El árbitro tiene el silbato caliente.',
      'Se calentaron las manos.',
    ],
  ),
  Situacion.bonus: FrasesSituacion(
    relator: [
      'Falta de {d} con {rv} en bonus: {q} va a la línea ({lib}).',
      '{rv} alcanza el límite de faltas: libres para {q}, {lib}.',
      'En bonus, falta de {d}: {q} tiene dos tiros libres. {lib}.',
      'Situación de bonus: cada falta de {rv} se paga con libres.',
    ],
    comentarista: [
      'Se les acumulan las faltas y ahora pagan.',
      'Regalaron dos tiros desde la línea.',
      'En bonus no se puede tocar a nadie, che.',
      'Ya van a tener que cuidar las manos.',
    ],
  ),
  Situacion.tecnica: FrasesSituacion(
    relator: [
      'Falta técnica para {d}: protesta excesiva. {q} {libtxt}',
      'Sanción técnica: {d} recibe la falta por conducta. {q} {libtxt}',
      'El árbitro cobra técnica a {d}. {q} {libtxt}',
      'Técnica a {d}; un tiro libre para {eq}. {q} {libtxt}',
    ],
    comentarista: [
      'Se le fue la boca, {d}.',
      'Hay que aprender a callarse a tiempo.',
      'Mucho reclamo y poco juego.',
      'Eso le va a costar caro.',
    ],
  ),
  Situacion.flagrante: FrasesSituacion(
    relator: [
      'Falta flagrante de {d} sobre {q}: dos libres y posesión para {eq}. {q} {libtxt}',
      'Flagrante: contacto excesivo de {d}. {q} {libtxt} y la pelota sigue siendo de {eq}.',
      'El árbitro marca flagrante contra {d}: libres para {q} y posesión. {q} {libtxt}',
      '^Falta flagrante de {d}: demasiado contacto sobre {q}. {q} {libtxt}',
    ],
    comentarista: [
      '¡Eso fue una barbaridad, {d}!',
      'Le pegó con todas las ganas.',
      'Eso ya no es básquet, es otra cosa.',
      'Se está poniendo espeso esto.',
    ],
  ),
  Situacion.intencional: FrasesSituacion(
    relator: [
      'Falta intencional de {d} para frenar el reloj: {q} {libtxt}',
      'Estrategia de faltas: {rv} manda a {q} a la línea. {q} {libtxt}',
      'Detienen el reloj con la falta de {d}: {q} {libtxt}',
      'Falta táctica de {rv}; {q} va a los libres. {q} {libtxt}',
    ],
    comentarista: [
      'Es la única forma que tienen de volver, a pelear.',
      'Hay que elegir bien a quién se lo hacen: ojo con eso.',
      'La jugada del que pierde: parar el reloj como sea.',
      'El que va perdiendo se aferra a lo que puede.',
    ],
  ),

  // ───────────────────────────── Gestión del partido ─────────────────────────────
  Situacion.salto: FrasesSituacion(
    relator: [
      'Salto entre dos: {q} y {d} disputan; se queda con la pelota {g}.',
      'Pelota retenida entre {q} y {d}. La gana {g}.',
      'Disputa por la posesión: {q} contra {d}, se impone {g}.',
      'Salto: pierde la pelota {rv} y la tiene {eq}.',
    ],
    comentarista: [
      'Tironeo de los dos y se la lleva {g}.',
      'Pelea de gigantes, y lo ganó {g}.',
      'Ni uno ni otro la quería soltar.',
      'Dos fortachones con la misma idea: no soltarla.',
    ],
  ),
  Situacion.cambio: FrasesSituacion(
    relator: [
      'Cambio en {eq}: entra {e} por {s}.',
      '{ceq} modifica su rotación: {e} reemplaza a {s}.',
      'Sale {s}, entra {e}.',
      'Movimiento del banco: {e} ingresa a la cancha.',
      '~Cambio: {e} por {s}.',
      'Rotación: {s} descansa para que {e} aporte piernas frescas.',
    ],
    comentarista: [
      'A ver qué trae {e} desde el banco.',
      '{s} necesita un respiro.',
      'Se mueve el banco, entra aire fresco.',
      'Ojo con {e}, que viene con hambre.',
    ],
  ),
  Situacion.cambioFaltas: FrasesSituacion(
    relator: [
      'Cambio preventivo: {s} se sienta con problemas de faltas y entra {e}.',
      '{s} acumula faltas; el entrenador lo protege y manda a {e}.',
      'Entra {e} por {s}, cargado de faltas.',
      'Rotación obligada: las faltas de {s} fuerzan a modificar el quinteto.',
    ],
    comentarista: [
      'Para no arriesgar al tipo con tantas faltas.',
      'El entrenador no quiere sorpresas.',
      'Mejor sentarlo antes que perderlo para siempre.',
      '{s} se va al banco con la cabeza gacha.',
    ],
  ),
  Situacion.cambioExpulsion: FrasesSituacion(
    relator: [
      'Sale {s} por expulsión, entra {e}.',
      '{ceq} debe reemplazar a {s}, expulsado: ingresa {e}.',
      'Sin {s}, {ceq} recurre a {e}.',
      'Se completa la expulsión de {s}: {e} salta a la cancha.',
    ],
    comentarista: [
      'Se perdió un jugador clave para lo que viene.',
      'Ahora a hacerse cargo del lío, {e}.',
      '{ceq} se queda sin {s} y sin remedio.',
      'Hay que remar sin uno de los importantes.',
    ],
  ),
  Situacion.expulsion: FrasesSituacion(
    relator: [
      '{x} es expulsado: acumula {motivo}.',
      'Queda fuera {x}: {motivo}.',
      'El árbitro lo manda al vestuario: {x}, {motivo}.',
      'Expulsión de {x} por {motivo}.',
    ],
    comentarista: [
      '¡Lo echaron! ¡Y qué falta va a hacer!',
      'Se va {x} y el partido no es el mismo.',
      'Calentón de más que se paga caro.',
      'Se le terminó la noche a {x}.',
    ],
  ),
  Situacion.tiempoMuerto: FrasesSituacion(
    relator: [
      'Tiempo muerto solicitado: el entrenador detiene el juego.',
      'Se reúne el equipo con su cuerpo técnico en el banco.',
      'Minuto pedido: a ajustar la defensa y definir la jugada.',
      'Pausa en el juego. Marcador {marc}.',
    ],
    comentarista: [
      'A respirar y a acomodar las ideas.',
      'El técnico tiene que decir algo importante acá.',
      'Se juntan en el círculo, a tomar aire.',
      'Ahora es cosa de pizarrón.',
      'A tomar agua y a pensar.',
    ],
  ),
  Situacion.tiempoMuertoParcial: FrasesSituacion(
    relator: [
      'Tiempo muerto de {eq} tras el {rach} en contra: hay que cortar la racha.',
      'El parcial de {rach} obliga a {eq} a detener el juego.',
      'Minuto de {eq}: {crv} corrió {rach} y el entrenador no tiene otra opción.',
      '{ceq} frena el golpe con un tiempo muerto después de un parcial de {rach}.',
    ],
    comentarista: [
      'Ya era hora, venían de palo en palo.',
      'Les pasaron por arriba y tuvieron que frenar.',
      'Cortó el entrenador porque esto se les estaba yendo de las manos.',
      'Hay que cortar el viento en contra.',
    ],
  ),
  Situacion.finCuarto: FrasesSituacion(
    relator: [
      'Termina el {cq}: {parcial}. El marcador general, {marc}.',
      'Final del {cq}. {lider}.',
      'Fin del {cq}: {parcial}. {lider}.',
      '~Se cierra el {cq}. {marc}.',
      '^Se acaba el {cq} y todo sigue abierto: {marc}.',
    ],
    comentarista: [
      'Estuvo para sacarse el sombrero.',
      'Cuarto de mucha tensión: nadie se aflojó.',
      'Tomemos aire, que esto recién empieza.',
      'Qué cuarto: mucha pelea y poco respiro.',
      'Se vienen minutos que van a definir todo.',
    ],
  ),
  Situacion.entretiempo: FrasesSituacion(
    relator: [
      'Descanso: {marc} al final de la primera mitad. {lider}.',
      'Se van al vestuario con {marc}.',
      'Final del primer tiempo: {lider}.',
      'Medio tiempo: {parcial} en el segundo cuarto, {marc} en el global.',
    ],
    comentarista: [
      'A tomar aire y a corregir.',
      'Mitad de partido: se viene lo mejor.',
      'El entretiempo les va a servir para pensar.',
      'Si esto sigue así, la segunda mitad va a ser un infarto.',
    ],
  ),
  Situacion.prorroga: FrasesSituacion(
    relator: [
      'Empate al final del tiempo reglamentario: tiempo suplementario de cinco minutos.',
      '{marc}: empatados, vamos a la prórroga.',
      'No hay ganador tras 48 minutos: prórroga.',
      'Igualdad total: cinco minutos más para definir.',
    ],
    comentarista: [
      '¡Qué barbaridad, no se quiere terminar!',
      '¡Más básquet para el que le guste! ¡Prórroga!',
      'Los nervios no se terminan nunca.',
      'Cinco minutos más de suspenso, qué locura.',
    ],
  ),
  Situacion.finPartido: FrasesSituacion(
    relator: [
      'Final: {gan} se impone a {perd} por {pg}-{pp}.',
      'Se terminó el partido. Victoria de {gan}, {pg}-{pp}. {mejor}',
      'Suena la chicharra final: {gan} {pg}, {perd} {pp}. {mejor}',
      'Concluye el encuentro con triunfo de {gan}, {pg}-{pp}.',
    ],
    comentarista: [
      '¡Qué partido, señores!',
      'A los ganadores, felicitaciones; a los otros, a repasar.',
      'Un partido para recordar.',
      'Eso fue una noche de básquet de verdad.',
      'Qué final, che.',
    ],
  ),

  // ───────────────────────────── Contexto ─────────────────────────────
  Situacion.parcialAFavor: FrasesSituacion(
    relator: [
      'Parcial de {rach} para {ceq}.',
      '{ceq} encadena {rach}: la defensa funciona y el ataque fluye.',
      'Racha de {n} puntos consecutivos de {ceq}.',
      '{ceq} domina este tramo: {rach} sin respuesta.',
    ],
    comentarista: [
      'Qué arrancada tiene {ceq}, parecen otro equipo.',
      'Se están llevando puesto a {rv}.',
      'Cuando {ceq} se pone en marcha no hay quien lo pare.',
      'Esto ya es una avalancha.',
    ],
  ),
  Situacion.parcialEnContra: FrasesSituacion(
    relator: [
      '{crv} no encuentra respuestas: {rach} en su contra.',
      'Parcial desfavorable para {crv}: {n} puntos sin anotar.',
      '{crv} sufre en ataque: lleva varias posesiones sin sumar.',
      'Se complica {crv}: la defensa de {ceq} no deja espacios.',
    ],
    comentarista: [
      '{crv} está en problemas.',
      'Se les apagó la luz, hay que ver si el entrenador reacciona.',
      'Ahí es cuando el técnico tiene que mover el banco.',
      'Están tirando todo mal, no les sale una.',
    ],
  ),
  Situacion.remontada: FrasesSituacion(
    relator: [
      '{ceq} completa la remontada: estaba {dm} abajo y ahora pasa al frente.',
      'De {dm} puntos en contra a liderar el marcador: {ceq} da vuelta el partido.',
      '{ceq} pasa adelante tras estar {dm} abajo.',
      'Remontada de {ceq}: el partido cambia de dueño.',
    ],
    comentarista: [
      '¡Qué carácter, nadie los dio por vivos!',
      '¡Esto era imposible hace un rato y mirá ahora!',
      'Se pusieron la camiseta al hombro.',
      'Eso es no darse por vencido nunca.',
    ],
  ),
  Situacion.finalApretado: FrasesSituacion(
    relator: [
      'Quedan {reloj} y la diferencia es de {dif}: todo se define ahora.',
      'Final de infarto: {marc}, a {reloj} del cierre.',
      'Cada posesión vale oro: {marc} con {reloj} por jugarse.',
      'Partido abierto a falta de {reloj}.',
    ],
    comentarista: [
      'Se me aceleró el corazón.',
      'Esto lo van a recordar...',
      'Esto se define por detalles.',
      'No miro, no miro... bueno, miro.',
      'Qué final, qué final.',
    ],
  ),
  Situacion.rachaTirador: FrasesSituacion(
    relator: [
      '{q} suma {n} triples consecutivos.',
      'Mano caliente de {q}: {n} triples seguidos.',
      '{q} encadena {n} lanzamientos de tres puntos sin fallar.',
      'Tirador encendido: {q} va {n} de {n} desde el perímetro.',
    ],
    comentarista: [
      '¡Está encendido {q}, no hay quien lo pare!',
      'No le erra a nada, parece que el aro fuera una pileta.',
      'Hay que salir a marcarlo a la otra cuadra.',
      'Ese ya no mira el aro, lo siente.',
    ],
  ),
  Situacion.jugadorDominante: FrasesSituacion(
    relator: [
      '{q} está dominando: {linea}.',
      'Noche brillante de {q}: {linea}.',
      'Todo pasa por {q}: {linea}.',
      '{q} impone su ley en ambos lados de la cancha: {linea}.',
    ],
    comentarista: [
      'Está en otra categoría, {q}.',
      'No lo para nadie, parece que juega solo.',
      'Hoy {q} se la come toda.',
      'Que alguien lo detenga, por favor.',
      '{q} se carga el partido al hombro.',
    ],
  ),
  Situacion.dobleDoble: FrasesSituacion(
    relator: [
      'Doble-doble para {q}: {linea}.',
      '{q} alcanza el doble-doble con {linea}.',
      'Línea de doble-doble de {q}: {linea}.',
      'Completa el doble-doble {q}. {linea}.',
    ],
    comentarista: [
      '¡Otro doble-doble en el bolsillo!',
      'Noche redonda de {q}.',
      'Eso es llegar a diez de todo.',
      'Qué completo está {q}.',
    ],
  ),
  Situacion.tripleDoble: FrasesSituacion(
    relator: [
      '¡Triple-doble de {q}! {linea}.',
      '{q} firma un triple-doble: {linea}.',
      'Noche histórica: triple-doble de {q}, {linea}.',
      'Completa el triple-doble {q}: {linea}.',
    ],
    comentarista: [
      '¡Se mandó un triple-doble, me muero!',
      'Eso es lo que se llama jugador total.',
      'Son de esas noches que quedan para el recuerdo.',
      '¡Hace de todo, este {q}!',
    ],
  ),
  Situacion.anotadorAlto: FrasesSituacion(
    relator: [
      '{q} llega a {pts} puntos y es el máximo anotador del partido.',
      'Exhibición ofensiva de {q}: {pts} puntos.',
      '{q} supera los {pts} puntos esta noche.',
      'Producción enorme de {q}: {pts} unidades.',
    ],
    comentarista: [
      '¡Está endemoniado, {q}!',
      'Se anotó la noche, {q}.',
      'Eso no son números, es una exhibición.',
      'Hoy {q} no sabe lo que es fallar.',
    ],
  ),
  Situacion.partidoParejo: FrasesSituacion(
    relator: [
      'El marcador no se despega: {marc}, con {cambios} cambios de líder.',
      'Partido muy parejo: ninguno logra sacar más de {dif} puntos.',
      'Igualdad total en el marcador y en el juego.',
      'Se repiten los cambios de ventaja: partido de ida y vuelta.',
    ],
    comentarista: [
      'Esto está para cualquiera.',
      'Está más parejo que dos mellizos.',
      'Acá nadie se despega, qué disfrute.',
      'No hay caso, se miran de igual a igual.',
      'Cada pelota es una final.',
    ],
  ),
  Situacion.partidoPicado: FrasesSituacion(
    relator: [
      'El partido se ha vuelto físico: se acumulan las infracciones graves y los reclamos.',
      'Aumenta la tensión: contactos fuertes y mucha discusión con los árbitros.',
      'Se endurece el juego: el árbitro debe controlar los ánimos.',
      'Faltas, protestas y empujones: la temperatura sube.',
    ],
    comentarista: [
      'Se está calentando esto, ojo.',
      'Acá alguien va a perder la cabeza.',
      'Se miran feo y eso es peligroso.',
      'Esto ya no es tanto básquet sino otra cosa.',
      'Hay que poner paños fríos, che.',
    ],
  ),
  Situacion.playoffs: FrasesSituacion(
    relator: [
      '{ronda}, {juego}: {serie}.',
      'Estamos en playoffs: cada posesión cuenta doble.',
      'En esta instancia no hay margen de error.',
      'Playoffs: el ritmo es otro, la defensa es otra.',
    ],
    comentarista: [
      'En playoffs no se regala nada.',
      'Esto es otra cosa, esto es primavera de playoffs.',
      'Se juega con el cuchillo entre los dientes.',
      'Acá nadie tiene miedo de dejarlo todo en la cancha.',
    ],
  ),
  Situacion.eliminacion: FrasesSituacion(
    relator: [
      'Partido de eliminación: el que pierda hoy queda al borde del abismo. {serie}.',
      'Una derrota hoy puede cerrar la serie: {serie}.',
      'Sin margen: {serie} y la serie puede terminar esta noche.',
      'Cada error se paga muy caro: se juega la continuidad en el torneo.',
    ],
    comentarista: [
      'Hoy se juega la vida.',
      'Hoy no se especula: es ganar o irse a casa.',
      'No hay mañana, hay solo este partido.',
      'El que se distraiga, se queda mirando desde afuera.',
    ],
  ),
  Situacion.clutch: FrasesSituacion(
    relator: [
      'Entramos en tiempo decisivo: {marc} con {reloj}.',
      'Últimos minutos y el marcador no se define.',
      'Quedan {reloj}: las posesiones clave serán de los líderes.',
      'Momento clutch: diferencia de {dif} con {reloj}.',
    ],
    comentarista: [
      'Ahora sí, a apretar los dientes.',
      'Los jugadores grandes aparecen en esto.',
      '¡Esto es lo que vinimos a ver!',
      'Acá se separa a los valientes de los demás.',
    ],
  ),
  Situacion.apertura: FrasesSituacion(
    relator: [
      'Muy buenas noches y bienvenidos a la transmisión: {cloc} recibe a {nvis} en {ciudad}.',
      'Comenzamos desde {ciudad}: {nloc} frente a {nvis}.',
      'Todo listo en {ciudad} para el duelo entre {nloc} y {nvis}.',
    ],
    comentarista: [
      '¡Buenas noches! Noche de básquet en {ciudad}: {nloc} y {nvis} se miden.',
      'Arrancamos desde {ciudad} y se anuncia una noche larga.',
      'Bienvenidos: {nloc} y {nvis}, un duelo que promete.',
      'Qué noche para estar en {ciudad}, con la cancha llena y las ganas a tope.',
    ],
  ),
  Situacion.arranque: FrasesSituacion(
    relator: [
      'Sube la pelota: comienza el partido.',
      'Salto inicial y arranca el juego.',
      'Se pone en movimiento el reloj: primer cuarto.',
    ],
    comentarista: [
      'Que salte la pelota, que ya no aguanto.',
      'A ver quién larga mejor.',
      'Vamos que arranca esto, con todo.',
      'Se viene lindo, se viene.',
    ],
  ),
  Situacion.historial: FrasesSituacion(
    relator: [
      'En lo que va de la temporada, {cusuario} ganó {hv} y perdió {hd} frente a {rival}.',
      'Historial reciente: {hv}-{hd} para {usuario} contra {rival}.',
      'El último cruce entre ambos fue {ultimo}.',
      'Estos equipos ya se vieron las caras: {usuario} {hv}, {rival} {hd}.',
    ],
    comentarista: [
      'Estos dos ya se conocen, y no se tienen mucho cariño.',
      'Ojo con la revancha, que está picante.',
      'Siempre es especial cuando se encuentran.',
      'Hay cuentas pendientes.',
    ],
  ),
  Situacion.serie: FrasesSituacion(
    relator: [
      '{ronda}, {juego}: {serie}.',
      '{serie}; el que gane hoy toma ventaja.',
      'Serie de playoffs, {juego}: {serie}.',
      'Se disputa el {juego}: {serie}.',
    ],
    comentarista: [
      'La serie está para cualquiera.',
      'Esto se pone bueno.',
      'Cada partido de la serie vale oro.',
      'Se va definiendo, partido a partido.',
    ],
  ),
  Situacion.localia: FrasesSituacion(
    relator: [
      'Con {nloc} en casa, el público juega de su lado.',
      'La localía pesa: {nloc} está en su cancha y se nota.',
      '{cvis} visita una cancha complicada en {ciudad}.',
    ],
    comentarista: [
      'Con el público a favor es otra cosa.',
      'La cancha empuja, se siente.',
      'Jugar de local ayuda, y mucho.',
      'Esa tribuna es un jugador más.',
    ],
  ),
  Situacion.record: FrasesSituacion(
    relator: [
      '{cusuario} llega con récord de {vic}-{der}{racha}.',
      'Balance de {vic} victorias y {der} derrotas para {usuario}{racha}.',
      '{usuario}, con {vic}-{der} en la temporada{racha}.',
    ],
    comentarista: [
      'Veremos si mantienen el nivel.',
      'Los números dicen una cosa, la cancha dice otra.',
      'La temporada es larga y cada partido suma.',
      'Eso es trabajo de todo el año.',
    ],
  ),
  Situacion.rivalidad: FrasesSituacion(
    relator: ['Duelo con historia: {riv}.', 'Un cruce con mucho en juego: {riv}.', 'Atención a la rivalidad: {riv}.'],
    comentarista: [
      'Rivalidad de verdad: hay mucha tela para cortar.',
      'Estos partidos no se juegan, se pelean.',
      'Cuando se ven estos dos, vuelan chispas.',
      'Hay algo extra en el aire.',
    ],
  ),
  Situacion.recordEnJuego: FrasesSituacion(
    relator: ['Dato de la noche: {rec}.', 'Atención a este número: {rec}.', 'Hay un registro en juego: {rec}.'],
    comentarista: ['Atentos a eso: {rec}.', 'Mirá que está cerca: {rec}.', 'Qué lindo sería verlo hoy: {rec}.'],
  ),
  Situacion.historiaTemporada: FrasesSituacion(
    relator: ['Contexto de la temporada: {hist}.', 'Para ubicarnos: {hist}.', 'Vale recordar que {hist}.'],
    comentarista: [
      'Eso pesa en la cabeza del equipo.',
      'La historia de la temporada se juega acá.',
      'Se siente en el ambiente, eh.',
    ],
  ),
  Situacion.fatiga: FrasesSituacion(
    relator: [
      '{q} muestra signos de cansancio: lleva muchos minutos en cancha.',
      'Las piernas de {q} ya no responden como al principio.',
      'El desgaste se nota: {q} necesita descanso.',
      'La fatiga empieza a pesar en {q}.',
    ],
    comentarista: [
      'Al pobre {q} se le acabó la batería.',
      'Ya no da más, mirá cómo respira.',
      'Hay que sentarlo un rato, las piernas no mienten.',
      'Está agotado, se le nota hasta en la cara.',
    ],
  ),
  Situacion.tramite: FrasesSituacion(
    relator: [
      '{ganando} amplía la ventaja a {dif} puntos y el partido parece decidido.',
      'La diferencia ya es de {dif}: difícil la remontada.',
      'Con {dif} arriba, {ganando} maneja el ritmo.',
      '~{ganando} controla con comodidad: {marc}.',
    ],
    comentarista: [
      'Esto ya está, che.',
      'Se terminó la historia, a pensar en el próximo.',
      'Pan comido para {ganando}.',
      'Con esta ventaja ya pueden dormir tranquilos.',
    ],
  ),
  Situacion.retoma: FrasesSituacion(
    relator: [
      'Retomamos la transmisión: {marc}, {cq} con {reloj} por jugarse.',
      'Volvemos al partido: {lider}. Quedan {reloj} del {cq}.',
      'Al reanudar el relato: {marc}, {cq}, {reloj} en el reloj.',
    ],
    comentarista: [
      'Nos perdimos un rato, pero acá seguimos.',
      'Se nos pasó volando, y mirá cómo está esto.',
      'Volvemos justo a lo mejor.',
      'A ver cómo viene la mano ahora.',
    ],
  ),
  Situacion.ritmoAlto: FrasesSituacion(
    relator: [
      'Ritmo alto de ambos equipos: muchas posesiones y poco descanso.',
      'El partido se juega a gran velocidad: transiciones rápidas en las dos canchas.',
      'Pocos segundos por posesión: ritmo de carrera.',
    ],
    comentarista: [
      'Esto es una carrera, no se paran.',
      'No paran ni para respirar.',
      'Se corre como si no hubiera mañana en la cancha.',
    ],
  ),
  Situacion.ritmoBajo: FrasesSituacion(
    relator: [
      'Ritmo pausado: los dos equipos consumen casi todo el reloj de posesión.',
      'Partido de pocas posesiones: la defensa manda.',
      'Juego estático, se busca el mejor tiro hasta el final de los 24 segundos.',
    ],
    comentarista: [
      'Esto es ajedrez, cada movimiento se piensa.',
      'Se están estudiando, nadie se apura.',
      'Parsimonia total, che.',
    ],
  ),
};
