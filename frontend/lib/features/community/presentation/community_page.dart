import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/community/domain/community.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';
import 'package:share_plus/share_plus.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<CommunityBloc>().add(const CommunityOpened());
          context.read<FriendsBloc>().add(const FriendsOpened());
        },
        child: ListView(
          key: const PageStorageKey('community-scroll'),
          padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.lg, QSpace.page, QSpace.xxl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(context.l10n.communityCommunityTitle, style: context.text.headlineLarge)),
                        BlocBuilder<CommunityBloc, CommunityState>(
                          builder: (context, s) => Badge(
                            isLabelVisible: s.invitations > 0,
                            label: Text(context.n(s.invitations)),
                            child: QIconButton(
                              icon: Icons.mail_outline_rounded,
                              tooltip: context.l10n.challengeInvitations,
                              onTap: () => context.push('/challenge/invitations'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: QSpace.md),
                    BlocBuilder<CommunityBloc, CommunityState>(
                      builder: (context, s) {
                        if (s.status == CommunityStatus.initial || s.status == CommunityStatus.loading && s.league == null) {
                          return const QLoadingView();
                        }
                        if (s.noLeague) {
                          return QCard(
                            child: Column(
                              children: [
                                const FlameMark(size: QCommunity.questIcon),
                                const SizedBox(height: QSpace.md),
                                Text(context.l10n.communityNoLeagueTitle, textAlign: TextAlign.center, style: context.text.titleMedium),
                                const SizedBox(height: QSpace.md),
                                QButton(label: context.l10n.commonContinue, onPressed: () => context.go('/journey')),
                              ],
                            ),
                          );
                        }
                        if (s.leagueFailure != null) {
                          return QErrorView(
                            kind: failureKind(s.leagueFailure!),
                            onRetry: () => context.read<CommunityBloc>().add(const CommunityOpened()),
                          );
                        }
                        final league = s.league!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Reveal(child: _LeagueHeader(league: league)),
                            const SizedBox(height: QSpace.md),
                            QCard(
                              padding: const EdgeInsets.symmetric(vertical: QSpace.xs),
                              child: Column(
                                children: [
                                  for (var i = 0; i < league.members.length; i++) ...[
                                    Reveal(
                                      delay: QCommunity.stagger * i,
                                      child: _LeagueRow(member: league.members[i]),
                                    ),
                                    if (league.promotionSize > 0 && i == league.promotionSize - 1)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QCommunity.gap),
                                        child: Row(
                                          children: [
                                            const Expanded(
                                              child: Divider(color: QColors.correct, thickness: QCommunity.border),
                                            ),
                                            const SizedBox(width: QSpace.xs),
                                            const Icon(
                                              Icons.keyboard_double_arrow_up_rounded,
                                              size: QCommunity.promotionIcon,
                                              color: QColors.correct,
                                            ),
                                            Flexible(
                                              child: Text(
                                                context.l10n.communityPromotionZone,
                                                style: context.text.labelSmall?.copyWith(color: QColors.correct),
                                              ),
                                            ),
                                            const SizedBox(width: QSpace.xs),
                                            const Expanded(
                                              child: Divider(color: QColors.correct, thickness: QCommunity.border),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: QSpace.xl),
                    const Reveal(delay: QMotion.reveal200, child: _LiveCard()),
                    const SizedBox(height: QSpace.xl),
                    SectionHeader(context.l10n.communityDailyQuests),
                    BlocBuilder<CommunityBloc, CommunityState>(
                      builder: (context, s) {
                        if (s.status == CommunityStatus.loading && s.quests == null) return const QLoadingView();
                        if (s.questsFailure != null) {
                          return QErrorView(
                            kind: failureKind(s.questsFailure!),
                            onRetry: () => context.read<CommunityBloc>().add(const CommunityOpened()),
                          );
                        }
                        final quests = s.quests;
                        return QCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (quests == null || quests.items.isEmpty)
                                Text(context.l10n.communityNoQuests)
                              else ...[
                                for (var i = 0; i < quests.items.length; i++) ...[
                                  if (i > 0)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: QSpace.sm),
                                      child: Divider(),
                                    ),
                                  _QuestRow(quest: quests.items[i]),
                                ],
                                const SizedBox(height: QSpace.sm),
                                Text(
                                  context.l10n.communityResetsIn(context.n((quests.resetsIn / 3600).ceil())),
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: QSpace.xl),
                    SectionHeader(context.l10n.communityFriends, action: context.l10n.communityInvite, onAction: () => _invite(context)),
                    const FriendsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _invite(BuildContext context) {
    final bloc = context.read<FriendsBloc>()..add(const InviteCreated());
    showQSheet(
      context,
      builder: (_) => BlocProvider.value(value: bloc, child: const InviteSheet()),
    );
  }
}

class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader({required this.league});
  final League league;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(QSpace.md),
    decoration: BoxDecoration(gradient: QGradients.communityLeague, borderRadius: BorderRadius.circular(QRadius.xl)),
    child: Row(
      children: [
        Container(
          width: QCommunity.badgeWidth,
          height: QCommunity.badgeHeight,
          decoration: ShapeDecoration(
            shape: const StarBorder.polygon(sides: 6, pointRounding: 0.35),
            gradient: LinearGradient(
              colors: [Color.lerp(_color, QColors.surface, 0.25)!, _color],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            shadows: QShadows.glow(_color, strength: 0.5),
          ),
          child: const Center(
            child: LanternGlyph(color: QColors.surface, lit: true, size: QCommunity.badgeGlyph),
          ),
        ),
        const SizedBox(width: QSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(league.name, style: context.text.headlineSmall?.copyWith(color: QColors.softEmber)),
              const SizedBox(height: QSpace.xxs),
              Text(
                league.topTier ? context.l10n.communityTopTier : context.l10n.communityPromotionCount(context.n(league.promotionSize)),
                style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: QCommunity.gap),
              Tag(
                context.l10n.communityEndsIn(context.n(league.endsIn ~/ 86400), context.n(league.endsIn % 86400 ~/ 3600)),
                icon: Icons.schedule_rounded,
                color: QColors.flameGold,
                background: QColors.flameGold.withValues(alpha: 0.14),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Color get _color => switch (league.tier) {
    'tier_star' => QColors.dusk,
    'tier_dawn' => QColors.flameGold,
    _ => QColors.emerald400,
  };
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({required this.member});
  final LeagueMember member;
  @override
  Widget build(BuildContext context) {
    final medal = member.rank <= 3 ? [QColors.flameGold, QCommunity.silver, QCommunity.bronze][member.rank - 1] : null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: QSpace.xs, vertical: QCommunity.rowMargin),
      padding: const EdgeInsets.symmetric(horizontal: QSpace.sm, vertical: QCommunity.rowInset),
      decoration: BoxDecoration(
        color: member.isMe ? QColors.gold50 : null,
        borderRadius: BorderRadius.circular(QRadius.md),
        border: member.isMe ? Border.all(color: QColors.flameGold, width: QCommunity.border) : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < QBreakpoints.readingWidth / 2 || MediaQuery.textScalerOf(context).scale(1) > 1;
          return Row(
            children: [
              SizedBox(
                width: QCommunity.rank,
                child: medal != null
                    ? Icon(Icons.workspace_premium_rounded, color: medal, size: QCommunity.medal)
                    : Text(
                        context.n(member.rank),
                        textAlign: TextAlign.center,
                        style: context.text.labelLarge?.copyWith(color: member.promoted ? QColors.correct : QColors.muted),
                      ),
              ),
              const SizedBox(width: QSpace.xs),
              TravelerAvatar.fromKey(avatarKey: member.avatar, size: QCommunity.avatar, ring: member.isMe ? QColors.flameGold : null),
              const SizedBox(width: QSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.isMe ? context.l10n.communityYou : member.name,
                      style: context.text.titleSmall?.copyWith(fontWeight: member.isMe ? FontWeight.w800 : FontWeight.w600),
                    ),
                    if (compact)
                      Text(
                        context.l10n.commonEmbers(context.n(member.xp)),
                        style: context.text.labelMedium?.copyWith(color: QColors.slate),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: QSpace.xs),
              if (!compact)
                Text(context.l10n.commonEmbers(context.n(member.xp)), style: context.text.labelMedium?.copyWith(color: QColors.slate)),
            ],
          );
        },
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.quest});
  final Quest quest;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: QCommunity.questIcon,
        height: QCommunity.questIcon,
        decoration: BoxDecoration(color: QColors.gold50, borderRadius: BorderRadius.circular(QRadius.md)),
        child: const Center(child: FlameMark(size: QCommunity.flame, animate: false)),
      ),
      const SizedBox(width: QSpace.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quest.title, style: context.text.titleSmall),
            const SizedBox(height: QCommunity.gap),
            Row(
              children: [
                Expanded(
                  child: ProgressTrack(value: quest.goal == 0 ? 0 : quest.progress / quest.goal, height: QCommunity.bar),
                ),
                const SizedBox(width: QSpace.xs),
                Text(
                  context.l10n.communityProgressCount(context.n(quest.progress), context.n(quest.goal)),
                  style: context.text.labelMedium,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(width: QSpace.sm),
      Icon(
        quest.completed ? Icons.check_circle_rounded : Icons.card_giftcard_rounded,
        color: quest.completed ? QColors.correct : QColors.gold700,
      ),
    ],
  );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(QSpace.lg),
    decoration: BoxDecoration(
      gradient: QGradients.communityChallenge,
      borderRadius: BorderRadius.circular(QRadius.xl),
      boxShadow: QShadows.lifted,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: QColors.flameGold),
            const SizedBox(width: QCommunity.gap),
            Expanded(
              child: Text(
                context.l10n.communityLiveChallenge.toUpperCase(),
                style: context.qText.eyebrow.copyWith(color: QColors.flameGold),
              ),
            ),
            BlocBuilder<FriendsBloc, FriendsState>(
              builder: (context, s) => SizedBox(
                width: QCommunity.previewWidth,
                height: QCommunity.previewAvatar,
                child: Stack(
                  children: [
                    for (var i = 0; i < s.items.take(3).length; i++)
                      PositionedDirectional(
                        start: i * QCommunity.previewStride,
                        child: TravelerAvatar.fromKey(
                          avatarKey: s.items[i].avatar,
                          size: QCommunity.previewAvatar,
                          ring: QColors.emerald500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: QSpace.sm),
        Text(context.l10n.communityLiveChallengeBody, style: context.text.titleMedium?.copyWith(color: QColors.surface, height: 1.35)),
        const SizedBox(height: QSpace.md),
        QButton(
          key: const ValueKey('start-challenge'),
          label: context.l10n.communityStartChallenge,
          tone: QButtonTone.gold,
          icon: Icons.play_arrow_rounded,
          onPressed: () => context.push('/challenge'),
        ),
      ],
    ),
  );
}

class FriendsList extends StatelessWidget {
  const FriendsList({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<FriendsBloc, FriendsState>(
    builder: (context, s) {
      if (s.status == FriendsStatus.initial || s.status == FriendsStatus.loading && s.items.isEmpty) return const QLoadingView();
      return QCard(
        padding: const EdgeInsets.symmetric(vertical: QSpace.xs),
        child: Column(
          children: [
            if (s.failure != null)
              QErrorView(kind: failureKind(s.failure!), onRetry: () => context.read<FriendsBloc>().add(const FriendsOpened())),
            if (s.items.isEmpty)
              Padding(padding: const EdgeInsets.all(QSpace.md), child: Text(context.l10n.communityNoFriends))
            else
              for (final f in s.items)
                ListTile(
                  leading: Stack(
                    children: [
                      TravelerAvatar.fromKey(avatarKey: f.avatar, size: QCommunity.friendAvatar),
                      if (f.online)
                        const PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: Icon(Icons.circle, size: QCommunity.promotionIcon, color: QColors.correct),
                        ),
                    ],
                  ),
                  title: Text(f.name, style: context.text.titleSmall),
                  subtitle: Text(
                    f.streak == null ? context.l10n.profilePrivateBadge : context.l10n.communityStreakDays(context.n(f.streak!)),
                    style: context.text.bodySmall,
                  ),
                  onTap: f.online ? () => context.push('/challenge?friend=${Uri.encodeComponent(f.id)}') : null,
                  trailing: PopupMenuButton<String>(
                    tooltip: context.l10n.communityFriends,
                    onSelected: (v) {
                      if (v == 'challenge') {
                        context.push('/challenge?friend=${Uri.encodeComponent(f.id)}');
                      } else {
                        showQSheet(
                          context,
                          builder: (_) => QConfirmSheet(
                            title: context.l10n.friendsRemove,
                            body: context.l10n.friendsRemoveBody(f.name),
                            primaryLabel: context.l10n.friendsRemove,
                            onPrimary: () {
                              context.read<FriendsBloc>().add(FriendRemoved(f.id));
                              context.pop();
                            },
                            secondaryLabel: context.l10n.commonCancel,
                            onSecondary: () => context.pop(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (f.online) PopupMenuItem(value: 'challenge', child: Text(context.l10n.communityStartChallenge)),
                      PopupMenuItem(value: 'remove', child: Text(context.l10n.friendsRemove)),
                    ],
                    child: f.xp == null
                        ? const Icon(Icons.more_horiz_rounded)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const EmberIcon(size: QCommunity.promotionIcon),
                              const SizedBox(width: QSpace.xxs),
                              Text(context.n(f.xp!), style: context.text.labelLarge),
                            ],
                          ),
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key});
  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  final _code = TextEditingController();
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<FriendsBloc, FriendsState>(
    listenWhen: (a, b) => a.accepted != b.accepted,
    listener: (context, s) {
      context.pop();
      showQSnack(context, context.l10n.friendsAccepted);
    },
    builder: (context, s) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.communityInvite, style: context.text.headlineSmall),
        const SizedBox(height: QSpace.md),
        if (s.invite != null) ...[
          Semantics(
            label: context.l10n.friendsCode,
            child: SelectableText(s.invite!.code, textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: context.qText.stat),
          ),
          const SizedBox(height: QSpace.md),
          Builder(
            builder: (shareContext) => QButton(
              label: context.l10n.friendsShare,
              onPressed: s.status == FriendsStatus.working
                  ? null
                  : () async {
                      final box = shareContext.findRenderObject() as RenderBox;
                      try {
                        await SharePlus.instance.share(
                          ShareParams(text: s.invite!.shareText, sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size),
                        );
                      } catch (_) {
                        if (shareContext.mounted) showQSnack(shareContext, context.l10n.errorGenericTitle);
                      }
                    },
            ),
          ),
          const SizedBox(height: QSpace.lg),
        ] else if (s.status == FriendsStatus.working)
          const QInlineLoading(),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: context.l10n.friendsAcceptCode),
          onSubmitted: (v) => context.read<FriendsBloc>().add(InviteAccepted(v)),
        ),
        const SizedBox(height: QSpace.md),
        if (s.failure != null) ...[
          Text(
            s.failure is ConflictFailure
                ? (s.failure as ConflictFailure).code == 'already_friends'
                      ? context.l10n.friendsAlreadyFriends
                      : context.l10n.friendsInviteInvalid
                : failureBody(s.failure!, context.l10n),
            style: context.text.bodyMedium?.copyWith(color: QColors.retry),
          ),
          const SizedBox(height: QSpace.sm),
          if (s.invite == null)
            QButton(label: context.l10n.commonRetry, onPressed: () => context.read<FriendsBloc>().add(const InviteCreated())),
        ],
        QButton(
          label: context.l10n.friendsAccept,
          onPressed: s.status == FriendsStatus.working ? null : () => context.read<FriendsBloc>().add(InviteAccepted(_code.text)),
        ),
      ],
    ),
  );
}
