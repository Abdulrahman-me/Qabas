import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/unit_guide/data/unit_guide_dto.dart';
import 'package:qabas/features/unit_guide/domain/unit_guide.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';

final class UnitGuideRepositoryImpl implements UnitGuideRepository {
  const UnitGuideRepositoryImpl(this.api, this.journey);
  final ApiClient api;
  final JourneyRepository journey;
  @override
  Future<Result<UnitGuide>> load(String id) => guard(() async {
    if (journey.cachedJourney == null) await journey.loadJourney();
    final d = await api.get('/units/${Uri.encodeComponent(id)}/guide', decode: UnitGuideDto.fromJson);
    return UnitGuide(
      title: d.title,
      sections: d.sections.map((s) => GuideSection(s.title, s.sentences.map((v) => v.toEntity()).toList())).toList(),
      sources: d.sources.map((v) => v.toEntity()).toList(),
      terms: d.terms.map((k, v) => MapEntry(k, v.toEntity())),
      unit: journey.cachedJourney?.units.where((u) => u.unitId == id).firstOrNull,
    );
  });
}
