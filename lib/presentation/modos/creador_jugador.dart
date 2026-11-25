import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/franquicias.dart';
import '../../domain/entities/avatar_creado.dart';
import '../../domain/entities/estilo_creado.dart';
import '../../domain/entities/posicion.dart';
import '../../domain/entities/rol_cancha.dart';
import '../../domain/modos/carrera_jugador.dart';
import '../widgets/avatar_ilustrado.dart';
import '../widgets/disposicion.dart';
import '../widgets/texto_led.dart';

/// Creador de jugadores (reutilizable: Mi carrera, modo universitario…). Devuelve el
/// [JugadorCreado] con `Navigator.pop`, o null si se vuelve atrás.
class CreadorJugadorPantalla extends StatefulWidget {
  const CreadorJugadorPantalla({
    super.key,
    this.titulo = 'Creá tu jugador',
    this.textoBoton = 'CONTINUAR',
    this.nombreInicial = '',
    this.nacimiento,
    this.posicionInicial = Posicion.escolta,
    this.conArranque = false,
  });

  final String titulo, textoBoton, nombreInicial;

  /// Año de nacimiento que se le pone al jugador (opcional).
  final int? nacimiento;
  final Posicion posicionInicial;

  /// Pide también el año del draft, la edad de arranque y el número de camiseta (Mi carrera).
  final bool conArranque;

  @override
  State<CreadorJugadorPantalla> createState() => _CreadorJugadorPantallaState();
}

class _CreadorJugadorPantallaState extends State<CreadorJugadorPantalla> {
  late final _nombre = TextEditingController(text: widget.nombreInicial);
  late Posicion _posicion = widget.posicionInicial;
  late RolCancha _rol = JugadorCreado.rolesDe(_posicion).first;
  late double _altura = JugadorCreado.alturaSugerida(_posicion).toDouble();
  var _peso = 92.0;
  var _avatar = const AvatarCreado();
  var _estilo = const EstiloCreado();
  var _anio = 2026, _edad = 20, _dorsal = 7;
  final _fuertes = <Atributo>[Atributo.tiro, Atributo.iq, Atributo.defensa];

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  JugadorCreado get _jugador => JugadorCreado(
    nombre: _nombre.text,
    posicion: _posicion,
    rol: _rol,
    fuertes: List.of(_fuertes),
    alturaCm: _altura.round(),
    pesoKg: _peso.round(),
    nacimiento: widget.conArranque ? _anio - _edad : widget.nacimiento,
    avatar: _avatar,
    estilo: _estilo,
    anioDraft: widget.conArranque ? _anio : null,
    edadInicial: widget.conArranque ? _edad : null,
    dorsal: widget.conArranque ? _dorsal : 0,
  );

  void _elegirPosicion(Posicion p) => setState(() {
    _posicion = p;
    _rol = JugadorCreado.rolesDe(p).first;
    _altura = JugadorCreado.alturaSugerida(p).toDouble();
    _peso = (70 + (_altura - 180) * 1.0).clamp(70, 150);
  });

