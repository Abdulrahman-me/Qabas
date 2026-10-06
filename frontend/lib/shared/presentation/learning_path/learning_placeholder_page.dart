import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';

/// Route destination until its named phase builds the lesson/review flow.
class LearningPlaceholderPage extends StatelessWidget {
  const LearningPlaceholderPage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: QEmptyView(
        key: const ValueKey('learning-entry'),
        title: title,
        body: context.l10n.learningEntryBody,
        illustration: const CharacterView(size: QJourney.companion, appearCue: CharacterCue.greet),
        action: (context.l10n.commonBack, () => context.pop()),
      ),
    ),
  );
}
