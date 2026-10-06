import 'package:equatable/equatable.dart';
import 'package:qabas/shared/domain/entities/content.dart';

enum ExerciseType {
  multipleChoice,
  flashcard,
  fillBlank,
  whichEvidence,
  timelineOrder,
  verseMeaning,
  trueFalseReason,
  matchPairs,
  categorize,
  spotError,
  orderSteps,
  scenario,
  mapPlace,
  reciteVerse,
  unknown,
}

final class Scoring extends Equatable {
  const Scoring({required this.accuracy, required this.combo, required this.layer});
  final bool accuracy, combo;
  final String? layer;
  @override
  List<Object?> get props => [accuracy, combo, layer];
}

final class Exercise extends Equatable {
  Exercise({
    required this.id,
    required this.type,
    required List<String> conceptIds,
    required List<ContentSpan> prompt,
    required this.timeLimit,
    required this.scoring,
    required List<ContentSpan>? framing,
    required this.payload,
  }) : conceptIds = List.unmodifiable(conceptIds),
       prompt = List.unmodifiable(prompt),
       framing = framing == null ? null : List.unmodifiable(framing);
  final String id;
  final ExerciseType type;
  final List<String> conceptIds;
  final List<ContentSpan> prompt;
  final Duration? timeLimit;
  final Scoring scoring;
  final List<ContentSpan>? framing;
  final ExercisePayload payload;
  @override
  List<Object?> get props => [id, type, conceptIds, prompt, timeLimit, scoring, framing, payload];
}

sealed class ExercisePayload extends Equatable {
  const ExercisePayload();
}

final class ExerciseOption extends Equatable {
  ExerciseOption(this.id, List<ContentSpan> spans) : spans = List.unmodifiable(spans);
  final String id;
  final List<ContentSpan> spans;
  @override
  List<Object?> get props => [id, spans];
}

final class ChoicePayload extends ExercisePayload {
  ChoicePayload(List<ExerciseOption> options, {List<ContentSpan>? situation, this.verse})
    : options = List.unmodifiable(options),
      situation = situation == null ? null : List.unmodifiable(situation);
  final List<ExerciseOption> options;
  final List<ContentSpan>? situation;
  final Evidence? verse;
  @override
  List<Object?> get props => [options, situation, verse];
}

final class ReasonPayload extends ExercisePayload {
  ReasonPayload(List<ContentSpan> statement, List<ExerciseOption> reasons)
    : statement = List.unmodifiable(statement),
      reasons = List.unmodifiable(reasons);
  final List<ContentSpan> statement;
  final List<ExerciseOption> reasons;
  @override
  List<Object?> get props => [statement, reasons];
}

final class PairsPayload extends ExercisePayload {
  PairsPayload(List<ExerciseOption> left, List<ExerciseOption> right) : left = List.unmodifiable(left), right = List.unmodifiable(right);
  final List<ExerciseOption> left, right;
  @override
  List<Object?> get props => [left, right];
}

final class Category extends Equatable {
  const Category({required this.id, required this.label, required this.artKey, required this.phase, required this.capacity});
  final String id, label;
  final String? artKey, phase;
  final int? capacity;
  @override
  List<Object?> get props => [id, label, artKey, phase, capacity];
}

final class ExerciseToken extends Equatable {
  ExerciseToken(this.id, List<ContentSpan> spans, this.secondaryLabel) : spans = List.unmodifiable(spans);
  final String id;
  final List<ContentSpan> spans;
  final String? secondaryLabel;
  @override
  List<Object?> get props => [id, spans, secondaryLabel];
}

final class CategorizePayload extends ExercisePayload {
  CategorizePayload({required this.presentation, required List<Category> categories, required List<ExerciseToken> items})
    : categories = List.unmodifiable(categories),
      items = List.unmodifiable(items);
  final String presentation;
  final List<Category> categories;
  final List<ExerciseToken> items;
  @override
  List<Object?> get props => [presentation, categories, items];
}

final class SegmentPayload extends ExercisePayload {
  SegmentPayload(List<ExerciseOption> segments) : segments = List.unmodifiable(segments);
  final List<ExerciseOption> segments;
  @override
  List<Object?> get props => [segments];
}

final class OrderPayload extends ExercisePayload {
  OrderPayload(this.presentation, List<ExerciseToken> steps) : steps = List.unmodifiable(steps);
  final String presentation;
  final List<ExerciseToken> steps;
  @override
  List<Object?> get props => [presentation, steps];
}

final class MapPin extends Equatable {
  const MapPin({
    required this.id,
    required this.xPct,
    required this.yPct,
    required this.label,
    required this.radiusPct,
    required this.anchorId,
  });
  final String id;
  final double xPct, yPct;
  final String? label, anchorId;
  final double? radiusPct;
  @override
  List<Object?> get props => [id, xPct, yPct, label, radiusPct, anchorId];
}

