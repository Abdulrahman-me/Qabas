import 'dart:async';
// Ported from the read-only prototype; authored proportions and motion retained.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/motion/motion.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

/// Celebration particles in the brand's language: warm embers that rise and
/// fade, with a few soft four-point sparkles. No confetti, nothing loud.
class EmberBurst extends StatefulWidget {
  const EmberBurst({super.key, this.count = 36, this.play = true, this.duration = const Duration(milliseconds: 2600), this.loop = false});
  final int count;
  final bool play;
  final Duration duration;
  final bool loop;

  @override
  State<EmberBurst> createState() => _EmberBurstState();
}

class _EmberBurstState extends State<EmberBurst> with SingleTickerProviderStateMixin {
  bool _started = false;
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final List<_Particle> _ps = List.generate(widget.count, (i) => _Particle(math.Random(i * 31 + 7)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context) || !widget.play) {
      _c.stop();
    } else if (!_started) {
      _started = true;
      unawaited(widget.loop ? _c.repeat() : _c.forward(from: 0));
    }
  }

  @override
  void didUpdateWidget(EmberBurst old) {
    super.didUpdateWidget(old);
    if (!widget.play) _c.stop();
    if (widget.play && !old.play && !reduceMotionOf(context)) {
      _started = true;
      unawaited(widget.loop ? _c.repeat() : _c.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _BurstPainter(_c, _ps), size: Size.infinite),
      ),
    );
  }
}

class _Particle {
  _Particle(math.Random r)
    : x = r.nextDouble(),
      y0 = 0.55 + r.nextDouble() * 0.5,
      rise = 0.35 + r.nextDouble() * 0.55,
      drift = (r.nextDouble() - 0.5) * 0.18,
      size = 2 + r.nextDouble() * 4.5,
      delay = r.nextDouble() * 0.45,
      sparkle = r.nextDouble() < 0.22,
      phase = r.nextDouble() * math.pi * 2,
      warm = r.nextDouble();
  final double x, y0, rise, drift, size, delay, phase, warm;
  final bool sparkle;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.ps) : super(repaint: t);
  final Animation<double> t;
  final List<_Particle> ps;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      final local = ((t.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final e = Curves.easeOutCubic.transform(local);
      final x = (p.x + p.drift * e + math.sin(local * 6 + p.phase) * 0.012) * size.width;
      final y = (p.y0 - p.rise * e) * size.height;
      final a = math.sin(local * math.pi);
      final color = Color.lerp(const Color(0xFFFFE7A8), QColors.flameGold, p.warm)!;
      final c = Offset(x, y);
      if (p.sparkle) {
        _sparkle(canvas, c, p.size * 2.2 * (0.6 + 0.4 * a), color.withValues(alpha: a));
      } else {
        canvas.drawCircle(
          c,
          p.size * 2.6,
          Paint()..shader = ui.Gradient.radial(c, p.size * 2.6, [color.withValues(alpha: 0.35 * a), color.withValues(alpha: 0)]),
        );
        canvas.drawCircle(c, p.size * 0.6, Paint()..color = color.withValues(alpha: a));
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.28;
      final pt = c + Offset(math.cos(ang), math.sin(ang)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BurstPainter old) => false;
}

/// Soft radial light behind a hero element.
class Glow extends StatelessWidget {
  const Glow({super.key, this.color = QColors.flameGold, this.size = 260, this.opacity = 0.45});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.3),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}
