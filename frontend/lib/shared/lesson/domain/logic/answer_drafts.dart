import 'package:equatable/equatable.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';

sealed class AnswerDraft extends Equatable {
  const AnswerDraft();
  bool get isComplete;
  AnswerPayload toPayload();
  factory AnswerDraft.forPayload(ExercisePayload p) => switch (p) {
    FlashcardPayload() => const RatingDraft(),
    FillPayload() => FillsDraft(p),
    EvidenceChoicePayload() => const OptionDraft(),
    ChoicePayload() => const OptionDraft(),
    ReasonPayload() => const ReasonDraft(),
    PairsPayload() => PairsDraft(p.left.map((v) => v.id).toList()),
    CategorizePayload() => AssignmentsDraft(p),
    SegmentPayload() => const SegmentDraft(),
    OrderPayload() => OrderDraft(p.steps.map((v) => v.id).toList()),
    MapPayload() => const PinDraft(),
    RecitePayload() => const RecitationDraft(),
    UnknownExercisePayload() => const UnknownDraft(),
  };
  static AnswerDraft restored(ExercisePayload p, AnswerPayload? a) => switch ((p, a)) {
    (ChoicePayload() || EvidenceChoicePayload(), final OptionAnswer a) => OptionDraft(a.optionId),
    (ReasonPayload(), final ReasonAnswer a) => ReasonDraft(value: a.value, reason: a.reasonOptionId),
    (final PairsPayload p, final PairsAnswer a) => PairsDraft(p.left.map((o) => o.id).toList(), pairs: a.pairs),
    (final CategorizePayload p, final AssignmentsAnswer a) => AssignmentsDraft(p, assignments: a.assignments),
    (SegmentPayload(), final SegmentAnswer a) => SegmentDraft(a.segmentId),
    (final OrderPayload p, final OrderAnswer a) => OrderDraft(p.steps.map((o) => o.id).toList(), order: a.order),
    (MapPayload(), final PinAnswer a) => PinDraft(a.pinId),
    (MapPayload(), UnavailableAnswer()) => const PinDraft(null, true),
    (final FillPayload p, final FillsAnswer a) => FillsDraft(p, fills: a.fills),
    (FlashcardPayload(), final RatingAnswer a) => RatingDraft(flipped: true, rating: a.rating),
    (RecitePayload(), RecitationAnswer(:final checkId)) => RecitationDraft(checkId: checkId),
    (RecitePayload(), SkippedAnswer()) => const RecitationDraft(skipped: true),
    _ => AnswerDraft.forPayload(p),
  };
}

final class OptionDraft extends AnswerDraft {
  const OptionDraft([this.selected]);
  final String? selected;
  @override
  bool get isComplete => selected != null;
  @override
  AnswerPayload toPayload() => OptionAnswer(selected!);
  @override
  List<Object?> get props => [selected];
}

final class SegmentDraft extends AnswerDraft {
  const SegmentDraft([this.selected]);
  final String? selected;
  @override
  bool get isComplete => selected != null;
  @override
  AnswerPayload toPayload() => SegmentAnswer(selected!);
  @override
  List<Object?> get props => [selected];
}

final class PinDraft extends AnswerDraft {
  const PinDraft([this.selected, this.unavailable = false]);
  final String? selected;
  final bool unavailable;
  @override
  bool get isComplete => selected != null || unavailable;
  @override
  AnswerPayload toPayload() => unavailable ? const UnavailableAnswer() : PinAnswer(selected!);
  @override
  List<Object?> get props => [selected, unavailable];
}

final class ReasonDraft extends AnswerDraft {
  const ReasonDraft({this.value, this.reason});
  final bool? value;
  final String? reason;
  @override
  bool get isComplete => value != null && reason != null;
  @override
  AnswerPayload toPayload() => ReasonAnswer(value!, reason!);
  @override
  List<Object?> get props => [value, reason];
}

final class PairsDraft extends AnswerDraft {
  PairsDraft(List<String> ids, {Map<String, String> pairs = const {}}) : ids = List.unmodifiable(ids), pairs = Map.unmodifiable(pairs);
  final List<String> ids;
  final Map<String, String> pairs;
  PairsDraft pair(String left, String right) => PairsDraft(
    ids,
    pairs: {
      for (final e in pairs.entries)
        if (e.key != left && e.value != right) e.key: e.value,
      left: right,
    },
  );
  PairsDraft remove(String left) => PairsDraft(
    ids,
    pairs: {
      for (final e in pairs.entries)
        if (e.key != left) e.key: e.value,
    },
  );
  @override
  bool get isComplete => ids.every(pairs.containsKey) && pairs.length == ids.length;
  @override
  AnswerPayload toPayload() => PairsAnswer({for (final id in ids) id: pairs[id]!});
  @override
  List<Object?> get props => [ids, pairs];
}

