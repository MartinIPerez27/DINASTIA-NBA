import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';
import 'carta_jugador.dart';
import 'escudo.dart';
import 'jugador_avatar.dart';
import 'texto_led.dart';

/// Proporción de las cartas verticales (ancho / alto).
const proporcionCarta = 0.66;

String _codigoEpoca(Epoca e) => switch (e) {
  Epoca.anios80 => '80s',
  Epoca.anios90 => '90s',
  Epoca.anios2000 => '00s',
  Epoca.anios2010 => '10s',
  Epoca.actualidad => 'HOY',
};

String _codigoPosicion(String etiqueta) => switch (etiqueta) {
  'ALA-PÍVOT' => 'AP',
  'PÍVOT' => 'PIV',
  'SEXTO HOMBRE' => '6TO',
  _ => etiqueta.substring(0, 3),
};

/// Carta de draft vertical: media en LED grande, foto, apellido y PPP/RPP/APP/IQ.
/// Los LED de cada carta usan el color de SU franquicia; el marco se enciende según la rareza.
class CartaVertical extends StatelessWidget {
  const CartaVertical({super.key, required this.jugador, this.seleccionada = false});

  final Jugador jugador;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final franquicia = franquiciaPorId(jugador.franquiciaId);
    final led = colorLed(franquicia);
    final s = jugador.stats;
    final partes = jugador.nombre.split(' ');
    final apellido = partes.length > 1 ? partes.sublist(1).join(' ') : jugador.nombre;
    final (grosor, colorMarco) = switch (jugador.tier) {
      _ when seleccionada => (3.0, led),
      Tier.sPlus => (2.5, led),
      Tier.s => (1.5, led.withValues(alpha: 0.7)),
      Tier.a => (1.0, esquema.outlineVariant),
    };

    return AspectRatio(
      aspectRatio: proporcionCarta,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: esquema.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(w * 0.09),
              border: Border.all(color: colorMarco, width: grosor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.09 - grosor),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (jugador.tier != Tier.a) CustomPaint(painter: GrillaLedPainter(led.withValues(alpha: 0.10))),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Media, posición, escudo y época.
                      Padding(
                        padding: EdgeInsets.fromLTRB(w * 0.07, w * 0.06, w * 0.07, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextoLed('${jugador.media}', tamano: w * 0.27, color: led),
                                    Row(
                                      children: [
                                        Text(
                                          _codigoPosicion(jugador.posiciones.first.etiqueta),
                                          style: TextStyle(
                                            fontFamily: Fuentes.estadio,
                                            fontVariations: const [FontVariation.weight(700)],
                                            fontSize: w * 0.11,
                                            color: esquema.onSurfaceVariant,
                                            height: 1,
                                          ),
                                        ),
                                        SizedBox(width: w * 0.04),
                                        TextoLed(CartaJugador.codigoTier(jugador.tier), tamano: w * 0.1, color: led),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Escudo(franquicia, tamano: w * 0.2),
                                SizedBox(height: w * 0.02),
                                TextoLed(_codigoEpoca(jugador.epoca), tamano: w * 0.1, color: esquema.onSurfaceVariant),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                          child: JugadorAvatar(jugador: jugador, franquicia: franquicia, recortar: true),
                        ),
                      ),
                      // Apellido sobre una placa con el color de la franquicia de la carta.
                      ColoredBox(
                        color: led,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: w * 0.015),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              apellido.toUpperCase(),
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: Fuentes.estadio,
                                fontVariations: const [FontVariation.weight(800)],
                                fontSize: w * 0.15,
                                height: 1.05,
                                letterSpacing: 0.5,
                                color: led.computeLuminance() > 0.3 ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(w * 0.05, w * 0.04, w * 0.05, w * 0.05),
                        child: Row(
                          children: [
                            for (final (sigla, valor) in [
                              ('PPP', s.ppp.toStringAsFixed(0)),
                              ('RPP', s.rpp.toStringAsFixed(0)),
                              ('APP', s.app.toStringAsFixed(0)),
                              ('IQ', '${s.iq}'),
                            ])
                              Expanded(
                                child: Column(
                                  children: [
                                    FittedBox(
                                      child: TextoLed(valor, tamano: w * 0.12, color: esquema.onSurface),
                                    ),
                                    FittedBox(
                                      child: Text(
                                        sigla,
                                        style: TextStyle(fontSize: w * 0.075, color: esquema.onSurfaceVariant),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dorso de la carta: el panel del tablero. [carga] (0–1) enciende los LED del dorso de abajo
/// hacia arriba en [color]: así "carga" una carta rara antes de darse vuelta.
class DorsoCarta extends StatelessWidget {
  const DorsoCarta({super.key, this.carga = 0, required this.color});

  final double carga;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: proporcionCarta,
      child: LayoutBuilder(
        builder: (context, c) => DecoratedBox(
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(c.maxWidth * 0.09),
            border: Border.all(color: Color.lerp(esquema.outlineVariant, color, carga)!, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(c.maxWidth * 0.09),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: GrillaLedPainter(esquema.onSurface.withValues(alpha: 0.07), encendidos: color, carga: carga),
                ),
                Center(
                  child: TextoLed(
                    '82-0',
                    tamano: c.maxWidth * 0.2,
                    color: Color.lerp(esquema.onSurfaceVariant, color, carga),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grilla de LED. Con [carga] > 0, los puntos se encienden en [encendidos] desde abajo.
class GrillaLedPainter extends CustomPainter {
  const GrillaLedPainter(this.apagados, {this.encendidos, this.carga = 0});

  final Color apagados;
  final Color? encendidos;
  final double carga;

  @override
  void paint(Canvas canvas, Size size) {
    const paso = 7.0;
    final apagado = Paint()..color = apagados;
    final encendido = Paint()..color = encendidos ?? apagados;
    final limite = size.height * (1 - carga);
    for (var y = paso / 2; y < size.height; y += paso) {
      for (var x = paso / 2; x < size.width; x += paso) {
        canvas.drawCircle(Offset(x, y), 1.3, y >= limite && carga > 0 ? encendido : apagado);
      }
    }
  }

  @override
  bool shouldRepaint(GrillaLedPainter a) => a.apagados != apagados || a.encendidos != encendidos || a.carga != carga;
}
