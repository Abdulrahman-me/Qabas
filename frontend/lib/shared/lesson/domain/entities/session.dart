import 'package:equatable/equatable.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';

enum SessionKind { lesson, review, pretest, unitTest, unknown }

enum LessonSessionStatus { active, finished, abandoned, unknown }

enum FeedbackMode { immediate, none, end, unknown }

enum TeachStyle { standard, summary, unknown }

enum CalloutVariant { tip, note, unknown }

sealed class SessionItem extends Equatable {
  const SessionItem();
  String get blockId;
}

final class SessionCounts extends Equatable {
  const SessionCounts({required this.interactions, required this.exercises, required this.scored});
  final int interactions;
  final int exercises;
  final int scored;
  @override
  List<Object?> get props => [interactions, exercises, scored];
}

final class RecordedAnswer extends Equatable {
  const RecordedAnswer({required this.exerciseId, required this.isRetry, required this.result, required this.recordedAt, this.evaluation});
  final String exerciseId;
  final bool isRetry;
  final String result;
  final DateTime recordedAt;
  final AnswerEvaluation? evaluation;
  @override
  List<Object?> get props => [exerciseId, isRetry, result, recordedAt, evaluation];
}

final class LessonCompletion extends Equatable {
  LessonCompletion({required List<ContentSpan> challenge, required List<ReviewTopic> reviewTopics, required List<ContentSpan> checkIn})
    : challenge = List.unmodifiable(challenge),
      reviewTopics = List.unmodifiable(reviewTopics),
      checkIn = List.unmodifiable(checkIn);
  final List<ContentSpan> challenge;
  final List<ReviewTopic> reviewTopics;
  final List<ContentSpan> checkIn;
  @override
  List<Object?> get props => [challenge, reviewTopics, checkIn];
}

final class ReviewTopic extends Equatable {
  ReviewTopic({required this.topicId, required this.title, required List<String> conceptIds}) : conceptIds = List.unmodifiable(conceptIds);
  final String topicId;
  final String title;
  final List<String> conceptIds;
  @override
  List<Object?> get props => [topicId, title, conceptIds];
}

final class Session extends Equatable {
  Session({
    required this.sessionId,
    required this.kind,
    required this.mode,
    required this.status,
    required this.feedbackMode,
    required this.unitId,
    required this.lessonId,
    required this.lessonVersion,
    required this.title,
    required this.subtitle,
    required this.lessonType,
    required this.reviewedBy,
    required List<List<ContentSpan>> objectives,
    required this.counts,
    required this.sourceCount,
    required this.totalExercises,
    required this.answeredExercises,
    required this.startedAt,
    required List<RecordedAnswer> answers,
    required List<SessionItem> items,
    required this.completion,
    required List<Source> sources,
    required Map<String, TermCard> terms,
  }) : objectives = List.unmodifiable(objectives.map((spans) => List<ContentSpan>.unmodifiable(spans))),
       answers = List.unmodifiable(answers),
       items = List.unmodifiable(items),
       sources = List.unmodifiable(sources),
       terms = Map.unmodifiable(terms);
  final String sessionId;
  final SessionKind kind;
  final String? mode;
  final LessonSessionStatus status;
  final FeedbackMode feedbackMode;
  final String? unitId;
  final String? lessonId;
  final int? lessonVersion;
  final String title;
  final String? subtitle;
  final LessonType? lessonType;
  final String? reviewedBy;
  final List<List<ContentSpan>> objectives;
  final SessionCounts counts;
  final int sourceCount;
  final int totalExercises;
  final int answeredExercises;
  final DateTime startedAt;
  final List<RecordedAnswer> answers;
  final List<SessionItem> items;
  final LessonCompletion? completion;
  final List<Source> sources;
  final Map<String, TermCard> terms;
  @override
  List<Object?> get props => [
    sessionId,
    kind,
    mode,
    status,
    feedbackMode,
    unitId,
    lessonId,
    lessonVersion,
    title,
    subtitle,
    lessonType,
    reviewedBy,
    objectives,
    counts,
    sourceCount,
    totalExercises,
    answeredExercises,
    startedAt,
    answers,
    items,
    completion,
    sources,
    terms,
  ];
}

