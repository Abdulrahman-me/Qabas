import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';
import 'package:qabas/shared/presentation/content/evidence_card.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

List<Widget> correctAnswerWidgets(BuildContext c, Exercise ex, AnswerPayload a, {EvaluationDetails? details}) {
  Widget spans(List<ContentSpan> value) => SpanText(value, style: c.text.titleSmall);
  Widget mapping(Widget left, Widget right) => Row(
    children: [
      Expanded(child: left),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: QSpace.xs),
        child: Icon(Icons.arrow_forward_rounded, size: QExercise.smallIcon),
      ),
      Expanded(child: right),
    ],
  );
  final p = ex.payload;
  return switch ((p, a)) {
    (final ChoicePayload p, final OptionAnswer a) => [spans(p.options.firstWhere((o) => o.id == a.optionId).spans)],
    (final FillPayload p, final FillsAnswer a) => [for (final word in a.fills.values) spans(p.words.firstWhere((w) => w.id == word).spans)],
    (final EvidenceChoicePayload p, final OptionAnswer a) => [
      EvidenceCard(evidence: p.options.firstWhere((o) => o.id == a.optionId).evidence),
    ],
    (final SegmentPayload p, final SegmentAnswer a) => [spans(p.segments.firstWhere((o) => o.id == a.segmentId).spans)],
    (final ReasonPayload p, final ReasonAnswer a) => [
      Text(a.value ? c.l10n.sessionTrueLabel : c.l10n.sessionFalseLabel, style: c.text.titleSmall),
      spans(p.reasons.firstWhere((o) => o.id == a.reasonOptionId).spans),
    ],
    (final PairsPayload p, final PairsAnswer a) => [
      for (final e in a.pairs.entries)
        mapping(spans(p.left.firstWhere((o) => o.id == e.key).spans), spans(p.right.firstWhere((o) => o.id == e.value).spans)),
    ],
    (final CategorizePayload p, final AssignmentsAnswer a) => [
      for (final e in a.assignments.entries)
        mapping(
          spans(p.items.firstWhere((o) => o.id == e.key).spans),
          Text(p.categories.firstWhere((o) => o.id == e.value).label, style: c.text.titleSmall),
        ),
    ],
    (final OrderPayload p, final OrderAnswer a) => [
      for (var i = 0; i < a.order.length; i++)
        Row(
          children: [
            Text(c.n(i + 1), style: c.text.labelMedium),
            const SizedBox(width: QSpace.xs),
            Expanded(child: spans(p.steps.firstWhere((o) => o.id == a.order[i]).spans)),
          ],
        ),
    ],
    (final MapPayload p, final PinAnswer a) => [
      Text(
        (details is PinDetails ? (details).labels[a.pinId] : null) ??
            p.pins.firstWhere((o) => o.id == a.pinId).label ??
            c.l10n.sessionMapPin(c.n(p.pins.indexWhere((o) => o.id == a.pinId) + 1)),
        style: c.text.titleSmall,
      ),
    ],
    _ => [],
  };
}
