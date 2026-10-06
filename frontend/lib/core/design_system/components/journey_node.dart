// Ported from journey_widgets.dart; the authored node face and motion are retained.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';

enum QNodeStatus { done, current, available, locked }

enum QNodeKind { lesson, story, practice, checkpoint }

@immutable
final class QJourneyNodeData {
  const QJourneyNodeData({required this.id, required this.title, required this.kind, required this.minutes, required this.embers});
  final String id, title;
  final QNodeKind kind;
  final int minutes, embers;
}

class QJourneyNode extends StatefulWidget {
  const QJourneyNode({
    super.key,
    required this.node,
    required this.status,
    required this.selected,
    required this.onTap,
    required this.onDismiss,
    required this.lessonNumber,
    required this.lessonCount,
    required this.onOpen,
    this.actionLabel,
    this.onSecondaryOpen,
    this.secondaryLabel,
  });

  final QJourneyNodeData node;
  final QNodeStatus status;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final int lessonNumber;
  final int lessonCount;
  final VoidCallback onOpen;
  final String? actionLabel, secondaryLabel;
  final VoidCallback? onSecondaryOpen;

  @override
  State<QJourneyNode> createState() => _QJourneyNodeState();
}

class _QJourneyNodeState extends State<QJourneyNode> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  bool _down = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.selected) _portal.show();
    });
  }

  @override
  void didUpdateWidget(QJourneyNode old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      // the overlay can't change mid-build; sync right after this frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.selected && !_portal.isShowing) {
          _portal.show();
        } else if (!widget.selected && _portal.isShowing) {
          _portal.hide();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.node.kind == QNodeKind.checkpoint;
    final size = big ? QJourney.checkpointSize : QJourney.nodeSize;
    final st = widget.status;
    final (Color face, Color edge) = switch (st) {
      QNodeStatus.done => (QColors.flameGold, QColors.gold700),
      QNodeStatus.current || QNodeStatus.available => (QColors.emerald400, QColors.emerald700),
      QNodeStatus.locked => (QColors.night700, QColors.night950),
    };
    final s = context.l10n;
    final label = s.journeyNodeSemantics(widget.node.title, switch (st) {
      QNodeStatus.done => s.journeyDoneLabel,
      QNodeStatus.current => s.journeyStartHere,
      QNodeStatus.available => s.journeyAvailable,
      QNodeStatus.locked => s.journeyLockedTitle,
    });

    final Widget circle = SizedBox(
      width: size,
      height: size + 8,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          if (st == QNodeStatus.current)
            Positioned(
              top: -8,
              left: -8,
              child: Breathe(amount: 0.08, child: _Halo(size: size + 16)),
            ),
          Positioned(
            top: 8,
            child: Container(
              width: size,
              height: size * 0.92,
              decoration: BoxDecoration(color: edge, borderRadius: BorderRadius.all(Radius.elliptical(size / 2, size * 0.46))),
            ),
          ),
          AnimatedPositioned(
            duration: context.reduceMotion ? Duration.zero : QJourney.nodePress,
            top: _down ? 7 : 0,
            child: Container(
              width: size,
              height: size * 0.92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(size / 2, size * 0.46)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(face, Colors.white, st == QNodeStatus.locked ? 0.05 : 0.18)!, face],
                ),
                border: st == QNodeStatus.locked ? Border.all(color: QColors.nightLine, width: 1.5) : null,
              ),
              child: Center(
                child: QJourneyNodeGlyph(node: widget.node, status: st, size: size),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      onTap: widget.onTap,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _portal,
              overlayChildBuilder: (ctx) => _Popover(
                link: _link,
                node: widget.node,
                status: st,
                anchorContext: context,
                number: widget.lessonNumber,
                count: widget.lessonCount,
                onDismiss: widget.onDismiss,
                onOpen: widget.onOpen,
                actionLabel: widget.actionLabel,
                onSecondaryOpen: widget.onSecondaryOpen,
                secondaryLabel: widget.secondaryLabel,
              ),
              child: TapRegion(
                groupId: widget.node.id,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _down = true),
                  onTapCancel: () => setState(() => _down = false),
                  onTapUp: (_) => setState(() => _down = false),
                  onTap: widget.onTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      circle,
                      if (st == QNodeStatus.current && !widget.selected)
                        Positioned(top: -46, child: _StartBubble(text: s.journeyStartHere.toUpperCase())),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: QColors.flameGold.withValues(alpha: 0.75), width: 4),
        boxShadow: QShadows.glow(QColors.flameGold, strength: 0.6),
      ),
    );
  }
}

