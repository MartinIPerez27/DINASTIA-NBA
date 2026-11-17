import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/franquicia.dart';
import '../tema/tema_franquicia.dart';
import 'jugadores_animados.dart';
import 'publico.dart';

/// Cancha completa vista desde arriba, en pies: 50 de ancho, 94 de largo (aro de arriba en y=5.25).
abstract final class Cancha94 {
  static const ancho = 50.0, largo = 94.0, borde = 6.0;
  static Offset aro(bool arriba) => Offset(25, arriba ? 5.25 : largo - 5.25);
}

class Ficha {
  const Ficha({
    required this.posicion,
    required this.relleno,
    required this.texto,
    required this.etiqueta,
    this.nombre,
    this.conBalon = false,
    this.opacidad = 1,
    this.ribete,
    this.energia = 1,
    this.salto = 0,
    this.postura,
    this.semilla = 0,
    this.enLlamas = false,
    this.esTecnico = false,
  });

  /// Entrenador (traje, sin aro de energía).
  final bool esTecnico;

  /// Cuerpo animado (hacia dónde mira, brazos, ánimo). Sin él, está parado mirando hacia arriba.
  final PosturaJugador? postura;

  /// Para el tono de piel y los gestos propios (estable por jugador).
  final int semilla;

  /// El tirador "en llamas" (racha de aciertos): fuego y brillo alrededor.
  final bool enLlamas;

  final Offset posicion; // en pies

  /// Cuánto está saltando (0 = en el piso, 1 = en lo más alto): la ficha crece y su sombra se aleja.
  final double salto;
  final Color relleno;
  final Color texto;
  final String etiqueta;

  /// Apellido que se muestra bajo la ficha (solo para quien tiene la pelota).
  final String? nombre;
  final bool conBalon;
  final double opacidad;

  /// Segundo color de la camiseta (ribete del cuello y las sisas).
  final Color? ribete;

  /// Estamina 0–1: el aro de energía alrededor de la ficha se va apagando.
  final double energia;
}

/// Atmósfera del estadio: tribuna, banco de suplentes, luz y destellos del cartel LED.
class AmbienteCancha {
  const AmbienteCancha({
    this.publico = const PublicoEstado(),
    this.luzDramatica = 0,
    this.destello = 0,
    this.bancoAtaque,
    this.bancoDefensa,
    this.levantadoAtaque = 0,
    this.levantadoDefensa = 0,
    this.tecnicos = const [],
    this.humo = 0,
  });

  final PublicoEstado publico;

  /// 0–1: playoffs y final apretado oscurecen los bordes y dejan la luz sobre la cancha.
  final double luzDramatica;

  /// 0–1: el cartel LED y la luz se encienden un instante (canasta grande).
  final double destello;

  /// Colores (camiseta, ribete) del banco del equipo que ataca y del que defiende.
  final (Color, Color)? bancoAtaque, bancoDefensa;

  /// Qué tan de pie están los suplentes (festejan una jugada grande o un tiempo muerto).
  final double levantadoAtaque, levantadoDefensa;
  final List<Ficha> tecnicos;

  /// 0–1: humo del tirador encendido que sube del piso.
  final double humo;

  /// Lo mismo con el banco y los técnicos de la jugada puestos.
  AmbienteCancha conEscena({
    required (Color, Color) bancoAtaque,
    required (Color, Color) bancoDefensa,
    required List<Ficha> tecnicos,
  }) => AmbienteCancha(
    publico: publico,
    luzDramatica: luzDramatica,
    destello: destello,
    bancoAtaque: bancoAtaque,
    bancoDefensa: bancoDefensa,
    levantadoAtaque: levantadoAtaque,
    levantadoDefensa: levantadoDefensa,
    tecnicos: tecnicos,
    humo: humo,
  );
}

/// Lo que le pasa al aro de un lado: la red se sacude al entrar la pelota o el aro vibra al rebotar.
class EfectoAro {
  const EfectoAro({required this.arriba, required this.progreso, required this.adentro, this.fuerte = false});

  final bool arriba;
  final double progreso; // 0–1
  final bool adentro;

  /// Volcada: además de la red, tiembla todo el aro y el tablero.
  final bool fuerte;
}

/// "+2"/"+3" que sube desde el aro al anotar.
class Tanto {
  const Tanto(this.texto, this.posicion, this.progreso);

  final String texto;
  final Offset posicion;
  final double progreso; // 0–1
}

