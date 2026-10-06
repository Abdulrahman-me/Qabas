// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journey_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LessonRefDto _$LessonRefDtoFromJson(Map<String, dynamic> json) => $checkedCreate('LessonRefDto', json, ($checkedConvert) {
  final val = LessonRefDto(
    lessonId: $checkedConvert('lesson_id', (v) => v as String),
    unitId: $checkedConvert('unit_id', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'lessonId': 'lesson_id', 'unitId': 'unit_id'});

SoftLockDto _$SoftLockDtoFromJson(Map<String, dynamic> json) => $checkedCreate('SoftLockDto', json, ($checkedConvert) {
  final val = SoftLockDto(
    prerequisites: $checkedConvert(
      'prerequisites',
      (v) => (v as List<dynamic>).map((e) => LessonRefDto.fromJson(e as Map<String, dynamic>)).toList(),
    ),
    startWith: $checkedConvert('start_with', (v) => LessonRefDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'startWith': 'start_with'});

JourneyCurrentDto _$JourneyCurrentDtoFromJson(Map<String, dynamic> json) => $checkedCreate('JourneyCurrentDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['unit_id', 'lesson_id']);
  final val = JourneyCurrentDto(
    unitId: $checkedConvert('unit_id', (v) => v as String?),
    lessonId: $checkedConvert('lesson_id', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'unitId': 'unit_id', 'lessonId': 'lesson_id'});

PretestDto _$PretestDtoFromJson(Map<String, dynamic> json) => $checkedCreate('PretestDto', json, ($checkedConvert) {
  final val = PretestDto(
    state: $checkedConvert('state', (v) => $enumDecode(_$PretestStateDtoEnumMap, v, unknownValue: PretestStateDto.unknown)),
  );
  return val;
});

const _$PretestStateDtoEnumMap = {
  PretestStateDto.taken: 'taken',
  PretestStateDto.notTaken: 'not_taken',
  PretestStateDto.unknown: 'unknown',
};

UnitTestDto _$UnitTestDtoFromJson(Map<String, dynamic> json) => $checkedCreate('UnitTestDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['best_percent']);
  final val = UnitTestDto(
    state: $checkedConvert('state', (v) => $enumDecode(_$UnitTestStateDtoEnumMap, v, unknownValue: UnitTestStateDto.unknown)),
    bestPercent: $checkedConvert('best_percent', (v) => (v as num?)?.toInt()),
    passPercent: $checkedConvert('pass_percent', (v) => (v as num).toInt()),
    canSkip: $checkedConvert('can_skip', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'bestPercent': 'best_percent', 'passPercent': 'pass_percent', 'canSkip': 'can_skip'});

const _$UnitTestStateDtoEnumMap = {
  UnitTestStateDto.notPassed: 'not_passed',
  UnitTestStateDto.passed: 'passed',
  UnitTestStateDto.unknown: 'unknown',
};

LessonEntryDto _$LessonEntryDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'LessonEntryDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['soft_lock']);
    final val = LessonEntryDto(
      lessonId: $checkedConvert('lesson_id', (v) => v as String),
      index: $checkedConvert('index', (v) => (v as num).toInt()),
      title: $checkedConvert('title', (v) => v as String),
      lessonType: $checkedConvert('lesson_type', (v) => $enumDecode(_$LessonTypeDtoEnumMap, v, unknownValue: LessonTypeDto.unknown)),
      state: $checkedConvert('state', (v) => $enumDecode(_$LessonStateDtoEnumMap, v, unknownValue: LessonStateDto.unknown)),
      estimatedMinutes: $checkedConvert('estimated_minutes', (v) => (v as num).toInt()),
      xp: $checkedConvert('xp', (v) => (v as num).toInt()),
      standaloneEligible: $checkedConvert('standalone_eligible', (v) => v as bool),
      softLock: $checkedConvert('soft_lock', (v) => v == null ? null : SoftLockDto.fromJson(v as Map<String, dynamic>)),
    );
    return val;
  },
  fieldKeyMap: const {
    'lessonId': 'lesson_id',
    'lessonType': 'lesson_type',
    'estimatedMinutes': 'estimated_minutes',
    'standaloneEligible': 'standalone_eligible',
    'softLock': 'soft_lock',
  },
);

const _$LessonTypeDtoEnumMap = {
  LessonTypeDto.concept: 'concept',
  LessonTypeDto.story: 'story',
  LessonTypeDto.practice: 'practice',
  LessonTypeDto.unknown: 'unknown',
};

const _$LessonStateDtoEnumMap = {
  LessonStateDto.locked: 'locked',
  LessonStateDto.available: 'available',
  LessonStateDto.inProgress: 'in_progress',
  LessonStateDto.completed: 'completed',
  LessonStateDto.unknown: 'unknown',
};

JourneyUnitDto _$JourneyUnitDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'JourneyUnitDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['art_key']);
    final val = JourneyUnitDto(
      unitId: $checkedConvert('unit_id', (v) => v as String),
      index: $checkedConvert('index', (v) => (v as num).toInt()),
      title: $checkedConvert('title', (v) => v as String),
      subtitle: $checkedConvert('subtitle', (v) => v as String),
      artKey: $checkedConvert('art_key', (v) => v as String?),
      hasGuide: $checkedConvert('has_guide', (v) => v as bool),
      state: $checkedConvert('state', (v) => $enumDecode(_$UnitStateDtoEnumMap, v, unknownValue: UnitStateDto.unknown)),
      comingSoon: $checkedConvert('coming_soon', (v) => v as bool),
      pretest: $checkedConvert('pretest', (v) => PretestDto.fromJson(v as Map<String, dynamic>)),
      unitTest: $checkedConvert('unit_test', (v) => UnitTestDto.fromJson(v as Map<String, dynamic>)),
      lessons: $checkedConvert(
        'lessons',
        (v) => (v as List<dynamic>).map((e) => LessonEntryDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'unitId': 'unit_id',
    'artKey': 'art_key',
    'hasGuide': 'has_guide',
    'comingSoon': 'coming_soon',
    'unitTest': 'unit_test',
  },
);

const _$UnitStateDtoEnumMap = {
  UnitStateDto.locked: 'locked',
  UnitStateDto.available: 'available',
  UnitStateDto.inProgress: 'in_progress',
  UnitStateDto.completed: 'completed',
  UnitStateDto.skipped: 'skipped',
  UnitStateDto.unknown: 'unknown',
};

JourneyDto _$JourneyDtoFromJson(Map<String, dynamic> json) => $checkedCreate('JourneyDto', json, ($checkedConvert) {
  final val = JourneyDto(
    track: $checkedConvert('track', (v) => $enumDecode(_$JourneyTrackDtoEnumMap, v, unknownValue: JourneyTrackDto.unknown)),
    current: $checkedConvert('current', (v) => JourneyCurrentDto.fromJson(v as Map<String, dynamic>)),
    units: $checkedConvert('units', (v) => (v as List<dynamic>).map((e) => JourneyUnitDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

const _$JourneyTrackDtoEnumMap = {
  JourneyTrackDto.explorer: 'explorer',
  JourneyTrackDto.newMuslim: 'new_muslim',
  JourneyTrackDto.unknown: 'unknown',
};
