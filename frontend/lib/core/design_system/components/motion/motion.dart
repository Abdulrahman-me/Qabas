import 'dart:async';
// Ported from the read-only prototype; authored proportions and motion retained.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

/// True when the learner (or the OS) asked for less motion.
bool reduceMotionOf(BuildContext context) => context.reduceMotion;

/// Fades and lifts its child into place after [delay]. Used for staggered
/// entrances so screens assemble calmly rather than popping in.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = QMotion.slow,
    this.offset = const Offset(0, 18),
    this.scale = 1.0,
    this.curve = QMotion.emphasizedDecel,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scale;
  final Curve curve;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: widget.curve);

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted && !reduceMotionOf(context)) unawaited(_c.forward());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - v),
            child: Transform.scale(scale: widget.scale + (1 - widget.scale) * v, child: child),
          ),
        );
      },
    );
  }
}

/// A gentle breathing scale, for things that invite a tap.
class Breathe extends StatefulWidget {
  const Breathe({super.key, required this.child, this.amount = 0.04, this.period = const Duration(milliseconds: 2400)});
  final Widget child;
  final double amount;
  final Duration period;

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.scale(scale: 1 + widget.amount * Curves.easeInOut.transform(_c.value), child: child),
    );
  }
}

/// Shakes horizontally when [trigger] changes — a soft "not quite".
class Nudge extends StatefulWidget {
  const Nudge({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<Nudge> createState() => _NudgeState();
}

class _NudgeState extends State<Nudge> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) _c.stop();
  }

  @override
  void didUpdateWidget(Nudge old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !reduceMotionOf(context)) unawaited(_c.forward(from: 0));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = _c.value;
        final dx = (1 - t) * 7 * math.sin(t * math.pi * 6);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
