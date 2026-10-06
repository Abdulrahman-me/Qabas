import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/session/presentation/bloc/session_start_bloc.dart';

class SessionStartPage extends StatelessWidget {
  const SessionStartPage({super.key, required this.request});
  final SessionStartRequested request;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(),
    body: BlocConsumer<SessionStartBloc, SessionStartState>(
      listener: (c, s) async {
        if (s.session != null) c.replace('/session/${s.session!.sessionId}');
        if (s.status == SessionStartStatus.empty) {
          // Finish the outgoing shell transition before reusing its navigator key.
          await Future<void>.delayed(QMotion.page);
          if (!c.mounted) return;
          ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(c.l10n.sessionAllCaughtUp)));
          if (c.canPop()) {
            c.pop();
          } else {
            c.go('/journey');
          }
        }
      },
      builder: (c, s) => s.status == SessionStartStatus.empty
          ? QEmptyView(title: c.l10n.sessionAllCaughtUp, body: c.l10n.reviewReviewSubtitle)
          : s.status == SessionStartStatus.failure
          ? QErrorView(kind: failureKind(s.failure!), onRetry: () => c.read<SessionStartBloc>().add(request))
          : const QLoadingView(),
    ),
  );
}
