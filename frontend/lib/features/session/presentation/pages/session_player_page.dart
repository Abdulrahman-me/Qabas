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
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/recitation.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/steps/content_step_bloc.dart';
import 'package:qabas/features/session/presentation/steps/content_step_views.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/features/session/presentation/widgets/feedback_panel.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/content_sheets.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

class SessionPlayerPage extends StatefulWidget {
  const SessionPlayerPage({super.key, this.createExerciseBloc});
  final ExerciseStepBloc Function(Exercise)? createExerciseBloc;
  @override
  State<SessionPlayerPage> createState() => _SessionPlayerPageState();
}

class _SessionPlayerPageState extends State<SessionPlayerPage> {
  bool _quitOpen = false;
  Future<void> _quit() async {
    if (_quitOpen) return;
    _quitOpen = true;
    final player = context.read<SessionPlayerBloc>();
    final leave = await showQSheet<bool>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CharacterView(size: QLesson.introCompanion, zoom: QJourney.sheetZoom, appearCue: CharacterCue.encourage),
          ),
          const SizedBox(height: QSpace.sm),
          Text(ctx.l10n.sessionQuitTitle, textAlign: TextAlign.center, style: ctx.text.headlineSmall),
          const SizedBox(height: QSpace.xs),
          Text(ctx.l10n.sessionQuitBody, textAlign: TextAlign.center, style: ctx.text.bodyMedium),
          const SizedBox(height: QSpace.xl),
          QButton(key: const ValueKey('keep-learning'), label: ctx.l10n.sessionKeepLearning, onPressed: () => Navigator.pop(ctx, false)),
          const SizedBox(height: QSpace.xs),
          QButton(
            key: const ValueKey('leave-lesson'),
            label: ctx.l10n.sessionLeave,
            tone: QButtonTone.ghost,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    _quitOpen = false;
    if (leave == true && mounted && !player.isClosed) player.add(const QuitConfirmed());
  }

