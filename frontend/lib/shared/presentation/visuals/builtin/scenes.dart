// Ported from the read-only prototype; authored proportions and motion retained.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/motion/motion.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

/// Base for gently animated illustrations. Scenes contain places and light
/// only — no people, no historical figures (brief §8).
abstract class _AnimatedScene extends StatefulWidget {
  const _AnimatedScene({super.key, this.period = const Duration(seconds: 6)});
  final Duration period;
  CustomPainter painter(Animation<double> t);

  @override
  State<_AnimatedScene> createState() => _AnimatedSceneState();
}

class _AnimatedSceneState extends State<_AnimatedScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _c.value = 0.3;
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
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: widget.painter(_c), size: Size.infinite),
  );
}

// ------------------------------------------------------------------ river

/// The river at the door (hadith 4968). [beat]: 0 establishing, 1 river,
/// 2 clean light, 3 five lights for the five prayers.
class RiverHouseScene extends _AnimatedScene {
  const RiverHouseScene({super.key, this.beat = 1}) : super(period: const Duration(seconds: 5));
  final int beat;

  @override
  CustomPainter painter(Animation<double> t) => _RiverPainter(t, beat);
}

class _RiverPainter extends CustomPainter {
  _RiverPainter(this.t, this.beat) : super(repaint: t);
  final Animation<double> t;
  final int beat;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final v = t.value;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(QRadius.lg)));

    // sky
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h * 0.7),
          [const Color(0xFFBFE2DA), const Color(0xFFE4F0E6), const Color(0xFFF7E7C6)],
          [0, 0.55, 1],
        ),
    );
    // sun
    final sun = Offset(w * 0.86, h * 0.17);
    canvas.drawCircle(sun, w * 0.2, Paint()..shader = ui.Gradient.radial(sun, w * 0.2, [const Color(0x66F6C453), const Color(0x00F6C453)]));
    canvas.drawCircle(sun, w * 0.045, Paint()..color = const Color(0xFFF7D27A));

    // distant hills
    final hills = Path()
      ..moveTo(0, h * 0.5)
      ..quadraticBezierTo(w * 0.2, h * 0.36, w * 0.42, h * 0.47)
      ..quadraticBezierTo(w * 0.7, h * 0.33, w, h * 0.46)
      ..lineTo(w, h * 0.7)
      ..lineTo(0, h * 0.7)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFFA9D1C3));

    // ground
    canvas.drawRect(Rect.fromLTWH(0, h * 0.66, w, h * 0.14), Paint()..color = const Color(0xFFE9D3A6));

    // house
    final house = Rect.fromLTWH(w * 0.35, h * 0.24, w * 0.57, h * 0.46);
    canvas.drawRRect(
      RRect.fromRectAndCorners(house, topLeft: const Radius.circular(6), topRight: const Radius.circular(6)),
      Paint()..shader = ui.Gradient.linear(house.topLeft, house.bottomRight, [const Color(0xFFF6E6C4), const Color(0xFFE6CC9A)]),
    );
    // parapet
    for (var i = 0; i < 6; i++) {
      final x = house.left + i * house.width / 5.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, house.top - h * 0.03, house.width / 11, h * 0.04), const Radius.circular(2)),
        Paint()..color = const Color(0xFFEBD5A8),
      );
    }
    canvas.drawRect(Rect.fromLTWH(house.left - 4, house.top - 3, house.width + 8, 6), Paint()..color = const Color(0xFFD9BC86));
    // door (arched)
    final door = Path()
      ..moveTo(w * 0.505, house.bottom)
      ..lineTo(w * 0.505, h * 0.47)
      ..quadraticBezierTo(w * 0.55, h * 0.36, w * 0.595, h * 0.47)
      ..lineTo(w * 0.595, house.bottom)
      ..close();
    canvas.drawPath(door, Paint()..color = QColors.emerald500);
    canvas.drawCircle(Offset(w * 0.582, h * 0.58), w * 0.008, Paint()..color = QColors.flameGold);
    // windows with warm light
    for (final cx in [w * 0.43, w * 0.8]) {
      final win = Path()
        ..moveTo(cx - w * 0.04, h * 0.44)
        ..lineTo(cx - w * 0.04, h * 0.36)
        ..quadraticBezierTo(cx, h * 0.28, cx + w * 0.04, h * 0.36)
        ..lineTo(cx + w * 0.04, h * 0.44)
        ..close();
      canvas.drawPath(win, Paint()..color = const Color(0xFFF3C556));
      canvas.drawLine(
        Offset(cx, h * 0.31),
        Offset(cx, h * 0.44),
        Paint()
          ..color = const Color(0xFFC99A3F)
          ..strokeWidth = 2,
      );
    }
    // step down to the river
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.49, house.bottom, w * 0.12, h * 0.05), const Radius.circular(3)),
      Paint()..color = const Color(0xFFCDB07C),
    );

    // palm
    final trunk = Path()
      ..moveTo(w * 0.13, h * 0.74)
      ..quadraticBezierTo(w * 0.12, h * 0.48, w * 0.17, h * 0.27);
    canvas.drawPath(
      trunk,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF8A6243),
    );
    final crown = Offset(w * 0.17, h * 0.27);
    final sway = math.sin(v * math.pi * 2) * 0.05;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + (i - 2.5) * 0.62 + sway;
      final tip = crown + Offset(math.cos(a), math.sin(a) * 0.62 + 0.42) * w * 0.13;
      final ctrl = crown + Offset(math.cos(a) * 0.6, math.sin(a) * 0.6 - 0.1) * w * 0.13;
      final frond = Path()
        ..moveTo(crown.dx, crown.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy - 8, tip.dx, tip.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy + 4, crown.dx, crown.dy);
      canvas.drawPath(frond, Paint()..color = i.isEven ? const Color(0xFF2F7A5A) : const Color(0xFF3E9168));
    }

    // river
    final river = Rect.fromLTWH(0, h * 0.78, w, h * 0.22);
    canvas.drawRect(
      river,
      Paint()..shader = ui.Gradient.linear(river.topCenter, river.bottomCenter, [const Color(0xFF6CC0B8), const Color(0xFF2E8C88)]),
    );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.775, w, 3), Paint()..color = const Color(0xFFD7EFEA));
    final streak = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 9; i++) {
      final y = h * (0.82 + (i % 3) * 0.055);
      final x = ((i * 0.37 + v * (0.6 + (i % 3) * 0.25)) % 1.2 - 0.1) * w;
      canvas.drawLine(Offset(x, y), Offset(x + w * (0.05 + (i % 2) * 0.03), y), streak);
    }

    if (beat >= 2) {
      // clean light: soft sparkles over the water
      for (var i = 0; i < 7; i++) {
        final p = Offset(w * (0.12 + i * 0.13), h * (0.8 + (i.isEven ? 0.04 : 0.1)));
        final a = 0.5 + 0.5 * math.sin(v * math.pi * 4 + i);
        _sparkle(canvas, p, 5 + 3 * a, Colors.white.withValues(alpha: 0.5 + 0.5 * a));
      }
    }
    if (beat >= 3) {
      // five lights rise in an arc above the house: the five prayers
      for (var i = 0; i < 5; i++) {
        final ang = math.pi * (0.95 - i * 0.225);
        final p = Offset(w * 0.6 + math.cos(ang) * w * 0.3, h * 0.36 - math.sin(ang) * h * 0.26);
        final pulse = 0.85 + 0.15 * math.sin(v * math.pi * 2 + i);
        canvas.drawCircle(
          p,
          16 * pulse,
          Paint()..shader = ui.Gradient.radial(p, 16 * pulse, [const Color(0x99F6C453), const Color(0x00F6C453)]),
        );
        canvas.drawCircle(p, 4.5, Paint()..color = const Color(0xFFFFF1C9));
      }
    }
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.3;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RiverPainter old) => old.beat != beat;
}

