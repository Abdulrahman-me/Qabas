import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/media_failure_messages.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';
import 'package:qabas/shared/lesson/domain/entities/recitation.dart';
import 'package:qabas/shared/lesson/domain/logic/answer_drafts.dart';
import 'package:qabas/shared/lesson/presentation/exercises/flashcard_view.dart';
import 'package:qabas/shared/lesson/presentation/exercises/kit/exercise_kit.dart';
import 'package:qabas/shared/lesson/presentation/lesson_preview_scope.dart';
import 'package:qabas/shared/lesson/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/shared/lesson/presentation/widgets/step_scaffold.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/evidence_card.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';
import 'package:qabas/shared/presentation/visuals/builtin/scenes.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

/// Registry dispatches only on the typed payload; no lesson-specific branches.
class ExerciseRendererRegistry {
  const ExerciseRendererRegistry();
  Widget build(Exercise exercise, ExerciseStepState state, AnswerEvaluation? evaluation, {required bool locked}) =>
      ExerciseBody(exercise: exercise, state: state, evaluation: evaluation, locked: locked);
}

class ExerciseBody extends StatelessWidget {
  const ExerciseBody({super.key, required this.exercise, required this.state, required this.evaluation, required this.locked});
  final Exercise exercise;
  final ExerciseStepState state;
  final AnswerEvaluation? evaluation;
  final bool locked;
  void send(BuildContext c, ExerciseStepEvent e) {
    if (!locked) c.read<ExerciseStepBloc>().add(e);
  }

