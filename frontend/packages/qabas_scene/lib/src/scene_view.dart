import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'cache.dart';
import 'engine.dart';
import 'painter.dart';

/// Presentation-only media view. The app supplies verified-media byte loading,
/// localized semantics and the image/alt fallback; this package has no app imports.
class SceneView extends StatefulWidget {
  const SceneView({
    super.key,
    required this.descriptor,
    required this.cache,
    required this.params,
    required this.reducedMotion,
    required this.fallback,
    required this.alt,
    this.onAvailability,
  });
  final SceneDescriptor descriptor;
  final SceneCache cache;
  final Map<String, Object?> params;
  final bool reducedMotion;
  final Widget fallback;
  final String alt;
  final ValueChanged<bool>? onAvailability;
  @override
  SceneViewState createState() => SceneViewState();
}

class _FrameSignal extends ChangeNotifier {
  void changed() => notifyListeners();
}

class SceneViewState extends State<SceneView> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  final _repaint = _FrameSignal();
  final _boxKey = GlobalKey();
  SceneEngine? _engine;
  SceneProgram? _program;
  ScrollPosition? _scroll;
  var _epoch = 0;
  var _clockMs = 0.0, _runStart = 0.0;
  var _tickerEnabled = true, _inViewport = true, _foreground = true, _checkScheduled = false;
  bool _failed = false;
  SceneEngine? get engine => _engine;
  double get clockMs => _clockMs;
  bool get running => _ticker.isActive;
  SceneFrame? get frame => _engine?.frame(_clockMs, reducedMotion: widget.reducedMotion);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    _engine = null;
    _program = null;
    _failed = false;
    _ticker.stop();
    _clockMs = 0;
    try {
      final manifest = await widget.cache.load(widget.descriptor);
      if (!mounted || epoch != _epoch) return;
      final engine = SceneEngine(manifest, params: widget.params), program = SceneProgram(manifest);
      setState(() {
        _engine = engine;
        _program = program;
      });
      _availability(true);
      _scheduleVisibilityCheck();
      _syncTicker();
    } catch (_) {
      if (!mounted || epoch != _epoch) return;
      setState(() => _failed = true);
    }
  }

  void _availability(bool value) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) widget.onAvailability?.call(value);
  });
  void _tick(Duration elapsed) {
    _clockMs = _runStart + elapsed.inMicroseconds / 1000;
    _repaint.changed();
  }

  void _syncTicker() {
    final active = _engine != null && !_failed && !widget.reducedMotion && _tickerEnabled && _inViewport && _foreground;
    if (active && !_ticker.isActive) {
      _runStart = _clockMs;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scroll) {
      _scroll?.removeListener(_scheduleVisibilityCheck);
      _scroll = position;
      _scroll?.addListener(_scheduleVisibilityCheck);
    }
    _scheduleVisibilityCheck();
    _syncTicker();
  }

  void _scheduleVisibilityCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final box = _boxKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final rectangle = box.localToGlobal(Offset.zero) & box.size;
      var visibleBounds = Offset.zero & MediaQuery.sizeOf(context);
      final viewport = RenderAbstractViewport.maybeOf(box) as RenderObject?;
      if (viewport is RenderBox && viewport.hasSize) {
        visibleBounds = visibleBounds.intersect(viewport.localToGlobal(Offset.zero) & viewport.size);
      }
      _inViewport = rectangle.overlaps(visibleBounds) && !rectangle.isEmpty;
      _syncTicker();
    });
  }

  @override
  void didChangeMetrics() => _scheduleVisibilityCheck();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  @override
  void didUpdateWidget(SceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.descriptor.cacheKey != widget.descriptor.cacheKey ||
        oldWidget.cache != widget.cache ||
        oldWidget.descriptor.width != widget.descriptor.width ||
        oldWidget.descriptor.height != widget.descriptor.height ||
        oldWidget.descriptor.schemaVersion != widget.descriptor.schemaVersion ||
        oldWidget.descriptor.mimeType != widget.descriptor.mimeType ||
        !listEquals(oldWidget.descriptor.requiredCapabilities, widget.descriptor.requiredCapabilities)) {
      unawaited(_load());
      return;
    }
    if (_failed && _engine == null && !mapEquals(oldWidget.params, widget.params)) {
      unawaited(_load());
      return;
    }
    if (widget.reducedMotion && !oldWidget.reducedMotion) _engine?.finishTransitions();
    try {
      _engine?.setState(widget.params, _clockMs, reducedMotion: widget.reducedMotion);
      if (_engine != null && _failed) {
        _failed = false;
        _availability(true);
      }
    } catch (_) {
      _failed = true;
    }
    _syncTicker();
    _scheduleVisibilityCheck();
    _repaint.changed();
  }

  @override
  Widget build(BuildContext context) {
    if (_engine == null || _failed) return widget.fallback;
    return Semantics(
      image: true,
      label: widget.alt,
      child: RepaintBoundary(
        key: _boxKey,
        child: CustomPaint(
          painter: ScenePainter(program: _program!, frame: () => frame!, repaint: _repaint),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    _scroll?.removeListener(_scheduleVisibilityCheck);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }
}
