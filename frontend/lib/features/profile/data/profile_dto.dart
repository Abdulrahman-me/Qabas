import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
part 'profile_dto.g.dart';

@JsonSerializable()
final class AchievementProgressDto {
  const AchievementProgressDto({required this.current, required this.target});
  factory AchievementProgressDto.fromJson(Map<String, dynamic> json) => _$AchievementProgressDtoFromJson(json);
  final int current, target;
}

@JsonSerializable()
final class AchievementDto {
  const AchievementDto({
    required this.achievementKey,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.unlockedAt,
    required this.progress,
  });
  factory AchievementDto.fromJson(Map<String, dynamic> json) => _$AchievementDtoFromJson(json);
  final String achievementKey, title, description;
  final bool unlocked;
  @JsonKey(required: true)
  final String? unlockedAt;
  final AchievementProgressDto progress;
  Achievement toEntity() => Achievement(
    key: achievementKey,
    title: title,
    description: description,
    unlocked: unlocked,
    unlockedAt: unlockedAt == null ? null : DateTime.parse(unlockedAt!),
    current: progress.current,
    target: progress.target,
  );
}

@JsonSerializable()
final class AchievementsDto {
  const AchievementsDto({required this.items});
  factory AchievementsDto.fromJson(Map<String, dynamic> json) => _$AchievementsDtoFromJson(json);
  final List<AchievementDto> items;
}

@JsonSerializable()
final class WordsPreviewDto {
  const WordsPreviewDto({required this.items, required this.nextCursor});
  factory WordsPreviewDto.fromJson(Map<String, dynamic> json) => _$WordsPreviewDtoFromJson(json);
  final List<TermCardDto> items;
  @JsonKey(required: true)
  final String? nextCursor;
}
