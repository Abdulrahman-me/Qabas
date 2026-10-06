import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';

enum QUnitStatus { done, current, available, locked }

@immutable
final class QUnitBannerData {
  const QUnitBannerData({required this.title, required this.subtitle, required this.number, required this.progress, this.artKey});
  final String title, subtitle;
  final String? artKey;
  final int number;
  final double progress;
}

class QUnitBanner extends StatelessWidget {
  const QUnitBanner({super.key, required this.unit, required this.status, this.onGuide});
  final QUnitBannerData unit;
  final QUnitStatus status;
  final VoidCallback? onGuide;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final current = status == QUnitStatus.current;
    final locked = status == QUnitStatus.locked;
    final progress = unit.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(QSpace.md, QSpace.xl, QSpace.md, 0),
      child: Opacity(
        opacity: locked ? 0.62 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(QSpace.md, QSpace.md, QSpace.sm, QSpace.md),
          decoration: BoxDecoration(
            gradient: current
                ? const LinearGradient(colors: [QColors.emerald500, QColors.emerald], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: current ? null : QColors.night800.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(QRadius.xl),
            border: Border.all(color: current ? QColors.flameGold.withValues(alpha: 0.55) : QColors.nightLine, width: current ? 2 : 1.5),
            boxShadow: current ? QShadows.glow(QColors.flameGold, strength: 0.28) : null,
          ),
          child: Row(
            children: [
              UnitArtIcon.fromKey(artKey: unit.artKey ?? 'book', size: 56, dim: locked),
              const SizedBox(width: QSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.journeyUnitN(QNumbers.format(unit.number, context.isArabic ? 'ar' : 'en')).toUpperCase(),
                          style: context.qText.eyebrow.copyWith(
                            color: current ? QColors.softEmber : QColors.flameGold.withValues(alpha: 0.9),
                          ),
                        ),
                        if (status == QUnitStatus.done) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, size: 15, color: QColors.flameGold),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(unit.title, style: context.text.titleLarge?.copyWith(color: Colors.white)),
                    Text(unit.subtitle, style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.75))),
                    if (!locked) ...[
                      const SizedBox(height: QSpace.xs),
                      SizedBox(width: 160, child: ProgressTrack(value: progress, height: 8)),
                    ],
                  ],
                ),
              ),
              if (onGuide != null)
                QIconButton(
                  icon: Icons.menu_book_rounded,
                  tooltip: s.journeyGuide,
                  color: QColors.softEmber,
                  background: Colors.white.withValues(alpha: 0.1),
                  onTap: onGuide,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
