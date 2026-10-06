import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/router/routes.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:qabas/shared/domain/entities/journey.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});
  @override
  Widget build(BuildContext context) => BlocConsumer<DiscoverBloc, DiscoverState>(
    listenWhen: (a, b) => a.actionSerial != b.actionSerial,
    listener: (context, state) {
      if (state.lessonToOpen case final String id) {
        final lesson = state.journey!.lesson(id)!, unit = state.journey!.unitFor(id)!;
        context.push(
          Routes.lessonIntro(id),
          extra: LessonRef(lessonId: id, unitId: unit.unitId, title: lesson.title),
        );
      }
    },
    builder: (context, state) {
      final bloc = context.read<DiscoverBloc>(), l = context.l10n, locale = context.isArabic ? 'ar' : 'en';
      if (state.journey == null) {
        return Scaffold(
          body: SafeArea(
            child: state.status == DiscoverStatus.failure
                ? QErrorView(
                    kind: failureKind(state.failure!),
                    body: failureBody(state.failure!, l),
                    onRetry: () => bloc.add(const DiscoverRefreshed()),
                  )
                : const DelayedLoading(child: QLoadingView()),
          ),
        );
      }
      if (state.units.isEmpty) {
        return Scaffold(
          body: SafeArea(
            child: QEmptyView(
              title: l.discoverEmptyTitle,
              body: l.discoverEmptyBody,
              illustration: const CharacterView(size: QJourney.companion, appearCue: CharacterCue.encourage),
              action: (l.commonTabJourney, () => context.go(Routes.journey)),
            ),
          ),
        );
      }
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                bloc.add(const DiscoverRefreshed());
                await bloc.stream.firstWhere((s) => !s.refreshing, orElse: () => bloc.state);
              },
              child: ListView(
                key: const PageStorageKey('discover-scroll'),
                padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.lg, QSpace.page, QSpace.xxl),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l.commonTabDiscover, style: context.text.headlineLarge),
                          const SizedBox(height: QSpace.md),
                          QCard(
                            key: const ValueKey('discover-notice'),
                            shadow: false,
                            color: QColors.surfaceSunk,
                            child: Text(l.discoverNotice, style: context.text.bodyMedium),
                          ),
                          if (state.refreshing) ...[const SizedBox(height: QSpace.sm), const QInlineLoading()],
                          if (state.failure != null) ...[
                            const SizedBox(height: QSpace.sm),
                            QInlineError(message: failureBody(state.failure!, l), onRetry: () => bloc.add(const DiscoverRefreshed())),
                          ],
                          for (final unit in state.units) ...[
                            const SizedBox(height: QSpace.xl),
                            SectionHeader(l.discoverUnitHeading(QNumbers.format(unit.index, locale), unit.title)),
                            for (final lesson in unit.lessons.where((l) => l.standaloneEligible))
                              Padding(
                                padding: const EdgeInsets.only(bottom: QSpace.xs),
                                child: QCard(
                                  key: ValueKey('discover-${lesson.lessonId}'),
                                  shadow: false,
                                  onTap: () => bloc.add(LessonPicked(lesson.lessonId)),
                                  child: Row(
                                    children: [
                                      QJourneyNodeGlyph(
                                        node: QJourneyNodeData(
                                          id: lesson.lessonId,
                                          title: lesson.title,
                                          kind: switch (lesson.lessonType) {
                                            LessonType.story => QNodeKind.story,
                                            LessonType.practice => QNodeKind.practice,
                                            _ => QNodeKind.lesson,
                                          },
                                          minutes: lesson.estimatedMinutes,
                                          embers: lesson.xp,
                                        ),
                                        status: lesson.state == LessonState.completed ? QNodeStatus.done : QNodeStatus.available,
                                        size: QJourney.nodeSize,
                                      ),
                                      const SizedBox(width: QSpace.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(lesson.title, style: context.text.titleSmall),
                                            const SizedBox(height: QSpace.xs),
                                            Wrap(
                                              spacing: QSpace.sm,
                                              runSpacing: QSpace.xs,
                                              children: [
                                                Text(
                                                  l.commonMinutesLong(
                                                    QNumbers.prototypePluralCount(lesson.estimatedMinutes),
                                                    QNumbers.format(lesson.estimatedMinutes, locale),
                                                  ),
                                                  style: context.text.bodySmall,
                                                ),
                                                Text(
                                                  l.commonPlusEmbers(QNumbers.format(lesson.xp, locale)),
                                                  style: context.text.labelMedium?.copyWith(color: QColors.emerald500),
                                                ),
                                              ],
                                            ),
                                            if (lesson.state == LessonState.completed) ...[
                                              const SizedBox(height: QSpace.xs),
                                              Text(l.journeyDoneLabel, style: context.text.labelMedium?.copyWith(color: QColors.correct)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (lesson.state == LessonState.completed)
                                        const Icon(Icons.check_circle_rounded, color: QColors.correct)
                                      else
                                        const Icon(Icons.chevron_right_rounded, color: QColors.muted),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
