import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/jugador.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../../domain/modos/medidor_tiro.dart';
import '../../domain/motor.dart' show ModoMedidor;
import '../../domain/modos/vida_carrera.dart';
import 'carrera_equipo_pantallas.dart';
import '../widgets/disposicion.dart';
import '../widgets/escudo.dart';
import '../widgets/jugador_avatar.dart';
import '../widgets/texto_led.dart';

String _n1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

Franquicia _franq(String id) => franquiciaPorId(id);

/// Barra con nombre, valor y color (confianza, ánimo, fans, relación…).
class BarraNivel extends StatelessWidget {
  const BarraNivel({super.key, required this.etiqueta, required this.valor, this.maximo = 100, this.pie});

  final String etiqueta;
  final int valor;
  final int maximo;
  final String? pie;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final f = (valor / maximo).clamp(0.0, 1.0);
    final color = f >= 0.6 ? const Color(0xFF46C46E) : (f >= 0.35 ? const Color(0xFFF5B83D) : const Color(0xFFE5484D));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(etiqueta, style: tema.textTheme.bodySmall)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: f,
                minHeight: 7,
                color: color,
                backgroundColor: tema.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(pie ?? '$valor', textAlign: TextAlign.end, style: tema.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

String _etiquetaConfianza(int c) => c >= 80
    ? 'Intocable'
    : c >= 60
    ? 'Titular'
    : c >= 35
    ? 'A prueba'
    : 'En duda';

/// Marco común de un panel de la carrera.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.destacado = false});

  final Widget child;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: destacado ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.6),
          width: destacado ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// Atributos con botones para subirlos, y las insignias. Se usa en el receso y en la pantalla de tu jugador.
class PanelAtributos extends StatelessWidget {
  const PanelAtributos({
    super.key,
    required this.estado,
    required this.carrera,
    required this.onSubir,
    this.onSubirHabilidad,
  });

