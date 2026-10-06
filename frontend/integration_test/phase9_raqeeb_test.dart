import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/domain/usecases/dev_tools_actions.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/chat_widgets.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const selected = String.fromEnvironment('PHASE9_OUTCOMES');
  final allOutcomes = [...'ABCDEFGH'.split(''), 'failed'];
  final outcomes = selected.isEmpty ? allOutcomes : selected.split(',');
  assert(outcomes.every(allOutcomes.contains));
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Raqeeb text, stages, all outcomes, rating and retry $language/$reduced', (t) async {
        Future<void> until(bool Function() ready) async {
          for (var i = 0; i < 240 && !ready(); i++) {
            await t.pump(const Duration(milliseconds: 80));
          }
          expect(ready(), true);
          expect(t.takeException(), isNull);
          await t.pump(const Duration(milliseconds: 600));
        }

        Future<void> capture(String name) async {
          for (var i = 0; i < 70; i++) {
            await t.pump(const Duration(milliseconds: 16));
          }
          expect(t.takeException(), isNull);
          await binding.takeScreenshot(name);
        }

        final store = await PreferencesStore.open();
        await store.clear();
        await store.setString('language', language);
        await store.setBoolean('reduce_motion', reduced);
        final d = await AppDependencies.create(
          config: AppConfig(),
          store: store,
          initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await d.dispose();
        });
        await d.services<TokenStore>().clear();
        d.services<MockBackend>().controls.fast = true;
        await d.services<AuthRepository>().createGuest();
        await d.services<OnboardingRepository>().complete(
          OnboardingAnswers(
            track: TrackChoice.explorer,
            language: language,
            familiarity: null,
            dailyGoal: 10,
            privateProfile: true,
            goalAnchor: null,
          ),
        );
        await t.pumpWidget(QabasApp(dependencies: d));
        await until(
          () =>
              find.byType(JourneyPage).evaluate().isNotEmpty &&
              t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey != null,
        );
        await t.tap(find.byKey(const ValueKey('nav-2')));
        await until(() => find.byType(RaqeebPage).evaluate().isNotEmpty);
        final prefix = 'phase9/${defaultTargetPlatform.name}_${language}_${reduced ? 'reduced' : 'motion'}';
        await capture('${prefix}_43_welcome');
        final c = t.element(find.byType(RaqeebPage)), bloc = c.read<RaqeebChatBloc>();
        for (final (i, outcome) in outcomes.indexed) {
          if (i > 0) {
            await t.tap(find.byKey(const ValueKey('raqeeb-new')));
            await until(() => bloc.state.status == ChatStatus.welcome && bloc.state.turns.isEmpty);
          }
          await d.services<DevToolsActions>().change(DevOption.raqeebOutcome, outcome);
          final q = raqeebSuggestions(c)[allOutcomes.indexOf(outcome) % 4];
          // A retained EditableText is unfocused/disabled during processing;
          // a real tap reconnects native input before synthetic keyboard text.
          await t.tap(find.byType(TextField));
          await t.pump(const Duration(milliseconds: 500));
          await t.enterText(find.byType(TextField), q);
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          expect(t.widget<TextField>(find.byType(TextField)).controller!.text, q);
          await t.tap(find.byTooltip(c.l10n.commonSendTooltip));
          await until(() => bloc.state.status == ChatStatus.processing);
          expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
          if (i == 0) await capture('${prefix}_processing');
          await until(() => !bloc.state.busy && bloc.state.turns.last.assistant is! ProcessingMessage);
          expect(bloc.state.turns.last.assistant, outcome == 'failed' ? isA<FailedMessage>() : isA<CompletedMessage>());
          final answer = bloc.state.turns.last.assistant;
          if (answer is CompletedMessage) {
            final list = t.widget<ListView>(find.byType(ListView));
            list.controller!.jumpTo(0);
            await t.pump();
            await capture('${prefix}_${outcome}_answer_top');
            final toggle = find.byKey(ValueKey('raqeeb-understood-${answer.messageId}'));
            await Scrollable.ensureVisible(t.element(toggle), alignment: 0);
            await t.pump();
            await t.tap(toggle);
            await t.pump();
            await capture('${prefix}_${outcome}_understood');
            final rating = find.byKey(ValueKey('raqeeb-rate-${answer.messageId}-up'));
            await Scrollable.ensureVisible(t.element(rating));
            await t.pump();
            await t.tap(rating);
            await until(() => bloc.state.ratings[answer.messageId] == AnswerRating.up);
            await capture('${prefix}_${outcome}_answer_bottom');
          } else {
            await capture('${prefix}_failed');
            final turn = bloc.state.turns.last;
            await t.tap(find.byKey(ValueKey('raqeeb-retry-${turn.key}')));
            await until(() => bloc.state.turns.length == 2);
            expect(bloc.state.turns.last.key, isNot(turn.key));
            await until(() => !bloc.state.busy);
          }
        }
      });
    }
  }
}
