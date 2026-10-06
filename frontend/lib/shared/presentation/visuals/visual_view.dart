import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/presentation/visuals/builtin/scenes.dart';
import 'package:qabas_scene/qabas_scene.dart';

enum VisualUse { hook, story, teach, predict, block, hotspots, dayArc }

/// An outer step crossfade owns the outgoing renderer slot. Its descendants
/// show only their current visual until that outer transition has finished.
class VisualCrossfadeScope extends InheritedWidget {
  const VisualCrossfadeScope({super.key, required this.allowOutgoing, required super.child});
  final bool allowOutgoing;
  static bool allowedOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<VisualCrossfadeScope>()?.allowOutgoing ?? true;
  @override
  bool updateShouldNotify(VisualCrossfadeScope oldWidget) => allowOutgoing != oldWidget.allowOutgoing;
}

class VisualMediaScope extends InheritedWidget {
  const VisualMediaScope({super.key, required this.resolve, this.scenes, required super.child});
  final ResolvedMedia Function(String) resolve;
  final SceneCache? scenes;
  static SceneCache? scenesOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<VisualMediaScope>()?.scenes;
  static ResolvedMedia resolveOf(BuildContext c, String url) =>
      c.dependOnInheritedWidgetOfExactType<VisualMediaScope>()?.resolve(url) ?? RemoteMedia(Uri.parse(url));
  @override
  bool updateShouldNotify(VisualMediaScope oldWidget) => resolve != oldWidget.resolve || scenes != oldWidget.scenes;
}

