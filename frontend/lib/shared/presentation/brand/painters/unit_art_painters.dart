part of 'package:qabas/shared/presentation/brand/unit_art.dart';

class _UnitArtPainter extends CustomPainter {
  _UnitArtPainter(this.art, this.dim);
  final UnitArt art;
  final bool dim;

  Color get gold => dim ? const Color(0xFF8FA19C) : QColors.flameGold;
  Color get ember => dim ? const Color(0xFFC8D3D0) : QColors.softEmber;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.3));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, s),
          dim ? [const Color(0xFF3B5D58), const Color(0xFF2C4B47)] : [QColors.night700, QColors.nightEmerald],
        ),
    );
    if (!dim) {
      canvas.drawCircle(
        c,
        s * 0.42,
        Paint()..shader = ui.Gradient.radial(c, s * 0.42, [gold.withValues(alpha: 0.28), gold.withValues(alpha: 0)]),
      );
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = gold;
    final fill = Paint()..color = gold;
    final soft = Paint()..color = ember;

    switch (art) {
      case UnitArt.starrySky:
        _star(canvas, c + Offset(-s * 0.05, -s * 0.06), s * 0.17, fill);
        _star(canvas, c + Offset(s * 0.2, s * 0.14), s * 0.08, soft);
        _star(canvas, c + Offset(-s * 0.2, s * 0.18), s * 0.06, soft);
        _star(canvas, c + Offset(s * 0.18, -s * 0.22), s * 0.05, soft);
      case UnitArt.footprints:
        _foot(canvas, c + Offset(-s * 0.1, s * 0.12), s, -0.25, fill);
        _foot(canvas, c + Offset(s * 0.1, -s * 0.1), s, 0.15, soft);
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(c + Offset(-s * 0.26 + i * s * 0.05, s * 0.32 - i * s * 0.02), s * 0.015, soft);
        }
      case UnitArt.waterDrop:
        final drop = Path()
          ..moveTo(c.dx, c.dy - s * 0.28)
          ..cubicTo(c.dx + s * 0.06, c.dy - s * 0.14, c.dx + s * 0.2, c.dy - s * 0.02, c.dx + s * 0.2, c.dy + s * 0.1)
          ..arcToPoint(Offset(c.dx - s * 0.2, c.dy + s * 0.1), radius: Radius.circular(s * 0.2))
          ..cubicTo(c.dx - s * 0.2, c.dy - s * 0.02, c.dx - s * 0.06, c.dy - s * 0.14, c.dx, c.dy - s * 0.28)
          ..close();
        canvas.drawPath(drop, fill);
        canvas.drawArc(
          Rect.fromCircle(center: c + Offset(-s * 0.02, s * 0.1), radius: s * 0.12),
          math.pi * 0.6,
          math.pi * 0.5,
          false,
          stroke
            ..color = ember
            ..strokeWidth = s * 0.035,
        );
      case UnitArt.prayerRug:
        // a rug with a mihrab arch — pattern only, never a person
        final rug = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 0.42, height: s * 0.58), Radius.circular(s * 0.05));
        canvas.drawRRect(rug, fill);
        final arch = Path()
          ..moveTo(c.dx - s * 0.13, c.dy + s * 0.2)
          ..lineTo(c.dx - s * 0.13, c.dy - s * 0.06)
          ..quadraticBezierTo(c.dx - s * 0.13, c.dy - s * 0.2, c.dx, c.dy - s * 0.22)
          ..quadraticBezierTo(c.dx + s * 0.13, c.dy - s * 0.2, c.dx + s * 0.13, c.dy - s * 0.06)
          ..lineTo(c.dx + s * 0.13, c.dy + s * 0.2)
          ..close();
        canvas.drawPath(arch, Paint()..color = QColors.nightEmerald.withValues(alpha: dim ? 0.4 : 0.55));
        canvas.drawCircle(c + Offset(0, -s * 0.05), s * 0.028, soft);
        for (var i = -2; i <= 2; i++) {
          canvas.drawLine(
            Offset(c.dx + i * s * 0.07, c.dy + s * 0.29),
            Offset(c.dx + i * s * 0.07, c.dy + s * 0.34),
            stroke
              ..color = gold
              ..strokeWidth = s * 0.025,
          );
        }
      case UnitArt.lantern:
        canvas.drawLine(Offset(c.dx, c.dy - s * 0.32), Offset(c.dx, c.dy - s * 0.24), stroke);
        final body = Path()
          ..moveTo(c.dx - s * 0.09, c.dy - s * 0.2)
          ..lineTo(c.dx + s * 0.09, c.dy - s * 0.2)
          ..lineTo(c.dx + s * 0.16, c.dy + s * 0.04)
          ..lineTo(c.dx + s * 0.1, c.dy + s * 0.24)
          ..lineTo(c.dx - s * 0.1, c.dy + s * 0.24)
          ..lineTo(c.dx - s * 0.16, c.dy + s * 0.04)
          ..close();
        canvas.drawPath(body, fill);
        canvas.drawOval(Rect.fromCenter(center: c + Offset(0, s * 0.03), width: s * 0.1, height: s * 0.16), soft);
      case UnitArt.book:
        final left = Path()
          ..moveTo(c.dx, c.dy - s * 0.12)
          ..quadraticBezierTo(c.dx - s * 0.14, c.dy - s * 0.2, c.dx - s * 0.28, c.dy - s * 0.14)
          ..lineTo(c.dx - s * 0.28, c.dy + s * 0.16)
          ..quadraticBezierTo(c.dx - s * 0.14, c.dy + s * 0.1, c.dx, c.dy + s * 0.18)
          ..close();
        canvas.drawPath(left, fill);
        canvas.save();
        canvas.translate(c.dx * 2, 0);
        canvas.scale(-1, 1);
        canvas.drawPath(left, soft);
        canvas.restore();
        canvas.drawCircle(c + Offset(0, -s * 0.26), s * 0.04, soft);
      case UnitArt.heart:
        final h = Path()
          ..moveTo(c.dx, c.dy + s * 0.22)
          ..cubicTo(c.dx - s * 0.36, c.dy - s * 0.02, c.dx - s * 0.18, c.dy - s * 0.3, c.dx, c.dy - s * 0.12)
          ..cubicTo(c.dx + s * 0.18, c.dy - s * 0.3, c.dx + s * 0.36, c.dy - s * 0.02, c.dx, c.dy + s * 0.22)
          ..close();
        canvas.drawPath(h, fill);
        canvas.drawCircle(c + Offset(-s * 0.08, -s * 0.06), s * 0.035, soft);
      case UnitArt.compass:
        canvas.drawCircle(c, s * 0.26, stroke);
        final needle = Path()
          ..moveTo(c.dx, c.dy - s * 0.2)
          ..lineTo(c.dx + s * 0.06, c.dy)
          ..lineTo(c.dx, c.dy + s * 0.2)
          ..lineTo(c.dx - s * 0.06, c.dy)
          ..close();
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.6);
        canvas.translate(-c.dx, -c.dy);
        canvas.drawPath(needle, fill);
        canvas.drawCircle(c, s * 0.03, soft);
        canvas.restore();
      case UnitArt.questions:
        final b1 = RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.28, c.dy - s * 0.22, s * 0.34, s * 0.24), Radius.circular(s * 0.08));
        final b2 = RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - s * 0.04, c.dy - s * 0.02, s * 0.32, s * 0.24), Radius.circular(s * 0.08));
        canvas.drawRRect(b1, fill);
        canvas.drawRRect(b2, soft);
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(b2.left + s * 0.08 + i * s * 0.08, b2.center.dy), s * 0.022, Paint()..color = QColors.nightEmerald);
        }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.36;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  void _foot(Canvas canvas, Offset c, double s, double rot, Paint p) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.12, height: s * 0.2), p);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(-s * 0.045 + i * s * 0.03, -s * 0.13 - (i == 0 ? 0.01 * s : 0)), s * 0.018, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_UnitArtPainter old) => old.art != art || old.dim != dim;
}
