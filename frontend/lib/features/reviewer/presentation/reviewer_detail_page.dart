import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/reviewer/domain/reviewer_content.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_labels.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_plan_view.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_shell.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/lesson/presentation/widgets/correct_answer.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

class ReviewerDetailPage extends StatelessWidget {
  const ReviewerDetailPage({super.key, required this.runId, required this.previewBuilder});
  final String runId;
  final Widget Function(ReviewDraft, ReviewPreview) previewBuilder;
  @override
  Widget build(BuildContext c) => ContentInteractions(
    child: BlocConsumer<ReviewerDetailBloc, ReviewerDetailState>(
      listener: (c, s) {
        final draft = s.run?.draft;
        if (draft != null) {
          c.read<ContentBloc>().add(ContentReceived(reviewerTerms(draft, c.isArabic ? 'ar' : 'en'), reviewerSources(draft)));
        }
      },
      builder: (c, s) {
        final run = s.run;
        if (run == null) {
          return s.failure != null
              ? QErrorView(kind: failureKind(s.failure!), onRetry: () => c.read<ReviewerDetailBloc>().add(RunOpened(runId)))
              : const QLoadingView();
        }
        final atGate = ['awaiting_gate1', 'awaiting_gate2'].contains(run.status);
        return Scaffold(
          backgroundColor: QColors.morningMint,
          appBar: AppBar(
            actions: const [ReviewerLanguageMenu()],
            leading: BackButton(onPressed: () => c.go('/reviewer/runs')),
            title: Text(
              run.plan == null ? run.runId : (Localizations.localeOf(c).languageCode == 'ar' ? run.plan!.title.ar : run.plan!.title.en),
            ),
          ),
          body: ListView(
            key: PageStorageKey('reviewer-detail-$runId'),
            padding: const EdgeInsets.all(QSpace.page),
            children: [
              Wrap(
                spacing: QSpace.sm,
                runSpacing: QSpace.sm,
                children: [
                  Tag(reviewerLabel(run.status, c.l10n), color: run.status == 'failed' ? QColors.statusFabricated : QColors.emerald500),
                  Text(run.runId, style: c.text.bodySmall),
                ],
              ),
              const SizedBox(height: QSpace.md),
              Text(c.l10n.reviewerStage, style: c.text.titleMedium),
              Wrap(
                spacing: QSpace.sm,
                runSpacing: QSpace.xs,
                children: [
                  for (final stage in run.stages)
                    Tag(
                      c.l10n.reviewerStatusStage(reviewerLabel(stage.stage, c.l10n), _stageStatus(c, stage.status)),
                      color: stage.status == 'failed' ? QColors.statusFabricated : QColors.statusUnknown,
                    ),
                ],
              ),
              const SizedBox(height: QSpace.md),
              if (run.error != null) QCard(borderColor: QColors.statusFabricated, child: Text(run.error!.message)),
              if (s.status == ReviewerStatus.loading || s.status == ReviewerStatus.submitting) const QInlineLoading(showFlame: false),
              if (s.failure != null)
                QInlineError(message: failureBody(s.failure!, c.l10n), onRetry: () => c.read<ReviewerDetailBloc>().add(RunOpened(runId))),
              if (s.failure case ValidationFailure(:final details)) ..._validation(c, details),
              if (s.issue != null)
                QCard(
                  borderColor: QColors.statusFabricated,
                  child: Text(switch (s.issue!) {
                    ReviewActionIssue.pairedEnglish => c.l10n.reviewerPairedEnglish,
                    ReviewActionIssue.blockers => c.l10n.reviewerBlockers,
                    ReviewActionIssue.reasonRequired => c.l10n.reviewerReasonRequired,
                    ReviewActionIssue.invalidPlan => c.l10n.reviewerInvalidPlan,
                  }),
                ),
              if (s.stale)
                QCard(
                  borderColor: QColors.statusCaution,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(c.l10n.reviewerStale),
                      const SizedBox(height: QSpace.md),
                      QButton(
                        label: c.l10n.reviewerReconfirm,
                        silent: true,
                        onPressed: s.status == ReviewerStatus.ready
                            ? () => c.read<ReviewerDetailBloc>().add(const ReviewReconfirmed())
                            : null,
                      ),
                    ],
                  ),
                ),
              if (s.regenerationAccepted) QCard(child: Text(c.l10n.reviewerRegenerationAccepted)),
              const SizedBox(height: QSpace.md),
              if (s.plan != null)
                ExpansionTile(
                  key: PageStorageKey('plan-$runId-${run.reviewDigest}'),
                  initiallyExpanded: run.status == 'awaiting_gate1',
                  title: Text(run.status == 'awaiting_gate1' ? c.l10n.reviewerGate1 : c.l10n.reviewerPlan),
                  children: [
                    ReviewerPlanView(
                      key: ValueKey('plan-fields-${run.reviewDigest}'),
                      plan: s.plan!,
                      editable: run.status == 'awaiting_gate1' && s.status == ReviewerStatus.ready && !s.stale,
                      onChanged: (p) => c.read<ReviewerDetailBloc>().add(PlanEdited(p)),
                    ),
                  ],
                ),
              if (run.draft != null) ..._draft(c, s, run.draft!),
              if (atGate) ...[
                if (s.hasBlockers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: QSpace.md),
                    child: Text(c.l10n.reviewerBlockers, style: c.text.bodyMedium?.copyWith(color: QColors.statusFabricated)),
                  ),
                TextFormField(
                  key: ValueKey('review-note-${run.reviewDigest}'),
                  initialValue: s.reason,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: c.l10n.reviewerNote),
                  onChanged: (v) => c.read<ReviewerDetailBloc>().add(ReviewReasonEdited(v)),
                ),
                const SizedBox(height: QSpace.lg),
                Wrap(
                  spacing: QSpace.sm,
                  runSpacing: QSpace.sm,
                  children: [
                    QButton(
                      key: const ValueKey('reviewer-approve'),
                      expand: false,
                      label: c.l10n.reviewerApprove,
                      silent: true,
                      onPressed: s.canApprove ? () => c.read<ReviewerDetailBloc>().add(const GateDecisionSubmitted('approve')) : null,
                    ),
                    if (run.status == 'awaiting_gate2')
                      QButton(
                        key: const ValueKey('reviewer-request-changes'),
                        expand: false,
                        label: c.l10n.reviewerRequestChanges,
                        silent: true,
                        tone: QButtonTone.outline,
                        onPressed: s.status == ReviewerStatus.ready && !s.stale
                            ? () => c.read<ReviewerDetailBloc>().add(const GateDecisionSubmitted('request_changes'))
                            : null,
                      ),
                    QButton(
                      key: const ValueKey('reviewer-reject'),
                      expand: false,
                      label: c.l10n.reviewerReject,
                      silent: true,
                      tone: QButtonTone.retry,
                      onPressed: s.status == ReviewerStatus.ready && !s.stale
                          ? () => c.read<ReviewerDetailBloc>().add(const GateDecisionSubmitted('reject'))
                          : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: QSpace.xl),
            ],
          ),
        );
      },
    ),
  );
  String _stageStatus(BuildContext c, String s) => switch (s) {
    'pending' => c.l10n.reviewerPending,
    'done' => c.l10n.reviewerDone,
    'skipped' => c.l10n.reviewerSkipped,
    _ => reviewerLabel(s, c.l10n),
  };
  List<Widget> _validation(BuildContext c, Map<String, Object?> d) => [
    if (d['issues'] is List)
      for (final issue in d['issues'] as List)
        if (issue is Map && issue['message'] is String)
          QCard(borderColor: QColors.statusFabricated, child: Text(issue['message'] as String)),
  ];
  List<Widget> _draft(BuildContext c, ReviewerDetailState s, ReviewDraft d) {
    final previews = d.previews.where((p) => p.variant == s.variant).toList();
    final sentences = {for (final p in previews) p.language: reviewerSentences(p)};
    Widget panel(String title, List<Widget> children) => ExpansionTile(
      key: PageStorageKey('${s.run!.runId}-$title'),
      maintainState: true,
      title: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: QSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: QSpace.sm), children[i]],
            ],
          ),
        ),
      ],
    );
    return [
      Text(c.l10n.reviewerGate2, style: c.text.titleLarge),
      const SizedBox(height: QSpace.md),
      QSegmentedChips<String>(
        options: {for (final v in d.variants) v: reviewerLabel(v, c.l10n)},
        selected: s.variant,
        onSelected: (v) => c.read<ReviewerDetailBloc>().add(ReviewVariantPicked(v)),
      ),
      const SizedBox(height: QSpace.md),
      Text(c.l10n.reviewerPreview, style: c.text.titleLarge),
      const SizedBox(height: QSpace.md),
      _KeepPreviewAlive(
        key: ValueKey('preview-${s.run!.runId}'),
        child: LayoutBuilder(
          builder: (c, box) {
            final height = MediaQuery.sizeOf(c).height < QReviewer.previewHeight ? QReviewer.shortPreviewHeight : QReviewer.previewHeight;
            final children = [
              for (final p in previews)
                QCard(
                  key: ValueKey('preview-${s.run!.reviewDigest}-${p.language}-${p.variant}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(p.language == 'ar' ? c.l10n.commonArabic : c.l10n.commonEnglish, style: c.text.titleMedium),
                      SizedBox(height: height, child: previewBuilder(d, p)),
                    ],
                  ),
                ),
            ];
            final sideBySide = box.maxWidth >= QBreakpoints.rail;
            return Wrap(
              spacing: QSpace.md,
              runSpacing: QSpace.md,
              children: [
                for (final child in children)
                  SizedBox(width: sideBySide ? (box.maxWidth - QSpace.md) / children.length : box.maxWidth, child: child),
              ],
            );
          },
        ),
      ),
      panel(c.l10n.reviewerEvidence, [
        for (final row in d.sentenceMap)
          QCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(row.sentenceId, style: c.text.labelMedium),
                Tag(reviewerLabel(row.role, c.l10n), color: QColors.statusUnknown),
                for (final language in ['ar', 'en'])
                  if (sentences[language]?[row.sentenceId] case final Sentence sentence)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: QSpace.sm),
                      child: Directionality(
                        textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                        child: SpanText(sentence.spans, style: c.text.bodyLarge),
                      ),
                    ),
                for (final claim in d.claims.where((v) => row.claimIds.contains(v.claimId))) ...[
                  Text(claim.text, style: c.text.bodyLarge),
                  Wrap(
                    spacing: QSpace.xs,
                    children: [
                      Tag(reviewerLabel(claim.basis, c.l10n)),
                      Tag(reviewerLabel(claim.status, c.l10n), color: QColors.statusUnknown),
                    ],
                  ),
                  if (claim.reasoning != null) ...[
                    Text(reviewerLabel(claim.reasoning!.tool, c.l10n)),
                    for (final premise in claim.reasoning!.premises) Text(premise),
                    Text(claim.reasoning!.inference),
                  ],
                  for (final evidence in claim.evidence)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: QSpace.sm),
                      child: QCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(evidence.source.title, style: c.text.titleMedium),
                            Text(evidence.source.reference),
                            Text(evidence.source.excerpt, style: c.text.bodyLarge),
                            Text(evidence.supports ? c.l10n.reviewerSupports : c.l10n.reviewerNotSupporting),
                            Text(evidence.verifierNote),
                            if (evidence.semanticReview != null) ...[
                              Tag(
                                reviewerLabel(evidence.semanticReview!.fit, c.l10n),
                                color: evidence.semanticReview!.fit == 'exact' ? QColors.emerald500 : QColors.statusCaution,
                              ),
                              for (final concern in evidence.semanticReview!.concerns)
                                Text(reviewerLabel(concern, c.l10n), style: c.text.labelMedium),
                              Text(evidence.semanticReview!.note),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
                if (s.run?.status == 'awaiting_gate2')
                  QButton(
                    label: c.l10n.reviewerEditSentence,
                    silent: true,
                    tone: QButtonTone.ghost,
                    onPressed: s.status == ReviewerStatus.ready && !s.stale ? () => _edit(c, s, row.sentenceId) : null,
                  ),
                if (s.edits.any((e) => e.sentenceId == row.sentenceId && e.variant == s.variant))
                  Text(c.l10n.reviewerEditsSaved, style: c.text.labelMedium),
              ],
            ),
          ),
      ]),
      panel(c.l10n.reviewerArcMap, [
        for (final row in d.arcMap)
          QCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.stepId, style: c.text.titleMedium),
                for (final block in row.blockIds) Text(block),
              ],
            ),
          ),
      ]),
      panel(c.l10n.reviewerExercises, [
        for (final e in d.exercises)
          QCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpanText(e.exercise.prompt, style: c.text.titleMedium),
                Text(c.l10n.reviewerAnswerKey, style: c.text.labelMedium),
                if (e.answerKey != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: correctAnswerWidgets(c, e.exercise, e.answerKey!))
                else
                  Text(c.l10n.reviewerNoKey),
                for (final entry in e.optionMisconceptions.entries) Text(c.l10n.reviewerIdsPair(entry.key, entry.value)),
                CheckboxListTile(
                  title: Text(c.l10n.reviewerRemoveExercise),
                  value: s.removals.contains(e.exercise.id),
                  onChanged: s.status == ReviewerStatus.ready && !s.stale
                      ? (v) => c.read<ReviewerDetailBloc>().add(ExerciseRemovalChanged(e.exercise.id, v!))
                      : null,
                ),
              ],
            ),
          ),
      ]),
      panel(c.l10n.reviewerQA, [
        if (s.run!.qaReport?.issues.isEmpty == true) Text(c.l10n.reviewerNoIssues),
        for (final severity in ['blocker', 'warning', 'info']) ...[
          if (s.run!.qaReport?.issues.any((v) => v.severity == severity) == true)
            Text(switch (severity) {
              'blocker' => c.l10n.reviewerBlocker,
              'warning' => c.l10n.reviewerWarning,
              _ => c.l10n.reviewerInfo,
            }, style: c.text.titleMedium),
          for (final kind in {
            for (final issue in s.run!.qaReport?.issues ?? <ReviewQAIssue>[])
              if (issue.severity == severity) issue.kind,
          }) ...[
            Text(reviewerLabel(kind, c.l10n), style: c.text.labelLarge),
            for (final issue in s.run!.qaReport!.issues.where((v) => v.severity == severity && v.kind == kind))
              QCard(
                borderColor: severity == 'blocker'
                    ? QColors.statusFabricated
                    : severity == 'warning'
                    ? QColors.statusCaution
                    : QColors.statusUnknown,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reviewerLabel(issue.kind, c.l10n), style: c.text.labelMedium),
                    if (issue.location.sentenceId ?? issue.location.exerciseId ?? issue.location.sceneId case final String location)
                      Text(location, style: c.text.bodySmall),
                    Text(issue.message),
                  ],
                ),
              ),
          ],
        ],
      ]),
      panel(c.l10n.reviewerVisuals, [
        for (final v in d.visuals)
          QCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(v.sceneId, style: c.text.titleMedium),
                Tag(
                  v.origin == 'builtin' ? c.l10n.reviewerCompiled : c.l10n.reviewerPlaceholder,
                  color: v.origin == 'builtin' ? QColors.emerald500 : QColors.statusCaution,
                ),
                VisualView(v.visual, use: VisualUse.teach),
                if (v.audit != null)
                  for (final issue in v.audit!.issues) Text(issue),
                if (v.previews != null) ...[Text(v.previews!.rendererVersion), Text(v.previews!.timing.device)],
                if (v.origin != 'builtin')
                  QButton(
                    label: c.l10n.reviewerRegenerate,
                    silent: true,
                    tone: QButtonTone.outline,
                    onPressed: s.status == ReviewerStatus.ready && !s.stale && s.run!.status == 'awaiting_gate2'
                        ? () => c.read<ReviewerDetailBloc>().add(ImageRegenerationRequested(v.sceneId))
                        : null,
                  ),
              ],
            ),
          ),
      ]),
    ];
  }

  void _edit(BuildContext c, ReviewerDetailState s, String id) {
    showQSheet<void>(
      c,
      builder: (_) => BlocProvider.value(
        value: c.read<ReviewerDetailBloc>(),
        child: _SentenceEditor(id: id, state: s),
      ),
    );
  }
}

