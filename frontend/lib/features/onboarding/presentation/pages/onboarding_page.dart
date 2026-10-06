import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';

part 'onboarding_pages.dart';

/// Ports the prototype's PageView and one persistent companion; the flow lives
/// in OnboardingBloc. Short windows scroll the composition without losing state.
class OnboardingPageView extends StatefulWidget {
  const OnboardingPageView({super.key, required this.onCompleted});
  final ValueChanged<UserProfile> onCompleted;
  @override
  State<OnboardingPageView> createState() => _OnboardingPageViewState();
}

class _OnboardingPageViewState extends State<OnboardingPageView> {
  final _pager = PageController();
  final _companion = CharacterController();
  Timer? _languageDelay;
  @override
  void dispose() {
    _languageDelay?.cancel();
    _pager.dispose();
    _companion.dispose();
    super.dispose();
  }

  void _pickLanguage(String language) {
    if (_languageDelay != null) return;
    // Immediate locale change, while keeping the prototype's brief choice cue.
    context.read<OnboardingBloc>().add(LanguagePicked(language));
    _languageDelay = Timer(context.reduceMotion ? Duration.zero : QMotion.languageChoice, () {
      _languageDelay = null;
      if (mounted) _next();
    });
  }

  void _listen(BuildContext context, OnboardingState state) {
    if (state.status == OnboardingStatus.complete && state.user != null) {
      widget.onCompleted(state.user!);
      return;
    }
    final previous = _previous;
    if (previous?.page != state.page || previous?.curiosity != state.curiosity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pager.hasClients) return;
        if (context.reduceMotion) {
          _pager.jumpToPage(state.pageIndex);
        } else {
          unawaited(_pager.animateToPage(state.pageIndex, duration: QMotion.page, curve: QMotion.emphasized));
        }
      });
      if (state.page == OnboardingPage.ready && previous?.page != state.page) {
        _companion.cue(CharacterCue.celebrate);
        SensoryScope.of(context).complete();
      }
    }
    if (previous != null && previous.selectionSerial != state.selectionSerial) {
      _companion.cue(state.page == OnboardingPage.familiarity ? CharacterCue.encourage : CharacterCue.correct);
    }
    _previous = state;
  }

  OnboardingState? _previous;
  void _next() => context.read<OnboardingBloc>().add(const PageAdvanced());
  void _back() => context.read<OnboardingBloc>().add(const PageBacked());
  String _bubble(BuildContext context, OnboardingState state) {
    final l = context.l10n;
    final welcome = state.track == TrackChoice.newMuslim ? l.onboardingWelcomeNewMuslim : l.onboardingWelcomeExplorer;
    return switch (state.page) {
      OnboardingPage.who => state.track == null ? l.onboardingWhoBubble : welcome,
      OnboardingPage.curiosity => state.curiosity?.question ?? l.onboardingWhoBubble,
      OnboardingPage.familiarity => welcome,
      OnboardingPage.goal => l.onboardingGoalBubble,
      OnboardingPage.privacy => l.onboardingPrivacyTitle,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OnboardingBloc, OnboardingState>(
    listener: _listen,
    builder: (context, state) {
      final l = context.l10n;
      final compact = MediaQuery.sizeOf(context).height < QOnboarding.compactHeight;
      final heroSize = compact ? QOnboarding.heroCompact : QOnboarding.hero;
      final smallSize = compact ? QOnboarding.smallCompact : QOnboarding.small;
      final duration = context.reduceMotion ? Duration.zero : QMotion.page;
      final bubble = _bubble(context, state);
      final bubbleStyle = context.text.titleSmall!.copyWith(height: 1.4);
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            backgroundColor: QColors.night950,
            body: NightSky(
              density: 0.9,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final measured =
                            TextPainter(
                              text: TextSpan(text: bubble, style: bubbleStyle),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(
                              maxWidth: math.max(
                                QSizes.tapTarget,
                                box.maxWidth -
                                    QSpace.page * 2 -
                                    smallSize * QOnboarding.bubbleStartRatio -
                                    QOnboarding.bubbleHorizontalPadding,
                              ),
                            );
                        final headerHeight = state.hero
                            ? heroSize
                            : math.max(smallSize, measured.height + QOnboarding.bubbleVerticalPadding + QSpace.xs);
                        final scale = MediaQuery.textScalerOf(context).scale(1);
                        final height = math.max(box.maxHeight, QOnboarding.minimumHeight * scale);
                        return SingleChildScrollView(
                          key: const ValueKey('onboarding-scroll'),
                          child: SizedBox(
                            height: height,
                            child: AbsorbPointer(
                              absorbing: state.status == OnboardingStatus.submitting,
                              child: Column(
                                children: [
                                  AnimatedOpacity(
                                    duration: context.reduceMotion ? Duration.zero : QMotion.normal,
                                    opacity: !state.hero ? 1 : 0,
                                    child: IgnorePointer(
                                      ignoring: state.hero,
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional.fromSTEB(QSpace.xs, QSpace.xxs, QSpace.lg, 0),
                                        child: Row(
                                          children: [
                                            QIconButton(
                                              icon: Icons.arrow_back_rounded,
                                              color: QColors.softEmber,
                                              tooltip: l.commonBack,
                                              onTap: _back,
                                            ),
                                            const SizedBox(width: QSpace.xxs),
                                            Expanded(
                                              child: ProgressTrack(
                                                value: ((state.pageIndex - 1) / (state.pages.length - 2)).clamp(0, 1),
                                                height: QOnboarding.progressHeight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: duration,
                                    curve: QMotion.emphasized,
                                    height: headerHeight,
                                    padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
                                    child: Stack(
                                      children: [
                                        AnimatedAlign(
                                          duration: duration,
                                          curve: QMotion.emphasized,
                                          alignment: state.hero
                                              ? Alignment.bottomCenter
                                              : AlignmentDirectional.bottomStart.resolve(Directionality.of(context)),
                                          child: AnimatedContainer(
                                            duration: duration,
                                            curve: QMotion.emphasized,
                                            width: state.hero ? heroSize : smallSize * QOnboarding.smallWidthRatio,
                                            height: state.hero ? heroSize : smallSize,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.bottomCenter,
                                              children: [
                                                if (state.hero)
                                                  Positioned(
                                                    bottom: heroSize * QOnboarding.heroGlowBottom,
                                                    child: Glow(
                                                      size: heroSize * QOnboarding.heroGlowSize,
                                                      opacity: QOnboarding.heroGlowOpacity,
                                                    ),
                                                  ),
                                                Positioned.fill(
                                                  child: CharacterView(
                                                    controller: _companion,
                                                    size: state.hero ? heroSize : smallSize,
                                                    aspect: 1,
                                                    zoom: state.hero ? QOnboarding.heroZoom : QOnboarding.smallZoom,
                                                    appearCue: CharacterCue.greet,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (!state.hero)
                                          PositionedDirectional(
                                            start: smallSize * QOnboarding.bubbleStartRatio,
                                            end: 0,
                                            top: QSpace.xs,
                                            child: AnimatedSwitcher(
                                              duration: context.reduceMotion ? Duration.zero : QMotion.medium,
                                              transitionBuilder: (child, animation) => FadeTransition(
                                                opacity: animation,
                                                child: ScaleTransition(
                                                  scale: Tween(begin: QOnboarding.bubbleScale, end: 1.0).animate(animation),
                                                  alignment: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
                                                  child: child,
                                                ),
                                              ),
                                              layoutBuilder: (current, previous) =>
                                                  Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
                                              child: Align(
                                                key: ValueKey(bubble),
                                                alignment: AlignmentDirectional.topStart,
                                                child: SpeechBubble(child: Text(bubble, style: bubbleStyle)),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: PageView(
                                      controller: _pager,
                                      physics: const NeverScrollableScrollPhysics(),
                                      children: [
                                        for (final page in state.pages)
                                          KeyedSubtree(key: ValueKey(page), child: _page(context, page, state)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _page(BuildContext context, OnboardingPage page, OnboardingState state) {
    final l = context.l10n;
    final bloc = context.read<OnboardingBloc>();
    return switch (page) {
      OnboardingPage.language => _ExpandablePage(child: _LanguagePage(onPick: _pickLanguage)),
      OnboardingPage.welcome => _ExpandablePage(child: _WelcomePage(onStart: _next)),
      OnboardingPage.who => _ChoicePage(
        title: l.onboardingWhoTitle,
        options: [
          _Option(l.onboardingExplorerTitle, l.onboardingExplorerBody, art: UnitArt.starrySky),
          _Option(l.onboardingNewMuslimTitle, l.onboardingNewMuslimBody, art: UnitArt.footprints),
          _Option(l.onboardingPreferNotToSay, null),
        ],
        selected: state.track?.index,
        onSelect: (index) => bloc.add(TrackPicked(TrackChoice.values[index])),
        onContinue: state.track == null ? null : _next,
      ),
      OnboardingPage.curiosity => _curiosity(context, state),
      OnboardingPage.familiarity => _ChoicePage(
        title: l.onboardingFamiliarTitle,
        note: l.onboardingFamiliarNote,
        options: [
          _Option(l.onboardingFamiliarNew, null, bars: 1),
          _Option(l.onboardingFamiliarSome, null, bars: 2),
          _Option(l.onboardingFamiliarBasics, null, bars: 3),
        ],
        selected: state.familiarity?.index,
        onSelect: (index) => bloc.add(FamiliarityPicked(Familiarity.values[index])),
        onContinue: state.familiarity == null ? null : _next,
      ),
      OnboardingPage.goal => _ChoicePage(
        title: l.onboardingGoalTitle,
        options: [
          for (final entry in {
            5: l.onboardingGoalGentle,
            10: l.onboardingGoalSteady,
            15: l.onboardingGoalDedicated,
            20: l.onboardingGoalDeep,
          }.entries)
            _Option(
              entry.value,
              null,
              trailing: l.onboardingPerDay(QNumbers.prototypePluralCount(entry.key), QNumbers.format(entry.key, context.l10n.localeName)),
            ),
        ],
        selected: const [5, 10, 15, 20].indexOf(state.dailyGoal),
        onSelect: (index) => bloc.add(GoalPicked(const [5, 10, 15, 20][index])),
        onContinue: _next,
      ),
      OnboardingPage.privacy => _PrivacyPage(onContinue: _next),
      OnboardingPage.ready => _ReadyPage(state: state, onStart: () => bloc.add(const OnboardingSubmitted())),
    };
  }

  Widget _curiosity(BuildContext context, OnboardingState state) {
    final copy = state.curiosity;
    if (copy == null) return const SizedBox.shrink();
    final bloc = context.read<OnboardingBloc>();
    if (state.bridgeVisible && state.bridge != null) {
      return _ExpandablePage(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
          child: Column(
            children: [
              const SizedBox(height: QSpace.lg),
              Reveal(
                child: Text(
                  copy.options.firstWhere((option) => option.anchor == state.goalAnchor).label,
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium?.copyWith(color: QColors.softEmber),
                ),
              ),
              const SizedBox(height: QSpace.md),
              Reveal(
                delay: QMotion.reveal150,
                child: Text(
                  state.bridge!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge?.copyWith(color: QColors.softEmber.withValues(alpha: 0.75)),
                ),
              ),
              const Spacer(),
              Reveal(
                delay: QMotion.reveal300,
                child: QButton(
                  key: const ValueKey('onboarding-continue'),
                  label: context.l10n.commonContinue,
                  tone: QButtonTone.gold,
                  onDark: true,
                  onPressed: _next,
                ),
              ),
              const SizedBox(height: QSpace.lg),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: QSpace.md),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(copy.question, style: context.text.headlineMedium?.copyWith(color: QColors.softEmber)),
                  const SizedBox(height: QSpace.lg),
                  for (final option in copy.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: QSpace.sm),
                      child: _NightOption(
                        title: option.label,
                        selected: state.goalAnchor == option.anchor,
                        onTap: () => bloc.add(CuriosityPicked(option.anchor)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          QButton(
            key: const ValueKey('onboarding-continue'),
            label: context.l10n.commonContinue,
            tone: QButtonTone.gold,
            onDark: true,
            onPressed: state.goalAnchor != null ? _next : null,
          ),
          TextButton(
            onPressed: () => bloc.add(const CuriositySkipped()),
            child: Text(context.l10n.onboardingSkipCuriosity, style: context.text.labelLarge?.copyWith(color: QColors.softEmber)),
          ),
          const SizedBox(height: QSpace.lg),
        ],
      ),
    );
  }
}

/// Keep the authored Spacer layout when it fits; scroll larger text and short
/// windows without squeezing the two welcome actions.
class _ExpandablePage extends StatelessWidget {
  const _ExpandablePage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}