class VisualView extends StatelessWidget {
  const VisualView(this.visual, {super.key, required this.use, this.params, this.onAvailability});
  final Visual visual;
  final VisualUse use;
  final ValueChanged<bool>? onAvailability;
  final Map<String, Object?>? params;
  double get ratio => switch (visual) {
    ImageVisual(:final image) => image.width / image.height,
    SceneVisual(:final scene) => scene.width / scene.height,
    _ => switch (use) {
      VisualUse.story => QLesson.storyRatio,
      VisualUse.teach => visual is BuiltinVisual && (visual as BuiltinVisual).key == 'day_arc' ? QLesson.dayTeachRatio : QLesson.teachRatio,
      VisualUse.hotspots => QLesson.hotspotRatio,
      VisualUse.dayArc => QLesson.dayExerciseRatio,
      _ => QLesson.hookRatio,
    },
  };
  String get identity => switch (visual) {
    final BuiltinVisual v => 'builtin/${v.key}/${v.version}',
    final SceneVisual v => '${v.scene.sceneId}/${v.scene.version}/${v.scene.sha256}',
    final ImageVisual v => v.image.url,
    _ => 'unknown',
  };
  @override
  Widget build(BuildContext context) {
    final v = visual;
    final allowOutgoing = VisualCrossfadeScope.allowedOf(context);
    void availability(bool value) {
      if (onAvailability != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) onAvailability!(value);
        });
      }
    }

    if (v is BuiltinVisual && v.version == 1 && ['river_house', 'workplace', 'day_arc', 'pillars'].contains(v.key)) availability(true);
    if (v is UnknownVisual ||
        (v is BuiltinVisual &&
            (v.version != 1 || !['river_house', 'workplace', 'day_arc', 'pillars'].contains(v.key)) &&
            v.fallbackImage == null)) {
      availability(false);
    }
    final Widget renderer = switch (v) {
      BuiltinVisual() => v.version == 1 ? _builtin(context, v) : _fallback(v.fallbackImage, v.alt),
      ImageVisual() => _VisualImage(image: v.image, alt: v.alt, onAvailability: availability),
      SceneVisual() => _scene(context, v, availability),
      UnknownVisual() => _VisualPlaceholder(alt: v.alt),
    };
    final box = AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: QRadius.card,
            child: AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : QMotion.slow,
              layoutBuilder: (current, previous) =>
                  Stack(fit: StackFit.expand, children: [if (allowOutgoing && previous.isNotEmpty) previous.last, ?current]),
              child: KeyedSubtree(
                key: ValueKey(identity),
                child: SizedBox.expand(child: renderer),
              ),
            ),
          ),
          for (final overlay in v.overlays)
            if (overlay.type == 'medallion' && overlay.anchor != OverlayAnchor.unknown) _OverlayView(overlay),
        ],
      ),
    );
    if (v is! BuiltinVisual || v.key != 'pillars' || v.version != 1) return box;
    final highlight = ((params ?? v.params)['highlight'] as num?)?.toInt() ?? -1;
    final names = [
      context.l10n.journeyPillarNames1,
      context.l10n.journeyPillarNames2,
      context.l10n.journeyPillarNames3,
      context.l10n.journeyPillarNames4,
      context.l10n.journeyPillarNames5,
    ];
    return Column(
      children: [
        box,
        const SizedBox(height: QSpace.xs),
        Row(
          children: [
            for (var i = 0; i < names.length; i++)
              Expanded(
                child: Text(
                  names[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: i == highlight ? QColors.gold800 : QColors.slate,
                    fontWeight: i == highlight ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _scene(BuildContext context, SceneVisual visual, ValueChanged<bool> availability) {
    final cache = VisualMediaScope.scenesOf(context);
    final fallback = _VisualImage(image: visual.fallbackImage, alt: visual.alt, onAvailability: availability);
    if (cache == null) return fallback;
    final scene = visual.scene;
    return SceneView(
      descriptor: SceneDescriptor(
        sceneId: scene.sceneId,
        version: scene.version,
        schemaVersion: scene.schemaVersion,
        url: scene.url,
        sha256: scene.sha256,
        width: scene.width,
        height: scene.height,
        mimeType: scene.mimeType,
        requiredCapabilities: scene.requiredCapabilities,
      ),
      cache: cache,
      params: {...visual.params, ...?params},
      reducedMotion: context.reduceMotion,
      fallback: fallback,
      alt: visual.alt,
      onAvailability: availability,
    );
  }

  Widget _builtin(BuildContext c, BuiltinVisual v) {
    final p = params ?? v.params;
    int integer(String key, int fallback) => (p[key] as num?)?.toInt() ?? fallback;
    return switch (v.key) {
      'river_house' => RiverHouseScene(beat: integer('beat', 1)),
      'workplace' => const WorkplaceScene(),
      'day_arc' => DayArcScene(highlight: integer('highlight', -1)),
      'pillars' => Transform.flip(
        flipX: c.isRtl,
        child: PillarsScene(highlight: integer('highlight', -1)),
      ),
      _ => _fallback(v.fallbackImage, v.alt),
    };
  }

  Widget _fallback(NetworkImageRef? image, String alt) => image == null
      ? _VisualPlaceholder(alt: alt)
      : _VisualImage(
          image: image,
          alt: alt,
          onAvailability: (value) {
            if (onAvailability != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onAvailability!(value);
              });
            }
          },
        );
}

class _VisualImage extends StatefulWidget {
  const _VisualImage({required this.image, required this.alt, this.onAvailability});
  final ValueChanged<bool>? onAvailability;
  final NetworkImageRef image;
  final String alt;
  @override
  State<_VisualImage> createState() => _VisualImageState();
}

class _VisualImageState extends State<_VisualImage> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) {
    ResolvedMedia resolved;
    try {
      resolved = VisualMediaScope.resolveOf(context, widget.image.url);
    } catch (_) {
      widget.onAvailability?.call(false);
      return _VisualPlaceholder(alt: widget.alt);
    }
    Widget error() {
      widget.onAvailability?.call(false);
      return _VisualPlaceholder(
        alt: widget.alt,
        onRetry: () {
          setState(() => _attempt++);
        },
      );
    }

    return switch (resolved) {
      UnavailableMedia() => error(),
      MemoryMedia(:final bytes) => Image.memory(bytes, fit: BoxFit.contain, semanticLabel: widget.alt, errorBuilder: (_, _, _) => error()),
      AssetMedia(:final path) => Image.asset(
        path,
        key: ValueKey('$path/$_attempt'),
        fit: BoxFit.contain,
        semanticLabel: widget.alt,
        errorBuilder: (_, _, _) => error(),
        frameBuilder: (context, child, frame, sync) {
          if (frame != null || sync) widget.onAvailability?.call(true);
          return child;
        },
      ),
      RemoteMedia(:final uri) => CachedNetworkImage(
        key: ValueKey('$uri/$_attempt'),
        imageUrl: uri.toString(),
        fit: BoxFit.contain,
        progressIndicatorBuilder: (_, _, _) => const Center(child: QInlineLoading(showFlame: false)),
        errorWidget: (_, _, _) => error(),
        imageBuilder: (_, provider) {
          widget.onAvailability?.call(true);
          return Image(image: provider, fit: BoxFit.contain, semanticLabel: widget.alt);
        },
      ),
    };
  }
}

class _VisualPlaceholder extends StatelessWidget {
  const _VisualPlaceholder({required this.alt, this.onRetry});
  final String alt;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    color: QColors.surfaceSunk,
    child: SingleChildScrollView(
      key: PageStorageKey('visual-placeholder-$alt'),
      child: Padding(
        padding: const EdgeInsets.all(QSpace.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.landscape_outlined, color: QColors.muted),
            const SizedBox(height: QSpace.xs),
            Text(alt, textAlign: TextAlign.center, style: context.text.bodySmall),
            if (onRetry != null) TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
          ],
        ),
      ),
    ),
  );
}

class _OverlayView extends StatelessWidget {
  const _OverlayView(this.overlay);
  final VisualOverlay overlay;
  @override
  Widget build(BuildContext context) {
    ResolvedMedia media;
    try {
      media = VisualMediaScope.resolveOf(context, overlay.assetUrl);
    } catch (_) {
      return const SizedBox.shrink();
    }
    final alignment = switch (overlay.anchor) {
      OverlayAnchor.topStart => AlignmentDirectional.topStart,
      OverlayAnchor.topEnd => AlignmentDirectional.topEnd,
      OverlayAnchor.center => AlignmentDirectional.center,
      OverlayAnchor.bottomStart => AlignmentDirectional.bottomStart,
      OverlayAnchor.bottomEnd => AlignmentDirectional.bottomEnd,
      OverlayAnchor.unknown => AlignmentDirectional.center,
    };
    return LayoutBuilder(
      builder: (c, box) => Align(
        alignment: alignment,
        child: SizedBox(
          width: box.maxWidth * overlay.sizePct / 100,
          height: box.maxWidth * overlay.sizePct / 100,
          child: switch (media) {
            UnavailableMedia() || MemoryMedia() => const SizedBox.shrink(),
            AssetMedia(:final path) => SvgPicture.asset(
              path,
              semanticsLabel: overlay.label,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            RemoteMedia(:final uri) => SvgPicture.network(
              uri.toString(),
              semanticsLabel: overlay.label,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          },
        ),
      ),
    );
  }
}
