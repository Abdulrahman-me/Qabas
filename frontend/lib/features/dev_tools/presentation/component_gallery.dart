import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/router/transitions.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/characters/character_scope.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/shared/presentation/brand/achievement_badge.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';
import 'package:qabas/shared/presentation/visuals/builtin/scenes.dart';

/// Gallery-only settings stub. Persistent app preferences belong to Phase 2.
class GallerySettings extends ChangeNotifier {
  GallerySettings({this.locale = 'en', this.reduceMotion = false});
  String locale;
  bool reduceMotion;
  bool sound = true;
  bool haptics = true;
  void languageChanged(String value) {
    locale = value;
    notifyListeners();
  }

  void motionChanged(bool value) {
    reduceMotion = value;
    notifyListeners();
  }

  void soundChanged(bool value) {
    sound = value;
    notifyListeners();
  }

  void hapticsChanged(bool value) {
    haptics = value;
    notifyListeners();
  }
}

class FoundationApp extends StatefulWidget {
  const FoundationApp({super.key, this.settings});
  final GallerySettings? settings;
  @override
  State<FoundationApp> createState() => _FoundationAppState();
}

class _FoundationAppState extends State<FoundationApp> {
  late final GallerySettings _settings = widget.settings ?? GallerySettings();
  late final SensoryService _sensory = SensoryService(
    settings: () => SensorySettings(sound: _settings.sound, haptics: _settings.haptics),
  );
  late final GoRouter _router = GoRouter(
    initialLocation: kDebugMode ? '/gallery' : '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      if (kDebugMode)
        GoRoute(
          path: '/gallery',
          pageBuilder: (_, state) => fadeThrough(state, ComponentGallery(settings: _settings)),
        ),
    ],
  );
  @override
  void initState() {
    super.initState();
    unawaited(_sensory.warmUp());
  }

  @override
  void dispose() {
    _router.dispose();
    unawaited(_sensory.dispose());
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _settings,
    builder: (_, _) => SensoryScope(
      service: _sensory,
      child: QMotionScope(
        reduceMotion: _settings.reduceMotion,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => context.l10n.commonAppName,
          theme: QTheme.light(arabic: _settings.locale == 'ar'),
          locale: Locale(_settings.locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35)),
              child: child!,
            );
          },
        ),
      ),
    ),
  );
}

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key, required this.settings, this.onBack});
  final VoidCallback? onBack;
  final GallerySettings settings;
  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  int _section = 0;
  int _nudge = 0;
  int _celebration = 0;
  double _progress = 0.45;
  final _name = TextEditingController();
  final _message = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  void _notice() => showQSnack(context, context.l10n.commonGotIt);
  void _sheet({bool confirm = false, bool session = false}) {
    unawaited(
      showQSheet<void>(
        context,
        builder: (context) => session
            ? SessionEndedSheet(onContinue: () => Navigator.pop(context))
            : QConfirmSheet(
                title: confirm ? context.l10n.sessionQuitTitle : context.l10n.galleryOpenSheet,
                body: confirm ? context.l10n.sessionQuitBody : context.l10n.galleryCardBody,
                primaryLabel: confirm ? context.l10n.sessionKeepLearning : context.l10n.commonGotIt,
                onPrimary: () => Navigator.pop(context),
                secondaryLabel: context.l10n.commonCancel,
                onSecondary: () => Navigator.pop(context),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      final l = context.l10n;
      final sections = [
        l.galleryButtons,
        l.gallerySurfaces,
        l.galleryInputs,
        l.galleryBrand,
        l.galleryMotion,
        l.galleryStates,
        l.gallerySheets,
      ];
      return Scaffold(
        appBar: AppBar(
          title: Text(l.galleryTitle),
          leading: widget.onBack == null ? null : BackButton(key: const ValueKey('gallery-back'), onPressed: widget.onBack),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: QSpace.page),
              child: Row(
                children: [
                  Expanded(
                    child: QSegmentedChips<String>(
                      options: {'en': l.commonEnglish, 'ar': l.commonArabic},
                      selected: widget.settings.locale,
                      onSelected: widget.settings.languageChanged,
                    ),
                  ),
                  Tooltip(
                    message: l.settingsReduceMotion,
                    child: Switch(value: widget.settings.reduceMotion, onChanged: widget.settings.motionChanged),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(QSpace.sm),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: QSpace.xxs,
                  children: [
                    for (var i = 0; i < sections.length; i++)
                      TextButton(
                        key: ValueKey('gallery-section-$i'),
                        onPressed: () => setState(() => _section = i),
                        child: Text(
                          sections[i],
                          style: _section == i ? context.text.labelMedium?.copyWith(color: QColors.emerald500) : context.text.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey('gallery-content-$_section'),
                padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.sm, QSpace.page, QSpace.xxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _components(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  List<Widget> _components(BuildContext context) {
    final l = context.l10n;
    String number(num value) => QNumbers.format(value, widget.settings.locale);
    switch (_section) {
      case 0:
        return [
          for (final tone in QButtonTone.values)
            Padding(
              padding: const EdgeInsets.only(bottom: QSpace.sm),
              child: QButton(
                key: ValueKey('button-${tone.name}'),
                label: l.commonContinue,
                tone: tone,
                onPressed: _notice,
                icon: Icons.local_fire_department_rounded,
                trailingIcon: Icons.arrow_forward_rounded,
              ),
            ),
          QButton(label: l.galleryDisabled),
          const SizedBox(height: QSpace.sm),
          QButton(label: l.galleryDisabled, onDark: true),
          Row(
            children: [
              QIconButton(icon: Icons.close_rounded, tooltip: l.commonClose, onTap: _notice),
              Expanded(
                child: Pressable(
                  onTap: _notice,
                  semanticLabel: l.commonStart,
                  child: Padding(
                    padding: const EdgeInsets.all(QSpace.md),
                    child: Text(l.commonStart, style: context.text.titleMedium),
                  ),
                ),
              ),
            ],
          ),
        ];
      case 1:
        return [
          SectionHeader(l.gallerySurfaces, action: l.commonSeeAll, onAction: _notice),
          QCard(
            onTap: _notice,
            child: Text(l.galleryCardBody, style: context.text.bodyLarge),
          ),
          const SizedBox(height: QSpace.lg),
          Wrap(
            spacing: QSpace.xs,
            runSpacing: QSpace.xs,
            children: [
              Tag(l.commonPathExplorer, icon: Icons.explore_rounded),
              Tag(l.commonNew, color: QColors.gold800),
              StatChip(
                leading: const StreakFlame(),
                value: number(3),
                onDark: false,
                semantic: l.commonDayStreak(3, number(3)),
                onTap: _notice,
              ),
              StatChip(leading: const EmberIcon(), value: number(245), onDark: false, semantic: l.commonEmbers(number(245))),
            ],
          ),
          const SizedBox(height: QSpace.lg),
          ProgressTrack(value: _progress, streakGlow: true),
          Slider(value: _progress, onChanged: (value) => setState(() => _progress = value)),
          Center(
            child: RingProgress(
              value: _progress,
              child: Text(l.commonPercent(number((_progress * 100).round())), style: context.text.labelSmall),
            ),
          ),
          const SizedBox(height: QSpace.lg),
          const DottedLine(),
          const SizedBox(height: QSpace.lg),
          SpeechBubble(child: Text(l.onboardingCompanionHello, style: context.text.bodyLarge)),
          const SizedBox(height: QSpace.lg),
          SizedBox(
            height: 100,
            child: NightSky(
              child: Center(
                child: StatChip(leading: const StreakFlame(), value: number(3), onTap: _notice),
              ),
            ),
          ),
        ];
      case 2:
        return [
          QTextField(controller: _name, hint: l.profileEditName, maxLines: 1),
          const SizedBox(height: QSpace.md),
          QSegmentedChips<int>(
            options: {0: l.commonPathExplorer, 1: l.commonPathNewMuslim},
            selected: _nudge % 2,
            onSelected: (value) => setState(() => _nudge = value),
          ),
          QSettingsSection(l.settingsSectionExperience, [
            QSettingsRow(
              icon: Icons.translate_rounded,
              title: l.settingsLanguage,
              value: widget.settings.locale == 'ar' ? l.commonArabic : l.commonEnglish,
              onTap: () => widget.settings.languageChanged(widget.settings.locale == 'ar' ? 'en' : 'ar'),
            ),
            QSettingsToggle(
              icon: Icons.music_note_rounded,
              title: l.settingsSoundEffects,
              value: widget.settings.sound,
              onChanged: widget.settings.soundChanged,
            ),
            QSettingsToggle(
              icon: Icons.vibration_rounded,
              title: l.settingsHapticsLabel,
              value: widget.settings.haptics,
              onChanged: widget.settings.hapticsChanged,
            ),
            QSettingsToggle(
              icon: Icons.motion_photos_off_rounded,
              title: l.settingsReduceMotion,
              subtitle: l.settingsReduceMotionBody,
              value: widget.settings.reduceMotion,
              onChanged: widget.settings.motionChanged,
            ),
          ]),
          const SizedBox(height: QSpace.lg),
          QComposerBar(
            controller: _message,
            hint: l.raqeebAskAnything,
            onSend: (_) => _notice(),
            onAttach: _notice,
            onRecord: _notice,
            attachments: [Tag(l.raqeebAttachPhoto, icon: Icons.image_rounded)],
          ),
        ];
      case 3:
        return [
          if (CharacterScope.maybeOf(context) != null) const Center(child: CharacterView()),
          SizedBox(
            height: 230,
            child: NightSky(
              child: Stack(
                children: [
                  const Positioned.fill(child: Center(child: QabasLogo(size: 0.8))),
                  Positioned(left: 0, right: 0, bottom: 0, height: 65, child: CustomPaint(painter: HillsPainter())),
                ],
              ),
            ),
          ),
          const SizedBox(height: QSpace.lg),
          const Center(child: QabasLogo(onDark: false, stacked: false)),
          const SizedBox(height: QSpace.lg),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FlameMark(size: 48, glow: 0.5),
              EmberIcon(size: 30),
              StreakFlame(size: 30),
              LanternGlyph(color: QColors.emerald500, size: 44, lit: true),
              TravelerAvatar(hue: 0.43),
              TravelerAvatar(hue: 0.12),
            ],
          ),
          const SizedBox(height: QSpace.lg),
          Wrap(
            spacing: QSpace.sm,
            runSpacing: QSpace.sm,
            children: [
              for (final art in UnitArt.values) UnitArtIcon(art: art),
              const UnitArtIcon(art: UnitArt.prayerRug, dim: true),
            ],
          ),
          const SizedBox(height: QSpace.lg),
          Wrap(
            spacing: QSpace.sm,
            runSpacing: QSpace.sm,
            children: [
              for (final key in [
                'first_step',
                'kindled',
                'steady_flame',
                'word_keeper',
                'clear_sight',
                'unit_complete',
                'seeker',
                'quick_light',
                'unknown',
              ])
                AchievementBadge(achievementKey: key, unlocked: true),
              const AchievementBadge(unlocked: false),
            ],
          ),
          const SizedBox(height: QSpace.lg),
          Wrap(
            spacing: QSpace.sm,
            children: [
              for (final phase in [0, 1, 2, 3, 4]) PhaseIcon(phase: phase),
            ],
          ),
          const SizedBox(height: QSpace.md),
          const AspectRatio(aspectRatio: 1.62, child: RiverHouseScene()),
          const SizedBox(height: QSpace.md),
          const AspectRatio(aspectRatio: 1.52, child: WorkplaceScene()),
          const SizedBox(height: QSpace.md),
          const AspectRatio(aspectRatio: 2.2, child: DayArcScene()),
          const SizedBox(height: QSpace.md),
          const AspectRatio(aspectRatio: 1.6, child: PillarsScene()),
        ];
      case 4:
        return [
          Reveal(child: QCard(child: Text(l.galleryCardBody))),
          const SizedBox(height: QSpace.lg),
          Breathe(
            child: QButton(label: l.commonStart, onPressed: _notice),
          ),
          const SizedBox(height: QSpace.lg),
          Nudge(
            trigger: _nudge,
            child: QButton(label: l.galleryNudge, onPressed: () => setState(() => _nudge++)),
          ),
          const SizedBox(height: QSpace.lg),
          SizedBox(
            height: 180,
            child: NightSky(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Glow(size: 160),
                  RollingNumber(key: ValueKey(_celebration), from: 3, to: 4),
                  Positioned.fill(child: EmberBurst(key: ValueKey(_celebration), count: 40)),
                ],
              ),
            ),
          ),
          const SizedBox(height: QSpace.md),
          Center(
            child: CountUp(key: ValueKey(_celebration), value: 245, format: number),
          ),
          QButton(
            label: l.galleryCelebrate,
            onPressed: () {
              SensoryScope.of(context).complete();
              setState(() => _celebration++);
            },
            silent: true,
          ),
        ];
      case 5:
        return [
          const SizedBox(height: 230, child: QLoadingView()),
          SizedBox(
            height: 230,
            child: QLoadingView(tone: QTone.night, label: l.commonLoading),
          ),
          QInlineLoading(label: l.commonLoading),
          const SizedBox(height: QSpace.md),
          QEmptyView(title: l.galleryEmptyTitle, body: l.galleryEmptyBody, action: (l.commonContinue, _notice)),
          QEmptyView(title: l.galleryEmptyTitle, body: l.galleryEmptyBody, art: QEmptyArt.lantern),
          QEmptyView(title: l.galleryEmptyTitle, body: l.galleryEmptyBody, art: QEmptyArt.unitArt),
          for (final kind in QErrorKind.values) QErrorView(kind: kind, onRetry: _notice, retryTime: number(30)),
          SizedBox(
            height: 350,
            child: QErrorView(onRetry: _notice, tone: QTone.night),
          ),
          QInlineError(message: l.errorNetworkBody, onRetry: _notice),
          const QOfflineBanner(),
          SizedBox(height: 460, child: QBlockingScreen(onUpdate: _notice)),
          StatusSwitcher(
            status: LoadStatus.loading,
            hasData: true,
            loading: () => const QInlineLoading(),
            empty: () => const SizedBox.shrink(),
            failure: () => const SizedBox.shrink(),
            builder: () => QCard(child: Text(l.galleryCardBody)),
          ),
        ];
      default:
        return [
          QButton(label: l.galleryOpenSheet, onPressed: _sheet),
          const SizedBox(height: QSpace.md),
          QButton(label: l.galleryConfirm, onPressed: () => _sheet(confirm: true)),
          const SizedBox(height: QSpace.md),
          QButton(label: l.commonSessionEndedTitle, onPressed: () => _sheet(session: true)),
          const SizedBox(height: QSpace.md),
          QButton(label: l.commonGotIt, onPressed: _notice, tone: QButtonTone.light),
        ];
    }
  }
}
