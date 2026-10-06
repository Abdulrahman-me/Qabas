import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class QReviewDeckCard extends StatelessWidget {
  const QReviewDeckCard({super.key, required this.count, required this.onReview});
  final String count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Container(
      padding: const EdgeInsets.all(QSpace.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [QColors.emerald500, QColors.emerald], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(QRadius.xl),
        boxShadow: QShadows.lifted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.reviewCardsReady(count), style: context.text.headlineSmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(s.reviewReviewTiming, style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                height: 80,
                child: Stack(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Positioned(
                        left: 10.0 + i * 6,
                        top: 10.0 - i * 5,
                        child: Transform.rotate(
                          angle: (i - 1) * 0.12,
                          child: Container(
                            width: 58,
                            height: 72,
                            decoration: BoxDecoration(
                              color: i == 2 ? QColors.softEmber : Colors.white.withValues(alpha: 0.85 - i * 0.1),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: QShadows.soft,
                            ),
                            child: i == 2 ? const Center(child: FlameMark(size: 22, animate: false)) : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: QSpace.lg),
          QButton(label: s.journeyStartReview, tone: QButtonTone.gold, icon: Icons.bolt_rounded, onPressed: onReview),
        ],
      ),
    );
  }
}
