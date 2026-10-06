import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/components/prediction_tile.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';
import 'package:qabas/shared/lesson/domain/logic/teach_params.dart';
import 'package:qabas/shared/lesson/presentation/lesson_preview_scope.dart';
import 'package:qabas/shared/lesson/presentation/steps/content_step_bloc.dart';
import 'package:qabas/shared/lesson/presentation/widgets/step_scaffold.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/evidence_card.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

class HookStepView extends StatelessWidget {
  const HookStepView(this.item, {super.key});
  final HookItem item;
  @override
  Widget build(BuildContext context) => StepScroll(
    children: [
      KindChip(context.l10n.sessionSituation, icon: Icons.wb_sunny_outlined, color: QColors.gold800),
      const SizedBox(height: QSpace.md),
      Reveal(child: VisualView(item.visual, use: VisualUse.hook)),
      const SizedBox(height: QSpace.lg),
      Reveal(
        delay: QMotion.reveal120,
        child: SpanText(item.situation, style: context.text.bodyLarge?.copyWith(fontSize: QLesson.body)),
      ),
      const SizedBox(height: QSpace.lg),
      Reveal(
        delay: QLesson.reveal260,
        child: LayoutBuilder(
          builder: (context, box) {
            if (LessonPreviewScope.active(context)) return SpanText(item.question, style: context.text.titleMedium);
            final companion = CharacterView(
              size: box.maxWidth < QLesson.compactContent ? QLesson.compactCompanion : QLesson.hookCompanion,
              aspect: QLesson.hookAspect,
              zoom: QLesson.hookZoom,
              mood: CharacterMood.thinking,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                companion,
                const SizedBox(width: QSpace.sm),
                Expanded(
                  child: SpeechBubble(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SpanText(item.question, style: context.text.titleMedium?.copyWith(height: QLesson.questionHeight)),
                        const SizedBox(height: QLesson.smallGap),
                        Text(context.l10n.sessionThinkFirst, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class PredictStepView extends StatelessWidget {
  const PredictStepView(this.item, {super.key});
  final PredictItem item;
  @override
  Widget build(BuildContext context) => BlocBuilder<ContentStepBloc, ContentStepState>(
    builder: (context, state) => StepScroll(
      children: [
        KindChip(context.l10n.sessionKindGuess, icon: Icons.lightbulb_rounded, color: QColors.gold800),
        const SizedBox(height: QSpace.md),
        Reveal(
          delay: QLesson.reveal60,
          child: SpanText(item.prompt, style: context.text.headlineSmall),
        ),
        if (item.visual != null) ...[const SizedBox(height: QSpace.md), VisualView(item.visual!, use: VisualUse.predict)],
        const SizedBox(height: QSpace.lg),
        for (var i = 0; i < item.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: QSpace.sm),
            child: Reveal(
              delay: QLesson.reveal160 + QLesson.optionStagger * i,
              child: PredictionTile(
                key: ValueKey('predict-option-$i'),
                index: i,
                state: state.status == ContentStepStatus.ready
                    ? state.selectedOptionId == item.options[i].optionId
                          ? PredictionTileState.selected
                          : PredictionTileState.idle
                    : state.selectedOptionId == item.options[i].optionId
                    ? PredictionTileState.guess
                    : PredictionTileState.dimmed,
                onTap: state.status == ContentStepStatus.ready
                    ? () => context.read<ContentStepBloc>().add(PredictionOptionPicked(item.options[i].optionId))
                    : null,
                child: Builder(builder: (context) => SpanText(item.options[i].spans, style: DefaultTextStyle.of(context).style)),
              ),
            ),
          ),
      ],
    ),
  );
}

class StoryStepView extends StatelessWidget {
  const StoryStepView(this.item, {super.key});
  final StoryItem item;
  @override
  Widget build(BuildContext context) => BlocBuilder<ContentStepBloc, ContentStepState>(
    builder: (context, state) {
      if (state.originShown) {
        return StepScroll(
          children: [
            KindChip(context.l10n.sessionOriginTitle, icon: Icons.menu_book_rounded),
            const SizedBox(height: QSpace.md),
            Text(item.origin!.title, style: context.text.headlineSmall),
            const SizedBox(height: QSpace.md),
            SourcesSheet(
              sources: context.read<ContentBloc>().state.sources.where((s) => item.origin!.sourceIds.contains(s.sourceId)).toList(),
            ),
          ],
        );
      }
      final beat = item.beats[state.beat];
      final provenance = item.provenance;
      return StepScroll(
        children: [
          KindChip(item.label, icon: Icons.auto_stories_rounded, color: QColors.gold800),
          const SizedBox(height: QSpace.sm),
          if (item.title != null) ...[Text(item.title!, style: context.text.headlineSmall), const SizedBox(height: QSpace.md)],
          VisualView(beat.visual, use: VisualUse.story),
          const SizedBox(height: QSpace.sm),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < item.beats.length; i++)
                AnimatedContainer(
                  duration: context.reduceMotion ? Duration.zero : QMotion.normal,
                  margin: const EdgeInsets.symmetric(horizontal: QLesson.dotGap),
                  width: i == state.beat ? QLesson.activeDot : QLesson.dots,
                  height: QLesson.dots,
                  decoration: BoxDecoration(color: i <= state.beat ? QColors.flameGold : QColors.lineStrong, borderRadius: QRadius.chip),
                ),
            ],
          ),
          const SizedBox(height: QSpace.md),
          AnimatedSwitcher(
            duration: context.reduceMotion ? Duration.zero : QMotion.slow,
            switchInCurve: QMotion.emphasized,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, QLesson.storyEnterDy), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
            layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
            child: Column(
              key: ValueKey(beat.beatId),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final sentence in beat.narration)
                  SentenceText(sentence, style: context.text.bodyLarge?.copyWith(fontSize: QLesson.body)),
                if (beat.narrationAudioUrl != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => context.read<ContentBloc>().add(ContentAudioPlayed(beat.narrationAudioUrl!)),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: Text(context.l10n.glossaryListen),
                    ),
                  ),
                if (beat.quote != null) ...[
                  const SizedBox(height: QSpace.md),
                  Container(
                    padding: const EdgeInsets.all(QSpace.md),
                    decoration: BoxDecoration(
                      color: QColors.surface,
                      borderRadius: QRadius.card,
                      border: Border.all(color: QColors.gold100, width: QLesson.quoteBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        switch (beat.quote) {
                          final q? when q is QuranEvidence => QuranText(q),
                          final h? when h is HadithEvidence => HadithText(h),
                          _ => const SizedBox.shrink(),
                        },
                        if (beat.quoteMeaning != null) ...[
                          const SizedBox(height: QSpace.sm),
                          SpanText(
                            beat.quoteMeaning!,
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium?.copyWith(
                              color: QColors.deepInk.withValues(alpha: QLesson.quoteMeaningAlpha),
                              fontStyle: context.isArabic ? null : FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (provenance != null) ...[
            const SizedBox(height: QSpace.lg),
            Wrap(
              spacing: QLesson.smallGap,
              runSpacing: QLesson.smallGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (provenance.gradeLabel != null)
                  Tag(provenance.gradeLabel!, icon: Icons.verified_rounded, color: QColors.correct, background: QColors.correctSoft),
                Tag(provenance.reference, color: QColors.slate, background: QColors.surfaceSunk),
                Tag(
                  sourceProviderLabel(context, provenance.provider),
                  icon: Icons.link_rounded,
                  color: QColors.emerald500,
                  background: QColors.emerald50,
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class TeachStepView extends StatefulWidget {
  const TeachStepView(this.item, {super.key});
  final TeachItem item;
  @override
  State<TeachStepView> createState() => _TeachStepViewState();
}

class _TeachStepViewState extends State<TeachStepView> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ContentStepBloc, ContentStepState>(
    listenWhen: (a, b) => a.shown != b.shown,
    listener: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          if (context.reduceMotion) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          } else {
            unawaited(_scroll.animateTo(_scroll.position.maxScrollExtent, duration: QMotion.slow, curve: QMotion.emphasized));
          }
        }
      });
    },
    builder: (context, state) {
      final item = widget.item;
      final summary = item.style == TeachStyle.summary;
      return Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: context.l10n.sessionShowAll): () => context.read<ContentStepBloc>().add(const AllTeachPointsShown()),
        },
        child: StepScroll(
          controller: _scroll,
          children: [
            if (item.eyebrow != null) ...[
              KindChip(
                item.eyebrow!,
                icon: item.evidence != null ? Icons.verified_rounded : Icons.lightbulb_rounded,
                color: item.evidence != null ? QColors.emerald500 : QColors.gold800,
              ),
              const SizedBox(height: QSpace.sm),
            ],
            Reveal(child: SpanText(item.title, style: context.text.headlineMedium)),
            const SizedBox(height: QSpace.md),
            if (item.visual != null) ...[
              Reveal(
                delay: QLesson.reveal100,
                child: VisualView(item.visual!, use: VisualUse.teach, params: teachParams(item, state.shown)),
              ),
              const SizedBox(height: QSpace.md),
            ],
            if (item.evidence != null) ...[
              Reveal(
                delay: QLesson.reveal180,
                child: EvidenceCard(evidence: item.evidence!),
              ),
              const SizedBox(height: QSpace.lg),
            ],
            for (var i = 0; i < state.shown; i++)
              Reveal(
                key: ValueKey('point-$i'),
                delay: summary ? QLesson.pointStagger * i : Duration.zero,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: QSpace.md),
                  child: summary ? _SummaryPoint(i, item.points[i]) : _TeachPoint(item.points[i], latest: i == state.shown - 1),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _TeachPoint extends StatelessWidget {
  const _TeachPoint(this.point, {required this.latest});
  final TeachPoint point;
  final bool latest;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(top: context.isArabic ? QLesson.pointArabicTop : QLesson.pointLatinTop),
        child: AnimatedOpacity(
          duration: context.reduceMotion ? Duration.zero : QMotion.normal,
          opacity: latest ? 1 : QLesson.earlierFlameAlpha,
          child: LessonPreviewScope.active(context)
              ? const Icon(Icons.circle_outlined, size: QLesson.pointFlame, color: QColors.statusUnknown)
              : const FlameMark(size: QLesson.pointFlame, animate: false),
        ),
      ),
      const SizedBox(width: QSpace.sm),
      Expanded(
        child: AnimatedDefaultTextStyle(
          duration: context.reduceMotion ? Duration.zero : QMotion.normal,
          style: context.text.bodyLarge!.copyWith(
            fontSize: QLesson.body,
            color: latest ? QColors.deepInk : QColors.deepInk.withValues(alpha: QLesson.earlierTextAlpha),
          ),
          child: Builder(builder: (context) => SentenceText(point.sentence, style: DefaultTextStyle.of(context).style)),
        ),
      ),
    ],
  );
}

class _SummaryPoint extends StatelessWidget {
  const _SummaryPoint(this.index, this.point);
  final int index;
  final TeachPoint point;
  @override
  Widget build(BuildContext context) {
    const icons = [Icons.self_improvement_rounded, Icons.water_rounded, Icons.wb_twilight_rounded];
    return QCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: QLesson.summaryIcon,
            height: QLesson.summaryIcon,
            decoration: BoxDecoration(color: QColors.gold100, borderRadius: BorderRadius.circular(QRadius.sm)),
            child: Icon(icons[index % icons.length], color: QColors.gold800),
          ),
          const SizedBox(width: QSpace.md),
          Expanded(child: SentenceText(point.sentence, style: context.text.bodyLarge)),
        ],
      ),
    );
  }
}

Widget contentStepView(SessionItem item) => switch (item) {
  final HookItem i => HookStepView(i),
  final PredictItem i => PredictStepView(i),
  final StoryItem i => StoryStepView(i),
  final TeachItem i => TeachStepView(i),
  final ParagraphItem i => StepScroll(
    children: [
      for (final s in i.sentences)
        Padding(
          padding: const EdgeInsets.only(bottom: QSpace.md),
          child: SentenceText(s),
        ),
    ],
  ),
  final EvidenceItem i => StepScroll(
    children: [
      EvidenceCard(evidence: i.evidence),
      if (i.caption != null) ...[const SizedBox(height: QSpace.md), SpanText(i.caption!)],
    ],
  ),
  final VisualItem i => StepScroll(
    children: [
      VisualView(i.visual, use: VisualUse.block),
      if (i.caption != null) ...[const SizedBox(height: QSpace.md), SpanText(i.caption!)],
    ],
  ),
  final CalloutItem i => _CalloutStep(i),
  final ExerciseItem i => _ExercisePlaceholder(i),
  _ => const SizedBox.shrink(),
};

class _CalloutStep extends StatelessWidget {
  const _CalloutStep(this.item);
  final CalloutItem item;
  @override
  Widget build(BuildContext context) => StepScroll(
    children: [
      QCard(
        color: item.variant == CalloutVariant.tip ? QColors.gold50 : QColors.emerald50,
        shadow: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.variant == CalloutVariant.tip ? Icons.lightbulb_outline_rounded : Icons.info_outline_rounded,
              color: item.variant == CalloutVariant.tip ? QColors.gold800 : QColors.emerald500,
            ),
            const SizedBox(width: QSpace.sm),
            Expanded(child: SpanText(item.spans)),
          ],
        ),
      ),
    ],
  );
}

class _ExercisePlaceholder extends StatelessWidget {
  const _ExercisePlaceholder(this.item);
  final ExerciseItem item;
  @override
  Widget build(BuildContext context) => StepScroll(
    children: [
      KindChip(context.l10n.sessionExercisePlaceholderTitle, icon: Icons.extension_rounded),
      const SizedBox(height: QSpace.md),
      SpanText(item.prompt, style: context.text.headlineSmall),
      const SizedBox(height: QSpace.lg),
      QCard(shadow: false, child: Text(context.l10n.sessionExercisePlaceholderBody, style: context.text.bodyMedium)),
    ],
  );
}