final class HookItem extends SessionItem {
  HookItem({
    required this.blockId,
    required List<ContentSpan> situation,
    required List<ContentSpan> question,
    required this.visual,
    required this.cta,
  }) : situation = List.unmodifiable(situation),
       question = List.unmodifiable(question);
  @override
  final String blockId;
  final List<ContentSpan> situation;
  final List<ContentSpan> question;
  final Visual visual;
  final String? cta;
  @override
  List<Object?> get props => [blockId, situation, question, visual, cta];
}

final class PredictOption extends Equatable {
  PredictOption({required this.optionId, required List<ContentSpan> spans}) : spans = List.unmodifiable(spans);
  final String optionId;
  final List<ContentSpan> spans;
  @override
  List<Object?> get props => [optionId, spans];
}

final class PredictItem extends SessionItem {
  PredictItem({
    required this.blockId,
    required List<ContentSpan> prompt,
    required List<PredictOption> options,
    required List<ContentSpan> reveal,
    required this.visual,
  }) : prompt = List.unmodifiable(prompt),
       options = List.unmodifiable(options),
       reveal = List.unmodifiable(reveal);
  @override
  final String blockId;
  final List<ContentSpan> prompt;
  final List<PredictOption> options;
  final List<ContentSpan> reveal;
  final Visual? visual;
  @override
  List<Object?> get props => [blockId, prompt, options, reveal, visual];
}

final class StoryProvenance extends Equatable {
  const StoryProvenance({required this.sourceId, required this.provider, required this.reference, required this.gradeLabel});
  final String sourceId;
  final SourceProvider provider;
  final String reference;
  final String? gradeLabel;
  @override
  List<Object?> get props => [sourceId, provider, reference, gradeLabel];
}

final class StoryOrigin extends Equatable {
  StoryOrigin({required this.title, required List<String> sourceIds, required this.showCard}) : sourceIds = List.unmodifiable(sourceIds);
  final String title;
  final List<String> sourceIds;
  final bool showCard;
  @override
  List<Object?> get props => [title, sourceIds, showCard];
}

final class StoryBeat extends Equatable {
  StoryBeat({
    required this.beatId,
    required this.beatIndex,
    required List<Sentence> narration,
    required this.narrationAudioUrl,
    required this.quote,
    required List<ContentSpan>? quoteMeaning,
    required this.visual,
  }) : narration = List.unmodifiable(narration),
       quoteMeaning = quoteMeaning == null ? null : List.unmodifiable(quoteMeaning);
  final String beatId;
  final int beatIndex;
  final List<Sentence> narration;
  final String? narrationAudioUrl;
  final Evidence? quote;
  final List<ContentSpan>? quoteMeaning;
  final Visual visual;
  @override
  List<Object?> get props => [beatId, beatIndex, narration, narrationAudioUrl, quote, quoteMeaning, visual];
}

final class StoryItem extends SessionItem {
  StoryItem({
    required this.blockId,
    required this.label,
    required this.title,
    required this.provenance,
    required List<StoryBeat> beats,
    required this.origin,
  }) : beats = List.unmodifiable(beats);
  @override
  final String blockId;
  final String label;
  final String? title;
  final StoryProvenance? provenance;
  final List<StoryBeat> beats;
  final StoryOrigin? origin;
  @override
  List<Object?> get props => [blockId, label, title, provenance, beats, origin];
}

final class TeachPoint extends Equatable {
  TeachPoint({required this.pointId, required this.sentence, required Map<String, Object?>? visualParams})
    : visualParams = visualParams == null ? null : Map.unmodifiable(visualParams);
  final String pointId;
  final Sentence sentence;
  final Map<String, Object?>? visualParams;
  @override
  List<Object?> get props => [pointId, sentence, visualParams];
}

