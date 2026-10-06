import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/chat_widgets.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/evidence_card.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

class AnswerBubble extends StatefulWidget {
  const AnswerBubble({
    super.key,
    required this.turn,
    required this.controller,
    required this.onRetry,
    required this.onRate,
    this.rating,
    this.ratingBusy = false,
    this.ratingFailure,
  });
  final ChatTurn turn;
  final CharacterController controller;
  final VoidCallback onRetry;
  final ValueChanged<AnswerRating> onRate;
  final AnswerRating? rating;
  final bool ratingBusy;
  final Failure? ratingFailure;
  @override
  State<AnswerBubble> createState() => _AnswerBubbleState();
}

class _AnswerBubbleState extends State<AnswerBubble> {
  final _citations = <int, GlobalKey>{};
  bool _expanded = false;
  void _citation(int ref) {
    final c = _citations[ref]?.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: context.reduceMotion ? Duration.zero : QMotion.slow, alignment: 0.3);
  }

  Widget _spans(List<ContentSpan> spans, CompletedMessage message) => SpanText(
    spans,
    style: context.text.bodyLarge?.copyWith(fontSize: QRaqeeb.answerFont),
    onCitation: _citation,
    citationBadge: true,
    terms: message.terms,
  );
  Widget _motionSize(BuildContext c, {required Widget child}) => c.reduceMotion
      ? child
      : AnimatedSize(duration: QMotion.medium, curve: QMotion.emphasized, alignment: Alignment.topCenter, child: child);
  @override
  Widget build(BuildContext c) {
    final m = widget.turn.assistant;
    final failure = widget.turn.failure;
    Widget body;
    if (failure != null || m is FailedMessage) {
      final text = failure is RaqeebTimeoutFailure
          ? c.l10n.raqeebTimeout
          : m is FailedMessage
          ? c.l10n.raqeebFailed
          : failureBody(failure!, c.l10n);
      body = Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, style: c.text.bodyMedium?.copyWith(color: QColors.retryInk)),
            const SizedBox(height: QSpace.sm),
            QButton(
              key: ValueKey('raqeeb-retry-${widget.turn.key}'),
              label: c.l10n.commonRetry,
              tone: QButtonTone.light,
              onPressed: widget.onRetry,
            ),
          ],
        ),
      );
    } else if (m is ProcessingMessage) {
      body = Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TypingDots(),
            const SizedBox(width: QRaqeeb.thinkingGap),
            Flexible(
              child: Text(stageLabel(c, m.stage), key: const ValueKey('raqeeb-stage'), style: c.text.bodySmall),
            ),
          ],
        ),
      );
    } else if (m is CompletedMessage) {
      final understood = m.understoodInput;
      final rating = widget.rating ?? m.feedback;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            key: ValueKey('raqeeb-understood-${m.messageId}'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: QSpace.xs),
              child: Row(
                children: [
                  Expanded(child: Text(c.l10n.raqeebUnderstood, style: c.text.labelMedium)),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: QColors.slate),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: QSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (understood.transcript != null) Text(understood.transcript!, style: c.text.bodyMedium),
                  for (final image in understood.images) ...[
                    Text(image.extractedText, style: c.text.bodyMedium),
                    Text(image.description, style: c.text.bodySmall),
                  ],
                  if (understood.document case final UnderstoodDocument doc) ...[
                    Text(doc.filename, style: c.text.titleSmall),
                    Text(doc.summary, style: c.text.bodyMedium),
                    if (doc.truncated) Text(c.l10n.raqeebTruncated, style: c.text.bodySmall),
                  ],
                  if (understood.transcript == null && understood.images.isEmpty && understood.document == null)
                    Text(c.l10n.raqeebTextOnly, style: c.text.bodySmall),
                ],
              ),
            ),
          Wrap(
            spacing: QSpace.xs,
            runSpacing: QSpace.xs,
            children: [
              Tag(m.classification.label, color: QColors.emerald500, background: QColors.emerald50),
              if (m.abstained) Tag(c.l10n.raqeebAbstained, color: QColors.slate, background: QColors.surfaceSunk),
            ],
          ),
          const SizedBox(height: QSpace.sm),
          for (final (i, block) in m.blocks.indexed)
            Reveal(
              key: ValueKey('${m.messageId}-block-$i'),
              delay: QRaqeeb.stagger * i,
              offset: const Offset(0, QSpace.xs),
              child: Padding(
                padding: const EdgeInsets.only(bottom: QSpace.sm),
                child: switch (block) {
                  ParagraphAnswer(:final spans) => _spans(spans, m),
                  EvidenceAnswer(:final evidence) => EvidenceCard(evidence: evidence),
                  VerificationAnswer(:final items) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: QSpace.xs),
                          child: VerificationCard(item: item, onCitation: _citation, terms: m.terms),
                        ),
                    ],
                  ),
                  ViewsAnswer(:final intro, :final views) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _spans(intro, m),
                      for (final view in views) ...[
                        const SizedBox(height: QSpace.sm),
                        Text(view.holder, style: c.text.titleSmall),
                        _spans(view.spans, m),
                        SourceReferences(ids: view.sourceIds, citations: m.citations, onCitation: _citation),
                      ],
                    ],
                  ),
                  ReferralAnswer(:final referral) => ReferralCard(referral: referral, onCitation: _citation, terms: m.terms),
                },
              ),
            ),
          if (m.citations.isNotEmpty) ...[
            Text(c.l10n.raqeebSources.toUpperCase(), style: c.qText.eyebrow),
            const SizedBox(height: QSpace.xs),
            for (final citation in m.citations)
              Padding(
                key: _citations.putIfAbsent(citation.ref, GlobalKey.new),
                padding: const EdgeInsets.only(bottom: QSpace.xs),
                child: CitationCard(citation: citation),
              ),
          ],
          if (m.suggestedLessons.isNotEmpty) ...[
            const SizedBox(height: QSpace.sm),
            Text(c.l10n.raqeebLearnMore, style: c.text.titleSmall),
            const SizedBox(height: QSpace.xs),
            for (final lesson in m.suggestedLessons)
              Padding(
                padding: const EdgeInsets.only(bottom: QSpace.xs),
                child: SuggestionChip(
                  key: ValueKey('raqeeb-lesson-${lesson.lessonId}'),
                  text: lesson.title,
                  onTap: () => c.push('/lesson/${Uri.encodeComponent(lesson.lessonId)}/intro'),
                  wide: true,
                ),
              ),
          ],
          Wrap(
            spacing: QSpace.xs,
            children: [
              for (final (value, icon, label) in [
                (AnswerRating.up, Icons.thumb_up_outlined, c.l10n.raqeebRateUp),
                (AnswerRating.down, Icons.thumb_down_outlined, c.l10n.raqeebRateDown),
              ])
                Semantics(
                  selected: rating == value,
                  child: QIconButton(
                    key: ValueKey('raqeeb-rate-${m.messageId}-${value.name}'),
                    icon: icon,
                    tooltip: label,
                    color: rating == value ? QColors.emerald500 : QColors.slate,
                    background: rating == value ? QColors.emerald50 : QColors.surface,
                    onTap: widget.ratingBusy ? null : () => widget.onRate(value),
                  ),
                ),
            ],
          ),
          if (widget.ratingFailure != null) QInlineError(message: c.l10n.raqeebRateFailed),
        ],
      );
    } else {
      body = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: QSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: QRaqeeb.answerAvatar,
            height: QRaqeeb.answerAvatar,
            margin: const EdgeInsetsDirectional.only(end: QSpace.xs, top: QSpace.xxs),
            decoration: const BoxDecoration(color: QColors.nightEmerald, shape: BoxShape.circle),
            child: Center(
              child: CharacterView(
                role: CharacterRole.assistant,
                size: QRaqeeb.answerGlyph,
                tint: QColors.softEmber,
                controller: m is ProcessingMessage ? widget.controller : null,
              ),
            ),
          ),
          Expanded(
            child: _motionSize(
              c,
              child: Container(
                padding: const EdgeInsets.all(QSpace.md),
                decoration: BoxDecoration(
                  color: QColors.surface,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(QRaqeeb.tail),
                    topEnd: Radius.circular(QRadius.lg),
                    bottomStart: Radius.circular(QRadius.lg),
                    bottomEnd: Radius.circular(QRadius.lg),
                  ),
                  border: Border.all(color: QColors.line, width: QRaqeeb.border),
                  boxShadow: QShadows.soft,
                ),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CitationCard extends StatelessWidget {
  const CitationCard({super.key, required this.citation});
  final Citation citation;
  @override
  Widget build(BuildContext c) {
    final s = citation.source;
    return Container(
      padding: const EdgeInsets.all(QSpace.sm),
      decoration: BoxDecoration(
        color: QColors.surfaceSunk,
        borderRadius: BorderRadius.circular(QRadius.md),
        border: Border.all(color: QColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: QRaqeeb.sourceBadge,
                height: QRaqeeb.sourceBadge,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: QColors.gold100, borderRadius: BorderRadius.circular(QRaqeeb.citationRadius)),
                child: Text(c.n(citation.ref), style: c.text.labelSmall?.copyWith(color: QColors.gold800, letterSpacing: 0)),
              ),
              const SizedBox(width: QSpace.xs),
              Icon(
                s.kind == SourceKind.quran ? Icons.menu_book_rounded : Icons.format_quote_rounded,
                size: QRaqeeb.sourceIcon,
                color: QColors.emerald500,
              ),
              const SizedBox(width: QSpace.xxs),
              Expanded(child: Text(s.title, style: c.text.titleSmall)),
            ],
          ),
          if (s.excerpt.isNotEmpty) ...[const SizedBox(height: QRaqeeb.smallGap), Text(s.excerpt, style: c.text.bodyMedium)],
          const SizedBox(height: QSpace.xxs),
          Row(
            children: [
              Expanded(child: Text(s.reference, style: c.text.bodySmall)),
              if (s.url != null)
                QIconButton(
                  icon: Icons.open_in_new_rounded,
                  tooltip: c.l10n.contentViewSource,
                  color: QColors.emerald500,
                  onTap: () => c.read<ContentBloc>().add(SourceLinkOpened(s.url!)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// TODO(contract): A-04 — fabricated is explicit clay; not-found stays neutral grey.
(Color, Color, String) verificationStyle(BuildContext c, VerificationItem item) => switch (item.status) {
  VerificationStatus.quranExact => (QColors.statusVerified, QColors.statusVerifiedSoft, c.l10n.raqeebQuranExact),
  VerificationStatus.quranInexact => (QColors.statusCaution, QColors.statusCautionSoft, c.l10n.raqeebQuranInexact),
  VerificationStatus.notFound => (QColors.statusUnknown, QColors.statusUnknownSoft, c.l10n.raqeebNotFound),
  VerificationStatus.needsSpecialist => (QColors.statusSpecialist, QColors.statusSpecialistSoft, c.l10n.raqeebNeedsSpecialist),
  VerificationStatus.hadithGraded => switch (item.hadithGrade?.gradeCategory) {
    HadithGrade.authentic => (QColors.statusVerified, QColors.statusVerifiedSoft, c.l10n.raqeebAuthentic),
    HadithGrade.acceptable => (QColors.statusVerified, QColors.statusVerifiedSoft, c.l10n.raqeebAcceptable),
    HadithGrade.weak => (QColors.statusCaution, QColors.statusCautionSoft, c.l10n.raqeebWeak),
    HadithGrade.fabricated => (QColors.statusFabricated, QColors.statusFabricatedSoft, c.l10n.raqeebFabricated),
    _ => (QColors.statusUnknown, QColors.statusUnknownSoft, c.l10n.raqeebGradeOther),
  },
  _ => (QColors.statusUnknown, QColors.statusUnknownSoft, c.l10n.raqeebGradeOther),
};

class VerificationCard extends StatelessWidget {
  const VerificationCard({super.key, required this.item, this.onCitation, this.terms = const {}});
  final VerificationItem item;
  final ValueChanged<int>? onCitation;
  final Map<String, TermCard> terms;
  @override
  Widget build(BuildContext c) {
    final (ink, soft, label) = verificationStyle(c, item);
    final verified =
        item.status == VerificationStatus.quranExact ||
        item.status == VerificationStatus.hadithGraded &&
            [HadithGrade.authentic, HadithGrade.acceptable].contains(item.hadithGrade?.gradeCategory);
    Widget field(String name, String text) => Padding(
      padding: const EdgeInsets.only(top: QSpace.xxs),
      child: LayoutBuilder(
        builder: (_, box) => box.maxWidth < QRaqeeb.fieldStackWidth
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: c.text.labelMedium?.copyWith(color: QColors.slate)),
                  Text(text, style: c.text.labelMedium?.copyWith(color: QColors.deepInk)),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: QRaqeeb.fieldLabel,
                    child: Text(name, style: c.text.labelMedium?.copyWith(color: QColors.slate)),
                  ),
                  Expanded(
                    child: Text(text, style: c.text.labelMedium?.copyWith(color: QColors.deepInk)),
                  ),
                ],
              ),
      ),
    );
    return Container(
      key: ValueKey('verification-${item.itemId}'),
      padding: const EdgeInsets.all(QSpace.sm),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(QRadius.md),
        border: Border.all(
          color: ink.withValues(alpha: QRaqeeb.glowOpacity),
          width: QRaqeeb.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: QRaqeeb.smallGap,
            runSpacing: QSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, color: ink, size: QRaqeeb.verificationIcon),
                  const SizedBox(width: QRaqeeb.smallGap),
                  Flexible(
                    child: Text(c.l10n.raqeebAuthenticityCheck, style: c.text.titleSmall?.copyWith(color: ink)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: QRaqeeb.verdictHorizontal, vertical: QRaqeeb.verdictVertical),
                decoration: BoxDecoration(color: ink, borderRadius: QRadius.chip),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(verified ? Icons.check_rounded : Icons.help_rounded, size: QRaqeeb.verdictIcon, color: QColors.surface),
                    const SizedBox(width: QRaqeeb.verdictGap),
                    Flexible(
                      child: Text(label, style: c.text.labelSmall?.copyWith(color: QColors.surface, letterSpacing: 0)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: QSpace.xs),
          Text(
            item.quoteText,
            textAlign: TextAlign.center,
            style: item.detectedKind == DetectedKind.hadith
                ? c.qText.hadith.copyWith(fontSize: QRaqeeb.verificationFont, height: QRaqeeb.quoteHeight)
                : c.text.bodyLarge,
          ),
          if (item.hadithGrade case final QuoteGrade grade) ...[
            field(c.l10n.raqeebFoundIn, grade.sourceBook),
            field(c.l10n.raqeebGrade, grade.gradeLabel),
            field(c.l10n.raqeebGrader, grade.grader),
            if (grade.reference != null) field(c.l10n.contentSource, grade.reference!),
          ],
          const SizedBox(height: QSpace.xs),
          SpanText(item.note, citationBadge: true, onCitation: onCitation, terms: terms),
          if (item.correctText != null) ...[
            const SizedBox(height: QSpace.sm),
            Text(c.l10n.raqeebExactText, style: c.text.titleSmall),
            EvidenceCard(evidence: item.correctText!),
          ],
          if (item.alternative != null) ...[
            const SizedBox(height: QSpace.sm),
            Text(c.l10n.raqeebAlternative, style: c.text.titleSmall),
            EvidenceCard(evidence: item.alternative!),
          ],
          if (item.sourceIds.isNotEmpty)
            Pressable(
              onTap: () => c.read<ContentBloc>().add(SentenceSourcesOpened(item.sourceIds)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: QSpace.sm),
                child: Text(c.l10n.raqeebSources, style: c.text.labelMedium?.copyWith(color: ink)),
              ),
            ),
        ],
      ),
    );
  }
}

class SourceReferences extends StatelessWidget {
  const SourceReferences({super.key, required this.ids, required this.citations, required this.onCitation});
  final List<String> ids;
  final List<Citation> citations;
  final ValueChanged<int> onCitation;
  @override
  Widget build(BuildContext c) => Wrap(
    children: [
      for (final cite in citations.where((c) => ids.contains(c.source.sourceId)))
        TextButton(
          onPressed: () => onCitation(cite.ref),
          child: Text(c.n(cite.ref), style: c.text.labelMedium?.copyWith(color: QColors.gold800)),
        ),
    ],
  );
}

class ReferralCard extends StatelessWidget {
  // TODO(contract): A-06 — open supplied targets; the contract has no private-send endpoint.
  const ReferralCard({super.key, required this.referral, this.onCitation, this.terms = const {}});
  final Referral referral;
  final ValueChanged<int>? onCitation;
  final Map<String, TermCard> terms;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(QSpace.md),
    decoration: BoxDecoration(
      color: QColors.gold50,
      borderRadius: BorderRadius.circular(QRadius.md),
      border: Border.all(color: QColors.gold100, width: QRaqeeb.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.school_rounded, color: QColors.gold800),
            const SizedBox(width: QSpace.xs),
            Expanded(
              child: Text(c.l10n.raqeebSpecialistTitle, style: c.text.titleSmall?.copyWith(color: QColors.gold800)),
            ),
          ],
        ),
        const SizedBox(height: QSpace.xxs),
        SpanText(
          referral.reason,
          style: c.text.bodySmall?.copyWith(color: QColors.deepInk),
          onCitation: onCitation,
          citationBadge: true,
          terms: terms,
        ),
        for (final target in referral.targets) ...[
          const SizedBox(height: QSpace.sm),
          Text(target.name, style: c.text.titleSmall),
          Text(target.description, style: c.text.bodySmall?.copyWith(color: QColors.deepInk)),
          if (target.contact != null) SelectableText(target.contact!, style: c.text.bodySmall),
          if (target.url != null) ...[
            const SizedBox(height: QSpace.sm),
            QButton(
              label: c.l10n.raqeebOpen,
              tone: QButtonTone.gold,
              icon: Icons.open_in_new_rounded,
              onPressed: () => c.read<ContentBloc>().add(SourceLinkOpened(target.url!)),
            ),
          ],
        ],
      ],
    ),
  );
}
