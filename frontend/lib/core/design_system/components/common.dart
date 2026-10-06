// Ported from the read-only prototype; authored proportions and motion retained.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/buttons.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

/// Standard light surface.
class QCard extends StatelessWidget {
  const QCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(QSpace.md),
    this.color = QColors.surface,
    this.borderColor = QColors.line,
    this.onTap,
    this.radius = QRadius.lg,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    // A Material surface (not a coloured box) so ListTiles inside keep their ink.
    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadow ? QShadows.soft : null),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: borderColor != null ? BorderSide(color: borderColor!, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.color});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: QSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: context.text.titleLarge?.copyWith(color: color)),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                constraints: const BoxConstraints(minHeight: QSizes.tapTarget),
                alignment: AlignmentDirectional.centerEnd,
                child: Text(action!, style: context.text.labelMedium?.copyWith(color: QColors.emerald500)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small coloured label.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color = QColors.emerald500, this.background, this.icon});
  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background ?? color.withValues(alpha: 0.12), borderRadius: QRadius.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: color, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak / embers counters in the top bar.
class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.leading, required this.value, this.onTap, this.onDark = true, this.semantic});
  final Widget leading;
  final String value;
  final VoidCallback? onTap;
  final bool onDark;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semantic,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 12, 5),
        constraints: onTap == null ? null : const BoxConstraints(minHeight: QSizes.tapTarget),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.08) : QColors.surface,
          borderRadius: QRadius.chip,
          border: Border.all(color: onDark ? Colors.white.withValues(alpha: 0.1) : QColors.line, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(value, style: context.qText.stat.copyWith(fontSize: 16, color: onDark ? QColors.softEmber : QColors.deepInk)),
          ],
        ),
      ),
    );
  }
}

/// Lesson progress: a warm gold track whose leading edge glows like an ember.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value, this.height = 14, this.streakGlow = false, this.color});
  final double value;
  final double height;
  final bool streakGlow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: context.reduceMotion ? Duration.zero : QMotion.slow,
      curve: QMotion.emphasized,
      // progress fills from the reading start: right-to-left in Arabic
      builder: (context, v, _) => Transform.flip(
        flipX: Directionality.of(context) == TextDirection.rtl,
        child: CustomPaint(size: Size(double.infinity, height), painter: _TrackPainter(v, streakGlow, color)),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.v, this.glow, this.color);
  final double v;
  final bool glow;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = QColors.line);
    if (v <= 0) return;
    final w = math.max(size.height, size.width * v);
    final rect = Rect.fromLTWH(0, 0, w, size.height);
    if (glow) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(2), r),
        Paint()
          ..color = QColors.flameGold.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, r),
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), [color ?? const Color(0xFFEFB43A), color ?? QColors.flameGold]),
    );
    // gloss highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.height * 0.35, size.height * 0.22, math.max(0, w - size.height * 0.7), size.height * 0.24),
        Radius.circular(size.height),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.38),
    );
    // ember at the leading edge
    final tip = Offset(w - size.height / 2, size.height / 2);
    canvas.drawCircle(
      tip,
      size.height * 0.9,
      Paint()
        ..shader = ui.Gradient.radial(tip, size.height * 0.9, [
          const Color(0xFFFFF4D6).withValues(alpha: 0.9),
          QColors.flameGold.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.v != v || old.glow != glow || old.color != color;
}

/// Circular progress with a rounded cap.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    this.size = 56,
    this.stroke = 6,
    this.color = QColors.flameGold,
    this.track = QColors.line,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: context.reduceMotion ? Duration.zero : QMotion.slow,
      curve: QMotion.emphasized,
      builder: (_, v, c) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(v, stroke, color, track),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: c),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color, this.track);
  final double v, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (v > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, base..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}

/// The companion's speech bubble, with a tail pointing at the speaker.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.child, this.tailStart = true, this.color = QColors.surface});
  final Widget child;

  /// Tail on the leading edge (towards a companion standing before the text).
  final bool tailStart;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final left = tailStart == (dir == TextDirection.ltr);
    return CustomPaint(
      painter: _BubblePainter(left: left, color: color),
      child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 14), child: child),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.left, required this.color});
  final bool left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    final tailY = size.height * 0.62;
    final tail = Path();
    if (left) {
      tail
        ..moveTo(1, tailY - 9)
        ..lineTo(-11, tailY + 2)
        ..lineTo(1, tailY + 8);
    } else {
      tail
        ..moveTo(size.width - 1, tailY - 9)
        ..lineTo(size.width + 11, tailY + 2)
        ..lineTo(size.width - 1, tailY + 8);
    }
    final shape = Path()
      ..addRRect(r)
      ..addPath(tail, Offset.zero);
    canvas.drawShadow(shape, const Color(0x33073C37), 6, false);
    canvas.drawPath(shape, Paint()..color = color);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = QColors.line,
    );
    canvas.drawRRect(r.deflate(0.75), Paint()..color = color);
    canvas.drawPath(tail, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.left != left || old.color != color;
}

/// A dashed divider made of soft dots — the journey path in miniature.
class DottedLine extends StatelessWidget {
  const DottedLine({super.key, this.color = QColors.lineStrong, this.height = 2});
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(double.infinity, height), painter: _DotsPainter(color));
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double x = 2; x < size.width; x += 9) {
      canvas.drawCircle(Offset(x, size.height / 2), size.height / 2 + 0.4, p);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// The streak flame used in chips and headers.
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, this.size = 20, this.lit = true});
  final double size;
  final bool lit;

  @override
  Widget build(BuildContext context) =>
      FlameMark(size: size, color: lit ? const Color(0xFFE99A2C) : QColors.muted, animate: lit, dim: lit ? 1 : 0.4);
}
