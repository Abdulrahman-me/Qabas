import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_labels.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_shell.dart';

class ReviewerMetricsPage extends StatelessWidget {
  const ReviewerMetricsPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: QColors.morningMint,
    appBar: AppBar(title: Text(c.l10n.reviewerMetrics), actions: const [ReviewerLanguageMenu()]),
    body: BlocBuilder<ReviewerMetricsBloc, MetricsState>(
      builder: (c, s) {
        if (s.status == ReviewerStatus.failure) {
          return QErrorView(kind: failureKind(s.failure!), onRetry: () => c.read<ReviewerMetricsBloc>().add(const MetricsOpened()));
        }
        if (s.metrics == null) return const QLoadingView();
        final m = s.metrics!;
        Widget tile(String label, num? value, {bool percent = false}) => _MetricTile(
          label: label,
          value: value == null
              ? c.l10n.reviewerNotMeasured
              : percent
              ? c.l10n.reviewerPercentageNumber(c.n(value))
              : c.n(value),
          measured: value != null,
        );
        Widget section(String title, List<Widget> children, {String? supporting}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: c.text.titleLarge),
            if (supporting != null) ...[const SizedBox(height: QSpace.xxs), Text(supporting, style: c.text.bodySmall)],
            const SizedBox(height: QSpace.md),
            ...children,
          ],
        );
        Widget unavailable() => QCard(
          shadow: false,
          color: QColors.surfaceSunk,
          child: Text(c.l10n.reviewerNotMeasured, style: c.text.bodyMedium),
        );
        final learning = section(c.l10n.reviewerLearning, [
          _MetricGrid(
            children: [
              tile(c.l10n.reviewerActivated, m.learning.misconceptions.activated),
              tile(c.l10n.reviewerResolved, m.learning.misconceptions.resolved),
              tile(c.l10n.reviewerResolutionRate, m.learning.misconceptions.resolutionRatePercent, percent: true),
            ],
          ),
          const SizedBox(height: QSpace.md),
          _MetricGrid(
            children: [
              tile(c.l10n.reviewerUnitsStarted, m.learning.completion.unitsStarted),
              tile(c.l10n.reviewerUnitsCompleted, m.learning.completion.unitsCompleted),
            ],
          ),
        ]);
        final factory = section(c.l10n.reviewerFactory, [
          _MetricGrid(
            children: [
              tile(c.l10n.reviewerPublished, m.factory.lessonsPublished),
              tile(c.l10n.reviewerGenerationMinutes, m.factory.avgGenerationMinutes),
              tile(c.l10n.reviewerReviewMinutes, m.factory.avgReviewMinutes),
            ],
          ),
          const SizedBox(height: QSpace.md),
          _MetricGrid(
            children: [
              tile(c.l10n.reviewerResponses, m.factory.blindTest.responses),
              tile(c.l10n.reviewerIdentified, m.factory.blindTest.handwrittenIdentifiedPercent, percent: true),
              tile(c.l10n.reviewerPreferred, m.factory.blindTest.generatedPreferredOrSamePercent, percent: true),
            ],
          ),
        ]);
        final benchmark = m.raqeebBenchmark;
        return LayoutBuilder(
          builder: (c, box) => SingleChildScrollView(
            key: const PageStorageKey('reviewer-metrics-scroll'),
            padding: const EdgeInsets.all(QSpace.page),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: QReviewer.dashboardMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MetricGrid(minWidth: QBreakpoints.readingWidth, gap: QSpace.xl, equalHeight: false, children: [learning, factory]),
                    const SizedBox(height: QSpace.xxl),
                    section(c.l10n.reviewerPrePost, [
                      if (m.learning.prePost.isEmpty) unavailable(),
                      _MetricGrid(
                        minWidth: QReviewer.listWidth,
                        equalHeight: false,
                        children: [
                          for (final row in m.learning.prePost)
                            QCard(
                              shadow: false,
                              padding: const EdgeInsets.all(QSpace.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(row.unitTitle, style: c.text.titleMedium),
                                  const SizedBox(height: QSpace.xxs),
                                  Text(c.l10n.reviewerParticipantsValue(c.n(row.participants)), style: c.text.bodySmall),
                                  const SizedBox(height: QSpace.lg),
                                  _MetricBar(label: c.l10n.reviewerBefore, value: row.preAvgPercent, color: QColors.statusUnknown),
                                  const SizedBox(height: QSpace.md),
                                  _MetricBar(label: c.l10n.reviewerAfter, value: row.postAvgPercent, color: QColors.emerald500),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: QSpace.xxl),
                    section(c.l10n.reviewerBenchmark, [
                      if (benchmark == null || (benchmark.systems.isEmpty && benchmark.byClass.isEmpty)) unavailable(),
                      if (benchmark != null) ...[
                        _MetricGrid(
                          minWidth: QReviewer.listWidth,
                          equalHeight: false,
                          children: [
                            for (final system in benchmark.systems)
                              QCard(
                                shadow: false,
                                padding: const EdgeInsets.all(QSpace.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(reviewerLabel(system.name, c.l10n), style: c.text.titleMedium),
                                    const SizedBox(height: QSpace.md),
                                    _MetricGrid(
                                      children: [
                                        tile(c.l10n.reviewerAccuracy, system.accuracyPercent, percent: true),
                                        tile(c.l10n.reviewerUnsupported, system.unsupportedClaimRatePercent, percent: true),
                                        tile(c.l10n.reviewerAbstention, system.correctAbstentionPercent, percent: true),
                                        tile(c.l10n.reviewerReferral, system.correctReferralPercent, percent: true),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (benchmark.byClass.isNotEmpty) const SizedBox(height: QSpace.lg),
                        _MetricGrid(
                          minWidth: QReviewer.listWidth,
                          equalHeight: false,
                          children: [
                            for (final row in benchmark.byClass)
                              QCard(
                                shadow: false,
                                padding: const EdgeInsets.all(QSpace.lg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(reviewerLabel(row.questionClass, c.l10n), style: c.text.titleMedium),
                                    const SizedBox(height: QSpace.lg),
                                    _MetricBar(label: c.l10n.commonTabRaqeeb, value: row.raqeebAccuracyPercent, color: QColors.emerald500),
                                    const SizedBox(height: QSpace.md),
                                    _MetricBar(
                                      label: c.l10n.reviewerValueBaselineLlm,
                                      value: row.baselineAccuracyPercent,
                                      color: QColors.statusUnknown,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ], supporting: benchmark?.runAt),
                    const SizedBox(height: QSpace.xl),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Natural-height rows keep labels and values aligned without clipping Arabic.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children, this.minWidth = QReviewer.metricMinWidth, this.gap = QSpace.md, this.equalHeight = true});
  final List<Widget> children;
  final double minWidth, gap;
  final bool equalHeight;
  @override
  Widget build(BuildContext c) => LayoutBuilder(
    builder: (c, box) {
      if (children.isEmpty) return const SizedBox.shrink();
      final capacity = ((box.maxWidth + gap) / (minWidth + gap)).floor().clamp(1, children.length);
      final rows = (children.length / capacity).ceil();
      final columns = (children.length / rows).ceil();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) SizedBox(height: gap),
            _row([
              for (var i = start; i < start + columns && i < children.length; i++) ...[
                if (i > start) SizedBox(width: gap),
                Expanded(child: children[i]),
              ],
            ]),
          ],
        ],
      );
    },
  );
  Widget _row(List<Widget> widgets) {
    final row = Row(crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start, children: widgets);
    return equalHeight ? IntrinsicHeight(child: row) : row;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.measured});
  final String label, value;
  final bool measured;
  @override
  Widget build(BuildContext c) => QCard(
    shadow: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: c.text.bodyMedium),
        const SizedBox(height: QSpace.sm),
        Text(value, style: measured ? c.qText.stat.copyWith(color: QColors.emerald700) : c.text.bodyMedium),
      ],
    ),
  );
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext c) => Semantics(
    label: c.l10n.reviewerPercentValue(label, c.n(value)),
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: c.text.bodyMedium)),
            const SizedBox(width: QSpace.sm),
            Text(c.l10n.reviewerPercentageNumber(c.n(value)), style: c.text.labelLarge),
          ],
        ),
        const SizedBox(height: QSpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(QRadius.xs),
          child: LinearProgressIndicator(
            value: value.clamp(0, 100) / 100,
            minHeight: QReviewer.chartHeight,
            color: color,
            backgroundColor: QColors.line,
          ),
        ),
      ],
    ),
  );
}