  final EstadoCarrera estado;
  final CarreraJugador carrera;
  final ValueChanged<Atributo> onSubir;
  final ValueChanged<Habilidad>? onSubirHabilidad;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('PUNTOS DE HABILIDAD', style: tema.textTheme.labelLarge),
            const Spacer(),
            TextoLed('${estado.phBanco}', tamano: 26),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Los ganás jugando bien, cumpliendo los objetivos y con los premios. Cuanto más alto el atributo, más '
          'cuesta subirlo. Cada jugador tiene un potencial que no se ve: pasarte se puede, pero sale más caro (se nota en el botón con ▲).',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        if (carrera.avisoPuntosSinUsar(estado) case final aviso?) ...[
          const SizedBox(height: 6),
          Text(aviso, style: tema.textTheme.bodySmall?.copyWith(color: esquema.primary)),
        ],
        const SizedBox(height: 8),
        for (final a in Atributo.values)
          _FilaAtributo(
            atributo: a,
            valor: estado.atributos[a],
            cambio: estado.atributos[a] - estado.atributosBase[a],
            costo: carrera.costoMejora(estado, a),
            puede: carrera.puedeSubir(estado, a),
            techo: carrera.enTecho(estado, a),
            onSubir: () => onSubir(a),
          ),
        if (onSubirHabilidad != null) ...[
          const SizedBox(height: 12),
          Text('HABILIDADES ESPECÍFICAS', style: tema.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            'Cada atributo se abre en habilidades más finas. Sumales puntos a las que más usás: salen más baratos '
            'que un atributo entero y te acercan a las insignias.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          for (final at in Atributo.values)
            Material(
              type: MaterialType.transparency,
              child: Theme(
                data: tema.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(at.etiqueta, style: tema.textTheme.bodyMedium),
                  children: [
                    for (final h in Habilidad.de(at))
                      _FilaHabilidad(
                        habilidad: h,
                        valor: Habilidad.valor(h, estado.atributos, estado.espec),
                        espec: estado.espec[h] ?? 0,
                        costo: carrera.costoHabilidad(estado, h),
                        puede: carrera.puedeSubirHabilidad(estado, h),
                        afin: VidaCarrera.afines(estado.base.rol).contains(h),
                        onSubir: () => onSubirHabilidad!(h),
                      ),
                  ],
                ),
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: Theme(
              data: tema.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Rasgos mentales', style: tema.textTheme.bodyMedium),
                children: [
                  for (final h in Habilidad.mentales)
                    _FilaHabilidad(
                      habilidad: h,
                      valor: Habilidad.valor(h, estado.atributos, estado.espec),
                      espec: estado.espec[h] ?? 0,
                      costo: carrera.costoHabilidad(estado, h),
                      puede: carrera.puedeSubirHabilidad(estado, h),
                      onSubir: () => onSubirHabilidad!(h),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('INSIGNIAS', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        _InsigniasPorFamilia(estado: estado),
        const SizedBox(height: 4),
        Text(
          'Tocá una insignia para ver qué pide. Tienen cuatro grados (Bronce, Plata, Oro y Leyenda) y cada grado '
          'suma más a tus estadísticas.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

Color _colorGrado(GradoInsignia g, ColorScheme esquema) => switch (g) {
  GradoInsignia.ninguno => esquema.outlineVariant,
  GradoInsignia.bronce => const Color(0xFFB87333),
  GradoInsignia.plata => const Color(0xFFB8BCC4),
  GradoInsignia.oro => const Color(0xFFE0B52E),
  GradoInsignia.leyenda => const Color(0xFFB478F0),
};

/// Las insignias agrupadas por familia: las que ya tenés (con su grado) primero y después las que faltan.
class _InsigniasPorFamilia extends StatelessWidget {
  const _InsigniasPorFamilia({required this.estado});

  final EstadoCarrera estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ctx = estado.contexto;
    final grados = Insignia.grados(ctx);
    final tiene = grados.values.where((g) => g.nivel >= 1).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$tiene de ${Insignia.values.length} desbloqueadas', style: tema.textTheme.bodySmall),
        for (final f in FamiliaInsignia.values) ...[
          const SizedBox(height: 8),
          Text(f.etiqueta, style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final i in ([
                ...Insignia.values.where((x) => x.familia == f),
              ]..sort((a, b) => grados[b]!.nivel.compareTo(grados[a]!.nivel))))
                _ChipInsignia(insignia: i, grado: grados[i]!, ctx: ctx),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChipInsignia extends StatelessWidget {
  const _ChipInsignia({required this.insignia, required this.grado, required this.ctx});

  final Insignia insignia;
  final GradoInsignia grado;
  final ContextoInsignia ctx;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = _colorGrado(grado, esquema);
    final tiene = grado.nivel >= 1;
    final siguiente = insignia.umbralDe(grado);
    final puntaje = insignia.puntaje(ctx);
    final msg = StringBuffer(insignia.descripcion);
    msg.write(tiene ? '\nGrado: ${grado.etiqueta}.' : '\nTodavía bloqueada.');
    if (siguiente != null) {
      final prox = GradoInsignia.deNivel(grado.nivel + 1).etiqueta;
      msg.write('\nPara $prox: puntaje $siguiente (tenés $puntaje).');
    }
    return Tooltip(
      message: msg.toString(),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: Chip(
        avatar: Icon(tiene ? Icons.verified : Icons.lock_outline, size: 16, color: color),
        label: Text(tiene ? '${insignia.etiqueta} · ${grado.etiqueta}' : insignia.etiqueta),
        side: BorderSide(color: color, width: tiene ? 1.5 : 1),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FilaHabilidad extends StatelessWidget {
  const _FilaHabilidad({
    required this.habilidad,
    required this.valor,
    required this.espec,
    required this.costo,
    required this.puede,
    required this.onSubir,
    this.afin = false,
  });

  final Habilidad habilidad;
  final int valor, espec, costo;
  final bool puede, afin;
  final VoidCallback onSubir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final maximo = espec >= Habilidad.maxEspecializacion || valor >= 99;
    return Tooltip(
      message: afin ? '${habilidad.descripcion}\nVa con tu arquetipo: sube un 30 % más barato.' : habilidad.descripcion,
      triggerMode: TooltipTriggerMode.longPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                afin ? '★ ${habilidad.etiqueta}' : habilidad.etiqueta,
                style: tema.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 30, child: TextoLed('$valor', tamano: 16)),
            SizedBox(
              width: 30,
              child: Text(
                espec == 0 ? '' : '+$espec',
                style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary),
              ),
            ),
            FilledButton.tonal(
              onPressed: puede ? onSubir : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(maximo ? 'MÁX.' : '+1 · $costo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Qué trabajás este receso: una rutina por temporada, con su premio al cerrar el año.
class _PanelRutina extends StatelessWidget {
  const _PanelRutina({required this.estado, required this.onElegir});

  final EstadoCarrera estado;
  final ValueChanged<Rutina> onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final actual = VidaCarrera.rutinaDe(estado);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RUTINA DE LA PRÓXIMA TEMPORADA', style: tema.textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(
          'Elegí en qué trabajar este verano: es un punto gratis al cerrar el año, sin gastar tus puntos.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final r in Rutina.values)
              ChoiceChip(label: Text(r.etiqueta), selected: actual == r, onSelected: (_) => onElegir(r)),
          ],
        ),
        const SizedBox(height: 6),
        Text(actual?.descripcion ?? 'Todavía no elegiste ninguna.', style: tema.textTheme.bodySmall),
      ],
    );
  }
}

String _avanceCorto(ObjetivoTemporada o, double v) => o.tipo.entero ? '${v.round()}' : _n1(v);

/// Elegí entre 4 y 6 de los 8 objetivos que te ofrece el DT para la temporada (hasta jugar el primer partido).
class ElegirObjetivosPantalla extends StatefulWidget {
  const ElegirObjetivosPantalla({super.key, required this.estado, required this.onConfirmar});

  final EstadoCarrera estado;
  final ValueChanged<EstadoCarrera> onConfirmar;

  @override
  State<ElegirObjetivosPantalla> createState() => _ElegirObjetivosPantallaState();
}

class _ElegirObjetivosPantallaState extends State<ElegirObjetivosPantalla> {
  late final Set<int> _elegidos = {
    for (var i = 0; i < widget.estado.ofrecidos.length; i++)
      if (widget.estado.objetivos.contains(widget.estado.ofrecidos[i])) i,
  };

  bool get _valido =>
      _elegidos.length >= ObjetivosCarrera.minAceptados && _elegidos.length <= ObjetivosCarrera.maxAceptados;

  int get _puntos => _elegidos.fold(0, (a, i) => a + widget.estado.ofrecidos[i].nivel.puntos);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final o = widget.estado.ofrecidos;
    return Scaffold(
      appBar: AppBar(title: const Text('Objetivos de la temporada')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  Text(
                    'El DT te ofrece ${o.length}. Elegí entre ${ObjetivosCarrera.minAceptados} y '
                    '${ObjetivosCarrera.maxAceptados}: lo difícil da más puntos de habilidad, pero si no lo cumplís '
                    'no suma (y la confianza del DT baja). Podés cambiar hasta jugar el primer partido.',
                    style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < o.length; i++)
                    CheckboxListTile(
                      value: _elegidos.contains(i),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          if (_elegidos.length < ObjetivosCarrera.maxAceptados) _elegidos.add(i);
                        } else {
                          _elegidos.remove(i);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(o[i].texto),
                      subtitle: Text('${o[i].tipo.familia.etiqueta} · ${o[i].nivel.etiqueta}'),
                      secondary: Text(
                        '+${o[i].nivel.puntos}',
                        style: tema.textTheme.titleMedium?.copyWith(color: esquema.primary),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Elegiste ${_elegidos.length} (${ObjetivosCarrera.minAceptados} a ${ObjetivosCarrera.maxAceptados}) · hasta $_puntos puntos',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _valido
                        ? () {
                            widget.onConfirmar(ObjetivosCarrera.elegir(widget.estado, _elegidos));
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text('CONFIRMAR OBJETIVOS'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-objetivo del mes y objetivos de carrera (varias temporadas).
class PanelObjetivosLargos extends StatelessWidget {
  const PanelObjetivosLargos({super.key, required this.estado});

  final EstadoCarrera estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final mini = ObjetivosCarrera.miniActual(estado);
    final pendientes =
        [
          for (final o in ObjetivoCarrera.values)
            if (!o.lograda(estado)) o,
        ]..sort((a, b) {
          double f(ObjetivoCarrera o) => o.avance(estado).$1 / o.avance(estado).$2;
          return f(b).compareTo(f(a));
        });
    final hechos = ObjetivoCarrera.values.where((o) => o.lograda(estado)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mini != null) ...[
          Text('MINI-OBJETIVO DEL MES ${ObjetivosCarrera.mesActual(estado)}', style: tema.textTheme.labelLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(ObjetivosCarrera.textoMini(mini.$1, mini.$2), style: tema.textTheme.bodyMedium)),
              Text(
                '${ObjetivosCarrera.valorMes(mini.$1, estado.uso).toStringAsFixed(mini.$1 == MiniObjetivo.victorias || mini.$1 == MiniObjetivo.partidos25 ? 0 : 1).replaceAll('.', ',')} '
                '(${estado.uso['mes:n'] ?? 0}/${MiniObjetivo.partidosPorMes})',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if ((estado.uso['sc:semana'] ?? 0) + (estado.uso['sc:mes'] ?? 0) + (estado.uso['sc:novMes'] ?? 0) + (estado.uso['sc:clutch'] ?? 0) > 0) ...[
          Text('PREMIOS DE ESTE AÑO', style: tema.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if ((estado.uso['sc:semana'] ?? 0) > 0) Chip(visualDensity: VisualDensity.compact, label: Text('Jugador de la semana ×${estado.uso['sc:semana']}')),
              if ((estado.uso['sc:mes'] ?? 0) > 0) Chip(visualDensity: VisualDensity.compact, label: Text('Jugador del mes ×${estado.uso['sc:mes']}')),
              if ((estado.uso['sc:novMes'] ?? 0) > 0) Chip(visualDensity: VisualDensity.compact, label: Text('Novato del mes ×${estado.uso['sc:novMes']}')),
              if ((estado.uso['sc:clutch'] ?? 0) > 0) Chip(visualDensity: VisualDensity.compact, label: Text('Partidos clutch ×${estado.uso['sc:clutch']} (6 = Clutch Player)')),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: Text('OBJETIVOS DE CARRERA', style: tema.textTheme.labelLarge)),
            Text('$hechos/${ObjetivoCarrera.values.length}', style: tema.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        for (final o in pendientes.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(o.texto, style: tema.textTheme.bodySmall)),
                    Text('+${o.puntos}', style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary)),
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: (o.avance(estado).$1 / o.avance(estado).$2).clamp(0.0, 1.0),
                  minHeight: 4,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// De dónde salieron los puntos de habilidad de esta temporada: rendimiento, notas de partido, objetivos,
/// premios y eventos. Los números salen de `EstadoCarrera.uso` (claves `dg:` y `gr:`).
class PanelDesglose extends StatelessWidget {
  const PanelDesglose({super.key, required this.estado});

  final EstadoCarrera estado;

  static String _n(num v) => (v / 100).toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final u = estado.uso;
    final filas = <(String, String, int)>[
      ('Rendimiento', 'Tus números de la temporada, sin tope por edad.', u['dg:rend'] ?? 0),
      ('Notas de partido', 'Cada partido tiene una nota de D a A+.', u['dg:nota'] ?? 0),
      ('Objetivos', 'Los que cumpliste al cerrar la temporada.', u['dg:obj'] ?? 0),
      ('Premios', 'Título, premios individuales y All-Star.', u['dg:prem'] ?? 0),
      ('Mini-objetivos', 'Los del mes que cumpliste.', u['dg:mes'] ?? 0),
      ('Eventos', 'Decisiones fuera de la cancha.', u['dg:evento'] ?? 0),
    ];
    final total = filas.fold(0, (a, f) => a + f.$3);
    final notas = [
      for (final n in Nota.values)
        if ((u['gr:${n.etiqueta}'] ?? 0) > 0) (n, u['gr:${n.etiqueta}']!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('PUNTOS DE ESTA TEMPORADA', style: tema.textTheme.labelLarge)),
            TextoLed(_n(total), tamano: 20),
          ],
        ),
        const SizedBox(height: 6),
        for (final f in filas)
          if (f.$3 > 0 || f.$1 == 'Rendimiento' || f.$1 == 'Notas de partido')
            Tooltip(
              message: f.$2,
              triggerMode: TooltipTriggerMode.tap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(f.$1, style: tema.textTheme.bodyMedium)),
                    Text(_n(f.$3), style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary)),
                  ],
                ),
              ),
            ),
        if (notas.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Tus notas', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final n in notas)
                Chip(visualDensity: VisualDensity.compact, label: Text('${n.$1.etiqueta} ×${n.$2}')),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Los puntos de rendimiento y de las notas se acreditan mientras jugás; los de objetivos y premios, '
          'al cerrar el año. Las notas suman por partido y se juntan hasta completar un punto entero.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Cómo jugás el control del partido: cuándo aparece la barra de tiro, el tamaño de la zona verde y cómo se suelta.
class PanelControlPartido extends StatelessWidget {
  const PanelControlPartido({super.key, required this.estado, required this.alCambiar});

  final EstadoCarrera estado;
  final ValueChanged<AjustesMedidor> alCambiar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final a = AjustesMedidor.de(estado);
    final u = estado.uso;
    final perfectos = u['q:perfecto'] ?? 0;
    final total = perfectos + (u['q:bueno'] ?? 0) + (u['q:temprano'] ?? 0) + (u['q:tarde'] ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTROL DEL PARTIDO', style: tema.textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(
          'Jugando en vivo, tus tiros y tu defensa directa se resuelven con la barra: tu timing decide. Al simular, '
          'todo sigue automático.',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ModoMedidor>(
          segments: [for (final m in ModoMedidor.values) ButtonSegment(value: m, label: Text(m.etiqueta, textAlign: TextAlign.center))],
          selected: {a.modo},
          showSelectedIcon: false,
          onSelectionChanged: (s) => alCambiar(a.copyWith(modo: s.first)),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 4),
        Text(a.modo.descripcion, style: tema.textTheme.bodySmall),
        const SizedBox(height: 8),
        Text('Zona verde', style: tema.textTheme.bodySmall),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: [for (var i = 0; i < 3; i++) ButtonSegment(value: i, label: Text(AjustesMedidor.nombresZona[i]))],
          selected: {a.zona},
          showSelectedIcon: false,
          onSelectionChanged: (s) => alCambiar(a.copyWith(zona: s.first)),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Mantener y soltar'),
            subtitle: const Text('En vez de tocar una vez: mantenés apretado mientras se llena y soltás.'),
            value: a.mantener,
            onChanged: (v) => alCambiar(a.copyWith(mantener: v)),
          ),
        ),
        if (total > 0)
          Text(
            'Tus timings: $perfectos perfectos de $total (${(100 * perfectos / total).round()} %).',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.primary),
          ),
      ],
    );
  }
}

/// Tu personalidad, la química con el plantel y lo que los rivales saben de vos.
class PanelMundo extends StatelessWidget {
  const PanelMundo({super.key, required this.estado});

  final EstadoCarrera estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final p = VidaCarrera.personalidad(estado);
    final puntos = QuimicaCarrera.puntos(estado);
    final maximo = estado.companeros.length * 3;
    final mods = QuimicaCarrera.mods(estado);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TU PERSONALIDAD: ${p.etiqueta.toUpperCase()}', style: tema.textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(p.descripcion, style: tema.textTheme.bodySmall),
        const SizedBox(height: 12),
        Text('QUÍMICA DEL EQUIPO', style: tema.textTheme.labelLarge),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: maximo == 0 ? 0 : puntos / maximo, minHeight: 6),
        const SizedBox(height: 4),
        Text(
          puntos == 0
              ? 'Jugando juntos se arma la química (Bronce a los 20 partidos, Plata a los 60 y Oro a los 150). Si un compañero se va, se pierde.'
              : 'Tus tiros asistidos aciertan +${(mods.asistidoExtra * 100).toStringAsFixed(1).replaceAll('.', ',')} % por lo bien que se conocen.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text('SCOUTING DE LOS RIVALES', style: tema.textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final l in AdaptacionRival.informe(estado))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(l, style: tema.textTheme.bodySmall?.copyWith(color: l.startsWith('Te cierran') ? esquema.error : null)),
          ),
      ],
    );
  }
}

/// Tus estadísticas avanzadas de carrera.
class PanelAvanzadas extends StatelessWidget {
  const PanelAvanzadas({super.key, required this.estado});

  final EstadoCarrera estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final a = AvanzadasCarrera.de(estado);
    String pc(double v) => '${(v * 100).toStringAsFixed(1).replaceAll('.', ',')} %';
    String n1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ESTADÍSTICAS AVANZADAS', style: tema.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (a == null)
          Text('Aparecen después de tu primer partido.', style: tema.textTheme.bodySmall)
        else ...[
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Celda('TS %', pc(a.ts)),
              _Celda('eFG %', pc(a.efg)),
              _Celda('TC', pc(a.pctTc)),
              _Celda('T3', pc(a.pctT3)),
              _Celda('TL', pc(a.pctTl)),
              _Celda('AST/PÉRD.', n1(a.astPorPerdida)),
              _Celda('VALORACIÓN', n1(a.valoracion)),
              _Celda('MIN', n1(a.minutos)),
              _Celda('PTS/36', n1(a.puntosPor36)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'En ${a.pj} partidos desde que se llevan estos números. TS % y eFG % cuentan que un triple vale más y '
            'los libres importan; la valoración usa la fórmula de Hollinger.',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Tu marca personal: fama, patrocinios y camisetas retiradas.
class PanelMarca extends StatelessWidget {
  const PanelMarca({super.key, required this.estado});

  final EstadoCarrera estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tiene = VidaCarrera.patrocinios(estado);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MARCA PERSONAL', style: tema.textTheme.labelLarge),
            const Spacer(),
            TextoLed('${VidaCarrera.marca(estado)}', tamano: 22),
          ],
        ),
        const SizedBox(height: 6),
        for (final p in Patrocinio.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  tiene.contains(p) ? Icons.handshake : Icons.lock_outline,
                  size: 16,
                  color: tiene.contains(p) ? esquema.primary : esquema.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${p.etiqueta}: ${p.descripcion}',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tiene.contains(p) ? null : esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilaAtributo extends StatelessWidget {
  const _FilaAtributo({
    required this.atributo,
    required this.valor,
    required this.cambio,
    required this.costo,
    required this.puede,
    required this.onSubir,
    this.techo = false,
  });

  final Atributo atributo;
  final int valor, cambio, costo;
  final bool puede, techo;
  final VoidCallback onSubir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(atributo.etiqueta, style: tema.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: valor / 99, minHeight: 6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 36, child: TextoLed('$valor', tamano: 20)),
          SizedBox(
            width: 34,
            child: Text(
              cambio == 0 ? '' : (cambio > 0 ? '+$cambio' : '$cambio'),
              style: tema.textTheme.labelSmall?.copyWith(color: cambio >= 0 ? esquema.primary : esquema.error),
            ),
          ),
          FilledButton.tonal(
            onPressed: puede ? onSubir : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(valor >= 99 ? 'MÁX.' : (techo ? '+1 · $costo ▲' : '+1 · $costo')),
          ),
        ],
      ),
    );
  }
}

/// La línea de estadísticas de la carta de tu jugador (lo que usa el motor del partido).
class LineaCarta extends StatelessWidget {
  const LineaCarta({super.key, required this.carta});

  final Jugador carta;

  @override
  Widget build(BuildContext context) {
    final s = carta.stats;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _Celda('PPP', _n1(s.ppp)),
        _Celda('RPP', _n1(s.rpp)),
        _Celda('APP', _n1(s.app)),
        _Celda('ROB', _n1(s.robP)),
        _Celda('TAP', _n1(s.tapP)),
        _Celda('%T3', '${(s.pctT3 * 100).round()}'),
        _Celda('%TC', '${(s.pctTc * 100).round()}'),
        _Celda('IQ', '${s.iq}'),
      ],
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda(this.etiqueta, this.valor);

  final String etiqueta, valor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextoLed(valor, tamano: 18),
      Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

/// Tarjeta de tu jugador en la temporada: papel, confianza, puntos de habilidad y objetivos.
class TarjetaMiJugador extends StatelessWidget {
  const TarjetaMiJugador({
    super.key,
    required this.estado,
    required this.marca,
    required this.onAbrir,
    this.onElegirObjetivos,
    this.onFechaLimite,
  });

  final EstadoCarrera estado;
  final MarcaTemporada marca;
  final VoidCallback onAbrir;

  /// Si se puede elegir los objetivos de la temporada (antes del primer partido).
  final VoidCallback? onElegirObjetivos;

  /// Si hay una decisión pendiente en la fecha límite de traspasos.
  final VoidCallback? onFechaLimite;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final carta = estado.carta;
    return _Panel(
      destacado: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Escudo(_franq(estado.franquiciaId), tamano: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estado.nombre.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium?.copyWith(letterSpacing: 0.5),
                    ),
                    Text(
                      '${estado.etiquetaTemporada} · ${estado.edad} años · ${estado.rolEquipo.etiqueta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextoLed('${carta.media}', tamano: 30),
            ],
          ),
          const SizedBox(height: 8),
          BarraNivel(etiqueta: 'Confianza DT', valor: estado.confianza, pie: _etiquetaConfianza(estado.confianza)),
          BarraNivel(etiqueta: 'Ánimo', valor: estado.moral),
          if (CarreraJugador.rolProyectado(estado) != estado.rolEquipo)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'El DT te va a pasar a ${CarreraJugador.rolProyectado(estado).etiqueta.toLowerCase()} en el receso.',
                style: tema.textTheme.bodySmall?.copyWith(color: esquema.primary),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            marca.pj == 0
                ? 'Todavía no jugaste.'
                : '${_n1(marca.ppg)} pts · ${_n1(marca.rpg)} reb · ${_n1(marca.apg)} ast en ${marca.pj} partidos',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          if (onFechaLimite != null)
            FilledButton.tonalIcon(
              onPressed: onFechaLimite,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('FECHA LÍMITE DE TRASPASOS: DECIDÍ'),
            ),
          if (onElegirObjetivos != null)
            OutlinedButton.icon(
              onPressed: onElegirObjetivos,
              icon: const Icon(Icons.flag_outlined),
              label: Text('ELEGÍ TUS OBJETIVOS (${ObjetivosCarrera.minAceptados} A ${ObjetivosCarrera.maxAceptados})'),
            ),
          for (final o in estado.objetivos)
            Builder(
              builder: (context) {
                final (v, ok) = o.avance(marca);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Icon(
                        ok ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: ok ? esquema.primary : esquema.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          o.texto,
                          style: tema.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!o.tipo.siNo) Text(_avanceCorto(o, v), style: tema.textTheme.bodySmall),
                      const SizedBox(width: 6),
                      Text('+${o.nivel.puntos}', style: tema.textTheme.labelSmall?.copyWith(color: esquema.primary)),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAbrir,
            icon: const Icon(Icons.trending_up),
            label: Text(estado.phBanco > 0 ? 'MEJORAR · ${estado.phBanco} PUNTOS' : 'MI JUGADOR'),
          ),
        ],
      ),
    );
  }
}

/// Tu jugador a fondo, durante la temporada: gastá los puntos, mirá tu ánimo y tus objetivos.
class MiJugadorPantalla extends StatefulWidget {
  const MiJugadorPantalla({super.key, required this.temporada, required this.carrera, required this.onCambiar});

  final Temporada temporada;
  final CarreraJugador carrera;

  /// Devuelve la temporada ya con los cambios (para guardarla y refrescar el inicio).
  final ValueChanged<Temporada> onCambiar;

  @override
  State<MiJugadorPantalla> createState() => _MiJugadorPantallaState();
}

class _MiJugadorPantallaState extends State<MiJugadorPantalla> {
  late Temporada _t = widget.temporada;

  EstadoCarrera get _e => EstadoCarrera.de(_t)!;

  void _subir(Atributo a) {
    final e = widget.carrera.subir(_e, a);
    setState(() => _t = widget.carrera.sincronizar(_t, e));
    widget.onCambiar(_t);
  }

  void _marcarLeidos() {
    final e = BandejaCarrera.marcarLeidos(_e);
    setState(() => _t = widget.carrera.sincronizar(_t, e));
    widget.onCambiar(_t);
  }

  void _ajustarMedidor(AjustesMedidor a) {
    final e = _e.copyWith(uso: {..._e.uso, ...a.aUso});
    setState(() => _t = widget.carrera.sincronizar(_t, e));
    widget.onCambiar(_t);
  }

  void _subirHabilidad(Habilidad h) {
    final e = widget.carrera.subirHabilidad(_e, h);
    setState(() => _t = widget.carrera.sincronizar(_t, e));
    widget.onCambiar(_t);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final e = _e;
    final carta = e.carta;
    final marca = widget.carrera.marca(_t, e);
    final izquierda = <Widget>[
      _Panel(
        destacado: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 62,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: JugadorAvatar(jugador: carta, franquicia: _franq(e.franquiciaId)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleLarge),
                      Text(
                        '${e.posicion.etiqueta} · ${carta.rol.etiqueta}',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                      Text(
                        '${e.edad} años · contrato: ${e.contrato} ${e.contrato == 1 ? 'temporada' : 'temporadas'}',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextoLed('${carta.media}', tamano: 36),
              ],
            ),
            const SizedBox(height: 10),
            LineaCarta(carta: carta),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TU LUGAR EN EL EQUIPO', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            BarraNivel(etiqueta: 'Confianza DT', valor: e.confianza, pie: _etiquetaConfianza(e.confianza)),
            BarraNivel(etiqueta: 'Ánimo', valor: e.moral),
            BarraNivel(etiqueta: 'Fans', valor: e.fans),
            BarraNivel(etiqueta: 'Vestuario', valor: e.relacion),
            const SizedBox(height: 4),
            Text(
              'Jugás de ${e.rolEquipo.etiqueta.toLowerCase()}. Rendir sube la confianza; con confianza alta pasás a '
              'titular, con poca vas al banco. El vestuario y el ánimo mueven tus estadísticas.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OBJETIVOS DEL DT', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final o in e.objetivos)
              Builder(
                builder: (context) {
                  final (v, ok) = o.avance(marca);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(ok ? Icons.check_circle : Icons.flag_outlined, color: ok ? esquema.primary : null),
                    title: Text(o.texto),
                    subtitle: Text('${o.nivel.etiqueta} · +${o.nivel.puntos} puntos', style: tema.textTheme.bodySmall),
                    trailing: o.tipo.siNo ? null : Text('${_avanceCorto(o, v)}/${_avanceCorto(o, o.meta)}'),
                  );
                },
              ),
            Text(
              'Cada objetivo cumplido da puntos de habilidad según su nivel (Fácil 1, Normal 2, Difícil 4, Élite 6) y '
              'confianza del DT, al final de la temporada.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ];
    final derecha = <Widget>[
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MiEquipoPantalla(estado: e))),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('MI EQUIPO'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GeneracionPantalla(estado: e, catalogo: widget.carrera.liga.catalogo),
                ),
              ),
              icon: const Icon(Icons.school_outlined),
              label: const Text('MI GENERACIÓN'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecordsPantalla(estado: e))),
        icon: const Icon(Icons.emoji_events_outlined),
        label: const Text('CAMINO A LOS RÉCORDS'),
      ),
      const SizedBox(height: 12),
      _Panel(child: PanelObjetivosLargos(estado: e)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => BandejaPantalla(estado: e, alAbrir: _marcarLeidos)),
        ),
        icon: const Icon(Icons.inbox_outlined),
        label: Text(BandejaCarrera.sinLeer(e) > 0 ? 'BANDEJA DE ENTRADA · ${BandejaCarrera.sinLeer(e)} NUEVOS' : 'BANDEJA DE ENTRADA'),
      ),
      const SizedBox(height: 12),
      _Panel(child: PanelMundo(estado: e)),
      const SizedBox(height: 12),
      _Panel(child: PanelAvanzadas(estado: e)),
      const SizedBox(height: 12),
      _Panel(
        child: PanelControlPartido(estado: e, alCambiar: _ajustarMedidor),
      ),
      const SizedBox(height: 12),
      _Panel(child: PanelDesglose(estado: e)),
      const SizedBox(height: 12),
      _Panel(child: PanelMarca(estado: e)),
      const SizedBox(height: 12),
      _Panel(
        child: PanelAtributos(estado: e, carrera: widget.carrera, onSubir: _subir, onSubirHabilidad: _subirHabilidad),
      ),
    ];
    const relleno = EdgeInsets.fromLTRB(16, 8, 16, 24);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi jugador')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ListView(padding: relleno, children: izquierda),
                  ),
                  Expanded(
                    flex: 5,
                    child: ListView(padding: relleno, children: derecha),
                  ),
                ],
              )
            : ListView(padding: relleno, children: [...izquierda, const SizedBox(height: 12), ...derecha]),
      ),
    );
  }
}

