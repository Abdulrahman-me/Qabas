import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/domain/entities/session.dart';
import 'package:qabas/shared/lesson/presentation/exercises/exercise_views.dart';
import 'package:qabas/shared/lesson/presentation/lesson_preview_scope.dart';
import 'package:qabas/shared/lesson/presentation/steps/content_step_bloc.dart';
import 'package:qabas/shared/lesson/presentation/steps/content_step_views.dart';
import 'package:qabas/shared/lesson/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

final class PreviewState extends Equatable {
  const PreviewState(this.cursor);
  final int cursor;
  @override
  List<Object?> get props => [cursor];
}

final class PreviewItemChanged {
  const PreviewItemChanged(this.delta);
  final int delta;
}

final class LessonPreviewBloc extends Bloc<PreviewItemChanged, PreviewState> {
  LessonPreviewBloc(this.items) : super(const PreviewState(0)) {
    on<PreviewItemChanged>((e, emit) => emit(PreviewState((state.cursor + e.delta).clamp(0, items.length - 1))));
  }
  final List<SessionItem> items;
}

/// Learner renderer with local interactions only: no session, grading or rewards.
class LessonPreview extends StatelessWidget {
  const LessonPreview({super.key, required this.items, this.objectives = const [], this.completion});
  final List<SessionItem> items;
  final List<List<ContentSpan>> objectives;
  final LessonCompletion? completion;
  @override
  Widget build(BuildContext c) => LessonPreviewScope(
    child: ContentInteractions(
      child: items.isEmpty
          ? QEmptyView(art: QEmptyArt.unitArt, title: c.l10n.reviewerPreview, body: c.l10n.reviewerPreviewEmpty)
          : BlocProvider(
              create: (_) => LessonPreviewBloc(items),
              child: BlocBuilder<LessonPreviewBloc, PreviewState>(
                builder: (c, s) {
                  final item = items[s.cursor];
                  return Column(
                    children: [
                      if (s.cursor == 0 && objectives.isNotEmpty)
                        Flexible(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(QSpace.md),
                              child: Column(children: [for (final spans in objectives) SpanText(spans, style: c.text.bodyMedium)]),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 3,
                        child: item is ExerciseItem && item.exercise != null
                            ? BlocProvider(
                                key: ValueKey(item.blockId),
                                create: (_) => ExerciseStepBloc(item.exercise!),
                                child: BlocBuilder<ExerciseStepBloc, ExerciseStepState>(
                                  builder: (c, s) => SingleChildScrollView(
                                    child: ExerciseBody(exercise: item.exercise!, state: s, evaluation: null, locked: false),
                                  ),
                                ),
                              )
                            : BlocProvider(
                                key: ValueKey(item.blockId),
                                create: (_) => ContentStepBloc(item),
                                child: BlocBuilder<ContentStepBloc, ContentStepState>(
                                  builder: (c, s) => Column(
                                    children: [
                                      Expanded(child: contentStepView(item)),
                                      if (s.status != ContentStepStatus.completed)
                                        Padding(
                                          padding: const EdgeInsets.all(QSpace.sm),
                                          child: QButton(
                                            label: c.l10n.reviewerReveal,
                                            silent: true,
                                            tone: QButtonTone.ghost,
                                            onPressed: () => c.read<ContentStepBloc>().add(const CtaPressed()),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      if (s.cursor == items.length - 1 && completion != null)
                        Flexible(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(QSpace.sm),
                              child: SpanText(completion!.challenge, style: c.text.bodyMedium),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: QSpace.sm),
                        child: Text(
                          c.l10n.reviewerBlockPosition(s.cursor + 1, items.length),
                          textAlign: TextAlign.center,
                          style: c.text.labelMedium,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(QSpace.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: QButton(
                                label: c.l10n.commonBack,
                                silent: true,
                                tone: QButtonTone.ghost,
                                onPressed: s.cursor == 0 ? null : () => c.read<LessonPreviewBloc>().add(const PreviewItemChanged(-1)),
                              ),
                            ),
                            const SizedBox(width: QSpace.xs),
                            Expanded(
                              child: QButton(
                                label: c.l10n.commonNext,
                                silent: true,
                                tone: QButtonTone.ghost,
                                onPressed: s.cursor == items.length - 1
                                    ? null
                                    : () => c.read<LessonPreviewBloc>().add(const PreviewItemChanged(1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    ),
  );
}
