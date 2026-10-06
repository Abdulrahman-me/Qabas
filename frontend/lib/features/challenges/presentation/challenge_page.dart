import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_lobby_bloc.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/content/evidence_card.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';
import 'package:qabas/shared/presentation/exercises/exercise_kit.dart';

class ChallengeLobbyPage extends StatelessWidget {
  const ChallengeLobbyPage({super.key, this.invitationsOnly = false});
  final bool invitationsOnly;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(invitationsOnly ? context.l10n.challengeInvitations : context.l10n.communityLiveChallenge)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(QSpace.page),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
          child: BlocBuilder<ChallengeLobbyBloc, ChallengeLobbyState>(
            builder: (context, s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.status == LobbyStatus.initial || s.status == LobbyStatus.loading)
                  const QLoadingView()
                else ...[
                  if (s.failure != null)
                    QErrorView(
                      kind: failureKind(s.failure!),
                      onRetry: () => context.read<ChallengeLobbyBloc>().add(const ChallengeLobbyOpened()),
                    ),
                  if (!invitationsOnly) ...[
                    QButton(
                      key: const ValueKey('challenge-bot'),
                      label: context.l10n.challengePracticeBot,
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => context.push('/challenge/play?new=duel'),
                    ),
                    const SizedBox(height: QSpace.xl),
                    Text(context.l10n.challengeChooseFriends, style: context.text.titleLarge),
                    const SizedBox(height: QSpace.sm),
                    for (final f in s.friends)
                      CheckboxListTile(
                        value: s.selected.contains(f.id),
                        onChanged: f.online ? (_) => context.read<ChallengeLobbyBloc>().add(ChallengeFriendSelected(f.id)) : null,
                        secondary: TravelerAvatar.fromKey(avatarKey: f.avatar),
                        title: Text(f.name),
                        subtitle: Text(f.online ? context.l10n.friendsOnline : context.l10n.friendsOffline),
                      ),
                    SwitchListTile(
                      value: s.botFill,
                      onChanged: (v) => context.read<ChallengeLobbyBloc>().add(ChallengeBotFillChanged(v)),
                      title: Text(context.l10n.challengeBotFill),
                    ),
                    const SizedBox(height: QSpace.md),
                    QButton(
                      key: const ValueKey('challenge-group'),
                      label: context.l10n.challengeGroup,
                      onPressed: s.selected.isEmpty
                          ? null
                          : () => context.push(
                              '/challenge/play?new=${s.selected.length == 1 && !s.botFill ? 'duel' : 'group'}&friends=${s.selected.map(Uri.encodeComponent).join(',')}&fill=${s.botFill}',
                            ),
                    ),
                    const SizedBox(height: QSpace.xl),
                  ],
                  SectionHeader(context.l10n.challengeInvitations),
                  if (s.invitations.isEmpty)
                    QCard(child: Text(context.l10n.challengeNoInvitations))
                  else
                    for (final i in s.invitations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: QSpace.sm),
                        child: QCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(context.l10n.challengeInviteFrom(i.name), style: context.text.titleMedium),
                              const SizedBox(height: QSpace.md),
                              QButton(
                                label: context.l10n.challengeAccept,
                                onPressed: s.status == LobbyStatus.working
                                    ? null
                                    : () => context.push('/challenge/play?id=${Uri.encodeComponent(i.id)}&accept=true'),
                              ),
                              QButton(
                                label: context.l10n.challengeDecline,
                                tone: QButtonTone.ghost,
                                onPressed: s.status == LobbyStatus.working
                                    ? null
                                    : () => context.read<ChallengeLobbyBloc>().add(ChallengeInvitationDeclined(i.id)),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});
  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> {
  final _character = CharacterController();
  @override
  void dispose() {
    _character.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ChallengeBloc, ChallengeState>(
    listenWhen: (a, b) => a.phase != b.phase,
    listener: (context, s) {
      if (s.phase == ChallengePhase.reveal) {
        final right = s.reveal!.players.firstWhere((p) => p.id == s.challenge!.myId).correct;
        if (right) {
          SensoryScope.of(context).correct();
        } else {
          SensoryScope.of(context).retry();
        }
      }
      if (s.phase == ChallengePhase.results) {
        _character.cue(s.result!.winners.contains(s.challenge!.myId) ? CharacterCue.celebrate : CharacterCue.encourage);
        SensoryScope.of(context).complete();
      }
    },
    builder: (context, s) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QColors.night950,
        body: NightSky(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(QSpace.xs, QSpace.xxs, QSpace.page, 0),
                      child: Row(
                        children: [
                          QIconButton(
                            icon: Icons.close_rounded,
                            color: QColors.softEmber,
                            tooltip: context.l10n.commonClose,
                            onTap: () => context.canPop() ? context.pop() : context.go('/community'),
                          ),
                          const SizedBox(width: QChallenge.gap),
                          const Icon(Icons.bolt_rounded, color: QColors.flameGold),
                          const SizedBox(width: QSpace.xxs),
                          Expanded(
                            child: Text(
                              context.l10n.communityLiveChallenge,
                              style: context.text.titleMedium?.copyWith(color: QColors.softEmber),
                            ),
                          ),
                          if (s.phase == ChallengePhase.results && s.summary.isNotEmpty)
                            QIconButton(
                              icon: Icons.fact_check_outlined,
                              tooltip: context.l10n.challengeSummary,
                              color: QColors.softEmber,
                              onTap: () => _showSummary(context, s),
                            ),
                        ],
                      ),
                    ),
                    if (s.status == ChallengeStatus.reconnecting)
                      Semantics(
                        liveRegion: true,
                        child: Text(context.l10n.challengeReconnecting, style: context.text.bodyMedium?.copyWith(color: QColors.softEmber)),
                      ),
                    Expanded(
                      child: s.status == ChallengeStatus.initial || s.status == ChallengeStatus.loading
                          ? QLoadingView(tone: QTone.night, label: context.l10n.challengeLiveLobby)
                          : s.status == ChallengeStatus.failure
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(QSpace.page),
                              child: Column(
                                children: [
                                  QErrorView(
                                    kind: failureKind(s.failure!),
                                    tone: QTone.night,
                                    title: s.failure is ConflictFailure
                                        ? context.l10n.challengeNotJoinableTitle
                                        : context.l10n.challengeConnectionLost,
                                    onRetry: () => context.read<ChallengeBloc>().add(const ChallengeRetried()),
                                  ),
                                  const SizedBox(height: QSpace.md),
                                  QButton(
                                    label: context.l10n.challengePracticeBot,
                                    onPressed: () => context.read<ChallengeBloc>().add(ChallengeStarted()),
                                  ),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, box) => SingleChildScrollView(
                                padding: const EdgeInsets.all(QSpace.page),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: (box.maxHeight - QSpace.page * 2).clamp(0, double.infinity)),
                                  child: IntrinsicHeight(
                                    child: AnimatedSwitcher(
                                      duration: context.reduceMotion ? Duration.zero : QMotion.medium,
                                      child: KeyedSubtree(
                                        key: ValueKey(
                                          s.phase == ChallengePhase.results
                                              ? 'results'
                                              : s.phase == ChallengePhase.question || s.phase == ChallengePhase.reveal
                                              ? 'question-${s.question!.index}'
                                              : 'lobby',
                                        ),
                                        child: s.phase == ChallengePhase.results
                                            ? _results(
                                                context,
                                                s,
                                                compact:
                                                    box.maxWidth - QSpace.page * 2 - QSpace.md * 2 < QBreakpoints.readingWidth / 2 ||
                                                    MediaQuery.textScalerOf(context).scale(1) > 1,
                                              )
                                            : s.phase == ChallengePhase.question || s.phase == ChallengePhase.reveal
                                            ? _question(context, s)
                                            : _lobby(context, s),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _lobby(BuildContext context, ChallengeState s) => Column(
    children: [
      const Spacer(),
      if (s.phase == ChallengePhase.countdown)
        Reveal(
          key: ValueKey(s.remainingMs ~/ 1000),
          scale: 0.5,
          offset: Offset.zero,
          curve: QMotion.settle,
          child: Text(
            context.n((s.remainingMs / 1000).ceil()),
            style: context.qText.stat.copyWith(fontSize: QChallenge.countdownSize, color: QColors.flameGold),
          ),
        )
      else
        const FlameMark(size: QChallenge.lobbyFlame, glow: 1.5),
      const SizedBox(height: QSpace.md),
      Text(
        s.phase == ChallengePhase.countdown ? context.l10n.challengeGetReady : context.l10n.challengeLiveLobby,
        style: context.text.headlineSmall?.copyWith(color: QColors.softEmber),
      ),
      const SizedBox(height: QSpace.xl),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: QSpace.md,
        runSpacing: QSpace.sm,
        children: [
          for (final p in s.challenge!.players)
            AnimatedOpacity(
              duration: context.reduceMotion ? Duration.zero : QMotion.medium,
              opacity: p.status == 'joined' ? 1 : QChallenge.waiting,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TravelerAvatar.fromKey(
                    avatarKey: p.avatar,
                    size: QChallenge.lobbyAvatar,
                    ring: p.isMe ? QColors.flameGold : QColors.nightLine,
                  ),
                  const SizedBox(height: QChallenge.gap),
                  Text(_name(context, p), style: context.text.labelMedium?.copyWith(color: QColors.softEmber)),
                ],
              ),
            ),
        ],
      ),
      const Spacer(flex: 2),
    ],
  );
  String _name(BuildContext context, ChallengePlayer p) => p.isMe ? context.l10n.communityYou : p.name;
  Widget _question(BuildContext context, ChallengeState s) {
    final q = s.question!,
        reveal = s.phase == ChallengePhase.reveal,
        canAnswer = !reveal && !s.locked && s.answer == null && s.status == ChallengeStatus.connected && s.remainingMs > 0;
    final fastest = s.reveal?.fastest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.challengeQuestionOf(context.n(q.index + 1), context.n(q.total)),
                style: context.qText.eyebrow.copyWith(color: QColors.flameGold),
              ),
            ),
            Text(
              context.n((s.remainingMs / 1000).ceil()),
              style: context.qText.stat.copyWith(color: QColors.softEmber, fontSize: QChallenge.timer),
            ),
          ],
        ),
        const SizedBox(height: QSpace.xs),
        ProgressTrack(value: s.remainingMs / s.challenge!.config.timeLimit, height: QChallenge.bar),
        const SizedBox(height: QSpace.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: QSpace.lg,
          runSpacing: QSpace.sm,
          children: [
            for (final p in s.challenge!.players.where((p) => !p.isMe))
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedOpacity(
                        duration: context.reduceMotion ? Duration.zero : QMotion.normal,
                        opacity: reveal || s.answered.contains(p.id) ? 1 : QChallenge.dim,
                        child: TravelerAvatar.fromKey(avatarKey: p.avatar, size: QChallenge.avatar),
                      ),
                      if (reveal || s.answered.contains(p.id))
                        PositionedDirectional(
                          end: -QSpace.xxs,
                          bottom: -QSpace.xxs,
                          child: Container(
                            width: QChallenge.marker,
                            height: QChallenge.marker,
                            decoration: BoxDecoration(
                              color: !reveal
                                  ? QColors.flameGold
                                  : (s.reveal!.players.firstWhere((a) => a.id == p.id).correct ? QColors.correct : QColors.retry),
                              shape: BoxShape.circle,
                              border: Border.all(color: QColors.night950, width: QExercise.border),
                            ),
                            child: Icon(
                              !reveal
                                  ? Icons.bolt_rounded
                                  : (s.reveal!.players.firstWhere((a) => a.id == p.id).correct ? Icons.check_rounded : Icons.close_rounded),
                              size: QChallenge.markerIcon,
                              color: QColors.surface,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: QSpace.xxs),
                  Text(
                    reveal
                        ? context.l10n.challengeSeconds(context.n(s.reveal!.players.firstWhere((a) => a.id == p.id).elapsedMs / 1000))
                        : p.name,
                    style: context.text.labelSmall?.copyWith(
                      color: QColors.softEmber.withValues(alpha: QChallenge.answeredAlpha),
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: QSpace.lg),
        for (final entry in s.disconnected.entries)
          Text(
            context.l10n.challengeDisconnected(
              s.challenge!.players.firstWhere((p) => p.id == entry.key).name,
              context.n(s.graceSeconds[entry.key] ?? 0),
            ),
            style: context.text.bodySmall?.copyWith(color: QColors.softEmber),
          ),
        SpanText(q.prompt, style: context.text.headlineSmall?.copyWith(color: QColors.softEmber)),
        if (q.verse case final QuranEvidence verse) ...[
          const SizedBox(height: QSpace.sm),
          QCard(
            child: Column(
              children: [
                QuranText(verse),
                if (verse.translation != null) ...[
                  const SizedBox(height: QSpace.sm),
                  Text(verse.translation!, style: context.text.bodyMedium),
                ],
              ],
            ),
          ),
        ],
        if (q.statement.isNotEmpty) ...[
          const SizedBox(height: QSpace.sm),
          SpanText(q.statement, style: context.text.titleMedium?.copyWith(color: QColors.softEmber)),
        ],
        const SizedBox(height: QSpace.md),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: QSpace.sm),
            child: OptionTile(
              key: ValueKey('challenge-option-$i'),
              index: i,
              spans: q.options[i].spans.isEmpty
                  ? [
                      TextContentSpan(
                        text: q.options[i].choice.value == true ? context.l10n.sessionTrueLabel : context.l10n.sessionFalseLabel,
                      ),
                    ]
                  : q.options[i].spans,
              state: !reveal
                  ? s.answer == q.options[i].choice
                        ? TileState.selected
                        : TileState.idle
                  : q.options[i].choice == s.reveal!.correctAnswer
                  ? TileState.correct
                  : s.answer == q.options[i].choice
                  ? TileState.wrong
                  : TileState.dimmed,
              onTap: canAnswer ? () => context.read<ChallengeBloc>().add(ChallengeAnswerSelected(q.options[i].choice)) : null,
            ),
          ),
        if (s.locked && !reveal) Text(context.l10n.challengeAnswered, style: context.text.bodySmall?.copyWith(color: QColors.softEmber)),
        const Spacer(),
        if (reveal && fastest != null)
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(QSpace.sm),
              decoration: BoxDecoration(color: QColors.flameGold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(QRadius.md)),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: QChallenge.gap,
                children: [
                  const Icon(Icons.bolt_rounded, color: QColors.flameGold),
                  Text(context.l10n.challengeFastest, style: context.text.labelLarge?.copyWith(color: QColors.flameGold)),
                  TravelerAvatar.fromKey(avatarKey: s.challenge!.players.firstWhere((p) => p.id == fastest.id).avatar, size: QSpace.xl),
                  Text(
                    '${_name(context, s.challenge!.players.firstWhere((p) => p.id == fastest.id))} · ${context.l10n.challengeSeconds(context.n(fastest.elapsedMs / 1000))}',
                    style: context.text.labelLarge?.copyWith(color: QColors.softEmber),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showSummary(BuildContext context, ChallengeState s) {
    showQSheet(
      context,
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.challengeSummary, style: context.text.titleLarge),
          for (final answer in s.summary) ...[
            const SizedBox(height: QSpace.md),
            SpanText(answer.prompt),
            const SizedBox(height: QSpace.sm),
            SpanText(answer.explanation),
          ],
        ],
      ),
    );
  }

  Widget _results(BuildContext context, ChallengeState s, {required bool compact}) {
    final r = s.result!, won = r.winners.contains(s.challenge!.myId);
    return Stack(
      children: [
        if (won) const Positioned.fill(child: IgnorePointer(child: EmberBurst(count: 40))),
        Column(
          children: [
            CharacterView(size: QChallenge.hero, controller: _character),
            Text(
              r.isDraw
                  ? context.l10n.challengeDraw
                  : won
                  ? context.l10n.challengeYouWon
                  : context.l10n.challengeWellPlayed,
              style: context.qText.display.copyWith(color: QColors.softEmber, fontSize: QChallenge.title),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: QSpace.lg),
            for (var i = 0; i < r.scores.length; i++)
              Reveal(
                delay: QMotion.reveal120 * i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: QSpace.xs),
                  padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QSpace.sm),
                  decoration: BoxDecoration(
                    color: r.scores[i].id == s.challenge!.myId
                        ? QColors.flameGold.withValues(alpha: 0.16)
                        : QColors.night800.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(QRadius.md),
                    border: Border.all(
                      color: r.scores[i].id == s.challenge!.myId ? QColors.flameGold : QColors.nightLine,
                      width: QCommunity.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: QCommunity.rank,
                        child: r.scores[i].rank == 1
                            ? const Icon(Icons.workspace_premium_rounded, color: QColors.flameGold)
                            : Text(context.n(r.scores[i].rank), style: context.text.labelLarge?.copyWith(color: QColors.softEmber)),
                      ),
                      const SizedBox(width: QSpace.xs),
                      TravelerAvatar.fromKey(
                        avatarKey: s.challenge!.players.firstWhere((p) => p.id == r.scores[i].id).avatar,
                        size: QChallenge.resultAvatar,
                      ),
                      const SizedBox(width: QSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _name(context, s.challenge!.players.firstWhere((p) => p.id == r.scores[i].id)),
                              style: context.text.titleSmall?.copyWith(color: QColors.softEmber),
                            ),
                            if (compact)
                              Text(
                                '${context.n(r.scores[i].points)} ${context.l10n.challengePoints}',
                                style: context.text.labelLarge?.copyWith(color: QColors.flameGold),
                              ),
                          ],
                        ),
                      ),
                      if (!compact)
                        Text(
                          '${context.n(r.scores[i].points)} ${context.l10n.challengePoints}',
                          style: context.text.labelLarge?.copyWith(color: QColors.flameGold),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: QSpace.sm),
            Tag(
              context.l10n.commonPlusEmbers(context.n(r.xp)),
              icon: Icons.local_fire_department_rounded,
              color: QColors.flameGold,
              background: QColors.flameGold.withValues(alpha: 0.14),
            ),
            const Spacer(),
            QButton(
              key: const ValueKey('challenge-done'),
              label: context.l10n.challengeDone,
              tone: QButtonTone.gold,
              onPressed: () => context.canPop() ? context.pop() : context.go('/community'),
            ),
            const SizedBox(height: QSpace.xs),
            QButton(
              label: context.l10n.challengePlayAgain,
              tone: QButtonTone.night,
              onPressed: () => context.read<ChallengeBloc>().add(const ChallengeReplayed()),
            ),
          ],
        ),
      ],
    );
  }
}