// ===========================================================================================
// Receso
// ===========================================================================================

enum _Paso { resumen, entrenar, evento, prensa, contrato, retiro }

/// Entre temporada y temporada: el resumen, entrenar, la prensa, el contrato y, a veces, el retiro.
/// Cada paso se guarda, así que podés cerrar la app y seguir donde quedaste.
class RecesoJugadorPantalla extends StatefulWidget {
  const RecesoJugadorPantalla({
    super.key,
    required this.temporada,
    required this.estado,
    required this.carrera,
    required this.cierre,
    required this.onEstado,
    required this.onSeguir,
    required this.onRetirar,
    this.pasoInicial,
    this.onPaso,
  });

  /// Paso del receso en que se había quedado (retomar no vuelve al principio).
  final String? pasoInicial;

  /// Se llama al cambiar de paso, para guardarlo.
  final ValueChanged<String>? onPaso;

  /// La temporada terminada (con los playoffs).
  final Temporada temporada;
  final EstadoCarrera estado;
  final CarreraJugador carrera;

  /// Lo que pasó al cerrar (null al retomar un receso ya empezado).
  final CierreTemporada? cierre;

  /// Se llama con cada cambio del estado, para guardarlo.
  final ValueChanged<EstadoCarrera> onEstado;

  /// Arranca la temporada siguiente (con la oferta elegida, si hubo).
  final void Function(EstadoCarrera estado, OfertaContrato? oferta) onSeguir;

