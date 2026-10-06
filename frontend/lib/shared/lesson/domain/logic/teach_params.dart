import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';

Map<String, Object?> teachParams(TeachItem item, int shown) => Map.unmodifiable({
  ...switch (item.visual) {
    BuiltinVisual(:final params) || SceneVisual(:final params) => params,
    _ => <String, Object?>{},
  },
  for (final point in item.points.take(shown)) ...?point.visualParams,
});
