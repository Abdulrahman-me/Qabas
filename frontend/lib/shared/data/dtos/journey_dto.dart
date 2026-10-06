import 'package:json_annotation/json_annotation.dart';
part 'journey_dto.g.dart';

enum LessonTypeDto { concept, story, practice, unknown }

enum LessonStateDto {
  locked,
  available,
  @JsonValue('in_progress')
  inProgress,
  completed,
  unknown,
}

enum UnitStateDto {
  locked,
  available,
  @JsonValue('in_progress')
  inProgress,
  completed,
  skipped,
  unknown,
}

enum PretestStateDto {
  taken,
  @JsonValue('not_taken')
  notTaken,
  unknown,
}

enum UnitTestStateDto {
  @JsonValue('not_passed')
  notPassed,
  passed,
  unknown,
}

enum JourneyTrackDto {
  explorer,
  @JsonValue('new_muslim')
  newMuslim,
  unknown,
}

@JsonSerializable()
final class LessonRefDto {
  const LessonRefDto({required this.lessonId, required this.unitId, required this.title});
  factory LessonRefDto.fromJson(Map<String, dynamic> json) => _$LessonRefDtoFromJson(json);
  final String lessonId;
  final String unitId;
  final String title;
}

@JsonSerializable()
final class SoftLockDto {
  const SoftLockDto({required this.prerequisites, required this.startWith});
  factory SoftLockDto.fromJson(Map<String, dynamic> json) => _$SoftLockDtoFromJson(json);
  final List<LessonRefDto> prerequisites;
  final LessonRefDto startWith;
}

@JsonSerializable()
final class JourneyCurrentDto {
  const JourneyCurrentDto({required this.unitId, required this.lessonId});
  factory JourneyCurrentDto.fromJson(Map<String, dynamic> json) => _$JourneyCurrentDtoFromJson(json);
  @JsonKey(required: true)
  final String? unitId;
  @JsonKey(required: true)
  final String? lessonId;
}

@JsonSerializable()
final class PretestDto {
  const PretestDto({required this.state});
  factory PretestDto.fromJson(Map<String, dynamic> json) => _$PretestDtoFromJson(json);
  @JsonKey(unknownEnumValue: PretestStateDto.unknown)
  final PretestStateDto state;
}

@JsonSerializable()
final class UnitTestDto {
  const UnitTestDto({required this.state, required this.bestPercent, required this.passPercent, required this.canSkip});
  factory UnitTestDto.fromJson(Map<String, dynamic> json) => _$UnitTestDtoFromJson(json);
  @JsonKey(unknownEnumValue: UnitTestStateDto.unknown)
  final UnitTestStateDto state;
  @JsonKey(required: true)
  final int? bestPercent;
  final int passPercent;
  final bool canSkip;
}

@JsonSerializable()
final class LessonEntryDto {
  const LessonEntryDto({
    required this.lessonId,
    required this.index,
    required this.title,
    required this.lessonType,
    required this.state,
    required this.estimatedMinutes,
    required this.xp,
    required this.standaloneEligible,
    required this.softLock,
  });
  factory LessonEntryDto.fromJson(Map<String, dynamic> json) => _$LessonEntryDtoFromJson(json);
  final String lessonId;
  final int index;
  final String title;
  @JsonKey(unknownEnumValue: LessonTypeDto.unknown)
  final LessonTypeDto lessonType;
  @JsonKey(unknownEnumValue: LessonStateDto.unknown)
  final LessonStateDto state;
  final int estimatedMinutes;
  final int xp;
  final bool standaloneEligible;
  @JsonKey(required: true)
  final SoftLockDto? softLock;
}

@JsonSerializable()
final class JourneyUnitDto {
  const JourneyUnitDto({
    required this.unitId,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.artKey,
    required this.hasGuide,
    required this.state,
    required this.comingSoon,
    required this.pretest,
    required this.unitTest,
    required this.lessons,
  });
  factory JourneyUnitDto.fromJson(Map<String, dynamic> json) => _$JourneyUnitDtoFromJson(json);
  final String unitId;
  final int index;
  final String title;
  final String subtitle;
  @JsonKey(required: true)
  final String? artKey;
  final bool hasGuide;
  @JsonKey(unknownEnumValue: UnitStateDto.unknown)
  final UnitStateDto state;
  final bool comingSoon;
  final PretestDto pretest;
  final UnitTestDto unitTest;
  final List<LessonEntryDto> lessons;
}

@JsonSerializable()
final class JourneyDto {
  const JourneyDto({required this.track, required this.current, required this.units});
  factory JourneyDto.fromJson(Map<String, dynamic> json) => _$JourneyDtoFromJson(json);
  @JsonKey(unknownEnumValue: JourneyTrackDto.unknown)
  final JourneyTrackDto track;
  final JourneyCurrentDto current;
  final List<JourneyUnitDto> units;
}