  /// Te retirás: se cierra la carrera.
  final ValueChanged<EstadoCarrera> onRetirar;

  @override
  State<RecesoJugadorPantalla> createState() => _RecesoJugadorPantallaState();
}

class _RecesoJugadorPantallaState extends State<RecesoJugadorPantalla> {
  late EstadoCarrera _e = widget.estado;
  late _Paso _paso = _pasoGuardado() ?? (widget.cierre == null ? _Paso.entrenar : _Paso.resumen);
  OfertaContrato? _oferta;
  late var _pidioTraspaso = widget.estado.pidioTraspaso;
  RespuestaPrensa? _respondida;

  /// El evento del año (si hay) y la respuesta que elegiste.
  late final EventoCarrera? _evento = VidaCarrera.eventoPara(widget.estado);
  int? _respuestaEvento;
  late final bool _hayEvento = _evento != null || widget.pasoInicial == 'evento';

  void _cambiar(EstadoCarrera e) {
    setState(() => _e = e);
    widget.onEstado(e);
  }

  bool get _vencido => _e.contrato <= 0;
  bool get _hayContrato => _vencido || _pidioTraspaso;
  bool get _hayRetiro => CarreraJugador.puedeRetirarse(_e);

  List<_Paso> get _pasos => [
    if (widget.cierre != null) _Paso.resumen,
    _Paso.entrenar,
    if (_hayEvento) _Paso.evento,
    _Paso.prensa,
    _Paso.contrato,
    if (_hayRetiro) _Paso.retiro,
  ];

