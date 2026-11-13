import 'dart:math';

import 'entities/jugador.dart';
import 'motor.dart';
import 'premios.dart' show apellido;

/// Relator rioplatense: convierte cada jugada en una frase con personalidad, según el tipo de
/// jugada y el momento del partido (empate, lo da vuelta, final apretado).
class Relator {
  Relator({Random? azar}) : _azar = azar ?? Random();

  final Random _azar;
  int _ultimaDiferencia = 0;

  String _apellido(Jugador? j) => j == null ? '' : apellido(j);
  String _uno(List<String> opciones) => opciones[_azar.nextInt(opciones.length)];

  /// Frase para una jugada. [jugadores]: todos los del partido por id de carta.
  String frase(EventoPartido e, Map<String, Jugador> jugadores) {
    final quien = _apellido(jugadores[e.jugadorId]);
    final asistente = _apellido(jugadores[e.asistenteId]);
    final defensor = _apellido(jugadores[e.defensorId]);
    final participante = _apellido(jugadores[e.participanteId]);
    final rebote = _apellido(jugadores[e.reboteId]);
    final diferencia = e.marcadorLocal - e.marcadorVisitante;
    final cambioDeMando = _ultimaDiferencia != 0 && diferencia != 0 && diferencia.sign != _ultimaDiferencia.sign;
    final empata = diferencia == 0 && _ultimaDiferencia != 0;
    final finalApretado = e.cuarto >= 4 && e.reloj <= 120 && diferencia.abs() <= 5;
    _ultimaDiferencia = diferencia;

    final base = switch (e.tipo) {
      TipoEvento.tiro when e.convertido && e.desdeLejos => _uno([
        '¡NO PUEDE SER! ¡$quien desde la otra mitad, SOBRE LA CHICHARRA!',
        '¡DESDE SU CASA! ¡$quien la tiró de todo el largo y entró con la chicharra!',
      ]),
      TipoEvento.tiro when e.desdeLejos => _uno([
        'Se termina el cuarto: $quien la tira desde la otra mitad… no.',
        'Lanzamiento desesperado de $quien con la chicharra: ni cerca.',
        '$quien prueba desde lejísimos sobre la bocina: afuera.',
      ]),
      TipoEvento.tiro when e.convertido && e.interferencia => _uno([
        '¡Interferencia de $defensor! La tocó bajando: los dos puntos son de $quien.',
        'Tapón ilegal de $defensor, la pelota ya bajaba: canasta para $quien.',
      ]),
      TipoEvento.tiro when e.convertido && e.chicharra => _uno([
        '¡SOBRE LA CHICHARRA! $quien ${e.triple ? 'la clavó de tres' : 'la metió'} con el reloj en cero.',
        '¡Con la bocina! $quien cierra el cuarto con ${e.triple ? 'un triple' : 'un doble'}.',
      ]),
      TipoEvento.tiro when e.convertido && e.alleyOop => _uno([
        '¡ALLEY-OOP! $asistente la tiró al cielo y $quien la bajó con todo.',
        '¡Qué conexión! Pase alto de $asistente y $quien la colgó del aro.',
      ]),
      TipoEvento.tiro when e.convertido && e.volcada => _uno([
        '¡LA COLGÓ $quien! ¡Se viene abajo el estadio!',
        '¡Volcadón de $quien! Eso no se marca, eso se sufre.',
        '¡Arriba del aro $quien, y la mete con violencia!',
      ]),
      TipoEvento.tiro when e.convertido && e.triple => _uno([
        '¡Adentro, señores! Triple de $quien.',
        '¡Bombazo de $quien desde lejísimos!',
        '¡De tres $quien, y la red ni se movió!',
        if (asistente.isNotEmpty) 'La movió $asistente, la clavó $quien: ¡triple!',
      ]),
      TipoEvento.tiro when e.convertido && e.contraataque => _uno([
        'Contragolpe letal: $quien se fue solo y no perdonó.',
        '¡Corrida y adentro! $quien en transición.',
      ]),
      TipoEvento.tiro when e.convertido => _uno([
        'Doble de $quien.',
        if (asistente.isNotEmpty) 'Buena asistencia de $asistente y $quien suma dos.',
        '$quien la deja suave contra el tablero.',
        '$quien, de media distancia: dos más.',
      ]),
      TipoEvento.tiro when e.taponado && e.reboteOfensivo => _uno([
        '¡TAPÓN de $defensor a $quien! Pero la recupera $rebote: sigue el ataque.',
        '¡Le pusieron una tapa a $quien! $rebote la rescata y siguen con la pelota.',
      ]),
      TipoEvento.tiro when e.taponado => _uno([
        '¡TAPÓN de $defensor! ¡Ahí no, $quien!',
        '¡Se la mandó a la tribuna! Tapa $defensor.',
        '¡Qué tapa, señores! $defensor le dijo que no a $quien.',
        '¡Rechazo de $defensor! $quien se comió la tapa.',
      ]),
      TipoEvento.tiro when e.reboteOfensivo => _uno([
        'La erró $quien pero $rebote pelea el rebote ofensivo: segunda chance.',
        'No entra… ¡y $rebote la recupera arriba!',
      ]),
      TipoEvento.tiro => _uno([
        'La erró $quien. Rebote de $rebote.',
        'No quiso entrar el de $quien; la toma $rebote.',
        '$quien tira… ¡afuera! Controla $rebote.',
      ]),
      TipoEvento.libres =>
        e.puntos == (e.triple ? 3 : 2)
            ? _uno(['Falta sobre $quien, que no falla desde la línea.', '$quien, perfecto en los libres.'])
            : e.puntos == 0
            ? _uno(['¡Se le escaparon los dos libres a $quien!', 'Ladrillo y ladrillo para $quien en la línea.'])
            : 'Falta sobre $quien: mete ${e.puntos} de ${e.triple ? 3 : 2}.',
      TipoEvento.perdida when e.defensorId != null => _uno([
        '¡Se la robó $defensor! Y se va de contra.',
        '¡Manotazo de $defensor! Le sacó la pelota a $quien.',
        '¡Lectura perfecta de $defensor, que corta el pase!',
      ]),
      TipoEvento.perdida => switch (e.perdida) {
        TipoPerdida.carga => _uno([
          '¡Falta en ataque de $quien! $participante plantó los pies y recibió la carga.',
          '¡Carga! $quien se lo llevó puesto a $participante: pelota para el rival.',
          '$participante se quedó parado y aguantó el impacto: falta en ataque de $quien.',
        ]),
        TipoPerdida.veinticuatro => _uno([
          '¡Violación de 24 segundos! No encontraron el tiro.',
          'Suena la bocina de posesión: se les fueron los 24 segundos.',
        ]),
        TipoPerdida.tresSegundos => _uno([
          'Tres segundos en la zona: $quien se quedó plantado en la pintura.',
          'Cobran tres segundos a $quien. Pelota para el otro lado.',
        ]),
        TipoPerdida.campoAtras => _uno([
          '¡Campo atrás! $quien volvió a su mitad con la pelota.',
          '$quien cruzó la mitad y se le escapó para atrás: campo atrás.',
        ]),
        TipoPerdida.pasos => _uno(['Pasos de $quien, cobra el árbitro.', '$quien arrancó sin picar: ¡caminó!']),
        TipoPerdida.dobles => _uno([
          'Doble dribbling de $quien. Error de principiante.',
          '$quien volvió a picar después de agarrarla: dobles.',
        ]),
        _ => _uno([
          'Pérdida de $quien: la pelota se fue afuera.',
          'Error no forzado de $quien: se le fue por el costado.',
          'Pase de $quien a la tribuna. Cambio de posesión.',
        ]),
      },
      TipoEvento.falta => switch (e.falta) {
        TipoFalta.tecnica => _uno([
          '¡Técnica para $defensor! Protestó de más. $quien ${_libresTexto(e)}',
          'Se calentó $defensor y el árbitro le cobró técnica. $quien ${_libresTexto(e)}',
        ]),
        TipoFalta.flagrante => _uno([
          '¡FLAGRANTE de $defensor! Le pegó fuerte a $quien. ${_libresTexto(e)} y la pelota sigue siendo de ellos.',
          '¡Durísimo $defensor! Falta flagrante sobre $quien: ${_libresTexto(e)} y posesión.',
        ]),
        TipoFalta.intencional => _uno([
          'Falta intencional de $defensor: la manda a la línea a propósito. $quien ${_libresTexto(e)}',
          'Paran el reloj: $defensor hace falta enseguida para mandar a $quien a la línea. ${_libresTexto(e)}',
        ]),
        TipoFalta.bonus => _uno([
          '¡Están en bonus! Falta de $defensor y $quien va a la línea: ${_libresTexto(e)}',
          'Quinta falta del equipo en el cuarto: libres para $quien. ${_libresTexto(e)}',
        ]),
        _ => _uno([
          'Falta de $defensor sobre $quien. Saque lateral.',
          'Le cobran falta a $defensor por meter la mano. Siguen atacando.',
          'Falta en la marca de $defensor: saque desde el costado.',
        ]),
      },
      TipoEvento.salto => _uno([
        'Pelota retenida entre $quien y $defensor: salto entre dos… ¡la gana ${e.convertido ? quien : defensor}!',
        '¡Se la disputan $quien y $defensor! Salto entre dos y se queda con ella ${e.convertido ? quien : defensor}.',
      ]),
      TipoEvento.cambio => e.texto,
      TipoEvento.tiempoMuerto => _uno(['Tiempo muerto. A acomodar las ideas.', 'Pide minuto el entrenador.']),
      TipoEvento.finCuarto => e.texto,
      TipoEvento.finPartido => _uno([
        '¡Terminó el partido! ${e.marcadorLocal}-${e.marcadorVisitante}.',
        'Suena la chicharra: ${e.marcadorLocal}-${e.marcadorVisitante}, final.',
      ]),
    };

    final remate = StringBuffer(base);
    if (e.expulsadoId case final id?) {
      remate.write(
        e.falta == TipoFalta.tecnica
            ? ' ¡Segunda técnica de ${_apellido(jugadores[id])}: expulsado!'
            : ' ¡Sexta falta de ${_apellido(jugadores[id])}: afuera!',
      );
    }
    if (e.puntos > 0 && e.tipo != TipoEvento.libres && e.tipo != TipoEvento.falta) {
      if (cambioDeMando) {
        remate.write(_uno([' ¡Y lo da vuelta!', ' ¡Pasan al frente!']));
      } else if (empata) {
        remate.write(' ¡Empate!');
      } else if (finalApretado) {
        remate.write(_uno([' ¡Partido abierto!', ' ¡Esto es infarto!']));
      }
    }
    if (e.texto.contains('Sangre fría')) remate.write(' ¡Sangre fría, eh!');
    return remate.toString();
  }

  /// "mete 2 de 2", "falla el libre"…
  String _libresTexto(EventoPartido e) => e.libres == 1
      ? (e.puntos == 1 ? 'Adentro el libre.' : 'Falla el libre.')
      : e.puntos == e.libres
      ? 'Mete ${e.puntos} de ${e.libres}.'
      : e.puntos == 0
      ? '¡Falla los ${e.libres}!'
      : 'Mete ${e.puntos} de ${e.libres}.';
}