  TileState choice(String id, String? selected, String? correct) => evaluation == null
      ? (id == selected ? TileState.selected : TileState.idle)
      : id == correct
      ? TileState.correct
      : id == selected
      ? (evaluation!.correct == null ? TileState.guess : TileState.wrong)
      : TileState.dimmed;
  TileState itemState(String id) => evaluation?.details is ItemDetails
      ? ((evaluation!.details as ItemDetails).results[id] == true ? TileState.correct : TileState.wrong)
      : TileState.idle;
  Widget token(
    BuildContext c,
    ExerciseToken i, {
    TileState tileState = TileState.idle,
    bool ghost = false,
    bool compact = false,
    bool showSecondary = true,
    VoidCallback? tap,
    String? dragData,
  }) => Token(
    key: ValueKey('token-${i.id}'),
    spans: i.spans,
    secondaryLabel: showSecondary ? i.secondaryLabel : null,
    state: tileState,
    ghost: ghost,
    compact: compact,
    onTap: locked ? null : tap,
    dragData: locked ? null : dragData,
  );
  @override
  Widget build(BuildContext c) {
    final p = exercise.payload;
    final l = c.l10n;
    if (p is FlashcardPayload) return FlashcardView(payload: p, draft: state.draft as RatingDraft, locked: locked);
    final (label, icon, color) = exercise.framing != null
        ? (l.sessionKindFix, Icons.auto_fix_high_rounded, QColors.retryInk)
        : switch (p) {
            ChoicePayload(:final situation) =>
              situation != null
                  ? (l.sessionKindRealLife, Icons.forum_rounded, QColors.dusk)
                  : (l.sessionKindChoose, Icons.touch_app_rounded, QColors.emerald500),
            FlashcardPayload() => (l.reviewReviewTitle, Icons.style_rounded, QColors.emerald500),
            FillPayload() => (l.sessionFillBlank, Icons.edit_rounded, QColors.emerald500),
            EvidenceChoicePayload() => (l.sessionWhichEvidence, Icons.menu_book_rounded, QColors.emerald500),
            ReasonPayload() => (l.sessionKindTrueFalse, Icons.rule_rounded, QColors.emerald500),
            PairsPayload() => (l.sessionKindMatch, Icons.compare_arrows_rounded, QColors.emerald500),
            CategorizePayload(:final presentation) =>
              presentation == 'day_arc'
                  ? (l.sessionKindDay, Icons.wb_twilight_rounded, QColors.gold800)
                  : (l.sessionKindSort, Icons.call_split_rounded, QColors.emerald500),
            OrderPayload() => (l.sessionKindOrder, Icons.format_list_numbered_rounded, QColors.emerald500),
            SegmentPayload() => (l.sessionSpotError, Icons.manage_search_rounded, QColors.emerald500),
            MapPayload() => (l.sessionKindDiscover, Icons.travel_explore_rounded, QColors.dusk),
            RecitePayload() => (l.sessionKindRecite, Icons.mic_rounded, QColors.emerald500),
            UnknownExercisePayload() => (l.sessionUpdateRequired, Icons.system_update_rounded, QColors.muted),
          };
    return StepScroll(
      children: [
        KindChip(label, icon: icon, color: color),
        SizedBox(height: p is RecitePayload ? QSpace.sm : QSpace.md),
        if (p is ChoicePayload && p.situation != null) ...[
          Reveal(
            child: LessonPreviewScope.active(c)
                ? SpanText(p.situation!, style: c.text.bodyLarge)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const TravelerAvatar(hue: QExercise.scenarioHue, size: QExercise.scenarioAvatar),
                      const SizedBox(width: QSpace.sm),
                      Expanded(
                        child: SpeechBubble(
                          child: SpanText(p.situation!, style: c.text.bodyLarge?.copyWith(fontSize: QExercise.scenarioBody)),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: QSpace.lg),
        ],
        Reveal(
          delay: QLesson.reveal60,
          child: SpanText(exercise.prompt, style: p is RecitePayload ? c.text.headlineMedium : c.text.headlineSmall),
        ),
        if (exercise.framing != null) ...[
          const SizedBox(height: QSpace.md),
          Reveal(
            delay: QMotion.reveal120,
            child: Container(
              padding: const EdgeInsets.all(QSpace.md),
              decoration: BoxDecoration(
                color: QColors.surface,
                borderRadius: QRadius.card,
                border: Border.all(
                  color: QColors.retry.withValues(alpha: QExercise.mythBorderAlpha),
                  width: QExercise.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, size: QExercise.smallIcon, color: QColors.retryInk),
                      const SizedBox(width: QLesson.smallGap),
                      Expanded(
                        child: Text(l.sessionMistakenIdea, style: c.text.labelMedium?.copyWith(color: QColors.retryInk)),
                      ),
                    ],
                  ),
                  const SizedBox(height: QLesson.smallGap),
                  SpanText(exercise.framing!, style: c.text.bodyLarge?.copyWith(fontStyle: c.isArabic ? null : FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
        ...switch (p) {
          FlashcardPayload() => [],
          FillPayload() => _fills(c, p),
          EvidenceChoicePayload() => _evidenceChoices(c, p),
          ChoicePayload() => [
            if (p.verse != null) ...[const SizedBox(height: QSpace.md), EvidenceCard(evidence: p.verse!)],
            ..._choices(c, p),
          ],
          ReasonPayload() => _reason(c, p),
          PairsPayload() => _pairs(c, p),
          CategorizePayload() => p.presentation == 'day_arc' ? _day(c, p) : _buckets(c, p),
          OrderPayload() => _order(c, p),
          SegmentPayload() => _segments(c, p),
          MapPayload() => _map(c, p),
          RecitePayload() => _recite(c, p),
          UnknownExercisePayload() => [const SizedBox(height: QSpace.md), Text(l.sessionUpdateRequired, style: c.text.bodyLarge)],
        },
      ],
    );
  }

  Widget _nudge(Widget child) => Nudge(trigger: evaluation?.correct == false ? 1 : 0, child: child);

  List<Widget> _choices(BuildContext c, ChoicePayload p) {
    final selected = (state.draft as OptionDraft).selected,
        correct = (evaluation?.correctAnswer is OptionAnswer) ? (evaluation!.correctAnswer as OptionAnswer).optionId : null;
    final details = evaluation?.details;
    return [
      const SizedBox(height: QSpace.lg),
      for (var i = 0; i < p.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: QSpace.sm),
          child: Reveal(
            delay: QLesson.reveal160 + QLesson.optionStagger * i,
            child: OptionTile(
              key: ValueKey('option-${p.options[i].id}'),
              index: i,
              spans: p.options[i].spans,
              state: choice(p.options[i].id, selected, correct),
              onTap: locked ? null : () => send(c, ExerciseOptionSelected(p.options[i].id)),
            ),
          ),
        ),
      if (details is ScenarioDetails && selected != null && (details.options[selected]?.isNotEmpty ?? false))
        Padding(
          padding: const EdgeInsets.only(top: QSpace.sm),
          child: SpanText(details.options[selected]!, style: c.text.bodyMedium),
        ),
    ];
  }

  List<Widget> _reason(BuildContext c, ReasonPayload p) {
    final d = state.draft as ReasonDraft, answer = evaluation?.correctAnswer;
    final correct = answer is ReasonAnswer ? answer : null;
    return [
      const SizedBox(height: QSpace.md),
      QCard(child: SpanText(p.statement, style: c.text.bodyLarge)),
      const SizedBox(height: QSpace.md),
      Row(
        children: [
          for (final value in [true, false]) ...[
            if (!value) const SizedBox(width: QSpace.sm),
            Expanded(
              child: Tile3D(
                key: ValueKey('truth-$value'),
                state: evaluation == null
                    ? (d.value == value ? TileState.selected : TileState.idle)
                    : correct?.value == value
                    ? TileState.correct
                    : d.value == value
                    ? TileState.wrong
                    : TileState.dimmed,
                onTap: locked ? null : () => send(c, TruthSelected(value)),
                child: Text(
                  value ? c.l10n.sessionTrueLabel : c.l10n.sessionFalseLabel,
                  textAlign: TextAlign.center,
                  style: c.text.titleSmall,
                ),
              ),
            ),
          ],
        ],
      ),
      if (d.value != null) ...[
        const SizedBox(height: QSpace.lg),
        Text(c.l10n.sessionChooseReason, style: c.text.titleMedium),
        const SizedBox(height: QSpace.sm),
        for (var i = 0; i < p.reasons.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: QSpace.sm),
            child: OptionTile(
              key: ValueKey('reason-${p.reasons[i].id}'),
              index: i,
              spans: p.reasons[i].spans,
              state: choice(p.reasons[i].id, d.reason, correct?.reasonOptionId),
              onTap: locked ? null : () => send(c, ReasonSelected(p.reasons[i].id)),
            ),
          ),
      ],
    ];
  }

  List<Widget> _segments(BuildContext c, SegmentPayload p) {
    final d = state.draft as SegmentDraft, a = evaluation?.correctAnswer;
    return [
      const SizedBox(height: QSpace.lg),
      for (final s in p.segments)
        Padding(
          padding: const EdgeInsets.only(bottom: QSpace.sm),
          child: Tile3D(
            key: ValueKey('segment-${s.id}'),
            state: choice(s.id, d.selected, a is SegmentAnswer ? a.segmentId : null),
            onTap: locked ? null : () => send(c, ExerciseOptionSelected(s.id)),
            child: SpanText(s.spans, style: c.text.bodyLarge),
          ),
        ),
    ];
  }

  List<Widget> _pairs(BuildContext c, PairsPayload p) {
    final d = state.draft as PairsDraft;
    Widget tile(ExerciseOption i, bool left) {
      final paired = left ? d.pairs.containsKey(i.id) : d.pairs.containsValue(i.id);
      final owner = left ? i.id : d.pairs.entries.where((e) => e.value == i.id).firstOrNull?.key;
      final result = owner == null ? TileState.idle : itemState(owner);
      final color = result != TileState.idle
          ? result
          : paired
          ? TileState.guess
          : state.selected == i.id
          ? TileState.selected
          : TileState.idle;
      return Padding(
        padding: const EdgeInsets.only(bottom: QSpace.sm),
        child: Tile3D(
          key: ValueKey('${left ? 'left' : 'right'}-${i.id}'),
          state: color,
          onTap: locked ? null : () => send(c, left ? TokenSelected(i.id) : PairRightSelected(i.id)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: QExercise.matchMinHeight),
            child: Center(
              child: SpanText(i.spans, textAlign: TextAlign.center, style: c.text.titleSmall),
            ),
          ),
        ),
      );
    }

    return [
      const SizedBox(height: QSpace.lg),
      _nudge(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: [for (final i in p.left) tile(i, true)])),
            const SizedBox(width: QSpace.sm),
            Expanded(child: Column(children: [for (final i in p.right) tile(i, false)])),
          ],
        ),
      ),
      const SizedBox(height: QSpace.sm),
      Text(c.l10n.sessionPairHint, style: c.text.bodySmall),
    ];
  }

  List<Widget> _buckets(BuildContext c, CategorizePayload p) {
    final d = state.draft as AssignmentsDraft;
    Widget bucket(Category category) => DragTarget<String>(
      onWillAcceptWithDetails: (_) => !locked,
      onAcceptWithDetails: (v) => send(c, TokenPlaced(v.data, category.id)),
      builder: (c, candidates, _) {
        final hot = candidates.isNotEmpty || state.selected != null;
        return Semantics(
          button: true,
          label: category.label,
          onTap: !locked && state.selected != null ? () => send(c, TokenPlaced(state.selected!, category.id)) : null,
          child: GestureDetector(
            onTap: !locked && state.selected != null ? () => send(c, TokenPlaced(state.selected!, category.id)) : null,
            child: AnimatedContainer(
              duration: c.reduceMotion ? Duration.zero : QMotion.normal,
              constraints: const BoxConstraints(minHeight: QExercise.bucketMinHeight),
              padding: const EdgeInsets.all(QSpace.sm),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty ? QColors.emerald50 : QColors.surface,
                borderRadius: QRadius.card,
                border: Border.all(
                  color: hot ? QColors.emerald400 : QColors.line,
                  width: hot ? QExercise.bucketHotBorder : QExercise.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (c, box) => box.maxWidth < QExercise.compactBucketWidth
                        ? Column(
                            children: [
                              if (category.artKey != null) UnitArtIcon.fromKey(artKey: category.artKey!, size: QExercise.art),
                              Text(category.label, textAlign: TextAlign.center, style: c.text.titleSmall),
                            ],
                          )
                        : Row(
                            children: [
                              if (category.artKey != null) ...[
                                UnitArtIcon.fromKey(artKey: category.artKey!, size: QExercise.art),
                                const SizedBox(width: QSpace.sm),
                              ],
                              Expanded(child: Text(category.label, style: c.text.titleSmall)),
                            ],
                          ),
                  ),
                  const SizedBox(height: QSpace.sm),
                  Wrap(
                    spacing: QLesson.smallGap,
                    runSpacing: QLesson.smallGap,
                    children: [
                      for (final i in p.items)
                        if (d.assignments[i.id] == category.id)
                          Reveal(
                            key: ValueKey(i.id),
                            duration: QMotion.medium,
                            scale: QExercise.tokenRevealScale,
                            offset: Offset.zero,
                            curve: QMotion.settle,
                            child: token(
                              c,
                              i,
                              compact: true,
                              tileState: itemState(i.id),
                              tap: () =>
                                  state.selected != null ? send(c, TokenPlaced(state.selected!, category.id)) : send(c, TokenRemoved(i.id)),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return [
      const SizedBox(height: QSpace.xs),
      Text(c.l10n.sessionTapThenPlace, style: c.text.bodySmall),
      const SizedBox(height: QSpace.lg),
      _nudge(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < p.categories.length; i++) ...[
              if (i > 0) const SizedBox(width: QSpace.sm),
              Expanded(
                child: KeyedSubtree(key: ValueKey('category-${p.categories[i].id}'), child: bucket(p.categories[i])),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: QSpace.lg),
      _bank(c, p, d),
    ];
  }

  Widget _bank(BuildContext c, CategorizePayload p, AssignmentsDraft d) => Wrap(
    alignment: WrapAlignment.center,
    spacing: QSpace.xs,
    runSpacing: QSpace.sm,
    children: [
      for (final i in p.items)
        token(
          c,
          i,
          ghost: d.assignments.containsKey(i.id),
          tileState: state.selected == i.id ? TileState.selected : TileState.idle,
          dragData: i.id,
          tap: () => send(c, TokenSelected(i.id)),
        ),
    ],
  );
  List<Widget> _day(BuildContext c, CategorizePayload p) {
    final d = state.draft as AssignmentsDraft;
    final selectedCategory = d.assignments.values.lastOrNull;
    final sky = p.categories.indexWhere((v) => v.id == selectedCategory);
    return [
      const SizedBox(height: QSpace.xs),
      Text(c.l10n.sessionTapThenSlot, style: c.text.bodySmall),
      const SizedBox(height: QSpace.md),
      ClipRRect(
        borderRadius: QRadius.card,
        child: AspectRatio(
          aspectRatio: QLesson.dayExerciseRatio,
          child: DayArcScene(highlight: sky < 0 ? 0 : sky),
        ),
      ),
      const SizedBox(height: QSpace.md),
      _bank(c, p, d),
      const SizedBox(height: QSpace.lg),
      _nudge(
        Column(
          children: [
            for (var n = 0; n < p.categories.length; n++)
              Padding(
                padding: const EdgeInsets.only(bottom: QSpace.xs),
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (_) => !locked,
                  onAcceptWithDetails: (v) => send(c, TokenPlaced(v.data, p.categories[n].id)),
                  builder: (c, candidates, _) {
                    final category = p.categories[n], item = p.items.where((v) => d.assignments[v.id] == category.id).firstOrNull;
                    return Tile3D(
                      key: ValueKey('slot-${category.id}'),
                      depth: 0,
                      borderColor: candidates.isNotEmpty || (state.selected != null && item == null) ? QColors.emerald400 : QColors.line,
                      state: candidates.isNotEmpty ? TileState.selected : TileState.idle,
                      padding: const EdgeInsets.symmetric(horizontal: QSpace.sm, vertical: QSpace.xs),
                      onTap: locked
                          ? null
                          : () => state.selected != null
                                ? send(c, TokenPlaced(state.selected!, category.id))
                                : item != null
                                ? send(c, TokenRemoved(item.id))
                                : null,
                      child: Row(
                        children: [
                          PhaseIcon(phase: n, size: QLesson.summaryIcon),
                          const SizedBox(width: QSpace.sm),
                          Expanded(child: Text(category.label, style: c.text.titleSmall)),
                          const SizedBox(width: QSpace.xs),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: QExercise.slotMinHeight),
                              child: Center(
                                heightFactor: 1,
                                child: item == null
                                    ? Container(
                                        width: QExercise.emptySlotWidth,
                                        height: QExercise.emptySlotHeight,
                                        decoration: BoxDecoration(
                                          color: QColors.surfaceSunk,
                                          borderRadius: BorderRadius.circular(QRadius.sm),
                                          border: Border.all(color: QColors.lineStrong, width: QLesson.border),
                                        ),
                                      )
                                    : token(
                                        c,
                                        item,
                                        compact: true,
                                        showSecondary: false,
                                        tileState: itemState(item.id),
                                        tap: () => state.selected != null
                                            ? send(c, TokenPlaced(state.selected!, category.id))
                                            : send(c, TokenRemoved(item.id)),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _order(BuildContext c, OrderPayload p) {
    final d = state.draft as OrderDraft, correct = evaluation?.correctAnswer;
    final target = correct is OrderAnswer ? correct.order : null;
    return [
      const SizedBox(height: QSpace.md),
      if (p.presentation == 'timeline' && evaluation?.details is TimelineDetails) ...[
        for (final id in (target ?? d.order))
          Padding(
            padding: const EdgeInsets.only(bottom: QSpace.sm),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, color: QColors.emerald500),
                const SizedBox(width: QSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SpanText(p.steps.firstWhere((s) => s.id == id).spans),
                      Text((evaluation!.details as TimelineDetails).dates[id] ?? '', style: c.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      if (p.presentation == 'day_sequence') ...[
        Row(
          children: [
            const PhaseIcon(phase: 0, size: QExercise.phaseSmall),
            const SizedBox(width: QLesson.smallGap),
            Expanded(
              child: Container(height: QExercise.border, color: QColors.line),
            ),
            const Icon(Icons.arrow_forward_rounded, size: QExercise.smallIcon, color: QColors.muted),
            const SizedBox(width: QLesson.smallGap),
            const PhaseIcon(phase: 4, size: QExercise.phaseSmall),
          ],
        ),
        const SizedBox(height: QSpace.md),
      ],
      _nudge(
        Container(
          constraints: const BoxConstraints(minHeight: QExercise.orderMinHeight),
          padding: const EdgeInsets.all(QSpace.sm),
          decoration: BoxDecoration(
            color: QColors.surface,
            borderRadius: QRadius.card,
            border: Border.all(color: QColors.line, width: QExercise.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 2; i++)
                      Container(
                        height: QExercise.orderLineWidth,
                        margin: const EdgeInsets.only(top: QExercise.orderLineOffset),
                        color: QColors.line,
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: QSpace.xs,
                runSpacing: QSpace.sm,
                children: [
                  for (var n = 0; n < d.order.length; n++)
                    Reveal(
                      key: ValueKey(d.order[n]),
                      duration: QMotion.medium,
                      offset: const Offset(0, QExercise.orderRevealDy),
                      curve: QMotion.settle,
                      child: token(
                        c,
                        p.steps.firstWhere((i) => i.id == d.order[n]),
                        tileState: target == null
                            ? TileState.idle
                            : target[n] == d.order[n]
                            ? TileState.correct
                            : TileState.wrong,
                        tap: () => send(c, TokenRemoved(d.order[n])),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: QSpace.xl),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: QSpace.xs,
        runSpacing: QSpace.sm,
        children: [for (final i in p.steps) token(c, i, ghost: d.order.contains(i.id), tap: () => send(c, OrderTokenSelected(i.id)))],
      ),
      const SizedBox(height: QSpace.sm),
      Text(c.l10n.sessionTapInOrder, textAlign: TextAlign.center, style: c.text.bodySmall),
    ];
  }

  List<Widget> _fills(BuildContext c, FillPayload p) {
    final d = state.draft as FillsDraft;
    return [
      const SizedBox(height: QSpace.lg),
      Wrap(
        spacing: QSpace.xs,
        runSpacing: QSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final segment in p.segments)
            if (segment.blankId == null)
              Text(segment.text ?? '', style: c.text.bodyLarge)
            else
              Tile3D(
                key: ValueKey('blank-${segment.blankId}'),
                state: evaluation == null
                    ? (state.selected == segment.blankId ? TileState.selected : TileState.idle)
                    : itemState(segment.blankId!),
                onTap: locked ? null : () => send(c, BlankSelected(segment.blankId!)),
                child: Padding(
                  padding: const EdgeInsets.all(QSpace.sm),
                  child: d.fills[segment.blankId] == null
                      ? Text(c.l10n.sessionBlank(c.n(p.blanks.indexOf(segment.blankId!) + 1)), style: c.text.labelLarge)
                      : SpanText(p.words.firstWhere((w) => w.id == d.fills[segment.blankId]).spans, style: c.text.titleSmall),
                ),
              ),
        ],
      ),
      const SizedBox(height: QSpace.xl),
      Wrap(
        spacing: QSpace.xs,
        runSpacing: QSpace.sm,
        children: [
          for (final w in p.words)
            Token(
              key: ValueKey('word-${w.id}'),
              spans: w.spans,
              ghost: d.fills.containsValue(w.id),
              onTap: locked ? null : () => send(c, BlankFilled(w.id)),
            ),
        ],
      ),
    ];
  }

  List<Widget> _evidenceChoices(BuildContext c, EvidenceChoicePayload p) {
    final selected = (state.draft as OptionDraft).selected;
    final correct = evaluation?.correctAnswer;
    return [
      const SizedBox(height: QSpace.md),
      SpanText(p.claim, style: c.text.bodyLarge),
      const SizedBox(height: QSpace.md),
      for (final o in p.options)
        Padding(
          padding: const EdgeInsets.only(bottom: QSpace.sm),
          child: Tile3D(
            key: ValueKey('evidence-${o.id}'),
            state: choice(o.id, selected, correct is OptionAnswer ? correct.optionId : null),
            onTap: locked ? null : () => send(c, ExerciseOptionSelected(o.id)),
            child: EvidenceCard(evidence: o.evidence),
          ),
        ),
    ];
  }

  List<Widget> _map(BuildContext c, MapPayload p) {
    final selected = (state.draft as PinDraft).selected;
    final answer = evaluation?.correctAnswer;
    final correct = answer is PinAnswer ? answer.pinId : null;
    final params = <String, Object?>{
      if (p.visual is BuiltinVisual) ...(p.visual as BuiltinVisual).params,
      if (p.visual is SceneVisual) ...(p.visual as SceneVisual).params,
      ...state.visualParams,
      if (evaluation?.correct == true) ...?p.interaction?.correct,
      if (evaluation?.correct == false) ...?p.interaction?.incorrect,
    };
    final ratio = VisualView(p.visual, use: VisualUse.hotspots).ratio;
    return [
      if (p.question.isNotEmpty && !listEquals(exercise.prompt, p.question)) ...[
        const SizedBox(height: QSpace.sm),
        SpanText(p.question, style: c.text.bodyLarge),
      ],
      const SizedBox(height: QSpace.xs),
      Text(c.l10n.sessionTapTheScene, style: c.text.bodySmall),
      const SizedBox(height: QSpace.md),
      ClipRRect(
        borderRadius: QRadius.card,
        child: AspectRatio(
          aspectRatio: ratio,
          child: LayoutBuilder(
            builder: (c, box) => GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTapUp: p.presentation == 'map_pins' && state.mapAvailable && !locked
                  ? (tap) => _mapPinTapped(c, p, box, tap.localPosition)
                  : null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VisualView(
                      p.visual,
                      use: VisualUse.hotspots,
                      params: params,
                      onAvailability: _availability(c.read<ExerciseStepBloc>()),
                    ),
                  ),
                  if (state.mapAvailable)
                    for (final pin in p.pins) _positionedPin(c, p, pin, box, selected, correct),
                ],
              ),
            ),
          ),
        ),
      ),
      if (p.presentation == 'map_pins') ...[
        const SizedBox(height: QSpace.sm),
        Wrap(
          spacing: QSpace.md,
          runSpacing: QSpace.xs,
          children: [
            for (final pin in p.pins)
              if ((evaluation?.details is PinDetails ? (evaluation!.details as PinDetails).labels[pin.id] : null) ?? pin.label
                  case final String label)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.n(p.pins.indexOf(pin) + 1), style: c.text.labelMedium),
                    const SizedBox(width: QSpace.xs),
                    Flexible(child: Text(label, style: c.text.labelMedium)),
                  ],
                ),
          ],
        ),
      ],
    ];
  }

  void _mapPinTapped(BuildContext c, MapPayload payload, BoxConstraints box, Offset tap) {
    MapPin? nearest;
    var nearestDistance = double.infinity;
    for (final pin in payload.pins) {
      final center = Offset(pin.xPct * box.maxWidth / 100, pin.yPct * box.maxHeight / 100);
      final distance = (tap - center).distanceSquared;
      final radius = ((pin.radiusPct ?? 0) * box.maxWidth / 100).clamp(QSizes.tapTarget / 2, double.infinity);
      if (distance <= radius * radius && distance < nearestDistance) {
        nearest = pin;
        nearestDistance = distance;
      }
    }
    if (nearest != null) c.read<ExerciseStepBloc>().add(ExerciseOptionSelected(nearest.id));
  }

  Widget _positionedPin(BuildContext c, MapPayload p, MapPin pin, BoxConstraints box, String? selected, String? correct) {
    final radius = pin.radiusPct;
    final geographic = p.presentation == 'map_pins';
    final diameter = radius == null
        ? geographic
              ? QSizes.tapTarget
              : QExercise.pinWidth
        : (radius * box.maxWidth * 2 / 100).clamp(QSizes.tapTarget, double.infinity);
    final bloc = c.read<ExerciseStepBloc>();
    final action = locked ? null : () => bloc.add(ExerciseOptionSelected(pin.id));
    final label =
        (evaluation?.details is PinDetails ? (evaluation!.details as PinDetails).labels[pin.id] : null) ??
        pin.label ??
        c.l10n.sessionMapPin(c.n(p.pins.indexOf(pin) + 1));
    final marker = _MapPinView(
      key: ValueKey('pin-${pin.id}'),
      label: label,
      selected: selected == pin.id,
      checked: evaluation != null,
      correct: pin.id == correct,
      onTap: action,
      compactLabel: geographic ? c.n(p.pins.indexOf(pin) + 1) : null,
      handlePointer: !geographic,
    );
    return Positioned(
      left: radius == null && !geographic
          ? (pin.xPct * box.maxWidth / 100 - diameter / 2).clamp(0, (box.maxWidth - diameter).clamp(0, double.infinity))
          : pin.xPct * box.maxWidth / 100 - diameter / 2,
      top: radius == null && !geographic
          ? (pin.yPct * box.maxHeight / 100 - (geographic ? diameter / 2 : QExercise.pinTop)).clamp(
              0,
              (box.maxHeight - QSizes.tapTarget).clamp(0, double.infinity),
            )
          : pin.yPct * box.maxHeight / 100 - diameter / 2,
      width: diameter,
      height: radius == null && !geographic ? null : diameter,
      child: radius == null && !geographic
          ? Center(child: marker)
          : ClipOval(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: geographic ? null : action,
                child: Center(child: marker),
              ),
            ),
    );
  }

  List<Widget> _recite(BuildContext c, RecitePayload p) {
    final timings = p.audio.words, position = state.position;
    final reference = c.watch<ContentBloc>().state.sources.where((source) => source.sourceId == p.sourceId).firstOrNull?.reference;
    final activeTiming = timings
        ?.where((w) => state.audioStatus == RecitationPlaybackStatus.playing && w.ayah == p.ayah && position >= w.start && position < w.end)
        .firstOrNull;
    final active = activeTiming == null ? -1 : activeTiming.position - (p.wordStart ?? 1);
    RecitationWordResult? wordResult(int index) =>
        state.check?.words.where((w) => w.index == index && w.result != RecitationWordResult.extra).firstOrNull?.result;
    final words = p.textUthmani.split(RegExp(r'\s+'));
    return [
      const SizedBox(height: QSpace.xs),
      Text(c.l10n.sessionReciteBody, style: c.text.bodyMedium),
      const SizedBox(height: QSpace.md),
      Container(
        padding: const EdgeInsets.fromLTRB(QSpace.md, QSpace.lg, QSpace.md, QSpace.md),
        decoration: BoxDecoration(
          color: QColors.surface,
          borderRadius: BorderRadius.circular(QRadius.xl),
          border: Border.all(color: QColors.emerald100, width: QExercise.border),
          boxShadow: QShadows.soft,
        ),
        child: Column(
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: QSpace.xxs,
                runSpacing: QSpace.xxs,
                children: [
                  for (var i = 0; i <= words.length; i++) ...[
                    for (final _
                        in state.check?.words.where((w) => w.result == RecitationWordResult.extra && w.index == i) ?? <RecitationWord>[])
                      Chip(label: Text(c.l10n.recitationExtraWord), backgroundColor: QColors.retrySoft),
                    if (i < words.length)
                      AnimatedContainer(
                        duration: c.reduceMotion ? Duration.zero : QMotion.normal,
                        padding: const EdgeInsets.symmetric(horizontal: QLesson.smallGap),
                        decoration: BoxDecoration(
                          color: wordResult(i) == RecitationWordResult.missing || wordResult(i) == RecitationWordResult.substituted
                              ? QColors.retrySoft
                              : i == active
                              ? QColors.gold100
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(QExercise.reciteRadius),
                        ),
                        child: Semantics(
                          button: state.check != null,
                          label: wordResult(i) == null
                              ? words[i]
                              : c.l10n.recitationWordFeedback(words[i], switch (wordResult(i)) {
                                  RecitationWordResult.correct => c.l10n.recitationCorrectWord,
                                  RecitationWordResult.missing => c.l10n.recitationMissingWord,
                                  _ => c.l10n.recitationSubstitutedWord,
                                }),
                          child: GestureDetector(
                            onTap: state.check == null ? null : () => c.read<ExerciseStepBloc>().add(RecitationWordPressed(i)),
                            child: AnimatedScale(
                              scale: i == active && !c.reduceMotion ? QExercise.reciteScale : 1,
                              duration: c.reduceMotion ? Duration.zero : QMotion.normal,
                              child: Text(
                                key: ValueKey('recite-word-$i'),
                                words[i],
                                style: c.qText.quran.copyWith(
                                  fontSize: QExercise.reciteWord,
                                  height: QExercise.reciteWordHeight,
                                  color: i == active ? QColors.gold800 : QColors.deepInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (!c.isArabic && p.transliteration != null) ...[
              TextButton(
                onPressed: () => c.read<ExerciseStepBloc>().add(const TransliterationToggled()),
                child: Text(c.l10n.sessionTransliteration),
              ),
              if (state.transliteration) Text(p.transliteration!, textAlign: TextAlign.center, style: c.text.bodyMedium),
            ],
            const SizedBox(height: QSpace.sm),
            Text(
              reference?.isNotEmpty == true ? reference! : c.l10n.sessionVerseReference(c.n(p.surah), c.n(p.ayah)),
              style: c.text.labelMedium,
            ),
            if (p.meaning?.isNotEmpty ?? false) ...[
              TextButton(
                key: const ValueKey('recite-meaning'),
                onPressed: () => c.read<ExerciseStepBloc>().add(const MeaningToggled()),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.l10n.sessionMeaning),
                    Icon(state.meaning ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: QLesson.interfaceIcon),
                  ],
                ),
              ),
              if (c.reduceMotion) ...[
                if (state.meaning) SpanText(p.meaning!, textAlign: TextAlign.center, style: c.text.bodyMedium),
              ] else
                AnimatedSize(
                  duration: QMotion.normal,
                  child: state.meaning
                      ? SpanText(p.meaning!, textAlign: TextAlign.center, style: c.text.bodyMedium)
                      : const SizedBox(width: double.infinity),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: QSpace.xl),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _round(
            c,
            state.audioStatus == RecitationPlaybackStatus.playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
            state.audioStatus == RecitationPlaybackStatus.playing ? c.l10n.sessionPlaying : c.l10n.sessionListenReciter,
            QColors.emerald500,
            QExercise.listenSize,
            state.audioStatus == RecitationPlaybackStatus.unavailable
                ? null
                : () => c.read<ExerciseStepBloc>().add(const AudioListenPressed()),
          ),
          _round(
            c,
            state.recitationStatus == RecitationStatus.recording ? Icons.stop_rounded : Icons.mic_rounded,
            state.recitationStatus == RecitationStatus.unavailable
                ? c.l10n.sessionRecordingUnavailable
                : state.recitationStatus == RecitationStatus.recording
                ? c.l10n.mediaStopRecording
                : c.l10n.mediaRecord,
            QColors.flameGold,
            QExercise.micSize,
            locked ||
                    [RecitationStatus.unavailable, RecitationStatus.checking, RecitationStatus.requesting].contains(state.recitationStatus)
                ? null
                : () => c.read<ExerciseStepBloc>().add(const RecitationRecordPressed()),
          ),
        ],
      ),
      const SizedBox(height: QSpace.lg),
      if (state.audioStatus == RecitationPlaybackStatus.unavailable || state.audioStatus == RecitationPlaybackStatus.failure)
        Text(c.l10n.contentAudioError, textAlign: TextAlign.center, style: c.text.bodyMedium),
      if (state.recitationStatus == RecitationStatus.recording)
        Semantics(
          liveRegion: true,
          child: Text(
            c.l10n.mediaRecordingTime(c.n(state.recordingElapsed.inSeconds), c.n(p.maxDuration.inSeconds.clamp(1, 30))),
            textAlign: TextAlign.center,
          ),
        ),
      if (state.recitationStatus == RecitationStatus.checking) QInlineLoading(label: c.l10n.recitationChecking),
      if (state.recitationFailure != null) ...[
        QInlineError(
          message: state.recitationFailure is UpstreamUnavailableFailure
              ? c.l10n.recitationBusy
              : mediaFailureBody(state.recitationFailure!, c),
        ),
        if (state.recitationFailure is MicrophoneDeniedFailure)
          TextButton(
            onPressed: () => c.read<ExerciseStepBloc>().add(const RecitationSettingsOpened()),
            child: Text(c.l10n.mediaOpenSettings),
          ),
      ],
      if (state.check != null) ...[
        const SizedBox(height: QSpace.md),
        SpanText(state.check!.message, textAlign: TextAlign.center),
        if (!state.check!.unclear && !state.check!.passed)
          QButton(
            label: c.l10n.recitationContinue,
            onPressed: locked ? null : () => c.read<ExerciseStepBloc>().add(const RecitationAccepted()),
          ),
        TextButton(
          onPressed: locked ? null : () => c.read<ExerciseStepBloc>().add(const RecitationRecordPressed()),
          child: Text(c.l10n.recitationAgain),
        ),
      ],
      if (p.skippable)
        Center(
          child: QButton(
            key: const ValueKey('recite-skip'),
            label: c.l10n.sessionSkipRecite,
            tone: QButtonTone.ghost,
            expand: false,
            onPressed: locked ? null : () => send(c, const RecitationSkipped()),
          ),
        ),
    ];
  }

  Widget _round(BuildContext c, IconData icon, String label, Color color, double size, VoidCallback? onTap) => Flexible(
    child: Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: onTap == null ? QExercise.disabledPinAlpha : 1,
            child: GestureDetector(
              onTap: onTap,
              child: SizedBox(
                width: size + QSpace.xl,
                height: size + QSpace.xl,
                child: Center(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color == QColors.flameGold ? QColors.gold700 : QColors.emerald700,
                          offset: const Offset(0, QSizes.buttonDepth),
                        ),
                        ...QShadows.glow(color, strength: QExercise.roundGlow),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: color == QColors.flameGold ? QColors.deepInk : QColors.surface,
                      size: size * QExercise.roundIconFraction,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: QSpace.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: c.text.labelMedium?.copyWith(color: QColors.slate),
          ),
        ],
      ),
    ),
  );

  void Function(bool) _availability(ExerciseStepBloc bloc) => (available) {
    if (!bloc.isClosed) bloc.add(MapAvailabilityChanged(available));
  };
}

class _MapPinView extends StatelessWidget {
  const _MapPinView({
    super.key,
    required this.label,
    required this.selected,
    required this.checked,
    required this.correct,
    this.onTap,
    this.compactLabel,
    this.handlePointer = true,
  });
  final String label;
  final String? compactLabel;
  final bool handlePointer;
  final bool selected, checked, correct;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext c) {
    final bg = checked
        ? (correct
              ? QColors.correct
              : selected
              ? QColors.retry
              : QColors.nightEmerald.withValues(alpha: QExercise.disabledPinAlpha))
        : selected
        ? QColors.flameGold
        : QColors.nightEmerald.withValues(alpha: QExercise.pinAlpha);
    final ink = !checked && selected ? QColors.deepInk : QColors.surface;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: handlePointer ? onTap : null,
        child: AnimatedScale(
          scale: selected && !c.reduceMotion ? QExercise.pinScale : 1,
          duration: c.reduceMotion ? Duration.zero : QMotion.normal,
          curve: QMotion.settle,
          child: AnimatedContainer(
            duration: c.reduceMotion ? Duration.zero : QMotion.normal,
            constraints: const BoxConstraints(minHeight: QSizes.tapTarget),
            padding: compactLabel == null
                ? const EdgeInsets.symmetric(horizontal: QExercise.pinHorizontal, vertical: QExercise.pinVertical)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(QExercise.pinRadius),
              border: Border.all(color: QColors.surface, width: QExercise.border),
              boxShadow: QShadows.soft,
            ),
            child: compactLabel != null
                ? Center(
                    child: checked && (correct || selected)
                        ? Icon(correct ? Icons.check_rounded : Icons.close_rounded, color: ink, size: QExercise.pinIcon)
                        : Text(compactLabel!, style: c.text.labelMedium?.copyWith(color: ink)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (checked && (correct || selected)) ...[
                        Icon(correct ? Icons.check_rounded : Icons.close_rounded, color: ink, size: QExercise.pinIcon),
                        const SizedBox(width: QSpace.xxs),
                      ],
                      Flexible(
                        child: Text(label, style: c.text.labelMedium?.copyWith(color: ink)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
