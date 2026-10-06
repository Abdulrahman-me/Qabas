part of 'package:qabas/shared/presentation/brand/brand.dart';

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.t, required this.glow, required this.outer, required this.dim}) : super(repaint: t);

  final Animation<double> t;
  final double glow;
  final Color outer;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    // flame occupies a 0.72 x 1 box centred horizontally
    final fw = size.width * 0.72, fh = size.height;
    final box = Size(fw, fh);
    final dx = (size.width - fw) / 2;
    final sway = math.sin(v * math.pi * 2) * 0.025;
    final stretch = 1 + math.sin(v * math.pi * 4 + 1) * 0.02;

    if (glow > 0) {
      final center = Offset(size.width / 2, size.height * 0.66);
      final r = size.width * 1.0 * glow;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            r,
            [
              QColors.flameGold.withValues(alpha: 0.42 * dim),
              QColors.flameGold.withValues(alpha: 0.12 * dim),
              QColors.flameGold.withValues(alpha: 0),
            ],
            [0, 0.45, 1],
          ),
      );
    }

    canvas.save();
    canvas.translate(dx + fw / 2, fh);
    canvas.transform(
      Matrix4.identity().storage
        ..[4] =
            sway // skew x by y: the tip sways, the base stays put
        ..[5] = stretch,
    );
    canvas.translate(-fw / 2, -fh);
    final outerPath = flamePath(box);
    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, fh),
          [Color.lerp(outer, Colors.white, 0.22)!, outer, Color.lerp(outer, const Color(0xFFB8740F), 0.5)!],
          [0, 0.55, 1],
        ),
    );
    // inner core
    canvas.save();
    canvas.translate(fw * 0.5, fh * 0.97);
    canvas.scale(0.46, 0.5 + 0.02 * math.sin(v * math.pi * 6));
    canvas.translate(-fw * 0.5, -fh);
    canvas.drawPath(
      flamePath(box),
      Paint()..shader = ui.Gradient.linear(Offset(0, fh * 0.3), Offset(0, fh), [const Color(0xFFFFFDF6), QColors.softEmber]),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.glow != glow || old.outer != outer || old.dim != dim;
}

class GeometricPatternPainter extends CustomPainter {
  GeometricPatternPainter({this.color = Colors.white, this.opacity = 0.05, this.cell = 64});
  final Color color;
  final double opacity;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = cell * 0.34;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        canvas.drawPath(_star(c, r), paint);
        // connectors to neighbours make the lattice read as one weave
        canvas.drawLine(c + Offset(r, 0), c + Offset(cell - r, 0), paint);
        canvas.drawLine(c + Offset(0, r), c + Offset(0, cell - r), paint);
      }
    }
  }

  Path _star(Offset c, double r) {
    final p = Path();
    for (var k = 0; k < 2; k++) {
      final rot = k * math.pi / 4;
      for (var i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2 + math.pi / 4;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      p.close();
    }
    p.addOval(Rect.fromCircle(center: c, radius: r * 0.36));
    return p;
  }

  @override
  bool shouldRepaint(GeometricPatternPainter old) => old.color != color || old.opacity != opacity || old.cell != cell;
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter(this.t, this.density, this.seed) : super(repaint: t);
  final Animation<double> t;
  final double density;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final count = (size.width * size.height / 9000 * density).round();
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.5 + rnd.nextDouble() * 1.3;
      final phase = rnd.nextDouble() * math.pi * 2;
      final speed = 0.6 + rnd.nextDouble() * 1.4;
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t.value * math.pi * 2 * speed + phase));
      // fade stars toward the bottom: the night thins near the horizon
      final fade = (1 - y / size.height).clamp(0.15, 1.0);
      paint.color = (rnd.nextDouble() < 0.18 ? QColors.softEmber : Colors.white).withValues(alpha: 0.75 * tw * fade);
      canvas.drawCircle(Offset(x, y), r, paint);
      if (r > 1.55) {
        paint.color = paint.color.withValues(alpha: paint.color.a * 0.18);
        canvas.drawCircle(Offset(x, y), r * 3.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.density != density || old.seed != seed;
}

class HillsPainter extends CustomPainter {
  HillsPainter({this.colors = const [Color(0xFF0A4A44), Color(0xFF07403B), Color(0xFF05332F)]});
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (var i = 0; i < colors.length; i++) {
      final base = h * (0.35 + i * 0.2);
      final amp = h * (0.16 - i * 0.03);
      final path = Path()..moveTo(0, h);
      path.lineTo(0, base);
      const steps = 6;
      for (var k = 0; k < steps; k++) {
        final x0 = w * k / steps, x1 = w * (k + 1) / steps;
        final up = (k + i).isEven ? -amp : amp * 0.4;
        path.quadraticBezierTo((x0 + x1) / 2, base + up, x1, base + (k.isEven ? amp * 0.2 : -amp * 0.1));
      }
      path.lineTo(w, h);
      path.close();
      canvas.drawPath(path, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(HillsPainter old) => false;
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.hue);
  final double hue;

  static const _skins = [Color(0xFFE2B999), Color(0xFFC79474), Color(0xFFA06E50), Color(0xFF7B4F36)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cloak = HSLColor.fromAHSL(1, hue * 360, 0.42, 0.42).toColor();
    final bg = HSLColor.fromAHSL(1, hue * 360, 0.35, 0.9).toColor();
    final skin = _skins[(hue * 97).floor() % _skins.length];
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    // shoulders
    final body = Path()
      ..moveTo(s * 0.12, s * 1.05)
      ..quadraticBezierTo(s * 0.16, s * 0.7, s * 0.5, s * 0.68)
      ..quadraticBezierTo(s * 0.84, s * 0.7, s * 0.88, s * 1.05)
      ..close();
    canvas.drawPath(body, Paint()..color = cloak);
    // scarf
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * 0.5, s * 0.71), width: s * 0.42, height: s * 0.11), Radius.circular(s)),
      Paint()..color = QColors.flameGold,
    );
    // hood
    final hood = Path()
      ..moveTo(s * 0.5, s * 0.14)
      ..cubicTo(s * 0.74, s * 0.16, s * 0.8, s * 0.36, s * 0.78, s * 0.5)
      ..cubicTo(s * 0.76, s * 0.66, s * 0.64, s * 0.7, s * 0.5, s * 0.7)
      ..cubicTo(s * 0.36, s * 0.7, s * 0.24, s * 0.66, s * 0.22, s * 0.5)
      ..cubicTo(s * 0.2, s * 0.34, s * 0.28, s * 0.2, s * 0.43, s * 0.12)
      ..quadraticBezierTo(s * 0.46, s * 0.12, s * 0.5, s * 0.14)
      ..close();
    canvas.drawPath(hood, Paint()..color = Color.lerp(cloak, Colors.black, 0.12)!);
    // blank face — no features, by design
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.5, s * 0.47), width: s * 0.36, height: s * 0.38),
      Paint()..color = Color.lerp(cloak, Colors.black, 0.45)!,
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.48), width: s * 0.29, height: s * 0.31), Paint()..color = skin);
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.hue != hue;
}
