import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_scope.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/characters/rig/character_rig.dart';
import 'package:qabas/core/characters/rig/painter_character_rig.dart';
import 'package:qabas/core/characters/rig/rive_character_rig.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';

class CharacterView extends StatefulWidget {
  const CharacterView({
    super.key,
    this.role = CharacterRole.guide,
    this.size = 200,
    this.aspect,
    this.zoom,
    this.mood = CharacterMood.idle,
    this.tint,
    this.appearCue,
    this.controller,
    this.whenDisabled = CharacterAbsence.keepSpace,
  });
  final CharacterRole role;
  final double size;
  final double? aspect, zoom;
  final Color? tint;
  final CharacterMood mood;
  final CharacterCue? appearCue;
  final CharacterController? controller;
  final CharacterAbsence whenDisabled;
  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> {
  CharacterSpec? _spec;
  CharacterRig? _rig;
  final _mountedRigs = <CharacterRig, int>{};
  bool _disposed = false;
  Timer? _settle;
  int _epoch = 0, _cueSerial = 0;
  bool _enabled = true, _failed = false, _reduced = false, _visible = true;
  CharacterCue? _pending;
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_changed);
    _pending = widget.controller?.pendingCue ?? widget.appearCue;
    _cueSerial = widget.controller?.cueSerial ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = CharacterScope.maybeOf(context);
    final spec = scope?.registry.resolve(widget.role, overrides: scope.settings.overrides);
    final enabled = scope?.settings.enabled ?? true;
    final reduced = context.reduceMotion;
    _visible = TickerMode.valuesOf(context).enabled;
    final rebuild = spec != _spec || enabled != _enabled || reduced != _reduced;
    _spec = spec;
    _enabled = enabled;
    _reduced = reduced;
    if (_reduced) {
      _pending = null;
      widget.controller?.consumeCue(_cueSerial);
    }
    if (rebuild) {
      _replaceRig(scope);
    }
    _apply();
  }

  void _replaceRig(CharacterScope? scope) {
    _epoch++;
    _settle?.cancel();
    final old = _rig;
    if (old != null) {
      old.setPaused(true);
      if (!_mountedRigs.containsKey(old)) old.dispose();
    }
    _rig = null;
    _failed = false;
    if (!_enabled || _spec == null || scope == null) return;
    final rig = switch (_spec!.rig) {
      RiveRigSpec() => RiveCharacterRig(spec: _spec!, cache: scope.cache),
      PainterRigSpec() => PainterCharacterRig(),
    };
    unawaited(_load(rig, _epoch));
  }

  Future<void> _load(CharacterRig rig, int epoch) async {
    final attached = await rig.attach();
    if (!mounted || epoch != _epoch) {
      rig.dispose();
      return;
    }
    if (!attached) {
      rig.dispose();
      setState(() => _failed = true);
      return;
    }
    setState(() => _rig = rig);
    _apply();
    _settle = Timer(QMotion.characterSettle, () {
      if (mounted && epoch == _epoch && _pending != null) _firePending();
    });
  }

  void _apply() {
    _rig?.setPaused(_reduced || !_visible);
    _rig?.setMood(_reduced ? CharacterMood.idle : _spec?.resolveMood(widget.controller?.mood ?? widget.mood) ?? CharacterMood.idle);
  }

  void _changed() {
    _apply();
    final controller = widget.controller;
    if (controller != null && controller.cueSerial != _cueSerial) {
      _cueSerial = controller.cueSerial;
      _pending = controller.pendingCue;
      if (_rig != null) _firePending();
    }
  }

  void _firePending() {
    final cue = _pending;
    _pending = null;
    widget.controller?.consumeCue(_cueSerial);
    if (cue == null || _reduced || !_visible) return;
    final resolved = _spec?.resolveCue(cue);
    if (resolved != null) _rig?.fire(resolved);
  }

  @override
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
      _cueSerial = widget.controller?.cueSerial ?? 0;
      _pending = widget.controller?.pendingCue;
    }
    if (old.role != widget.role) {
      final scope = CharacterScope.maybeOf(context);
      _spec = scope?.registry.resolve(widget.role, overrides: scope.settings.overrides);
      _replaceRig(scope);
    }
    _apply();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _settle?.cancel();
    widget.controller?.removeListener(_changed);
    final old = _rig;
    if (old != null) {
      old.setPaused(true);
      if (!_mountedRigs.containsKey(old)) old.dispose();
    }
    super.dispose();
  }

  void _rigUnmounted(CharacterRig rig) {
    final remaining = (_mountedRigs[rig] ?? 1) - 1;
    if (remaining > 0) {
      _mountedRigs[rig] = remaining;
      return;
    }
    _mountedRigs.remove(rig);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mountedRigs.containsKey(rig) && (_disposed || _rig != rig)) rig.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = CharacterLayout(
      aspect: widget.aspect ?? _spec?.layout.aspect ?? 1,
      zoom: widget.zoom ?? _spec?.layout.zoom ?? 1,
      tint: widget.tint ?? _spec?.layout.tint,
      alignment: _spec?.layout.alignment ?? Alignment.bottomCenter,
    );
    final w = widget.size * layout.aspect, h = widget.size;
    if (!_enabled) return widget.whenDisabled == CharacterAbsence.collapse ? const SizedBox.shrink() : SizedBox(width: w, height: h);
    final fallback = switch (_spec?.fallback ?? CharacterFallbackKind.flame) {
      CharacterFallbackKind.flame => Align(
        alignment: const Alignment(0, 0.25),
        child: FlameMark(size: h * 0.16, glow: _failed ? 0.6 : 1.2, dim: _failed ? 0.5 : 1),
      ),
      CharacterFallbackKind.lantern => LanternGlyph(color: widget.tint ?? QColors.emerald500, lit: true, size: h * 0.5),
      CharacterFallbackKind.none => const SizedBox.shrink(),
    };
    final rig = _rig;
    Widget body = AnimatedSwitcher(
      duration: _reduced ? Duration.zero : QMotion.medium,
      child: _rig == null
          ? KeyedSubtree(key: const ValueKey('character-fallback'), child: fallback)
          : _RigBody(
              key: ValueKey(_rig),
              rig: _rig!,
              layout: layout,
              onMounted: () => _mountedRigs.update(rig!, (count) => count + 1, ifAbsent: () => 1),
              onDisposed: _rigUnmounted,
            ),
    );
    if (layout.zoom != 1) {
      body = OverflowBox(
        alignment: layout.alignment,
        minWidth: w * layout.zoom,
        maxWidth: w * layout.zoom,
        minHeight: h * layout.zoom,
        maxHeight: h * layout.zoom,
        child: body,
      );
    }
    return Semantics(
      image: true,
      label: _spec?.semanticsLabel(context.l10n) ?? context.l10n.characterGuideSemantics,
      child: SizedBox(width: w, height: h, child: body),
    );
  }
}

/// Own the rig for as long as AnimatedSwitcher retains its rendered subtree.
/// A departing Rive widget must detach before its controller is disposed.
class _RigBody extends StatefulWidget {
  const _RigBody({super.key, required this.rig, required this.layout, required this.onMounted, required this.onDisposed});
  final CharacterRig rig;
  final CharacterLayout layout;
  final VoidCallback onMounted;
  final void Function(CharacterRig) onDisposed;
  @override
  State<_RigBody> createState() => _RigBodyState();
}

class _RigBodyState extends State<_RigBody> {
  @override
  void initState() {
    super.initState();
    widget.onMounted();
  }

  @override
  Widget build(BuildContext context) => widget.rig.build(context, widget.layout);
  @override
  void dispose() {
    widget.onDisposed(widget.rig);
    super.dispose();
  }
}
