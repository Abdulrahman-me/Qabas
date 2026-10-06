import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_labels.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_shell.dart';

class ReviewerRunsPage extends StatelessWidget {
  const ReviewerRunsPage({super.key, this.detail});
  final Widget? detail;
  @override
  Widget build(BuildContext c) => BlocListener<ReviewerRunsBloc, ReviewerRunsState>(
    listenWhen: (a, b) => a.openedRun != b.openedRun && b.openedRun != null,
    listener: (c, s) => c.go('/reviewer/runs/${Uri.encodeComponent(s.openedRun!)}'),
    child: LayoutBuilder(
      builder: (c, box) {
        final wide = detail != null && box.maxWidth >= QBreakpoints.rail - QNavigation.railWidth;
        final list = Scaffold(
          backgroundColor: QColors.morningMint,
          appBar: AppBar(
            title: Text(c.l10n.reviewerRuns),
            actions: [
              QIconButton(icon: Icons.add_rounded, tooltip: c.l10n.reviewerNewRun, onTap: () => _newRun(c)),
              if (detail == null) const ReviewerLanguageMenu(),
            ],
          ),
          body: BlocBuilder<ReviewerRunsBloc, ReviewerRunsState>(
            builder: (c, s) => ListView(
              padding: EdgeInsets.symmetric(
                horizontal: QSpace.page + (detail == null ? (box.maxWidth - QBreakpoints.composerMax).clamp(0, double.infinity) / 2 : 0),
                vertical: QSpace.page,
              ),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: s.filter ?? 'all',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: c.l10n.reviewerAllStatuses),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(c.l10n.reviewerAllStatuses)),
                    for (final v in ['running', 'awaiting_gate1', 'awaiting_gate2', 'published', 'rejected', 'failed'])
                      DropdownMenuItem(value: v, child: Text(reviewerLabel(v, c.l10n))),
                  ],
                  onChanged: s.status == ReviewerStatus.loading
                      ? null
                      : (v) => c.read<ReviewerRunsBloc>().add(RunsOpened(v == 'all' ? null : v)),
                ),
                const SizedBox(height: QSpace.md),
                if (s.failure != null)
                  QInlineError(
                    message: failureBody(s.failure!, c.l10n),
                    onRetry: () => c.read<ReviewerRunsBloc>().add(s.items.isNotEmpty ? const MoreRunsRequested() : RunsOpened(s.filter)),
                  ),
                if (s.status == ReviewerStatus.loading) const QInlineLoading(showFlame: false),
                if (s.status == ReviewerStatus.ready && s.items.isEmpty)
                  QEmptyView(art: QEmptyArt.unitArt, title: c.l10n.reviewerRuns, body: c.l10n.reviewerNoRuns),
                for (final row in s.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: QSpace.sm),
                    child: QCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.title ?? row.runId),
                        subtitle: Text(c.l10n.reviewerStatusStage(reviewerLabel(row.status, c.l10n), reviewerLabel(row.stage, c.l10n))),
                        trailing: IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          tooltip: c.l10n.reviewerOpenRun,
                          onPressed: () => c.go('/reviewer/runs/${Uri.encodeComponent(row.runId)}'),
                        ),
                      ),
                    ),
                  ),
                if (s.cursor != null)
                  QButton(
                    label: c.l10n.reviewerMore,
                    silent: true,
                    tone: QButtonTone.outline,
                    onPressed: s.status == ReviewerStatus.loading ? null : () => c.read<ReviewerRunsBloc>().add(const MoreRunsRequested()),
                  ),
              ],
            ),
          ),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Visibility(
              visible: wide || detail == null,
              maintainState: true,
              child: SizedBox(width: wide ? QReviewer.listWidth : box.maxWidth, child: list),
            ),
            Visibility(
              visible: wide,
              maintainState: true,
              child: const VerticalDivider(width: QSpace.md, color: QColors.line),
            ),
            Expanded(
              child:
                  detail ??
                  Offstage(
                    offstage: !wide,
                    child: Center(child: Text(c.l10n.reviewerSelectRun, style: c.text.bodyLarge)),
                  ),
            ),
          ],
        );
      },
    ),
  );
  void _newRun(BuildContext c) {
    final bloc = c.read<ReviewerRunsBloc>();
    showQSheet<void>(
      c,
      builder: (_) => BlocProvider.value(value: bloc, child: const _NewRunForm()),
    );
  }
}

class _NewRunForm extends StatefulWidget {
  const _NewRunForm();
  @override
  State<_NewRunForm> createState() => _NewRunFormState();
}

class _NewRunFormState extends State<_NewRunForm> {
  final unit = TextEditingController(), brief = TextEditingController(), position = TextEditingController(text: '0');
  final form = GlobalKey<FormState>();
  String type = 'concept';
  @override
  void dispose() {
    unit.dispose();
    brief.dispose();
    position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => BlocConsumer<ReviewerRunsBloc, ReviewerRunsState>(
    listener: (c, s) {
      if (s.openedRun != null) Navigator.of(c).pop();
    },
    builder: (c, s) => Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.l10n.reviewerNewRun, style: c.text.headlineSmall),
          const SizedBox(height: QSpace.lg),
          TextFormField(
            controller: unit,
            decoration: InputDecoration(labelText: c.l10n.reviewerUnitId),
            validator: (v) => v == null || v.trim().isEmpty ? c.l10n.reviewerUnitId : null,
          ),
          const SizedBox(height: QSpace.md),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: c.l10n.reviewerLessonType),
            items: [
              for (final v in ['concept', 'story', 'practice']) DropdownMenuItem(value: v, child: Text(reviewerLabel(v, c.l10n))),
            ],
            onChanged: (v) => setState(() => type = v!),
          ),
          const SizedBox(height: QSpace.md),
          TextFormField(
            controller: brief,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: c.l10n.reviewerBrief),
            validator: (v) => v == null || v.trim().isEmpty ? c.l10n.reviewerBrief : null,
          ),
          const SizedBox(height: QSpace.md),
          TextFormField(
            controller: position,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: c.l10n.reviewerPosition),
            validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? c.l10n.reviewerPosition : null,
          ),
          const SizedBox(height: QSpace.lg),
          if (s.failure != null) Text(failureBody(s.failure!, c.l10n)),
          QButton(
            label: c.l10n.reviewerCreate,
            silent: true,
            onPressed: s.status == ReviewerStatus.submitting
                ? null
                : () {
                    if (form.currentState!.validate()) {
                      c.read<ReviewerRunsBloc>().add(
                        NewRunSubmitted(
                          ReviewRunCreate(
                            unitId: unit.text.trim(),
                            lessonType: type,
                            brief: brief.text,
                            positionIndex: int.parse(position.text),
                          ),
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
