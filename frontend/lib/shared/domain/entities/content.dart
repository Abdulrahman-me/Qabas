import 'package:equatable/equatable.dart';

enum TermState { newTerm, learning, mastered, unknown }

enum TermLevel { basic, intermediate, unknown }

enum SourceKind { quran, hadith, tafsir, article, book, fatwa, unknown }

enum SourceProvider { tafsirCenter, quranCom, hadeethenc, quranenc, islamhouse, dorar, unknown }

enum DisplayRole { content, activity, unknown }

enum OverlayAnchor { topStart, topEnd, center, bottomStart, bottomEnd, unknown }

enum HadithGrade { authentic, acceptable, weak, fabricated, other, unknown }

sealed class ContentSpan extends Equatable {
  const ContentSpan();
}

sealed class Evidence extends Equatable {
  const Evidence();
  String get evidenceId;
}

sealed class Visual extends Equatable {
  const Visual();
  String get alt;
  List<VisualOverlay> get overlays;
}

final class TextContentSpan extends ContentSpan {
  const TextContentSpan({required this.text});
  final String text;
  @override
  List<Object?> get props => [text];
}

final class StrongContentSpan extends ContentSpan {
  const StrongContentSpan({required this.text});
  final String text;
  @override
  List<Object?> get props => [text];
}

final class TermContentSpan extends ContentSpan {
  const TermContentSpan({required this.text, required this.termId});
  final String text;
  final String termId;
  @override
  List<Object?> get props => [text, termId];
}

final class CitationContentSpan extends ContentSpan {
  const CitationContentSpan({required this.ref});
  final int ref;
  @override
  List<Object?> get props => [ref];
}

final class UnknownContentSpan extends ContentSpan {
  const UnknownContentSpan({required this.text});
  final String text;
  @override
  List<Object?> get props => [text];
}

final class Sentence extends Equatable {
  Sentence({required this.sentenceId, required List<ContentSpan> spans, required List<String> sourceIds})
    : spans = List.unmodifiable(spans),
      sourceIds = List.unmodifiable(sourceIds);
  final String sentenceId;
  final List<ContentSpan> spans;
  final List<String> sourceIds;
  @override
  List<Object?> get props => [sentenceId, spans, sourceIds];
}

