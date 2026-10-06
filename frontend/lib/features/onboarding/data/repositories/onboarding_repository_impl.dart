import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:qabas/features/onboarding/data/dtos/onboarding_dto.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_copy.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this.remote, this.preferences, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle;
  final OnboardingRemoteDataSource remote;
  final PreferencesStore preferences;
  final AssetBundle bundle;
  static const anchors = ['does_god_exist', 'who_is_god', 'quran_special', 'who_was_muhammad', 'muslim_beliefs', 'why_pray'];
  @override
  Future<CuriosityCopy?> curiosity(String language) async {
    // TODO(contract): A-26 — absent/unapproved copy skips this optional page.
    try {
      final json = jsonDecode(await bundle.loadString('assets/onboarding/curiosity.json')) as Map<String, dynamic>;
      final question = (json['question'] as Map<String, dynamic>)[language] as String?;
      final rows = (json['anchors'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (question == null || question.trim().isEmpty || rows.length != anchors.length) return null;
      final options = <CuriosityOption>[];
      for (final anchor in anchors) {
        final row = rows.singleWhere((row) => row['goal_anchor'] == anchor);
        final label = (row['label'] as Map<String, dynamic>)[language] as String?;
        if (label == null || label.trim().isEmpty) return null;
        final bridges = row['bridge'] as Map<String, dynamic>;
        String? bridge(String track) {
          final value = (bridges[track] as Map<String, dynamic>? ?? {})[language] as String?;
          return value == null || value.trim().isEmpty ? null : value;
        }

        options.add(
          CuriosityOption(anchor: anchor, label: label, explorerBridge: bridge('explorer'), newMuslimBridge: bridge('new_muslim')),
        );
      }
      return CuriosityCopy(question: question, options: options);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<PathPreview>> preview(String language, TrackChoice track) async {
    // TODO(contract): A-32 — bundled canonical unit headings for the ready-page preview only.
    final rows = (jsonDecode(await bundle.loadString('assets/onboarding/path_preview.json')) as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.where((row) => track != TrackChoice.newMuslim || row['number'] != 0).take(3).map((row) {
      final titles = row['title'] as Map<String, dynamic>;
      return PathPreview(
        number: row['number'] as int,
        title: (titles[language] ?? titles['en']) as String,
        artKey: row['art_key'] as String? ?? 'book',
      );
    }).toList();
  }

  @override
  Future<Result<UserProfile>> complete(OnboardingAnswers answers) => guard(() async {
    final request = OnboardingRequestDto(
      trackChoice: switch (answers.track) {
        TrackChoice.newMuslim => 'new_muslim',
        TrackChoice.explorer => 'explorer',
        TrackChoice.undisclosed => 'undisclosed',
      },
      language: answers.language,
      familiarity: switch (answers.familiarity) {
        Familiarity.none => 'none',
        Familiarity.some => 'some',
        Familiarity.good => 'good',
        _ => null,
      },
      dailyGoalMinutes: answers.dailyGoal,
      privateProfile: answers.privateProfile,
      goalAnchor: answers.goalAnchor,
    );
    return (await remote.complete(request)).user.toEntity();
  });

  @override
  Future<Result<void>> saveLocalChoices({required bool discreetReminders, required int reminderHour}) => guard(() async {
    await preferences.setBoolean('discreet_reminders', discreetReminders);
    await preferences.setString('reminder_hour', reminderHour.toString());
  });
}
