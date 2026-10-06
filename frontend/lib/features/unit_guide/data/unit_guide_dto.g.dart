// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_guide_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GuideSectionDto _$GuideSectionDtoFromJson(Map<String, dynamic> json) => $checkedCreate('GuideSectionDto', json, ($checkedConvert) {
  final val = GuideSectionDto(
    title: $checkedConvert('title', (v) => v as String),
    sentences: $checkedConvert(
      'sentences',
      (v) => (v as List<dynamic>).map((e) => SentenceDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
  );
  return val;
});

UnitGuideDto _$UnitGuideDtoFromJson(Map<String, dynamic> json) => $checkedCreate('UnitGuideDto', json, ($checkedConvert) {
  final val = UnitGuideDto(
    unitId: $checkedConvert('unit_id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    sections: $checkedConvert(
      'sections',
      (v) => (v as List<dynamic>).map((e) => GuideSectionDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    sources: $checkedConvert('sources', (v) => (v as List<dynamic>).map((e) => SourceDto.fromJson(e as Map<String, dynamic>)).toList()),
    terms: $checkedConvert(
      'terms',
      (v) => (v as Map<String, dynamic>).map((k, e) => MapEntry(k, TermCardDto.fromJson(e as Map<String, dynamic>))),
    ),
  );
  return val;
}, fieldKeyMap: const {'unitId': 'unit_id'});
