import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class QJourneyToday extends StatelessWidget {
  const QJourneyToday({
    super.key,
    required this.greeting,
    required this.minutes,
    required this.goal,
    required this.learnedToday,
    this.nextTitle,
    this.onContinue,
  });
  final String greeting;
  final int minutes, goal;
  final bool learnedToday;
  final String? nextTitle;
  final VoidCallback? onContinue;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, locale = context.isArabic ? 'ar' : 'en';
    final progress = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(l.journeyDailyGoal.toUpperCase(), style: context.qText.eyebrow.copyWith(color: QColors.flameGold, fontSize: 10.5)),
        const SizedBox(height: 2),
        Text(
          l.journeyGoalProgress(QNumbers.format(math.min(minutes, goal), locale), QNumbers.format(goal, locale)),
          style: context.text.labelMedium?.copyWith(color: QColors.softEmber.withValues(alpha: 0.85)),
        ),
      ],
    );
    final main = Row(
      children: [
        RingProgress(
          value: goal > 0 ? (minutes / goal).clamp(0, 1) : 0,
          size: 58,
          stroke: 6,
          track: Colors.white.withValues(alpha: 0.1),
          child: StreakFlame(size: 22, lit: learnedToday),
        ),
        const SizedBox(width: QSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: context.text.titleLarge?.copyWith(color: QColors.softEmber)),
              const SizedBox(height: 2),
              Text(
                learnedToday ? l.journeyLearnedTodayLine : l.journeyKeepTheLight,
                style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(QSpace.md, QSpace.lg, QSpace.md, QSpace.xs),
      child: Reveal(
        child: Container(
          padding: const EdgeInsets.all(QSpace.md),
          decoration: BoxDecoration(
            color: QColors.night800.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(QRadius.xl),
            border: Border.all(color: QColors.nightLine, width: 1.5),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(1) > 1.1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (compact) ...[
                    main,
                    const SizedBox(height: QSpace.xs),
                    Align(alignment: AlignmentDirectional.centerEnd, child: progress),
                  ] else
                    Row(
                      children: [
                        Expanded(child: main),
                        progress,
                      ],
                    ),
                  if (nextTitle != null) ...[
                    const SizedBox(height: QSpace.sm),
                    Pressable(
                      onTap: onContinue,
                      scale: 0.98,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: QSpace.sm, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(QRadius.md),
                          border: Border.all(color: QColors.softEmber.withValues(alpha: 0.18), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const FlameMark(size: 20, animate: false),
                            const SizedBox(width: QSpace.xs),
                            Expanded(
                              child: Text(
                                nextTitle!,
                                style: context.text.labelMedium?.copyWith(color: QColors.softEmber.withValues(alpha: 0.85)),
                              ),
                            ),
                            const SizedBox(width: QSpace.xs),
                            Text(l.commonContinue, style: context.text.labelMedium?.copyWith(color: QColors.flameGold)),
                            Icon(Icons.chevron_right_rounded, color: QColors.softEmber.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
