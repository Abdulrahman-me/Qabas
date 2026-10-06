// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'next_step_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NextStepDto _$NextStepDtoFromJson(Map<String, dynamic> json) => $checkedCreate('NextStepDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['unit_id', 'lesson_id', 'title']);
  final val = NextStepDto(
    type: $checkedConvert('type', (v) => $enumDecode(_$NextTypeDtoEnumMap, v, unknownValue: NextTypeDto.unknown)),
    reason: $checkedConvert('reason', (v) => $enumDecode(_$NextReasonDtoEnumMap, v, unknownValue: NextReasonDto.unknown)),
    unitId: $checkedConvert('unit_id', (v) => v as String?),
    lessonId: $checkedConvert('lesson_id', (v) => v as String?),
    title: $checkedConvert('title', (v) => v as String?),
    dueReviewsCount: $checkedConvert('due_reviews_count', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'unitId': 'unit_id', 'lessonId': 'lesson_id', 'dueReviewsCount': 'due_reviews_count'});

const _$NextTypeDtoEnumMap = {
  NextTypeDto.pretest: 'pretest',
  NextTypeDto.lesson: 'lesson',
  NextTypeDto.review: 'review',
  NextTypeDto.unitTest: 'unit_test',
  NextTypeDto.journeyComplete: 'journey_complete',
  NextTypeDto.unknown: 'unknown',
};

const _$NextReasonDtoEnumMap = {
  NextReasonDto.newUnitPretest: 'new_unit_pretest',
  NextReasonDto.dueReviews: 'due_reviews',
  NextReasonDto.nextLesson: 'next_lesson',
  NextReasonDto.unitReadyForTest: 'unit_ready_for_test',
  NextReasonDto.allDone: 'all_done',
  NextReasonDto.unknown: 'unknown',
};
