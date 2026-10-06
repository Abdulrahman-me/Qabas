import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';

enum PredictionTileState { idle, selected, guess, dimmed }

/// Prediction subset of the prototype option kit; child accepts rich spans.
class PredictionTile extends StatefulWidget {
  const PredictionTile({super.key, required this.index, required this.state, required this.child, this.onTap});
  final int index;
  final PredictionTileState state;
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<PredictionTile> createState() => _PredictionTileState();
}

class _PredictionTileState extends State<PredictionTile> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final (face, edge, border, ink) = switch (widget.state) {
      PredictionTileState.idle => (QColors.surface, QColors.lineStrong, QColors.line, QColors.deepInk),
      PredictionTileState.selected => (QColors.emerald50, QColors.emerald400, QColors.emerald400, QColors.emerald700),
      PredictionTileState.guess => (QColors.gold50, QColors.flameGold, QColors.flameGold, QColors.gold800),
      PredictionTileState.dimmed => (QColors.surface, QColors.line, QColors.line, QColors.muted),
    };
    final pressed = _down && !context.reduceMotion ? QSizes.buttonDepth - 1 : 0.0;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.state == PredictionTileState.selected || widget.state == PredictionTileState.guess,
      onTap: widget.onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: context.reduceMotion ? Duration.zero : QLesson.tilePress,
          margin: EdgeInsets.only(top: pressed),
          padding: EdgeInsets.only(bottom: QSizes.buttonDepth - pressed),
          decoration: BoxDecoration(color: edge, borderRadius: BorderRadius.circular(QRadius.md + 1)),
          child: AnimatedContainer(
            duration: context.reduceMotion ? Duration.zero : QMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QLesson.optionPadding),
            decoration: BoxDecoration(
              color: face,
              borderRadius: BorderRadius.circular(QRadius.md),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: context.reduceMotion ? Duration.zero : QMotion.fast,
                  width: QSizes.optionBadge,
                  height: QSizes.optionBadge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(QLesson.optionBadgeRadius),
                    border: Border.all(color: border.withValues(alpha: widget.state == PredictionTileState.idle ? 1 : 0.6), width: 2),
                    color: widget.state == PredictionTileState.idle ? QColors.surface : face,
                  ),
                  child: Text(
                    context.n(widget.index + 1),
                    style: context.text.labelLarge?.copyWith(color: ink.withValues(alpha: 0.75), letterSpacing: 0),
                  ),
                ),
                const SizedBox(width: QSpace.sm),
                Expanded(
                  child: DefaultTextStyle(
                    style: context.text.titleSmall!.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      height: context.isArabic ? 1.55 : 1.35,
                    ),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
