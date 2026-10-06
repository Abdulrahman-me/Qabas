import 'package:json_annotation/json_annotation.dart';
part 'content_dto.g.dart';

sealed class SpanDto {
  const SpanDto();
  factory SpanDto.fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'text' => TextSpanDto.fromJson(json),
    'strong' => StrongSpanDto.fromJson(json),
    'term' => TermSpanDto.fromJson(json),
    'citation' => CitationSpanDto.fromJson(json),
    _ => UnknownSpanDto(json['text'] as String? ?? ''),
  };
}

final class UnknownSpanDto extends SpanDto {
  const UnknownSpanDto(this.text);
  final String text;
}

@JsonSerializable()
final class TextSpanDto extends SpanDto {
  const TextSpanDto({required this.text});
  factory TextSpanDto.fromJson(Map<String, dynamic> json) => _$TextSpanDtoFromJson(json);
  final String text;
}

@JsonSerializable()
final class StrongSpanDto extends SpanDto {
  const StrongSpanDto({required this.text});
  factory StrongSpanDto.fromJson(Map<String, dynamic> json) => _$StrongSpanDtoFromJson(json);
  final String text;
}

@JsonSerializable()
final class TermSpanDto extends SpanDto {
  const TermSpanDto({required this.text, required this.termId});
  factory TermSpanDto.fromJson(Map<String, dynamic> json) => _$TermSpanDtoFromJson(json);
  final String text;
  final String termId;
}

@JsonSerializable()
final class CitationSpanDto extends SpanDto {
  const CitationSpanDto({required this.ref});
  factory CitationSpanDto.fromJson(Map<String, dynamic> json) => _$CitationSpanDtoFromJson(json);
  final int ref;
}

@JsonSerializable()
final class SentenceDto {
  const SentenceDto({required this.sentenceId, required this.spans, required this.sourceIds});
  factory SentenceDto.fromJson(Map<String, dynamic> json) => _$SentenceDtoFromJson(json);
  final String sentenceId;
  final List<SpanDto> spans;
  final List<String> sourceIds;
}

@JsonSerializable()
final class SourceDto {
  const SourceDto({
    required this.sourceId,
    required this.kind,
    required this.provider,
    required this.title,
    required this.reference,
    required this.excerpt,
    required this.url,
    required this.displayed,
    required this.displayRole,
  });
  factory SourceDto.fromJson(Map<String, dynamic> json) => _$SourceDtoFromJson(json);
  final String sourceId;
  final String kind;
  final String provider;
  final String title;
  final String reference;
  final String excerpt;
  @JsonKey(required: true)
  final String? url;
  final bool displayed;
  @JsonKey(required: true)
  final String? displayRole;
}

@JsonSerializable()
final class TermCardDto {
  const TermCardDto({
    required this.termId,
    required this.text,
    required this.arabic,
    required this.transliteration,
    required this.state,
    required this.level,
    required this.definition,
    required this.example,
    required this.pronunciationAudioUrl,
    required this.sourceId,
    required this.lessonId,
    required this.lessonTitle,
  });
  factory TermCardDto.fromJson(Map<String, dynamic> json) => _$TermCardDtoFromJson(json);
  final String termId;
  final String text;
  @JsonKey(required: true)
  final String? arabic;
  final String transliteration;
  final String state;
  final String level;
  final List<SpanDto> definition;
  final List<SpanDto> example;
  @JsonKey(required: true)
  final String? pronunciationAudioUrl;
  @JsonKey(required: true)
  final String? sourceId;
  @JsonKey(required: true)
  final String? lessonId;
  @JsonKey(required: true)
  final String? lessonTitle;
}

@JsonSerializable()
final class WordTimingDto {
  const WordTimingDto({required this.ayah, required this.position, required this.text, required this.startMs, required this.endMs});
  factory WordTimingDto.fromJson(Map<String, dynamic> json) => _$WordTimingDtoFromJson(json);
  final int ayah;
  final int position;
  final String text;
  final int startMs;
  final int endMs;
}

@JsonSerializable()
final class AudioDto {
  const AudioDto({required this.reciter, required this.url, required this.words});
  factory AudioDto.fromJson(Map<String, dynamic> json) => _$AudioDtoFromJson(json);
  final String reciter;
  final String url;
  @JsonKey(required: true)
  final List<WordTimingDto>? words;
}

@JsonSerializable()
final class SegmentDto {
  const SegmentDto({required this.wordStart, required this.wordEnd});
  factory SegmentDto.fromJson(Map<String, dynamic> json) => _$SegmentDtoFromJson(json);
  final int wordStart;
  final int wordEnd;
}