/// Estética de la cancha y la pelota (cosméticos del pase de temporada). La de fábrica es la de
/// siempre: parquet moderno y pelota naranja.
class EstiloCancha {
  const EstiloCancha({
    this.id = 'moderna',
    this.superficie = SuperficieCancha.parquet,
    this.madera = const Color(0xFFA2724A),
    this.opacidadPintura = 1,
    this.pelota = const [Color(0xFFE8792B)],
    this.costura = const Color(0xFF3A1A08),
  });

  /// Para el caché del piso.
  final String id;
  final SuperficieCancha superficie;
  final Color madera;

  /// Pintura de la zona: 1 = nueva; menos, gastada.
  final double opacidadPintura;

  /// Un color (lisa) o varios (paneles, como la pelota ABA).
  final List<Color> pelota;
  final Color costura;
}

enum SuperficieCancha { parquet, cuadros, cemento }

/// Transmisión 2D (GDD §6): cancha del usuario vista desde arriba con una cámara que sigue la jugada,
/// 10 fichas, balón con estela y sombra según la altura, y la luz del estadio.
class CanchaPartidoPainter extends CustomPainter {
  CanchaPartidoPainter({
    required this.franquicia,
    required this.fichas,
    required this.balon,
    required this.camaraY,
    required this.colorLed,
    this.alturaBalon = 0,
    this.estela = const [],
    this.tanto,
    this.margenArriba = 0,
    this.margenAbajo = 0,
    this.camaraX = Cancha94.ancho / 2,
    this.zoom = 1,
    this.escudo,
    this.efectoAro,
    this.cartel = '',
    this.tiempo = 0,
    this.estilo = const EstiloCancha(),
    this.ambiente = const AmbienteCancha(),
    this.temblor = Offset.zero,
  });

  final AmbienteCancha ambiente;

  /// Sacudida de la cámara en píxeles (impacto de una volcada o un tapón).
  final Offset temblor;

  /// Piso y pelota (cosméticos).
  final EstiloCancha estilo;

  /// Centro horizontal de la toma (en pies) y acercamiento (1 = cancha de lado a lado).
  final double camaraX, zoom;

  /// Escudo de la franquicia, pintado en el círculo central (GDD §2.2).
  final ui.Image? escudo;

  final EfectoAro? efectoAro;

  /// Texto de los carteles LED a los costados, y el tiempo (s) para que corra.
  final String cartel;
  final double tiempo;

  /// Píxeles tapados por el marcador (arriba) y el zócalo (abajo): la cámara puede pasarse del
  /// fondo para que el aro nunca quede debajo de un gráfico.
  final double margenArriba, margenAbajo;

  final Franquicia franquicia;
  final List<Ficha> fichas;
  final Offset balon;
  final double alturaBalon; // 0 = en la mano; 1 = punto más alto del tiro
  final List<Offset> estela;
  final double camaraY; // centro vertical de la vista, en pies
  final Color colorLed;
  final Tanto? tanto;

  static final _piso = <String, ui.Picture>{};

  /// El piso (madera, pintura, líneas, nombres, escudo) se dibuja una vez por franquicia y escala.
  ui.Picture _pisoCacheado(double pie) {
    final clave = '${franquicia.id}-${pie.toStringAsFixed(2)}-${escudo != null}-${estilo.id}';
    return _piso[clave] ??= () {
      final grabador = ui.PictureRecorder();
      _dibujarPiso(Canvas(grabador), pie);
      return grabador.endRecording();
    }();
  }

  static double altoVisible(Size size) => size.height / (size.width / (Cancha94.ancho + 2 * Cancha94.borde));

