import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/franquicia.dart';

/// Escudo oficial empaquetado en assets/logos (funciona offline desde el primer arranque).
class Escudo extends StatelessWidget {
  const Escudo(this.franquicia, {super.key, required this.tamano});

  final Franquicia franquicia;
  final double tamano;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/logos/${franquicia.id}.svg',
    width: tamano,
    height: tamano,
    semanticsLabel: 'Escudo de ${franquicia.nombreCompleto}',
  );
}