class QJourneyNodeGlyph extends StatelessWidget {
  const QJourneyNodeGlyph({super.key, required this.node, required this.status, required this.size});
  final QJourneyNodeData node;
  final QNodeStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final locked = status == QNodeStatus.locked;
    final done = status == QNodeStatus.done;
    final color = locked ? QColors.softEmber.withValues(alpha: 0.35) : (done ? QColors.deepInk.withValues(alpha: 0.82) : Colors.white);
    final iconSize = size * 0.42;
    switch (node.kind) {
      case QNodeKind.lesson:
        if (done) return Icon(Icons.check_rounded, color: color, size: iconSize * 1.05);
        return FlameMark(
          size: iconSize * 0.9,
          glow: locked ? 0 : 0.7,
          animate: !locked,
          color: locked ? QJourney.lockedFlame : QColors.flameGold,
        );
      case QNodeKind.story:
        return Icon(Icons.auto_stories_rounded, color: color, size: iconSize);
      case QNodeKind.practice:
        return Icon(Icons.replay_rounded, color: color, size: iconSize);
      case QNodeKind.checkpoint:
        return LanternGlyph(color: color, lit: !locked, size: iconSize * 1.1);
    }
  }
}

class _StartBubble extends StatefulWidget {
  const _StartBubble({required this.text});
  final String text;

  @override
  State<_StartBubble> createState() => _StartBubbleState();
}

class _StartBubbleState extends State<_StartBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: QJourney.bubbleMotion)..repeat(reverse: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QColors.line, width: 2),
          ),
          child: Text(widget.text, style: context.text.labelLarge?.copyWith(color: QColors.emerald500, letterSpacing: 1)),
        ),
        CustomPaint(size: const Size(16, 8), painter: _ArrowPainter(Colors.white, down: true)),
      ],
    );
    if (context.reduceMotion) return bubble;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(offset: Offset(0, -4 * Curves.easeInOut.transform(_c.value)), child: child),
      child: bubble,
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color, {this.down = false});
  final Color color;
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (down) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    } else {
      p
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color || old.down != down;
}

// --------------------------------------------------------------------- popover

class _Popover extends StatelessWidget {
  const _Popover({
    required this.link,
    required this.node,
    required this.status,
    required this.anchorContext,
    required this.number,
    required this.count,
    required this.onDismiss,
    required this.onOpen,
    this.actionLabel,
    this.onSecondaryOpen,
    this.secondaryLabel,
  });

  final LayerLink link;
  final QJourneyNodeData node;
  final QNodeStatus status;
  final BuildContext anchorContext;
  final int number;
  final int count;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;
  final String? actionLabel, secondaryLabel;
  final VoidCallback? onSecondaryOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final overlay =
        (Scrollable.maybeOf(anchorContext)?.context.findRenderObject() ?? Overlay.of(context).context.findRenderObject())! as RenderBox;
    final origin = overlay.localToGlobal(Offset.zero);
    final screen = overlay.size;
    final width = math.min(320.0, screen.width - 32);
    final box = anchorContext.findRenderObject() as RenderBox?;
    final anchor = box == null ? Rect.fromLTWH(origin.dx + screen.width / 2, origin.dy, 0, 0) : box.localToGlobal(Offset.zero) & box.size;
    final nodeX = anchor.center.dx;
    // centre the card on screen-ish, keep the arrow on the node
    final left = (nodeX - width / 2).clamp(origin.dx + 16.0, origin.dx + screen.width - width - 16);
    final arrowX = (nodeX - left).clamp(24.0, width - 24);
    final compact = screen.width < QJourney.compactBarWidth || MediaQuery.textScalerOf(context).scale(1) > 1.1;
    final top = origin.dy + MediaQuery.paddingOf(context).top + (compact ? QJourney.compactBarHeight : QJourney.barHeight);
    final below = math.max(48.0, origin.dy + screen.height - anchor.bottom - 22);
    final above = math.max(48.0, anchor.top - top - 22);
    final flipped = below < 220 * MediaQuery.textScalerOf(context).scale(1) && above > below;
    final maxHeight = flipped ? above : below;

