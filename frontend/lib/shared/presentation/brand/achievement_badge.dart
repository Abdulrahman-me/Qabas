import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/motion/motion.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

part 'painters/achievement_badge_painter.dart';

/// Flame-inspired badge: a rounded shield of deep emerald with a gold rim and
/// a soft inner light. Locked badges rest in muted tones.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({super.key, this.achievementKey = 'first_step', required this.unlocked, this.size = 72});
  final String achievementKey;
  (IconData, Color) get _style => switch (achievementKey) {
    'kindled' => (Icons.local_fire_department_rounded, QColors.flameGold),
    'steady_flame' => (Icons.whatshot_rounded, QColors.badgeSteady),
    'word_keeper' => (Icons.translate_rounded, QColors.sky),
    'clear_sight' => (Icons.visibility_rounded, QColors.dusk),
    'unit_complete' => (Icons.flag_rounded, QColors.emerald500),
    'seeker' => (Icons.travel_explore_rounded, QColors.rose),
    'quick_light' => (Icons.bolt_rounded, QColors.gold700),
    _ => (Icons.directions_walk_rounded, QColors.emerald400),
  };
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(
        painter: _BadgePainter(_style.$2, unlocked),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.06),
            child: Icon(_style.$1, size: size * 0.4, color: unlocked ? QColors.softEmber : QColors.badgeMuted),
          ),
        ),
      ),
    );
    return unlocked ? Breathe(amount: 0.02, period: QMotion.badgeBreathe, child: badge) : badge;
  }
}
