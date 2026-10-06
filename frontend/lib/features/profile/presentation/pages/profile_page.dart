import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/router/routes.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/presentation/brand/achievement_badge.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.developerEnabled = false, this.reviewerSampleEnabled = false});
  final bool developerEnabled, reviewerSampleEnabled;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _character = CharacterController();
  @override
  void dispose() {
    _character.dispose();
    super.dispose();
  }

  void _editName() {
    final bloc = context.read<ProfileBloc>();
    if (bloc.state.status == ProfileStatus.saving) return;
    showQSheet(
      context,
      builder: (_) => BlocProvider.value(value: bloc, child: const _NameEditor()),
    );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ProfileBloc, ProfileState>(
    listener: (context, state) {
      if (state.status == ProfileStatus.ready) _character.cue(CharacterCue.greet);
      if (state.notice > 0 && state.failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.status == ProfileStatus.failure
                  ? failureBody(state.failure!, context.l10n)
                  : state.failure is ValidationFailure
                  ? context.l10n.profileNameValidation
                  : context.l10n.settingsSaveFailed,
            ),
          ),
        );
      }
    },
    listenWhen: (a, b) => a.notice != b.notice || (a.snapshot == null && b.snapshot != null),
    builder: (context, state) {
      final data = state.snapshot;
      if (data == null) {
        return Scaffold(
          body: state.status == ProfileStatus.failure
              ? QErrorView(kind: failureKind(state.failure!), onRetry: () => context.read<ProfileBloc>().add(const ProfileOpened()))
              : const QLoadingView(),
        );
      }
      final l = context.l10n, user = data.user;
      final joinedDate = user.createdAt.toLocal();
      final joined = MaterialLocalizations.of(
        context,
      ).formatMonthYear(joinedDate).replaceAll('${joinedDate.year}', context.n(joinedDate.year));
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: CustomScrollView(
            key: const PageStorageKey('profile-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(gradient: QGradients.night),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: NightSky(density: QProfile.skyDensity)),
                      SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Padding(
                                padding: const EdgeInsets.all(QSpace.xs),
                                child: QIconButton(
                                  key: const ValueKey('profile-settings'),
                                  icon: Icons.settings_rounded,
                                  color: QColors.softEmber,
                                  tooltip: l.profileSettings,
                                  onTap: () => context.push(Routes.settings),
                                ),
                              ),
                            ),
                            GestureDetector(
                              key: const ValueKey('profile-avatar'),
                              behavior: HitTestBehavior.opaque,
                              onLongPress: widget.developerEnabled ? () => context.push(Routes.developer) : null,
                              child: CharacterView(size: QProfile.hero, controller: _character),
                            ),
                            const SizedBox(height: QSpace.xs),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
                              child: Semantics(
                                button: true,
                                label: l.profileEditName,
                                child: Pressable(
                                  onTap: _editName,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.displayName.isEmpty ? l.profileLearnerName : user.displayName,
                                          key: const ValueKey('profile-name'),
                                          textAlign: TextAlign.center,
                                          style: context.text.headlineMedium?.copyWith(color: QColors.softEmber),
                                        ),
                                      ),
                                      const SizedBox(width: QProfile.gap),
                                      Icon(Icons.edit_rounded, size: QProfile.editIcon, color: QColors.softEmber.withValues(alpha: 0.6)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: QSpace.xxs),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: QProfile.gap,
                                runSpacing: QProfile.gap,
                                children: [
                                  Tag(
                                    user.track == UserTrack.newMuslim ? l.commonPathNewMuslimLong : l.commonPathExplorerLong,
                                    color: QColors.flameGold,
                                    background: QColors.flameGold.withValues(alpha: 0.15),
                                  ),
                                  Tag(
                                    l.profileJoined(joined),
                                    color: QColors.softEmber,
                                    background: QColors.surface.withValues(alpha: 0.08),
                                  ),
                                  if (user.privateProfile)
                                    Tag(
                                      l.profilePrivateBadge,
                                      icon: Icons.lock_rounded,
                                      color: QColors.softEmber,
                                      background: QColors.surface.withValues(alpha: 0.08),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: QSpace.lg),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.lg, QSpace.page, QSpace.xxl),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.status == ProfileStatus.loading) const QInlineLoading(),
                          if (state.status == ProfileStatus.failure)
                            Padding(
                              padding: const EdgeInsets.only(bottom: QSpace.md),
                              child: QButton(
                                label: l.commonRetry,
                                tone: QButtonTone.outline,
                                onPressed: () => context.read<ProfileBloc>().add(const ProfileOpened()),
                              ),
                            ),
                          if (widget.reviewerSampleEnabled) ...[
                            QCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(l.reviewerConsole, style: context.text.titleLarge),
                                  const SizedBox(height: QSpace.sm),
                                  Text(l.reviewerSampleDescription, style: context.text.bodyMedium),
                                  const SizedBox(height: QSpace.md),
                                  QButton(
                                    key: const ValueKey('profile-reviewer-sample'),
                                    label: l.reviewerSampleOpen,
                                    onPressed: () => context.push('/reviewer/login'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: QSpace.xl),
                          ],
                          SectionHeader(l.profileStatistics),
                          _Statistics(data),
                          const SizedBox(height: QSpace.xl),
                          SectionHeader(
                            l.profileAchievementsTitle,
                            action: l.commonSeeAll,
                            onAction: () => context.push(Routes.achievements),
                          ),
                          if (data.achievements.isEmpty)
                            QCard(shadow: false, child: Text(l.profileNoAchievements, style: context.text.bodyMedium))
                          else
                            QCard(
                              onTap: () => context.push(Routes.achievements),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final a in data.achievements.take(4))
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Semantics(
                                            label: a.description,
                                            child: AchievementBadge(achievementKey: a.key, unlocked: a.unlocked, size: QProfile.badge),
                                          ),
                                          const SizedBox(height: QProfile.gap),
                                          Text(
                                            a.title,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.text.labelSmall?.copyWith(letterSpacing: 0),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: QSpace.xl),
                          SectionHeader(l.reviewYourWords, action: l.commonSeeAll, onAction: () => context.push(Routes.glossary)),
                          Text(
                            l.reviewWordsMasteredOf(context.n(data.stats.terms.mastered), context.n(data.stats.terms.seen)),
                            style: context.text.bodySmall,
                          ),
                          const SizedBox(height: QSpace.sm),
                          if (data.words.isEmpty) QCard(shadow: false, child: Text(l.profileNoWords, style: context.text.bodyMedium)),
                          for (final word in data.words)
                            Padding(
                              padding: const EdgeInsets.only(bottom: QSpace.xs),
                              child: _WordPreview(word),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Statistics extends StatelessWidget {
  const _Statistics(this.data);
  final ProfileSnapshot data;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, stats = data.stats;
    String n(num value) => context.n(value);
    final rows = [
      (StreakFlame(size: QProfile.statIcon, lit: stats.streak.todayCompleted), n(stats.streak.current), l.profileStatStreak),
      (const EmberIcon(size: QProfile.statIcon), n(stats.xpTotal), l.profileStatTotal),
      (const Icon(Icons.translate_rounded, color: QColors.sky), n(stats.terms.mastered), l.profileStatWords),
      (const Icon(Icons.school_rounded, color: QColors.emerald400), n(stats.lessonsCompleted), l.profileStatLessons),
      (
        const Icon(Icons.shield_rounded, color: QColors.emerald500),
        stats.league == null ? l.profileNoLeague : l.profileLeagueRank(n(stats.league!.rank)),
        l.profileStatLeague,
      ),
      (
        const Icon(Icons.workspace_premium_rounded, color: QColors.flameGold),
        '${n(data.achievements.where((a) => a.unlocked).length)}/${n(data.achievements.length)}',
        l.profileStatBadges,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - QSpace.sm) / 2;
        final scaled = MediaQuery.textScalerOf(context).scale(1) > 1;
        final height = scaled ? QProfile.scaledStatHeight : (width / QProfile.statAspect).clamp(QProfile.statMinHeight, double.infinity);
        return Wrap(
          spacing: QSpace.sm,
          runSpacing: QSpace.sm,
          children: [
            for (var i = 0; i < rows.length; i++)
              SizedBox(
                width: width,
                height: height,
                child: Reveal(
                  delay: QProfile.statStagger * i,
                  child: QCard(
                    key: i == 0 ? const ValueKey('profile-streak-calendar') : null,
                    onTap: i == 0 ? () => context.push(Routes.streak) : null,
                    shadow: false,
                    padding: const EdgeInsets.symmetric(horizontal: QSpace.sm, vertical: QSpace.xs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: QProfile.statIconBox,
                          child: Center(child: rows[i].$1),
                        ),
                        const SizedBox(width: QSpace.xs),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(rows[i].$2, style: context.qText.stat.copyWith(fontSize: QProfile.statValue)),
                              ),
                              Text(rows[i].$3, maxLines: 2, style: context.text.bodySmall?.copyWith(fontSize: QProfile.statLabel)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WordPreview extends StatelessWidget {
  const _WordPreview(this.word);
  final TermCard word;
  @override
  Widget build(BuildContext context) {
    final known = word.state == TermState.mastered;
    // A-44: the wire exposes a state, not a numeric strength. Use discrete ring stops.
    final value = switch (word.state) {
      TermState.mastered => 1.0,
      TermState.learning => 0.5,
      _ => 0.0,
    };
    return QCard(
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QSpace.sm),
      onTap: () => context.push(Routes.glossary),
      child: Row(
        children: [
          RingProgress(
            value: value,
            size: QProfile.wordRing,
            stroke: QProfile.ringStroke,
            color: known ? QColors.correct : QColors.flameGold,
            child: known ? const Icon(Icons.check_rounded, size: QProfile.editIcon, color: QColors.correct) : null,
          ),
          const SizedBox(width: QSpace.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final arabic = word.arabic;
                final description = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.text, style: context.text.titleSmall),
                    Text(
                      word.definition
                          .map(
                            (span) => switch (span) {
                              TextContentSpan(:final text) ||
                              StrongContentSpan(:final text) ||
                              TermContentSpan(:final text) ||
                              UnknownContentSpan(:final text) => text,
                              _ => '',
                            },
                          )
                          .join(),
                      style: context.text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
                if (arabic == null) return description;
                final secondary = Text(
                  arabic,
                  textDirection: TextDirection.rtl,
                  style: QContentText.termArabic.copyWith(fontSize: QProfile.wordArabic, color: QColors.emerald),
                );
                if (constraints.maxWidth < QProfile.wordInlineMinimum) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [description, secondary]);
                }
                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: QSpace.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * QProfile.wordArabicFraction),
                      child: secondary,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NameEditor extends StatefulWidget {
  const _NameEditor();
  @override
  State<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends State<_NameEditor> {
  late final _controller = TextEditingController(text: context.read<ProfileBloc>().state.snapshot!.user.displayName);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ProfileBloc, ProfileState>(
    listenWhen: (a, b) => a.nameSaved != b.nameSaved,
    listener: (context, _) => Navigator.pop(context),
    builder: (context, state) {
      final valid = _controller.text.trim().runes.length >= 2 && _controller.text.trim().runes.length <= 24;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.profileEditName, style: context.text.headlineSmall),
          const SizedBox(height: QSpace.md),
          TextField(
            key: const ValueKey('profile-name-input'),
            controller: _controller,
            autofocus: true,
            enabled: state.status != ProfileStatus.saving,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.profileEditName,
              helperText: context.l10n.profileNameValidation,
              errorText: state.failure == null
                  ? null
                  : state.failure is ValidationFailure
                  ? context.l10n.profileNameValidation
                  : context.l10n.settingsSaveFailed,
              filled: true,
              fillColor: QColors.surfaceSunk,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(QRadius.md), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: QSpace.lg),
          QButton(
            key: const ValueKey('profile-name-save'),
            label: context.l10n.profileSave,
            onPressed: valid && state.status != ProfileStatus.saving
                ? () => context.read<ProfileBloc>().add(DisplayNameSubmitted(_controller.text))
                : null,
          ),
        ],
      );
    },
  );
}
