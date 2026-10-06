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
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/pages/other_session_result_view.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

class SessionResultPage extends StatefulWidget {
  const SessionResultPage({super.key});
  @override
  State<SessionResultPage> createState() => _SessionResultPageState();
}

class _SessionResultPageState extends State<SessionResultPage> {
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
  Widget build(BuildContext context) => ContentInteractions(
    child: BlocConsumer<SessionResultBloc, SessionResultState>(
      listener: (context, state) {
        if (state.session case final session?) {
          context.read<ContentBloc>().add(ContentReceived(session.terms, session.sources));
        }
        if (state.status == SessionResultStatus.ready && !_celebrated) {
          _celebrated = true;
          _controller.cue(CharacterCue.complete);
          _sound = Timer(QCompletion.soundDelay, () {
            if (mounted) {
              SensoryScope.of(context).complete();
            }
          });
        }
      },
      builder: (context, state) {
        if (state.status != SessionResultStatus.ready) {
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
                    child: state.status == SessionResultStatus.failure
                        ? QErrorView(
                            kind: failureKind(state.failure!),
                            tone: QTone.night,
                            onRetry: () => context.read<SessionResultBloc>().add(const SessionResultRetried()),
                          )
                        : const QLoadingView(tone: QTone.night),
                  ),
                ],
              ),
            ),
          );
        }
        final result = state.result!;
        if (result.kind != 'lesson') {
          return OtherSessionResultView(
            result: result,
            session: state.session!,
            controller: _controller,
            onContinue: () => context.go(result.streakExtended ? '/streak?celebrate=1' : '/journey'),
          );
        }
        return SessionResultView(
          result: result,
          completion: state.session?.completion,
          controller: _controller,
          onContinue: () => context.go(result.streakExtended ? '/streak?celebrate=1' : '/journey'),
        );
      },
    ),
  );
}

