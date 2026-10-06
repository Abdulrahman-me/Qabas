import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';

Map<String, Sentence> reviewerSentences(ReviewPreview preview) => {
  for (final block in preview.items)
    for (final sentence in switch (block) {
      TeachItem() => block.points.map((p) => p.sentence),
      ParagraphItem() => block.sentences,
      StoryItem() => block.beats.expand((b) => b.narration),
      _ => const <Sentence>[],
    })
      sentence.sentenceId: sentence,
};
Map<String, TermCard> reviewerTerms(ReviewDraft draft, String language) => {
  for (final t in draft.glossary)
    t.termId: TermCard(
      termId: t.termId,
      text: language == 'ar' ? t.text.ar : t.text.en,
      arabic: t.arabic,
      transliteration: t.transliteration,
      state: TermState.newTerm,
      level: TermLevel.basic,
      definition: language == 'ar' ? t.definition.basic.ar : t.definition.basic.en,
      example: language == 'ar' ? t.example.ar : t.example.en,
      pronunciationAudioUrl: t.pronunciationAudioUrl,
      sourceId: t.sourceId,
      lessonId: t.lessonId,
      lessonTitle: null,
    ),
};
List<Source> reviewerSources(ReviewDraft draft) => {
  for (final c in draft.claims)
    for (final e in c.evidence) e.source.sourceId: e.source,
}.values.toList();