final class MapInteraction extends Equatable {
  MapInteraction({
    required Map<String, Map<String, Object?>> bindings,
    required this.resetOnDeselect,
    required Map<String, Object?>? correct,
    required Map<String, Object?>? incorrect,
  }) : bindings = Map.unmodifiable(bindings.map((k, v) => MapEntry(k, Map<String, Object?>.unmodifiable(v)))),
       correct = correct == null ? null : Map.unmodifiable(correct),
       incorrect = incorrect == null ? null : Map.unmodifiable(incorrect);
  final Map<String, Map<String, Object?>> bindings;
  final bool resetOnDeselect;
  final Map<String, Object?>? correct, incorrect;
  @override
  List<Object?> get props => [bindings, resetOnDeselect, correct, incorrect];
}

final class MapPayload extends ExercisePayload {
  MapPayload({
    required this.presentation,
    required this.visual,
    required List<ContentSpan> question,
    required List<MapPin> pins,
    required this.interaction,
  }) : question = List.unmodifiable(question),
       pins = List.unmodifiable(pins);
  final String presentation;
  final Visual visual;
  final List<ContentSpan> question;
  final List<MapPin> pins;
  final MapInteraction? interaction;
  @override
  List<Object?> get props => [presentation, visual, question, pins, interaction];
}

final class RecitePayload extends ExercisePayload {
  RecitePayload({
    required this.surah,
    required this.ayah,
    required this.wordStart,
    required this.wordEnd,
    required this.textUthmani,
    required this.audio,
    required this.transliteration,
    required List<ContentSpan>? meaning,
    required this.sourceId,
    required this.maxDuration,
    required this.skippable,
  }) : meaning = meaning == null ? null : List.unmodifiable(meaning);
  final int surah, ayah;
  final int? wordStart, wordEnd;
  final String textUthmani, sourceId;
  final String? transliteration;
  final RecitationAudio audio;
  final List<ContentSpan>? meaning;
  final Duration maxDuration;
  final bool skippable;
  @override
  List<Object?> get props => [
    surah,
    ayah,
    wordStart,
    wordEnd,
    textUthmani,
    audio,
    transliteration,
    meaning,
    sourceId,
    maxDuration,
    skippable,
  ];
}

final class UnknownExercisePayload extends ExercisePayload {
  const UnknownExercisePayload();
  @override
  List<Object?> get props => [];
}

sealed class AnswerPayload extends Equatable {
  const AnswerPayload();
}

final class OptionAnswer extends AnswerPayload {
  const OptionAnswer(this.optionId);
  final String optionId;
  @override
  List<Object?> get props => [optionId];
}

final class ReasonAnswer extends AnswerPayload {
  const ReasonAnswer(this.value, this.reasonOptionId);
  final bool value;
  final String reasonOptionId;
  @override
  List<Object?> get props => [value, reasonOptionId];
}

final class PairsAnswer extends AnswerPayload {
  PairsAnswer(Map<String, String> pairs) : pairs = Map.unmodifiable(pairs);
  final Map<String, String> pairs;
  @override
  List<Object?> get props => [pairs];
}

final class AssignmentsAnswer extends AnswerPayload {
  AssignmentsAnswer(Map<String, String> assignments) : assignments = Map.unmodifiable(assignments);
  final Map<String, String> assignments;
  @override
  List<Object?> get props => [assignments];
}

final class SegmentAnswer extends AnswerPayload {
  const SegmentAnswer(this.segmentId);
  final String segmentId;
  @override
  List<Object?> get props => [segmentId];
}

final class OrderAnswer extends AnswerPayload {
  OrderAnswer(List<String> order) : order = List.unmodifiable(order);
  final List<String> order;
  @override
  List<Object?> get props => [order];
}

final class PinAnswer extends AnswerPayload {
  const PinAnswer(this.pinId);
  final String pinId;
  @override
  List<Object?> get props => [pinId];
}

final class RecitationAnswer extends AnswerPayload {
  const RecitationAnswer(this.checkId);
  final String checkId;
  @override
  List<Object?> get props => [checkId];
}

final class SkippedAnswer extends AnswerPayload {
  const SkippedAnswer();
  @override
  List<Object?> get props => [];
}

final class UnavailableAnswer extends AnswerPayload {
  const UnavailableAnswer();
  @override
  List<Object?> get props => [];
}

sealed class EvaluationDetails extends Equatable {
  const EvaluationDetails();
}

final class ReasonDetails extends EvaluationDetails {
  const ReasonDetails(this.valueCorrect, this.reasonCorrect);
  final bool valueCorrect, reasonCorrect;
  @override
  List<Object?> get props => [valueCorrect, reasonCorrect];
}

final class ItemDetails extends EvaluationDetails {
  ItemDetails(Map<String, bool> results) : results = Map.unmodifiable(results);
  final Map<String, bool> results;
  @override
  List<Object?> get props => [results];
}

final class OrderDetails extends EvaluationDetails {
  const OrderDetails(this.firstWrongIndex);
  final int? firstWrongIndex;
  @override
  List<Object?> get props => [firstWrongIndex];
}

final class ScenarioDetails extends EvaluationDetails {
  ScenarioDetails(Map<String, List<ContentSpan>> options)
    : options = Map.unmodifiable(options.map((k, v) => MapEntry(k, List<ContentSpan>.unmodifiable(v))));
  final Map<String, List<ContentSpan>> options;
  @override
  List<Object?> get props => [options];
}

