import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/buttons.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';
import 'package:qabas/shared/presentation/brand/unit_art.dart';

enum QTone { light, night }

enum QEmptyArt { companion, unitArt, lantern }

// Presentation statuses only; the app's Failure mapping arrives in Phase 2.
enum QErrorKind { network, server, sources, rateLimited, notFound, forbidden, tooLarge, fileType, unexpected }

class DelayedLoading extends StatefulWidget {
  const DelayedLoading({super.key, required this.child, this.delay = QMotion.loadingDelay});
  final Widget child;
  final Duration delay;
  @override
  State<DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<DelayedLoading> {
  Timer? _timer;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _visible ? widget.child : const SizedBox.shrink();
}

class QLoadingView extends StatelessWidget {
  const QLoadingView({super.key, this.tone = QTone.light, this.label});
  final QTone tone;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: SingleChildScrollView(
        primary: false,
        child: Padding(
          padding: const EdgeInsets.all(QSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tone == QTone.night)
                  const FlameMark(size: QSpace.huge, glow: 1.2)
                else ...[
                  const FlameMark(size: QSpace.xxxl, glow: 0.3),
                  const SizedBox(height: QSpace.xl),
                  const _Skeleton(),
                ],
                const SizedBox(height: QSpace.md),
                _LoadingLabel(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      label ?? context.l10n.commonLoading,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: tone == QTone.night ? QColors.softEmber : QColors.slate),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return tone == QTone.night ? NightSky(child: content) : ColoredBox(color: QColors.morningMint, child: content);
  }
}

// Reserve the label's space from the first frame, avoiding a layout jump.
class _LoadingLabel extends StatefulWidget {
  const _LoadingLabel({required this.child});
  final Widget child;

  @override
  State<_LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<_LoadingLabel> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(QMotion.loadingLabelDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _visible ? 1 : 0,
    duration: context.reduceMotion ? Duration.zero : QMotion.normal,
    child: ExcludeSemantics(excluding: !_visible, child: widget.child),
  );
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: fraction,
    child: Container(
      height: QSpace.sm,
      decoration: const BoxDecoration(color: QColors.line, borderRadius: QRadius.chip),
    ),
  );
}

class _Skeleton extends StatefulWidget {
  const _Skeleton();
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: QMotion.skeletonPulse);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++)
          Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : QSpace.sm),
            child: Container(
              padding: const EdgeInsets.all(QSpace.md),
              decoration: BoxDecoration(
                color: QColors.surface,
                border: Border.all(color: QColors.line),
                borderRadius: BorderRadius.circular(QRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    width: QSpace.xxxl,
                    height: QSpace.xxxl,
                    decoration: BoxDecoration(color: QColors.emerald50, borderRadius: BorderRadius.circular(QRadius.sm)),
                  ),
                  const SizedBox(width: QSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(fraction: index == 1 ? 0.6 : 0.8),
                        const SizedBox(height: QSpace.xs),
                        const _SkeletonLine(fraction: 0.45),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class QInlineLoading extends StatelessWidget {
  const QInlineLoading({super.key, this.label, this.showFlame = true});
  final bool showFlame;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label ?? context.l10n.commonLoading,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFlame)
          const FlameMark(size: 22)
        else
          const SizedBox(
            width: QSpace.lg,
            height: QSpace.lg,
            child: CircularProgressIndicator(strokeWidth: 2, color: QColors.emerald500),
          ),
        if (label != null) ...[const SizedBox(width: QSpace.xs), Flexible(child: Text(label!, style: context.text.bodyMedium))],
      ],
    ),
  );
}

class QEmptyView extends StatelessWidget {
  const QEmptyView({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.art = QEmptyArt.companion,
    this.illustration,
    this.tone = QTone.light,
  });
  final String title;
  final String body;
  final (String, VoidCallback)? action;
  final QEmptyArt art;
  final Widget? illustration;
  final QTone tone;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      primary: false,
      child: Padding(
        padding: const EdgeInsets.all(QSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                switch (art) {
                  QEmptyArt.companion => const FlameMark(size: 56, glow: 0.6),
                  QEmptyArt.unitArt => const UnitArtIcon(art: UnitArt.book),
                  QEmptyArt.lantern => const LanternGlyph(color: QColors.emerald500, lit: true, size: 56),
                },
            const SizedBox(height: QSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall?.copyWith(color: tone == QTone.night ? QColors.softEmber : null),
            ),
            const SizedBox(height: QSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: tone == QTone.night ? QColors.softEmber.withValues(alpha: 0.75) : null),
            ),
            if (action != null) ...[const SizedBox(height: QSpace.xl), QButton(label: action!.$1, onPressed: action!.$2)],
          ],
        ),
      ),
    ),
  );
}

