final class MockControls {
  bool reviewStale = false;
  int reviewerReset = 0;
  bool fast = false, offline = false, recitationUnclear = false, unknownVisual = false;
  bool hideDraftNotices = false, curiosityOnboarding = true;
  int? nextStatus;
  String raqeebOutcome = 'A', recitationOutcome = 'errors';
  bool recitationUnavailable = false;
  double botSpeed = 1;
  void reset() {
    reviewerReset++;
    offline = false;
    reviewStale = false;
    nextStatus = null;
    recitationUnclear = false;
    recitationOutcome = 'errors';
    unknownVisual = false;
    raqeebOutcome = 'A';
    botSpeed = 1;
  }
}
