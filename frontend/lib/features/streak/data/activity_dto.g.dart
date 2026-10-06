// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityDayDto _$ActivityDayDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ActivityDayDto', json, ($checkedConvert) {
  final val = ActivityDayDto(
    date: $checkedConvert('date', (v) => v as String),
    qualifying: $checkedConvert('qualifying', (v) => v as bool),
    minutes: $checkedConvert('minutes', (v) => (v as num).toInt()),
    xp: $checkedConvert('xp', (v) => (v as num).toInt()),
  );
  return val;
});

ActivityDto _$ActivityDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ActivityDto', json, ($checkedConvert) {
  final val = ActivityDto(
    timezone: $checkedConvert('timezone', (v) => v as String),
    from: $checkedConvert('from', (v) => v as String),
    to: $checkedConvert('to', (v) => v as String),
    streak: $checkedConvert('streak', (v) => StreakDto.fromJson(v as Map<String, dynamic>)),
    days: $checkedConvert('days', (v) => (v as List<dynamic>).map((e) => ActivityDayDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});
