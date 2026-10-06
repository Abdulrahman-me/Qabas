import 'package:equatable/equatable.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

enum LessonType { concept, story, practice, unknown }

enum LessonState { locked, available, inProgress, completed, unknown }

enum UnitState { locked, available, inProgress, completed, skipped, unknown }

enum PretestState { taken, notTaken, unknown }

enum UnitTestState { notPassed, passed, unknown }

final class LessonRef extends Equatable {
  const LessonRef({required this.lessonId, required this.unitId, required this.title});
  final String lessonId;
  final String unitId;
  final String title;
  @override
  List<Object?> get props => [lessonId, unitId, title];
}

final class SoftLock extends Equatable {
  SoftLock({required List<LessonRef> prerequisites, required this.startWith}) : prerequisites = List.unmodifiable(prerequisites);
  final List<LessonRef> prerequisites;
  final LessonRef startWith;
  @override
  List<Object?> get props => [prerequisites, startWith];
}

final class JourneyCurrent extends Equatable {
  const JourneyCurrent({required this.unitId, required this.lessonId});
  final String? unitId;
  final String? lessonId;
  @override
  List<Object?> get props => [unitId, lessonId];
}

final class Pretest extends Equatable {
  const Pretest({required this.state});
  final PretestState state;
  @override
  List<Object?> get props => [state];
}

final class UnitTest extends Equatable {
  const UnitTest({required this.state, required this.bestPercent, required this.passPercent, required this.canSkip});
  final UnitTestState state;
  final int? bestPercent;
  final int passPercent;
  final bool canSkip;
  @override
  List<Object?> get props => [state, bestPercent, passPercent, canSkip];
}

final class LessonEntry extends Equatable {
  const LessonEntry({
    required this.lessonId,
    required this.index,
    required this.title,
    required this.lessonType,
    required this.state,
    required this.estimatedMinutes,
    required this.xp,
    required this.standaloneEligible,
    required this.softLock,
  });
  final String lessonId;
  final int index;
  final String title;
  final LessonType lessonType;
  final LessonState state;
  final int estimatedMinutes;
  final int xp;
  final bool standaloneEligible;
  final SoftLock? softLock;
  @override
  List<Object?> get props => [lessonId, index, title, lessonType, state, estimatedMinutes, xp, standaloneEligible, softLock];
}

final class JourneyUnit extends Equatable {
  JourneyUnit({
    required this.unitId,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.artKey,
    required this.hasGuide,
    required this.state,
    required this.comingSoon,
    required this.pretest,
    required this.unitTest,
    required List<LessonEntry> lessons,
  }) : lessons = List.unmodifiable(lessons);
  final String unitId;
  final int index;
  final String title;
  final String subtitle;
  final String? artKey;
  final bool hasGuide;
  final UnitState state;
  final bool comingSoon;
  final Pretest pretest;
  final UnitTest unitTest;
  final List<LessonEntry> lessons;
  @override
  List<Object?> get props => [unitId, index, title, subtitle, artKey, hasGuide, state, comingSoon, pretest, unitTest, lessons];
}

final class Journey extends Equatable {
  Journey({required this.track, required this.current, required List<JourneyUnit> units}) : units = List.unmodifiable(units);
  final UserTrack track;
  final JourneyCurrent current;
  final List<JourneyUnit> units;
  LessonEntry? lesson(String id) => units.expand((u) => u.lessons).where((l) => l.lessonId == id).firstOrNull;
  JourneyUnit? unitFor(String lessonId) => units.where((u) => u.lessons.any((l) => l.lessonId == lessonId)).firstOrNull;
  @override
  List<Object?> get props => [track, current, units];
}
