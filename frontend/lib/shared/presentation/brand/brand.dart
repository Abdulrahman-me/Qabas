// Ported from the read-only prototype; authored proportions and motion retained.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/motion/motion.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/l10n/l10n_x.dart';

part 'painters/brand_painters.dart';

/// The qabas: a small, soft, rounded flame. Gentle — never a blaze (brief §6.3).
Path flamePath(Size s) {
  final w = s.width, h = s.height;
  Offset p(double x, double y) => Offset(x * w, y * h);
  final path = Path()..moveTo(p(0.5, 1).dx, p(0.5, 1).dy);
  void c(double x1, double y1, double x2, double y2, double x3, double y3) => path.cubicTo(x1 * w, y1 * h, x2 * w, y2 * h, x3 * w, y3 * h);
  c(0.23, 1.0, 0.07, 0.82, 0.09, 0.6);
  c(0.11, 0.41, 0.28, 0.31, 0.41, 0.15);
  c(0.47, 0.08, 0.52, 0.03, 0.57, 0.0);
  c(0.62, 0.11, 0.67, 0.2, 0.75, 0.31);
  c(0.85, 0.45, 0.93, 0.56, 0.91, 0.68);
  c(0.89, 0.88, 0.73, 1.0, 0.5, 1.0);
  path.close();
  return path;
}

/// The brand flame, optionally glowing and gently flickering.
class FlameMark extends StatefulWidget {
  const FlameMark({super.key, this.size = 28, this.glow = 0, this.animate = true, this.color = QColors.flameGold, this.dim = 1});

  final double size;
  final double glow;
  final bool animate;
  final Color color;
  final double dim;

  @override
  State<FlameMark> createState() => _FlameMarkState();
}

class _FlameMarkState extends State<FlameMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: QMotion.flame);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.animate && !reduceMotionOf(context);
    if (animate && !_c.isAnimating) _c.repeat();
    if (!animate) _c.stop();
  }

  @override
  void didUpdateWidget(FlameMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    final animate = widget.animate && !reduceMotionOf(context);
    if (animate && !_c.isAnimating) _c.repeat();
    if (!animate) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.12,
        child: CustomPaint(
          painter: _FlamePainter(t: _c, glow: widget.glow, outer: widget.color, dim: widget.dim),
        ),
      ),
    );
  }
}

/// Logo lockups (brief §7): symbol + Arabic + Latin wordmarks.
class QabasLogo extends StatelessWidget {
  const QabasLogo({super.key, this.size = 1, this.onDark = true, this.stacked = true, this.showFlame = true});
  final double size;
  final bool onDark;
  final bool stacked;

  /// Off when the companion on screen is already carrying the ember.
  final bool showFlame;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? QColors.softEmber : QColors.emerald;
    final arabic = Text(context.l10n.commonBrandArabic, textDirection: TextDirection.rtl, style: QBrandText.arabicWordmark(size, ink));
    final latin = Text(context.l10n.commonBrandLatin, style: QBrandText.latinWordmark(size, ink.withValues(alpha: 0.85)));
    final flame = FlameMark(size: 46 * size, glow: onDark ? 1.4 : 0.6);
    if (!stacked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlameMark(size: 26 * size, glow: onDark ? 1 : 0.4),
          SizedBox(width: 8 * size),
          Text(context.l10n.commonBrandLatin, style: QBrandText.inlineWordmark(size, ink)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFlame) ...[flame, SizedBox(height: 6 * size)],
        arabic,
        SizedBox(height: 4 * size),
        latin,
      ],
    );
  }
}

// ---------------------------------------------------------------- backdrops

/// Faint Islamic geometric lattice (eight-pointed stars). Texture only —
/// never dominant (brief §6.3).

/// Deep-emerald night with twinkling stars and an optional geometric weave.
class NightSky extends StatefulWidget {
  const NightSky({super.key, this.child, this.density = 1, this.pattern = true, this.gradient = QGradients.night, this.seed = 7});

  final Widget? child;
  final double density;
  final bool pattern;
  final Gradient gradient;
  final int seed;

  @override
  State<NightSky> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSky> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: QMotion.nightSky);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: widget.gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.pattern)
            RepaintBoundary(
              child: CustomPaint(painter: GeometricPatternPainter(color: QColors.softEmber, opacity: 0.035)),
            ),
          RepaintBoundary(child: CustomPaint(painter: _StarfieldPainter(_c, widget.density, widget.seed))),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// Soft layered hills/dunes silhouette for the bottom of night scenes.

// ---------------------------------------------------------------- avatars

/// A faceless hooded traveller — the companion's silhouette — used as an
/// avatar for learners. Ordinary characters must have blank faces (brief §8.4).
class TravelerAvatar extends StatelessWidget {
  const TravelerAvatar({super.key, required this.hue, this.size = 44, this.ring});
  factory TravelerAvatar.fromKey({Key? key, required String avatarKey, double size = 44, Color? ring}) => TravelerAvatar(
    key: key,
    size: size,
    ring: ring,
    hue: switch (avatarKey) {
      'traveler_01' => 0.12,
      'traveler_02' => 0.55,
      'traveler_04' => 0.75,
      'traveler_05' => 0.05,
      _ => 0.43,
    },
  );
  final double hue;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring != null ? Border.all(color: ring!, width: 2.5) : null,
      ),
      child: ClipOval(child: CustomPaint(painter: _AvatarPainter(hue))),
    );
  }
}

/// A small ember used as the "embers" (XP) glyph.
class EmberIcon extends StatelessWidget {
  const EmberIcon({super.key, this.size = 18, this.glow = false});
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) => FlameMark(size: size * 0.9, glow: glow ? 0.9 : 0, animate: false, color: QColors.emberGold);
}
