import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/estado_app.dart';
import '../../data/franquicias.dart';
import '../../domain/entities/temporada.dart';
import '../../domain/version_catalogo.dart';
import '../../domain/reto.dart';
import '../widgets/escudo.dart';
import '../widgets/texto_led.dart';
import 'modos.dart';

/// "Reto de un amigo": pide el código, muestra de qué se trata y arranca la partida (el flujo
/// clásico, con el draft, el calendario y los rivales que salen de la semilla del código).
Future<void> iniciarReto(ContextoModos c) async {
  final codigo = await pedirCodigoReto(c.context);
  if (codigo == null) return;
  final t = Reto.aceptar(codigo, id: ContextoModos.nuevoId(), fichasExtra: perfilApp.value.fichasExtra);
  await c.guardar(t);
  await c.abrirTemporada(t);
}

/// Hoja para ingresar un código de reto. Devuelve el reto aceptado (null si se cierra).
Future<CodigoReto?> pedirCodigoReto(BuildContext context) => showModalBottomSheet<CodigoReto>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: IngresarCodigoReto(onAceptar: (c) => Navigator.of(context).pop(c)),
  ),
);

class IngresarCodigoReto extends StatefulWidget {
  const IngresarCodigoReto({super.key, required this.onAceptar, this.inicial = ''});

  final ValueChanged<CodigoReto> onAceptar;
  final String inicial;

  @override
  State<IngresarCodigoReto> createState() => _IngresarCodigoRetoState();
}

class _IngresarCodigoRetoState extends State<IngresarCodigoReto> {
  late final _texto = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final escrito = _texto.text.replaceAll(RegExp(r'[\s\-]'), '');
    final codigo = CodigoReto.leer(_texto.text);
    final valido = codigo != null && codigo.regla != ReglaDraft.coleccion;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RETO DE UN AMIGO', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Pegá o escribí su código: vas a jugar su mismo draft, con el mismo calendario y los mismos rivales.',
            style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _texto,
            autofocus: widget.inicial.isEmpty,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 22, letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()]),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z\- ]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              hintText: '82-XXXX-XXXX-XXXX',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Pegar',
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  final datos = await Clipboard.getData(Clipboard.kTextPlain);
                  final pegado = datos?.text?.trim();
                  if (pegado == null || pegado.isEmpty) return;
                  // Si pegó el mensaje entero, busca el código adentro.
                  final m = RegExp(r'82-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}').firstMatch(pegado);
                  setState(() => _texto.text = (m?.group(0) ?? pegado).toUpperCase());
                },
              ),
              errorText: codigo == null && escrito.length >= 14
                  ? 'Ese código no es válido: revisá que esté bien copiado.'
                  : codigo != null && !valido
                  ? 'Ese reto usa "Mi colección": cada álbum es distinto, no se puede jugar.'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (valido) ...[
            VistaPreviaReto(codigo: codigo),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => widget.onAceptar(codigo), child: const Text('ACEPTAR EL RETO')),
          ],
        ],
      ),
    );
  }
}

/// Aviso si el reto se armó con otra versión de las cartas (o con un código anterior al versionado),
/// o null si es el mismo catálogo.
String? avisoCatalogo(CodigoReto codigo, {int? versionActual}) =>
    switch (codigo.mismoCatalogo(versionActual ?? versionCatalogo)) {
      false => 'Este reto se armó con otra versión de las cartas: el draft puede no ser idéntico.',
      null when codigo.version == null => 'Código de una versión anterior de la app: el draft puede no ser idéntico.',
      _ => null,
    };

/// "Reto de un amigo: Bulls, Ruleta, Normal — superá 64-18".
class VistaPreviaReto extends StatelessWidget {
  const VistaPreviaReto({super.key, required this.codigo});

  final CodigoReto codigo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final f = franquiciaPorId(codigo.franquiciaId);
    final reglas = [
      codigo.modo.nombre,
      if (codigo.regla != ReglaDraft.libre) codigo.regla.nombre,
      if (codigo.epoca case final e?) e.etiqueta,
      codigo.dificultad.nombre,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: esquema.primary),
      ),
      child: Row(
        children: [
          Escudo(f, tamano: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reto de un amigo: ${f.nombre}', style: tema.textTheme.titleMedium),
                Text(reglas, style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  codigo.marca == null
                      ? 'Todavía no terminó su temporada: comparen récords al final.'
                      : 'Superá su ${codigo.marca}${codigo.campeon ? ' (y salió campeón)' : ''}.',
                ),
                if (avisoCatalogo(codigo) case final aviso?) ...[
                  const SizedBox(height: 6),
                  Text(aviso, style: tema.textTheme.bodySmall?.copyWith(color: esquema.error)),
                ],
              ],
            ),
          ),
          if (codigo.marca case final m?) ...[const SizedBox(width: 8), TextoLed(m, tamano: 24)],
        ],
      ),
    );
  }
}

/// En la temporada de un reto: tu récord contra el de tu amigo y, al final, quién ganó.
class TarjetaReto extends StatelessWidget {
  const TarjetaReto({super.key, required this.temporada});

  final Temporada temporada;

  @override
  Widget build(BuildContext context) {
    final codigo = Reto.aceptadoEn(temporada);
    if (codigo == null) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final (tuya, amigo, veredicto) = Reto.comparar(temporada);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: veredicto == ResultadoReto.ganaste ? esquema.primary : esquema.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sports_score, color: esquema.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('RETO DE UN AMIGO', style: tema.textTheme.titleSmall?.copyWith(letterSpacing: 1))),
              Text(codigo.codificar(), style: tema.textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Marca(titulo: 'VOS', marca: tuya),
              ),
              Text('vs', style: tema.textTheme.bodySmall),
              Expanded(
                child: _Marca(titulo: 'TU AMIGO', marca: amigo ?? '—'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            veredicto?.texto ??
                (amigo == null
                    ? 'Tu amigo todavía no tenía récord cuando te retó: compárenlo al final.'
                    : 'Gana el mejor récord de la temporada regular; si empatan, desempata el anillo.'),
            textAlign: TextAlign.center,
            style: veredicto == null
                ? tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)
                : tema.textTheme.titleMedium?.copyWith(color: esquema.primary),
          ),
        ],
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.titulo, required this.marca});

  final String titulo;
  final String marca;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(titulo, style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),
      const SizedBox(height: 4),
      TextoLed(marca, tamano: 30),
    ],
  );
}
