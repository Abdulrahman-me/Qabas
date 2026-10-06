import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/config/download_links.dart';
import 'package:qabas/app/router/routes.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/components/download_banner.dart';
import 'package:qabas/core/design_system/components/journey_banner.dart';
import 'package:qabas/core/design_system/components/journey_header.dart';
import 'package:qabas/core/design_system/components/journey_horizon.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/design_system/components/journey_path_painter.dart';
import 'package:qabas/core/design_system/components/journey_scenery.dart';
import 'package:qabas/core/design_system/components/journey_today.dart';
import 'package:qabas/core/design_system/components/review_deck.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';
import 'package:qabas/shared/presentation/learning_path/soft_lock_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key});
  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  final _scroll = ScrollController(), _currentKey = GlobalKey(), _selectedKey = GlobalKey(), _companion = CharacterController();
  String? _centredOn;
  Size? _viewport;
  void _revealCurrent({required bool animate}) {
    final target = _currentKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: QJourney.currentAlignment,
        duration: animate && !context.reduceMotion ? QMotion.page : Duration.zero,
        curve: QMotion.emphasized,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _companion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<JourneyBloc, JourneyState>(
    listener: (context, state) {
      if (state.journey?.current.lessonId != null && _centredOn != state.journey?.current.lessonId) _companion.cue(CharacterCue.greet);
      if (state.softLock case final SoftLock lock) {
        final bloc = context.read<JourneyBloc>();
        showSoftLockSheet(context, lock, onOpen: (id) => bloc.add(LessonOpened(id))).whenComplete(() {
          if (!bloc.isClosed) bloc.add(const SoftLockDismissed());
        });
      }
      if (state.lessonToOpen case final String id) {
        final lesson = state.journey!.lesson(id)!, unit = state.journey!.unitFor(id)!;
        context.push(
          Routes.lessonIntro(id),
          extra: LessonRef(lessonId: id, unitId: unit.unitId, title: lesson.title),
        );
      }
      if (state.pretestUnitToOpen case final String id) context.push(Routes.unitPretest(id), extra: state.nextStep?.title);
      if (state.unitToOpen case final String id) context.push(Routes.unitTest(id));
      if (state.openReview) context.push(Routes.review);
      if (state.openAndroidDownload) _downloadAndroid();
    },
    listenWhen: (a, b) => a.actionSerial != b.actionSerial || a.journey?.current.lessonId != b.journey?.current.lessonId,
    builder: (context, state) {
      final bloc = context.read<JourneyBloc>(), l = context.l10n, locale = context.isArabic ? 'ar' : 'en';
      final journey = state.journey;
      if (journey == null) {
        return Scaffold(
          backgroundColor: QColors.night950,
          body: state.status == JourneyStatus.failure
              ? NightSky(
                  child: QErrorView(
                    tone: QTone.night,
                    kind: failureKind(state.failure!),
                    body: failureBody(state.failure!, l),
                    onRetry: () => bloc.add(const JourneyRefreshed()),
                  ),
                )
              : DelayedLoading(
                  child: QLoadingView(tone: QTone.night, label: l.journeyLoading),
                ),
        );
      }
      if (journey.units.isEmpty) {
        return Scaffold(
          backgroundColor: QColors.night950,
          body: NightSky(
            child: QEmptyView(
              tone: QTone.night,
              title: l.journeyEmptyTitle,
              body: l.journeyEmptyBody,
              illustration: const CharacterView(size: QJourney.companion, appearCue: CharacterCue.encourage),
              action: (l.commonRetry, () => bloc.add(const JourneyRefreshed())),
            ),
          ),
        );
      }
      final current = journey.current.lessonId;
      if (current != _centredOn) {
        final first = _centredOn == null;
        _centredOn = current;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _revealCurrent(animate: !first);
          }
        });
      }
      final total = journey.units.expand((u) => u.lessons).length;
      final completed = journey.units.expand((u) => u.lessons).where((l) => l.state == LessonState.completed).length;
      final stats = state.stats;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: QColors.night950,
          body: QDownloadBannerFrame(
            visible: kIsWeb && !state.downloadBannerDismissed,
            eyebrow: l.journeyDownloadEyebrow,
            title: l.journeyDownloadTitle,
            body: l.journeyDownloadBody,
            action: l.journeyDownloadAction,
            dismissLabel: l.journeyDownloadDismiss,
            onDownload: () => bloc.add(const AndroidDownloadOpened()),
            onDismiss: () => bloc.add(const DownloadBannerDismissed()),
            child: LayoutBuilder(
              builder: (context, box) {
                final size = box.biggest;
                if (_viewport != size && (state.selectedLessonId != null || state.selectedUnitId != null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final target = (state.selectedLessonId == journey.current.lessonId ? _currentKey : _selectedKey).currentContext;
                    if (target != null) Scrollable.ensureVisible(target, alignment: QJourney.currentAlignment, duration: Duration.zero);
                    // Scrolling settles the anchor transform on the next layout frame.
                    setState(() {});
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() {});
                    });
                  });
                }
                _viewport = size;
                final pathWidth = math.min(box.maxWidth, QJourney.pathWidth);
                Widget reading(Widget child) => Center(
                  child: SizedBox(width: pathWidth, child: child),
                );
                final greeting = switch (bloc.greeting) {
                  JourneyGreeting.morning => l.journeyGreetingMorning,
                  JourneyGreeting.afternoon => l.journeyGreetingAfternoon,
                  JourneyGreeting.evening => l.journeyGreetingEvening,
                };
                return Stack(
                  children: [
                    Positioned.fill(
                      child: NightSky(density: QJourney.waveScale, gradient: QJourney.sky(total == 0 ? 0 : completed / total)),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => bloc.add(const PopoverDismissed()),
                      child: RefreshIndicator(
                        onRefresh: () async {
                          bloc.add(const JourneyRefreshed());
                          await bloc.stream.firstWhere((s) => !s.refreshing, orElse: () => bloc.state);
                        },
                        child: CustomScrollView(
                          key: const PageStorageKey('journey-scroll'),
                          controller: _scroll,
                          scrollCacheExtent: const ScrollCacheExtent.pixels(QJourney.cacheExtent),
                          slivers: [
                            QJourneyHeader(
                              pathLabel: journey.track == UserTrack.newMuslim ? l.commonPathNewMuslim : l.commonPathExplorer,
                              pathSemantics: journey.track == UserTrack.newMuslim ? l.commonPathNewMuslimLong : l.commonPathExplorerLong,
                              art: journey.track == UserTrack.newMuslim ? UnitArt.footprints : UnitArt.starrySky,
                              streak: QNumbers.format(stats?.streak.current ?? 0, locale),
                              embers: QNumbers.format(stats?.xpTotal ?? 0, locale),
                              streakSemantics: l.commonDayStreak(
                                QNumbers.prototypePluralCount(stats?.streak.current ?? 0),
                                QNumbers.format(stats?.streak.current ?? 0, locale),
                              ),
                              embersSemantics: l.commonEmbers(QNumbers.format(stats?.xpTotal ?? 0, locale)),
                              learnedToday: stats?.streak.todayCompleted ?? false,
                              onPath: () => _switchPath(context, journey.track),
                              onStreak: () => context.push(Routes.streak),
                              onEmbers: () => context.go(Routes.community),
                            ),
                            if (state.refreshing)
                              SliverToBoxAdapter(
                                child: reading(const Padding(padding: EdgeInsets.all(QSpace.xs), child: QInlineLoading())),
                              ),
                            if (state.failure != null)
                              SliverToBoxAdapter(
                                child: reading(
                                  Padding(
                                    padding: const EdgeInsets.all(QSpace.md),
                                    child: QCard(
                                      color: QColors.night800,
                                      child: QInlineError(
                                        message: failureBody(state.failure!, l),
                                        onRetry: () => bloc.add(const JourneyRefreshed()),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: reading(
                                QJourneyToday(
                                  greeting: greeting,
                                  minutes: stats?.dailyGoal.minutesToday ?? 0,
                                  goal: stats?.dailyGoal.minutes ?? 10,
                                  learnedToday: stats?.streak.todayCompleted ?? false,
                                  nextTitle: [NextStepType.journeyComplete, NextStepType.unknown].contains(state.nextStep?.type)
                                      ? null
                                      : state.nextStep?.title ??
                                            (state.nextStep?.type == NextStepType.review ? l.journeyStartReview : null),
                                  onContinue: () => bloc.add(const NextStepOpened()),
                                ),
                              ),
                            ),
                            if ((state.nextStep?.dueReviewsCount ?? 0) > 0)
                              SliverToBoxAdapter(
                                child: reading(
                                  Padding(
                                    padding: const EdgeInsets.all(QSpace.md),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        QReviewDeckCard(
                                          key: const ValueKey('journey-review'),
                                          count: QNumbers.format(state.nextStep!.dueReviewsCount, locale),
                                          onReview: () => bloc.add(const ReviewOpened()),
                                        ),
                                        TextButton(
                                          key: const ValueKey('journey-quick-review'),
                                          onPressed: () => context.push('${Routes.review}?mode=quick'),
                                          child: Text(context.l10n.sessionQuickReview),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            for (final indexed in journey.units.asMap().entries) ...[
                              SliverToBoxAdapter(
                                child: reading(
                                  QUnitBanner(
                                    key: ValueKey('unit-${indexed.value.unitId}'),
                                    unit: QUnitBannerData(
                                      title: indexed.value.title,
                                      subtitle: indexed.value.subtitle,
                                      number: indexed.value.index,
                                      artKey: indexed.value.artKey,
                                      progress: _progress(indexed.value),
                                    ),
                                    status: _unitStatus(indexed.value, journey.current.unitId),
                                    onGuide: indexed.value.hasGuide
                                        ? () => context.push(Routes.unitGuide(indexed.value.unitId), extra: indexed.value.title)
                                        : null,
                                  ),
                                ),
                              ),
                              if (indexed.value.lessons.isNotEmpty ||
                                  indexed.value.unitTest.canSkip ||
                                  indexed.value.unitTest.state == UnitTestState.passed)
                                SliverToBoxAdapter(
                                  child: reading(
                                    _UnitPath(
                                      unit: indexed.value,
                                      unitIndex: indexed.key,
                                      state: state,
                                      currentKey: _currentKey,
                                      selectedKey: _selectedKey,
                                      companion: _companion,
                                    ),
                                  ),
                                ),
                            ],
                            const SliverToBoxAdapter(child: QJourneyHorizon()),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
  Future<void> _downloadAndroid() async {
    bool opened;
    try {
      opened = await launchUrl(DownloadLinks.android, webOnlyWindowName: '_self');
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.journeyDownloadFailed)));
    }
  }

  double _progress(JourneyUnit unit) => [UnitState.completed, UnitState.skipped].contains(unit.state)
      ? 1
      : unit.lessons.isEmpty
      ? 0
      : unit.lessons.where((l) => l.state == LessonState.completed).length / unit.lessons.length;
  QUnitStatus _unitStatus(JourneyUnit unit, String? current) => switch (unit.state) {
    UnitState.completed || UnitState.skipped => QUnitStatus.done,
    UnitState.locked || UnitState.unknown => QUnitStatus.locked,
    _ => unit.unitId == current ? QUnitStatus.current : QUnitStatus.available,
  };
  Future<void> _switchPath(BuildContext context, UserTrack track) async {
    final bloc = context.read<JourneyBloc>();
    await showQSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.l10n.journeyYourPath, style: ctx.text.headlineSmall),
          const SizedBox(height: QSpace.xs),
          for (final choice in [UserTrack.explorer, UserTrack.newMuslim])
            ListTile(
              key: ValueKey('track-${choice.name}'),
              contentPadding: const EdgeInsets.symmetric(vertical: QSpace.xs),
              leading: UnitArtIcon(art: choice == UserTrack.explorer ? UnitArt.starrySky : UnitArt.footprints, size: QSizes.tapTarget),
              title: Text(
                choice == UserTrack.explorer ? ctx.l10n.commonPathExplorerLong : ctx.l10n.commonPathNewMuslimLong,
                style: ctx.text.titleMedium,
              ),
              subtitle: Text(
                choice == UserTrack.explorer ? ctx.l10n.journeyExplorerPathHint : ctx.l10n.journeyNewMuslimPathHint,
                style: ctx.text.bodySmall,
              ),
              trailing: choice == track ? const Icon(Icons.check_circle_rounded, color: QColors.emerald500) : null,
              onTap: () {
                SensoryScope.of(ctx).select();
                Navigator.pop(ctx);
                bloc.add(TrackPicked(choice));
              },
            ),
        ],
      ),
    );
  }
}

class _UnitPath extends StatelessWidget {
  const _UnitPath({
    required this.unit,
    required this.unitIndex,
    required this.state,
    required this.currentKey,
    required this.selectedKey,
    required this.companion,
  });
  final JourneyUnit unit;
  final int unitIndex;
  final JourneyState state;
  final GlobalKey currentKey, selectedKey;
  final CharacterController companion;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth,
          half = (width - QJourney.horizontalClearance) / 2,
          dir = context.isRtl ? -1.0 : 1.0,
          shift = unitIndex.isOdd ? QJourney.oddUnitShift : 0;
      final checkpoint = unit.unitTest.canSkip || unit.unitTest.state == UnitTestState.passed;
      final count = unit.lessons.length + (checkpoint ? 1 : 0);
      final centers = [
        for (var i = 0; i < count; i++)
          Offset(
            width / 2 + dir * QJourney.wave[(i + shift) % QJourney.wave.length] * half * QJourney.waveScale,
            QJourney.top + i * QJourney.spacing,
          ),
      ];
      QNodeStatus status(LessonEntry lesson) => switch (lesson.state) {
        LessonState.completed => QNodeStatus.done,
        LessonState.locked || LessonState.unknown => QNodeStatus.locked,
        _ => lesson.lessonId == state.journey?.current.lessonId ? QNodeStatus.current : QNodeStatus.available,
      };
      final statuses = [
            ...unit.lessons.map(status),
            if (checkpoint)
              unit.unitTest.state == UnitTestState.passed
                  ? QNodeStatus.done
                  : state.nextStep?.type == NextStepType.unitTest && state.nextStep?.unitId == unit.unitId
                  ? QNodeStatus.current
                  : QNodeStatus.available,
          ],
          current = statuses.indexOf(QNodeStatus.current);
      final height = QJourney.top + (count - 1) * QJourney.spacing + QJourney.bottom;
      final bloc = context.read<JourneyBloc>();
      return SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: JourneyPathPainter(centers: centers, statuses: statuses),
              ),
            ),
            for (var i = 0; i < unit.lessons.length; i += QJourney.sceneryInterval)
              Positioned(
                left: centers[i].dx > width / 2 ? QJourney.sceneryNear : width - QJourney.sceneryFar,
                top: centers[i].dy + QJourney.sceneryTop,
                child: Opacity(
                  opacity: QJourney.sceneryOpacity,
                  child: SideDecoration(seed: unitIndex * QJourney.unitSeedRange + i),
                ),
              ),
            if (current >= 0)
              Positioned(
                left:
                    (centers[current].dx > width / 2
                            ? centers[current].dx - QJourney.companionOpposite
                            : centers[current].dx + QJourney.companionSide)
                        .clamp(QSpace.md, width - QJourney.companion - QSpace.md),
                top: centers[current].dy - QJourney.companionTop,
                child: IgnorePointer(
                  child: CharacterView(controller: companion, size: QJourney.companion, appearCue: CharacterCue.greet),
                ),
              ),
            for (var i = 0; i < unit.lessons.length; i++)
              Positioned(
                left: centers[i].dx - QJourney.nodeWidth / 2,
                top: centers[i].dy - QJourney.nodeTop,
                width: QJourney.nodeWidth,
                child: QJourneyNode(
                  key: statuses[i] == QNodeStatus.current
                      ? currentKey
                      : state.selectedLessonId == unit.lessons[i].lessonId
                      ? selectedKey
                      : ValueKey('node-${unit.lessons[i].lessonId}'),
                  node: QJourneyNodeData(
                    id: unit.lessons[i].lessonId,
                    title: unit.lessons[i].title,
                    kind: switch (unit.lessons[i].lessonType) {
                      LessonType.story => QNodeKind.story,
                      LessonType.practice => QNodeKind.practice,
                      _ => QNodeKind.lesson,
                    },
                    minutes: unit.lessons[i].estimatedMinutes,
                    embers: unit.lessons[i].xp,
                  ),
                  status: statuses[i],
                  selected: state.selectedLessonId == unit.lessons[i].lessonId,
                  lessonNumber: unit.lessons[i].index + 1,
                  lessonCount: unit.lessons.length,
                  onTap: () {
                    SensoryScope.of(context).select();
                    bloc.add(NodePicked(unit.lessons[i].lessonId));
                  },
                  onDismiss: () => bloc.add(const PopoverDismissed()),
                  onOpen: () => bloc.add(LessonOpened(unit.lessons[i].lessonId)),
                ),
              ),
            if (checkpoint)
              Positioned(
                left: centers.last.dx - QJourney.nodeWidth / 2,
                top: centers.last.dy - QJourney.nodeTop,
                width: QJourney.nodeWidth,
                child: QJourneyNode(
                  key: statuses.last == QNodeStatus.current
                      ? currentKey
                      : state.selectedUnitId == unit.unitId
                      ? selectedKey
                      : ValueKey('checkpoint-${unit.unitId}'),
                  node: QJourneyNodeData(
                    id: 'checkpoint-${unit.unitId}',
                    title: context.l10n.journeyCheckpoint,
                    kind: QNodeKind.checkpoint,
                    minutes: 0,
                    embers: 0,
                  ),
                  status: statuses.last,
                  selected: state.selectedUnitId == unit.unitId,
                  lessonNumber: count,
                  lessonCount: count,
                  actionLabel: context.l10n.journeyTakeUnitTest,
                  secondaryLabel: unit.unitTest.canSkip ? context.l10n.journeySkipUnit : null,
                  onSecondaryOpen: unit.unitTest.canSkip ? () => bloc.add(UnitTestOpened(unit.unitId)) : null,
                  onTap: () => bloc.add(CheckpointPicked(unit.unitId)),
                  onDismiss: () => bloc.add(const PopoverDismissed()),
                  onOpen: () => bloc.add(UnitTestOpened(unit.unitId)),
                ),
              ),
          ],
        ),
      );
    },
  );
}
