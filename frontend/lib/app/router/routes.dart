abstract final class Routes {
  static const journey = '/journey', discover = '/discover', raqeeb = '/raqeeb', community = '/community', profile = '/profile';
  static const splash = '/splash', welcome = '/welcome', sessionEnded = '/session-ended', outdated = '/outdated';
  static const settings = '/settings', about = '/about', glossary = '/glossary', achievements = '/achievements';
  static const developer = '/developer', gallery = '/gallery';
  static const review = '/review/session', streak = '/streak';
  static String unitPretest(String id) => '/units/${Uri.encodeComponent(id)}/pretest';
  static String unitTest(String id) => '/units/${Uri.encodeComponent(id)}/test';
  static String unitGuide(String id) => '/units/${Uri.encodeComponent(id)}/guide';
  static String lessonIntro(String id) => '/lesson/${Uri.encodeComponent(id)}/intro';
}
