import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/characters/rig/rive_character_rig.dart';
import 'package:qabas/core/characters/specs/guide_traveler.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('Real browser Rive asset loads, binds its contract and plays cues', (tester) async {
    final cache = CharacterAssetCache(
      loader: (_) async {
        final initialized = await rive.RiveNative.init();
        if (!initialized) return null;
        return rive.File.url('http://localhost:8284/guide_traveler/guide_traveler.riv', riveFactory: rive.Factory.rive);
      },
    );
    final rig = RiveCharacterRig(spec: guideTraveler, cache: cache);
    bool? attached;
    final loading = rig.attach().then((value) => attached = value);
    for (var frame = 0; attached == null && frame < 1500; frame++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await loading;
    expect(attached, true);
    expect(rig.contractValid, true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 200, height: 200, child: Builder(builder: (context) => rig.build(context, const CharacterLayout()))),
          ),
        ),
      ),
    );
    rig.setMood(CharacterMood.thinking);
    expect(rig.currentMood, 'thinking');
    for (final cue in CharacterCue.values) {
      rig.fire(cue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }
    rig.setPaused(true);
    expect(rig.paused, true);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
    await cache.dispose();
  }, skip: !kIsWeb);
}
