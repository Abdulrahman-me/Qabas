import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';

class ReviewerShell extends StatefulWidget {
  const ReviewerShell({super.key, required this.child, required this.onSignOut, required this.onLanguageChanged, this.onDeveloperOpened});
  final Widget child;
  final VoidCallback onSignOut;
  final VoidCallback? onDeveloperOpened;
  final ValueChanged<String> onLanguageChanged;
  @override
  State<ReviewerShell> createState() => _ReviewerShellState();
}

class _ReviewerShellState extends State<ReviewerShell> {
  final quiet = SensoryService(settings: () => const SensorySettings(sound: false, haptics: false));
  @override
  void dispose() {
    quiet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SensoryScope(
    service: quiet,
    child: _ReviewerLanguageScope(
      onChanged: widget.onLanguageChanged,
      onDeveloperOpened: widget.onDeveloperOpened,
      child: LayoutBuilder(
        builder: (c, box) {
          final path = GoRouterState.of(c).uri.path;
          final selected = path.contains('/blind')
              ? 1
              : path.contains('/metrics')
              ? 2
              : 0;
          final labels = [c.l10n.reviewerRuns, c.l10n.reviewerBlindTest, c.l10n.reviewerMetrics, c.l10n.reviewerSignOut];
          final icons = [Icons.view_list_rounded, Icons.compare_rounded, Icons.bar_chart_rounded, Icons.logout_rounded];
          void pick(int i) {
            if (i == 3) {
              widget.onSignOut();
            } else {
              c.go(['/reviewer/runs', '/reviewer/blind', '/reviewer/metrics'][i]);
            }
          }

          final wide = box.maxWidth >= QBreakpoints.rail;
          return Scaffold(
            backgroundColor: QColors.morningMint,
            body: SafeArea(
              child: Row(
                children: [
                  if (wide)
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight - MediaQuery.paddingOf(c).vertical),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            minWidth: QNavigation.railWidth,
                            backgroundColor: QColors.morningMint,
                            selectedIndex: selected,
                            onDestinationSelected: pick,
                            labelType: NavigationRailLabelType.all,
                            destinations: [
                              for (var i = 0; i < labels.length; i++)
                                NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i])),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    backgroundColor: QColors.surface,
                    selectedIndex: selected,
                    onDestinationSelected: pick,
                    destinations: [for (var i = 0; i < labels.length; i++) NavigationDestination(icon: Icon(icons[i]), label: labels[i])],
                  ),
          );
        },
      ),
    ),
  );
}

/// Language selection belongs to the page toolbar, avoiding stacked app bars.
class _ReviewerLanguageScope extends InheritedWidget {
  const _ReviewerLanguageScope({required this.onChanged, this.onDeveloperOpened, required super.child});
  final ValueChanged<String> onChanged;
  final VoidCallback? onDeveloperOpened;
  @override
  bool updateShouldNotify(_ReviewerLanguageScope oldWidget) => onChanged != oldWidget.onChanged;
}

class ReviewerLanguageMenu extends StatelessWidget {
  const ReviewerLanguageMenu({super.key});
  @override
  Widget build(BuildContext c) {
    final scope = c.dependOnInheritedWidgetOfExactType<_ReviewerLanguageScope>();
    if (scope == null) return const SizedBox.shrink();
    return GestureDetector(
      onLongPress: scope.onDeveloperOpened,
      child: PopupMenuButton<String>(
        tooltip: c.l10n.settingsLanguage,
        onSelected: scope.onChanged,
        icon: GestureDetector(
          key: const ValueKey('reviewer-language-gesture'),
          onLongPress: scope.onDeveloperOpened,
          child: const Icon(Icons.language_rounded),
        ),
        itemBuilder: (c) => [
          PopupMenuItem(value: 'en', child: Text(c.l10n.commonEnglish)),
          PopupMenuItem(value: 'ar', child: Text(c.l10n.commonArabic)),
        ],
      ),
    );
  }
}
