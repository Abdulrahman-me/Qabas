import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/glossary/data/glossary_dto.dart';
import 'package:qabas/features/glossary/domain/glossary.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';

final class GlossaryRepositoryImpl implements GlossaryRepository {
  const GlossaryRepositoryImpl(this.api);
  final ApiClient api;
  @override
  Future<Result<WordsPage>> load({required String filter, String? cursor}) => guard(
    () => api.get(
      '/glossary',
      query: {'state': filter, 'limit': 20, 'cursor': ?cursor},
      decode: (j) {
        final d = GlossaryPageDto.fromJson(j);
        return WordsPage(d.items.map((t) => t.toEntity()).toList(), d.nextCursor);
      },
    ),
  );
}