  @override
  void paint(Canvas canvas, Size size) {
    final pie = size.width / (Cancha94.ancho + 2 * Cancha94.borde);
    final escala = pie * zoom;
    final alto = size.height / escala, ancho = size.width / escala;
    final arribaMin = -Cancha94.borde - margenArriba / escala;
    final arriba = (camaraY - alto / 2).clamp(
      arribaMin,
      max(arribaMin, Cancha94.largo + Cancha94.borde + margenAbajo / escala - alto),
    );
    // max(): sin zoom la cancha entra justa y el redondeo no puede dejar el tope por debajo del piso.
    final izquierda = (camaraX - ancho / 2).clamp(
      -Cancha94.borde,
      max(-Cancha94.borde, Cancha94.ancho + Cancha94.borde - ancho),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(temblor.dx, temblor.dy);
    canvas.scale(zoom);
    canvas.translate(-(izquierda + Cancha94.borde) * pie, -(arriba + Cancha94.borde) * pie);
    canvas.drawPicture(_pisoCacheado(pie));
    Offset p(Offset o) => Offset((o.dx + Cancha94.borde) * pie, (o.dy + Cancha94.borde) * pie);
    Publico.dibujar(
      canvas,
      pie,
      ambiente.publico,
      tiempo,
      Color(franquicia.colorSecundario),
      colorLed,
      visible: Rect.fromLTWH(izquierda.toDouble(), arriba.toDouble(), ancho, alto),
    );
    _carteles(canvas, pie);
    _banco(canvas, p, pie);

    // Fichas: figuras animadas. Los que saltan, arriba de todo (y el que tiene la pelota arriba de los
    // que no saltan). Los técnicos van con ellos.
    final radioBase = 2.1 * pie;
    int capa(Ficha f) => f.salto > 0 ? 2 : (f.conBalon ? 1 : 0);
    final todas = [...ambiente.tecnicos, ...fichas]..sort((a, b) => capa(a).compareTo(capa(b)));
    for (final f in todas) {
      final c = p(f.posicion);
      final a = f.opacidad;
      final radio = radioBase * (1 + 0.3 * f.salto.clamp(0.0, 1.0));
      final postura = f.postura ?? const PosturaJugador();
      if (f.enLlamas) _llamas(canvas, c, pie, postura.rumbo, a);
      // Aro de energía: completo con el tanque lleno, se acorta (y se pone ámbar) con el cansancio.
      final energia = f.energia.clamp(0.0, 1.0);
      // Solo se dibuja el aro de energía cuando el jugador ya se cansó (si no, ensucia la figura).
      if (!f.esTecnico && energia < 0.85) {
        canvas.drawCircle(
          c,
          radio + pie * 0.55,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.3 * a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = pie * 0.24,
        );
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: radio + pie * 0.55),
          -pi / 2,
          2 * pi * energia,
          false,
          Paint()
            ..color = (energia < 0.6 ? const Color(0xFFFFB020) : Colors.white.withValues(alpha: 0.75)).withValues(alpha: a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = pie * 0.24
            ..strokeCap = StrokeCap.round,
        );
      }
      dibujarJugador(
        canvas,
        c: c,
        pie: pie,
        postura: postura,
        camiseta: f.relleno,
        numero: f.texto,
        ribete: f.ribete ?? f.texto,
        etiqueta: f.etiqueta,
        semilla: f.semilla,
        salto: f.salto,
        opacidad: a,
        tiempo: tiempo,
        destello: colorLed,
      );
      if (f.conBalon) {
        // Resalte del que tiene la pelota: anillo LED que late.
        final late = 0.5 + 0.5 * sin(tiempo * 7);
        canvas.drawCircle(
          c,
          radio + pie * (1.15 + 0.25 * late),
          Paint()
            ..color = colorLed.withValues(alpha: a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.0, pie * 0.35),
        );
        canvas.drawCircle(
          c,
          radio + pie * 1.0,
          Paint()
            ..color = colorLed.withValues(alpha: 0.13 * a)
            ..style = PaintingStyle.fill,
        );
      }
      if (f.nombre != null) {
        final placa = _placa(f.nombre!, radio * 0.75);
        final rect = Rect.fromCenter(
          center: c + Offset(0, radio * 2.0),
          width: placa.width + radio * 0.8,
          height: placa.height + radio * 0.2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radio * 0.3)),
          Paint()..color = const Color(0xD90F1012),
        );
        placa.paint(canvas, rect.center - Offset(placa.width / 2, placa.height / 2));
      }
    }
    if (ambiente.humo > 0.05) {
      // Humo suave subiendo de las llamas (sin sombras de caja: solo círculos translúcidos en el canvas).
      for (final f in fichas.where((f) => f.enLlamas)) {
        final c = p(f.posicion);
        for (var k = 0; k < 4; k++) {
          final u = ((tiempo * 0.9 + k * 0.25) % 1.0);
          canvas.drawCircle(
            c + Offset(sin(tiempo * 2 + k) * pie * 0.8, -pie * (2 + u * 4)),
            pie * (0.8 + u * 1.4),
            Paint()..color = Colors.white.withValues(alpha: 0.10 * (1 - u) * ambiente.humo),
          );
        }
      }
    }

    // Pelota baja (en la mano o cayendo por la red) debajo del aro; la que vuela, por encima.
    if (alturaBalon < 0.35) _pelota(canvas, p, pie);
    for (final arribaAro in [true, false]) {
      final efecto = efectoAro?.arriba == arribaAro ? efectoAro : null;
      _aro(canvas, p(Cancha94.aro(arribaAro)), pie, arribaAro, efecto);
    }
    if (alturaBalon >= 0.35) _pelota(canvas, p, pie);

    // Tanto: sube y se desvanece sobre el aro.
    final t = tanto;
    if (t != null) {
      final sube = Curves.easeOutCubic.transform(t.progreso);
      final c = p(t.posicion) - Offset(0, sube * pie * 6);
      _texto(canvas, t.texto, c, pie * 3.4, colorLed.withValues(alpha: (1 - t.progreso).clamp(0, 1)), FontWeight.w800);
    }
    canvas.restore();

    // Luz del estadio sobre la toma: centro iluminado, bordes en penumbra.
    final toma = Offset.zero & size;
    canvas.drawRect(
      toma,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38 + 0.3 * ambiente.luzDramatica)],
          stops: [0.55 - 0.15 * ambiente.luzDramatica, 1],
        ).createShader(toma),
    );
  }

  void _pelota(Canvas canvas, Offset Function(Offset) p, double pie) {
    // Estela, sombra y balón (más grande cuanto más alto va el tiro).
    for (final (i, e) in estela.indexed) {
      final k = 1 - i / max(estela.length, 1);
      canvas.drawCircle(p(e), pie * 0.95 * k, Paint()..color = const Color(0xFFFFB347).withValues(alpha: 0.45 * k));
    }
    final b = p(balon);
    final rb = pie * (1.0 + 0.75 * alturaBalon);
    canvas.drawCircle(
      b + Offset(pie * (0.4 + 2.2 * alturaBalon), pie * (0.5 + 2.6 * alturaBalon)),
      rb * 0.85,
      Paint()..color = Colors.black.withValues(alpha: 0.3 * (1 - alturaBalon * 0.5)),
    );
    _cueroPelota(canvas, b, rb);
    final costura = Paint()
      ..color = estilo.costura
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, rb * 0.12);
    canvas.drawLine(b - Offset(rb, 0), b + Offset(rb, 0), costura);
    canvas.drawArc(Rect.fromCircle(center: b - Offset(rb * 1.1, 0), radius: rb * 0.9), -0.9, 1.8, false, costura);
    canvas.drawArc(Rect.fromCircle(center: b + Offset(rb * 1.1, 0), radius: rb * 0.9), pi - 0.9, 1.8, false, costura);
    canvas.drawCircle(
      b,
      rb,
      Paint()
        ..color = estilo.costura
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, rb * 0.1),
    );
  }

  /// Cuero liso o en paneles diagonales (la ABA: roja, blanca y azul).
  void _cueroPelota(Canvas canvas, Offset b, double rb) {
    final colores = estilo.pelota;
    if (colores.length == 1) {
      canvas.drawCircle(b, rb, Paint()..color = colores.first);
      return;
    }
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: b, radius: rb)));
    canvas.translate(b.dx, b.dy);
    canvas.rotate(-pi / 4);
    final ancho = 2 * rb / colores.length;
    for (final (i, c) in colores.indexed) {
      canvas.drawRect(Rect.fromLTWH(-rb + i * ancho, -rb, ancho + 0.5, 2 * rb), Paint()..color = c);
    }
    canvas.restore();
  }

  /// Aro visto desde arriba: base acolchada detrás del fondo, brazo, tablero de vidrio con su
  /// recuadro, aro naranja y red. La red se sacude al entrar la pelota; el aro vibra si rebota.
  void _aro(Canvas canvas, Offset centro, double pie, bool arriba, EfectoAro? efecto) {
    final s = arriba ? 1.0 : -1.0; // hacia adentro de la cancha
    Offset q(double x, double y) => centro + Offset(x * pie, y * s * pie);
    // Base y brazo.
    final base = Rect.fromPoints(q(-2.6, -11.0), q(2.6, -9.2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(base.shift(Offset(pie * 0.3, pie * 0.4)), Radius.circular(pie * 0.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(pie * 0.5)),
      Paint()..color = const Color(0xFF1B1D21),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base.deflate(pie * 0.35), Radius.circular(pie * 0.3)),
      Paint()..color = Color(franquicia.colorPrimario).withValues(alpha: 0.85),
    );
    canvas.drawRect(Rect.fromPoints(q(-0.45, -9.3), q(0.45, -1.4)), Paint()..color = const Color(0xFF2A2D33));
    // Tablero: vidrio con borde blanco y el recuadro del tirador.
    var vibra = 0.0;
    if (efecto != null && (!efecto.adentro || efecto.fuerte)) {
      vibra = sin(efecto.progreso * pi * 9) * (1 - efecto.progreso) * (efecto.fuerte ? 0.7 : 0.35);
    }
    final tablero = Rect.fromPoints(q(-3 + vibra, -1.45), q(3 + vibra, -0.95));
    canvas.drawRect(
      tablero.shift(Offset(pie * 0.25, pie * 0.35)),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawRect(tablero, Paint()..color = const Color(0x55DDEEFF));
    canvas.drawRect(
      tablero,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, pie * 0.16),
    );
    canvas.drawLine(
      q(-1, -0.95),
      q(1, -0.95),
      Paint()
        ..color = Colors.white
        ..strokeWidth = max(1.2, pie * 0.2),
    );
    // Soporte del aro.
    canvas.drawLine(
      q(vibra, -0.95),
      q(vibra, -0.7),
      Paint()
        ..color = const Color(0xFFE35205)
        ..strokeWidth = pie * 0.3,
    );
    final c = centro + Offset(vibra * pie, 0);
    // Red: hilos del aro hacia el fondo de la red (que se sacude con la canasta).
    var caida = 0.0, abre = 1.0;
    if (efecto != null && efecto.adentro) {
      final u = efecto.progreso;
      caida = sin(u * pi) * 0.9 + sin(u * pi * 5) * (1 - u) * 0.2;
      abre = 1 + sin(u * pi) * 0.25;
    }
    final fondo = c + Offset(0, caida * s * pie);
    final radioRed = 0.45 * pie * abre;
    final hilo = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = max(0.7, pie * 0.07);
    for (var k = 0; k < 12; k++) {
      final ang = k * pi / 6;
      final arriba = c + Offset(cos(ang), sin(ang)) * 0.75 * pie;
      final abajo = fondo + Offset(cos(ang + pi / 12), sin(ang + pi / 12)) * radioRed;
      canvas.drawLine(arriba, abajo, hilo);
    }
    canvas.drawCircle(fondo, radioRed, hilo..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset.lerp(c, fondo, 0.5)!, (0.75 * pie + radioRed) / 2, hilo);
    // Aro.
    canvas.drawCircle(
      c + Offset(pie * 0.12, pie * 0.18),
      0.75 * pie,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pie * 0.2,
    );
    // Rebote en el hierro: el aro se pone blanco un instante y salen chispas.
    final golpe = efecto != null && !efecto.adentro ? (1 - efecto.progreso * 3).clamp(0.0, 1.0) : 0.0;
    canvas.drawCircle(
      c,
      0.75 * pie,
      Paint()
        ..color = Color.lerp(const Color(0xFFF26A1B), Colors.white, golpe)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = pie * (0.22 + 0.1 * golpe),
    );
    if (golpe > 0) {
      final chispa = Paint()
        ..color = Colors.white.withValues(alpha: golpe)
        ..strokeWidth = max(1.2, pie * 0.14)
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 6; k++) {
        final ang = k * pi / 3 + 0.5;
        final d = Offset(cos(ang), sin(ang));
        canvas.drawLine(c + d * pie * (0.95 + (1 - golpe) * 0.6), c + d * pie * (1.5 + (1 - golpe) * 1.4), chispa);
      }
    }
  }

  /// Carteles LED a lo largo de los costados, con el texto corriendo (estilo "El Marcador"). Se
  /// encienden de golpe con las jugadas grandes y tienen puntitos de matriz.
  void _carteles(Canvas canvas, double pie) {
    if (cartel.isEmpty) return;
    final destello = ambiente.destello.clamp(0.0, 1.0);
    final estilo = TextStyle(
      fontFamily: Fuentes.led,
      fontVariations: const [FontVariation.weight(800)],
      fontSize: 1.05 * pie,
      color: Color.lerp(colorLed, Colors.white, destello * 0.6),
      height: 1,
      letterSpacing: 0.3 * pie,
    );
    final tp = _cartelPintado('$cartel   ·   ', estilo);
    final largo = (Cancha94.largo + 2 * Cancha94.borde) * pie;
    for (final izquierda in [true, false]) {
      final xMundo = izquierda ? -2.35 : Cancha94.ancho + 2.35;
      final x = (xMundo + Cancha94.borde) * pie;
      final franja = Rect.fromCenter(center: Offset(x, largo / 2), width: 1.45 * pie, height: largo);
      canvas.drawRect(franja, Paint()..color = Color.lerp(const Color(0xFF0B0C0E), colorLed, destello * 0.35)!);
      canvas.save();
      canvas.clipRect(franja);
      canvas.translate(x, 0);
      canvas.rotate(pi / 2); // el texto corre a lo largo de la cancha
      final velocidad = 6 + 14 * destello;
      final corrimiento = (tiempo * velocidad * pie) % tp.width;
      for (var d = -corrimiento; d < largo; d += tp.width) {
        tp.paint(canvas, Offset(d, -tp.height / 2));
      }
      canvas.restore();
    }
  }

  static final _textos = <String, TextPainter>{};

  TextPainter _cartelPintado(String texto, TextStyle estilo) {
    final clave = '$texto|${estilo.fontSize!.round()}|${estilo.color!.toARGB32()}';
    if (_textos.length > 60) _textos.clear();
    return _textos[clave] ??= TextPainter(text: TextSpan(text: texto, style: estilo), textDirection: TextDirection.ltr)
      ..layout();
  }

  TextPainter _placa(String nombre, double tamano) {
    final clave = 'placa|$nombre|${tamano.round()}';
    if (_textos.length > 60) _textos.clear();
    return _textos[clave] ??= TextPainter(
      text: TextSpan(
        text: nombre,
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: const [FontVariation.weight(700)],
          fontSize: tamano.roundToDouble(),
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Los suplentes sentados junto a la línea lateral: se levantan y alzan los brazos al festejar.
  void _banco(Canvas canvas, Offset Function(Offset) p, double pie) {
    for (final (k, equipo, levanta) in [
      (0, ambiente.bancoAtaque, ambiente.levantadoAtaque),
      (1, ambiente.bancoDefensa, ambiente.levantadoDefensa),
    ]) {
      if (equipo == null) continue;
      // Sillas del equipo: una banca oscura y 4 suplentes.
      final y0 = k == 0 ? 40.0 : 54.5;
      final banca = Rect.fromPoints(p(Offset(-2.7, y0 - 1.4)), p(Offset(-0.8, y0 + 4 * 2.5 + 0.2)));
      canvas.drawRRect(RRect.fromRectAndRadius(banca, Radius.circular(pie * 0.5)), Paint()..color = const Color(0xFF16181C));
      for (var n = 0; n < 4; n++) {
        dibujarSentado(
          canvas,
          c: p(Offset(-1.75, y0 + n * 2.5 + 0.6)),
          pie: pie * 0.78,
          camiseta: equipo.$1,
          ribete: equipo.$2,
          semilla: 11 + n * 7 + k * 31,
          levantado: levanta,
          tiempo: tiempo + n * 0.37,
        );
      }
    }
  }

  /// Llamas del tirador encendido: lenguas que salen hacia atrás y un resplandor naranja.
  void _llamas(Canvas canvas, Offset c, double pie, double rumbo, double a) {
    canvas.drawCircle(c, pie * 3.4, Paint()..color = const Color(0xFFFF7A1A).withValues(alpha: 0.2 * a));
    final atras = Offset(-sin(rumbo), cos(rumbo));
    for (var k = 0; k < 7; k++) {
      final f = (tiempo * 2.2 + k * 0.143) % 1.0;
      final lado = sin(tiempo * 9 + k * 2.1) * 0.9;
      final d = atras * pie * (1.5 + f * 4.2) + Offset(-atras.dy, atras.dx) * pie * lado * f;
      final r = pie * (1.5 - f * 1.2);
      canvas.drawCircle(
        c + d,
        r,
        Paint()
          ..color = Color.lerp(const Color(0xFFFFD23F), const Color(0xFFE8400C), f)!.withValues(alpha: (0.85 - f * 0.8) * a),
      );
    }
  }

  void _texto(Canvas canvas, String texto, Offset centro, double tamano, Color color, FontWeight peso) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          fontFamily: Fuentes.estadio,
          fontVariations: [FontVariation.weight(peso.value.toDouble())],
          fontSize: tamano,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  void _dibujarPiso(Canvas canvas, double pie) {
    Offset p(double x, double y) => Offset((x + Cancha94.borde) * pie, (y + Cancha94.borde) * pie);
    final pintura = Color(franquicia.colorPrimario);
    final secundario = Color(franquicia.colorSecundario);
    final total = Rect.fromLTWH(
      0,
      0,
      (Cancha94.ancho + 2 * Cancha94.borde) * pie,
      (Cancha94.largo + 2 * Cancha94.borde) * pie,
    );

    // Borde fuera de la cancha: color del equipo, mate.
    final hsl = HSLColor.fromColor(pintura);
    final borde = hsl.withLightness((hsl.lightness * 0.7).clamp(0.08, 0.4)).toColor();
    canvas.drawRect(total, Paint()..color = borde);

    // Madera con tablas, juntas y vetas (o el piso elegido en el vestuario).
    final cancha = Rect.fromPoints(p(0, 0), p(Cancha94.ancho, Cancha94.largo));
    canvas.save();
    canvas.clipRect(cancha);
    if (estilo.superficie != SuperficieCancha.parquet) {
      _superficieEspecial(canvas, cancha, pie);
    }
    final madera = estilo.madera;
    final tabla = cancha.width / 30;
    final azar = Random(94);
    final veta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var i = 0; estilo.superficie == SuperficieCancha.parquet && i * tabla < cancha.width; i++) {
      final x = cancha.left + i * tabla;
      final tono = HSLColor.fromColor(madera);
      canvas.drawRect(
        Rect.fromLTWH(x, cancha.top, tabla, cancha.height),
        Paint()..color = tono.withLightness((tono.lightness + (azar.nextDouble() - 0.5) * 0.07).clamp(0, 1)).toColor(),
      );
      for (var v = 0; v < 2; v++) {
        final vx = x + tabla * (0.3 + 0.4 * v);
        final camino = Path()..moveTo(vx, cancha.top);
        for (var y = cancha.top; y < cancha.bottom; y += 22) {
          camino.quadraticBezierTo(vx + (azar.nextBool() ? 1.5 : -1.5), y + 11, vx + (azar.nextDouble() - 0.5), y + 22);
        }
        canvas.drawPath(camino, veta..color = Colors.black.withValues(alpha: 0.05 + azar.nextDouble() * 0.05));
      }
      final junta = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..strokeWidth = 0.6;
      canvas.drawLine(Offset(x, cancha.top), Offset(x, cancha.bottom), junta);
      for (var y = cancha.top + azar.nextDouble() * 70; y < cancha.bottom; y += 60 + azar.nextDouble() * 50) {
        canvas.drawLine(Offset(x, y), Offset(x + tabla, y), junta);
      }
    }
    canvas.restore();

    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.3, pie * 0.22);
    canvas.drawRect(cancha, linea);
    canvas.drawLine(p(0, 47), p(50, 47), linea);
    final escudoCentral = escudo;
    if (escudoCentral == null) {
      canvas.drawCircle(p(25, 47), 6 * pie, Paint()..color = pintura.withValues(alpha: 0.85));
      canvas.drawCircle(p(25, 47), 2 * pie, linea);
    } else {
      // Escudo sobre la madera, como en las canchas de verdad.
      final lado = 10.5 * pie;
      final proporcion = escudoCentral.width / escudoCentral.height;
      final destino = Rect.fromCenter(
        center: p(25, 47),
        width: proporcion >= 1 ? lado : lado * proporcion,
        height: proporcion >= 1 ? lado / proporcion : lado,
      );
      canvas.drawImageRect(
        escudoCentral,
        Offset.zero & Size(escudoCentral.width.toDouble(), escudoCentral.height.toDouble()),
        destino,
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Colors.white.withValues(alpha: 0.92),
      );
    }
    canvas.drawCircle(p(25, 47), 6 * pie, linea);

    for (final arriba in [true, false]) {
      double y(double d) => arriba ? d : Cancha94.largo - d;
      final zona = Rect.fromPoints(p(17, y(0)), p(33, y(19)));
      canvas.drawRect(zona, Paint()..color = pintura.withValues(alpha: estilo.opacidadPintura));
      canvas.drawRect(zona, linea);
      canvas.drawCircle(p(25, y(19)), 6 * pie, linea);
      for (final d in [7.0, 10.5, 13.5, 16.5]) {
        canvas.drawLine(p(17, y(d)), p(16, y(d)), linea);
        canvas.drawLine(p(33, y(d)), p(34, y(d)), linea);
      }
      final aro = p(25, y(5.25));
      canvas.drawArc(Rect.fromCircle(center: aro, radius: 4 * pie), arriba ? 0 : pi, pi, false, linea);
      final ang = asin(8.95 / 23.75);
      canvas.drawLine(p(3, y(0)), p(3, y(14.2)), linea);
      canvas.drawLine(p(47, y(0)), p(47, y(14.2)), linea);
      canvas.drawArc(
        Rect.fromCircle(center: aro, radius: 23.75 * pie),
        arriba ? ang : pi + ang,
        pi - 2 * ang,
        false,
        linea,
      );

      // Nombre de la franquicia en cada línea de fondo (GDD §2), partido en dos mitades a los lados del
      // brazo del tablero (que pasa por el medio) para que nada lo tape.
      final texto = franquicia.nombre.toUpperCase();
      final corte = (texto.length + 1) ~/ 2;
      final color = secundario.computeLuminance() > 0.08 ? secundario : Colors.white;
      TextPainter mitad(String t) => TextPainter(
        text: TextSpan(
          text: t.trimRight(),
          style: TextStyle(
            fontFamily: Fuentes.estadio,
            fontVariations: const [FontVariation.weight(800)],
            fontSize: 2.2 * pie,
            letterSpacing: 1.2 * pie,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final izquierda = mitad(texto.substring(0, corte)), derecha = mitad(texto.substring(corte).trimLeft());
      final centro = p(25, arriba ? -1.5 : Cancha94.largo + 1.5);
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      if (!arriba) canvas.rotate(pi);
      izquierda.paint(canvas, Offset(-1.6 * pie - izquierda.width + 1.2 * pie, -izquierda.height / 2));
      derecha.paint(canvas, Offset(1.6 * pie, -derecha.height / 2));
      canvas.restore();
    }
  }

  /// Damero de parquet (tablas que cambian de sentido) o cemento de barrio con manchas.
  void _superficieEspecial(Canvas canvas, Rect cancha, double pie) {
    final azar = Random(70);
    final tono = HSLColor.fromColor(estilo.madera);
    if (estilo.superficie == SuperficieCancha.cuadros) {
      final lado = 5 * pie;
      final junta = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..strokeWidth = 0.6;
      for (var fila = 0; fila * lado < cancha.height; fila++) {
        for (var col = 0; col * lado < cancha.width; col++) {
          final r = Rect.fromLTWH(cancha.left + col * lado, cancha.top + fila * lado, lado, lado);
          final par = (fila + col).isEven;
          final luz = (tono.lightness + (par ? 0.04 : -0.04) + (azar.nextDouble() - 0.5) * 0.03).clamp(0.0, 1.0);
          canvas.drawRect(r, Paint()..color = tono.withLightness(luz).toColor());
          // Cuatro tablitas por cuadro, verticales u horizontales según el damero.
          for (var k = 1; k < 4; k++) {
            final d = lado * k / 4;
            par
                ? canvas.drawLine(Offset(r.left + d, r.top), Offset(r.left + d, r.bottom), junta)
                : canvas.drawLine(Offset(r.left, r.top + d), Offset(r.right, r.top + d), junta);
          }
          canvas.drawRect(r, junta..style = PaintingStyle.stroke);
          junta.style = PaintingStyle.fill;
        }
      }
      return;
    }
    canvas.drawRect(cancha, Paint()..color = estilo.madera);
    final mancha = Paint();
    for (var k = 0; k < 260; k++) {
      final c = Offset(cancha.left + azar.nextDouble() * cancha.width, cancha.top + azar.nextDouble() * cancha.height);
      mancha.color = (azar.nextBool() ? Colors.black : Colors.white).withValues(alpha: 0.04 + azar.nextDouble() * 0.05);
      canvas.drawCircle(c, pie * (0.3 + azar.nextDouble() * 1.6), mancha);
    }
    // Juntas de dilatación del cemento.
    final junta = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;
    for (var y = cancha.top + 15 * pie; y < cancha.bottom; y += 15 * pie) {
      canvas.drawLine(Offset(cancha.left, y), Offset(cancha.right, y), junta);
    }
    canvas.drawLine(Offset(cancha.center.dx, cancha.top), Offset(cancha.center.dx, cancha.bottom), junta);
  }

  @override
  bool shouldRepaint(CanchaPartidoPainter a) => true;
}
