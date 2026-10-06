// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TextSpanDto _$TextSpanDtoFromJson(Map<String, dynamic> json) => $checkedCreate('TextSpanDto', json, ($checkedConvert) {
  final val = TextSpanDto(text: $checkedConvert('text', (v) => v as String));
  return val;
});

StrongSpanDto _$StrongSpanDtoFromJson(Map<String, dynamic> json) => $checkedCreate('StrongSpanDto', json, ($checkedConvert) {
  final val = StrongSpanDto(text: $checkedConvert('text', (v) => v as String));
  return val;
});

TermSpanDto _$TermSpanDtoFromJson(Map<String, dynamic> json) => $checkedCreate('TermSpanDto', json, ($checkedConvert) {
  final val = TermSpanDto(text: $checkedConvert('text', (v) => v as String), termId: $checkedConvert('term_id', (v) => v as String));
  return val;
}, fieldKeyMap: const {'termId': 'term_id'});

CitationSpanDto _$CitationSpanDtoFromJson(Map<String, dynamic> json) => $checkedCreate('CitationSpanDto', json, ($checkedConvert) {
  final val = CitationSpanDto(ref: $checkedConvert('ref', (v) => (v as num).toInt()));
  return val;
});

SentenceDto _$SentenceDtoFromJson(Map<String, dynamic> json) => $checkedCreate('SentenceDto', json, ($checkedConvert) {
  final val = SentenceDto(
    sentenceId: $checkedConvert('sentence_id', (v) => v as String),
    spans: $checkedConvert('spans', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
    sourceIds: $checkedConvert('source_ids', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
  );
  return val;
}, fieldKeyMap: const {'sentenceId': 'sentence_id', 'sourceIds': 'source_ids'});

SourceDto _$SourceDtoFromJson(Map<String, dynamic> json) => $checkedCreate('SourceDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['url', 'display_role']);
  final val = SourceDto(
    sourceId: $checkedConvert('source_id', (v) => v as String),
    kind: $checkedConvert('kind', (v) => v as String),
    provider: $checkedConvert('provider', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    reference: $checkedConvert('reference', (v) => v as String),
    excerpt: $checkedConvert('excerpt', (v) => v as String),
    url: $checkedConvert('url', (v) => v as String?),
    displayed: $checkedConvert('displayed', (v) => v as bool),
    displayRole: $checkedConvert('display_role', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'sourceId': 'source_id', 'displayRole': 'display_role'});

TermCardDto _$TermCardDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'TermCardDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['arabic', 'pronunciation_audio_url', 'source_id', 'lesson_id', 'lesson_title']);
    final val = TermCardDto(
      termId: $checkedConvert('term_id', (v) => v as String),
      text: $checkedConvert('text', (v) => v as String),
      arabic: $checkedConvert('arabic', (v) => v as String?),
      transliteration: $checkedConvert('transliteration', (v) => v as String),
      state: $checkedConvert('state', (v) => v as String),
      level: $checkedConvert('level', (v) => v as String),
      definition: $checkedConvert(
        'definition',
        (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
      example: $checkedConvert('example', (v) => (v as List<dynamic>).map((e) => SpanDto.fromJson(e as Map<String, dynamic>)).toList()),
      pronunciationAudioUrl: $checkedConvert('pronunciation_audio_url', (v) => v as String?),
      sourceId: $checkedConvert('source_id', (v) => v as String?),
      lessonId: $checkedConvert('lesson_id', (v) => v as String?),
      lessonTitle: $checkedConvert('lesson_title', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'termId': 'term_id',
    'pronunciationAudioUrl': 'pronunciation_audio_url',
    'sourceId': 'source_id',
    'lessonId': 'lesson_id',
    'lessonTitle': 'lesson_title',
  },
);

WordTimingDto _$WordTimingDtoFromJson(Map<String, dynamic> json) => $checkedCreate('WordTimingDto', json, ($checkedConvert) {
  final val = WordTimingDto(
    ayah: $checkedConvert('ayah', (v) => (v as num).toInt()),
    position: $checkedConvert('position', (v) => (v as num).toInt()),
    text: $checkedConvert('text', (v) => v as String),
    startMs: $checkedConvert('start_ms', (v) => (v as num).toInt()),
    endMs: $checkedConvert('end_ms', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'startMs': 'start_ms', 'endMs': 'end_ms'});

AudioDto _$AudioDtoFromJson(Map<String, dynamic> json) => $checkedCreate('AudioDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['words']);
  final val = AudioDto(
    reciter: $checkedConvert('reciter', (v) => v as String),
    url: $checkedConvert('url', (v) => v as String),
    words: $checkedConvert('words', (v) => (v as List<dynamic>?)?.map((e) => WordTimingDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
});

SegmentDto _$SegmentDtoFromJson(Map<String, dynamic> json) => $checkedCreate('SegmentDto', json, ($checkedConvert) {
  final val = SegmentDto(
    wordStart: $checkedConvert('word_start', (v) => (v as num).toInt()),
    wordEnd: $checkedConvert('word_end', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'wordStart': 'word_start', 'wordEnd': 'word_end'});

QuranBodyDto _$QuranBodyDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'QuranBodyDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['segment', 'translation', 'translation_source', 'audio']);
    final val = QuranBodyDto(
      surah: $checkedConvert('surah', (v) => (v as num).toInt()),
      surahName: $checkedConvert('surah_name', (v) => v as String),
      ayahStart: $checkedConvert('ayah_start', (v) => (v as num).toInt()),
      ayahEnd: $checkedConvert('ayah_end', (v) => (v as num).toInt()),
      segment: $checkedConvert('segment', (v) => v == null ? null : SegmentDto.fromJson(v as Map<String, dynamic>)),
      textUthmani: $checkedConvert('text_uthmani', (v) => v as String),
      translation: $checkedConvert('translation', (v) => v as String?),
      translationSource: $checkedConvert('translation_source', (v) => v as String?),
      audio: $checkedConvert('audio', (v) => v == null ? null : AudioDto.fromJson(v as Map<String, dynamic>)),
    );
    return val;
  },
  fieldKeyMap: const {
    'surahName': 'surah_name',
    'ayahStart': 'ayah_start',
    'ayahEnd': 'ayah_end',
    'textUthmani': 'text_uthmani',
    'translationSource': 'translation_source',
  },
);

HadithBodyDto _$HadithBodyDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'HadithBodyDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['translation']);
    final val = HadithBodyDto(
      textAr: $checkedConvert('text_ar', (v) => v as String),
      translation: $checkedConvert('translation', (v) => v as String?),
      narrator: $checkedConvert('narrator', (v) => v as String),
      collections: $checkedConvert('collections', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
      gradeLabel: $checkedConvert('grade_label', (v) => v as String),
      gradeCategory: $checkedConvert('grade_category', (v) => v as String),
      gradeSource: $checkedConvert('grade_source', (v) => v as String),
      excerpt: $checkedConvert('excerpt', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {'textAr': 'text_ar', 'gradeLabel': 'grade_label', 'gradeCategory': 'grade_category', 'gradeSource': 'grade_source'},
);

EvidenceDto _$EvidenceDtoFromJson(Map<String, dynamic> json) => $checkedCreate('EvidenceDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['quran', 'hadith']);
  final val = EvidenceDto(
    evidenceId: $checkedConvert('evidence_id', (v) => v as String),
    kind: $checkedConvert('kind', (v) => v as String),
    quran: $checkedConvert('quran', (v) => v == null ? null : QuranBodyDto.fromJson(v as Map<String, dynamic>)),
    hadith: $checkedConvert('hadith', (v) => v == null ? null : HadithBodyDto.fromJson(v as Map<String, dynamic>)),
  );
  return val;
}, fieldKeyMap: const {'evidenceId': 'evidence_id'});

ImageDto _$ImageDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ImageDto', json, ($checkedConvert) {
  final val = ImageDto(
    url: $checkedConvert('url', (v) => v as String),
    mimeType: $checkedConvert('mime_type', (v) => v as String),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'mimeType': 'mime_type'});

OverlayDto _$OverlayDtoFromJson(Map<String, dynamic> json) => $checkedCreate('OverlayDto', json, ($checkedConvert) {
  final val = OverlayDto(
    type: $checkedConvert('type', (v) => v as String),
    assetUrl: $checkedConvert('asset_url', (v) => v as String),
    label: $checkedConvert('label', (v) => v as String),
    anchor: $checkedConvert('anchor', (v) => v as String),
    sizePct: $checkedConvert('size_pct', (v) => (v as num).toDouble()),
  );
  return val;
}, fieldKeyMap: const {'assetUrl': 'asset_url', 'sizePct': 'size_pct'});

ViewBoxDto _$ViewBoxDtoFromJson(Map<String, dynamic> json) => $checkedCreate('ViewBoxDto', json, ($checkedConvert) {
  final val = ViewBoxDto(
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
  );
  return val;
});

SceneRefDto _$SceneRefDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'SceneRefDto',
  json,
  ($checkedConvert) {
    final val = SceneRefDto(
      sceneId: $checkedConvert('scene_id', (v) => v as String),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
      schemaVersion: $checkedConvert('schema_version', (v) => v as String),
      url: $checkedConvert('url', (v) => v as String),
      mimeType: $checkedConvert('mime_type', (v) => v as String),
      sha256: $checkedConvert('sha256', (v) => v as String),
      viewBox: $checkedConvert('view_box', (v) => ViewBoxDto.fromJson(v as Map<String, dynamic>)),
      requiredCapabilities: $checkedConvert('required_capabilities', (v) => (v as List<dynamic>).map((e) => e as String).toList()),
    );
    return val;
  },
  fieldKeyMap: const {
    'sceneId': 'scene_id',
    'schemaVersion': 'schema_version',
    'mimeType': 'mime_type',
    'viewBox': 'view_box',
    'requiredCapabilities': 'required_capabilities',
  },
);

VisualDto _$VisualDtoFromJson(Map<String, dynamic> json) => $checkedCreate('VisualDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['key', 'version', 'params', 'image', 'scene', 'fallback_image', 'fallback_params']);
  final val = VisualDto(
    kind: $checkedConvert('kind', (v) => v as String),
    key: $checkedConvert('key', (v) => v as String?),
    version: $checkedConvert('version', (v) => (v as num?)?.toInt()),
    params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
    image: $checkedConvert('image', (v) => v == null ? null : ImageDto.fromJson(v as Map<String, dynamic>)),
    scene: $checkedConvert('scene', (v) => v == null ? null : SceneRefDto.fromJson(v as Map<String, dynamic>)),
    fallbackImage: $checkedConvert('fallback_image', (v) => v == null ? null : ImageDto.fromJson(v as Map<String, dynamic>)),
    fallbackParams: $checkedConvert('fallback_params', (v) => v as Map<String, dynamic>?),
    alt: $checkedConvert('alt', (v) => v as String),
    overlays: $checkedConvert('overlays', (v) => (v as List<dynamic>).map((e) => OverlayDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'fallbackImage': 'fallback_image', 'fallbackParams': 'fallback_params'});
