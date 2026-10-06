import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/presentation/widgets/correct_answer.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

class OtherSessionResultView extends StatelessWidget {
  const OtherSessionResultView({
    super.key,
    required this.result,
    required this.session,
    required this.controller,
    required this.onContinue,
  });
  final SessionResult result;
  final Session session;
  final CharacterController controller;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext c) {
    final pretest = result.kind == 'pretest', review = result.kind == 'review', cards = review && session.mode == 'cards';
    final title = pretest
        ? c.l10n.sessionPretestThanks
        : review
        ? c.l10n.reviewReviewDone
        : result.passed == true
        ? c.l10n.sessionTestPassed
        : c.l10n.sessionTestTryAgain;
    return Scaffold(
      backgroundColor: QColors.morningMint,
      body: SafeArea(
        child: Stack(
          children: [
            if (review || result.passed == true) const Positioned.fill(child: EmberBurst(count: QCompletion.burst)),
            Column(
              children: [
                if (cards)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(QSpace.xs, QSpace.xs, QLesson.topEnd, QLesson.topBottom),
                    child: Row(
                      children: [
                        QIconButton(icon: Icons.close_rounded, tooltip: c.l10n.commonClose, onTap: onContinue),
                        const SizedBox(width: QLesson.smallGap),
                        const Expanded(child: ProgressTrack(value: 1, height: QLesson.progressHeight)),
                      ],
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (c, box) => SingleChildScrollView(
                      padding: const EdgeInsets.all(QSpace.page),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: box.maxHeight - QSpace.page * 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: CharacterView(size: QReview.companion, controller: controller),
                                ),
                                Reveal(
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: c.qText.display.copyWith(fontSize: QReview.displaySize),
                                  ),
                                ),
                                const SizedBox(height: QSpace.xs),
                                if (review) Text(c.l10n.reviewReviewDoneBody, textAlign: TextAlign.center, style: c.text.bodyMedium),
                                if (!pretest) ...[
                                  const SizedBox(height: QSpace.md),
                                  Center(
                                    child: Tag(
                                      c.l10n.commonPlusEmbers(c.n(result.xp)),
                                      icon: Icons.local_fire_department_rounded,
                                      color: QColors.gold800,
                                      background: QColors.gold100,
                                    ),
                                  ),
                                  if (!cards) ...[
                                    const SizedBox(height: QSpace.md),
                                    Text(
                                      c.l10n.sessionProgress(c.n(result.percent)),
                                      textAlign: TextAlign.center,
                                      style: c.text.titleLarge,
                                    ),
                                  ],
                                ],
                                if (result.nextStep?.title != null) ...[
                                  const SizedBox(height: QSpace.md),
                                  Text(result.nextStep!.title!, textAlign: TextAlign.center, style: c.text.titleSmall),
                                ],
                                if (result.unlocked.isNotEmpty && !pretest) ...[
                                  const SizedBox(height: QSpace.md),
                                  for (final item in result.unlocked) Text(item.title, style: c.text.bodyMedium),
                                ],
                                if (result.reviewItems.isNotEmpty) ...[
                                  const SizedBox(height: QSpace.lg),
                                  SectionHeader(c.l10n.sessionAnswerReview),
                                  for (final item in result.reviewItems)
                                    Builder(
                                      builder: (c) {
                                        final exercise = session.items
                                            .whereType<ExerciseItem>()
                                            .where((e) => e.exerciseId == item.exerciseId)
                                            .firstOrNull
                                            ?.exercise;
                                        if (exercise == null) return const SizedBox.shrink();
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: QSpace.sm),
                                          child: QCard(
                                            shadow: false,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      item.correct == true
                                                          ? Icons.check_circle_rounded
                                                          : item.correct == null
                                                          ? Icons.remove_circle_outline
                                                          : Icons.refresh_rounded,
                                                      color: item.correct == false ? QColors.retryInk : QColors.correct,
                                                    ),
                                                    const SizedBox(width: QSpace.xs),
                                                    Expanded(child: SpanText(exercise.prompt, style: c.text.titleSmall)),
                                                  ],
                                                ),
                                                if (item.correctAnswer != null) ...[
                                                  const SizedBox(height: QSpace.sm),
                                                  ...correctAnswerWidgets(c, exercise, item.correctAnswer!),
                                                ],
                                                if (item.explanation.isNotEmpty) ...[
                                                  const SizedBox(height: QSpace.sm),
                                                  SpanText(item.explanation, style: c.text.bodyMedium),
                                                ],
                                                if (item.sourceIds.isNotEmpty)
                                                  TextButton(
                                                    onPressed: () => c.read<ContentBloc>().add(SentenceSourcesOpened(item.sourceIds)),
                                                    child: Text(c.l10n.sessionSourcesTitle),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                                const SizedBox(height: QSpace.xl),
                                QButton(key: const ValueKey('result-continue'), label: c.l10n.commonContinue, onPressed: onContinue),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
