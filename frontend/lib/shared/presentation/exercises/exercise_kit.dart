import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:qabas/shared/presentation/content/span_text.dart';

enum TileState { idle, selected, correct, wrong, dimmed, guess }

({Color face, Color edge, Color border, Color ink}) tileColors(TileState s) => switch (s) {
  TileState.idle => (face: QColors.surface, edge: QColors.lineStrong, border: QColors.line, ink: QColors.deepInk),
  TileState.selected => (face: QColors.emerald50, edge: QColors.emerald400, border: QColors.emerald400, ink: QColors.emerald700),
  TileState.correct => (face: QColors.correctSoft, edge: QColors.correct, border: QColors.correct, ink: QColors.correctEdge),
  TileState.wrong => (face: QColors.retrySoft, edge: QColors.retry, border: QColors.retry, ink: QColors.retryInk),
  TileState.dimmed => (face: QColors.surface, edge: QColors.line, border: QColors.line, ink: QColors.muted),
  TileState.guess => (face: QColors.gold50, edge: QColors.flameGold, border: QColors.flameGold, ink: QColors.gold800),
};

class Tile3D extends StatefulWidget {
  const Tile3D({
    super.key,
    required this.child,
    required this.state,
    this.onTap,
    this.depth = QSizes.buttonDepth,
    this.radius = QRadius.md,
    this.padding,
    this.borderColor,
  });
  final Widget child;
  final TileState state;
  final VoidCallback? onTap;
  final double depth, radius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  @override
  State<Tile3D> createState() => _Tile3DState();
}

class _Tile3DState extends State<Tile3D> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final c = tileColors(widget.state), pressed = _down && !context.reduceMotion ? (widget.depth - 1).clamp(0.0, double.infinity) : 0.0;
    void tap() {
      SensoryScope.of(context).select();
      widget.onTap?.call();
    }

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.state == TileState.selected,
      onTap: widget.onTap == null ? null : tap,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              tap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap == null ? null : tap,
          child: AnimatedContainer(
            duration: context.reduceMotion ? Duration.zero : QLesson.tilePress,
            margin: EdgeInsets.only(top: pressed),
            padding: EdgeInsets.only(bottom: widget.depth - pressed),
            decoration: BoxDecoration(color: c.edge, borderRadius: BorderRadius.circular(widget.radius + 1)),
            child: AnimatedContainer(
              duration: context.reduceMotion ? Duration.zero : QMotion.fast,
              padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QLesson.optionPadding),
              constraints: const BoxConstraints(minHeight: QSizes.tapTarget),
              decoration: BoxDecoration(
                color: c.face,
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: widget.borderColor ?? c.border, width: QExercise.border),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: c.ink),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OptionTile extends StatelessWidget {
  const OptionTile({super.key, required this.index, required this.spans, required this.state, this.onTap});
  final int index;
  final List<ContentSpan> spans;
  final TileState state;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = tileColors(state);
    return Tile3D(
      state: state,
      onTap: onTap,
      child: Row(
        children: [
          AnimatedContainer(
            duration: context.reduceMotion ? Duration.zero : QMotion.fast,
            width: QSizes.optionBadge,
            height: QSizes.optionBadge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(QLesson.optionBadgeRadius),
              border: Border.all(
                color: c.border.withValues(alpha: state == TileState.idle ? 1 : QExercise.secondaryAlpha),
                width: QExercise.border,
              ),
              color: state == TileState.idle ? QColors.surface : c.face,
            ),
            child: switch (state) {
              TileState.correct => const Icon(Icons.check_rounded, size: QExercise.smallIcon, color: QColors.correct),
              TileState.wrong => const Icon(Icons.close_rounded, size: QExercise.smallIcon, color: QColors.retry),
              _ => Text(
                context.n(index + 1),
                style: context.text.labelLarge?.copyWith(color: c.ink.withValues(alpha: QExercise.inkAlpha), letterSpacing: 0),
              ),
            },
          ),
          const SizedBox(width: QSpace.sm),
          Expanded(
            child: SpanText(
              spans,
              style: context.text.titleSmall?.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
                height: context.isArabic ? QExercise.optionArabicHeight : QExercise.optionLatinHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Token extends StatelessWidget {
  const Token({
    super.key,
    required this.spans,
    this.secondaryLabel,
    this.state = TileState.idle,
    this.ghost = false,
    this.onTap,
    this.dragData,
    this.compact = false,
  });
  final List<ContentSpan> spans;
  final String? secondaryLabel, dragData;
  final TileState state;
  final bool ghost, compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = tileColors(state);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpanText(
          spans,
          textAlign: TextAlign.center,
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: c.ink, height: QExercise.tokenHeight),
        ),
        if (secondaryLabel != null && !context.isArabic)
          Text(
            secondaryLabel!,
            textDirection: TextDirection.rtl,
            style: QBrandText.languageTitle(context.text.labelSmall!, arabic: true).copyWith(
              color: c.ink.withValues(alpha: QExercise.secondaryAlpha),
              fontSize: context.text.labelSmall?.fontSize,
            ),
          ),
      ],
    );
    final tile = Tile3D(
      state: state,
      depth: QExercise.depth,
      radius: QRadius.sm,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? QExercise.tokenCompactHorizontal : QExercise.tokenHorizontal,
        vertical: compact ? QExercise.tokenCompactVertical : QExercise.tokenVertical,
      ),
      onTap: onTap,
      child: body,
    );
    if (ghost) {
      return ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: QExercise.bankGhostAlpha,
            child: Padding(
              padding: const EdgeInsets.only(bottom: QExercise.depth),
              child: Container(
                constraints: const BoxConstraints(minHeight: QSizes.tapTarget),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? QExercise.tokenCompactHorizontal : QExercise.tokenHorizontal,
                  vertical: compact ? QExercise.tokenCompactVertical : QExercise.tokenVertical,
                ),
                decoration: BoxDecoration(
                  color: QColors.line.withValues(alpha: QExercise.secondaryAlpha),
                  borderRadius: BorderRadius.circular(QRadius.sm),
                  border: Border.all(color: Colors.transparent, width: QExercise.border),
                ),
                child: Opacity(opacity: 0, child: body),
              ),
            ),
          ),
        ),
      );
    }
    if (dragData == null) return tile;
    return Draggable<String>(
      data: dragData,
      feedback: BlocProvider.value(
        value: context.read<ContentBloc>(),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: QBreakpoints.phoneMax / 2),
            child: Transform.rotate(
              angle: context.reduceMotion ? 0 : QExercise.tokenRotation,
              child: Transform.scale(
                scale: context.reduceMotion ? 1 : QExercise.tokenDragScale,
                child: Token(spans: spans, secondaryLabel: secondaryLabel, state: TileState.selected),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Token(spans: spans, secondaryLabel: secondaryLabel, ghost: true, compact: compact),
      onDragStarted: () => SensoryScope.of(context).select(),
      child: tile,
    );
  }
}