    final (Color bg, Color ink, Color sub) = switch (status) {
      QNodeStatus.current || QNodeStatus.available => (QColors.emerald500, Colors.white, QColors.softEmber),
      QNodeStatus.done => (QColors.flameGold, QColors.deepInk, QColors.deepInk.withValues(alpha: 0.7)),
      QNodeStatus.locked => (QColors.night800, QColors.softEmber, QColors.softEmber.withValues(alpha: 0.6)),
    };
    final kindLabel = switch (node.kind) {
      QNodeKind.lesson => s.journeyLesson,
      QNodeKind.story => s.journeyStory,
      QNodeKind.practice => s.journeyPractice,
      QNodeKind.checkpoint => s.journeyCheckpoint,
    };

    final cta = QButton(
      key: ValueKey('node-start-${node.id}'),
      label:
          actionLabel ??
          (status == QNodeStatus.done
              ? s.journeyReviewLesson
              : s.journeyLessonAction(s.commonPlusEmbers(QNumbers.format(node.embers, context.isArabic ? 'ar' : 'en')))),
      tone: QButtonTone.light,
      onPressed: onOpen,
    );

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: link,
        targetAnchor: flipped ? Alignment.topCenter : Alignment.bottomCenter,
        followerAnchor: flipped ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(left - nodeX, flipped ? -6 : 6),
        child: TapRegion(
          groupId: node.id,
          onTapOutside: (_) => onDismiss(),
          child: Reveal(
            duration: QMotion.medium,
            offset: const Offset(0, -10),
            scale: 0.94,
            curve: QMotion.settle,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!flipped)
                    Padding(
                      padding: EdgeInsets.only(left: arrowX - 10),
                      child: CustomPaint(size: const Size(20, 10), painter: _ArrowPainter(bg)),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      key: ValueKey('popover-${node.id}'),
                      constraints: BoxConstraints(maxHeight: maxHeight - 10),
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(QSpace.md),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(QRadius.lg),
                            border: status == QNodeStatus.locked ? Border.all(color: QColors.nightLine, width: 1.5) : null,
                            boxShadow: QShadows.lifted,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(kindLabel.toUpperCase(), style: context.qText.eyebrow.copyWith(color: sub)),
                                  const Spacer(),
                                  Text(
                                    context.isArabic
                                        ? '${QNumbers.format(number, context.isArabic ? 'ar' : 'en')} / ${QNumbers.format(count, context.isArabic ? 'ar' : 'en')}'
                                        : '$number / $count',
                                    style: context.text.labelMedium?.copyWith(color: sub),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(node.title, style: context.text.titleLarge?.copyWith(color: ink)),
                              const SizedBox(height: 6),
                              if (node.kind != QNodeKind.checkpoint)
                                Wrap(
                                  spacing: QSpace.md,
                                  runSpacing: QSpace.xs,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule_rounded, size: 16, color: sub),
                                        const SizedBox(width: 4),
                                        Text(
                                          s.commonMinutesLong(
                                            QNumbers.prototypePluralCount(node.minutes),
                                            QNumbers.format(node.minutes, context.isArabic ? 'ar' : 'en'),
                                          ),
                                          style: context.text.labelMedium?.copyWith(color: sub),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const EmberIcon(size: 15),
                                        const SizedBox(width: 4),
                                        Text(
                                          s.commonPlusEmbers(QNumbers.format(node.embers, context.isArabic ? 'ar' : 'en')),
                                          style: context.text.labelMedium?.copyWith(color: sub),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              const SizedBox(height: QSpace.md),
                              cta,
                              if (onSecondaryOpen != null && secondaryLabel != null) ...[
                                const SizedBox(height: QSpace.xs),
                                QButton(label: secondaryLabel!, tone: QButtonTone.night, onPressed: onSecondaryOpen),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (flipped)
                    Padding(
                      padding: EdgeInsets.only(left: arrowX - 10),
                      child: CustomPaint(size: const Size(20, 10), painter: _ArrowPainter(bg, down: true)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
