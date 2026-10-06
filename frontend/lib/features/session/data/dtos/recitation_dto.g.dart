// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recitation_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecitationSegmentDto _$RecitationSegmentDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RecitationSegmentDto', json, ($checkedConvert) {
      final val = RecitationSegmentDto(
        url: $checkedConvert('url', (v) => v as String),
        startMs: $checkedConvert('start_ms', (v) => (v as num).toInt()),
        endMs: $checkedConvert('end_ms', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'startMs': 'start_ms', 'endMs': 'end_ms'});

RecitationWordDto _$RecitationWordDtoFromJson(Map<String, dynamic> json) => $checkedCreate('RecitationWordDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['expected', 'heard', 'audio_segment']);
  final val = RecitationWordDto(
    index: $checkedConvert('index', (v) => (v as num).toInt()),
    expected: $checkedConvert('expected', (v) => v as String?),
    result: $checkedConvert('result', (v) => v as String),
    heard: $checkedConvert('heard', (v) => v as String?),
    audioSegment: $checkedConvert('audio_segment', (v) => v == null ? null : RecitationSegmentDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'audioSegment': 'audio_segment'});

RecitationCheckDto _$RecitationCheckDtoFromJson(Map<String, dynamic> json) => $checkedCreate('RecitationCheckDto', json, ($checkedConvert) {
  final val = RecitationCheckDto(
    checkId: $checkedConvert('check_id', (v) => v as String),
    status: $checkedConvert('status', (v) => v as String),
    passed: $checkedConvert('passed', (v) => v as bool),
    words: $checkedConvert('words', (v) => (v as List<dynamic>).map((e) => RecitationWordDto.fromJson(e as Map<String, dynamic>)).toList()),
    summary: $checkedConvert('summary', (v) => Map<String, int>.from(v as Map)),
    message: $checkedConvert('message', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'checkId': 'check_id'});
