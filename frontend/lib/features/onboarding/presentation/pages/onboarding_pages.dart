part of 'onboarding_page.dart';

class _LanguagePage extends StatelessWidget {
  const _LanguagePage({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final current = context.select((OnboardingBloc bloc) => bloc.state.language);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
      child: Column(
        children: [
          const SizedBox(height: QSpace.lg),
          const Reveal(child: QabasLogo(size: QOnboarding.logoScale, showFlame: false)),
          const Spacer(),
          Reveal(
            delay: QMotion.reveal200,
            child: Column(
              children: [
                Text(
                  context.l10n.onboardingLanguageEnglishPrompt,
                  style: QBrandText.languageTitle(context.text.titleLarge!, arabic: false).copyWith(color: QColors.softEmber),
                  textAlign: TextAlign.center,
                ),
                Text(
                  context.l10n.onboardingLanguageArabicPrompt,
                  textDirection: TextDirection.rtl,
                  style: QBrandText.languageTitle(
                    context.text.titleMedium!,
                    arabic: true,
                  ).copyWith(color: QColors.softEmber.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: QSpace.lg),
          Reveal(
            delay: QMotion.reveal320,
            child: _NightOption(
              title: context.l10n.commonEnglish,
              selected: current == 'en',
              leading: Text(context.l10n.onboardingEnglishGlyph, style: QBrandText.latinLanguageGlyph),
              onTap: () => onPick('en'),
              languageScript: false,
            ),
          ),
          const SizedBox(height: QSpace.sm),
          Reveal(
            delay: QMotion.reveal420,
            child: _NightOption(
              title: context.l10n.commonArabic,
              selected: current == 'ar',
              leading: Text(context.l10n.onboardingArabicGlyph, style: QBrandText.arabicLanguageGlyph),
              onTap: () => onPick('ar'),
              languageScript: true,
            ),
          ),
          const SizedBox(height: QSpace.xl),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
      child: Column(
        children: [
          const SizedBox(height: QSpace.lg),
          Reveal(
            child: Text(
              s.onboardingWelcomeTitle,
              textAlign: TextAlign.center,
              style: context.qText.display.copyWith(
                color: QColors.softEmber,
                fontSize: context.isRtl ? QOnboarding.welcomeArabic : QOnboarding.welcomeLatin,
              ),
            ),
          ),
          const SizedBox(height: QSpace.md),
          Reveal(
            delay: QMotion.reveal150,
            child: Text(
              s.onboardingWelcomeBody,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: QColors.softEmber.withValues(alpha: 0.75)),
            ),
          ),
          const Spacer(),
          Reveal(
            delay: QMotion.reveal300,
            child: QButton(
              key: const ValueKey('onboarding-get-started'),
              label: s.onboardingGetStarted,
              tone: QButtonTone.gold,
              onPressed: onStart,
            ),
          ),
          const SizedBox(height: QSpace.sm),
          Reveal(
            delay: QMotion.languageChoice,
            child: QButton(label: s.onboardingHaveAccount, tone: QButtonTone.night, onPressed: onStart),
          ),
          const SizedBox(height: QSpace.lg),
        ],
      ),
    );
  }
}

class _Option {
  const _Option(this.title, this.body, {this.art, this.bars, this.trailing});
  final String title;
  final String? body;
  final UnitArt? art;
  final int? bars;
  final String? trailing;
}

class _ChoicePage extends StatelessWidget {
  const _ChoicePage({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.onContinue,
    this.note,
  });
  final String title;
  final List<_Option> options;
  final int? selected;
  final ValueChanged<int> onSelect;
  final VoidCallback? onContinue;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: QSpace.md),
          Text(title, style: context.text.headlineMedium?.copyWith(color: QColors.softEmber)),
          const SizedBox(height: QSpace.lg),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: options.length + (note != null ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: QSpace.sm),
              itemBuilder: (context, i) {
                if (i == options.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: QSpace.xs),
                    child: Text(note!, style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.6))),
                  );
                }
                final o = options[i];
                return Reveal(
                  delay: QMotion.onboardingChoiceReveal * i,
                  child: _NightOption(
                    title: o.title,
                    body: o.body,
                    selected: selected == i,
                    big: o.art != null,
                    leading: o.art != null
                        ? UnitArtIcon(art: o.art!, size: QOnboarding.optionArt)
                        : o.bars != null
                        ? _Bars(level: o.bars!)
                        : null,
                    trailing: o.trailing,
                    onTap: () => onSelect(i),
                  ),
                );
              },
            ),
          ),
          QButton(
            key: const ValueKey('onboarding-continue'),
            label: s.commonContinue,
            tone: QButtonTone.gold,
            onDark: true,
            onPressed: onContinue,
          ),
          const SizedBox(height: QSpace.lg),
        ],
      ),
    );
  }
}