// ------------------------------------------------------------------ day arc

/// Sky colours for the five prayer moments: first light, midday,
/// afternoon, sunset, night.
const phaseSkies = [
  [Color(0xFF34506F), Color(0xFFF0B27E)],
  [Color(0xFF7EC6E0), Color(0xFFDDF1F5)],
  [Color(0xFF97C7DA), Color(0xFFF4E3BF)],
  [Color(0xFFD9805A), Color(0xFFF5C68A)],
  [Color(0xFF0C2738), Color(0xFF173F52)],
];

/// The sun's path through the day with the five prayer moments.
/// [highlight] lights moments up to that index (−1 for none).
class DayArcScene extends _AnimatedScene {
  const DayArcScene({super.key, this.highlight = 4}) : super(period: const Duration(seconds: 8));
  final int highlight;

  @override
  CustomPainter painter(Animation<double> t) => _DayArcPainter(t, highlight);
}

/// Positions (fraction of width/height) of the five moments on the arc.
Offset dayArcPoint(int i, Size s) {
  const angles = [0.98, 0.52, 0.3, 0.02, -0.12];
  final a = math.pi * angles[i];
  final cx = s.width / 2, cy = s.height * 0.78, rx = s.width * 0.4, ry = s.height * 0.6;
  return Offset(cx - math.cos(a) * rx, cy - math.sin(a) * ry);
}

