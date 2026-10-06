import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/audio/sensory_service.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';

/// Tab scaffold. The navigation adapts to the screen: a bottom bar on phones,
/// a side rail on tablets and the web; and to the content: night-toned on the
/// journey, light everywhere else.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(BuildContext context, int i) {
    if (i != shell.currentIndex) SensoryScope.of(context).select();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final items = [
      _NavItem(
        s.commonTabJourney,
        (on, c) => Icon(on ? Icons.explore_rounded : Icons.explore_outlined, color: c, size: QNavigation.iconLarge),
      ),
      _NavItem(
        s.commonTabDiscover,
        (on, c) => Icon(on ? Icons.travel_explore_rounded : Icons.travel_explore_outlined, color: c, size: QNavigation.icon),
      ),
      _NavItem(s.commonTabRaqeeb, (on, c) => LanternGlyph(color: c, lit: on, size: QNavigation.icon)),
      _NavItem(
        s.commonTabCommunity,
        (on, c) => Icon(on ? Icons.emoji_events_rounded : Icons.emoji_events_outlined, color: c, size: QNavigation.icon),
      ),
      _NavItem(
        s.commonTabProfile,
        (on, c) => Icon(on ? Icons.person_rounded : Icons.person_outline_rounded, color: c, size: QNavigation.iconLarge),
      ),
    ];
    final night = shell.currentIndex == 0;
    final wide = MediaQuery.sizeOf(context).width >= QBreakpoints.rail;

    final scaffold = wide
        ? Scaffold(
            backgroundColor: night ? QColors.night950 : QColors.morningMint,
            body: Row(
              children: [
                _Rail(items: items, index: shell.currentIndex, night: night, onTap: (i) => _go(context, i)),
                Expanded(child: shell),
              ],
            ),
          )
        : Scaffold(
            body: shell,
            extendBody: false,
            bottomNavigationBar: _BottomBar(items: items, index: shell.currentIndex, night: night, onTap: (i) => _go(context, i)),
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(value: night ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark, child: scaffold);
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final Widget Function(bool active, Color color) icon;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.items, required this.index, required this.night, required this.onTap});
  final List<_NavItem> items;
  final int index;
  final bool night;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnimatedContainer(
      duration: context.reduceMotion ? Duration.zero : QMotion.medium,
      curve: QMotion.gentle,
      decoration: BoxDecoration(
        color: night ? QColors.night950 : QColors.surface,
        border: Border(
          top: BorderSide(color: night ? QColors.nightLine.withValues(alpha: 0.6) : QColors.line, width: QNavigation.borderWidth),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom - QNavigation.barTop : QSpace.xs, top: QNavigation.barTop),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavButton(key: ValueKey('nav-$i'), item: items[i], active: i == index, night: night, onTap: () => onTap(i)),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({super.key, required this.item, required this.active, required this.night, required this.onTap});
  final _NavItem item;
  final bool active;
  final bool night;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = night ? QColors.flameGold : QColors.emerald500;
    final idle = night ? QColors.softEmber.withValues(alpha: 0.55) : QColors.muted;
    final color = active ? activeColor : idle;
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: false,
        scale: QNavigation.pressScale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: context.reduceMotion ? Duration.zero : QMotion.normal,
              curve: QMotion.emphasized,
              padding: const EdgeInsets.symmetric(horizontal: QSpace.md, vertical: QNavigation.iconPadding),
              decoration: BoxDecoration(
                color: active ? activeColor.withValues(alpha: night ? 0.16 : 0.12) : Colors.transparent,
                borderRadius: QRadius.chip,
              ),
              child: item.icon(active, color),
            ),
            const SizedBox(height: QNavigation.labelGap),
            AnimatedDefaultTextStyle(
              duration: context.reduceMotion ? Duration.zero : QMotion.normal,
              style: context.text.labelSmall!.copyWith(
                color: color,
                letterSpacing: QNavigation.labelTracking,
                fontSize: QNavigation.labelSize,
              ),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(item.label, maxLines: 1, softWrap: false)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.items, required this.index, required this.night, required this.onTap});
  final List<_NavItem> items;
  final int index;
  final bool night;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.reduceMotion ? Duration.zero : QMotion.medium,
      width: QNavigation.railWidth,
      decoration: BoxDecoration(
        color: night ? QColors.night950 : QColors.surface,
        border: BorderDirectional(
          end: BorderSide(color: night ? QColors.nightLine : QColors.line, width: QNavigation.borderWidth),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: QSpace.xl),
              FlameMark(size: QNavigation.railMark, glow: night ? 1 : 0.5),
              const SizedBox(height: QSpace.xxl),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: QSpace.sm),
                  child: _NavButton(key: ValueKey('nav-$i'), item: items[i], active: i == index, night: night, onTap: () => onTap(i)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
