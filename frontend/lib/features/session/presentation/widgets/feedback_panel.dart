import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/presentation/widgets/correct_answer.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

/// The prototype panel in neutral, emerald and clay states.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.reveal, required this.onContinue})
    : evaluation = null,
      exercise = null,
      characterController = null;
  const FeedbackPanel.exercise({
    super.key,
    required AnswerEvaluation this.evaluation,
    required this.exercise,
    required this.onContinue,
    this.characterController,
  }) : reveal = const [];
  final AnswerEvaluation? evaluation;
  final Exercise? exercise;
  final CharacterController? characterController;
  final List<ContentSpan> reveal;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final correct = evaluation?.correct;
    final prediction = evaluation == null;
    final ink = prediction
        ? QColors.gold800
        : correct == true
        ? QColors.correct
        : correct == false
        ? QColors.retryInk
        : QColors.gold800;
    final bg = prediction
        ? QColors.gold50
        : correct == true
        ? QColors.correctSoft
        : correct == false
        ? QColors.retrySoft
        : QColors.gold50;
    final cue = correct == true
        ? CharacterCue.correct
        : correct == false
        ? CharacterCue.retry
        : CharacterCue.encourage;
    final praise = [
      context.l10n.sessionPraise1,
      context.l10n.sessionPraise2,
      context.l10n.sessionPraise3,
      context.l10n.sessionPraise4,
      context.l10n.sessionPraise5,
    ];
    final gentle = [context.l10n.sessionGentle1, context.l10n.sessionGentle2, context.l10n.sessionGentle3];
    final seed = evaluation?.exerciseId.codeUnits.fold<int>(0, (a, b) => a + b) ?? 0;
    final title = prediction
        ? context.l10n.sessionNiceThinking
        : correct == null
        ? context.l10n.sessionSkipped
        : correct
        ? praise[seed % praise.length]
        : gentle[seed % gentle.length];
    final spans = evaluation?.explanation ?? reveal;
    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(QSpace.page, QSpace.md, QSpace.page, QSpace.md + MediaQuery.paddingOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: QSizes.feedbackCompanionWidth,
                        height: QSizes.feedbackCompanionHeight,
                        child: CharacterView(
                          size: QSizes.feedbackCompanionHeight,
                          aspect: QLesson.feedbackAspect,
                          zoom: QLesson.companionZoom,
                          controller: characterController,
                          appearCue: characterController == null ? cue : null,
                        ),
                      ),
                      const SizedBox(width: QSpace.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Row(
                                children: [
                                  Container(
                                    width: QSizes.optionBadge,
                                    height: QSizes.optionBadge,
                                    decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
                                    child: Icon(
                                      correct == true ? Icons.check_rounded : Icons.lightbulb_outline_rounded,
                                      color: QColors.surface,
                                      size: QLesson.interfaceIcon,
                                    ),
                                  ),
                                  const SizedBox(width: QSpace.xs),
                                  Flexible(
                                    child: Text(title, style: context.text.headlineSmall?.copyWith(color: ink)),
                                  ),
                                ],
                              ),
                            ),
                            if (correct == false && evaluation?.correctAnswer != null && exercise != null) ...[
                              const SizedBox(height: QSpace.xs),
                              Text(context.l10n.sessionCorrectAnswerIs, style: context.text.labelMedium?.copyWith(color: ink)),
                              ...correctAnswerWidgets(context, exercise!, evaluation!.correctAnswer!, details: evaluation!.details),
                            ],
                            if (spans.isNotEmpty) const SizedBox(height: QSpace.xs),
                            if (spans.isNotEmpty)
                              SpanText(
                                spans,
                                style: context.text.bodyMedium?.copyWith(
                                  color: QColors.deepInk.withValues(alpha: QLesson.feedbackInkAlpha),
                                  height: context.isArabic ? QLesson.feedbackArabicHeight : QLesson.feedbackLatinHeight,
                                ),
                              ),
                            if (evaluation?.sourceIds.isNotEmpty ?? false)
                              TextButton(
                                onPressed: () => context.read<ContentBloc>().add(SentenceSourcesOpened(evaluation!.sourceIds)),
                                child: Text(context.l10n.sessionSourcesTitle),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (evaluation?.misconception case final m?) ...[
                const SizedBox(height: QSpace.sm),
                Flexible(
                  child: SingleChildScrollView(
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
                          Text(context.l10n.sessionRemediation, style: context.text.labelMedium?.copyWith(color: QColors.retryInk)),
                          const SizedBox(height: QSpace.xs),
                          Text(m.title, style: context.text.titleSmall),
                          if (m.card.isNotEmpty) ...[const SizedBox(height: QSpace.xs), SpanText(m.card, style: context.text.bodyMedium)],
                          if (m.sourceIds.isNotEmpty)
                            TextButton(
                              onPressed: () => context.read<ContentBloc>().add(SentenceSourcesOpened(m.sourceIds)),
                              child: Text(context.l10n.sessionSourcesTitle),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: QSpace.md),
              QButton(
                key: ValueKey(prediction ? 'predict-continue' : 'feedback-continue'),
                label: context.l10n.commonContinue,
                tone: prediction || correct == null
                    ? QButtonTone.gold
                    : correct
                    ? QButtonTone.correct
                    : QButtonTone.retry,
                onPressed: onContinue,
                silent: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
