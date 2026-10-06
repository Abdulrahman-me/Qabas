import 'package:flutter/widgets.dart';

/// Reviewer mode preserves learner rendering while removing companion chrome.
class LessonPreviewScope extends InheritedWidget {
  const LessonPreviewScope({super.key, required super.child});
  static bool active(BuildContext c) => c.dependOnInheritedWidgetOfExactType<LessonPreviewScope>() != null;
  @override
  bool updateShouldNotify(LessonPreviewScope oldWidget) => false;
}
