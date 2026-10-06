import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_auth_bloc.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

class ReviewerLoginPage extends StatefulWidget {
  const ReviewerLoginPage({super.key, required this.onSignedIn});
  final ValueChanged<UserProfile> onSignedIn;
  @override
  State<ReviewerLoginPage> createState() => _ReviewerLoginPageState();
}

class _ReviewerLoginPageState extends State<ReviewerLoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => BlocConsumer<ReviewerAuthBloc, ReviewerAuthState>(
    listener: (c, s) {
      if (s.status == ReviewerAuthStatus.signedIn) widget.onSignedIn(s.user!);
    },
    builder: (c, s) => Scaffold(
      backgroundColor: QColors.morningMint,
      appBar: AppBar(title: Text(c.l10n.reviewerConsole)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(QSpace.page),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QCard(
                    color: QColors.nightEmerald,
                    child: Padding(
                      padding: const EdgeInsets.all(QSpace.lg),
                      child: Text(c.l10n.reviewerSignIn, style: c.text.headlineMedium?.copyWith(color: QColors.softEmber)),
                    ),
                  ),
                  const SizedBox(height: QSpace.xl),
                  TextFormField(
                    key: const ValueKey('reviewer-email'),
                    controller: email,
                    autofillHints: const [AutofillHints.username],
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: c.l10n.reviewerEmail),
                    validator: (v) => v == null || !v.contains('@') ? c.l10n.reviewerEmail : null,
                  ),
                  const SizedBox(height: QSpace.md),
                  TextFormField(
                    key: const ValueKey('reviewer-password'),
                    controller: password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: c.l10n.reviewerPassword),
                    validator: (v) => v == null || v.isEmpty ? c.l10n.reviewerPassword : null,
                  ),
                  const SizedBox(height: QSpace.xl),
                  if (s.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: QSpace.md),
                      child: Text(
                        s.failure is RateLimitedFailure ? c.l10n.reviewerLockout : failureBody(s.failure!, c.l10n),
                        style: c.text.bodyMedium?.copyWith(color: QColors.statusFabricated),
                      ),
                    ),
                  QButton(
                    key: const ValueKey('reviewer-sign-in'),
                    silent: true,
                    label: c.l10n.reviewerSignIn,
                    onPressed: s.status == ReviewerAuthStatus.submitting
                        ? null
                        : () {
                            if (form.currentState!.validate()) {
                              c.read<ReviewerAuthBloc>().add(ReviewerSignedIn(email.text.trim(), password.text));
                            }
                          },
                  ),
                  if (s.status == ReviewerAuthStatus.submitting) const QInlineLoading(showFlame: false),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
