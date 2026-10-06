// Ported from the read-only prototype; authored proportions and motion retained.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

part 'painters/lantern_painters.dart';

/// Raqeeb's identity: a small lantern — trust and light, not a robot (brief §9).
class LanternGlyph extends StatelessWidget {
  const LanternGlyph({super.key, required this.color, this.lit = false, this.size = 24});
  final Color color;
  final bool lit;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LanternPainter(color, lit)),
  );
}
