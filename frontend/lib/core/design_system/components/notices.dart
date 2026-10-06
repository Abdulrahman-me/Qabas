import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/components/buttons.dart';
import 'package:qabas/core/design_system/theme/app_theme.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class QConfirmSheet extends StatelessWidget {
  const QConfirmSheet({
    super.key,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.destructive = false,
    this.art,
  });
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool destructive;
  final Widget? art;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(child: art ?? const FlameMark(size: 56, glow: 0.6)),
      const SizedBox(height: QSpace.md),
      Text(title, style: context.text.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: QSpace.sm),
      Text(body, style: context.text.bodyLarge, textAlign: TextAlign.center),
      const SizedBox(height: QSpace.xl),
      QButton(label: primaryLabel, onPressed: onPrimary, tone: destructive ? QButtonTone.retry : QButtonTone.emerald),
      if (secondaryLabel != null) ...[
        const SizedBox(height: QSpace.xs),
        QButton(label: secondaryLabel!, onPressed: onSecondary, tone: QButtonTone.ghost),
      ],
    ],
  );
}

class SessionEndedSheet extends StatelessWidget {
  const SessionEndedSheet({super.key, required this.onContinue, this.art});
  final VoidCallback onContinue;
  final Widget? art;
  @override
  Widget build(BuildContext context) => QConfirmSheet(
    title: context.l10n.commonSessionEndedTitle,
    body: context.l10n.commonSessionEndedBody,
    primaryLabel: context.l10n.commonContinue,
    onPrimary: onContinue,
    art: art,
  );
}

void showQSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: actionLabel != null && onAction != null ? SnackBarAction(label: actionLabel, onPressed: onAction) : null,
    ),
  );
}