class _DayArcPainter extends CustomPainter {
  _DayArcPainter(this.t, this.highlight) : super(repaint: t);
  final Animation<double> t;
  final int highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(QRadius.lg)));
    final phase = highlight.clamp(0, 4);
    final sky = phaseSkies[phase];
    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [sky[0], sky[1]]));
    if (phase == 4 || phase == 0) {
      final rnd = math.Random(3);
      for (var i = 0; i < 30; i++) {
        final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.6);
        canvas.drawCircle(
          p,
          rnd.nextDouble() * 1.3 + 0.4,
          Paint()..color = Colors.white.withValues(alpha: (phase == 4 ? 0.8 : 0.35) * (0.4 + 0.6 * math.sin(t.value * 6 + i).abs())),
        );
      }
    }
    // the arc
    final arc = Path();
    for (var k = 0; k <= 60; k++) {
      final a = math.pi * (1.02 - k / 60 * 1.16);
      final p = Offset(w / 2 - math.cos(a) * w * 0.4, h * 0.78 - math.sin(a) * h * 0.6);
      k == 0 ? arc.moveTo(p.dx, p.dy) : arc.lineTo(p.dx, p.dy);
    }
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.6);
    for (final m in arc.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 3.5), dash);
      }
    }
    // horizon & ground
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.78, w, h * 0.22),
      Paint()..color = Color.lerp(const Color(0xFF2E6B5F), Colors.black, phase == 4 ? 0.45 : 0.0)!,
    );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, 2), Paint()..color = Colors.white.withValues(alpha: 0.35));

    for (var i = 0; i < 5; i++) {
      final p = dayArcPoint(i, size);
      final lit = i <= highlight;
      final active = i == highlight;
      final color = i == 4 ? const Color(0xFFF6E3B4) : (i == 3 ? const Color(0xFFF29B5E) : const Color(0xFFF7C948));
      if (active) {
        final pulse = 1 + 0.12 * math.sin(t.value * math.pi * 6);
        canvas.drawCircle(
          p,
          26 * pulse,
          Paint()..shader = ui.Gradient.radial(p, 26 * pulse, [color.withValues(alpha: 0.6), color.withValues(alpha: 0)]),
        );
      }
      canvas.drawCircle(p, lit ? 9 : 6, Paint()..color = lit ? color : Colors.white.withValues(alpha: 0.35));
      canvas.drawCircle(
        p,
        lit ? 9 : 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: lit ? 0.9 : 0.4),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DayArcPainter old) => old.highlight != highlight;
}

/// A tiny sky for one prayer moment (used in timeline slots).
class PhaseIcon extends StatelessWidget {
  const PhaseIcon({super.key, required this.phase, this.size = 40});
  final int phase;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PhasePainter(phase)),
  );
}

class _PhasePainter extends CustomPainter {
  _PhasePainter(this.phase);
  final int phase;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.3));
    canvas.save();
    canvas.clipRRect(r);
    final sky = phaseSkies[phase];
    canvas.drawRect(Offset.zero & size, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s), [sky[0], sky[1]]));
    const sunY = [0.82, 0.24, 0.4, 0.7, -1.0];
    const sunX = [0.3, 0.5, 0.68, 0.72, 0.5];
    if (phase == 4) {
      for (final p in [const Offset(0.3, 0.3), const Offset(0.66, 0.22), const Offset(0.5, 0.5), const Offset(0.78, 0.55)]) {
        canvas.drawCircle(Offset(p.dx * s, p.dy * s), s * 0.03, Paint()..color = const Color(0xFFF6E3B4));
      }
    } else {
      final c = Offset(sunX[phase] * s, sunY[phase] * s);
      final col = phase == 3 ? const Color(0xFFF29B5E) : const Color(0xFFF7C948);
      canvas.drawCircle(
        c,
        s * 0.3,
        Paint()..shader = ui.Gradient.radial(c, s * 0.3, [col.withValues(alpha: 0.6), col.withValues(alpha: 0)]),
      );
      canvas.drawCircle(c, s * 0.12, Paint()..color = col);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, s * 0.78, s, s * 0.22),
      Paint()..color = const Color(0xFF2E6B5F).withValues(alpha: phase == 4 ? 0.5 : 0.9),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PhasePainter old) => old.phase != phase;
}

