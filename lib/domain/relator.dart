import 'dart:math';

import 'entities/jugador.dart';
import 'motor.dart';

/// Relator rioplatense: convierte cada jugada en una frase con personalidad, según el tipo de
/// jugada y el momento del partido (empate, lo da vuelta, final apretado).
class Relator {
  Relator({Random? azar}) : _azar = azar ?? Random();

  final Random _azar;
  int _ultimaDiferencia = 0;

  String _apellido(Jugador? j) => j == null ? '' : j.nombre.split(' ').last;
  String _uno(List<String> opciones) => opciones[_azar.nextInt(opciones.length)];

  /// Frase para una jugada. [jugadores]: todos los del partido por id de carta.
  String frase(EventoPartido e, Map<String, Jugador> jugadores) {
    final quien = _apellido(jugadores[e.jugadorId]);
    final asistente = _apellido(jugadores[e.asistenteId]);
    final defensor = _apellido(jugadores[e.defensorId]);
    final rebote = _apellido(jugadores[e.reboteId]);
    final diferencia = e.marcadorLocal - e.marcadorVisitante;
    final cambioDeMando = _ultimaDiferencia != 0 && diferencia != 0 && diferencia.sign != _ultimaDiferencia.sign;
    final empata = diferencia == 0 && _ultimaDiferencia != 0;
    final finalApretado = e.cuarto >= 4 && e.reloj <= 120 && diferencia.abs() <= 5;
    _ultimaDiferencia = diferencia;

    final base = switch (e.tipo) {
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
      TipoEvento.tiro when e.taponado => _uno([
        '¡TAPÓN de $defensor! ¡Ahí no, $quien!',
        '¡Se la mandó a la tribuna! Tapa $defensor.',
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
      TipoEvento.perdida => _uno([
        'Pérdida de $quien: la pelota se fue afuera.',
        'Error no forzado de $quien. Cambio de posesión.',
        'Pasos de $quien, cobra el árbitro.',
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
    if (e.expulsadoId != null) remate.write(' ¡Sexta falta de ${_apellido(jugadores[e.expulsadoId])}: afuera!');
    if (e.puntos > 0 && e.tipo != TipoEvento.libres) {
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
}
