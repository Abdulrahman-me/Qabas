import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_reader_bloc.dart';
import 'package:qabas/features/session/presentation/steps/content_step_bloc.dart';
import 'package:qabas/features/session/presentation/steps/content_step_views.dart';
import 'package:qabas/features/session/presentation/widgets/step_scaffold.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

class LessonReaderPage extends StatelessWidget {
  const LessonReaderPage({super.key, required this.lessonId});
  final String lessonId;
  @override
  Widget build(BuildContext c) => ContentInteractions(
    child: BlocConsumer<LessonReaderBloc, ReaderState>(
      listener: (c, s) {
        if (s.lesson != null) c.read<ContentBloc>().add(ContentReceived(s.lesson!.terms, s.lesson!.sources));
      },
      builder: (c, s) => Scaffold(
        backgroundColor: QColors.morningMint,
        appBar: AppBar(
          title: Text(s.lesson?.title ?? c.l10n.sessionReadLesson),
          actions: [
            if (s.lesson?.sources.isNotEmpty == true)
              QIconButton(
                icon: Icons.menu_book_outlined,
                tooltip: c.l10n.sessionSourcesTitle,
                onTap: () => c.read<ContentBloc>().add(const SentenceSourcesOpened(null)),
              ),
          ],
        ),
        body: s.status == ReaderStatus.failure
            ? QErrorView(kind: failureKind(s.failure!), onRetry: () => c.read<LessonReaderBloc>().add(ReaderOpened(lessonId)))
            : s.status != ReaderStatus.ready
            ? const QLoadingView()
            : s.item == null
            ? QEmptyView(title: c.l10n.sessionReadLesson, body: c.l10n.sessionReaderEmpty)
            : Column(
                children: [
                  Expanded(
                    child: BlocProvider<ContentStepBloc>(
                      key: ValueKey(s.item!.blockId),
                      create: (_) {
                        final item = s.item!;
                        return ContentStepBloc(
                          item,
                          initial: ContentStepState(
                            shown: item is TeachItem ? item.points.length : 1,
                            status: item is PredictItem ? ContentStepStatus.feedback : ContentStepStatus.ready,
                          ),
                        );
                      },
                      child: _ReaderBlock(item: s.item!),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(QSpace.page, QSpace.md, QSpace.page, QSpace.md + MediaQuery.paddingOf(c).bottom),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                        child: Row(
                          children: [
                            Expanded(
                              child: QButton(
                                key: const ValueKey('reader-previous'),
                                label: c.l10n.commonBack,
                                tone: QButtonTone.ghost,
                                onPressed: s.cursor == 0 ? null : () => c.read<LessonReaderBloc>().add(const ReaderItemChanged(-1)),
                              ),
                            ),
                            const SizedBox(width: QSpace.sm),
                            Expanded(
                              child: QButton(
                                key: const ValueKey('reader-next'),
                                label: c.l10n.commonNext,
                                onPressed: s.cursor + 1 == s.lesson!.items.length
                                    ? null
                                    : () => c.read<LessonReaderBloc>().add(const ReaderItemChanged(1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _ReaderBlock extends StatelessWidget {
  const _ReaderBlock({required this.item});
  final SessionItem item;
  @override
  Widget build(BuildContext c) => BlocBuilder<ContentStepBloc, ContentStepState>(
    builder: (c, s) => Column(
      children: [
        Expanded(
          child: item is PredictItem
              ? StepScroll(
                  children: [
                    SpanText((item as PredictItem).prompt, style: c.text.headlineSmall),
                    if ((item as PredictItem).visual != null) ...[
                      const SizedBox(height: QSpace.md),
                      VisualView((item as PredictItem).visual!, use: VisualUse.predict),
                    ],
                    const SizedBox(height: QSpace.md),
                    SpanText((item as PredictItem).reveal, style: c.text.bodyLarge),
                  ],
                )
              : contentStepView(item),
        ),
        if (item is StoryItem && s.status != ContentStepStatus.completed)
          Padding(
            padding: const EdgeInsets.all(QSpace.page),
            child: QButton(
              label: c.l10n.commonNext,
              tone: QButtonTone.ghost,
              onPressed: () => c.read<ContentStepBloc>().add(const CtaPressed()),
            ),
          ),
      ],
    ),
  );
}