class _NightOption extends StatelessWidget {
  const _NightOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.body,
    this.leading,
    this.trailing,
    this.big = false,
    this.languageScript,
  });
  final String title;
  final String? body;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final String? trailing;
  final bool big;
  final bool? languageScript;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: QOnboarding.pressScale,
        child: AnimatedContainer(
          duration: context.reduceMotion ? Duration.zero : QMotion.normal,
          curve: QMotion.emphasized,
          padding: EdgeInsets.all(big ? QSpace.md : QOnboarding.optionPadding),
          decoration: BoxDecoration(
            color: selected ? QColors.flameGold.withValues(alpha: 0.12) : QColors.night800.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(QRadius.lg),
            border: Border.all(
              color: selected ? QColors.flameGold : QColors.nightLine,
              width: selected ? QOnboarding.selectedBorder : QOnboarding.border,
            ),
            boxShadow: selected ? QShadows.glow(QColors.flameGold, strength: 0.35) : null,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: QSpace.md)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          (languageScript == null
                                  ? context.text.titleMedium!
                                  : QBrandText.languageTitle(context.text.titleMedium!, arabic: languageScript!))
                              .copyWith(color: QColors.softEmber, fontSize: big ? QOnboarding.bigTitle : QOnboarding.optionTitle),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: QOnboarding.bodyGap),
                      Text(body!, style: context.text.bodyMedium?.copyWith(color: QColors.softEmber.withValues(alpha: 0.68))),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        (math.min(MediaQuery.sizeOf(context).width, QBreakpoints.readingWidth) -
                            QSpace.page * 2 -
                            QSpace.md * 2 -
                            QOnboarding.selectedBorder * 2) /
                        2,
                  ),
                  child: Text(trailing!, style: context.text.labelMedium?.copyWith(color: QColors.softEmber.withValues(alpha: 0.7))),
                ),
              const SizedBox(width: QSpace.xs),
              AnimatedSwitcher(
                duration: context.reduceMotion ? Duration.zero : QMotion.normal,
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: selected
                    ? const Icon(Icons.check_circle_rounded, key: ValueKey(1), color: QColors.flameGold, size: QOnboarding.optionCheck)
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey(0),
                        color: QColors.softEmber.withValues(alpha: 0.25),
                        size: QOnboarding.optionCheck,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: QOnboarding.barsWidth,
      height: QOnboarding.barsHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 1; i <= 3; i++)
            Container(
              width: QOnboarding.barWidth,
              height: QOnboarding.barUnit * i,
              decoration: BoxDecoration(
                color: i <= level ? QColors.flameGold : QColors.softEmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(QOnboarding.barRadius),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final state = context.watch<OnboardingBloc>().state;
    final bloc = context.read<OnboardingBloc>();
    const hours = [8, 13, 19, 21];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: QSpace.md),
          Text(s.onboardingPrivacyBody, style: context.text.bodyLarge?.copyWith(color: QColors.softEmber.withValues(alpha: 0.85))),
          const SizedBox(height: QSpace.lg),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NightToggle(
                  icon: Icons.notifications_paused_rounded,
                  title: s.onboardingDiscreetTitle,
                  body: s.onboardingDiscreetBody,
                  value: state.discreetReminders,
                  onChanged: (value) => bloc.add(RemindersToggled(value)),
                ),
                const SizedBox(height: QSpace.sm),
                _NightToggle(
                  icon: Icons.lock_rounded,
                  title: s.onboardingPrivateTitle,
                  body: s.onboardingPrivateBody,
                  value: state.privateProfile,
                  onChanged: (value) => bloc.add(PrivacyToggled(value)),
                ),
                const SizedBox(height: QSpace.lg),
                Text(s.onboardingReminderTitle, style: context.text.titleSmall?.copyWith(color: QColors.softEmber)),
                const SizedBox(height: QSpace.sm),
                Wrap(
                  spacing: QSpace.xs,
                  runSpacing: QSpace.xs,
                  children: [
                    for (final h in hours)
                      Semantics(
                        selected: state.reminderHour == h,
                        button: true,
                        label: s.onboardingReminderTime(QNumbers.format(h, context.l10n.localeName)),
                        child: Pressable(
                          onTap: () => bloc.add(ReminderTimePicked(h)),
                          child: AnimatedContainer(
                            duration: context.reduceMotion ? Duration.zero : QMotion.normal,
                            padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QOnboarding.progressHeight),
                            decoration: BoxDecoration(
                              color: state.reminderHour == h ? QColors.flameGold : QColors.night800,
                              borderRadius: QRadius.chip,
                              border: Border.all(
                                color: state.reminderHour == h ? QColors.flameGold : QColors.nightLine,
                                width: QOnboarding.border,
                              ),
                            ),
                            child: Text(
                              QNumbers.localizeDigits(
                                MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: h, minute: 0)),
                                s.localeName,
                              ),
                              style: context.text.labelLarge?.copyWith(
                                color: state.reminderHour == h ? QColors.deepInk : QColors.softEmber,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          QButton(
            key: const ValueKey('onboarding-continue'),
            label: s.commonContinue,
            tone: QButtonTone.gold,
            onDark: true,
            onPressed: onContinue,
          ),
          const SizedBox(height: QSpace.lg),
        ],
      ),
    );
  }
}

