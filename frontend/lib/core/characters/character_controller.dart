import 'package:flutter/foundation.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';

final class CharacterController extends ChangeNotifier {
  CharacterMood _mood = CharacterMood.idle;
  CharacterCue? pendingCue;
  int cueSerial = 0;
  CharacterMood get mood => _mood;
  set mood(CharacterMood value) {
    _mood = value;
    notifyListeners();
  }

  void cue(CharacterCue cue) {
    pendingCue = cue;
    cueSerial++;
    notifyListeners();
  }

  void consumeCue(int serial) {
    if (serial == cueSerial) pendingCue = null;
  }
}
