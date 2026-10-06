import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/shared/data/dtos/core_requests_dto.dart';
import 'package:qabas/shared/data/dtos/next_step_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';

void main() {
  late Map<String, dynamic> user;
  setUp(() {
    user = jsonDecode(File('assets/mocks/examples/User__5_1_user__0.json').readAsStringSync()) as Map<String, dynamic>;
  });
  test('Goal anchor is nullable, required, and maps verbatim', () {
    expect(UserDto.fromJson(user).toEntity().goalAnchor, user['goal_anchor']);
    user['goal_anchor'] = null;
    expect(UserDto.fromJson(user).toEntity().goalAnchor, isNull);
    user.remove('goal_anchor');
    expect(() => UserDto.fromJson(user), throwsA(isA<Exception>()));
  });
  test('Unknown enum and metadata remain forward compatible', () {
    user.addAll({
      'role': 'future_role',
      'language': 'fr',
      'track': 'future_track',
      'familiarity': 'future_level',
      '_mock': {'private_key': 'ignored'},
    });
    final dto = UserDto.fromJson(user);
    expect(dto.role, RoleDto.unknown);
    expect(dto.language, LanguageDto.unknown);
    expect(dto.track, TrackDto.unknown);
    expect(dto.familiarity, FamiliarityDto.unknown);
    expect(dto.toEntity().createdAt.isUtc, isTrue);
  });
  test('Next step nullable fields and future enums', () {
    final dto = NextStepDto.fromJson({
      'type': 'future',
      'reason': 'future',
      'unit_id': null,
      'lesson_id': null,
      'title': null,
      'due_reviews_count': 0,
    });
    expect(dto.type, NextTypeDto.unknown);
    expect(dto.reason, NextReasonDto.unknown);
    expect(dto.toEntity().lessonId, isNull);
  });
  test('Patch serializes only changes and no nulls', () {
    expect(const MePatchDto(language: 'ar', privateProfile: false).toJson(), {'language': 'ar', 'private_profile': false});
    expect(const GuestRequestDto('Asia/Muscat').toJson(), {'timezone': 'Asia/Muscat'});
  });
}
