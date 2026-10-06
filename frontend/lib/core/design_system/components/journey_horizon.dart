import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class QJourneyHorizon extends StatelessWidget {
  const QJourneyHorizon({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: QJourney.horizonHeight,
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1.1),
                radius: 1.1,
                colors: [QColors.flameGold.withValues(alpha: 0.35), QColors.flameGold.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: QJourney.hillHeight,
          child: CustomPaint(painter: HillsPainter()),
        ),
        Positioned(
          left: QSpace.md,
          right: QSpace.md,
          top: 40,
          child: Column(
            children: [
              const FlameMark(size: 30, glow: 1.2),
              const SizedBox(height: QSpace.xs),
              Text(
                context.l10n.journeyPathUnfolds,
                textAlign: TextAlign.center,
                style: context.text.labelMedium?.copyWith(color: QColors.softEmber.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
