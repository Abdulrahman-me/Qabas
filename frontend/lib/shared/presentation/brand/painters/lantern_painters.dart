part of 'package:qabas/shared/presentation/brand/lantern.dart';

class _LanternPainter extends CustomPainter {
  _LanternPainter(this.color, this.lit);
  final Color color;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.085
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    // hanger
    canvas.drawArc(Rect.fromCenter(center: Offset(s * 0.5, s * 0.12), width: s * 0.24, height: s * 0.18), 3.14, 3.14, false, stroke);
    // cap
    canvas.drawLine(Offset(s * 0.34, s * 0.22), Offset(s * 0.66, s * 0.22), stroke);
    // body
    final body = Path()
      ..moveTo(s * 0.36, s * 0.24)
      ..lineTo(s * 0.64, s * 0.24)
      ..lineTo(s * 0.76, s * 0.55)
      ..lineTo(s * 0.64, s * 0.86)
      ..lineTo(s * 0.36, s * 0.86)
      ..lineTo(s * 0.24, s * 0.55)
      ..close();
    if (lit) {
      final c = Offset(s * 0.5, s * 0.56);
      canvas.drawCircle(
        c,
        s * 0.5,
        Paint()
          ..shader = ui.Gradient.radial(c, s * 0.5, [QColors.flameGold.withValues(alpha: 0.35), QColors.flameGold.withValues(alpha: 0)]),
      );
      canvas.drawPath(body, Paint()..color = color.withValues(alpha: 0.18));
    }
    canvas.drawPath(body, stroke);
    // the small flame inside
    final f = Path()
      ..moveTo(s * 0.5, s * 0.4)
      ..quadraticBezierTo(s * 0.6, s * 0.56, s * 0.5, s * 0.7)
      ..quadraticBezierTo(s * 0.4, s * 0.56, s * 0.5, s * 0.4);
    canvas.drawPath(f, Paint()..color = lit ? QColors.flameGold : color);
  }

  @override
  bool shouldRepaint(_LanternPainter old) => old.color != color || old.lit != lit;
}
