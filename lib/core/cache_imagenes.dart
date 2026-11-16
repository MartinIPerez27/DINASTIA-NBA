import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché en disco SOLO para mostrar al instante las fotos del CDN de la NBA mientras el gestor de
/// fotos (`core/fotos/gestor_fotos.dart`) las baja a su carpeta definitiva. Lo que queda para siempre
/// en el celular no depende de este caché: vive en la carpeta del gestor y en su índice SQLite.
final cacheHeadshots = CacheManager(
  Config('headshots_nba', stalePeriod: const Duration(days: 3650), maxNrOfCacheObjects: 6000),
);
