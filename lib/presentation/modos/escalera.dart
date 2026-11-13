import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/modo_juego.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/liga.dart';
import '../../domain/entities/metajuego.dart';
import '../../domain/misiones.dart';
import '../../domain/modos/escalera.dart';
import '../../domain/motor.dart';
import '../../domain/premios.dart' show apellido;
import '../compartir/tarjeta_compartir.dart';
import '../pantallas/partido_pantalla.dart';
import '../tema/tema_franquicia.dart';
import '../widgets/elegir_modo.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// Modos de escalera: una sucesión de cruces (partido único o serie) contra rivales armados a medida.
bool esModoEscalera(ModoJuego m) => ProgresoEscalera.esEscalera(m);

/// Arranca una partida nueva de uno de estos modos.
Future<void> iniciarEscalera(ModoJuego m, Franquicia enfocada, ContextoModos c) async {
  if (m == ModoJuego.escenario) return _iniciarEscenario(c);
  final modo = await elegirModoDraft(c.context);
  if (modo == null || !c.context.mounted) return;
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null) return;
  final t = Temporada(
    id: ContextoModos.nuevoId(),
    franquiciaUsuarioId: enfocada.id,
    modo: modo,
    dificultad: dificultad,
    modoJuego: m,
    rerollsRestantes: Temporada.rerollsPorTemporada + perfilApp.value.fichasExtra,
  );
  await c.guardar(t);
  await c.abrirTemporada(t);
}

Future<void> _iniciarEscenario(ContextoModos c) async {
  final esc = await showModalBottomSheet<Escenario>(
    context: c.context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => const _ElegirEscenario(),
  );
  if (esc == null || !c.context.mounted) return;
  final dificultad = await elegirDificultad(c.context);
  if (dificultad == null) return;
  final liga = await c.liga();
  final t = ModosEscalera(liga).nuevaDeEscenario(esc, id: ContextoModos.nuevoId(), dificultad: dificultad);
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// Pantalla propia del modo para la partida [t], o null si sigue el flujo clásico en su fase
/// (draft y tácticas, antes de la escalera).
Future<Widget?> pantallaEscalera(Temporada t, ContextoModos c) async {
  if (!t.plantel.completo || !t.tacticaConfirmada) return null;
  final liga = await c.liga();
  var x = t;
  if (!Escalera.de(x).iniciada) {
    x = ModosEscalera(liga).iniciar(x);
    await c.guardar(x);
  }
  return EscaleraPantalla(temporada: x, liga: liga, onCambio: c.guardar);
}

/// "Chicago Bulls 1995-96", "Detroit Pistons (90’)", "Boston Celtics (Histórico)".
String nombreRival(RivalEscalera r) => '${franquiciaPorId(r.identidadId).nombreCompleto} ${r.etiqueta}';

/// La escalera: progreso, el cruce que sigue (en vivo o simulado), las ventajas del Camino al
/// anillo, el cuadro del Mundial y el final.
class EscaleraPantalla extends StatefulWidget {
  const EscaleraPantalla({super.key, required this.temporada, required this.liga, required this.onCambio, this.azar});

  final Temporada temporada;
  final Liga liga;
  final ValueChanged<Temporada> onCambio;

  /// Azar fijo para pruebas.
  final Random? azar;

  @override
  State<EscaleraPantalla> createState() => _EscaleraPantallaState();
}

class _EscaleraPantallaState extends State<EscaleraPantalla> {
  late Temporada _t = widget.temporada;
  late final _modos = ModosEscalera(widget.liga, azar: widget.azar);
  var _ocupado = false;

  @override
  void didUpdateWidget(EscaleraPantalla vieja) {
    super.didUpdateWidget(vieja);
    if (!identical(vieja.temporada, widget.temporada)) _t = widget.temporada;
  }

  Escalera get _e => Escalera.de(_t);

  void _guardar(Temporada t) {
    // Misiones: cada partido ganado en un desafío cuenta (se cobra en el próximo guardado).
    final ganados = Escalera.de(t).victorias - _e.victorias;
    if (ganados > 0) Misiones.anotar(TipoMision.ganarDesafio, ganados);
    setState(() => _t = t);
    widget.onCambio(t);
  }

  Franquicia get _propia => franquiciaPorId(_t.franquiciaUsuarioId);

  Future<void> _vivo() async {
    final antes = _t;
    final motor = _modos.motor(antes);
    final rival = franquiciaPorId(_e.pendiente!.rival.identidadId);
    final local = motor.usuarioLocal!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidoPantalla(
          motor: motor,
          usuarioLocal: local,
          franquiciaUsuario: _propia,
          identidadLocal: local ? _propia : rival,
          identidadVisitante: local ? rival : _propia,
          onTerminado: (MotorPartido m) => _guardar(_modos.registrar(antes, m)),
        ),
      ),
    );
  }

  Future<void> _simular({bool cruce = false}) async {
    setState(() => _ocupado = true);
    await Future<void>.delayed(Duration.zero);
    _guardar(cruce ? _modos.simularCruce(_t) : _modos.simularPartido(_t));
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final modo = _t.modoJuego;
    final pendiente = e.pendiente;
    final escenario = escenarioPorId(e.escenarioId);
    return Scaffold(
      appBar: AppBar(title: Text(escenario?.titulo ?? modo.nombre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Encabezado(temporada: _t, escalera: e, escenario: escenario),
          const SizedBox(height: 12),
          if (e.terminada)
            _Final(temporada: _t, escalera: e, onSalir: () => Navigator.of(context).popUntil((r) => r.isFirst))
          else if (e.esperandoVentaja)
            _Ventajas(opciones: e.ofrecidas, onElegir: (v) => _guardar(_modos.elegirVentaja(_t, v)))
          else if (pendiente != null)
            _ProximoCruce(
              cruce: pendiente,
              plantel: [for (final id in pendiente.rival.cartaIds.values) ?widget.liga.jugador(id)],
              propia: _propia,
              ocupado: _ocupado,
              onVivo: _vivo,
              onSimular: () => _simular(),
              onSimularSerie: pendiente.esSerie ? () => _simular(cruce: true) : null,
            ),
          const SizedBox(height: 16),
          if (modo == ModoJuego.mundial)
            _CuadroMundial(escalera: e, propia: _propia)
          else
            _Escalones(temporada: _t, escalera: e, propia: _propia),
        ],
      ),
    );
  }
}

