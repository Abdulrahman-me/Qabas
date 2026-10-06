final class MockDb {
  MockDb({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  Map<String, dynamic>? stats;
  final Map<String, Map<String, dynamic>> activity = {};
  final Set<String> goalRewardDays = {};
  final Map<String, String> termStates = {};
  final Map<String, Set<String>> openedTerms = {};
  Map<String, dynamic>? user;
  Map<String, dynamic>? suspendedLearner;
  DateTime? reviewerExpiresAt;
  int dueReviews = 0;
  bool friendsSeeded = false, noLeague = false;
  final Map<String, Map<String, dynamic>> duels = {};
  final Map<String, ({String id, DateTime expires})> socketTickets = {};
  bool contractCurriculum = false;
  final Set<String> pretestedUnits = {}, passedUnits = {};
  final Map<String, int> unitBestScores = {};
  final Set<String> tokens = {};
  final Set<String> tokenDigests = {};
  final Set<String> completedLessons = {}, inProgressLessons = {};
  final Map<String, Map<String, dynamic>> sessions = {},
      sessionKeys = {},
      results = {},
      answers = {},
      checks = {},
      conversations = {},
      raqeebMessages = {},
      raqeebWork = {},
      friends = {};
  final Map<String, ({String fingerprint, int status, Object? body, DateTime created})> idempotency = {};
  void reset() {
    user = null;
    suspendedLearner = null;
    reviewerExpiresAt = null;
    stats = null;
    activity.clear();
    goalRewardDays.clear();
    termStates.clear();
    openedTerms.clear();
    dueReviews = 0;
    friendsSeeded = false;
    noLeague = false;
    duels.clear();
    socketTickets.clear();
    contractCurriculum = false;
    pretestedUnits.clear();
    passedUnits.clear();
    unitBestScores.clear();
    tokens.clear();
    tokenDigests.clear();
    completedLessons.clear();
    inProgressLessons.clear();
    for (final table in [sessions, sessionKeys, results, answers, checks, conversations, raqeebMessages, raqeebWork, friends]) {
      table.clear();
    }
    idempotency.clear();
  }
}