/// Layout ported from lesson_complete_screen.dart; values come from the result.
class SessionResultView extends StatelessWidget {
  const SessionResultView({super.key, required this.result, required this.completion, required this.controller, required this.onContinue});
  final SessionResult result;
  final LessonCompletion? completion;
  final CharacterController controller;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QColors.night950,
        body: NightSky(
          density: 1,
          child: Stack(
            children: [
              const Positioned.fill(child: EmberBurst(count: QCompletion.burst)),
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('result-scroll'),
                      padding: EdgeInsets.fromLTRB(QSpace.page, top + QSpace.md, QSpace.page, QSpace.xl),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    const Positioned(
                                      bottom: QCompletion.heroGlowBottom,
                                      child: Glow(size: QCompletion.heroGlow, opacity: QCompletion.glowOpacity),
                                    ),
                                    CharacterView(size: QCompletion.hero, controller: controller),
                                  ],
                                ),
                              ),
                              Reveal(
                                delay: QMotion.reveal300,
                                child: Text(
                                  context.l10n.sessionLessonComplete,
                                  textAlign: TextAlign.center,
                                  style: context.qText.display.copyWith(color: QColors.softEmber),
                                ),
                              ),
                              const SizedBox(height: QSpace.xs),
                              Reveal(
                                delay: QCompletion.reveal400,
                                child: Text(
                                  context.l10n.sessionLessonCompleteSub,
                                  textAlign: TextAlign.center,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: QColors.softEmber.withValues(alpha: QCompletion.subtitleAlpha),
                                  ),
                                ),
                              ),
                              const SizedBox(height: QSpace.xl),
                              Reveal(
                                delay: QMotion.slow,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _StatTile(
                                        label: context.l10n.sessionStatEmbers,
                                        color: QColors.flameGold,
                                        icon: const EmberIcon(size: QCompletion.icon),
                                        value: result.xp,
                                        format: (v) => '+${context.n(v)}',
                                      ),
                                    ),
                                    const SizedBox(width: QSpace.sm),
                                    Expanded(
                                      child: _StatTile(
                                        label: context.l10n.sessionStatAccuracy,
                                        color: QColors.emerald400,
                                        icon: const Icon(Icons.track_changes_rounded, size: QCompletion.icon, color: QColors.emerald400),
                                        value: result.percent,
                                        format: (v) => context.l10n.commonPercent(context.n(v)),
                                      ),
                                    ),
                                    const SizedBox(width: QSpace.sm),
                                    Expanded(
                                      child: _StatTile(
                                        label: context.l10n.sessionStatTime,
                                        color: QColors.sky,
                                        icon: const Icon(Icons.timer_outlined, size: QCompletion.icon, color: QColors.sky),
                                        value: result.duration.inSeconds,
                                        format: (value) =>
                                            '${context.n(value ~/ 60)}:${context.n(value % 60).padLeft(2, context.isArabic ? '٠' : '0')}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (result.perfect) ...[
                                const SizedBox(height: QSpace.sm),
                                Reveal(
                                  delay: QCompletion.reveal640,
                                  child: Center(
                                    child: Tag(
                                      context.l10n.sessionPerfectBonus,
                                      icon: Icons.auto_awesome_rounded,
                                      color: QColors.flameGold,
                                      background: QColors.flameGold.withValues(alpha: QCompletion.perfectAlpha),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: QSpace.lg),
                              Reveal(
                                delay: QCompletion.reveal700,
                                child: _MasteryCard(result: result, completion: completion),
                              ),
                              if (completion != null) ...[
                                const SizedBox(height: QSpace.md),
                                Reveal(
                                  delay: QCompletion.reveal820,
                                  child: QCard(
                                    color: QColors.gold50,
                                    borderColor: QColors.gold100,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.flag_rounded, color: QColors.gold800, size: QCompletion.challengeIcon),
                                            const SizedBox(width: QCompletion.gap),
                                            Flexible(
                                              child: Text(
                                                context.l10n.sessionTodaysChallenge.toUpperCase(),
                                                style: context.qText.eyebrow.copyWith(color: QColors.gold800),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: QSpace.xs),
                                        SpanText(completion!.challenge, style: context.text.bodyLarge),
                                        const SizedBox(height: QSpace.sm),
                                        const DottedLine(color: QColors.gold100),
                                        const SizedBox(height: QSpace.sm),
                                        Text(
                                          context.l10n.sessionTomorrowWeAsk,
                                          style: context.text.labelMedium?.copyWith(color: QColors.gold800),
                                        ),
                                        const SizedBox(height: QCompletion.bubbleGap),
                                        SpanText(completion!.checkIn, style: context.text.bodyMedium?.copyWith(color: QColors.deepInk)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (result.nextStep?.title != null) ...[
                                const SizedBox(height: QSpace.md),
                                Reveal(
                                  delay: QCompletion.reveal900,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock_open_rounded, color: QColors.flameGold, size: QCompletion.icon),
                                      const SizedBox(width: QCompletion.gap),
                                      Flexible(
                                        child: Text(
                                          context.l10n.sessionNextOnPath(result.nextStep!.title!),
                                          textAlign: TextAlign.center,
                                          style: context.text.labelMedium?.copyWith(
                                            color: QColors.softEmber.withValues(alpha: QCompletion.nextAlpha),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(QSpace.page, QSpace.sm, QSpace.page, QSpace.md + MediaQuery.paddingOf(context).bottom),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                      child: QButton(
                        label: context.l10n.commonContinue,
                        tone: QButtonTone.gold,
                        key: const ValueKey('result-continue'),
                        onPressed: onContinue,
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.color, required this.icon, required this.value, required this.format});
  final String label;
  final Color color;
  final Widget icon;
  final int value;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(QRadius.md)),
      padding: const EdgeInsets.all(QCompletion.statInset),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: QCompletion.labelPadding),
            child: Text(
              label.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: color == QColors.flameGold ? QColors.deepInk : QColors.surface,
                fontSize: QCompletion.statLabel,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: QCompletion.statPadding),
            decoration: BoxDecoration(color: QColors.night900, borderRadius: BorderRadius.circular(QRadius.md - QCompletion.statInset)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: QCompletion.gap),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: CountUp(
                      value: value,
                      format: format,
                      style: context.qText.stat.copyWith(color: color, fontSize: QCompletion.statValue),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard({required this.result, required this.completion});
  final SessionResult result;
  final LessonCompletion? completion;

  @override
  Widget build(BuildContext context) {
    Widget bar(String label, double? v) => Padding(
      padding: const EdgeInsets.only(bottom: QSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: QCompletion.masteryLabel,
            child: Text(label, style: context.text.labelMedium?.copyWith(color: QColors.deepInk)),
          ),
          Expanded(
            child: v == null
                ? Container(
                    height: QCompletion.bar,
                    decoration: BoxDecoration(
                      borderRadius: QRadius.chip,
                      border: Border.all(color: QColors.lineStrong, width: QCompletion.border),
                      color: QColors.surfaceSunk,
                    ),
                  )
                : ClipRRect(
                    borderRadius: QRadius.chip,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: context.reduceMotion ? v : 0, end: v),
                      duration: context.reduceMotion ? Duration.zero : QCompletion.barMotion,
                      curve: QMotion.emphasized,
                      builder: (_, x, _) => LinearProgressIndicator(
                        value: x,
                        minHeight: QCompletion.bar,
                        backgroundColor: QColors.line,
                        color: QColors.correct,
                      ),
                    ),
                  ),
          ),
          SizedBox(
            width: QCompletion.masteryValue,
            child: Text(
              v == null ? context.l10n.sessionSoon : context.l10n.commonPercent(context.n((v * 100).round())),
              textAlign: TextAlign.end,
              style: context.text.labelMedium?.copyWith(color: v == null ? QColors.muted : QColors.correct),
            ),
          ),
        ],
      ),
    );
    return QCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.sessionYourMastery, style: context.text.titleLarge),
          const SizedBox(height: QCompletion.bubbleGap),
          Text(context.l10n.sessionMasteryNote, style: context.text.bodySmall),
          const SizedBox(height: QSpace.md),
          bar(context.l10n.sessionUnderstanding, result.understanding == null ? null : result.understanding!.percent / 100),
          bar(context.l10n.sessionApplying, result.applying == null ? null : result.applying!.percent / 100),
          bar(context.l10n.sessionRemembering, null),
          const SizedBox(height: QSpace.xs),
          const DottedLine(color: QColors.line),
          const SizedBox(height: QSpace.sm),
          Text(context.l10n.sessionComesBack, style: context.text.titleSmall),
          const SizedBox(height: QSpace.xs),
          for (final item in completion?.reviewTopics ?? <ReviewTopic>[])
            Padding(
              padding: const EdgeInsets.only(bottom: QSpace.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: QCompletion.bulletTop),
                    child: Icon(Icons.circle, size: QCompletion.bullet, color: QColors.flameGold),
                  ),
                  const SizedBox(width: QSpace.xs),
                  Expanded(
                    child: Text(item.title, style: context.text.bodyMedium?.copyWith(color: QColors.deepInk)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
