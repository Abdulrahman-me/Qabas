// Ported from the read-only prototype; authored proportions and motion retained.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

part 'painters/unit_art_painters.dart';

enum UnitArt { starrySky, footprints, waterDrop, prayerRug, lantern, book, heart, compass, questions }

/// One simple icon per unit (brief §9): gold light on deep emerald.
class UnitArtIcon extends StatelessWidget {
  const UnitArtIcon({super.key, required this.art, this.size = 56, this.dim = false});
  factory UnitArtIcon.fromKey({Key? key, required String artKey, double size = 56, bool dim = false}) => UnitArtIcon(
    key: key,
    size: size,
    dim: dim,
    art: switch (artKey) {
      'unit_big_questions' || 'starry_sky' => UnitArt.starrySky,
      'unit_first_steps' || 'footprints' => UnitArt.footprints,
      'water_drop' => UnitArt.waterDrop,
      'prayer_rug' => UnitArt.prayerRug,
      'lantern' => UnitArt.lantern,
      'heart' => UnitArt.heart,
      'compass' => UnitArt.compass,
      'questions' => UnitArt.questions,
      _ => UnitArt.book,
    },
  );
  final UnitArt art;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _UnitArtPainter(art, dim)),
    );
  }
}
