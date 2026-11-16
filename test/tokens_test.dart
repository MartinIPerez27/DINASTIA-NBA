import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dinastia_nba/data/catalogo_jugadores.dart';
import 'package:dinastia_nba/domain/draft.dart';
import 'package:dinastia_nba/domain/entities/jugador.dart';
import 'package:dinastia_nba/domain/entities/modo_juego.dart';
import 'package:dinastia_nba/domain/entities/oferta.dart';
import 'package:dinastia_nba/domain/entities/perfil.dart';
import 'package:dinastia_nba/domain/entities/plantel.dart';
import 'package:dinastia_nba/domain/entities/posicion.dart';
import 'package:dinastia_nba/domain/entities/rol_cancha.dart';
import 'package:dinastia_nba/domain/entities/temporada.dart';
import 'package:dinastia_nba/domain/entities/tirada.dart';
import 'package:dinastia_nba/domain/reto.dart';
import 'package:dinastia_nba/domain/tokens_draft.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = EstadisticasJugador(
  ppp: 20,
  rpp: 5,
  app: 5,
  robP: 1,
  tapP: 1,
  pctTc: .5,
  pctT3: .35,
  pctTl: .8,
  minP: 34,
  perP: 2,
  iq: 80,
);

Jugador _carta(int persona, String franquicia, Epoca epoca, int media, List<Posicion> pos, {Tier tier = Tier.a}) =>
    Jugador(
      id: '$persona-$franquicia-${epoca.name}',
      nbaPlayerId: persona,
      nombre: 'Persona $persona',
      franquiciaId: franquicia,
      epoca: epoca,
      tier: tier,
      posiciones: pos,
      rol: RolCancha.controladorTotal,
      dorsal: persona % 99,
      stats: _stats,
      media: media,
    );

/// Catálogo sintético: nada depende de las medias del catálogo real.
final _lebronMia = _carta(23, 'MIA', Epoca.anios2010, 92, [Posicion.alero]);
final _lebronCle = _carta(23, 'CLE', Epoca.anios2010, 97, [Posicion.alero], tier: Tier.sPlus);
final _wade = _carta(3, 'MIA', Epoca.anios2010, 90, [Posicion.escolta]);
final _bosh = _carta(4, 'MIA', Epoca.anios2010, 88, [Posicion.alaPivot, Posicion.pivot]);
final _rondo = _carta(5, 'BOS', Epoca.anios2010, 85, [Posicion.base]);
final _garnett = _carta(6, 'BOS', Epoca.anios2010, 80, [Posicion.pivot]);
final _jordan = _carta(7, 'CHI', Epoca.anios90, 99, [Posicion.escolta], tier: Tier.sPlus);
final _pippen = _carta(8, 'CHI', Epoca.anios90, 94, [Posicion.alero], tier: Tier.s);
final _kobe = _carta(9, 'LAL', Epoca.anios2000, 96, [Posicion.escolta, Posicion.alero], tier: Tier.s);
final _catalogo = [_lebronMia, _lebronCle, _wade, _bosh, _rondo, _garnett, _jordan, _pippen, _kobe];

const _miami = Tirada(franquiciaId: 'MIA', epoca: Epoca.anios2010, tier: Tier.a);
const _chicago = Tirada(franquiciaId: 'CHI', epoca: Epoca.anios90, tier: Tier.sPlus);

Temporada _nueva({
  int fichas = Temporada.rerollsPorTemporada,
  ModoJuego modo = ModoJuego.clasico,
  Tirada? tirada,
  Map<String, dynamic>? datos,
}) => Temporada(
  id: 't',
  franquiciaUsuarioId: 'CHI',
  rerollsRestantes: fichas,
  modoJuego: modo,
  tirada: tirada,
  datosModo: datos ?? const {},
);

Temporada _json(Temporada t) => Temporada.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);

