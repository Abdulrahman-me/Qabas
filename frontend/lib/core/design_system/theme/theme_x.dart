import 'package:flutter/widgets.dart';

/// Phase 1 presentation scope. Phase 2's preferences state supplies this value.
class QMotionScope extends InheritedWidget {
  const QMotionScope({super.key, required this.reduceMotion, required super.child});
  final bool reduceMotion;

  @override
  bool updateShouldNotify(QMotionScope oldWidget) => reduceMotion != oldWidget.reduceMotion;
}

extension QPresentationX on BuildContext {
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
  bool get reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(this) == true || (dependOnInheritedWidgetOfExactType<QMotionScope>()?.reduceMotion ?? false);
}
