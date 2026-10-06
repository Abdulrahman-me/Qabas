import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';

class QJourneyHeader extends StatelessWidget {
  const QJourneyHeader({
    super.key,
    required this.pathLabel,
    required this.pathSemantics,
    required this.art,
    required this.streak,
    required this.embers,
    required this.streakSemantics,
    required this.embersSemantics,
    required this.learnedToday,
    required this.onPath,
    required this.onStreak,
    required this.onEmbers,
  });
  final String pathLabel, pathSemantics, streak, embers, streakSemantics, embersSemantics;
  final UnitArt art;
  final bool learnedToday;
  final VoidCallback onPath, onStreak, onEmbers;
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final compact = MediaQuery.sizeOf(context).width < QJourney.compactBarWidth || MediaQuery.textScalerOf(context).scale(1) > 1.1;
    final path = Pressable(
      key: const ValueKey('journey-path-switch'),
      onTap: onPath,
      semanticLabel: pathSemantics,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 12, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: QRadius.chip,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnitArtIcon(art: art, size: 30),
            const SizedBox(width: 8),
            Text(pathLabel, style: context.text.labelLarge?.copyWith(color: QColors.softEmber, letterSpacing: 0)),
            Icon(Icons.expand_more_rounded, color: QColors.softEmber.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
    final stats = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatChip(
          leading: StreakFlame(size: 19, lit: learnedToday),
          value: streak,
          semantic: streakSemantics,
          onTap: onStreak,
        ),
        const SizedBox(width: QSpace.xs),
        StatChip(leading: const EmberIcon(size: 19, glow: true), value: embers, semantic: embersSemantics, onTap: onEmbers),
      ],
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(
        height: top + (compact ? QJourney.compactBarHeight : QJourney.barHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.fromLTRB(QSpace.md, top + 8, QSpace.md, 8),
              decoration: BoxDecoration(
                color: QColors.night950.withValues(alpha: 0.72),
                border: Border(bottom: BorderSide(color: QColors.nightLine.withValues(alpha: 0.5))),
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        path,
                        const SizedBox(height: QSpace.xs),
                        Align(alignment: AlignmentDirectional.centerEnd, child: stats),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FittedBox(fit: BoxFit.scaleDown, child: path),
                          ),
                        ),
                        stats,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(_HeaderDelegate old) => old.height != height || old.child != child;
}
