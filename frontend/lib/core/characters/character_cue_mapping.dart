import 'package:qabas/core/characters/character_vocabulary.dart';

enum EvaluationOutcome { correct, incorrect, neutral }

CharacterCue cueForEvaluation(EvaluationOutcome outcome) => switch (outcome) {
  EvaluationOutcome.correct => CharacterCue.correct,
  EvaluationOutcome.incorrect => CharacterCue.retry,
  EvaluationOutcome.neutral => CharacterCue.encourage,
};