final class PinDetails extends EvaluationDetails {
  PinDetails(Map<String, String> labels) : labels = Map.unmodifiable(labels);
  final Map<String, String> labels;
  @override
  List<Object?> get props => [labels];
}

final class Misconception extends Equatable {
  Misconception({required this.id, required this.title, required List<ContentSpan> card, required List<String> sourceIds})
    : card = List.unmodifiable(card),
      sourceIds = List.unmodifiable(sourceIds);
  final String id, title;
  final List<ContentSpan> card;
  final List<String> sourceIds;
  @override
  List<Object?> get props => [id, title, card, sourceIds];
}

final class MasteryChange extends Equatable {
  const MasteryChange(this.id, this.title, this.before, this.after);
  final String id, title;
  final double before, after;
  @override
  List<Object?> get props => [id, title, before, after];
}

final class TermChange extends Equatable {
  const TermChange(this.id, this.state);
  final String id;
  final TermState state;
  @override
  List<Object?> get props => [id, state];
}

sealed class AnswerResponse extends Equatable {
  const AnswerResponse();
  String get exerciseId;
}

final class AnswerRecorded extends AnswerResponse {
  const AnswerRecorded(this.exerciseId);
  @override
  final String exerciseId;
  @override
  List<Object?> get props => [exerciseId];
}

final class AnswerEvaluation extends AnswerResponse {
  AnswerEvaluation({
    required this.exerciseId,
    required this.correct,
    required this.correctAnswer,
    required this.details,
    required List<ContentSpan> explanation,
    required List<String> sourceIds,
    required this.misconception,
    required List<MasteryChange> masteryChanges,
    required List<TermChange> termChanges,
    required this.xpAwarded,
  }) : explanation = List.unmodifiable(explanation),
       sourceIds = List.unmodifiable(sourceIds),
       masteryChanges = List.unmodifiable(masteryChanges),
       termChanges = List.unmodifiable(termChanges);
  @override
  final String exerciseId;
  final bool? correct;
  final AnswerPayload? correctAnswer;
  final EvaluationDetails? details;
  final List<ContentSpan> explanation;
  final List<String> sourceIds;
  final Misconception? misconception;
  final List<MasteryChange> masteryChanges;
  final List<TermChange> termChanges;
  final int xpAwarded;
  @override
  List<Object?> get props => [
    exerciseId,
    correct,
    correctAnswer,
    details,
    explanation,
    sourceIds,
    misconception,
    masteryChanges,
    termChanges,
    xpAwarded,
  ];
}

enum RecitationPlaybackStatus { unavailable, idle, playing, failure }

abstract interface class RecitationPlayback {
  bool get available;
  Future<void> play(void Function(Duration) position, void Function(RecitationPlaybackStatus) status);
  Future<void> dispose();
}

final class FlashcardPayload extends ExercisePayload {
  FlashcardPayload(List<ContentSpan> front, List<ContentSpan> back) : front = List.unmodifiable(front), back = List.unmodifiable(back);
  final List<ContentSpan> front, back;
  @override
  List<Object?> get props => [front, back];
}

final class BlankSegment extends Equatable {
  const BlankSegment({this.text, this.blankId});
  final String? text, blankId;
  @override
  List<Object?> get props => [text, blankId];
}

final class FillPayload extends ExercisePayload {
  FillPayload(List<BlankSegment> segments, List<ExerciseOption> words)
    : segments = List.unmodifiable(segments),
      words = List.unmodifiable(words);
  final List<BlankSegment> segments;
  final List<ExerciseOption> words;
  List<String> get blanks => segments.where((s) => s.blankId != null).map((s) => s.blankId!).toList();
  @override
  List<Object?> get props => [segments, words];
}

final class EvidenceOption extends Equatable {
  const EvidenceOption(this.id, this.evidence);
  final String id;
  final Evidence evidence;
  @override
  List<Object?> get props => [id, evidence];
}

final class EvidenceChoicePayload extends ExercisePayload {
  EvidenceChoicePayload(List<ContentSpan> claim, List<EvidenceOption> options)
    : claim = List.unmodifiable(claim),
      options = List.unmodifiable(options);
  final List<ContentSpan> claim;
  final List<EvidenceOption> options;
  @override
  List<Object?> get props => [claim, options];
}

final class FillsAnswer extends AnswerPayload {
  FillsAnswer(Map<String, String> fills) : fills = Map.unmodifiable(fills);
  final Map<String, String> fills;
  @override
  List<Object?> get props => [fills];
}

final class RatingAnswer extends AnswerPayload {
  const RatingAnswer(this.rating);
  final String rating;
  @override
  List<Object?> get props => [rating];
}

final class TimeoutAnswer extends AnswerPayload {
  const TimeoutAnswer();
  @override
  List<Object?> get props => [];
}

final class TimelineDetails extends EvaluationDetails {
  TimelineDetails(Map<String, String> dates) : dates = Map.unmodifiable(dates);
  final Map<String, String> dates;
  @override
  List<Object?> get props => [dates];
}