final class AssignmentsDraft extends AnswerDraft {
  AssignmentsDraft(this.payload, {Map<String, String> assignments = const {}}) : assignments = Map.unmodifiable(assignments);
  final CategorizePayload payload;
  final Map<String, String> assignments;
  AssignmentsDraft place(String item, String category) {
    if (!payload.items.any((i) => i.id == item) || !payload.categories.any((c) => c.id == category)) return this;
    final capacity = payload.categories.firstWhere((c) => c.id == category).capacity;
    final next = {...assignments}..remove(item);
    if (capacity != null) {
      final occupants = next.entries.where((e) => e.value == category).map((e) => e.key).toList();
      while (occupants.length >= capacity) {
        next.remove(occupants.removeAt(0));
      }
    }
    next[item] = category;
    return AssignmentsDraft(payload, assignments: next);
  }

  AssignmentsDraft remove(String item) => AssignmentsDraft(
    payload,
    assignments: {
      for (final e in assignments.entries)
        if (e.key != item) e.key: e.value,
    },
  );
  @override
  bool get isComplete => payload.items.every((i) => assignments.containsKey(i.id));
  @override
  AnswerPayload toPayload() => AssignmentsAnswer({for (final i in payload.items) i.id: assignments[i.id]!});
  @override
  List<Object?> get props => [payload, assignments];
}

final class OrderDraft extends AnswerDraft {
  OrderDraft(List<String> ids, {List<String> order = const []}) : ids = List.unmodifiable(ids), order = List.unmodifiable(order);
  final List<String> ids, order;
  OrderDraft add(String id) => !ids.contains(id) || order.contains(id) ? this : OrderDraft(ids, order: [...order, id]);
  OrderDraft remove(String id) => OrderDraft(ids, order: order.where((v) => v != id).toList());
  @override
  bool get isComplete => order.length == ids.length && ids.every(order.contains);
  @override
  AnswerPayload toPayload() => OrderAnswer(order);
  @override
  List<Object?> get props => [ids, order];
}

final class RecitationDraft extends AnswerDraft {
  const RecitationDraft({this.skipped = false, this.checkId});
  final String? checkId;
  final bool skipped;
  @override
  bool get isComplete => skipped || checkId != null;
  @override
  AnswerPayload toPayload() => checkId == null ? const SkippedAnswer() : RecitationAnswer(checkId!);
  @override
  List<Object?> get props => [skipped, checkId];
}

final class UnknownDraft extends AnswerDraft {
  const UnknownDraft();
  @override
  bool get isComplete => false;
  @override
  AnswerPayload toPayload() => throw StateError('Unsupported exercise');
  @override
  List<Object?> get props => [];
}

final class RatingDraft extends AnswerDraft {
  const RatingDraft({this.flipped = false, this.rating});
  final bool flipped;
  final String? rating;
  @override
  bool get isComplete => flipped && rating != null;
  @override
  AnswerPayload toPayload() => RatingAnswer(rating!);
  @override
  List<Object?> get props => [flipped, rating];
}

final class FillsDraft extends AnswerDraft {
  FillsDraft(this.payload, {Map<String, String> fills = const {}}) : fills = Map.unmodifiable(fills);
  final FillPayload payload;
  final Map<String, String> fills;
  FillsDraft place(String blank, String word) {
    if (!payload.blanks.contains(blank) || !payload.words.any((w) => w.id == word)) return this;
    return FillsDraft(
      payload,
      fills: {
        for (final e in fills.entries)
          if (e.key != blank && e.value != word) e.key: e.value,
        blank: word,
      },
    );
  }

  FillsDraft remove(String blank) => FillsDraft(
    payload,
    fills: {
      for (final e in fills.entries)
        if (e.key != blank) e.key: e.value,
    },
  );
  @override
  bool get isComplete => payload.blanks.every(fills.containsKey);
  @override
  AnswerPayload toPayload() => FillsAnswer({for (final id in payload.blanks) id: fills[id]!});
  @override
  List<Object?> get props => [payload, fills];
}
