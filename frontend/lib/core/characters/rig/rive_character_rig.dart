import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/characters/rig/character_rig.dart';
import 'package:rive/rive.dart' as rive;

final class _PausableController extends rive.RiveWidgetController {
  _PausableController(super.file, {required super.artboardSelector, required super.stateMachineSelector});
  @override
  bool advance(double elapsedSeconds) => active ? super.advance(elapsedSeconds) : false;
}

final class RiveCharacterRig implements CharacterRig {
  RiveCharacterRig({required this.spec, required this.cache});
  final CharacterSpec spec;
  final CharacterAssetCache cache;
  _PausableController? _controller;
  rive.ViewModelInstance? _vmi;
  rive.ViewModelInstanceEnum? _mood;
  rive.ViewModelInstanceBoolean? _reduced;
  final Map<CharacterCue, rive.ViewModelInstanceTrigger> _triggers = {};
  bool _disposed = false;
  bool get contractValid => _mood != null && _triggers.keys.toSet().containsAll(spec.supportedCues);
  bool get paused => _controller?.active == false;
  String? get currentMood => _mood?.value;
  Set<CharacterCue> get availableCues => Set.unmodifiable(_triggers.keys);
  @override
  Future<bool> attach() async {
    final rig = spec.rig as RiveRigSpec;
    final file = await cache.load(rig);
    if (file == null || _disposed) return false;
    try {
      _controller = _PausableController(
        file,
        artboardSelector: rig.artboard == null ? rive.ArtboardSelector.byDefault() : rive.ArtboardSelector.byName(rig.artboard!),
        stateMachineSelector: rig.stateMachine == null
            ? rive.StateMachineSelector.byDefault()
            : rive.StateMachineSelector.byName(rig.stateMachine!),
      );
      _vmi = _controller!.dataBind(rig.viewModelInstance == null ? rive.DataBind.auto() : rive.DataBind.byName(rig.viewModelInstance!));
      _mood = _vmi!.enumerator(rig.moodProperty);
      if (rig.reducedMotionProperty != null) _reduced = _vmi!.boolean(rig.reducedMotionProperty!);
      for (final cue in spec.supportedCues) {
        final trigger = _vmi!.trigger(rig.cueTriggers[cue] ?? cue.name);
        if (trigger != null) _triggers[cue] = trigger;
      }
      if (!contractValid) {
        Logger('characters').warning(
          'Character ${spec.id}: contract mismatch (mood=${_mood != null}, triggers=${_triggers.keys.map((cue) => cue.name).join(',')})',
        );
      }
      setMood(CharacterMood.idle);
      _controller!.stateMachine.advanceAndApply(0);
      return true;
    } catch (_) {
      Logger('characters').warning('Character ${spec.id}: rig setup failed');
      dispose();
      return false;
    }
  }

  @override
  void setMood(CharacterMood mood) {
    if (_disposed) return;
    final rig = spec.rig as RiveRigSpec;
    _mood?.value = rig.moodValues[mood] ?? mood.name;
  }

  @override
  void fire(CharacterCue cue) {
    _triggers[cue]?.trigger();
  }

  @override
  void setPaused(bool paused) {
    if (_disposed) return;
    _reduced?.value = paused;
    if (_controller != null) _controller!.active = !paused;
  }

  @override
  Widget build(BuildContext context, CharacterLayout layout) => rive.RiveWidget(
    controller: _controller!,
    fit: layout.aspect >= 1 ? rive.Fit.contain : rive.Fit.fitHeight,
    alignment: layout.alignment,
  );
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _mood?.dispose();
    _reduced?.dispose();
    for (final trigger in _triggers.values) {
      trigger.dispose();
    }
    _triggers.clear();
    _vmi?.dispose();
    _controller?.dispose();
    _controller = null;
  }
}
