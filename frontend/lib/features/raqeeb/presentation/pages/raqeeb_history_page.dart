import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_history_bloc.dart';

class RaqeebHistoryPage extends StatelessWidget {
  const RaqeebHistoryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.raqeebHistory)),
    body: BlocBuilder<RaqeebHistoryBloc, RaqeebHistoryState>(
      builder: (context, s) {
        if (s.status == HistoryStatus.initial || s.status == HistoryStatus.loading && s.items.isEmpty) return const QLoadingView();
        return ListView(
          padding: const EdgeInsets.all(QSpace.page),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.failure != null)
                      QErrorView(
                        kind: failureKind(s.failure!),
                        onRetry: () =>
                            context.read<RaqeebHistoryBloc>().add(RaqeebHistoryOpened(more: s.items.isNotEmpty && s.cursor != null)),
                      ),
                    if (s.items.isEmpty && s.failure == null) QCard(child: Text(context.l10n.raqeebNoHistory)),
                    for (final c in s.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: QSpace.sm),
                        child: QCard(
                          onTap: () => context.push('/raqeeb/c/${Uri.encodeComponent(c.id)}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(c.title ?? context.l10n.raqeebNewChat, style: context.text.titleMedium),
                              if (c.preview != null) ...[
                                const SizedBox(height: QSpace.xs),
                                Text(c.preview!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                              ],
                              const SizedBox(height: QSpace.xs),
                              Text(
                                MaterialLocalizations.of(context).formatMediumDate(c.updatedAt.toLocal()),
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (s.status == HistoryStatus.paging)
                      const QInlineLoading()
                    else if (s.cursor != null)
                      QButton(
                        label: context.l10n.commonSeeAll,
                        onPressed: () => context.read<RaqeebHistoryBloc>().add(const RaqeebHistoryOpened(more: true)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