// ------------------------------------------------------------------ pillars

/// "Islam is built upon five" — a building on five columns, with the
/// [highlight]ed column glowing. Architecture only, no religious figures,
/// and deliberately not a mosque silhouette.
class PillarsScene extends _AnimatedScene {
  const PillarsScene({super.key, this.highlight = 1}) : super(period: const Duration(seconds: 4));
  final int highlight;

  @override
  CustomPainter painter(Animation<double> t) => _PillarsPainter(t, highlight);
}

class _PillarsPainter extends CustomPainter {
  _PillarsPainter(this.t, this.highlight) : super(repaint: t);
  final Animation<double> t;
  final int highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(QRadius.lg)));
    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [QColors.night800, QColors.nightEmerald]));
    final pat = Paint()
      ..style = PaintingStyle.stroke
      ..color = QColors.softEmber.withValues(alpha: 0.05);
    for (double x = 0; x < w; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), pat);
    }
    final left = w * 0.14, right = w * 0.86, top = h * 0.26, base = h * 0.8;
    // roof
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(left - 10, top - h * 0.1, right + 10, top), const Radius.circular(6)),
      Paint()..color = QColors.softEmber.withValues(alpha: 0.9),
    );
    canvas.drawRect(Rect.fromLTRB(left - 2, top, right + 2, top + 6), Paint()..color = QColors.softEmber.withValues(alpha: 0.6));
    // base steps
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(left - 16, base, right + 16, base + h * 0.06), const Radius.circular(4)),
      Paint()..color = QColors.softEmber.withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(left - 28, base + h * 0.06, right + 28, base + h * 0.12), const Radius.circular(4)),
      Paint()..color = QColors.softEmber.withValues(alpha: 0.55),
    );
    final colW = (right - left) / 9;
    for (var i = 0; i < 5; i++) {
      final x = left + colW * (i * 2);
      final r = Rect.fromLTRB(x, top + 6, x + colW, base);
      final lit = i == highlight;
      if (lit) {
        final c = r.center;
        final pulse = 1 + 0.08 * math.sin(t.value * math.pi * 2);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: colW * 4 * pulse, height: r.height * 1.3 * pulse),
          Paint()
            ..shader = ui.Gradient.radial(c, colW * 2.4, [
              QColors.flameGold.withValues(alpha: 0.55),
              QColors.flameGold.withValues(alpha: 0),
            ]),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()..color = lit ? QColors.flameGold : (i == 0 ? QColors.softEmber : QColors.softEmber.withValues(alpha: 0.72)),
      );
      for (var f = 1; f < 3; f++) {
        canvas.drawLine(
          Offset(x + colW * f / 3, top + 12),
          Offset(x + colW * f / 3, base - 6),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.08)
            ..strokeWidth = 1.2,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PillarsPainter old) => old.highlight != highlight;
}

// ------------------------------------------------------------------ workplace

/// The hook scene: a calm office at midday. A wall clock just past noon hints
/// at Dhuhr. The colleague is never drawn — the story is told around them.
class WorkplaceScene extends _AnimatedScene {
  const WorkplaceScene({super.key}) : super(period: const Duration(seconds: 60));

  @override
  CustomPainter painter(Animation<double> t) => _WorkplacePainter(t);
}

