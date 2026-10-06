import 'package:qabas/shared/data/dtos/journey_dto.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

extension LessonRefMapping on LessonRefDto {
  LessonRef toEntity() => LessonRef(lessonId: lessonId, unitId: unitId, title: title);
}

extension SoftLockMapping on SoftLockDto {
  SoftLock toEntity() => SoftLock(prerequisites: prerequisites.map((v) => v.toEntity()).toList(), startWith: startWith.toEntity());
}

extension JourneyCurrentMapping on JourneyCurrentDto {
  JourneyCurrent toEntity() => JourneyCurrent(unitId: unitId, lessonId: lessonId);
}

extension PretestMapping on PretestDto {
  Pretest toEntity() => Pretest(
    state: switch (state) {
      PretestStateDto.taken => PretestState.taken,
      PretestStateDto.notTaken => PretestState.notTaken,
      PretestStateDto.unknown => PretestState.unknown,
    },
  );
}

extension UnitTestMapping on UnitTestDto {
  UnitTest toEntity() => UnitTest(
    state: switch (state) {
      UnitTestStateDto.notPassed => UnitTestState.notPassed,
      UnitTestStateDto.passed => UnitTestState.passed,
      UnitTestStateDto.unknown => UnitTestState.unknown,
    },
    bestPercent: bestPercent,
    passPercent: passPercent,
    canSkip: canSkip,
  );
}

extension LessonEntryMapping on LessonEntryDto {
  LessonEntry toEntity() => LessonEntry(
    lessonId: lessonId,
    index: index,
    title: title,
    lessonType: switch (lessonType) {
      LessonTypeDto.concept => LessonType.concept,
      LessonTypeDto.story => LessonType.story,
      LessonTypeDto.practice => LessonType.practice,
      LessonTypeDto.unknown => LessonType.unknown,
    },
    state: switch (state) {
      LessonStateDto.locked => LessonState.locked,
      LessonStateDto.available => LessonState.available,
      LessonStateDto.inProgress => LessonState.inProgress,
      LessonStateDto.completed => LessonState.completed,
      LessonStateDto.unknown => LessonState.unknown,
    },
    estimatedMinutes: estimatedMinutes,
    xp: xp,
    standaloneEligible: standaloneEligible,
    softLock: softLock?.toEntity(),
  );
}

extension JourneyUnitMapping on JourneyUnitDto {
  JourneyUnit toEntity() => JourneyUnit(
    unitId: unitId,
    index: index,
    title: title,
    subtitle: subtitle,
    artKey: artKey,
    hasGuide: hasGuide,
    state: switch (state) {
      UnitStateDto.locked => UnitState.locked,
      UnitStateDto.available => UnitState.available,
      UnitStateDto.inProgress => UnitState.inProgress,
      UnitStateDto.completed => UnitState.completed,
      UnitStateDto.skipped => UnitState.skipped,
      UnitStateDto.unknown => UnitState.unknown,
    },
    comingSoon: comingSoon,
    pretest: pretest.toEntity(),
    unitTest: unitTest.toEntity(),
    lessons: lessons.map((v) => v.toEntity()).toList(),
  );
}

extension JourneyMapping on JourneyDto {
  Journey toEntity() => Journey(
    track: switch (track) {
      JourneyTrackDto.explorer => UserTrack.explorer,
      JourneyTrackDto.newMuslim => UserTrack.newMuslim,
      JourneyTrackDto.unknown => UserTrack.unknown,
    },
    current: current.toEntity(),
    units: units.map((v) => v.toEntity()).toList(),
  );
}