@JsonSerializable()
final class QuranBodyDto {
  const QuranBodyDto({
    required this.surah,
    required this.surahName,
    required this.ayahStart,
    required this.ayahEnd,
    required this.segment,
    required this.textUthmani,
    required this.translation,
    required this.translationSource,
    required this.audio,
  });
  factory QuranBodyDto.fromJson(Map<String, dynamic> json) => _$QuranBodyDtoFromJson(json);
  final int surah;
  final String surahName;
  final int ayahStart;
  final int ayahEnd;
  @JsonKey(required: true)
  final SegmentDto? segment;
  final String textUthmani;
  @JsonKey(required: true)
  final String? translation;
  @JsonKey(required: true)
  final String? translationSource;
  @JsonKey(required: true)
  final AudioDto? audio;
}

@JsonSerializable()
final class HadithBodyDto {
  const HadithBodyDto({
    required this.textAr,
    required this.translation,
    required this.narrator,
    required this.collections,
    required this.gradeLabel,
    required this.gradeCategory,
    required this.gradeSource,
    required this.excerpt,
  });
  factory HadithBodyDto.fromJson(Map<String, dynamic> json) => _$HadithBodyDtoFromJson(json);
  final String textAr;
  @JsonKey(required: true)
  final String? translation;
  final String narrator;
  final List<String> collections;
  final String gradeLabel;
  final String gradeCategory;
  final String gradeSource;
  final bool excerpt;
}

@JsonSerializable()
final class EvidenceDto {
  const EvidenceDto({required this.evidenceId, required this.kind, required this.quran, required this.hadith});
  factory EvidenceDto.fromJson(Map<String, dynamic> json) => _$EvidenceDtoFromJson(json);
  final String evidenceId;
  final String kind;
  @JsonKey(required: true)
  final QuranBodyDto? quran;
  @JsonKey(required: true)
  final HadithBodyDto? hadith;
}

@JsonSerializable()
final class ImageDto {
  const ImageDto({required this.url, required this.mimeType, required this.width, required this.height});
  factory ImageDto.fromJson(Map<String, dynamic> json) => _$ImageDtoFromJson(json);
  final String url;
  final String mimeType;
  final int width;
  final int height;
}

@JsonSerializable()
final class OverlayDto {
  const OverlayDto({required this.type, required this.assetUrl, required this.label, required this.anchor, required this.sizePct});
  factory OverlayDto.fromJson(Map<String, dynamic> json) => _$OverlayDtoFromJson(json);
  final String type;
  final String assetUrl;
  final String label;
  final String anchor;
  final double sizePct;
}

@JsonSerializable()
final class ViewBoxDto {
  const ViewBoxDto({required this.width, required this.height});
  factory ViewBoxDto.fromJson(Map<String, dynamic> json) => _$ViewBoxDtoFromJson(json);
  final int width;
  final int height;
}

@JsonSerializable()
final class SceneRefDto {
  const SceneRefDto({
    required this.sceneId,
    required this.version,
    required this.schemaVersion,
    required this.url,
    required this.mimeType,
    required this.sha256,
    required this.viewBox,
    required this.requiredCapabilities,
  });
  factory SceneRefDto.fromJson(Map<String, dynamic> json) => _$SceneRefDtoFromJson(json);
  final String sceneId;
  final int version;
  final String schemaVersion;
  final String url;
  final String mimeType;
  final String sha256;
  final ViewBoxDto viewBox;
  final List<String> requiredCapabilities;
}

@JsonSerializable()
final class VisualDto {
  const VisualDto({
    required this.kind,
    required this.key,
    required this.version,
    required this.params,
    required this.image,
    required this.scene,
    required this.fallbackImage,
    required this.fallbackParams,
    required this.alt,
    required this.overlays,
  });
  factory VisualDto.fromJson(Map<String, dynamic> json) => _$VisualDtoFromJson(json);
  final String kind;
  @JsonKey(required: true)
  final String? key;
  @JsonKey(required: true)
  final int? version;
  @JsonKey(required: true)
  final Map<String, dynamic>? params;
  @JsonKey(required: true)
  final ImageDto? image;
  @JsonKey(required: true)
  final SceneRefDto? scene;
  @JsonKey(required: true)
  final ImageDto? fallbackImage;
  @JsonKey(required: true)
  final Map<String, dynamic>? fallbackParams;
  final String alt;
  final List<OverlayDto> overlays;
}
