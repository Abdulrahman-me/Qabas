import 'package:json_annotation/json_annotation.dart';
part 'next_step_dto.g.dart';

enum NextTypeDto {
  pretest,
  lesson,
  review,
  @JsonValue('unit_test')
  unitTest,
  @JsonValue('journey_complete')
  journeyComplete,
  unknown,
}

enum NextReasonDto {
  @JsonValue('new_unit_pretest')
  newUnitPretest,
  @JsonValue('due_reviews')
  dueReviews,
  @JsonValue('next_lesson')
  nextLesson,
  @JsonValue('unit_ready_for_test')
  unitReadyForTest,
  @JsonValue('all_done')
  allDone,
  unknown,
}

@JsonSerializable()
final class NextStepDto {
  const NextStepDto({
    required this.type,
    required this.reason,
    required this.unitId,
    required this.lessonId,
    required this.title,
    required this.dueReviewsCount,
  });
  factory NextStepDto.fromJson(Map<String, dynamic> json) => _$NextStepDtoFromJson(json);
  @JsonKey(unknownEnumValue: NextTypeDto.unknown)
  final NextTypeDto type;
  @JsonKey(unknownEnumValue: NextReasonDto.unknown)
  final NextReasonDto reason;
  @JsonKey(required: true)
  final String? unitId;
  @JsonKey(required: true)
  final String? lessonId;
  @JsonKey(required: true)
  final String? title;
  final int dueReviewsCount;
}
