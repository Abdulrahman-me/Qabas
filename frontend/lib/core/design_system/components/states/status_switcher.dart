import 'package:flutter/widgets.dart';
import 'package:qabas/core/design_system/components/states/state_views.dart';
import 'package:qabas/core/design_system/theme/theme_x.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

enum LoadStatus { initial, loading, success, empty, failure, refreshing }

class StatusSwitcher extends StatelessWidget {
  const StatusSwitcher({
    super.key,
    required this.status,
    required this.hasData,
    required this.loading,
    required this.empty,
    required this.failure,
    required this.builder,
  });
  final LoadStatus status;
  final bool hasData;
  final Widget Function() loading;
  final Widget Function() empty;
  final Widget Function() failure;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    final child = hasData
        ? builder()
        : switch (status) {
            LoadStatus.initial || LoadStatus.loading || LoadStatus.refreshing => DelayedLoading(child: loading()),
            LoadStatus.empty => empty(),
            LoadStatus.failure => failure(),
            LoadStatus.success => builder(),
          };
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : QMotion.normal,
      switchInCurve: QMotion.emphasized,
      switchOutCurve: QMotion.emphasized,
      child: KeyedSubtree(key: ValueKey(hasData ? 'content' : status), child: child),
    );
  }
}
