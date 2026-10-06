import 'package:flutter/material.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/domain/entities/journey.dart';

Future<void> showSoftLockSheet(BuildContext context, SoftLock lock, {required ValueChanged<String> onOpen}) async {
  await showQSheet<void>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: CharacterView(size: QJourney.companion, zoom: QJourney.sheetZoom, appearCue: CharacterCue.encourage),
        ),
        const SizedBox(height: QSpace.sm),
        Text(ctx.l10n.journeySoftLockTitle, textAlign: TextAlign.center, style: ctx.text.headlineSmall),
        const SizedBox(height: QSpace.sm),
        Text(ctx.l10n.journeySoftLockBody, textAlign: TextAlign.center, style: ctx.text.bodyMedium),
        const SizedBox(height: QSpace.md),
        for (final ref in lock.prerequisites)
          Padding(
            padding: const EdgeInsets.only(bottom: QSpace.xs),
            child: QCard(shadow: false, child: Text(ref.title, style: ctx.text.titleSmall)),
          ),
        const SizedBox(height: QSpace.lg),
        QButton(
          key: const ValueKey('soft-lock-start'),
          label: ctx.l10n.journeyStartWith(lock.startWith.title),
          onPressed: () {
            Navigator.pop(ctx);
            onOpen(lock.startWith.lessonId);
          },
        ),
      ],
    ),
  );
}
