import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/lesson/data/dtos/session_dto.dart';
import 'package:qabas/shared/lesson/data/mappers/exercise_mappers.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';

extension SessionMapping on SessionDto {
  Session toEntity() => Session(
    sessionId: sessionId,
    kind: wireEnum(kind, SessionKind.values, SessionKind.unknown),
    mode: mode,
    status: wireEnum(status, LessonSessionStatus.values, LessonSessionStatus.unknown),
    feedbackMode: wireEnum(feedbackMode, FeedbackMode.values, FeedbackMode.unknown),
    unitId: unitId,
    lessonId: lessonId,
    lessonVersion: lessonVersion,
    title: title,
    subtitle: subtitle,
    lessonType: lessonType == null ? null : wireEnum(lessonType, LessonType.values, LessonType.unknown),
    reviewedBy: reviewedBy,
    objectives: objectives.map(contentSpans).toList(),
    counts: SessionCounts(interactions: counts.interactions, exercises: counts.exercises, scored: counts.scored),
    sourceCount: sourceCount,
    totalExercises: totalExercises,
    answeredExercises: answeredExercises,
    startedAt: DateTime.parse(startedAt),
    answers: answers
        .map(
          (a) => RecordedAnswer(
            exerciseId: a.exerciseId,
            isRetry: a.isRetry,
            result: a.result,
            recordedAt: DateTime.parse(a.recordedAt),
            evaluation: a.evaluation == null
                ? null
                : decodeAnswerResponse(
                        a.evaluation!,
                        items
                            .whereType<ExerciseBlockDto>()
                            .firstWhere((i) => i.exercise.exerciseId == a.exerciseId)
                            .exercise
                            .toEntity()
                            .type,
                        immediate: true,
                      )
                      as AnswerEvaluation,
          ),
        )
        .toList(),
    items: items.map((b) => b.toEntity()).toList(),
    completion: completion == null
        ? null
        : LessonCompletion(
            challenge: contentSpans(completion!.challenge),
            reviewTopics: completion!.reviewTopics
                .map((t) => ReviewTopic(topicId: t.topicId, title: t.title, conceptIds: t.conceptIds))
                .toList(),
            checkIn: contentSpans(completion!.checkIn),
          ),
    sources: sources.map((s) => s.toEntity()).toList(),
    terms: terms.map((k, v) => MapEntry(k, v.toEntity())),
  );
}

extension BlockMapping on BlockDto {
  SessionItem toEntity() => switch (this) {
    final HookDto b => HookItem(
      blockId: b.blockId,
      situation: contentSpans(b.situation),
      question: contentSpans(b.question),
      visual: b.visual.toEntity(),
      cta: b.cta,
    ),
    final PredictDto b => PredictItem(
      blockId: b.blockId,
      prompt: contentSpans(b.prompt),
      options: b.options.map((o) => PredictOption(optionId: o.optionId, spans: contentSpans(o.spans))).toList(),
      reveal: contentSpans(b.reveal),
      visual: b.visual?.toEntity(),
    ),
    final StoryDto b => _story(b),
    final TeachDto b => TeachItem(
      blockId: b.blockId,
      eyebrow: b.eyebrow,
      title: contentSpans(b.title),
      style: wireEnum(b.style, TeachStyle.values, TeachStyle.unknown),
      visual: b.visual?.toEntity(),
      evidence: b.evidence?.toEntity(),
      points: b.points
          .map(
            (p) => TeachPoint(
              pointId: p.pointId,
              sentence: p.sentence.toEntity(),
              visualParams: p.visualParams == null ? null : visualParams(p.visualParams!),
            ),
          )
          .toList(),
    ),
    final ParagraphDto b => ParagraphItem(blockId: b.blockId, sentences: b.sentences.map((s) => s.toEntity()).toList()),
    final EvidenceBlockDto b => EvidenceItem(
      blockId: b.blockId,
      evidence: b.evidence.toEntity(),
      caption: b.caption == null ? null : contentSpans(b.caption!),
    ),
    final VisualBlockDto b => VisualItem(
      blockId: b.blockId,
      visual: b.visual.toEntity(),
      caption: b.caption == null ? null : contentSpans(b.caption!),
    ),
    final CalloutDto b => CalloutItem(
      blockId: b.blockId,
      variant: wireEnum(b.variant, CalloutVariant.values, CalloutVariant.unknown),
      spans: contentSpans(b.spans),
    ),
    final ExerciseBlockDto b => ExerciseItem(
      blockId: b.blockId,
      exercise: b.exercise.toEntity(),
      exerciseId: b.exercise.exerciseId,
      exerciseType: b.exercise.type,
      prompt: contentSpans(b.exercise.prompt),
    ),
    final UnknownBlockDto b => UnknownItem(blockId: b.blockId),
  };
  StoryItem _story(StoryDto b) {
    if (b.beats.isEmpty) throw const FormatException('Story has no beats');
    if (b.origin == null && (b.provenance != null || b.beats.any((beat) => beat.quote != null))) {
      throw const FormatException('Scenario contains provenance');
    }
    return StoryItem(
      blockId: b.blockId,
      label: b.label,
      title: b.title,
      provenance: b.provenance == null
          ? null
          : StoryProvenance(
              sourceId: b.provenance!.sourceId,
              provider: sourceProvider(b.provenance!.provider),
              reference: b.provenance!.reference,
              gradeLabel: b.provenance!.gradeLabel,
            ),
      beats: b.beats
          .map(
            (beat) => StoryBeat(
              beatId: beat.beatId,
              beatIndex: beat.beatIndex,
              narration: beat.narration.map((s) => s.toEntity()).toList(),
              narrationAudioUrl: beat.narrationAudioUrl,
              quote: beat.quote?.toEntity(),
              quoteMeaning: beat.quoteMeaning == null ? null : contentSpans(beat.quoteMeaning!),
              visual: beat.visual.toEntity(),
            ),
          )
          .toList(),
      origin: b.origin == null ? null : StoryOrigin(title: b.origin!.title, sourceIds: b.origin!.sourceIds, showCard: b.origin!.showCard),
    );
  }
}
