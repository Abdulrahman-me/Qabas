import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/app/router/app_router.dart';
import 'package:qabas/app/router/routes.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/characters/character_scope.dart';
import 'package:qabas/core/characters/character_settings_cubit.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/component_gallery.dart';
import 'package:qabas/features/profile/presentation/bloc/preferences_cubit.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/presentation/visuals/visual_view.dart';

class QabasApp extends StatefulWidget {
  const QabasApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<QabasApp> createState() => _QabasAppState();
}

class _QabasAppState extends State<QabasApp> {
  late final _refresh = RouterRefresh(widget.dependencies.session.stream);
  late final _gallery = _PersistentGallerySettings(widget.dependencies);
  late final _router = createRouter(widget.dependencies, _refresh, _gallery);
  @override
  void initState() {
    super.initState();
    if (widget.dependencies.session.state.status == SessionStatus.unknown) widget.dependencies.session.add(const AppStarted());
  }

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    _gallery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dependencies;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: d.locale),
        BlocProvider.value(value: d.preferences),
        BlocProvider.value(value: d.session),
        BlocProvider.value(value: d.characters),
      ],
      child: BlocListener<AppSessionBloc, AppSessionState>(
        listener: (_, state) {
          if (state.status == SessionStatus.sessionEnded) _router.go(Routes.sessionEnded);
          if (state.status == SessionStatus.outdated) _router.go(Routes.outdated);
          if (state.user != null && [SessionStatus.ready, SessionStatus.needsOnboarding].contains(state.status)) {
            final language = state.user!.language;
            if (language != UserLanguage.unknown) unawaited(d.locale.languageChanged(language.name));
          }
        },
        child: BlocListener<PreferencesCubit, PreferencesState>(
          listenWhen: (a, b) => a.value.companionEnabled != b.value.companionEnabled,
          listener: (_, state) => d.characters.settingsChanged(enabled: state.value.companionEnabled),
          child: BlocBuilder<LocaleCubit, LocaleState>(
            builder: (_, locale) => BlocBuilder<PreferencesCubit, PreferencesState>(
              builder: (_, preferences) => BlocBuilder<CharacterSettingsCubit, CharacterSettingsState>(
                builder: (_, characters) => SensoryScope(
                  service: d.sensory,
                  child: QMotionScope(
                    reduceMotion: preferences.value.reduceMotion,
                    child: CharacterScope(
                      cache: d.cache,
                      registry: d.registry,
                      settings: characters,
                      child: MaterialApp.router(
                        debugShowCheckedModeBanner: false,
                        onGenerateTitle: (context) => context.l10n.commonAppName,
                        theme: QTheme.light(arabic: locale.language == 'ar'),
                        locale: Locale(locale.language),
                        localizationsDelegates: AppLocalizations.localizationsDelegates,
                        supportedLocales: AppLocalizations.supportedLocales,
                        routerConfig: _router,
                        builder: (context, child) {
                          final media = MediaQuery.of(context);
                          return MediaQuery(
                            data: media.copyWith(textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35)),
                            child: VisualMediaScope(resolve: d.media.resolve, scenes: d.scenes, child: child!),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the original Phase 1 gallery API while using persistent app state.
class _PersistentGallerySettings extends GallerySettings {
  _PersistentGallerySettings(this.d) {
    _subscriptions.add(d.locale.stream.listen((_) => _sync()));
    _subscriptions.add(d.preferences.stream.listen((_) => _sync()));
    _sync();
  }
  final AppDependencies d;
  final _subscriptions = <StreamSubscription<Object?>>[];
  void _sync() {
    locale = d.locale.state.language;
    final value = d.preferences.state.value;
    reduceMotion = value.reduceMotion;
    sound = value.sound;
    haptics = value.haptics;
    notifyListeners();
  }

  @override
  void languageChanged(String value) => unawaited(d.locale.languageChanged(value));
  @override
  void motionChanged(bool value) => unawaited(d.preferences.preferencesChanged(d.preferences.state.value.copyWith(reduceMotion: value)));
  @override
  void soundChanged(bool value) => unawaited(d.preferences.preferencesChanged(d.preferences.state.value.copyWith(sound: value)));
  @override
  void hapticsChanged(bool value) => unawaited(d.preferences.preferencesChanged(d.preferences.state.value.copyWith(haptics: value)));
  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
