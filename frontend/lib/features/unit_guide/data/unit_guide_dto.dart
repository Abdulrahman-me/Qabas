import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
part 'unit_guide_dto.g.dart';

@JsonSerializable()
final class GuideSectionDto {
  const GuideSectionDto({required this.title, required this.sentences});
  factory GuideSectionDto.fromJson(Map<String, dynamic> j) => _$GuideSectionDtoFromJson(j);
  final String title;
  final List<SentenceDto> sentences;
}

@JsonSerializable()
final class UnitGuideDto {
  const UnitGuideDto({required this.unitId, required this.title, required this.sections, required this.sources, required this.terms});
  factory UnitGuideDto.fromJson(Map<String, dynamic> j) => _$UnitGuideDtoFromJson(j);
  final String unitId, title;
  final List<GuideSectionDto> sections;
  final List<SourceDto> sources;
  final Map<String, TermCardDto> terms;
}
