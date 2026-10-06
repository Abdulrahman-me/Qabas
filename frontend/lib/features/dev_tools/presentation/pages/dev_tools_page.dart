import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/characters/character_controller.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/presentation/bloc/dev_tools_bloc.dart';
import 'package:qabas/shared/domain/entities/local_preferences.dart';

class DevToolsPage extends StatefulWidget {
  const DevToolsPage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.preferences,
    required this.onPreferencesChanged,
    required this.onLocalReset,
    required this.onGateReset,
    required this.onCastingChanged,
    required this.characterIds,
    required this.onBack,
  });
  final String language;
  final ValueChanged<String> onLanguageChanged, onCastingChanged;
  final LocalPreferences preferences;
  final ValueChanged<LocalPreferences> onPreferencesChanged;
  final VoidCallback onLocalReset, onGateReset;
  final List<String> characterIds;
  final VoidCallback onBack;
  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage> {
  final _guide = CharacterController(), _assistant = CharacterController();
  @override
  void dispose() {
    _guide.dispose();
    _assistant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Developer tools'),
      leading: BackButton(key: const ValueKey('developer-back'), onPressed: widget.onBack),
    ),
    body: BlocConsumer<DevToolsBloc, DevToolsState>(
      listener: (context, state) {
        if (state.lessonToOpen != null) context.push('/lesson/${Uri.encodeComponent(state.lessonToOpen!)}/intro');
      },
      builder: (context, state) {
        final snapshot = state.snapshot;
        void change(DevOption option, Object? value) => context.read<DevToolsBloc>().add(DevOptionChanged(option, value));
        Widget toggle(String label, DevOption option) => SwitchListTile(
          title: Text(label),
          value: snapshot?.values[option] == true,
          onChanged: snapshot?.mockAvailable == true ? (value) => change(option, value) : null,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(QSpace.page),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QButton(
                    key: const ValueKey('dev-reviewer'),
                    label: context.l10n.reviewerConsole,
                    silent: true,
                    onPressed: () => context.push('/reviewer/login'),
                  ),
                  toggle('Stale reviewer digest (next gate)', DevOption.reviewStale),
                  if (snapshot?.values[DevOption.prepareRecording] == true) ...[
                    TextButton(
                      key: const ValueKey('recording-prepare'),
                      onPressed: () => change(DevOption.prepareRecording, null),
                      child: const Text('Prepare recording: refill reviews and automatic answers'),
                    ),
                    TextButton(
                      key: const ValueKey('recording-reviewer-reset'),
                      onPressed: () => change(DevOption.resetReviewer, null),
                      child: const Text('Reset reviewer runs and blind pairs'),
                    ),
                  ],
                  if (state.status == DevToolsStatus.loading) const QInlineLoading(),
                  if (state.failure != null)
                    QInlineError(
                      message: context.l10n.errorGenericBody,
                      onRetry: () => context.read<DevToolsBloc>().add(const DevToolsOpened()),
                    ),
                  if (snapshot != null)
                    QCard(
                      child: Text(
                        'API: ${snapshot.mode}\n${snapshot.baseUrl}\nLive: ${snapshot.liveGroups}\nContract: ${snapshot.serverContract ?? '—'}',
                      ),
                    ),
                  const SizedBox(height: QSpace.md),
                  QSegmentedChips<String>(
                    options: {'en': context.l10n.commonEnglish, 'ar': context.l10n.commonArabic},
                    selected: widget.language,
                    onSelected: widget.onLanguageChanged,
                  ),
                  SwitchListTile(
                    title: Text(context.l10n.settingsReduceMotion),
                    value: widget.preferences.reduceMotion,
                    onChanged: (value) => widget.onPreferencesChanged(widget.preferences.copyWith(reduceMotion: value)),
                  ),
                  SwitchListTile(
                    title: Text(context.l10n.settingsSoundEffects),
                    value: widget.preferences.sound,
                    onChanged: (value) => widget.onPreferencesChanged(widget.preferences.copyWith(sound: value)),
                  ),
                  SwitchListTile(
                    title: Text(context.l10n.settingsHapticsLabel),
                    value: widget.preferences.haptics,
                    onChanged: (value) => widget.onPreferencesChanged(widget.preferences.copyWith(haptics: value)),
                  ),
                  SwitchListTile(
                    title: const Text('Characters enabled'),
                    value: widget.preferences.companionEnabled,
                    onChanged: (value) => widget.onPreferencesChanged(widget.preferences.copyWith(companionEnabled: value)),
                  ),
                  const SizedBox(height: QSpace.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CharacterView(size: 160, aspect: 0.88, zoom: 1.45, controller: _guide),
                      CharacterView(role: CharacterRole.assistant, size: 100, controller: _assistant),
                    ],
                  ),
                  Wrap(
                    spacing: QSpace.xs,
                    runSpacing: QSpace.xs,
                    children: [
                      for (final mood in CharacterMood.values)
                        TextButton(
                          key: ValueKey('character-mood-${mood.name}'),
                          onPressed: () {
                            _guide.mood = mood;
                            _assistant.mood = mood;
                          },
                          child: Text(mood.name),
                        ),
                      for (final cue in CharacterCue.values)
                        TextButton(key: ValueKey('character-cue-${cue.name}'), onPressed: () => _guide.cue(cue), child: Text(cue.name)),
                      for (final id in widget.characterIds)
                        TextButton(onPressed: () => widget.onCastingChanged(id), child: Text('Guide: $id')),
                    ],
                  ),
                  const SizedBox(height: QSpace.lg),
                  QButton(key: const ValueKey('dev-gallery'), label: 'Component gallery', onPressed: () => context.push('/gallery')),
                  const SizedBox(height: QSpace.md),
                  QButton(
                    key: const ValueKey('dev-probe'),
                    label: 'Test auth + profile request',
                    onPressed: state.status == DevToolsStatus.loading
                        ? null
                        : () => context.read<DevToolsBloc>().add(const DevProbeRequested()),
                  ),
                  if (snapshot?.probeUser != null)
                    Text(
                      '${snapshot!.probeUser!.displayName}\nQabas-Client: ${snapshot.probeClient}\nQabas-Contract: ${snapshot.probeContract}\nAccept-Language: ${snapshot.probeLanguage}',
                    ),
                  const SizedBox(height: QSpace.lg),
                  toggle('Fast latency', DevOption.fast),
                  toggle('Offline', DevOption.offline),
                  toggle('Unknown visual fallback', DevOption.unknownVisual),
                  toggle(context.l10n.communityNoLeagueTitle, DevOption.noLeague),
                  if (snapshot?.devFlagsEnabled == true)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: snapshot?.values[DevOption.recitationOutcome] as String? ?? 'errors',
                      decoration: InputDecoration(labelText: context.l10n.recitationDeveloperOutcome),
                      items: [
                        for (final value in ['errors', 'missing_extra', 'passed', 'unclear', 'busy'])
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              switch (value) {
                                'passed' => context.l10n.recitationCorrectWord,
                                'unclear' => context.l10n.recitationDeveloperUnclear,
                                'busy' => context.l10n.recitationBusy,
                                'missing_extra' => context.l10n.recitationDeveloperMissingExtra,
                                _ => context.l10n.recitationSubstitutedWord,
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) change(DevOption.recitationOutcome, value);
                      },
                    ),
                  if (snapshot?.devFlagsEnabled == true) ...[
                    toggle('Hide draft notices', DevOption.hideDraftNotices),
                    toggle('Curiosity onboarding', DevOption.curiosityOnboarding),
                  ],
                  if (snapshot?.mockAvailable == true) ...[
                    const SizedBox(height: QSpace.lg),
                    SwitchListTile(
                      title: const Text('Contract test curriculum'),
                      value: snapshot?.values[DevOption.contractCurriculum] == true,
                      onChanged: (value) => context.read<DevToolsBloc>().add(DevOptionChanged(DevOption.contractCurriculum, value)),
                    ),
                    TextButton(
                      key: const ValueKey('dev-guide'),
                      onPressed: () => context.push('/units/unit_1/guide'),
                      child: const Text('Supplied guide preview'),
                    ),
                    Text(context.l10n.sessionSalahPreview),
                    Wrap(
                      spacing: QSpace.xs,
                      children: [
                        for (final lang in ['en', 'ar'])
                          for (final track in ['explorer', 'new_muslim'])
                            TextButton(
                              key: ValueKey('dev-salah-$lang-$track'),
                              onPressed: state.status == DevToolsStatus.loading
                                  ? null
                                  : () {
                                      widget.onLanguageChanged(lang);
                                      context.read<DevToolsBloc>().add(DevLessonPreviewOpened('les_u1_l3', track: track));
                                    },
                              child: Text('$lang · $track'),
                            ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('dev-unit0-picker'),
                      isExpanded: true,
                      decoration: InputDecoration(labelText: context.l10n.sessionUnit0ContentPreview),
                      items: [
                        for (final entry in snapshot!.unit0Choices.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (id) {
                        if (id != null) context.read<DevToolsBloc>().add(DevLessonPreviewOpened(id));
                      },
                    ),
                    const SizedBox(height: QSpace.md),
                    Wrap(
                      spacing: QSpace.xs,
                      children: [
                        for (final status in [426, 503, 429])
                          TextButton(onPressed: () => change(DevOption.nextStatus, status), child: Text('Next HTTP $status')),
                        TextButton(onPressed: () => change(DevOption.revoke, null), child: const Text('Revoke token')),
                      ],
                    ),
                    QSegmentedChips<String>(
                      options: const {'explorer': 'Explorer', 'new_muslim': 'New Muslim'},
                      selected: snapshot.values[DevOption.track] as String? ?? 'explorer',
                      onSelected: (value) => change(DevOption.track, value),
                    ),
                    const SizedBox(height: QSpace.md),
                    DropdownButtonFormField<String>(
                      initialValue: snapshot.values[DevOption.raqeebOutcome] as String? ?? 'A',
                      decoration: const InputDecoration(labelText: 'Raqeeb outcome'),
                      items: [
                        for (final value in ['auto', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'failed'])
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) {
                        if (value != null) change(DevOption.raqeebOutcome, value);
                      },
                    ),
                    const SizedBox(height: QSpace.md),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Mark lesson completed'),
                      items: [
                        for (final entry in snapshot.lessonChoices.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                      ],
                      onChanged: (value) {
                        if (value != null) change(DevOption.completedLesson, value);
                      },
                    ),
                    const Text('Bot speed'),
                    Slider(
                      value: (snapshot.values[DevOption.botSpeed] as double).clamp(0.25, 2),
                      min: 0.25,
                      max: 2,
                      onChanged: (value) => change(DevOption.botSpeed, value),
                    ),
                    Wrap(
                      children: [
                        TextButton(onPressed: () => change(DevOption.resetProgress, null), child: const Text('Reset progress')),
                        TextButton(onPressed: () => change(DevOption.reset, null), child: const Text('Reset mock database')),
                      ],
                    ),
                  ],
                  Wrap(
                    children: [
                      TextButton(onPressed: widget.onLocalReset, child: const Text('Clear local preferences and resume data')),
                      TextButton(onPressed: widget.onGateReset, child: const Text('Restart bootstrap')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
