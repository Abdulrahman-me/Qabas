import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/glossary/presentation/glossary_bloc.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';

class GlossaryPage extends StatelessWidget {
  const GlossaryPage({super.key});
  @override
  Widget build(BuildContext context) => ContentInteractions(
    child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.reviewYourWords)),
      body: BlocConsumer<GlossaryBloc, GlossaryState>(
        listener: (c, s) {
          c.read<ContentBloc>().add(ContentReceived({for (final t in s.items) t.termId: t}, const []));
        },
        builder: (c, s) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(QSpace.page),
                  child: Wrap(
                    spacing: QSpace.xs,
                    runSpacing: QSpace.xs,
                    children: [
                      for (final filter in [
                        ('all', c.l10n.glossaryAll),
                        ('new', c.l10n.glossaryNew),
                        ('learning', c.l10n.glossaryLearning),
                        ('mastered', c.l10n.glossaryMastered),
                      ])
                        ChoiceChip(
                          label: Text(filter.$2),
                          selected: s.filter == filter.$1,
                          onSelected: (_) => c.read<GlossaryBloc>().add(GlossaryFilterSelected(filter.$1)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: s.items.isEmpty
                      ? switch (s.status) {
                          GlossaryStatus.loading || GlossaryStatus.initial => const QLoadingView(),
                          GlossaryStatus.failure => QErrorView(
                            kind: failureKind(s.failure!),
                            onRetry: () => c.read<GlossaryBloc>().add(const GlossaryOpened()),
                          ),
                          _ => QEmptyView(title: c.l10n.reviewYourWords, body: c.l10n.glossaryEmpty),
                        }
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(QSpace.page, 0, QSpace.page, QSpace.xxl),
                          itemCount: s.items.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: QSpace.xs),
                          itemBuilder: (c, i) {
                            if (i == s.items.length) {
                              return Column(
                                children: [
                                  if (s.status == GlossaryStatus.loading || s.paging) const QInlineLoading(),
                                  if (s.failure != null) Text(failureBody(s.failure!, c.l10n), style: c.text.bodySmall),
                                  if (s.cursor != null)
                                    QButton(
                                      key: const ValueKey('glossary-more'),
                                      label: s.failure == null ? c.l10n.glossaryLoadMore : c.l10n.commonRetry,
                                      tone: QButtonTone.ghost,
                                      onPressed: s.paging ? null : () => c.read<GlossaryBloc>().add(const GlossaryPageRequested()),
                                    ),
                                  if (s.failure != null && s.cursor == null)
                                    QButton(label: c.l10n.commonRetry, onPressed: () => c.read<GlossaryBloc>().add(const GlossaryOpened())),
                                ],
                              );
                            }
                            final term = s.items[i], known = term.state == TermState.mastered;
                            return QCard(
                              key: ValueKey('glossary-${term.termId}'),
                              shadow: false,
                              padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QSpace.sm),
                              onTap: () => c.read<ContentBloc>().add(TermOpened(term.termId)),
                              child: Row(
                                children: [
                                  RingProgress(
                                    value: known
                                        ? 1
                                        : term.state == TermState.learning
                                        ? .5
                                        : 0,
                                    size: QProfile.wordRing,
                                    stroke: QProfile.ringStroke,
                                    color: known ? QColors.correct : QColors.flameGold,
                                    child: known
                                        ? const Icon(Icons.check_rounded, size: QExercise.smallIcon, color: QColors.correct)
                                        : null,
                                  ),
                                  const SizedBox(width: QSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(term.text, style: c.text.titleSmall),
                                        Text(
                                          term.definition
                                              .map(
                                                (s) => switch (s) {
                                                  TextContentSpan(:final text) ||
                                                  StrongContentSpan(:final text) ||
                                                  TermContentSpan(:final text) => text,
                                                  _ => '',
                                                },
                                              )
                                              .join(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: c.text.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (term.arabic != null) ...[
                                    const SizedBox(width: QSpace.sm),
                                    Flexible(
                                      child: Text(
                                        term.arabic!,
                                        textDirection: TextDirection.rtl,
                                        style: QContentText.termArabic.copyWith(fontSize: QProfile.wordArabic),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