BoxDecoration _panel(ColorScheme esquema, {bool resaltado = false}) => BoxDecoration(
  color: esquema.surfaceContainerLowest,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: resaltado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
    width: resaltado ? 1.5 : 1,
  ),
);

const _titular = TextStyle(
  fontFamily: Fuentes.estadio,
  fontVariations: [FontVariation.weight(800)],
  fontSize: 20,
  letterSpacing: 0.5,
);

/// Marcador grande del modo: récord, racha o serie, y lo que falta.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.temporada, required this.escalera, this.escenario});

  final Temporada temporada;
  final Escalera escalera;
  final Escenario? escenario;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = escalera;
    final (led, etiqueta, detalle) = switch (temporada.modoJuego) {
      ModoJuego.racha => (
        '${e.racha}',
        'RACHA',
        'Mejor racha: ${max(perfilApp.value.mejorRacha, e.racha)} · cada rival es un poco más fuerte',
      ),
      ModoJuego.escenario => ('${e.actual?.propias ?? 0}-${e.actual?.ajenas ?? 0}', 'SERIE', escenario?.relato ?? ''),
      ModoJuego.mundial => (
        '${e.victorias}-${e.derrotas}',
        'RÉCORD',
        e.ganadores.length < rondasMundial.length
            ? 'Ronda: ${rondasMundial[e.ganadores.length]} · 32 franquicias con planteles de toda su historia'
            : 'Mundial terminado',
      ),
      _ => (
        '${e.cruces.where((c) => c.ganado).length}/${e.total}',
        temporada.modoJuego == ModoJuego.caminoAlAnillo ? 'ESCALONES' : 'GANADOS',
        temporada.modoJuego == ModoJuego.caminoAlAnillo
            ? 'Partido único en cada escalón; Las Finales, al mejor de 7. Si perdés, se termina.'
            : 'Series al mejor de 3, del más chico al más grande. Si perdés, se termina.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(temporada.modoJuego.nombre.toUpperCase(), style: _titular),
                const SizedBox(height: 4),
                Text(detalle, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  temporada.dificultad.nombre.toUpperCase(),
                  style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              TextoLed(led, tamano: 40),
              Text(etiqueta, style: tema.textTheme.labelSmall?.copyWith(letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

/// El cruce que sigue: escudos, formato, figuras del rival y los botones.
class _ProximoCruce extends StatelessWidget {
  const _ProximoCruce({
    required this.cruce,
    required this.plantel,
    required this.propia,
    required this.ocupado,
    required this.onVivo,
    required this.onSimular,
    this.onSimularSerie,
  });

  final Cruce cruce;
  final List<Jugador> plantel;
  final Franquicia propia;
  final bool ocupado;
  final VoidCallback onVivo, onSimular;
  final VoidCallback? onSimularSerie;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final rival = franquiciaPorId(cruce.rival.identidadId);
    final figuras = [...plantel]..sort((a, b) => b.media.compareTo(a.media));
    final formato = switch (cruce.aGanar) {
      1 => 'Partido único',
      2 => 'Al mejor de 3',
      3 => 'Al mejor de 5',
      _ => 'Al mejor de 7',
    };
    final local = cruce.usuarioLocalProximo ? 'de local' : 'de visitante';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema, resaltado: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(cruce.titulo.toUpperCase(), style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Escudo(propia, tamano: 52),
              Expanded(
                child: Column(
                  children: [
                    if (cruce.esSerie) TextoLed('${cruce.propias}-${cruce.ajenas}', tamano: 34) else const Text('VS'),
                    if (cruce.esSerie)
                      Text('Juego ${cruce.juego + 1}', style: tema.textTheme.labelSmall?.copyWith(letterSpacing: 1)),
                  ],
                ),
              ),
              Escudo(rival, tamano: 52),
            ],
          ),
          const SizedBox(height: 12),
          Text(nombreRival(cruce.rival), style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
          Text(
            '$formato · $local · media ${cruce.rival.media.toStringAsFixed(1)}',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.primary),
          ),
          const SizedBox(height: 4),
          Text(
            figuras.take(3).map((j) => '${apellido(j)} ${j.media}').join(' · '),
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: ocupado ? null : onVivo,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('JUGAR EN VIVO'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: ocupado ? null : onSimular,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('SIMULAR'),
                ),
              ),
              if (onSimularSerie != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: ocupado ? null : onSimularSerie,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('SIMULAR SERIE'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Camino al anillo: 1 de 3 ventajas antes del próximo escalón.
class _Ventajas extends StatelessWidget {
  const _Ventajas({required this.opciones, required this.onElegir});

  final List<VentajaCamino> opciones;
  final ValueChanged<VentajaCamino> onElegir;

  static IconData _icono(VentajaCamino v) => switch (v) {
    VentajaCamino.inspiracion => Icons.campaign,
    VentajaCamino.figura => Icons.star,
    VentajaCamino.quimica => Icons.handshake,
    VentajaCamino.refuerzo => Icons.person_add_alt_1,
    VentajaCamino.piernasFrescas => Icons.bedtime,
    VentajaCamino.scouting => Icons.ondemand_video,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('¡ESCALÓN SUPERADO!', style: _titular),
        Text('Elegí una ventaja para lo que viene:', style: tema.textTheme.bodyMedium),
        const SizedBox(height: 8),
        for (final v in opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: esquema.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: esquema.primary.withValues(alpha: 0.6)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(_icono(v), color: esquema.primary),
                title: Text(v.nombre.toUpperCase(), style: tema.textTheme.titleSmall?.copyWith(letterSpacing: 0.5)),
                subtitle: Text(v.descripcion),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onElegir(v),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fin del modo: campeón o eliminado.
class _Final extends StatelessWidget {
  const _Final({required this.temporada, required this.escalera, required this.onSalir});

  final Temporada temporada;
  final Escalera escalera;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = escalera;
    final ultimo = e.actual;
    final campeonMundial = e.cuadro.isNotEmpty && e.ganadores.length == rondasMundial.length
        ? e.cuadro[e.ganadores.last.first]
        : null;
    final (titulo, texto) = switch (temporada.modoJuego) {
      ModoJuego.racha => (
        'SE CORTÓ LA RACHA',
        'Ganaste ${e.racha} seguidos. Te frenaron los ${ultimo == null ? '' : nombreRival(ultimo.rival)}.',
      ),
      _ when e.completada => switch (temporada.modoJuego) {
        ModoJuego.caminoAlAnillo => ('¡EL ANILLO ES TUYO!', 'Superaste los 10 escalones. Trofeo a la vitrina.'),
        ModoJuego.mejoresEquipos => (
          '¡EL MEJOR DE LA HISTORIA!',
          'Le ganaste a los 10 mejores equipos de todos los tiempos.',
        ),
        ModoJuego.mundial => ('¡CAMPEÓN DEL MUNDO!', 'Tu plantel le ganó a la historia de todas las franquicias.'),
        _ => ('¡LO CAMBIASTE!', 'La historia ahora tiene otro final.'),
      },
      ModoJuego.mundial => (
        'AFUERA DEL MUNDIAL',
        'Campeón: ${campeonMundial == null ? 'tu equipo' : nombreRival(campeonMundial)}.',
      ),
      ModoJuego.escenario => ('LA HISTORIA SE REPITIÓ', 'Esta vez tampoco. Podés volver a intentarlo.'),
      _ => (
        'SE TERMINÓ',
        'Llegaste a ${ultimo?.titulo ?? ''}: te eliminaron los ${ultimo == null ? '' : nombreRival(ultimo.rival)}.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(esquema, resaltado: e.completada),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(e.completada ? Icons.emoji_events : Icons.flag_outlined, color: esquema.primary, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text(titulo, style: _titular)),
            ],
          ),
          const SizedBox(height: 8),
          Text(texto),
          const SizedBox(height: 4),
          Text(
            'Partidos: ${e.victorias}-${e.derrotas}',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onSalir, child: const Text('VOLVER AL INICIO')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => compartirPartida(context, temporada),
            icon: const Icon(Icons.ios_share),
            label: const Text('COMPARTIR'),
          ),
        ],
      ),
    );
  }
}

/// Los escalones jugados, el actual y (si se conocen) los que vienen.
class _Escalones extends StatelessWidget {
  const _Escalones({required this.temporada, required this.escalera, required this.propia});

  final Temporada temporada;
  final Escalera escalera;
  final Franquicia propia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final e = escalera;
    final total = e.total;
    final futuros = total == null ? 0 : max(0, total - e.cruces.length);
    final conocidos = temporada.modoJuego == ModoJuego.mejoresEquipos;
    final filas = <Widget>[
      // Los más nuevos arriba.
      for (final (i, c) in e.cruces.indexed.toList().reversed)
        _FilaEscalon(numero: i + 1, cruce: c, actual: i == e.cruces.length - 1 && !c.terminado),
    ];
    final proximos = <Widget>[
      for (var k = 0; k < futuros; k++)
        _FilaFutura(
          numero: e.cruces.length + k + 1,
          equipo: conocidos ? mejoresEquipos[e.cruces.length + k] : null,
          esFinal: temporada.modoJuego == ModoJuego.caminoAlAnillo && e.cruces.length + k + 1 == total,
        ),
    ];
    if (filas.length <= 1 && proximos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (proximos.isNotEmpty) ...[
          Text('LO QUE VIENE', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          ...proximos.reversed,
          const SizedBox(height: 12),
        ],
        Text('TU CAMINO', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
        const SizedBox(height: 4),
        ...filas,
      ],
    );
  }
}

class _FilaEscalon extends StatelessWidget {
  const _FilaEscalon({required this.numero, required this.cruce, required this.actual});

  final int numero;
  final Cruce cruce;
  final bool actual;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final c = cruce;
    final resultado = !c.terminado
        ? (c.esSerie ? '${c.propias}-${c.ajenas}' : '—')
        : c.esSerie
        ? '${c.propias}-${c.ajenas}'
        : '${c.marcadores.last.$1}-${c.marcadores.last.$2}';
    final color = !c.terminado
        ? esquema.primary
        : c.ganado
        ? esquema.onSurface
        : esquema.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 30, child: TextoLed('$numero', tamano: 16, color: esquema.onSurfaceVariant)),
          Escudo(franquiciaPorId(c.rival.identidadId), tamano: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nombreRival(c.rival),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodyMedium?.copyWith(fontWeight: actual ? FontWeight.w700 : null),
            ),
          ),
          const SizedBox(width: 8),
          if (c.terminado) Icon(c.ganado ? Icons.check : Icons.close, size: 16, color: color),
          const SizedBox(width: 4),
          TextoLed(resultado, tamano: 16, color: color),
        ],
      ),
    );
  }
}

