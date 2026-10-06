import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';
import 'package:qabas/shared/presentation/learning_path/soft_lock_sheet.dart';

class LessonIntroPage extends StatelessWidget {
  const LessonIntroPage({super.key});
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/journey');
    }
  }

  @override
  Widget build(BuildContext context) => ContentInteractions(
    child: BlocConsumer<LessonIntroBloc, LessonIntroState>(
      listener: (context, state) {
        if (state.start case final start?) context.read<ContentBloc>().add(ContentReceived(start.session.terms, start.session.sources));
        if (state.softLock case final lock?) {
          unawaited(showSoftLockSheet(context, lock, onOpen: (id) => context.pushReplacement('/lesson/${Uri.encodeComponent(id)}/intro')));
        }
      },
      builder: (context, state) {
        final start = state.start;
        if (start == null) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: QIconButton(
                      key: const ValueKey('intro-close'),
                      icon: Icons.close_rounded,
                      tooltip: context.l10n.commonClose,
                      onTap: () => _close(context),
                    ),
                  ),
                  Expanded(
                    child: state.status == LessonIntroStatus.failure || state.status == LessonIntroStatus.locked
                        ? QErrorView(onRetry: () => context.read<LessonIntroBloc>().add(const LessonIntroRetried()))
                        : const _IntroLoading(),
                  ),
                ],
              ),
            ),
          );
        }
        final lesson = start.session, info = start.info;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: QColors.morningMint,
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(gradient: QGradients.night),
                          child: Stack(
                            children: [
                              const Positioned.fill(child: NightSky(density: QLesson.introSkyDensity)),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  QSpace.xs,
                                  MediaQuery.paddingOf(context).top + QSpace.xxs,
                                  QSpace.page,
                                  QSpace.lg,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        QIconButton(
                                          key: const ValueKey('intro-close'),
                                          icon: Icons.close_rounded,
                                          color: QColors.softEmber,
                                          tooltip: context.l10n.commonClose,
                                          onTap: () => _close(context),
                                        ),
                                        const Spacer(),
                                        QIconButton(
                                          key: const ValueKey('lesson-reader'),
                                          icon: Icons.menu_book_outlined,
                                          color: QColors.softEmber,
                                          tooltip: context.l10n.sessionReadLesson,
                                          onTap: () => context.push('/reader/${Uri.encodeComponent(lesson.lessonId!)}'),
                                        ),
                                      ],
                                    ),
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                                        child: Padding(
                                          padding: const EdgeInsetsDirectional.only(start: QSpace.md),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (info.unitIndex != null && info.lessonIndex != null)
                                                      Reveal(
                                                        child: Text(
                                                          context.l10n
                                                              .sessionLessonPosition(
                                                                context.n(info.unitIndex!),
                                                                context.n(info.lessonIndex!),
                                                              )
                                                              .toUpperCase(),
                                                          style: context.qText.eyebrow.copyWith(color: QColors.flameGold),
                                                        ),
                                                      ),
                                                    const SizedBox(height: QLesson.smallGap),
                                                    Reveal(
                                                      delay: QLesson.reveal80,
                                                      child: Text(
                                                        lesson.title,
                                                        style: context.qText.display.copyWith(
                                                          color: QColors.softEmber,
                                                          fontSize: context.isArabic ? QLesson.introArabic : QLesson.introLatin,
                                                        ),
                                                      ),
                                                    ),
                                                    if (lesson.subtitle != null) ...[
                                                      const SizedBox(height: QSpace.xs),
                                                      Reveal(
                                                        delay: QLesson.reveal160,
                                                        child: Text(
                                                          lesson.subtitle!,
                                                          style: context.text.bodyMedium?.copyWith(
                                                            color: QColors.softEmber.withValues(alpha: QLesson.introSubtitleAlpha),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const Stack(
                                                clipBehavior: Clip.none,
                                                alignment: Alignment.bottomCenter,
                                                children: [
                                                  Positioned(
                                                    bottom: QLesson.introGlowBottom,
                                                    child: Glow(size: QLesson.introCompanion, opacity: QLesson.introGlowAlpha),
                                                  ),
                                                  CharacterView(
                                                    size: QLesson.introCompanion,
                                                    aspect: QLesson.introAspect,
                                                    zoom: QLesson.introZoom,
                                                    appearCue: CharacterCue.greet,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.md, QSpace.page, QSpace.xl),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Reveal(
                                    delay: QMotion.reveal200,
                                    child: Wrap(
                                      spacing: QSpace.xs,
                                      runSpacing: QSpace.xs,
                                      children: [
                                        if (info.minutes != null)
                                          Tag(
                                            context.l10n.commonMinutesLong(
                                              QNumbers.prototypePluralCount(info.minutes!),
                                              context.n(info.minutes!),
                                            ),
                                            icon: Icons.schedule_rounded,
                                            color: QColors.slate,
                                            background: QColors.surface,
                                          ),
                                        if (info.xp != null)
                                          Tag(
                                            context.l10n.commonPlusEmbers(context.n(info.xp!)),
                                            icon: Icons.local_fire_department_rounded,
                                            color: QColors.gold800,
                                            background: QColors.gold100,
                                          ),
                                        Tag(
                                          context.l10n.sessionExercisesCount(context.n(lesson.counts.interactions)),
                                          icon: Icons.extension_rounded,
                                          color: QColors.emerald500,
                                          background: QColors.emerald50,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: QSpace.lg),
                                  Text(context.l10n.sessionYouWillLearn, style: context.text.titleLarge),
                                  const SizedBox(height: QSpace.sm),
                                  for (var i = 0; i < lesson.objectives.length; i++)
                                    Reveal(
                                      delay: QLesson.reveal260 + QLesson.objectiveStagger * i,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: QSpace.sm),
                                        child: QCard(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: QSpace.md,
                                            vertical: QSpace.sm + QLesson.objectiveVerticalExtra,
                                          ),
                                          shadow: false,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: QLesson.objectiveBadge,
                                                height: QLesson.objectiveBadge,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: QColors.gold100,
                                                  borderRadius: BorderRadius.circular(QLesson.objectiveRadius),
                                                ),
                                                child: Text(
                                                  context.n(i + 1),
                                                  style: context.text.labelLarge?.copyWith(color: QColors.gold800),
                                                ),
                                              ),
                                              const SizedBox(width: QSpace.sm),
                                              Expanded(
                                                child: SpanText(
                                                  lesson.objectives[i],
                                                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: QSpace.md),
                                  if (lesson.reviewedBy != null || lesson.sourceCount > 0)
                                    Reveal(
                                      delay: QLesson.reveal560,
                                      child: QCard(
                                        color: QColors.emerald50,
                                        borderColor: QColors.emerald100,
                                        shadow: false,
                                        onTap: lesson.sourceCount > 0
                                            ? () => context.read<ContentBloc>().add(const SentenceSourcesOpened(null))
                                            : null,
                                        child: Column(
                                          children: [
                                            if (lesson.reviewedBy != null) _TrustRow(Icons.verified_user_rounded, lesson.reviewedBy!),
                                            if (lesson.reviewedBy != null && lesson.sourceCount > 0) const SizedBox(height: QSpace.xs),
                                            if (lesson.sourceCount > 0)
                                              _TrustRow(
                                                Icons.menu_book_rounded,
                                                context.l10n.sessionSourcesLine(context.n(lesson.sourceCount)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: QSpace.md),
                                  Reveal(
                                    delay: QLesson.reveal640,
                                    child: Row(
                                      children: [
                                        const FlameMark(size: QLesson.introHintFlame),
                                        const SizedBox(width: QSpace.xs),
                                        Expanded(child: Text(context.l10n.sessionCompanionIntro, style: context.text.bodySmall)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: QColors.line, width: QLesson.border),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(QSpace.page, QSpace.md, QSpace.page, QSpace.md + MediaQuery.paddingOf(context).bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                      child: QButton(
                        key: const ValueKey('lesson-start'),
                        label: start.resumed ? context.l10n.commonContinue : context.l10n.sessionBegin,
                        tone: QButtonTone.gold,
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => context.pushReplacement('/session/${Uri.encodeComponent(lesson.sessionId)}'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _TrustRow extends StatelessWidget {
  const _TrustRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: QLesson.interfaceIcon, color: QColors.emerald500),
      const SizedBox(width: QSpace.xs),
      Expanded(
        child: Text(text, style: context.text.labelMedium?.copyWith(color: QColors.emerald700)),
      ),
    ],
  );
}

class _IntroLoading extends StatelessWidget {
  const _IntroLoading();
  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.all(QSpace.page),
      child: Column(
        children: [
          CharacterView(size: QLesson.introCompanion, appearCue: CharacterCue.greet),
          SizedBox(height: QSpace.md),
          SizedBox(height: QSpace.xxxl, child: QInlineLoading()),
          SizedBox(height: QSpace.md),
          SizedBox(height: QSpace.huge, child: QInlineLoading()),
        ],
      ),
    ),
  );
}
