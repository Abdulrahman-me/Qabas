import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_registry.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/characters/specs/guide_traveler.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  test('Asset cache deduplicates concurrent loads and catches asynchronous failures', () async {
    var loads = 0;
    final completer = Completer<rive.File?>();
    final cache = CharacterAssetCache(
      loader: (_) {
        loads++;
        return completer.future;
      },
    );
    final first = cache.load(guideTraveler.rig as RiveRigSpec), second = cache.load(guideTraveler.rig as RiveRigSpec);
    expect(identical(first, second), true);
    expect(loads, 1);
    completer.completeError(StateError('missing'));
    expect(await first, isNull);
    expect(await second, isNull);
    await cache.dispose();
    expect(await cache.load(guideTraveler.rig as RiveRigSpec), isNull);
    expect(loads, 1);
  });
  test('Cache disposal resolves pending loads without waiting for I/O', () async {
    final pending = Completer<rive.File?>();
    final cache = CharacterAssetCache(loader: (_) => pending.future);
    final loading = cache.load(guideTraveler.rig as RiveRigSpec);
    await cache.dispose();
    expect(await loading, isNull);
    pending.complete(null);
  });
  test('A hung asset load becomes a finite failed fallback', () async {
    final pending = Completer<rive.File?>();
    final cache = CharacterAssetCache(loader: (_) => pending.future, loadTimeout: const Duration(milliseconds: 10));
    expect(await cache.load(guideTraveler.rig as RiveRigSpec), isNull);
    pending.complete(null);
    await cache.dispose();
  });
  test('Unsupported guide moods fall back to idle and roles cast independently', () {
    final registry = CharacterRegistry.bundled();
    expect(registry.resolve(CharacterRole.guide)?.id, 'guide_traveler');
    expect(registry.resolve(CharacterRole.assistant)?.id, 'raqeeb_lantern');
    expect(registry.resolve(CharacterRole.guide, overrides: {CharacterRole.guide: 'unknown'})?.id, 'guide_traveler');
    expect(registry.resolve(CharacterRole.guide, overrides: {CharacterRole.guide: 'raqeeb_lantern'})?.id, 'raqeeb_lantern');
    expect(guideTraveler.resolveMood(CharacterMood.listening), CharacterMood.idle);
    expect(guideTraveler.resolveMood(CharacterMood.speaking), CharacterMood.idle);
  });
  test('Controller retains the last pre-load cue and avoids dropping a later cue', () {
    final controller = CharacterController();
    controller.cue(CharacterCue.greet);
    final old = controller.cueSerial;
    controller.cue(CharacterCue.complete);
    controller.consumeCue(old);
    expect(controller.pendingCue, CharacterCue.complete);
    controller.consumeCue(controller.cueSerial);
    expect(controller.pendingCue, isNull);
    controller.dispose();
  });
}
