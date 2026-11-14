// Mi carrera (creador, combine, draft, inicio, mi jugador, receso y legado) con tipografías reales.
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/data/franquicias.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/liga.dart';
import 'package:dinastia_nba/domain/modos/carrera_jugador.dart';
import 'package:dinastia_nba/presentation/modos/carrera_jugador_pantallas.dart';
import 'package:dinastia_nba/presentation/modos/creador_jugador.dart';
import 'package:dinastia_nba/presentation/pantallas/temporada_pantalla.dart';
import 'package:dinastia_nba/presentation/tema/tema_franquicia.dart';
import 'package:dinastia_nba/presentation/widgets/jugador_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _fuente(String familia, List<String> archivos) async {
  final loader = FontLoader(familia);
  for (final a in archivos) {
    loader.addFont(Future.value(ByteData.sublistView(File(a).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  final liga = Liga(catalogo, franquicias, azar: Random(44));
  final carrera = CarreraJugador(liga);
  final creado = JugadorCreado(
    nombre: 'Martín Pérez',
    posicion: Posicion.alero,
    rol: RolCancha.especialista3D,
    fuertes: const [Atributo.tiro, Atributo.defensa, Atributo.iq],
    alturaCm: 201,
    pesoKg: 96,
  );
  late Temporada hub;
  late Temporada finalizada;
  late CierreTemporada cierre;

  setUpAll(() async {
    JugadorAvatar.usarRed = false;
    const mf = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _fuente('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
    await _fuente('Doto', ['assets/fonts/Doto.ttf']);
    await _fuente('BigShouldersDisplay', ['assets/fonts/BigShouldersDisplay.ttf']);
    await _fuente('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    final e0 = carrera.estadoCreado(raiz: 'cap', creado: creado, pick: 11, franquiciaId: 'CHI');
    var t = carrera.nuevaCarrera(estado: e0, dificultad: Dificultad.normal);
    for (var i = 0; i < 30; i++) {
      t = liga.simularProximo(t);
    }
    hub = carrera.alGuardar(t);
    while (liga.proximoDelUsuario(t) != null) {
      t = liga.simularProximo(t);
    }
    t = liga.simularRestoPlayoffs(liga.simularOtrosHasta(t, 1 << 30));
    finalizada = t;
    cierre = carrera.cerrar(finalizada, EstadoCarrera.de(finalizada)!, (id) => franquiciaPorId(id).nombreCompleto);
  });

  void tel(WidgetTester t, {double alto = 900}) {
    t.view.physicalSize = Size(412, alto) * 2.5;
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  Widget app(Widget home) =>
      MaterialApp(debugShowCheckedModeBanner: false, theme: temaFranquicia(franquiciaPorId('CHI')), home: home);

  Future<void> captura(WidgetTester t, String nombre) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('salida/m3-micarrera-$nombre.png'));
  }

  testWidgets('creador', (t) async {
    tel(t, alto: 1500);
    await t.pumpWidget(app(CreadorJugadorPantalla(nombreInicial: creado.nombre, posicionInicial: Posicion.alero)));
    await t.pumpAndSettle();
    await captura(t, 'creador');
  });

  testWidgets('combine y noche del draft', (t) async {
    tel(t);
    final r = carrera.combine(creado, Random(3));
    await t.pumpWidget(app(CombinePantalla(creado: creado, resultado: r)));
    await t.pumpAndSettle();
    for (var i = 0; i < r.pruebas.length; i++) {
      await t.tap(find.textContaining('HACER').first);
      await t.pumpAndSettle();
    }
    await captura(t, 'combine');
    await t.pumpWidget(app(NocheDraftPantalla(nombre: creado.nombre, pick: r.pick, franquiciaId: 'CHI', anio: 2026)));
    await t.pumpAndSettle();
    await captura(t, 'draft');
  });

  testWidgets('inicio de la temporada con tu jugador', (t) async {
    tel(t, alto: 1500);
    await t.pumpWidget(
      app(
        TemporadaPantalla(
          temporada: hub,
          liga: liga,
          onCambio: (_) {},
          modoJugador: true,
          ajustar: carrera.alGuardar,
          cabeceraBuilder: (context, temp, cambiar) => TarjetaMiJugador(
            estado: EstadoCarrera.de(temp)!,
            marca: carrera.marca(temp, EstadoCarrera.de(temp)!),
            onAbrir: () {},
          ),
        ),
      ),
    );
    await t.pump();
    await captura(t, 'hub');
  });

  testWidgets('mi jugador (teléfono y tablet)', (t) async {
    tel(t, alto: 2300);
    final e = EstadoCarrera.de(hub)!.copyWith(phBanco: 9);
    final temp = carrera.sincronizar(hub, e);
    await t.pumpWidget(app(MiJugadorPantalla(temporada: temp, carrera: carrera, onCambiar: (_) {})));
    await t.pump();
    await captura(t, 'jugador');
    t.view.physicalSize = const Size(1340, 900) * 1.8;
    t.view.devicePixelRatio = 1.8;
    await t.pumpWidget(app(MiJugadorPantalla(temporada: temp, carrera: carrera, onCambiar: (_) {})));
    await t.pump();
    await captura(t, 'tablet-jugador');
  });

  testWidgets('receso: resumen, entrenar, prensa y contrato', (t) async {
    tel(t, alto: 1500);
    var estado = cierre.estado;
    Widget receso() => app(
      RecesoJugadorPantalla(
        temporada: finalizada,
        estado: estado,
        carrera: carrera,
        cierre: cierre,
        onEstado: (e) => estado = e,
        onSeguir: (_, _) {},
        onRetirar: (_) {},
      ),
    );
    await t.pumpWidget(receso());
    await t.pumpAndSettle();
    await captura(t, 'receso-resumen');
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    await captura(t, 'receso-entrenar');
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    await captura(t, 'receso-prensa');
    await t.tap(find.byType(OutlinedButton).first);
    await t.pumpAndSettle();
    await t.tap(find.byType(OutlinedButton).first);
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    await captura(t, 'receso-contrato');
  });

  testWidgets('contrato vencido: ofertas', (t) async {
    tel(t, alto: 1500);
    final e = cierre.estado.copyWith(contrato: 0, prensaHecha: 2);
    await t.pumpWidget(
      app(
        RecesoJugadorPantalla(
          temporada: finalizada,
          estado: e,
          carrera: carrera,
          cierre: null,
          onEstado: (_) {},
          onSeguir: (_, _) {},
          onRetirar: (_) {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUAR'));
    await t.pumpAndSettle();
    await captura(t, 'ofertas');
  });

  testWidgets('legado', (t) async {
    tel(t, alto: 1300);
    final e = cierre.estado;
    await t.pumpWidget(app(LegadoCarreraPantalla(estado: e, carrera: carrera, alInicio: () {})));
    await t.pumpAndSettle();
    await captura(t, 'legado');
  });
}
