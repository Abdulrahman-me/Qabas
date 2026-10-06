import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/streak/domain/activity.dart';
import 'package:qabas/features/streak/presentation/bloc/streak_bloc.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class StreakPage extends StatefulWidget {
  const StreakPage({super.key});
  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  final _controller = CharacterController();
  Timer? _sound;
  bool _celebrated = false;
  @override
  void dispose() {
    _sound?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<StreakBloc, StreakState>(
    listener: (context, state) {
      if (state.status == StreakStatus.ready && state.celebrate && !_celebrated) {
        _celebrated = true;
        _controller.cue(CharacterCue.streak);
        _sound = Timer(QStreak.soundDelay, () {
          if (mounted) {
            SensoryScope.of(context).streak();
          }
        });
      }
    },
    builder: (context, state) {
      if (state.status != StreakStatus.ready) {
        return Scaffold(
          backgroundColor: QColors.night950,
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: QIconButton(
                    key: const ValueKey('celebration-close'),
                    icon: Icons.close_rounded,
                    color: QColors.softEmber,
                    tooltip: context.l10n.commonClose,
                    onTap: () => context.go('/journey'),
                  ),
                ),
                Expanded(
                  child: state.status == StreakStatus.failure
                      ? QErrorView(
                          kind: failureKind(state.failure!),
                          tone: QTone.night,
                          onRetry: () => context.read<StreakBloc>().add(const StreakRetried()),
                        )
                      : const QLoadingView(tone: QTone.night),
                ),
              ],
            ),
          ),
        );
      }
      return StreakView(activity: state.activity!, celebrate: state.celebrate, controller: _controller);
    },
  );
}