  _Paso? _pasoGuardado() {
    final p = _Paso.values.asNameMap()[widget.pasoInicial];
    return p == null || (p == _Paso.resumen && widget.cierre == null) ? null : p;
  }

  void _siguiente() {
    final pasos = _pasos;
    final i = pasos.indexOf(_paso);
    if (i < pasos.length - 1) {
      setState(() => _paso = pasos[i + 1]);
      widget.onPaso?.call(pasos[i + 1].name);
    } else {
      widget.onSeguir(_e, _oferta);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pasos = _pasos;
    final indice = pasos.indexOf(_paso);
    final ultimo = indice == pasos.length - 1;
    final bloqueado = switch (_paso) {
      _Paso.evento => _evento != null && _respuestaEvento == null && VidaCarrera.eventoPara(_e) != null,
      _Paso.prensa => _e.prensaHecha < 2,
      _Paso.contrato => _hayContrato && _oferta == null,
      _ => false,
    };
    final forzoso = CarreraJugador.retiroForzoso(_e);
    return Scaffold(
      appBar: AppBar(title: Text('Receso · ${_e.etiquetaDe(_e.numero + 1)}')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  for (var i = 0; i < pasos.length; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= indice ? tema.colorScheme.primary : tema.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < pasos.length - 1) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
            Expanded(
              child: AnchoMaximo(
                ancho: 900,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: switch (_paso) {
                    _Paso.resumen => _pasoResumen(context),
                    _Paso.entrenar => _pasoEntrenar(context),
                    _Paso.evento => _pasoEvento(context),
                    _Paso.prensa => _pasoPrensa(context),
                    _Paso.contrato => _pasoContrato(context),
                    _Paso.retiro => _pasoRetiro(context, forzoso),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _paso == _Paso.retiro && forzoso
                  ? const SizedBox.shrink()
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: bloqueado ? null : _siguiente,
                        child: Text(ultimo ? 'ARRANCAR LA TEMPORADA ${_e.numero + 1}' : 'CONTINUAR'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Resumen ----------

  Widget _pasoResumen(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final c = widget.cierre!;
    final s = c.temporada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FIN DE LA TEMPORADA ${s.numero}', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _Panel(
          destacado: s.campeon,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Escudo(_franq(s.franquiciaId), tamano: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.campeon ? '¡CAMPEÓN!' : s.resultado.toUpperCase(),
                      style: tema.textTheme.titleLarge?.copyWith(color: s.campeon ? esquema.primary : null),
                    ),
                  ),
                  TextoLed('${s.victorias}-${s.derrotas}', tamano: 26),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${_n1(s.pts)} pts · ${_n1(s.reb)} reb · ${_n1(s.ast)} ast en ${s.pj} partidos',
                style: tema.textTheme.titleMedium,
              ),
              if (s.allStar || s.premios.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (s.allStar) const Chip(label: Text('All-Star'), visualDensity: VisualDensity.compact),
                    for (final p in s.premios) Chip(label: Text(p), visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OBJETIVOS DEL DT', style: tema.textTheme.labelLarge),
              for (final (o, ok) in c.objetivos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    ok ? Icons.check_circle : Icons.cancel_outlined,
                    color: ok ? esquema.primary : esquema.error,
                  ),
                  title: Text(o.texto),
                  trailing: Text(ok ? '+3' : '—'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PUNTOS DE HABILIDAD GANADOS', style: tema.textTheme.labelLarge),
              const SizedBox(height: 4),
              _Linea('Por tu juego', '+${c.phBase}'),
              _Linea('Objetivos', '+${c.phObjetivos}'),
              _Linea('Premios y título', '+${c.phPremios}'),
              const Divider(),
              _Linea('Total disponible', '${c.estado.phBanco}', fuerte: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TU CUERPO Y TU CABEZA, A LOS ${c.estado.edad}', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final a in Atributo.values)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        (c.desarrollo[a] ?? 0) > 0
                            ? Icons.arrow_upward
                            : ((c.desarrollo[a] ?? 0) < 0 ? Icons.arrow_downward : Icons.remove),
                        size: 14,
                      ),
                      label: Text('${a.etiqueta} ${(c.desarrollo[a] ?? 0) > 0 ? '+' : ''}${c.desarrollo[a] ?? 0}'),
                    ),
                ],
              ),
              for (final o in c.objetivosCarrera) ...[
                const SizedBox(height: 8),
                Text(
                  '¡Objetivo de carrera cumplido: ${o.texto}! +${o.puntos} puntos de habilidad.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary),
                ),
              ],
              for (final i in c.insigniasNuevas) ...[
                const SizedBox(height: 8),
                Text(
                  '¡Insignia ${i.etiqueta}: ${c.gradosNuevos[i]?.etiqueta ?? 'nueva'}! ${i.descripcion}',
                  style: tema.textTheme.bodyMedium?.copyWith(color: esquema.primary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Entrenar ----------

  Widget _pasoEntrenar(BuildContext context) {
    final tema = Theme.of(context);
    final carta = _e.carta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ENTRENAMIENTO', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Gastá tus puntos en el receso. Podés guardar algunos para después.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _Panel(
          child: Row(
            children: [
              TextoLed('${carta.media}', tamano: 34),
              const SizedBox(width: 12),
              Expanded(child: LineaCarta(carta: carta)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: PanelAtributos(
            estado: _e,
            carrera: widget.carrera,
            onSubir: (a) => _cambiar(widget.carrera.subir(_e, a)),
            onSubirHabilidad: (h) => _cambiar(widget.carrera.subirHabilidad(_e, h)),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(child: PanelDesglose(estado: _e)),
        const SizedBox(height: 12),
        _Panel(
          child: _PanelRutina(estado: _e, onElegir: (r) => _cambiar(VidaCarrera.elegirRutina(_e, r))),
        ),
      ],
    );
  }

  // ---------- Evento ----------

  Widget _pasoEvento(BuildContext context) {
    final tema = Theme.of(context);
    final ev = _evento;
    if (ev == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SIN NOVEDADES', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Ya resolviste lo que pasó este año fuera de la cancha.'),
        ],
      );
    }
    final elegida = _respuestaEvento;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FUERA DE LA CANCHA', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _Panel(
          destacado: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ev.titulo, style: tema.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(ev.texto, style: tema.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (elegida == null)
          for (var i = 0; i < ev.opciones.length; i++) ...[
            FilledButton.tonal(
              onPressed: () {
                setState(() => _respuestaEvento = i);
                _cambiar(VidaCarrera.resolver(_e, ev, i));
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), alignment: Alignment.centerLeft),
              child: Text(ev.opciones[i].texto),
            ),
            const SizedBox(height: 8),
          ]
        else
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ev.opciones[elegida].texto, style: tema.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(ev.opciones[elegida].resultado, style: tema.textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }

  // ---------- Prensa ----------

  Widget _pasoPrensa(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final preguntas = widget.carrera.preguntasDelReceso(_e);
    final hecha = _e.prensaHecha;
    if (hecha >= preguntas.length) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONFERENCIA DE PRENSA', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (_respondida case final r?) _Reaccion(r),
          const SizedBox(height: 8),
          _Panel(
            child: Column(
              children: [
                BarraNivel(etiqueta: 'Confianza DT', valor: _e.confianza, pie: _etiquetaConfianza(_e.confianza)),
                BarraNivel(etiqueta: 'Ánimo', valor: _e.moral),
                BarraNivel(etiqueta: 'Fans', valor: _e.fans),
                BarraNivel(etiqueta: 'Vestuario', valor: _e.relacion),
              ],
            ),
          ),
        ],
      );
    }
    final idx = hecha.clamp(0, preguntas.length - 1);
    final pregunta = preguntas[idx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONFERENCIA DE PRENSA', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Pregunta ${idx + 1} de ${preguntas.length}',
          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (_respondida case final r? when hecha > 0) _Reaccion(r),
        _Panel(
          destacado: true,
          child: Row(
            children: [
              const Icon(Icons.mic_none),
              const SizedBox(width: 10),
              Expanded(child: Text(pregunta.texto, style: tema.textTheme.titleMedium)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final r in pregunta.respuestas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () {
                _respondida = r;
                _cambiar(widget.carrera.responderPrensa(_e, r));
              },
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(r.texto, textAlign: TextAlign.start),
            ),
          ),
      ],
    );
  }

  // ---------- Contrato ----------

  Widget _pasoContrato(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final mostrarOfertas = _hayContrato;
    final ofertas = mostrarOfertas
        ? widget.carrera.ofertas(widget.temporada, _e, traspaso: _pidioTraspaso && !_vencido)
        : const <OfertaContrato>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_vencido ? 'AGENCIA LIBRE' : 'TU CONTRATO', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (!mostrarOfertas) ...[
          _Panel(
            child: Row(
              children: [
                Escudo(_franq(_e.franquiciaId), tamano: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seguís en ${_franq(_e.franquiciaId).nombreCompleto}: te quedan ${_e.contrato} '
                    '${_e.contrato == 1 ? 'temporada' : 'temporadas'} de contrato.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_e.numero >= 2)
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _pidioTraspaso = true);
                _cambiar(
                  _e.copyWith(
                    pidioTraspaso: true,
                    moral: _e.moral - 8,
                    confianza: _e.confianza - 5,
                    hitos: [..._e.hitos, '${_e.etiquetaTemporada}: ${_e.nombre} pide el traspaso.'],
                  ),
                );
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('PEDIR EL TRASPASO'),
            ),
          if (_e.numero >= 2)
            Text(
              'Te cuesta ánimo y confianza, pero te llegan ofertas de otros equipos.',
              style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
        ] else ...[
          Text(
            _vencido
                ? 'Se te terminó el contrato. Elegí dónde seguís: el papel que te ofrecen decide tu confianza inicial.'
                : 'Pediste el traspaso. Elegí un destino.',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          for (final o in ofertas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TarjetaOferta(
                oferta: o,
                elegida: _oferta == o || (_oferta?.franquiciaId == o.franquiciaId),
                onTap: () => setState(() => _oferta = o),
              ),
            ),
          if (!_vencido)
            TextButton(
              onPressed: () {
                setState(() {
                  _pidioTraspaso = false;
                  _oferta = null;
                });
                _cambiar(_e.copyWith(pidioTraspaso: false));
              },
              child: const Text('Mejor me quedo'),
            ),
        ],
      ],
    );
  }

  // ---------- Retiro ----------

  Widget _pasoRetiro(BuildContext context, bool forzoso) {
    final tema = Theme.of(context);
    final legado = _e.legado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(forzoso ? 'EL CUERPO DIJO BASTA' : '¿SEGUÍS O TE RETIRÁS?', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_e.nombre}, ${_e.edad} años · media ${_e.media}', style: tema.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                '${legado.anillos} anillos · ${legado.allStars} All-Star · ${legado.puntos} puntos de carrera',
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(legado.veredicto, style: tema.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => widget.onRetirar(_e),
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('ME RETIRO'),
        ),
        if (!forzoso) ...[
          const SizedBox(height: 8),
          Text(
            'Si seguís, arrancás la temporada ${_e.numero + 1}. A estas edades el físico cae cada año.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.texto, this.valor, {this.fuerte = false});

  final String texto, valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = fuerte ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _Reaccion extends StatelessWidget {
  const _Reaccion(this.r);

  final RespuestaPrensa r;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget efecto(String etiqueta, int v) => v == 0
        ? const SizedBox.shrink()
        : Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(v > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
            label: Text('$etiqueta ${v > 0 ? '+' : ''}$v'),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${r.texto}"', style: tema.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text(r.reaccion, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            Wrap(
              spacing: 6,
              children: [
                efecto('Confianza', r.confianza),
                efecto('Ánimo', r.moral),
                efecto('Fans', r.fans),
                efecto('Vestuario', r.relacion),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaOferta extends StatelessWidget {
  const _TarjetaOferta({required this.oferta, required this.elegida, required this.onTap});

  final OfertaContrato oferta;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final f = _franq(oferta.franquiciaId);
    return Material(
      color: elegida ? esquema.primary.withValues(alpha: 0.12) : esquema.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: elegida ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.6),
          width: elegida ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Escudo(f, tamano: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oferta.renovacion ? 'Renovar con ${f.nombre}' : f.nombreCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium,
                    ),
                    Text(
                      '${oferta.rol.etiqueta} · ${oferta.anios} ${oferta.anios == 1 ? 'año' : 'años'}',
                      style: tema.textTheme.bodyMedium,
                    ),
                    Text(
                      oferta.rival == null
                          ? 'Plantel de media ${oferta.nivelEquipo}'
                          : 'Competís con ${oferta.rival!.$1} (${oferta.rival!.$2}) · plantel de media ${oferta.nivelEquipo}',
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(elegida ? Icons.check_circle : Icons.circle_outlined, color: elegida ? esquema.primary : null),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================================
// Legado
// ===========================================================================================

/// La carrera completa: totales, anillos, premios, veredicto del Salón y la línea de tiempo.
class LegadoCarreraPantalla extends StatelessWidget {
  const LegadoCarreraPantalla({super.key, required this.estado, required this.carrera, this.alInicio});

  final EstadoCarrera estado;
  final CarreraJugador carrera;

  /// Al terminar la carrera (retirado): volver al inicio.
  final VoidCallback? alInicio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final l = estado.legado;
    final lineas = carrera.narrar(estado);
    final totales = _Panel(
      destacado: l.salon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(estado.nombre.toUpperCase(), style: tema.textTheme.headlineSmall)),
              TextoLed('${l.mejorMedia}', tamano: 30),
            ],
          ),
          Text(
            estado.retirado ? 'Retirado a los ${estado.edad} años' : '${estado.edad} años · temporada ${estado.numero}',
            style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Celda('PARTIDOS', '${l.partidos}'),
              _Celda('PUNTOS', '${l.puntos}'),
              _Celda('REBOTES', '${l.rebotes}'),
              _Celda('ASIST.', '${l.asistencias}'),
              _Celda('ANILLOS', '${l.anillos}'),
              _Celda('ALL-STAR', '${l.allStars}'),
              _Celda('MVP', '${l.mvps}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(l.salon ? Icons.emoji_events : Icons.history_edu, color: l.salon ? esquema.primary : null),
              const SizedBox(width: 8),
              Expanded(child: Text(l.veredicto, style: tema.textTheme.titleMedium)),
            ],
          ),
        ],
      ),
    );
    final camisetas = VidaCarrera.camisetas(l);
    final records = VidaCarrera.records(l);
    final despues = estado.retirado ? VidaCarrera.epilogo(estado) : const <String>[];
    final huella = (camisetas.isEmpty && records.isEmpty && despues.isEmpty)
        ? null
        : _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (records.isNotEmpty) ...[
                  Text('TUS MEJORES TEMPORADAS', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  for (final r in records)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text('${r.etiqueta}: ${_n1(r.valor)} (${r.temporada})', style: tema.textTheme.bodyMedium),
                    ),
                ],
                if (camisetas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('CAMISETAS RETIRADAS', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  for (final c in camisetas)
                    Row(
                      children: [
                        Escudo(_franq(c.franquiciaId), tamano: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_franq(c.franquiciaId).nombreCompleto} · ${c.temporadas} temporadas'
                            '${estado.base.dorsal > 0 ? ' · número ${estado.base.dorsal} retirado' : ''}',
                            style: tema.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                ],
                if (despues.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('DESPUÉS DE LA CANCHA', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  for (final d in despues) _Hito(d),
                ],
              ],
            ),
          );
    final historia = _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LÍNEA DE TIEMPO', style: tema.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final h in estado.hitos.take(1)) _Hito(h),
          for (final s in lineas) _Hito(s, principal: true),
          for (final h
              in estado.hitos
                  .skip(1)
                  .where((x) => x.contains('retira') || x.contains('firma') || x.contains('traspaso')))
            _Hito(h),
          if (lineas.isEmpty && estado.hitos.length <= 1) const Text('Todavía no jugaste ninguna temporada.'),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Historia de tu carrera')),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 8, 24), children: [totales]),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                      children: [
                        if (huella != null) ...[huella, const SizedBox(height: 12)],
                        historia,
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  totales,
                  const SizedBox(height: 12),
                  if (huella != null) ...[huella, const SizedBox(height: 12)],
                  historia,
                  if (alInicio != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(onPressed: alInicio, child: const Text('VOLVER AL INICIO')),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Hito extends StatelessWidget {
  const _Hito(this.texto, {this.principal = false});

  final String texto;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: principal ? 9 : 6, color: tema.colorScheme.primary),
          ),
          Expanded(child: Text(texto, style: principal ? tema.textTheme.bodyMedium : tema.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// ===========================================================================================
// Elegir jugador real, combine y noche del draft
// ===========================================================================================

/// Elegí el jugador real con el que arrancás la carrera (su carta más temprana).
class ElegirJugadorRealPantalla extends StatefulWidget {
  const ElegirJugadorRealPantalla({super.key, required this.carrera});

  final CarreraJugador carrera;

  @override
  State<ElegirJugadorRealPantalla> createState() => _ElegirJugadorRealPantallaState();
}

class _ElegirJugadorRealPantallaState extends State<ElegirJugadorRealPantalla> {
  var _texto = '';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lista = widget.carrera.candidatosReales(texto: _texto, limite: 80);
    return Scaffold(
      appBar: AppBar(title: const Text('Elegí tu jugador')),
      body: SafeArea(
        child: AnchoMaximo(
          ancho: 760,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscá por nombre (Jordan, Jokić, Kobe…)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _texto = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Arrancás en su año de novato, con su equipo y su elección real del draft. Después, la carrera la '
                  'escribís vos.',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: lista.isEmpty
                    ? const Center(child: Text('No hay jugadores con ese nombre.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                        itemCount: lista.length,
                        itemBuilder: (context, i) {
                          final j = lista[i];
                          return ListTile(
                            leading: SizedBox(width: 48, child: Center(child: TextoLed('${j.media}', tamano: 22))),
                            title: Text(j.nombre),
                            subtitle: Text(
                              '${j.posiciones.first.etiqueta} · ${j.rol.etiqueta} · ${j.tramoConEquipo}'
                              '${j.draft == null ? '' : ' · draft ${j.draft!.$1}, n.º ${j.draft!.$2}'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).pop(j),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El combine de la carrera de un jugador creado: las pruebas aparecen de a una.
class CombinePantalla extends StatefulWidget {
  const CombinePantalla({super.key, required this.creado, required this.resultado});

  final JugadorCreado creado;
  final ResultadoCombine resultado;

  @override
  State<CombinePantalla> createState() => _CombinePantallaState();
}

class _CombinePantallaState extends State<CombinePantalla> {
  var _vistas = 0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final r = widget.resultado;
    final termino = _vistas >= r.pruebas.length;
    return Scaffold(
      appBar: AppBar(title: const Text('El combine')),
      body: SafeArea(
        child: AnchoMaximo(
          ancho: 700,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Los scouts te miran de arriba abajo, ${widget.creado.nombre.split(' ').first}. Tocá cada prueba para ver cómo te va.',
                  style: tema.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < r.pruebas.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: i < _vistas
                              ? _Panel(
                                  child: Row(
                                    children: [
                                      TextoLed('${r.pruebas[i].nota}', tamano: 30),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.pruebas[i].nombre, style: tema.textTheme.titleMedium),
                                            Text(r.pruebas[i].comentario, style: tema.textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: i == _vistas ? () => setState(() => _vistas++) : null,
                                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                                  child: Text(
                                    i == _vistas ? 'HACER: ${r.pruebas[i].nombre.toUpperCase()}' : r.pruebas[i].nombre,
                                  ),
                                ),
                        ),
                      if (termino)
                        _Panel(
                          destacado: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PROYECCIÓN DE LOS SCOUTS', style: tema.textTheme.labelLarge),
                              const SizedBox(height: 4),
                              Text(
                                r.sinDraft
                                    ? 'Nadie te proyecta en el draft. Tendrás que ganarte un lugar firmando como agente libre.'
                                    : 'Te proyectan en la ${r.ronda == 1 ? 'primera' : 'segunda'} ronda, alrededor del puesto ${r.pick}.',
                                style: tema.textTheme.titleMedium?.copyWith(color: esquema.primary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: termino ? () => Navigator.of(context).pop(true) : null,
                  child: const Text('IR A LA NOCHE DEL DRAFT'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La noche del draft: te eligen (o no) y firmás con tu equipo. Devuelve el id de la franquicia.
class NocheDraftPantalla extends StatelessWidget {
  const NocheDraftPantalla({
    super.key,
    required this.nombre,
    required this.pick,
    required this.franquiciaId,
    this.anio,
    this.opciones = const [],
    this.real = false,
  });

  final String nombre;
  final int pick;
  final String franquiciaId;
  final int? anio;

  /// Sin draft: tres equipos que te ofrecen un contrato.
  final List<String> opciones;
  final bool real;

  bool get sinDraft => pick > 50;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(anio == null ? 'Noche del draft' : 'Draft $anio')),
      body: SafeArea(
        child: AnchoMaximo(
          ancho: 640,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                if (sinDraft) ...[
                  Text('SE ACABÓ EL DRAFT', style: tema.textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Nadie dijo tu nombre, pero tres equipos te llaman con un contrato de dos años. Elegí uno.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final id in opciones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(id),
                        icon: Escudo(_franq(id), tamano: 28),
                        label: Text(_franq(id).nombreCompleto),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      ),
                    ),
                ] else ...[
                  Center(child: TextoLed('N.º $pick', tamano: 44)),
                  const SizedBox(height: 16),
                  Center(child: Escudo(_franq(franquiciaId), tamano: 96)),
                  const SizedBox(height: 16),
                  Text(
                    real
                        ? '${_franq(franquiciaId).nombreCompleto} elige a $nombre'
                        : 'Con el puesto $pick, ${_franq(franquiciaId).nombreCompleto} elige a $nombre',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pick <= 14
                        ? 'Una elección de lotería: el equipo cuenta con vos desde el primer día.'
                        : pick <= 30
                        ? 'Primera ronda: tendrás que ganarte los minutos.'
                        : 'Segunda ronda: contrato corto y mucho por demostrar.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                if (!sinDraft)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(franquiciaId),
                    child: Text('FIRMAR CON ${_franq(franquiciaId).nombre.toUpperCase()}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
