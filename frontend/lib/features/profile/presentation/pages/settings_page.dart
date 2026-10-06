import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/router/routes.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/presentation/bloc/preferences_cubit.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_extras_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/account_deletion_sheet.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  void _pick(BuildContext context, String title, List<String> labels, int selected, ValueChanged<int> onPick) {
    showQSheet(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: ctx.text.headlineSmall),
          const SizedBox(height: QSpace.sm),
          for (var i = 0; i < labels.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(labels[i], style: ctx.text.titleMedium),
              trailing: i == selected ? const Icon(Icons.check_circle_rounded, color: QColors.emerald500) : null,
              onTap: () {
                SensoryScope.of(ctx).select();
                onPick(i);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocListener<LocaleCubit, LocaleState>(
    listenWhen: (a, b) => a.language != b.language,
    listener: (context, _) => context.read<SettingsBloc>().add(const SettingsLanguageObserved()),
    child: BlocConsumer<SettingsBloc, SettingsState>(
      listenWhen: (a, b) => a.notice != b.notice,
      listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.settingsSaveFailed))),
      builder: (context, state) {
        final l = context.l10n, bloc = context.read<SettingsBloc>();
        final user = state.user;
        final prefs = context.watch<PreferencesCubit>().state.value;
        final locale = context.watch<LocaleCubit>().state.language;
        void local(LocalPreferencesEdit edit) => bloc.add(LocalSettingChanged(edit));
        void server(ProfileEdit edit) => bloc.add(SettingChanged(edit));
        final busy = state.status == SettingsStatus.saving;
        final loc = MaterialLocalizations.of(context);
        String goal(int value) => l.onboardingPerDay(QNumbers.prototypePluralCount(value), context.n(value));
        String time(int value) => QNumbers.localizeDigits(loc.formatTimeOfDay(TimeOfDay(hour: value, minute: 0)), locale);
        return Scaffold(
          appBar: AppBar(title: Text(l.profileSettings)),
          body: user == null
              ? state.status == SettingsStatus.failure
                    ? QErrorView(kind: failureKind(state.failure!), onRetry: () => bloc.add(const SettingsOpened()))
                    : const QLoadingView()
              : ListView(
                  key: const PageStorageKey('settings-scroll'),
                  padding: const EdgeInsets.fromLTRB(QSpace.page, QSpace.xs, QSpace.page, QSpace.xxl),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            QSettingsSection(l.settingsSectionAccount, [
                              QSettingsRow(
                                key: const ValueKey('settings-language'),
                                icon: Icons.translate_rounded,
                                title: l.settingsLanguage,
                                value: locale == 'ar' ? l.settingsArabic : l.settingsEnglish,
                                onTap: busy
                                    ? null
                                    : () => _pick(
                                        context,
                                        l.settingsLanguage,
                                        [l.settingsEnglish, l.settingsArabic],
                                        locale == 'ar' ? 1 : 0,
                                        (i) => server(ProfileEdit(language: i == 0 ? UserLanguage.en : UserLanguage.ar)),
                                      ),
                              ),
                              QSettingsRow(
                                key: const ValueKey('settings-track'),
                                icon: Icons.route_rounded,
                                title: l.settingsLearnerPath,
                                value: user.track == UserTrack.newMuslim ? l.commonPathNewMuslim : l.commonPathExplorer,
                                onTap: busy
                                    ? null
                                    : () => _pick(
                                        context,
                                        l.settingsLearnerPath,
                                        [l.commonPathExplorer, l.commonPathNewMuslim],
                                        user.track == UserTrack.newMuslim ? 1 : 0,
                                        (i) => server(ProfileEdit(track: i == 0 ? UserTrack.explorer : UserTrack.newMuslim)),
                                      ),
                              ),
                              if (state.curiosity case final copy?)
                                QSettingsRow(
                                  key: const ValueKey('settings-curiosity'),
                                  icon: Icons.help_outline_rounded,
                                  title: copy.question,
                                  value: copy.labels[user.goalAnchor],
                                  onTap: busy
                                      ? null
                                      : () => _pick(
                                          context,
                                          copy.question,
                                          copy.labels.values.toList(),
                                          copy.labels.keys.toList().indexOf(user.goalAnchor ?? ''),
                                          (i) => server(ProfileEdit(goalAnchor: copy.labels.keys.elementAt(i))),
                                        ),
                                ),
                            ]),
                            QSettingsSection(l.settingsSectionLearning, [
                              QSettingsRow(
                                key: const ValueKey('settings-goal'),
                                icon: Icons.flag_rounded,
                                title: l.settingsDailyGoalSetting,
                                value: goal(user.dailyGoalMinutes),
                                onTap: busy
                                    ? null
                                    : () => _pick(
                                        context,
                                        l.settingsDailyGoalSetting,
                                        [
                                          for (final m in [5, 10, 15, 20]) goal(m),
                                        ],
                                        const [5, 10, 15, 20].indexOf(user.dailyGoalMinutes),
                                        (i) => server(ProfileEdit(dailyGoal: const [5, 10, 15, 20][i])),
                                      ),
                              ),
                              QSettingsRow(
                                key: const ValueKey('settings-reminder'),
                                icon: Icons.alarm_rounded,
                                title: l.settingsReminders,
                                value: time(prefs.reminderHour),
                                onTap: () => _pick(
                                  context,
                                  l.settingsReminders,
                                  [
                                    for (final h in [8, 13, 19, 21]) time(h),
                                  ],
                                  const [8, 13, 19, 21].indexOf(prefs.reminderHour),
                                  (i) => local(LocalPreferencesEdit(reminderHour: const [8, 13, 19, 21][i])),
                                ),
                              ),
                              QSettingsToggle(
                                key: const ValueKey('settings-discreet'),
                                icon: Icons.notifications_paused_rounded,
                                title: l.settingsDiscreetReminders,
                                subtitle: l.onboardingDiscreetBody,
                                value: prefs.discreetReminders,
                                onChanged: (v) => local(LocalPreferencesEdit(discreetReminders: v)),
                              ),
                            ]),
                            QSettingsSection(l.settingsSectionExperience, [
                              QSettingsToggle(
                                key: const ValueKey('settings-sound'),
                                icon: Icons.music_note_rounded,
                                title: l.settingsSoundEffects,
                                value: prefs.sound,
                                onChanged: (v) => local(LocalPreferencesEdit(sound: v)),
                              ),
                              QSettingsToggle(
                                key: const ValueKey('settings-haptics'),
                                icon: Icons.vibration_rounded,
                                title: l.settingsHapticsLabel,
                                value: prefs.haptics,
                                onChanged: (v) => local(LocalPreferencesEdit(haptics: v)),
                              ),
                              QSettingsToggle(
                                key: const ValueKey('settings-motion'),
                                icon: Icons.motion_photos_off_rounded,
                                title: l.settingsReduceMotion,
                                subtitle: l.settingsReduceMotionBody,
                                value: prefs.reduceMotion,
                                onChanged: (v) => local(LocalPreferencesEdit(reduceMotion: v)),
                              ),
                              QSettingsToggle(
                                key: const ValueKey('settings-characters'),
                                icon: Icons.emoji_people_rounded,
                                title: l.settingsCharacters,
                                value: prefs.companionEnabled,
                                onChanged: (v) => local(LocalPreferencesEdit(companionEnabled: v)),
                              ),
                            ]),
                            QSettingsSection(l.settingsSectionPrivacy, [
                              QSettingsRow(
                                key: const ValueKey('settings-delete-account'),
                                icon: Icons.delete_outline_rounded,
                                title: l.settingsDeleteAccount,
                                onTap: () {
                                  final bloc = context.read<AccountDeletionBloc>();
                                  showQSheet(
                                    context,
                                    builder: (_) => BlocProvider.value(value: bloc, child: const AccountDeletionSheet()),
                                  );
                                },
                              ),
                              QSettingsToggle(
                                key: const ValueKey('settings-private'),
                                icon: Icons.lock_rounded,
                                title: l.settingsPrivateProfileSetting,
                                subtitle: l.onboardingPrivateBody,
                                value: user.privateProfile,
                                onChanged: busy ? null : (v) => server(ProfileEdit(privateProfile: v)),
                              ),
                            ]),
                            QSettingsSection(l.settingsSectionAbout, [
                              QSettingsRow(
                                key: const ValueKey('settings-about'),
                                icon: Icons.local_fire_department_rounded,
                                title: l.settingsAboutQabas,
                                onTap: () => context.push(Routes.about),
                              ),
                              QSettingsRow(
                                key: const ValueKey('settings-content'),
                                icon: Icons.info_outline_rounded,
                                title: l.settingsContentNote,
                                onTap: () => showQSheet(
                                  context,
                                  builder: (ctx) => Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(ctx.l10n.settingsContentNote, style: ctx.text.headlineSmall),
                                      const SizedBox(height: QSpace.sm),
                                      Text(ctx.l10n.settingsContentNoteBody, style: ctx.text.bodyLarge),
                                      const SizedBox(height: QSpace.sm),
                                      Text(ctx.l10n.aboutAiNotice, style: ctx.text.bodyLarge),
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    ),
  );
}
