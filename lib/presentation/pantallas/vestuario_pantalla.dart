import 'package:flutter/material.dart';

import '../../data/estado_app.dart';
import '../../domain/entities/franquicia.dart';
import '../../domain/entities/metajuego.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/misiones.dart';
import '../partido/cancha_partido.dart';
import '../tema/vestuario.dart';

/// Vestuario: elegí cancha, pelota, uniforme y color de los LED entre lo que ganaste en el pase de
/// temporada o con tu nivel de entrenador. Arriba, la cancha en vivo con lo elegido.
class VestuarioPantalla extends StatelessWidget {
  const VestuarioPantalla({super.key, required this.franquicia, required this.onPerfil});

  final Franquicia franquicia;
  final ValueChanged<PerfilEntrenador> onPerfil;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Vestuario')),
      body: ValueListenableBuilder(
        valueListenable: perfilApp,
        builder: (context, perfil, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            VistaPreviaVestuario(franquicia: franquicia, perfil: perfil),
            for (final cat in CategoriaCosmetico.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 6),
                child: Text(cat.nombre.toUpperCase(), style: tema.textTheme.titleSmall?.copyWith(letterSpacing: 1)),
              ),
              for (final c in Cosmetico.values.where((c) => c.categoria == cat))
                _OpcionCosmetico(
                  cosmetico: c,
                  franquicia: franquicia,
                  disponible: PaseTemporada.disponible(perfil, c),
                  elegido: perfil.metajuego.elegido(cat) == c,
                  onElegir: () => onPerfil(PaseTemporada.elegir(perfil, c)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La cancha en vivo (cerca del aro) con el piso, la pelota, los LED y la camiseta elegidos.
class VistaPreviaVestuario extends StatelessWidget {
  const VistaPreviaVestuario({super.key, required this.franquicia, required this.perfil});

  final Franquicia franquicia;
  final PerfilEntrenador perfil;

  @override
  Widget build(BuildContext context) {
    final primario = Color(franquicia.colorPrimario), secundario = Color(franquicia.colorSecundario);
    final (relleno, ribete) = Vestuario.uniforme(primario, secundario, perfil) ?? (primario, secundario);
    final numero = relleno.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    final led = Vestuario.led(perfil) ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Vista previa de la cancha con lo elegido',
      child: AspectRatio(
        aspectRatio: 1.25,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            painter: CanchaPartidoPainter(
              franquicia: franquicia,
              estilo: Vestuario.cancha(perfil),
              colorLed: led,
              cartel: 'VESTUARIO · ${franquicia.nombre.toUpperCase()}',
              camaraY: 16,
              zoom: 1.5,
              balon: const Offset(21.5, 21.5),
              alturaBalon: 0.25,
              fichas: [
                for (final (pos, n) in [(const Offset(20, 23), '23'), (const Offset(31, 14), '33')])
                  Ficha(
                    posicion: pos,
                    relleno: relleno,
                    texto: numero,
                    ribete: ribete,
                    etiqueta: n,
                    conBalon: n == '23',
                  ),
                const Ficha(
                  posicion: Offset(23, 16),
                  relleno: Color(0xFFEDEDED),
                  texto: Colors.black,
                  ribete: Color(0xFF555555),
                  etiqueta: '1',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpcionCosmetico extends StatelessWidget {
  const _OpcionCosmetico({
    required this.cosmetico,
    required this.franquicia,
    required this.disponible,
    required this.elegido,
    required this.onElegir,
  });

  final Cosmetico cosmetico;
  final Franquicia franquicia;
  final bool disponible, elegido;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final muestra = switch (cosmetico.categoria) {
      CategoriaCosmetico.led => Vestuario.ledDe(cosmetico) ?? esquema.primary,
      CategoriaCosmetico.pelota => Vestuario.estiloDe(Cosmetico.canchaModerna, cosmetico).pelota.first,
      CategoriaCosmetico.cancha => Vestuario.estiloDe(cosmetico, Cosmetico.pelotaClasica).madera,
      CategoriaCosmetico.uniforme =>
        (Vestuario.uniformeDe(cosmetico, Color(franquicia.colorPrimario), Color(franquicia.colorSecundario)) ??
                (Color(franquicia.colorPrimario), null))
            .$1,
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: elegido ? esquema.primary : Colors.transparent, width: 1.6),
      ),
      child: ListTile(
        enabled: disponible,
        onTap: disponible && !elegido ? onElegir : null,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: disponible ? muestra : esquema.surfaceContainerHighest,
          child: disponible ? null : Icon(Icons.lock_outline, size: 16, color: esquema.onSurfaceVariant),
        ),
        title: Text(cosmetico.nombre),
        subtitle: Text(disponible ? cosmetico.descripcion : 'Se gana en: ${cosmetico.origen}'),
        trailing: elegido
            ? Icon(Icons.check_circle, color: esquema.primary, semanticLabel: 'En uso')
            : disponible
            ? const Text('USAR')
            : null,
      ),
    );
  }
}
