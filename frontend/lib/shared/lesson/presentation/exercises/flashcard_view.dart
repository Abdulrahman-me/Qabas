import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/lesson/domain/entities/exercise.dart';
import 'package:qabas/shared/lesson/domain/logic/answer_drafts.dart';
import 'package:qabas/shared/lesson/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

class FlashcardView extends StatefulWidget {
  const FlashcardView({super.key, required this.payload, required this.draft, required this.locked});
  final FlashcardPayload payload;
  final RatingDraft draft;
  final bool locked;
  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> with SingleTickerProviderStateMixin {
  late final _flip = AnimationController(vsync: this, duration: QMotion.slow);
  @override
  void initState() {
    super.initState();
    _flip.value = widget.draft.flipped ? 1 : 0;
  }

  @override
  void didUpdateWidget(FlashcardView old) {
    super.didUpdateWidget(old);
    if (old.draft.flipped != widget.draft.flipped) {
      if (context.reduceMotion) {
        _flip.value = widget.draft.flipped ? 1 : 0;
      } else if (widget.draft.flipped) {
        _flip.forward();
      } else {
        _flip.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _flip,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(QSpace.page),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
            child: SizedBox(
              height: math.max(QReview.minimumContentHeight, box.maxHeight - QSpace.page * 2),
              child: Column(
                children: [
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: context.l10n.reviewTapToFlip,
                    onTap: widget.locked ? null : _toggle,
                    child: GestureDetector(
                      excludeFromSemantics: true,
                      onTap: widget.locked ? null : _toggle,
                      child: AnimatedBuilder(
                        animation: _flip,
                        builder: (context, _) {
                          final t = QMotion.emphasized.transform(_flip.value), back = t > .5;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, QReview.perspective)
                              ..rotateY(t * math.pi),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(back ? math.pi : 0),
                              child: Container(
                                key: ValueKey(back ? 'card-back' : 'card-front'),
                                height: QReview.cardHeight,
                                width: double.infinity,
                                padding: const EdgeInsets.all(QSpace.xl),
                                decoration: BoxDecoration(
                                  color: back ? QColors.emerald500 : QColors.surface,
                                  borderRadius: BorderRadius.circular(QRadius.xxl),
                                  border: Border.all(color: back ? QColors.emerald400 : QColors.line, width: QReview.border),
                                  boxShadow: QShadows.lifted,
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: SpanText(
                                      back ? widget.payload.back : widget.payload.front,
                                      textAlign: TextAlign.center,
                                      style: (back ? context.text.titleLarge : context.text.headlineSmall)?.copyWith(
                                        color: back ? QColors.surface : QColors.deepInk,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: QSpace.md),
                  Text(
                    _flip.value > .5 ? context.l10n.reviewHowWell : context.l10n.reviewTapToFlip,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium,
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: context.reduceMotion ? Duration.zero : QMotion.normal,
                    opacity: _flip.value > .5 ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: _flip.value <= .5 || widget.locked,
                      child: ExcludeSemantics(
                        excluding: _flip.value <= .5,
                        child: LayoutBuilder(
                          builder: (context, width) {
                            final ratings = [
                              ('again', context.l10n.reviewAgain, QButtonTone.retry),
                              ('hard', context.l10n.reviewHard, QButtonTone.light),
                              ('good', context.l10n.reviewGood, QButtonTone.emerald),
                              ('easy', context.l10n.reviewEasy, QButtonTone.gold),
                            ];
                            return Wrap(
                              spacing: QReview.gap,
                              runSpacing: QSpace.sm,
                              children: [
                                for (final r in ratings)
                                  SizedBox(
                                    width:
                                        (width.maxWidth - QReview.gap * (width.maxWidth < QBreakpoints.readingWidth / 2 ? 1 : 3)) /
                                        (width.maxWidth < QBreakpoints.readingWidth / 2 ? 2 : 4),
                                    child: QButton(
                                      key: ValueKey('rating-${r.$1}'),
                                      label: r.$2,
                                      tone: r.$3,
                                      height: QReview.ratingHeight,
                                      onPressed: widget.locked ? null : () => context.read<ExerciseStepBloc>().add(RecallRated(r.$1)),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: QReview.ratingFooterHeight),
                  const SizedBox(height: QSpace.md),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  void _toggle() {
    SensoryScope.of(context).tap();
    context.read<ExerciseStepBloc>().add(const CardFlipped());
  }
}
