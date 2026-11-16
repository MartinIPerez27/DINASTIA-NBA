import 'package:flutter/material.dart';

import '../../core/fotos/fuentes_foto.dart';
import '../../core/fotos/gestor_fotos.dart';
import '../../core/fotos/indice_fotos.dart';
import '../../data/catalogo_jugadores.dart';
import '../../domain/entities/jugador.dart';
import '../tema/tema_franquicia.dart';

/// Fotos de jugadores: baja todas las fotos una vez (con wifi) y las deja guardadas en el celular.
/// [gestor] y [catalogo] se pueden inyectar (tests); por defecto, el de la app y el catálogo real.
class FotosPantalla extends StatelessWidget {
  const FotosPantalla({super.key, this.gestor, this.catalogo});

  final GestorFotos? gestor;
  final Future<List<Jugador>> Function()? catalogo;

  @override
  Widget build(BuildContext context) {
    final g = gestor ?? GestorFotos.instancia;
    return Scaffold(
      appBar: AppBar(title: const Text('Fotos de jugadores')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: g == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Las fotos no están disponibles en este dispositivo. Se ven los retratos ilustrados.'),
                  )
                : FutureBuilder<List<Jugador>>(
                    future: (catalogo ?? cargarCatalogo)(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      return _Contenido(gestor: g, personas: GestorFotos.personasDe(snap.data!));
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.gestor, required this.personas});

  final GestorFotos gestor;
  final List<PersonaFoto> personas;

  static String _n(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  /// Tiempo aproximado: ~0,5 s por foto de la NBA y ~7 s por foto de Wikipedia/Commons (3 s entre
  /// pedidos al mismo sitio, varios pedidos por persona).
  static String _estimado(Iterable<PersonaFoto> faltan) {
    final seg = faltan.fold<double>(0, (s, p) => s + (p.usaNba ? 0.8 : 7));
    final min = (seg / 60).ceil();
    if (min < 2) return 'menos de 2 minutos';
    if (min < 90) return 'unos $min minutos';
    return 'unas ${(min / 60).toStringAsFixed(1).replaceAll('.', ',')} horas';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return ListenableBuilder(
      listenable: gestor,
      builder: (context, _) {
        final c = gestor.conteo(personas);
        final total = personas.length;
        final resueltas = c.listas + c.sin;
        final faltan = [
          for (final p in personas)
            if (gestor.de(p.clave)?.estado != EstadoFoto.ok && gestor.de(p.clave)?.estado != EstadoFoto.sin) p,
        ];
        final trabajando = gestor.trabajando;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: esquema.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EN EL CELULAR', style: tema.textTheme.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      '${_n(c.listas)} / ${_n(total)}',
                      key: const Key('fotos-contador'),
                      style: TextStyle(fontFamily: Fuentes.led, fontSize: 40, color: esquema.primary, height: 1.1),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      key: const Key('fotos-progreso'),
                      value: total == 0 ? 0 : resueltas / total,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 12),
                    Text('Faltan ${_n(faltan.length)} · Sin foto en ninguna fuente ${_n(c.sin)}'),
                    if (faltan.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tiempo estimado: ${_estimado(faltan)}.',
                        style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                    ],
                    if (gestor.mensaje case final m?) ...[
                      const SizedBox(height: 8),
                      Text(
                        m,
                        key: const Key('fotos-mensaje'),
                        style: TextStyle(color: esquema.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!trabajando)
              FilledButton.icon(
                key: const Key('fotos-descargar'),
                onPressed: faltan.isEmpty ? null : () => gestor.descargarTodas(personas),
                icon: const Icon(Icons.download),
                label: const Text('Descargar todas (recomendado con wifi)'),
              )
            else if (gestor.pausado)
              FilledButton.icon(
                key: const Key('fotos-reanudar'),
                onPressed: gestor.reanudar,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Reanudar'),
              )
            else
              OutlinedButton.icon(
                key: const Key('fotos-pausar'),
                onPressed: gestor.pausar,
                icon: const Icon(Icons.pause),
                label: const Text('Pausar'),
              ),
            if (c.sin > 0 && !trabajando)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  key: const Key('fotos-reintentar'),
                  onPressed: () => gestor.reintentarSinFoto(personas),
                  child: Text('Buscar de nuevo las ${_n(c.sin)} sin foto'),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Las fotos se bajan una sola vez, de a poco y con pausas para no abusar de los sitios, y '
              'quedan guardadas en el celular: después se ven sin internet. Dejá la app abierta mientras '
              'baja. Si falta una foto, la carta muestra un retrato ilustrado.',
              style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('fotos-fuentes'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copyright),
              title: const Text('Fuentes y licencias'),
              subtitle: const Text('De dónde salen las fotos y quién las hizo.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => FuentesLicenciasPantalla(gestor: gestor))),
            ),
          ],
        );
      },
    );
  }
}

/// Atribución de cada fuente de fotos y, por foto, autor y licencia (CC BY / CC BY-SA exigen mostrarlos).
class FuentesLicenciasPantalla extends StatelessWidget {
  const FuentesLicenciasPantalla({super.key, required this.gestor});

  final GestorFotos gestor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fotos = gestor.atribuciones();
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(t, style: tema.textTheme.titleMedium),
    );
    final suave = tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Fuentes y licencias')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                titulo('CDN de la NBA'),
                Text(
                  'Las fotos oficiales de los jugadores actuales y recientes se bajan del servidor público de '
                  'imágenes de la NBA (cdn.nba.com). Son propiedad de la NBA y de NBA Media Ventures; se usan '
                  'solo en esta app personal, sin fines comerciales.',
                  style: suave,
                ),
                titulo('Wikipedia y Wikimedia Commons'),
                Text(
                  'Los retratos históricos salen de los artículos de Wikipedia y de Wikimedia Commons. Solo se '
                  'aceptan archivos con licencia libre (Creative Commons CC BY, CC BY-SA, CC0 o dominio '
                  'público). Cada foto conserva su autor y su licencia, que figuran abajo. Las fotos se '
                  'recortan (se les quita el fondo) para mostrarlas en las cartas.',
                  style: suave,
                ),
                titulo('Sports Reference / Basketball-Reference'),
                Text(
                  'Las estadísticas del catálogo parten de los datos públicos de Basketball-Reference '
                  '(Sports Reference LLC). Esta app no baja sus fotos.',
                  style: suave,
                ),
                titulo('Retratos ilustrados'),
                Text(
                  'Cuando no hay foto, el retrato es una ilustración propia de la app, dibujada por código '
                  'con la camiseta de la franquicia.',
                  style: suave,
                ),
                titulo('Autor y licencia de cada foto (${fotos.length})'),
                if (fotos.isEmpty)
                  Text('Todavía no hay fotos de Wikipedia o Commons en este celular.', style: suave)
                else
                  for (final f in fotos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.nombre ?? f.persona, style: tema.textTheme.titleSmall),
                          Text('${f.autor ?? 'Autor sin datos'} · ${f.licencia ?? 'licencia sin datos'}', style: suave),
                          if (f.urlPagina ?? f.urlOrigen case final u?)
                            SelectableText(
                              u,
                              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.primary),
                            ),
                        ],
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
