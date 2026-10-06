import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_extras_bloc.dart';
import 'package:qabas/shared/presentation/brand/achievement_badge.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.profileAchievementsTitle)),
    body: BlocBuilder<AchievementsBloc, AchievementsState>(
      builder: (context, s) {
        if (s.status == AchievementsStatus.initial || s.status == AchievementsStatus.loading && s.items.isEmpty) {
          return const QLoadingView();
        }
        if (s.status == AchievementsStatus.failure) {
          return QErrorView(kind: failureKind(s.failure!), onRetry: () => context.read<AchievementsBloc>().add(const AchievementsOpened()));
        }
        if (s.items.isEmpty) return Center(child: Text(context.l10n.profileNoAchievements));
        return LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= QBreakpoints.rail ? 4 : 2;
            final width = (box.maxWidth - QSpace.page * 2 - QSpace.sm * (columns - 1)) / columns;
            final height = width / QAchievements.aspect;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.xs, QSpace.page, QSpace.md),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      context.l10n.profileUnlockedOf(context.n(s.items.where((a) => a.unlocked).length), context.n(s.items.length)),
                      style: context.text.bodyMedium,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(QSpace.page, 0, QSpace.page, QSpace.xxl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, row) => Padding(
                        padding: const EdgeInsets.only(bottom: QSpace.sm),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var column = 0; column < columns; column++) ...[
                                if (column > 0) const SizedBox(width: QSpace.sm),
                                Expanded(
                                  child: row * columns + column < s.items.length
                                      ? ConstrainedBox(
                                          constraints: BoxConstraints(minHeight: height),
                                          child: Reveal(
                                            delay: QAchievements.stagger * (row * columns + column),
                                            child: _Tile(s.items[row * columns + column]),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      childCount: (s.items.length / columns).ceil(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.a);
  final Achievement a;
  @override
  Widget build(BuildContext context) => QCard(
    shadow: a.unlocked,
    padding: const EdgeInsets.all(QSpace.md),
    child: Column(
      children: [
        Semantics(
          label: a.description,
          child: AchievementBadge(achievementKey: a.key, unlocked: a.unlocked, size: QAchievements.badge),
        ),
        const SizedBox(height: QSpace.sm),
        Text(a.title, textAlign: TextAlign.center, style: context.text.titleSmall),
        const SizedBox(height: QAchievements.gap),
        Text(a.description, textAlign: TextAlign.center, style: context.text.bodySmall),
        const Spacer(),
        if (a.unlocked)
          const Icon(Icons.check_circle_rounded, color: QColors.correct, size: QAchievements.check)
        else
          Row(
            children: [
              Expanded(
                child: ProgressTrack(value: a.target == 0 ? 0 : a.current / a.target, height: QAchievements.progress),
              ),
              const SizedBox(width: QCommunity.gap),
              Text(
                context.l10n.communityProgressCount(context.n(a.current), context.n(a.target)),
                style: context.text.labelSmall?.copyWith(letterSpacing: 0),
              ),
            ],
          ),
      ],
    ),
  );
}
