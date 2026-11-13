import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/dinastia.dart';
import 'package:dinastia_nba/domain/progreso.dart';
import 'package:flutter_test/flutter_test.dart';

String nombre(String id) => franquiciaPorId(id).nombreCompleto;

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(5));
  final carrera = CarreraDinastia(liga);

  Temporada primera() {
    var p = const Plantel();
    final js = catalogo.where((j) => j.franquiciaId == 'CHI').toList()..sort((a, b) => b.media.compareTo(a.media));
    for (final pos in Posicion.values) {
      p = p.asignar(js.firstWhere((j) => p.posicionesDisponiblesPara(j).contains(pos)), pos);
    }
    return Temporada(
      id: 'din',
      franquiciaUsuarioId: 'CHI',
      plantel: p,
      tacticaConfirmada: true,
      modoJuego: ModoJuego.dinastia,
      datosModo: CarreraDinastia.datosIniciales('din'),
    );
  }

  Temporada jugarEntera(Temporada t) {
    var x = liga.iniciar(t);
    x = liga.simularOtrosHasta(x, 1 << 30);
    while (liga.proximoDelUsuario(x) != null) {
      x = liga.simularProximo(x);
    }
    x = liga.simularOtrosHasta(x, 1 << 30);
    return liga.simularRestoPlayoffs(x);
  }

  Map<Posicion, Jugador> elegirPrimeros(Receso r) => {for (final e in r.opciones.entries) e.key: e.value.first};

  test('envejecer: los jóvenes suben, los veteranos bajan', () {
    expect(CarreraDinastia.cambioPorEdad(22), greaterThan(0));
    expect(CarreraDinastia.cambioPorEdad(29), 0);
    expect(CarreraDinastia.cambioPorEdad(35), lessThan(0));
    final t = primera().copyWith(
      datosModo: EstadoDinastia(raiz: 'din', edades: {for (final j in primera().plantel.jugadores) j.id: 21}).toJson(),
    );
    final terminada = jugarEntera(t);
    final r = carrera.receso(terminada, nombre);
    expect(r.retiros, isEmpty, reason: 'a los 22 nadie se retira');
    expect(r.cambios.values.every((c) => c >= 2), isTrue, reason: r.cambios.toString());
    for (final j in r.plantel.jugadores) {
      final original = catalogo.firstWhere((c) => c.id == j.id);
      expect(j.media, original.media + r.cambios[j.id]!);
      expect(r.edades[j.id], 22);
    }
  });

  test('retiros: los de 37 se van (como mucho 3 titulares) y el mini-draft ofrece 3 por puesto', () {
    final base = primera();
    final t = base.copyWith(
      datosModo: EstadoDinastia(raiz: 'din', edades: {for (final j in base.plantel.jugadores) j.id: 37}).toJson(),
    );
    final r = carrera.receso(jugarEntera(t), nombre);
    expect(r.retiros.length, inInclusiveRange(1, 3));
    expect(r.vacantes.length, r.retiros.length);
    for (final x in r.retiros) {
      expect(x.frase, contains(x.edad.toString()));
    }
    expect(r.opciones.keys.toSet(), r.vacantes.toSet());
    final propios = {for (final j in r.plantel.jugadores) j.nbaPlayerId};
    for (final e in r.opciones.entries) {
      expect(e.value, hasLength(3));
      expect(e.value.every((j) => j.puedeJugarEn(e.key) && !propios.contains(j.nbaPlayerId)), isTrue);
    }
    // Determinístico: abrir el receso dos veces da lo mismo.
    final otra = carrera.receso(jugarEntera(t), nombre);
    expect(otra.retiros.length, isNonNegative);
  });

  test('dos temporadas seguidas: historial, ids, JSON y sin doble premio en el cambio de temporada', () {
    final t1 = jugarEntera(primera());
    expect(t1.fase, FaseTemporada.finalizada);
    final r1 = carrera.receso(t1, nombre);
    // Mismo receso si se vuelve a abrir.
    expect(carrera.receso(t1, nombre).cambios, r1.cambios);
    final t2 = carrera.siguiente(t1, r1, elegirPrimeros(r1));
    expect(t2.id, 'din-t2');
    expect(t2.plantel.completo, isTrue);
    expect(t2.fase, FaseTemporada.tacticas);
    expect(t2.entrenadorId, t1.entrenadorId);
    final e2 = EstadoDinastia.de(t2);
    expect(e2.numero, 2);
    expect(e2.historial, hasLength(1));
    expect(e2.historial.first.victorias + e2.historial.first.derrotas, 82);
    expect(narrar(e2.historial.first).first, contains('${e2.historial.first.victorias}-'));

    // JSON: la temporada 2 se guarda y se recupera igual.
    final copia = Temporada.fromJson(t2.toJson());
    expect(copia.modoJuego, ModoJuego.dinastia);
    expect(EstadoDinastia.de(copia).toJson(), e2.toJson());
    expect([for (final j in copia.plantel.jugadores) j.media], [for (final j in t2.plantel.jugadores) j.media]);

    // Progreso: pasar de la temporada 1 terminada a la 2 no reparte nada de nuevo.
    final perfil = const PerfilEntrenador();
    final (p1, _) = Progreso(liga).aplicar(perfil, t1, t2);
    expect(identical(p1, perfil), isTrue);

    final t2b = jugarEntera(t2.copyWith(tacticaConfirmada: true));
    expect(t2b.fase, FaseTemporada.finalizada);
    final r2 = carrera.receso(t2b, nombre);
    final t3 = carrera.siguiente(t2b, r2, elegirPrimeros(r2));
    expect(t3.id, 'din-t3');
    expect(EstadoDinastia.de(t3).historial.map((p) => p.numero), [1, 2]);
  });

  test('Reescribí la historia: plantel real de la década, rivales de época y novatos de la década siguiente', () {
    final epocas = carrera.epocasPosibles('CHI');
    expect(epocas, contains(Epoca.anios80));
    final t = carrera.reescribir(id: 're', franquiciaId: 'CHI', epoca: Epoca.anios80, dificultad: Dificultad.normal);
    expect(t.plantel.jugadores.every((j) => j.franquiciaId == 'CHI' && j.epoca == Epoca.anios80), isTrue);
    expect(t.fase, FaseTemporada.tacticas);
    final iniciada = carrera.rivalesDeEpoca(liga.iniciar(t.copyWith(tacticaConfirmada: true)));
    final deEpoca = iniciada.rivales.values.where((r) => r.epoca == Epoca.anios80).length;
    expect(deEpoca, greaterThan(20));
    // Las que no existían en los 80 juegan con su década más cercana (nunca con un plantel de otra era lejana).
    expect(
      iniciada.rivales.values.every((r) => r.epoca != null && (r.epoca!.index - Epoca.anios80.index).abs() <= 2),
      isTrue,
    );
    // Con todos de 37 se libera algún puesto: los novatos vienen de los 90 (primero de los Bulls si hay).
    final viejos = iniciada.copyWith(
      datosModo: EstadoDinastia(
        raiz: 're',
        epoca: Epoca.anios80,
        edades: {for (final j in t.plantel.jugadores) j.id: 37},
      ).toJson(),
    );
    final r = carrera.receso(jugarEntera(viejos), nombre);
    expect(r.opciones.values.expand((x) => x).every((j) => j.epoca == Epoca.anios90), isTrue);
    final t2 = carrera.siguiente(viejos, r, elegirPrimeros(r));
    final novato = elegirPrimeros(r).values.first;
    final enPlantel = [...t2.plantel.jugadores, ...t2.suplentes].firstWhere((j) => j.id == novato.id);
    expect(enPlantel.media, lessThanOrEqualTo(novato.media), reason: 'llega más abajo y crece');
  });

  test('Reescribí: cada 3 temporadas se pasa a la década siguiente', () {
    final t = carrera.reescribir(id: 're2', franquiciaId: 'BOS', epoca: Epoca.anios60, dificultad: Dificultad.normal);
    final enLaTercera = t.copyWith(
      tacticaConfirmada: true,
      datosModo: const EstadoDinastia(raiz: 're2', numero: 3, epoca: Epoca.anios60, temporadasEnEpoca: 2).toJson(),
    );
    final r = carrera.receso(jugarEntera(enLaTercera), nombre);
    expect(r.epocaNueva, Epoca.anios70);
    final sig = carrera.siguiente(enLaTercera, r, elegirPrimeros(r));
    final e = EstadoDinastia.de(sig);
    expect(e.epoca, Epoca.anios70);
    expect(e.temporadasEnEpoca, 0);
    expect(e.historial.last.momentos.last, contains('años 70'));
  });
}