final class Source extends Equatable {
  const Source({
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
  final String sourceId;
  final SourceKind kind;
  final SourceProvider provider;
  final String title;
  final String reference;
  final String excerpt;
  final String? url;
  final bool displayed;
  final DisplayRole? displayRole;
  @override
  List<Object?> get props => [sourceId, kind, provider, title, reference, excerpt, url, displayed, displayRole];
}

final class TermCard extends Equatable {
  TermCard({
    required this.termId,
    required this.text,
    required this.arabic,
    required this.transliteration,
    required this.state,
    required this.level,
    required List<ContentSpan> definition,
    required List<ContentSpan> example,
    required this.pronunciationAudioUrl,
    required this.sourceId,
    required this.lessonId,
    required this.lessonTitle,
  }) : definition = List.unmodifiable(definition),
       example = List.unmodifiable(example);
  final String termId;
  final String text;
  final String? arabic;
  final String transliteration;
  final TermState state;
  final TermLevel level;
  final List<ContentSpan> definition;
  final List<ContentSpan> example;
  final String? pronunciationAudioUrl;
  final String? sourceId;
  final String? lessonId;
  final String? lessonTitle;
  @override
  List<Object?> get props => [
    termId,
    text,
    arabic,
    transliteration,
    state,
    level,
    definition,
    example,
    pronunciationAudioUrl,
    sourceId,
    lessonId,
    lessonTitle,
  ];
}

final class WordTiming extends Equatable {
  const WordTiming({required this.ayah, required this.position, required this.text, required this.start, required this.end});
  final int ayah;
  final int position;
  final String text;
  final Duration start;
  final Duration end;
  @override
  List<Object?> get props => [ayah, position, text, start, end];
}

final class RecitationAudio extends Equatable {
  RecitationAudio({required this.reciter, required this.url, required List<WordTiming>? words})
    : words = words == null ? null : List.unmodifiable(words);
  final String reciter;
  final String url;
  final List<WordTiming>? words;
  @override
  List<Object?> get props => [reciter, url, words];
}

final class VerseSegment extends Equatable {
  const VerseSegment({required this.wordStart, required this.wordEnd});
  final int wordStart;
  final int wordEnd;
  @override
  List<Object?> get props => [wordStart, wordEnd];
}

final class QuranEvidence extends Evidence {
  const QuranEvidence({
    required this.evidenceId,
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
  @override
  final String evidenceId;
  final int surah;
  final String surahName;
  final int ayahStart;
  final int ayahEnd;
  final VerseSegment? segment;
  final String textUthmani;
  final String? translation;
  final String? translationSource;
  final RecitationAudio? audio;
  @override
  List<Object?> get props => [
    evidenceId,
    surah,
    surahName,
    ayahStart,
    ayahEnd,
    segment,
    textUthmani,
    translation,
    translationSource,
    audio,
  ];
}

final class HadithEvidence extends Evidence {
  HadithEvidence({
    required this.evidenceId,
    required this.textAr,
    required this.translation,
    required this.narrator,
    required List<String> collections,
    required this.gradeLabel,
    required this.gradeCategory,
    required this.gradeSource,
    required this.excerpt,
  }) : collections = List.unmodifiable(collections);
  @override
  final String evidenceId;
  final String textAr;
  final String? translation;
  final String narrator;
  final List<String> collections;
  final String gradeLabel;
  final HadithGrade gradeCategory;
  final String gradeSource;
  final bool excerpt;
  @override
  List<Object?> get props => [evidenceId, textAr, translation, narrator, collections, gradeLabel, gradeCategory, gradeSource, excerpt];
}

final class UnknownEvidence extends Evidence {
  const UnknownEvidence({required this.evidenceId});
  @override
  final String evidenceId;
  @override
  List<Object?> get props => [evidenceId];
}

final class NetworkImageRef extends Equatable {
  const NetworkImageRef({required this.url, required this.mimeType, required this.width, required this.height});
  final String url;
  final String mimeType;
  final int width;
  final int height;
  @override
  List<Object?> get props => [url, mimeType, width, height];
}

final class VisualOverlay extends Equatable {
  const VisualOverlay({required this.type, required this.assetUrl, required this.label, required this.anchor, required this.sizePct});
  final String type;
  final String assetUrl;
  final String label;
  final OverlayAnchor anchor;
  final double sizePct;
  @override
  List<Object?> get props => [type, assetUrl, label, anchor, sizePct];
}

final class SceneRef extends Equatable {
  SceneRef({
    required this.sceneId,
    required this.version,
    required this.schemaVersion,
    required this.url,
    required this.mimeType,
    required this.sha256,
    required this.width,
    required this.height,
    required List<String> requiredCapabilities,
  }) : requiredCapabilities = List.unmodifiable(requiredCapabilities);
  final String sceneId;
  final int version;
  final String schemaVersion;
  final String url;
  final String mimeType;
  final String sha256;
  final int width;
  final int height;
  final List<String> requiredCapabilities;
  @override
  List<Object?> get props => [sceneId, version, schemaVersion, url, mimeType, sha256, width, height, requiredCapabilities];
}

final class BuiltinVisual extends Visual {
  BuiltinVisual({
    required this.key,
    required this.version,
    required Map<String, Object?> params,
    required this.fallbackImage,
    required this.alt,
    required List<VisualOverlay> overlays,
  }) : params = Map.unmodifiable(params),
       overlays = List.unmodifiable(overlays);
  final String key;
  final int version;
  final Map<String, Object?> params;
  final NetworkImageRef? fallbackImage;
  @override
  final String alt;
  @override
  final List<VisualOverlay> overlays;
  @override
  List<Object?> get props => [key, version, params, fallbackImage, alt, overlays];
}

final class ImageVisual extends Visual {
  ImageVisual({required this.image, required this.alt, required List<VisualOverlay> overlays}) : overlays = List.unmodifiable(overlays);
  final NetworkImageRef image;
  @override
  final String alt;
  @override
  final List<VisualOverlay> overlays;
  @override
  List<Object?> get props => [image, alt, overlays];
}

final class SceneVisual extends Visual {
  SceneVisual({
    required this.scene,
    required Map<String, Object?> params,
    required this.fallbackImage,
    required Map<String, Object?> fallbackParams,
    required this.alt,
    required List<VisualOverlay> overlays,
  }) : params = Map.unmodifiable(params),
       fallbackParams = Map.unmodifiable(fallbackParams),
       overlays = List.unmodifiable(overlays);
  final SceneRef scene;
  final Map<String, Object?> params;
  final NetworkImageRef fallbackImage;
  final Map<String, Object?> fallbackParams;
  @override
  final String alt;
  @override
  final List<VisualOverlay> overlays;
  @override
  List<Object?> get props => [scene, params, fallbackImage, fallbackParams, alt, overlays];
}

final class UnknownVisual extends Visual {
  UnknownVisual({required this.alt, required List<VisualOverlay> overlays}) : overlays = List.unmodifiable(overlays);
  @override
  final String alt;
  @override
  final List<VisualOverlay> overlays;
  @override
  List<Object?> get props => [alt, overlays];
}
