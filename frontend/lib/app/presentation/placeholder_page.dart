import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

/// Phase 2 shell content; product screens are built in their own phases.
class PlaceholderPage extends StatefulWidget {
  const PlaceholderPage({super.key, required this.index, this.developerEnabled = false});
  final int index;
  final bool developerEnabled;
  @override
  State<PlaceholderPage> createState() => _PlaceholderPageState();
}

class _PlaceholderPageState extends State<PlaceholderPage> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = [l.commonTabJourney, l.commonTabDiscover, l.commonTabRaqeeb, l.commonTabCommunity, l.commonTabProfile][widget.index];
    final night = widget.index == 0;
    final content = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(QSpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (night) const CharacterView(size: QNavigation.companion, appearCue: CharacterCue.greet),
                  if (widget.index == 4)
                    GestureDetector(
                      key: const ValueKey('profile-avatar'),
                      behavior: HitTestBehavior.opaque,
                      onLongPress: widget.developerEnabled ? () => context.push('/developer') : null,
                      child: const CharacterView(size: QNavigation.companion),
                    ),
                  Text(
                    label,
                    key: ValueKey('placeholder-${widget.index}'),
                    style: context.text.headlineMedium?.copyWith(color: night ? QColors.softEmber : QColors.deepInk),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return night ? NightSky(child: content) : ColoredBox(color: QColors.morningMint, child: content);
  }
}
