part of 'package:qabas/shared/presentation/brand/achievement_badge.dart';

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.tint, this.unlocked);
  final Color tint;
  final bool unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.72, h * 0.06, w * 0.9, h * 0.08, w * 0.98, h * 0.14)
      ..cubicTo(w, h * 0.5, w * 0.86, h * 0.8, w * 0.5, h)
      ..cubicTo(w * 0.14, h * 0.8, 0, h * 0.5, w * 0.02, h * 0.14)
      ..cubicTo(w * 0.1, h * 0.08, w * 0.28, h * 0.06, w * 0.5, 0)
      ..close();
    if (unlocked) {
      canvas.drawPath(path.shift(const Offset(0, 4)), Paint()..color = Color.lerp(tint, Colors.black, 0.45)!);
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          unlocked
              ? [Color.lerp(tint, QColors.nightEmerald, 0.35)!, QColors.nightEmerald]
              : [const Color(0xFFDCE4E1), const Color(0xFFC9D4D0)],
        ),
    );
    if (unlocked) {
      final c = Offset(w / 2, h * 0.46);
      canvas.drawCircle(
        c,
        w * 0.42,
        Paint()..shader = ui.Gradient.radial(c, w * 0.42, [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0)]),
      );
      // a few rays — light, not fire
      final ray = Paint()
        ..color = QColors.softEmber.withValues(alpha: 0.12)
        ..strokeWidth = 2;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * w * 0.22, c + Offset(math.cos(a), math.sin(a)) * w * 0.4, ray);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = unlocked ? QColors.flameGold : const Color(0xFFB9C5C1),
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.tint != tint || old.unlocked != unlocked;
}
