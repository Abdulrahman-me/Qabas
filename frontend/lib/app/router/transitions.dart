import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

/// A popup route keeps the underlying page painted while its sheet opens.
class QSheetPage<T> extends Page<T> {
  const QSheetPage({super.key, required this.child, required this.barrierLabel, required this.reduceMotion});
  final Widget child;
  final String barrierLabel;
  final bool reduceMotion;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    builder: (_) => child,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: QColors.surface.withValues(alpha: 0),
    modalBarrierColor: QColors.nightEmerald.withValues(alpha: .42),
    barrierLabel: barrierLabel,
    sheetAnimationStyle: AnimationStyle(
      duration: reduceMotion ? Duration.zero : QMotion.page,
      reverseDuration: reduceMotion ? Duration.zero : QMotion.pageReverse,
    ),
  );
}

CustomTransitionPage<T> fadeThrough<T>(GoRouterState state, Widget child, {bool fromBottom = false}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: QMotion.page,
    reverseTransitionDuration: QMotion.pageReverse,
    transitionsBuilder: (context, animation, secondary, child) {
      if (context.reduceMotion) return child;
      final curved = CurvedAnimation(parent: animation, curve: QMotion.emphasized, reverseCurve: Curves.easeInCubic);
      final out = CurvedAnimation(parent: secondary, curve: QMotion.emphasized);
      return FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: out, curve: const Interval(0, 0.5))),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: const Interval(0.15, 1)),
          child: SlideTransition(
            position: Tween(begin: Offset(0, fromBottom ? 0.08 : 0.03), end: Offset.zero).animate(curved),
            child: ScaleTransition(
              scale: Tween(begin: fromBottom ? 1.0 : 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
