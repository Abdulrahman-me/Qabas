import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class SessionEndedPage extends StatefulWidget {
  const SessionEndedPage({super.key});
  @override
  State<SessionEndedPage> createState() => _SessionEndedPageState();
}

class _SessionEndedPageState extends State<SessionEndedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<AppSessionBloc>();
      unawaited(
        showQSheet<void>(
          context,
          isDismissible: false,
          enableDrag: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CharacterView(size: QNavigation.companion, appearCue: CharacterCue.encourage),
                Text(context.l10n.commonSessionEndedTitle, textAlign: TextAlign.center, style: context.text.headlineSmall),
                const SizedBox(height: QSpace.sm),
                Text(context.l10n.commonSessionEndedBody, textAlign: TextAlign.center, style: context.text.bodyMedium),
                const SizedBox(height: QSpace.xl),
                QButton(
                  key: const ValueKey('session-ended-continue'),
                  label: context.l10n.commonContinue,
                  onPressed: () {
                    Navigator.of(context).pop();
                    bloc.add(const SessionEndedAcknowledged());
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: QColors.night950,
    body: NightSky(child: SizedBox.expand()),
  );
}
