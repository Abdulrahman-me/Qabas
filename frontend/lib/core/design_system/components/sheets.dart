// Ported from the read-only prototype; authored proportions and motion retained.

import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

/// Rounded bottom sheet with a drag handle, constrained to a readable width
/// on tablets and the web.
Future<T?> showQSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color color = QColors.surface,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: QColors.nightEmerald.withValues(alpha: 0.42),
    sheetAnimationStyle: context.reduceMotion ? AnimationStyle.noAnimation : null,
    constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
    builder: (ctx) => Padding(
      // Keep sheet actions reachable when a narrow browser opens its keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Material(
        color: color,
        shape: const RoundedRectangleBorder(borderRadius: QRadius.sheet),
        child: Padding(
          padding: EdgeInsets.fromLTRB(QSpace.xl, QSpace.sm, QSpace.xl, QSpace.xl + MediaQuery.paddingOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: QSizes.sheetHandleWidth,
                    height: QSizes.sheetHandleHeight,
                    margin: const EdgeInsets.only(bottom: QSpace.md),
                    decoration: const BoxDecoration(color: QColors.lineStrong, borderRadius: QRadius.chip),
                  ),
                ),
                builder(ctx),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