class _FilaFutura extends StatelessWidget {
  const _FilaFutura({required this.numero, this.equipo, this.esFinal = false});

  final int numero;
  final EquipoHistorico? equipo;
  final bool esFinal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = equipo;
    return Opacity(
      opacity: 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 30, child: TextoLed('$numero', tamano: 16, color: esquema.onSurfaceVariant)),
            if (e != null)
              Escudo(franquiciaPorId(e.identidadId), tamano: 28)
            else
              Icon(esFinal ? Icons.emoji_events_outlined : Icons.lock_outline, size: 28, color: esquema.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                e != null
                    ? '${franquiciaPorId(e.identidadId).nombreCompleto} ${e.etiqueta}'
                    : esFinal
                    ? 'Las Finales: uno de los mejores de la historia'
                    : 'Rival sorpresa',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mundial: tu camino y las llaves de cada ronda.
class _CuadroMundial extends StatelessWidget {
  const _CuadroMundial({required this.escalera, required this.propia});

  final Escalera escalera;
  final Franquicia propia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final e = escalera;
    if (e.cuadro.isEmpty) return const SizedBox.shrink();
    final rondas = e.ganadores.length;
    // La ronda en juego (o la última, si terminó): sus llaves con resultado si ya se jugaron.
    final mostrar = min(rondas, rondasMundial.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('EL CUADRO', style: tema.textTheme.labelLarge?.copyWith(letterSpacing: 1)),
        const SizedBox(height: 4),
        for (var r = mostrar; r >= 0; r--)
          Theme(
            data: tema.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: r == mostrar,
              title: Text(rondasMundial[r], style: tema.textTheme.titleSmall),
              children: [
                for (final (a, b, ganador, marcador) in _llaves(e, r))
                  _LlaveMundial(cuadro: e.cuadro, a: a, b: b, ganador: ganador, marcador: marcador, propia: propia),
              ],
            ),
          ),
      ],
    );
  }

  List<(int, int, int?, String?)> _llaves(Escalera e, int r) {
    final part = r == 0 ? [for (var i = 0; i < 32; i++) i] : e.ganadores[r - 1];
    final jugada = e.ganadores.length > r;
    return [
      for (var k = 0; k + 1 < part.length; k += 2)
        (part[k], part[k + 1], jugada ? e.ganadores[r][k ~/ 2] : null, jugada ? e.marcadoresCuadro[r][k ~/ 2] : null),
    ];
  }
}

