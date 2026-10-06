// Ported from the read-only prototype; authored proportions and motion retained.
import 'package:flutter/material.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

enum QButtonTone { emerald, gold, correct, retry, light, outline, ghost, night }

class _Palette {
  const _Palette(this.face, this.edge, this.ink, {this.border});
  final Color face;
  final Color edge;
  final Color ink;
  final Color? border;
}

_Palette _palette(QButtonTone tone) => switch (tone) {
  QButtonTone.emerald => const _Palette(QColors.emerald500, QColors.emerald700, Colors.white),
  QButtonTone.gold => const _Palette(QColors.flameGold, QColors.gold700, QColors.deepInk),
  QButtonTone.correct => const _Palette(QColors.correct, QColors.correctEdge, Colors.white),
  QButtonTone.retry => const _Palette(QColors.retry, QColors.retryEdge, Colors.white),
  QButtonTone.light => const _Palette(Colors.white, QColors.lineStrong, QColors.deepInk, border: QColors.line),
  QButtonTone.outline => const _Palette(Colors.white, QColors.line, QColors.emerald500, border: QColors.line),
  QButtonTone.ghost => const _Palette(Colors.transparent, Colors.transparent, QColors.emerald500),
  QButtonTone.night => const _Palette(QColors.night800, QColors.night950, QColors.softEmber, border: QColors.nightLine),
};

/// The primary tactile button: a raised face over a darker edge that presses
/// down under the finger — satisfying, but calm in colour.
class QButton extends StatefulWidget {
  const QButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tone = QButtonTone.emerald,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.height = QSizes.buttonHeight,
    this.depth = QSizes.buttonDepth,
    this.silent = false,
    this.onDark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final QButtonTone tone;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final double height;
  final double depth;

  /// Skip the default tap sound (when the action plays its own).
  final bool silent;

  /// Use a night-toned disabled state on dark backgrounds.
  final bool onDark;

  @override
  State<QButton> createState() => _QButtonState();
}

class _QButtonState extends State<QButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  void _activate() {
    if (!widget.silent) SensoryScope.of(context).tap();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette(widget.tone);
    final face = _enabled ? p.face : (widget.onDark ? Colors.white.withValues(alpha: 0.08) : QColors.line);
    final edge = _enabled ? p.edge : QColors.lineStrong.withValues(alpha: 0.6);
    final ink = _enabled ? p.ink : (widget.onDark ? QColors.softEmber.withValues(alpha: 0.35) : QColors.muted);
    final flat = widget.tone == QButtonTone.ghost;
    final depth = flat || !_enabled ? 0.0 : widget.depth;
    final pressed = _down ? depth : 0.0;

    final label = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[Icon(widget.icon, color: ink, size: 21), const SizedBox(width: 8)],
        Flexible(
          // long labels shrink to fit rather than truncate
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              context.qText.isArabic ? widget.label : widget.label.toUpperCase(),
              maxLines: 1,
              style: context.text.labelLarge?.copyWith(color: ink, letterSpacing: context.qText.isArabic ? 0 : 0.9),
            ),
          ),
        ),
        if (widget.trailingIcon != null) ...[const SizedBox(width: 8), Icon(widget.trailingIcon, color: ink, size: 21)],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      onTap: _enabled ? _activate : null,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: _enabled ? (_) => _set(false) : null,
        onTap: _enabled ? _activate : null,
        child: SizedBox(
          height: widget.height + depth,
          width: widget.expand ? double.infinity : null,
          child: Stack(
            children: [
              if (depth > 0)
                Positioned.fill(
                  top: depth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: edge, borderRadius: QRadius.button),
                  ),
                ),
              AnimatedPositioned(
                duration: context.reduceMotion ? Duration.zero : QMotion.buttonPress,
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: pressed,
                height: widget.height,
                child: AnimatedContainer(
                  duration: context.reduceMotion ? Duration.zero : QMotion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: face,
                    borderRadius: QRadius.button,
                    border: p.border != null && _enabled ? Border.all(color: p.border!, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  child: label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic press feedback: scales down slightly and fires a selection tick.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96, this.haptic = true, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) SensoryScope.of(context).select();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: context.reduceMotion ? Duration.zero : QMotion.pressScale,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Round icon button used in headers (close, settings, back).
class QIconButton extends StatelessWidget {
  const QIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color = QColors.slate,
    this.background = Colors.transparent,
    this.size = QSizes.iconButton,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        semanticLabel: tooltip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: size * 0.56),
        ),
      ),
    );
  }
}
