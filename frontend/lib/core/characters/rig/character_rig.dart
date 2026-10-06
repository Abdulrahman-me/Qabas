import 'package:flutter/widgets.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';

abstract interface class CharacterRig {
  Future<bool> attach();
  void setMood(CharacterMood mood);
  void fire(CharacterCue cue);
  void setPaused(bool paused);
  Widget build(BuildContext context, CharacterLayout layout);
  void dispose();
}