class _LlaveMundial extends StatelessWidget {
  const _LlaveMundial({
    required this.cuadro,
    required this.a,
    required this.b,
    required this.ganador,
    required this.marcador,
    required this.propia,
  });

  final List<RivalEscalera?> cuadro;
  final int a, b;
  final int? ganador;
  final String? marcador;
  final Franquicia propia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tuya = cuadro[a] == null || cuadro[b] == null;
    Widget lado(int i) {
      final r = cuadro[i];
      final f = r == null ? propia : franquiciaPorId(r.identidadId);
      final perdio = ganador != null && ganador != i;
      return Expanded(
        child: Opacity(
          opacity: perdio ? 0.4 : 1,
          child: Row(
            children: [
              Escudo(f, tamano: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  r == null ? 'VOS' : f.id,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.labelLarge?.copyWith(
                    fontWeight: r == null ? FontWeight.w800 : null,
                    color: r == null ? esquema.primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tuya ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          lado(a),
          SizedBox(
            width: 70,
            child: Center(child: TextoLed(marcador ?? 'vs', tamano: 14, color: esquema.onSurfaceVariant)),
          ),
          lado(b),
        ],
      ),
    );
  }
}

/// Hoja para elegir el escenario histórico.
class _ElegirEscenario extends StatelessWidget {
  const _ElegirEscenario();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿QUÉ MOMENTO REESCRIBÍS?', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 12),
          for (final e in escenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: esquema.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.5)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(e),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Escudo(franquiciaPorId(e.usuario.identidadId), tamano: 34),
                        const SizedBox(width: 4),
                        TextoLed('${e.propias}-${e.ajenas}', tamano: 16),
                        const SizedBox(width: 4),
                        Escudo(franquiciaPorId(e.rival.identidadId), tamano: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.titulo, style: tema.textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                e.relato,
                                style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
