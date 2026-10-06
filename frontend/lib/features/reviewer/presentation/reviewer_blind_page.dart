import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_shell.dart';

class ReviewerBlindPage extends StatelessWidget {
  const ReviewerBlindPage({super.key, required this.previewBuilder});
  final Widget Function(ReviewBlindLesson) previewBuilder;
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: QColors.morningMint,
    appBar: AppBar(title: Text(c.l10n.reviewerBlindTest), actions: const [ReviewerLanguageMenu()]),
    body: BlocBuilder<ReviewerBlindBloc, BlindState>(
      builder: (c, s) {
        if (s.status == ReviewerStatus.failure) {
          return QErrorView(kind: failureKind(s.failure!), onRetry: () => c.read<ReviewerBlindBloc>().add(const BlindOpened()));
        }
        if (s.status == ReviewerStatus.loading || s.status == ReviewerStatus.initial) return const QLoadingView();
        if (s.pair == null) return QEmptyView(art: QEmptyArt.unitArt, title: c.l10n.reviewerBlindTest, body: c.l10n.reviewerBlindEmpty);
        Widget lesson(String label, ReviewBlindLesson lesson) => QCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: c.text.titleLarge),
              Text(lesson.title, style: c.text.titleMedium),
              SizedBox(
                height: QReviewer.previewHeight,
                child: KeyedSubtree(key: ValueKey('${s.pair!.pairId}/$label/${lesson.title}'), child: previewBuilder(lesson)),
              ),
            ],
          ),
        );
        return ListView(
          padding: const EdgeInsets.all(QSpace.page),
          children: [
            LayoutBuilder(
              builder: (c, box) {
                final a = lesson(c.l10n.reviewerLessonA, s.pair!.lessonA), b = lesson(c.l10n.reviewerLessonB, s.pair!.lessonB);
                final wide = box.maxWidth >= QBreakpoints.rail;
                return Wrap(
                  spacing: QSpace.md,
                  runSpacing: QSpace.md,
                  children: [
                    for (final child in [a, b]) SizedBox(width: wide ? (box.maxWidth - QSpace.md) / 2 : box.maxWidth, child: child),
                  ],
                );
              },
            ),
            const SizedBox(height: QSpace.lg),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: QSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text([c.l10n.reviewerClearer, c.l10n.reviewerAccurate, c.l10n.reviewerHandwritten][i], style: c.text.titleMedium),
                    QSegmentedChips<String>(
                      options: {
                        'a': c.l10n.reviewerLessonA,
                        'b': c.l10n.reviewerLessonB,
                        (i == 2 ? 'unsure' : 'same'): i == 2 ? c.l10n.reviewerUnsure : c.l10n.reviewerSame,
                      },
                      selected: [s.clearer, s.accurate, s.handwritten][i] ?? '',
                      onSelected: (v) {
                        if (s.status == ReviewerStatus.ready) c.read<ReviewerBlindBloc>().add(BlindChoicePicked(i, v));
                      },
                    ),
                  ],
                ),
              ),
            if (s.failure != null) Text(failureBody(s.failure!, c.l10n)),
            QButton(
              label: c.l10n.reviewerSubmit,
              silent: true,
              onPressed: s.complete && s.status == ReviewerStatus.ready
                  ? () => c.read<ReviewerBlindBloc>().add(const BlindAnswerSubmitted())
                  : null,
            ),
          ],
        );
      },
    ),
  );
}
