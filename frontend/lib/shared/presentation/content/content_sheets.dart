import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

String sourceKindLabel(BuildContext c, SourceKind kind) => switch (kind) {
  SourceKind.quran => c.l10n.contentQuranLabel,
  SourceKind.hadith => c.l10n.contentHadithLabel,
  SourceKind.tafsir => c.l10n.contentTafsir,
  SourceKind.article => c.l10n.contentArticle,
  SourceKind.book => c.l10n.contentBook,
  SourceKind.fatwa => c.l10n.contentFatwa,
  SourceKind.unknown => c.l10n.contentSource,
};
String sourceProviderLabel(BuildContext c, SourceProvider provider) => switch (provider) {
  SourceProvider.tafsirCenter => c.l10n.contentProviderTafsirCenter,
  SourceProvider.quranCom => c.l10n.contentProviderQuranCom,
  SourceProvider.hadeethenc => c.l10n.contentProviderHadeethenc,
  SourceProvider.quranenc => c.l10n.contentProviderQuranenc,
  SourceProvider.islamhouse => c.l10n.contentProviderIslamhouse,
  SourceProvider.dorar => c.l10n.contentProviderDorar,
  SourceProvider.unknown => c.l10n.contentSource,
};

class ContentInteractions extends StatelessWidget {
  const ContentInteractions({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => BlocListener<ContentBloc, ContentState>(
    listenWhen: (a, b) => a.serial != b.serial || (a.status != b.status && b.status == ContentStatus.failure),
    listener: (context, state) {
      if (state.status == ContentStatus.failure) {
        showQSnack(context, state.operation == ContentOperation.source ? context.l10n.errorGenericBody : context.l10n.contentAudioError);
        return;
      }
      final bloc = context.read<ContentBloc>();
      if (state.selectedTerm case final TermCard term) {
        unawaited(
          showQSheet<void>(
            context,
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: TermSheet(term: term),
            ),
          ),
        );
      } else if (state.selectedSources case final List<Source> sources) {
        unawaited(
          showQSheet<void>(
            context,
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: SourcesSheet(sources: sources),
            ),
          ),
        );
      } else if (state.lessonToOpen case final String id) {
        context.push('/lesson/${Uri.encodeComponent(id)}/intro');
      }
    },
    child: child,
  );
}

class TermSheet extends StatelessWidget {
  const TermSheet({super.key, required this.term});
  final TermCard term;
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ContentBloc>();
    final source = bloc.state.sources.where((s) => s.sourceId == term.sourceId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: QSpace.xs,
          runSpacing: QSpace.xs,
          children: [
            Text(context.l10n.glossaryYourDictionary.toUpperCase(), style: context.qText.eyebrow),
            Tag(
              switch (term.level) {
                TermLevel.basic => context.l10n.contentLevelBasic,
                TermLevel.intermediate => context.l10n.contentLevelIntermediate,
                TermLevel.unknown => context.l10n.contentLevelUnknown,
              },
              icon: Icons.tune_rounded,
              color: QColors.gold800,
              background: QColors.gold100,
            ),
          ],
        ),
        const SizedBox(height: QSpace.md),
        Container(
          padding: const EdgeInsets.all(QSpace.lg),
          decoration: BoxDecoration(
            color: QColors.emerald50,
            borderRadius: QRadius.card,
            border: Border.all(color: QColors.emerald100, width: 1.5),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: QSpace.sm,
              runSpacing: QSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: box.maxWidth * (term.arabic == null ? 0.85 : 0.48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(term.text, style: context.text.headlineMedium),
                      const SizedBox(height: 2),
                      Text(
                        term.transliteration,
                        style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: QColors.emerald500),
                      ),
                    ],
                  ),
                ),
                if (term.arabic != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth),
                    child: Text(term.arabic!, textDirection: TextDirection.rtl, style: QContentText.termArabic),
                  ),
                if (term.pronunciationAudioUrl != null)
                  QIconButton(
                    icon: Icons.volume_up_rounded,
                    tooltip: context.l10n.glossaryListen,
                    color: QColors.emerald500,
                    background: QColors.surface,
                    onTap: () => bloc.add(ContentAudioPlayed(term.pronunciationAudioUrl!)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: QSpace.lg),
        SpanText(term.definition, style: context.text.bodyLarge?.copyWith(fontSize: QLesson.body)),
        if (term.example.isNotEmpty) ...[
          const SizedBox(height: QSpace.md),
          QCard(
            color: QColors.surfaceSunk,
            shadow: false,
            borderColor: null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: QColors.flameGold, size: 22),
                const SizedBox(width: QSpace.xs),
                Expanded(
                  child: SpanText(term.example, style: context.text.bodyMedium?.copyWith(color: QColors.deepInk)),
                ),
              ],
            ),
          ),
        ],
        if (source != null) ...[const SizedBox(height: QSpace.md), Text(source.reference, style: context.text.bodySmall)],
        const SizedBox(height: QSpace.md),
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: QColors.muted),
            const SizedBox(width: QLesson.smallGap),
            Expanded(child: Text(context.l10n.glossaryUnderlineHint, style: context.text.bodySmall)),
          ],
        ),
        if (term.lessonId != null) ...[
          const SizedBox(height: QSpace.lg),
          QButton(
            label: context.l10n.contentLearnMore,
            tone: QButtonTone.outline,
            onPressed: () {
              Navigator.pop(context);
              bloc.add(TermLessonOpened(term.lessonId!));
            },
          ),
        ],
      ],
    );
  }
}

class SourcesSheet extends StatelessWidget {
  const SourcesSheet({super.key, required this.sources});
  final List<Source> sources;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.l10n.sessionSourcesTitle, style: context.text.headlineSmall),
      const SizedBox(height: QSpace.md),
      for (final source in sources)
        Padding(
          padding: const EdgeInsets.only(bottom: QSpace.md),
          child: QCard(
            shadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: QSpace.xs,
                  runSpacing: QSpace.xs,
                  children: [
                    Tag(sourceKindLabel(context, source.kind), color: QColors.emerald500, background: QColors.emerald50),
                    Tag(sourceProviderLabel(context, source.provider), color: QColors.slate),
                  ],
                ),
                const SizedBox(height: QSpace.sm),
                Text(source.title, style: context.text.titleMedium),
                if (source.reference != source.title) Text(source.reference, style: context.text.bodySmall),
                const SizedBox(height: QSpace.sm),
                Text(source.excerpt, style: context.text.bodyMedium?.copyWith(color: QColors.deepInk)),
                if (source.url != null)
                  TextButton.icon(
                    onPressed: () => context.read<ContentBloc>().add(SourceLinkOpened(source.url!)),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(context.l10n.contentViewSource),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