  @override
  Widget build(BuildContext context) => ContentInteractions(
    child: BlocConsumer<SessionPlayerBloc, SessionPlayerState>(
      listenWhen: (previous, current) =>
          previous.status != current.status || previous.session != current.session || previous.quitFailure != current.quitFailure,
      listener: (context, state) {
        if (state.quitFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureBody(state.quitFailure!, context.l10n))));
        }
        if (state.session case final session?) context.read<ContentBloc>().add(ContentReceived(session.terms, session.sources));
        if (state.status == PlayerStatus.left) context.go('/journey');
        if (state.status == PlayerStatus.finished) context.go('/session/${state.session!.sessionId}/result');
        if (state.status == PlayerStatus.feedback && state.evaluation != null) {
          final sensory = SensoryScope.of(context);
          if (state.evaluation!.correct == true) {
            sensory.correct();
            if (state.combo >= 3) sensory.sparkle();
          } else if (state.evaluation!.correct == false) {
            sensory.retry();
          }
        }
      },
      builder: (context, state) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_quit());
          },
          child: Scaffold(
            backgroundColor: QColors.morningMint,
            body: SafeArea(
              bottom: state.item is ExerciseItem && (state.item as ExerciseItem).exercise?.type == ExerciseType.flashcard,
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: QBreakpoints.composerMax),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(QSpace.xs, QSpace.xs, QLesson.topEnd, QLesson.topBottom),
                        child: Row(
                          children: [
                            QIconButton(
                              key: const ValueKey('player-close'),
                              icon: Icons.close_rounded,
                              tooltip: context.l10n.commonClose,
                              color: QColors.muted,
                              onTap: _quit,
                            ),
                            const SizedBox(width: QLesson.smallGap),
                            Expanded(
                              child: Semantics(
                                value: context.l10n.sessionProgress(context.n((state.progress * 100).round())),
                                child: ProgressTrack(value: state.progress, height: QLesson.progressHeight),
                              ),
                            ),
                            if (state.combo >= 3)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: QSpace.xs),
                                child: Semantics(
                                  label: context.l10n.sessionCombo(context.n(state.combo)),
                                  child: Row(
                                    children: [
                                      const FlameMark(size: QLesson.introHintFlame),
                                      const SizedBox(width: QSpace.xs),
                                      Text(context.n(state.combo), style: context.text.labelLarge?.copyWith(color: QColors.gold800)),
                                    ],
                                  ),
                                ),
                              ),
                            if ((state.session?.sourceCount ?? 0) > 0)
                              QIconButton(
                                key: const ValueKey('player-sources'),
                                icon: Icons.menu_book_outlined,
                                tooltip: context.l10n.sessionSourcesTitle,
                                onTap: () => context.read<ContentBloc>().add(const SentenceSourcesOpened(null)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: switch (state.status) {
                      PlayerStatus.initial || PlayerStatus.loading => const QLoadingView(),
                      PlayerStatus.failure => QErrorView(
                        onRetry: () => context.read<SessionPlayerBloc>().add(
                          state.session == null ? const SessionLoadRetried() : const FinishRequested(),
                        ),
                      ),
                      PlayerStatus.finishing => const QLoadingView(),
                      PlayerStatus.retryRound => QEmptyView(
                        title: context.l10n.sessionRetryTitle,
                        body: context.l10n.sessionRetryBody,
                        action: (context.l10n.commonContinue, () => context.read<SessionPlayerBloc>().add(const RetryRoundStarted())),
                      ),
                      PlayerStatus.previewEnded => QEmptyView(
                        title: context.l10n.sessionPreviewEndTitle,
                        body: context.l10n.sessionPreviewEndBody,
                        action: (context.l10n.sessionBackToJourney, () => context.read<SessionPlayerBloc>().add(const QuitConfirmed())),
                      ),
                      _ =>
                        state.item == null
                            ? const SizedBox.shrink()
                            : AnimatedSwitcher(
                                duration: context.reduceMotion ? Duration.zero : QMotion.slow,
                                switchInCurve: QMotion.emphasized,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) => _StepTransitionScope(
                                  animation: animation,
                                  current: child.key == ValueKey('${state.item!.blockId}/${state.inRetry}'),
                                  dx:
                                      (context.isRtl ? -1 : 1) *
                                      (child.key == ValueKey('${state.item!.blockId}/${state.inRetry}')
                                          ? QLesson.stepEnterDx
                                          : QLesson.stepExitDx),
                                  child: child,
                                ),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    if (previous.isNotEmpty)
                                      VisualCrossfadeScope(key: previous.last.key, allowOutgoing: false, child: previous.last),
                                    if (current != null)
                                      VisualCrossfadeScope(key: current.key, allowOutgoing: previous.isEmpty, child: current),
                                  ],
                                ),
                                child: state.item is ExerciseItem && (state.item as ExerciseItem).exercise != null
                                    ? _MountedExercise(
                                        key: ValueKey('${state.item!.blockId}/${state.inRetry}'),
                                        exercise: (state.item as ExerciseItem).exercise!,
                                        createBloc: widget.createExerciseBloc,
                                      )
                                    : _MountedStep(key: ValueKey('${state.item!.blockId}/${state.inRetry}'), item: state.item!),
                              ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MountedStep extends StatelessWidget {
  const _MountedStep({super.key, required this.item});
  final SessionItem item;
  @override
  Widget build(BuildContext context) => BlocProvider<ContentStepBloc>(
    create: (context) {
      final player = context.read<SessionPlayerBloc>().state;
      if (item is PredictItem) {
        return ContentStepBloc(
          item,
          initial: ContentStepState(
            selectedOptionId: player.predictions[item.blockId],
            status: player.status == PlayerStatus.feedback ? ContentStepStatus.feedback : ContentStepStatus.ready,
          ),
        );
      }
      return stepBloc(item);
    },
    child: BlocConsumer<ContentStepBloc, ContentStepState>(
      listener: (context, state) {
        final player = context.read<SessionPlayerBloc>();
        if (item is PredictItem && state.selectedOptionId != null) {
          player.add(PredictionSelectionSaved(item.blockId, state.selectedOptionId!));
        }
        if (state.intent == StepIntent.predictionChecked) {
          player.add(PredictionChecked(item.blockId));
          SensoryScope.of(context).sparkle();
        }
        if (state.intent == StepIntent.completed) player.add(StepCompleted(item.blockId));
        if (state.intent == StepIntent.placeholderContinued) player.add(ExercisePlaceholderContinued(item.blockId));
      },
      builder: (context, state) => LayoutBuilder(
        builder: (context, box) => Column(
          children: [
            Expanded(child: _StepTransition(child: contentStepView(item))),
            _PinnedAction(
              child: AnimatedSwitcher(
                duration: context.reduceMotion ? Duration.zero : QMotion.medium,
                switchInCurve: QMotion.emphasized,
                transitionBuilder: (child, anim) => SizeTransition(
                  sizeFactor: anim,
                  alignment: Alignment.topCenter,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, QLesson.feedbackEnterDy), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: state.status == ContentStepStatus.feedback && item is PredictItem
                    ? ConstrainedBox(
                        key: const ValueKey('feedback'),
                        constraints: BoxConstraints(maxHeight: box.maxHeight * QLesson.feedbackMaxFraction),
                        child: FeedbackPanel(
                          reveal: (item as PredictItem).reveal,
                          onContinue: () => context.read<ContentStepBloc>().add(const CtaPressed()),
                        ),
                      )
                    : const _ActionBar(key: ValueKey('action')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The prototype slides the reading surface while its pinned action stays put.
class _StepTransitionScope extends InheritedWidget {
  const _StepTransitionScope({required this.animation, required this.dx, required this.current, required super.child});
  final Animation<double> animation;
  final double dx;
  final bool current;
  @override
  bool updateShouldNotify(_StepTransitionScope old) => animation != old.animation || dx != old.dx || current != old.current;
}

class _PinnedAction extends StatelessWidget {
  const _PinnedAction({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final current = context.dependOnInheritedWidgetOfExactType<_StepTransitionScope>()!.current;
    return IgnorePointer(
      ignoring: !current,
      child: Opacity(opacity: current ? 1 : 0, child: child),
    );
  }
}

class _StepTransition extends StatelessWidget {
  const _StepTransition({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final motion = context.dependOnInheritedWidgetOfExactType<_StepTransitionScope>()!;
    return IgnorePointer(
      ignoring: !motion.current,
      child: FadeTransition(
        opacity: motion.animation,
        child: SlideTransition(
          position: Tween(begin: Offset(motion.dx, 0), end: Offset.zero).animate(motion.animation),
          child: child,
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({super.key});
  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<ContentStepBloc>();
    final cta = bloc.cta;
    final label =
        cta.serverLabel ??
        switch (cta.labelKey) {
          'commonCheck' => context.l10n.commonCheck,
          'commonNext' => context.l10n.commonNext,
          'sessionShowMore' => context.l10n.sessionShowMore,
          'sessionFindOut' => context.l10n.sessionFindOut,
          _ => context.l10n.commonContinue,
        };
    return Container(
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
            key: const ValueKey('step-cta'),
            label: label,
            tone: cta.tone,
            onPressed: cta.enabled && bloc.state.status != ContentStepStatus.completed ? () => bloc.add(const CtaPressed()) : null,
          ),
        ),
      ),
    );
  }
}

class _MountedExercise extends StatefulWidget {
  const _MountedExercise({super.key, required this.exercise, this.createBloc});
  final Exercise exercise;
  final ExerciseStepBloc Function(Exercise)? createBloc;
  @override
  State<_MountedExercise> createState() => _MountedExerciseState();
}

class _MountedExerciseState extends State<_MountedExercise> {
  int _lastSubmitSerial = 0;
  final _character = CharacterController();
  Exercise get exercise => widget.exercise;
  ExerciseStepBloc Function(Exercise)? get createBloc => widget.createBloc;
  @override
  void dispose() {
    _character.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (c) {
      final bloc = createBloc?.call(exercise) ?? ExerciseStepBloc(exercise);
      final answer = c.read<SessionPlayerBloc>().state.answer;
      if (answer != null) bloc.add(AnswerDraftRestored(answer));
      return bloc;
    },
    child: BlocListener<SessionPlayerBloc, SessionPlayerState>(
      listenWhen: (previous, current) =>
          previous.status != current.status && current.status == PlayerStatus.feedback && current.evaluation?.exerciseId == exercise.id,
      listener: (_, player) {
        _character.mood = CharacterMood.idle;
        _character.cue(
          player.evaluation?.correct == true
              ? CharacterCue.correct
              : player.evaluation?.correct == false
              ? CharacterCue.retry
              : CharacterCue.encourage,
        );
      },
      child: BlocListener<ExerciseStepBloc, ExerciseStepState>(
        listenWhen: (p, c) => p.submitSerial != c.submitSerial || p.recitationStatus != c.recitationStatus,
        listener: (c, s) {
          _character.mood = s.recitationStatus == RecitationStatus.recording
              ? CharacterMood.listening
              : s.recitationStatus == RecitationStatus.checking
              ? CharacterMood.thinking
              : CharacterMood.idle;
          if (s.submitSerial != _lastSubmitSerial &&
              s.recitationStatus != RecitationStatus.recording &&
              s.recitationStatus != RecitationStatus.checking) {
            _lastSubmitSerial = s.submitSerial;
            c.read<SessionPlayerBloc>().add(AnswerChecked(exercise.id, s.draft.toPayload(), c.read<ExerciseStepBloc>().elapsed));
          }
        },
        child: BlocBuilder<ExerciseStepBloc, ExerciseStepState>(
          builder: (c, s) => BlocBuilder<SessionPlayerBloc, SessionPlayerState>(
            builder: (c, player) => LayoutBuilder(
              builder: (c, box) => Column(
                children: [
                  if (player.session?.mode == 'quick')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: QSpace.page, vertical: QSpace.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: ProgressTrack(
                              key: const ValueKey('quick-review-timer'),
                              value: (player.remaining.inMilliseconds / (exercise.timeLimit?.inMilliseconds ?? 1)).clamp(0, 1),
                              height: QLesson.progressHeight,
                              color: player.remaining <= QReview.timerWarning ? QColors.retry : null,
                            ),
                          ),
                          const SizedBox(width: QSpace.sm),
                          Semantics(
                            label: c.l10n.sessionSecondsRemaining(c.n(player.secondsRemaining)),
                            child: ExcludeSemantics(child: Text(c.n(player.secondsRemaining), style: c.text.labelLarge)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _StepTransition(
                      child: const ExerciseRendererRegistry().build(
                        exercise,
                        s,
                        player.evaluation?.exerciseId == exercise.id ? player.evaluation : null,
                        locked: player.submitting || player.failure != null || player.status == PlayerStatus.feedback,
                      ),
                    ),
                  ),
                  if (exercise.type != ExerciseType.flashcard || player.failure != null || player.submitting)
                    _PinnedAction(
                      child: AnimatedSwitcher(
                        duration: c.reduceMotion ? Duration.zero : QMotion.medium,
                        switchInCurve: QMotion.emphasized,
                        transitionBuilder: (child, anim) => SizeTransition(
                          sizeFactor: anim,
                          alignment: Alignment.topCenter,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, QLesson.feedbackEnterDy), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: player.status == PlayerStatus.feedback && player.evaluation?.exerciseId == exercise.id
                            ? ConstrainedBox(
                                key: const ValueKey('exercise-feedback'),
                                constraints: BoxConstraints(maxHeight: box.maxHeight * QLesson.feedbackMaxFraction),
                                child: FeedbackPanel.exercise(
                                  evaluation: player.evaluation!,
                                  exercise: exercise,
                                  onContinue: () => c.read<SessionPlayerBloc>().add(const FeedbackContinued()),
                                ),
                              )
                            : Container(
                                key: const ValueKey('exercise-action'),
                                color: QColors.morningMint,
                                padding: EdgeInsets.fromLTRB(
                                  QSpace.page,
                                  QSpace.md,
                                  QSpace.page,
                                  QSpace.lg + MediaQuery.paddingOf(c).bottom,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (player.failure != null) ...[
                                          Text(c.l10n.sessionSubmitError, style: c.text.bodySmall),
                                          const SizedBox(height: QSpace.xs),
                                        ],
                                        if (player.submitting) const QInlineLoading(),
                                        QButton(
                                          key: const ValueKey('exercise-cta'),
                                          label: player.failure != null
                                              ? c.l10n.commonRetry
                                              : exercise.type == ExerciseType.reciteVerse
                                              ? c.l10n.commonContinue
                                              : c.l10n.commonCheck,
                                          onPressed: player.submitting || !s.draft.isComplete
                                              ? null
                                              : () => player.failure != null
                                                    ? c.read<SessionPlayerBloc>().add(const AnswerSubmitRetried())
                                                    : c.read<ExerciseStepBloc>().add(const AnswerCheckPressed()),
                                        ),
                                      ],
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
  );
}