class QErrorView extends StatelessWidget {
  const QErrorView({
    super.key,
    this.kind = QErrorKind.network,
    required this.onRetry,
    this.tone = QTone.light,
    this.title,
    this.body,
    this.actionLabel,
    this.retryTime,
  });
  final QErrorKind kind;
  final VoidCallback onRetry;
  final QTone tone;
  final String? title;
  final String? body;
  final String? actionLabel;
  final String? retryTime;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final words = switch (kind) {
      QErrorKind.network => (l.errorNetworkTitle, l.errorNetworkBody, l.commonRetry),
      QErrorKind.server => (l.errorServerTitle, l.errorServerBody, l.commonRetry),
      QErrorKind.sources => (l.errorSourcesTitle, l.errorSourcesBody, l.commonRetry),
      QErrorKind.rateLimited => (
        l.errorRateLimitedTitle,
        retryTime == null ? l.errorGenericBody : l.errorRateLimitedBody(retryTime!),
        l.commonRetry,
      ),
      QErrorKind.notFound => (l.errorNotFoundTitle, l.errorNotFoundBody, l.commonBack),
      QErrorKind.forbidden => (l.errorForbiddenTitle, l.errorForbiddenBody, l.commonBack),
      QErrorKind.tooLarge => (l.errorTooLargeTitle, l.errorTooLargeBody, l.commonChooseAnother),
      QErrorKind.fileType => (l.errorFileTypeTitle, l.errorFileTypeBody, l.commonChooseAnother),
      QErrorKind.unexpected => (l.errorGenericTitle, l.errorGenericBody, l.commonRetry),
    };
    final content = Semantics(
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          primary: false,
          child: Padding(
            padding: const EdgeInsets.all(QSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: QColors.retrySoft, shape: BoxShape.circle),
                  child: Icon(kind == QErrorKind.network ? Icons.cloud_off_rounded : Icons.refresh_rounded, color: QColors.retryInk),
                ),
                const SizedBox(height: QSpace.md),
                Text(
                  title ?? words.$1,
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(color: tone == QTone.night ? QColors.softEmber : QColors.deepInk),
                ),
                const SizedBox(height: QSpace.sm),
                Text(
                  body ?? words.$2,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: tone == QTone.night ? QColors.softEmber : QColors.slate),
                ),
                const SizedBox(height: QSpace.xl),
                QButton(
                  label: actionLabel ?? words.$3,
                  onPressed: onRetry,
                  tone: tone == QTone.night ? QButtonTone.night : QButtonTone.light,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return tone == QTone.night ? NightSky(child: content) : content;
  }
}

class QInlineError extends StatelessWidget {
  const QInlineError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: QSpace.xs,
      children: [
        Text(message, style: context.text.bodySmall?.copyWith(color: QColors.retryInk)),
        if (onRetry != null) TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
      ],
    ),
  );
}

class QOfflineBanner extends StatelessWidget {
  const QOfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      color: QColors.surfaceSunk,
      padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QSpace.xs),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: QColors.slate, size: 18),
          const SizedBox(width: QSpace.xs),
          Expanded(child: Text(context.l10n.commonOfflineBody, style: context.text.bodySmall)),
        ],
      ),
    ),
  );
}

class QBlockingScreen extends StatelessWidget {
  const QBlockingScreen({super.key, required this.onUpdate});
  final VoidCallback onUpdate;
  @override
  Widget build(BuildContext context) => NightSky(
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          primary: false,
          child: Padding(
            padding: const EdgeInsets.all(QSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FlameMark(size: 72, glow: 1.2),
                const SizedBox(height: QSpace.xl),
                Text(
                  context.l10n.commonUpdateTitle,
                  style: context.qText.displaySmall.copyWith(color: QColors.softEmber),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: QSpace.md),
                Text(
                  context.l10n.commonUpdateBody,
                  style: context.text.bodyLarge?.copyWith(color: QColors.softEmber),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: QSpace.xl),
                QButton(label: context.l10n.commonUpdate, onPressed: onUpdate, tone: QButtonTone.gold),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