void main() {
  cartasConCatalogoReal();
  Draft draft([VentajasTokens v = VentajasTokens.ninguna, int semilla = 1]) =>
      Draft(_catalogo, azar: Random(semilla), ventajas: v);

  group('volver a tirar: pocas fichas gratis y después monedas con precio creciente', () {
    test('una ficha gratis por draft; la segunda tirada se paga y sin monedas no se puede', () {
      final d = draft();
      var t = d.tirar(_nueva());
      expect(t.rerollsRestantes, 1);
      expect(d.precioDe(t, TokenDraft.volverATirar), 0);
      expect(d.estadoDe(t, TokenDraft.volverATirar, monedas: 0), EstadoToken.gratis);
      t = d.tirar(t);
      expect(t.rerollsRestantes, 0);
      expect(t.tokens.gastadas, 0);
      expect(d.precioDe(t, TokenDraft.volverATirar), 50);
      expect(d.estadoDe(t, TokenDraft.volverATirar, monedas: 49), EstadoToken.caro);
      expect(d.estadoDe(t, TokenDraft.volverATirar, monedas: 50), EstadoToken.disponible);
      expect(() => d.tirar(t), throwsStateError, reason: 'monedas = 0');
      expect(() => d.tirar(t, monedas: 49), throwsStateError);
    });

    test('precios 50 · 100 · 200 · 400, tope de 4 pagas y después agotado', () {
      final d = draft();
      var t = _nueva(fichas: 0, tirada: _miami);
      final cobrado = <int>[];
      for (var i = 0; i < 4; i++) {
        final antes = t.tokens.gastadas;
        // Con 1000 monedas alcanza para uno por uno; el tope de gasto (800) corta recién después.
        t = d.tirar(t, monedas: 1000);
        cobrado.add(t.tokens.gastadas - antes);
      }
      expect(cobrado, [50, 100, 200, 400]);
      expect(t.tokens.pagosDe(TokenDraft.volverATirar), 4);
      expect(d.usosRestantes(t, TokenDraft.volverATirar), 0);
      expect(d.estadoDe(t, TokenDraft.volverATirar, monedas: 9999), EstadoToken.agotado);
      expect(d.puedeVolverATirar(t, const {}), isFalse);
      expect(() => d.tirar(t, monedas: 9999), throwsStateError);
    });

    test('el nivel 10 descuenta 20 %: 40 · 80 · 160 · 320', () {
      final d = draft(const VentajasTokens(descuento: 20));
      var t = _nueva(fichas: 0, tirada: _miami);
      final cobrado = <int>[];
      for (var i = 0; i < 4; i++) {
        final antes = t.tokens.gastadas;
        t = d.tirar(t, monedas: 1000);
        cobrado.add(t.tokens.gastadas - antes);
      }
      expect(cobrado, [40, 80, 160, 320]);
    });

    test('tope de gasto por draft: con 750 gastados ya no entra un token de 120', () {
      final d = draft();
      var t = _nueva(fichas: 0, tirada: _miami);
      for (var i = 0; i < 4; i++) {
        t = d.tirar(t, monedas: 1000);
      }
      expect(t.tokens.gastadas, 750);
      expect(d.precioDe(t, TokenDraft.comodin), isNull, reason: '750 + 120 > ${ReglasTokens.topeGastoPorDraft}');
      expect(d.estadoDe(t, TokenDraft.comodin, monedas: 9999), EstadoToken.agotado);
    });

    test('cartas: volver a repartir usa la misma regla (gratis, luego monedas)', () {
      final d = draft();
      const cartas = Temporada(id: 'c', franquiciaUsuarioId: 'CHI', modo: ModoDraft.cartas);
      // Un catálogo chico no alcanza para sobres: este caso se prueba con la regla de pago.
      expect(d.precioDe(cartas, TokenDraft.volverATirar), 0);
      expect(d.precioDe(cartas.copyWith(rerollsRestantes: 0), TokenDraft.volverATirar), 50);
    });
  });

  group('mejor versión', () {
    test('sale LeBron de Miami: ofrece la carta de mayor media de su persona (Cleveland)', () {
      final d = draft();
      final t = _nueva(tirada: _miami);
      expect(d.candidatos(t), contains(_lebronMia));
      expect(d.mejorVersionDe(t, _lebronMia), _lebronCle);
      expect(d.versionesDe(_lebronMia), [_lebronCle, _lebronMia], reason: 'de más a menos media');
      expect(d.mejorVersionDe(t, _wade), isNull, reason: 'Wade tiene una sola carta');
    });

    test('cuesta 150, la grilla muestra la mejor versión y se elige en un puesto libre', () {
      final d = draft();
      var t = _nueva(tirada: _miami);
      expect(() => d.mejorVersion(t, _lebronMia), throwsStateError, reason: 'sin monedas');
      t = d.mejorVersion(t, _lebronMia, monedas: 150);
      expect(t.tokens.gastadas, 150);
      final cartas = d.candidatos(t);
      expect(cartas, contains(_lebronCle));
      expect(cartas, isNot(contains(_lebronMia)));
      // Se guarda y se recupera igual.
      expect(d.candidatos(_json(t)), cartas);
      final fichado = d.elegir(t, _lebronCle, Posicion.alero);
      expect(fichado.plantel.en(Posicion.alero), _lebronCle);
      expect(fichado.tirada, isNull);
      expect(fichado.tokens.sustituidas, isEmpty, reason: 'las sustituciones valen para una sola tirada');
      expect(fichado.tokens.gastadas, 150);
    });

    test('segundo uso 300 y tope de 2 por draft; con la ventaja de nivel 20 el primero es gratis', () {
      final d = draft();
      var t = _nueva(tirada: _miami);
      t = d.mejorVersion(t, _lebronMia, monedas: 500);
      expect(d.precioDe(t, TokenDraft.mejorVersion), 300);
      // Tope de gasto: 150 + 300 = 450 (< 800): se puede, pero ya no quedan usos.
      t = t.copyWith(tokens: t.tokens.conUso(TokenDraft.mejorVersion, precio: 300));
      expect(d.precioDe(t, TokenDraft.mejorVersion), isNull);

      final conNivel = draft(const VentajasTokens(versionGratis: true));
      final g = _nueva(tirada: _miami);
      expect(conNivel.precioDe(g, TokenDraft.mejorVersion), 0);
      final usado = conNivel.mejorVersion(g, _lebronMia);
      expect(usado.tokens.gastadas, 0);
      expect(conNivel.precioDe(usado, TokenDraft.mejorVersion), 150, reason: 'el segundo ya se paga');
    });

    test('respeta la regla del draft (franquicia pura) y no ofrece versiones de otro equipo', () {
      final d = draft();
      final t = Temporada(
        id: 't',
        franquiciaUsuarioId: 'MIA',
        regla: ReglaDraft.franquiciaPura,
        tirada: _miami,
      );
      expect(d.mejorVersionDe(t, _lebronMia), isNull, reason: 'la de Cleveland no es de tu franquicia');
    });
  });

  group('doble', () {
    test('con la misma tirada se eligen dos jugadores y recién después se cierra', () {
      final d = draft();
      var t = _nueva(tirada: _miami);
      expect(d.precioDe(t, TokenDraft.doble), 200);
      t = d.doble(t, monedas: 200);
      expect(t.tokens.picksExtra, 1);
      expect(t.tokens.gastadas, 200);
      expect(d.puedeVolverATirar(t, const {}), isFalse, reason: 'con el Doble activo no se vuelve a tirar');
      expect(() => d.doble(t, monedas: 500), throwsStateError);

      final primero = d.elegir(t, _wade, Posicion.escolta);
      expect(primero.tirada, _miami, reason: 'la tirada sigue abierta');
      expect(primero.tokens.picksExtra, 0);
      expect(d.candidatos(primero), isNot(contains(_wade)));
      expect(_json(primero).tokens.picksExtra, 0);
      final segundo = d.elegir(primero, _bosh, Posicion.pivot);
      expect(segundo.tirada, isNull);
      expect(segundo.plantel.jugadores, hasLength(2));
      expect(segundo.tokens.usosDe(TokenDraft.doble), 1);
      expect(d.precioDe(segundo, TokenDraft.doble), isNull, reason: 'tope 1 por draft');
    });

    test('no deja elegir un puesto que le saca el lugar al segundo jugador', () {
      final d = draft();
      // Quedan libres solo BASE y PIVOT: Rondo (BASE) y Garrett (PIVOT).
      final plantel = [
        (_wade, Posicion.escolta),
        (_lebronMia, Posicion.alero),
        (_bosh, Posicion.alaPivot),
        (_pippen, Posicion.sextoHombre),
      ].fold(const Temporada(id: 'x', franquiciaUsuarioId: 'BOS').plantel, (p, e) => p.asignar(e.$1, e.$2));
      var t = Temporada(
        id: 'x',
        franquiciaUsuarioId: 'BOS',
        plantel: plantel,
        tirada: const Tirada(franquiciaId: 'BOS', epoca: Epoca.anios2010, tier: Tier.a),
      );
      t = d.doble(t, monedas: 200);
      expect(d.puestosPara(t, _rondo), [Posicion.base]);
      final uno = d.elegir(t, _rondo, Posicion.base);
      expect(uno.tirada, isNotNull);
      final dos = d.elegir(uno, _garnett, Posicion.pivot);
      expect(dos.plantel.completo, isTrue);
    });

    test('no se puede activar si la tirada no tiene dos cartas que entren en dos puestos', () {
      final d = draft();
      // CHI 90s: con escolta y Sexto Hombre ocupados, Jordan no entra y solo queda Pippen.
      final t = Temporada(
        id: 'x',
        franquiciaUsuarioId: 'CHI',
        plantel: const Temporada(
          id: 'x',
          franquiciaUsuarioId: 'CHI',
        ).plantel.asignar(_wade, Posicion.escolta).asignar(_garnett, Posicion.sextoHombre),
        tirada: _chicago,
      );
      expect(d.estadoDe(t, TokenDraft.doble, monedas: 999), EstadoToken.bloqueado, reason: 'solo Pippen entra');
      expect(() => d.doble(t, monedas: 999), throwsStateError);
    });
  });

  group('intercambio', () {
    Temporada conWade() => Temporada(
      id: 'x',
      franquiciaUsuarioId: 'CHI',
      plantel: const Temporada(id: 'x', franquiciaUsuarioId: 'CHI').plantel.asignar(_wade, Posicion.escolta),
      tirada: _chicago,
    );

    test('la carta vieja se pierde; cuesta 250 más 10 por punto de media que ganás (tope 400)', () {
      final d = draft();
      final t = conWade();
      final opciones = d.opcionesIntercambio(t);
      expect(opciones.map((o) => o.$1), [Posicion.escolta]);
      expect(opciones.single.$3, [_jordan], reason: 'solo Jordan juega de escolta en CHI 90s');
      // Wade 90 → Jordan 99: +9 → 250 + 90 = 340.
      expect(ReglasTokens.precioIntercambio(90, 99), 340);
      expect(ReglasTokens.precioIntercambio(90, 80), 250, reason: 'bajar o empatar no suma');
      expect(ReglasTokens.precioIntercambio(60, 99), 400, reason: 'tope');
      expect(d.precioDe(t, TokenDraft.intercambio, sale: _wade, entra: _jordan), 340);
      expect(() => d.intercambiar(t, _jordan, Posicion.escolta, monedas: 339), throwsStateError);

      final nueva = d.intercambiar(t, _jordan, Posicion.escolta, monedas: 340);
      expect(nueva.plantel.en(Posicion.escolta), _jordan);
      expect(nueva.plantel.contiene(_wade), isFalse, reason: 'la vieja se pierde');
      expect(nueva.tirada, isNull, reason: 'el intercambio gasta la tirada');
      expect(nueva.tokens.gastadas, 340);
      expect(d.precioDe(nueva, TokenDraft.intercambio), isNull, reason: 'tope 1 por draft');
    });

    test('solo por una carta del mismo puesto, de esta tirada y que no repita persona', () {
      final d = draft();
      final t = conWade();
      expect(
        () => d.intercambiar(t, _pippen, Posicion.escolta, monedas: 999),
        throwsA(isA<ReglaPlantelException>()),
        reason: 'Pippen es alero',
      );
      expect(() => d.intercambiar(t, _kobe, Posicion.escolta, monedas: 999), throwsA(isA<ReglaPlantelException>()));
      expect(() => d.intercambiar(t.conTirada(null), _jordan, Posicion.escolta, monedas: 999), throwsA(anything));
    });

    test('con el descuento de nivel 10 baja el precio y se redondea a múltiplos de 5', () {
      final d = draft(const VentajasTokens(descuento: 20));
      expect(d.precioDe(conWade(), TokenDraft.intercambio, sale: _wade, entra: _jordan), 270);
    });
  });

  group('comodín', () {
    test('fija la franquicia: la próxima tirada es de esa franquicia, aun sin tirada previa', () {
      final d = draft();
      var t = _nueva();
      expect(d.precioDe(t, TokenDraft.comodin), 120);
      t = d.comodin(t, franquiciaId: 'BOS', monedas: 120);
      expect(t.tirada!.franquiciaId, 'BOS');
      expect(t.tokens.gastadas, 120);
      expect(t.rerollsRestantes, Temporada.rerollsPorTemporada, reason: 'no gasta la ficha de volver a tirar');
      expect(d.precioDe(t, TokenDraft.comodin), isNull, reason: 'tope 1 por draft');
    });

    test('fija la época, reemplaza la tirada en curso y valida los argumentos', () {
      final d = draft();
      final t = _nueva(tirada: _miami);
      expect(() => d.comodin(t, monedas: 120), throwsArgumentError);
      expect(() => d.comodin(t, franquiciaId: 'BOS', epoca: Epoca.anios90, monedas: 120), throwsArgumentError);
      expect(() => d.comodin(t, epoca: Epoca.anios90), throwsStateError, reason: 'sin monedas');
      final nueva = d.comodin(t, epoca: Epoca.anios90, monedas: 120);
      expect(nueva.tirada!.epoca, Epoca.anios90);
      expect(nueva.tirada!.franquiciaId, 'CHI');
      expect(() => d.comodin(t, franquiciaId: 'DEN', monedas: 120), throwsStateError, reason: 'DEN no tiene cartas');
      expect(d.franquiciasPosibles(t), {'MIA', 'CLE', 'BOS', 'CHI', 'LAL'});
      expect(d.epocasPosibles(t), {Epoca.anios2010, Epoca.anios90, Epoca.anios2000});
    });
  });

  group('modos: a quién se le cobra', () {
    test('Extremo no tiene tokens; los modos prestados solo traen sus fichas gratis', () {
      final d = draft();
      final extremo = _nueva(fichas: 0, modo: ModoJuego.extremo, tirada: _miami);
      expect(ReglasTokens.modoDe(extremo), ModoTokens.ninguno);
      for (final k in TokenDraft.values) {
        expect(Draft.trae(extremo, k), isFalse);
        expect(d.usosRestantes(extremo, k), 0);
      }
      expect(d.puedeVolverATirar(extremo, const {}), isFalse);

      final espejo = _nueva(fichas: 0, modo: ModoJuego.espejo, tirada: _miami);
      expect(ReglasTokens.modoDe(espejo), ModoTokens.soloReroll);
      expect(d.precioDe(espejo, TokenDraft.volverATirar), isNull, reason: 'no cobra monedas sin querer');
      expect(() => d.tirar(espejo, monedas: 9999), throwsStateError);
      expect(Draft.trae(espejo, TokenDraft.comodin), isFalse);
      final conFicha = _nueva(fichas: 1, modo: ModoJuego.dinastia, tirada: _miami);
      expect(d.tirar(conFicha).tokens.gastadas, 0);
    });

    test('Desafío del día: kit fijo y gratis (2 fichas, 1 mejor versión, 1 doble); Reto: solo 2 fichas', () {
      final d = draft();
      final dia = _nueva(fichas: ReglasTokens.rerollsKit, modo: ModoJuego.desafioDelDia, tirada: _miami);
      expect(d.precioDe(dia, TokenDraft.mejorVersion), 0);
      expect(d.precioDe(dia, TokenDraft.doble), 0);
      expect(Draft.trae(dia, TokenDraft.comodin), isFalse);
      expect(Draft.trae(dia, TokenDraft.intercambio), isFalse);
      final usada = d.mejorVersion(dia, _lebronMia);
      expect(usada.tokens.gastadas, 0);
      expect(d.precioDe(usada, TokenDraft.mejorVersion), isNull);
      // Las ventajas de nivel no cambian el kit: es igual para todos.
      final conNivel = draft(const VentajasTokens(descuento: 20, versionGratis: true));
      expect(conNivel.usosRestantes(dia, TokenDraft.mejorVersion), 1);
      // Las fichas del kit se gastan sin costo y la tercera no se puede pagar.
      var t = _nueva(fichas: ReglasTokens.rerollsKit, modo: ModoJuego.reto, tirada: _miami);
      t = d.tirar(d.tirar(t));
      expect(() => d.tirar(t, monedas: 9999), throwsStateError);
      expect(t.tokens.gastadas, 0);
      expect(Draft.trae(t, TokenDraft.mejorVersion), isFalse);
      expect(Draft.trae(t, TokenDraft.doble), isFalse);
    });

    test('aceptar un reto da el kit fijo sin importar el nivel del que acepta', () {
      final c = Reto.codigoDe(
        Temporada(id: 'c', franquiciaUsuarioId: 'BOS', datosModo: Reto.datosNuevos(2, azar: Random(1))),
      )!;
      final aceptada = Reto.aceptar(c, id: 'y', fichasExtra: 2);
      expect(aceptada.rerollsRestantes, ReglasTokens.rerollsKit);
      expect(ReglasTokens.modoDe(aceptada), ModoTokens.kit);
    });
  });

  group('retos y determinismo', () {
    test('gastar monedas en tokens no mueve las tiradas: mismas tiradas con el mismo código', () {
      final base = Temporada(
        id: 'a',
        franquiciaUsuarioId: 'CHI',
        rerollsRestantes: 1,
        datosModo: Reto.datosNuevos(1, azar: Random(7)),
      );
      final codigo = Reto.codigoDe(base)!;
      // El amigo juega el kit (2 fichas gratis); el creador, 1 gratis + 1 pagada con monedas.
      final amigo = Reto.aceptar(codigo, id: 'b');
      final dA = Draft(_catalogo, azarPara: Reto.azarPara(base));
      final dB = Draft(_catalogo, azarPara: Reto.azarPara(amigo));

      var a = dA.tirar(base), b = dB.tirar(amigo);
      expect(a.tirada, b.tirada, reason: 'primera tirada');
      a = dA.tirar(a);
      b = dB.tirar(b);
      expect(a.tirada, b.tirada, reason: 'primera vuelta, gratis para los dos');
      a = dA.tirar(a, monedas: 50);
      b = dB.tirar(b);
      expect(a.tokens.gastadas, 50);
      expect(a.tirada, b.tirada, reason: 'segunda vuelta: una se paga y otra es del kit, sale lo mismo');
    });

    test('una partida que pagó tokens ya no se puede retar; con solo fichas gratis, sí', () {
      final base = Temporada(
        id: 'a',
        franquiciaUsuarioId: 'CHI',
        rerollsRestantes: 1,
        datosModo: Reto.datosNuevos(1, azar: Random(7)),
      );
      expect(Reto.sePuedeRetar(base), isTrue);
      final d = Draft(_catalogo, azarPara: Reto.azarPara(base));
      var t = d.tirar(base);
      t = d.tirar(t);
      expect(Reto.sePuedeRetar(t), isTrue);
      t = d.tirar(t, monedas: 50);
      expect(t.tokens.usoPagos, isTrue);
      expect(Reto.sePuedeRetar(t), isFalse);
    });
  });

  group('JSON y partidas viejas', () {
    test('una partida vieja con 5 fichas carga igual: se conservan como gratis y sin tokens', () {
      final vieja = _json(_nueva(fichas: 5)).toJson()..remove('tokens');
      final t = Temporada.fromJson(vieja);
      expect(t.rerollsRestantes, 5);
      expect(t.tokens.vacio, isTrue);
      final d = draft();
      expect(d.precioDe(t, TokenDraft.volverATirar), 0);
      expect(d.usosRestantes(t, TokenDraft.volverATirar), 5 + 4, reason: '5 viejas + 4 de pago');
      var x = t.conTirada(_miami);
      for (var i = 0; i < 5; i++) {
        x = d.tirar(x);
      }
      expect(x.rerollsRestantes, 0);
      expect(x.tokens.gastadas, 0, reason: 'las fichas viejas no cobran monedas');
    });

    test('una partida sin tokens no escribe la clave; con tokens vuelve completa', () {
      expect(_nueva().toJson().containsKey('tokens'), isFalse);
      final d = draft();
      var t = _nueva(tirada: _miami);
      t = d.mejorVersion(t, _lebronMia, monedas: 150);
      t = d.tirar(d.tirar(t), monedas: 50);
      final vuelta = _json(t);
      expect(vuelta.tokens.gastadas, 200);
      expect(vuelta.tokens.usosDe(TokenDraft.mejorVersion), 1);
      expect(vuelta.tokens.pagosDe(TokenDraft.volverATirar), 1);
      expect(vuelta.tokens.usosDe(TokenDraft.volverATirar), 2);
    });
  });

  group('ventajas del entrenador', () {
    test('nivel 3: una ficha gratis más; nivel 10: −20 %; nivel 20: una mejor versión gratis', () {
      expect(PerfilEntrenador(xp: PerfilEntrenador.xpParaNivel(2)).fichasExtra, 0);
      expect(PerfilEntrenador(xp: PerfilEntrenador.xpParaNivel(3)).fichasExtra, 1);
      expect(PerfilEntrenador(xp: PerfilEntrenador.xpParaNivel(25)).fichasExtra, 1, reason: 'ya no hay segunda ficha');
      final n10 = VentajasTokens.de(PerfilEntrenador(xp: PerfilEntrenador.xpParaNivel(10)));
      expect((n10.descuento, n10.versionGratis), (20, false));
      final n20 = VentajasTokens.de(PerfilEntrenador(xp: PerfilEntrenador.xpParaNivel(20)));
      expect((n20.descuento, n20.versionGratis), (20, true));
      expect(VentajasTokens.de(const PerfilEntrenador()).descuento, 0);
    });

    test('fichas totales: 1 base y hasta 2 con nivel; nunca 5', () {
      const alto = PerfilEntrenador(xp: 999999);
      expect(Temporada.rerollsPorTemporada + alto.fichasExtra, 2);
    });
  });
}