final class TeachItem extends SessionItem {
  TeachItem({
    required this.blockId,
    required this.eyebrow,
    required List<ContentSpan> title,
    required this.style,
    required this.visual,
    required this.evidence,
    required List<TeachPoint> points,
  }) : title = List.unmodifiable(title),
       points = List.unmodifiable(points);
  @override
  final String blockId;
  final String? eyebrow;
  final List<ContentSpan> title;
  final TeachStyle style;
  final Visual? visual;
  final Evidence? evidence;
  final List<TeachPoint> points;
  @override
  List<Object?> get props => [blockId, eyebrow, title, style, visual, evidence, points];
}

final class ParagraphItem extends SessionItem {
  ParagraphItem({required this.blockId, required List<Sentence> sentences}) : sentences = List.unmodifiable(sentences);
  @override
  final String blockId;
  final List<Sentence> sentences;
  @override
  List<Object?> get props => [blockId, sentences];
}

final class EvidenceItem extends SessionItem {
  EvidenceItem({required this.blockId, required this.evidence, required List<ContentSpan>? caption})
    : caption = caption == null ? null : List.unmodifiable(caption);
  @override
  final String blockId;
  final Evidence evidence;
  final List<ContentSpan>? caption;
  @override
  List<Object?> get props => [blockId, evidence, caption];
}

final class VisualItem extends SessionItem {
  VisualItem({required this.blockId, required this.visual, required List<ContentSpan>? caption})
    : caption = caption == null ? null : List.unmodifiable(caption);
  @override
  final String blockId;
  final Visual visual;
  final List<ContentSpan>? caption;
  @override
  List<Object?> get props => [blockId, visual, caption];
}

final class CalloutItem extends SessionItem {
  CalloutItem({required this.blockId, required this.variant, required List<ContentSpan> spans}) : spans = List.unmodifiable(spans);
  @override
  final String blockId;
  final CalloutVariant variant;
  final List<ContentSpan> spans;
  @override
  List<Object?> get props => [blockId, variant, spans];
}

final class ExerciseItem extends SessionItem {
  ExerciseItem({
    required this.blockId,
    required this.exerciseId,
    required this.exerciseType,
    required List<ContentSpan> prompt,
    this.exercise,
  }) : prompt = List.unmodifiable(prompt);
  @override
  final String blockId;
  final Exercise? exercise;
  final String exerciseId;
  final String exerciseType;
  final List<ContentSpan> prompt;
  @override
  List<Object?> get props => [blockId, exerciseId, exerciseType, prompt, exercise];
}

final class UnknownItem extends SessionItem {
  const UnknownItem({required this.blockId});
  @override
  final String blockId;
  @override
  List<Object?> get props => [blockId];
}

final class LessonEntryInfo extends Equatable {
  const LessonEntryInfo({required this.unitIndex, required this.lessonIndex, required this.minutes, required this.xp});
  final int? unitIndex;
  final int? lessonIndex;
  final int? minutes;
  final int? xp;
  @override
  List<Object?> get props => [unitIndex, lessonIndex, minutes, xp];
}

final class SessionStart extends Equatable {
  const SessionStart({required this.session, required this.resumed, required this.info});
  final Session session;
  final bool resumed;
  final LessonEntryInfo info;
  @override
  List<Object?> get props => [session, resumed, info];
}

final class LessonReader extends Equatable {
  LessonReader({
    required this.lessonId,
    required this.title,
    required List<SessionItem> items,
    required List<Source> sources,
    required Map<String, TermCard> terms,
  }) : items = List.unmodifiable(items),
       sources = List.unmodifiable(sources),
       terms = Map.unmodifiable(terms);
  final String lessonId, title;
  final List<SessionItem> items;
  final List<Source> sources;
  final Map<String, TermCard> terms;
  @override
  List<Object?> get props => [lessonId, title, items, sources, terms];
}