class _NightToggle extends StatelessWidget {
  const _NightToggle({required this.icon, required this.title, required this.body, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(QSpace.md),
      decoration: BoxDecoration(
        color: QColors.night800.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(QRadius.lg),
        border: Border.all(color: QColors.nightLine, width: QOnboarding.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: QColors.flameGold),
          const SizedBox(width: QSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall?.copyWith(color: QColors.softEmber)),
                Text(body, style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.65))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              SensoryScope.of(context).select();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage({required this.state, required this.onStart});
  final OnboardingState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final units = state.preview;
    return Stack(
      children: [
        const Positioned.fill(child: EmberBurst(count: QOnboarding.readyEmbers)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                child: Text(
                  s.onboardingReadyTitle,
                  textAlign: TextAlign.center,
                  style: context.qText.display.copyWith(color: QColors.softEmber, fontSize: QOnboarding.readyTitle),
                ),
              ),
              const SizedBox(height: QSpace.xs),
              Reveal(
                delay: QMotion.reveal120,
                child: Text(
                  state.track != TrackChoice.newMuslim ? s.onboardingReadyExplorer : s.onboardingReadyNewMuslim,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: QColors.softEmber.withValues(alpha: 0.72)),
                ),
              ),
              const SizedBox(height: QSpace.lg),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < units.length; i++)
                      Reveal(
                        delay: QMotion.onboardingReadyReveal + QMotion.onboardingReadyStagger * i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: QSpace.sm),
                          child: Row(
                            children: [
                              UnitArtIcon.fromKey(artKey: units[i].artKey, size: QOnboarding.previewArt, dim: i > 0),
                              const SizedBox(width: QSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.journeyUnitN(QNumbers.format(units[i].number, context.l10n.localeName)).toUpperCase(),
                                      style: context.qText.eyebrow.copyWith(
                                        color: i == 0 ? QColors.flameGold : QColors.softEmber.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    Text(
                                      units[i].title,
                                      style: context.text.titleMedium?.copyWith(
                                        color: QColors.softEmber.withValues(alpha: i == 0 ? 1 : 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.failure != null) ...[
                QCard(
                  child: QInlineError(message: failureBody(state.failure!, context.l10n), onRetry: onStart),
                ),
                const SizedBox(height: QSpace.sm),
              ],
              if (state.status == OnboardingStatus.submitting) const Center(child: QInlineLoading()),
              QButton(
                key: const ValueKey('onboarding-submit'),
                label: s.onboardingStartMyJourney,
                tone: QButtonTone.gold,
                icon: Icons.local_fire_department_rounded,
                onPressed: state.status == OnboardingStatus.submitting ? null : onStart,
              ),
              const SizedBox(height: QSpace.lg),
            ],
          ),
        ),
      ],
    );
  }
}
