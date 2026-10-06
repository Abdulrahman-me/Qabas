import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/l10n/q_numbers.dart';

/// Extracted from the completion statistics tile.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.format, this.style});
  final int value;
  final String Function(int) format;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return Text(format(value), style: style ?? context.qText.stat);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: QMotion.countUp,
      curve: QMotion.emphasized,
      builder: (_, value, _) => Text(format(value.round()), style: style ?? context.qText.stat),
    );
  }
}

/// Extracted without changing the streak screen's timing or travel distance.
class RollingNumber extends StatelessWidget {
  const RollingNumber({super.key, required this.from, required this.to, this.animate = true});
  final int from;
  final int to;
  final bool animate;
  @override
  Widget build(BuildContext context) {
    String number(int value) => QNumbers.format(value, Localizations.localeOf(context).languageCode);
    final style = context.qText.stat.copyWith(fontSize: 88, color: QColors.softEmber, height: 1);
    if (!animate || context.reduceMotion) return Text(number(to), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: QMotion.rollingNumber,
      curve: const Interval(0.55, 1, curve: QMotion.settle),
      builder: (_, t, _) => SizedBox(
        height: 92,
        child: ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, -92 * t),
                child: Opacity(
                  opacity: (1 - t).clamp(0, 1),
                  child: Text(number(from), style: style),
                ),
              ),
              Transform.translate(
                offset: Offset(0, 92 * (1 - t)),
                child: Text(number(to), style: style.copyWith(color: QColors.flameGold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