class StreakView extends StatelessWidget {
  const StreakView({super.key, required this.activity, required this.celebrate, required this.controller});
  final Activity activity;
  final bool celebrate;
  final CharacterController controller;
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QColors.night950,
        body: NightSky(
          child: Stack(
            children: [
              if (celebrate)
                const Positioned.fill(
                  child: EmberBurst(count: QStreak.burst, duration: QStreak.burstMotion),
                ),
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(QSpace.xs, top + QSpace.xxs, QSpace.xs, 0),
                    child: Row(
                      children: [
                        if (!celebrate)
                          QIconButton(
                            icon: Icons.close_rounded,
                            color: QColors.softEmber,
                            tooltip: context.l10n.commonClose,
                            onTap: () => context.canPop() ? context.pop() : context.go('/journey'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                          child: Column(
                            children: [
                              SizedBox(
                                height: QStreak.hero,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    const Glow(size: QStreak.glow, opacity: QStreak.glowOpacity),
                                    if (celebrate)
                                      Positioned(
                                        bottom: 0,
                                        child: CharacterView(size: QStreak.hero, controller: controller),
                                      )
                                    else
                                      const Positioned(
                                        top: QStreak.flameTop,
                                        child: FlameMark(size: QStreak.flame, glow: QStreak.flameGlow),
                                      ),
                                  ],
                                ),
                              ),
                              RollingNumber(
                                from: celebrate && activity.streak.current > 0 ? activity.streak.current - 1 : activity.streak.current,
                                to: activity.streak.current,
                                animate: celebrate,
                              ),
                              Text(
                                context.l10n.streakDayStreakLabel,
                                style: context.text.titleLarge?.copyWith(
                                  color: QColors.flameGold,
                                  letterSpacing: context.isArabic ? 0 : QStreak.letterSpacing,
                                ),
                              ),
                              const SizedBox(height: QSpace.md),
                              Text(
                                activity.streak.todayCompleted ? context.l10n.streakStreakBody : context.l10n.streakKeepFlameWarm,
                                textAlign: TextAlign.center,
                                style: context.text.bodyLarge?.copyWith(color: QColors.softEmber.withValues(alpha: QStreak.bodyAlpha)),
                              ),
                              const SizedBox(height: QSpace.xl),
                              _WeekRow(activity: activity, celebrate: celebrate),
                              if (!celebrate) ...[const SizedBox(height: QSpace.lg), _MonthCalendar(activity: activity)],
                              const SizedBox(height: QSpace.xl),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (celebrate)
                    Padding(
                      padding: EdgeInsets.fromLTRB(QSpace.page, QSpace.sm, QSpace.page, QSpace.md + MediaQuery.paddingOf(context).bottom),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                        child: QButton(
                          key: const ValueKey('streak-continue'),
                          label: context.l10n.streakStreakKeep,
                          tone: QButtonTone.gold,
                          onPressed: () => context.go('/journey'),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.celebrate, required this.activity});
  final Activity activity;
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final days = activity.week;
    final names = MaterialLocalizations.of(context).narrowWeekdays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: QSpace.sm, vertical: QSpace.md),
      decoration: BoxDecoration(
        color: QColors.night800.withValues(alpha: QStreak.rowAlpha),
        borderRadius: BorderRadius.circular(QRadius.lg),
        border: Border.all(color: QColors.nightLine, width: QStreak.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    names[days[i].weekday % 7],
                    style: context.text.labelMedium?.copyWith(color: QColors.softEmber.withValues(alpha: i == 6 ? 1 : QStreak.otherAlpha)),
                  ),
                  const SizedBox(height: QSpace.xs),
                  Reveal(
                    delay: celebrate ? (i == 6 ? QStreak.todayReveal : QMotion.reveal300 + QStreak.dayStagger * i) : Duration.zero,
                    scale: QStreak.dayScale,
                    offset: Offset.zero,
                    curve: QMotion.settle,
                    child: _DayDot(lit: activity.qualifies(days[i]), today: i == 6),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.lit, required this.today});
  final bool lit;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: QStreak.day,
      height: QStreak.day,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? QColors.flameGold.withValues(alpha: QStreak.dotAlpha) : QColors.surface.withValues(alpha: QStreak.emptyAlpha),
        border: Border.all(color: lit ? QColors.flameGold : QColors.nightLine, width: today ? QStreak.todayBorder : QStreak.border),
        boxShadow: lit && today ? QShadows.glow(QColors.flameGold, strength: QStreak.glowStrength) : null,
      ),
      child: Semantics(
        label: today ? context.l10n.streakToday : null,
        selected: lit,
        child: Center(child: lit ? const FlameMark(size: QStreak.dayFlame, animate: false) : null),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.activity});
  final Activity activity;
  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context), today = activity.to;
    final weekStart = today.subtract(Duration(days: (today.weekday % 7 - loc.firstDayOfWeekIndex) % 7));
    final first = weekStart.subtract(const Duration(days: 28));
    return Container(
      padding: const EdgeInsets.all(QSpace.md),
      decoration: BoxDecoration(
        color: QColors.night800.withValues(alpha: QStreak.rowAlpha),
        borderRadius: BorderRadius.circular(QRadius.lg),
        border: Border.all(color: QColors.nightLine, width: QStreak.border),
      ),
      child: Column(
        children: [
          Text(context.l10n.streakLastFiveWeeks, style: context.text.titleMedium?.copyWith(color: QColors.softEmber)),
          const SizedBox(height: QSpace.sm),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      loc.narrowWeekdays[(i + loc.firstDayOfWeekIndex) % 7],
                      style: context.text.labelSmall?.copyWith(color: QColors.softEmber.withValues(alpha: QStreak.otherAlpha)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: QSpace.xs),
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 35; i++)
                Builder(
                  builder: (context) {
                    final d = first.add(Duration(days: i)), lit = activity.qualifies(d), future = d.isAfter(today);
                    return Center(
                      child: Semantics(
                        label: loc.formatFullDate(d),
                        selected: lit,
                        child: Container(
                          width: QStreak.day,
                          height: QStreak.day,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lit ? QColors.flameGold.withValues(alpha: QStreak.dotAlpha) : null,
                            border: d == today ? Border.all(color: QColors.flameGold, width: QStreak.todayBorder) : null,
                          ),
                          child: Text(
                            context.n(d.day),
                            style: context.text.labelMedium?.copyWith(
                              color: lit
                                  ? QColors.flameGold
                                  : QColors.softEmber.withValues(alpha: future ? QChallenge.waiting : QStreak.otherAlpha),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