class _SentenceEditor extends StatefulWidget {
  const _SentenceEditor({required this.id, required this.state});
  final String id;
  final ReviewerDetailState state;
  @override
  State<_SentenceEditor> createState() => _SentenceEditorState();
}

class _SentenceEditorState extends State<_SentenceEditor> {
  late final ar = TextEditingController(
        text:
            widget.state.edits
                .where((v) => v.sentenceId == widget.id && v.variant == widget.state.variant && v.language == 'ar')
                .firstOrNull
                ?.newText ??
            '',
      ),
      en = TextEditingController(
        text:
            widget.state.edits
                .where((v) => v.sentenceId == widget.id && v.variant == widget.state.variant && v.language == 'en')
                .firstOrNull
                ?.newText ??
            '',
      );
  @override
  void dispose() {
    ar.dispose();
    en.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => BlocConsumer<ReviewerDetailBloc, ReviewerDetailState>(
    listenWhen: (a, b) => a.edits != b.edits,
    listener: (c, s) {
      if (s.issue == null) Navigator.of(c).pop();
    },
    builder: (c, s) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.l10n.reviewerEditSentence, style: c.text.headlineSmall),
        Text(widget.id),
        const SizedBox(height: QSpace.md),
        TextField(
          key: const ValueKey('sentence-edit-ar'),
          controller: ar,
          maxLines: null,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(labelText: c.l10n.reviewerEditAr),
        ),
        const SizedBox(height: QSpace.md),
        TextField(
          key: const ValueKey('sentence-edit-en'),
          controller: en,
          maxLines: null,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: c.l10n.reviewerEditEn),
        ),
        const SizedBox(height: QSpace.md),
        if (s.issue == ReviewActionIssue.pairedEnglish)
          Text(c.l10n.reviewerPairedEnglish, style: c.text.bodyMedium?.copyWith(color: QColors.statusFabricated)),
        QButton(
          label: c.l10n.reviewerSaveEdits,
          silent: true,
          onPressed: () => c.read<ReviewerDetailBloc>().add(SentencePairEdited(widget.id, ar.text, en.text)),
        ),
      ],
    ),
  );
}

class _KeepPreviewAlive extends StatefulWidget {
  const _KeepPreviewAlive({super.key, required this.child});
  final Widget child;
  @override
  State<_KeepPreviewAlive> createState() => _KeepPreviewAliveState();
}

class _KeepPreviewAliveState extends State<_KeepPreviewAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