  void _alternarFuerte(Atributo a) => setState(() {
    if (_fuertes.contains(a)) {
      _fuertes.remove(a);
    } else if (_fuertes.length < 3) {
      _fuertes.add(a);
    }
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final jugador = _jugador;
    final error = jugador.error;
    final formulario = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'Nombre y apellido', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('PUESTO', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in Posicion.titulares)
              ChoiceChip(label: Text(p.etiqueta), selected: p == _posicion, onSelected: (_) => _elegirPosicion(p)),
          ],
        ),
        const SizedBox(height: 16),
        Text('ARQUETIPO', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in JugadorCreado.rolesDe(_posicion))
              ChoiceChip(label: Text(r.etiqueta), selected: r == _rol, onSelected: (_) => setState(() => _rol = r)),
          ],
        ),
        const SizedBox(height: 16),
        _Deslizador(
          etiqueta: 'ALTURA',
          valor: '${_altura.round()} cm',
          slider: Slider(
            value: _altura,
            min: JugadorCreado.alturaMin.toDouble(),
            max: JugadorCreado.alturaMax.toDouble(),
            divisions: JugadorCreado.alturaMax - JugadorCreado.alturaMin,
            onChanged: (v) => setState(() => _altura = v),
          ),
        ),
        _Deslizador(
          etiqueta: 'PESO',
          valor: '${_peso.round()} kg',
          slider: Slider(
            value: _peso,
            min: JugadorCreado.pesoMin.toDouble(),
            max: JugadorCreado.pesoMax.toDouble(),
            divisions: JugadorCreado.pesoMax - JugadorCreado.pesoMin,
            onChanged: (v) => setState(() => _peso = v),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('TRES PUNTOS FUERTES', style: tema.textTheme.labelLarge),
            const Spacer(),
            Text('${_fuertes.length}/3', style: tema.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in Atributo.values)
              FilterChip(
                label: Text(a.etiqueta),
                selected: _fuertes.contains(a),
                onSelected: (_) => _alternarFuerte(a),
                tooltip: a.descripcion,
              ),
          ],
        ),
        if (widget.conArranque) ...[
          const SizedBox(height: 16),
          Text('TU ARRANQUE', style: tema.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            'El año del draft define la época: de ahí salen tus compañeros y tu camiseta. Podés empezar de pibe o llegar más grande.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in const [2026, 2015, 2005, 1995, 1985])
                ChoiceChip(label: Text('$a'), selected: _anio == a, onSelected: (_) => setState(() => _anio = a)),
            ],
          ),
          _Deslizador(
            etiqueta: 'AÑO',
            valor: '$_anio',
            slider: Slider(
              value: _anio.toDouble(),
              min: JugadorCreado.anioMin.toDouble(),
              max: JugadorCreado.anioMax.toDouble(),
              divisions: JugadorCreado.anioMax - JugadorCreado.anioMin,
              onChanged: (v) => setState(() => _anio = v.round()),
            ),
          ),
          _Deslizador(
            etiqueta: 'EDAD',
            valor: '$_edad años',
            slider: Slider(
              value: _edad.toDouble(),
              min: JugadorCreado.edadMin.toDouble(),
              max: JugadorCreado.edadMax.toDouble(),
              divisions: JugadorCreado.edadMax - JugadorCreado.edadMin,
              onChanged: (v) => setState(() => _edad = v.round()),
            ),
          ),
          _Deslizador(
            etiqueta: 'NÚMERO',
            valor: '#$_dorsal',
            slider: Slider(
              value: _dorsal.toDouble(),
              max: 99,
              divisions: 99,
              onChanged: (v) => setState(() => _dorsal = v.round()),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _EditorAvatar(
          avatar: _avatar,
          estilo: _estilo,
          jugador: jugador,
          alCambiar: (a) => setState(() => _avatar = a),
          alCambiarEstilo: (e) => setState(() => _estilo = e),
        ),
      ],
    );
    final vista = _VistaPrevia(jugador: jugador, error: error);
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: SafeArea(
        child: esTabletApaisada(context)
            ? Row(
                children: [
                  Expanded(flex: 6, child: formulario),
                  Expanded(
                    flex: 5,
                    child: Padding(padding: const EdgeInsets.fromLTRB(0, 8, 24, 24), child: _conBoton(vista, error)),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(child: formulario),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _conBoton(vista, error, compacto: true),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _conBoton(Widget vista, String? error, {bool compacto = false}) => Column(
    mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (compacto) vista else Expanded(child: SingleChildScrollView(child: vista)),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: error == null ? () => Navigator.of(context).pop(_jugador) : null,
        child: Text(widget.textoBoton),
      ),
    ],
  );
}

class _Deslizador extends StatelessWidget {
  const _Deslizador({required this.etiqueta, required this.valor, required this.slider});

  final String etiqueta, valor;
  final Slider slider;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        SizedBox(width: valor.isEmpty ? 52 : 72, child: Text(etiqueta, style: tema.textTheme.labelLarge)),
        Expanded(child: slider),
        if (valor.isNotEmpty)
          SizedBox(
            width: 70,
            child: Text(valor, textAlign: TextAlign.end, style: tema.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

/// Cómo arranca el jugador: media, estadísticas y atributos, en vivo mientras lo armás.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({required this.jugador, required this.error});

  final JugadorCreado jugador;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final ok = error == null;
    final a = jugador.atributos;
    final s = jugador.estadisticas;
    String n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextoLed('${jugador.media}', tamano: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jugador.nombre.trim().isEmpty ? 'Tu jugador' : jugador.nombre.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium,
                    ),
                    Text(
                      '${jugador.posicion.etiqueta} · ${jugador.rol.etiqueta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Dato('PPP', n(s.ppp)),
              _Dato('RPP', n(s.rpp)),
              _Dato('APP', n(s.app)),
              _Dato('%T3', '${(s.pctT3 * 100).round()}'),
              _Dato('IQ', '${s.iq}'),
            ],
          ),
          const SizedBox(height: 8),
          for (final x in Atributo.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 108, child: Text(x.etiqueta, style: tema.textTheme.bodySmall)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(value: a[x] / 99, minHeight: 6),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('${a[x]}', textAlign: TextAlign.end, style: tema.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          if (!ok) ...[
            const SizedBox(height: 8),
            Text(error!, style: tema.textTheme.bodySmall?.copyWith(color: esquema.error)),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

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

/// Un rasgo con opciones en fichas (ojos, peinado, barba…).
class _Opciones extends StatelessWidget {
  const _Opciones({required this.titulo, required this.nombres, required this.valor, required this.alElegir});

  final String titulo;
  final List<String> nombres;
  final int valor;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < nombres.length; i++)
                ChoiceChip(
                  label: Text(nombres[i]),
                  selected: valor == i,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => alElegir(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un grupo plegable del editor.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.hijos, this.abierto = false});

  final String titulo;
  final List<Widget> hijos;
  final bool abierto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: tema.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: abierto,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(titulo, style: tema.textTheme.labelLarge),
          children: hijos,
        ),
      ),
    );
  }
}

/// El editor completo del jugador: vista previa, rostro, peinado y barba, accesorios, cuerpo y estilo de juego.
class _EditorAvatar extends StatelessWidget {
  const _EditorAvatar({
    required this.avatar,
    required this.estilo,
    required this.jugador,
    required this.alCambiar,
    required this.alCambiarEstilo,
  });

  final AvatarCreado avatar;
  final EstiloCreado estilo;
  final JugadorCreado jugador;
  final ValueChanged<AvatarCreado> alCambiar;
  final ValueChanged<EstiloCreado> alCambiarEstilo;

  Widget _muestra(BuildContext context, Color color, bool elegido, VoidCallback alTocar, String etiqueta) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: elegido,
      label: etiqueta,
      child: GestureDetector(
        onTap: alTocar,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: elegido ? esquema.primary : esquema.outlineVariant, width: elegido ? 3 : 1),
          ),
        ),
      ),
    );
  }

  AvatarCreado _azar() {
    final r = Random();
    return AvatarCreado(
      piel: r.nextInt(AvatarCreado.pieles),
      pelo: r.nextInt(AvatarCreado.pelos),
      estilo: r.nextInt(AvatarCreado.estilos),
      barba: r.nextInt(3) == 0 ? 1 + r.nextInt(AvatarCreado.barbas - 1) : 0,
      ancho: r.nextInt(AvatarCreado.anchos),
      alto: r.nextInt(AvatarCreado.altos),
      ojos: r.nextInt(AvatarCreado.ojosN),
      cejas: r.nextInt(AvatarCreado.cejasN),
      nariz: r.nextInt(AvatarCreado.narices),
      boca: r.nextInt(AvatarCreado.bocas),
      orejas: r.nextInt(AvatarCreado.orejasN),
      tatuaje: r.nextInt(4) == 0 ? 1 + r.nextInt(AvatarCreado.tatuajes - 1) : 0,
      gafas: r.nextInt(5) == 0 ? 1 + r.nextInt(AvatarCreado.gafasN - 1) : 0,
      cinta: r.nextInt(4) == 0,
      cuerpo: r.nextInt(AvatarCreado.cuerpos),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final franquicia = franquicias.first;
    final carta = jugador.comoCarta(id: 'mc-previa', franquiciaId: franquicia.id);
    final a = avatar;
    final colores = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < AvatarCreado.pieles; i++)
          _muestra(context, PerfilAvatar.pieles[i], a.piel == i, () => alCambiar(a.copyWith(piel: i)), 'Piel ${i + 1}'),
      ],
    );
    final coloresPelo = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < AvatarCreado.pelos; i++)
          _muestra(context, PerfilAvatar.pelosCreador[i], a.pelo == i, () => alCambiar(a.copyWith(pelo: i)), 'Pelo ${i + 1}'),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 120, height: 150, child: AvatarIlustrado(jugador: carta, franquicia: franquicia)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TU JUGADOR', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Armalo a tu gusto: rostro, peinado, accesorios, cuerpo y estilo de juego.',
                    style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => alCambiar(_azar()),
                        icon: const Icon(Icons.casino_outlined, size: 18),
                        label: const Text('Al azar'),
                      ),
                      TextButton(onPressed: () => alCambiar(const AvatarCreado()), child: const Text('Restablecer')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Grupo(
          titulo: 'ROSTRO',
          abierto: false,
          hijos: [
            Text('Piel', style: tema.textTheme.bodySmall),
            const SizedBox(height: 4),
            colores,
            const SizedBox(height: 10),
            _Opciones(titulo: 'Ojos', nombres: AvatarCreado.nombresOjos, valor: a.ojos, alElegir: (v) => alCambiar(a.copyWith(ojos: v))),
            _Opciones(titulo: 'Cejas', nombres: AvatarCreado.nombresCejas, valor: a.cejas, alElegir: (v) => alCambiar(a.copyWith(cejas: v))),
            _Opciones(titulo: 'Nariz', nombres: AvatarCreado.nombresNariz, valor: a.nariz, alElegir: (v) => alCambiar(a.copyWith(nariz: v))),
            _Opciones(titulo: 'Boca', nombres: AvatarCreado.nombresBoca, valor: a.boca, alElegir: (v) => alCambiar(a.copyWith(boca: v))),
            _Opciones(titulo: 'Orejas', nombres: AvatarCreado.nombresOrejas, valor: a.orejas, alElegir: (v) => alCambiar(a.copyWith(orejas: v))),
            _Deslizador(
              etiqueta: 'ANCHO',
              valor: '',
              slider: Slider(
                value: a.ancho.toDouble(),
                max: AvatarCreado.anchos - 1.0,
                divisions: AvatarCreado.anchos - 1,
                onChanged: (v) => alCambiar(a.copyWith(ancho: v.round())),
              ),
            ),
            _Deslizador(
              etiqueta: 'ALTO',
              valor: '',
              slider: Slider(
                value: a.alto.toDouble(),
                max: AvatarCreado.altos - 1.0,
                divisions: AvatarCreado.altos - 1,
                onChanged: (v) => alCambiar(a.copyWith(alto: v.round())),
              ),
            ),
          ],
        ),
        _Grupo(
          titulo: 'PEINADO Y BARBA',
          hijos: [
            Text('Color de pelo', style: tema.textTheme.bodySmall),
            const SizedBox(height: 4),
            coloresPelo,
            const SizedBox(height: 10),
            _Opciones(titulo: 'Peinado', nombres: AvatarCreado.nombresEstilo, valor: a.estilo, alElegir: (v) => alCambiar(a.copyWith(estilo: v))),
            _Opciones(titulo: 'Barba', nombres: AvatarCreado.nombresBarba, valor: a.barba, alElegir: (v) => alCambiar(a.copyWith(barba: v))),
          ],
        ),
        _Grupo(
          titulo: 'ACCESORIOS Y TATUAJES',
          hijos: [
            _Opciones(titulo: 'Gafas', nombres: AvatarCreado.nombresGafas, valor: a.gafas, alElegir: (v) => alCambiar(a.copyWith(gafas: v))),
            _Opciones(titulo: 'Tatuajes', nombres: AvatarCreado.nombresTatuaje, valor: a.tatuaje, alElegir: (v) => alCambiar(a.copyWith(tatuaje: v))),
            FilterChip(
              label: const Text('Cinta de brazo'),
              selected: a.cinta,
              visualDensity: VisualDensity.compact,
              onSelected: (v) => alCambiar(a.copyWith(cinta: v)),
            ),
          ],
        ),
        _Grupo(
          titulo: 'CUERPO Y ORIGEN',
          hijos: [
            _Opciones(titulo: 'Complexión', nombres: AvatarCreado.nombresCuerpo, valor: a.cuerpo, alElegir: (v) => alCambiar(a.copyWith(cuerpo: v))),
            _Deslizador(
              etiqueta: 'BRAZOS',
              valor: '${estilo.envergadura >= 0 ? '+' : ''}${estilo.envergadura} cm',
              slider: Slider(
                value: estilo.envergadura.toDouble(),
                min: EstiloCreado.envergaduraMin.toDouble(),
                max: EstiloCreado.envergaduraMax.toDouble(),
                divisions: EstiloCreado.envergaduraMax - EstiloCreado.envergaduraMin,
                onChanged: (v) => alCambiarEstilo(estilo.copyWith(envergadura: v.round())),
              ),
            ),
            Text('Brazos largos suman tapones, robos y rebotes; cortos, los restan.', style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            _Opciones(titulo: 'Mano dominante', nombres: EstiloCreado.manos, valor: estilo.mano, alElegir: (v) => alCambiarEstilo(estilo.copyWith(mano: v))),
            _Opciones(
              titulo: 'Origen',
              nombres: [for (final o in OrigenJugador.values) o.etiqueta],
              valor: estilo.origen.index,
              alElegir: (v) => alCambiarEstilo(estilo.copyWith(origen: OrigenJugador.values[v])),
            ),
            Text(estilo.origen.descripcion, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
        ),
        _Grupo(
          titulo: 'ESTILO DE JUEGO',
          hijos: [
            _Opciones(
              titulo: 'Personalidad',
              nombres: [for (final p in Personalidad.values) p.etiqueta],
              valor: estilo.personalidad.index,
              alElegir: (v) => alCambiarEstilo(estilo.copyWith(personalidad: Personalidad.values[v])),
            ),
            Text(
              estilo.personalidad.descripcion,
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            _Opciones(titulo: 'Forma de tirar', nombres: EstiloCreado.formas, valor: estilo.formaDeTiro, alElegir: (v) => alCambiarEstilo(estilo.copyWith(formaDeTiro: v))),
            _Opciones(titulo: 'Festejo', nombres: EstiloCreado.festejos, valor: estilo.festejo, alElegir: (v) => alCambiarEstilo(estilo.copyWith(festejo: v))),
            Text('Tu forma de tirar y tu festejo te identifican en el relato y en la barra de tiro.', style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
