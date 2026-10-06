import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/features/session/domain/entities/recitation.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
part 'recitation_dto.g.dart';

@JsonSerializable()
final class RecitationSegmentDto {
  const RecitationSegmentDto({required this.url, required this.startMs, required this.endMs});
  factory RecitationSegmentDto.fromJson(Map<String, dynamic> j) => _$RecitationSegmentDtoFromJson(j);
  final String url;
  final int startMs, endMs;
}

@JsonSerializable()
final class RecitationWordDto {
  const RecitationWordDto({
    required this.index,
    required this.expected,
    required this.result,
    required this.heard,
    required this.audioSegment,
  });
  factory RecitationWordDto.fromJson(Map<String, dynamic> j) => _$RecitationWordDtoFromJson(j);
  final int index;
  final String result;
  @JsonKey(required: true)
  final String? expected, heard;
  @JsonKey(required: true)
  final RecitationSegmentDto? audioSegment;
}

@JsonSerializable()
final class RecitationCheckDto {
  const RecitationCheckDto({
    required this.checkId,
    required this.status,
    required this.passed,
    required this.words,
    required this.summary,
    required this.message,
  });
  factory RecitationCheckDto.fromJson(Map<String, dynamic> j) => _$RecitationCheckDtoFromJson(j);
  final String checkId, status;
  final bool passed;
  final List<RecitationWordDto> words;
  final Map<String, int> summary;
  final List<SpanDto> message;
  RecitationCheck toEntity() {
    if (!['evaluated', 'unclear'].contains(status)) throw const FormatException('Unknown recitation status');
    return RecitationCheck(
      checkId,
      status == 'unclear',
      passed,
      words
          .map(
            (w) => RecitationWord(
              w.index,
              RecitationWordResult.values.byName(w.result),
              w.audioSegment == null
                  ? null
                  : RecitationSegment(
                      w.audioSegment!.url,
                      Duration(milliseconds: w.audioSegment!.startMs), // rules:allow wire duration, not a motion constant
                      Duration(milliseconds: w.audioSegment!.endMs), // rules:allow wire duration, not a motion constant
                    ),
            ),
          )
          .toList(),
      contentSpans(message),
    );
  }
}