// Modo cartas con el catálogo real (sin depender de medias concretas).
void cartasConCatalogoReal() {
  final catalogo = parsearCatalogo(File(rutaCatalogo).readAsStringSync());
  group('modo cartas con tokens', () {
    const base = Temporada(id: 'c', franquiciaUsuarioId: 'CHI', modo: ModoDraft.cartas, rerollsRestantes: 0);

    test('mejor versión reemplaza a la carta por la de mayor media de la misma persona', () {
      final d = Draft(catalogo, azar: Random(11));
      for (var i = 0; i < 40; i++) {
        final t = d.abrirSobre(d.repartir(base, Posicion.values[i % 6]), i % 3);
        for (final j in d.cartasDeOferta(t)) {
          final mejor = d.mejorVersionDe(t, j);
          if (mejor == null) continue;
          expect(mejor.nbaPlayerId, j.nbaPlayerId);
          expect(mejor.media, greaterThan(j.media));
          expect(d.versionesDe(j).first.media, greaterThanOrEqualTo(mejor.media));
          final nueva = d.mejorVersion(t, j, monedas: 150);
          expect(nueva.oferta!.cartaIds, contains(mejor.id));
          expect(nueva.oferta!.cartaIds, isNot(contains(j.id)));
          expect(nueva.oferta!.cartaIds, hasLength(t.oferta!.cartaIds.length));
          expect(nueva.tokens.gastadas, 150);
          return;
        }
      }
      fail('ningún reparto trajo una carta con mejor versión');
    });

    test('comodín: cambia el sobre de franquicia por el elegido, con las cartas suficientes', () {
      final d = Draft(catalogo, azar: Random(12));
      final t = d.repartir(base, Posicion.base);
      final posibles = d.franquiciasPosibles(t);
      expect(posibles, isNotEmpty);
      final elegida = posibles.firstWhere((f) => f != t.oferta!.sobres[1].franquiciaId);
      final nueva = d.comodinSobre(t, franquiciaId: elegida, monedas: 120);
      expect(nueva.oferta!.sobres, hasLength(3));
      expect(nueva.oferta!.sobres.where((s) => s.tipo == TipoSobre.franquicia).single.franquiciaId, elegida);
      expect(nueva.tokens.gastadas, 120);
      final abierta = d.abrirSobre(nueva, 1);
      expect(d.cartasDeOferta(abierta).every((j) => j.franquiciaId == elegida), isTrue);
    });
  });
}
