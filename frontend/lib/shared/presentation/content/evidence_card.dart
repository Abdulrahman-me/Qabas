import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';

class QuranText extends StatelessWidget {
  const QuranText(this.evidence, {super.key});
  final QuranEvidence evidence;
  @override
  Widget build(BuildContext context) {
    final quoted = '﴿${evidence.textUthmani}﴾';
    return Text(quoted, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: context.qText.quran);
  }
}

class HadithText extends StatelessWidget {
  const HadithText(this.evidence, {super.key});
  final HadithEvidence evidence;
  @override
  Widget build(BuildContext context) {
    final quoted = '«${evidence.textAr}»';
    return Text(quoted, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: context.qText.hadith);
  }
}

class EvidenceCard extends StatelessWidget {
  const EvidenceCard({super.key, required this.evidence, this.compact = false});
  final Evidence evidence;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final quran = evidence is QuranEvidence;
    final source = context.watch<ContentBloc>().state.sources.where((s) => s.sourceId == evidence.evidenceId).firstOrNull;
    final translation = switch (evidence) {
      QuranEvidence(:final translation) || HadithEvidence(:final translation) => translation,
      _ => null,
    };
    return Container(
      decoration: BoxDecoration(
        color: QColors.surface,
        borderRadius: QRadius.card,
        border: Border.all(color: QColors.line, width: 1.5),
        boxShadow: QShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: QLesson.sourcesStripe, color: quran ? QColors.emerald400 : QColors.flameGold),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(QSpace.md, QSpace.md, QSpace.md, QSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: QLesson.smallGap,
                      runSpacing: QLesson.smallGap,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Tag(
                          switch (evidence) {
                            QuranEvidence() => context.l10n.contentQuranLabel,
                            HadithEvidence() => context.l10n.contentHadithLabel,
                            _ => context.l10n.contentSource,
                          },
                          icon: quran ? Icons.menu_book_rounded : Icons.format_quote_rounded,
                          color: quran ? QColors.emerald500 : QColors.gold800,
                          background: quran ? QColors.emerald50 : QColors.gold100,
                        ),
                        if (evidence case HadithEvidence(:final gradeLabel))
                          Tag(gradeLabel, icon: Icons.verified_rounded, color: QColors.correct, background: QColors.correctSoft),
                      ],
                    ),
                    if (evidence case HadithEvidence(:final narrator)) ...[
                      const SizedBox(height: QSpace.sm),
                      if (!compact) Text(narrator, style: context.text.bodySmall),
                    ],
                    const SizedBox(height: QSpace.sm),
                    switch (evidence) {
                      final QuranEvidence q => QuranText(q),
                      final HadithEvidence h => HadithText(h),
                      _ => Text(context.l10n.contentSource, style: context.text.bodyMedium),
                    },
                    if (translation != null) ...[
                      const SizedBox(height: QSpace.sm),
                      const DottedLine(color: QColors.line),
                      const SizedBox(height: QSpace.sm),
                      Text(translation, style: context.text.bodyMedium?.copyWith(color: QColors.deepInk.withValues(alpha: 0.82))),
                    ],
                    const SizedBox(height: QSpace.xs),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: QSpace.xs,
                      runSpacing: QSpace.xs,
                      children: [
                        Text(
                          source?.reference ??
                              switch (evidence) {
                                final QuranEvidence q => '${q.surahName}: ${context.n(q.ayahStart)}–${context.n(q.ayahEnd)}',
                                final HadithEvidence h => h.collections.join(' · '),
                                _ => context.l10n.contentSource,
                              },
                          style: context.text.labelMedium?.copyWith(color: QColors.slate),
                        ),
                        if (source?.url != null)
                          Pressable(
                            onTap: () => context.read<ContentBloc>().add(SourceLinkOpened(source.url!)),
                            semanticLabel: context.l10n.contentViewSource,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: QLesson.smallGap),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      sourceProviderLabel(context, source!.provider),
                                      style: context.text.labelMedium?.copyWith(color: QColors.emerald500),
                                    ),
                                  ),
                                  const SizedBox(width: QLesson.linkGap),
                                  const Icon(Icons.open_in_new_rounded, size: 14, color: QColors.emerald500),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
