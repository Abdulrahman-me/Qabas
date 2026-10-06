// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AchievementProgressDto _$AchievementProgressDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AchievementProgressDto', json, ($checkedConvert) {
      final val = AchievementProgressDto(
        current: $checkedConvert('current', (v) => (v as num).toInt()),
        target: $checkedConvert('target', (v) => (v as num).toInt()),
      );
      return val;
    });

AchievementDto _$AchievementDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AchievementDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['unlocked_at']);
  final val = AchievementDto(
    achievementKey: $checkedConvert('achievement_key', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String),
    unlocked: $checkedConvert('unlocked', (v) => v as bool),
    unlockedAt: $checkedConvert('unlocked_at', (v) => v as String?),
    progress: $checkedConvert('progress', (v) => AchievementProgressDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'achievementKey': 'achievement_key', 'unlockedAt': 'unlocked_at'});

AchievementsDto _$AchievementsDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AchievementsDto', json, ($checkedConvert) {
  final val = AchievementsDto(
    items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => AchievementDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

WordsPreviewDto _$WordsPreviewDtoFromJson(Map<String, dynamic> json) => $checkedCreate('WordsPreviewDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['next_cursor']);
  final val = WordsPreviewDto(
    items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => TermCardDto.fromJson(e as Map<String, dynamic>)).toList()),
    nextCursor: $checkedConvert('next_cursor', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'nextCursor': 'next_cursor'});
