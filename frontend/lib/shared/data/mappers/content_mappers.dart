import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/domain/entities/content.dart';

T wireEnum<T extends Enum>(String? value, List<T> values, T unknown) {
  final normalized = value?.replaceAll('_', '').toLowerCase();
  return values.where((e) => e.name.toLowerCase() == normalized).firstOrNull ?? unknown;
}

SourceProvider sourceProvider(String value) => wireEnum(value, SourceProvider.values, SourceProvider.unknown);
List<ContentSpan> contentSpans(List<SpanDto> spans) => List.unmodifiable(
  spans.map(
    (s) => switch (s) {
      TextSpanDto() => TextContentSpan(text: s.text),
      StrongSpanDto() => StrongContentSpan(text: s.text),
      TermSpanDto() => TermContentSpan(text: s.text, termId: s.termId),
      CitationSpanDto() => CitationContentSpan(ref: s.ref),
      UnknownSpanDto() => UnknownContentSpan(text: s.text),
    },
  ),
);
// Visual states are scalar values in this revision; freeze nested additive values too.
Object? immutableValue(Object? value) => switch (value) {
  Map<String, dynamic>() => Map<String, Object?>.unmodifiable(value.map((k, v) => MapEntry(k, immutableValue(v)))),
  List() => List<Object?>.unmodifiable(value.map(immutableValue)),
  _ => value,
};
Map<String, Object?> visualParams(Map<String, dynamic> value) => Map.unmodifiable(value.map((k, v) => MapEntry(k, immutableValue(v))));

extension SentenceMapping on SentenceDto {
  Sentence toEntity() => Sentence(sentenceId: sentenceId, spans: contentSpans(spans), sourceIds: sourceIds);
}

extension SourceMapping on SourceDto {
  Source toEntity() => Source(
    sourceId: sourceId,
    kind: wireEnum(kind, SourceKind.values, SourceKind.unknown),
    provider: sourceProvider(provider),
    title: title,
    reference: reference,
    excerpt: excerpt,
    url: url,
    displayed: displayed,
    displayRole: displayRole == null ? null : wireEnum(displayRole, DisplayRole.values, DisplayRole.unknown),
  );
}

extension TermMapping on TermCardDto {
  TermCard toEntity() => TermCard(
    termId: termId,
    text: text,
    arabic: arabic,
    transliteration: transliteration,
    state: state == 'new' ? TermState.newTerm : wireEnum(state, TermState.values, TermState.unknown),
    level: wireEnum(level, TermLevel.values, TermLevel.unknown),
    definition: contentSpans(definition),
    example: contentSpans(example),
    pronunciationAudioUrl: pronunciationAudioUrl,
    sourceId: sourceId,
    lessonId: lessonId,
    lessonTitle: lessonTitle,
  );
}

extension EvidenceMapping on EvidenceDto {
  Evidence toEntity() => switch (kind) {
    'quran' => _quran(quran ?? (throw const FormatException('Missing Quran body'))),
    'hadith' => _hadith(hadith ?? (throw const FormatException('Missing hadith body'))),
    _ => UnknownEvidence(evidenceId: evidenceId),
  };
  QuranEvidence _quran(QuranBodyDto q) => QuranEvidence(
    evidenceId: evidenceId,
    surah: q.surah,
    surahName: q.surahName,
    ayahStart: q.ayahStart,
    ayahEnd: q.ayahEnd,
    segment: q.segment == null ? null : VerseSegment(wordStart: q.segment!.wordStart, wordEnd: q.segment!.wordEnd),
    textUthmani: q.textUthmani,
    translation: q.translation,
    translationSource: q.translationSource,
    audio: q.audio == null
        ? null
        : RecitationAudio(
            reciter: q.audio!.reciter,
            url: q.audio!.url,
            words: q.audio!.words
                ?.map(
                  (w) => WordTiming(
                    ayah: w.ayah,
                    position: w.position,
                    text: w.text,
                    start: Duration(milliseconds: w.startMs), // rules:allow — converts wire milliseconds, no authored timing
                    end: Duration(milliseconds: w.endMs), // rules:allow — converts wire milliseconds, no authored timing
                  ),
                )
                .toList(),
          ),
  );
  HadithEvidence _hadith(HadithBodyDto h) => HadithEvidence(
    evidenceId: evidenceId,
    textAr: h.textAr,
    translation: h.translation,
    narrator: h.narrator,
    collections: h.collections,
    gradeLabel: h.gradeLabel,
    gradeCategory: wireEnum(h.gradeCategory, HadithGrade.values, HadithGrade.unknown),
    gradeSource: h.gradeSource,
    excerpt: h.excerpt,
  );
}

extension ImageMapping on ImageDto {
  NetworkImageRef toEntity() {
    if (width <= 0 || height <= 0) throw const FormatException('Invalid image geometry');
    return NetworkImageRef(url: url, mimeType: mimeType, width: width, height: height);
  }
}

extension OverlayMapping on OverlayDto {
  VisualOverlay toEntity() => VisualOverlay(
    type: type,
    assetUrl: assetUrl,
    label: label,
    anchor: wireEnum(anchor, OverlayAnchor.values, OverlayAnchor.unknown),
    sizePct: sizePct,
  );
}

extension VisualMapping on VisualDto {
  Visual toEntity() {
    final decorations = overlays.map((o) => o.toEntity()).toList();
    return switch (kind) {
      'builtin' => BuiltinVisual(
        key: key ?? (throw const FormatException('Missing builtin key')),
        version: version ?? (throw const FormatException('Missing builtin version')),
        params: visualParams(params ?? {}),
        fallbackImage: fallbackImage?.toEntity(),
        alt: alt,
        overlays: decorations,
      ),
      'image' => ImageVisual(image: (image ?? (throw const FormatException('Missing image'))).toEntity(), alt: alt, overlays: decorations),
      'scene' => SceneVisual(
        scene: _scene(scene ?? (throw const FormatException('Missing scene'))),
        params: visualParams(params ?? {}),
        fallbackImage: (fallbackImage ?? (throw const FormatException('Missing scene fallback'))).toEntity(),
        fallbackParams: visualParams(fallbackParams ?? {}),
        alt: alt,
        overlays: decorations,
      ),
      _ => UnknownVisual(alt: alt, overlays: decorations),
    };
  }

  SceneRef _scene(SceneRefDto s) => SceneRef(
    sceneId: s.sceneId,
    version: s.version,
    schemaVersion: s.schemaVersion,
    url: s.url,
    mimeType: s.mimeType,
    sha256: s.sha256,
    width: s.viewBox.width,
    height: s.viewBox.height,
    requiredCapabilities: s.requiredCapabilities,
  );
}
