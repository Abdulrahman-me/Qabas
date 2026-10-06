enum ApiMode { mock, hybrid, live }

enum AppFlavor { dev, demo, prod }

enum LiveGroup {
  auth,
  profile,
  journey,
  sessions,
  recitation,
  glossary,
  raqeeb,
  community,
  challenges,
  reviewer;

  static LiveGroup of(String path) {
    final segments = Uri.parse(path).path.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.firstOrNull == 'v1') segments.removeAt(0);
    return switch (segments.firstOrNull) {
      'auth' => segments.elementAtOrNull(1) == 'reviewer' ? LiveGroup.reviewer : LiveGroup.auth,
      'onboarding' => LiveGroup.auth,
      'me' => segments.elementAtOrNull(1) == 'quests' ? LiveGroup.community : LiveGroup.profile,
      'journey' || 'units' => LiveGroup.journey,
      'sessions' || 'lessons' => LiveGroup.sessions,
      'recitation' => LiveGroup.recitation,
      'glossary' => LiveGroup.glossary,
      'raqeeb' => LiveGroup.raqeeb,
      'leagues' || 'friends' => LiveGroup.community,
      'duels' => LiveGroup.challenges,
      'admin' => LiveGroup.reviewer,
      _ => throw ArgumentError('Path has no contract group'),
    };
  }
}

final class AppConfig {
  AppConfig({
    this.mode = ApiMode.mock,
    this.flavor = AppFlavor.dev,
    this.baseUrl = 'http://localhost:8000/v1',
    Set<LiveGroup> liveGroups = const {},
    this.hideDraftNotices = false,
    this.curiosityOnboarding = true,
    this.demoDeveloper = false,
    this.recordingDemo = false,
    this.appVersion = '1.0.0',
    this.iosStoreUrl = '',
    this.androidStoreUrl = '',
    this.webUpdateUrl = '',
  }) : liveGroups = Set.unmodifiable(liveGroups) {
    if (recordingDemo && (flavor != AppFlavor.demo || mode != ApiMode.mock || !demoDeveloper)) {
      throw ArgumentError('Recording requires the mock demo flavor and hidden developer tools');
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.path != '/v1' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError('API_BASE_URL must be an HTTP origin ending in /v1');
    }
    if (flavor == AppFlavor.prod && (mode != ApiMode.live || uri.scheme != 'https' || demoDeveloper)) {
      throw ArgumentError('Production requires live HTTPS and no developer tools');
    }
    if (mode == ApiMode.hybrid && liveGroups.isNotEmpty && !liveGroups.containsAll({LiveGroup.auth, LiveGroup.profile})) {
      throw ArgumentError('Live groups require live auth and profile');
    }
  }

  factory AppConfig.fromEnvironment({required String appVersion}) => AppConfig(
    mode: ApiMode.values.byName(const String.fromEnvironment('API_MODE', defaultValue: 'mock')),
    flavor: AppFlavor.values.byName(const String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev')),
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/v1'),
    liveGroups: const String.fromEnvironment(
      'LIVE_GROUPS',
    ).split(',').where((group) => group.isNotEmpty).map(LiveGroup.values.byName).toSet(),
    hideDraftNotices: const bool.fromEnvironment('HIDE_DRAFT_NOTICES'),
    curiosityOnboarding: const bool.fromEnvironment('CURIOSITY_ONBOARDING', defaultValue: true),
    demoDeveloper: const bool.fromEnvironment('DEMO_DEVELOPER'),
    recordingDemo: const bool.fromEnvironment('RECORDING_DEMO'),
    appVersion: appVersion,
    iosStoreUrl: const String.fromEnvironment('IOS_STORE_URL'),
    androidStoreUrl: const String.fromEnvironment('ANDROID_STORE_URL'),
    webUpdateUrl: const String.fromEnvironment('WEB_UPDATE_URL'),
  );

  final ApiMode mode;
  final AppFlavor flavor;
  final String baseUrl, appVersion, iosStoreUrl, androidStoreUrl, webUpdateUrl;
  final Set<LiveGroup> liveGroups;
  final bool hideDraftNotices, curiosityOnboarding, demoDeveloper, recordingDemo;
  bool get allowsMocks => flavor != AppFlavor.prod && mode != ApiMode.live;
  bool developerMenuEnabled(bool debug) => flavor != AppFlavor.prod && (debug || demoDeveloper);
  bool isLive(LiveGroup group) => mode == ApiMode.live || (mode == ApiMode.hybrid && liveGroups.contains(group));
}
