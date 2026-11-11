import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché en disco de fotos del CDN. El default de flutter_cache_manager expira a los 30 días;
/// acá se guardan ~10 años para que, una vez vista la carta, funcione siempre sin internet.
final cacheHeadshots = CacheManager(
  Config('headshots_nba', stalePeriod: const Duration(days: 3650), maxNrOfCacheObjects: 2000),
);
