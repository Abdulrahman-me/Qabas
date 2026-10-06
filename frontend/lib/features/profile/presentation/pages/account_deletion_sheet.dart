import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_extras_bloc.dart';

class AccountDeletionSheet extends StatelessWidget {
  const AccountDeletionSheet({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
    builder: (context, s) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.settingsDeleteAccount, style: context.text.headlineSmall),
        const SizedBox(height: QSpace.sm),
        Text(context.l10n.settingsDeleteAccountBody, style: context.text.bodyLarge),
        const SizedBox(height: QSpace.xl),
        if (s.failure != null) ...[QInlineError(message: failureBody(s.failure!, context.l10n)), const SizedBox(height: QSpace.md)],
        if (s.status == AccountDeletionStatus.deleting)
          const QInlineLoading()
        else
          QButton(
            key: const ValueKey('confirm-delete-account'),
            label: context.l10n.settingsDeleteAccount,
            tone: QButtonTone.retry,
            onPressed: () => context.read<AccountDeletionBloc>().add(const AccountDeletionConfirmed()),
          ),
        QButton(
          label: context.l10n.commonCancel,
          tone: QButtonTone.ghost,
          onPressed: s.status == AccountDeletionStatus.deleting ? null : () => context.pop(),
        ),
      ],
    ),
  );
}