class _WorkplacePainter extends CustomPainter {
  _WorkplacePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(QRadius.lg)));
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE6F1EC));
    // window with a city at midday
    final win = Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.46, h * 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(win.inflate(6), const Radius.circular(10)), Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(win, const Radius.circular(6)));
    canvas.drawRect(
      win,
      Paint()..shader = ui.Gradient.linear(win.topCenter, win.bottomCenter, [const Color(0xFF9ED3E6), const Color(0xFFE2F2F3)]),
    );
    final sun = Offset(win.left + win.width * 0.62, win.top + win.height * 0.2);
    canvas.drawCircle(
      sun,
      win.width * 0.22,
      Paint()..shader = ui.Gradient.radial(sun, win.width * 0.22, [const Color(0x99FFE08A), const Color(0x00FFE08A)]),
    );
    canvas.drawCircle(sun, win.width * 0.06, Paint()..color = const Color(0xFFFFDC7A));
    final rnd = math.Random(5);
    var x = win.left;
    while (x < win.right) {
      final bw = win.width * (0.08 + rnd.nextDouble() * 0.1);
      final bh = win.height * (0.25 + rnd.nextDouble() * 0.4);
      canvas.drawRect(Rect.fromLTWH(x, win.bottom - bh, bw - 2, bh), Paint()..color = const Color(0xFF7FAFB0).withValues(alpha: 0.75));
      x += bw;
    }
    canvas.restore();
    canvas.drawLine(
      Offset(win.center.dx, win.top),
      Offset(win.center.dx, win.bottom),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5,
    );

    // wall clock just after midday
    final cc = Offset(w * 0.78, h * 0.28);
    final cr = w * 0.11;
    canvas.drawCircle(cc, cr + 4, Paint()..color = QColors.emerald500);
    canvas.drawCircle(cc, cr, Paint()..color = Colors.white);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(
        cc + Offset(math.sin(a), -math.cos(a)) * cr * 0.8,
        cc + Offset(math.sin(a), -math.cos(a)) * cr * 0.92,
        Paint()
          ..color = QColors.slate
          ..strokeWidth = i % 3 == 0 ? 2.4 : 1.2,
      );
    }
    void hand(double turns, double len, double width, Color c) {
      final a = turns * math.pi * 2;
      canvas.drawLine(
        cc,
        cc + Offset(math.sin(a), -math.cos(a)) * len,
        Paint()
          ..color = c
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand((12 + 10 / 60) / 12, cr * 0.5, 3.4, QColors.deepInk);
    hand(10 / 60, cr * 0.75, 2.4, QColors.deepInk);
    hand(t.value, cr * 0.82, 1.2, QColors.flameGold);
    canvas.drawCircle(cc, 3, Paint()..color = QColors.flameGold);

    // desk
    final desk = Rect.fromLTWH(0, h * 0.72, w, h * 0.06);
    canvas.drawRect(desk, Paint()..color = const Color(0xFFC9A57A));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), Paint()..color = const Color(0xFFD9E7E2));
    // laptop
    final lap = Rect.fromLTWH(w * 0.12, h * 0.52, w * 0.3, h * 0.2);
    canvas.drawRRect(RRect.fromRectAndRadius(lap, const Radius.circular(6)), Paint()..color = const Color(0xFF3B4A5E));
    canvas.drawRRect(RRect.fromRectAndRadius(lap.deflate(5), const Radius.circular(3)), Paint()..color = const Color(0xFFBFE0E6));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(lap.left - 10, lap.bottom - 2, lap.width + 20, 7), const Radius.circular(3)),
      Paint()..color = const Color(0xFF55657A),
    );
    // mug with steam
    final mug = Rect.fromLTWH(w * 0.56, h * 0.6, w * 0.08, h * 0.12);
    canvas.drawRRect(RRect.fromRectAndRadius(mug, const Radius.circular(5)), Paint()..color = QColors.flameGold);
    canvas.drawArc(
      Rect.fromLTWH(mug.right - 6, mug.top + 6, 16, 18),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = QColors.flameGold,
    );
    for (var i = 0; i < 2; i++) {
      final sx = mug.left + mug.width * (0.35 + i * 0.3);
      final ph = t.value * math.pi * 20 + i;
      final steam = Path()..moveTo(sx, mug.top - 4);
      steam.cubicTo(sx - 6 + math.sin(ph) * 2, mug.top - 14, sx + 6, mug.top - 22, sx + math.sin(ph) * 3, mug.top - 32);
      canvas.drawPath(
        steam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.8),
      );
    }
    // plant
    final pot = Rect.fromLTWH(w * 0.78, h * 0.6, w * 0.1, h * 0.12);
    canvas.drawRRect(RRect.fromRectAndRadius(pot, const Radius.circular(4)), Paint()..color = QColors.emerald500);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + (i - 2) * 0.42;
      final base = Offset(pot.center.dx, pot.top);
      final tip = base + Offset(math.cos(a), math.sin(a)) * w * 0.09;
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = const Color(0xFF3E9168)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WorkplacePainter old) => false;
}
